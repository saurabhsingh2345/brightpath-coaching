import { Logger, ValidationPipe } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { NestFactory } from '@nestjs/core';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import helmet from 'helmet';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule, { bufferLogs: true });
  const config = app.get(ConfigService);
  const logger = new Logger('Bootstrap');

  const prefix = config.get<string>('API_PREFIX') ?? 'api';
  app.setGlobalPrefix(prefix, { exclude: ['health'] });

  // crossOriginResourcePolicy off so the mobile app can fetch /files/*.
  app.use(
    helmet({
      crossOriginResourcePolicy: false,
      contentSecurityPolicy: false,
    }),
  );

  const origins = (config.get<string>('CORS_ORIGINS') ?? '*').trim();
  app.enableCors({
    origin: origins === '*' ? true : origins.split(',').map((o) => o.trim()),
    methods: ['GET', 'POST', 'PATCH', 'PUT', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization'],
    credentials: true,
  });

  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: false,
      transform: true,
      transformOptions: { enableImplicitConversion: false },
    }),
  );

  const swagger = new DocumentBuilder()
    .setTitle('BrightPath Coaching API')
    .setDescription(
      'REST API powering the BrightPath Coaching mobile app (ADMIN + STUDENT).',
    )
    .setVersion('1.0')
    .addBearerAuth()
    .build();
  SwaggerModule.setup(
    'docs',
    app,
    SwaggerModule.createDocument(app, swagger),
    { swaggerOptions: { persistAuthorization: true } },
  );

  const port = Number(config.get<string>('PORT') ?? 3000);
  await app.listen(port, '0.0.0.0');

  logger.log(`API      -> http://localhost:${port}/${prefix}`);
  logger.log(`Docs     -> http://localhost:${port}/docs`);
  logger.log(`Health   -> http://localhost:${port}/health`);
  logger.log(`Files    -> http://localhost:${port}/files`);
}

bootstrap();
