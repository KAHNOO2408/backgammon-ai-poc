import 'package:flutter/material.dart';
import '../models/backgammon_position.dart';

class BoardWidget extends StatelessWidget {
  final BackgammonPosition position;
  final Set<int> legalFromPoints;
  final Set<int> legalToPoints;
  final int? selectedFrom;
  final Set<int> lastMovePoints;
  final void Function(int point) onTapPoint;

  const BoardWidget({
    super.key,
    required this.position,
    required this.legalFromPoints,
    required this.legalToPoints,
    required this.selectedFrom,
    required this.lastMovePoints,
    required this.onTapPoint,
  });

  @override
  Widget build(BuildContext context) {
    final topPoints = List.generate(12, (i) => 13 + i); // 13..24
    final bottomPoints = List.generate(12, (i) => 12 - i); // 12..1

    return AspectRatio(
      aspectRatio: 1.35,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF4E342E),
          border: Border.all(color: Colors.black, width: 3),
        ),
        padding: const EdgeInsets.all(4),
        child: Column(
          children: [
            Expanded(child: _row(topPoints, top: true)),
            _barAndOffRow(),
            Expanded(child: _row(bottomPoints, top: false)),
          ],
        ),
      ),
    );
  }

  Widget _row(List<int> pointsInOrder, {required bool top}) {
    final left = pointsInOrder.sublist(0, 6);
    final right = pointsInOrder.sublist(6, 12);
    return Row(
      children: [
        ...left.map((p) => Expanded(child: _pointWidget(p, top: top))),
        const SizedBox(width: 18),
        ...right.map((p) => Expanded(child: _pointWidget(p, top: top))),
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
        point.isEven ? const Color(0xFFD9B98A) : const Color(0xFF7B4B2A);

    Color? overlay;
    if (isSelected) {
      overlay = Colors.yellow.withOpacity(0.45);
    } else if (isLegalFrom || isLegalTo) {
      overlay = Colors.lightGreenAccent.withOpacity(0.4);
    } else if (isLastMove) {
      overlay = Colors.orangeAccent.withOpacity(0.35);
    }

    return GestureDetector(
      onTap: () => onTapPoint(point),
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
          Column(
            mainAxisAlignment: top ? MainAxisAlignment.start : MainAxisAlignment.end,
            children: top ? checkers : checkers.reversed.toList(),
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
      margin: const EdgeInsets.symmetric(horizontal: 1.5),
      width: 15,
      height: 15,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isPlayerA ? Colors.white : Colors.black87,
        border: Border.all(color: Colors.grey.shade600),
      ),
    );
  }

  Widget _barAndOffRow() {
    final barIsLegalFrom = legalFromPoints.contains(barPoint);
    final offIsLegalTo = legalToPoints.contains(offPoint);

    return SizedBox(
      height: 60,
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => onTapPoint(barPoint),
              child: Container(
                decoration: BoxDecoration(
                  color: barIsLegalFrom
                      ? Colors.lightGreenAccent.withOpacity(0.4)
                      : Colors.black.withOpacity(0.35),
                  border: Border.all(color: Colors.black54),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('BAR',
                        style: TextStyle(
                            color: Colors.white54,
                            fontSize: 9,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Wrap(
                      alignment: WrapAlignment.center,
                      children: [
                        ...List.generate(position.barA, (_) => _smallChecker(true)),
                        if (position.barA > 0 && position.barB > 0)
                          const SizedBox(width: 8),
                        ...List.generate(position.barB, (_) => _smallChecker(false)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: () => onTapPoint(offPoint),
            child: Container(
              width: 90,
              decoration: BoxDecoration(
                color: offIsLegalTo
                    ? Colors.lightGreenAccent.withOpacity(0.4)
                    : Colors.black.withOpacity(0.25),
                border: Border.all(color: Colors.black54),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('You', style: TextStyle(color: Colors.white70, fontSize: 9)),
                      Text('${position.offA}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('CPU', style: TextStyle(color: Colors.white70, fontSize: 9)),
                      Text('${position.offB}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
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
