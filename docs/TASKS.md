Rules: one subtask at a time, in order. Done only when every check passes with real command output. Write `docs/schema.md` and ADRs as noted. Standard commands: `make setup`, `make check`, `make test`, `make up`, `make down`, `make migrate`, `make eval`.

**Phase 0: Foundation**

- **0.1 Scaffold.** Done: `make setup && make check` exits 0; `pre-commit run --all-files` exits 0; `uv.lock` committed and `uv sync --frozen` exits 0; no `.env` tracked.
- **0.2 Local environment.** Add: `sqlalchemy[asyncio]`, `asyncpg`, `redis`. Create `deploy/compose.dev.yml` (Postgres, Redis), `core/settings.py`, `scripts/healthcheck.py`, `scripts/check_env_example.py`. Done: `make up` healthy within 60 s; healthcheck prints `db ok` and `redis ok`; every settings field appears in `.env.example`.
- **0.3 CI.** Create `.github/workflows/ci.yml`. Done: runs `make check` on push and PR; runs migrations up, down, up against service containers; a deliberately failing test turns CI red (link, then delete the branch).
- **0.4 Container build and local production run.** Add: `fastapi`, `uvicorn[standard]`, dev `httpx`. Create Dockerfile (multi-stage, non-root), `deploy/compose.prod.yml`, `/healthz`, `/readyz`. Done: image builds and runs as non-root; `curl http://localhost:8000/readyz` returns 200 with `db: ok`, `redis: ok`; tests cover the Redis-down case.

**Phase 1: Data and tenancy**

- **1.1 Schema.** Add: `alembic`. Tables: tenants, phone_numbers, site_keys, calls, call_events, leads, appointments, consents, usage_records, kb_documents (tsvector). Done: migrate, downgrade base, migrate all exit 0; test proves every tenant-owned table has NOT NULL `tenant_id`, FK, and index; `docs/schema.md` lists every table.
- **1.2 RLS and isolation proof.** Done: RLS enabled and forced on every tenant table; `app_user` is not superuser and has no BYPASSRLS; with tenants A and B seeded, A cannot SELECT, UPDATE, or DELETE B rows in any table (tables discovered from `information_schema`); no tenant context returns zero rows; runs in CI.
- **1.3 Config system.** Done: merge order unit-tested; invalid YAML fails at load naming file and field; adding a second example tenant needs YAML only; business-hours helper correct across midnight, closed day, and DST.
- **1.4 Tenant resolver.** Done: known number and site key resolve; unknown returns a typed result, never ends the call; disallowed Origin rejected; `app_user` cannot read `phone_numbers` or `site_keys` without context.

**Phase 2: Agent runtime (text only)**

- **2.1 LLM adapter.** Add: `anthropic`. Done: model names from settings and checked against Anthropic docs (link in ADR); timeout, one retry, cost accounting tested with a fake; `make test` passes offline.
- **2.2 Flow engine and roofing flow.** Call types: new_inspection, storm_damage, emergency_leak, insurance_question, job_status, general_faq, vendor_spam, human_request. Done: unit tests for slot filling, read-back, unknown intent; prompt version stored per call; emergency flow collects only name, address, number.
- **2.3 Tools with fakes.** Tools: check_availability, book_inspection, create_lead, send_sms, notify_owner, transfer_call, lookup_faq. Done: every call validated, tenant-scoped, logged to `call_events`; calendar failure yields a callback request and the lead is saved; partial lead saved on dropped session; `send_sms` refuses without consent; `lookup_faq` returns nothing for unknown topics.
- **2.4 Guardrails and CLI.** Done: disclosure is the first message; one test each for price request, insurance promise, prompt injection, off-topic, anger, emergency, safety advice; none skipped.
- **2.5 Scenario suite.** Done: 25 to 30 scenarios cover every call type, Spanish switch, refused address, silence, dropped session, repeat caller, full calendar, each guardrail; `make eval` prints pass or fail per scenario; guardrails 100 percent, overall at least 90 percent, result in an ADR.

