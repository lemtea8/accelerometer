import 'dart:math' as math;

import 'package:accelerometer/buffered_list.dart';
import 'package:flutter/material.dart';

// Multiple lines are not supported yet
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
  @override
  void initState() {
    super.initState();
  }

  // Keep this function cost as less as possible
  @override
  Widget build(BuildContext context) {
    if (widget.lines[0].data.length <= 1) {
      return const SizedBox();
    }

    final data = widget.lines[0].data;

    // Estimate maxX if not specified
    final xStep = (data._xData.last - data._xData.first) / data._xData.length;
    final minX = widget.minX ?? data._xData.first;
    final maxX = widget.maxX ?? data._xData.first + xStep * data.limit;

    final minY = widget.minY ?? data._minY;
    final maxY = widget.maxY ?? data._maxY;

    final fontSize = Theme.of(context).textTheme.labelLarge!.fontSize!;
    final labelSize = widget.lableSize ?? fontSize;
    final double labelWidth = widget.showLabel ? labelSize * 3 : 0;
    final double topBottomPadding = widget.showLabel ? labelSize / 2 : 0;

    return Stack(
      children: [
        // meter
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _MeterPainter(
                color: Theme.of(context).colorScheme.onSurface,
                showLabel: widget.showLabel,
                labelFontSize: labelSize,
                labelCount: widget.labelCount,
                labelWidth: labelWidth,
                minY: minY,
                maxY: maxY,
              ),
              willChange: true,
            ),
          ),
        ),
        // chart
        Positioned.fill(
          child: Padding(
            padding: EdgeInsets.only(
              left: labelWidth,
              // these paddings are for aligning labels
              top: topBottomPadding,
              bottom: topBottomPadding,
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
                willChange: true,
              ),
            ),
          ),
        ),
      ],
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
  // data-oriented design
  final BufferedFixedLengthList _xData;
  final BufferedFixedLengthList _yData;
  final int limit;

  LineChartData({
    required this.limit,
  })  : _xData = BufferedFixedLengthList(limit),
        _yData = BufferedFixedLengthList(limit);

  // min y value in array
  double _minY = double.infinity;
  // max y value in array
  double _maxY = -double.infinity;

  void addData(double x, double y) {
    while (_yData.length + 1 > limit) {
      final pop = _yData[0];
      _xData.removeFirst();
      _yData.removeFirst();
      // the removed one is region max, find a new one.
      // can have a better way to do this, but currently is good enough
      if ((pop - _maxY).abs() < 1e-4) {
        _maxY = _yData.maximum();
      }
      if ((pop - _minY).abs() < 1e-4) {
        _minY = _yData.minimum();
      }
    }

    _maxY = math.max(_maxY, y);
    _minY = math.min(_minY, y);
    _xData.add(x);
    _yData.add(y);
  }

  void reset() {
    _xData.clear();
    _yData.clear();
    _minY = double.infinity;
    _maxY = -double.infinity;
  }

  Line asLine({required Color color, required double strokeWidth}) {
    return Line._private(this, color, strokeWidth);
  }

  bool get isEmpty => _xData.isEmpty;
  int get length => _xData.length;

  double get firstX => _xData.first;
  double get lastX => _xData.last;
  (double, double) operator [](int index) => (_xData[index], _yData[index]);

  double get minY => _minY;
  double get maxY => _maxY;

  double get currentY => _yData.last;
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
    final xLen = maxX - minX;
    final yLen = maxY - minY;

    final stepX = size.width / xLen;
    final stepY = size.height / yLen;
    // the canvas start from the top left corner so y needs to reverse (height - y)
    final data = line.data;
    // normalize
    final x = (data._xData[0] - minX) * stepX;
    final y = (data._yData[0] - minY) * stepY;

    // go to the first point
    path.moveTo(x, size.height - y);
    for (int i = 1; i < line.data.length; i++) {
      // normalize
      final x = (data._xData[i] - minX) * stepX;
      final y = (data._yData[i] - minY) * stepY;
      // reverse (height - y)
      path.lineTo(x, size.height - y);
    }
    canvas.clipRect(Rect.fromLTRB(0, 0, size.width, size.height));
    canvas.drawPath(path, paint);
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
      ..color = color.withAlpha(50)
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
        var text = meterValue.toStringAsFixed(2);
        // Prevent -0.00 text when value is a small negative number
        if (text == "-0.00") {
          text = "0.00";
        }
        final textSpan = TextSpan(
          text: text,
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
