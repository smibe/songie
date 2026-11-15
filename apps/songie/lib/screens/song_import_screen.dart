import 'dart:convert';

import 'package:chordpro/chordpro.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../data/song.dart';
import '../data/song_access.dart';
import '../data/song_repository.dart';
import '../settings/songie_settings.dart';
import 'song_reader_content.dart';

class SongImportScreen extends StatefulWidget {
  const SongImportScreen({
    required this.settings,
    required this.songRepository,
    super.key,
  });

  final SongieSettings settings;
  final SongRepository songRepository;

  @override
  State<SongImportScreen> createState() => _SongImportScreenState();
}

class _SongImportScreenState extends State<SongImportScreen> {
  static const _maximumSourceBytes = 900000;

  final _textController = TextEditingController();
  SongieSong? _previewSong;
  SongSourceImportResult? _importResult;
  String? _selectedFileName;
  String? _errorMessage;
  bool _isPickingFile = false;
  bool _isSaving = false;
  bool _publishImmediately = true;
  SongVisibility _visibility = SongVisibility.friends;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _onTextChanged(String value) {
    setState(() {
      _previewSong = null;
      _importResult = null;
      _errorMessage = null;
      _selectedFileName = null;
    });
  }

  Future<void> _pickFile() async {
    setState(() {
      _isPickingFile = true;
      _errorMessage = null;
    });

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pro', 'chopro', 'chordpro', 'cho', 'txt'],
        allowMultiple: false,
        withData: true,
      );
      if (!mounted) return;

