import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';
import 'package:path/path.dart' as p;

/// flutter drive 진입점.
///
/// 테스트가 `binding.takeScreenshot('이름')` 을 호출하면 이 콜백이 받아서
/// TEST_RESULTS_DIR(기본 test_results/) 에 평탄하게 PNG 로 저장한다.
/// — 하위 디렉토리 분리 X, 모두 한 디렉토리에 시간순으로 쌓임.
Future<void> main() async {
  final outDir = Platform.environment['TEST_RESULTS_DIR'] ?? 'test_results';
  await Directory(outDir).create(recursive: true);

  await integrationDriver(
    onScreenshot: (name, bytes, [_]) async {
      final safe = name.replaceAll(RegExp(r'[\\/: ]'), '_');
      final file = File(p.join(outDir, '$safe.png'));
      await file.writeAsBytes(bytes);
      return true;
    },
  );
}
