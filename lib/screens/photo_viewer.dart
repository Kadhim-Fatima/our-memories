import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../models.dart';
import '../services/memory_store.dart';
import '../theme.dart';
import '../widgets/repo_image.dart';

typedef PhotoRef = ({String path, Memory memory});

/// نفس الوسم بالبطاقة والعارض، حتى الصورة "تطير" من مكانها وتكبر.
String photoHeroTag(Memory m, String path) => 'photo:${m.id}:$path';

/// عارض الصور: سحب يمين ويسار بين الصور، تكبير بإصبعين، وسحب لتحت للإغلاق.
class PhotoViewer extends StatefulWidget {
  final MemoryStore store;
  final List<PhotoRef> photos;
  final int initial;

  const PhotoViewer({super.key, required this.store, required this.photos, this.initial = 0});

  @override
  State<PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<PhotoViewer> {
  late final PageController _pc = PageController(initialPage: widget.initial);
  late int _i = widget.initial;
  double _drag = 0;
  bool _chrome = true;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.photos[_i];
    final df = DateFormat.yMMMMd('ar');
    final fade = (1 - (_drag.abs() / 300)).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: Colors.black.withAlpha((255 * fade).round()),
      body: GestureDetector(
        onTap: () => setState(() => _chrome = !_chrome),
        onVerticalDragUpdate: (d) => setState(() => _drag += d.delta.dy),
        onVerticalDragEnd: (d) {
          if (_drag.abs() > 120 || (d.primaryVelocity ?? 0).abs() > 900) {
            Navigator.pop(context);
          } else {
            setState(() => _drag = 0);
          }
        },
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedContainer(
                duration: _drag == 0 ? const Duration(milliseconds: 220) : Duration.zero,
                curve: Curves.easeOut,
                transform: Matrix4.translationValues(0, _drag, 0),
                child: PageView.builder(
                  controller: _pc,
                  itemCount: widget.photos.length,
                  onPageChanged: (i) => setState(() => _i = i),
                  itemBuilder: (_, i) {
                    final ph = widget.photos[i];
                    return InteractiveViewer(
                      maxScale: 4,
                      child: Center(
                        child: Hero(
                          tag: photoHeroTag(ph.memory, ph.path),
                          child: _FullImage(store: widget.store, path: ph.path),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            // الشريط العلوي
            AnimatedOpacity(
              opacity: _chrome && _drag == 0 ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded, color: Colors.white),
                        style: IconButton.styleFrom(backgroundColor: const Color(0x33FFFFFF)),
                      ),
                      const Spacer(),
                      if (widget.photos.length > 1)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0x33FFFFFF),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text('${_i + 1} / ${widget.photos.length}',
                              style: const TextStyle(color: Colors.white, fontSize: 14)),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            // العنوان والتاريخ
            Align(
              alignment: Alignment.bottomCenter,
              child: AnimatedOpacity(
                opacity: _chrome && _drag == 0 ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Color(0xAA000000), Color(0x00000000)],
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(p.memory.title,
                              textAlign: TextAlign.center,
                              style: displayFont(size: 26, color: Colors.white, weight: FontWeight.w400)),
                          Text(df.format(p.memory.date),
                              style: const TextStyle(color: Color(0xFFE5D3DB), fontSize: 14)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// بالعارض: تطلع النسخة الصغيرة فوراً، وبعدها تتبدل بالكاملة بهدوء لما توصل.
class _FullImage extends StatelessWidget {
  final MemoryStore store;
  final String path;
  const _FullImage({required this.store, required this.path});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: store.photo(path),
      initialData: store.cachedPhoto(path),
      builder: (context, snap) {
        if (snap.hasData) {
          return Image.memory(snap.data!, fit: BoxFit.contain, gaplessPlayback: true);
        }
        return Stack(
          alignment: Alignment.center,
          children: [
            RepoImage(store: store, path: path, fit: BoxFit.contain),
            if (!snap.hasError)
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
              ),
          ],
        );
      },
    );
  }
}
