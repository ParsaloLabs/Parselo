import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme.dart';
import 'router.dart';
import 'state/providers.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
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
