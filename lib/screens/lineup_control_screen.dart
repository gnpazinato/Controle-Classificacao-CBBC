import 'dart:async';

import 'package:flutter/material.dart';

import '../constants/point_limits.dart';
import '../models/match_state.dart';
import '../models/player.dart';
import '../models/team.dart';
import '../services/cache_service.dart';
import '../services/vibration_service.dart';
import '../services/wakelock_controller.dart';
import '../theme/cbbc_theme.dart';
import '../widgets/cbbc_logo_header.dart';
import '../widgets/player_jersey_icon.dart';

/// Tela principal da partida.
class LineupControlScreen extends StatefulWidget {
  const LineupControlScreen({
    super.key,
    required this.initialState,
    CacheService? cache,
    VibrationService? vibration,
    WakelockController? wakelock,
  })  : _cache = cache,
        _vibration = vibration,
        _wakelock = wakelock;

  final MatchState initialState;
  final CacheService? _cache;
  final VibrationService? _vibration;
  final WakelockController? _wakelock;

  @override
  State<LineupControlScreen> createState() => _LineupControlScreenState();
}

class _LineupControlScreenState extends State<LineupControlScreen> {
  static const double _tabletBreakpoint = 720;

  late MatchState _state;
  late final CacheService _cache;
  late final VibrationService _vibration;
  late final WakelockController _wakelock;

  bool _wasOverA = false;
  bool _wasOverB = false;

  @override
  void initState() {
    super.initState();
    _state = widget.initialState;
    _cache = widget._cache ?? CacheService();
    _vibration = widget._vibration ?? const VibrationService();
    _wakelock = widget._wakelock ?? const WakelockController();
    _wasOverA = _state.isTeamAOverLimit;
    _wasOverB = _state.isTeamBOverLimit;
    unawaited(_wakelock.enable());
    unawaited(_persist());
  }

  @override
  void dispose() {
    unawaited(_wakelock.disable());
    super.dispose();
  }

  Future<void> _persist() => _cache.saveMatchState(_state);

  void _onPlayerTap(Player player, _Side side) {
    final Set<String> bucket = side == _Side.a
        ? _state.selectedTeamAIds
        : _state.selectedTeamBIds;
    final bool wasSelected = bucket.contains(player.id);
    final bool nowSelected = _state.togglePlayer(player);
    if (!wasSelected && !nowSelected) {
      _showSnack(side == _Side.a
          ? 'Apenas 5 atletas podem ser selecionados na Equipe A.'
          : 'Apenas 5 atletas podem ser selecionados na Equipe B.');
      return;
    }
    setState(() {});
    _checkLimitCrossing();
    unawaited(_persist());
  }

  void _onPointLimitChanged(double next) {
    setState(() {
      _state.setPointLimit(next);
    });
    _checkLimitCrossing();
    unawaited(_persist());
  }

  void _checkLimitCrossing() {
    final bool isOverA = _state.isTeamAOverLimit;
    final bool isOverB = _state.isTeamBOverLimit;
    if (!_wasOverA && isOverA) unawaited(_vibration.shortBuzz());
    if (!_wasOverB && isOverB) unawaited(_vibration.shortBuzz());
    _wasOverA = isOverA;
    _wasOverB = isOverB;
  }

  void _clearTeamA() {
    setState(() => _state.clearTeamA());
    _checkLimitCrossing();
    unawaited(_persist());
  }

  void _clearTeamB() {
    setState(() => _state.clearTeamB());
    _checkLimitCrossing();
    unawaited(_persist());
  }

  void _clearAll() {
    setState(() => _state.clearAll());
    _checkLimitCrossing();
    unawaited(_persist());
  }

