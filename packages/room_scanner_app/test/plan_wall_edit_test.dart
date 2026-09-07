import 'package:flutter_test/flutter_test.dart';
import 'package:room_scanner_core/room_scanner_core.dart';
import 'package:room_scanner_ar/providers/floor_plan_provider.dart';

ARPoint p(double x, double z) => ARPoint(x: x, y: 0, z: z);
RoomModel room(String id, List<ARPoint> points,
        {bool closed = true, List<WallFeature> features = const []}) =>
    RoomModel(
        id: id,
        name: id,
        type: RoomType.other,
        points: points,
        isClosed: closed,
        features: features);
FloorPlanProvider provider(List<RoomModel> rooms) =>
    FloorPlanProvider()..loadProject(uuid: 'p', name: 'Plan', rooms: rooms);

void main() {
  test(
      'delete complete room preserves neighbour and restores connections with undo',
      () async {
    final door = WallFeature(
        id: 'd',
        type: FeatureType.door,
        start: p(4, 1),
        end: p(4, 2),
        connectedRoomId: 'b');
    final a = room('a', [p(0, 0), p(4, 0), p(4, 3), p(0, 3)], features: [door]);
    final b = room('b', [p(4, 0), p(6, 0), p(6, 3), p(4, 3)],
        features: [door.copyWith(connectedRoomId: 'a')]);
    final plan = provider([a, b]);
    addTearDown(plan.dispose);
    final before = plan.completedRooms.map((r) => r.toJson()).toList();
    await plan.removeRoom('a');
    expect(plan.completedRooms.single.id, 'b');
    expect(plan.completedRooms.single.points, b.points);
    expect(plan.completedRooms.single.features.single.isConnected, isFalse);
    expect(await plan.undoTransform(), isTrue);
    expect(plan.completedRooms.map((r) => r.toJson()).toList(), before);
    expect(await plan.redoTransform(), isTrue);
    expect(plan.completedRooms.single.id, 'b');
    expect(plan.completedRooms.single.features.single.isConnected, isFalse);
  });
  test(
      'delete removes dependent opening and disconnects neighbour; undo restores both',
      () async {
    final d = WallFeature(
        id: 'd',
        type: FeatureType.door,
        start: p(4, 1),
        end: p(4, 2),
        connectedRoomId: 'b');
    final a = room('a', [p(0, 0), p(4, 0), p(4, 3), p(0, 3)], features: [d]);
    final b = room('b', [p(4, 0), p(6, 0), p(6, 3), p(4, 3)],
        features: [d.copyWith(connectedRoomId: 'a')]);
    final plan = provider([a, b]);
    addTearDown(plan.dispose);
    final before = plan.completedRooms.map((r) => r.toJson()).toList();
    final proposal = plan.previewDeleteWall(plan.completedRooms.first, 1);
    expect(plan.completedRooms.first.isClosed, isTrue);
    expect(await plan.applyPlanEdit(proposal), isTrue);
    expect(plan.completedRooms.first.features, isEmpty);
    expect(plan.completedRooms.last.features.single.isConnected, isFalse);
    expect(plan.totalProjectArea, 6);
    expect(await plan.undoTransform(), isTrue);
    expect(plan.completedRooms.map((r) => r.toJson()).toList(), before);
    expect(await plan.redoTransform(), isTrue);
    expect(plan.completedRooms.first.isClosed, isFalse);
  });
  test('wall length changes are undoable and reject stale previews', () async {
    final plan = provider([
      room('r', [p(0, 0), p(4, 0), p(4, 3), p(0, 3)])
    ]);
    addTearDown(plan.dispose);
    final original = plan.completedRooms.single;
    final proposal = plan.previewGeometry(
        original, PlanEditGeometry.resizeWall(original, 0, 5)!);
    expect(await plan.applyPlanEdit(proposal), isTrue);
    expect(await plan.applyPlanEdit(proposal), isFalse);
    expect(plan.completedRooms.single.points[1].x, 5);
    expect(await plan.undoTransform(), isTrue);
    expect(plan.completedRooms.single.points[1].x, 4);
    expect(
        (await plan.updateWallLength(
                roomId: 'r', wallIndex: 0, lengthMeters: 6))
            .isValid,
        isTrue);
    expect(plan.canRedoTransform, isFalse);
    expect(await plan.undoTransform(), isTrue);
    expect(plan.completedRooms.single.points[1].x, 4);
  });
  test('connected door is protected from a wall drag', () {
    final d = WallFeature(
        id: 'd',
        type: FeatureType.door,
        start: p(1, 0),
        end: p(2, 0),
        connectedRoomId: 'other');
    final plan = provider([
      room('r', [p(0, 0), p(4, 0), p(4, 3), p(0, 3)], features: [d])
    ]);
    addTearDown(plan.dispose);
    final original = plan.completedRooms.single;
    expect(
        plan
            .previewGeometry(
                original, PlanEditGeometry.moveWall(original, 0, 0, -1))
            .error,
        PlanEditError.connection);
    expect(plan.canUndoTransform, isFalse);
  });
  test(
      'closure preview is reversible and a phantom closing wall cannot hold an opening',
      () async {
    final plan = provider([
      room('r', [p(0, 0), p(4, 0), p(4, 3), p(0, 3)], closed: false)
    ]);
    addTearDown(plan.dispose);
    expect(plan.totalProjectArea, 0);
    final placement = await plan.placeOpeningOnWall(
        roomId: 'r',
        type: FeatureType.door,
        wallIndex: 3,
        location: p(0, 1),
        widthMeters: 0.8,
        openingHeightMeters: 2.1,
        sillHeightMeters: 0);
    expect(placement.isSuccess, isFalse);
    final proposal = plan.previewCloseRoom(plan.completedRooms.single);
    expect(proposal.error, isNull);
    expect(plan.completedRooms.single.isClosed, isFalse);
    expect(await plan.applyPlanEdit(proposal), isTrue);
    expect(plan.totalProjectArea, 12);
    expect(await plan.undoTransform(), isTrue);
    expect(plan.completedRooms.single.isClosed, isFalse);
  });
  test('continued open room replaces the original without duplication', () async {
    final open = room(
      'r',
      [p(0, 0), p(3, 0), p(3, 2)],
      closed: false,
    );
    final plan = provider([open]);
    addTearDown(plan.dispose);

    final closed = open.copyWith(
      points: [...open.points, p(0, 2)],
      isClosed: true,
    );
    expect(await plan.replaceCompletedRoom(closed), isTrue);
    expect(plan.completedRooms, hasLength(1));
    expect(plan.completedRooms.single.id, 'r');
    expect(plan.completedRooms.single.isClosed, isTrue);
    expect(plan.completedRooms.single.points, hasLength(4));
    expect(
      await plan.replaceCompletedRoom(closed.copyWith(id: 'missing')),
      isFalse,
    );
    expect(plan.completedRooms, hasLength(1));
  });

  test('open room can continue from either endpoint preserving its identity', () {
    final open = room(
      'angled',
      [p(0, 0), p(2.4, 1.1), p(4, 0.3)],
      closed: false,
    );
    final plan = provider([open]);
    addTearDown(plan.dispose);

    final fromLast = plan.prepareOpenRoomContinuation(
      roomId: 'angled',
      vertexIndex: 2,
    );
    expect(fromLast, same(plan.completedRooms.single));

    final fromFirst = plan.prepareOpenRoomContinuation(
      roomId: 'angled',
      vertexIndex: 0,
    );
    expect(fromFirst, isNotNull);
    expect(fromFirst!.id, 'angled');
    expect(fromFirst.points, open.points.reversed.toList());
    expect(fromFirst.points.last, open.points.first);

    expect(
      plan.prepareOpenRoomContinuation(
        roomId: 'angled',
        vertexIndex: 1,
      ),
      isNull,
    );
  });

  test('closed room can continue from any selected corner', () {
    final closed = room(
      'closed',
      [p(0, 0), p(3, 0), p(3, 2), p(0, 2)],
    );
    final plan = provider([closed]);
    addTearDown(plan.dispose);

    for (var vertex = 0; vertex < closed.points.length; vertex++) {
      final prepared = plan.prepareOpenRoomContinuation(
        roomId: 'closed',
        vertexIndex: vertex,
      );
      expect(prepared, isNotNull);
      expect(prepared!.isClosed, isFalse);
      expect(prepared.points, hasLength(closed.points.length));
      expect(prepared.points.last, closed.points[vertex]);
    }
  });

  test('saved continuation replaces its cyclic closed source safely', () async {
    final closed = room(
      'closed-save',
      [p(0, 0), p(3, 0), p(3, 2), p(0, 2)],
    );
    final plan = provider([closed]);
    addTearDown(plan.dispose);
    final prepared = plan.prepareOpenRoomContinuation(
      roomId: 'closed-save',
      vertexIndex: 2,
    )!;
    final extended = prepared.copyWith(
      points: [...prepared.points, p(4, 3)],
      isClosed: true,
    );

    expect(
      await plan.replaceCompletedRoom(
        extended,
        expectedOpenRoom: prepared,
      ),
      isTrue,
    );
    expect(plan.completedRooms.single.points, extended.points);
  });

}
