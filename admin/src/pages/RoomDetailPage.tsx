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
  Popconfirm,
  message,
  Divider,
} from 'antd';
import {
  ArrowLeftOutlined,
  DeleteOutlined,
} from '@ant-design/icons';
import dayjs from 'dayjs';
import { roomsApi } from '../api/rooms';
import type { Room, RoomMember } from '../types';

const { Title } = Typography;

const STATUS_MAP: Record<string, { color: string; label: string }> = {
  RECRUITING: { color: 'blue', label: '모집중' },
  CLOSED: { color: 'orange', label: '모집완료' },
  IN_PROGRESS: { color: 'green', label: '진행중' },
  COMPLETED: { color: 'default', label: '완료' },
  CANCELLED: { color: 'red', label: '취소' },
};

const PLACE_TYPE_MAP: Record<string, string> = {
  PLAYGROUND: '놀이터',
  KIDS_CAFE: '키즈카페',
  PARTY_ROOM: '파티룸',
  PARK: '공원',
  OTHER: '기타',
};

const JOIN_TYPE_MAP: Record<string, string> = {
  FREE: '자유 입장',
  APPROVAL: '승인 필요',
};

export default function RoomDetailPage() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const [room, setRoom] = useState<Room | null>(null);
  const [loading, setLoading] = useState(true);
  const [deleteLoading, setDeleteLoading] = useState(false);

  useEffect(() => {
    if (id) fetchRoom(id);
  }, [id]);

  const fetchRoom = async (roomId: string) => {
    try {
      setLoading(true);
      const res = await roomsApi.getRoom(roomId);
      setRoom(res);
    } catch {
      message.error('모임 정보를 불러올 수 없습니다.');
      navigate('/rooms');
    } finally {
      setLoading(false);
    }
  };

  const handleDelete = async () => {
    if (!id) return;
    try {
      setDeleteLoading(true);
      await roomsApi.deleteRoom(id);
      message.success('모임이 삭제되었습니다.');
      navigate('/rooms');
    } catch {
      message.error('삭제 중 오류가 발생했습니다.');
    } finally {
      setDeleteLoading(false);
    }
  };

  const memberColumns = [
    {
      title: '닉네임',
      key: 'nickname',
      render: (_: unknown, record: RoomMember) => record.user?.nickname || '-',
    },
    {
      title: '이메일',
      key: 'email',
      render: (_: unknown, record: RoomMember) => record.user?.email || '-',
    },
    {
      title: '역할',
      key: 'role',
      width: 80,
      render: (_: unknown, record: RoomMember) =>
        record.isHost ? <Tag color="gold">방장</Tag> : <Tag>참여자</Tag>,
    },
  ];

  if (loading) {
    return (
      <div style={{ display: 'flex', justifyContent: 'center', alignItems: 'center', height: 400 }}>
        <Spin size="large" />
      </div>
    );
  }

  if (!room) return null;

  const statusInfo = STATUS_MAP[room.status] || { color: 'default', label: room.status };

  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 24 }}>
        <Space>
          <Button icon={<ArrowLeftOutlined />} onClick={() => navigate('/rooms')}>
            목록으로
          </Button>
        </Space>
        <Popconfirm
          title="이 모임을 삭제하시겠습니까?"
          description="삭제된 모임은 복구할 수 없습니다."
          onConfirm={handleDelete}
          okText="삭제"
          cancelText="취소"
          okButtonProps={{ danger: true }}
        >
          <Button danger icon={<DeleteOutlined />} loading={deleteLoading}>
            모임 삭제
          </Button>
        </Popconfirm>
      </div>

      <Card style={{ marginBottom: 24 }}>
        <Space align="center" style={{ marginBottom: 16 }}>
          <Title level={4} style={{ margin: 0 }}>
            {room.title}
          </Title>
          <Tag color={statusInfo.color}>{statusInfo.label}</Tag>
        </Space>

        <Descriptions bordered column={{ xs: 1, sm: 2 }} size="small">
          <Descriptions.Item label="ID">
            <span style={{ fontFamily: 'monospace', fontSize: 12 }}>{room.id}</span>
          </Descriptions.Item>
          <Descriptions.Item label="방장">{room.host?.nickname || '-'}</Descriptions.Item>
          <Descriptions.Item label="날짜">
            {dayjs(room.date).format('YYYY.MM.DD')}
          </Descriptions.Item>
          <Descriptions.Item label="시간">
            {room.startTime}{room.endTime ? ` ~ ${room.endTime}` : ''}
          </Descriptions.Item>
          <Descriptions.Item label="지역">
            {room.regionSido} {room.regionSigungu} {room.regionDong}
          </Descriptions.Item>
          <Descriptions.Item label="장소 유형">
            {PLACE_TYPE_MAP[room.placeType] || room.placeType}
          </Descriptions.Item>
          {room.placeName && (
            <Descriptions.Item label="장소명">{room.placeName}</Descriptions.Item>
          )}
          {room.placeAddress && (
            <Descriptions.Item label="주소">{room.placeAddress}</Descriptions.Item>
          )}
          <Descriptions.Item label="대상 개월수">
            {room.ageMonthMin}~{room.ageMonthMax}개월
          </Descriptions.Item>
          <Descriptions.Item label="인원">
            {room.currentMembers}/{room.maxMembers}명
          </Descriptions.Item>
          <Descriptions.Item label="입장 방식">
            {JOIN_TYPE_MAP[room.joinType] || room.joinType}
          </Descriptions.Item>
          <Descriptions.Item label="비용">
            {room.cost === 0 ? '무료' : `${room.cost.toLocaleString()}원`}
            {room.costDescription ? ` (${room.costDescription})` : ''}
          </Descriptions.Item>
          <Descriptions.Item label="태그" span={2}>
            {room.tags && room.tags.length > 0
              ? room.tags.map((tag) => (
                  <Tag key={tag} style={{ marginBottom: 4 }}>
                    #{tag}
                  </Tag>
                ))
              : '-'}
          </Descriptions.Item>
          <Descriptions.Item label="설명" span={2}>
            <div style={{ whiteSpace: 'pre-wrap' }}>{room.description}</div>
          </Descriptions.Item>
          <Descriptions.Item label="생성일">
            {dayjs(room.createdAt).format('YYYY.MM.DD HH:mm')}
          </Descriptions.Item>
          <Descriptions.Item label="수정일">
            {dayjs(room.updatedAt).format('YYYY.MM.DD HH:mm')}
          </Descriptions.Item>
        </Descriptions>
      </Card>

      <Divider />

      {/* Members */}
      <Card title={`참여자 목록 (${room.members?.length || 0}명)`}>
        <Table<RoomMember>
          dataSource={room.members || []}
          columns={memberColumns}
          rowKey="id"
          pagination={false}
          size="small"
          locale={{ emptyText: '참여자가 없습니다.' }}
        />
      </Card>
    </div>
  );
}
