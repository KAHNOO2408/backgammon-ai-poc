import 'package:flutter/material.dart';
import 'wildbg_bindings.dart';

void main() {
  runApp(const WildbgTestApp());
}

class WildbgTestApp extends StatelessWidget {
  const WildbgTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'wildbg FFI test',
      theme: ThemeData(colorSchemeSeed: Colors.green, useMaterial3: true),
      home: const EngineTestScreen(),
    );
  }
}

class EngineTestScreen extends StatefulWidget {
  const EngineTestScreen({super.key});

  @override
  State<EngineTestScreen> createState() => _EngineTestScreenState();
}

class _EngineTestScreenState extends State<EngineTestScreen> {
  String _status = 'Loading engine...';
  List<MoveStep> _moves = [];
  double? _winProbability;
  WildbgEngine? _engine;

  @override
  void initState() {
    super.initState();
    _runTest();
  }

  void _runTest() {
    try {
      final engine = WildbgEngine();
      _engine = engine;

      // Starting position, rolling 3 and 1 (the classic example from wildbg's docs).
      final moves = engine.bestMove(startingPosition, 3, 1);
      final probs = engine.probabilities(startingPosition);

      setState(() {
        _status = 'Engine loaded successfully!';
        _moves = moves;
        _winProbability = probs.win;
      });
    } catch (e) {
      setState(() {
        _status = 'Error loading engine: $e';
      });
    }
  }

  @override
  void dispose() {
    _engine?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('wildbg engine test')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_status, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 24),
            if (_winProbability != null)
              Text(
                'Starting position win probability: '
                '${(_winProbability! * 100).toStringAsFixed(1)}%',
              ),
            const SizedBox(height: 16),
            if (_moves.isNotEmpty) ...[
              const Text('Best move for starting position with dice 3-1:'),
              const SizedBox(height: 8),
              for (final m in _moves) Text('  • $m'),
            ],
          ],
        ),
      ),
    );
  }
}
