import 'dart:typed_data';

import 'package:excel/excel.dart' as xlsx;

import '../constants/player_classes.dart';
import '../models/player.dart';
import '../models/team.dart';
import 'column_mapping.dart';
import 'import_result.dart';

/// Estrutura intermediária independente do pacote `excel`.
class SheetData {
  const SheetData({required this.name, required this.rows});

  final String name;
  final List<List<String?>> rows;
}

/// Parser de planilhas `.xlsx` no formato CBBC.
///
/// Aceita dois layouts:
/// - **Aba única "Atletas"**: cabeçalho com `clube`, `classe`, `atleta`,
///   `camisa`, `data de nascimento`, `genero`. Uma linha por atleta.
/// - **Uma aba por clube**: nome da aba = nome do clube. Cabeçalho sem
///   coluna `clube`.
class SpreadsheetParserService {
  const SpreadsheetParserService();

  static const Set<String> _requiredFieldsSingleSheet = <String>{
    'club',
    'class',
    'name',
    'shirt',
    'dob',
    'gender',
  };
  static const Set<String> _requiredFieldsPerSheet = <String>{
    'class',
    'name',
    'shirt',
    'dob',
    'gender',
  };

  /// Nome de aba reconhecido como modelo "aba única" (case-insensitive).
  static const Set<String> _singleSheetNames = <String>{
    'atletas',
    'jogadores',
    'players',
  };

  ImportResult parseBytes(Uint8List bytes) {
    final List<SheetData>? sheets = _readBytes(bytes);
    if (sheets == null) {
      return ImportResult.error(
        'Não foi possível ler o arquivo .xlsx.',
        ImportIssueCategory.fileUnreadable,
      );
    }
    return parseSheets(sheets);
  }

  ImportResult parseSheets(List<SheetData> sheets) {
    final List<SheetData> nonEmpty =
        sheets.where((SheetData s) => s.rows.any(_rowHasContent)).toList();
    if (nonEmpty.isEmpty) {
      return ImportResult.error(
        'A planilha não contém dados.',
        ImportIssueCategory.emptyFile,
      );
    }

    SheetData? singleSheet;
    for (final SheetData s in nonEmpty) {
      if (_singleSheetNames.contains(s.name.trim().toLowerCase())) {
        singleSheet = s;
        break;
      }
    }

    if (singleSheet != null) {
      return _parseSingleSheet(singleSheet);
    }
    return _parseMultiSheet(nonEmpty);
  }

  // -------- modo aba única --------

  ImportResult _parseSingleSheet(SheetData sheet) {
    final _HeaderInfo? header = _readHeader(sheet);
    if (header == null) {
      return ImportResult.error(
        'A aba "${sheet.name}" não tem cabeçalho válido.',
        ImportIssueCategory.missingRequiredColumn,
      );
    }

    final List<ImportIssue> issues = <ImportIssue>[];
    final List<String> missing = <String>[];
    for (final String required in _requiredFieldsSingleSheet) {
      if (!header.fieldIndex.containsKey(required)) {
        missing.add(required);
      }
    }
    if (missing.isNotEmpty) {
      issues.add(ImportIssue(
        category: ImportIssueCategory.missingRequiredColumn,
        severity: ImportIssueSeverity.error,
        message:
            'Colunas obrigatórias ausentes: ${missing.map(_fieldLabel).join(", ")}',
        sheetName: sheet.name,
      ));
      return ImportResult(teams: const <Team>[], issues: issues);
    }

    final Map<String, _ClubBucket> buckets = <String, _ClubBucket>{};
    String? competitionName;

    for (int i = header.firstDataRow; i < sheet.rows.length; i++) {
      final List<String?> row = sheet.rows[i];
      if (!_rowHasContent(row)) continue;

      final String clubName =
          (_readCell(row, header.fieldIndex['club']) ?? '').trim();
      if (clubName.isEmpty) {
        issues.add(ImportIssue(
          category: ImportIssueCategory.missingRequiredColumn,
          severity: ImportIssueSeverity.error,
          message: 'Linha sem nome do clube.',
          sheetName: sheet.name,
          rowNumber: i + 1,
        ));
        continue;
      }

      competitionName ??=
          _readOptionalString(row, header.fieldIndex['competition']);

      final String clubId = clubIdFromName(clubName);
      final _ClubBucket bucket = buckets.putIfAbsent(
        clubId,
        () => _ClubBucket(id: clubId, name: clubName),
      );
      final Player? player = _buildPlayer(
        row: row,
        header: header,
        sheetName: sheet.name,
        rowNumber: i + 1,
        clubId: clubId,
        clubName: clubName,
        issues: issues,
      );
      if (player != null) bucket.players.add(player);
    }

    final List<Team> teams = buckets.values
        .map((_ClubBucket b) =>
            Team(id: b.id, clubName: b.name, players: b.players))
        .toList();

    _detectDuplicateShirtNumbers(teams, issues, sheet.name);

    return ImportResult(
      teams: teams,
      issues: issues,
      competitionName: competitionName,
    );
  }

