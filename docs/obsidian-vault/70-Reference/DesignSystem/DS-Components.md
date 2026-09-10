---
tags: [type/design-system, ds/components]
components_version: 1.0.0
date: 2026-05-15
---

# DS-Components

## Button

### Purpose
ใช้สำหรับ actions — submit, confirm, cancel ฯลฯ

### Anatomy
- Container
- Label (text)
- Icon (optional, leading or trailing)

### Variants
- **size**: sm (32px) / md (40px) / lg (48px)
- **intent**: primary / secondary / danger / ghost / link
- **state**: default / hover / focus / disabled / loading

### Props
| Prop | Type | Default | Note |
|---|---|---|---|
| intent | enum | primary | |
| size | enum | md | |
| loading | bool | false | shows spinner, disables click |
| disabled | bool | false | |
| icon | ReactNode | — | leading by default |
| iconPosition | enum | leading | leading/trailing |

### Accessibility
- Role: `button`
- Focus visible: 2px ring of `--color-primary-500` + offset 2px
- Keyboard: Enter / Space activates
- Loading: `aria-busy="true"`, label remains visible
- Disabled: `aria-disabled="true"`

### Tokens Used
- color: `--color-primary-600` (primary), `--color-danger-500` (danger), `--color-neutral-0` (text-on-primary)
- spacing: `--space-3` (px), `--space-4` (md)
- radius: `--radius-md`
- typography: `--text-body-md`, weight 500
- motion: `--motion-fast`

### Example
```tsx
<Button intent="primary" size="md" onClick={save}>บันทึก</Button>
<Button intent="danger" loading>กำลังลบ...</Button>
```

### Don't
- ห้ามใส่ icon เกิน 1 ตัว
- ห้ามเปลี่ยนสี — ใช้ intent
- ห้ามใส่ใน table cell หนาแน่น (ใช้ ghost)

---

## Input

### Purpose
Text input — single line

### Anatomy
- Label (optional, above)
- Field container (border + padding)
- Input element
- Helper text (optional, below)
- Error message (replaces helper when error)
- Leading icon (optional)
- Trailing element (optional — icon or button)

### Variants
- **size**: sm / md / lg
- **variant**: default / search / barcode (monospace)
- **state**: default / focus / error / disabled

### Props
| Prop | Type | Default | Note |
|---|---|---|---|
| label | string | — | |
| value | string | — | |
| onChange | fn | — | |
| placeholder | string | — | |
| helperText | string | — | |
| errorText | string | — | overrides helper |
| size | enum | md | |
| variant | enum | default | |
| leadingIcon | ReactNode | — | |
| trailingElement | ReactNode | — | |

### Accessibility
- Label: `<label for="id">` linked to input
- Error: `aria-invalid="true"`, `aria-describedby="error-id"`
- Required: `aria-required="true"`
- Search variant: `role="searchbox"`
- Focus visible: border `--color-primary-500` + ring

### Tokens Used
- color: `--color-neutral-300` (border), `--color-primary-500` (focus), `--color-danger-500` (error)
- spacing: `--space-3` / `--space-4`
- radius: `--radius-md`
- typography: `--text-body-md`

### Example
```tsx
<Input label="ค้นหาสมาชิก" variant="search" leadingIcon={<SearchIcon/>} />
<Input label="บาร์โค้ด" variant="barcode" autoFocus />
```

### Don't
- ห้ามใช้แทน Textarea
- ห้ามใส่ icon ทั้ง leading + trailing เกิน 1
- ห้ามแก้ font จาก variant — variant คือ source of truth

---

## Card

### Purpose
Container สำหรับ grouped content

### Anatomy
- Outer container (background + border + shadow + radius)
- Header (optional)
- Body
- Footer (optional)

### Variants
- **elevation**: flat (border only) / raised (shadow)
- **interactive**: false / true (hover effect)

### Tokens Used
- bg: `--bg-surface`
- border: `1px solid --color-neutral-200`
- shadow: `--shadow-sm` (raised), none (flat)
- radius: `--radius-md`
- padding: `--space-4`

### Accessibility
- ถ้า interactive: role="button", focus visible

---

## Badge

### Purpose
Inline status indicator (active/inactive, count, label)

### Variants
- **intent**: neutral / primary / success / warning / danger
- **size**: sm / md

### Tokens
- bg: `--color-<intent>-100` (light)
- text: `--color-<intent>-800` (dark)
- padding: `--space-1 --space-2`
- radius: `--radius-full`
- typography: `--text-caption`, weight 500

---

## Modal

### Purpose
Dialog ที่ block underlying UI — confirm, override, form

### Anatomy
- Backdrop (semi-transparent overlay)
- Container (centered, max-width)
- Header (title + close button)
- Body
- Footer (actions)

### Accessibility
- `role="dialog"`, `aria-modal="true"`
- `aria-labelledby` → title id
- Focus trap inside modal
- Escape closes
- Initial focus: first interactive

### Tokens
- backdrop: `rgb(0 0 0 / 0.5)`
- bg: `--bg-surface`
- shadow: `--shadow-xl`
- radius: `--radius-lg`
- padding: `--space-6`
- z-index: `--z-modal`

---

## Toast

### Purpose
Non-blocking notification (success/error/warning/info)

### Variants
- **intent**: success / warning / danger / info

### Accessibility
- `role="status"` (success/info) or `role="alert"` (warning/danger)
- Auto-dismiss after 5s (configurable); pause on hover
- Dismiss button: `aria-label="ปิด"`

### Tokens
- bg: `--color-<intent>-50`
- text: `--color-<intent>-900`
- border-left: 4px `--color-<intent>-500`
- shadow: `--shadow-md`
- z-index: `--z-toast`

---

## Table

### Purpose
Tabular data display

### Features
- Sortable header (click)
- Sticky header
- Row hover state
- Empty state
- Loading skeleton

### Accessibility
- `role="table"`, proper `<thead>`/`<tbody>`
- Sortable column: `aria-sort`
- Row selection (if any): checkbox + `aria-selected`

---

## Pagination

### Purpose
Navigate pages of results

### Anatomy
- Previous button
- Page numbers (with ellipsis for many)
- Next button
- Optional: "Showing N of M"

### Accessibility
- Each page link: `aria-label="หน้า N"`
- Current: `aria-current="page"`
