import { useEffect, useState, useCallback } from 'react';
import {
  Button,
  Card,
  Input,
  InputNumber,
  Switch,
  Typography,
  Space,
  Row,
  Col,
  Spin,
  Tag,
  Alert,
  message,
} from 'antd';
import {
  versionsApi,
  type AppVersion,
  type UpdateVersionPayload,
} from '../api/versions';

const { Title, Text } = Typography;

export default function VersionPage() {
  const [versions, setVersions] = useState<AppVersion[]>([]);
  const [loading, setLoading] = useState(false);

  const fetchVersions = useCallback(async () => {
    try {
      setLoading(true);
      setVersions(await versionsApi.getVersions());
    } catch {
      message.error('버전 정보를 불러올 수 없습니다.');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchVersions();
  }, [fetchVersions]);

  return (
    <div>
      <Title level={3}>앱 버전 관리</Title>
      <Text type="secondary">
        플랫폼별 최소/최신 버전, 강제 업데이트, 광고 노출, 본인인증 우회(심사 모드)를 관리합니다.
      </Text>
      {loading && versions.length === 0 ? (
        <div style={{ textAlign: 'center', padding: 48 }}>
          <Spin />
        </div>
      ) : (
        <Row gutter={[16, 16]} style={{ marginTop: 16 }}>
          {versions.map((v) => (
            <Col xs={24} lg={12} key={v.id}>
              <VersionCard version={v} onSaved={fetchVersions} />
            </Col>
          ))}
        </Row>
      )}
    </div>
  );
}

function VersionCard({
  version,
  onSaved,
}: {
  version: AppVersion;
  onSaved: () => void;
}) {
  const [form, setForm] = useState<UpdateVersionPayload>({
    minVersion: version.minVersion,
    latestVersion: version.latestVersion,
    latestBuild: version.latestBuild,
    forceUpdate: version.forceUpdate,
    updateMessage: version.updateMessage ?? '',
    storeUrl: version.storeUrl ?? '',
    showAd: version.showAd,
    bypassPhoneVerification: version.bypassPhoneVerification,
  });
  const [saving, setSaving] = useState(false);

  const set = <K extends keyof UpdateVersionPayload>(
    key: K,
    value: UpdateVersionPayload[K],
  ) => setForm((prev) => ({ ...prev, [key]: value }));

  const save = async () => {
    try {
      setSaving(true);
      await versionsApi.updateVersion(version.id, form);
      message.success(`${version.platform} 버전 정보가 저장되었습니다.`);
      onSaved();
    } catch (e: unknown) {
      const msg =
        (e as { response?: { data?: { message?: string } } })?.response?.data
          ?.message ?? '저장에 실패했습니다.';
      message.error(msg);
    } finally {
      setSaving(false);
    }
  };

  const isIOS = version.platform === 'IOS';

  return (
    <Card
      title={
        <Space>
          <Tag color={isIOS ? 'blue' : 'green'}>{version.platform}</Tag>
          <Text>버전 설정</Text>
        </Space>
      }
      extra={
        <Button type="primary" loading={saving} onClick={save}>
          저장
        </Button>
      }
    >
      <Space direction="vertical" size="middle" style={{ width: '100%' }}>
        <Field label="최소 지원 버전 (미달 시 강제 업데이트)">
          <Input
            value={form.minVersion}
            placeholder="1.0.0"
            onChange={(e) => set('minVersion', e.target.value)}
          />
        </Field>
        <Field label="최신 버전 (미달 시 권장 업데이트)">
          <Input
            value={form.latestVersion}
            placeholder="1.0.0"
            onChange={(e) => set('latestVersion', e.target.value)}
          />
        </Field>
        <Field label="최신 빌드 번호">
          <InputNumber
            value={form.latestBuild}
            min={1}
            style={{ width: '100%' }}
            onChange={(v) => set('latestBuild', v ?? 1)}
          />
        </Field>
        <Field label="스토어 URL">
          <Input
            value={form.storeUrl ?? ''}
            placeholder="https://..."
            onChange={(e) => set('storeUrl', e.target.value)}
          />
        </Field>
        <Field label="업데이트 안내 메시지">
          <Input.TextArea
            value={form.updateMessage ?? ''}
            rows={2}
            placeholder="업데이트 안내 문구 (선택)"
            onChange={(e) => set('updateMessage', e.target.value)}
          />
        </Field>

        <ToggleRow
          label="강제 업데이트"
          desc="켜면 현재 버전과 무관하게 모든 사용자에게 차단형 업데이트를 띄웁니다."
          checked={form.forceUpdate ?? false}
          onChange={(v) => set('forceUpdate', v)}
        />
        <ToggleRow
          label="광고 노출"
          desc="끄면 앱에서 광고가 표시되지 않습니다."
          checked={form.showAd ?? false}
          onChange={(v) => set('showAd', v)}
        />
        <ToggleRow
          label="본인인증 우회 (심사 모드)"
          desc="앱 심사용. 켜면 신규 가입 시 KCP 본인인증을 건너뜁니다. 심사 종료 후 반드시 끄세요."
          checked={form.bypassPhoneVerification ?? false}
          onChange={(v) => set('bypassPhoneVerification', v)}
        />

        {form.bypassPhoneVerification && (
          <Alert
            type="warning"
            showIcon
            message="본인인증 우회가 켜져 있습니다 — 심사 기간에만 사용하세요."
          />
        )}
      </Space>
    </Card>
  );
}

function Field({
  label,
  children,
}: {
  label: string;
  children: React.ReactNode;
}) {
  return (
    <div>
      <Text type="secondary" style={{ fontSize: 12, display: 'block', marginBottom: 4 }}>
        {label}
      </Text>
      {children}
    </div>
  );
}

function ToggleRow({
  label,
  desc,
  checked,
  onChange,
}: {
  label: string;
  desc: string;
  checked: boolean;
  onChange: (v: boolean) => void;
}) {
  return (
    <div
      style={{
        display: 'flex',
        alignItems: 'flex-start',
        justifyContent: 'space-between',
        gap: 12,
      }}
    >
      <div style={{ flex: 1 }}>
        <Text strong>{label}</Text>
        <Text type="secondary" style={{ fontSize: 12, display: 'block' }}>
          {desc}
        </Text>
      </div>
      <Switch checked={checked} onChange={onChange} />
    </div>
  );
}
