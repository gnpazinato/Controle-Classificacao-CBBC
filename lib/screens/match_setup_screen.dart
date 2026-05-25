import 'package:flutter/material.dart';

import '../constants/point_limits.dart';
import '../models/match_state.dart';
import '../models/team.dart';
import '../theme/cbbc_theme.dart';
import '../widgets/cbbc_logo_header.dart';
import 'lineup_control_screen.dart';

/// Configuração da partida: escolhe Equipe A, Equipe B, pontuação máxima
/// e bonificações da competição.
class MatchSetupScreen extends StatefulWidget {
  const MatchSetupScreen({
    super.key,
    this.teams,
    this.competitionName,
    this.restored,
  });

  final List<Team>? teams;
  final String? competitionName;
  final MatchState? restored;

  @override
  State<MatchSetupScreen> createState() => _MatchSetupScreenState();
}

class _MatchSetupScreenState extends State<MatchSetupScreen> {
  Team? _teamA;
  Team? _teamB;
  double _pointLimit = kDefaultPointLimit;
  BonusRules _bonus = const BonusRules();

  @override
  void initState() {
    super.initState();
    final MatchState? restored = widget.restored;
    if (restored != null) {
      _teamA = restored.teamA;
      _teamB = restored.teamB;
      _pointLimit = restored.pointLimit;
      _bonus = restored.bonusRules;
    }
  }

  List<Team> get _availableTeams {
    final List<Team>? raw = widget.teams;
    final List<Team> source;
    if (raw != null) {
      source = raw;
    } else {
      final MatchState? r = widget.restored;
      if (r != null) {
        source = <Team>[r.teamA, r.teamB];
      } else {
        return const <Team>[];
      }
    }
    return <Team>[...source]
      ..sort((Team a, Team b) =>
          a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
  }

  String? get _competitionName =>
      widget.competitionName ?? widget.restored?.competitionName;

  bool get _teamsAreSame =>
      _teamA != null && _teamB != null && _teamA == _teamB;

  bool get _canStart =>
      _teamA != null && _teamB != null && !_teamsAreSame;

  void _onStartPressed() {
    if (!_canStart) return;
    final Team a = _teamA!;
    final Team b = _teamB!;
    final MatchState state = MatchState(
      teamA: a,
      teamB: b,
      pointLimit: _pointLimit,
      competitionName: _competitionName,
      bonusRules: _bonus,
    );
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => LineupControlScreen(initialState: state),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Team> teams = _availableTeams;
    final String? compName = _competitionName;

    return Scaffold(
      appBar: AppBar(
        title: const CbbcAppBarTitle(text: 'Configurar partida'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (compName != null && compName.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Competição: $compName',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              _TeamDropdown(
                key: const Key('team-a-dropdown'),
                label: 'Selecionar Equipe A',
                value: _teamA,
                teams: teams,
                onChanged: (Team? value) => setState(() => _teamA = value),
              ),
              const SizedBox(height: 16),
              _TeamDropdown(
                key: const Key('team-b-dropdown'),
                label: 'Selecionar Equipe B',
                value: _teamB,
                teams: teams,
                onChanged: (Team? value) => setState(() => _teamB = value),
              ),
              const SizedBox(height: 16),
              _PointLimitDropdown(
                value: _pointLimit,
                onChanged: (double next) =>
                    setState(() => _pointLimit = next),
              ),
              const SizedBox(height: 20),
              _BonusSection(
                rules: _bonus,
                onChanged: (BonusRules r) => setState(() => _bonus = r),
              ),
              if (_teamsAreSame)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                    'Equipe A e Equipe B devem ser diferentes.',
                    key: Key('teams-equal-error'),
                    style: TextStyle(color: CbbcColors.alertRed),
                  ),
                ),
              const SizedBox(height: 24),
              if (teams.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Nenhum clube carregado. Volte e importe um arquivo.',
                  ),
                ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            key: const Key('start-match-button'),
            onPressed: _canStart ? _onStartPressed : null,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Iniciar partida'),
          ),
        ),
      ),
    );
  }
}

class _TeamDropdown extends StatelessWidget {
  const _TeamDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.teams,
    required this.onChanged,
  });

  final String label;
  final Team? value;
  final List<Team> teams;
  final ValueChanged<Team?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<Team>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: teams
          .map(
            (Team t) => DropdownMenuItem<Team>(
              value: t,
              child: Text(
                t.displayName,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: teams.isEmpty ? null : onChanged,
    );
  }
}

class _PointLimitDropdown extends StatelessWidget {
  const _PointLimitDropdown({
    required this.value,
    required this.onChanged,
  });

  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<double>(
      key: const Key('point-limit-dropdown'),
      initialValue: value,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Pontuação máxima por equipe',
        border: OutlineInputBorder(),
      ),
      items: kAcceptedPointLimits
          .map(
            (double v) => DropdownMenuItem<double>(
              value: v,
              child: Text(v.toStringAsFixed(1)),
            ),
          )
          .toList(),
      onChanged: (double? next) {
        if (next != null) onChanged(next);
      },
    );
  }
}

class _BonusSection extends StatelessWidget {
  const _BonusSection({required this.rules, required this.onChanged});

  final BonusRules rules;
  final ValueChanged<BonusRules> onChanged;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CbbcColors.blueSoft,
        border: Border.all(color: CbbcColors.blueDeep.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'A competição fornece bonificação para atletas?',
            style: text.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: CbbcColors.blueDeep,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Quando houver atleta da categoria marcada em quadra, a equipe '
            'pode chegar até 15.0 pontos sem alerta. Hard cap = 15.',
            style: text.bodySmall?.copyWith(color: CbbcColors.textSecondary),
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            key: const Key('bonus-u16-checkbox'),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text('Sub-16'),
            value: rules.youthU16,
            onChanged: (bool? v) =>
                onChanged(rules.copyWith(youthU16: v ?? false)),
          ),
          CheckboxListTile(
            key: const Key('bonus-u23-checkbox'),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text('Sub-23'),
            value: rules.youthU23,
            onChanged: (bool? v) =>
                onChanged(rules.copyWith(youthU23: v ?? false)),
          ),
          CheckboxListTile(
            key: const Key('bonus-female-checkbox'),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text('Atleta feminina'),
            value: rules.female,
            onChanged: (bool? v) =>
                onChanged(rules.copyWith(female: v ?? false)),
          ),
        ],
      ),
    );
  }
}
