import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  Unique,
  Index,
} from 'typeorm';

@Entity('room_photo_child_tag')
@Unique(['photoId', 'childId'])
export class RoomPhotoChildTag {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'photo_id', type: 'uuid' })
  @Index()
  photoId: string;

  @Column({ name: 'child_id', type: 'uuid' })
  @Index()
  childId: string;
}
