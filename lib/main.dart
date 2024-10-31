import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:accelerometer/data.dart';
import 'package:accelerometer/line_chart.dart';
import 'package:accelerometer/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:system_theme/system_theme.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

const sampleInterval = SensorInterval.gameInterval;
const limit = 500;

final haveSensor = Platform.isAndroid || Platform.isIOS;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(systemNavigationBarColor: Colors.transparent),
  );

  final prefs = await SharedPreferences.getInstance();
  WakelockPlus.enable();
  await SystemTheme.accentColor.load();

  runApp(
    ProviderScope(
      overrides: [sharedPrefsProvider.overrideWith((ref) => prefs)],
      child: const App(),
    ),
  );
}

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brightness = ref.watch(brightnessProvider);
    final accentColor = SystemTheme.accentColor.accent;
    Color cardColor;
    if (brightness == Brightness.light) {
      cardColor = accentColor.withOpacity(0.75);
    } else {
      cardColor = accentColor;
    }

    return MaterialApp(
      title: 'Accelerometer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: accentColor,
        appBarTheme: AppBarTheme(color: cardColor),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: SystemTheme.accentColor.lightest,
          elevation: 0,
          hoverElevation: 0,
          focusElevation: 0,
          highlightElevation: 0,
        ),
        cardTheme: CardTheme(
          shadowColor: Colors.transparent,
          color: cardColor,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: accentColor,
        appBarTheme: AppBarTheme(color: cardColor),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: SystemTheme.accentColor.lightest,
          elevation: 0,
          hoverElevation: 0,
          focusElevation: 0,
          highlightElevation: 0,
        ),
        cardTheme: CardTheme(
          shadowColor: Colors.transparent,
          color: cardColor,
        ),
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      themeMode:
          brightness == Brightness.light ? ThemeMode.light : ThemeMode.dark,
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
                    : Chart(
                        stream: sineData(sampleInterval),
                        strokeWidth: 2,
                      ),
              ),
            ),
            const SizedBox(height: 26),
            Text(
              'Gravity',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Expanded(
              flex: 9,
              child: GraphCard(
                child: haveSensor
                    ? const AccChart()
                    : Chart(
                        stream: sineData(sampleInterval),
                        strokeWidth: 2,
                      ),
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

class Chart extends ConsumerStatefulWidget {
  const Chart({
    super.key,
    required this.stream,
    this.strokeWidth = 1,
    this.lineColor,
  });

  final Stream<ChartPoint> stream;
  final double strokeWidth;
  final Color? lineColor;

  @override
  ConsumerState<Chart> createState() => _ChartState();
}

class _ChartState extends ConsumerState<Chart> {
  final _line = LineChartData(limit: limit);

  @override
  void initState() {
    widget.stream.listen((data) {
      _line.addData(data.time, data.value);
      setState(() {});
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (_line.isEmpty) {
      return const SizedBox();
    }
    return LineChart(
      lines: [
        _line.asLine(
          color: widget.lineColor ?? Theme.of(context).colorScheme.onSurface,
          strokeWidth: widget.strokeWidth,
        ),
      ],
      minX: _line.firstX,
      maxX: _line.firstX + (limit * sampleInterval.inMilliseconds),
      labelCount: 5,
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
  late final _accLine = LineChartData(limit: limit);
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
      final acc = math.sqrt(sum);
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
      _graphNotifier.value = 0;
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
                    color: Theme.of(context).colorScheme.onSurface,
                    strokeWidth: 1,
                  ),
                ],
                minX: _accLine.firstX,
                maxX: _accLine.firstX + limit * _step,
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
  late final _accLine = LineChartData(limit: limit);

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
        final acc = math.sqrt(sum);
        _accLine.addData(x, acc);
        x += _step;
        return LineChart(
          lines: [
            _accLine.asLine(
              color: Theme.of(context).colorScheme.onSurface,
              strokeWidth: 1,
            ),
          ],
          minX: _accLine.firstX,
          maxX: _accLine.firstX + limit * _step,
          labelCount: 5,
        );
      },
    );
  }
}
