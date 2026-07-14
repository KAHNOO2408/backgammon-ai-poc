// Core backgammon rules engine (no UI, no AI - just the game itself).
//
// Points are numbered 1..24 using the classic convention: Player A moves
// from 24 towards 1 (home board = points 1-6). Player B moves from 1
// towards 24 (home board = points 19-24). Positive counts in `points`
// mean Player A's checkers, negative mean Player B's checkers.

enum Player { a, b }

extension PlayerX on Player {
  Player get opponent => this == Player.a ? Player.b : Player.a;
}

/// Sentinel values used in [PipMove.from] / [PipMove.to] for the bar and
/// for bearing off, since 0 and 25 aren't valid point numbers.
const int barPoint = -1;
const int offPoint = -2;

class PipMove {
  final int from; // 1..24, or barPoint
  final int to; // 1..24, or offPoint
  const PipMove({required this.from, required this.to});

  @override
  bool operator ==(Object other) =>
      other is PipMove && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);

  @override
  String toString() {
    final f = from == barPoint ? 'bar' : '$from';
    final t = to == offPoint ? 'off' : '$to';
    return '$f/$t';
  }
}

class BackgammonPosition {
  /// Index 0 is unused; 1..24 hold signed checker counts.
  final List<int> points;
  final int barA;
  final int barB;
  final int offA;
  final int offB;

  const BackgammonPosition({
    required this.points,
    required this.barA,
    required this.barB,
    required this.offA,
    required this.offB,
  });

  factory BackgammonPosition.starting() {
    final p = List<int>.filled(25, 0);
    p[24] = 2;
    p[13] = 5;
    p[8] = 3;
    p[6] = 5;
    p[1] = -2;
    p[12] = -5;
    p[17] = -3;
    p[19] = -5;
    return BackgammonPosition(points: p, barA: 0, barB: 0, offA: 0, offB: 0);
  }

  int bar(Player p) => p == Player.a ? barA : barB;
  int off(Player p) => p == Player.a ? offA : offB;

  int countAt(Player p, int point) {
    final c = points[point];
    if (p == Player.a) return c > 0 ? c : 0;
    return c < 0 ? -c : 0;
  }

  bool isBlockedFor(Player p, int point) {
    final c = points[point];
    if (p == Player.a) return c <= -2;
    return c >= 2;
  }

  bool hasWon(Player p) => off(p) == 15;

  int _forwardDestination(Player p, int from, int die) {
    return p == Player.a ? from - die : from + die;
  }

  int _entryPoint(Player p, int die) => p == Player.a ? 25 - die : die;

  bool _isHome(Player p, int point) =>
      p == Player.a ? (point >= 1 && point <= 6) : (point >= 19 && point <= 24);

  bool allCheckersHome(Player p) {
    if (bar(p) > 0) return false;
    for (var i = 1; i <= 24; i++) {
      if (!_isHome(p, i) && countAt(p, i) > 0) return false;
    }
    return true;
  }

  /// Legal moves using a single die of value [die] for player [p].
  List<PipMove> singleDieMoves(Player p, int die) {
    final moves = <PipMove>[];

    if (bar(p) > 0) {
      final entry = _entryPoint(p, die);
      if (!isBlockedFor(p, entry)) {
        moves.add(PipMove(from: barPoint, to: entry));
      }
      return moves; // must enter from the bar before doing anything else
    }

    final canBearOff = allCheckersHome(p);

    for (var from = 1; from <= 24; from++) {
      if (countAt(p, from) == 0) continue;
      final dest = _forwardDestination(p, from, die);
      final overshoot = p == Player.a ? dest < 1 : dest > 24;

      if (!overshoot) {
        if (!isBlockedFor(p, dest)) {
          moves.add(PipMove(from: from, to: dest));
        }
        continue;
      }

      if (!canBearOff) continue;
      final pipValue = p == Player.a ? from : 25 - from;
      if (pipValue == die) {
        moves.add(PipMove(from: from, to: offPoint));
      } else if (pipValue < die) {
        // Legal only if no checker sits further from home than this one
        // (i.e. on a higher pip-value point within the home board).
        final hasFurther = p == Player.a
            ? List.generate(6 - from, (i) => from + 1 + i).any((pt) => countAt(p, pt) > 0)
            : List.generate(from - 19, (i) => 19 + i).any((pt) => countAt(p, pt) > 0);
        if (!hasFurther) {
          moves.add(PipMove(from: from, to: offPoint));
        }
      }
    }
    return moves;
  }

