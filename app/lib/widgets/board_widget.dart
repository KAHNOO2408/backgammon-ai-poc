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
  final Player? hintMover;
  final PipMove? animatingMove;
  final bool animatingIsPlayerA;
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
    this.hintMover,
    this.animatingMove,
    this.animatingIsPlayerA = true,
    this.interactive = true,
  });

  static const double _padXFrac = 0.03;
  static const double _padYFrac = 0.045;
  static const double _barFrac = 0.045;
  static const double _offWidth = 46;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('BUILD-CHECK-9', style: TextStyle(color: Colors.pink, fontSize: 10, fontWeight: FontWeight.bold)),
        IntrinsicHeight(
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
                    RepaintBoundary(
                      child: Container(
                        decoration: const BoxDecoration(
                          image: DecorationImage(
                            image: AssetImage('assets/images/wood_board.png'),
                            fit: BoxFit.fill,
                          ),
                        ),
                      ),
                    ),
                    Padding(
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
                    // Point numbers, drawn on the wood frame itself.
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Stack(
                          children: [
                            for (final p in const [
                              13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24
                            ])
                              Positioned(
                                left: _PointLayout.centerOf(p, w, h).dx - 12,
                                top: padY * 0.12,
                                width: 24,
                                child: Text(
                                  '$p',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFFF3DDB0),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            for (final p in const [
                              12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1
                            ])
                              Positioned(
                                left: _PointLayout.centerOf(p, w, h).dx - 12,
                                bottom: padY * 0.12,
                                width: 24,
                                child: Text(
                                  '$p',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFFF3DDB0),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (hintMoves != null && hintMoves!.isNotEmpty && hintMover != null)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: _ArrowPainter(_buildArrowSegments(
                                hintMoves!, position, hintMover!, w, h)),
                          ),
                        ),
                      ),
                    if (animatingMove != null)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: TweenAnimationBuilder<double>(
                            key: ValueKey(animatingMove),
                            tween: Tween(begin: 0.0, end: 1.0),
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeInOut,
                            builder: (context, t, child) {
                              final mover = animatingIsPlayerA ? Player.a : Player.b;
                              final from = animatingMove!.from == barPoint
                                  ? _PointLayout.centerOf(barPoint, w, h)
                                  : _PointLayout.landingOffset(
                                      animatingMove!.from, 0, w, h);
                              final existingAtDest =
                                  (animatingMove!.to >= 1 && animatingMove!.to <= 24)
                                      ? position.countAt(mover, animatingMove!.to)
                                      : 0;
                              final to = _PointLayout.landingOffset(
                                  animatingMove!.to, existingAtDest, w, h);
                              const size = 18.0;

                              Offset posAt(double tt) => Offset.lerp(from, to, tt)!;

                              final checkerDecoration = BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: animatingIsPlayerA
                                      ? [Colors.white, Colors.grey.shade300]
                                      : [Colors.grey.shade800, Colors.black],
                                ),
                                border: Border.all(
                                    color: animatingIsPlayerA
                                        ? Colors.black54
                                        : Colors.white,
                                    width: 1.3),
                                boxShadow: const [
                                  BoxShadow(color: Colors.black45, blurRadius: 3),
                                ],
                              );

                              // A short fading trail of echoes behind the checker.
                              const trailSteps = [0.16, 0.11, 0.06];
                              final trail = <Widget>[];
                              for (final d in trailSteps) {
                                final tt = t - d;
                                if (tt <= 0) continue;
                                final p = posAt(tt);
                                trail.add(Positioned(
                                  left: p.dx - size / 2,
                                  top: p.dy - size / 2,
                                  width: size,
                                  height: size,
                                  child: Opacity(
                                    opacity: (0.28 * (1 - d / 0.2)).clamp(0.0, 0.28),
                                    child: DecoratedBox(decoration: checkerDecoration),
                                  ),
                                ));
                              }

                              final pos = posAt(t);

                              return Stack(
                                children: [
                                  ...trail,
                                  Positioned(
                                    left: pos.dx - size / 2,
                                    top: pos.dy - size / 2,
                                    width: size,
                                    height: size,
                                    child: DecoratedBox(decoration: checkerDecoration),
                                  ),
                                ],
                              );
                            },
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
        ),
      ],
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

    final triangleColor =
        point.isEven ? const Color(0xFFE8C79A) : const Color(0xFF8B5A2B);

    Color? overlay;
    if (isLegalFrom && !isSelected) {
      overlay = Colors.lightGreenAccent.withOpacity(0.3);
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
          // Checkers auto-shrink/overlap to always fit within the triangle's
          // bounds, no matter how many are stacked on this point.
          Positioned.fill(
            child: _checkerStack(
              count.abs(),
              isPlayerA,
              top,
              growIndex: isSelected ? 0 : null,
              hideIndex: (animatingMove != null && animatingMove!.from == point) ? 0 : null,
            ),
          ),
          if (isLegalTo) Positioned.fill(child: _legalToRing(count.abs(), top)),
        ],
      ),
    );
  }

  Widget _legalToRing(int existingCount, bool top) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availH = constraints.maxHeight;
        final availW = constraints.maxWidth;
        final diameter = (availW * 0.82).clamp(8.0, 20.0);
        final naturalStep = diameter + 1;
        final n = existingCount + 1;
        final neededHeight = naturalStep * n;
        final step = n <= 1
            ? 0.0
            : (neededHeight <= availH
                ? naturalStep
                : ((availH - diameter) / (n - 1)).clamp(0.0, naturalStep));
        final offset = existingCount * step;

        return Positioned(
          top: top ? offset : null,
          bottom: top ? null : offset,
          left: (availW - diameter) / 2,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.7, end: 1.0),
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
            child: Container(
              width: diameter,
              height: diameter,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFF00FF), width: 6),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _checkerStack(int count, bool isPlayerA, bool top, {int? growIndex, int? hideIndex}) {
    if (count == 0) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final availH = constraints.maxHeight;
        final availW = constraints.maxWidth;
        final diameter = (availW * 0.82).clamp(8.0, 20.0);
        final naturalStep = diameter + 1;
        final neededHeight = naturalStep * count;
        final step = count <= 1
            ? 0.0
            : (neededHeight <= availH
                ? naturalStep
                : ((availH - diameter) / (count - 1)).clamp(0.0, naturalStep));

        return Stack(
          clipBehavior: Clip.none,
          children: List.generate(count, (i) {
            if (i == hideIndex) return const SizedBox.shrink();
            final offset = i * step;
            Widget checker = _checker(isPlayerA, diameter);
            if (growIndex == i) {
              checker = TweenAnimationBuilder<double>(
                tween: Tween(begin: 1.0, end: 1.22),
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                builder: (context, scale, child) =>
                    Transform.scale(scale: scale, child: child),
                child: checker,
              );
            }
            return Positioned(
              top: top ? offset : null,
              bottom: top ? null : offset,
              left: (availW - diameter) / 2,
              child: checker,
            );
          }),
        );
      },
    );
  }

  Widget _checker(bool isPlayerA, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: isPlayerA
              ? [Colors.white, Colors.grey.shade300]
              : [Colors.grey.shade800, Colors.black],
        ),
        border: Border.all(color: isPlayerA ? Colors.black54 : Colors.white, width: 1.3),
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
        border: Border.all(color: isPlayerA ? Colors.black54 : Colors.white, width: 1.3),
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

  static List<_ArrowSegment> _buildArrowSegments(
    List<PipMove> moves,
    BackgammonPosition startPos,
    Player mover,
    double w,
    double h,
  ) {
    var pos = startPos;
    final raw = <_ArrowSegment>[];
    for (final m in moves) {
      final fromOffset = m.from == barPoint
          ? _PointLayout.centerOf(barPoint, w, h)
          : _PointLayout.landingOffset(m.from, 0, w, h);
      final toOffset = m.to == offPoint
          ? _PointLayout.centerOf(offPoint, w, h)
          : _PointLayout.landingOffset(m.to, pos.countAt(mover, m.to), w, h);
      raw.add(_ArrowSegment(fromOffset, toOffset));
      pos = pos.applyMove(mover, m);
    }

    final result = <_ArrowSegment>[];
    var i = 0;
    while (i < moves.length) {
      var j = i;
      while (j + 1 < moves.length && moves[j + 1].from == moves[j].to) {
        j++;
      }
      result.add(_ArrowSegment(raw[i].from, raw[j].to));
      i = j + 1;
    }
    return result;
  }
}

