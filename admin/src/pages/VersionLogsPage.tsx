import { useEffect, useState, useCallback } from 'react';
import {
  Table,
  Card,
  Tag,
  Typography,
  Select,
  Space,
  Button,
  Tooltip,
  message,
  type TableProps,
} from 'antd';
import { ReloadOutlined } from '@ant-design/icons';
import dayjs from 'dayjs';
import { versionsApi, type VersionCheckLog } from '../api/versions';

const { Title, Text } = Typography;

export default function VersionLogsPage() {
  const [logs, setLogs] = useState<VersionCheckLog[]>([]);
  const [loading, setLoading] = useState(false);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [pageSize] = useState(50);
  const [platform, setPlatform] = useState<string | undefined>();
  const [hasLocation, setHasLocation] = useState<boolean | undefined>();

  const fetchLogs = useCallback(async () => {
    try {
      setLoading(true);
      const res = await versionsApi.getCheckLogs({
        page,
        pageSize,
        platform,
        hasLocation,
      });
      setLogs(res.data);
      setTotal(res.total);
    } catch {
      message.error('접속 로그를 불러올 수 없습니다.');
    } finally {
      setLoading(false);
    }
  }, [page, pageSize, platform, hasLocation]);

  useEffect(() => {
    fetchLogs();
  }, [fetchLogs]);

  const columns: TableProps<VersionCheckLog>['columns'] = [
    {
      title: '시간',
      dataIndex: 'createdAt',
      width: 160,
      render: (v: string) => dayjs(v).format('YYYY-MM-DD HH:mm:ss'),
    },
    {
      title: '사용자',
      width: 200,
      render: (_, r) =>
        r.userId ? (
          <div>
            <Text strong>{r.nickname ?? '-'}</Text>
            {r.email && (
              <Text type="secondary" style={{ fontSize: 12, display: 'block' }}>
                {r.email}
              </Text>
            )}
            {r.phoneNumber && (
              <Text type="secondary" style={{ fontSize: 12, display: 'block' }}>
                {r.phoneNumber}
              </Text>
            )}
          </div>
        ) : (
          <Tag>익명</Tag>
        ),
    },
    {
      title: '플랫폼',
      dataIndex: 'platform',
      width: 90,
      render: (v: string) => (
        <Tag color={v === 'IOS' ? 'blue' : 'green'}>{v}</Tag>
      ),
    },
    {
      title: '앱 버전',
      dataIndex: 'appVersion',
      width: 90,
      render: (v: string | null) => v ?? '-',
    },
    {
      title: '위치(GPS)',
      width: 130,
      render: (_, r) =>
        r.latitude != null && r.longitude != null ? (
          <a
            href={`https://maps.google.com/?q=${r.latitude},${r.longitude}`}
            target="_blank"
            rel="noreferrer"
          >
            {r.latitude.toFixed(4)}, {r.longitude.toFixed(4)}
          </a>
        ) : (
          '-'
        ),
    },
    {
      title: 'IP',
      dataIndex: 'ipAddress',
      width: 130,
      render: (v: string | null) => v ?? '-',
    },
    {
      title: 'IP 위치',
      dataIndex: 'ipLocation',
      render: (v: string | null) => v ?? '-',
    },
    {
      title: 'User-Agent',
      dataIndex: 'userAgent',
      width: 160,
      render: (v: string | null) =>
        v ? (
          <Tooltip title={v}>
            <Text ellipsis style={{ maxWidth: 150, display: 'inline-block' }}>
              {v}
            </Text>
          </Tooltip>
        ) : (
          '-'
        ),
    },
  ];

  return (
    <div>
      <Title level={3}>앱 접속 로그</Title>
      <Text type="secondary">
        앱 시작 시 버전 체크 호출 기록 — 누가, 어디서, 어떤 버전으로 접속했는지.
      </Text>
      <Card style={{ marginTop: 16 }}>
        <Space style={{ marginBottom: 16 }} wrap>
          <Select
            placeholder="플랫폼"
            allowClear
            value={platform}
            style={{ width: 120 }}
            onChange={(v) => {
              setPlatform(v);
              setPage(1);
            }}
            options={[
              { value: 'IOS', label: 'iOS' },
              { value: 'ANDROID', label: 'Android' },
            ]}
          />
          <Select
            placeholder="위치 유무"
            allowClear
            value={hasLocation}
            style={{ width: 140 }}
            onChange={(v) => {
              setHasLocation(v);
              setPage(1);
            }}
            options={[
              { value: true, label: '위치 있음' },
              { value: false, label: '위치 없음' },
            ]}
          />
          <Button icon={<ReloadOutlined />} onClick={fetchLogs}>
            새로고침
          </Button>
        </Space>
        <Table<VersionCheckLog>
          rowKey="id"
          loading={loading}
          columns={columns}
          dataSource={logs}
          scroll={{ x: 1000 }}
          pagination={{
            current: page,
            pageSize,
            total,
            showSizeChanger: false,
            onChange: setPage,
            showTotal: (t) => `총 ${t}건`,
          }}
        />
      </Card>
    </div>
  );
}
