import 'package:flutter/material.dart';

class DiceWidget extends StatelessWidget {
  final List<int> dice;
  const DiceWidget({super.key, required this.dice});

  @override
  Widget build(BuildContext context) {
    if (dice.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: dice.map((d) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: _die(d),
        );
      }).toList(),
    );
  }

  Widget _die(int value) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black87, width: 1.5),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 3, offset: Offset(1, 2)),
        ],
      ),
      padding: const EdgeInsets.all(6),
      child: CustomPaint(painter: _DiePipsPainter(value), size: Size.infinite),
    );
  }
}

class _DiePipsPainter extends CustomPainter {
  final int value;
  _DiePipsPainter(this.value);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black87;
    final r = size.shortestSide / 8;
    for (final p in _pipPositions(value)) {
      canvas.drawCircle(Offset(p.dx * size.width, p.dy * size.height), r, paint);
    }
  }

  List<Offset> _pipPositions(int v) {
    const l = 0.22, c = 0.5, r = 0.78, t = 0.22, b = 0.78;
    switch (v) {
      case 1:
        return [const Offset(c, c)];
      case 2:
        return [const Offset(l, t), const Offset(r, b)];
      case 3:
        return [const Offset(l, t), const Offset(c, c), const Offset(r, b)];
      case 4:
        return [
          const Offset(l, t),
          const Offset(r, t),
          const Offset(l, b),
          const Offset(r, b),
        ];
      case 5:
        return [
          const Offset(l, t),
          const Offset(r, t),
          const Offset(c, c),
          const Offset(l, b),
          const Offset(r, b),
        ];
      case 6:
        return [
          const Offset(l, t),
          const Offset(r, t),
          const Offset(l, c),
          const Offset(r, c),
          const Offset(l, b),
          const Offset(r, b),
        ];
      default:
        return [];
    }
  }

  @override
  bool shouldRepaint(covariant _DiePipsPainter oldDelegate) => oldDelegate.value != value;
}
