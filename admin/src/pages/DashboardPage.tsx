import { useEffect, useState } from 'react';
import { Row, Col, Typography, Spin, message, Card } from 'antd';
import {
  UserOutlined,
  HomeOutlined,
  UserAddOutlined,
  PlusCircleOutlined,
  StopOutlined,
  CheckCircleOutlined,
  WifiOutlined,
  EyeOutlined,
  TeamOutlined,
} from '@ant-design/icons';
import {
  ResponsiveContainer,
  LineChart,
  Line,
  XAxis,
  YAxis,
  Tooltip,
  CartesianGrid,
  Legend,
} from 'recharts';
import dayjs from 'dayjs';
import StatCard from '../components/StatCard';
import { dashboardApi } from '../api/dashboard';
import type { DashboardStats, TrendPoint } from '../types';

const { Title } = Typography;

const POLL_INTERVAL_MS = 30_000;

export default function DashboardPage() {
  const [stats, setStats] = useState<DashboardStats | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchDashboard(true);
    const id = setInterval(() => fetchDashboard(false), POLL_INTERVAL_MS);
    return () => clearInterval(id);
  }, []);

  const fetchDashboard = async (showSpinner: boolean) => {
    try {
      if (showSpinner) setLoading(true);
      const res = await dashboardApi.getDashboard();
      setStats(res);
    } catch {
      if (showSpinner) message.error('대시보드 데이터를 불러올 수 없습니다.');
    } finally {
      if (showSpinner) setLoading(false);
    }
  };

  if (loading) {
    return (
      <div style={{ display: 'flex', justifyContent: 'center', alignItems: 'center', height: 400 }}>
        <Spin size="large" />
      </div>
    );
  }

  return (
    <div>
      <Title level={4} style={{ marginBottom: 24 }}>
        대시보드
      </Title>

      {/* 실시간 접속 */}
      <Title level={5} style={{ marginBottom: 12 }}>
        실시간
      </Title>
      <Row gutter={[16, 16]} style={{ marginBottom: 24 }}>
        <Col xs={24} sm={12} lg={8}>
          <StatCard
            title="현재 접속자 (5분 내)"
            value={stats?.currentOnline ?? 0}
            icon={<WifiOutlined />}
            color="#52C41A"
          />
        </Col>
        <Col xs={24} sm={12} lg={8}>
          <StatCard
            title="오늘 방문자 수"
            value={stats?.todayVisitors ?? 0}
            icon={<EyeOutlined />}
            color="#13C2C2"
          />
        </Col>
        <Col xs={24} sm={12} lg={8}>
          <StatCard
            title="오늘 신규 가입"
            value={stats?.todayUsers ?? 0}
            icon={<UserAddOutlined />}
            color="#F9CA24"
          />
        </Col>
      </Row>

      {/* 회원 */}
      <Title level={5} style={{ marginBottom: 12 }}>
        회원
      </Title>
      <Row gutter={[16, 16]} style={{ marginBottom: 24 }}>
        <Col xs={24} sm={12} lg={6}>
          <StatCard
            title="총 회원수"
            value={stats?.totalUsers ?? 0}
            icon={<UserOutlined />}
            color="#FF6B6B"
          />
        </Col>
        <Col xs={24} sm={12} lg={6}>
          <StatCard
            title="최근 7일 가입"
            value={stats?.last7DaysSignups ?? 0}
            icon={<TeamOutlined />}
            color="#9254DE"
          />
        </Col>
        <Col xs={24} sm={12} lg={6}>
          <StatCard
            title="정지 회원수"
            value={stats?.bannedUsers ?? 0}
            icon={<StopOutlined />}
            color="#E17055"
          />
        </Col>
        <Col xs={24} sm={12} lg={6}>
          <StatCard
            title="오늘 신규"
            value={stats?.todayUsers ?? 0}
            icon={<UserAddOutlined />}
            color="#F9CA24"
          />
        </Col>
      </Row>

      {/* 모임 */}
      <Title level={5} style={{ marginBottom: 12 }}>
        모임
      </Title>
      <Row gutter={[16, 16]} style={{ marginBottom: 24 }}>
        <Col xs={24} sm={12} lg={8}>
          <StatCard
            title="누적 모임수"
            value={stats?.totalRooms ?? 0}
            icon={<HomeOutlined />}
            color="#4ECDC4"
          />
        </Col>
        <Col xs={24} sm={12} lg={8}>
          <StatCard
            title="현재 활성 모임"
            value={stats?.activeRooms ?? 0}
            icon={<CheckCircleOutlined />}
            color="#45B7D1"
          />
        </Col>
        <Col xs={24} sm={12} lg={8}>
          <StatCard
            title="오늘 생성된 모임"
            value={stats?.todayRooms ?? 0}
            icon={<PlusCircleOutlined />}
            color="#6C5CE7"
          />
        </Col>
      </Row>

      {/* 추이 그래프 */}
      <Title level={5} style={{ marginBottom: 12 }}>
        최근 30일 추이
      </Title>
      <Row gutter={[16, 16]}>
        <Col xs={24} lg={12}>
          <TrendChartCard
            title="일별 가입자 / 방문자"
            data={mergeTrend(stats?.signupTrend ?? [], stats?.visitorTrend ?? [])}
            lines={[
              { key: 'signup', name: '신규 가입', color: '#FF6B6B' },
              { key: 'visitor', name: '방문자', color: '#13C2C2' },
            ]}
          />
        </Col>
        <Col xs={24} lg={12}>
          <TrendChartCard
            title="일별 모임 생성"
            data={(stats?.roomTrend ?? []).map((p) => ({ date: p.date, room: p.count }))}
            lines={[{ key: 'room', name: '모임 생성', color: '#6C5CE7' }]}
          />
        </Col>
      </Row>
    </div>
  );
}

