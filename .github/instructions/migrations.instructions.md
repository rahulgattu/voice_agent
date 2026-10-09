---
applyTo: "migrations/**"
---

- Use Alembic.
- Make one change per migration.
- Every migration must have a working downgrade.
- For every new tenant table, verify: `tenant_id NOT NULL` with a foreign key, an index, `ENABLE` and `FORCE` RLS, a policy on `current_setting('app.tenant_id', true)::uuid`, and minimal grants to `app_user`.
- Never edit a merged migration.
