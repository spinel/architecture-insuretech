# GraphQL API Documentation для client-info

## Обзор

GraphQL API для сервиса client-info предоставляет гибкий интерфейс для работы с клиентскими данными, устраняя проблемы N+1 запросов и over-fetching, характерные для REST API.

## Основные преимущества

### 1. Устранение N+1 Problem
**Было (REST)**:
```bash
GET /clients/123           # 1 запрос
GET /clients/123/documents # 2 запрос
GET /clients/123/relatives # 3 запрос
```

**Стало (GraphQL)**:
```graphql
query {
  client(id: "123") {
    name
    age
    documents {
      type
      number
      issueDate
    }
    relatives {
      relationType
      name
      age
    }
  }
}
```

### 2. Гибкость запросов
- Выбор только нужных полей
- Контроль глубины запроса
- Возможность запросить связанные данные

### 3. Снижение нагрузки
- Один HTTP-запрос вместо множества
- Передача только необходимых данных
- Оптимизация пропускной способности

## Примеры запросов

### 1. Получение базовой информации о клиенте

**Запрос**:
```graphql
query GetClientBasicInfo($clientId: ID!) {
  client(id: $clientId) {
    id
    name
    age
  }
}
```

**Переменные**:
```json
{
  "clientId": "123"
}
```

**Ответ**:
```json
{
  "data": {
    "client": {
      "id": "123",
      "name": "Иван Петров",
      "age": 35
    }
  }
}
```

### 2. Получение клиента с документами

**Запрос**:
```graphql
query GetClientWithDocuments($clientId: ID!) {
  client(id: $clientId) {
    id
    name
    documents {
      id
      type
      number
      issueDate
      expiryDate
    }
  }
}
```

**Ответ**:
```json
{
  "data": {
    "client": {
      "id": "123",
      "name": "Иван Петров",
      "documents": [
        {
          "id": "doc1",
          "type": "passport",
          "number": "1234 567890",
          "issueDate": "2010-01-15",
          "expiryDate": "2020-01-15"
        },
        {
          "id": "doc2",
          "type": "driver_license",
          "number": "1234567890",
          "issueDate": "2015-03-20",
          "expiryDate": "2025-03-20"
        }
      ]
    }
  }
}
```

### 3. Получение клиента с родственниками

**Запрос**:
```graphql
query GetClientWithRelatives($clientId: ID!) {
  client(id: $clientId) {
    id
    name
    relatives {
      id
      relationType
      name
      age
    }
  }
}
```

**Ответ**:
```json
{
  "data": {
    "client": {
      "id": "123",
      "name": "Иван Петров",
      "relatives": [
        {
          "id": "rel1",
          "relationType": "spouse",
          "name": "Мария Петрова",
          "age": 32
        },
        {
          "id": "rel2",
          "relationType": "child",
          "name": "Алексей Петров",
          "age": 8
        }
      ]
    }
  }
}
```

### 4. Получение полной информации о клиенте

**Запрос**:
```graphql
query GetFullClientInfo($clientId: ID!) {
  client(id: $clientId) {
    id
    name
    age
    createdAt
    updatedAt
    documents {
      id
      type
      number
      issueDate
      expiryDate
      createdAt
    }
    relatives {
      id
      relationType
      name
      age
      createdAt
    }
  }
}
```

### 5. Получение только необходимых полей

**Запрос** (только имена и типы документов):
```graphql
query GetClientMinimalInfo($clientId: ID!) {
  client(id: $clientId) {
    name
    documents {
      type
    }
  }
}
```

**Ответ**:
```json
{
  "data": {
    "client": {
      "name": "Иван Петров",
      "documents": [
        { "type": "passport" },
        { "type": "driver_license" }
      ]
    }
  }
}
```

### 6. Получение списка клиентов

**Запрос**:
```graphql
query GetClientsList($limit: Int, $offset: Int) {
  clients(limit: $limit, offset: $offset) {
    id
    name
    age
  }
}
```

**Переменные**:
```json
{
  "limit": 5,
  "offset": 0
}
```

## Примеры мутаций

### 1. Создание нового клиента

**Запрос**:
```graphql
mutation CreateClient($input: CreateClientInput!) {
  createClient(input: $input) {
    id
    name
    age
    createdAt
  }
}
```

**Переменные**:
```json
{
  "input": {
    "name": "Анна Сидорова",
    "age": 28
  }
}
```

