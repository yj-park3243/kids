import { BadRequestException, Injectable } from '@nestjs/common';

/**
 * 부적절 콘텐츠 필터 (Apple Guideline 1.2 UGC 대응).
 *
 * - 한국어 욕설/혐오/성적 표현 + 영어 일부.
 * - 정규화: 공백/특수문자 제거, 소문자 변환 후 부분일치.
 * - 완벽한 필터는 아니지만 자동 차단 1차 방어선으로 사용.
 *   머신러닝 기반 필터는 후속 작업.
 */
@Injectable()
export class ProfanityFilterService {
  // 약 40개. 운영 중 발견되는 우회 표현은 여기에 추가.
  private readonly bannedWords: string[] = [
    // 한국어 욕설/비속어
    '시발',
    '씨발',
    '씨바',
    '씨빨',
    '시바',
    '쉬발',
    '병신',
    '븅신',
    '존나',
    '존만',
    '좆',
    '개새끼',
    '개색끼',
    '개쌔끼',
    '개자식',
    '미친놈',
    '미친년',
    '쌍놈',
    '쌍년',
    '느금마',
    '니애미',
    '니미',
    '엠창',
    '엠병',
    '꺼져',
    // 혐오/위협
    '죽어',
    '뒈져',
    '자살해',
    '죽여버',
    // 성적 표현
    '섹스',
    '자위',
    '야동',
    '음란',
    '에로',
    // 영어
    'fuck',
    'shit',
    'asshole',
    'bitch',
    'bastard',
    'dick',
    'pussy',
    'nigger',
    'faggot',
    'cunt',
    'porn',
    'sex',
  ];

  /** 텍스트에 금칙어가 포함되었는지 검사. */
  containsProfanity(text: string | null | undefined): boolean {
    if (!text) return false;
    const normalized = this.normalize(text);
    if (!normalized) return false;
    for (const w of this.bannedWords) {
      if (normalized.includes(w)) return true;
    }
    return false;
  }

  /**
   * 금칙어 포함 시 BadRequestException(code: 'PROFANITY') 던지기.
   * field 는 에러 메시지에 포함할 필드명(예: '제목', '설명').
   */
  assertClean(text: string | null | undefined, field: string): void {
    if (this.containsProfanity(text)) {
      throw new BadRequestException({
        code: 'PROFANITY',
        message: `${field}에 부적절한 표현이 포함되어 있어 등록할 수 없습니다.`,
      });
    }
  }

  /** 공백/특수문자 제거 + 소문자. 예: "씨 발" → "씨발", "F.U.C.K" → "fuck". */
  private normalize(text: string): string {
    return text
      .toLowerCase()
      .replace(/[\s\p{P}\p{S}​-‍﻿]/gu, '');
  }
}
