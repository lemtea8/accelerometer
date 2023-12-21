// import 'dart:math';

// import 'package:flutter/material.dart';
// import 'package:sensors_plus/sensors_plus.dart';
// import 'package:syncfusion_flutter_charts/charts.dart';

// void main() {
//   runApp(const MyApp());
// }

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   // This widget is the root of your application.
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Flutter Demo',
//       theme: ThemeData(
//         colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
//         useMaterial3: true,
//       ),
//       home: const MyHomePage(title: 'Accelerometer'),
//     );
//   }
// }

// class MyHomePage extends StatefulWidget {
//   const MyHomePage({super.key, required this.title});

//   final String title;

//   @override
//   State<MyHomePage> createState() => _MyHomePageState();
// }

// class _MyHomePageState extends State<MyHomePage> {
//   final startedTime = DateTime.now();

//   late ChartSeriesController _chartSeriesController;
//   List<LiveData> chartData = [];

//   @override
//   void initState() {
//     userAccelerometerEvents.listen(
//       updateData,
//       onError: (error) {
//         print(error);
//       },
//       cancelOnError: true,
//     );
//     super.initState();
//   }

//   void updateData(UserAccelerometerEvent event) {
//     final sum = event.x * event.x + event.y * event.y + event.z * event.z;
//     final acc = sqrt(sum);
//     chartData.add(LiveData(acc, DateTime.now().difference(startedTime)));

//     if (chartData.length > 100) {
//       chartData.removeAt(0);
//       _chartSeriesController.updateDataSource(
//         addedDataIndex: chartData.length - 1,
//         removedDataIndex: 0,
//       );
//     } else {
//       _chartSeriesController.updateDataSource(
//         addedDataIndex: chartData.length - 1,
//       );
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return SafeArea(
//       child: Scaffold(
//         appBar: AppBar(
//           backgroundColor: Theme.of(context).colorScheme.inversePrimary,
//           title: Text(widget.title),
//         ),
//         body: Center(
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: <Widget>[
//               SfCartesianChart(
//                 title: ChartTitle(text: 'Accelerometer'),
//                 series: [
//                   LineSeries(
//                     onRendererCreated: (controller) {
//                       _chartSeriesController = controller;
//                     },
//                     dataSource: chartData,
//                     xValueMapper: (LiveData d, _) => d.elapsed.inMilliseconds,
//                     yValueMapper: (LiveData d, _) => d.acc,
//                     xAxisName: 'ms',
//                     yAxisName: 'm/s^2',
//                   )
//                 ],
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

// class LiveData {
//   final double acc;
//   final Duration elapsed;

//   const LiveData(this.acc, this.elapsed);
// }
