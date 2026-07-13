import 'dart:math';
import 'package:flutter/material.dart';
import '../models/backgammon_position.dart';

class BoardWidget extends StatelessWidget {
  final BackgammonPosition position;
  final Set<int> legalFromPoints;
  final Set<int> legalToPoints;
  final int? selectedFrom;
  final Set<int> lastMovePoints;
  final List<PipMove>? hintMoves;
  final void Function(int point) onTapPoint;
  final bool interactive;

  const BoardWidget({
    super.key,
    required this.position,
    required this.legalFromPoints,
    required this.legalToPoints,
    required this.selectedFrom,
    required this.lastMovePoints,
    required this.onTapPoint,
    this.hintMoves,
    this.interactive = true,
  });

  static const double _pad = 4;
  static const double _barWidth = 34;
  static const double _offWidth = 46;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.35,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF8A5A34), Color(0xFF4E2F1A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF2B1810), width: 5),
              boxShadow: const [
                BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 3)),
              ],
            ),
            padding: const EdgeInsets.all(_pad),
            child: Row(
              children: [
                Expanded(
                  child: _half(
                    top: const [13, 14, 15, 16, 17, 18],
                    bottom: const [12, 11, 10, 9, 8, 7],
                  ),
                ),
                _verticalBar(),
                Expanded(
                  child: _half(
                    top: const [19, 20, 21, 22, 23, 24],
                    bottom: const [6, 5, 4, 3, 2, 1],
                  ),
                ),
                _offTray(),
              ],
            ),
          ),
          if (hintMoves != null && hintMoves!.isNotEmpty)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: _ArrowPainter(hintMoves!)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _half({required List<int> top, required List<int> bottom}) {
    return Column(
      children: [
        Expanded(
          child: Row(children: top.map((p) => Expanded(child: _pointWidget(p, top: true))).toList()),
        ),
        Expanded(
          child: Row(children: bottom.map((p) => Expanded(child: _pointWidget(p, top: false))).toList()),
        ),
      ],
    );
  }

  Widget _pointWidget(int point, {required bool top}) {
    final count = position.points[point];
    final isPlayerA = count > 0;
    final isSelected = selectedFrom == point;
    final isLegalFrom = legalFromPoints.contains(point);
    final isLegalTo = legalToPoints.contains(point);
    final isLastMove = lastMovePoints.contains(point);

    final checkers = List.generate(count.abs(), (_) => _checker(isPlayerA));
    final triangleColor =
        point.isEven ? const Color(0xFFE8C79A) : const Color(0xFF8B5A2B);

    Color? overlay;
    if (isSelected) {
      overlay = Colors.yellow.withOpacity(0.45);
    } else if (isLegalFrom || isLegalTo) {
      overlay = Colors.lightGreenAccent.withOpacity(0.4);
    } else if (isLastMove) {
      overlay = Colors.orangeAccent.withOpacity(0.35);
    }

    return GestureDetector(
      onTap: interactive ? () => onTapPoint(point) : null,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _TrianglePainter(pointsDown: top, color: triangleColor),
            ),
          ),
          if (overlay != null) Positioned.fill(child: Container(color: overlay)),
          Positioned(
            top: top ? null : 2,
            bottom: top ? 2 : null,
            left: 0,
            right: 0,
            child: Text(
              '$point',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 9,
                color: Colors.white70,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // Positioned.fill is essential here - without it, Stack pins this
          // Column to the top-left corner instead of centering it.
          Positioned.fill(
            child: Column(
              mainAxisAlignment: top ? MainAxisAlignment.start : MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: top ? checkers : checkers.reversed.toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _checker(bool isPlayerA) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 1),
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: isPlayerA
              ? [Colors.white, Colors.grey.shade300]
              : [Colors.grey.shade800, Colors.black],
        ),
        border: Border.all(color: Colors.black54, width: 1),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 1)],
      ),
    );
  }

  Widget _smallChecker(bool isPlayerA) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 1.5),
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isPlayerA ? Colors.white : Colors.black87,
        border: Border.all(color: Colors.grey.shade600),
      ),
    );
  }

  Widget _verticalBar() {
    final barIsLegalFrom = legalFromPoints.contains(barPoint);
    return GestureDetector(
      onTap: interactive ? () => onTapPoint(barPoint) : null,
      child: Container(
        width: _barWidth,
        decoration: BoxDecoration(
          color: barIsLegalFrom
              ? Colors.lightGreenAccent.withOpacity(0.4)
              : Colors.black.withOpacity(0.35),
          border: Border(
            left: BorderSide(color: Colors.black54, width: 1),
            right: BorderSide(color: Colors.black54, width: 1),
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...List.generate(position.barA, (_) => _smallChecker(true)),
                if (position.barA > 0 && position.barB > 0) const SizedBox(height: 10),
                ...List.generate(position.barB, (_) => _smallChecker(false)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _offTray() {
    final offIsLegalTo = legalToPoints.contains(offPoint);
    return GestureDetector(
      onTap: interactive ? () => onTapPoint(offPoint) : null,
      child: Container(
        width: _offWidth,
        decoration: BoxDecoration(
          color: offIsLegalTo
              ? Colors.lightGreenAccent.withOpacity(0.4)
              : Colors.black.withOpacity(0.25),
          border: Border.all(color: Colors.black54),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('You', style: TextStyle(color: Colors.white70, fontSize: 9)),
            Text('${position.offA}',
                style: const TextStyle(
                    color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text('CPU', style: TextStyle(color: Colors.white70, fontSize: 9)),
            Text('${position.offB}',
                style: const TextStyle(
                    color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

/// Computes the on-screen center of a point/bar/off, matching the layout
/// math used by [BoardWidget] above, so hint arrows land in the right spot.
class _PointLayout {
  static Offset centerOf(int point, double width, double height) {
    const pad = BoardWidget._pad;
    const barWidth = BoardWidget._barWidth;
    const offWidth = BoardWidget._offWidth;

    final usableWidth = width - pad * 2 - barWidth - offWidth;
    final halfWidth = usableWidth / 2;
    final colWidth = halfWidth / 6;
    final sectionHeight = (height - pad * 2) / 2;

    if (point == barPoint) {
      return Offset(pad + halfWidth + barWidth / 2, height / 2);
    }
    if (point == offPoint) {
      return Offset(pad + halfWidth * 2 + barWidth + offWidth / 2, height / 2);
    }

    final isTop = point >= 13 && point <= 24;
    double x;
    double y;
    if (isTop) {
      if (point <= 18) {
        final i = point - 13;
        x = pad + i * colWidth + colWidth / 2;
      } else {
        final j = point - 19;
        x = pad + halfWidth + barWidth + j * colWidth + colWidth / 2;
      }
      y = pad + sectionHeight / 2;
    } else {
      if (point >= 7) {
        final i = 12 - point;
        x = pad + i * colWidth + colWidth / 2;
      } else {
        final j = 6 - point;
        x = pad + halfWidth + barWidth + j * colWidth + colWidth / 2;
      }
      y = pad + sectionHeight + sectionHeight / 2;
    }
    return Offset(x, y);
  }
}

class _ArrowPainter extends CustomPainter {
  final List<PipMove> moves;
  _ArrowPainter(this.moves);

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.redAccent.shade700
      ..strokeWidth = 4.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Spread out parallel arrows that point in (roughly) the same direction
    // so they don't overlap each other.
    final n = moves.length;
    for (var i = 0; i < n; i++) {
      final m = moves[i];
      var from = _PointLayout.centerOf(m.from, size.width, size.height);
      var to = _PointLayout.centerOf(m.to, size.width, size.height);

      final dir = to - from;
      final len = dir.distance;
      if (len > 0) {
        final perp = Offset(-dir.dy, dir.dx) / len;
        final offsetIndex = i - (n - 1) / 2;
        final shift = perp * offsetIndex * 10;
        from += shift;
        to += shift;
      }

      canvas.drawLine(from, to, linePaint);
      _drawArrowHead(canvas, from, to, linePaint);
    }
  }

  void _drawArrowHead(Canvas canvas, Offset from, Offset to, Paint paint) {
    const arrowLength = 15.0;
    const arrowAngle = 0.45;
    final angle = (to - from).direction;
    final p1 = to -
        Offset(arrowLength * cos(angle - arrowAngle), arrowLength * sin(angle - arrowAngle));
    final p2 = to -
        Offset(arrowLength * cos(angle + arrowAngle), arrowLength * sin(angle + arrowAngle));
    final headPaint = Paint()
      ..color = paint.color
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(to.dx, to.dy)
      ..lineTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..close();
    canvas.drawPath(path, headPaint);
  }

  @override
  bool shouldRepaint(covariant _ArrowPainter oldDelegate) => true;
}

class _TrianglePainter extends CustomPainter {
  final bool pointsDown;
  final Color color;
  _TrianglePainter({required this.pointsDown, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path();
    if (pointsDown) {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width / 2, size.height);
    } else {
      path.moveTo(0, size.height);
      path.lineTo(size.width, size.height);
      path.lineTo(size.width / 2, 0);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TrianglePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.pointsDown != pointsDown;
}
