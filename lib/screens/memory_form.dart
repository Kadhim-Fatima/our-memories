import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../services/github_api.dart';
import '../services/memory_store.dart';
import '../theme.dart';
import '../widgets/repo_image.dart';

/// إضافة ذكرى جديدة أو تعديل ذكرى موجودة.
class MemoryForm extends StatefulWidget {
  final MemoryStore store;
  final Memory? memory;

  const MemoryForm({super.key, required this.store, this.memory});

  @override
  State<MemoryForm> createState() => _MemoryFormState();
}

class _NewPhoto {
  final Uint8List bytes;
  final String ext;
  _NewPhoto(this.bytes, this.ext);
}

class _MemoryFormState extends State<MemoryForm> {
  late final _title = TextEditingController(text: widget.memory?.title);
  late final _place = TextEditingController(text: widget.memory?.place);
  late final _story = TextEditingController(text: widget.memory?.story);
  late DateTime _date = widget.memory?.date ?? DateUtils.dateOnly(DateTime.now());
  late String _tag = widget.memory?.tag ?? '';
  late final List<String> _keep = [...?widget.memory?.photos];
  final List<_NewPhoto> _new = [];
  bool _saving = false;
  String _status = '';

  bool get _isEdit => widget.memory != null;

  @override
  void dispose() {
    _title.dispose();
    _place.dispose();
    _story.dispose();
    super.dispose();
  }

  Future<void> _pickPhotos() async {
    try {
      final files = await ImagePicker().pickMultiImage(
        maxWidth: 2000,
        maxHeight: 2000,
        imageQuality: 85,
      );
      for (final f in files) {
        final bytes = await f.readAsBytes();
        _new.add(_NewPhoto(bytes, _extOf(f)));
      }
      if (mounted) setState(() {});
    } catch (_) {
      _snack('ما گدرت أفتح الصور، جرّب مرة ثانية.');
    }
  }

  static String _extOf(XFile f) {
    final mime = f.mimeType ?? '';
    if (mime.contains('png')) return 'png';
    if (mime.contains('webp')) return 'webp';
    if (mime.contains('gif')) return 'gif';
    final n = f.name.toLowerCase();
    for (final e in ['png', 'webp', 'gif']) {
      if (n.endsWith('.$e')) return e;
    }
    return 'jpg';
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(1990),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      _snack('اكتب عنوان للذكرى');
      return;
    }
    setState(() {
      _saving = true;
      _status = 'جاري الحفظ…';
    });
    final base = widget.memory ??
        Memory(id: MemoryStore.newId(), title: title, date: _date, createdAt: DateTime.now());
    final m = Memory(
      id: base.id,
      title: title,
      date: _date,
      place: _place.text.trim(),
      story: _story.text.trim(),
      tag: _tag,
      photos: List.of(_keep),
      createdAt: base.createdAt,
    );
    try {
      await widget.store.saveMemory(
        m,
        newPhotos: [for (final p in _new) (bytes: p.bytes, ext: p.ext)],
        onProgress: (done, total) {
          if (!mounted || total == 0) return;
          setState(() => _status = done < total ? 'رفع الصور ${done + 1} من $total…' : 'جاري الحفظ…');
        },
      );
      if (mounted) Navigator.pop(context, true);
    } on GitHubException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('ما انحفظت الذكرى، تأكد من الإنترنت وجرب مرة ثانية.');
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _status = '';
        });
      }
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final df = DateFormat.yMMMMd('ar');
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: c.bg,
          surfaceTintColor: Colors.transparent,
          title: Text(_isEdit ? 'تعديل الذكرى' : 'ذكرى جديدة',
              style: displayFont(size: 26, color: c.accent)),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  TextField(
                    controller: _title,
                    maxLength: 120,
                    decoration: const InputDecoration(
                      labelText: 'العنوان',
                      hintText: 'مثلاً: يوم الخطوبة',
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: _pickDate,
                          child: InputDecorator(
                            decoration: const InputDecoration(labelText: 'التاريخ'),
                            child: Text(df.format(_date)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _place,
                          maxLength: 80,
                          decoration: const InputDecoration(
                            labelText: 'المكان',
                            hintText: 'البصرة، الكورنيش…',
                            counterText: '',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('نوع الذكرى', style: TextStyle(color: c.muted, fontSize: 14)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final t in memoryTags)
                        ChoiceChip(
                          label: Text(t),
                          selected: _tag == t,
                          showCheckmark: false,
                          selectedColor: c.accent,
                          labelStyle: TextStyle(color: _tag == t ? c.surface : c.ink),
                          shape: StadiumBorder(side: BorderSide(color: _tag == t ? c.accent : c.line)),
                          backgroundColor: c.surface,
                          onSelected: (_) => setState(() => _tag = _tag == t ? '' : t),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _story,
                    minLines: 5,
                    maxLines: 14,
                    maxLength: 6000,
                    decoration: const InputDecoration(
                      labelText: 'القصة',
                      hintText: 'شنو صار؟ شنو حسّيتوا؟',
                      alignLabelWithHint: true,
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('الصور', style: TextStyle(color: c.muted, fontSize: 14)),
                  const SizedBox(height: 6),
                  GridView.extent(
                    maxCrossAxisExtent: 100,
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      for (var i = 0; i < _keep.length; i++)
                        _Thumb(
                          onRemove: _saving ? null : () => setState(() => _keep.removeAt(i)),
                          child: RepoImage(store: widget.store, path: _keep[i]),
                        ),
                      for (var i = 0; i < _new.length; i++)
                        _Thumb(
                          onRemove: _saving ? null : () => setState(() => _new.removeAt(i)),
                          child: Image.memory(_new[i].bytes, fit: BoxFit.cover),
                        ),
                      InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: _saving ? null : _pickPhotos,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: c.line, width: 1.5),
                          ),
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add_photo_alternate_outlined, color: c.muted),
                              Text('صور', style: TextStyle(color: c.muted, fontSize: 13)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      FilledButton(
                        onPressed: _saving ? null : _save,
                        child: Text(_isEdit ? 'حفظ التعديل' : 'حفظ الذكرى'),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(_status, style: TextStyle(color: c.muted, fontSize: 14)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  final Widget child;
  final VoidCallback? onRemove;
  const _Thumb({required this.child, this.onRemove});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        fit: StackFit.expand,
        children: [
          child,
          if (onRemove != null)
            PositionedDirectional(
              top: 4,
              end: 4,
              child: Material(
                color: Colors.black54,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onRemove,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close, size: 16, color: Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
