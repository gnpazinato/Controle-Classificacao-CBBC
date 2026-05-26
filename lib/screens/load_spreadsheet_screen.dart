import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../constants/app_version.dart';
import '../models/match_state.dart';
import '../services/cache_service.dart';
import '../services/import_result.dart';
import '../services/pdf_parser_service.dart';
import '../services/spreadsheet_parser_service.dart';
import '../services/template_generator_service.dart';
import '../utils/template_saver.dart' as platform_saver;
import '../widgets/cbbc_logo_header.dart';
import 'match_setup_screen.dart';
import 'missing_data_screen.dart';
import 'validation_summary_screen.dart';

typedef FilePickerFn = Future<_PickedFile?> Function();

typedef TemplateSaveFn = Future<String?> Function(
    String filename, Uint8List bytes);

class _PickedFile {
  const _PickedFile({required this.bytes, required this.extension});
  final Uint8List bytes;
  final String extension;
}

/// Tela inicial — escolhe planilha ou PDF e oferece restaurar a sessão.
class LoadSpreadsheetScreen extends StatefulWidget {
  const LoadSpreadsheetScreen({
    super.key,
    SpreadsheetParserService? xlsxParser,
    PdfParserService? pdfParser,
    CacheService? cache,
    FilePickerFn? filePicker,
    TemplateGeneratorService? templates,
    TemplateSaveFn? saveTemplate,
  })  : _xlsxParser = xlsxParser,
        _pdfParser = pdfParser,
        _cache = cache,
        _filePicker = filePicker,
        _templates = templates,
        _saveTemplate = saveTemplate;

  final SpreadsheetParserService? _xlsxParser;
  final PdfParserService? _pdfParser;
  final CacheService? _cache;
  final FilePickerFn? _filePicker;
  final TemplateGeneratorService? _templates;
  final TemplateSaveFn? _saveTemplate;

  @override
  State<LoadSpreadsheetScreen> createState() => _LoadSpreadsheetScreenState();
}

class _LoadSpreadsheetScreenState extends State<LoadSpreadsheetScreen> {
  late final SpreadsheetParserService _xlsxParser;
  late final PdfParserService _pdfParser;
  late final CacheService _cache;
  late final FilePickerFn _pickFile;
  late final TemplateGeneratorService _templates;
  late final TemplateSaveFn _saveTemplate;

  bool _busy = false;
  bool _hasPromptedRestore = false;

  @override
  void initState() {
    super.initState();
    _xlsxParser = widget._xlsxParser ?? const SpreadsheetParserService();
    _pdfParser = widget._pdfParser ?? const PdfParserService();
    _cache = widget._cache ?? CacheService();
    _pickFile = widget._filePicker ?? _defaultFilePicker;
    _templates = widget._templates ?? const TemplateGeneratorService();
    _saveTemplate = widget._saveTemplate ?? platform_saver.defaultSaveTemplate;
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeOfferRestore());
  }

  Future<_PickedFile?> _defaultFilePicker() async {
    final FilePickerResult? picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: <String>['xlsx', 'pdf'],
      withData: true,
    );
    if (picked == null) return null;
    final PlatformFile file = picked.files.single;
    final Uint8List? bytes = file.bytes;
    if (bytes == null) return null;
    final String ext = (file.extension ?? '').toLowerCase();
    return _PickedFile(bytes: bytes, extension: ext);
  }

  Future<void> _maybeOfferRestore() async {
    if (_hasPromptedRestore) return;
    _hasPromptedRestore = true;
    final bool hasSession = await _cache.hasMatchState();
    if (!mounted || !hasSession) return;
    final bool? restore = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Sessão anterior encontrada'),
          content: const Text(
            'Deseja restaurar a sessão anterior ou começar do zero?',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Começar do zero'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Restaurar sessão'),
            ),
          ],
        );
      },
    );
    if (!mounted) return;
    if (restore == true) {
      final MatchState? state = await _cache.loadMatchState();
      if (!mounted) return;
      if (state == null) {
        _showSnack('Sessão salva não pôde ser restaurada.');
        return;
      }
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => MatchSetupScreen(restored: state),
        ),
      );
    } else {
      await _cache.clear();
    }
  }

  Future<void> _onLoadPressed() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final _PickedFile? picked = await _pickFile();
      if (picked == null) return;
      final ImportResult result;
      if (picked.extension == 'pdf') {
        result = _pdfParser.parseBytes(picked.bytes);
      } else {
        result = _xlsxParser.parseBytes(picked.bytes);
      }
      if (!mounted) return;
      if (result.hasBlockingIssues && result.teams.isEmpty) {
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => MissingDataScreen(result: result),
          ),
        );
        return;
      }
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => ValidationSummaryScreen(
            result: result,
            cache: _cache,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onDownloadTemplatePressed(TemplateKind kind) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final Uint8List bytes = _templates.build(kind);
      final String filename = _templates.filenameFor(kind);
      final String? savedAt = await _saveTemplate(filename, bytes);
      if (!mounted) return;
      if (savedAt == null) return;
      _showSnack('Modelo salvo em $savedAt');
    } catch (e) {
      if (!mounted) return;
      _showSnack('Não foi possível salvar o modelo: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const SizedBox(height: 16),
              const CbbcBrandHeader(
                subtitle: 'Basquetebol em cadeira de rodas — controle de pontos por equipe',
              ),
              const SizedBox(height: 8),
              const Text(
                'Carregue a planilha ou PDF de referência dos atletas para iniciar uma partida.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                key: const Key('load-spreadsheet-button'),
                onPressed: _busy ? null : _onLoadPressed,
                icon: const Icon(Icons.upload_file),
                label: const Text('Carregar planilha (.xlsx) ou PDF'),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                key: const Key('download-template-single-sheet'),
                onPressed: _busy
                    ? null
                    : () =>
                        _onDownloadTemplatePressed(TemplateKind.singleSheet),
                icon: const Icon(Icons.download_outlined),
                label: const Text('Baixar modelo — aba única'),
              ),
              const _OrDivider(),
              OutlinedButton.icon(
                key: const Key('download-template-per-team'),
                onPressed: _busy
                    ? null
                    : () => _onDownloadTemplatePressed(TemplateKind.perTeam),
                icon: const Icon(Icons.download_outlined),
                label: const Text('Baixar modelo — uma aba por clube'),
              ),
              const Spacer(),
              if (_busy) const LinearProgressIndicator(),
              const SizedBox(height: 8),
              Text(
                'App offline. Sem login. Sem necessidade de internet.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              Text(
                'Versão $kAppVersion',
                key: const Key('app-version-label'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    final TextStyle? style = Theme.of(context)
        .textTheme
        .bodySmall
        ?.copyWith(fontWeight: FontWeight.w600);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: <Widget>[
          const Expanded(child: Divider(thickness: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text('ou', style: style),
          ),
          const Expanded(child: Divider(thickness: 1)),
        ],
      ),
    );
  }
}
