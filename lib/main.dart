import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:accelerometer/line_chart.dart';
import 'package:accelerometer/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

const sampleInterval = SensorInterval.gameInterval;
const count = 500;

final haveSensor = Platform.isAndroid || Platform.isIOS;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  final prefs = await SharedPreferences.getInstance();
  WakelockPlus.enable();

  runApp(
    ProviderScope(
      overrides: [sharedPrefsProvider.overrideWith((ref) => prefs)],
      child: const App(),
    ),
  );
}

class App extends ConsumerWidget {
  const App({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Accelerometer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.lime,
        appBarTheme: AppBarTheme(color: Colors.lime.shade100),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: Colors.lime.shade100,
          elevation: 0,
          hoverElevation: 0,
          focusElevation: 0,
          highlightElevation: 0,
        ),
        cardTheme: CardTheme(
          shadowColor: Colors.transparent,
          color: Colors.lime.shade100,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.amber,
        appBarTheme: AppBarTheme(color: Colors.brown.shade800),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: Colors.brown.shade800,
          elevation: 0,
          hoverElevation: 0,
          focusElevation: 0,
          highlightElevation: 0,
        ),
        cardTheme: CardTheme(
          shadowColor: Colors.transparent,
          color: Colors.brown.shade800,
        ),
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      themeMode: ref.watch(brightnessProvider) == Brightness.light
          ? ThemeMode.light
          : ThemeMode.dark,
      home: const Home(),
    );
  }
}

class Home extends ConsumerStatefulWidget {
  const Home({super.key});

  @override
  ConsumerState<Home> createState() => _HomeState();
}

class _HomeState extends ConsumerState<Home> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(haveSensor ? 'Accelerometer' : 'Accelerometer (fake)'),
        elevation: 1,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(24),
            bottomRight: Radius.circular(24),
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              final brightness = ref.read(brightnessProvider);
              ref.read(brightnessProvider.notifier).state =
                  brightness == Brightness.dark
                      ? Brightness.light
                      : Brightness.dark;
            },
            icon: Consumer(
              builder: (context, ref, child) {
                final brightness = ref.watch(brightnessProvider);
                if (brightness == Brightness.light) {
                  return const Icon(Icons.dark_mode);
                }
                return const Icon(Icons.light_mode);
              },
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: () {
              final v = ref.read(pausedProvider);
              ref.read(pausedProvider.notifier).state = !v;
            },
            child: Consumer(
              builder: (context, ref, _) {
                if (ref.watch(pausedProvider)) {
                  return const Icon(Icons.play_arrow);
                }
                return const Icon(Icons.pause);
              },
            ),
          ),
          const SizedBox(height: 12, width: 12),
          FloatingActionButton(
            onPressed: () {
              ref.read(restartProvider.notifier).state =
                  !ref.read(restartProvider);
            },
            child: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SizedBox(height: 24),
            Text(
              'Linear acceleration',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Expanded(
              flex: 10,
              child: GraphCard(
                child: haveSensor
                    ? const UserAccChart()
                    : const SineChart(count: count),
              ),
            ),
            const SizedBox(height: 26),
            Text(
              'Acceleration (including gravity)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Expanded(
              flex: 9,
              child: GraphCard(
                child: haveSensor
                    ? const AccChart()
                    : const SineChart(count: count),
              ),
            ),
            const SizedBox(height: 84),
          ],
        ),
      ),
    );
  }
}

class GraphCard extends StatelessWidget {
  final Widget? child;
  const GraphCard({super.key, this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: child,
        ),
      ),
    );
  }
}

class UserAccChart extends ConsumerStatefulWidget {
  const UserAccChart({super.key});

  @override
  ConsumerState<UserAccChart> createState() => _UserAccChartState();
}

class _UserAccChartState extends ConsumerState<UserAccChart> {
  static const _step = 1.0;

  late final Stream<UserAccelerometerEvent> _stream;
  StreamSubscription? _subscription;
  late final _accLine = LineChartData(limit: count);
  final _currValue = ValueNotifier(0.0);
  final _maxValue = ValueNotifier(0.0);
  final _graphNotifier = ValueNotifier(0.0);

