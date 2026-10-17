import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../models.dart';
import 'github_api.dart';

const _dataPath = 'memories.json';

/// يدير الذكريات: يقرأ ويكتب memories.json ويرفع الصور للـ repo.
class MemoryStore extends ChangeNotifier {
  final GitHubApi api;
  MemoryStore(this.api);

  MemoryBook book = const MemoryBook();
  String? _sha;
  bool loading = true;
  String? error;

  final Map<String, Future<Uint8List>> _photoCache = {};

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      await _fetch();
    } catch (e) {
      error = e.toString();
    }
    loading = false;
    notifyListeners();
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
      final path = 'photos/${memory.date.year}/${memory.id}-${_rand()}.${p.ext}';
      await api.putFile(path, p.bytes, message: 'صورة: ${memory.title}');
      _photoCache[path] = Future.value(p.bytes);
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
      _photoCache.remove(path);
    } catch (_) {
      // مو مشكلة إذا فشل حذف صورة، الذكرى نفسها انحفظت
    }
  }

  /// يجيب الصورة من الـ repo الخاص (مع كاش بالذاكرة).
  Future<Uint8List> photo(String path) =>
      _photoCache.putIfAbsent(path, () => api.getRaw(path).catchError((Object e) {
            _photoCache.remove(path);
            throw e;
          }));

  static String newId() =>
      '${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}${_rand()}';

  static String _rand() {
    final r = Random();
    return List.generate(4, (_) => 'abcdefghijklmnopqrstuvwxyz0123456789'[r.nextInt(36)]).join();
  }
}
