import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme.dart';
import 'router.dart';
import 'services/push_service.dart';
import 'state/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  await pushService.init();
  debugLogPushToken();

  runApp(const ProviderScope(child: ParsaloAgentApp()));
}

class ParsaloAgentApp extends ConsumerStatefulWidget {
  const ParsaloAgentApp({super.key});

  @override
  ConsumerState<ParsaloAgentApp> createState() => _ParsaloAgentAppState();
}

class _ParsaloAgentAppState extends ConsumerState<ParsaloAgentApp> {
  @override
  void initState() {
    super.initState();
    final api = ref.read(apiClientProvider);
    api.onUnauthorized = () {
      ref.read(authStateProvider.notifier).logout();
    };
    // Route notification taps. Offers live on /dashboard; if a future push
    // carries `orderId`, deep-link straight to job detail.
    pushService.taps.listen((msg) {
      if (!mounted) return;
      final router = ref.read(routerProvider);
      final orderId = msg.data['orderId'];
      if (orderId != null && orderId.isNotEmpty) {
        router.go('/dashboard/jobs/$orderId');
      } else {
        router.go('/dashboard');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Parsalo Agent',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      routerConfig: router,
    );
  }
}
