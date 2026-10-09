# ReceptionistAI

ReceptionistAI is a multi-tenant AI receptionist for small service businesses, starting with roofing and supporting web chat followed by inbound voice through one shared agent runtime.

## Prerequisites

- Git
- Docker
- [uv](https://docs.astral.sh/uv/)
- VS Code with GitHub Copilot

## Setup

```sh
uv sync
copy .env.example .env
uv run pre-commit install
uv run pytest
```

## Repository map

The system design and package layout are documented in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md). Decisions live in [docs/DECISIONS.md](docs/DECISIONS.md), and the ordered work plan is in [docs/TASKS.md](docs/TASKS.md).

## Copilot workflow

Work on one subtask from `docs/TASKS.md` per chat. Before writing code, list the files, dependencies, and Done checks and wait for approval. Follow the persistent rules in `.github/copilot-instructions.md` and the applicable path-specific instructions. Run every Done command, paste its real output, and stop when the subtask is complete.

## Phases

Phase 0 establishes the foundation and local environment. Phase 1 adds data and tenancy. Phase 2 builds the text agent runtime. Phase 3 adds web chat. Phase 4 adds voice. Later phases cover production hardening, deployment, and operations.