**Phase 3: Web chat**

- **3.1 Chat gateway.** Done: tests for allowed origin, blocked origin, rate limit, cap reached, oversized message, malformed JSON; cap reached sends a polite message and an owner alert.
- **3.2 Widget.** Done: one `<script data-site-key>` works on a plain HTML page and one WordPress or Wix test page; shows AI disclosure and privacy link; usable at 360 px; under 30 KB gzipped.
- **3.3 Lead delivery and consent.** Add: `resend`, `arq`. Done: a captured lead emails the owner within 60 s; consent row stored only after explicit opt-in; deleting a lead removes its transcripts and consents.

**Phase 4: Voice**

- **4.1 Framework spike (GATED: O06, O07).** Add: chosen framework and plugins only, per current docs. Done: both candidates complete 20 scripted inbound calls; ADR table with time-to-first-audio median and p95, failures, setup effort; choice follows G01; loser deleted; trunk setup is one idempotent script run twice without error.
- **4.2 Telephony adapter.** Done: a real call reaches the runtime; tenant resolved from dialed number; same `calls` and `call_events` schema as chat; duplicate webhooks create no duplicate rows.
- **4.3 STT and TTS adapters.** Done: each candidate tested on 10 English and 10 Spanish recorded calls with results in an ADR; provider chosen per language in config only.
- **4.4 Latency.** Done: every call stores time-to-first-audio; a query reports median and p95 over the last 50 calls; owner writes D20 from the numbers; barge-in, silence, noisy audio documented in `docs/runbooks/voice-quality.md`.
- **4.5 Failover, kill switch, caps.** Done: with the api stopped, a call reaches the fallback phone or voicemail; kill switch routes the next call to a human within 5 s; unanswered transfer takes a message and alerts the owner; concurrency and spend caps each block the next call gracefully.
- **4.6 Google Calendar adapter.** Add: `google-api-python-client`, `google-auth-oauthlib`, `cryptography`. Done: reads availability, books, handles API errors; credentials encrypted at rest and absent from logs (test greps captured logs); end-to-end real call books a real slot.
- **4.7 SMS adapter (GATED: O06, client 10DLC approval).** Done: script creates one brand and one campaign for a test tenant; sends only after approval and only with consent; STOP creates a revoked consent and blocks further texts.

**Phase 5: Analytics and cost**

- **5.1 Logging and QA scoring.** Add: `langfuse`. Done: every finished call has a QA row within 2 minutes; a review command lists flagged calls.
- **5.2 Metric views.** Views: calls_answered, leads_captured, inspections_booked, after_hours_caught, booking_rate, call_type_mix, calls_per_day, estimated_pipeline_value. Done: correct on a seeded dataset with hand-computed expectations; RLS respected (isolation test extended).
- **5.3 Cost metering.** Done: cost per call, per tenant per month, and margin versus configured price; one alert at 80 percent of cap.

**Phase 6: Ship per client**

- **6.0 Staging deploy (GATED: O02).** Done: `https://STAGING_DOMAIN/readyz` returns 200; rollback executed once; only ports 80, 443, SSH open.
- **6.1 Backups, restore, alerting.** Add: `sentry-sdk`. Done: restore from last night's backup into a fresh database, row counts match, output pasted; stopping the api alerts the owner's phone within 5 minutes.
- **6.2 Owner dashboard.** Add: `jinja2` plus one charting library chosen in the ADR. Done: an owner sees only their tenant (isolation test extended to dashboard routes); magic link expires in 15 minutes and works once; usable at 360 px; no raw technical terms.
- **6.3 Weekly impact report.** Done: scheduled email per tenant in the tenant timezone; delivery logged; three retries, then operator alert.
- **6.4 Client rollout kit (GATED: O05, O06).** Done: rollout checklist (shadow, after-hours, overflow, primary) with exit criteria; per-client runbook (how to disable, who to call, where logs are); service agreement draft for lawyer review; first client onboarded by tenant YAML, a number, and credentials only.
