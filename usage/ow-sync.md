# /ow-sync

> **Sync obsidian-workflow snapshot** — pull update ล่าสุดจาก obsidian-workflow repo แล้วทับ `.ow/`

[← กลับ usage/README](./README.md) · [Full spec: `.ow/commands/ow-sync.md`](../.ow/commands/ow-sync.md)

## เมื่อไหร่ใช้

- มี command ใหม่/template ใหม่ใน [`obsidian-workflow`](https://github.com/ThunderBirdsX3/obsidian-workflow) อยาก pull ลง project
- `ow.version` เก่า อยาก bump
- เริ่ม project ใหม่ + อยากมั่นใจว่าใช้ spec ล่าสุด

## Quick start

```
/ow-sync
```

ตัวอย่าง output:
```
Currently pinned: 0.4.1
Latest available: 0.4.3

Files to add:    3
Files to update: 5
Files to remove: 0

Update the .ow snapshot from 0.4.1 → 0.4.3?
[y/N]:
```

## รูปแบบเต็ม

```
/ow-sync                       # interactive — show diff + ask confirm
/ow-sync --check               # ดู version diff อย่างเดียว ไม่ดาวน์โหลด
/ow-sync --to <version>        # pin ไป version เฉพาะ (เช่น 0.6.0)
/ow-sync --dry-run             # show changes แต่ไม่ทำจริง
/ow-sync --force               # skip confirmation
```

| Flag | Default | ใช้สำหรับ |
|---|---|---|
| `--check` | off | preview version diff |
| `--to <ver>` | latest | pin ไปเวอร์ชันเก่า/เฉพาะ |
| `--dry-run` | off | ทำทุก phase ยกเว้น write |
| `--force` | off | ไม่ถาม confirm (ใช้ใน CI) |

## ขั้นตอนภายใน (Phase summary)

1. **Phase 1** — Read current pinned (`.ow.yml` `ow.version`)
2. **Phase 2** — Fetch latest version จาก source repo (git tag + tree API)
3. **Phase 3** — Diff (เทียบ blob sha)
4. **Phase 4** — Confirm กับ user (ถ้าไม่ `--force`)
5. **Phase 5** — Download + atomic swap **scope: `.ow/` only** (สร้าง `.ow.backup-<ts>` ก่อน)
6. **Phase 6** — Update `.ow.yml` `ow.version` + `ow.last_synced`
7. **Phase 7** — Impact check (template overrides ที่ user แก้ใน `templates/` ยัง compatible ไหม)
8. **Phase 8** — Changelog (`.ow/SYNC-HISTORY.md`)

## Output ที่ได้

- `.ow/` ที่อัพเดต (ทับเฉพาะ folder นี้)
- `.ow.backup-<YYYYMMDD-HHMMSS>/` (rollback ได้)
- `.ow.yml` update 2 field: `ow.version`, `ow.last_synced`
- `.ow/SYNC-HISTORY.md` (append-only changelog)

## Workflow ที่นิยม

ตัวอย่าง: routine monthly sync
```
1. /ow-sync --check              ← เช็คก่อน
2. /ow-sync                       ← confirm + ทำจริง
3. (ตรวจ templates/ overrides ของ project ว่ายัง compat)
4. /ow-git --message "chore: sync obsidian-workflow 0.4.3"
```

ตัวอย่าง: pin ไป version เก่า (rollback)
```
/ow-sync --to 0.4.1
```

## Gotchas / ข้อควรระวัง

- 🚫 **ห้ามแตะ folder อื่นเด็ดขาด** — sync แค่ `.ow/` เท่านั้น ถ้าเจอ path นอก scope → abort + restore backup
- 🚫 ห้ามแก้ `.ow/` ด้วยมือ — sync ทับทุกครั้ง; ส่งการแก้เข้า `obsidian-workflow` repo แทน
- 🚫 ห้ามใส่ template ของ project เข้า `.ow/templates/` — ใส่ `templates/` แทน
- ⚠️ `.ow.yml` ไม่ถูกแตะ — sync แค่ bump `ow.version` + `ow.last_synced` ของไฟล์เดียว
- 💡 เก็บ backup อย่างน้อย 3 อันล่าสุด — `rm -rf .ow.backup-*` ทีหลังถ้าเก่าเกิน
- 💡 source repo เป็น private → `gh auth login` หรือ `GITHUB_TOKEN` (scope `repo`) — ไม่มี auth `raw.githubusercontent.com` ตอบ **404** ไม่ใช่ 403 sync จึง STOP แทนที่จะรายงาน "up to date" จากการอ่านที่ล้มเหลว

## Related

- ก่อน `/ow-sync`: ดู [`CHANGELOG.md`](https://github.com/ThunderBirdsX3/obsidian-workflow/blob/main/CHANGELOG.md) ของ obsidian-workflow repo
- หลัง `/ow-sync`: ตรวจ `templates/` overrides แล้ว run `/ow-test` smoke test
- Override template: ใส่ใน `templates/<name>.md` (gitTracked — sync ไม่ทับ)

## FAQ

**Q: ถ้า sync ทับ template ของผมล่ะ?**
A: ไม่ทับ — sync แตะแค่ `.ow/templates/` ของ project lookup chain: `templates/` > `.ow/templates/` — ตัวแรกไม่ถูก sync

**Q: rollback ยังไง?**
A: `rm -rf .ow && mv .ow.backup-<ts> .ow && yq -i '.ow.version = "<old>"' .ow.yml`

**Q: ใน CI ใช้ยังไง?**
A: `/ow-sync --force --to <pinned-version>` — pin ไป version เฉพาะ ไม่ถาม confirm
