import { useEffect, useMemo, useState } from 'react';
import {
  Button,
  Card,
  Col,
  Empty,
  Input,
  List,
  Popconfirm,
  Row,
  Space,
  Spin,
  Tag,
  Typography,
  message,
} from 'antd';
import { DeleteOutlined, SaveOutlined } from '@ant-design/icons';
import MDEditor from '@uiw/react-md-editor';
import { guidesApi } from '../api/guides';
import type { Guide, GuideListItem } from '../types';

const { Title, Text } = Typography;

const MONTHS = Array.from({ length: 73 }, (_, i) => i); // 0..72

interface FormState {
  ageMonth: number;
  title: string;
  summary: string;
  bodyMarkdown: string;
  coverImage: string;
  tags: string[];
  exists: boolean;
}

const emptyForm = (ageMonth: number): FormState => ({
  ageMonth,
  title: '',
  summary: '',
  bodyMarkdown: '',
  coverImage: '',
  tags: [],
  exists: false,
});

export default function GuidesPage() {
  const [list, setList] = useState<GuideListItem[]>([]);
  const [listLoading, setListLoading] = useState(false);
  const [selected, setSelected] = useState<number>(0);
  const [form, setForm] = useState<FormState>(emptyForm(0));
  const [formLoading, setFormLoading] = useState(false);
  const [saving, setSaving] = useState(false);
  const [tagInput, setTagInput] = useState('');

  const existsMap = useMemo(() => {
    const m = new Set<number>();
    list.forEach((g) => m.add(g.ageMonth));
    return m;
  }, [list]);

  useEffect(() => {
    fetchList();
  }, []);

  useEffect(() => {
    loadGuide(selected);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [selected]);

  const fetchList = async () => {
    try {
      setListLoading(true);
      const res = await guidesApi.getGuides();
      setList(res || []);
    } catch {
      message.error('가이드 목록을 불러올 수 없습니다.');
    } finally {
      setListLoading(false);
    }
  };

  const loadGuide = async (ageMonth: number) => {
    try {
      setFormLoading(true);
      const guide = await guidesApi.getGuide(ageMonth);
      setForm({
        ageMonth,
        title: guide.title || '',
        summary: guide.summary || '',
        bodyMarkdown: guide.bodyMarkdown || '',
        coverImage: guide.coverImage || '',
        tags: guide.tags || [],
        exists: true,
      });
    } catch {
      setForm(emptyForm(ageMonth));
    } finally {
      setFormLoading(false);
    }
  };

  const handleSave = async () => {
    if (!form.title.trim()) {
      message.warning('제목을 입력하세요.');
      return;
    }
    try {
      setSaving(true);
      const payload = {
        ageMonth: form.ageMonth,
        title: form.title,
        summary: form.summary,
        bodyMarkdown: form.bodyMarkdown,
        coverImage: form.coverImage || null,
        tags: form.tags,
      };
      if (form.exists) {
        await guidesApi.updateGuide(form.ageMonth, payload);
        message.success('가이드를 수정했습니다.');
      } else {
        await guidesApi.createGuide(payload);
        message.success('가이드를 등록했습니다.');
      }
      await fetchList();
      await loadGuide(form.ageMonth);
    } catch {
      message.error('저장 중 오류가 발생했습니다.');
    } finally {
      setSaving(false);
    }
  };

  const handleDelete = async () => {
    try {
      setSaving(true);
      await guidesApi.deleteGuide(form.ageMonth);
      message.success('가이드를 삭제했습니다.');
      await fetchList();
      setForm(emptyForm(form.ageMonth));
    } catch {
      message.error('삭제 중 오류가 발생했습니다.');
    } finally {
      setSaving(false);
    }
  };

  const addTag = () => {
    const t = tagInput.trim();
    if (!t) return;
    if (form.tags.includes(t)) {
      setTagInput('');
      return;
    }
    setForm({ ...form, tags: [...form.tags, t] });
    setTagInput('');
  };

  const removeTag = (t: string) => {
    setForm({ ...form, tags: form.tags.filter((x) => x !== t) });
  };

  return (
    <div>
      <Title level={4} style={{ marginBottom: 24 }}>
        발달 가이드
      </Title>

      <Row gutter={16}>
        <Col xs={24} md={8} lg={6}>
          <Card title="개월 (0~72)" size="small" loading={listLoading}>
            <div style={{ maxHeight: 600, overflowY: 'auto' }}>
              <List
                size="small"
                dataSource={MONTHS}
                renderItem={(m) => {
                  const has = existsMap.has(m);
                  const active = m === selected;
                  return (
                    <List.Item
                      onClick={() => setSelected(m)}
                      style={{
                        cursor: 'pointer',
                        background: active ? '#FFF1F0' : undefined,
                        padding: '8px 12px',
                      }}
                    >
                      <Space>
                        <Text>{has ? '✓' : '○'}</Text>
                        <Text strong={active}>{m}개월</Text>
                      </Space>
                    </List.Item>
                  );
                }}
              />
            </div>
          </Card>
        </Col>

        <Col xs={24} md={16} lg={18}>
          <Card
            title={`${form.ageMonth}개월 가이드 ${form.exists ? '(등록됨)' : '(미등록)'}`}
            extra={
              <Space>
                <Button
                  type="primary"
                  icon={<SaveOutlined />}
                  loading={saving}
                  onClick={handleSave}
                >
                  저장
                </Button>
                {form.exists && (
                  <Popconfirm
                    title="가이드를 삭제하시겠습니까?"
                    onConfirm={handleDelete}
                    okText="삭제"
                    cancelText="취소"
                    okButtonProps={{ danger: true }}
                  >
                    <Button danger icon={<DeleteOutlined />} loading={saving}>
                      삭제
                    </Button>
                  </Popconfirm>
                )}
              </Space>
            }
          >
            {formLoading ? (
              <div style={{ textAlign: 'center', padding: 40 }}>
                <Spin />
              </div>
            ) : (
              <Space direction="vertical" size="middle" style={{ width: '100%' }}>
                <div>
                  <div style={{ marginBottom: 8 }}>제목</div>
                  <Input
                    value={form.title}
                    onChange={(e) => setForm({ ...form, title: e.target.value })}
                    placeholder="가이드 제목"
                  />
                </div>
                <div>
                  <div style={{ marginBottom: 8 }}>요약</div>
                  <Input.TextArea
                    rows={2}
                    value={form.summary}
                    onChange={(e) => setForm({ ...form, summary: e.target.value })}
                    placeholder="짧은 요약"
                  />
                </div>
                <div>
                  <div style={{ marginBottom: 8 }}>본문 (Markdown)</div>
                  <div data-color-mode="light">
                    <MDEditor
                      value={form.bodyMarkdown}
                      onChange={(v) => setForm({ ...form, bodyMarkdown: v || '' })}
                      height={400}
                    />
                  </div>
                </div>
                <div>
                  <div style={{ marginBottom: 8 }}>커버 이미지 URL</div>
                  <Input
                    value={form.coverImage}
                    onChange={(e) => setForm({ ...form, coverImage: e.target.value })}
                    placeholder="https://..."
                  />
                  {/* TODO: 이미지 직접 업로드 지원 */}
                </div>
                <div>
                  <div style={{ marginBottom: 8 }}>태그</div>
                  <Space wrap>
                    {form.tags.map((t) => (
                      <Tag key={t} closable onClose={() => removeTag(t)}>
                        {t}
                      </Tag>
                    ))}
                    <Input
                      value={tagInput}
                      onChange={(e) => setTagInput(e.target.value)}
                      onPressEnter={addTag}
                      onBlur={addTag}
                      placeholder="태그 입력 후 Enter"
                      style={{ width: 160 }}
                    />
                  </Space>
                  {form.tags.length === 0 && (
                    <div style={{ marginTop: 8 }}>
                      <Empty
                        image={Empty.PRESENTED_IMAGE_SIMPLE}
                        description="태그 없음"
                        style={{ margin: 0 }}
                      />
                    </div>
                  )}
                </div>
              </Space>
            )}
          </Card>
        </Col>
      </Row>
    </div>
  );
}
