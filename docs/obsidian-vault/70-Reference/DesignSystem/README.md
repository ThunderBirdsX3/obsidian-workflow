---
tags: [type/design-system, ds/index]
version: 1.0.0
date: 2026-05-15
status: active
---

# Design System — Library Book Tracker

Version: 1.0.0 — active

## Files

- [[DS-Tokens]] — colors, typography, spacing, radius, shadow, motion
- [[DS-Components]] — UI components (Button, Input, Card, ...)
- DS-Patterns — common UI patterns (not created yet: `/ow-design pattern <name>`)
- [[DS-Accessibility]] — WCAG AA rules
- DS-Layout — grid, breakpoints (not created yet)
- [[DS-Voice]] — tone + microcopy

## Style

- Minimalist + Thai-first
- Light theme default; dark mode Phase 2
- Target: librarians (50+ comfortable), members (general public)

## Frameworks

- Web: React + Tailwind CSS (binds to DS tokens via custom config)
- (Phase 2) Mobile native: tokens exported as Flutter ThemeData / Swift / Kotlin

## Force-use rule

หลัง DS active — งาน UI **ทุกชิ้น** ถูกบังคับใช้ tokens + components ที่นี่ ห้าม inline styling ห้าม recreate component

gate อยู่ที่ **ตัวงาน ไม่ใช่ที่ผู้ทำ** ⇒ บังคับเหมือนกันทั้งตอน Claude ทำเอง (inline) และตอน delegate ให้ subagent
`frontend`/`mobile` — สอง agent นี้ไม่ได้ ship มากับ obsidian-workflow, project สร้างเองด้วย `/ow-agent create <name>`
ไม่มีก็ไม่ได้แปลว่าไม่มี gate. เนื้อกฎอยู่ที่ `.ow/commands/_shared/design-process.md`
