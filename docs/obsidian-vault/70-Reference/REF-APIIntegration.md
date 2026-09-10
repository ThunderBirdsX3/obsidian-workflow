---
tags: [type/reference]
date: 2026-05-15
---

# REF — API Integration

## Base URL

- Dev: `http://localhost:5000/api`
- Staging: `https://lbt-staging.example.com/api`
- Production: `https://lbt.example.com/api`

## Authentication

- All endpoints (except `/auth/*`) require `Authorization: Bearer <jwt>`
- JWT issued at `POST /auth/login` (response includes refresh token)
- Refresh: `POST /auth/refresh`
- JWT lifetime: 1 hour
- Refresh lifetime: 14 days

## Endpoints

### Auth
- `POST /auth/login` → `{token, refresh, role}`
- `POST /auth/refresh` → `{token, refresh}`
- `POST /auth/logout`

### Members
- `GET /members?q=&status=&limit=` → see [[FN-API-Members-Search]]
- `GET /members/{id}` → member detail
- `POST /members` → create (Librarian only)
- `PATCH /members/{id}` → update

### Books
- `GET /books?q=&status=&limit=`
- `GET /books/{id}` → book detail with current loan if any
- `POST /books` → create (Librarian)

### Loans
- `GET /loans?member_id=&status=&limit=` → see [[FN-API-Books-Checkout]] for create
- `GET /loans/{id}`
- `POST /loans` → create checkout (see [[FN-API-Books-Checkout]])
- `PATCH /loans/{id}/return` → close loan (Phase 1.5)

## Error format

```json
{
  "error_code": "MEMBER_INACTIVE",
  "message": "สมาชิกถูกระงับการใช้งาน",
  "details": {
    "member_id": "..."
  }
}
```

## Error codes

- `MEMBER_NOT_FOUND`, `MEMBER_INACTIVE`, `MEMBER_OVER_LOAN_LIMIT`
- `BOOK_NOT_FOUND`, `BOOK_ON_LOAN`, `BOOK_LOST`
- `LOAN_NOT_FOUND`
- `AUTH_INVALID`, `AUTH_EXPIRED`, `AUTH_INSUFFICIENT_ROLE`
- `VALIDATION_ERROR` (with `details.errors[]`)

## Pagination

Query: `?limit=20&offset=0`
Response: `{items: [...], total: N}`

## Rate limiting

- 100 req/min per JWT (returns 429)
- 20 req/min on `/auth/*` per IP
