import { useEffect, useState, useCallback } from 'react';
import {
  Button,
  Card,
  Input,
  Modal,
  Switch,
  Table,
  Tag,
  Typography,
  Space,
  Popconfirm,
  message,
} from 'antd';
import { PlusOutlined } from '@ant-design/icons';
import dayjs from 'dayjs';
import { noticesApi, type Notice } from '../api/notices';

const { Title, Text } = Typography;

interface FormState {
  title: string;
  content: string;
  isPinned: boolean;
  isPublished: boolean;
}

const EMPTY_FORM: FormState = {
  title: '',
  content: '',
  isPinned: false,
  isPublished: true,
};

export default function NoticesPage() {
  const [items, setItems] = useState<Notice[]>([]);
  const [loading, setLoading] = useState(false);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [limit] = useState(15);

  const [modalOpen, setModalOpen] = useState(false);
  const [editing, setEditing] = useState<Notice | null>(null);
  const [form, setForm] = useState<FormState>(EMPTY_FORM);
  const [saving, setSaving] = useState(false);

  const fetchNotices = useCallback(async () => {
    try {
      setLoading(true);
      const res = await noticesApi.getNotices({ page, limit });
      setItems(res.items);
      setTotal(res.total);
    } catch {
      message.error('공지사항 목록을 불러올 수 없습니다.');
    } finally {
      setLoading(false);
    }
  }, [page, limit]);

  useEffect(() => {
    fetchNotices();
  }, [fetchNotices]);

  const openCreate = () => {
    setEditing(null);
    setForm(EMPTY_FORM);
    setModalOpen(true);
  };

  const openEdit = (n: Notice) => {
    setEditing(n);
    setForm({
      title: n.title,
      content: n.content,
      isPinned: n.isPinned,
      isPublished: n.isPublished,
    });
    setModalOpen(true);
  };

  const handleSubmit = async () => {
    if (!form.title.trim()) {
      message.warning('제목을 입력하세요.');
      return;
    }
    if (!form.content.trim()) {
      message.warning('내용을 입력하세요.');
      return;
    }
    try {
      setSaving(true);
      const payload = {
        title: form.title.trim(),
        content: form.content.trim(),
        isPinned: form.isPinned,
        isPublished: form.isPublished,
      };
      if (editing) {
        await noticesApi.updateNotice(editing.id, payload);
        message.success('공지사항을 수정했습니다.');
      } else {
        await noticesApi.createNotice(payload);
        message.success('공지사항을 등록했습니다.');
      }
      setModalOpen(false);
      fetchNotices();
    } catch {
      message.error('저장 중 오류가 발생했습니다.');
    } finally {
      setSaving(false);
    }
  };

  const handleDelete = async (id: string) => {
    try {
      await noticesApi.deleteNotice(id);
      message.success('공지사항을 삭제했습니다.');
      fetchNotices();
    } catch {
      message.error('삭제 중 오류가 발생했습니다.');
    }
  };

  const columns = [
    {
      title: '제목',
      dataIndex: 'title',
      key: 'title',
      render: (title: string) => (
        <Text strong>{title.length > 40 ? `${title.slice(0, 40)}…` : title}</Text>
      ),
    },
    {
      title: '홈 노출',
      key: 'isPinned',
      width: 100,
      render: (_: unknown, r: Notice) =>
        r.isPinned ? <Tag color="orange">고정</Tag> : <Tag>일반</Tag>,
    },
    {
      title: '게시 상태',
      key: 'isPublished',
      width: 110,
      render: (_: unknown, r: Notice) =>
        r.isPublished ? (
          <Tag color="green">게시중</Tag>
        ) : (
          <Tag color="default">미게시</Tag>
        ),
    },
    {
      title: '작성일',
      dataIndex: 'createdAt',
      key: 'createdAt',
      width: 140,
      render: (d: string) => dayjs(d).format('YYYY.MM.DD HH:mm'),
    },
    {
      title: '액션',
      key: 'action',
      width: 150,
      render: (_: unknown, r: Notice) => (
        <Space>
          <Button size="small" type="primary" onClick={() => openEdit(r)}>
            수정
          </Button>
          <Popconfirm
            title="이 공지사항을 삭제할까요?"
            okText="삭제"
            cancelText="취소"
            onConfirm={() => handleDelete(r.id)}
          >
            <Button size="small" danger>
              삭제
            </Button>
          </Popconfirm>
        </Space>
      ),
    },
  ];

  return (
    <div>
      <Title level={4} style={{ marginBottom: 24 }}>
        공지사항 관리
      </Title>

      <Card>
        <Space style={{ marginBottom: 16 }}>
          <Button type="primary" icon={<PlusOutlined />} onClick={openCreate}>
            공지 작성
          </Button>
        </Space>

        <Table<Notice>
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
        title={editing ? '공지사항 수정' : '공지사항 작성'}
        open={modalOpen}
        onCancel={() => setModalOpen(false)}
        onOk={handleSubmit}
        okText="저장"
        cancelText="취소"
        confirmLoading={saving}
        width={640}
      >
        <div style={{ marginBottom: 8 }}>제목</div>
        <Input
          value={form.title}
          onChange={(e) => setForm({ ...form, title: e.target.value })}
          placeholder="공지사항 제목"
          maxLength={200}
          showCount
        />

        <div style={{ marginTop: 16, marginBottom: 8 }}>내용</div>
        <Input.TextArea
          rows={8}
          value={form.content}
          onChange={(e) => setForm({ ...form, content: e.target.value })}
          placeholder="공지사항 내용을 입력하세요"
        />

        <div style={{ marginTop: 16 }}>
          <Space size="large">
            <Space>
              <Switch
                checked={form.isPinned}
                onChange={(v) => setForm({ ...form, isPinned: v })}
              />
              <span>홈 화면 상단 고정</span>
            </Space>
            <Space>
              <Switch
                checked={form.isPublished}
                onChange={(v) => setForm({ ...form, isPublished: v })}
              />
              <span>게시 (앱에 노출)</span>
            </Space>
          </Space>
        </div>
      </Modal>
    </div>
  );
}
