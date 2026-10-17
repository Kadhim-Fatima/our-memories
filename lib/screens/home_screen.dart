import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../config.dart';
import '../models.dart';
import '../services/github_api.dart';
import '../services/memory_store.dart';
import '../services/settings.dart';
import '../services/viewer_access.dart';
import '../theme.dart';
import '../widgets/repo_image.dart';
import '../widgets/viewer_password_dialog.dart';
import 'memory_form.dart';
import 'photo_viewer.dart';

class HomeScreen extends StatefulWidget {
  final MemoryStore store;
  final RepoSettings settings;
  final VoidCallback onLogout;
  const HomeScreen({super.key, required this.store, required this.settings, required this.onLogout});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  MemoryStore get store => widget.store;
  bool get _admin => !widget.settings.viewer;

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _openForm([Memory? m]) async {
    final ok = await Navigator.push<bool>(
      context,
      _slideUpRoute(MemoryForm(store: store, memory: m)),
    );
    if (ok == true && mounted) _snack(m == null ? 'انحفظت الذكرى 🤍' : 'انحفظ التعديل');
  }

  Future<void> _delete(Memory m) async {
    final c = AppColors.of(context);
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تحذف هذي الذكرى؟'),
        content: Text('"${m.title}" وصورها راح تنحذف نهائياً.'),
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

  Future<void> _viewerPassword() async {
    final site = ViewerAccess.siteRepo();
    if (site == null) {
      _snack('هاي الميزة تشتغل من رابط الموقع على GitHub Pages بس.');
      return;
    }
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ViewerPasswordDialog(settings: widget.settings, siteOwner: site.$1, siteRepo: site.$2),
    );
    if (result == true && mounted) {
      _snack('انحفظت كلمة السر. الموقع يتحدث خلال دقيقتين تقريباً.');
    }
  }

  void _openViewer(Memory m, int i) {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        transitionDuration: const Duration(milliseconds: 380),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (_, __, ___) => PhotoViewer(
          store: store,
          photos: [for (final p in m.photos) (path: p, memory: m)],
          initial: i,
        ),
        transitionsBuilder: (_, a, __, child) =>
            FadeTransition(opacity: CurvedAnimation(parent: a, curve: Curves.easeOut), child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final sorted = store.book.sorted;
        return Scaffold(
          floatingActionButton: !_admin || store.loading || store.error != null
              ? null
              : FloatingActionButton.extended(
                  onPressed: () => _openForm(),
                  backgroundColor: c.accent,
                  foregroundColor: c.surface,
                  elevation: 3,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('ذكرى جديدة', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0, .45],
                colors: [c.accentSoft, c.bg],
              ),
            ),
            child: RefreshIndicator(
              color: c.accent,
              onRefresh: store.load,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                slivers: [
                  SliverToBoxAdapter(
                    child: _Header(
                      count: sorted.length,
                      viewer: !_admin,
                      onViewerPassword: _admin ? _viewerPassword : null,
                      onRefresh: store.load,
                      onLogout: widget.onLogout,
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
                  else if (sorted.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _Empty(
                        title: 'صفحتنا بعدها بيضاء',
                        body: _admin
                            ? 'ابدأ بأول ذكرى: يوم الخطوبة، أو أول طلعة، أو أي يوم حلو.'
                            : 'قريباً تنضاف هنا أول ذكرى 🤍',
                        action: _admin
                            ? FilledButton(onPressed: () => _openForm(), child: const Text('+ أضف أول ذكرى'))
                            : null,
                      ),
                    )
                  else
                    ..._memories(sorted),
                  const SliverToBoxAdapter(child: SizedBox(height: 110)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _memories(List<Memory> sorted) {
    final items = <Widget>[];
    int? year;
    var i = 0;
    for (final m in sorted) {
      if (m.date.year != year) {
        year = m.date.year;
        items.add(_Reveal(key: ValueKey('y$year'), index: i, child: _YearDivider(year: year)));
      }
      items.add(_Reveal(
        key: ValueKey(m.id),
        index: i,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _MemoryCard(
            store: store,
            memory: m,
            onEdit: _admin ? () => _openForm(m) : null,
            onDelete: _admin ? () => _delete(m) : null,
            onPhoto: (p) => _openViewer(m, p),
          ),
        ),
      ));
      i++;
    }
    return [
      SliverList.list(children: [for (final w in items) _Constrain(child: w)]),
    ];
  }
}

/// انتقال الصفحات: تطلع من تحت بنعومة.
Route<T> _slideUpRoute<T>(Widget page) => PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 420),
      reverseTransitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, a, __, child) {
        final curved = CurvedAnimation(parent: a, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, .06), end: Offset.zero).animate(curved),
            child: child,
          ),
        );
      },
    );

