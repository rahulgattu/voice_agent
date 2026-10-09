1. **Purpose.** Multi-tenant AI receptionist for small service businesses. First vertical: roofing. Channels: web chat, then inbound voice. One deployment serves many clients.
2. **Context.** Caller to Telnyx to `voice_transport`. Visitor to widget to `api/chat_gateway`. Both feed one `agent_runtime`, which uses `pipeline` (STT, LLM, TTS), `integrations` (calendar, SMS, email), and `analytics`, all backed by PostgreSQL (RLS) and Redis. The owner dashboard reads RLS-scoped metric views.
3. **Tenancy.** One database. Forced RLS on every tenant table. Roles `migrator` and `app_user`. Each transaction runs `SET LOCAL app.tenant_id`. Tenant is unknown at the start of a call, so resolution uses `SECURITY DEFINER` functions (`resolve_tenant_by_number`, `resolve_tenant_by_site_key`) that return only a tenant id. The isolation test discovers tables from `information_schema` and proves tenant A cannot SELECT, UPDATE, or DELETE tenant B rows. It runs in CI.
4. **Config.** `core defaults`, then `verticals/<vertical>/`, then `tenants/<slug>/tenant.yaml`. Later layers override earlier. Pydantic validates the merged result. Invalid config fails at load, never mid-call. No secrets in config.
5. **Voice flow.** Resolve tenant from dialed number (unknown or kill switch routes to fallback number). Compute `after_hours`. Open `calls` row. Speak disclosure. STT, LLM, tools, TTS streaming. Every tool call is a `call_events` row. On end: close the row, enqueue QA scoring and owner notification.
6. **Chat flow.** Widget connects with a public site key. Gateway checks site key and Origin, rate limits in Redis, enforces caps, opens a session on the same runtime with channel `web_chat`.
7. **Failure modes.** Service down: carrier-level fallback forwards to owner phone or voicemail. Kill switch: straight to a human. Calendar down: take a callback request, save the lead. LLM timeout: one retry, then apologize and take a callback request. Transfer unanswered: take a message, alert owner. Cap reached: graceful message, owner alert, route to human. Duplicate webhook: idempotent.
8. **Deployment.** One VPS per environment: Caddy to api, worker, Postgres, Redis in docker compose. Workers are stateless. Per-tenant concurrency caps in Redis.
9. **Observability.** structlog JSON with `tenant_id` and `call_id`, Sentry, Langfuse, per-call time-to-first-audio and cost. Alerts: outage, error spike, tenant at 80 percent of cap.
10. **Portability.** Vendor code stays in adapters. Voice framework stays in `voice_transport/`. Server address and keys from env. Infra setup scripted in `infra/`, never clicked.
11. **Out of scope.** Outbound calling, price quotes, claim negotiation, payments, multi-location routing, CRM sync, multiple live agents, voice cloning.

## 3. Folder tree

```text
receptionistai/
├── .github/
│   ├── copilot-instructions.md
│   ├── instructions/            # path-specific Copilot rules
│   └── workflows/               # CI, deploy (added in 0.3, 6.0)
├── docs/
│   ├── ARCHITECTURE.md  DECISIONS.md  TASKS.md  schema.md
│   ├── adr/                     # one file per design decision
│   └── runbooks/                # per-client and incident runbooks
├── src/receptionistai/
│   ├── core/
│   │   ├── tenancy/             # db session + tenant context, resolver, config loader/merge
│   │   ├── telephony/           # TelephonyProvider + Telnyx adapter
│   │   ├── voice_transport/     # the ONLY place that imports LiveKit or Pipecat
│   │   ├── pipeline/            # STTProvider, TTSProvider, LLMProvider + adapters + fakes
│   │   ├── agent_runtime/       # flow engine, slots, guardrails, tool dispatch, disclosure
│   │   ├── integrations/        # CalendarProvider, SmsProvider, EmailProvider + fakes
│   │   ├── analytics/           # call logging, QA scoring, metric views
│   │   ├── billing/             # usage metering, caps
│   │   └── errors.py  settings.py  logging.py
│   ├── api/                     # FastAPI: chat gateway, webhooks, owner dashboard, health
│   └── workers/                 # Arq jobs: QA scoring, reports, retries
├── verticals/roofing/           # flow.yaml, prompts/, tools.yaml, kb_seed/
├── tenants/                     # <slug>/tenant.yaml (no secrets)
├── widget/                      # embeddable chat widget (static JS)
├── migrations/                  # Alembic
├── infra/                       # voice transport + Telnyx setup scripts (idempotent)
├── deploy/                      # Dockerfile, compose.dev.yml, compose.prod.yml, Caddyfile
├── scripts/                     # healthcheck, env check, seed
├── tests/                       # unit/, integration/, isolation/, scenarios/
├── Makefile  pyproject.toml  requirements.txt  uv.lock  .env.example
├── .pre-commit-config.yaml  .python-version  .gitignore  README.md
```
