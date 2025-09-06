# Проектирование продажи ОСАГО - Техническое решение

## Анализ требований

### Бизнес-требования
- **Пользовательский путь**: Заполнение заявки → Получение предложений от страховых компаний → Выбор предложения
- **Ключевое требование**: Предложения должны отображаться сразу по мере поступления (streaming)
- **Максимальное время ожидания**: 60 секунд на ответ от страховой компании
- **Пиковая нагрузка**: 2,500 одновременных пользователей

### Технические требования
- **API страховых компаний**: REST с двумя эндпоинтами (создать заявку, получить предложение)
- **Архитектурное решение**: Отдельный сервис osago-aggregator
- **Интеграция**: Сохранение подхода из Task 3 (Event-Driven)

## Проектирование osago-aggregator

### 1. Функциональные обязанности
- **Создание заявок**: Отправка заявок во все доступные страховые компании
- **Опрос решений**: Периодический опрос статуса заявок
- **Агрегация результатов**: Сбор и передача предложений в core-app
- **Управление таймаутами**: Контроль 60-секундного лимита

### 2. Хранилище данных
**Решение**: Требуется собственное хранилище данных

**Обоснование**:
- Необходимость хранения состояния заявок (pending, completed, timeout)
- Отслеживание прогресса опроса каждой страховой компании
- Кэширование результатов для повторных запросов
- Аудит и логирование операций

**Структура данных**:
```sql
-- Таблица заявок ОСАГО
osago_applications (
    id UUID PRIMARY KEY,
    client_id UUID,
    vehicle_data JSON,
    status ENUM('pending', 'processing', 'completed', 'timeout'),
    created_at TIMESTAMP,
    completed_at TIMESTAMP,
    timeout_at TIMESTAMP
);

-- Таблица предложений от страховых компаний
osago_offers (
    id UUID PRIMARY KEY,
    application_id UUID,
    company_id VARCHAR,
    offer_data JSON,
    status ENUM('pending', 'received', 'timeout'),
    created_at TIMESTAMP,
    received_at TIMESTAMP
);

-- Outbox таблица для событий
osago_outbox (
    id UUID PRIMARY KEY,
    event_type VARCHAR,
    event_data JSON,
    created_at TIMESTAMP,
    processed_at TIMESTAMP
);
```

### 3. API для core-app

**REST API Endpoints**:

```yaml
# Создание заявки на ОСАГО
POST /api/v1/osago/applications
Request:
{
  "client_id": "uuid",
  "vehicle_data": {
    "vin": "string",
    "license_plate": "string",
    "brand": "string",
    "model": "string",
    "year": "number",
    "engine_power": "number"
  }
}
Response:
{
  "application_id": "uuid",
  "status": "pending",
  "estimated_completion_time": "2024-01-01T12:05:00Z"
}

# Получение статуса заявки
GET /api/v1/osago/applications/{application_id}
Response:
{
  "application_id": "uuid",
  "status": "processing",
  "offers_received": 3,
  "total_companies": 10,
  "offers": [
    {
      "company_id": "company1",
      "premium": 15000,
      "coverage": "full",
      "received_at": "2024-01-01T12:02:30Z"
    }
  ]
}

# WebSocket для real-time обновлений
WS /api/v1/osago/applications/{application_id}/stream
Messages:
{
  "type": "offer_received",
  "data": {
    "company_id": "company1",
    "offer": {...}
  }
}
```

## Средства интеграции

### 1. core-app ↔ osago-aggregator

**Решение**: REST API + WebSocket

**Обоснование**:
- **REST API**: Для создания заявок и получения финального статуса
- **WebSocket**: Для real-time streaming предложений по мере поступления
- **Event-Driven**: Дополнительно через Kafka для асинхронной обработки

**Паттерны отказоустойчивости**:
- **Circuit Breaker**: Защита от каскадных сбоев
- **Retry**: Повторные попытки при временных сбоях
- **Timeout**: 60-секундный лимит на получение предложений
- **Rate Limiting**: Ограничение нагрузки на страховые компании

### 2. Веб-приложение ↔ core-app

**Решение**: REST API + Server-Sent Events (SSE)

**Обоснование**:
- **REST API**: Для создания заявок и получения базовой информации
- **Server-Sent Events**: Для real-time обновлений предложений
- **Альтернатива WebSocket**: SSE проще в реализации для односторонней передачи

**API для веб-приложения**:

