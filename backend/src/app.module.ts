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
      synchronize: true, // 임시로 프로덕션에서도 테이블 생성 허용
      logging: process.env.NODE_ENV !== 'production',
      // SSL 설정 추가
      ssl: {
        rejectUnauthorized: false,
      },
      // 연결 설정 추가
      connectTimeoutMS: 30000, // 30초
      extra: {
        connectionTimeoutMillis: 30000,
        query_timeout: 30000,
        statement_timeout: 30000,
        ssl: {
          rejectUnauthorized: false,
        },
      },
      // 재시도 설정
      retryAttempts: 10,
      retryDelay: 3000, // 3초
    }),
    MessagesModule,
  ],
})
export class AppModule {}
