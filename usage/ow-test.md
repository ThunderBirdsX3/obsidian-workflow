# /ow-test

> **Smoke test เฉพาะส่วน diff** — detect changed surface → spin servers → รัน smoke test (inline หรือ delegate ให้ test-runner) → รายงานผลจริง

[← กลับ usage/README](./README.md) · [Full spec: `.ow/commands/ow-test.md`](../.ow/commands/ow-test.md)

## เมื่อไหร่ใช้

- หลัง `/ow-implement` — verify ว่า code ที่แก้ทำงาน
- ก่อน `/ow-verify` / `/ow-secure` — smoke pass ก่อน
- มี test plan (`90-TestPlan/TP-*.md`) — รัน systematic role-by-role
- หลัง `/ow-fix` → `/ow-implement` — verify ว่า fix ใช้ได้

## Quick start

```
/ow-test
```

Auto-detect:
```
git diff --name-only HEAD
→ ตรวจว่าแก้ใน web/, api/, mobile/
→ spin server → รัน smoke test (inline / test-runner)
→ capture screenshot + console + network
```

## รูปแบบเต็ม

```
/ow-test                       # auto-detect จาก git diff
/ow-test web                   # บังคับ web
/ow-test app                   # บังคับ mobile — default unit + integration เท่านั้น (ไม่เปิด emu/sim)
/ow-test app --e2e             # mobile + E2E (Maestro) — เปิด emulator/simulator (#32)
/ow-test api                   # backend (unit + integration)
/ow-test <plan-file>           # scope ของ plan
/ow-test <test-plan-file>      # systematic test plan (90-TestPlan/)
/ow-test --since <ref>         # diff ตั้งแต่ ref (default HEAD)
/ow-test <plan> --no-merge     # worktree mode: test ใน worktree แต่ห้าม auto-merge (#31)
/ow-test <plan> --no-worktree  # บังคับ test ที่ main tree
```

## 🌳 Worktree mode — auto-merge ตอน PASS (#31)

ถ้า task ถูก build ใน worktree (`/ow-implement --worktree`) → `/ow-test` จะ:
1. detect worktree จาก plan frontmatter (`worktree_status: built`) → รัน server/test **ใน worktree** (โค้ดใหม่)
2. **ทุก scenario PASS** → **auto-merge** branch `plan/<slug>` กลับ base (`git merge --no-ff`, **local เท่านั้น ไม่ push**) + cleanup worktree
3. **FAIL/BLOCKED / `--no-merge`** → ไม่ merge, เก็บ worktree ไว้ที่ `worktrees/plan-<slug>/` ให้แก้ต่อ → รัน `/ow-test` ซ้ำ

