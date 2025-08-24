import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { MessagesModule } from './messages/messages.module';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
    }),
    TypeOrmModule.forRoot({
      type: 'postgres',
      host: process.env.DB_HOST || 'localhost',
      port: parseInt(process.env.DB_PORT) || 5432,
      username: process.env.DB_USERNAME || 'postgres',
      password: process.env.DB_PASSWORD || 'password',
      database: process.env.DB_NAME || 'cicd_demo',
      entities: [__dirname + '/**/*.entity{.ts,.js}'],
      synchronize: process.env.NODE_ENV !== 'production', // 프로덕션에서는 false로 설정
      logging: process.env.NODE_ENV !== 'production',
      // SSL 설정 (AWS RDS용)
      ssl: process.env.NODE_ENV === 'production' ? {
        rejectUnauthorized: false,
      } : false,
      // 연결 설정
      connectTimeoutMS: 30000,
      extra: {
        connectionTimeoutMillis: 30000,
        query_timeout: 30000,
        statement_timeout: 30000,
        ssl: process.env.NODE_ENV === 'production' ? {
          rejectUnauthorized: false,
        } : false,
      },
      // 재시도 설정
      retryAttempts: 10,
      retryDelay: 3000,
    }),
    MessagesModule,
  ],
})
export class AppModule {}
