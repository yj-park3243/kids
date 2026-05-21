import client from './client';
import type { PaginatedResponse } from '../types';

export interface Notice {
  id: string;
  title: string;
  content: string;
  isPinned: boolean;
  isPublished: boolean;
  authorId: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface NoticePayload {
  title: string;
  content: string;
  isPinned?: boolean;
  isPublished?: boolean;
}

export const noticesApi = {
  getNotices(params: {
    page?: number;
    limit?: number;
  }): Promise<PaginatedResponse<Notice>> {
    return client.get('/admin/notices', { params }).then((r) => r.data);
  },

  createNotice(payload: NoticePayload): Promise<Notice> {
    return client.post('/admin/notices', payload).then((r) => r.data);
  },

  updateNotice(id: string, payload: Partial<NoticePayload>): Promise<Notice> {
    return client.patch(`/admin/notices/${id}`, payload).then((r) => r.data);
  },

  deleteNotice(id: string): Promise<{ success: boolean }> {
    return client.delete(`/admin/notices/${id}`).then((r) => r.data);
  },
};