```yaml
# Создание заявки на ОСАГО
POST /api/v1/osago/quote
Request:
{
  "vehicle": {
    "vin": "string",
    "license_plate": "string",
    "brand": "string",
    "model": "string",
    "year": "number",
    "engine_power": "number"
  },
  "driver": {
    "license_number": "string",
    "experience_years": "number"
  }
}
Response:
{
  "quote_id": "uuid",
  "status": "processing",
  "stream_url": "/api/v1/osago/quotes/{quote_id}/stream"
}

# Server-Sent Events для real-time обновлений
GET /api/v1/osago/quotes/{quote_id}/stream
Content-Type: text/event-stream

data: {"type": "offer_received", "company": "company1", "premium": 15000}
data: {"type": "offer_received", "company": "company2", "premium": 14500}
data: {"type": "completed", "total_offers": 8}
```

## Паттерны отказоустойчивости

### 1. Rate Limiting
**Применение**: 
- osago-aggregator → страховые компании
- core-app → osago-aggregator

**Настройки**:
- 100 RPS на страховую компанию
- 50 RPS от core-app к osago-aggregator
- 10 RPS от веб-приложения к core-app

### 2. Circuit Breaker
**Применение**:
- osago-aggregator → страховые компании
- core-app → osago-aggregator

**Настройки**:
- Failure threshold: 50%
- Recovery timeout: 30 секунд
- Half-open max calls: 5

### 3. Retry
**Применение**:
- osago-aggregator → страховые компании
- core-app → osago-aggregator

**Настройки**:
- Max attempts: 3
- Backoff strategy: exponential (1s, 2s, 4s)
- Retryable errors: 5xx, timeout

### 4. Timeout
**Применение**:
- osago-aggregator → страховые компании (60 секунд)
- core-app → osago-aggregator (30 секунд)
- Веб-приложение → core-app (10 секунд)

## Архитектурные решения

### 1. Масштабирование
**osago-aggregator**:
- Горизонтальное масштабирование: 5-10 реплик
- Вертикальное масштабирование: 2 CPU, 4GB RAM
- Автоматическое масштабирование на основе нагрузки

**core-app**:
- Увеличение реплик до 10-15 при пиковой нагрузке
- Отдельные реплики для ОСАГО операций

### 2. Кэширование
**Redis Cache**:
- Кэширование результатов по VIN номеру (TTL: 1 час)
- Кэширование статуса страховых компаний
- Кэширование тарифов ОСАГО

### 3. Мониторинг
**Метрики**:
- Время ответа страховых компаний
- Количество успешных/неуспешных запросов
- Количество активных заявок
- Использование WebSocket соединений

**Алерты**:
- Превышение времени ответа > 45 секунд
- Failure rate > 20%
- Количество активных заявок > 2000

## Поток обработки заявки

### 1. Создание заявки
```
1. Пользователь заполняет форму на веб-приложении
2. Веб-приложение → core-app (POST /api/v1/osago/quote)
3. core-app → osago-aggregator (POST /api/v1/osago/applications)
4. osago-aggregator создает заявку в БД
5. osago-aggregator отправляет заявки во все страховые компании (параллельно)
6. Возврат quote_id пользователю
```

### 2. Обработка предложений
```
1. osago-aggregator периодически опрашивает статус заявок
2. При получении предложения:
   - Сохранение в БД
   - Публикация события в Kafka
   - Отправка через WebSocket в core-app
3. core-app → веб-приложение (SSE)
4. Веб-приложение отображает предложение пользователю
```

### 3. Завершение заявки
```
1. По истечении 60 секунд или получении всех ответов
2. osago-aggregator помечает заявку как completed
3. Публикация финального события
4. Уведомление пользователя о завершении
```

## Преимущества решения

### 1. Производительность
- Параллельная обработка заявок во всех страховых компаниях
- Real-time отображение предложений
- Кэширование для повторных запросов

### 2. Отказоустойчивость
- Circuit Breaker защищает от каскадных сбоев
- Retry механизмы для временных сбоев
- Graceful degradation при недоступности части компаний

### 3. Масштабируемость
- Горизонтальное масштабирование всех компонентов
- Автоматическое масштабирование при пиковой нагрузке
- Изоляция нагрузки между пользователями

### 4. Пользовательский опыт
- Мгновенное отображение предложений
- Прозрачность процесса обработки
- Надежность при высоких нагрузках

## Заключение

Предложенное решение обеспечивает:
- Обработку 2,500 одновременных пользователей
- Real-time отображение предложений
- Высокую отказоустойчивость
- Масштабируемость при росте нагрузки
- Соответствие бизнес-требованиям по времени ответа
