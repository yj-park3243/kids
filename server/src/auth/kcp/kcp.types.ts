export interface KcpRawResult {
  ci: string;
  di: string;
  phoneNumber: string;
  gender: string; // M | F | 1 | 0 | 01 | 02
  birthDate: string; // YYYYMMDD
  realName: string;
  carrier: string;
}

export interface KcpVerifyResult {
  accessToken: string;
  refreshToken: string;
  merged?: boolean;
  user: {
    id: string;
    nickname: string | null;
    profileImageUrl: string | null;
    isNewUser: boolean;
    isVerified: boolean;
    phoneNumber: string;
  };
  nextRoute: 'profile-setup' | 'home';
}