### 2. Добавление документа клиенту

**Запрос**:
```graphql
mutation AddDocument($clientId: ID!, $input: CreateDocumentInput!) {
  addDocument(clientId: $clientId, input: $input) {
    id
    type
    number
    issueDate
    expiryDate
  }
}
```

**Переменные**:
```json
{
  "clientId": "123",
  "input": {
    "type": "passport",
    "number": "9876 543210",
    "issueDate": "2020-05-10",
    "expiryDate": "2030-05-10"
  }
}
```

### 3. Добавление родственника

**Запрос**:
```graphql
mutation AddRelative($clientId: ID!, $input: CreateRelativeInput!) {
  addRelative(clientId: $clientId, input: $input) {
    id
    relationType
    name
    age
  }
}
```

**Переменные**:
```json
{
  "clientId": "123",
  "input": {
    "relationType": "parent",
    "name": "Петр Петров",
    "age": 65
  }
}
```

## Примеры подписок

### 1. Подписка на изменения клиента

**Запрос**:
```graphql
subscription ClientUpdates($clientId: ID!) {
  clientUpdated(clientId: $clientId) {
    id
    name
    age
    updatedAt
  }
}
```

### 2. Подписка на изменения документов

**Запрос**:
```graphql
subscription DocumentsUpdates($clientId: ID!) {
  documentsUpdated(clientId: $clientId) {
    id
    type
    number
    updatedAt
  }
}
```

## Сравнение с REST API

### REST API (3 запроса)
```bash
# Запрос 1: Основная информация
curl -X GET "https://api.client-service.com/v1/clients/123"
# Ответ: {"id": "123", "name": "Иван Петров", "age": 35}

# Запрос 2: Документы
curl -X GET "https://api.client-service.com/v1/clients/123/documents"
# Ответ: [{"id": "doc1", "type": "passport", "number": "1234 567890", ...}]

# Запрос 3: Родственники
curl -X GET "https://api.client-service.com/v1/clients/123/relatives"
# Ответ: [{"id": "rel1", "relationType": "spouse", "name": "Мария Петрова", ...}]
```

### GraphQL API (1 запрос)
```graphql
query {
  client(id: "123") {
    name
    age
    documents {
      type
      number
    }
    relatives {
      relationType
      name
    }
  }
}
```

## Оптимизации

### 1. DataLoader для устранения N+1
```javascript
// Пример реализации DataLoader
const clientLoader = new DataLoader(async (ids) => {
  const clients = await db.clients.findByIds(ids);
  return ids.map(id => clients.find(client => client.id === id));
});

const documentLoader = new DataLoader(async (clientIds) => {
  const documents = await db.documents.findByClientIds(clientIds);
  return clientIds.map(clientId => 
    documents.filter(doc => doc.clientId === clientId)
  );
});
```

### 2. Кэширование запросов
```javascript
// Пример кэширования
const cache = new Map();

const resolveClient = async (id) => {
  if (cache.has(id)) {
    return cache.get(id);
  }
  
  const client = await db.clients.findById(id);
  cache.set(id, client);
  return client;
};
```

### 3. Пагинация для больших списков
```graphql
type ClientConnection {
  edges: [ClientEdge!]!
  pageInfo: PageInfo!
}

type ClientEdge {
  node: Client!
  cursor: String!
}

type PageInfo {
  hasNextPage: Boolean!
  hasPreviousPage: Boolean!
  startCursor: String
  endCursor: String
}
```

## Миграция с REST на GraphQL

### Этап 1: Параллельная работа
- GraphQL API работает параллельно с REST
- Постепенная миграция клиентов

### Этап 2: Обновление клиентов
- Веб-приложение переходит на GraphQL
- core-app переходит на GraphQL

### Этап 3: Отключение REST API
- Полное отключение REST endpoints
- Очистка кода

## Мониторинг и метрики

### Ключевые метрики
- Время выполнения запросов
- Количество запросов в секунду
- Размер ответов
- Частота использования полей

### Алерты
- Превышение времени выполнения > 100ms
- Ошибки в запросах > 1%
- Необычные паттерны запросов

## Заключение

GraphQL API для client-info обеспечивает:
- ✅ Устранение N+1 problem
- ✅ Гибкость в выборе данных
- ✅ Снижение нагрузки на сервер
- ✅ Улучшение производительности
- ✅ Лучший пользовательский опыт
