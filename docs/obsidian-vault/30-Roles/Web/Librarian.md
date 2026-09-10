---
tags: [type/role]
platform: web
date: 2026-05-15
---

# Role — Librarian (Web)

## 1. Description
บรรณารักษ์ของห้องสมุดชุมชน — ใช้บน desktop browser, ทำงาน checkout/return/manage members

## 2. Permissions
- read/write: members, books, loans
- read: audit log (own actions + others)
- ไม่ได้: delete member, system config
- (ดู [[REF-AuthorizationMatrix]] full matrix)

## 3. Menu / Navigation
- หน้าแรก (Dashboard) — overdue summary
- สมาชิก
  - ค้นหา / เพิ่ม / แก้
- ยืม-คืน
  - ยืมหนังสือ
  - คืนหนังสือ
- หนังสือ
  - รายการ / เพิ่ม
- รายงาน
  - หนังสือเลยกำหนด

## 4. Screens available
- [[FN-Web-Librarian-MemberSearch]] — ค้นหาสมาชิก
- [[FN-Web-Librarian-CheckoutFlow]] — ยืมหนังสือ
- (Return screen — TBD)

## 5. Restricted from
- Member portal pages (different role)
- System settings

## 6. Onboarding / First-time UX
- Live training session (45 min) before account activation
- In-app tooltip on dashboard (dismissible)
