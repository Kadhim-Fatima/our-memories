import 'package:flutter/material.dart';

import '../services/github_api.dart';
import '../services/settings.dart';
import '../services/viewer_access.dart';
import '../theme.dart';

/// منصة التحكم: تحديد أو تغيير كلمة سر المشاهدة.
class ViewerPasswordDialog extends StatefulWidget {
  final RepoSettings settings;
  final String siteOwner;
  final String siteRepo;
  const ViewerPasswordDialog({required this.settings, required this.siteOwner, required this.siteRepo});

  @override
  State<ViewerPasswordDialog> createState() => ViewerPasswordDialogState();
}

class ViewerPasswordDialogState extends State<ViewerPasswordDialog> {
  final _pw = TextEditingController();
  final _pw2 = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _pw.dispose();
    _pw2.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final pw = _pw.text;
    if (pw.isEmpty) {
      setState(() => _error = 'اكتب كلمة السر.');
      return;
    }
    if (pw.length < 6) {
      setState(() => _error = 'خلي كلمة السر ٦ حروف أو أكثر.');
      return;
    }
    if (pw != _pw2.text) {
      setState(() => _error = 'كلمتين السر مو متطابقات.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final s = widget.settings;
    try {
      // المشاهد يدخل بنفس الوصول، بس الموقع يفتحله وضع المشاهدة (بدون تعديل)
      final cfg = await ViewerAccess.encrypt(
        {'owner': s.owner, 'repo': s.repo, 'branch': s.branch, 'token': s.token},
        pw,
      );
      try {
        await ViewerAccess.publish(
          adminToken: s.token,
          siteOwner: widget.siteOwner,
          siteRepo: widget.siteRepo,
          config: cfg,
        );
      } on GitHubException catch (e) {
        if (e.status == 403 || e.status == 404) {
          throw GitHubException(e.status,
              'التوكن مالتك ما عنده صلاحية على repo الموقع (${widget.siteRepo}). ضيفه للتوكن من إعدادات GitHub بصلاحية Contents: Read and write.');
        }
        rethrow;
      }
      if (mounted) Navigator.pop(context, true);
    } on GitHubException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'ما انحفظت، تأكد من الإنترنت وجرب مرة ثانية.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return AlertDialog(
      title: Text('كلمة سر المشاهدة', style: displayFont(size: 26, color: c.accent)),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'اللي يدخل بكلمة السر يشوف الذكريات والصور بس، بدون إضافة أو تعديل أو حذف. إذا حفظت كلمة سر جديدة، القديمة تبطل.',
                style: TextStyle(color: c.muted, fontSize: 14, height: 1.6),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _pw,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'كلمة السر الجديدة'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _pw2,
                obscureText: true,
                onSubmitted: (_) => _save(),
                decoration: const InputDecoration(labelText: 'أعد كتابة كلمة السر'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: TextStyle(color: c.danger, fontSize: 14)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('حفظ'),
        ),
      ],
    );
  }
}
