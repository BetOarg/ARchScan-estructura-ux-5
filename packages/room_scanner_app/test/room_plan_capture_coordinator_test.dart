import 'package:flutter_test/flutter_test.dart';
import 'package:room_scanner_ar/providers/floor_plan_provider.dart';
import 'package:room_scanner_ar/services/room_plan_capture_coordinator.dart';
import 'package:room_scanner_core/room_scanner_core.dart';

void main() {
  test('persiste la habitación capturada mediante el contrato del proyecto',
      () async {
    var persistenceCalls = 0;
    List<RoomModel>? persistedRooms;
    final provider = FloorPlanProvider()
      ..loadProject(uuid: 'project', name: 'Home', rooms: const [])
      ..persister = ({required uuid, required name, required rooms}) async {
        persistenceCalls++;
        persistedRooms = rooms;
      };
    addTearDown(provider.dispose);

    final coordinator = RoomPlanCaptureCoordinator(
      capture: ({
        required roomId,
        required roomName,
        required roomType,
      }) async =>
          RoomModel(
        id: roomId,
        name: roomName,
        type: roomType,
        isClosed: true,
        points: [
          ARPoint(x: 0, y: 0, z: 0),
          ARPoint(x: 3, y: 0, z: 0),
          ARPoint(x: 3, y: 0, z: 2),
          ARPoint(x: 0, y: 0, z: 2),
        ],
      ),
    );

    final room = await coordinator.captureAndPersist(
      floorPlanProvider: provider,
      roomName: 'Office',
    );

    expect(room, isNotNull);
    expect(provider.completedRooms.single.name, 'Office');
    expect(persistenceCalls, 1);
    expect(persistedRooms!.single.toJson(), room!.toJson());
  });

  test('cancelar RoomPlan no modifica ni persiste el proyecto', () async {
    var persistenceCalls = 0;
    final provider = FloorPlanProvider()
      ..loadProject(uuid: 'project', name: 'Home', rooms: const [])
      ..persister = ({required uuid, required name, required rooms}) async {
        persistenceCalls++;
      };
    addTearDown(provider.dispose);
    final coordinator = RoomPlanCaptureCoordinator(
      capture: ({
        required roomId,
        required roomName,
        required roomType,
      }) async =>
          null,
    );

    final room = await coordinator.captureAndPersist(
      floorPlanProvider: provider,
      roomName: 'Cancelled',
    );

    expect(room, isNull);
    expect(provider.completedRooms, isEmpty);
    expect(persistenceCalls, 0);
  });
}
