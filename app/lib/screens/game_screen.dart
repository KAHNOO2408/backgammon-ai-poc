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
  List<List<PipMove>> _legalSequences = [];
  final List<PipMove> _movesMade = [];
  int? _selectedFrom;
  Set<int> _lastMovePoints = {};
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
      _movesMade.clear();
      _legalSequences = [];
      _selectedFrom = null;
      _lastMovePoints = {};
      _status = 'Tap "Roll Dice" to start.';
    });
  }

  void _rollDice() {
    if (_dice.isNotEmpty) return;
    final d1 = _random.nextInt(6) + 1;
    final d2 = _random.nextInt(6) + 1;
    final seqs = TurnGenerator.legalSequences(_position, _currentPlayer, [d1, d2]);
    final noMoves = seqs.isEmpty || seqs.first.isEmpty;

    setState(() {
      _dice = [d1, d2];
      _movesMade.clear();
      _selectedFrom = null;
      _lastMovePoints = {};
      _legalSequences = seqs;
      _status = noMoves
          ? '${_playerName(_currentPlayer)} rolled $d1-$d2 - no legal moves.'
          : '${_playerName(_currentPlayer)} rolled $d1-$d2.';
    });

    if (noMoves) {
      _finishTurnAfterDelay();
    } else if (_currentPlayer != _humanPlayer) {
      _playAiTurn();
    }
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
    if (_currentPlayer != _humanPlayer || _isAiThinking || _dice.isEmpty) return;

    if (_selectedFrom == null) {
      if (_legalFromPoints.contains(point)) {
        setState(() => _selectedFrom = point);
      }
      return;
    }

    final legalTos = _legalToPointsFor(_selectedFrom!);
    if (legalTos.contains(point)) {
      final move = PipMove(from: _selectedFrom!, to: point);
      setState(() {
        _position = _position.applyMove(_currentPlayer, move);
        _movesMade.add(move);
        _selectedFrom = null;
        _lastMovePoints = _pointsOf(move);
      });
      _checkTurnComplete();
    } else if (_legalFromPoints.contains(point)) {
      setState(() => _selectedFrom = point);
    } else {
      setState(() => _selectedFrom = null);
    }
  }

  Set<int> _pointsOf(PipMove m) => {
        if (m.from != barPoint && m.from != offPoint) m.from,
        if (m.to != barPoint && m.to != offPoint) m.to,
      };

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
          _dice = [];
        });
        return;
      }
      setState(() {
        _currentPlayer = _currentPlayer.opponent;
        _dice = [];
        _movesMade.clear();
        _legalSequences = [];
        _selectedFrom = null;
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

    // Apply the computer's moves one at a time so you can follow along.
    for (final m in converted) {
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      setState(() {
        _position = _position.applyMove(_currentPlayer, m);
        _movesMade.add(m);
        _lastMovePoints = _pointsOf(m);
        _status = 'Computer played $m';
      });
    }

    _finishTurnAfterDelay();
  }

  void _showHint() {
    if (_engine == null || _dice.isEmpty || _currentPlayer != _humanPlayer) return;
    final pips = toWildbgPips(_position, _currentPlayer);
    final wildbgMoves = _engine!.bestMove(pips, _dice[0], _dice[1]);
    final converted =
        wildbgMoves.map((m) => fromWildbgMoveStep(m, _currentPlayer)).toList();
    final text =
        converted.isEmpty ? 'No move available.' : converted.join(',  ');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Suggested move: $text'),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Backgammon'),
        actions: [
          IconButton(
            tooltip: 'Hint',
            icon: const Icon(Icons.lightbulb_outline),
            onPressed: (_dice.isNotEmpty && _currentPlayer == _humanPlayer)
                ? _showHint
                : null,
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
                  onTapPoint: _onTapPoint,
                ),
              ),
              const SizedBox(height: 12),
              DiceWidget(dice: _dice),
              if (_isAiThinking)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(),
                ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: (_dice.isEmpty && !_isAiThinking && _engine != null)
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
