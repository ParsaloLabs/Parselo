import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../theme/theme.dart';

class SignaturePad extends StatefulWidget {
  final Function(String base64)? onSigned;

  const SignaturePad({Key? key, this.onSigned}) : super(key: key);

  @override
  State<SignaturePad> createState() => SignaturePadState();
}

class SignaturePadState extends State<SignaturePad> {
  final List<Offset?> _points = [];

  void clear() {
    setState(() {
      _points.clear();
    });
    if (widget.onSigned != null) {
      widget.onSigned!('');
    }
  }

  bool get isEmpty => _points.isEmpty;

  // Convert the points into a Base64 PNG image string
  Future<String?> toDataURL() async {
    if (isEmpty) return null;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 300, 150));
    
    // Draw background
    final bgPaint = Paint()..color = Colors.white;
    canvas.drawRect(const Rect.fromLTWH(0, 0, 300, 150), bgPaint);

    final paint = Paint()
      ..color = AppColors.brand
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.5;

    for (int i = 0; i < _points.length - 1; i++) {
      if (_points[i] != null && _points[i + 1] != null) {
        canvas.drawLine(_points[i]!, _points[i + 1]!, paint);
      }
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(300, 150);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return null;
    
    final bytes = byteData.buffer.asUint8List();
    final base64String = base64Encode(bytes);
    return 'data:image/png;base64,$base64String';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 160,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border, width: 1),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: GestureDetector(
              onPanUpdate: (DragUpdateDetails details) {
                final box = context.findRenderObject() as RenderBox;
                final point = box.globalToLocal(details.globalPosition);
                // Clamp point within canvas heights
                if (point.dx >= 0 && point.dx <= box.size.width && point.dy >= 0 && point.dy <= 160) {
                  setState(() {
                    _points.add(point);
                  });
                }
              },
              onPanEnd: (DragEndDetails details) {
                _points.add(null);
                _triggerCallback();
              },
              child: CustomPaint(
                painter: SignaturePainter(_points),
                size: Size.infinite,
              ),
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: clear,
              child: const Text(
                'Clear signature',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ),
            const Text(
              'Sign inside the box',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
        )
      ],
    );
  }

  void _triggerCallback() async {
    if (widget.onSigned != null) {
      final base64 = await toDataURL();
      if (base64 != null) {
        widget.onSigned!(base64);
      }
    }
  }
}

class SignaturePainter extends CustomPainter {
  final List<Offset?> points;

  SignaturePainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.brand
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.5;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!, points[i + 1]!, paint);
      }
    }
  }

  @override
  bool shouldRepaint(SignaturePainter oldDelegate) => true;
}
