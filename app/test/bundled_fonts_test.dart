import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 앱이 쓰는 폰트가 전부 번들 에셋(google_fonts/)에서 로드되는지 검증.
  // 런타임 다운로드가 금지된 상태에서 에셋에 ttf가 없으면 예외가 나므로,
  // 폰트 파일 누락/파일명 오타 회귀를 잡는다.
  test('실사용 폰트는 번들 에셋에서 로드된다 (런타임 다운로드 금지)', () async {
    GoogleFonts.config.allowRuntimeFetching = false;

    await GoogleFonts.pendingFonts([
      GoogleFonts.gowunDodum(),
      GoogleFonts.doHyeon(),
    ]);
  });
}
