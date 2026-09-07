import 'package:flutter_test/flutter_test.dart';
import 'package:room_scanner_ar/scanner/adapters/ar_scanner_adapter.dart';

void main() {
  test('decodifica la pose Map devuelta por ARCore', () {
    final position = ARScannerAdapter.decodeAndroidCameraTranslation({
      'position': {'x': 1, 'y': 2.5, 'z': -3},
      'rotation': {'x': 0, 'y': 0, 'z': 0, 'w': 1},
    });

    expect(position, isNotNull);
    expect(position!.x, 1);
    expect(position.y, 2.5);
    expect(position.z, -3);
  });

  test('rechaza una pose Android incompleta', () {
    expect(
      ARScannerAdapter.decodeAndroidCameraTranslation({
        'position': {'x': 1, 'z': 2},
      }),
      isNull,
    );
  });
}
