import 'dart:math';
import 'package:flutter/material.dart';
import '../models/backgammon_position.dart';
import '../wildbg_adapter.dart';
import '../widgets/board_widget.dart';
import '../widgets/dice_widget.dart';
import '../wildbg_bindings.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late BackgammonPosition _position;
  Player _currentPlayer = Player.a;
  final Player _humanPlayer = Player.a;
  List<int> _dice = [];
  bool _rolled = false;
  List<List<PipMove>> _legalSequences = [];
  final List<PipMove> _movesMade = [];
  int? _selectedFrom;
  Set<int> _lastMovePoints = {};
  List<PipMove> _autoHint = [];
  PipMove? _animatingMove;
  bool _animatingIsPlayerA = true;
  final List<BackgammonPosition> _positionHistory = [];
  String _status = 'Tap "Roll Dice" to start.';
  bool _isAiThinking = false;
  WildbgEngine? _engine;
  String? _engineError;
  final _random = Random();

  @override
  void initState() {
    super.initState();
    _position = BackgammonPosition.starting();
    try {
      _engine = WildbgEngine();
    } catch (e) {
      _engineError = e.toString();
    }
  }

  @override
  void dispose() {
    _engine?.dispose();
    super.dispose();
  }

  String _playerName(Player p) => p == _humanPlayer ? 'You' : 'Computer';

  void _newGame() {
    setState(() {
      _position = BackgammonPosition.starting();
      _currentPlayer = Player.a;
      _dice = [];
      _rolled = false;
      _movesMade.clear();
      _legalSequences = [];
      _selectedFrom = null;
      _lastMovePoints = {};
      _autoHint = [];
      _animatingMove = null;
      _positionHistory.clear();
      _status = 'Tap "Roll Dice" to start.';
    });
  }

  void _rollDice() {
    if (_rolled) return;
    final d1 = _random.nextInt(6) + 1;
    final d2 = _random.nextInt(6) + 1;
    final seqs = TurnGenerator.legalSequences(_position, _currentPlayer, [d1, d2]);
    final noMoves = seqs.isEmpty || seqs.first.isEmpty;

    setState(() {
      _dice = [d1, d2];
      _rolled = true;
      _movesMade.clear();
      _positionHistory.clear();
      _selectedFrom = null;
      _lastMovePoints = {};
      _legalSequences = seqs;
      _autoHint = [];
      _status = noMoves
          ? '${_playerName(_currentPlayer)} rolled $d1-$d2 - no legal moves.'
          : '${_playerName(_currentPlayer)} rolled $d1-$d2.';
    });

    // Wait for the dice-rolling animation to settle before showing the hint,
    // so the arrow doesn't appear while the numbers are still spinning.
    if (!noMoves && _currentPlayer == _humanPlayer && _engine != null) {
      final rollToken = _dice;
      Future.delayed(const Duration(milliseconds: 620), () {
        if (!mounted || !_rolled || _dice != rollToken) return;
        setState(() => _autoHint = _computeBestMove(d1, d2));
      });
    }

    if (noMoves) {
      _finishTurnAfterDelay();
    } else if (_currentPlayer != _humanPlayer) {
      _playAiTurn();
    }
  }

  List<PipMove> _computeBestMove(int d1, int d2) {
    final pips = toWildbgPips(_position, _currentPlayer);
    final wildbgMoves = _engine!.bestMove(pips, d1, d2);
    return wildbgMoves.map((m) => fromWildbgMoveStep(m, _currentPlayer)).toList();
  }

  Set<int> get _legalFromPoints {
    final froms = <int>{};
    for (final seq in _legalSequences) {
      if (seq.length > _movesMade.length && _matchesPrefix(seq)) {
        froms.add(seq[_movesMade.length].from);
      }
    }
    return froms;
  }

  Set<int> _legalToPointsFor(int from) {
    final tos = <int>{};
    for (final seq in _legalSequences) {
      if (seq.length > _movesMade.length &&
          _matchesPrefix(seq) &&
          seq[_movesMade.length].from == from) {
        tos.add(seq[_movesMade.length].to);
      }
    }
    return tos;
  }

  bool _matchesPrefix(List<PipMove> seq) {
    for (var i = 0; i < _movesMade.length; i++) {
      if (seq[i] != _movesMade[i]) return false;
    }
    return true;
  }

  void _onTapPoint(int point) {
    if (_currentPlayer != _humanPlayer || _isAiThinking || !_rolled) return;

    if (_selectedFrom == null) {
      if (_legalFromPoints.contains(point)) {
        setState(() {
          _selectedFrom = point;
        });
      }
      return;
    }

    final legalTos = _legalToPointsFor(_selectedFrom!);
    if (legalTos.contains(point)) {
      final move = PipMove(from: _selectedFrom!, to: point);
      setState(() => _selectedFrom = null);
      _animateAndApplyMove(move);
    } else if (_legalFromPoints.contains(point)) {
      setState(() => _selectedFrom = point);
    } else {
      setState(() => _selectedFrom = null);
    }
  }

  Future<void> _animateAndApplyMove(PipMove move) async {
    _positionHistory.add(_position);
    setState(() {
      _animatingMove = move;
      _animatingIsPlayerA = _currentPlayer == Player.a;
    });
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    setState(() {
      _position = _position.applyMove(_currentPlayer, move);
      _movesMade.add(move);
      _lastMovePoints = _pointsOf(move);
      _autoHint = [];
      _animatingMove = null;
    });
    _checkTurnComplete();
  }

  Set<int> _pointsOf(PipMove m) => {
        if (m.from != barPoint && m.from != offPoint) m.from,
        if (m.to != barPoint && m.to != offPoint) m.to,
      };

  bool get _canUndo =>
      _positionHistory.isNotEmpty &&
      _currentPlayer == _humanPlayer &&
      _animatingMove == null &&
      !_isAiThinking;

  void _undoLastMove() {
    if (!_canUndo) return;
    setState(() {
      _position = _positionHistory.removeLast();
      _movesMade.removeLast();
      _selectedFrom = null;
      _lastMovePoints = _movesMade.isNotEmpty ? _pointsOf(_movesMade.last) : {};
      _autoHint =
          (_dice.length == 2 && _engine != null) ? _computeBestMove(_dice[0], _dice[1]) : [];
      _status = '${_playerName(_currentPlayer)} undid a move.';
    });
  }

  void _checkTurnComplete() {
    final maxLen = _legalSequences.isEmpty ? 0 : _legalSequences.first.length;
    if (_movesMade.length >= maxLen) {
      _finishTurnAfterDelay();
    }
  }

  void _finishTurnAfterDelay() {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      if (_position.hasWon(_currentPlayer)) {
        setState(() {
          _status = '${_playerName(_currentPlayer)} wins! 🎉';
          _rolled = false;
        });
        return;
      }
      setState(() {
        _currentPlayer = _currentPlayer.opponent;
        _rolled = false;
        _movesMade.clear();
        _legalSequences = [];
        _selectedFrom = null;
        _autoHint = [];
        _status = "${_playerName(_currentPlayer)}'s turn - tap Roll Dice.";
      });
    });
  }

  Future<void> _playAiTurn() async {
    setState(() => _isAiThinking = true);
    await Future.delayed(const Duration(milliseconds: 500));

    final engine = _engine;
    if (engine == null || _legalSequences.isEmpty || _legalSequences.first.isEmpty) {
      setState(() => _isAiThinking = false);
      _finishTurnAfterDelay();
      return;
    }

    final pips = toWildbgPips(_position, _currentPlayer);
    final wildbgMoves = engine.bestMove(pips, _dice[0], _dice[1]);
    final converted =
        wildbgMoves.map((m) => fromWildbgMoveStep(m, _currentPlayer)).toList();

    setState(() => _isAiThinking = false);

    // Animate and apply the computer's moves one at a time so you can follow along.
    for (final m in converted) {
      if (!mounted) return;
      setState(() {
        _animatingMove = m;
        _animatingIsPlayerA = _currentPlayer == Player.a;
      });
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      setState(() {
        _position = _position.applyMove(_currentPlayer, m);
        _movesMade.add(m);
        _lastMovePoints = _pointsOf(m);
        _animatingMove = null;
        _status = 'Computer played $m';
      });
      await Future.delayed(const Duration(milliseconds: 150));
    }

    _finishTurnAfterDelay();
  }

  void _showAllMoves() {
    if (_engine == null || !_rolled || _currentPlayer != _humanPlayer || _movesMade.isNotEmpty) {
      return;
    }
    final seen = <String>{};
    final options = <_MoveOption>[];
    for (final seq in _legalSequences) {
      final key = seq.map((m) => '${m.from}-${m.to}').join(',');
      if (!seen.add(key)) continue;
      var pos = _position;
      for (final m in seq) {
        pos = pos.applyMove(_currentPlayer, m);
      }
      final eq = moveEquity(_engine!, pos, _currentPlayer);
      options.add(_MoveOption(seq, eq));
    }
    if (options.isEmpty) return;
    options.sort((a, b) => b.equity.compareTo(a.equity));
    final best = options.first.equity;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('All moves (best to worst)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: options.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final opt = options[i];
                      final error = best - opt.equity;
                      return ListTile(
                        dense: true,
                        leading: Text('${i + 1}'),
                        title: Text(opt.moves.join(',  ')),
                        trailing: Text(
                          i == 0 ? 'Best' : '-${error.toStringAsFixed(3)}',
                          style: TextStyle(
                            color: i == 0 ? Colors.green.shade700 : Colors.black54,
                            fontWeight: i == 0 ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        onTap: () {
                          setState(() => _autoHint = opt.moves);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Backgammon'),
        actions: [
          IconButton(
            tooltip: 'Undo move',
            icon: const Icon(Icons.undo),
            onPressed: _canUndo ? _undoLastMove : null,
          ),
          IconButton(
            tooltip: 'New game',
            icon: const Icon(Icons.refresh),
            onPressed: _newGame,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              if (_engineError != null)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'AI engine failed to load: $_engineError',
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text(
                  _status,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: BoardWidget(
                  position: _position,
                  legalFromPoints: _selectedFrom == null ? _legalFromPoints : {},
                  legalToPoints:
                      _selectedFrom == null ? {} : _legalToPointsFor(_selectedFrom!),
                  selectedFrom: _selectedFrom,
                  lastMovePoints: _lastMovePoints,
                  animatingMove: _animatingMove,
                  animatingIsPlayerA: _animatingIsPlayerA,
                  onTapPoint: _onTapPoint,
                ),
              ),
              const SizedBox(height: 12),
              DiceWidget(dice: _dice),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _autoHint.isNotEmpty ? 'Suggested move' : 'Hint board',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: (_rolled && _currentPlayer == _humanPlayer && _movesMade.isEmpty)
                        ? _showAllMoves
                        : null,
                    child: const Text('All moves', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: BoardWidget(
                  position: _position,
                  legalFromPoints: const {},
                  legalToPoints: const {},
                  selectedFrom: null,
                  lastMovePoints: const {},
                  hintMoves: _autoHint,
                  hintMover: _currentPlayer,
                  onTapPoint: (_) {},
                  interactive: false,
                ),
              ),
              if (_isAiThinking)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(),
                ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: (!_rolled && !_isAiThinking && _engine != null)
                    ? _rollDice
                    : null,
                child: const Text('Roll Dice'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoveOption {
  final List<PipMove> moves;
  final double equity;
  _MoveOption(this.moves, this.equity);
}