class _PointLayout {
  static Rect cellRect(int point, double width, double height) {
    final padX = width * BoardWidget._padXFrac;
    final padY = height * BoardWidget._padYFrac;
    final barW = width * BoardWidget._barFrac;
    final usableWidth = width - padX * 2 - barW;
    final halfWidth = usableWidth / 2;
    final colWidth = halfWidth / 6;
    final sectionHeight = (height - padY * 2) / 2;

    final isTop = point >= 13 && point <= 24;
    double left;
    if (isTop) {
      if (point <= 18) {
        left = padX + (point - 13) * colWidth;
      } else {
        left = padX + halfWidth + barW + (point - 19) * colWidth;
      }
    } else {
      if (point >= 7) {
        left = padX + (12 - point) * colWidth;
      } else {
        left = padX + halfWidth + barW + (6 - point) * colWidth;
      }
    }
    final top = isTop ? padY : padY + sectionHeight;
    return Rect.fromLTWH(left, top, colWidth, sectionHeight);
  }

  static Offset centerOf(int point, double width, double height) {
    if (point == barPoint) return Offset(width / 2, height / 2);
    if (point == offPoint) {
      final padX = width * BoardWidget._padXFrac;
      return Offset(width - padX / 2, height / 2);
    }
    final r = cellRect(point, width, height);
    return Offset(r.left + r.width / 2, r.top + r.height / 2);
  }

