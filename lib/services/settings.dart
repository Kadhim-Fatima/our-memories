import 'package:shared_preferences/shared_preferences.dart';

/// إعدادات الاتصال بالـ repo الخاص. تنحفظ بالمتصفح فقط (localStorage)،
/// يعني التوكن ما يطلع للإنترنت ولا ينحفظ بالكود.
class RepoSettings {
  final String owner;
  final String repo;
  final String branch;
  final String token;
  /// true = مشاهد (يشوف بس)، false = أدمن (يضيف ويعدل)
  final bool viewer;

  const RepoSettings({
    required this.owner,
    required this.repo,
    required this.token,
    this.branch = 'main',
    this.viewer = false,
  });

  static const _kOwner = 'gh_owner', _kRepo = 'gh_repo', _kBranch = 'gh_branch', _kToken = 'gh_token', _kViewer = 'gh_viewer';

  static Future<RepoSettings?> load() async {
    final p = await SharedPreferences.getInstance();
    final owner = p.getString(_kOwner), repo = p.getString(_kRepo), token = p.getString(_kToken);
    if (owner == null || repo == null || token == null || token.isEmpty) return null;
    return RepoSettings(
        owner: owner,
        repo: repo,
        token: token,
        branch: p.getString(_kBranch) ?? 'main',
        viewer: p.getBool(_kViewer) ?? false);
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kOwner, owner);
    await p.setString(_kRepo, repo);
    await p.setString(_kBranch, branch);
    await p.setString(_kToken, token);
    await p.setBool(_kViewer, viewer);
  }

  static Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kToken);
    await p.remove(_kViewer);
  }

  /// آخر اسم حساب وrepo (حتى ما تنكتب مرة ثانية بعد تسجيل الخروج).
  static Future<(String, String, String)> lastRepo() async {
    final p = await SharedPreferences.getInstance();
    return (p.getString(_kOwner) ?? '', p.getString(_kRepo) ?? '', p.getString(_kBranch) ?? 'main');
  }
}
