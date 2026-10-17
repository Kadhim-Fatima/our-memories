import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../services/github_api.dart';
import '../services/memory_store.dart';
import '../theme.dart';
import '../widgets/repo_image.dart';
import 'memory_form.dart';
import 'photo_viewer.dart';

class HomeScreen extends StatefulWidget {
  final MemoryStore store;
  final VoidCallback onLogout;
  const HomeScreen({super.key, required this.store, required this.onLogout});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0; // 0 الذكريات، 1 الألبوم

  MemoryStore get store => widget.store;

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _openForm([Memory? m]) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => MemoryForm(store: store, memory: m)),
    );
    if (ok == true && mounted) _snack(m == null ? 'انحفظت الذكرى 🤍' : 'انحفظ التعديل');
  }

  Future<void> _delete(Memory m) async {
    final c = AppColors.of(context);
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تحذف هذي الذكرى؟'),
        content: Text('"${m.title}" وصورها راح تنحذف من الـ repo.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('لا')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('إي احذف', style: TextStyle(color: c.danger)),
          ),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await store.deleteMemory(m);
      if (mounted) _snack('انحذفت الذكرى');
    } on GitHubException catch (e) {
      if (mounted) _snack(e.message);
    } catch (_) {
      if (mounted) _snack('ما انحذفت، جرب مرة ثانية.');
    }
  }

  Future<void> _editCouple() async {
    final cp = store.book.couple;
    final n1 = TextEditingController(text: cp.name1);
    final n2 = TextEditingController(text: cp.name2);
    DateTime? since = cp.since;
    final df = DateFormat.yMMMMd('ar');
    final result = await showDialog<Couple>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text('إحنا', style: displayFont(size: 28, color: AppColors.of(ctx).accent)),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: n1, decoration: const InputDecoration(labelText: 'اسمك')),
                const SizedBox(height: 10),
                TextField(controller: n2, decoration: const InputDecoration(labelText: 'اسم خطيبتك')),
                const SizedBox(height: 10),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: since ?? DateTime.now(),
                      firstDate: DateTime(1990),
                      lastDate: DateTime(2100),
                    );
                    if (d != null) setD(() => since = d);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'تاريخ الخطوبة'),
                    child: Text(since == null ? 'اختر التاريخ' : df.format(since!)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () => Navigator.pop(
                ctx,
                Couple(name1: n1.text.trim(), name2: n2.text.trim(), since: since),
              ),
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
    n1.dispose();
    n2.dispose();
    if (result == null) return;
    try {
      await store.saveCouple(result);
      if (mounted) _snack('انحفظ');
    } on GitHubException catch (e) {
      if (mounted) _snack(e.message);
    } catch (_) {
      if (mounted) _snack('ما انحفظ، جرب مرة ثانية.');
    }
  }

  List<PhotoRef> _allPhotos(List<Memory> sorted) => [
        for (final m in sorted)
          for (final p in m.photos) (path: p, memory: m),
      ];

  void _openViewer(List<PhotoRef> list, int i) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PhotoViewer(store: store, photos: list, initial: i)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final sorted = store.book.sorted;
        final photos = _allPhotos(sorted);
        return Scaffold(
          floatingActionButton: store.loading || store.error != null
              ? null
              : FloatingActionButton.extended(
                  onPressed: () => _openForm(),
                  backgroundColor: c.accent,
                  foregroundColor: c.surface,
                  icon: const Icon(Icons.add),
                  label: const Text('ذكرى جديدة'),
                ),
          body: RefreshIndicator(
            onRefresh: store.load,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _Hero(store: store, onEdit: _editCouple, onLogout: widget.onLogout)),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _TabsHeader(
                    color: c.bg,
                    line: c.line,
                    child: _Tabs(
                      tab: _tab,
                      memCount: sorted.length,
                      photoCount: photos.length,
                      onTab: (t) => setState(() => _tab = t),
                    ),
                  ),
                ),
                if (store.loading)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (store.error != null)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _Empty(
                      title: 'ما گدرت أجيب الذكريات',
                      body: store.error!,
                      action: FilledButton(onPressed: store.load, child: const Text('جرب مرة ثانية')),
                    ),
                  )
                else if (_tab == 0)
                  ..._timeline(sorted)
                else
                  _album(photos),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _timeline(List<Memory> sorted) {
    if (sorted.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _Empty(
            title: 'صفحتكم بعدها بيضاء',
            body: 'ابدأوا بأول ذكرى: يوم تعارفتوا، يوم الخطوبة، أو حتى طلعة الأسبوع الماضي.',
            action: FilledButton(onPressed: () => _openForm(), child: const Text('+ أضف أول ذكرى')),
          ),
        ),
      ];
    }
    final out = <Widget>[];
    int? year;
    final group = <Memory>[];
    void flush() {
      if (group.isEmpty) return;
      final y = year!;
      final items = List.of(group);
      out.add(SliverToBoxAdapter(child: _Constrain(child: _YearTitle(year: y))));
      out.add(SliverList.list(children: [
        for (final m in items)
          _Constrain(
            child: _MemoryTile(
              store: store,
              memory: m,
              onEdit: () => _openForm(m),
              onDelete: () => _delete(m),
              onPhoto: (i) => _openViewer([for (final p in m.photos) (path: p, memory: m)], i),
            ),
          ),
      ]));
      group.clear();
    }

    for (final m in sorted) {
      if (m.date.year != year) {
        flush();
        year = m.date.year;
      }
      group.add(m);
    }
    flush();
    return out;
  }

  Widget _album(List<PhotoRef> photos) {
    if (photos.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: _Empty(title: 'الألبوم فاضي', body: 'الصور اللي تضيفونها مع الذكريات تتجمع هنا.'),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverGrid.builder(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 180,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 4 / 5,
        ),
        itemCount: photos.length,
        itemBuilder: (_, i) => ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: () => _openViewer(photos, i),
            child: RepoImage(store: store, path: photos[i].path),
          ),
        ),
      ),
    );
  }
}

