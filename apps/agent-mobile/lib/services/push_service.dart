import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Channel id the server includes on incoming-offer pushes — matches the
/// AndroidManifest default channel meta-data so Android groups them right
/// and so we can route taps to the dashboard's offer stack.
const String kIncomingOffersChannelId = 'incoming_offers';
const String kIncomingOffersChannelName = 'Incoming offers';

/// Top-level background handler — required to be a top-level function by
/// firebase_messaging. Runs in an isolate, so we keep it dead simple: FCM
/// will already show the system notification when the payload has a
/// `notification` block, so this just stays out of the way.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage _) async {
  // Intentionally empty — display is handled by FCM's system tray rendering.
}

/// Owns the FCM lifecycle: permission, token retrieval, foreground display,
/// and a stream of tap events that the router can listen to for deep links.
class PushService {
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  final StreamController<RemoteMessage> _taps =
      StreamController<RemoteMessage>.broadcast();
  final StreamController<String> _tokenChanges =
      StreamController<String>.broadcast();

  String? _token;
  bool _ready = false;

  Stream<RemoteMessage> get taps => _taps.stream;
  Stream<String> get tokenChanges => _tokenChanges.stream;
  String? get currentToken => _token;

  /// Re-fetches the token from Firebase. Use this instead of [currentToken]
  /// when you need a guaranteed value — on a cold launch the cached field
  /// may still be null while FCM is finishing registration. Returns null
  /// (without throwing) when push was never initialised, e.g. on iOS where
  /// Firebase init is skipped pending an Apple Dev Program + plist.
  Future<String?> ensureToken() async {
    if (!_ready) return null;
    _token ??= await FirebaseMessaging.instance.getToken();
    return _token;
  }

  /// Initialise once at app start. Idempotent.
  Future<void> init() async {
    if (_ready) return;
    _ready = true;

    await _local.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (resp) {
        final payload = resp.payload;
        if (payload != null) _taps.add(_decodePayload(payload));
      },
    );

    // Pre-create the Android channel so importance is right on first push.
    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          kIncomingOffersChannelId,
          kIncomingOffersChannelName,
          description: 'A new delivery is available to accept.',
          importance: Importance.high,
        ));

    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);

    _token = await messaging.getToken();
    if (_token != null) _tokenChanges.add(_token!);
    messaging.onTokenRefresh.listen((t) {
      _token = t;
      _tokenChanges.add(t);
    });

    // Foreground: FCM does NOT auto-show on Android. Render via local plugin.
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    // Tap on the system tray while app is backgrounded.
    FirebaseMessaging.onMessageOpenedApp.listen(_taps.add);

    // Cold-start: app launched by tapping a notification.
    final initial = await messaging.getInitialMessage();
    if (initial != null) _taps.add(initial);
  }

  Future<void> _onForegroundMessage(RemoteMessage msg) async {
    final n = msg.notification;
    if (n == null) return;
    await _local.show(
      msg.hashCode,
      n.title,
      n.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          kIncomingOffersChannelId,
          kIncomingOffersChannelName,
          importance: Importance.high,
          priority: Priority.high,
          ticker: n.title,
        ),
      ),
      payload: _encodePayload(msg),
    );
  }

  String _encodePayload(RemoteMessage msg) {
    // We only need data keys so the tap handler can route. RemoteMessage
    // doesn't serialise cleanly, so flatten data → "k=v;k=v".
    return msg.data.entries.map((e) => '${e.key}=${e.value}').join(';');
  }

  RemoteMessage _decodePayload(String payload) {
    final data = <String, String>{};
    for (final part in payload.split(';')) {
      final idx = part.indexOf('=');
      if (idx > 0) data[part.substring(0, idx)] = part.substring(idx + 1);
    }
    return RemoteMessage(data: data);
  }

  void dispose() {
    _taps.close();
    _tokenChanges.close();
  }
}

/// Singleton handle so main.dart and the router both reach the same instance
/// without threading it through providers (push wiring is bootstrap, not
/// state).
final PushService pushService = PushService();

/// Convenience: log token in debug so we can paste it into the FCM console
/// for ad-hoc test sends before the backend push hook is wired.
void debugLogPushToken() {
  if (kDebugMode) {
    final t = pushService.currentToken;
    debugPrint('[FCM] token=$t');
  }
}
