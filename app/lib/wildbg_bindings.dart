// Dart FFI bindings for the wildbg backgammon engine (crates/wildbg-c/wildbg.h)
//
// Board encoding (matches wildbg.h):
// - `pips` is a 26-length array.
// - Index 0 = opponent's bar, index 25 = player-on-turn's bar.
// - Indices 1..24 are the 24 points.
// - Positive numbers = player on turn's checkers, negative = opponent's.
// - The player on turn always conceptually moves from pip 24 towards pip 1.

import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

// Opaque handle matching `struct Wildbg` in C.
final class WildbgHandle extends Opaque {}

final class CMoveDetail extends Struct {
  @Int32()
  external int from;

  @Int32()
  external int to;
}

final class CMove extends Struct {
  @Array(4)
  external Array<CMoveDetail> details;

  @Int32()
  external int detailCount;
}

final class BgConfig extends Struct {
  @Uint32()
  external int xAway;

  @Uint32()
  external int oAway;
}

final class CCubeInfo extends Struct {
  @Bool()
  external bool shouldDouble;

  @Bool()
  external bool shouldAccept;
}

final class CProbabilities extends Struct {
  @Float()
  external double win;

  @Float()
  external double winG;

  @Float()
  external double winBg;

  @Float()
  external double loseG;

  @Float()
  external double loseBg;
}

// Native function signatures
typedef _WildbgNewNative = Pointer<WildbgHandle> Function();
typedef _WildbgFreeNative = Void Function(Pointer<WildbgHandle>);
typedef _WildbgFreeDart = void Function(Pointer<WildbgHandle>);

typedef _BestMoveNative = CMove Function(
  Pointer<WildbgHandle> wildbg,
  Pointer<Int32> pips,
  Uint32 die1,
  Uint32 die2,
  Pointer<BgConfig> config,
);
typedef _BestMoveDart = CMove Function(
  Pointer<WildbgHandle> wildbg,
  Pointer<Int32> pips,
  int die1,
  int die2,
  Pointer<BgConfig> config,
);

typedef _ProbabilitiesNative = CProbabilities Function(
  Pointer<WildbgHandle> wildbg,
  Pointer<Int32> pips,
);

typedef _CubeInfoNative = CCubeInfo Function(
  Pointer<WildbgHandle> wildbg,
  Pointer<Int32> pips,
);

class MoveStep {
  final int from;
  final int to;
  const MoveStep({required this.from, required this.to});

  @override
  String toString() => '$from -> $to';
}

class WildbgEngine {
  late final DynamicLibrary _lib;
  late final Pointer<WildbgHandle> _handle;

  late final _WildbgNewNative _wildbgNew;
  late final _WildbgFreeDart _wildbgFree;
  late final _BestMoveDart _bestMoveNative;
  late final CProbabilities Function(Pointer<WildbgHandle>, Pointer<Int32>)
      _probabilitiesNative;
  late final CCubeInfo Function(Pointer<WildbgHandle>, Pointer<Int32>)
      _cubeInfoNative;

  bool _initialized = false;

  WildbgEngine() {
    _lib = _openLibrary();

    _wildbgNew = _lib
        .lookup<NativeFunction<_WildbgNewNative>>('wildbg_new')
        .asFunction();
    _wildbgFree = _lib
        .lookup<NativeFunction<_WildbgFreeNative>>('wildbg_free')
        .asFunction();
    _bestMoveNative = _lib
        .lookup<NativeFunction<_BestMoveNative>>('best_move')
        .asFunction();
    _probabilitiesNative = _lib
        .lookup<NativeFunction<_ProbabilitiesNative>>('probabilities')
        .asFunction();
    _cubeInfoNative = _lib
        .lookup<NativeFunction<_CubeInfoNative>>('cube_info')
        .asFunction();

    _handle = _wildbgNew();
    if (_handle == nullptr) {
      throw StateError(
        'wildbg_new() returned NULL - the neural nets could not be loaded.',
      );
    }
    _initialized = true;
  }

  static DynamicLibrary _openLibrary() {
    if (Platform.isAndroid) {
      return DynamicLibrary.open('libwildbg.so');
    }
    throw UnsupportedError(
      'wildbg native library is currently only wired up for Android.',
    );
  }

  /// Computes the best move for [pips] given [die1] and [die2].
  ///
  /// [pips] must have length 26 (see encoding notes at the top of this file).
  /// [xAway]/[oAway] describe a match-play score; leave both at 0 for money game.
  List<MoveStep> bestMove(
    List<int> pips,
    int die1,
    int die2, {
    int xAway = 0,
    int oAway = 0,
  }) {
    _ensureNotDisposed();
    if (pips.length != 26) {
      throw ArgumentError('pips must have exactly 26 elements, got ${pips.length}');
    }

    final pipsPtr = calloc<Int32>(26);
    final configPtr = calloc<BgConfig>();
    try {
      for (var i = 0; i < 26; i++) {
        pipsPtr[i] = pips[i];
      }
      configPtr.ref.xAway = xAway;
      configPtr.ref.oAway = oAway;

      final result = _bestMoveNative(_handle, pipsPtr, die1, die2, configPtr);

      final steps = <MoveStep>[];
      for (var i = 0; i < result.detailCount; i++) {
        final d = result.details[i];
        steps.add(MoveStep(from: d.from, to: d.to));
      }
      return steps;
    } finally {
      calloc.free(pipsPtr);
      calloc.free(configPtr);
    }
  }

  /// Cubeless money-game win/loss probabilities for [pips].
  CProbabilities probabilities(List<int> pips) {
    _ensureNotDisposed();
    if (pips.length != 26) {
      throw ArgumentError('pips must have exactly 26 elements, got ${pips.length}');
    }
    final pipsPtr = calloc<Int32>(26);
    try {
      for (var i = 0; i < 26; i++) {
        pipsPtr[i] = pips[i];
      }
      return _probabilitiesNative(_handle, pipsPtr);
    } finally {
      calloc.free(pipsPtr);
    }
  }

  /// Cube (double/take) recommendation for [pips].
  CCubeInfo cubeInfo(List<int> pips) {
    _ensureNotDisposed();
    if (pips.length != 26) {
      throw ArgumentError('pips must have exactly 26 elements, got ${pips.length}');
    }
    final pipsPtr = calloc<Int32>(26);
    try {
      for (var i = 0; i < 26; i++) {
        pipsPtr[i] = pips[i];
      }
      return _cubeInfoNative(_handle, pipsPtr);
    } finally {
      calloc.free(pipsPtr);
    }
  }

  void _ensureNotDisposed() {
    if (!_initialized) {
      throw StateError('WildbgEngine has already been disposed.');
    }
  }

  /// Frees the native engine. Call this exactly once when you're done with it.
  void dispose() {
    if (_initialized) {
      _wildbgFree(_handle);
      _initialized = false;
    }
  }
}

/// Standard backgammon starting position, encoded for wildbg.
/// Index 0 = opponent bar, index 25 = player bar, 1..24 = points.
const List<int> startingPosition = [
  0, -2, 0, 0, 0, 0, 5, 0, 3, 0, 0, 0, -5,
  5, 0, 0, 0, -3, 0, -5, 0, 0, 0, 0, 2, 0,
];
