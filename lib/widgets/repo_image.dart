import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/memory_store.dart';
import '../theme.dart';

/// صورة محفوظة بالـ repo الخاص (تنجاب بالتوكن، مو برابط عام).
class RepoImage extends StatelessWidget {
  final MemoryStore store;
  final String path;
  final BoxFit fit;

  const RepoImage({super.key, required this.store, required this.path, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return FutureBuilder<Uint8List>(
      future: store.photo(path),
      builder: (context, snap) {
        if (snap.hasData) {
          return Image.memory(snap.data!, fit: fit, gaplessPlayback: true);
        }
        return Container(
          color: c.accentSoft,
          alignment: Alignment.center,
          child: snap.hasError
              ? Icon(Icons.broken_image_outlined, color: c.muted)
              : SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: c.accent),
                ),
        );
      },
    );
  }
}
