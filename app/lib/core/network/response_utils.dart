/// 목록 응답의 data 부분을 리스트로 정규화한다.
///
/// 서버가 엔드포인트마다 `data: [...]` (배열) 또는 `data: {items: [...]}`
/// (객체) 로 일관되지 않게 응답하는 경우가 있다. data 가 List 일 때
/// `data['items']` 는 TypeError 를 던지므로 타입 분기가 필수다.
List<dynamic> extractItems(dynamic data) {
  if (data is List) return data;
  if (data is Map) {
    return data['items'] as List<dynamic>? ?? const <dynamic>[];
  }
  return const <dynamic>[];
}
