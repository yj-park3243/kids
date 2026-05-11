-- 방 사진첩 테이블 (prod 수동 적용용 — dev 는 TypeORM synchronize 로 자동)
-- 적용: psql "$DATABASE_URL" -f room_photo_ddl.sql

CREATE TABLE IF NOT EXISTS room_photo (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id           UUID NOT NULL REFERENCES room(id) ON DELETE CASCADE,
  uploader_id       UUID REFERENCES "user"(id) ON DELETE SET NULL,
  uploader_nickname VARCHAR(40) NOT NULL,
  url               TEXT NOT NULL,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_room_photo_room ON room_photo(room_id);
CREATE INDEX IF NOT EXISTS idx_room_photo_created ON room_photo(created_at);

CREATE TABLE IF NOT EXISTS room_photo_child_tag (
  id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  photo_id  UUID NOT NULL REFERENCES room_photo(id) ON DELETE CASCADE,
  child_id  UUID NOT NULL REFERENCES child(id) ON DELETE CASCADE,
  UNIQUE (photo_id, child_id)
);
CREATE INDEX IF NOT EXISTS idx_rpct_photo ON room_photo_child_tag(photo_id);
CREATE INDEX IF NOT EXISTS idx_rpct_child ON room_photo_child_tag(child_id);

CREATE TABLE IF NOT EXISTS room_photo_comment (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  photo_id      UUID NOT NULL REFERENCES room_photo(id) ON DELETE CASCADE,
  user_id       UUID REFERENCES "user"(id) ON DELETE SET NULL,
  user_nickname VARCHAR(40) NOT NULL,
  content       TEXT NOT NULL,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_rpc_photo ON room_photo_comment(photo_id);
