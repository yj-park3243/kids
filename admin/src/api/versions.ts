import client from './client';

export interface AppVersion {
  id: string;
  platform: string; // IOS | ANDROID
  minVersion: string;
  latestVersion: string;
  latestBuild: number;
  forceUpdate: boolean;
  updateMessage: string | null;
  storeUrl: string | null;
  bypassPhoneVerification: boolean;
  showAd: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface UpdateVersionPayload {
  minVersion?: string;
  latestVersion?: string;
  latestBuild?: number;
  forceUpdate?: boolean;
  updateMessage?: string | null;
  storeUrl?: string | null;
  showAd?: boolean;
  bypassPhoneVerification?: boolean;
}

export interface VersionCheckLog {
  id: string;
  userId: string | null;
  nickname: string | null;
  email: string | null;
  phoneNumber: string | null;
  platform: string;
  appVersion: string | null;
  latitude: number | null;
  longitude: number | null;
  ipAddress: string | null;
  ipLocation: string | null;
  userAgent: string | null;
  createdAt: string;
}

export interface VersionLogQuery {
  page?: number;
  pageSize?: number;
  platform?: string;
  userId?: string;
  hasLocation?: boolean;
}

export interface VersionLogResponse {
  data: VersionCheckLog[];
  total: number;
  page: number;
  pageSize: number;
}

export const versionsApi = {
  getVersions(): Promise<AppVersion[]> {
    return client.get('/admin/app-versions').then((r) => r.data);
  },

  updateVersion(
    id: string,
    payload: UpdateVersionPayload,
  ): Promise<AppVersion> {
    return client
      .patch(`/admin/app-versions/${id}`, payload)
      .then((r) => r.data);
  },

  getCheckLogs(params: VersionLogQuery): Promise<VersionLogResponse> {
    return client
      .get('/admin/version-check-logs', { params })
      .then((r) => r.data);
  },
};