/* ---------------- أجزاء الواجهة ---------------- */

class _Constrain extends StatelessWidget {
  final Widget child;
  const _Constrain({required this.child});
  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: child),
        ),
      );
}

class _Hero extends StatelessWidget {
  final MemoryStore store;
  final VoidCallback onEdit;
  final VoidCallback onLogout;
  const _Hero({required this.store, required this.onEdit, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final cp = store.book.couple;
    final nf = NumberFormat.decimalPattern('ar');
    final df = DateFormat.yMMMMd('ar');

    Widget? sinceLine;
    Widget? countdown;
    final since = cp.since;
    if (since != null) {
      final today = DateUtils.dateOnly(DateTime.now());
      final days = today.difference(since).inDays;
      sinceLine = Text.rich(
        TextSpan(children: [
          const TextSpan(text: 'سوا من '),
          TextSpan(text: df.format(since), style: TextStyle(color: c.ink, fontWeight: FontWeight.w700)),
          const TextSpan(text: ' · '),
          TextSpan(
              text: nf.format(days < 0 ? 0 : days),
              style: TextStyle(color: c.ink, fontWeight: FontWeight.w700)),
          const TextSpan(text: ' يوم'),
        ]),
        textAlign: TextAlign.center,
        style: TextStyle(color: c.muted, fontSize: 15),
      );
      var next = DateTime(today.year, since.month, since.day);
      if (next.isBefore(today)) next = DateTime(today.year + 1, since.month, since.day);
      final left = next.difference(today).inDays;
      final years = next.year - since.year;
      if (years >= 1) {
        countdown = Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: c.surface,
            border: Border.all(color: c.line),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            left == 0
                ? 'اليوم ذكرى خطوبتكم 🤍'
                : 'باقي ${nf.format(left)} يوم على ذكرى خطوبتكم الـ${nf.format(years)}',
            style: TextStyle(color: c.muted, fontSize: 14),
          ),
        );
      }
    }

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          children: [
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: PopupMenuButton<String>(
                icon: Icon(Icons.more_horiz, color: c.muted),
                onSelected: (v) {
                  if (v == 'edit') onEdit();
                  if (v == 'refresh') store.load();
                  if (v == 'logout') onLogout();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('تعديل الأسماء والتاريخ')),
                  PopupMenuItem(value: 'refresh', child: Text('تحديث')),
                  PopupMenuItem(value: 'logout', child: Text('تسجيل خروج من هذا الجهاز')),
                ],
              ),
            ),
            Text('دفتر ذكرياتنا',
                style: TextStyle(color: c.gold, letterSpacing: 1, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(text: cp.name1.isEmpty ? 'أنا' : cp.name1),
                  TextSpan(
                    text: ' و ',
                    style: displayFont(size: 60, color: c.gold, weight: FontWeight.w400),
                  ),
                  TextSpan(text: cp.name2.isEmpty ? 'خطيبتي' : cp.name2),
                ]),
                style: displayFont(size: 64, color: c.accent),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 4),
            if (sinceLine != null)
              sinceLine
            else
              TextButton(
                onPressed: onEdit,
                child: Text('اكتبوا أسماءكم وتاريخ الخطوبة',
                    style: TextStyle(color: c.muted, decoration: TextDecoration.underline)),
              ),
            if (countdown != null) countdown,
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(width: 64, height: 1, color: c.gold.withAlpha(128)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('❦', style: TextStyle(color: c.gold, fontSize: 18)),
                ),
                Container(width: 64, height: 1, color: c.gold.withAlpha(128)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  final int tab;
  final int memCount;
  final int photoCount;
  final ValueChanged<int> onTab;
  const _Tabs({required this.tab, required this.memCount, required this.photoCount, required this.onTab});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final nf = NumberFormat.decimalPattern('ar');
    Widget pill(int i, String label, int n) {
      final sel = tab == i;
      return Padding(
        padding: const EdgeInsetsDirectional.only(end: 6),
        child: Material(
          color: sel ? c.accentSoft : Colors.transparent,
          shape: const StadiumBorder(),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: () => onTab(i),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Text(
                n > 0 ? '$label  ${nf.format(n)}' : label,
                style: TextStyle(color: sel ? c.accent : c.muted, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ),
      );
    }

    return _Constrain(
      child: Row(children: [pill(0, 'الذكريات', memCount), pill(1, 'الألبوم', photoCount)]),
    );
  }
}

class _TabsHeader extends SliverPersistentHeaderDelegate {
  final Widget child;
  final Color color;
  final Color line;
  _TabsHeader({required this.child, required this.color, required this.line});

  @override
  double get minExtent => 56;
  @override
  double get maxExtent => 56;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => Container(
        decoration: BoxDecoration(color: color, border: Border(bottom: BorderSide(color: line))),
        alignment: Alignment.center,
        child: child,
      );

  @override
  bool shouldRebuild(covariant _TabsHeader old) => true;
}

class _YearTitle extends StatelessWidget {
  final int year;
  const _YearTitle({required this.year});
  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 28, bottom: 6),
      child: Text(NumberFormat('####', 'ar').format(year), style: displayFont(size: 34, color: c.gold)),
    );
  }
}

