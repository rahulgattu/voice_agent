---
applyTo: "src/**/*.py"
---

- Type every function.
- Use Pydantic v2 at boundaries.
- Use database sessions only through `core/tenancy/db.py`.
- Use typed exceptions from `core/errors.py`.
- Bind structlog with `tenant_id` and `call_id`.
- Use UTC-aware datetimes only.
- Do not use `print`, bare `except`, or `time.sleep` in async code.
