# /ow-auto

> **สั่งครั้งเดียว ทำจนจบ** — ถามคำถามรวดเดียวตอนเริ่ม แล้ว plan → implement → test ทุก FEAT ใน vault phase (หรือ FEAT เดียว / brief) ให้เอง ไม่ถามซ้ำ · `--codex` / `--claude` ส่งงานเขียนโค้ดให้ CLI อีกตัว

[← กลับ usage/README](./README.md) · [Full spec: `.ow/commands/ow-auto.md`](../.ow/commands/ow-auto.md)

## เมื่อไหร่ใช้

- vault phase มีหลาย FEAT และอยากให้ทำต่อกันไปจนจบโดยไม่ต้องนั่งเฝ้า
- มี FEAT หรือ brief เดียว ยังไม่มี plan และอยากให้ทำครบวงจรในคำสั่งเดียว
- อยากใช้ quota ของอีก vendor เขียนโค้ด — สั่งจาก Claude Code ให้ Codex ทำ (`--codex`) หรือสั่งจาก Codex ให้ Claude ทำ (`--claude`)

## Quick start

```
/ow-auto PHASE-1
/ow-auto FEAT-Returns --codex
/ow-auto --resume docs/obsidian-vault/80-ImplementPlan/2026-10-15-1402-auto-phase-1.md
```

| target | คิวงาน |
|---|---|
| `PHASE-<n>` | ทุก `[[FEAT-*]]` ใต้ `## 2. Scope` → **In** ที่ doc ยังไม่ `status: done` เรียงตาม Priority |
| `FEAT-<name>` | FEAT เดียว → plan เดียว |
| `"<brief>"` | ข้อความอิสระ → plan เดียว (ไม่มี FEAT doc) |

flag เสริม: `--worktree` (implement+test ใน worktree แยก) · `--merge` (ให้ `/ow-test` merge เองเมื่อ PASS — default ไม่ merge)

## ก่อนใช้ `--codex` / `--claude`

- `--codex` (host = Claude Code) — ติดตั้ง Codex CLI แล้ว `codex login` · ทดสอบกับ `codex-cli 0.155.1`
- `--claude` (host = Codex) — ต้องมี `claude` บน PATH และ login แล้ว (รัน `claude` แบบ interactive หนึ่งครั้ง)
- ใช้ flag ที่ชี้ไป CLI ตัวเดียวกับ host (เช่น `--claude` บน Claude Code) → หยุดทันที "same host"
- preflight รันก่อนเขียนไฟล์ใดๆ — CLI ไม่มี / ไม่ได้ login → หยุด ไม่ fallback ไปทำเองเงียบๆ

## เกิดอะไรขึ้นบ้าง

1. **รวบรวมคิว** แล้วแสดงให้ดู (ไม่ใช่คำถาม)
2. **Phase 1.5 — ถามครั้งเดียว** — สแกนความกำกวมของทุก FEAT ในคิว รวมเป็นชุดเดียว ทุกข้อมี Recommended ตอบ "ตาม recommended ทั้งหมด" ได้ · คำตอบเขียนลง `## Clarifications` ของ FEAT doc และ run-log
3. **หลังจากนั้นไม่ถามอีก** — ต่อ FEAT: `/ow-plan` (ไม่ถาม ใช้ Clarifications) → stamp `status: approved` + `approved_by: ow-auto` → `/ow-implement --auto` → `/ow-test --no-merge`
4. build/test พัง → fix chunk + fix-log สั้นๆ ไม่เกิน `auto.max_fix_per_phase` รอบ · `/ow-test` FAIL → fix-log → `/ow-implement --from-fix <fix-log> --auto` ไม่เกินจำนวนรอบเดียวกัน
5. ทำต่อไม่ได้ → FEAT นั้นเป็น `stopped` พร้อมเหตุผล แล้ว**ไปต่อ FEAT ที่ไม่ได้พึ่งมัน** · FEAT ที่พึ่งมัน → `stopped: depends on …`
6. จบ: run-log `status: done` หรือ `done-with-stops`

