import { DataSource } from 'typeorm';
import * as dotenv from 'dotenv';

dotenv.config();

export default new DataSource({
  type: 'postgres',
  host: process.env.DB_HOST || 'localhost',
  port: parseInt(process.env.DB_PORT || '5432'),
  username: process.env.DB_USER || 'kids',
  password: process.env.DB_PASSWORD || 'kids1234',
  database: process.env.DB_NAME || 'kids',
  entities: [__dirname + '/../**/*.entity{.ts,.js}'],
  migrations: [__dirname + '/../migrations/*{.ts,.js}'],
  // TODO: production에서는 false로. 현재는 개발 단계라 true.
  synchronize: true,
});