🔒 **Safe merge (กฎ #29 ขยายถึง merge):** ใช้ `git merge --no-ff` (non-destructive) เท่านั้น — ถ้าจะทับงาน
uncommitted ใน main tree git จะ **abort เอง** → STOP เก็บ worktree. **ไม่เคย** `reset --hard`/`stash`/`restore`/`clean`
→ **งาน uncommitted คู่ขนานของคุณไม่หาย**. main tree ต้องอยู่บน base branch (ไม่งั้น STOP ไม่ checkout).
หลัง merge → `/ow-git --bump` เพื่อ push (— `/ow-test` ไม่ push เด็ดขาด).

🔒 **Submodule-safe cleanup:** worktree ถูกลบ**เฉพาะหลัง merge สำเร็จ + verify จริง** (`merge-base --is-ancestor`
ยืนยันทุก commit อยู่ใน base แล้ว). superproject merge บันทึกแค่ gitlink SHA — objects ของ submodule ยังอยู่ใน
per-worktree store ⇒ ก่อนลบ worktree จะ absorb objects เข้า store หลัก + ตรวจว่า gitlink ทุกตัว resolve ได้
(**ทุก gate ผ่านเท่านั้นถึงลบ**); ไม่ผ่าน → เก็บ worktree ไว้ (merge สำเร็จแล้ว แค่ cleanup ค้าง — commit ไม่มีทางหาย).

| Mode | Trigger |
|---|---|
| Auto | args ว่าง → ดู git diff |
| Forced | `web` / `app` / `api` |
| Plan scope | path ใน `80-ImplementPlan/` |
| Test Plan | path ใน `90-TestPlan/` (systematic) |

## ขั้นตอนภายใน (Phase summary)

1. **Phase 0** — Detect mode
2. **Phase 1** — Detect scope (auto only) จาก `git diff`
3. **Phase 2** — Spin servers (dev server, API) เท่าที่จำเป็น (reuse ตัว healthy, `READY_URL` ต่อ target — ไม่ hardcode port); mobile emulator/simulator เปิด**เฉพาะ** `--e2e` (#32). ใครเปิดคนนั้น **ปิดทุกอย่างที่ตัวเองเปิด** ตอนจบ (Phase 7.5 teardown) — กัน dev-server/emulator ค้างกิน resource
4. **Phase 3** — รัน smoke tests, เก็บ console+network output, PII mask, route source trace — **3.0 ตัดสินเองว่า inline หรือ delegate ให้ `test-runner`** (ไม่บังคับทางไหน · งาน/gate เหมือนกันทั้งสองแบบ)
6. **Phase T (Test Plan mode)** — รัน systematic ทุก role × scenario, status taxonomy: PASS/FAIL/INFO/LIMITED/PASS_NO_MUTATION/BLOCKED_*/NOT_RUN
6. **Phase 4** — บันทึกสิ่งที่รันเห็นจริง: output ลง scratch run dir (`${TMPDIR:-/tmp}/ow-run-<slug>/`) แล้ว quote เฉพาะบรรทัดที่เกี่ยวลงรายงาน
7. **Phase 5** — Visible-menu rule: route source = VISIBLE_MENU / DIRECT_URL_USER / DIRECT_URL_TECHNICAL
8. **Phase 6** — Output report (PASS/FAIL summary + คำสั่งที่รันจริง)

## Output ที่ได้

- Scratch run dir `${TMPDIR:-/tmp}/ow-run-<slug>/` — `test-output.txt`, `console.log`, `network.log` (ชั่วคราว ไม่ commit ไม่เข้า vault)
- Test Plan mode: รายงานฉบับเต็มเป็น **text** ใน vault `90-TestPlan/`
- Console: PASS/FAIL/BLOCKED summary

## Status taxonomy

| Status | ความหมาย |
|---|---|
| `PASS` | ผ่านสมบูรณ์ |
| `FAIL` | failed (มี error/wrong output) |
| `INFO` | informational (no pass/fail) |
| `LIMITED` | partial — บาง assertion ทำไม่ได้ |
| `PASS_NO_MUTATION` | pass แต่ไม่ test side-effect |
| `BLOCKED_<reason>` | blocked (env, dep, perm) |
| `NOT_RUN_RISK` | ไม่ได้รัน (ไม่ใช่ pass ปลอม) |

## Workflow ที่นิยม

ตัวอย่าง 1: post-implement smoke
```
1. /ow-implement <plan>           ← code change
2. /ow-test                       ← auto-detect web → smoke
3. (ถ้า fail → /ow-fix)
4. /ow-verify
```

ตัวอย่าง 2: systematic test plan
```
1. /ow-doc TestPlan FEAT-Checkout      ← สร้าง TP-Checkout.md
2. /ow-test docs/obsidian-vault/90-TestPlan/TP-Checkout.md
   → รันทุก role × scenario
   → รายงานผลครบทุก role × scenario ใน 90-TestPlan/
```

ตัวอย่าง 3: pre-merge check
```
/ow-test --since main
  → diff vs main branch
  → smoke ทุก surface ที่กระทบ
```

## Gotchas / ข้อควรระวัง

- 🚫 **ห้ามแต่ง console log, network log, pass/fail count** — no-fake-results policy
- 🚫 **ห้ามรัน test กับ production env**
- 🚫 ห้าม claim PASS ถ้า test ไม่ได้รันจริง — mark `NOT_RUN_RISK` แทน
- 🚫 ห้าม quote output ที่มี PII ลง vault โดยไม่ mask
- ⚠️ Visible-menu rule: UI test ต้องเริ่มจาก menu navigation default; ใช้ `DIRECT_URL_*` ต้องระบุเหตุผล
- ⚠️ Server credentials/secrets ที่ไม่มี → blocker → STOP + แจ้ง user
- 🌳 **Worktree mode**: auto-merge เกิดเฉพาะ **PASS ทุก scenario**; merge local เท่านั้น (ไม่ push); conflict/dirty = STOP เก็บ worktree (ไม่ลบงาน uncommitted ของคุณ, #29)
- 💡 ถ้า "ไม่มี diff" → exit สั้นๆ ไม่รัน
- 📱 **Mobile default = no emulator (#32)**: `/ow-test app` รัน unit+integration เท่านั้น; e2e scope = `NOT_RUN`
  (reason "no --e2e flag") จนกว่าจะสั่ง `--e2e`
- 💡 ทุก scenario บันทึก page / expected / actual / console / network summary ลงรายงาน

## Related

- ก่อน `/ow-test`: [/ow-implement](./ow-implement.md) (มี code change)
- หลัง `/ow-test` (fail): [/ow-fix](./ow-fix.md)
- Test plans: `docs/obsidian-vault/90-TestPlan/`
- Subagent: `test-runner` — ไม่ได้ ship มา สร้างเองด้วย [`/ow-agent create test-runner`](./ow-agent.md); ไม่มีก็รัน inline ได้ปกติ gate เดิมครบ

## FAQ

**Q: ต้อง install Playwright/Maestro ก่อนไหม?**
A: ใช่ — Playwright (web) + Maestro (mobile) ถ้า project ไม่มี → ใช้ unit/integration test ของ project แทน (จะรัน inline หรือผ่าน `test-runner` agent ที่ create ไว้ ก็ได้ผลเหมือนกัน)

**Q: output ของ test เก็บไว้ที่ไหน?**
A: scratch run dir ชั่วคราวเท่านั้น — อ่าน, quote บรรทัดที่เกี่ยวลงรายงาน/vault (mask PII ก่อน) แล้วปล่อยทิ้ง ไม่มีการเก็บไฟล์ถาวรและไม่ commit

**Q: smoke test กับ full test plan ต่างกันไง?**
A: Smoke = diff-scoped (เร็ว, fail-fast); Test Plan = systematic role × scenario (ครบ, ใช้ก่อน release)

**Q: mobile ต้องเปิด emulator/simulator ทุกครั้งไหม?**
A: ไม่ — default (`/ow-test app`) รัน **unit + integration** เท่านั้น (host-side, ไม่มี device). ต้องการ
E2E (Maestro) ค่อยสั่ง `/ow-test app --e2e` — ตอนนั้นถึงเปิด emulator/simulator (#32)
