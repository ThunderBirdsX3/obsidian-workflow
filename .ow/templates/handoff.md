<!--
  Default template — แก้ per-project ได้โดย copy ไป `templates/handoff.md`

  Session handoff note — สรุปงานเพื่อต่อ session หน้า (ตัวเองหรือ AI ตัวถัดไป)
  ไม่ใช่รายงาน — เขียนแค่พอให้เปิดมาแล้วทำต่อได้ทันที
-->

---
tags: [type/handoff]
date: <YYYY-MM-DD HH:mm>
title: <handoff title>
scope: <plan-slug | feature-name | diff-range>
status: open                 # open | continued | closed
related_plan: "[[<plan-slug>]]"
---

# <Title>

## Summary

<สรุปงานที่ทำ + สถานะปัจจุบัน 2-4 ประโยค>

## What Changed

- Files changed: <N> (production: <M>, tests: <K>)
- <feature/fix ที่เสร็จ>
- Docs updated: <list>

## Verification

- Tests: <N passed / M total> — evidence: <test-artifacts path>
- Build: <pass/fail/not run>
- Lint: <pass/fail/not run>
- Working level: <compiles | lint clean | tests pass | local smoke>

## Remaining Work

- [ ] <งานที่ยังไม่เสร็จ + ไฟล์/จุดที่ค้าง>
- [ ] <decision ที่ยังไม่ได้ตัดสิน>

## Context for Next Session

<สิ่งที่ session หน้าต้องรู้: gotcha, ทางที่ลองแล้วไม่ work, ไฟล์ที่ต้องอ่านก่อน>

## Next Steps

1. <ขั้นถัดไปที่แนะนำ>
