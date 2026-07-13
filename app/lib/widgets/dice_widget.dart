import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

class DiceWidget extends StatefulWidget {
  final List<int> dice;
  const DiceWidget({super.key, required this.dice});

  @override
  State<DiceWidget> createState() => _DiceWidgetState();
}

class _DiceWidgetState extends State<DiceWidget> {
  List<int> _displayValues = [];
  Timer? _timer;
  final _random = Random();

  @override
  void initState() {
    super.initState();
    _displayValues = List.from(widget.dice);
  }

  @override
  void didUpdateWidget(covariant DiceWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.dice.isEmpty) {
      _timer?.cancel();
      setState(() => _displayValues = []);
      return;
    }
    if (!_sameList(oldWidget.dice, widget.dice)) {
      _startRollAnimation();
    }
  }

  bool _sameList(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _startRollAnimation() {
    _timer?.cancel();
    var ticks = 0;
    const totalTicks = 9;
    _timer = Timer.periodic(const Duration(milliseconds: 65), (t) {
      ticks++;
      if (!mounted) {
        t.cancel();
        return;
      }
      if (ticks >= totalTicks) {
        t.cancel();
        setState(() => _displayValues = List.from(widget.dice));
      } else {
        setState(() {
          _displayValues =
              List.generate(widget.dice.length, (_) => _random.nextInt(6) + 1);
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_displayValues.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: _displayValues.map((d) {
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
