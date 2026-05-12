import 'package:flutter/foundation.dart';
import 'package:kakao_flutter_sdk_share/kakao_flutter_sdk_share.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../models/room.dart';

class KakaoShareService {
  KakaoShareService._();
  static final KakaoShareService instance = KakaoShareService._();

  // TODO: 실제 카카오 디벨로퍼 콘솔에서 발급받은 Custom Template ID 로 교체.
  // .env 또는 별도 secrets 파일에서 주입하는 것을 권장.
  static const int kakaoTemplateId = 0;

  // 딥링크 host. iOS/Android intent-filter 와 일치해야 함.
  static const String _deeplinkScheme = 'kids';
  static const String _webHost = 'https://growtogether.kr';

  /// 모임 공유. 카카오톡 설치 시 ShareClient.shareCustom, 미설치 시 웹 share URL fallback.
  Future<void> shareRoom(Room room) async {
    final templateArgs = <String, String>{
      'title': room.title,
      'description': _buildDescription(room),
      'imageUrl': '', // TODO: 방 대표 이미지 URL 이 모델에 추가되면 채울 것.
      'deeplink': '$_deeplinkScheme://room/${room.id}',
      'webUrl': '$_webHost/room/${room.id}',
      'roomId': room.id,
    };

    try {
      final installed = await ShareClient.instance.isKakaoTalkSharingAvailable();
      if (installed) {
        final uri = await ShareClient.instance.shareCustom(
          templateId: kakaoTemplateId,
          templateArgs: templateArgs,
        );
        await ShareClient.instance.launchKakaoTalk(uri);
        return;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Kakao shareCustom failed: $e');
    }

    // Fallback — 카카오톡 미설치 또는 SDK 호출 실패. 웹 공유 URL 을 외부 브라우저로 연다.
    try {
      final shareUrl = await WebSharerClient.instance.makeCustomUrl(
        templateId: kakaoTemplateId,
        templateArgs: templateArgs,
      );
      await launchUrl(shareUrl, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (kDebugMode) debugPrint('Kakao web share fallback failed: $e');
      // 최후의 fallback — 그냥 룸 웹페이지를 연다.
      final fallback = Uri.parse('$_webHost/room/${room.id}');
      await launchUrl(fallback, mode: LaunchMode.externalApplication);
    }
  }

  String _buildDescription(Room room) {
    final age = '${room.ageMonthMin}~${room.ageMonthMax}개월';
    return '$age · ${room.regionDong} · ${room.date} ${room.startTime}';
  }
}
