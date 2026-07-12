import 'package:flutter/material.dart';
import '../models/backgammon_position.dart';

class BoardWidget extends StatelessWidget {
  final BackgammonPosition position;
  final Set<int> legalFromPoints;
  final Set<int> legalToPoints;
  final int? selectedFrom;
  final void Function(int point) onTapPoint;

  const BoardWidget({
    super.key,
    required this.position,
    required this.legalFromPoints,
    required this.legalToPoints,
    required this.selectedFrom,
    required this.onTapPoint,
  });

  @override
  Widget build(BuildContext context) {
    final topPoints = List.generate(12, (i) => 13 + i); // 13..24
    final bottomPoints = List.generate(12, (i) => 12 - i); // 12..1

    return AspectRatio(
      aspectRatio: 1.4,
      child: Container(
        color: const Color(0xFF3E2723),
        padding: const EdgeInsets.all(6),
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
        const SizedBox(width: 20),
        ...right.map((p) => Expanded(child: _pointWidget(p, top: top))),
      ],
    );
  }

  Widget _pointWidget(int point, {required bool top}) {
    final count = position.points[point];
    final isLegalFrom = legalFromPoints.contains(point);
    final isLegalTo = legalToPoints.contains(point);
    final isSelected = selectedFrom == point;
    final isPlayerA = count > 0;

    final checkers = List.generate(
      count.abs(),
      (_) => _checker(isPlayerA),
    );

    return GestureDetector(
      onTap: () => onTapPoint(point),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.yellow.withOpacity(0.35)
              : (isLegalFrom || isLegalTo)
                  ? Colors.green.withOpacity(0.3)
                  : Colors.transparent,
          border: Border.all(color: Colors.brown.shade900, width: 0.5),
        ),
        child: Column(
          mainAxisAlignment: top ? MainAxisAlignment.start : MainAxisAlignment.end,
          children: top ? checkers : checkers.reversed.toList(),
        ),
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
        color: isPlayerA ? Colors.white : Colors.black87,
        border: Border.all(color: Colors.grey.shade700),
      ),
    );
  }

  Widget _barAndOffRow() {
    final barIsLegalFrom = legalFromPoints.contains(barPoint);
    final offIsLegalTo = legalToPoints.contains(offPoint);
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => onTapPoint(barPoint),
              child: Container(
                color: barIsLegalFrom
                    ? Colors.green.withOpacity(0.35)
                    : Colors.brown.shade800,
                alignment: Alignment.center,
                child: Text(
                  'Bar - You: ${position.barA}  Computer: ${position.barB}',
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: () => onTapPoint(offPoint),
            child: Container(
              width: 90,
              color: offIsLegalTo
                  ? Colors.green.withOpacity(0.35)
                  : Colors.brown.shade700,
              alignment: Alignment.center,
              child: Text(
                'Off\nYou: ${position.offA}  CPU: ${position.offB}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
