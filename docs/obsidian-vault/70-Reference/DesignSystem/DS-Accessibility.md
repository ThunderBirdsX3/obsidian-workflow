---
tags: [type/design-system, ds/accessibility]
version: 1.0.0
date: 2026-05-15
---

# DS-Accessibility

Target: **WCAG 2.1 AA** สำหรับทุก feature

## Color contrast

- Text on background: **4.5:1** minimum (3:1 สำหรับ text >= 18pt หรือ 14pt bold)
- UI components vs background: **3:1** minimum
- ตรวจด้วย Stark / Contrast / axe ก่อน merge

ทุก token combination ที่ allowed:
- text-primary on bg-base ✓ 16.6:1
- text-primary on bg-surface ✓ 16.6:1
- text-secondary on bg-base ✓ 6.5:1
- text-on-primary on color-primary-600 ✓ 4.5:1
- color-danger-500 on bg-surface ✓ 4.5:1

## Keyboard navigation

- Tab order ตรง visual order
- Focus visible เสมอ — 2px ring of `--color-primary-500` + 2px offset
- Skip-to-main link ที่ top ของ page
- Escape closes modal/popover
- Arrow keys ใน menu/list (optional but preferred)
- Enter/Space activates button

## Screen reader

- Semantic HTML: `<header>`, `<nav>`, `<main>`, `<footer>` ใช้ตามจริง
- Form labels: ทุก input มี `<label>` linked
- Images: `alt` text descriptive; decorative → `alt=""`
- Icons standalone: `aria-label`
- Live region: Toast `role="status"` / `role="alert"`
- Loading state: `aria-busy="true"`
- Errors: `aria-invalid`, `aria-describedby` → error id

## Forms

- Label always visible (no placeholder-only)
- Error message ถัด field, color + icon (ไม่ใช้สีเดียว)
- Required indicator (asterisk + `aria-required`)
- Inline validation only after blur or submit (ไม่ใช่ทุก keystroke)

## Motion

- Honor `prefers-reduced-motion: reduce` → motion duration → 0 หรือ minimal
- ห้าม flash > 3 times/sec (epilepsy concern)
- Auto-play video: หลีกเลี่ยง; ถ้ามี — มี pause button

## Touch target

- Minimum 44×44 px hit area (mobile + desktop)
- 8px gap minimum ระหว่าง adjacent targets

## Language

- `<html lang="th">` (or "en" หรือ user preference)
- ทุก text ผ่าน i18n; ห้าม hardcode
- Direction: LTR default (RTL Phase 3 if needed)

## Testing

- Manual: keyboard-only navigation test ทุก feature
- Automated: axe-core ใน Vitest + Playwright E2E
- Screen reader: VoiceOver (macOS) + NVDA (Windows) ทุก major release

## Required for each component

- [ ] Keyboard accessible
- [ ] Focus visible
- [ ] Screen reader announces correctly
- [ ] Color contrast 4.5:1 text / 3:1 UI
- [ ] Works without color alone (use icon + text)
- [ ] Touch target 44×44+
- [ ] Reduced motion respected
