import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart';
import 'github_api.dart';
import 'image_tools.dart';
import 'photo_cache.dart';

const _dataPath = 'memories.json';
const _bookCacheKey = 'book_cache_v1';

/// يدير الذكريات: يقرأ ويكتب memories.json ويرفع الصور للـ repo.
class MemoryStore extends ChangeNotifier {
  final GitHubApi api;
  final bool canWrite;
  MemoryStore(this.api, {this.canWrite = false});

  MemoryBook book = const MemoryBook();
  String? _sha;
  bool loading = true;
  String? error;

  /// يفتح الذكريات المحفوظة بالجهاز فوراً، وبنفس الوقت يجيب الأحدث من GitHub.
  Future<void> load() async {
    error = null;
    var hadCache = false;
    if (book.memories.isEmpty) {
      try {
        final p = await SharedPreferences.getInstance();
        final cached = p.getString(_bookCacheKey);
        if (cached != null) {
          book = MemoryBook.fromJson(jsonDecode(cached) as Map<String, dynamic>);
          hadCache = true;
        }
      } catch (_) {}
    } else {
      hadCache = true;
    }
    loading = !hadCache;
    notifyListeners();
    try {
      await _fetch();
    } catch (e) {
      // إذا عندنا نسخة محفوظة نخليها ونسكت، حتى بدون إنترنت تنعرض الذكريات
      if (!hadCache) error = e.toString();
    }
    loading = false;
    notifyListeners();
  }