  static Offset landingOffset(int point, int existingCount, double width, double height) {
    if (point == barPoint || point == offPoint) return centerOf(point, width, height);
    final r = cellRect(point, width, height);
    final isTop = point >= 13 && point <= 24;
    final diameter = (r.width * 0.82).clamp(8.0, 20.0);
    final naturalStep = diameter + 1;
    final n = existingCount + 1;
    final neededHeight = naturalStep * n;
    final step = n <= 1
        ? 0.0
        : (neededHeight <= r.height
            ? naturalStep
            : ((r.height - diameter) / (n - 1)).clamp(0.0, naturalStep));
    final offsetInCell = existingCount * step;
    final y = isTop
        ? r.top + offsetInCell + diameter / 2
        : r.top + r.height - offsetInCell - diameter / 2;
    return Offset(r.left + r.width / 2, y);
  }
}

class _ArrowSegment {
  final Offset from;
  final Offset to;
  _ArrowSegment(this.from, this.to);
}

class _ArrowPainter extends CustomPainter {
  final List<_ArrowSegment> segments;
  _ArrowPainter(this.segments);

  static const Color _arrowColor = Color(0xFFD32F2F);

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = _arrowColor
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (final seg in segments) {
      canvas.drawLine(seg.from, seg.to, linePaint);
      _drawArrowHead(canvas, seg.from, seg.to);
    }
  }

  void _drawArrowHead(Canvas canvas, Offset from, Offset to) {
    const headLength = 18.0;
    const headAngle = 0.5;
    final angle = (to - from).direction;
    final p1 = to -
        Offset(headLength * cos(angle - headAngle), headLength * sin(angle - headAngle));
    final p2 = to -
        Offset(headLength * cos(angle + headAngle), headLength * sin(angle + headAngle));
    final headPaint = Paint()
      ..color = _arrowColor
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