/* ---------------- أجزاء الواجهة ---------------- */

class _Constrain extends StatelessWidget {
  final Widget child;
  const _Constrain({required this.child});
  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: child),
        ),
      );
}

/// ظهور ناعم: يطلع العنصر من تحت ويتوضح، واحد ورا الثاني.
class _Reveal extends StatefulWidget {
  final int index;
  final Widget child;
  const _Reveal({super.key, required this.index, required this.child});

  @override
  State<_Reveal> createState() => _RevealState();
}

class _RevealState extends State<_Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 650));
  late final Animation<double> _a = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);

  @override
  void initState() {
    super.initState();
    final delay = Duration(milliseconds: 80 * widget.index.clamp(0, 6).toInt());
    Future.delayed(delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _a,
      builder: (_, child) => Opacity(
        opacity: _a.value,
        child: Transform.translate(offset: Offset(0, 28 * (1 - _a.value)), child: child),
      ),
      child: widget.child,
    );
  }
}

class _Header extends StatelessWidget {
  final int count;
  final bool viewer;
  final VoidCallback? onViewerPassword;
  final VoidCallback onRefresh;
  final VoidCallback onLogout;
  const _Header({
    required this.count,
    required this.viewer,
    this.onViewerPassword,
    required this.onRefresh,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final cp = appCouple;
    final nf = NumberFormat.decimalPattern('ar');
    final df = DateFormat.yMMMMd('ar');

    int? days;
    int? left;
    int years = 0;
    final since = cp.since;
    if (since != null) {
      final today = DateUtils.dateOnly(DateTime.now());
      days = today.difference(since).inDays;
      var next = DateTime(today.year, since.month, since.day);
      if (next.isBefore(today)) next = DateTime(today.year + 1, since.month, since.day);
      left = next.difference(today).inDays;
      years = next.year - since.year;
    }

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Column(
          children: [
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: PopupMenuButton<String>(
                icon: Icon(Icons.more_horiz_rounded, color: c.muted),
                onSelected: (v) {
                  if (v == 'viewer') onViewerPassword?.call();
                  if (v == 'refresh') onRefresh();
                  if (v == 'logout') onLogout();
                },
                itemBuilder: (_) => [
                  if (onViewerPassword != null)
                    const PopupMenuItem(value: 'viewer', child: Text('كلمة سر المشاهدة')),
                  const PopupMenuItem(value: 'refresh', child: Text('تحديث')),
                  const PopupMenuItem(value: 'logout', child: Text('تسجيل خروج')),
                ],
              ),
            ),
            _Reveal(
              index: 0,
              child: Column(
                children: [
                  Text('دفتر ذكرياتنا',
                      style: TextStyle(color: c.gold, letterSpacing: 1.5, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 6),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      children: [
                        Text(cp.name1, style: displayFont(size: 52, color: c.accent)),
                        Text('و', style: displayFont(size: 40, color: c.gold, weight: FontWeight.w400)),
                        Text(cp.name2, style: displayFont(size: 52, color: c.accent)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (days != null)
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _Stat(value: nf.format(days < 0 ? 0 : days), label: 'يوم سوا'),
                        _Stat(value: nf.format(count), label: count == 1 ? 'ذكرى' : 'ذكريات'),
                        if (left != null && years >= 1)
                          _Stat(
                            value: left == 0 ? '🤍' : nf.format(left),
                            label: left == 0 ? 'اليوم ذكرانا' : 'يوم لذكرانا الـ${nf.format(years)}',
                          ),
                      ],
                    ),
                  if (since != null) ...[
                    const SizedBox(height: 12),
                    Text('مخطوبين من ${df.format(since)}', style: TextStyle(color: c.muted, fontSize: 14)),
                  ],
                  const SizedBox(height: 22),
                  const _Ornament(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  const _Stat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 96),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: c.surface.withAlpha(200),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.line),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              style: TextStyle(
                  color: c.accent, fontSize: 22, fontWeight: FontWeight.w700, height: 1.2,
                  fontFeatures: const [FontFeature.tabularFigures()])),
          Text(label, style: TextStyle(color: c.muted, fontSize: 12.5)),
        ],
      ),
    );
  }
}

class _Ornament extends StatelessWidget {
  const _Ornament();
  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    Widget line(bool rtl) => Container(
          width: 70,
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: rtl ? [c.gold.withAlpha(0), c.gold] : [c.gold, c.gold.withAlpha(0)],
            ),
          ),
        );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        line(true),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('❦', style: TextStyle(color: c.gold, fontSize: 18)),
        ),
        line(false),
      ],
    );
  }
}

