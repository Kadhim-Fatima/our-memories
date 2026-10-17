import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'screens/home_screen.dart';
import 'screens/setup_screen.dart';
import 'services/github_api.dart';
import 'services/memory_store.dart';
import 'services/settings.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ar');
  runApp(const OurMemoriesApp());
}

class OurMemoriesApp extends StatelessWidget {
  const OurMemoriesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ذكرياتنا',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const Root(),
    );
  }
}

/// يقرر: إذا الإعدادات محفوظة يفتح الدفتر، وإلا يفتح شاشة الدخول.
class Root extends StatefulWidget {
  const Root({super.key});

  @override
  State<Root> createState() => _RootState();
}

class _RootState extends State<Root> {
  MemoryStore? _store;
  RepoSettings? _settings;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final s = await RepoSettings.load();
    if (s != null) _open(s);
    setState(() => _ready = true);
  }

  void _open(RepoSettings s) {
    _store?.dispose();
    _settings = s;
    _store = MemoryStore(GitHubApi(owner: s.owner, repo: s.repo, branch: s.branch, token: s.token))
      ..load();
  }

  Future<void> _logout() async {
    await RepoSettings.clear();
    setState(() {
      _store?.dispose();
      _store = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final store = _store;
    if (store == null) {
      return SetupScreen(onConnected: (s) => setState(() => _open(s)));
    }
    return HomeScreen(store: store, settings: _settings!, onLogout: _logout);
  }
}
