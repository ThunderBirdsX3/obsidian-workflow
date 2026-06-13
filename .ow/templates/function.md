<!--
  Default template — แก้ per-project ได้โดย copy ไป `templates/function.md` (lookup priority สูงกว่า)

  FN spec = รายละเอียดที่ SRS ไม่ครอบ: UI states / API contract / validation / error states
  ของ FR ที่อ้างใน `source_fr` — acceptance Given/When/Then ของ FR อยู่ที่ SRS (single source
  of truth) ห้าม restate ที่นี่ ให้ reference กลับไป
-->

---
tags: [type/function]
area: <web | mobile | api>
role: <if role-specific>
status: spec               # spec | implemented | deprecated
version: 0.1.0
date: <YYYY-MM-DD>
feature: "[[FEAT-<slug>]]"
source_fr: "FR-###"        # FR ใน SRS ที่ FN นี้ implement (≥ 1; list ได้ถ้าหลายตัว)
related_functions: []
ui_components_used: []
design_tokens_used: []
---

# FN-<area>-<role>-<slug> — <Function name>

## 1. Purpose

<paragraph สั้นๆ อธิบายว่า function นี้ทำอะไร>

## 2. Source FR (SRS contract)

<!-- Tip: ทุก FN ต้องชี้กลับ FR ใน SRS — FN ที่ไม่มี FR รองรับ = spec gap (/ow-plan จะ flag)
     เกณฑ์ผ่าน/ไม่ผ่านใช้ acceptance Given/When/Then ของ FR ใน SRS; FN นี้ลงรายละเอียด
     UI states / API contract / validation / error states ที่ทำให้ acceptance นั้นเป็นจริง -->

- **FR-###** ([[SRS-<slug>#FR-###]]) — <requirement title> — acceptance: ดู SRS

## 3. Trigger / Entry point

- Web: route `/path` หรือ menu "<menu name>"
- Mobile: screen `<name>` หรือ tab "<name>"
- API: `<METHOD> /<endpoint>`

## 4. Inputs

| Input | Type | Source | Required |
|---|---|---|---|
| <input> | <type> | <source> | <yes/no> |

## 5. Behavior / Flow

1. <step 1>
2. <step 2>

## 6. Outputs / API contract

<!-- Tip: ฝั่ง API ระบุ request/response schema + status codes; ฝั่ง UI ระบุ result state -->

- Success: <state, redirect, message / response schema + HTTP code>
- Error: <state, message / error response ต่อ failure mode — ต้อง map กับ Error Catalog ใน SRS>

## 7. Side effects

- Database: <writes>
- External: <API calls>
- Cache: <invalidation>
- Audit: <log entries>

## 8. Auth / RBAC

- Required role(s): <list — ดู REF-AuthorizationMatrix>
- Required permissions: <list>
- Public/restricted: <decision>

## 9. UI states (web/mobile)

<!-- Tip: ระบุครบทุก state — loading / empty / error / success — พร้อม DS component ที่ใช้ -->

- Container: <DS component>
- Inputs: <DS components>
- Actions: <DS components>
- States: loading / empty / error / success — <แต่ละ state แสดงอะไร>

## 10. Design System Compliance

- Components used: <list จาก DS-Components.md>
- Tokens used: <list>
- Accessibility: <focus order, ARIA, keyboard>

## 11. Validation rules

<!-- Tip: ทุก input ต้องมี rule + ข้อความ error เมื่อไม่ผ่าน — สอดคล้องกับ pre-conditions ของ FR -->

- <field>: <rule> → error: <message>

## 12. Error states

<!-- Tip: ทุก failure mode ของ FR (จาก SRS § Error handling) ต้องมี UI/response ที่นี่ -->

| When | User เห็นอะไร / API ตอบอะไร | FR |
|---|---|---|
| <เงื่อนไข> | <message / HTTP code> | FR-### |

## 13. Edge cases

- <edge 1 — handle ยังไง>

## 14. Test scenarios

- [[TP-<slug>]]

## 15. Implementation

- Plan: [[80-ImplementPlan/<slug>]]
- Files: <relative paths>
