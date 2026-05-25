import 'dart:typed_data';

import 'package:excel/excel.dart' as xlsx;

enum TemplateKind { singleSheet, perTeam }

/// Gera planilhas modelo `.xlsx` que o usuário pode baixar e usar como
/// ponto de partida.
///
/// Layout único exigido pelo CBBC: `clube`, `classe`, `atleta`, `camisa`,
/// `data de nascimento`, `gênero`. O modelo "aba única" usa a aba
/// `Atletas` com todas as colunas. O modelo "uma aba por clube" omite a
/// coluna `clube` (vem do nome da aba).
class TemplateGeneratorService {
  const TemplateGeneratorService();

  static const List<String> singleSheetHeaders = <String>[
    'clube',
    'classe',
    'atleta',
    'camisa',
    'data de nascimento',
    'genero',
  ];

  static const List<String> perTeamHeaders = <String>[
    'classe',
    'atleta',
    'camisa',
    'data de nascimento',
    'genero',
  ];

  static const String singleSheetTabName = 'Atletas';

  /// Distribuição de classes para o exemplo (soma = 35.5).
  static const List<double> _classDistribution = <double>[
    1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.0, 4.0, 4.5, 4.5, 4.5,
  ];

  static const List<int> _shirts = <int>[
    4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15,
  ];

  Uint8List build(TemplateKind kind) {
    switch (kind) {
      case TemplateKind.singleSheet:
        return _buildSingleSheet();
      case TemplateKind.perTeam:
        return _buildPerTeam();
    }
  }

  String filenameFor(TemplateKind kind) {
    switch (kind) {
      case TemplateKind.singleSheet:
        return 'cbbc_modelo_aba_unica.xlsx';
      case TemplateKind.perTeam:
        return 'cbbc_modelo_por_clube.xlsx';
    }
  }

  Uint8List _buildSingleSheet() {
    final xlsx.Excel excel = xlsx.Excel.createExcel();
    excel.rename(excel.getDefaultSheet()!, singleSheetTabName);
    excel.appendRow(
      singleSheetTabName,
      singleSheetHeaders
          .map((String h) => xlsx.TextCellValue(h))
          .toList(growable: false),
    );
    for (final _SampleRow row in _expandSampleRows()) {
      excel.appendRow(singleSheetTabName, <xlsx.CellValue?>[
        xlsx.TextCellValue(row.club),
        xlsx.TextCellValue(_formatPlayerClass(row.playerClass)),
        xlsx.TextCellValue(row.fullName),
        xlsx.IntCellValue(row.shirt),
        xlsx.TextCellValue(_formatDob(row.dob)),
        xlsx.TextCellValue(row.gender),
      ]);
    }
    return _encode(excel);
  }

  Uint8List _buildPerTeam() {
    final xlsx.Excel excel = xlsx.Excel.createExcel();
    final String? defaultSheet = excel.getDefaultSheet();

    final Map<String, List<_SampleRow>> rowsByClub =
        <String, List<_SampleRow>>{};
    for (final _SampleRow r in _expandSampleRows()) {
      rowsByClub.putIfAbsent(r.club, () => <_SampleRow>[]).add(r);
    }

    for (final String club in rowsByClub.keys) {
      excel.appendRow(
        club,
        perTeamHeaders
            .map((String h) => xlsx.TextCellValue(h))
            .toList(growable: false),
      );
      for (final _SampleRow row in rowsByClub[club]!) {
        excel.appendRow(club, <xlsx.CellValue?>[
          xlsx.TextCellValue(_formatPlayerClass(row.playerClass)),
          xlsx.TextCellValue(row.fullName),
          xlsx.IntCellValue(row.shirt),
          xlsx.TextCellValue(_formatDob(row.dob)),
          xlsx.TextCellValue(row.gender),
        ]);
      }
    }

    if (defaultSheet != null && !rowsByClub.containsKey(defaultSheet)) {
      excel.delete(defaultSheet);
    }

    return _encode(excel);
  }

  Uint8List _encode(xlsx.Excel excel) {
    final List<int>? bytes = excel.encode();
    if (bytes == null) {
      throw StateError('Falha ao codificar o modelo .xlsx.');
    }
    return Uint8List.fromList(bytes);
  }

  static String _formatPlayerClass(double value) {
    final String fixed = value.toStringAsFixed(1);
    return fixed.replaceAll('.', ',');
  }

