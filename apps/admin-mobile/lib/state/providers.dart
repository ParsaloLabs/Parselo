import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../core/token_storage.dart';
import '../models/admin_kpi.dart';
import '../models/admin_order.dart';
import '../models/pending_agent.dart';
import '../models/dispatch_config.dart';

// ─── Foundation ──────────────────────────────────────────────────────────────

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());

final Provider<ApiClient> apiClientProvider = Provider<ApiClient>((ref) {
  final tokens = ref.read(tokenStorageProvider);
  final client = ApiClient(tokens);
  client.onUnauthorized = () {
    ref.read(authStateProvider.notifier).logout();
  };
  return client;
});

// ─── Auth State ──────────────────────────────────────────────────────────────

enum AuthStatus { unknown, signedIn, signedOut }

class AuthStateNotifier extends StateNotifier<AuthStatus> {
  final ApiClient _client;
  final TokenStorage _tokens;

  AuthStateNotifier(this._client, this._tokens) : super(AuthStatus.unknown) {
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final signedIn = await _tokens.hasToken();
    state = signedIn ? AuthStatus.signedIn : AuthStatus.signedOut;
  }

  Future<void> login(String email, String password) async {
    try {
      final res = await _client.dio.post('/auth/admin/login', data: {
        'email': email,
        'password': password,
      });
      final token = res.data['token'];
      if (token != null && token is String) {
        await _tokens.saveToken(token);
        state = AuthStatus.signedIn;
      } else {
        throw Exception('No token returned from server');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> logout() async {
    await _tokens.deleteToken();
    state = AuthStatus.signedOut;
  }
}

final StateNotifierProvider<AuthStateNotifier, AuthStatus> authStateProvider =
    StateNotifierProvider<AuthStateNotifier, AuthStatus>((ref) {
  return AuthStateNotifier(
    ref.read(apiClientProvider),
    ref.read(tokenStorageProvider),
  );
});

// ─── Dashboard Stats Provider (Polls every 10s) ──────────────────────────────

final dashboardStatsProvider =
    StreamProvider.autoDispose<AdminKpis>((ref) {
  final client = ref.read(apiClientProvider);
  final controller = StreamController<AdminKpis>();
  Timer? timer;
  var cancelled = false;

  Future<void> tick() async {
    try {
      final res = await client.dio.get('/admin/dashboard-stats');
      if (!cancelled && res.data != null) {
        controller.add(AdminKpis.fromJson(res.data));
      }
    } catch (e) {
      if (!cancelled) controller.addError(e);
    }
  }

  tick();
  timer = Timer.periodic(const Duration(seconds: 10), (_) => tick());

  ref.onDispose(() {
    cancelled = true;
    timer?.cancel();
    controller.close();
  });

  return controller.stream;
});

// ─── Orders Feed Provider ──────────────────────────────────────────────────

class OrdersFeedNotifier extends StateNotifier<AsyncValue<List<AdminOrder>>> {
  final ApiClient _client;
  String? _currentStatus;

  OrdersFeedNotifier(this._client) : super(const AsyncValue.loading());

  Future<void> fetchOrders({String? status}) async {
    _currentStatus = status;
    state = const AsyncValue.loading();
    try {
      final queryParams = <String, dynamic>{'limit': 100};
      if (status != null && status != 'all') {
        queryParams['status'] = status;
      }
      final res = await _client.dio.get('/admin/orders', queryParameters: queryParams);
      final raw = res.data;
      if (raw is List) {
        final list = raw.map((j) => AdminOrder.fromJson(j)).toList();
        state = AsyncValue.data(list);
      } else {
        state = AsyncValue.error('Invalid response format', StackTrace.current);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() async {
    await fetchOrders(status: _currentStatus);
  }
}

final ordersFeedProvider =
    StateNotifierProvider.autoDispose<OrdersFeedNotifier, AsyncValue<List<AdminOrder>>>((ref) {
  final notifier = OrdersFeedNotifier(ref.read(apiClientProvider));
  notifier.fetchOrders(status: 'all');
  return notifier;
});

// ─── Pending Agents Provider ───────────────────────────────────────────────

class PendingAgentsNotifier extends StateNotifier<AsyncValue<List<PendingAgent>>> {
  final ApiClient _client;

  PendingAgentsNotifier(this._client) : super(const AsyncValue.loading());

  Future<void> fetchPending() async {
    state = const AsyncValue.loading();
    try {
      final res = await _client.dio.get('/admin/agents/pending');
      final raw = res.data;
      if (raw is List) {
        final list = raw.map((j) => PendingAgent.fromJson(j)).toList();
        state = AsyncValue.data(list);
      } else {
        state = AsyncValue.error('Invalid response format', StackTrace.current);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> approveAgent(String id) async {
    try {
      await _client.dio.post('/admin/agents/$id/approve');
      await fetchPending();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> rejectAgent(String id, String reason) async {
    try {
      await _client.dio.post('/admin/agents/$id/reject', data: {'reason': reason});
      await fetchPending();
    } catch (e) {
      rethrow;
    }
  }
}

final pendingAgentsProvider =
    StateNotifierProvider.autoDispose<PendingAgentsNotifier, AsyncValue<List<PendingAgent>>>((ref) {
  final notifier = PendingAgentsNotifier(ref.read(apiClientProvider));
  notifier.fetchPending();
  return notifier;
});

// ─── Approved Active Agents Provider (for assignment dialog) ───────────────

final approvedAgentsProvider =
    FutureProvider.autoDispose<List<ApprovedAgent>>((ref) async {
  final client = ref.read(apiClientProvider);
  final res = await client.dio.get('/admin/agents');
  final raw = res.data;
  if (raw is List) {
    return raw.map((j) => ApprovedAgent.fromJson(j)).toList();
  }
  return [];
});

// ─── Dispatch Config Provider ───────────────────────────────────────────────

class DispatchConfigNotifier extends StateNotifier<AsyncValue<DispatchConfig>> {
  final ApiClient _client;

  DispatchConfigNotifier(this._client) : super(const AsyncValue.loading());

  Future<void> fetchConfig() async {
    state = const AsyncValue.loading();
    try {
      final res = await _client.dio.get('/admin/dispatch-config');
      state = AsyncValue.data(DispatchConfig.fromJson(res.data));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateConfig(int radiusM, int ttlSeconds) async {
    try {
      final res = await _client.dio.post('/admin/dispatch-config', data: {
        'initial_radius_m': radiusM,
        'offer_ttl_seconds': ttlSeconds,
      });
      state = AsyncValue.data(DispatchConfig.fromJson(res.data));
    } catch (e) {
      rethrow;
    }
  }
}

final dispatchConfigProvider =
    StateNotifierProvider.autoDispose<DispatchConfigNotifier, AsyncValue<DispatchConfig>>((ref) {
  final notifier = DispatchConfigNotifier(ref.read(apiClientProvider));
  notifier.fetchConfig();
  return notifier;
});