// 두 추이를 date 기준으로 머지 (없는 날은 0으로 처리하지 않고 raw 그대로 — recharts가 missing point는 graph break)
function mergeTrend(signup: TrendPoint[], visitor: TrendPoint[]) {
  const map = new Map<string, { date: string; signup?: number; visitor?: number }>();
  signup.forEach((p) => {
    map.set(p.date, { ...(map.get(p.date) ?? { date: p.date }), signup: p.count });
  });
  visitor.forEach((p) => {
    map.set(p.date, { ...(map.get(p.date) ?? { date: p.date }), visitor: p.count });
  });
  return Array.from(map.values()).sort((a, b) => a.date.localeCompare(b.date));
}

interface TrendChartCardProps {
  title: string;
  data: Array<Record<string, string | number | undefined>>;
  lines: Array<{ key: string; name: string; color: string }>;
}

function TrendChartCard({ title, data, lines }: TrendChartCardProps) {
  return (
    <Card title={title}>
      <div style={{ width: '100%', height: 280 }}>
        {data.length === 0 ? (
          <div
            style={{
              height: '100%',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              color: '#999',
            }}
          >
            데이터가 없습니다
          </div>
        ) : (
          <ResponsiveContainer>
            <LineChart data={data} margin={{ top: 8, right: 16, left: -16, bottom: 0 }}>
              <CartesianGrid strokeDasharray="3 3" stroke="#eee" />
              <XAxis
                dataKey="date"
                tickFormatter={(d) => dayjs(d as string).format('M/D')}
                fontSize={12}
              />
              <YAxis allowDecimals={false} fontSize={12} />
              <Tooltip
                labelFormatter={(d) => dayjs(d as string).format('YYYY-MM-DD')}
              />
              <Legend />
              {lines.map((l) => (
                <Line
                  key={l.key}
                  type="monotone"
                  dataKey={l.key}
                  name={l.name}
                  stroke={l.color}
                  strokeWidth={2}
                  dot={false}
                  connectNulls
                />
              ))}
            </LineChart>
          </ResponsiveContainer>
        )}
      </div>
    </Card>
  );
}
