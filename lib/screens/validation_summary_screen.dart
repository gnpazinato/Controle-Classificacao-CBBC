import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/player_classes.dart';
import '../models/player.dart';
import '../models/team.dart';
import '../services/cache_service.dart';
import '../services/import_result.dart';
import '../theme/cbbc_theme.dart';
import '../widgets/cbbc_logo_header.dart';
import 'match_setup_screen.dart';
import 'missing_data_screen.dart';

class ValidationSummaryScreen extends StatefulWidget {
  const ValidationSummaryScreen({
    super.key,
    required this.result,
    this.cache,
  });

  final ImportResult result;
  final CacheService? cache;

  @override
  State<ValidationSummaryScreen> createState() =>
      _ValidationSummaryScreenState();
}

class _ValidationSummaryScreenState extends State<ValidationSummaryScreen> {
  late List<Team> _teams;

  @override
  void initState() {
    super.initState();
    _teams = <Team>[...widget.result.teams];
  }

  List<ImportIssue> get _errors => widget.result.issues
      .where((ImportIssue i) => i.severity == ImportIssueSeverity.error)
      .toList();

  List<ImportIssue> get _warnings => widget.result.issues
      .where((ImportIssue i) => i.severity == ImportIssueSeverity.warning)
      .toList();

  int get _playerCount {
    int total = 0;
    for (final Team t in _teams) {
      total += t.players.length;
    }
    return total;
  }

  void _updateShirt(Team team, Player player, int newShirt) {
    final int teamIdx = _teams.indexWhere((Team t) => t.id == team.id);
    if (teamIdx == -1) return;
    final List<Player> updated = team.players
        .map((Player p) =>
            p.id == player.id ? p.copyWith(shirtNumber: newShirt) : p)
        .toList(growable: false);
    setState(() {
      _teams[teamIdx] = team.copyWith(players: updated);
    });
  }

  void _updateClass(Team team, Player player, double newClass) {
    final int teamIdx = _teams.indexWhere((Team t) => t.id == team.id);
    if (teamIdx == -1) return;
    final List<Player> updated = team.players
        .map((Player p) =>
            p.id == player.id ? p.copyWith(playerClass: newClass) : p)
        .toList(growable: false);
    setState(() {
      _teams[teamIdx] = team.copyWith(players: updated);
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<ImportIssue> errors = _errors;
    final List<ImportIssue> warnings = _warnings;

    return Scaffold(
      appBar: AppBar(
        title: const CbbcAppBarTitle(text: 'Resumo da importação'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            _Header(
              competitionName: widget.result.competitionName,
              clubCount: _teams.length,
              playerCount: _playerCount,
              hasBlockingIssues: errors.isNotEmpty,
            ),
            const SizedBox(height: 16),
            if (errors.isNotEmpty)
              _IssueBlock(
                title: 'Erros que impedem iniciar a partida',
                color: CbbcColors.alertRedSurface,
                borderColor: CbbcColors.alertRed,
                icon: Icons.error_outline,
                issues: errors,
                trailing: FilledButton.tonalIcon(
                  key: const Key('view-issues-button'),
                  onPressed: () => _openMissingData(context),
                  icon: const Icon(Icons.list_alt),
                  label: const Text('Ver detalhes'),
                ),
              ),
            if (warnings.isNotEmpty)
              _IssueBlock(
                title: 'Avisos',
                color: const Color(0xFFFFF7E0),
                borderColor: CbbcColors.orange,
                icon: Icons.warning_amber_outlined,
                issues: warnings,
              ),
            const SizedBox(height: 8),
            ..._teamTiles(),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Carregar outro arquivo'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  key: const Key('continue-button'),
                  onPressed: errors.isEmpty && _teams.isNotEmpty
                      ? () => _continue(context)
                      : null,
                  child: const Text('Continuar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _teamTiles() {
    if (_teams.isEmpty) return const <Widget>[];

    final List<Team> sorted = <Team>[..._teams]
      ..sort((Team a, Team b) =>
          a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));

    return <Widget>[
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'Clubes encontrados',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      ...sorted.map(_teamCard),
    ];
  }

  Widget _teamCard(Team team) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: Key('team-tile-${team.id}'),
        leading: const Icon(Icons.groups_outlined, color: CbbcColors.blue),
        title: Text(team.displayName),
        subtitle: Text('${team.players.length} atleta(s) importado(s)'),
        children: _playerRows(team),
      ),
    );
  }

  List<Widget> _playerRows(Team team) {
    if (team.players.isEmpty) {
      return const <Widget>[
        Padding(
          padding: EdgeInsets.all(12),
          child: Text('Nenhum atleta importado para este clube.'),
        ),
      ];
    }
    final List<Player> sorted = <Player>[...team.players]
      ..sort((Player a, Player b) => a.shirtNumber.compareTo(b.shirtNumber));
    return <Widget>[
      const Divider(height: 1),
      for (final Player p in sorted)
        _EditablePlayerRow(
          key: ValueKey<String>('player-row-${p.id}'),
          player: p,
          siblings: team.players,
          onShirtChanged: (int newShirt) => _updateShirt(team, p, newShirt),
          onClassChanged: (double newClass) =>
              _updateClass(team, p, newClass),
        ),
    ];
  }

  Future<void> _openMissingData(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => MissingDataScreen(result: widget.result),
      ),
    );
  }

  Future<void> _continue(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => MatchSetupScreen(
          teams: _teams,
          competitionName: widget.result.competitionName,
        ),
      ),
    );
  }
}