  double x = 0.0;
  bool _paused = false;

  @override
  void initState() {
    _stream = userAccelerometerEventStream(
      samplingPeriod: sampleInterval,
    );
    _subscription = _stream.listen((event) {
      if (_paused) {
        return;
      }
      final sum = event.x * event.x + event.y * event.y + event.z * event.z;
      final acc = sqrt(sum);
      // debounce label
      if (x.round() % 10 == 0) {
        _currValue.value = acc;
      }
      if (acc > _maxValue.value) {
        _maxValue.value = acc;
      }
      _accLine.addData(x, acc);
      x += _step;
      _graphNotifier.value = x;
    });
    super.initState();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(pausedProvider, (previous, next) {
      _paused = next;
    });
    ref.listen(restartProvider, (previous, next) {
      _accLine.reset();
      _maxValue.value = 0.0;
    });
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        ValueListenableBuilder(
          valueListenable: _maxValue,
          builder: (context, value, _) {
            final accStr = value.toStringAsFixed(2);
            final text = 'maximum: $accStr m/s²';
            return Text(
              text,
              style: const TextStyle(fontFamily: 'robot-mono'),
            );
          },
        ),
        ValueListenableBuilder(
          valueListenable: _currValue,
          builder: (context, value, _) {
            final curr = value.toStringAsFixed(2);
            final text = 'current: $curr m/s²';
            return Text(
              text,
              style: const TextStyle(fontFamily: 'robot-mono'),
            );
          },
        ),
        ValueListenableBuilder(
          valueListenable: _graphNotifier,
          builder: (context, value, _) {
            if (_accLine.isEmpty) {
              return const SizedBox();
            }
            return Expanded(
              child: LineChart(
                lines: [
                  _accLine.asLine(
                    color: Theme.of(context).colorScheme.onBackground,
                    strokeWidth: 1,
                  ),
                ],
                minX: _accLine.first.$1,
                maxX: _accLine.first.$1 + count * _step,
                minY: 0,
                labelCount: 5,
              ),
            );
          },
        ),
      ],
    );
  }
}

class AccChart extends StatefulWidget {
  const AccChart({super.key});

  @override
  State<AccChart> createState() => _AccChartState();
}

class _AccChartState extends State<AccChart> {
  static const _step = 1.0;

  late final Stream<AccelerometerEvent> _stream = accelerometerEventStream(
    samplingPeriod: sampleInterval,
  );
  late final _accLine = LineChartData(limit: count);

  double x = 0.0;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _stream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox();
        }
        final v = snapshot.data!;
        final sum = v.x * v.x + v.y * v.y + v.z * v.z;
        final acc = sqrt(sum);
        _accLine.addData(x, acc);
        x += _step;
        return LineChart(
          lines: [
            _accLine.asLine(
              color: Theme.of(context).colorScheme.onBackground,
              strokeWidth: 1,
            ),
          ],
          minX: _accLine.first.$1,
          maxX: _accLine.first.$1 + count * _step,
          labelCount: 5,
        );
      },
    );
  }
}

class SineChart extends StatefulWidget {
  final int count;
  const SineChart({super.key, required this.count});

  @override
  State<SineChart> createState() => _SineChartState();
}

final rand = Random();

