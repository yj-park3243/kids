import {
  Controller,
  Get,
  Post,
  Delete,
  Body,
  Param,
  UseGuards,
} from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation } from '@nestjs/swagger';
import { BlockService } from './block.service';
import { CreateBlockDto } from './dto/create-block.dto';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';

@ApiTags('Blocks')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('blocks')
export class BlockController {
  constructor(private blockService: BlockService) {}

  @Post()
  @ApiOperation({ summary: '유저 차단' })
  async block(
    @CurrentUser('id') userId: string,
    @Body() dto: CreateBlockDto,
  ) {
    return this.blockService.block(userId, dto.targetUserId);
  }

  @Delete(':targetUserId')
  @ApiOperation({ summary: '차단 해제' })
  async unblock(
    @CurrentUser('id') userId: string,
    @Param('targetUserId') targetUserId: string,
  ) {
    return this.blockService.unblock(userId, targetUserId);
  }

  @Get()
  @ApiOperation({ summary: '내 차단 목록' })
  async getMyBlocks(@CurrentUser('id') userId: string) {
    return this.blockService.getMyBlocks(userId);
  }
}
