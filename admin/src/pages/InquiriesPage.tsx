import { useEffect, useState, useCallback } from 'react';
import {
  Button,
  Card,
  Input,
  Modal,
  Select,
  Table,
  Tag,
  Typography,
  Space,
  message,
} from 'antd';
import dayjs from 'dayjs';
import { inquiriesApi, type InquiryListItem } from '../api/inquiries';

const { Title, Text } = Typography;

const STATUS_MAP: Record<string, { color: string; label: string }> = {
  OPEN: { color: 'orange', label: '대기' },
  REPLIED: { color: 'green', label: '답변완료' },
  CLOSED: { color: 'default', label: '종료' },
};

export default function InquiriesPage() {
  const [items, setItems] = useState<InquiryListItem[]>([]);
  const [loading, setLoading] = useState(false);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [limit] = useState(15);
  const [status, setStatus] = useState<string | undefined>();

  const [target, setTarget] = useState<InquiryListItem | null>(null);
  const [reply, setReply] = useState('');
  const [closeOnReply, setCloseOnReply] = useState(false);
  const [saving, setSaving] = useState(false);

  const fetchInquiries = useCallback(async () => {
    try {
      setLoading(true);
      const res = await inquiriesApi.getInquiries({ page, limit, status });
      setItems(res.items);
      setTotal(res.total);
    } catch {
      message.error('문의 목록을 불러올 수 없습니다.');
    } finally {
      setLoading(false);
    }
  }, [page, limit, status]);

  useEffect(() => {
    fetchInquiries();
  }, [fetchInquiries]);

  const openReply = (i: InquiryListItem) => {
    setTarget(i);
    setReply(i.reply ?? '');
    setCloseOnReply(i.status === 'CLOSED');
  };

  const handleSubmit = async () => {
    if (!target) return;
    if (!reply.trim()) {
      message.warning('답변 내용을 입력하세요.');
      return;
    }
    try {
      setSaving(true);
      await inquiriesApi.replyInquiry(
        target.id,
        reply.trim(),
        closeOnReply ? 'CLOSED' : 'REPLIED',
      );
      message.success('답변을 저장했습니다.');
      setTarget(null);
      fetchInquiries();
    } catch {
      message.error('답변 저장 중 오류가 발생했습니다.');
    } finally {
      setSaving(false);
    }
  };

  const columns = [
    {
      title: '제목',
      dataIndex: 'subject',
      key: 'subject',
      render: (subject: string) => (
        <Text strong>{subject.length > 30 ? `${subject.slice(0, 30)}…` : subject}</Text>
      ),
    },
    {
      title: '작성자',
      key: 'user',
      width: 160,
      render: (_: unknown, r: InquiryListItem) =>
        r.user.nickname || r.user.email || r.user.id.slice(0, 8),
    },
    {
      title: '본문',
      dataIndex: 'message',
      key: 'message',
      render: (m: string) =>
        m ? (
          <span title={m}>{m.length > 60 ? `${m.slice(0, 60)}…` : m}</span>
        ) : (
          '-'
        ),
    },
    {
      title: '접수일',
      dataIndex: 'createdAt',
      key: 'createdAt',
      width: 130,
      render: (d: string) => dayjs(d).format('YYYY.MM.DD HH:mm'),
    },
    {
      title: '상태',
      key: 'status',
      width: 110,
      render: (_: unknown, r: InquiryListItem) => {
        const m = STATUS_MAP[r.status] || { color: 'default', label: r.status };
        return <Tag color={m.color}>{m.label}</Tag>;
      },
    },
    {
      title: '액션',
      key: 'action',
      width: 110,
      render: (_: unknown, r: InquiryListItem) => (
        <Button size="small" type="primary" onClick={() => openReply(r)}>
          {r.reply ? '수정' : '답변'}
        </Button>
      ),
    },
  ];

  return (
    <div>
      <Title level={4} style={{ marginBottom: 24 }}>
        문의 관리
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
              { value: 'OPEN', label: '대기' },
              { value: 'REPLIED', label: '답변완료' },
              { value: 'CLOSED', label: '종료' },
            ]}
          />
        </Space>

        <Table<InquiryListItem>
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
        title="문의 답변"
        open={!!target}
        onCancel={() => setTarget(null)}
        onOk={handleSubmit}
        okText="저장"
        cancelText="취소"
        confirmLoading={saving}
        width={640}
      >
        {target && (
          <>
            <Card size="small" style={{ marginBottom: 16, background: '#FAFAFA' }}>
              <div style={{ marginBottom: 6 }}>
                <Text type="secondary">제목</Text>
              </div>
              <Text strong>{target.subject}</Text>
              <div style={{ marginTop: 12, marginBottom: 6 }}>
                <Text type="secondary">본문</Text>
              </div>
              <div style={{ whiteSpace: 'pre-wrap' }}>{target.message}</div>
              <div style={{ marginTop: 12 }}>
                <Text type="secondary">
                  {target.user.nickname || target.user.email || target.user.id.slice(0, 8)}
                  {' · '}
                  {dayjs(target.createdAt).format('YYYY.MM.DD HH:mm')}
                </Text>
              </div>
            </Card>

            <div style={{ marginBottom: 8 }}>답변</div>
            <Input.TextArea
              rows={5}
              value={reply}
              onChange={(e) => setReply(e.target.value)}
              placeholder="답변 내용을 입력하세요"
              maxLength={2000}
              showCount
            />
            <div style={{ marginTop: 12 }}>
              <Space>
                <span>저장 후 상태</span>
                <Select
                  value={closeOnReply ? 'CLOSED' : 'REPLIED'}
                  onChange={(v) => setCloseOnReply(v === 'CLOSED')}
                  style={{ width: 160 }}
                  options={[
                    { value: 'REPLIED', label: '답변완료' },
                    { value: 'CLOSED', label: '종료' },
                  ]}
                />
              </Space>
            </div>
          </>
        )}
      </Modal>
    </div>
  );
}