## Commit อัตโนมัติ

ทุก plan phase ที่ผ่าน gate · ทุก fix ที่ผ่าน · ปิด plan · ปิด FEAT → commit **local** ทันที

- stage เฉพาะไฟล์ที่ run แตะ (`git add -- <paths>`) — ไม่ `git add -A` บน main tree
- ไม่ push · ไม่เรียก `/ow-git` · ไม่ `--no-verify` — commit พัง (hook/lock) → `STOPPED: commit`
- push / bump version ยังเป็นขั้นของคน: รัน `/ow-git` หลัง run จบ

## run-log อยู่ไหน อ่านอย่างไร

`80-ImplementPlan/YYYY-MM-DD-HHmm-auto-<slug>.md`

- frontmatter: `status`, `target`, `worker`, `grant`, `worktree`, `host`
- `## Queue` — 1 แถวต่อ FEAT: `queued | planning | implementing | testing | done | stopped` อัปเดตก่อนและหลังทุกขั้น
- `## Clarifications` — คำตอบจาก Phase 1.5 · `## Stops` — บรรทัด `STOPPED:` ของแต่ละ FEAT ที่หยุด
- log ดิบของ worker อยู่ `.ow/local/runs/<plan-slug>/` (gitignored) — ไม่เข้า vault

session ตาย → `/ow-auto --resume <run-log>` ทำต่อจากแถวที่ค้าง ไม่ถาม Phase 1.5 ซ้ำ ใช้ worker/grant จาก run-log

## เพดาน (`.ow.yml` block `auto:`)

| key | default | ความหมาย |
|---|---|---|
| `max_fix_per_phase` | `2` | fix chunk ต่อ plan phase (และรอบแก้หลัง `/ow-test` ต่อ FEAT) |
| `worker_timeout_min` | `30` | เวลาต่อ chunk ของ worker ภายนอก — เกิน → kill + BLOCKED · `0` = ไม่จำกัดเวลา |
| `codex_model` | `""` | model ของ `codex exec` — ว่าง = default ของ codex · ชื่อเต็ม (`gpt-6-sol`) = ใช้ตัวนั้นตรงๆ · ชื่อตระกูล (`sol`) = ตัวล่าสุดที่ list ใน `~/.codex/models_cache.json` ถ้าบัญชีใช้ไม่ได้จะลองตัวถัดไป (สูงสุด 3) |
| `claude_model` | `""` | model ของ `claude -p` (ว่าง = default ของ claude) |

## เครดิต worker หมด

- worker (`codex` / `claude`) ตอบว่าเครดิตหมดหรือชน usage limit → chunk นั้นถูกรันต่อโดย host เอง (Claude หรือ Codex แล้วแต่ใครสั่ง) ไม่ STOP และไม่นับเป็น fix attempt
- chunk ถัดไปลอง worker ใหม่ทุกครั้ง — เครดิตกลับมาก็ใช้ต่อได้เอง
- `## Chunk Progress` ขึ้น `worker: native (codex quota)` ให้เห็นว่า chunk ไหน fallback
- ใช้เฉพาะ `--auto` — `/ow-implement --codex` เดี่ยว ๆ ยัง BLOCKED แล้วถามผู้ใช้

## สิ่งที่ไม่ทำ

- 🚫 ไม่ push · ไม่ merge (เว้นแต่ใส่ `--merge` และ `/ow-test` PASS)
- 🚫 ไม่ทำงานต่อหลังปิด session/เครื่อง — ต้อง `--resume` เอง
- 🚫 ไม่รายงานตัวเลข token/cost — ขึ้นเป็น `usage: unknown` เสมอ (provider ไม่ได้ให้ตัวเลขที่เชื่อถือได้)
- 🚫 worker ภายนอกแก้โค้ดเท่านั้น — ไม่แตะ `docs/` ไม่ commit · vault เขียนโดย orchestrator คนเดียว

