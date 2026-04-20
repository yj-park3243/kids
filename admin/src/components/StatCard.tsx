import { Card, Statistic } from 'antd';
import type { ReactNode } from 'react';

interface Props {
  title: string;
  value: number;
  icon: ReactNode;
  color: string;
  loading?: boolean;
}

export default function StatCard({ title, value, icon, color, loading }: Props) {
  return (
    <Card
      hoverable
      style={{ borderTop: `3px solid ${color}` }}
      styles={{ body: { padding: '20px 24px' } }}
    >
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <Statistic title={title} value={value} loading={loading} />
        <div
          style={{
            fontSize: 32,
            color,
            opacity: 0.8,
          }}
        >
          {icon}
        </div>
      </div>
    </Card>
  );
}
