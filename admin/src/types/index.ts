// ============ Auth ============
export interface LoginRequest {
  email: string;
  password: string;
}

export interface LoginResponse {
  accessToken: string;
  user: {
    id: string;
    email: string;
    nickname: string;
    isAdmin: boolean;
  };
}

// ============ User ============
export interface User {
  id: string;
  nickname: string;
  email: string | null;
  authProvider: string;
  socialId: string | null;
  profileImageUrl: string | null;
  introduction: string | null;
  regionSido: string | null;
  regionSigungu: string | null;
  regionDong: string | null;
  isProfileComplete: boolean;
  isPhoneVerified: boolean;
  isAdmin: boolean;
  status: 'ACTIVE' | 'WITHDRAWN' | 'BANNED';
  children?: Child[];
  createdAt: string;
  updatedAt: string;
}

export interface Child {
  id: string;
  nickname: string;
  birthYear: number;
  birthMonth: number;
  gender: 'MALE' | 'FEMALE' | null;
  createdAt: string;
  updatedAt: string;
}

export interface UserDetail extends User {
  children: Child[];
  roomCount: number;
}

// ============ Room ============
export type RoomStatus = 'RECRUITING' | 'CLOSED' | 'IN_PROGRESS' | 'COMPLETED' | 'CANCELLED';
export type PlaceType = 'PLAYGROUND' | 'KIDS_CAFE' | 'PARTY_ROOM' | 'PARK' | 'OTHER';
export type JoinType = 'FREE' | 'APPROVAL';

export interface RoomListItem {
  id: string;
  title: string;
  date: string;
  startTime: string;
  regionDong: string;
  status: RoomStatus;
  currentMembers: number;
  maxMembers: number;
  host: {
    id: string;
    nickname: string;
    email: string;
  } | null;
  createdAt: string;
}

export interface Room {
  id: string;
  hostId: string;
  title: string;
  description: string;
  date: string;
  startTime: string;
  endTime: string | null;
  regionSido: string;
  regionSigungu: string;
  regionDong: string;
  ageMonthMin: number;
  ageMonthMax: number;
  placeType: PlaceType;
  placeName: string | null;
  placeAddress: string | null;
  latitude: number | null;
  longitude: number | null;
  maxMembers: number;
  currentMembers: number;
  joinType: JoinType;
  cost: number;
  costDescription: string | null;
  tags: string[] | null;
  status: RoomStatus;
  chatRoomId: string | null;
  host: {
    id: string;
    nickname: string;
    email: string;
    profileImageUrl: string | null;
  } | null;
  members: RoomMember[];
  createdAt: string;
  updatedAt: string;
}

export interface RoomMember {
  id: string;
  roomId: string;
  userId: string;
  isHost: boolean;
  joinedAt: string;
  user: {
    id: string;
    nickname: string;
    profileImageUrl: string | null;
    email: string | null;
  };
}

// ============ Dashboard ============
export interface DashboardStats {
  totalUsers: number;
  totalRooms: number;
  todayUsers: number;
  todayRooms: number;
  activeRooms: number;
  bannedUsers: number;
}

// ============ Pagination ============
export interface PaginatedResponse<T> {
  items: T[];
  total: number;
  page: number;
  limit: number;
  totalPages: number;
}
