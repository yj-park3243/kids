import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';

import { RoomMember } from '../room/entities/room-member.entity';
import { UploadModule } from '../upload/upload.module';
import { User } from '../user/entities/user.entity';
import { RoomPhoto } from './entities/room-photo.entity';
import { RoomPhotoChildTag } from './entities/room-photo-child-tag.entity';
import { RoomPhotoComment } from './entities/room-photo-comment.entity';
import { RoomPhotoController } from './room-photo.controller';
import { RoomPhotoService } from './room-photo.service';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      RoomPhoto,
      RoomPhotoChildTag,
      RoomPhotoComment,
      RoomMember,
      User,
    ]),
    UploadModule,
  ],
  controllers: [RoomPhotoController],
  providers: [RoomPhotoService],
})
export class RoomPhotoModule {}
