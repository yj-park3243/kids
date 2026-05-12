import client from './client';
import type { Guide, GuideListItem } from '../types';

export const guidesApi = {
  getGuides(): Promise<GuideListItem[]> {
    return client.get('/admin/guides').then((res) => res.data);
  },

  getGuide(ageMonth: number): Promise<Guide> {
    return client.get(`/admin/guides/${ageMonth}`).then((res) => res.data);
  },

  createGuide(payload: Omit<Guide, 'createdAt' | 'updatedAt'>): Promise<Guide> {
    return client.post('/admin/guides', payload).then((res) => res.data);
  },

  updateGuide(ageMonth: number, payload: Partial<Guide>): Promise<Guide> {
    return client.patch(`/admin/guides/${ageMonth}`, payload).then((res) => res.data);
  },

  deleteGuide(ageMonth: number): Promise<{ success: boolean }> {
    return client.delete(`/admin/guides/${ageMonth}`).then((res) => res.data);
  },
};
