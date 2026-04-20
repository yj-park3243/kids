import { useState } from 'react';
import { useNavigate, useLocation, Outlet } from 'react-router-dom';
import { Layout as AntLayout, Menu, Button, Dropdown, theme, Typography } from 'antd';
import {
  DashboardOutlined,
  UserOutlined,
  HomeOutlined,
  SettingOutlined,
  LogoutOutlined,
  MenuFoldOutlined,
  MenuUnfoldOutlined,
} from '@ant-design/icons';
import { authStore } from '../stores/authStore';

const { Header, Sider, Content } = AntLayout;
const { Text } = Typography;

export default function Layout() {
  const [collapsed, setCollapsed] = useState(false);
  const navigate = useNavigate();
  const location = useLocation();
  const admin = authStore.getAdmin();
  const {
    token: { colorBgContainer, borderRadiusLG },
  } = theme.useToken();

  const menuItems = [
    {
      key: '/dashboard',
      icon: <DashboardOutlined />,
      label: '대시보드',
    },
    {
      key: '/users',
      icon: <UserOutlined />,
      label: '유저 관리',
    },
    {
      key: '/rooms',
      icon: <HomeOutlined />,
      label: '모임 관리',
    },
    {
      type: 'divider' as const,
    },
    {
      key: '/settings',
      icon: <SettingOutlined />,
      label: '설정',
      disabled: true,
    },
  ];

  const handleLogout = () => {
    authStore.clear();
    navigate('/login');
  };

  const profileMenu = {
    items: [
      {
        key: 'logout',
        icon: <LogoutOutlined />,
        label: '로그아웃',
        onClick: handleLogout,
      },
    ],
  };

  // Determine selected key based on current path
  const selectedKey = location.pathname.startsWith('/users')
    ? '/users'
    : location.pathname.startsWith('/rooms')
      ? '/rooms'
      : location.pathname;

  return (
    <AntLayout style={{ minHeight: '100vh' }}>
      <Sider
        trigger={null}
        collapsible
        collapsed={collapsed}
        style={{
          background: '#2D3436',
          overflow: 'auto',
          height: '100vh',
          position: 'fixed',
          left: 0,
          top: 0,
          bottom: 0,
          zIndex: 100,
        }}
        width={240}
      >
        <div
          style={{
            height: 64,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            borderBottom: '1px solid rgba(255,255,255,0.1)',
          }}
        >
          <Text
            strong
            style={{
              color: '#FF6B6B',
              fontSize: collapsed ? 16 : 20,
              whiteSpace: 'nowrap',
            }}
          >
            {collapsed ? '같크' : '같이크자 Admin'}
          </Text>
        </div>
        <Menu
          theme="dark"
          mode="inline"
          selectedKeys={[selectedKey]}
          items={menuItems}
          onClick={({ key }) => navigate(key)}
          style={{ background: '#2D3436', borderRight: 0, marginTop: 8 }}
        />
      </Sider>
      <AntLayout style={{ marginLeft: collapsed ? 80 : 240, transition: 'margin-left 0.2s' }}>
        <Header
          style={{
            padding: '0 24px',
            background: colorBgContainer,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            boxShadow: '0 1px 4px rgba(0,0,0,0.08)',
            position: 'sticky',
            top: 0,
            zIndex: 99,
          }}
        >
          <Button
            type="text"
            icon={collapsed ? <MenuUnfoldOutlined /> : <MenuFoldOutlined />}
            onClick={() => setCollapsed(!collapsed)}
            style={{ fontSize: 16, width: 48, height: 48 }}
          />
          <Dropdown menu={profileMenu} placement="bottomRight">
            <Button type="text" icon={<UserOutlined />}>
              {admin?.nickname || admin?.email || '관리자'}
            </Button>
          </Dropdown>
        </Header>
        <Content
          style={{
            margin: 24,
            padding: 24,
            minHeight: 280,
            background: '#F5F6FA',
            borderRadius: borderRadiusLG,
          }}
        >
          <Outlet />
        </Content>
      </AntLayout>
    </AntLayout>
  );
}
