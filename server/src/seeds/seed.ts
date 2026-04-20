import { DataSource } from 'typeorm';
import * as bcrypt from 'bcrypt';
import { User } from '../user/entities/user.entity';
import { Child } from '../child/entities/child.entity';
import { Room } from '../room/entities/room.entity';
import { RoomMember } from '../room/entities/room-member.entity';
import { RefreshToken } from '../auth/entities/refresh-token.entity';
import { Notification } from '../notification/entities/notification.entity';
import { DeviceToken } from '../notification/entities/device-token.entity';
import { JoinRequest } from '../room/entities/join-request.entity';
import * as dotenv from 'dotenv';
import * as path from 'path';

const envFile = process.env.NODE_ENV === 'production' ? '.env.production' : '.env';
dotenv.config({ path: path.resolve(__dirname, '../../', envFile) });

const dataSource = new DataSource({
  type: 'postgres',
  host: process.env.DB_HOST || 'localhost',
  port: parseInt(process.env.DB_PORT || '5432'),
  username: process.env.DB_USER || 'kids',
  password: process.env.DB_PASSWORD || 'kids1234',
  database: process.env.DB_NAME || 'kids',
  entities: [User, Child, Room, RoomMember, JoinRequest, Notification, DeviceToken, RefreshToken],
  synchronize: true,
  ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false,
});

