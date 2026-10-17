import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// يصغّر الصورة بالمتصفح نفسه (canvas)، سريع حتى للصور الكبيرة.
/// [maxSide] أطول ضلع بالبكسل. يرجع JPEG.
/// إذا صار أي خطأ يرجع الصورة الأصلية بدون تغيير.
Future<Uint8List> shrinkImage(Uint8List bytes, {int maxSide = 2000, double quality = .85}) async {
  try {
    if (isHeic(bytes)) bytes = await heicToJpeg(bytes);
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

@JS('heic2any')
external JSPromise<JSAny> _heic2any(JSObject options);

Future<void>? _heicLib;

/// مكتبة التحويل تنحمّل بس أول مرة نحتاجها.
Future<void> _loadHeicLib() => _heicLib ??= () {
      final done = Completer<void>();
      final script = web.HTMLScriptElement()
        ..src = 'https://cdn.jsdelivr.net/npm/heic2any@0.0.4/dist/heic2any.min.js';
      script.onload = ((web.Event _) => done.complete()).toJS;
      script.onerror = ((web.Event _) {
        _heicLib = null;
        done.completeError(StateError('heic2any failed to load'));
      }).toJS;
      web.document.head!.appendChild(script);
      return done.future;
    }();

/// يحوّل HEIC إلى JPEG. إذا فشل يرجع الأصلية.
Future<Uint8List> heicToJpeg(Uint8List bytes, {double quality = .9}) async {
  try {
    await _loadHeicLib();
    final opts = JSObject()
      ..setProperty('blob'.toJS, web.Blob([bytes.toJS].toJS))
      ..setProperty('toType'.toJS, 'image/jpeg'.toJS)
      ..setProperty('quality'.toJS, quality.toJS);
    final res = await _heic2any(opts).toDart;
    final web.Blob blob =
        res.instanceOfString('Array') ? (res as JSArray<web.Blob>).toDart.first : res as web.Blob;
    final buf = await blob.arrayBuffer().toDart;
    return buf.toDart.asUint8List();
  } catch (_) {
    return bytes;
  }
}