  /// `1995-04-15` -> `15/04/1995`.
  static String _formatDob(String iso) {
    final List<String> parts = iso.split('-');
    if (parts.length != 3) return iso;
    return '${parts[2]}/${parts[1]}/${parts[0]}';
  }

  Iterable<_SampleRow> _expandSampleRows() sync* {
    for (int t = 0; t < _sampleClubs.length; t++) {
      final _SampleClub club = _sampleClubs[t];
      for (int i = 0; i < 12; i++) {
        yield _SampleRow(
          club: club.name,
          fullName: club.athletes[i],
          gender: club.genders[i],
          shirt: _shirts[i],
          playerClass: _classDistribution[i],
          dob: _dobFor(t, i),
        );
      }
    }
  }

  static String _dobFor(int teamIndex, int playerIndex) {
    const List<int> years = <int>[
      1988, 1990, 1992, 1994, 1996, 1998,
      2000, 2002, 2004, 2007, 2009, 2011,
    ];
    final int year = years[playerIndex];
    final int day = ((teamIndex * 7 + playerIndex * 3) % 27) + 1;
    final int month = ((teamIndex * 3 + playerIndex * 5) % 12) + 1;
    final String d = day.toString().padLeft(2, '0');
    final String m = month.toString().padLeft(2, '0');
    return '$year-$m-$d';
  }
}

class _SampleRow {
  const _SampleRow({
    required this.club,
    required this.fullName,
    required this.gender,
    required this.shirt,
    required this.playerClass,
    required this.dob,
  });

  final String club;
  final String fullName;
  final String gender;
  final int shirt;
  final double playerClass;
  final String dob;
}

class _SampleClub {
  const _SampleClub({
    required this.name,
    required this.athletes,
    required this.genders,
  });

  final String name;
  final List<String> athletes;
  final List<String> genders;
}

const List<_SampleClub> _sampleClubs = <_SampleClub>[
  _SampleClub(
    name: 'ADD Vitória',
    athletes: <String>[
      'João Silva', 'Pedro Souza', 'Lucas Oliveira', 'Rafael Costa',
      'Bruno Lima', 'Felipe Santos', 'Thiago Ferreira', 'Gustavo Almeida',
      'Mariana Ribeiro', 'Camila Alves', 'Carolina Mendes', 'Beatriz Pinto',
    ],
    genders: <String>[
      'M', 'M', 'M', 'M', 'M', 'M', 'M', 'M', 'F', 'F', 'F', 'F',
    ],
  ),
  _SampleClub(
    name: 'Cruzeiro CR',
    athletes: <String>[
      'André Pereira', 'Daniel Carvalho', 'Eduardo Rodrigues', 'Henrique Dias',
      'Igor Barbosa', 'Mateus Nunes', 'Renato Teixeira', 'Vitor Cardoso',
      'Larissa Rocha', 'Juliana Martins', 'Fernanda Gomes', 'Amanda Sousa',
    ],
    genders: <String>[
      'M', 'M', 'M', 'M', 'M', 'M', 'M', 'M', 'F', 'F', 'F', 'F',
    ],
  ),
  _SampleClub(
    name: 'Magic Wheels',
    athletes: <String>[
      'Leonardo Castro', 'Marcos Vieira', 'Otavio Borges', 'Patrick Moreira',
      'Roberto Silveira', 'Samuel Costa', 'Tiago Andrade', 'William Freitas',
      'Isabela Lopes', 'Natália Cunha', 'Letícia Moura', 'Bruna Pereira',
    ],
    genders: <String>[
      'M', 'M', 'M', 'M', 'M', 'M', 'M', 'M', 'F', 'F', 'F', 'F',
    ],
  ),
  _SampleClub(
    name: 'BCR Joinville',
    athletes: <String>[
      'Antonio Reis', 'Carlos Nogueira', 'Diego Camargo', 'Eduardo Pires',
      'Fabio Mendonça', 'Geovane Ribeiro', 'Hugo Tavares', 'Ivan Castro',
      'Patricia Almeida', 'Renata Souza', 'Sofia Lima', 'Yasmin Costa',
    ],
    genders: <String>[
      'M', 'M', 'M', 'M', 'M', 'M', 'M', 'M', 'F', 'F', 'F', 'F',
    ],
  ),
];
