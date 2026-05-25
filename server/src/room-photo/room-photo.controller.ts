import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Query,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';

import { CurrentUser } from '../common/decorators/current-user.decorator';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import {
  CreatePhotoCommentDto,
  PhotoQueryDto,
  UpdatePhotoTagsDto,
} from './dto/room-photo.dto';
import { RoomPhotoService } from './room-photo.service';

@ApiTags('Room Photo')
@Controller()
@UseGuards(JwtAuthGuard)
@ApiBearerAuth()
export class RoomPhotoController {
  constructor(private readonly photoService: RoomPhotoService) {}

  // ─── 사진 ────────────────────────────────────────────────────────

  @Post('rooms/:roomId/photos')
  @ApiOperation({ summary: '방 사진 업로드 (multipart, 1장)' })
  @UseInterceptors(
    FileInterceptor('image', {
      limits: { fileSize: 20 * 1024 * 1024 }, // 20MB — 클라이언트가 2048px/85q로 압축해 올려도 여유분
    }),
  )
  async upload(
    @Param('roomId') roomId: string,
    @CurrentUser('id') userId: string,
    @UploadedFile() file: Express.Multer.File,
  ) {
    return this.photoService.upload(roomId, userId, file);
  }

  @Get('rooms/:roomId/photos')
  @ApiOperation({ summary: '방 사진 목록 (페이징 + 태그 필터)' })
  async list(
    @Param('roomId') roomId: string,
    @CurrentUser('id') userId: string,
    @Query() query: PhotoQueryDto,
  ) {
    return this.photoService.list(roomId, userId, query);
  }

  @Get('photos/:id')
  @ApiOperation({ summary: '사진 상세' })
  async getOne(@Param('id') id: string, @CurrentUser('id') userId: string) {
    return this.photoService.getOne(id, userId);
  }

  @Delete('photos/:id')
  @ApiOperation({ summary: '사진 삭제 (업로더만)' })
  async delete(@Param('id') id: string, @CurrentUser('id') userId: string) {
    return this.photoService.delete(id, userId);
  }

  // ─── 태그 ────────────────────────────────────────────────────────

  @Patch('photos/:id/tags')
  @ApiOperation({ summary: '사진 태그 변경 (방 멤버 누구든)' })
  async updateTags(
    @Param('id') id: string,
    @CurrentUser('id') userId: string,
    @Body() dto: UpdatePhotoTagsDto,
  ) {
    return this.photoService.updateTags(id, userId, dto);
  }

  // ─── 댓글 ────────────────────────────────────────────────────────

  @Get('photos/:id/comments')
  @ApiOperation({ summary: '사진 댓글 목록' })
  async listComments(
    @Param('id') id: string,
    @CurrentUser('id') userId: string,
  ) {
    return this.photoService.listComments(id, userId);
  }

  @Post('photos/:id/comments')
  @ApiOperation({ summary: '사진 댓글 작성' })
  async addComment(
    @Param('id') id: string,
    @CurrentUser('id') userId: string,
    @Body() dto: CreatePhotoCommentDto,
  ) {
    return this.photoService.addComment(id, userId, dto);
  }
}
