/// 아이 등록/수정에 쓰는 낮잠 시간대 옵션.
/// 서버는 영문 key 만 저장하고, 라벨은 앱에서 매핑한다.
class NapTimeOption {
  final String key;
  final String label;
  const NapTimeOption(this.key, this.label);
}

const napTimeOptions = <NapTimeOption>[
  NapTimeOption('MORNING', '오전 9-11시'),
  NapTimeOption('AFTERNOON', '점심후 12-14시'),
  NapTimeOption('LATE_AFTERNOON', '오후 15-17시'),
  NapTimeOption('EVENING', '저녁 18-19시'),
  NapTimeOption('NONE', '낮잠 없음'),
];

String? napTimeLabel(String? key) {
  if (key == null) return null;
  for (final o in napTimeOptions) {
    if (o.key == key) return o.label;
  }
  return null;
}

/// 아이 기질 태그 — 부모가 보통 쓰는 표현 중심.
/// key 는 영문, 라벨은 한글. 최대 5개 선택.
///
/// [category] 는 5가지 색 그룹 — 동/정/감성/취미/주장. UI 가 카테고리별 다른
/// 톤으로 선택 상태를 그리도록 매핑한다. [emoji] 는 칩 앞에 붙는 픽토그램.
class TemperamentTag {
  final String key;
  final String label;
  final String emoji;
  final TraitCategory category;
  const TemperamentTag(this.key, this.label, this.emoji, this.category);
}

/// 기질 태그 색 그룹. 화면(`child_traits_selector.dart`)이 카테고리별
/// 보조색을 골라 칠한다. 색 자체는 위젯이 들고 있어 — 디자인 의존성을 모델에
/// 끌어들이지 않는다.
enum TraitCategory {
  /// 활동/에너지 — 코랄 톤
  energetic,
  /// 차분/관조 — 라벤더 톤
  composed,
  /// 감성/사랑스러움 — 핑크(primary) 톤
  warm,
  /// 취미/탐구 — 라임 톤
  hobby,
  /// 주장/리더 — 옐로 톤
  assertive,
}

const temperamentTags = <TemperamentTag>[
  TemperamentTag('ACTIVE', '활발함', '⚡', TraitCategory.energetic),
  TemperamentTag('QUIET', '조용함', '🤫', TraitCategory.composed),
  TemperamentTag('CALM', '차분함', '🌿', TraitCategory.composed),
  TemperamentTag('CURIOUS', '호기심 많음', '🔍', TraitCategory.energetic),
  TemperamentTag('SHY', '낯가림', '🙈', TraitCategory.warm),
  TemperamentTag('SOCIABLE', '사교적', '🤝', TraitCategory.energetic),
  TemperamentTag('BASHFUL', '수줍음', '😊', TraitCategory.warm),
  TemperamentTag('RUNS_AROUND', '뛰어다님', '🏃', TraitCategory.energetic),
  TemperamentTag('CAUTIOUS', '신중함', '🧠', TraitCategory.composed),
  TemperamentTag('OWN_PACE', '마이페이스', '🌙', TraitCategory.composed),
  TemperamentTag('SENSITIVE', '예민함', '🌸', TraitCategory.warm),
  TemperamentTag('CHEERFUL', '잘 웃음', '😄', TraitCategory.warm),
  TemperamentTag('AFFECTIONATE', '애교 많음', '🥰', TraitCategory.warm),
  TemperamentTag('STUBBORN', '고집 셈', '💪', TraitCategory.assertive),
  TemperamentTag('EXPRESSIVE', '표현력 풍부', '🎤', TraitCategory.warm),
  TemperamentTag('LEADER', '리더형', '👑', TraitCategory.assertive),
  TemperamentTag('OBSERVER', '관찰형', '👀', TraitCategory.composed),
  TemperamentTag('LOVES_BOOKS', '책 좋아함', '📚', TraitCategory.hobby),
  TemperamentTag('LOVES_CRAFTS', '만들기 좋아함', '✂️', TraitCategory.hobby),
  TemperamentTag('LOVES_MUSIC', '음악 좋아함', '🎵', TraitCategory.hobby),
  TemperamentTag('MATURE', '의젓함', '🌟', TraitCategory.composed),
  TemperamentTag('PLAYFUL', '장난꾸러기', '🎭', TraitCategory.energetic),
  TemperamentTag('INDEPENDENT', '독립적', '🦋', TraitCategory.composed),
  TemperamentTag('HIGH_MAINTENANCE', '손이 많이 감', '🤲', TraitCategory.warm),
];

const maxTemperamentTags = 5;

String? temperamentTagLabel(String key) {
  for (final t in temperamentTags) {
    if (t.key == key) return t.label;
  }
  return null;
}