  /// Applies a single-die move, handling hits (sending a lone opposing
  /// checker to the bar).
  BackgammonPosition applyMove(Player p, PipMove move) {
    final newPoints = List<int>.from(points);
    var newBarA = barA;
    var newBarB = barB;
    var newOffA = offA;
    var newOffB = offB;

    if (move.from == barPoint) {
      p == Player.a ? newBarA-- : newBarB--;
    } else {
      newPoints[move.from] += (p == Player.a ? -1 : 1);
    }

    if (move.to == offPoint) {
      p == Player.a ? newOffA++ : newOffB++;
    } else {
      final destCount = newPoints[move.to];
      final opponentBlot = p == Player.a ? destCount == -1 : destCount == 1;
      if (opponentBlot) {
        newPoints[move.to] = 0;
        p == Player.a ? newBarB++ : newBarA++;
      }
      newPoints[move.to] += (p == Player.a ? 1 : -1);
    }

    return BackgammonPosition(
      points: newPoints,
      barA: newBarA,
      barB: newBarB,
      offA: newOffA,
      offB: newOffB,
    );
  }
}

/// Generates full-turn legal move sequences (using both dice, four uses for
/// doubles), enforcing "use as many dice as possible" and, when only one of
/// two different dice can be used, preferring the larger one if that's the
/// only way to use exactly one die.
class TurnGenerator {
  static List<List<PipMove>> legalSequences(
    BackgammonPosition position,
    Player p,
    List<int> dice,
  ) {
    final isDouble = dice[0] == dice[1];
    final dieValues = isDouble ? List<int>.filled(4, dice[0]) : [dice[0], dice[1]];
    final results = <List<PipMove>>[];
    final resultsDiceUsed = <List<int>>[];

    void search(BackgammonPosition pos, List<int> remaining, List<PipMove> soFar,
        List<int> diceSoFar) {
      if (remaining.isEmpty) {
        results.add(List<PipMove>.from(soFar));
        resultsDiceUsed.add(List<int>.from(diceSoFar));
        return;
      }
      final die = remaining.first;
      final rest = remaining.sublist(1);
      final moves = pos.singleDieMoves(p, die);
      if (moves.isEmpty) {
        results.add(List<PipMove>.from(soFar));
        resultsDiceUsed.add(List<int>.from(diceSoFar));
        return;
      }
      for (final m in moves) {
        search(pos.applyMove(p, m), rest, [...soFar, m], [...diceSoFar, die]);
      }
    }

    if (!isDouble) {
      search(position, [dieValues[0], dieValues[1]], [], []);
      search(position, [dieValues[1], dieValues[0]], [], []);
    } else {
      search(position, dieValues, [], []);
    }

    if (results.isEmpty) return [];

    final maxLen = results.map((s) => s.length).reduce((a, b) => a > b ? a : b);
    var bestIndices = [
      for (var i = 0; i < results.length; i++)
        if (results[i].length == maxLen) i
    ];

    if (!isDouble && maxLen == 1) {
      final high = dieValues.reduce((a, b) => a > b ? a : b);
      final canUseHigh = bestIndices.any((i) => resultsDiceUsed[i].first == high);
      if (canUseHigh) {
        bestIndices = bestIndices.where((i) => resultsDiceUsed[i].first == high).toList();
      }
    }

    final seen = <String>{};
    final deduped = <List<PipMove>>[];
    for (final i in bestIndices) {
      final s = results[i];
      final key = s.map((m) => '${m.from}-${m.to}').join(',');
      if (seen.add(key)) deduped.add(s);
    }
    return deduped;
  }
}