## แก้ปัญหา

- `preflight: codex not logged in` → `codex login` · `preflight: claude -p failed` → รัน `claude` แล้ว sign in
- `refusing to dispatch: prompt contains a secret-like token` → มีค่าคล้าย API key ใน rule/vault ที่ถูกแนบ — ลบออกจากไฟล์ต้นทาง

| `STOPPED:` reason | ความหมาย | ทำอะไรต่อ |
|---|---|---|
| `blocked` | worker BLOCKED ซ้ำหลังแบ่ง chunk ใหม่แล้ว 1 ครั้ง | อ่าน HANDOFF ใน plan · `tail -40` stderr ใน `.ow/local/runs/` |
| `fix-cap` | แก้ครบ `max_fix_per_phase` แล้วยังพัง | ดู fix-log ล่าสุดใน `85-FixLog` |
| `spawn-cap` | spawn chunk เกินเพดาน | plan ใหญ่เกิน — `/ow-plan --revise` แบ่ง phase |
| `timeout` | chunk เกิน `worker_timeout_min` สองครั้ง | เพิ่ม timeout หรือแบ่ง chunk |
| `worker-unavailable` | preflight / `ow-worker.sh` exit 2/3/4 | ดูข้อความ preflight ด้านบน |
| `dependency` | ไม่มี plan phase ไหนพร้อมรัน | `depends_on` ใน plan ผิด — `/ow-plan --revise` |
| `coverage` | มีโค้ด prod แต่ไม่มี test | เขียน test หรือระบุเหตุผล untestable |
| `scope` | ต้องขยาย scope เกิน plan | `/ow-plan --revise` แล้ว `--resume` |
| `commit` | commit ไม่ผ่าน (hook / lock / conflict) | แก้ hook แล้ว `--resume` |

## ทดสอบจริง (2026-10-15)

| worker | version | ผล |
|---|---|---|
| `--codex` | `codex-cli 0.155.1` | ✅ preflight ผ่าน · แก้ `a.js` ถูก · คืน `STATUS: DONE` + HANDOFF 7 บรรทัด · เก็บ session id ได้ — ต้องตั้ง `auto.codex_model` เพราะ model default ใน `~/.codex/config.toml` ถูกปฏิเสธเมื่อใช้ ChatGPT account (worker รายงาน `BLOCKED REASON: exit-code 1` ถูกต้อง) |
| `--claude` | `claude 2.1.289` | ✅ preflight ผ่าน · แก้ `a.js` ถูก · คืน `STATUS: DONE` · รัน shell ไม่ได้ใน `-p` + `acceptEdits` จึงแจ้ง `EXIT_STATE not verified` ใน DEVIATIONS — orchestrator รัน `EXIT_STATE` เองอยู่แล้ว ไม่ต้องเพิ่มสิทธิ์ |
| `--codex` alias | `codex_model: "sol"` | ✅ เลือก `gpt-6.1-sol` ก่อน → บัญชีปฏิเสธ → ลอง `gpt-6-sol` ต่อเองและงานเสร็จ (`<TAG>.model` = `gpt-6-sol`) |
| install | greenfield `--yes` | ✅ มี `scripts/ow-worker.sh` · `/ow-auto` shim · fragment ทั้งสอง · block `auto:` ใน `.ow.yml` · skill `.agents/skills/ow-auto/` เมื่อเปิด front-end codex |
| upgrade | `.ow.yml` 1.6.2 | ✅ config merge เติม block `auto:` ให้เอง |

## Related

- ใช้ภายใน: `/ow-clarify` · `/ow-plan` · `/ow-implement --auto` · `/ow-test`
- หลัง run: `/ow-git` (push) · `/ow-test <plan>` (merge ถ้าไม่ได้ใส่ `--merge`)