  // -------- modo uma aba por clube --------

  ImportResult _parseMultiSheet(List<SheetData> sheets) {
    final List<ImportIssue> issues = <ImportIssue>[];
    final List<Team> teams = <Team>[];
    String? competitionName;

    for (final SheetData sheet in sheets) {
      final _HeaderInfo? header = _readHeader(sheet);
      if (header == null) {
        issues.add(ImportIssue(
          category: ImportIssueCategory.missingRequiredColumn,
          severity: ImportIssueSeverity.error,
          message: 'A aba "${sheet.name}" não tem cabeçalho válido.',
          sheetName: sheet.name,
        ));
        continue;
      }

      final List<String> missing = <String>[];
      for (final String required in _requiredFieldsPerSheet) {
        if (!header.fieldIndex.containsKey(required)) {
          missing.add(required);
        }
      }
      if (missing.isNotEmpty) {
        issues.add(ImportIssue(
          category: ImportIssueCategory.missingRequiredColumn,
          severity: ImportIssueSeverity.error,
          message:
              'Colunas obrigatórias ausentes: ${missing.map(_fieldLabel).join(", ")}',
          sheetName: sheet.name,
        ));
        continue;
      }

      final String clubName = sheet.name.trim();
      final String clubId = clubIdFromName(clubName);
      final _ClubBucket bucket = _ClubBucket(id: clubId, name: clubName);

      for (int i = header.firstDataRow; i < sheet.rows.length; i++) {
        final List<String?> row = sheet.rows[i];
        if (!_rowHasContent(row)) continue;

        competitionName ??=
            _readOptionalString(row, header.fieldIndex['competition']);

        final Player? player = _buildPlayer(
          row: row,
          header: header,
          sheetName: sheet.name,
          rowNumber: i + 1,
          clubId: clubId,
          clubName: clubName,
          issues: issues,
        );
        if (player != null) bucket.players.add(player);
      }

      if (bucket.players.isNotEmpty) {
        teams.add(Team(
          id: bucket.id,
          clubName: bucket.name,
          players: bucket.players,
        ));
      }
    }

    _detectDuplicateShirtNumbers(teams, issues, null);

    return ImportResult(
      teams: teams,
      issues: issues,
      competitionName: competitionName,
    );
  }

  // -------- helpers --------

