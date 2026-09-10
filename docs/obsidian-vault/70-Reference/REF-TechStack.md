---
tags: [type/reference]
date: 2026-05-15
---

# REF — Tech Stack

## Frontend (Web)
- React 18 + TypeScript 5
- Vite (dev server + build)
- Tailwind CSS — binds to DS tokens
- TanStack Query + Zustand (state)
- Vitest + React Testing Library
- Playwright (E2E)

## Backend (API)
- .NET 8 Web API
- Entity Framework Core 8
- FluentValidation
- Serilog (structured logging)
- xUnit + FluentAssertions
- Testcontainers (integration tests)

## Database
- PostgreSQL 16
- Migrations via EF Core

## Auth
- JWT + Refresh tokens
- Role-based (Librarian, Member)
- ASP.NET Identity for user management
- bcrypt for passwords

## Hosting
- Frontend: Azure Static Web Apps
- Backend: Azure App Service (Linux)
- Database: Azure Database for PostgreSQL Flexible

## Monitoring
- Application Insights (logs + metrics)
- Sentry (frontend error tracking)

## Dev tooling
- obsidian-workflow workflow (this project)
- pnpm workspaces (web)
- GitHub Actions (CI)

## Versions pinned
- Node 20.x
- .NET 8.x
- PostgreSQL 16.x
