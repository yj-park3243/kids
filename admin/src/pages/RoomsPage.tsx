import { useEffect, useState, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { Card, Table, Input, Select, Tag, Typography, Space, message } from 'antd';
import { SearchOutlined } from '@ant-design/icons';
import dayjs from 'dayjs';
import { roomsApi } from '../api/rooms';
import type { RoomListItem } from '../types';

const { Title } = Typography;
const { Option } = Select;

const STATUS_MAP: Record<string, { color: string; label: string }> = {
  RECRUITING: { color: 'blue', label: '모집중' },
  CLOSED: { color: 'orange', label: '모집완료' },
  IN_PROGRESS: { color: 'green', label: '진행중' },
  COMPLETED: { color: 'default', label: '완료' },
  CANCELLED: { color: 'red', label: '취소' },
};

export default function RoomsPage() {
  const [rooms, setRooms] = useState<RoomListItem[]>([]);
  const [loading, setLoading] = useState(false);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [limit] = useState(15);
  const [search, setSearch] = useState('');
  const [status, setStatus] = useState<string>('');
  const navigate = useNavigate();

  const fetchRooms = useCallback(async () => {
    try {
      setLoading(true);
      const res = await roomsApi.getRooms({
        page,
        limit,
        search: search || undefined,
        status: status || undefined,
      });
      setRooms(res.items);
      setTotal(res.total);
    } catch {
      message.error('모임 목록을 불러올 수 없습니다.');
    } finally {
      setLoading(false);
    }
  }, [page, limit, search, status]);

  useEffect(() => {
    fetchRooms();
  }, [fetchRooms]);

  const handleSearch = (value: string) => {
    setSearch(value);
    setPage(1);
  };

  const handleStatusFilter = (value: string) => {
    setStatus(value);
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
      title: '제목',
      dataIndex: 'title',
      key: 'title',
      ellipsis: true,
    },
    {
      title: '방장',
      dataIndex: 'host',
      key: 'host',
      width: 100,
      render: (host: RoomListItem['host']) => host?.nickname || '-',
    },
    {
      title: '날짜',
      dataIndex: 'date',
      key: 'date',
      width: 120,
      render: (date: string) => dayjs(date).format('YYYY.MM.DD'),
    },
    {
      title: '지역',
      key: 'region',
      width: 140,
      render: (_: unknown, record: RoomListItem) =>
        record.regionDong || '-',
    },
    {
      title: '인원',
      key: 'members',
      width: 80,
      align: 'center' as const,
      render: (_: unknown, record: RoomListItem) => `${record.currentMembers}/${record.maxMembers}`,
    },
    {
      title: '상태',
      dataIndex: 'status',
      key: 'status',
      width: 90,
      render: (status: string) => {
        const s = STATUS_MAP[status] || { color: 'default', label: status };
        return <Tag color={s.color}>{s.label}</Tag>;
      },
    },
  ];

  return (
    <div>
      <Title level={4} style={{ marginBottom: 24 }}>
        모임 관리
      </Title>

      <Card>
        <Space style={{ marginBottom: 16 }} wrap>
          <Input.Search
            placeholder="제목 또는 방장 닉네임 검색"
            allowClear
            onSearch={handleSearch}
            style={{ width: 300 }}
            prefix={<SearchOutlined />}
          />
          <Select
            placeholder="상태 필터"
            allowClear
            onChange={handleStatusFilter}
            style={{ width: 150 }}
            value={status || undefined}
          >
            <Option value="">전체</Option>
            <Option value="RECRUITING">모집중</Option>
            <Option value="CLOSED">모집완료</Option>
            <Option value="IN_PROGRESS">진행중</Option>
            <Option value="COMPLETED">완료</Option>
            <Option value="CANCELLED">취소</Option>
          </Select>
        </Space>

        <Table<RoomListItem>
          dataSource={rooms}
          columns={columns}
          rowKey="id"
          loading={loading}
          pagination={{
            current: page,
            pageSize: limit,
            total,
            showTotal: (total) => `총 ${total}개`,
            onChange: (p) => setPage(p),
            showSizeChanger: false,
          }}
          onRow={(record) => ({
            onClick: () => navigate(`/rooms/${record.id}`),
            style: { cursor: 'pointer' },
          })}
        />
      </Card>
    </div>
  );
}
