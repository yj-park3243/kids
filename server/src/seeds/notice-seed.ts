import { DataSource } from 'typeorm';
import { Notice } from '../notice/entities/notice.entity';
import { User } from '../user/entities/user.entity';
import * as dotenv from 'dotenv';
import * as path from 'path';

const envFile =
  process.env.NODE_ENV === 'production' ? '.env.production' : '.env';
dotenv.config({ path: path.resolve(__dirname, '../../', envFile) });

const dataSource = new DataSource({
  type: 'postgres',
  host: process.env.DB_HOST || 'localhost',
  port: parseInt(process.env.DB_PORT || '5432'),
  username: process.env.DB_USER || 'kids',
  password: process.env.DB_PASSWORD || 'kids1234',
  database: process.env.DB_NAME || 'kids',
  entities: [path.join(__dirname, '../**/*.entity{.ts,.js}')],
  synchronize: true,
  ssl:
    process.env.NODE_ENV === 'production'
      ? { rejectUnauthorized: false }
      : false,
});

/** 실 운영용 초기 공지사항. createdAt 순서대로 — 뒤일수록 최신. */
const NOTICES: Array<{
  title: string;
  content: string;
  isPinned: boolean;
  createdAt: string;
}> = [
  {
    title: '커뮤니티 운영 정책 안내',
    content: [
      '같이크자는 아이와 부모 모두가 안심하고 모임에 참여할 수 있는 환경을 만들기 위해 다음 정책을 운영합니다.',
      '',
      '1. 모든 모임은 실명 인증을 마친 회원만 개설·참여할 수 있습니다.',
      '2. 광고, 종교·정치 권유, 상업적 홍보 목적의 모임은 제한됩니다.',
      '3. 아이의 안전을 위협하거나 불쾌감을 주는 행위는 신고 시 즉시 조치됩니다.',
      '4. 반복적인 노쇼·약속 불이행은 이용 제한 사유가 됩니다.',
      '',
      '건강한 커뮤니티를 함께 만들어 주셔서 감사합니다.',
    ].join('\n'),
    isPinned: false,
    createdAt: '2026-05-19T09:00:00+09:00',
  },
  {
    title: '안전한 만남을 위한 이용 수칙',
    content: [
      '처음 만나는 이웃과의 모임, 아래 수칙을 꼭 확인해 주세요.',
      '',
      '• 첫 모임은 키즈카페·놀이터 등 사람이 많은 공개된 장소를 권장합니다.',
      '• 모임 전 채팅으로 충분히 대화하며 서로를 확인하세요.',
      '• 아이의 컨디션이 좋지 않은 날은 무리하지 말고 일정을 조정하세요.',
      '• 불편하거나 위험하다고 느껴지면 즉시 모임을 떠나고 신고해 주세요.',
      '',
      '안전이 가장 우선입니다. 함께 지켜주세요.',
    ].join('\n'),
    isPinned: true,
    createdAt: '2026-05-19T15:00:00+09:00',
  },
  {
    title: '같이크자 정식 오픈 안내',
    content: [
      '안녕하세요, 같이크자입니다.',
      '',
      '비슷한 또래 아이를 키우는 이웃과 함께 놀이 모임을 만들 수 있는 같이크자가 정식 오픈했습니다.',
      '',
      '• 우리 동네 또래 모임을 지도에서 한눈에 확인하세요.',
      '• 아이 개월 수에 맞는 모임을 추천받을 수 있어요.',
      '• 모임 후기와 매너 평가로 믿을 수 있는 이웃을 만나보세요.',
      '',
      '앞으로도 더 편리한 서비스로 보답하겠습니다. 많은 이용 부탁드립니다.',
    ].join('\n'),
    isPinned: true,
    createdAt: '2026-05-20T10:00:00+09:00',
  },
  {
    title: '노쇼 방지 및 매너 평가 안내',
    content: [
      '약속한 모임에 정당한 사유 없이 불참하는 노쇼는 다른 참여자에게 큰 실망을 줍니다.',
      '',
      '모임 종료 후 참여자끼리 매너를 평가할 수 있으며, 평가 결과는 쑥쑥 등급에 반영됩니다.',
      '부득이하게 참석이 어려운 경우 모임 시작 전 채팅으로 미리 알려 주세요.',
      '',
      '서로 배려하는 약속 문화를 함께 만들어 주세요.',
    ].join('\n'),
    isPinned: false,
    createdAt: '2026-05-21T11:00:00+09:00',
  },
  {
    title: 'v1.1 업데이트 — 지도·공지사항 기능 추가',
    content: [
      'v1.1 업데이트로 다음 기능이 새롭게 추가되었습니다.',
      '',
      '• 지도에서 모임 위치를 핀으로 확인하고, 다양한 조건으로 필터링할 수 있어요.',
      '• 내 위치에서 모임까지의 거리를 km 단위로 확인할 수 있어요.',
      '• 공지사항 기능이 추가되어 중요한 소식을 홈 화면에서 바로 확인할 수 있어요.',
      '',
      '더 나은 서비스를 위해 계속 노력하겠습니다.',
    ].join('\n'),
    isPinned: false,
    createdAt: '2026-05-22T09:00:00+09:00',
  },
];

async function seedNotices() {
  console.log('데이터베이스 연결 중...');
  await dataSource.initialize();

  const noticeRepo = dataSource.getRepository(Notice);
  const existing = await noticeRepo.count();
  if (existing > 0) {
    console.log(`공지사항이 이미 ${existing}건 존재합니다. 건너뜁니다.`);
    await dataSource.destroy();
    return;
  }

  const admin = await dataSource
    .getRepository(User)
    .findOne({ where: { email: 'admin' } });

  for (const n of NOTICES) {
    await noticeRepo.save(
      noticeRepo.create({
        title: n.title,
        content: n.content,
        isPinned: n.isPinned,
        isPublished: true,
        authorId: admin?.id ?? null,
        createdAt: new Date(n.createdAt),
      }),
    );
  }

  console.log(`공지사항 ${NOTICES.length}건 생성 완료`);
  await dataSource.destroy();
}

seedNotices().catch((error) => {
  console.error('공지사항 시드 실패:', error);
  process.exit(1);
});
