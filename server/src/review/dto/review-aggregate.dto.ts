import { ApiProperty } from '@nestjs/swagger';

export class TagCountDto {
  @ApiProperty()
  tag: string;

  @ApiProperty()
  count: number;
}

export class ReviewAggregateDto {
  @ApiProperty({ example: 37.2 })
  mannerScore: number;

  @ApiProperty({ example: 12 })
  reviewCount: number;

  @ApiProperty({ example: { '5': 8, '4': 3, '3': 1, '2': 0, '1': 0 } })
  scoreDistribution: Record<string, number>;

  @ApiProperty({ type: [TagCountDto] })
  topTags: TagCountDto[];
}