async function seed() {
  console.log('Connecting to database...');
  await dataSource.initialize();
  console.log('Database connected.');

  const userRepo = dataSource.getRepository(User);
  const childRepo = dataSource.getRepository(Child);
  const roomRepo = dataSource.getRepository(Room);
  const roomMemberRepo = dataSource.getRepository(RoomMember);

  // Check if admin already exists
  const existingAdmin = await userRepo.findOne({ where: { email: 'admin' } });
  if (existingAdmin) {
    console.log('Seed data already exists. Skipping...');
    await dataSource.destroy();
    return;
  }

  console.log('Seeding data...');

  // 1. Admin user
  const adminPasswordHash = await bcrypt.hash('admin123', 10);
  const admin = userRepo.create({
    authProvider: 'EMAIL',
    email: 'admin',
    passwordHash: adminPasswordHash,
    nickname: '관리자',
    isAdmin: true,
    isProfileComplete: true,
    regionSido: '서울특별시',
    regionSigungu: '강남구',
    regionDong: '역삼동',
    status: 'ACTIVE',
  });
  await userRepo.save(admin);
  console.log('Admin user created: email=admin, password=admin123');

  // 2. Test user 1
  const user1PasswordHash = await bcrypt.hash('Test1234!', 10);
  const user1 = userRepo.create({
    authProvider: 'EMAIL',
    email: 'user1@test.com',
    passwordHash: user1PasswordHash,
    nickname: '콩이맘',
    isProfileComplete: true,
    regionSido: '서울특별시',
    regionSigungu: '강남구',
    regionDong: '역삼동',
    introduction: '10개월 콩이를 키우고 있어요!',
    status: 'ACTIVE',
  });
  await userRepo.save(user1);

  // User1's child
  const child1 = childRepo.create({
    userId: user1.id,
    nickname: '콩이',
    birthYear: 2025,
    birthMonth: 6,
    gender: 'MALE',
  });
  await childRepo.save(child1);

  // 3. Test user 2
  const user2PasswordHash = await bcrypt.hash('Test1234!', 10);
  const user2 = userRepo.create({
    authProvider: 'EMAIL',
    email: 'user2@test.com',
    passwordHash: user2PasswordHash,
    nickname: '두리맘',
    isProfileComplete: true,
    regionSido: '서울특별시',
    regionSigungu: '강남구',
    regionDong: '삼성동',
    introduction: '두리와 함께 놀 친구 찾아요~',
    status: 'ACTIVE',
  });
  await userRepo.save(user2);

  const child2 = childRepo.create({
    userId: user2.id,
    nickname: '두리',
    birthYear: 2025,
    birthMonth: 3,
    gender: 'FEMALE',
  });
  await childRepo.save(child2);

  // 4. Test user 3
  const user3PasswordHash = await bcrypt.hash('Test1234!', 10);
  const user3 = userRepo.create({
    authProvider: 'EMAIL',
    email: 'user3@test.com',
    passwordHash: user3PasswordHash,
    nickname: '민이아빠',
    isProfileComplete: true,
    regionSido: '서울특별시',
    regionSigungu: '서초구',
    regionDong: '반포동',
    introduction: '주말에 같이 놀아요!',
    status: 'ACTIVE',
  });
  await userRepo.save(user3);

  const child3 = childRepo.create({
    userId: user3.id,
    nickname: '민이',
    birthYear: 2025,
    birthMonth: 1,
    gender: 'MALE',
  });
  await childRepo.save(child3);

  // 5. Test rooms
  const tomorrow = new Date();
  tomorrow.setDate(tomorrow.getDate() + 1);
  const tomorrowStr = tomorrow.toISOString().split('T')[0];

  const dayAfter = new Date();
  dayAfter.setDate(dayAfter.getDate() + 3);
  const dayAfterStr = dayAfter.toISOString().split('T')[0];

  const nextWeek = new Date();
  nextWeek.setDate(nextWeek.getDate() + 7);
  const nextWeekStr = nextWeek.toISOString().split('T')[0];

  const room1 = roomRepo.create({
    hostId: user1.id,
    title: '역삼동 놀이터 모임',
    description: '역삼근린공원 놀이터에서 아이들이랑 놀아요! 같은 또래 아이 키우시는 분들 환영합니다.',
    regionSido: '서울특별시',
    regionSigungu: '강남구',
    regionDong: '역삼동',
    date: tomorrowStr,
    startTime: '14:00',
    endTime: '16:00',
    ageMonthMin: 6,
    ageMonthMax: 15,
    placeType: 'PLAYGROUND',
    placeName: '역삼근린공원 놀이터',
    placeAddress: '서울 강남구 역삼동 635',
    latitude: 37.5012,
    longitude: 127.0396,
    maxMembers: 5,
    currentMembers: 1,
    joinType: 'FREE',
    cost: 0,
    tags: ['놀이터', '산책', '또래모임'],
    status: 'RECRUITING',
  });
  await roomRepo.save(room1);

  const room1Member = roomMemberRepo.create({
    roomId: room1.id,
    userId: user1.id,
    isHost: true,
  });
  await roomMemberRepo.save(room1Member);

  const room2 = roomRepo.create({
    hostId: user2.id,
    title: '삼성동 키즈카페 함께해요',
    description: '플레이존 키즈카페에서 아이들이랑 실내 놀이 해요. 입장료 더치페이입니다.',
    regionSido: '서울특별시',
    regionSigungu: '강남구',
    regionDong: '삼성동',
    date: dayAfterStr,
    startTime: '10:00',
    endTime: '12:00',
    ageMonthMin: 8,
    ageMonthMax: 18,
    placeType: 'KIDS_CAFE',
    placeName: '플레이존 키즈카페',
    placeAddress: '서울 강남구 삼성동 143-2',
    latitude: 37.5096,
    longitude: 127.0622,
    maxMembers: 4,
    currentMembers: 1,
    joinType: 'APPROVAL',
    cost: 15000,
    costDescription: '키즈카페 입장료 더치페이',
    tags: ['키즈카페', '실내놀이'],
    status: 'RECRUITING',
  });
  await roomRepo.save(room2);

  const room2Member = roomMemberRepo.create({
    roomId: room2.id,
    userId: user2.id,
    isHost: true,
  });
  await roomMemberRepo.save(room2Member);

  const room3 = roomRepo.create({
    hostId: user3.id,
    title: '반포 한강공원 산책 모임',
    description: '반포 한강공원에서 유모차 산책하면서 수다 떨어요. 간식 가져오셔도 좋아요!',
    regionSido: '서울특별시',
    regionSigungu: '서초구',
    regionDong: '반포동',
    date: nextWeekStr,
    startTime: '15:00',
    endTime: '17:00',
    ageMonthMin: 3,
    ageMonthMax: 12,
    placeType: 'PARK',
    placeName: '반포한강공원',
    placeAddress: '서울 서초구 반포동 115-5',
    latitude: 37.5103,
    longitude: 126.9960,
    maxMembers: 6,
    currentMembers: 1,
    joinType: 'FREE',
    cost: 0,
    tags: ['산책', '한강', '유모차'],
    status: 'RECRUITING',
  });
  await roomRepo.save(room3);

  const room3Member = roomMemberRepo.create({
    roomId: room3.id,
    userId: user3.id,
    isHost: true,
  });
  await roomMemberRepo.save(room3Member);

  const room4 = roomRepo.create({
    hostId: user1.id,
    title: '역삼동 이유식 교류 모임',
    description: '이유식 만들어보신 분들 레시피 공유해요! 간단한 이유식 가져오셔서 같이 나눠먹어요.',
    regionSido: '서울특별시',
    regionSigungu: '강남구',
    regionDong: '역삼동',
    date: nextWeekStr,
    startTime: '11:00',
    endTime: '13:00',
    ageMonthMin: 6,
    ageMonthMax: 12,
    placeType: 'PARTY_ROOM',
    placeName: '역삼 파티룸 A',
    placeAddress: '서울 강남구 역삼동 821-1',
    latitude: 37.4998,
    longitude: 127.0365,
    maxMembers: 8,
    currentMembers: 1,
    joinType: 'APPROVAL',
    cost: 5000,
    costDescription: '파티룸 대여비 더치페이',
    tags: ['이유식', '레시피교류', '파티룸'],
    status: 'RECRUITING',
  });
  await roomRepo.save(room4);

  const room4Member = roomMemberRepo.create({
    roomId: room4.id,
    userId: user1.id,
    isHost: true,
  });
  await roomMemberRepo.save(room4Member);

  const room5 = roomRepo.create({
    hostId: user2.id,
    title: '주말 문화센터 수업 같이가요',
    description: '강남 문화센터 영유아 음악놀이 수업 같이 들으실 분! 수업 끝나고 점심도 같이 먹어요.',
    regionSido: '서울특별시',
    regionSigungu: '강남구',
    regionDong: '삼성동',
    date: dayAfterStr,
    startTime: '09:00',
    endTime: '11:00',
    ageMonthMin: 10,
    ageMonthMax: 24,
    placeType: 'OTHER',
    placeName: '강남문화센터',
    placeAddress: '서울 강남구 삼성동 159',
    latitude: 37.5101,
    longitude: 127.0610,
    maxMembers: 3,
    currentMembers: 1,
    joinType: 'FREE',
    cost: 0,
    tags: ['문화센터', '음악놀이'],
    status: 'RECRUITING',
  });
  await roomRepo.save(room5);

  const room5Member = roomMemberRepo.create({
    roomId: room5.id,
    userId: user2.id,
    isHost: true,
  });
  await roomMemberRepo.save(room5Member);

  console.log('Seed completed successfully!');
  console.log('---');
  console.log('Admin: email=admin, password=admin123');
  console.log('User1: email=user1@test.com, password=Test1234!');
  console.log('User2: email=user2@test.com, password=Test1234!');
  console.log('User3: email=user3@test.com, password=Test1234!');
  console.log(`Rooms created: 5`);

  await dataSource.destroy();
}

seed().catch((error) => {
  console.error('Seed failed:', error);
  process.exit(1);
});
