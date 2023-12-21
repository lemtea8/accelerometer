import 'dart:math';

import 'package:accelerometer/vector.dart';
import 'package:flutter/material.dart';

class LineChart extends StatefulWidget {
  final List<Line> lines;
  final bool showLabel;
  final int? labelCount;
  final double? lableSize;
  final double? minX;
  final double? maxX;
  final double? minY;
  final double? maxY;

  const LineChart({
    super.key,
    required this.lines,
    this.labelCount,
    this.showLabel = true,
    this.lableSize,
    this.minX,
    this.maxX,
    this.minY,
    this.maxY,
  });

  @override
  State<LineChart> createState() => _LineChartState();
}

class _LineChartState extends State<LineChart> {
  double labelWidth = 40.0;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final minX = widget.minX ?? widget.lines[0].data.first.x;
    final maxX = widget.maxX ?? widget.lines[0].data.last.x;
    final minY = widget.minY ?? widget.lines[0].data._minY;
    final maxY = widget.maxY ?? widget.lines[0].data._maxY;
    final labelSize =
        widget.lableSize ?? Theme.of(context).textTheme.labelLarge!.fontSize!;
    labelWidth = widget.showLabel ? labelSize * 3 : 0;
    return ClipRect(
      child: Stack(
        children: [
          // meter
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _MeterPainter(
                  color: Theme.of(context).colorScheme.onBackground,
                  showLabel: widget.showLabel,
                  labelFontSize: labelSize,
                  labelCount: widget.labelCount,
                  labelWidth: labelWidth,
                  minY: minY,
                  maxY: maxY,
                ),
              ),
            ),
          ),
          // chart
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(
                left: labelWidth,
                top: labelSize / 2,
                bottom: labelSize / 2,
              ),
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _ChartPainter(
                    widget.lines,
                    minX: minX,
                    maxX: maxX,
                    minY: minY,
                    maxY: maxY,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class Line {
  final LineChartData data;
  final Color color;
  final double strokeWidth;

  const Line._private(this.data, this.color, this.strokeWidth);
}

class LineChartData {
  final List<Vector2> _points = [];
  final int limit;

  LineChartData({
    required this.limit,
  });

  // min y value in array
  double _minY = double.infinity;
  // max y value in array
  double _maxY = -double.infinity;

  void addData(Vector2 data) {
    while (_points.length + 1 > limit) {
      final pop = _points[0].y;
      _points.removeAt(0);
      // the removed one is region max, find a new one.
      // can have a better way to do this, but currently is good enough
      if ((pop - _maxY).abs() < 1e-6) {
        _maxY = _points.reduce((value, element) {
          if (value.y > element.y) {
            return value;
          }
          return element;
        }).y;
      }
      if ((pop - _minY).abs() < 1e-6) {
        _minY = _points.reduce((value, element) {
          if (value.y < element.y) {
            return value;
          }
          return element;
        }).y;
      }
    }

    if (data.y > _maxY) {
      _maxY = data.y;
    }
    if (data.y < _minY) {
      _minY = data.y;
    }
    _points.add(data);
  }

  void reset() {
    _points.clear();
    _minY = double.infinity;
    _maxY = -double.infinity;
  }

  Line asLine({required Color color, required double strokeWidth}) {
    return Line._private(this, color, strokeWidth);
  }

  bool get isEmpty => _points.isEmpty;
  int get length => _points.length;

  Vector2 get first => _points.first;
  Vector2 get last => _points.last;
  Vector2 operator [](int index) => _points[index];

  double get minY => _minY;
  double get maxY => _maxY;
}

class _ChartPainter extends CustomPainter {
  final List<Line> lines;
  final double minX;
  final double maxX;
  final double minY;
  final double maxY;

  const _ChartPainter(
    this.lines, {
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final line in lines) {
      paintLine(canvas, size, line);
    }
  }

  void paintLine(Canvas canvas, Size size, Line line) {
    Paint paint = Paint()
      ..color = line.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = line.strokeWidth;

    Path path = Path();
    // the canvas start from the top left corner so y needs to reverse (height - y)
    final first = normalize(line.data.first, size);
    // go to the first point
    path.moveTo(first.x, size.height - first.y);
    for (int i = 1; i < line.data.length; i++) {
      final vec2 = normalize(line.data[i], size);
      path.lineTo(vec2.x, size.height - vec2.y);
    }

    canvas.drawPath(path, paint);
  }

  Vector2 normalize(Vector2 vec, Size size) {
    final stepX = size.width / (maxX - minX);
    final stepY = size.height / (maxY - minY);

    return Vector2((vec.x - minX) * stepX, (vec.y - minY) * stepY);
  }

  // set this to true to prevent stutter!
  @override
  bool shouldRepaint(_ChartPainter oldDelegate) {
    return true;
  }

  @override
  bool shouldRebuildSemantics(_ChartPainter oldDelegate) {
    return false;
  }
}

class _MeterPainter extends CustomPainter {
  final Color color;
  final bool showLabel;
  final int? labelCount;
  final double minY;
  final double maxY;
  final double labelFontSize;
  final double labelWidth;

  const _MeterPainter({
    required this.minY,
    required this.maxY,
    required this.showLabel,
    this.labelCount,
    required this.color,
    required this.labelFontSize,
    required this.labelWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // for painting lines
    Paint paint = Paint()
      ..color = color.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    int divisions;
    if (labelCount != null) {
      divisions = labelCount! - 1;
    } else {
      // how many areas between meters
      divisions = (size.height / (labelFontSize * 2)).floor();
      // round to multiple of 2, so 0.00 exists
      divisions = (divisions >> 1) << 1;
    }
    // prevent division by zero and negative numbers
    divisions = divisions <= 0 ? 1 : divisions;
    double step = (maxY - minY) / divisions;

    final textStyle = TextStyle(
      color: color,
      fontSize: labelFontSize,
      fontFamily: 'anonymous_pro',
    );

    double meterValue = minY;
    // subtract fontSize to prevent overflow
    final adjustedHight = size.height - labelFontSize;
    for (int i = 0; i <= divisions; i++) {
      final yPos = adjustedHight - (adjustedHight * i / divisions);
      final offset = Offset(0, yPos);
      if (showLabel) {
        final textSpan = TextSpan(
          // prevent -0.00
          text: meterValue.roundToPrecision(2).toStringAsFixed(2),
          style: textStyle,
        );
        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
        );
        textPainter.layout(minWidth: 0);
        textPainter.paint(canvas, offset);
      }

      final lineStart = offset.translate(labelWidth, labelFontSize / 2);
      final lineEnd = lineStart.translate(size.width - labelWidth, 0);
      canvas.drawLine(lineStart, lineEnd, paint);

      meterValue += step;
    }
  }

  // only repaint when value changes or color changes
  @override
  bool shouldRepaint(_MeterPainter oldDelegate) {
    return oldDelegate.maxY != maxY ||
        oldDelegate.minY != minY ||
        oldDelegate.color != color;
  }

  @override
  bool shouldRebuildSemantics(_MeterPainter oldDelegate) {
    return false;
  }
}

extension RoundDouble on double {
  double roundToPrecision(int precision) {
    final val = pow(10.0, precision);
    return ((this * val).round().toDouble() / val);
  }
}