      if (result == null || result.files.isEmpty) {
        setState(() => _isPickingFile = false);
        return;
      }

      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null) {
        throw const FormatException(
          'The selected file could not be read. Please try another file.',
        );
      }
      if (bytes.length > _maximumSourceBytes) {
        throw const FormatException(
          'The selected file is larger than the 900 KB import limit.',
        );
      }

      String text;
      try {
        text = utf8.decode(bytes);
      } on FormatException {
        // Some downloaded chord sheets are saved using a Windows code page.
        // Latin-1 preserves common German characters in those files.
        text = latin1.decode(bytes);
      }
      setState(() {
        _textController.text = text;
        _selectedFileName = file.name;
        _previewSong = null;
        _importResult = null;
        _errorMessage = null;
        _isPickingFile = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isPickingFile = false;
        _errorMessage = 'Could not read the file: ' + error.toString();
      });
    }
  }

  void _createPreview() {
    FocusScope.of(context).unfocus();

    try {
      if (utf8.encode(_textController.text).length > _maximumSourceBytes) {
        throw const FormatException(
          'The pasted song text is larger than the 900 KB import limit.',
        );
      }
      final result =
          const SongSourceImporter().importSource(_textController.text);
      if (utf8.encode(result.source).length > _maximumSourceBytes) {
        throw const FormatException(
          'The converted song is larger than the 900 KB Firestore limit.',
        );
      }

      final song = SongieSong.fromChordPro(
        id: 'song-import-preview',
        source: result.source,
      );
      if (song.title.trim().isEmpty || song.title == 'Untitled song') {
        throw const FormatException(
          'No song title was found. Please check the title or the first line.',
        );
      }
      if (song.document.sections.isEmpty) {
        throw const FormatException(
          'No song sections or lyrics were found in the imported text.',
        );
      }

      setState(() {
        _importResult = result;
        _previewSong = song;
        _errorMessage = null;
      });
    } catch (error) {
      setState(() {
        _previewSong = null;
        _importResult = null;
        _errorMessage = error.toString().replaceFirst('FormatException: ', '');
      });
    }
  }

  Future<void> _saveSong() async {
    final song = _previewSong;
    if (song == null || _isSaving) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await widget.songRepository.createSong(
        title: song.title,
        artist: song.artist,
        key: song.key,
        chordPro: song.source,
        published: _publishImmediately,
        visibility: _visibility,
      );
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"' + song.title + '" was imported successfully.'),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorMessage = _friendlySaveError(error);
      });
    }
  }

  String _friendlySaveError(Object error) {
    final message = error.toString();
    if (message.contains('already exists') ||
        message.contains('already-exists') ||
        message.contains('ALREADY_EXISTS')) {
      return 'A song with this title already exists. Rename the song before importing it again.';
    }
    if (message.contains('permission-denied') ||
        message.contains('PERMISSION_DENIED')) {
      return 'Firestore denied this import. Please check that you are signed in with an active administrator account.';
    }
    return 'The song could not be saved: ' + message;
  }

  String get _formatLabel {
    return switch (_importResult?.format) {
      SongSourceFormat.chordPro => 'ChordPro',
      SongSourceFormat.alignedText => 'Plain-text chord sheet',
      null => '',
    };
  }

  @override
  Widget build(BuildContext context) {
    final previewSong = _previewSong;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Import song'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Paste a song or select a file. Songie detects ChordPro '
                      'and supported chord-above-lyrics text sheets automatically.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _textController,
                      minLines: 12,
                      maxLines: 22,
                      keyboardType: TextInputType.multiline,
                      autocorrect: false,
                      enableSuggestions: false,
                      onChanged: _onTextChanged,
                      decoration: InputDecoration(
                        labelText: 'Song text',
                        hintText: '{title: My song}\n{artist: Artist}\n\n'
                            'Or paste a text chord sheet with chords above lyrics…',
                        alignLabelWithHint: true,
                        border: const OutlineInputBorder(),
                        suffixIcon: _textController.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear text',
                                onPressed: () {
                                  _textController.clear();
                                  setState(() {
                                    _selectedFileName = null;
                                    _previewSong = null;
                                    _importResult = null;
                                    _errorMessage = null;
                                  });
                                },
                                icon: const Icon(Icons.clear),
                              ),
                      ),
                    ),
                    if (_selectedFileName != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.insert_drive_file_outlined, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _selectedFileName!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      alignment: WrapAlignment.spaceBetween,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _isPickingFile ? null : _pickFile,
                          icon: _isPickingFile
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.attach_file),
                          label: const Text('Select file'),
                        ),
                        FilledButton.icon(
                          onPressed: _textController.text.trim().isEmpty
                              ? null
                              : _createPreview,
                          icon: const Icon(Icons.preview_outlined),
                          label: const Text('Preview'),
                        ),
                      ],
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      _ImportMessage(
                        message: _errorMessage!,
                        isError: true,
                      ),
                    ],
                    if (previewSong != null) ...[
                      const SizedBox(height: 28),
                      Row(
                        children: [
                          Text(
                            'Preview',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(width: 12),
                          Chip(label: Text(_formatLabel)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Card(
                        clipBehavior: Clip.antiAlias,
                        child: SizedBox(
                          height: constraints.maxWidth < 620 ? 360 : 440,
                          child: SongReaderContent(
                            song: previewSong,
                            settings: widget.settings,
                          ),
                        ),
                      ),
                      if (previewSong.document.warnings.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _ImportMessage(
                          message: previewSong.document.warnings.join('\n'),
                          isError: false,
                        ),
                      ],
                      const SizedBox(height: 20),
                      Text(
                        'Import settings',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<SongVisibility>(
                        value: _visibility,
                        decoration: const InputDecoration(
                          labelText: 'Visibility',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: SongVisibility.friends,
                            child: Text('Friends'),
                          ),
                          DropdownMenuItem(
                            value: SongVisibility.public,
                            child: Text('Public'),
                          ),
                          DropdownMenuItem(
                            value: SongVisibility.private,
                            child: Text('Private (admins only)'),
                          ),
                        ],
                        onChanged: _isSaving
                            ? null
                            : (value) {
                                if (value != null) {
                                  setState(() => _visibility = value);
                                }
                              },
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Publish immediately'),
                        subtitle: const Text(
                          'Turn off to save the song as an unpublished draft.',
                        ),
                        value: _publishImmediately,
                        onChanged: _isSaving
                            ? null
                            : (value) => setState(
                                  () => _publishImmediately = value,
                                ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _isSaving ? null : _saveSong,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.library_add_check),
                        label: Text(
                          _isSaving ? 'Importing…' : 'Import song',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ImportMessage extends StatelessWidget {
  const _ImportMessage({
    required this.message,
    required this.isError,
  });

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError
        ? Theme.of(context).colorScheme.errorContainer
        : Theme.of(context).colorScheme.surfaceContainerHighest;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(message),
    );
  }
}
