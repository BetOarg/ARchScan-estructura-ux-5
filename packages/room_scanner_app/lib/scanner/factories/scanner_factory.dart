import 'package:flutter/widgets.dart';

import '../../screens/ar_scanner_screen.dart';
import '../../screens/basic_scanner_screen.dart';
import '../models/scanner_mode.dart';
import '../navigation/scanner_launch_request.dart';

/// Crea la pantalla correspondiente al modo elegido por [ScannerModeResolver].
///
/// El modo manual no crea una pantalla de cámara. El coordinador de navegación
/// conserva el fallback seguro actual hasta que exista un flujo manual dedicado.
class ScannerFactory {
  const ScannerFactory();

  Widget? createScreen({
    required ScannerMode mode,
    required ScannerLaunchRequest request,
  }) {
    return switch (mode) {
      ScannerMode.ar => ARScannerScreen(
          projectUuid: request.projectUuid,
          projectName: request.projectName,
          continuationReference: request.continuationReference,
          resumeRoom: request.resumeRoom,
        ),
      ScannerMode.basic => BasicScannerScreen(
          projectUuid: request.projectUuid,
          projectName: request.projectName,
          continuationReference: request.continuationReference,
          resumeRoom: request.resumeRoom,
        ),
      ScannerMode.manual => null,
    };
  }
}
