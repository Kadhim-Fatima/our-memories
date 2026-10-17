import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// كاش دائم للصور داخل المتصفح (Cache Storage).
/// الصورة تنجاب من GitHub مرة وحدة، وبعدها تطلع من الجهاز مباشرة حتى لو سكّرت الموقع.
/// ملفات الصور ما تتغير أبداً (كل صورة إلها اسم جديد)، فالكاش ما يحتاج تحديث.
class PhotoCache {
  static const _name = 'our-memories-photos-v1';
  static Future<web.Cache?>? _open;

  static Future<web.Cache?> _cache() => _open ??= () async {
        try {
          return await web.window.caches.open(_name).toDart;
        } catch (_) {
          return null; // متصفح ما يدعم الكاش (مثلاً وضع التصفح الخفي)
        }
      }();

  static String _key(String path, String variant) =>
      'https://cache.our-memories.local/$variant/${Uri.encodeComponent(path)}';

  static Future<Uint8List?> get(String path, String variant) async {
    try {
      final c = await _cache();
      if (c == null) return null;
      final r = await c.match(_key(path, variant).toJS).toDart;
      if (r == null) return null;
      final buf = await (r as web.Response).arrayBuffer().toDart;
      return buf.toDart.asUint8List();
    } catch (_) {
      return null;
    }
  }

  static Future<void> put(String path, String variant, Uint8List bytes) async {
    try {
      final c = await _cache();
      if (c == null) return;
      final body = web.Blob([bytes.toJS].toJS);
      await c.put(_key(path, variant).toJS, web.Response(body)).toDart;
    } catch (_) {
      // الكاش مو ضروري، إذا فشل نكمل عادي
    }
  }

  static Future<void> remove(String path) async {
    try {
      final c = await _cache();
      if (c == null) return;
      for (final v in ['thumb', 'full']) {
        await c.delete(_key(path, v).toJS).toDart;
      }
    } catch (_) {}
  }
}
