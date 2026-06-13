<!--
  Default template — แก้ per-project ได้โดย copy ไป `templates/tech-spec.md` (lookup priority สูงกว่า)
-->

---
tags: [type/tech-spec]
status: draft
version: 0.1.0
date: <YYYY-MM-DD>
prd: "[[PRD-<slug>]]"
srs: "[[SRS-<slug>]]"
---

# Tech Spec — <Product / Feature>

## 1. Tech stack

| Layer | Choice | Why |
|---|---|---|
| Frontend | <e.g. React + Tailwind> | <reason> |
| Backend | <e.g. .NET 8 Web API> | <reason> |
| Mobile | <e.g. Flutter> | <reason> |
| Database | <e.g. PostgreSQL> | <reason> |
| Cache | <e.g. Redis> | <reason> |
| Message bus | <e.g. RabbitMQ> | <reason> |
| Auth | <e.g. JWT + RBAC> | <reason> |
| Hosting | <e.g. cloud app service> | <reason> |

## 2. Architecture

```mermaid
graph TD
  U[User] --> W[Web Frontend]
  U --> M[Mobile App]
  W --> A[API Gateway]
  M --> A
  A --> S1[Service 1]
  A --> S2[Service 2]
  S1 --> DB[(Database)]
  S2 --> DB
  S1 --> C[(Cache)]
```

## 3. Data model

### Entity: <name>

| Field | Type | Constraints | Note |
|---|---|---|---|
| id | uuid | PK | |
| <field> | <type> | <constraints> | |

Relationships:
- <entity A> 1—N <entity B>

## 4. API contracts (high-level)

### <METHOD> /<resource>

- Auth: <required role>
- Request: <schema>
- Response: <schema>
- Errors: <list>

(รายละเอียด contract เต็มอยู่ที่ [[REF-APIIntegration]])

## 5. Auth & RBAC

- AuthN: <method>
- AuthZ: <RBAC model>
- Roles: <list — ดู [[REF-AuthorizationMatrix]]>

## 6. Deployment

- Environments: dev / staging / production
- CI/CD: <pipeline>
- Migration strategy: <approach>
- Rollback strategy: <approach>

## 7. Observability

- Logging: <stack, format>
- Metrics: <stack>
- Tracing: <stack>
- Alerting: <channels>

## 8. Security

- Encryption at rest: <details>
- Encryption in transit: <details>
- Secret management: <details>
- Audit log: <approach>

## 9. Decisions (ADR refs)

- [[ADR-0001-<slug>]]
- [[ADR-0002-<slug>]]
