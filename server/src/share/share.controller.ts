import { Controller, Get, Param } from '@nestjs/common';
import { ApiTags, ApiOperation } from '@nestjs/swagger';
import { ShareService } from './share.service';

@ApiTags('Share')
@Controller('share')
export class ShareController {
  constructor(private shareService: ShareService) {}

  @Get('room/:roomId/preview')
  @ApiOperation({ summary: '방 공유 OG 프리뷰 (인증 불필요)' })
  async getRoomPreview(@Param('roomId') roomId: string) {
    return this.shareService.getRoomPreview(roomId);
  }
}
