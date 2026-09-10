---
tags: [type/design-system, ds/tokens]
tokens_version: 1.0.0
date: 2026-05-15
---

# DS-Tokens

## Color

### Primary (brand blue)
| Token | Hex |
|---|---|
| `--color-primary-50` | #EFF6FF |
| `--color-primary-100` | #DBEAFE |
| `--color-primary-200` | #BFDBFE |
| `--color-primary-300` | #93C5FD |
| `--color-primary-400` | #60A5FA |
| `--color-primary-500` | #3B82F6 |
| `--color-primary-600` | #2563EB |
| `--color-primary-700` | #1D4ED8 |
| `--color-primary-800` | #1E40AF |
| `--color-primary-900` | #1E3A8A |

### Neutral (gray)
| Token | Hex |
|---|---|
| `--color-neutral-0` | #FFFFFF |
| `--color-neutral-50` | #F9FAFB |
| `--color-neutral-100` | #F3F4F6 |
| `--color-neutral-200` | #E5E7EB |
| `--color-neutral-300` | #D1D5DB |
| `--color-neutral-400` | #9CA3AF |
| `--color-neutral-500` | #6B7280 |
| `--color-neutral-600` | #4B5563 |
| `--color-neutral-700` | #374151 |
| `--color-neutral-800` | #1F2937 |
| `--color-neutral-900` | #111827 |
| `--color-neutral-1000` | #030712 |

### Semantic
| Token | Hex |
|---|---|
| `--color-success-500` | #10B981 |
| `--color-warning-500` | #F59E0B |
| `--color-danger-500` | #EF4444 |
| `--color-info-500` | #3B82F6 |

### Background / surface
- `--bg-base` → `--color-neutral-50`
- `--bg-surface` → `--color-neutral-0`
- `--bg-elevated` → `--color-neutral-0` + shadow

### Text
- `--text-primary` → `--color-neutral-900`
- `--text-secondary` → `--color-neutral-600`
- `--text-disabled` → `--color-neutral-400`
- `--text-on-primary` → `--color-neutral-0`

## Typography

Font family:
- `--font-sans` → `'IBM Plex Sans Thai', 'Inter', system-ui, sans-serif`
- `--font-mono` → `'JetBrains Mono', monospace`

Scale (1.25 ratio):
| Token | Size | Line height |
|---|---|---|
| `--text-display` | 48px | 56px |
| `--text-h1` | 36px | 44px |
| `--text-h2` | 28px | 36px |
| `--text-h3` | 22px | 32px |
| `--text-h4` | 18px | 28px |
| `--text-body-lg` | 18px | 28px |
| `--text-body-md` | 16px | 24px |
| `--text-body-sm` | 14px | 20px |
| `--text-caption` | 12px | 16px |

Weights: 400 (regular), 500 (medium), 600 (semibold), 700 (bold)

## Spacing (4px base)

| Token | px |
|---|---|
| `--space-1` | 4 |
| `--space-2` | 8 |
| `--space-3` | 12 |
| `--space-4` | 16 |
| `--space-5` | 20 |
| `--space-6` | 24 |
| `--space-8` | 32 |
| `--space-10` | 40 |
| `--space-12` | 48 |
| `--space-16` | 64 |

## Radius

| Token | px |
|---|---|
| `--radius-none` | 0 |
| `--radius-sm` | 4 |
| `--radius-md` | 8 |
| `--radius-lg` | 12 |
| `--radius-full` | 9999 |

## Shadow

| Token | Value |
|---|---|
| `--shadow-sm` | `0 1px 2px rgb(0 0 0 / 0.05)` |
| `--shadow-md` | `0 4px 6px rgb(0 0 0 / 0.07)` |
| `--shadow-lg` | `0 10px 15px rgb(0 0 0 / 0.10)` |
| `--shadow-xl` | `0 20px 25px rgb(0 0 0 / 0.10)` |

## Motion

| Token | Duration / Easing |
|---|---|
| `--motion-fast` | 150ms ease-out |
| `--motion-normal` | 250ms ease-out |
| `--motion-slow` | 400ms ease-in-out |

## Z-index

| Token | Value |
|---|---|
| `--z-dropdown` | 1000 |
| `--z-sticky` | 1100 |
| `--z-modal-backdrop` | 1200 |
| `--z-modal` | 1300 |
| `--z-toast` | 1400 |
| `--z-tooltip` | 1500 |
