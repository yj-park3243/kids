import { useEffect, useState, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { Card, Table, Input, Tag, Typography, Space, message } from 'antd';
import { SearchOutlined } from '@ant-design/icons';
import dayjs from 'dayjs';
import { usersApi } from '../api/users';
import type { User } from '../types';

const { Title } = Typography;

const STATUS_MAP: Record<string, { color: string; label: string }> = {
  ACTIVE: { color: 'green', label: '활성' },
  BANNED: { color: 'red', label: '정지' },
  WITHDRAWN: { color: 'default', label: '탈퇴' },
};

export default function UsersPage() {
  const [users, setUsers] = useState<User[]>([]);
  const [loading, setLoading] = useState(false);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [limit] = useState(15);
  const [search, setSearch] = useState('');
  const navigate = useNavigate();

  const fetchUsers = useCallback(async () => {
    try {
      setLoading(true);
      const res = await usersApi.getUsers({
        page,
        limit,
        search: search || undefined,
      });
      setUsers(res.items);
      setTotal(res.total);
    } catch {
      message.error('유저 목록을 불러올 수 없습니다.');
    } finally {
      setLoading(false);
    }
  }, [page, limit, search]);

  useEffect(() => {
    fetchUsers();
  }, [fetchUsers]);

  const handleSearch = (value: string) => {
    setSearch(value);
    setPage(1);
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
      title: '닉네임',
      dataIndex: 'nickname',
      key: 'nickname',
      render: (nickname: string | null) => nickname || '-',
    },
    {
      title: '이메일',
      dataIndex: 'email',
      key: 'email',
      render: (email: string | null) => email || '-',
    },
    {
      title: '지역',
      key: 'region',
      render: (_: unknown, record: User) =>
        record.regionSigungu && record.regionDong
          ? `${record.regionSigungu} ${record.regionDong}`
          : '-',
    },
    {
      title: '아이 수',
      key: 'childrenCount',
      width: 80,
      align: 'center' as const,
      render: (_: unknown, record: User) => record.children?.length ?? 0,
    },
    {
      title: '가입일',
      dataIndex: 'createdAt',
      key: 'createdAt',
      width: 120,
      render: (date: string) => dayjs(date).format('YYYY.MM.DD'),
    },
    {
      title: '상태',
      dataIndex: 'status',
      key: 'status',
      width: 80,
      render: (status: string) => {
        const s = STATUS_MAP[status] || { color: 'default', label: status };
        return <Tag color={s.color}>{s.label}</Tag>;
      },
    },
  ];

  return (
    <div>
      <Title level={4} style={{ marginBottom: 24 }}>
        유저 관리
      </Title>

      <Card>
        <Space style={{ marginBottom: 16 }} wrap>
          <Input.Search
            placeholder="닉네임 또는 이메일 검색"
            allowClear
            onSearch={handleSearch}
            style={{ width: 300 }}
            prefix={<SearchOutlined />}
          />
        </Space>

        <Table<User>
          dataSource={users}
          columns={columns}
          rowKey="id"
          loading={loading}
          pagination={{
            current: page,
            pageSize: limit,
            total,
            showTotal: (total) => `총 ${total}명`,
            onChange: (p) => setPage(p),
            showSizeChanger: false,
          }}
          onRow={(record) => ({
            onClick: () => navigate(`/users/${record.id}`),
            style: { cursor: 'pointer' },
          })}
        />
      </Card>
    </div>
  );
}
