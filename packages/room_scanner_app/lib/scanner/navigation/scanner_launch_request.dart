import 'package:room_scanner_core/room_scanner_core.dart';

/// Datos necesarios para abrir un escáner sin perder el contexto del proyecto.
///
/// Mantenerlos en un único objeto reduce el riesgo de que un flujo nuevo omita
/// la referencia de continuación o el ambiente abierto al cambiar de modo.
class ScannerLaunchRequest {
  final String projectUuid;
  final String projectName;
  final ScanContinuationReference? continuationReference;
  final RoomModel? resumeRoom;

  const ScannerLaunchRequest({
    required this.projectUuid,
    required this.projectName,
    this.continuationReference,
    this.resumeRoom,
  });
}
