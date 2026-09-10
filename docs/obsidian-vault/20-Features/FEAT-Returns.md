---
tags: [type/feature]
status: planning
version: 0.1.0
date: 2026-05-20
prd: [[PRD-LibraryBookTracker]]
phase: [[PHASE-1-MVP]]
related_functions: []
ui_components_used: []
design_tokens_used: []
---

# FEAT-Returns — Book Returns Flow

## 1. Description
Librarian รับคืนหนังสือ — scan barcode → ระบุ condition (good / damaged / lost) → close loan

## 2. User value
- Close loan ใน < 15 วินาที
- Track damaged book สำหรับ replacement decision

## 3. Scope

**In:**
- Barcode scan / type
- Condition radio (good / damaged / lost)
- Late return note (auto-calculated)

**Out:**
- ค่าปรับ (Phase 2)
- Damage photo upload (Phase 2)

## 4. Roles affected
- [[Librarian]]

## 5. UX flow
- TBD (waiting for /ow-plan)

## 6. Functions involved
- TBD

## 7. Acceptance criteria
- [ ] Return creates timestamp on Loan.return_at
- [ ] Book status updates: good → available, damaged → review, lost → lost
- [ ] Member loan count - 1
- [ ] Audit log entry

## 8. Edge cases
- Book not actually on loan — clear error
- Book marked lost previously, but now physically returned — recovery flow

## 9. Test scenarios
- TBD

## 10. Design System Compliance
- TBD ตอน /ow-plan

## 11. Implementation plans
- (none yet)

## 12. Risks
- (TBD)

## 13. Status notes
- 2026-05-20: planning stage
- next: รัน /ow-plan "FEAT-Returns implementation"
