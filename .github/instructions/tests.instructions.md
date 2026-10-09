---
applyTo: "tests/**"
---

- Use pytest and pytest-asyncio.
- Name tests `test_<behavior>_<condition>`.
- Unit tests use fakes.
- The isolation test discovers tables from `information_schema`.
- Put scenario tests in `tests/scenarios/*.yaml`.
- Do not use sleeps for synchronous tests.
- A skipped or flaky test is a failing test.
