import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// خطأ مفهوم من GitHub مع رسالة بالعربي.
class GitHubException implements Exception {
  final int status;
  final String message;
  GitHubException(this.status, this.message);

  bool get isConflict => status == 409 || status == 422;

  @override
  String toString() => message;
}

/// ملف من الـ repo مع الـ sha مالته (نحتاجه للتعديل والحذف).
class RepoFile {
  final String path;
  final String sha;
  final Uint8List bytes;
  RepoFile(this.path, this.sha, this.bytes);
}

/// تعامل بسيط مع GitHub Contents API.
/// كل البيانات (memories.json والصور) تنحفظ بـ repo خاص.
class GitHubApi {
  final String owner;
  final String repo;
  final String branch;
  final String token;

  GitHubApi({
    required this.owner,
    required this.repo,
    required this.token,
    this.branch = 'main',
  });

  Map<String, String> _headers({bool raw = false}) => {
        'Authorization': 'Bearer $token',
        'Accept': raw ? 'application/vnd.github.raw+json' : 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
      };

  Uri _contents(String path, {bool withRef = true}) => Uri.https(
        'api.github.com',
        '/repos/$owner/$repo/contents/${_encodePath(path)}',
        withRef ? {'ref': branch} : null,
      );

  static String _encodePath(String path) =>
      path.split('/').map(Uri.encodeComponent).join('/');

  GitHubException _error(http.Response r) {
    String msg;
    switch (r.statusCode) {
      case 401:
        msg = 'التوكن غلط أو منتهي. سوّي توكن جديد من إعدادات GitHub.';
        break;
      case 403:
        msg = r.headers['x-ratelimit-remaining'] == '0'
            ? 'وصلت حد الطلبات على GitHub، انتظر شوية وجرب.'
            : 'التوكن ما عنده صلاحية على هذا الـ repo. تأكد من صلاحية Contents: Read and write.';
        break;
      case 404:
        msg = 'ما لگيت الـ repo أو الملف. تأكد من اسم الحساب واسم الـ repo والفرع.';
        break;
      case 409:
      case 422:
        msg = 'صار تعديل بنفس الوقت من جهاز ثاني، عيد المحاولة.';
        break;
      default:
        msg = 'خطأ من GitHub (${r.statusCode}).';
    }
    return GitHubException(r.statusCode, msg);
  }

  /// يتأكد إن الـ repo موجود والتوكن يشتغل.
  Future<void> checkAccess() async {
    final r = await http.get(
      Uri.https('api.github.com', '/repos/$owner/$repo'),
      headers: _headers(),
    );
    if (r.statusCode != 200) throw _error(r);
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    final perms = (j['permissions'] as Map?) ?? {};
    if (perms['push'] != true) {
      throw GitHubException(403, 'التوكن يقرأ بس وما يگدر يكتب. فعّل صلاحية Contents: Read and write.');
    }
  }

  /// يجيب ملف. يرجع null إذا الملف مو موجود.
  Future<RepoFile?> getFile(String path) async {
    final r = await http.get(_contents(path), headers: _headers());
    if (r.statusCode == 404) return null;
    if (r.statusCode != 200) throw _error(r);
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    final sha = j['sha'] as String;
    final content = (j['content'] as String?) ?? '';
    if (content.isNotEmpty && j['encoding'] == 'base64') {
      return RepoFile(path, sha, base64Decode(content.replaceAll('\n', '')));
    }
    // ملفات أكبر من 1MB: نجيبها raw
    final bytes = await getRaw(path);
    return RepoFile(path, sha, bytes);
  }

  /// يجيب محتوى الملف كبايتات (للصور).
  Future<Uint8List> getRaw(String path) async {
    final r = await http.get(_contents(path), headers: _headers(raw: true));
    if (r.statusCode != 200) throw _error(r);
    return r.bodyBytes;
  }

  /// ينشئ أو يحدّث ملف. يرجع الـ sha الجديد.
  Future<String> putFile(String path, Uint8List bytes,
      {String? sha, required String message}) async {
    final body = <String, dynamic>{
      'message': message,
      'content': base64Encode(bytes),
      'branch': branch,
      if (sha != null) 'sha': sha,
    };
    final r = await http.put(
      _contents(path, withRef: false),
      headers: {..._headers(), 'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (r.statusCode != 200 && r.statusCode != 201) throw _error(r);
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    return (j['content'] as Map<String, dynamic>)['sha'] as String;
  }

  /// يحذف ملف (يجيب الـ sha أول إذا ما معروف).
  Future<void> deleteFile(String path, {String? sha, required String message}) async {
    sha ??= await _shaOf(path);
    if (sha == null) return; // أصلاً مو موجود
    final r = await http.delete(
      _contents(path, withRef: false),
      headers: {..._headers(), 'Content-Type': 'application/json'},
      body: jsonEncode({'message': message, 'sha': sha, 'branch': branch}),
    );
    if (r.statusCode != 200 && r.statusCode != 404) throw _error(r);
  }

  Future<String?> _shaOf(String path) async {
    final r = await http.get(_contents(path), headers: _headers());
    if (r.statusCode == 404) return null;
    if (r.statusCode != 200) throw _error(r);
    return (jsonDecode(r.body) as Map<String, dynamic>)['sha'] as String;
  }
}
