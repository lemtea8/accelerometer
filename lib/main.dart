import 'dart:async';
import 'dart:io';

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
      cardColor = accentColor.withAlpha(190);
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
            mini: true,
            child: Consumer(
              builder: (context, ref, _) {
                if (ref.watch(pausedProvider)) {
                  return const Icon(Icons.play_arrow);
                }
                return const Icon(Icons.pause);
              },
            ),
          ),
          const SizedBox(height: 8, width: 8),
          FloatingActionButton(
            onPressed: () {
              ref.read(restartProvider.notifier).state =
                  !ref.read(restartProvider);
            },
            mini: true,
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
                chart: Chart(
                  stream: haveSensor
                      ? userAccData(sampleInterval)
                      : sineData(sampleInterval),
                  strokeWidth: haveSensor ? 1 : 3,
                  showMax: true,
                  showCurrent: true,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Gravity',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Expanded(
              flex: 9,
              child: GraphCard(
                chart: Chart(
                  stream: haveSensor
                      ? accData(sampleInterval)
                      : sineData(sampleInterval),
                  strokeWidth: haveSensor ? 1 : 3,
                  showMax: true,
                  showCurrent: true,
                ),
              ),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }
}

class GraphCard extends StatefulWidget {
  final Chart chart;

  const GraphCard({
    super.key,
    required this.chart,
  });

  @override
  State<GraphCard> createState() => _GraphCardState();
}

class _GraphCardState extends State<GraphCard> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: widget.chart,
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
    this.showMax = false,
    this.showCurrent = false,
  });

  final Stream<ChartPoint> stream;
  final double strokeWidth;
  final Color? lineColor;
  final bool showMax;
  final bool showCurrent;

  @override
  ConsumerState<Chart> createState() => _ChartState();
}

class _ChartState extends ConsumerState<Chart> {
  final _line = LineChartData(limit: limit);
  double _max = 0;
  double _current = 0;

  @override
  void initState() {
    widget.stream.listen((data) {
      _line.addData(data.time, data.value);
      if (ref.read(pausedProvider)) {
        return;
      }
      setState(() {
        _max = _line.maxY;
        _current = _line.currentY;
      });
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(restartProvider, (prev, next) {
      _line.reset();
      setState(() {
        _max = 0;
        _current = 0;
      });
    });
    return Column(
      children: [
        if (widget.showMax)
          Text(
            'maximum: ${_max.toStringAsFixed(2)} m/s²',
            style: const TextStyle(fontFamily: 'robot-mono'),
          ),
        if (widget.showCurrent)
          Text(
            'current: ${_current.toStringAsFixed(2)} m/s²',
            style: const TextStyle(fontFamily: 'robot-mono'),
          ),
        Expanded(
          child: LineChart(
            lines: [
              _line.asLine(
                color:
                    widget.lineColor ?? Theme.of(context).colorScheme.onSurface,
                strokeWidth: widget.strokeWidth,
              ),
            ],
            labelCount: 5,
          ),
        ),
      ],
    );
  }
}
