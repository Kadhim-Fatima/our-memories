/// معلوماتكم: الأسماء وتاريخ الخطوبة.
class Couple {
  final String name1;
  final String name2;
  final DateTime? since;

  const Couple({this.name1 = '', this.name2 = '', this.since});

  factory Couple.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const Couple();
    return Couple(
      name1: (j['name1'] as String?) ?? '',
      name2: (j['name2'] as String?) ?? '',
      since: parseDate(j['since'] as String?),
    );
  }

  Map<String, dynamic> toJson() => {
        'name1': name1,
        'name2': name2,
        'since': since == null ? null : formatDate(since!),
      };
}

/// ذكرى وحدة.
class Memory {
  final String id;
  final String title;
  final DateTime date;
  final String place;
  final String story;
  final String tag;
  /// مسارات الصور داخل الـ repo، مثل photos/2026/abc.jpg
  final List<String> photos;
  final DateTime createdAt;

  const Memory({
    required this.id,
    required this.title,
    required this.date,
    this.place = '',
    this.story = '',
    this.tag = '',
    this.photos = const [],
    required this.createdAt,
  });

  factory Memory.fromJson(Map<String, dynamic> j) => Memory(
        id: j['id'] as String,
        title: (j['title'] as String?) ?? '',
        date: parseDate(j['date'] as String?) ?? DateTime.now(),
        place: (j['place'] as String?) ?? '',
        story: (j['story'] as String?) ?? '',
        tag: (j['tag'] as String?) ?? '',
        photos: ((j['photos'] as List?) ?? const []).cast<String>(),
        createdAt: DateTime.tryParse((j['createdAt'] as String?) ?? '') ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'date': formatDate(date),
        'place': place,
        'story': story,
        'tag': tag,
        'photos': photos,
        'createdAt': createdAt.toUtc().toIso8601String(),
      };

  Memory copyWith({
    String? title,
    DateTime? date,
    String? place,
    String? story,
    String? tag,
    List<String>? photos,
  }) =>
      Memory(
        id: id,
        title: title ?? this.title,
        date: date ?? this.date,
        place: place ?? this.place,
        story: story ?? this.story,
        tag: tag ?? this.tag,
        photos: photos ?? this.photos,
        createdAt: createdAt,
      );
}

/// كل محتوى ملف memories.json
class MemoryBook {
  final Couple couple;
  final List<Memory> memories;

  const MemoryBook({this.couple = const Couple(), this.memories = const []});

  factory MemoryBook.fromJson(Map<String, dynamic> j) => MemoryBook(
        couple: Couple.fromJson(j['couple'] as Map<String, dynamic>?),
        memories: ((j['memories'] as List?) ?? const [])
            .map((e) => Memory.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'version': 1,
        'couple': couple.toJson(),
        'memories': memories.map((m) => m.toJson()).toList(),
      };

  /// الذكريات من الأحدث للأقدم.
  List<Memory> get sorted {
    final l = [...memories];
    l.sort((a, b) {
      final c = b.date.compareTo(a.date);
      return c != 0 ? c : b.createdAt.compareTo(a.createdAt);
    });
    return l;
  }
}

const memoryTags = ['يوم عادي', 'طلعة', 'سفرة', 'مناسبة', 'أول مرة', 'هدية'];

DateTime? parseDate(String? s) {
  if (s == null || s.isEmpty) return null;
  final p = s.split('-');
  if (p.length != 3) return DateTime.tryParse(s);
  final y = int.tryParse(p[0]), m = int.tryParse(p[1]), d = int.tryParse(p[2]);
  if (y == null || m == null || d == null) return null;
  return DateTime(y, m, d);
}

String formatDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
