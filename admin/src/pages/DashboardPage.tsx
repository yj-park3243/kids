import { useEffect, useState } from 'react';
import { Row, Col, Typography, Spin, message } from 'antd';
import {
  UserOutlined,
  HomeOutlined,
  UserAddOutlined,
  PlusCircleOutlined,
  StopOutlined,
  CheckCircleOutlined,
} from '@ant-design/icons';
import StatCard from '../components/StatCard';
import { dashboardApi } from '../api/dashboard';
import type { DashboardStats } from '../types';

const { Title } = Typography;

export default function DashboardPage() {
  const [stats, setStats] = useState<DashboardStats | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchDashboard();
  }, []);

  const fetchDashboard = async () => {
    try {
      setLoading(true);
      const res = await dashboardApi.getDashboard();
      setStats(res);
    } catch {
      message.error('대시보드 데이터를 불러올 수 없습니다.');
    } finally {
      setLoading(false);
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

      {/* Stats Cards */}
      <Row gutter={[16, 16]} style={{ marginBottom: 24 }}>
        <Col xs={24} sm={12} lg={8}>
          <StatCard
            title="총 회원수"
            value={stats?.totalUsers ?? 0}
            icon={<UserOutlined />}
            color="#FF6B6B"
          />
        </Col>
        <Col xs={24} sm={12} lg={8}>
          <StatCard
            title="총 모임수"
            value={stats?.totalRooms ?? 0}
            icon={<HomeOutlined />}
            color="#4ECDC4"
          />
        </Col>
        <Col xs={24} sm={12} lg={8}>
          <StatCard
            title="활성 모임수"
            value={stats?.activeRooms ?? 0}
            icon={<CheckCircleOutlined />}
            color="#45B7D1"
          />
        </Col>
      </Row>

      <Row gutter={[16, 16]}>
        <Col xs={24} sm={12} lg={8}>
          <StatCard
            title="오늘 신규 가입"
            value={stats?.todayUsers ?? 0}
            icon={<UserAddOutlined />}
            color="#F9CA24"
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
        <Col xs={24} sm={12} lg={8}>
          <StatCard
            title="정지 회원수"
            value={stats?.bannedUsers ?? 0}
            icon={<StopOutlined />}
            color="#E17055"
          />
        </Col>
      </Row>
    </div>
  );
}
