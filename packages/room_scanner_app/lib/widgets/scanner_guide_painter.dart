import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:room_scanner_core/room_scanner_core.dart';
import '../services/continuation_display_frame.dart';

class ScannerGuidePainter
    extends CustomPainter {
  final List<ARPoint> points;
  final List<WallFeature> features;
  final List<RoomModel> previousRooms;
  final ScanContinuationReference? continuationReference;

  const ScannerGuidePainter({
    required this.points,
    required this.features,
    required this.previousRooms,
    required this.continuationReference,
  });

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final previousPoints = <ARPoint>[
      for (final room in previousRooms)
        for (final point in room.points)
          _globalToLocal(point),
    ];

    final frame = ContinuationDisplayFrame(continuationReference);
    final visiblePoints = <ARPoint>[
      ...previousPoints,
      ...points,
    ].map(frame.toDisplay).toList();

    if (visiblePoints.isEmpty) {
      _drawCenterGuide(
        canvas,        size,
      );
      return;
    }

    final center =
        Offset(
      size.width / 2,
      size.height / 2,
    );
    final scale =
        _calculateScale(
      visiblePoints,
      size,    );

    final projected =
        points.map(frame.toDisplay).map((point) {
      return Offset(
        center.dx +
            point.x * scale,
        center.dy +
            point.z * scale,
      );
    }).toList();

    Offset projectPoint(ARPoint point) {
      point = frame.toDisplay(point);
      return Offset(
        center.dx + point.x * scale,
        center.dy + point.z * scale,
      );
    }

    _drawPreviousPlan(
      canvas,
      projectPoint,
    );

    final linePaint =
        Paint()
          ..style =
              PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = Colors.black.withValues(
            alpha: 0.92,
          )
          ..strokeCap =
              StrokeCap.round;

    for (int i = 0;
        i < projected.length - 1;
        i++) {
      canvas.drawLine(
        projected[i],        projected[i + 1],
        linePaint,
      );    }

    for (final feature in features) {      final featurePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth =
            feature.id ==
                    continuationReference?.featureId
                ? 9
                : 8
        ..strokeCap = StrokeCap.round
        ..color = feature.id ==
                continuationReference?.featureId
            ? const Color(0xFF00C853)
            : feature.type == FeatureType.door
                ? const Color(0xFFFF8A00)
                : const Color(0xFFD500F9);

      canvas.drawLine(
        projectPoint(feature.start),
        projectPoint(feature.end),
        featurePaint,
      );
    }

    for (int i = 0;
        i < projected.length;
        i++) {
      final pointPaint =
          Paint()
            ..style =
                PaintingStyle.fill;

      canvas.drawCircle(
        projected[i],
        i == 0 ? 10 : 8,
        pointPaint,
      );

      final textPainter =
          TextPainter(
        text: TextSpan(
          text:
              '${i + 1}',
          style:
              const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight:
                FontWeight.bold,
          ),
        ),
        textDirection:
            TextDirection.ltr,
      );

      textPainter.layout();

      textPainter.paint(
        canvas,
        projected[i] -
            Offset(
              textPainter.width / 2,
              textPainter.height / 2,
            ),
      );
    }

    if (continuationReference != null) {
      _drawContinuationPoint(
        canvas,
        projectPoint(
          ARPoint(
            x: 0.0,
            y: 0.0,
            z: 0.0,
          ),
        ),      );    }

    _drawCenterGuide(
      canvas,
      size,
      onlyCross: true,
    );
  }

  void _drawPreviousPlan(
    Canvas canvas,
    Offset Function(ARPoint point) project,
  ) {
    if (previousRooms.isEmpty) {
      return;
    }

    final wallPaint = Paint()
      ..color = const Color(0xFF448AFF).withValues(
        alpha: 0.55,      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeJoin = StrokeJoin.round;

    final roomFillPaint = Paint()
      ..color = const Color(0xFF448AFF).withValues(
        alpha: 0.08,
      )
      ..style = PaintingStyle.fill;

    for (final room in previousRooms) {
      if (room.points.length < 2) {
        continue;
      }

      final path = Path();
      final first = project(
        _globalToLocal(room.points.first),
      );
      path.moveTo(first.dx, first.dy);

      for (final point in room.points.skip(1)) {
        final projected = project(
          _globalToLocal(point),
        );
        path.lineTo(
          projected.dx,
          projected.dy,
        );
      }

      if (room.isClosed || room.points.length >= 3) {
        path.close();
        canvas.drawPath(path, roomFillPaint);
      }

      canvas.drawPath(path, wallPaint);

      for (final feature in room.features) {
        final selected = continuationReference != null &&
            room.id == continuationReference!.sourceRoomId &&
            feature.id == continuationReference!.featureId;

        final featurePaint = Paint()
          ..color = selected
              ? const Color(0xFF00C853)
              : feature.type == FeatureType.door
                  ? const Color(0xFFFF8A00).withValues(
                      alpha: 0.60,
                    )
                  : const Color(0xFFD500F9).withValues(
                      alpha: 0.60,
                    )
          ..strokeWidth = selected ? 9 : 5
          ..strokeCap = StrokeCap.round;

        canvas.drawLine(
          project(_globalToLocal(feature.start)),
          project(_globalToLocal(feature.end)),
          featurePaint,
        );
      }
    }
  }

  ARPoint _globalToLocal(
    ARPoint point,
  ) {
    final reference = continuationReference;

    if (reference == null) {
      return point;
    }

    final openingDx =
        reference.globalEnd.x - reference.globalStart.x;
    final openingDz =
        reference.globalEnd.z - reference.globalStart.z;
    final openingLength =
        math.sqrt(
      openingDx * openingDx + openingDz * openingDz,
    );

    if (openingLength <= 0.000001) {
      return point;
    }

    final tangentX = openingDx / openingLength;
    final tangentZ = openingDz / openingLength;
    final forwardX =
        reference.side == OpeningConnectionSide.left
            ? -tangentZ
            : tangentZ;
    final forwardZ =
        reference.side == OpeningConnectionSide.left
            ? tangentX
            : -tangentX;
    final rightX = forwardZ;
    final rightZ = -forwardX;
    final dx = point.x - reference.origin.x;
    final dz = point.z - reference.origin.z;

    return ARPoint(
      x: dx * rightX + dz * rightZ,
      y: point.y - reference.origin.y,
      z: dx * forwardX + dz * forwardZ,
    );
  }

  void _drawContinuationPoint(
    Canvas canvas,
    Offset point,
  ) {
    canvas.drawCircle(
      point,
      10,
      Paint()..color = const Color(0xFF00C853),
    );
    canvas.drawCircle(
      point,
      4,
      Paint()..color = Colors.white,
    );
  }

  void _drawCenterGuide(    Canvas canvas,
    Size size, {
    bool onlyCross = false,
  }) {
    final center =
        Offset(
      size.width / 2,
      size.height / 2,
    );

    final paint =        Paint()
          ..style =
              PaintingStyle.stroke
          ..strokeWidth = 2;

    canvas.drawCircle(
      center,
      12,
      paint,
    );

    canvas.drawLine(
      Offset(
        center.dx - 20,
        center.dy,      ),
      Offset(
        center.dx + 20,
        center.dy,
      ),
      paint,
    );

    canvas.drawLine(
      Offset(
        center.dx,        center.dy - 20,
      ),
      Offset(
        center.dx,
        center.dy + 20,
      ),
      paint,
    );
  }

  double _calculateScale(
    List<ARPoint> points,
    Size size,
  ) {
    if (points.length <= 1) {
      return 80;
    }

    double minX = points.first.x;
    double maxX = points.first.x;
    double minZ = points.first.z;
    double maxZ = points.first.z;

    for (final point in points) {
      minX =
          mathMin(
        minX,
        point.x,
      );

      maxX =
          mathMax(
        maxX,
        point.x,
      );

      minZ =
          mathMin(
        minZ,
        point.z,
      );

      maxZ =
          mathMax(
        maxZ,
        point.z,
      );
    }

    final maxAbsoluteX =
        mathMax(minX.abs(), maxX.abs());
    final maxAbsoluteZ =
        mathMax(minZ.abs(), maxZ.abs());

    if (maxAbsoluteX <= 0.000001 &&
        maxAbsoluteZ <= 0.000001) {
      return 80;
    }

    final scaleX = maxAbsoluteX <= 0.000001
        ? double.infinity
        : (size.width * 0.42) / maxAbsoluteX;
    final scaleZ = maxAbsoluteZ <= 0.000001
        ? double.infinity
        : (size.height * 0.27) / maxAbsoluteZ;
    final calculated =
        scaleX < scaleZ ? scaleX : scaleZ;

    return calculated > 90 ? 90 : calculated;
  }

  double mathMin(
    double a,
    double b,
  ) =>
      a < b ? a : b;

  double mathMax(
    double a,
    double b,
  ) =>
      a > b ? a : b;

  @override
  bool shouldRepaint(
    covariant ScannerGuidePainter oldDelegate,
  ) {
    return oldDelegate.points !=
            points ||
        oldDelegate.features != features ||
        oldDelegate.previousRooms != previousRooms ||
        oldDelegate.continuationReference !=
            continuationReference;
  }
}
