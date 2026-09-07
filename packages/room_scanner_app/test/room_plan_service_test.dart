import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:room_scanner_ar/services/room_plan_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.bet0.ARchScan/roomplan');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('consulta soporte usando el contrato del canal nativo', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'isSupported');
      return true;
    });

    expect(await RoomPlanService.isSupported(), isTrue);
  });

  test('convierte el resultado nativo en un ambiente persistible', () async {
    final payload = <String, dynamic>{
      'schemaVersion': 2,
      'walls': [
        _wall(0, 0, 4, 0),
        _wall(4, 0, 4, 3),
        _wall(4, 3, 0, 3),
        _wall(0, 3, 0, 0),
      ],
      'openings': <Map<String, dynamic>>[],
    };

    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'startScanning');
      return jsonEncode(payload);
    });

    final room = await RoomPlanService.scanRoom(
      roomId: 'room-id',
      roomName: 'RoomPlan',
    );

    expect(room, isNotNull);
    final scannedRoom = room!;
    expect(scannedRoom.id, 'room-id');
    expect(scannedRoom.name, 'RoomPlan');
    expect(scannedRoom.isClosed, isTrue);
    expect(scannedRoom.points, hasLength(4));
  });
}

Map<String, dynamic> _wall(
  double ax,
  double az,
  double bx,
  double bz,
) {
  return <String, dynamic>{
    'start': <String, dynamic>{'x': ax, 'y': 0.0, 'z': az},
    'end': <String, dynamic>{'x': bx, 'y': 0.0, 'z': bz},
  };
}
