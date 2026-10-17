import 'package:flutter/material.dart';

import '../services/github_api.dart';
import '../services/settings.dart';
import '../services/viewer_access.dart';
import '../theme.dart';

/// شاشة الدخول. فيها طريقتين:
/// - مشاهد: كلمة سر بس، يشوف الذكريات بدون تعديل.
/// - أدمن: اسم الحساب + الـ repo + التوكن، يضيف ويعدل ويحذف.
class SetupScreen extends StatefulWidget {
  final void Function(RepoSettings) onConnected;
  const SetupScreen({super.key, required this.onConnected});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _owner = TextEditingController();
  final _repo = TextEditingController();
  final _branch = TextEditingController(text: 'main');
  final _token = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _hide = true;
  String? _error;

  bool _checking = true;
  Map<String, dynamic>? _viewerCfg;
  bool _adminMode = false;

  @override
  void initState() {
    super.initState();
    RepoSettings.lastRepo().then((v) {
      if (!mounted) return;
      if (_owner.text.isEmpty) _owner.text = v.$1;
      if (_repo.text.isEmpty) _repo.text = v.$2;
      _branch.text = v.$3;
    });
    ViewerAccess.fetchConfig().then((cfg) {
      if (!mounted) return;
      setState(() {
        _viewerCfg = cfg;
        _adminMode = cfg == null;
        _checking = false;
      });
    });
  }

  @override
  void dispose() {
    _owner.dispose();
    _repo.dispose();
    _branch.dispose();
    _token.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() job) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await job();
    } on GitHubException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'ما گدرت أتصل بـ GitHub. تأكد من الإنترنت.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _connectAdmin() async {
    final s = RepoSettings(
      owner: _owner.text.trim(),
      repo: _repo.text.trim(),
      branch: _branch.text.trim().isEmpty ? 'main' : _branch.text.trim(),
      token: _token.text.trim(),
    );
    if (s.owner.isEmpty || s.repo.isEmpty || s.token.isEmpty) {
      setState(() => _error = 'اكتب اسم الحساب واسم الـ repo والتوكن.');
      return;
    }
    await _run(() async {
      await GitHubApi(owner: s.owner, repo: s.repo, branch: s.branch, token: s.token).checkAccess();
      await s.save();
      widget.onConnected(s);
    });
  }

  Future<void> _connectViewer() async {
    final pw = _password.text;
    final cfg = _viewerCfg;
    if (pw.isEmpty || cfg == null) {
      setState(() => _error = 'اكتب كلمة السر.');
      return;
    }
    await _run(() async {
      final p = await ViewerAccess.decrypt(cfg, pw);
      if (p == null) {
        if (mounted) setState(() => _error = 'كلمة السر غلط.');
        return;
      }
      final s = RepoSettings(
        owner: p['owner'] as String,
        repo: p['repo'] as String,
        branch: (p['branch'] as String?) ?? 'main',
        token: p['token'] as String,
        viewer: true,
      );
      await GitHubApi(owner: s.owner, repo: s.repo, branch: s.branch, token: s.token).checkAccess();
      await s.save();
      widget.onConnected(s);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: _checking
                  ? const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : AutofillGroup(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('دفتر ذكرياتنا',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: c.gold, letterSpacing: 1, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 4),
                          Text('أهلاً بيكم',
                              textAlign: TextAlign.center, style: displayFont(size: 48, color: c.accent)),
                          const SizedBox(height: 8),
                          Text(
                            _adminMode
                                ? 'دخول الأدمن: الذكريات والصور محفوظة بـ repo خاص على GitHub.'
                                : 'اكتبي كلمة السر حتى تشوفين ذكرياتنا 🤍',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: c.muted, height: 1.6),
                          ),
                          const SizedBox(height: 28),
                          if (_adminMode) ..._adminFields(c) else ..._viewerFields(),
                          if (_error != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(_error!, style: TextStyle(color: c.danger)),
                            ),
                          FilledButton(
                            onPressed: _busy ? null : (_adminMode ? _connectAdmin : _connectViewer),
                            child: _busy
                                ? const SizedBox(
                                    width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Text('ادخل'),
                          ),
                          const SizedBox(height: 12),
                          if (_viewerCfg != null)
                            TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => setState(() {
                                        _adminMode = !_adminMode;
                                        _error = null;
                                      }),
                              child: Text(_adminMode ? 'دخول بكلمة السر' : 'دخول الأدمن',
                                  style: TextStyle(color: c.muted)),
                            ),
                          if (_adminMode) ...[
                            const SizedBox(height: 8),
                            Text(
                              'التوكن ينحفظ بهذا المتصفح بس. لا تدخل من جهاز مو إلك، ولا ترسل التوكن لأي أحد.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: c.muted, fontSize: 12.5),
                            ),
                          ],
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _viewerFields() => [
        TextField(
          controller: _password,
          obscureText: _hide,
          autofocus: true,
          autofillHints: const [AutofillHints.password],
          onSubmitted: (_) => _connectViewer(),
          decoration: InputDecoration(
            labelText: 'كلمة السر',
            suffixIcon: IconButton(
              tooltip: _hide ? 'إظهار' : 'إخفاء',
              icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined),
              onPressed: () => setState(() => _hide = !_hide),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ];

  List<Widget> _adminFields(AppColors c) => [
        TextField(
          controller: _owner,
          textDirection: TextDirection.ltr,
          decoration: const InputDecoration(labelText: 'اسم حساب GitHub'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _repo,
          textDirection: TextDirection.ltr,
          decoration: const InputDecoration(labelText: 'اسم الـ repo الخاص', hintText: 'our-memories-data'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _token,
          obscureText: _hide,
          textDirection: TextDirection.ltr,
          onSubmitted: (_) => _connectAdmin(),
          decoration: InputDecoration(
            labelText: 'التوكن (Personal access token)',
            hintText: 'github_pat_…',
            suffixIcon: IconButton(
              tooltip: _hide ? 'إظهار' : 'إخفاء',
              icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined),
              onPressed: () => setState(() => _hide = !_hide),
            ),
          ),
        ),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text('إعدادات إضافية', style: TextStyle(color: c.muted, fontSize: 14)),
            children: [
              TextField(
                controller: _branch,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(labelText: 'الفرع (branch)'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ];
}
