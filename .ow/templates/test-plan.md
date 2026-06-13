<!--
  Default template — แก้ per-project ได้โดย copy ไป `templates/test-plan.md` (lookup priority สูงกว่า)
-->

---
tags: [type/test-plan]
status: draft                  # draft | active | archived
date: <YYYY-MM-DD>
feature: "[[FEAT-<slug>]]"
target: <web | mobile | api | cross>
---

# Test Plan — <Title>

## 1. Scope

<plan นี้ครอบอะไร + ไม่ครอบอะไร>

## 2. Roles to test

- <Role A>
- <Role B>

## 3. Scenarios

### TC-001 — <scenario title>

- **Pre-condition**: <state>
- **Steps**:
  1. <step 1>
  2. <step 2>
- **Expected**: <result>
- **Route source**: VISIBLE_MENU / DIRECT_URL_USER / DIRECT_URL_TECHNICAL
- **Auth**: <role required>

### TC-002 — <...>

## 4. Evidence requirements

- Screenshots per step
- Console + network logs
- PII masking required if data contains: <list>

## 5. Done definition

- [ ] ทุก scenario PASS หรือ acknowledged BLOCKED
- [ ] Evidence ครบตาม manifest format (ทุก artifact มี row)
- [ ] No PII leaks
- [ ] `EVIDENCE.md` manifest เติมครบ

## 6. Evidence

<!-- vault doc เก็บ TEXT เท่านั้น — evidence index คือ EVIDENCE.md MANIFEST ใต้
     test-artifacts/<date>/<source>-<NN>-<slug>/ (gitignored, นอก vault)
     ห้าม embed evidence table ที่นี่ -->

- Evidence: `test-artifacts/<date>/<source>-<NN>-<slug>/EVIDENCE.md` (manifest — binaries gitignored, นอก vault)
