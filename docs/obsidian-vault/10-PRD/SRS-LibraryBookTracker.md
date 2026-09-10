---
tags: [type/srs]
status: approved
version: 1.0.0
date: 2026-05-15
prd: [[PRD-LibraryBookTracker]]
---

# SRS — Library Book Tracker

## 1. System overview

Web application สำหรับห้องสมุดชุมชน — บรรณารักษ์ใช้บน desktop, สมาชิกใช้บน mobile web (responsive).
Backend: REST API (.NET 8) + PostgreSQL. Auth: JWT + role-based (Librarian / Member).

## 2. User stories (detailed)

### US-001 — Librarian search member
**As a** Librarian **I want** to search a member by name, phone, or member ID **so that** I can pull up their account quickly.

**Acceptance criteria:**
- [x] Given member exists, when I type 3+ chars, then matching members appear within 500ms
- [x] Given multiple matches, when I see results, then they show: name, member ID, phone (last 4), current loan count
- [x] Given no match, when I see results, then "ไม่พบสมาชิก" message + suggest create new

### US-002 — Librarian checkout book
**As a** Librarian **I want** to scan or type a book barcode after selecting member **so that** the loan is recorded.

**Acceptance criteria:**
- [ ] Given member selected + book available, when barcode entered, then loan created with due date = today + 14 days
- [ ] Given book already on loan, when barcode entered, then warning + show current borrower
- [ ] Given member has 5 active loans, when trying 6th, then warning + require override

### US-003 — Member view own loans
**As a** Member **I want** to see my current loans and due dates **so that** I return on time.

**Acceptance criteria:**
- [ ] Given logged in, when I open portal, then see list: book title, checkout date, due date, status (active / overdue)
- [ ] Given any loan, when I tap it, then see book detail + "ขอต่อเวลา" button (Phase 2 — disabled now)

## 3. Functional requirements

### FR-001 — Member search
- Inputs: free text query
- Outputs: list of matching members (max 20)
- Pre: librarian authenticated
- Post: nothing
- Errors: empty query → ignored; 0 results → empty state

### FR-002 — Book checkout
- Inputs: member_id, book_barcode
- Outputs: loan record (id, due_date)
- Pre: member exists; book available; member < 5 active loans
- Post: book status = on_loan; member loan count + 1
- Errors: see acceptance criteria above

### FR-003 — Member loans list
- Inputs: member_id (from JWT)
- Outputs: list of active + overdue loans
- Pre: member authenticated
- Post: nothing
- Errors: none

### FR-004 — Overdue dashboard
- Inputs: none (librarian role)
- Outputs: list of overdue loans grouped by member
- Pre: librarian authenticated

## 4. Non-functional requirements

- **Performance**: search response < 500ms (p95); checkout < 1s (p95)
- **Availability**: 99% (no SLA — internal tool)
- **Security**: JWT, HTTPS, parameterized queries, PII encrypted at rest
- **Privacy**: PDPA — audit log access, retention 1 year for inactive members
- **Accessibility**: WCAG AA, Thai language full support
- **i18n**: Thai-first, English fallback for librarian UI

## 5. Data model (high-level)

- **Member**: id, name, phone, email (encrypted), member_id (display), created_at
- **Book**: id, isbn, title, author, barcode (unique), status (available | on_loan | lost)
- **Loan**: id, member_id, book_id, checkout_at, due_at, return_at (nullable), status

## 6. External integrations

- (none in Phase 1)
- Phase 2: SMS/email notification provider

## 7. UX flows (links)
- [[FLOW-Checkout]]
- FLOW-MemberPortalView — not documented yet

## 8. Out-of-scope

- ปรับ ISBN data จาก external source
- Multi-branch (only single library)
- Inventory audit / stock count tools

## 9. Acceptance for release

- [ ] All FRs implemented + tested
- [ ] Performance targets met (load test)
- [ ] PDPA: PII encrypted + audit log functional
- [ ] WCAG AA: contrast + keyboard nav + screen reader
- [ ] Onboarding session conducted (live training with librarian)
- [ ] /ow-verify --feature Phase1 → handoff approved
