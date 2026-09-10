# /ow-secure

> **Security pre-flight** — scan secrets, PII, vault-language + vault present-tense gate, quoted-output masking, public-repo, dependency CVE, prod guardrails

[← กลับ usage/README](./README.md) · [Full spec: `.ow/commands/ow-secure.md`](../.ow/commands/ow-secure.md)

## เมื่อไหร่ใช้

- ก่อน `/ow-git` commit/push — เด็ดขาดก่อนส่ง code
- ก่อนส่งมอบ — มี secret/PII หลุดใน output ที่ quote ลง vault ไหม
- ก่อน `/ow-verify` handoff — pre-flight check
- ตอน adopt repo เดิม (brownfield) — สแกน hidden secrets

## Quick start

```
/ow-secure
```

ตัวอย่าง output:
```
Security pre-flight
===================
✅ Secret scan: clean (5 files scanned)
✅ PII scan: clean (12 docs scanned)
✅ Vault language gate: clean (2 new/modified vault files, VAULT_LANG=en)
✅ Vault present-tense gate: clean (2 new/modified vault files scanned)
🟡 Quoted output: 2 unmasked values in quoted logs
   - docs/obsidian-vault/85-FixLog/2026-05-20-1430-search.md:41
✅ Public-repo guardrails: ok
🟡 npm audit: 3 high-severity (express@4.17 → 4.19)
✅ Production guardrails: ok

Verdict: REVIEW NEEDED (2 yellow)
```

## รูปแบบเต็ม

```
/ow-secure                    # full scan (all 8 phases)
/ow-secure secrets            # secrets only
/ow-secure pii                # PII only
/ow-secure --since <ref>      # scan diff since ref
```

## ขั้นตอนภายใน (Phase summary)

1. **Phase 1** — Secret scan (AWS, GitHub PAT, Anthropic/OpenAI keys, Slack, Google, generic) → BLOCK ถ้าเจอ
2. **Phase 2** — PII scan in `docs/` (Thai citizen ID, phone, email, HN/VN/AN) → BLOCK ถ้าไม่ mask
3. **Phase 2.5** — Vault language gate (#33): เมื่อ `vault_language != project.language` → grep ไฟล์ vault ที่ new/modified (diff since HEAD + untracked) หา script ของภาษาแชทที่หลุดเข้ามาใน prose → BLOCK ถ้าเจอ (`scripts/ow-verify-vault-lang.sh`)
4. **Phase 2.6** — Vault present-tense gate: เอกสารใน vault นอก `80-ImplementPlan` / `85-FixLog` / `90-TestPlan` / `95-Handoff` ต้องเขียนสถานะปัจจุบันอย่างเดียว → grep ไฟล์ vault ที่ new/modified หา "เดิม X → ใหม่ Y" / `changed from … to …` / หัวข้อ `## Changelog` → BLOCK ถ้าเจอ (`scripts/ow-verify-vault-style.sh` · สัญญาอยู่ที่ `.ow/commands/_shared/vault-doc-style.md`)
5. **Phase 3** — Quoted-output masking check (fenced blocks ใน fix-log / test-plan / handoff)
6. **Phase 4** — Public-repo guardrails (confidential tags, NDA, customer name)
7. **Phase 5** — Dependency CVE quick-check (`npm audit`, `pip list --outdated`, `cargo audit`)
8. **Phase 6** — Production-write guardrails (`.env.production`, prod config, deploy script)
9. **Phase 7** — Report + verdict (ALL GREEN / REVIEW NEEDED / BLOCKED)

## Verdict matrix

| Verdict | Action |
|---|---|
| ✅ ALL GREEN | OK to commit/handoff |
| 🟡 REVIEW NEEDED | แก้/justify ก่อน proceed |
| ❌ BLOCKED | ห้าม commit — ต้องแก้ก่อน |

## Output ที่ได้

- Console report (verdict + findings table)
- **ไม่แก้ไฟล์** — read-only scan

## Secret patterns ที่ scan

- `AKIA[0-9A-Z]{16}` — AWS access key
- `-----BEGIN [A-Z ]+ PRIVATE KEY-----` — RSA/EC private keys
- `ghp_[A-Za-z0-9]{36,}` — GitHub PAT
- `sk-[A-Za-z0-9]{32,}` — Anthropic/OpenAI keys
- `xox[bpoa]-[0-9a-zA-Z-]{10,}` — Slack token
- `AIza[0-9A-Za-z-_]{35}` — Google API key
- Generic: `password|secret|api_key|token = "..."` (≥ 8 chars)

## PII patterns (Thai-specific)

- `[0-9]-[0-9]{4}-[0-9]{5}-[0-9]{2}-[0-9]` — Thai citizen ID
- 10-digit phone number
- Email regex
- `(HN|VN|AN)[0-9]{6,}` — hospital numbers

## Workflow ที่นิยม

ตัวอย่าง 1: pre-commit
```
1. /ow-implement <plan>
2. /ow-secure                  ← คุณอยู่ที่นี่
   → ✅ ALL GREEN
3. /ow-git --plan <path>
```

ตัวอย่าง 2: pre-handoff
```
1. /ow-secure
   → 🟡 REVIEW: 2 unmasked values ใน quoted output
2. แก้เอกสาร: mask ค่าที่หลุดใน fix-log/test-plan
3. /ow-secure
   → ✅ ALL GREEN
4. /ow-verify
```

ตัวอย่าง 3: diff-scoped
```
/ow-secure --since main
  → scan เฉพาะ diff vs main branch
```

## Gotchas / ข้อควรระวัง

- 🚫 **ห้ามรัน scan โดย skip files** — transparent, list ทุก file ที่ scan
- 🚫 **ห้าม fix secrets เอง** — แจ้ง user ให้ revoke + rotate (AI ไม่ควรรู้ secret value)
- 🚫 ห้าม commit ถ้า BLOCKED — ต้องผ่าน manual override + log reason
- ⚠️ Secret patterns ไม่ครอบคลุม custom secrets (เช่น internal token format) — manual review ด้วย
- ⚠️ PII regex อาจ false-positive (เช่น 10-digit timestamp) — verify ก่อน block
- ⚠️ `npm audit` อาจ noisy — focus high/critical
- 💡 ทุก verdict yellow ก็ block `/ow-verify` handoff — ต้องแก้ก่อน

## Related

- ก่อน `/ow-secure`: [/ow-implement](./ow-implement.md), [/ow-test](./ow-test.md)
- หลัง `/ow-secure`: [/ow-git](./ow-git.md), [/ow-verify](./ow-verify.md)
- Embedded ใน: [/ow-verify](./ow-verify.md) Phase 5
- Rules: `.ow/rules/security.md` (resolver `ow-paths.sh --rules security`)

## FAQ

**Q: ถ้าเจอ secret ใน .git history เก่า?**
A: `/ow-secure` แค่ flag — ต้อง rotate credential + `git filter-repo` แยกต่างหาก

**Q: PII Thai pattern คลุม ID อื่นๆ ไหม?**
A: คลุม citizen ID, phone, email, hospital number ถ้ามี custom pattern → extend ใน `.ow/commands/ow-secure.md` patterns array

**Q: ใช้ตัวเดียวกับ pre-commit hook ได้ไหม?**
A: ได้ — `bash <path>/.ow/scripts/secure.sh` (ถ้า project มี) หรือ `/ow-secure --since HEAD` ใน hook
