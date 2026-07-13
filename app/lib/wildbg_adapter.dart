// wildbg always expects the "player on turn" to be moving from pip 24
// towards pip 1, with that player's checkers as positive numbers. Since our
// BackgammonPosition treats Player A as the one who always moves 24->1, we
// pass A's board straight through - but when it's Player B's turn we must
// mirror the board (point i -> 25-i, and flip the sign) before calling
// wildbg, then mirror its answer back.

import '../models/backgammon_position.dart';
import '../wildbg_bindings.dart';

List<int> toWildbgPips(BackgammonPosition pos, Player playerOnTurn) {
  final pips = List<int>.filled(26, 0);

  if (playerOnTurn == Player.a) {
    for (var i = 1; i <= 24; i++) {
      pips[i] = pos.points[i];
    }
    pips[25] = pos.barA;
    pips[0] = -pos.barB;
  } else {
    for (var i = 1; i <= 24; i++) {
      pips[25 - i] = -pos.points[i];
    }
    pips[25] = pos.barB;
    pips[0] = -pos.barA;
  }
  return pips;
}

PipMove fromWildbgMoveStep(MoveStep step, Player playerOnTurn) {
  final from = step.from == 25
      ? barPoint
      : (playerOnTurn == Player.a ? step.from : 25 - step.from);
  final to = step.to == 0
      ? offPoint
      : (playerOnTurn == Player.a ? step.to : 25 - step.to);
  return PipMove(from: from, to: to);
}

/// Cubeless money-game equity of [resultPosition] from [mover]'s point of
/// view, right after [mover] has finished their turn (so it's the
/// opponent's turn next). Higher is better for [mover].
double moveEquity(WildbgEngine engine, BackgammonPosition resultPosition, Player mover) {
  final opponent = mover.opponent;
  final pips = toWildbgPips(resultPosition, opponent);
  final p = engine.probabilities(pips);
  final opponentEquity =
      (p.win - (1 - p.win)) + (p.winG - p.loseG) + (p.winBg - p.loseBg);
  return -opponentEquity;
}
