import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/api/shelfscan_api.dart';
import 'package:frontend/features/library/library_provider.dart';
import 'package:frontend/models/user_book_dto.dart';
import 'package:image_picker/image_picker.dart';

class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  final ImagePicker _picker = ImagePicker();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();

  File? _selectedImage;
  ScanPreviewDto? _preview;
  UserBookDto? _result;

  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _titleController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 65,
      maxWidth: 1280,
      maxHeight: 1280,
    );

    if (picked == null) return;

    setState(() {
      _selectedImage = File(picked.path);
      _preview = null;
      _result = null;
      _error = null;
      _titleController.clear();
      _tagsController.clear();
    });
  }

  Future<void> _previewScan() async {
    final image = _selectedImage;
    if (image == null || _isLoading) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _preview = null;
      _result = null;
    });

    try {
      final api = ref.read(shelfScanApiProvider);
      final preview = await api.previewScan(image);

      if (!mounted) return;

      setState(() {
        _preview = preview;
        _titleController.text = preview.title;
        _tagsController.text = preview.tags.join(', ');
      });
    } on DioException catch (e) {
      if (!mounted) return;

      final data = e.response?.data;
      final message = data == null || data.toString().trim().isEmpty
          ? e.message ?? 'Errore durante la scansione.'
          : data.toString();

      setState(() {
        _error = message;
      });
    } finally {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _confirmScan() async {
    final image = _selectedImage;
    final preview = _preview;

    if (image == null || preview == null || _isLoading) return;

    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() {
        _error = 'Il titolo non può essere vuoto.';
      });
      return;
    }

    final tags = _tagsController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    setState(() {
      _isLoading = true;
      _error = null;
      _result = null;
    });

    try {
      final api = ref.read(shelfScanApiProvider);

      final result = await api.confirmScan(
        imageFile: image,
        preview: preview,
        customTitle: _titleController.text.trim(),
        customTags: tags,
      );

      ref.invalidate(libraryProvider);

      if (!mounted) return;

      setState(() {
        _result = result;
        _preview = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Libro aggiunto alla libreria')),
      );
    } on DioException catch (e) {
      if (!mounted) return;

      debugPrint('ERRORE CONFIRM SCAN: ${e.response?.statusCode}');
      debugPrint('DATA: ${e.response?.data}');
      debugPrint('MESSAGE: ${e.message}');

      setState(() {
        _error =
        'Errore ${e.response?.statusCode ?? ''}: ${e.response?.data ?? e.message}';
      });
    } catch (e) {
      if (!mounted) return;

      debugPrint('ERRORE CONFIRM SCAN: $e');

      setState(() {
        _error = e.toString();
      });
    } finally {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });
    }
  }

  void _resetScan() {
    setState(() {
      _selectedImage = null;
      _preview = null;
      _result = null;
      _error = null;
      _titleController.clear();
      _tagsController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan'),
        actions: [
          if (_selectedImage != null)
            IconButton(
              onPressed: _isLoading ? null : _resetScan,
              icon: const Icon(Icons.refresh_rounded),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ActionButton(
            icon: Icons.photo_camera_rounded,
            title: 'Scatta foto',
            subtitle: 'Apri fotocamera e scansiona la copertina',
            onTap: _isLoading ? () {} : () => _pickImage(ImageSource.camera),
          ),
          const SizedBox(height: 12),
          _ActionButton(
            icon: Icons.photo_library_rounded,
            title: 'Carica da galleria',
            subtitle: 'Seleziona una foto esistente',
            onTap: _isLoading ? () {} : () => _pickImage(ImageSource.gallery),
          ),

          if (_selectedImage != null) ...[
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.file(
                _selectedImage!,
                height: 320,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 16),
            if (_preview == null && _result == null)
              FilledButton.icon(
                onPressed: _isLoading ? null : _previewScan,
                icon: _isLoading
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Icon(Icons.auto_awesome_rounded),
                label: Text(
                  _isLoading ? 'Analisi in corso...' : 'Analizza copertina',
                ),
              ),
          ],

          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(color: cs.error),
            ),
          ],

          if (_preview != null) ...[
            const SizedBox(height: 20),
            _PreviewEditor(
              titleController: _titleController,
              tagsController: _tagsController,
              preview: _preview!,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _isLoading ? null : _confirmScan,
              icon: _isLoading
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Icon(Icons.check_rounded),
              label: Text(
                _isLoading ? 'Salvataggio in corso...' : 'Conferma e salva',
              ),
            ),
          ],

          if (_result != null) ...[
            const SizedBox(height: 20),
            _ResultCard(book: _result!),
          ],
        ],
      ),
    );
  }
}

class _PreviewEditor extends StatelessWidget {
  final TextEditingController titleController;
  final TextEditingController tagsController;
  final ScanPreviewDto preview;

  const _PreviewEditor({
    required this.titleController,
    required this.tagsController,
    required this.preview,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Risultato riconosciuto',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            preview.existingBook
                ? 'Libro già presente nel catalogo. Puoi personalizzare titolo e tag per la tua libreria.'
                : 'Controlla i dati riconosciuti e personalizza titolo e tag prima del salvataggio.',
            style: Theme.of(context).textTheme.bodySmall,
          ),

          const SizedBox(height: 16),

          Text(
            'Personalizzazione libreria',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),

          TextField(
            controller: titleController,
            decoration: const InputDecoration(
              labelText: 'Titolo personale',
              helperText: 'Salvato solo nella tua libreria',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: tagsController,
            decoration: const InputDecoration(
              labelText: 'Tag personali',
              helperText: 'Separali con una virgola',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 18),

          Text(
            'Dati catalogo globale',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),

          _ReadOnlyInfoBox(
            label: 'Autore',
            value: preview.author.isEmpty
                ? 'Autore non disponibile'
                : preview.author,
          ),
          const SizedBox(height: 10),

          _ReadOnlyInfoBox(
            label: 'Descrizione',
            value: preview.description.isEmpty
                ? 'Nessuna descrizione disponibile.'
                : preview.description,
          ),
        ],
      ),
    );
  }
}

class _ReadOnlyInfoBox extends StatelessWidget {
  final String label;
  final String value;

  const _ReadOnlyInfoBox({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: cs.outline.withValues(alpha: 0.14),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final UserBookDto book;

  const _ResultCard({required this.book});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (book.coverUrl != null && book.coverUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(
                book.coverUrl!,
                width: 86,
                height: 128,
                fit: BoxFit.cover,
              ),
            )
          else
            Container(
              width: 86,
              height: 128,
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.menu_book_rounded),
            ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  book.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  book.author,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 10),
                Text(
                  'Aggiunto alla libreria',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: cs.onSurface.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}