import { Global, Module } from '@nestjs/common';
import { TelegramService } from './services/telegram.service';
import { GeocodingService } from './services/geocoding.service';

@Global()
@Module({
  providers: [TelegramService, GeocodingService],
  exports: [TelegramService, GeocodingService],
})
export class CommonModule {}
