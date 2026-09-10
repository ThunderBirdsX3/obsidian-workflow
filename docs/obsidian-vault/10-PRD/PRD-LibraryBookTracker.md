---
tags: [type/prd]
status: approved
version: 1.0.0
date: 2026-05-15
authors: [Supasin]
related_docs: [[SRS-LibraryBookTracker]]
---

# PRD — Library Book Tracker

## 1. Problem
ห้องสมุดขนาดเล็กของชุมชน (ไม่ใช่ห้องสมุดมหาวิทยาลัยใหญ่) ยังใช้ Excel/กระดาษติดตามการยืม-คืน
ทำให้: หาหนังสือยาก สมาชิกไม่เห็นว่าตัวเองยืมอะไรอยู่ บรรณารักษ์ตามทวงผิดคน

## 2. Target users / Personas

- **Librarian** — บรรณารักษ์ของห้องสมุดชุมชน, มี 1-3 คน, ใช้คอมพิวเตอร์พื้นฐานได้
- **Member** — สมาชิก, ส่วนใหญ่อายุ 25-60, อยากดูว่ายืมอะไรอยู่ + เมื่อต้องคืน

## 3. Goals

- Librarian check-out / check-in หนังสือใน < 30 วินาที
- Member ดู "หนังสือที่ฉันยืมอยู่" + วันคืนได้จากมือถือ
- Librarian ดูว่าหนังสือไหนเลยกำหนดคืน + ติดต่อสมาชิกได้

## 4. Non-goals

- ไม่มี payment / ค่าปรับออนไลน์ (Phase 1)
- ไม่มี reservation system (เลื่อนไป Phase 2)
- ไม่มี mobile app native (Phase 1 ใช้ web responsive)

## 5. Success metrics / KPIs

- Checkout time: median < 30 sec (จาก > 2 min ตอนนี้)
- Member self-service usage: > 60% ของ member ดู portal เดือนละครั้ง
- Lost book rate: < 1% (จาก ~3% ปัจจุบัน)

## 6. User stories (high-level)

- As a **Librarian**, I want to search a member by name/ID and check out books in one screen, so that the line moves faster.
- As a **Librarian**, I want to see overdue books per member, so that I can follow up.
- As a **Member**, I want to see my current loans and due dates on my phone, so that I don't forget.

## 7. Constraints

- **Deadline**: Phase 1 ใน 6 สัปดาห์
- **Budget**: internal — ไม่จ่าย vendor
- **Tech stack**: .NET 8 API + React web + PostgreSQL (org standard)
- **Compliance**: PDPA — member PII ต้อง encrypt + audit log
- **Language**: Thai-first (English secondary)

## 8. Assumptions

- ห้องสมุดมี Wi-Fi ที่บรรณารักษ์ใช้ได้
- หนังสือทุกเล่มมี barcode (ISBN หรือ internal)
- สมาชิกมี email หรือ mobile

## 9. Risks

- บรรณารักษ์อายุ 50+ อาจไม่ comfortable กับ tool ใหม่ → mitigation: onboarding session + UI ใหญ่ + Thai
- Concurrent checkout (book ที่ลูกค้า 2 คนพยายามยืมพร้อมกัน) → mitigation: optimistic locking ใน API

## 10. Open questions

- [x] Authentication method? → JWT + role-based (resolved in tech-spec)
- [ ] Email notification ใช้ provider ไหน? → ยังตัดสินใจ Phase 1

## 11. Related
- SRS: [[SRS-LibraryBookTracker]]
- Tech reference: [[REF-TechStack]]
- Phase plan: [[PHASE-1-MVP]]
- Features: [[FEAT-Checkout]] [[FEAT-Returns]] [[FEAT-MemberSearch]]