  Future<void> _saveBookCache() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_bookCacheKey, jsonEncode(book.toJson()));
    } catch (_) {}
  }

  Future<void> _fetch() async {
    final f = await api.getFile(_dataPath);
    if (f == null) {
      book = const MemoryBook();
      _sha = null;
    } else {
      book = MemoryBook.fromJson(jsonDecode(utf8.decode(f.bytes)) as Map<String, dynamic>);
      _sha = f.sha;
    }
    await _saveBookCache();
  }

  /// يطبق تعديل على أحدث نسخة من الملف ويحفظ.
  /// إذا جهاز ثاني عدّل بنفس الوقت، يجيب النسخة الجديدة ويعيد التعديل عليها.
  Future<void> _mutate(MemoryBook Function(MemoryBook) change, String message) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      final next = change(book);
      final bytes = Uint8List.fromList(
          utf8.encode(const JsonEncoder.withIndent('  ').convert(next.toJson())));
      try {
        _sha = await api.putFile(_dataPath, bytes, sha: _sha, message: message);
        book = next;
        notifyListeners();
        await _saveBookCache();
        return;
      } on GitHubException catch (e) {
        if (!e.isConflict || attempt == 2) rethrow;
        await _fetch();
      }
    }
  }

  Future<void> saveCouple(Couple c) =>
      _mutate((b) => MemoryBook(couple: c, memories: b.memories), 'تحديث معلوماتنا');

  /// يحفظ ذكرى (جديدة أو تعديل). [newPhotos] صور جديدة لازم تنرفع.
  /// [onProgress] يبلغ الواجهة بتقدم الرفع.
  Future<void> saveMemory(
    Memory memory, {
    List<({Uint8List bytes, String ext})> newPhotos = const [],
    void Function(int done, int total)? onProgress,
  }) async {
    final uploaded = <String>[];
    for (var i = 0; i < newPhotos.length; i++) {
      onProgress?.call(i, newPhotos.length);
      final p = newPhotos[i];
      // تصغير لحد ٢٠٠٠ بكسل قبل الرفع (صورة الموبايل ٨ ميگا تصير تقريباً ٤٠٠ كيلو)
      final full = p.ext == 'gif' ? p.bytes : await shrinkImage(p.bytes, maxSide: 2000);
      final ext = p.ext == 'gif' ? 'gif' : 'jpg';
      final path = 'photos/${memory.date.year}/${memory.id}-${_rand()}.$ext';
      await api.putFile(path, full, message: 'صورة: ${memory.title}');
      if (!isHeic(full)) {
        _remember(path, 'full', full);
        PhotoCache.put(path, 'full', full);
      }
      uploaded.add(path);
    }
    onProgress?.call(newPhotos.length, newPhotos.length);

    final full = memory.copyWith(photos: [...memory.photos, ...uploaded]);
    Memory? old;
    for (final m in book.memories) {
      if (m.id == memory.id) old = m;
    }
    await _mutate((b) {
      final list = b.memories.where((m) => m.id != memory.id).toList()..add(full);
      return MemoryBook(couple: b.couple, memories: list);
    }, old == null ? 'ذكرى جديدة: ${memory.title}' : 'تعديل: ${memory.title}');

    // الصور اللي انشالت من الذكرى نحذفها من الـ repo
    if (old != null) {
      for (final p in old.photos.where((p) => !full.photos.contains(p))) {
        await _safeDelete(p);
      }
    }
  }

  Future<void> deleteMemory(Memory m) async {
    await _mutate((b) => MemoryBook(
          couple: b.couple,
          memories: b.memories.where((x) => x.id != m.id).toList(),
        ), 'حذف: ${m.title}');
    for (final p in m.photos) {
      await _safeDelete(p);
    }
  }

  Future<void> _safeDelete(String path) async {
    try {
      await api.deleteFile(path, message: 'حذف صورة');
      _mem.removeWhere((k, _) => k.endsWith(':$path'));
      _loading.removeWhere((k, _) => k.endsWith(':$path'));
      PhotoCache.remove(path);
    } catch (_) {
      // مو مشكلة إذا فشل حذف صورة، الذكرى نفسها انحفظت
    }
  }

  /// الصور بثلاث طبقات كاش:
  /// ١. الذاكرة (فوري)  ٢. الجهاز (Cache Storage، يبقى بعد ما تسكّر)  ٣. GitHub (أول مرة بس)
  /// [thumb] نسخة صغيرة (٧٠٠ بكسل) للبطاقات، أخف وأسرع بكثير من الصورة الكاملة.
  Future<Uint8List> photo(String path, {bool thumb = false}) {
    final variant = thumb ? 'thumb' : 'full';
    final key = '$variant:$path';
    final ready = _mem[key];
    if (ready != null) return Future.value(ready);
    return _loading.putIfAbsent(key, () async {
      try {
        var bytes = await PhotoCache.get(path, variant);
        if (bytes != null && isHeic(bytes)) bytes = null; // نسخة قديمة غلط بالكاش
        if (bytes == null) {
          if (thumb) {
            final full = await photo(path);
            bytes = await shrinkImage(full, maxSide: 700, quality: .82);
          } else {
            bytes = await api.getRaw(path);
          }
          // صورة HEIC بعدها ما تحولت (GitHub يحولها خلال دقيقة): ما نخزنها
          if (isHeic(bytes)) throw const PhotoNotReady();
          PhotoCache.put(path, variant, bytes);
        }
        _remember(path, variant, bytes);
        return bytes;
      } finally {
        _loading.remove(key);
      }
    });
  }

  /// الصورة إذا موجودة بالذاكرة (حتى تطلع فوراً بدون وميض).
  Uint8List? cachedPhoto(String path, {bool thumb = false}) =>
      _mem['${thumb ? 'thumb' : 'full'}:$path'] ?? (thumb ? _mem['full:$path'] : null);

  void _remember(String path, String variant, Uint8List bytes) => _mem['$variant:$path'] = bytes;

  final Map<String, Uint8List> _mem = {};
  final Map<String, Future<Uint8List>> _loading = {};

  static String newId() =>
      '${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}${_rand()}';

  static String _rand() {
    final r = Random();
    return List.generate(4, (_) => 'abcdefghijklmnopqrstuvwxyz0123456789'[r.nextInt(36)]).join();
  }
}

/// الصورة بعدها تتحول من HEIC (يصير تلقائياً على GitHub خلال دقيقة).
class PhotoNotReady implements Exception {
  const PhotoNotReady();
}
