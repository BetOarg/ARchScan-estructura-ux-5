import 'package:ar_flutter_plugin_2/datatypes/config_planedetection.dart';
import 'package:ar_flutter_plugin_2/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin_2/managers/ar_location_manager.dart';
import 'package:ar_flutter_plugin_2/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin_2/managers/ar_session_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

typedef ArchScanArViewCreatedCallback = void Function(
  int viewId,
  ARSessionManager sessionManager,
  ARObjectManager objectManager,
  ARAnchorManager anchorManager,
  ARLocationManager locationManager,
);

/// Thin platform-view bridge that exposes the native view id.
///
/// `ar_flutter_plugin_2` hides this id, although Android's camera-pose channel
/// needs it. Camera permissions remain owned by the existing scanner flow.
class ArchScanArView extends StatelessWidget {
  final ArchScanArViewCreatedCallback onCreated;
  final PlaneDetectionConfig planeDetectionConfig;

  const ArchScanArView({
    super.key,
    required this.onCreated,
    this.planeDetectionConfig = PlaneDetectionConfig.none,
  });

  @override
  Widget build(BuildContext context) {
    void created(int id) {
      onCreated(
        id,
        ARSessionManager(id, context, planeDetectionConfig),
        ARObjectManager(id),
        ARAnchorManager(id),
        ARLocationManager(),
      );
    }

    const creationParams = <String, dynamic>{};
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return AndroidView(
          viewType: 'ar_flutter_plugin_2',
          layoutDirection: TextDirection.ltr,
          creationParams: creationParams,
          creationParamsCodec: const StandardMessageCodec(),
          onPlatformViewCreated: created,
        );
      case TargetPlatform.iOS:
        return UiKitView(
          viewType: 'ar_flutter_plugin_2',
          layoutDirection: TextDirection.ltr,
          creationParams: creationParams,
          creationParamsCodec: const StandardMessageCodec(),
          onPlatformViewCreated: created,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
