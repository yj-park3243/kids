import {
  Controller,
  Get,
  Post,
  Patch,
  Delete,
  Body,
  Param,
  UseGuards,
} from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation } from '@nestjs/swagger';
import { ChildService } from './child.service';
import { CreateChildDto } from './dto/create-child.dto';
import { UpdateChildDto } from './dto/update-child.dto';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';

@ApiTags('Children')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('children')
export class ChildController {
  constructor(private childService: ChildService) {}

  @Post()
  @ApiOperation({ summary: '아이 등록' })
  async create(
    @CurrentUser('id') userId: string,
    @Body() dto: CreateChildDto,
  ) {
    return this.childService.create(userId, dto);
  }

  @Get()
  @ApiOperation({ summary: '내 아이 목록 조회' })
  async findAll(@CurrentUser('id') userId: string) {
    return this.childService.findAll(userId);
  }

  @Patch(':childId')
  @ApiOperation({ summary: '아이 정보 수정' })
  async update(
    @CurrentUser('id') userId: string,
    @Param('childId') childId: string,
    @Body() dto: UpdateChildDto,
  ) {
    return this.childService.update(userId, childId, dto);
  }

  @Delete(':childId')
  @ApiOperation({ summary: '아이 정보 삭제' })
  async delete(
    @CurrentUser('id') userId: string,
    @Param('childId') childId: string,
  ) {
    return this.childService.delete(userId, childId);
  }
}