class _SineChartState extends State<SineChart>
    with SingleTickerProviderStateMixin {
  final _step = 0.07;

  late final _line1 = LineChartData(limit: widget.count);
  // late final _line2 = LineChartData(limit: widget.count);
  late final color1 = Colors.primaries[rand.nextInt(Colors.primaries.length)];
  // late final color2 = Colors.primaries[rand.nextInt(Colors.primaries.length)];
  late final mul1 = rand.nextInt(9) + 7; // 7-15
  late final mul2 = rand.nextInt(6) + 16; // 16-21
  late final div1 = rand.nextInt(6) + 4; // 4-9
  late final div2 = rand.nextInt(5) + 10; // 10-14

  late final AnimationController _controller;

  double x = rand.nextDouble() + rand.nextInt(5);

  @override
  void initState() {
    // rebuild every frame
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
    _controller.addListener(() {
      final value = sin(mul1 * x / div1) +
          cos(mul2 * x / div2) -
          sin(mul2 * x / div1) -
          cos(mul1 * x / div2);
      _line1.addData(x, value);
      // final value2 = cos(mul1 * x / div1) - sin(mul2 * x / div2);
      // _line2.addData(x, value2);
      x += _step;
    });
    super.initState();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        if (_line1.isEmpty) {
          return const SizedBox();
        }
        return LineChart(
          lines: [
            _line1.asLine(color: color1, strokeWidth: 3),
            // _line2.asLine(color: color2, strokeWidth: 3),
          ],
          showLabel: false,
          minX: _line1.first.$1,
          maxX: _line1.first.$1 + widget.count * _step,
          minY: -3,
          maxY: 3,
        );
      },
    );
  }
}

class RandomChart extends StatelessWidget {
  const RandomChart({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleStreamChart(
      stream: () async* {
        final rand = Random();
        while (true) {
          await Future.delayed(sampleInterval);
          yield rand.nextDouble() * 5;
        }
      }(),
      limit: 500,
    );
  }
}

class SingleStreamChart extends StatefulWidget {
  final Stream<double> stream;
  final int limit;

  const SingleStreamChart({
    super.key,
    required this.stream,
    required this.limit,
  });

  @override
  State<SingleStreamChart> createState() => _SingleStreamChartState();
}

class _SingleStreamChartState extends State<SingleStreamChart> {
  late final _line = LineChartData(limit: widget.limit);
  final _step = 1.0;
  double x = 0.0;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: widget.stream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox();
        }
        final v = snapshot.data!;
        _line.addData(x, v);
        x += 1.0;
        return LineChart(
          lines: [
            _line.asLine(
              color: Theme.of(context).colorScheme.onBackground,
              strokeWidth: 1,
            ),
          ],
          minX: _line.first.$1,
          maxX: _line.first.$1 + count * _step,
        );
      },
    );
  }
}

class StressTest extends StatefulWidget {
  const StressTest({super.key});

  @override
  State<StressTest> createState() => _StressTestState();
}

class _StressTestState extends State<StressTest> {
  int count = 1;
  final frameTime = ValueNotifier(const Duration(seconds: 1).inMicroseconds);

  @override
  void initState() {
    SchedulerBinding.instance.addTimingsCallback(callback);
    super.initState();
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(callback);
    super.dispose();
  }

  void callback(List<FrameTiming> timings) {
    final time1 = timings.last.rasterDuration.inMicroseconds;
    final time2 = timings.last.buildDuration.inMicroseconds;
    frameTime.value = max(time1, time2);
  }

  @override
  Widget build(BuildContext context) {
    final chart = Expanded(
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: ColoredBox(
          color: Theme.of(context).focusColor,
          child: const SineChart(count: 250),
        ),
      ),
    );
    return Scaffold(
      appBar: AppBar(
        actions: [
          ValueListenableBuilder(
            valueListenable: frameTime,
            builder: (context, value, _) {
              final fps = const Duration(seconds: 1).inMicroseconds / value;
              return Text(
                'fps: ${fps.toStringAsFixed(1).padLeft(5, ' ')}',
                style: const TextStyle(fontFamily: 'robot-mono'),
              );
            },
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Column(
        children: List.filled(
          count * 2,
          Expanded(
            child: Row(
              children: List.filled(count, chart),
            ),
          ),
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Visibility(
            visible: count <= 15,
            child: FloatingActionButton(
              onPressed: () {
                setState(() {
                  count++;
                });
              },
              child: const Icon(Icons.keyboard_double_arrow_up),
            ),
          ),
          const SizedBox(height: 12),
          Visibility(
            visible: count != 1,
            maintainAnimation: true,
            maintainSize: true,
            maintainState: true,
            child: FloatingActionButton(
              onPressed: () {
                setState(() {
                  count--;
                });
              },
              child: const Icon(Icons.keyboard_double_arrow_down),
            ),
          ),
        ],
      ),
    );
  }
}
