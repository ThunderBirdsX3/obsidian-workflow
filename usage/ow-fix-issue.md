# /ow-fix-issue — Fix GitHub bug issues (parallel worktree)

> ใช้ตอน: มี real-bug ที่ผ่าน triage แล้ว อยากแก้เป็นชุดแบบขนาน (diagnose + test + fix + commit + merge local)

## ใช้ยังไง

```
/ow-fix-issue                     # 🌟 auto-discover real-bug ทั้งหมด + per-group approval + parallel
/ow-fix-issue --dry-run           # แสดง queue plan แล้วจบ
/ow-fix-issue #62                 # แก้ issue เดียว
/ow-fix-issue #62 #63 #64         # แก้เป็น cluster (1 group)
/ow-fix-issue #62 --diagnose-only # หยุดที่ fix-log + RED baseline (เหมือน /ow-fix)
/ow-fix-issue #62 --submodule web # บังคับ submodule ถ้า detect ไม่ออก

# หลัง /ow-git push+bump แล้ว — บอก tester ว่า fix อยู่ใน version ไหน
/ow-fix-issue #62 #63 --ready-for-test       # comment "fixed in vX.Y.Z" + flip label → ready for test
/ow-fix-issue --ready-for-test               # auto: ทุก fix-log status:fixed ที่ push แล้วแต่ยังไม่ flip
/ow-fix-issue #62 --ready-for-test --version 1.4.2   # บังคับ version ถ้า detect ไม่ออก
```

## Prerequisite

- `gh` CLI auth + อยู่ใน git repo
- agent `gh-issue` + specialized subagent (backend/frontend/mobile) enabled
- `.ow.yml` `submodules:` ถูกต้อง (multi-repo) หรือ `[]` (monorepo)

## ทำอะไรให้

1. ค้น real-bug ที่พร้อมแก้ (default) หรือรับเลข issue ที่ระบุ
2. จัดกลุ่ม (cluster/standalone) + เรียง priority (P0→P3)
3. **ถามอนุมัติทุก group ก่อน** (default mode)
4. เปิด worktree แยกต่อ group → ทำงาน: diagnose → write test → RED baseline → fix → test pass → **GREEN result** → commit
   - **>1 group = spawn agent ขนาน** (แต่ละ group อิสระจริง คนละ worktree/branch) · **1 group = ดุลพินิจ** (inline หรือ 1 agent — Phase 4)
5. **Auto-merge fix branch เข้า base branch (local เท่านั้น — ไม่ push)** serial ภายใน submodule
   - 🔴 **ไม่เคย `git checkout` ให้** — repo นั้นต้องอยู่บน base branch + สะอาดอยู่แล้ว ไม่งั้น **ข้าม fix นั้นแล้วรายงาน**
     (เก็บ worktree + branch ไว้ให้ merge เอง) · dirty/diverged/conflict = ข้าม ไม่ force (#29 เดียวกับ `/ow-test`)
   - `git pull --ff-only origin <base>` เป็น network step เดียวที่ทำ (fix branch ตัดจาก `origin/<base>`) — diverged = git ปฏิเสธเอง ไม่เขียนทับ
6. Cleanup worktree → handoff report

## ต่อด้วย (user trigger — skill ไม่ทำให้)

ลำดับมาตรฐาน:
1. `/ow-test` — smoke เฉพาะ area/role ที่ fix แตะ
2. `/ow-git --bump patch` — push + version bump → **auto** comment "fixed in vX.Y.Z" + flip label `ready for test` ทุก issue ที่ commit ปิด (`Closes #NN`) ให้เลย (Phase 8.5)
3. หลัง tester verify ผ่าน → close issue เอง

> `--ready-for-test` mode ยังมีไว้สั่งเองภายหลัง (ถ้า push ตอนนั้นปิด auto ด้วย `--no-ready-for-test` หรือ version ยังไม่ออก): `/ow-fix-issue #NN --ready-for-test [--version X.Y.Z]`

## หมายเหตุ

- **ไม่ push** — obsidian-workflow no-auto-git; push เป็นงาน `/ow-git`
- **ไม่ comment / ไม่ close issue ใน fix flow** — comment version + flip label เกิดเฉพาะ `--ready-for-test` (หลัง push); close ยังเป็น tester เสมอ
- **`--ready-for-test` ตรวจ push จริงก่อน flip** — ถ้า merge ยังไม่ขึ้น remote = ข้าม + เตือน (กัน tester หา build ไม่เจอ); version ต้องมาจาก bump/tag จริง ไม่แต่ง
- **ผลตรวจอยู่ใน fix-log เป็น text** — RED/GREEN quote output จริง; scratch output ของ run ไม่ commit และไม่เข้า vault
- merge เป็น `--no-ff` (revert ง่าย); commit hash ใน fix-log = merge commit
- test fail → worktree เหลือไว้ + label คง `in progress` ให้ user แก้ต่อ
- base branch อ่านจาก config — ไม่ hardcode
- **UI bug:** สภาพผิดก่อนแก้ อ่านจาก issue ได้ แต่ **สภาพหลังแก้ต้องดูจาก build ที่ fix แล้วเสมอ** — มี before ต้องมี after คู่กัน (pairing invariant)
