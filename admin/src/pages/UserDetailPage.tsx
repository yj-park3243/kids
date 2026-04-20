import { useEffect, useState } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import {
  Card,
  Descriptions,
  Tag,
  Button,
  Table,
  Typography,
  Spin,
  Space,
  Avatar,
  Popconfirm,
  message,
} from 'antd';
import {
  ArrowLeftOutlined,
  UserOutlined,
  StopOutlined,
  CheckCircleOutlined,
} from '@ant-design/icons';
import dayjs from 'dayjs';
import { usersApi } from '../api/users';
import type { UserDetail, Child } from '../types';

const { Title } = Typography;

const STATUS_MAP: Record<string, { color: string; label: string }> = {
  ACTIVE: { color: 'green', label: '활성' },
  BANNED: { color: 'red', label: '정지' },
  WITHDRAWN: { color: 'default', label: '탈퇴' },
};

const GENDER_MAP: Record<string, string> = {
  MALE: '남',
  FEMALE: '여',
};

export default function UserDetailPage() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const [user, setUser] = useState<UserDetail | null>(null);
  const [loading, setLoading] = useState(true);
  const [actionLoading, setActionLoading] = useState(false);

  useEffect(() => {
    if (id) fetchUser(id);
  }, [id]);

  const fetchUser = async (userId: string) => {
    try {
      setLoading(true);
      const res = await usersApi.getUser(userId);
      setUser(res);
    } catch {
      message.error('유저 정보를 불러올 수 없습니다.');
      navigate('/users');
    } finally {
      setLoading(false);
    }
  };

  const handleBan = async () => {
    if (!id || !user) return;
    try {
      setActionLoading(true);
      if (user.status === 'BANNED') {
        await usersApi.banUser(id, false);
        message.success('정지가 해제되었습니다.');
      } else {
        await usersApi.banUser(id, true);
        message.success('유저가 정지되었습니다.');
      }
      fetchUser(id);
    } catch {
      message.error('처리 중 오류가 발생했습니다.');
    } finally {
      setActionLoading(false);
    }
  };

  const childColumns = [
    {
      title: '별명',
      dataIndex: 'nickname',
      key: 'nickname',
    },
    {
      title: '생년월',
      key: 'birth',
      render: (_: unknown, record: Child) => `${record.birthYear}.${String(record.birthMonth).padStart(2, '0')}`,
    },
    {
      title: '성별',
      dataIndex: 'gender',
      key: 'gender',
      render: (gender: string | null) => (gender ? GENDER_MAP[gender] || gender : '-'),
    },
  ];

  if (loading) {
    return (
      <div style={{ display: 'flex', justifyContent: 'center', alignItems: 'center', height: 400 }}>
        <Spin size="large" />
      </div>
    );
  }

  if (!user) return null;

  const statusInfo = STATUS_MAP[user.status] || { color: 'default', label: user.status };

  return (
    <div>
      <Space style={{ marginBottom: 24 }}>
        <Button icon={<ArrowLeftOutlined />} onClick={() => navigate('/users')}>
          목록으로
        </Button>
      </Space>

      <Card style={{ marginBottom: 24 }}>
        <div style={{ display: 'flex', alignItems: 'flex-start', gap: 24, marginBottom: 24 }}>
          <Avatar
            size={80}
            src={user.profileImageUrl}
            icon={<UserOutlined />}
            style={{ flexShrink: 0 }}
          />
          <div style={{ flex: 1 }}>
            <Space align="center" style={{ marginBottom: 8 }}>
              <Title level={4} style={{ margin: 0 }}>
                {user.nickname || '(닉네임 없음)'}
              </Title>
              <Tag color={statusInfo.color}>{statusInfo.label}</Tag>
            </Space>
            <div style={{ color: '#888' }}>
              {user.email || '-'} | {user.authProvider}
            </div>
          </div>
          <div>
            {user.status !== 'WITHDRAWN' && (
              <Popconfirm
                title={user.status === 'BANNED' ? '정지를 해제하시겠습니까?' : '유저를 정지하시겠습니까?'}
                onConfirm={handleBan}
                okText="확인"
                cancelText="취소"
              >
                <Button
                  danger={user.status !== 'BANNED'}
                  type={user.status === 'BANNED' ? 'primary' : 'default'}
                  icon={user.status === 'BANNED' ? <CheckCircleOutlined /> : <StopOutlined />}
                  loading={actionLoading}
                >
                  {user.status === 'BANNED' ? '정지 해제' : '정지'}
                </Button>
              </Popconfirm>
            )}
          </div>
        </div>

        <Descriptions bordered column={{ xs: 1, sm: 2 }} size="small">
          <Descriptions.Item label="ID">
            <span style={{ fontFamily: 'monospace', fontSize: 12 }}>{user.id}</span>
          </Descriptions.Item>
          <Descriptions.Item label="인증 방식">{user.authProvider}</Descriptions.Item>
          <Descriptions.Item label="지역">
            {user.regionSido} {user.regionSigungu} {user.regionDong}
          </Descriptions.Item>
          <Descriptions.Item label="본인인증">
            {user.isPhoneVerified ? (
              <Tag color="green">완료</Tag>
            ) : (
              <Tag color="default">미완료</Tag>
            )}
          </Descriptions.Item>
          <Descriptions.Item label="자기소개" span={2}>
            {user.introduction || '-'}
          </Descriptions.Item>
          <Descriptions.Item label="가입일">
            {dayjs(user.createdAt).format('YYYY.MM.DD HH:mm')}
          </Descriptions.Item>
          <Descriptions.Item label="수정일">
            {dayjs(user.updatedAt).format('YYYY.MM.DD HH:mm')}
          </Descriptions.Item>
          <Descriptions.Item label="생성한 모임 수">
            {user.roomCount ?? 0}개
          </Descriptions.Item>
        </Descriptions>
      </Card>

      {/* Children */}
      <Card title="아이 정보">
        <Table<Child>
          dataSource={user.children || []}
          columns={childColumns}
          rowKey="id"
          pagination={false}
          size="small"
          locale={{ emptyText: '등록된 아이가 없습니다.' }}
        />
      </Card>
    </div>
  );
}
