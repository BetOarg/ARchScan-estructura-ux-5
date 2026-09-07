import '../screens/ar_scanner_screen.dart';
import '../screens/basic_scanner_screen.dart';
import '../services/ar_check_service.dart';
import 'factories/scanner_factory.dart';

/// Registers concrete scanner screens at the application composition root.
///
/// Navigation and capability services depend only on scanner contracts; the
/// screen imports remain confined to this bootstrap boundary.
void configureScannerComposition() {
  ArCheckService.configure(
    scannerFactory: ScannerFactory(
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
    ),
  );
}
