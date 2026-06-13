<!--
  Default template — แก้ per-project ได้โดย copy ไป `templates/design-component.md` (lookup priority สูงกว่า)
  ใช้โดย /ow-design — 1 block ต่อ 1 component ใน DS-Components.md
-->

## <ComponentName>

### Purpose

<ใช้เมื่อไร ไม่ใช้เมื่อไร — เขียนให้ concrete>

### Anatomy

- Container
- Slot/children
- Icon (optional)
- <ส่วนอื่นๆ>

### Variants

- **size**: sm / md / lg
- **intent**: primary / secondary / danger / ghost
- **state**: default / hover / focus / disabled / loading / error

### Props (framework-agnostic)

| Prop | Type | Default | Note |
|---|---|---|---|
| <prop> | <type> | <default> | <note> |

### Accessibility

- Role: <button | link | textbox | ...>
- ARIA: <attributes>
- Keyboard: <Enter / Space / arrows>
- Focus visible: <how>
- Screen reader: <expected announcement>

### Tokens Used

- color: <e.g. `--color-primary-500`, `--color-text-on-primary`>
- spacing: <e.g. `--space-3`, `--space-4`>
- radius: <e.g. `--radius-md`>
- typography: <e.g. `--text-body-md`>
- shadow: <e.g. `--shadow-sm`>
- motion: <e.g. `--motion-fast`>

### Example (framework-aware)

```tsx
<Button intent="primary" size="md" onClick={save}>
  บันทึก
</Button>
```

### Don't

- <ข้อห้าม 1 — เช่น ห้าม override สีด้วย class ภายนอก>
- <ข้อห้าม 2>
