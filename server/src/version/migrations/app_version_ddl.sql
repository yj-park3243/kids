-- app_version 테이블 (prod 수동 적용용 — dev는 TypeORM synchronize로 자동 생성됨)
-- 적용: psql "$DATABASE_URL" -f app_version_ddl.sql

CREATE TABLE IF NOT EXISTS app_version (
  id                          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  platform                    VARCHAR(10) NOT NULL,
  min_version                 VARCHAR(20) NOT NULL,
  latest_version              VARCHAR(20) NOT NULL,
  latest_build                INT NOT NULL DEFAULT 1,
  force_update                BOOLEAN NOT NULL DEFAULT FALSE,
  update_message              TEXT,
  store_url                   TEXT,
  bypass_phone_verification   BOOLEAN NOT NULL DEFAULT FALSE,
  created_at                  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at                  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 기존 환경에서 컬럼만 추가 (테이블이 이미 있는 경우)
ALTER TABLE app_version
  ADD COLUMN IF NOT EXISTS bypass_phone_verification BOOLEAN NOT NULL DEFAULT FALSE;

-- 초기 시드 (필요 시 수정)
INSERT INTO app_version (platform, min_version, latest_version, latest_build, force_update, store_url)
VALUES
  ('IOS', '1.0.0', '1.0.0', 1, FALSE, 'https://apps.apple.com/app/id0000000000'),
  ('ANDROID', '1.0.0', '1.0.0', 1, FALSE, 'https://play.google.com/store/apps/details?id=kr.kids.app')
ON CONFLICT DO NOTHING;