  Future<bool> _confirmLeave() async {
    final bool? answer = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          key: const Key('leave-match-dialog'),
          title: const Text('Sair desta partida?'),
          content: const Text(
              'A seleção atual pode ser perdida.'),
          actions: <Widget>[
            TextButton(
              key: const Key('leave-stay-button'),
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Ficar'),
            ),
            FilledButton(
              key: const Key('leave-confirm-button'),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Sair'),
            ),
          ],
        );
      },
    );
    return answer ?? false;
  }

  Future<void> _onChangeTeams() async {
    final bool ok = await _confirmLeave();
    if (!mounted || !ok) return;
    Navigator.of(context).pop();
  }

  Future<void> _onLoadNewSpreadsheet() async {
    final bool ok = await _confirmLeave();
    if (!mounted || !ok) return;
    await _cache.clear();
    if (!mounted) return;
    Navigator.of(context).popUntil((Route<void> r) => r.isFirst);
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? _) async {
        if (didPop) return;
        final NavigatorState navigator = Navigator.of(context);
        final bool ok = await _confirmLeave();
        if (!ok) return;
        navigator.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const CbbcAppBarTitle(text: 'Quadra ao vivo'),
        ),
        body: SafeArea(
          child: Column(
            children: <Widget>[
              _Header(
                state: _state,
                onPointLimitChanged: _onPointLimitChanged,
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (BuildContext _, BoxConstraints c) {
                    if (c.maxWidth >= _tabletBreakpoint) {
                      return _TabletBody(
                        state: _state,
                        onPlayerTap: _onPlayerTap,
                      );
                    }
                    return _PhoneBody(
                      state: _state,
                      onPlayerTap: _onPlayerTap,
                    );
                  },
                ),
              ),
              _OperationalButtons(
                onClearTeamA: _clearTeamA,
                onClearTeamB: _clearTeamB,
                onClearAll: _clearAll,
                onChangeTeams: _onChangeTeams,
                onLoadNewSpreadsheet: _onLoadNewSpreadsheet,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _Side { a, b }

typedef _PlayerTapCallback = void Function(Player player, _Side side);

class _Header extends StatelessWidget {
  const _Header({required this.state, required this.onPointLimitChanged});

  final MatchState state;
  final ValueChanged<double> onPointLimitChanged;

  @override
  Widget build(BuildContext context) {
    final TextStyle teamStyle = Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(fontWeight: FontWeight.w700) ??
        const TextStyle(fontWeight: FontWeight.w700);
    final String? compName = state.competitionName;
    return Material(
      color: CbbcColors.offWhiteElevated,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (compName != null && compName.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  compName,
                  style: teamStyle,
                  textAlign: TextAlign.center,
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Flexible(
                  child: Text(
                    state.teamA.displayName,
                    style: teamStyle,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text('  ×  ', style: teamStyle),
                Flexible(
                  child: Text(
                    state.teamB.displayName,
                    style: teamStyle,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: <Widget>[
                Expanded(
                  child: _ScoreCell(
                    label: 'Equipe A',
                    total: state.totalPointsTeamA,
                    limit: state.effectiveLimitTeamA,
                    isOver: state.isTeamAOverLimit,
                    bonusActive: state.hasBonusInCourtTeamA,
                    keyName: 'score-team-a',
                  ),
                ),
                Expanded(
                  child: _ScoreCell(
                    label: 'Equipe B',
                    total: state.totalPointsTeamB,
                    limit: state.effectiveLimitTeamB,
                    isOver: state.isTeamBOverLimit,
                    bonusActive: state.hasBonusInCourtTeamB,
                    keyName: 'score-team-b',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Text('Pontuação máx.:', style: TextStyle(fontSize: 13)),
                const SizedBox(width: 6),
                DropdownButton<double>(
                  key: const Key('lineup-point-limit-dropdown'),
                  value: state.pointLimit,
                  isDense: true,
                  style: const TextStyle(
                    fontSize: 14,
                    color: CbbcColors.textPrimary,
                    fontWeight: FontWeight.w600,
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
                    if (next != null) onPointLimitChanged(next);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreCell extends StatelessWidget {
  const _ScoreCell({
    required this.label,
    required this.total,
    required this.limit,
    required this.isOver,
    required this.bonusActive,
    required this.keyName,
  });

  final String label;
  final double total;
  final double limit;
  final bool isOver;
  final bool bonusActive;
  final String keyName;

  @override
  Widget build(BuildContext context) {
    final Color textColor =
        isOver ? CbbcColors.alertRed : CbbcColors.textPrimary;
    return Container(
      key: Key(keyName),
      margin: const EdgeInsets.symmetric(horizontal: 3),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: isOver ? CbbcColors.alertRedSurface : Colors.transparent,
        border: Border.all(
          color: isOver ? CbbcColors.alertRed : Colors.black12,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              if (bonusActive) ...<Widget>[
                const SizedBox(width: 4),
                const Icon(
                  Icons.star,
                  size: 12,
                  color: CbbcColors.orange,
                ),
              ],
            ],
          ),
          Text(
            '${total.toStringAsFixed(1)} / ${limit.toStringAsFixed(1)}',
            style: TextStyle(
              color: textColor,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          SizedBox(
            height: 14,
            child: isOver
                ? const Text(
                    'Limite excedido.',
                    style: TextStyle(
                      color: CbbcColors.alertRed,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

class _TabletBody extends StatelessWidget {
  const _TabletBody({required this.state, required this.onPlayerTap});

  final MatchState state;
  final _PlayerTapCallback onPlayerTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(
          flex: 3,
          child: _TeamPlayerList(
            key: const Key('tablet-team-a-list'),
            team: state.teamA,
            isTeamA: true,
            selectedIds: state.selectedTeamAIds,
            onPlayerTap: (Player p) => onPlayerTap(p, _Side.a),
          ),
        ),
        Expanded(
          flex: 4,
          child: _CourtView(state: state),
        ),
        Expanded(
          flex: 3,
          child: _TeamPlayerList(
            key: const Key('tablet-team-b-list'),
            team: state.teamB,
            isTeamA: false,
            selectedIds: state.selectedTeamBIds,
            onPlayerTap: (Player p) => onPlayerTap(p, _Side.b),
          ),
        ),
      ],
    );
  }
}

class _PhoneBody extends StatelessWidget {
  const _PhoneBody({required this.state, required this.onPlayerTap});

  final MatchState state;
  final _PlayerTapCallback onPlayerTap;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: <Widget>[
          const TabBar(
            tabs: <Widget>[
              Tab(text: 'Equipe A'),
              Tab(text: 'Quadra'),
              Tab(text: 'Equipe B'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: <Widget>[
                _TeamPlayerList(
                  key: const Key('phone-team-a-list'),
                  team: state.teamA,
                  isTeamA: true,
                  selectedIds: state.selectedTeamAIds,
                  onPlayerTap: (Player p) => onPlayerTap(p, _Side.a),
                ),
                _CourtView(state: state),
                _TeamPlayerList(
                  key: const Key('phone-team-b-list'),
                  team: state.teamB,
                  isTeamA: false,
                  selectedIds: state.selectedTeamBIds,
                  onPlayerTap: (Player p) => onPlayerTap(p, _Side.b),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamPlayerList extends StatelessWidget {
  const _TeamPlayerList({
    super.key,
    required this.team,
    required this.isTeamA,
    required this.selectedIds,
    required this.onPlayerTap,
  });

  final Team team;
  final bool isTeamA;
  final Set<String> selectedIds;
  final ValueChanged<Player> onPlayerTap;

  @override
  Widget build(BuildContext context) {
    final List<Player> sortedPlayers = <Player>[...team.players]
      ..sort((Player a, Player b) =>
          a.shirtNumber.compareTo(b.shirtNumber));

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        const double headerHeight = 28;
        final double listHeight = constraints.maxHeight - headerHeight;
        final int playerCount = sortedPlayers.length;
        final double rawSlotHeight = playerCount > 0
            ? listHeight / playerCount
            : 0;
        final double slotHeight = rawSlotHeight.clamp(28.0, 56.0);

        return Column(
          mainAxisSize: MainAxisSize.max,
          children: <Widget>[
            SizedBox(
              height: headerHeight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Center(
                  child: Text(
                    team.displayName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                itemCount: sortedPlayers.length,
                itemExtent: slotHeight,
                itemBuilder: (BuildContext _, int i) {
                  final Player p = sortedPlayers[i];
                  return _PlayerCard(
                    player: p,
                    isTeamA: isTeamA,
                    selected: selectedIds.contains(p.id),
                    height: slotHeight,
                    onTap: () => onPlayerTap(p),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PlayerCard extends StatelessWidget {
  const _PlayerCard({
    required this.player,
    required this.isTeamA,
    required this.selected,
    required this.height,
    required this.onTap,
  });

  final Player player;
  final bool isTeamA;
  final bool selected;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final double iconSize = (height * 0.78).clamp(22.0, 44.0);
    final double fontSize = (height * 0.32).clamp(11.0, 14.0);
    final double verticalPadding = (height * 0.08).clamp(2.0, 6.0);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: verticalPadding * 0.4),
      child: Material(
        color: selected ? cs.primaryContainer : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(
            color: selected ? cs.primary : Colors.black12,
          ),
        ),
        child: InkWell(
          key: Key('player-card-${player.id}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 6,
              vertical: verticalPadding,
            ),
            child: Row(
              children: <Widget>[
                PlayerJerseyIcon(
                  player: player,
                  isTeamA: isTeamA,
                  size: iconSize,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _AutoShrinkText(
                    text: player.displayName,
                    maxFontSize: fontSize,
                    minFontSize: 7.0,
                    textAlign: TextAlign.left,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  player.playerClass.toStringAsFixed(1),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: fontSize,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

const String kCourtAsset = 'assets/images/court.png';

class _CourtView extends StatelessWidget {
  const _CourtView({required this.state});

  final MatchState state;

  static const double _aspectRatio = 1504 / 2816;

  static const List<Offset> _teamATargets = <Offset>[
    Offset(0.28, 0.08),
    Offset(0.72, 0.08),
    Offset(0.28, 0.26),
    Offset(0.72, 0.26),
    Offset(0.50, 0.42),
  ];

  static const List<Offset> _teamBTargets = <Offset>[
    Offset(0.28, 0.92),
    Offset(0.72, 0.92),
    Offset(0.28, 0.74),
    Offset(0.72, 0.74),
    Offset(0.50, 0.58),
  ];

  @override
  Widget build(BuildContext context) {
    final List<Player?> teamA = state.teamASlotPlayers;
    final List<Player?> teamB = state.teamBSlotPlayers;
    final bool teamAEmpty = teamA.every((Player? p) => p == null);
    final bool teamBEmpty = teamB.every((Player? p) => p == null);

    return Center(
      key: const Key('court-view'),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: AspectRatio(
          aspectRatio: _aspectRatio,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LayoutBuilder(
              builder: (BuildContext _, BoxConstraints c) {
                final double w = c.maxWidth;
                final double h = c.maxHeight;
                final double slotMaxWidth = (w * 0.34).clamp(60.0, 150.0);
                final double slotMaxHeight = (h * 0.12).clamp(46.0, 110.0);
                return Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    const Positioned.fill(
                      child: RotatedBox(
                        quarterTurns: 1,
                        child: Image(
                          image: AssetImage(kCourtAsset),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    if (teamAEmpty)
                      const Align(
                        alignment: Alignment(0, -0.55),
                        child: _CourtHint(
                          text: 'Toque nos atletas da Equipe A',
                        ),
                      ),
                    if (teamBEmpty)
                      const Align(
                        alignment: Alignment(0, 0.55),
                        child: _CourtHint(
                          text: 'Toque nos atletas da Equipe B',
                        ),
                      ),
                    for (int i = 0; i < 5; i++)
                      if (teamA[i] != null)
                        _CourtPlayerSlot(
                          player: teamA[i]!,
                          isTeamA: true,
                          target: _teamATargets[i],
                          width: w,
                          height: h,
                          slotMaxWidth: slotMaxWidth,
                          slotMaxHeight: slotMaxHeight,
                        ),
                    for (int i = 0; i < 5; i++)
                      if (teamB[i] != null)
                        _CourtPlayerSlot(
                          player: teamB[i]!,
                          isTeamA: false,
                          target: _teamBTargets[i],
                          width: w,
                          height: h,
                          slotMaxWidth: slotMaxWidth,
                          slotMaxHeight: slotMaxHeight,
                        ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _CourtHint extends StatelessWidget {
  const _CourtHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: CbbcColors.textPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _CourtPlayerSlot extends StatelessWidget {
  const _CourtPlayerSlot({
    required this.player,
    required this.isTeamA,
    required this.target,
    required this.width,
    required this.height,
    required this.slotMaxWidth,
    required this.slotMaxHeight,
  });

  final Player player;
  final bool isTeamA;
  final Offset target;
  final double width;
  final double height;
  final double slotMaxWidth;
  final double slotMaxHeight;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: width * target.dx,
      top: height * target.dy,
      child: FractionalTranslation(
        translation: const Offset(-0.5, -0.5),
        child: _CourtPlayerChip(
          player: player,
          isTeamA: isTeamA,
          maxWidth: slotMaxWidth,
          maxHeight: slotMaxHeight,
        ),
      ),
    );
  }
}

class _CourtPlayerChip extends StatelessWidget {
  const _CourtPlayerChip({
    required this.player,
    required this.isTeamA,
    required this.maxWidth,
    required this.maxHeight,
  });

  final Player player;
  final bool isTeamA;
  final double maxWidth;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final Color bg = isTeamA ? Colors.white : CbbcColors.blue;
    final Color fg = isTeamA ? CbbcColors.textPrimary : Colors.white;
    const Color border = CbbcColors.blueDeep;

    final double base = maxHeight;
    final double iconSize = (base * 0.46).clamp(18.0, 42.0);
    final double fontSize = (base * 0.15).clamp(7.5, 11.5);
    final double horizontalPad = (base * 0.06).clamp(2.0, 6.0);
    final double verticalPad = (base * 0.04).clamp(1.5, 4.0);
    final double gap = (base * 0.02).clamp(0.5, 2.0);

    return SizedBox(
      width: maxWidth,
      height: maxHeight,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPad,
          vertical: verticalPad,
        ),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: border, width: 1.2),
          borderRadius: BorderRadius.circular(6),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          children: <Widget>[
            PlayerJerseyIcon(
              player: player,
              isTeamA: isTeamA,
              size: iconSize,
            ),
            SizedBox(height: gap),
            _AutoShrinkText(
              text: player.surnameForChip.toUpperCase(),
              maxFontSize: fontSize,
              minFontSize: 6.0,
              color: fg,
              fontWeight: FontWeight.w600,
              textAlign: TextAlign.center,
            ),
            Text(
              player.playerClass.toStringAsFixed(1),
              style: TextStyle(color: fg, fontSize: fontSize, height: 1.0),
            ),
          ],
        ),
      ),
    );
  }
}

class _OperationalButtons extends StatelessWidget {
  const _OperationalButtons({
    required this.onClearTeamA,
    required this.onClearTeamB,
    required this.onClearAll,
    required this.onChangeTeams,
    required this.onLoadNewSpreadsheet,
  });

  final VoidCallback onClearTeamA;
  final VoidCallback onClearTeamB;
  final VoidCallback onClearAll;
  final VoidCallback onChangeTeams;
  final VoidCallback onLoadNewSpreadsheet;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              OutlinedButton(
                key: const Key('clear-team-a-button'),
                onPressed: onClearTeamA,
                child: const Text('Limpar Equipe A'),
              ),
              OutlinedButton(
                key: const Key('clear-team-b-button'),
                onPressed: onClearTeamB,
                child: const Text('Limpar Equipe B'),
              ),
              OutlinedButton(
                key: const Key('clear-all-button'),
                onPressed: onClearAll,
                child: const Text('Limpar tudo'),
              ),
              OutlinedButton(
                key: const Key('change-teams-button'),
                onPressed: onChangeTeams,
                child: const Text('Trocar equipes'),
              ),
              OutlinedButton(
                key: const Key('load-new-spreadsheet-button'),
                onPressed: onLoadNewSpreadsheet,
                child: const Text('Carregar outro arquivo'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Texto que encolhe proporcionalmente para caber em uma linha, com
/// ellipsis como fallback no piso.
class _AutoShrinkText extends StatelessWidget {
  const _AutoShrinkText({
    required this.text,
    required this.maxFontSize,
    this.minFontSize = 7.0,
    this.fontWeight,
    this.color,
    this.textAlign = TextAlign.left,
  });

  final String text;
  final double maxFontSize;
  final double minFontSize;
  final FontWeight? fontWeight;
  final Color? color;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final TextStyle baseStyle = TextStyle(
          fontSize: maxFontSize,
          fontWeight: fontWeight,
          color: color,
        );
        final TextPainter painter = TextPainter(
          text: TextSpan(text: text, style: baseStyle),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )..layout();

        double finalFontSize = maxFontSize;
        bool useEllipsis = false;

        if (constraints.maxWidth.isFinite && painter.size.width > 0) {
          if (painter.size.width > constraints.maxWidth) {
            final double idealFontSize =
                maxFontSize * constraints.maxWidth / painter.size.width;
            if (idealFontSize < minFontSize) {
              finalFontSize = minFontSize;
              useEllipsis = true;
            } else {
              finalFontSize = idealFontSize * 0.98;
            }
          }
        }

        return Text(
          text,
          maxLines: 1,
          softWrap: false,
          textAlign: textAlign,
          overflow: useEllipsis ? TextOverflow.ellipsis : TextOverflow.clip,
          style: TextStyle(
            fontSize: finalFontSize,
            fontWeight: fontWeight,
            color: color,
            height: 1.0,
          ),
        );
      },
    );
  }
}
