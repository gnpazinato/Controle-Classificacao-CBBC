import 'package:controle_classificacao_cbbc/main.dart';
import 'package:controle_classificacao_cbbc/models/match_state.dart';
import 'package:controle_classificacao_cbbc/models/player.dart';
import 'package:controle_classificacao_cbbc/models/team.dart';
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
