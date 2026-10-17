import 'dart:async';
import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// يصغّر الصورة بالمتصفح نفسه (canvas)، سريع حتى للصور الكبيرة.
/// [maxSide] أطول ضلع بالبكسل. يرجع JPEG.
/// إذا صار أي خطأ يرجع الصورة الأصلية بدون تغيير.
Future<Uint8List> shrinkImage(Uint8List bytes, {int maxSide = 2000, double quality = .85}) async {
  try {
    // HEIC ما ينفتح بالمتصفح؛ يترفع مثل ما هو وGitHub يحوله تلقائياً لـ JPG
    if (isHeic(bytes)) return bytes;
    final blob = web.Blob([bytes.toJS].toJS);
    final bmp = await web.window.createImageBitmap(blob).toDart;
    final w0 = bmp.width, h0 = bmp.height;
    final scale = math.min(1.0, maxSide / math.max(w0, h0));
    final w = math.max(1, (w0 * scale).round());
    final h = math.max(1, (h0 * scale).round());

    final canvas = web.HTMLCanvasElement()
      ..width = w
      ..height = h;
    final ctx = canvas.getContext('2d') as web.CanvasRenderingContext2D;
    ctx.imageSmoothingQuality = 'high';
    ctx.drawImage(bmp, 0, 0, w, h);
    bmp.close();

    final done = Completer<web.Blob?>();
    canvas.toBlob(
      ((web.Blob? b) => done.complete(b)).toJS,
      'image/jpeg',
      quality.toJS,
    );
    final out = await done.future;
    if (out == null) return bytes;
    final buf = await out.arrayBuffer().toDart;
    final result = buf.toDart.asUint8List();
    // إذا الأصلية أصغر (صورة صغيرة أصلاً)، نخليها
    return result.length < bytes.length ? result : bytes;
  } catch (_) {
    return bytes;
  }
}

/// صور الآيفون (HEIC) ما تنعرض بمتصفح Chrome، فنحولها لـ JPG.
bool isHeic(Uint8List b) {
  if (b.length < 12) return false;
  final ftyp = String.fromCharCodes(b.sublist(4, 8));
  if (ftyp != 'ftyp') return false;
  final brand = String.fromCharCodes(b.sublist(8, 12));
  return const {'heic', 'heix', 'hevc', 'hevx', 'heim', 'heis', 'mif1', 'msf1'}.contains(brand);
}
