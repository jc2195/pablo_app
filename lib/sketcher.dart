import 'package:drawing_app/drawn_line.dart';
import 'package:flutter/material.dart';
import 'package:perfect_freehand/perfect_freehand.dart';

class Sketcher extends CustomPainter {
  final List<DrawnLine> lines;

  Sketcher({this.lines});

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..color = Colors.redAccent
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 5.0;

    for (int i = 0; i < lines.length; ++i) {
      if (lines[i] == null) continue;
      paint.color = lines[i].color;
      // print(lines[i].width);
      final outlinePoints = getStroke(lines[i].path, size: lines[i].width, isComplete: true, simulatePressure: false, thinning: 0.3, capStart: true);
      final path = Path();
      if (outlinePoints.isEmpty) {
        return;
      } else if (outlinePoints.length < 2) {
        path.addOval(Rect.fromCircle(
            center: Offset(outlinePoints[0].x, outlinePoints[0].y), radius: 0.1));
      } else {
        path.moveTo(outlinePoints[0].x, outlinePoints[0].y);

        for (int i = 1; i < outlinePoints.length - 1; ++i) {
          final p0 = outlinePoints[i];
          final p1 = outlinePoints[i + 1];
          path.quadraticBezierTo(
              p0.x, p0.y, (p0.x + p1.x) / 2, (p0.y + p1.y) / 2);
        }
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(Sketcher oldDelegate) {
    return true;
  }
}
