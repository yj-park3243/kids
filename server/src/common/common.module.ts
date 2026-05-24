import { Global, Module } from '@nestjs/common';
import { TelegramService } from './services/telegram.service';
import { GeocodingService } from './services/geocoding.service';
import { ProfanityFilterService } from './services/profanity-filter.service';

@Global()
@Module({
  providers: [TelegramService, GeocodingService, ProfanityFilterService],
  exports: [TelegramService, GeocodingService, ProfanityFilterService],
})
export class CommonModule {}
