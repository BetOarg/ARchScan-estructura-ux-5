import 'package:flutter/widgets.dart';

import '../models/scanner_mode.dart';
import '../navigation/scanner_launch_request.dart';

typedef ScannerScreenBuilder = Widget Function(ScannerLaunchRequest request);

/// Crea la pantalla correspondiente al modo elegido por [ScannerModeResolver].
///
/// El modo manual no crea una pantalla de cámara. El coordinador de navegación
/// conserva el fallback seguro actual hasta que exista un flujo manual dedicado.
class ScannerFactory {
  final ScannerScreenBuilder arBuilder;
  final ScannerScreenBuilder basicBuilder;

  const ScannerFactory({
    required this.arBuilder,
    required this.basicBuilder,
  });

  Widget? createScreen({
    required ScannerMode mode,
    required ScannerLaunchRequest request,
  }) {
    return switch (mode) {
      ScannerMode.ar => arBuilder(request),
      ScannerMode.basic => basicBuilder(request),
      ScannerMode.manual => null,
    };
  }
}
