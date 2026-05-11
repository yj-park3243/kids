import { useEffect, useState, useCallback } from 'react';
import { Card, Table, Select, Tag, Typography, Space, message } from 'antd';
import dayjs from 'dayjs';
import { reportsApi } from '../api/reports';
import type { ReportListItem } from '../types';

const { Title } = Typography;

const REASON_LABEL: Record<string, string> = {
  SPAM: '스팸',
  ABUSE: '욕설/괴롭힘',
  INAPPROPRIATE: '부적절한 내용',
  FRAUD: '사기',
  OTHER: '기타',
};

const STATUS_MAP: Record<string, { color: string; label: string }> = {
  OPEN: { color: 'orange', label: '접수' },
  REVIEWED: { color: 'blue', label: '검토중' },
  RESOLVED: { color: 'green', label: '처리완료' },
  DISMISSED: { color: 'default', label: '반려' },
};

export default function ReportsPage() {
  const [items, setItems] = useState<ReportListItem[]>([]);
  const [loading, setLoading] = useState(false);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [limit] = useState(15);
  const [status, setStatus] = useState<string | undefined>();
  const [reason, setReason] = useState<string | undefined>();

  const fetchReports = useCallback(async () => {
    try {
      setLoading(true);
      const res = await reportsApi.getReports({ page, limit, status, reason });
      setItems(res.items);
      setTotal(res.total);
    } catch {
      message.error('신고 목록을 불러올 수 없습니다.');
    } finally {
      setLoading(false);
    }
  }, [page, limit, status, reason]);

  useEffect(() => {
    fetchReports();
  }, [fetchReports]);

  const columns = [
    {
      title: 'ID',
      dataIndex: 'id',
      key: 'id',
      width: 100,
      render: (id: string) => (
        <span style={{ fontFamily: 'monospace', fontSize: 12 }}>{id.slice(0, 8)}...</span>
      ),
    },
    {
      title: '신고자',
      key: 'reporter',
      render: (_: unknown, r: ReportListItem) => r.reporter.nickname || r.reporter.id.slice(0, 8),
    },
    {
      title: '대상 유저',
      key: 'targetUser',
      render: (_: unknown, r: ReportListItem) =>
        r.targetUser ? r.targetUser.nickname || r.targetUser.id.slice(0, 8) : '-',
    },
    {
      title: '대상 방',
      key: 'targetRoom',
      width: 100,
      render: (_: unknown, r: ReportListItem) =>
        r.targetRoomId ? (
          <span style={{ fontFamily: 'monospace', fontSize: 12 }}>
            {r.targetRoomId.slice(0, 8)}...
          </span>
        ) : (
          '-'
        ),
    },
    {
      title: '사유',
      dataIndex: 'reason',
      key: 'reason',
      width: 120,
      render: (reason: string) => REASON_LABEL[reason] || reason,
    },
    {
      title: '상세',
      dataIndex: 'detail',
      key: 'detail',
      render: (detail: string | null) =>
        detail ? (
          <span title={detail}>
            {detail.length > 40 ? `${detail.slice(0, 40)}…` : detail}
          </span>
        ) : (
          '-'
        ),
    },
    {
      title: '접수일',
      dataIndex: 'createdAt',
      key: 'createdAt',
      width: 130,
      render: (date: string) => dayjs(date).format('YYYY.MM.DD HH:mm'),
    },
    {
      title: '상태',
      dataIndex: 'status',
      key: 'status',
      width: 90,
      render: (s: string) => {
        const m = STATUS_MAP[s] || { color: 'default', label: s };
        return <Tag color={m.color}>{m.label}</Tag>;
      },
    },
  ];

  return (
    <div>
      <Title level={4} style={{ marginBottom: 24 }}>
        신고 관리
      </Title>

      <Card>
        <Space style={{ marginBottom: 16 }} wrap>
          <Select
            placeholder="상태"
            allowClear
            style={{ width: 140 }}
            value={status}
            onChange={(v) => {
              setStatus(v);
              setPage(1);
            }}
            options={[
              { value: 'OPEN', label: '접수' },
              { value: 'REVIEWED', label: '검토중' },
              { value: 'RESOLVED', label: '처리완료' },
              { value: 'DISMISSED', label: '반려' },
            ]}
          />
          <Select
            placeholder="사유"
            allowClear
            style={{ width: 160 }}
            value={reason}
            onChange={(v) => {
              setReason(v);
              setPage(1);
            }}
            options={Object.entries(REASON_LABEL).map(([value, label]) => ({
              value,
              label,
            }))}
          />
        </Space>

        <Table<ReportListItem>
          dataSource={items}
          columns={columns}
          rowKey="id"
          loading={loading}
          pagination={{
            current: page,
            pageSize: limit,
            total,
            showTotal: (t) => `총 ${t}건`,
            onChange: (p) => setPage(p),
            showSizeChanger: false,
          }}
        />
      </Card>
    </div>
  );
}
