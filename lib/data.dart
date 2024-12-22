import 'dart:async';
import 'dart:math' as math;

import 'package:sensors_plus/sensors_plus.dart';

class ChartPoint {
  final double time;
  final double value;

  const ChartPoint(this.time, this.value);
}

Stream<ChartPoint> userAccData(Duration samplingPeriod) async* {
  final stream = userAccelerometerEventStream(samplingPeriod: samplingPeriod);
  await for (final event in stream) {
    final sum = event.x * event.x + event.y * event.y + event.z * event.z;
    final acc = math.sqrt(sum);
    yield ChartPoint(event.timestamp.millisecondsSinceEpoch.toDouble(), acc);
  }
}

Stream<ChartPoint> accData(Duration samplingPeriod) async* {
  final stream = accelerometerEventStream(samplingPeriod: samplingPeriod);
  await for (final event in stream) {
    final sum = event.x * event.x + event.y * event.y + event.z * event.z;
    final acc = math.sqrt(sum);
    yield ChartPoint(event.timestamp.millisecondsSinceEpoch.toDouble(), acc);
  }
}

Stream<ChartPoint> sineData(Duration smaplingPeriod) async* {
  final sineFunc = _randomSineWaveFunction();
  var x = 0.0;
  while (true) {
    await Future.delayed(smaplingPeriod);
    yield ChartPoint(x, sineFunc(x));
    x += 0.05;
  }
}

double Function(double x) _randomSineWaveFunction() {
  final rand = math.Random();

  final mul1 = rand.nextInt(9) + 7; // 7-15
  final mul2 = rand.nextInt(6) + 16; // 16-21
  final div1 = rand.nextInt(6) + 4; // 4-9
  final div2 = rand.nextInt(5) + 10; // 10-14
  return (double x) =>
      math.sin(mul1 * x / div1) +
      math.cos(mul2 * x / div2) -
      math.sin(mul2 * x / div1) -
      math.cos(mul1 * x / div2);
}
