import { useEffect, useState, useCallback } from 'react';
import { Button, Card, Input, Modal, Radio, Table, Select, Tag, Typography, Space, message } from 'antd';
import dayjs from 'dayjs';
import { reportsApi } from '../api/reports';
import type { AdminAction, ReportListItem } from '../types';

const { Title } = Typography;

const REASON_LABEL: Record<string, string> = {
  SPAM: '스팸',
  ABUSE: '욕설/괴롭힘',
  INAPPROPRIATE: '부적절한 내용',
  FRAUD: '사기',
  OTHER: '기타',
};

const STATUS_MAP: Record<string, { color: string; label: string }> = {
  PENDING: { color: 'orange', label: '대기' },
  OPEN: { color: 'orange', label: '접수' },
  REVIEWED: { color: 'blue', label: '검토중' },
  RESOLVED: { color: 'green', label: '처리완료' },
  DISMISSED: { color: 'default', label: '반려' },
};

const ACTION_OPTIONS: Array<{ value: AdminAction; label: string }> = [
  { value: 'NONE', label: '조치 없음' },
  { value: 'WARNING', label: '경고' },
  { value: 'BAN_7D', label: '7일 정지' },
  { value: 'BAN_PERMANENT', label: '영구 정지' },
];

export default function ReportsPage() {
  const [items, setItems] = useState<ReportListItem[]>([]);
  const [loading, setLoading] = useState(false);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [limit] = useState(15);
  const [status, setStatus] = useState<string | undefined>();
  const [reason, setReason] = useState<string | undefined>();
  const [resolveTarget, setResolveTarget] = useState<ReportListItem | null>(null);
  const [resolveStatus, setResolveStatus] = useState<'RESOLVED' | 'DISMISSED'>('RESOLVED');
  const [resolveAction, setResolveAction] = useState<AdminAction>('NONE');
  const [resolveNote, setResolveNote] = useState('');
  const [resolveSaving, setResolveSaving] = useState(false);

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

  const openResolve = (r: ReportListItem) => {
    setResolveTarget(r);
    setResolveStatus('RESOLVED');
    setResolveAction('NONE');
    setResolveNote('');
  };

  const handleResolveSave = async () => {
    if (!resolveTarget) return;
    try {
      setResolveSaving(true);
      const action: AdminAction = resolveStatus === 'DISMISSED' ? 'NONE' : resolveAction;
      await reportsApi.resolveReport(
        resolveTarget.id,
        resolveStatus,
        action,
        resolveNote || undefined,
      );
      message.success('신고를 처리했습니다.');
      setResolveTarget(null);
      fetchReports();
    } catch {
      message.error('처리 중 오류가 발생했습니다.');
    } finally {
      setResolveSaving(false);
    }
  };

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
      key: 'status',
      width: 160,
      render: (_: unknown, r: ReportListItem) => {
        const m = STATUS_MAP[r.status] || { color: 'default', label: r.status };
        const action = (r as ReportListItem & { adminAction?: AdminAction }).adminAction;
        return (
          <Space size={4} wrap>
            <Tag color={m.color}>{m.label}</Tag>
            {action && action !== 'NONE' && <Tag>{action}</Tag>}
          </Space>
        );
      },
    },
    {
      title: '액션',
      key: 'action',
      width: 90,
      render: (_: unknown, r: ReportListItem) => {
        const done = r.status === 'RESOLVED' || r.status === 'DISMISSED';
        return (
          <Button size="small" type="primary" disabled={done} onClick={() => openResolve(r)}>
            처리
          </Button>
        );
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

      <Modal
        title="신고 처리"
        open={!!resolveTarget}
        onCancel={() => setResolveTarget(null)}
        onOk={handleResolveSave}
        okText="저장"
        cancelText="취소"
        confirmLoading={resolveSaving}
      >
        <div style={{ marginBottom: 16 }}>
          <div style={{ marginBottom: 8 }}>처리 상태</div>
          <Radio.Group
            value={resolveStatus}
            onChange={(e) => setResolveStatus(e.target.value)}
            options={[
              { value: 'RESOLVED', label: '처리완료' },
              { value: 'DISMISSED', label: '반려' },
            ]}
          />
        </div>
        <div style={{ marginBottom: 16 }}>
          <div style={{ marginBottom: 8 }}>조치</div>
          <Select
            style={{ width: '100%' }}
            value={resolveAction}
            onChange={(v) => setResolveAction(v)}
            disabled={resolveStatus === 'DISMISSED'}
            options={ACTION_OPTIONS}
          />
        </div>
        <div>
          <div style={{ marginBottom: 8 }}>메모 (선택)</div>
          <Input.TextArea
            rows={3}
            value={resolveNote}
            onChange={(e) => setResolveNote(e.target.value)}
            placeholder="처리 메모"
          />
        </div>
      </Modal>
    </div>
  );
}
