import 'package:flutter_test/flutter_test.dart';
import 'package:app/models/user.dart';

/// 자동 로그인 회귀 테스트.
///
/// 서버의 mannerScore 는 postgres `numeric` 컬럼이라 JSON 에 **문자열**로
/// 올 수 있다. 과거 `as num?` 캐스트가 String 에서 터지면서 /users/me
/// 파싱이 실패 → checkAuth 예외 → 자동 로그인이 깨졌다.
void main() {
  group('User.fromJson — mannerScore 타입', () {
    test('문자열 "20.0" 도 파싱된다 (서버 numeric 응답)', () {
      final u = User.fromJson({'id': 'u1', 'mannerScore': '20.0'});
      expect(u.mannerScore, 20.0);
    });

    test('숫자 20.0 도 파싱된다', () {
      final u = User.fromJson({'id': 'u1', 'mannerScore': 20.0});
      expect(u.mannerScore, 20.0);
    });

    test('정수 36 도 파싱된다', () {
      final u = User.fromJson({'id': 'u1', 'mannerScore': 36});
      expect(u.mannerScore, 36.0);
    });

    test('없으면 기본값 36.5', () {
      final u = User.fromJson({'id': 'u1'});
      expect(u.mannerScore, 36.5);
    });

    test('null 이면 기본값 36.5', () {
      final u = User.fromJson({'id': 'u1', 'mannerScore': null});
      expect(u.mannerScore, 36.5);
    });
  });

  group('User.fromJson — roomCount 타입', () {
    test('문자열 "5" 도 파싱된다', () {
      final u = User.fromJson({'id': 'u1', 'roomCount': '5'});
      expect(u.roomCount, 5);
    });

    test('숫자 5 도 파싱된다', () {
      final u = User.fromJson({'id': 'u1', 'roomCount': 5});
      expect(u.roomCount, 5);
    });

    test('없으면 null', () {
      final u = User.fromJson({'id': 'u1'});
      expect(u.roomCount, isNull);
    });
  });

  test('실제 /users/me 응답 형태 — 예외 없이 파싱된다', () {
    // 서버가 실제로 내려주는 형태: mannerScore 가 문자열.
    final json = <String, dynamic>{
      'id': 'a1b2c3',
      'nickname': '콩이맘',
      'email': 'user@test.com',
      'isProfileComplete': true,
      'isPhoneVerified': true,
      'isSingleParent': false,
      'mannerScore': '20.0',
      'status': 'ACTIVE',
      'children': [
        {'id': 'c1', 'nickname': '콩이', 'birthYear': 2025, 'birthMonth': 6},
      ],
    };
    final u = User.fromJson(json);
    expect(u.id, 'a1b2c3');
    expect(u.mannerScore, 20.0);
    expect(u.status, 'ACTIVE');
    expect(u.children, isNotNull);
    expect(u.children!.length, 1);
  });
}