class _MemoryTile extends StatelessWidget {
  final MemoryStore store;
  final Memory memory;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<int> onPhoto;
  const _MemoryTile({
    required this.store,
    required this.memory,
    required this.onEdit,
    required this.onDelete,
    required this.onPhoto,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final m = memory;
    final shown = m.photos.take(6).toList();
    // خط الزمن: حد جانبي على يمين المحتوى، ونقطة لكل ذكرى
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          margin: const EdgeInsetsDirectional.only(start: 11),
          padding: const EdgeInsetsDirectional.only(start: 22, bottom: 28),
          decoration: BoxDecoration(
            border: BorderDirectional(start: BorderSide(color: c.line)),
          ),
          child: SizedBox(
            width: double.infinity,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(DateFormat.MMMMd('ar').format(m.date),
                          style: TextStyle(color: c.accent, fontWeight: FontWeight.w700, fontSize: 14)),
                      if (m.place.isNotEmpty)
                        Text('📍 ${m.place}', style: TextStyle(color: c.muted, fontSize: 14)),
                      if (m.tag.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            border: Border.all(color: c.line),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(m.tag, style: TextStyle(color: c.muted, fontSize: 13)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(m.title.isEmpty ? 'بدون عنوان' : m.title,
                      style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700, height: 1.4)),
                  if (m.story.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 620),
                      child: Text(m.story, style: const TextStyle(fontSize: 16, height: 1.75)),
                    ),
                  ],
                  if (shown.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: GridView.extent(
                        maxCrossAxisExtent: 120,
                        mainAxisSpacing: 6,
                        crossAxisSpacing: 6,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          for (var i = 0; i < shown.length; i++)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: InkWell(
                                onTap: () => onPhoto(i),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    RepoImage(store: store, path: shown[i]),
                                    if (i == 5 && m.photos.length > 6)
                                      Container(
                                        color: Colors.black45,
                                        alignment: Alignment.center,
                                        child: Text('+${m.photos.length - 6}',
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 20,
                                                fontWeight: FontWeight.w700)),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      TextButton(onPressed: onEdit, child: Text('تعديل', style: TextStyle(color: c.muted))),
                      TextButton(onPressed: onDelete, child: Text('حذف', style: TextStyle(color: c.danger))),
                    ],
                  ),
                ],
              ),
            ),
          ),
        PositionedDirectional(
          start: 5,
          top: 9,
          child: Container(
            width: 13,
            height: 13,
            decoration: BoxDecoration(
              color: c.bg,
              shape: BoxShape.circle,
              border: Border.all(color: c.accent, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  final String title;
  final String body;
  final Widget? action;
  const _Empty({required this.title, required this.body, this.action});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, textAlign: TextAlign.center, style: displayFont(size: 30, color: c.ink)),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Text(body, textAlign: TextAlign.center, style: TextStyle(color: c.muted, height: 1.6)),
          ),
          if (action != null) ...[const SizedBox(height: 18), action!],
        ],
      ),
    );
  }
}
