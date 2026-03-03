# Redis Worker

This worker service is present in Docker Compose and runs `task_worker.py`, but it is not fully wired into the app flow yet.

## Current State

- The worker container starts and blocks on Redis queue `query_queue`.
- It executes SQL from queued tasks and writes results to `result:<task_id>`.
- Queue helper functions exist in `utils/redis_client.py`:
  - `enqueue_query(...)`
  - `get_query_result(...)`
- Dash callbacks still query MySQL directly via `utils.db.execute_query_with_date_range(...)`.
- No current app code enqueues jobs to `query_queue` or fetches async results from `result:<task_id>`.

## Feature TODO List

- [ ] Replace synchronous DB path in Dash callbacks with async queue workflow.
- [ ] Enqueue long-running graph queries using `enqueue_query(...)`.
- [ ] Add polling/interval callback in Dash to read `get_query_result(task_id)` and update UI when ready.
- [ ] Add loading/progress/error states for queued queries in UI.
- [ ] Move worker DB/Redis connection config to environment variables (`.env`) instead of hardcoded values in `task_worker.py`.
- [ ] Add structured logging in worker (task ID, query type, duration, failures).
- [ ] Add retry/backoff and dead-letter strategy for failed tasks.
- [ ] Add result TTL and cleanup policy for `result:*` keys.
- [ ] Add task schema validation/sanitization before executing SQL.
- [ ] Add integration test covering: enqueue -> process -> result retrieval.
- [ ] Document local verification commands for queue length, worker logs, and result keys.
