import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:app/core/network/api_error.dart';

// 참여 실패 사유 노출 회귀 테스트.
//
// 서버가 내려준 4xx 사유는 그대로 보여주되, 5xx 의 JS 예외 원문이나
// 프록시가 내려주는 HTML 본문이 토스트에 새어 나가면 안 된다.

DioException _res(int status, dynamic data) {
  final options = RequestOptions(path: '/rooms/r1/join');
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response:
        Response(requestOptions: options, statusCode: status, data: data),
  );
}

void main() {
  group('apiErrorMessage', () {
    test('4xx 는 서버가 내려준 사유를 그대로 보여준다', () {
      final e = _res(403, {
        'success': false,
        'error': {
          'code': 'AGE_NOT_MATCH',
          'message': '자녀 개월수가 방의 조건과 맞지 않습니다.',
        },
      });
      expect(apiErrorMessage(e, fallback: '참여 신청에 실패했습니다'),
          '자녀 개월수가 방의 조건과 맞지 않습니다.');
    });

    test('5xx 원문은 노출하지 않고 fallback', () {
      final e = _res(500, {
        'error': {
          'code': 'INTERNAL_ERROR',
          'message': 'Cannot read properties of undefined',
        },
      });
      expect(
          apiErrorMessage(e, fallback: '참여 신청에 실패했습니다'), '참여 신청에 실패했습니다');
    });

    test('JSON 이 아닌 4xx 본문(HTML 등)은 fallback', () {
      final e = _res(413, '<html>Request Entity Too Large</html>');
      expect(
          apiErrorMessage(e, fallback: '참여 신청에 실패했습니다'), '참여 신청에 실패했습니다');
    });

    test('error 키가 없는 4xx 본문은 fallback', () {
      final e = _res(400, {'success': false});
      expect(
          apiErrorMessage(e, fallback: '참여 신청에 실패했습니다'), '참여 신청에 실패했습니다');
    });

    test('message 배열은 이어붙인다', () {
      final e = _res(400, {
        'error': {
          'code': 'VALIDATION_ERROR',
          'message': ['제목은 필수입니다', '날짜 형식이 올바르지 않습니다'],
        },
      });
      expect(apiErrorMessage(e, fallback: 'x'), '제목은 필수입니다, 날짜 형식이 올바르지 않습니다');
    });

    test('연결 실패/타임아웃은 네트워크 문구', () {
      final e = DioException(
        requestOptions: RequestOptions(path: '/rooms/r1'),
        type: DioExceptionType.connectionError,
      );
      expect(apiErrorMessage(e, fallback: '방 정보를 불러올 수 없습니다'),
          '네트워크 연결을 확인해 주세요');
    });

    test('DioException 이 아니면 fallback', () {
      expect(apiErrorMessage(Exception('boom'), fallback: '방 정보를 불러올 수 없습니다'),
          '방 정보를 불러올 수 없습니다');
    });
  });
}
