import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:http/http.dart' as http;

import 'github_api.dart';

/// دخول المشاهد بكلمة سر.
///
/// الفكرة: الأدمن يسوي توكن "قراءة فقط" ويختار كلمة سر. الموقع يشفّر
/// التوكن بكلمة السر (PBKDF2 + AES-GCM) ويحفظه بملف web/viewer.json
/// بـ repo الموقع. المشاهد يكتب كلمة السر، والموقع يفك التشفير بالمتصفح.
/// بدون كلمة السر الصحيحة الملف ما يفيد أحد.
class ViewerAccess {
  static const _iterations = 200000;
  static const fileInSiteRepo = 'web/viewer.json';

  /// repo الموقع، يطلع من رابط الصفحة:
  /// https://OWNER.github.io/REPO/  ←  (OWNER, REPO)
  static (String, String)? siteRepo() {
    final host = Uri.base.host;
    if (!host.endsWith('.github.io')) return null;
    final owner = host.substring(0, host.length - '.github.io'.length);
    final segs = Uri.base.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segs.isEmpty) return (owner, '$owner.github.io');
    return (owner, segs.first);
  }

  static Uri _configUrl() {
    final b = Uri.base;
    final segs = b.pathSegments.where((s) => s.isNotEmpty).toList();
    final prefix = (b.host.endsWith('.github.io') && segs.isNotEmpty) ? '/${segs.first}' : '';
    return Uri(
      scheme: b.scheme,
      host: b.host,
      port: b.hasPort ? b.port : null,
      path: '$prefix/viewer.json',
      queryParameters: {'t': DateTime.now().millisecondsSinceEpoch.toString()},
    );
  }

  /// يجيب ملف المشاهد المشفّر من الموقع. null إذا بعد ما انعمل.
  static Future<Map<String, dynamic>?> fetchConfig() async {
    try {
      final r = await http.get(_configUrl());
      if (r.statusCode != 200) return null;
      final j = jsonDecode(utf8.decode(r.bodyBytes));
      return j is Map<String, dynamic> && j['ct'] != null ? j : null;
    } catch (_) {
      return null;
    }
  }

  static Future<SecretKey> _key(String password, List<int> salt, int iterations) =>
      Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: iterations, bits: 256)
          .deriveKeyFromPassword(password: password, nonce: salt);

  static List<int> _random(int n) {
    final r = Random.secure();
    return List<int>.generate(n, (_) => r.nextInt(256));
  }

  /// يشفّر معلومات الدخول بكلمة السر.
  static Future<Map<String, dynamic>> encrypt(Map<String, dynamic> payload, String password) async {
    final salt = _random(16);
    final nonce = _random(12);
    final key = await _key(password, salt, _iterations);
    final box = await AesGcm.with256bits().encrypt(
      utf8.encode(jsonEncode(payload)),
      secretKey: key,
      nonce: nonce,
    );
    return {
      'v': 1,
      'kdf': 'pbkdf2-sha256',
      'iter': _iterations,
      'salt': base64Encode(salt),
      'nonce': base64Encode(nonce),
      'ct': base64Encode(box.cipherText),
      'mac': base64Encode(box.mac.bytes),
    };
  }

  /// يفك التشفير. يرجع null إذا كلمة السر غلط.
  static Future<Map<String, dynamic>?> decrypt(Map<String, dynamic> cfg, String password) async {
    try {
      final key = await _key(password, base64Decode(cfg['salt'] as String), (cfg['iter'] as num).toInt());
      final clear = await AesGcm.with256bits().decrypt(
        SecretBox(
          base64Decode(cfg['ct'] as String),
          nonce: base64Decode(cfg['nonce'] as String),
          mac: Mac(base64Decode(cfg['mac'] as String)),
        ),
        secretKey: key,
      );
      return jsonDecode(utf8.decode(clear)) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// يحفظ ملف المشاهد بـ repo الموقع (يحتاج توكن الأدمن عنده صلاحية على repo الموقع).
  /// بعد الحفظ GitHub يعيد بناء الموقع تلقائياً (تقريباً دقيقتين).
  static Future<void> publish({
    required String adminToken,
    required String siteOwner,
    required String siteRepo,
    required Map<String, dynamic> config,
  }) async {
    final api = GitHubApi(owner: siteOwner, repo: siteRepo, token: adminToken);
    final existing = await api.getFile(fileInSiteRepo);
    await api.putFile(
      fileInSiteRepo,
      Uint8List.fromList(utf8.encode(const JsonEncoder.withIndent('  ').convert(config))),
      sha: existing?.sha,
      message: 'تحديث كلمة سر المشاهدة',
    );
  }
}
