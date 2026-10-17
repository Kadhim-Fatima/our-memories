import 'package:flutter/material.dart';

import '../services/github_api.dart';
import '../services/settings.dart';
import '../theme.dart';

/// شاشة الدخول: تربط الموقع بالـ repo الخاص اللي بيه الذكريات.
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
  bool _busy = false;
  bool _hide = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    RepoSettings.lastRepo().then((v) {
      if (!mounted) return;
      if (_owner.text.isEmpty) _owner.text = v.$1;
      if (_repo.text.isEmpty) _repo.text = v.$2;
      _branch.text = v.$3;
    });
  }

  @override
  void dispose() {
    _owner.dispose();
    _repo.dispose();
    _branch.dispose();
    _token.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
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
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await GitHubApi(owner: s.owner, repo: s.repo, branch: s.branch, token: s.token).checkAccess();
      await s.save();
      widget.onConnected(s);
    } on GitHubException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'ما گدرت أتصل بـ GitHub. تأكد من الإنترنت.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
              child: AutofillGroup(
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
                      'الذكريات والصور محفوظة بـ repo خاص على GitHub. اكتبوا معلوماته مرة وحدة وتنحفظ بهذا المتصفح.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: c.muted, height: 1.6),
                    ),
                    const SizedBox(height: 28),
                    TextField(
                      controller: _owner,
                      textDirection: TextDirection.ltr,
                      decoration: const InputDecoration(labelText: 'اسم حساب GitHub'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _repo,
                      textDirection: TextDirection.ltr,
                      decoration: const InputDecoration(
                          labelText: 'اسم الـ repo الخاص', hintText: 'our-memories-data'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _token,
                      obscureText: _hide,
                      textDirection: TextDirection.ltr,
                      autofillHints: const [AutofillHints.password],
                      onSubmitted: (_) => _connect(),
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
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(_error!, style: TextStyle(color: c.danger)),
                      ),
                    FilledButton(
                      onPressed: _busy ? null : _connect,
                      child: _busy
                          ? const SizedBox(
                              width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('ادخل'),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'التوكن ينحفظ بهذا المتصفح بس. لا تدخل من جهاز مو إلك، ولا ترسل التوكن لأي أحد.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: c.muted, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