  Player? _buildPlayer({
    required List<String?> row,
    required _HeaderInfo header,
    required String sheetName,
    required int rowNumber,
    required String clubId,
    required String clubName,
    required List<ImportIssue> issues,
  }) {
    final String? shirtRaw =
        _readOptionalString(row, header.fieldIndex['shirt']);
    final String name =
        (_readOptionalString(row, header.fieldIndex['name']) ?? '').trim();
    final String classRaw =
        (_readOptionalString(row, header.fieldIndex['class']) ?? '').trim();
    final String dobRaw =
        (_readOptionalString(row, header.fieldIndex['dob']) ?? '').trim();
    final String? genderRaw =
        _readOptionalString(row, header.fieldIndex['gender']);

    final String playerLabel = name.isEmpty ? '(sem nome)' : name;
    bool valid = true;

    if (name.isEmpty) {
      issues.add(ImportIssue(
        category: ImportIssueCategory.missingPlayerName,
        severity: ImportIssueSeverity.error,
        message: 'Atleta sem nome completo.',
        sheetName: sheetName,
        rowNumber: rowNumber,
        clubName: clubName,
        playerLabel: playerLabel,
      ));
      valid = false;
    }

    final int? shirtNumber = parseShirtNumber(shirtRaw);
    if (shirtNumber == null) {
      issues.add(ImportIssue(
        category: ImportIssueCategory.missingShirtNumber,
        severity: ImportIssueSeverity.error,
        message: 'Atleta sem número de camisa (use 0-99).',
        sheetName: sheetName,
        rowNumber: rowNumber,
        clubName: clubName,
        playerLabel: playerLabel,
      ));
      valid = false;
    }

    double? playerClass;
    if (classRaw.isEmpty) {
      issues.add(ImportIssue(
        category: ImportIssueCategory.missingPlayerClass,
        severity: ImportIssueSeverity.error,
        message: 'Atleta sem classe funcional.',
        sheetName: sheetName,
        rowNumber: rowNumber,
        clubName: clubName,
        playerLabel: playerLabel,
      ));
      valid = false;
    } else {
      playerClass = parsePlayerClass(classRaw);
      if (playerClass == null) {
        issues.add(ImportIssue(
          category: ImportIssueCategory.invalidPlayerClass,
          severity: ImportIssueSeverity.error,
          message:
              'Classe inválida para $playerLabel — aceitas: ${kAcceptedPlayerClasses.join(", ")}.',
          sheetName: sheetName,
          rowNumber: rowNumber,
          clubName: clubName,
          playerLabel: playerLabel,
        ));
        valid = false;
      }
    }

    final DateTime? dob = parseDateOfBirth(dobRaw);
    if (dob == null) {
      issues.add(ImportIssue(
        category: ImportIssueCategory.missingDateOfBirth,
        severity: ImportIssueSeverity.error,
        message: 'Data de nascimento ausente ou inválida (use DD/MM/AAAA).',
        sheetName: sheetName,
        rowNumber: rowNumber,
        clubName: clubName,
        playerLabel: playerLabel,
      ));
      valid = false;
    }

    if (!valid) return null;

    return Player(
      id: '$clubId::${shirtNumber!}',
      clubName: clubName,
      shirtNumber: shirtNumber,
      fullName: name,
      playerClass: playerClass!,
      dateOfBirth: dob,
      gender: _genderFromString(genderRaw),
    );
  }

  void _detectDuplicateShirtNumbers(
    List<Team> teams,
    List<ImportIssue> issues,
    String? sheetName,
  ) {
    for (final Team team in teams) {
      final Map<int, int> count = <int, int>{};
      for (final Player p in team.players) {
        count[p.shirtNumber] = (count[p.shirtNumber] ?? 0) + 1;
      }
      count.forEach((int number, int n) {
        if (n > 1) {
          issues.add(ImportIssue(
            category: ImportIssueCategory.duplicateShirtNumber,
            severity: ImportIssueSeverity.warning,
            message:
                'Camisa #$number aparece $n vezes em ${team.clubName}.',
            sheetName: sheetName,
            clubName: team.clubName,
          ));
        }
      });
    }
  }

