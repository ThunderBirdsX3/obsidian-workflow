# Test credentials — scaffold, request, mask

Config schema (`.ow.yml` → `test_credentials`): `env_file` (default `.env.test`, gitignored),
`example_file` (default `.env.test.example`, committed), `roles` (`[{label, user_var, pass_var}]`),
`redact` (default `true`). `ow-paths.sh` resolves `$TEST_ENV_FILE` and `$CRED_REDACT` directly;
`example_file` and `roles` live only in `$TEST_CREDENTIALS_JSON` (schema-level, absent ⇒ `{}`) —
derive them with jq, never re-parse `.ow.yml` yourself:

```bash
EXAMPLE_FILE=$(echo "$TEST_CREDENTIALS_JSON" | jq -r --arg d "${TEST_ENV_FILE}.example" '.example_file // $d')
ROLES=$(echo "$TEST_CREDENTIALS_JSON" | jq -c '.roles // []')
```

## The rule

🔴 **Never invent a test user's username or password.** A test user is a real row in a real
system (a seeded DB account, a staging login) — a value you make up does not exist anywhere,
so anything that later reads `$TEST_ENV_FILE` fails against it. This applies whether the file
is being scaffolded, filled in, or read back for a run.

- A role in `roles[]` has no value yet → **ask the user** for that role's real test user
  (or how to seed one) — do not fill it with a placeholder that looks like a real credential
- No `roles[]` defined and the user asks to "add a test user" → ask what the login flow calls
  it (env var names) before writing anything, so the schema and the file agree
- `$CRED_REDACT` (default `true`) → mask every value read from `$TEST_ENV_FILE` before it
  reaches a log, report, or vault doc — same masking level as a secret/PII finding

## Scaffold `$EXAMPLE_FILE` from `$ROLES`

One block per role, values left blank — this file is committed as the shape of the schema,
never as real credentials:

```
# <label>
<user_var>=
<pass_var>=
```

`$TEST_ENV_FILE` itself is never scaffolded with guessed values — either the user supplies
them, or the role stays blank in the example and unset in the real file.

## Gitignore

`$TEST_ENV_FILE` must be in `.gitignore`; `$EXAMPLE_FILE` must not be — a scan that finds
`$TEST_ENV_FILE` tracked by git is a leak, same severity as a committed `.env.production`.
