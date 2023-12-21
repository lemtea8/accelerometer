// import 'dart:async';
// import 'dart:math';
// import 'dart:ui';

// import 'package:fl_chart/fl_chart.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:sensors_plus/sensors_plus.dart';

// void main() {
//   runApp(const MyApp());
// }

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   // This widget is the root of your application.
//   @override
//   Widget build(BuildContext context) {
//     return ProviderScope(
//       child: MaterialApp(
//         title: 'Flutter Demo',
//         theme: ThemeData(
//           colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
//           useMaterial3: true,
//         ),
//         home: const AccMeter(),
//       ),
//     );
//   }
// }

// class AccMeter extends ConsumerStatefulWidget {
//   const AccMeter({super.key});

//   @override
//   ConsumerState<AccMeter> createState() => _AccMeterState();
// }

// const limitCount = 300;
// const sampleInterval = SensorInterval.gameInterval;

// class FlSpots extends ChangeNotifier {
//   // add an element to prevent "Bad state: no element" when calling first and last
//   final spots = <FlSpot>[const FlSpot(0, 0)];
//   int count = 0;

//   void add(FlSpot spot) {
//     count++;
//     while (spots.length + 1 > limitCount) {
//       spots.removeAt(0);
//     }

//     spots.add(spot);
//     if (count % 3 == 0) {
//       notifyListeners();
//     }
//   }

//   FlSpot get first => spots.first;
//   FlSpot get last => spots.last;
// }

// final pausedProvider = StateProvider((ref) => false);
// final maxValueProvider = StateProvider((ref) => 0.0);
// final pointsProvider = ChangeNotifierProvider((ref) => FlSpots());

// class _AccMeterState extends ConsumerState<AccMeter> {
//   late StreamSubscription _subscription;

//   double xValue = 0.0;

//   @override
//   void initState() {
//     final stream = userAccelerometerEventStream(
//       samplingPeriod: sampleInterval,
//     );
//     stream.listen(
//       (event) => updateData(event, ref),
//       cancelOnError: true,
//     );
//     super.initState();
//   }

//   @override
//   void dispose() {
//     _subscription.cancel();
//     super.dispose();
//   }

//   void updateData(UserAccelerometerEvent event, WidgetRef ref) {
//     if (ref.read(pausedProvider)) {
//       return;
//     }
//     final sum = event.x * event.x + event.y * event.y + event.z * event.z;
//     final acc = sqrt(sum);

//     if (acc > ref.read(maxValueProvider)) {
//       ref.read(maxValueProvider.notifier).state = acc;
//     }

//     xValue += sampleInterval.inMilliseconds;
//     ref.read(pointsProvider.notifier).add(FlSpot(xValue, acc));
//   }

//   @override
//   Widget build(BuildContext context) {
//     return SafeArea(
//       child: Scaffold(
//         floatingActionButton: FloatingActionButton(
//           onPressed: () {
//             final v = ref.read(pausedProvider);
//             ref.read(pausedProvider.notifier).state = !v;
//           },
//           child: Consumer(
//             builder: (context, ref, _) {
//               if (ref.watch(pausedProvider)) {
//                 return const Icon(Icons.play_arrow);
//               }
//               return const Icon(Icons.pause);
//             },
//           ),
//         ),
//         body: const Center(
//           child: Chart(),
//         ),
//       ),
//     );
//   }
// }

// class Chart extends StatelessWidget {
//   const Chart({super.key});

//   @override
//   Widget build(BuildContext context) {
//     final sampleRate = const Duration(seconds: 1).inMicroseconds /
//         sampleInterval.inMicroseconds;

//     return Column(
//       mainAxisAlignment: MainAxisAlignment.center,
//       children: [
//         const SizedBox(height: 8),
//         Text(
//           'Accelerometer (${sampleRate.round().toStringAsFixed(1)} hz)',
//           style: Theme.of(context).textTheme.titleLarge,
//         ),
//         Consumer(
//           builder: (context, ref, _) {
//             final maxValue = ref.read(maxValueProvider).toStringAsFixed(2);
//             final current = ref.watch(pointsProvider).last.y.toStringAsFixed(2);
//             final text = 'maximum: $maxValue, current: $current';
//             return Text(
//               text,
//               style: const TextStyle(
//                 fontFeatures: [FontFeature.tabularFigures()],
//               ),
//             );
//           },
//         ),
//         Expanded(
//           child: Padding(
//             padding: const EdgeInsets.fromLTRB(4, 16, 12, 72),
//             child: Consumer(
//               builder: (context, ref, _) {
//                 final points = ref.watch(pointsProvider);
//                 return LineChart(
//                   LineChartData(
//                     minX: points.first.x,
//                     maxX: points.first.x +
//                         limitCount * sampleInterval.inMilliseconds,
//                     minY: 0,
//                     clipData: const FlClipData.all(),
//                     gridData: const FlGridData(
//                       show: true,
//                       drawVerticalLine: false,
//                     ),
//                     borderData: FlBorderData(show: false),
//                     lineBarsData: [
//                       LineChartBarData(
//                         spots: points.spots,
//                         color: Colors.black,
//                         dotData: const FlDotData(
//                           show: false,
//                         ),
//                         isCurved: false,
//                       ),
//                     ],
//                     titlesData: const FlTitlesData(
//                       leftTitles: AxisTitles(
//                         axisNameSize: 24,
//                         axisNameWidget: Text(
//                           'm/s²',
//                         ),
//                         sideTitles: SideTitles(
//                           showTitles: true,
//                           reservedSize: 60,
//                           interval: 4,
//                         ),
//                       ),
//                       topTitles: AxisTitles(),
//                       rightTitles: AxisTitles(),
//                       bottomTitles: AxisTitles(),
//                     ),
//                   ),
//                   duration: Duration.zero,
//                 );
//               },
//             ),
//           ),
//         )
//       ],
//     );
//   }
// }