String _formatDob(DateTime? dob) {
  if (dob == null) return '—';
  final String day = dob.day.toString().padLeft(2, '0');
  final String month = dob.month.toString().padLeft(2, '0');
  return '$day/$month/${dob.year}';
}

class _EditablePlayerRow extends StatefulWidget {
  const _EditablePlayerRow({
    super.key,
    required this.player,
    required this.siblings,
    required this.onShirtChanged,
    required this.onClassChanged,
  });

  final Player player;
  final List<Player> siblings;
  final ValueChanged<int> onShirtChanged;
  final ValueChanged<double> onClassChanged;

  @override
  State<_EditablePlayerRow> createState() => _EditablePlayerRowState();
}

class _EditablePlayerRowState extends State<_EditablePlayerRow> {
  late TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller =
        TextEditingController(text: widget.player.shirtNumber.toString());
  }

  @override
  void didUpdateWidget(_EditablePlayerRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    final String latest = widget.player.shirtNumber.toString();
    if (_controller.text != latest && _error == null) {
      _controller.text = latest;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onShirtInput(String raw) {
    final String trimmed = raw.trim();
    if (trimmed.isEmpty) {
      setState(() => _error = 'Camisa obrigatória.');
      return;
    }
    final int? parsed = int.tryParse(trimmed);
    if (parsed == null || parsed < 0 || parsed > 99) {
      setState(() => _error = 'Use um número entre 0 e 99.');
      return;
    }
    if (parsed == widget.player.shirtNumber) {
      setState(() => _error = null);
      return;
    }
    final bool duplicate = widget.siblings.any(
        (Player p) => p.id != widget.player.id && p.shirtNumber == parsed);
    if (duplicate) {
      setState(() => _error = 'Camisa #$parsed já está em uso.');
      return;
    }
    setState(() => _error = null);
    widget.onShirtChanged(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle subtitleStyle =
        theme.textTheme.bodySmall ?? const TextStyle(fontSize: 12);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              SizedBox(
                width: 56,
                child: TextField(
                  key: Key('shirt-input-${widget.player.id}'),
                  controller: _controller,
                  keyboardType: TextInputType.number,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(2),
                  ],
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 8),
                    border: const OutlineInputBorder(),
                    enabledBorder: _error != null
                        ? const OutlineInputBorder(
                            borderSide:
                                BorderSide(color: CbbcColors.alertRed),
                          )
                        : null,
                    focusedBorder: _error != null
                        ? const OutlineInputBorder(
                            borderSide: BorderSide(
                                color: CbbcColors.alertRed, width: 2),
                          )
                        : null,
                  ),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                  onChanged: _onShirtInput,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      widget.player.displayName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    Text(
                      _formatDob(widget.player.dateOfBirth),
                      style: subtitleStyle,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 72,
                child: DropdownButtonFormField<double>(
                  key: Key('class-dropdown-${widget.player.id}'),
                  value: widget.player.playerClass,
                  isDense: true,
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                    border: OutlineInputBorder(),
                  ),
                  items: kAcceptedPlayerClasses
                      .map((double v) => DropdownMenuItem<double>(
                            value: v,
                            child: Text(v.toStringAsFixed(1)),
                          ))
                      .toList(growable: false),
                  onChanged: (double? next) {
                    if (next != null) widget.onClassChanged(next);
                  },
                ),
              ),
            ],
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4),
              child: Text(
                _error!,
                style: const TextStyle(
                  color: CbbcColors.alertRed,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.competitionName,
    required this.clubCount,
    required this.playerCount,
    required this.hasBlockingIssues,
  });

  final String? competitionName;
  final int clubCount;
  final int playerCount;
  final bool hasBlockingIssues;

  @override
  Widget build(BuildContext context) {
    final TextStyle? titleStyle = Theme.of(context).textTheme.titleMedium;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (competitionName != null && competitionName!.isNotEmpty) ...<Widget>[
              Text('Competição: $competitionName', style: titleStyle),
              const SizedBox(height: 4),
            ],
            Text('Clubes: $clubCount'),
            Text('Atletas: $playerCount'),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Icon(
                  hasBlockingIssues
                      ? Icons.error_outline
                      : Icons.check_circle_outline,
                  color: hasBlockingIssues
                      ? CbbcColors.alertRed
                      : const Color(0xFF1B8A3A),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hasBlockingIssues
                        ? 'O arquivo tem erros — corrija antes de continuar.'
                        : 'Arquivo carregado com sucesso.',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _IssueBlock extends StatelessWidget {
  const _IssueBlock({
    required this.title,
    required this.color,
    required this.borderColor,
    required this.icon,
    required this.issues,
    this.trailing,
  });

  final String title;
  final Color color;
  final Color borderColor;
  final IconData icon;
  final List<ImportIssue> issues;
  final Widget? trailing;

  static const int _previewCount = 5;

  @override
  Widget build(BuildContext context) {
    final List<ImportIssue> preview = issues.length > _previewCount
        ? issues.sublist(0, _previewCount)
        : issues;
    final int remaining = issues.length - preview.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, color: borderColor),
              const SizedBox(width: 8),
              Text(
                '$title (${issues.length})',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...preview.map((ImportIssue issue) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text('• ${issue.message}'),
              )),
          if (remaining > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '… e mais $remaining',
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
            ),
          if (trailing != null) ...<Widget>[
            const SizedBox(height: 8),
            trailing!,
          ],
        ],
      ),
    );
  }
}
