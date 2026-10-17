import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../services/memory_store.dart';
import '../theme.dart';
import '../widgets/repo_image.dart';

typedef PhotoRef = ({String path, Memory memory});

/// عارض الصور: سحب بين الصور، تكبير بإصبعين.
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

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.photos[_i];
    final df = DateFormat.yMMMMd('ar');
    return Scaffold(
      backgroundColor: const Color(0xFF0C0408),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: widget.photos.length > 1
            ? Text('${_i + 1} / ${widget.photos.length}', style: const TextStyle(fontSize: 15))
            : null,
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pc,
              itemCount: widget.photos.length,
              onPageChanged: (i) => setState(() => _i = i),
              itemBuilder: (_, i) => InteractiveViewer(
                maxScale: 4,
                child: Center(
                  child: RepoImage(
                    store: widget.store,
                    path: widget.photos[i].path,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                children: [
                  Text(p.memory.title,
                      textAlign: TextAlign.center,
                      style: displayFont(size: 24, color: Colors.white, weight: FontWeight.w400)),
                  Text(df.format(p.memory.date),
                      style: const TextStyle(color: Color(0xFFD9C4CE), fontSize: 14)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