  PlayerGender _genderFromString(String? raw) {
    if (raw == null) return PlayerGender.unspecified;
    final String value = raw.trim().toLowerCase();
    if (value.isEmpty) return PlayerGender.unspecified;
    if (value == 'm' ||
        value == 'masc' ||
        value == 'masculino' ||
        value == 'masculina' ||
        value == 'male') {
      return PlayerGender.male;
    }
    if (value == 'f' ||
        value == 'fem' ||
        value == 'feminino' ||
        value == 'feminina' ||
        value == 'female') {
      return PlayerGender.female;
    }
    return PlayerGender.unspecified;
  }

  String _fieldLabel(String field) {
    switch (field) {
      case 'club':
        return 'clube';
      case 'class':
        return 'classe';
      case 'name':
        return 'atleta';
      case 'shirt':
        return 'camisa';
      case 'dob':
        return 'data de nascimento';
      case 'gender':
        return 'gênero';
      case 'competition':
        return 'competição';
      default:
        return field;
    }
  }

  String? _readCell(List<String?> row, int? index) {
    if (index == null) return null;
    if (index < 0 || index >= row.length) return null;
    return row[index];
  }

  String? _readOptionalString(List<String?> row, int? index) {
    final String? raw = _readCell(row, index);
    if (raw == null) return null;
    final String trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  bool _rowHasContent(List<String?> row) {
    for (final String? cell in row) {
      if (cell != null && cell.trim().isNotEmpty) return true;
    }
    return false;
  }

  _HeaderInfo? _readHeader(SheetData sheet) {
    for (int i = 0; i < sheet.rows.length; i++) {
      final List<String?> row = sheet.rows[i];
      if (!_rowHasContent(row)) continue;
      final Map<String, int> map = <String, int>{};
      for (int c = 0; c < row.length; c++) {
        final String? raw = row[c];
        if (raw == null) continue;
        final String? field = canonicalField(raw);
        if (field == null) continue;
        map.putIfAbsent(field, () => c);
      }
      if (map.isEmpty) continue;
      return _HeaderInfo(fieldIndex: map, firstDataRow: i + 1);
    }
    return null;
  }

  List<SheetData>? _readBytes(Uint8List bytes) {
    xlsx.Excel decoded;
    try {
      decoded = xlsx.Excel.decodeBytes(bytes);
    } catch (_) {
      return null;
    }

    final List<SheetData> result = <SheetData>[];
    decoded.tables.forEach((String name, xlsx.Sheet sheet) {
      final List<List<String?>> rows = <List<String?>>[];
      for (final List<xlsx.Data?> rawRow in sheet.rows) {
        rows.add(rawRow.map(_cellToString).toList(growable: false));
      }
      result.add(SheetData(name: name, rows: rows));
    });
    return result;
  }

  String? _cellToString(xlsx.Data? cell) {
    if (cell == null) return null;
    final dynamic value = cell.value;
    if (value == null) return null;

    if (value is xlsx.DateCellValue) {
      return _formatYmd(value.year, value.month, value.day);
    }
    if (value is xlsx.DateTimeCellValue) {
      return _formatYmd(value.year, value.month, value.day);
    }

    try {
      final dynamic inner = (value as dynamic).value;
      if (inner == null) return null;
      if (inner is String) return inner;
      if (inner is num || inner is bool) return inner.toString();
      if (inner is DateTime) {
        return _formatYmd(inner.year, inner.month, inner.day);
      }
      try {
        final dynamic maybeText = (inner as dynamic).text;
        if (maybeText is String) return maybeText;
      } catch (_) {}
      return inner.toString();
    } catch (_) {
      return value.toString();
    }
  }

  String _formatYmd(int year, int month, int day) =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';
}

class _HeaderInfo {
  const _HeaderInfo({required this.fieldIndex, required this.firstDataRow});
  final Map<String, int> fieldIndex;
  final int firstDataRow;
}

class _ClubBucket {
  _ClubBucket({required this.id, required this.name});
  final String id;
  final String name;
  final List<Player> players = <Player>[];
}