class _YearDivider extends StatelessWidget {
  final int year;
  const _YearDivider({required this.year});
  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 14),
      child: Row(
        children: [
          Expanded(child: Container(height: 1, color: c.line)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(NumberFormat('####', 'ar').format(year), style: displayFont(size: 30, color: c.gold)),
          ),
          Expanded(child: Container(height: 1, color: c.line)),
        ],
      ),
    );
  }
}

/// بطاقة الذكرى: الصورة على اليمين، وجنبها العنوان ثم التاريخ ثم الوصف.
class _MemoryCard extends StatelessWidget {
  final MemoryStore store;
  final Memory memory;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final ValueChanged<int> onPhoto;
  const _MemoryCard({
    required this.store,
    required this.memory,
    this.onEdit,
    this.onDelete,
    required this.onPhoto,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final m = memory;
    final date = DateFormat.yMMMMd('ar').format(m.date);
    final hasPhotos = m.photos.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: c.line.withAlpha(140)),
        boxShadow: [
          BoxShadow(color: c.accent.withAlpha(18), blurRadius: 24, offset: const Offset(0, 10)),
        ],
      ),
      child: LayoutBuilder(builder: (context, box) {
        final imgW = (box.maxWidth * .38).clamp(110.0, 220.0);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // الصورة (على اليمين لأن الصفحة عربية)
            if (hasPhotos) ...[
              GestureDetector(
                onTap: () => onPhoto(0),
                child: SizedBox(
                  width: imgW,
                  child: AspectRatio(
                    aspectRatio: 3 / 4,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Hero(
                            tag: photoHeroTag(m, m.photos.first),
                            child: RepoImage(store: store, path: m.photos.first),
                          ),
                          if (m.photos.length > 1)
                            PositionedDirectional(
                              bottom: 8,
                              end: 8,
                              child: _Chip(
                                text: '+${m.photos.length - 1}',
                                icon: Icons.photo_library_outlined,
                                onImage: true,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
            ],
            // النصوص: العنوان، التاريخ، الوصف
            Expanded(
              child: Padding(
                padding: EdgeInsetsDirectional.only(top: 4, start: hasPhotos ? 0 : 6, end: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.title.isEmpty ? 'بدون عنوان' : m.title,
                      style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, height: 1.35, color: c.ink),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.event_outlined, size: 15, color: c.accent),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(date,
                              style: TextStyle(color: c.accent, fontSize: 13.5, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                    if (m.place.isNotEmpty || m.tag.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (m.place.isNotEmpty) _Chip(text: m.place, icon: Icons.place_outlined),
                          if (m.tag.isNotEmpty) _Chip(text: m.tag),
                        ],
                      ),
                    ],
                    if (m.story.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(height: 1, width: 36, color: c.gold.withAlpha(150)),
                      const SizedBox(height: 10),
                      _ExpandableText(m.story),
                    ],
                    if (onEdit != null || onDelete != null)
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (onEdit != null)
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                tooltip: 'تعديل',
                                onPressed: onEdit,
                                icon: Icon(Icons.edit_outlined, color: c.muted, size: 19),
                              ),
                            if (onDelete != null)
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                tooltip: 'حذف',
                                onPressed: onDelete,
                                icon: Icon(Icons.delete_outline_rounded, color: c.danger, size: 19),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  final IconData? icon;
  final bool onImage;
  const _Chip({required this.text, this.icon, this.onImage = false});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final fg = onImage ? Colors.white : c.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
      decoration: BoxDecoration(
        color: onImage ? const Color(0x66000000) : c.accentSoft.withAlpha(150),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 14, color: fg), const SizedBox(width: 4)],
          Text(text, style: TextStyle(color: fg, fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

/// نص القصة: يعرض أول كم سطر، و"اقرأ أكثر" يفتح الباقي بحركة ناعمة.
class _ExpandableText extends StatefulWidget {
  final String text;
  const _ExpandableText(this.text);
  @override
  State<_ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<_ExpandableText> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final style = TextStyle(fontSize: 15, height: 1.8, color: c.ink.withAlpha(215));
    return LayoutBuilder(builder: (context, box) {
      final tp = TextPainter(
        text: TextSpan(text: widget.text, style: style),
        maxLines: 4,
        textDirection: Directionality.of(context),
      )..layout(maxWidth: box.maxWidth);
      final long = tp.didExceedMaxLines;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: Text(
              widget.text,
              style: style,
              maxLines: _open ? null : 4,
              overflow: _open ? TextOverflow.visible : TextOverflow.fade,
            ),
          ),
          if (long)
            GestureDetector(
              onTap: () => setState(() => _open = !_open),
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(_open ? 'أقل' : 'اقرأ أكثر',
                    style: TextStyle(color: c.accent, fontWeight: FontWeight.w700, fontSize: 14)),
              ),
            ),
        ],
      );
    });
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
