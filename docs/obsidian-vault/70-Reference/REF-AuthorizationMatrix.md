---
tags: [type/reference]
date: 2026-05-15
---

# REF — Authorization Matrix

## Roles

- **Librarian** — บรรณารักษ์ (internal staff)
- **Member** — สมาชิก (external user)
- **Admin** — system admin (Phase 2)

## Permissions Matrix

| Resource | Action | Librarian | Member | Admin |
|---|---|---|---|---|
| members | read | ✅ | (self only) | ✅ |
| members | create | ✅ | ❌ | ✅ |
| members | update | ✅ | (self limited) | ✅ |
| members | delete | ❌ | ❌ | ✅ |
| books | read | ✅ | ✅ (catalog only) | ✅ |
| books | create | ✅ | ❌ | ✅ |
| books | update | ✅ | ❌ | ✅ |
| loans | read | ✅ | (own only) | ✅ |
| loans | create | ✅ | ❌ | ✅ |
| loans | update | ✅ | ❌ | ✅ |
| audit_log | read | ✅ | ❌ | ✅ |
| settings | * | ❌ | ❌ | ✅ |

## Notes

- Member "self limited" update: name display, password — ไม่แตะ member_id, phone (need librarian)
- Audit log retention: 1 year, immutable
