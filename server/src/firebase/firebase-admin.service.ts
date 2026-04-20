import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as admin from 'firebase-admin';

@Injectable()
export class FirebaseAdminService implements OnModuleInit {
  private readonly logger = new Logger(FirebaseAdminService.name);
  private app: admin.app.App | null = null;

  constructor(private configService: ConfigService) {}

  onModuleInit() {
    const projectId = this.configService.get('FIREBASE_PROJECT_ID');
    const clientEmail = this.configService.get('FIREBASE_CLIENT_EMAIL');
    const privateKey = this.configService.get('FIREBASE_PRIVATE_KEY');

    if (!projectId || !clientEmail || !privateKey) {
      this.logger.warn(
        'Firebase credentials not configured. Firebase features will be disabled.',
      );
      return;
    }

    try {
      this.app = admin.initializeApp({
        credential: admin.credential.cert({
          projectId,
          clientEmail,
          privateKey: privateKey.replace(/\\n/g, '\n'),
        }),
        storageBucket: this.configService.get('FIREBASE_STORAGE_BUCKET'),
      });
      this.logger.log('Firebase Admin SDK initialized successfully');
    } catch (error) {
      this.logger.error('Failed to initialize Firebase Admin SDK', error);
    }
  }

  /**
   * FCM 푸시 발송용. Firestore/Storage는 사용하지 않는다 (이미지 = S3, 채팅 = PostgreSQL+WebSocket).
   */
  getMessaging(): admin.messaging.Messaging | null {
    if (!this.app) return null;
    return this.app.messaging();
  }
}
