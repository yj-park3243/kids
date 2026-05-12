import {
  Body,
  Controller,
  Param,
  Post,
  UseGuards,
} from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiOperation,
  ApiProperty,
  ApiTags,
} from '@nestjs/swagger';
import {
  IsArray,
  IsBoolean,
  IsString,
  ValidateNested,
} from 'class-validator';
import { Type } from 'class-transformer';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { RoomAttendanceService } from './room-attendance.service';

class AttendanceRecordDto {
  @ApiProperty()
  @IsString()
  userId: string;

  @ApiProperty()
  @IsBoolean()
  attended: boolean;
}

class AttendanceBodyDto {
  @ApiProperty({ type: [AttendanceRecordDto] })
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => AttendanceRecordDto)
  records: AttendanceRecordDto[];
}

@ApiTags('Rooms')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('rooms')
export class RoomAttendanceController {
  constructor(private attendanceService: RoomAttendanceService) {}

  @Post(':roomId/attendance')
  @ApiOperation({ summary: '출석 체크 (방장)' })
  async submit(
    @CurrentUser('id') hostUserId: string,
    @Param('roomId') roomId: string,
    @Body() body: AttendanceBodyDto,
  ) {
    return this.attendanceService.submitAttendance(hostUserId, roomId, body.records);
  }
}
