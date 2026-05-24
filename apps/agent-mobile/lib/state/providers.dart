import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../core/token_storage.dart';
import '../models/agent_profile.dart';
import '../models/profits.dart';
import '../services/agent_service.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';

// ─── Foundation ──────────────────────────────────────────────────────────────

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref.read(tokenStorageProvider));
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(
    ref.read(apiClientProvider),
    ref.read(tokenStorageProvider),
  );
});

final agentServiceProvider = Provider<AgentService>((ref) {
  return AgentService(ref.read(apiClientProvider));
});

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService(ref.read(agentServiceProvider));
});

// ─── Auth state ──────────────────────────────────────────────────────────────

enum AuthStatus { unknown, signedIn, signedOut }

class AuthStateNotifier extends StateNotifier<AuthStatus> {
  final AuthService _auth;

  AuthStateNotifier(this._auth) : super(AuthStatus.unknown) {
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final signedIn = await _auth.hasSession();
    state = signedIn ? AuthStatus.signedIn : AuthStatus.signedOut;
  }

  Future<void> login(String phone, String password) async {
    await _auth.login(phone, password);
    state = AuthStatus.signedIn;
  }

  Future<void> logout() async {
    await _auth.logout();
    state = AuthStatus.signedOut;
  }
}

final authStateProvider =
    StateNotifierProvider<AuthStateNotifier, AuthStatus>((ref) {
  return AuthStateNotifier(ref.read(authServiceProvider));
});

// ─── Agent profile (loaded once on sign-in) ──────────────────────────────────

final agentProfileProvider = FutureProvider<AgentProfile>((ref) async {
  return ref.read(agentServiceProvider).getMe();
});

// ─── Jobs + profits dashboard feed (polls every 8s) ──────────────────────────

class DashboardSnapshot {
  final JobsResponse jobs;
  final Profits profits;
  const DashboardSnapshot({required this.jobs, required this.profits});
}

final dashboardFeedProvider =
    StreamProvider.autoDispose<DashboardSnapshot>((ref) {
  final svc = ref.read(agentServiceProvider);
  final controller = StreamController<DashboardSnapshot>();
  Timer? timer;
  var cancelled = false;

  Future<void> tick() async {
    try {
      final jobs = await svc.getJobs();
      final profits = await svc.getProfits();
      if (!cancelled) {
        controller.add(DashboardSnapshot(jobs: jobs, profits: profits));
      }
    } catch (e) {
      if (!cancelled) controller.addError(e);
    }
  }

  tick();
  timer = Timer.periodic(const Duration(seconds: 8), (_) => tick());

  ref.onDispose(() {
    cancelled = true;
    timer?.cancel();
    controller.close();
  });

  return controller.stream;
});

// ─── Online status ───────────────────────────────────────────────────────────

class OnlineStatusNotifier extends StateNotifier<bool> {
  final AgentService _agent;
  final LocationService _location;

  OnlineStatusNotifier(this._agent, this._location, bool initial)
      : super(initial);

  Future<void> setOnline(bool next) async {
    final previous = state;
    state = next;
    try {
      await _agent.setOnline(next);
      if (next) {
        try {
          await _location.start();
        } catch (e) {
          // Revert online if we can't get location.
          await _agent.setOnline(false);
          state = previous;
          rethrow;
        }
      } else {
        await _location.stop();
      }
    } catch (e) {
      state = previous;
      rethrow;
    }
  }
}

final onlineStatusProvider =
    StateNotifierProvider<OnlineStatusNotifier, bool>((ref) {
  final profile = ref.watch(agentProfileProvider).valueOrNull;
  return OnlineStatusNotifier(
    ref.read(agentServiceProvider),
    ref.read(locationServiceProvider),
    profile?.isOnline ?? false,
  );
});
