import 'package:controle_classificacao_cbbc/constants/player_classes.dart';
import 'package:controle_classificacao_cbbc/main.dart';
import 'package:controle_classificacao_cbbc/models/match_state.dart';
import 'package:controle_classificacao_cbbc/models/player.dart';
import 'package:controle_classificacao_cbbc/models/team.dart';
import 'package:controle_classificacao_cbbc/services/spreadsheet_parser_service.dart';
import 'package:controle_classificacao_cbbc/services/import_result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('home renderiza com logo CBBC e botão de carregar arquivo',
      (WidgetTester tester) async {
    await tester.pumpWidget(const CbbcApp());
    await tester.pump();

    expect(find.byKey(const Key('cbbc-brand-logo')), findsOneWidget);
    expect(find.byKey(const Key('load-spreadsheet-button')), findsOneWidget);
    expect(find.text('Carregar planilha (.xlsx) ou PDF'), findsOneWidget);
  });

  group('BonusRules', () {
    final DateTime ref = DateTime.utc(2026, 5, 25);

    Player makePlayer({
      required int shirt,
      required double cls,
      required DateTime dob,
      required PlayerGender gender,
    }) {
      return Player(
        id: 'p-$shirt',
        clubName: 'X',
        shirtNumber: shirt,
        fullName: 'Atleta $shirt',
        playerClass: cls,
        dateOfBirth: dob,
        gender: gender,
      );
    }

    test('atleta sub-16 qualifica quando regra ativa', () {
      const BonusRules rules = BonusRules(youthU16: true);
      final Player young =
          makePlayer(shirt: 4, cls: 4.5, dob: DateTime.utc(2012, 1, 1), gender: PlayerGender.male);
      expect(rules.qualifies(young, ref), isTrue);
    });

    test('atleta feminina qualifica quando regra ativa', () {
      const BonusRules rules = BonusRules(female: true);
      final Player adult = makePlayer(
          shirt: 5, cls: 4.5, dob: DateTime.utc(1990, 1, 1), gender: PlayerGender.female);
      expect(rules.qualifies(adult, ref), isTrue);
    });

    test('regras inativas → sem qualificação', () {
      const BonusRules rules = BonusRules();
      final Player young = makePlayer(
          shirt: 6, cls: 4.5, dob: DateTime.utc(2012, 1, 1), gender: PlayerGender.female);
      expect(rules.qualifies(young, ref), isFalse);
    });
  });

  group('SpreadsheetParserService — formato seccionado CBBC', () {
    test('atleta sem classe entra com playerClass null (aviso, não bloqueia)', () {
      // Dois blocos pra ativar o modo seccionado.
      final SheetData sheet = SheetData(
        name: 'Planilha1',
        rows: <List<String?>>[
          <String?>[null, null, null, 'APP', null],
          <String?>[null, 'CLASSE', 'NASCIMENTO', 'ATLETA', 'Nº'],
          <String?>[null, '4.0', '01/10/1995', 'ADRIENNE OLIVEIRA', '11'],
          <String?>[null, null, '02/06/1992', 'SEM CLASSE PRA TESTE', '8'],
          <String?>[null, null, null, null, null],
          <String?>[null, null, null, 'OUTRO CLUBE', null],
          <String?>[null, 'CLASSE', 'NASCIMENTO', 'ATLETA', 'Nº'],
          <String?>[null, '2.0', '15/03/1990', 'OUTRA ATLETA', '3'],
        ],
      );

      const SpreadsheetParserService parser = SpreadsheetParserService();
      final ImportResult result = parser.parseSheets(<SheetData>[sheet]);

      expect(result.hasBlockingIssues, isFalse,
          reason: result.issues.map((ImportIssue i) => i.message).join('\n'));

      final Team app =
          result.teams.firstWhere((Team t) => t.clubName == 'APP');
      expect(app.players, hasLength(2));

      final Player adrienne =
          app.players.firstWhere((Player p) => p.shirtNumber == 11);
      final Player semClasse =
          app.players.firstWhere((Player p) => p.shirtNumber == 8);
      expect(adrienne.playerClass, 4.0);
      expect(semClasse.playerClass, isNull);
      expect(semClasse.hasValidClass, isFalse);

      // O aviso (warning, não error) precisa aparecer pra usuária ver.
      final List<ImportIssue> warnings = result.issues
          .where((ImportIssue i) =>
              i.severity == ImportIssueSeverity.warning &&
              i.category == ImportIssueCategory.missingPlayerClass)
          .toList();
      expect(warnings, hasLength(1));
    });

    test('uma aba com blocos por clube, sem coluna de gênero', () {
      // Reproduz o layout da planilha "RELAÇÃO DE ATLETAS" da CBBC.
      final SheetData sheet = SheetData(
        name: 'RELAÇÃO DE ATLETAS',
        rows: <List<String?>>[
          <String?>[null, null, null, 'RELAÇÃO DE ATLETAS', null],
          <String?>[null, null, null, null, null],
          <String?>[null, null, null, 'APP', null],
          <String?>[null, 'CLASSE', 'NASCIMENTO', 'ATLETA', 'Nº'],
          <String?>[null, '1.5', '21/08/2000', 'STEPHANIA SILVA JACINTO', '7'],
          <String?>[null, '4.0', '01/10/1995', 'ADRIENNE OLIVEIRA DE SOUZA', '11'],
          <String?>[null, '1.0', '16/01/1987', 'CRISTIANE MEDINA RIBAS', '17'],
          <String?>[null, null, null, null, null],
          <String?>[null, null, null, 'ALL STAR RODAS PARÁ', null],
          <String?>[null, 'CLASSE', 'NASCIMENTO', 'ATLETA', 'Nº'],
          <String?>[null, '2.0', '26/09/1976', 'CLEONETE DE NAZARÉ SANTOS REIS', '4'],
          <String?>[null, '1.5', '15/06/1997', 'GRAZIELE GONCALVES DA SILVA', '5'],
        ],
      );

      const SpreadsheetParserService parser = SpreadsheetParserService();
      final ImportResult result = parser.parseSheets(<SheetData>[sheet]);

      expect(result.hasBlockingIssues, isFalse,
          reason: result.issues.map((ImportIssue i) => i.message).join('\n'));
      expect(result.teams, hasLength(2));

      final Team app = result.teams.firstWhere((Team t) => t.clubName == 'APP');
      final Team rodas = result.teams
          .firstWhere((Team t) => t.clubName == 'ALL STAR RODAS PARÁ');
      expect(app.players, hasLength(3));
      expect(rodas.players, hasLength(2));

      final Player stephania =
          app.players.firstWhere((Player p) => p.shirtNumber == 7);
      expect(stephania.fullName, 'STEPHANIA SILVA JACINTO');
      expect(stephania.playerClass, 1.5);
      expect(stephania.dateOfBirth, DateTime.utc(2000, 8, 21));
      expect(stephania.gender, PlayerGender.unspecified);
    });
  });

  group('parsePlayerClass — tolerância a lixo de planilha', () {
    test('formatos simples', () {
      expect(parsePlayerClass('1.5'), 1.5);
      expect(parsePlayerClass('1,5'), 1.5);
      expect(parsePlayerClass('4'), 4.0);
      expect(parsePlayerClass('4.0'), 4.0);
    });
    test('NBSP e espaços invisíveis em volta', () {
      expect(parsePlayerClass(' 1.5 '), 1.5);
      expect(parsePlayerClass(' 2.5 '), 2.5);
      expect(parsePlayerClass('​3.5'), 3.5); // zero-width space
    });
    test('variantes Unicode de vírgula/ponto', () {
      expect(parsePlayerClass('1٫5'), 1.5); // árabe
      expect(parsePlayerClass('2．5'), 2.5); // fullwidth full stop
    });
    test('valor inválido rejeitado', () {
      expect(parsePlayerClass('5.5'), isNull);
      expect(parsePlayerClass('abc'), isNull);
      expect(parsePlayerClass(''), isNull);
      expect(parsePlayerClass('1.5.0'), isNull);
    });
    test('classe meia que o Excel virou data (ISO yyyy-MM-dd)', () {
      // "1.5" digitado pelo usuário, Excel converteu pra 1º/5 → 2026-05-01
      expect(parsePlayerClass('2026-05-01'), 1.5);
      expect(parsePlayerClass('2026-05-02'), 2.5);
      expect(parsePlayerClass('2026-05-03'), 3.5);
      expect(parsePlayerClass('2026-05-04'), 4.5);
    });
    test('classe meia em formato BR DD/MM/YYYY', () {
      expect(parsePlayerClass('01/05/2026'), 1.5);
      expect(parsePlayerClass('04/05/2026'), 4.5);
    });
    test('data real que não bate com classe não é confundida', () {
      // 15 de maio de 1990 = 15.5 → não é classe válida → retorna null
      expect(parsePlayerClass('1990-05-15'), isNull);
    });
  });

  group('MatchState.effectiveLimit', () {
    final DateTime ref = DateTime.utc(2026, 5, 25);

    test('sem bonus → limite = pointLimit', () {
      final Team teamA = Team(id: 'a', clubName: 'A', players: <Player>[
        Player(
            id: 'a::4',
            clubName: 'A',
            shirtNumber: 4,
            fullName: 'X',
            playerClass: 4.5,
            dateOfBirth: DateTime.utc(1990, 1, 1),
            gender: PlayerGender.male),
      ]);
      final Team teamB = Team(id: 'b', clubName: 'B');
      final MatchState s = MatchState(
        teamA: teamA,
        teamB: teamB,
        pointLimit: 14.0,
        referenceDate: ref,
      );
      s.selectPlayer(teamA.players.first);
      expect(s.effectiveLimitTeamA, 14.0);
      expect(s.isTeamAOverLimit, isFalse);
    });

    test('bonus feminina ativa + atleta feminina em quadra → cap 15', () {
      final Player f = Player(
          id: 'a::4',
          clubName: 'A',
          shirtNumber: 4,
          fullName: 'Atleta F',
          playerClass: 4.5,
          dateOfBirth: DateTime.utc(1990, 1, 1),
          gender: PlayerGender.female);
      final Player m1 = Player(
          id: 'a::5',
          clubName: 'A',
          shirtNumber: 5,
          fullName: 'Atleta M1',
          playerClass: 4.5,
          dateOfBirth: DateTime.utc(1990, 1, 1),
          gender: PlayerGender.male);
      final Player m2 = Player(
          id: 'a::6',
          clubName: 'A',
          shirtNumber: 6,
          fullName: 'Atleta M2',
          playerClass: 4.5,
          dateOfBirth: DateTime.utc(1990, 1, 1),
          gender: PlayerGender.male);
      final Team teamA =
          Team(id: 'a', clubName: 'A', players: <Player>[f, m1, m2]);
      final Team teamB = Team(id: 'b', clubName: 'B');
      final MatchState s = MatchState(
        teamA: teamA,
        teamB: teamB,
        pointLimit: 13.0,
        referenceDate: ref,
        bonusRules: const BonusRules(female: true),
      );
      s.selectPlayer(f);
      s.selectPlayer(m1);
      s.selectPlayer(m2);
      // total = 13.5 > 13 mas <= 15 e bonus em quadra → não excede.
      expect(s.totalPointsTeamA, 13.5);
      expect(s.effectiveLimitTeamA, 15.0);
      expect(s.isTeamAOverLimit, isFalse);

      // remove a atleta feminina → cap volta a 13 e excede.
      s.deselectPlayer(f);
      expect(s.totalPointsTeamA, 9.0);
      expect(s.effectiveLimitTeamA, 13.0);
      expect(s.isTeamAOverLimit, isFalse);
    });
  });
}
