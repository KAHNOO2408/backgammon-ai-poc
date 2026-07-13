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

  static const double _padXFrac = 0.03;
  static const double _padYFrac = 0.045;
  static const double _barFrac = 0.045;
  static const double _offWidth = 46;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
        Expanded(
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                final h = constraints.maxHeight;
                final padX = w * _padXFrac;
                final padY = h * _padYFrac;
                final barW = w * _barFrac;

                return Stack(
                  children: [
                    Container(
                      decoration: const BoxDecoration(
                        image: DecorationImage(
                          image: AssetImage('assets/images/wood_board.png'),
                          fit: BoxFit.fill,
                        ),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: padX, vertical: padY),
                      child: Row(
                        children: [
                          Expanded(
                            child: _half(
                              top: const [13, 14, 15, 16, 17, 18],
                              bottom: const [12, 11, 10, 9, 8, 7],
                            ),
                          ),
                          _verticalBar(barW),
                          Expanded(
                            child: _half(
                              top: const [19, 20, 21, 22, 23, 24],
                              bottom: const [6, 5, 4, 3, 2, 1],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (hintMoves != null && hintMoves!.isNotEmpty)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Stack(
                            children: List.generate(hintMoves!.length, (i) {
                              final n = hintMoves!.length;
                              final m = hintMoves![i];
                              var from = _PointLayout.centerOf(m.from, w, h);
                              var to = _PointLayout.centerOf(m.to, w, h);

                              final dir = to - from;
                              final len = dir.distance;
                              if (len > 0) {
                                final perp = Offset(-dir.dy, dir.dx) / len;
                                final offsetIndex = i - (n - 1) / 2;
                                final shift = perp * offsetIndex * 14;
                                from += shift;
                                to += shift;
                              }

                              final mid =
                                  Offset((from.dx + to.dx) / 2, (from.dy + to.dy) / 2);
                              final angle = (to - from).direction;
                              final arrowLength =
                                  (to - from).distance.clamp(30.0, 10000.0);
                              const arrowThickness = 24.0;

                              return Positioned(
                                left: mid.dx - arrowLength / 2,
                                top: mid.dy - arrowThickness / 2,
                                width: arrowLength,
                                height: arrowThickness,
                                child: Transform.rotate(
                                  angle: angle,
                                  child: Image.asset(
                                    'assets/images/arrow.png',
                                    fit: BoxFit.fill,
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
        _offTray(),
        ],
      ),
    );
  }

  Widget _half({required List<int> top, required List<int> bottom}) {
    return Column(
      children: [
        Expanded(
          child: Row(
              children:
                  top.map((p) => Expanded(child: _pointWidget(p, top: true))).toList()),
        ),
        Expanded(
          child: Row(
              children: bottom
                  .map((p) => Expanded(child: _pointWidget(p, top: false)))
                  .toList()),
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

  Widget _verticalBar(double width) {
    final barIsLegalFrom = legalFromPoints.contains(barPoint);
    return GestureDetector(
      onTap: interactive ? () => onTapPoint(barPoint) : null,
      child: Container(
        width: width,
        color: barIsLegalFrom ? Colors.lightGreenAccent.withOpacity(0.35) : null,
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
              : const Color(0xFF3A2415),
          border: Border.all(color: Colors.black54),
          borderRadius: BorderRadius.circular(8),
        ),
        margin: const EdgeInsets.only(left: 6),
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

class _PointLayout {
  static Offset centerOf(int point, double width, double height) {
    final padX = width * BoardWidget._padXFrac;
    final padY = height * BoardWidget._padYFrac;
    final barW = width * BoardWidget._barFrac;

    if (point == barPoint) {
      return Offset(width / 2, height / 2);
    }
    if (point == offPoint) {
      return Offset(width - padX / 2, height / 2);
    }

    final usableWidth = width - padX * 2 - barW;
    final halfWidth = usableWidth / 2;
    final colWidth = halfWidth / 6;
    final sectionHeight = (height - padY * 2) / 2;

    final isTop = point >= 13 && point <= 24;
    double x;
    double y;
    if (isTop) {
      if (point <= 18) {
        final i = point - 13;
        x = padX + i * colWidth + colWidth / 2;
      } else {
        final j = point - 19;
        x = padX + halfWidth + barW + j * colWidth + colWidth / 2;
      }
      y = padY + sectionHeight / 2;
    } else {
      if (point >= 7) {
        final i = 12 - point;
        x = padX + i * colWidth + colWidth / 2;
      } else {
        final j = 6 - point;
        x = padX + halfWidth + barW + j * colWidth + colWidth / 2;
      }
      y = padY + sectionHeight + sectionHeight / 2;
    }
    return Offset(x, y);
  }
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
