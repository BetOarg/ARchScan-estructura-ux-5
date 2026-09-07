import 'package:flutter_test/flutter_test.dart';
import 'package:room_scanner_core/room_scanner_core.dart';
import 'package:room_scanner_ar/scanner/factories/scanner_factory.dart';
import 'package:room_scanner_ar/scanner/models/scanner_mode.dart';
import 'package:room_scanner_ar/scanner/navigation/scanner_launch_request.dart';
import 'package:room_scanner_ar/screens/ar_scanner_screen.dart';
import 'package:room_scanner_ar/screens/basic_scanner_screen.dart';

void main() {
  final factory = ScannerFactory(
    arBuilder: (request) => ARScannerScreen(
      projectUuid: request.projectUuid,
      projectName: request.projectName,
      continuationReference: request.continuationReference,
      resumeRoom: request.resumeRoom,
    ),
    basicBuilder: (request) => BasicScannerScreen(
      projectUuid: request.projectUuid,
      projectName: request.projectName,
      continuationReference: request.continuationReference,
      resumeRoom: request.resumeRoom,
    ),
  );
  const projectUuid = 'project-uuid';
  const projectName = 'Proyecto de prueba';
  const request = ScannerLaunchRequest(
    projectUuid: projectUuid,
    projectName: projectName,
  );

  group('ScannerFactory', () {
    test('crea ARScannerScreen para el modo AR', () {
      final screen = factory.createScreen(
        mode: ScannerMode.ar,
        request: request,
      );

      expect(screen, isA<ARScannerScreen>());
    });

    test('crea BasicScannerScreen para el modo Basic', () {
      final screen = factory.createScreen(
        mode: ScannerMode.basic,
        request: request,
      );

      expect(screen, isA<BasicScannerScreen>());
    });

    test('entrega el ambiente abierto a Basic y AR sin duplicarlo', () {
      final openRoom = RoomModel(
        id: 'open-room',
        name: 'Dormitorio',
        type: RoomType.dormitorio,
        points: [
          ARPoint(x: 0, y: 0, z: 0),
          ARPoint(x: 3, y: 0, z: 0),
        ],
        isClosed: false,
      );

      final basic = factory.createScreen(
        mode: ScannerMode.basic,
        request: ScannerLaunchRequest(
          projectUuid: projectUuid,
          projectName: projectName,
          resumeRoom: openRoom,
        ),
      ) as BasicScannerScreen;
      final ar = factory.createScreen(
        mode: ScannerMode.ar,
        request: ScannerLaunchRequest(
          projectUuid: projectUuid,
          projectName: projectName,
          resumeRoom: openRoom,
        ),
      ) as ARScannerScreen;

      expect(basic.resumeRoom, same(openRoom));
      expect(ar.resumeRoom, same(openRoom));
    });

    test('conserva la referencia de continuación en Basic y AR', () {
      final continuation = ScanContinuationReference(
        sourceRoomId: 'source-room',
        featureId: 'door-1',
        featureType: FeatureType.door,
        globalStart: ARPoint(x: 1, y: 0, z: 2),
        globalEnd: ARPoint(x: 2, y: 0, z: 2),
        side: OpeningConnectionSide.left,
        startEndpoint: ContinuationStartEndpoint.start,
      );
      final continuationRequest = ScannerLaunchRequest(
        projectUuid: projectUuid,
        projectName: projectName,
        continuationReference: continuation,
      );

      final basic = factory.createScreen(
        mode: ScannerMode.basic,
        request: continuationRequest,
      ) as BasicScannerScreen;
      final ar = factory.createScreen(
        mode: ScannerMode.ar,
        request: continuationRequest,
      ) as ARScannerScreen;

      expect(basic.continuationReference, same(continuation));
      expect(ar.continuationReference, same(continuation));
    });

    test('no crea una pantalla de cámara para el modo Manual', () {
      final screen = factory.createScreen(
        mode: ScannerMode.manual,
        request: request,
      );

      expect(screen, isNull);
    });

    test('conserva los datos del proyecto en la pantalla creada', () {
      final screen = factory.createScreen(
        mode: ScannerMode.basic,
        request: request,
      );

      expect(screen, isA<BasicScannerScreen>());
      final basicScreen = screen! as BasicScannerScreen;
      expect(basicScreen.projectUuid, projectUuid);
      expect(basicScreen.projectName, projectName);
    });
  });
}
