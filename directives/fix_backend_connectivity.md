# Directive: Fix Backend Connectivity

## Objective
Resolve the "Failed to fetch" errors reported by the frontend by ensuring the FastAPI backend is running and reachable on `http://localhost:8000`.

## Inputs
- Frontend error logs showing `ClientException: Failed to fetch`.
- Backend source code in `backend/`.

## Success Criteria
- [x] Backend is running on port 8000.
- [x] `http://localhost:8000/` returns a healthy status.
- [x] `UserUpdateRequest` model supports `device_token` (fixed a related bug found during analysis).

## Execution Flow
1. Check if port 8000 is occupied.
2. If free, start the backend server using `uvicorn main:app --host 0.0.0.0 --port 8000`.
3. Validate connectivity using `execution/check_backend_health.py`.
4. Patch `backend/app/models/user.py` to include `device_token` to prevent future validation errors during token synchronization.

## Failure Handling
- If port 8000 is occupied by another process, identify and terminate it or choose a different port (requires frontend update).
- If dependencies are missing, run `pip install -r requirements.txt`.

## Evolution History
- 2026-04-29: Initial resolution. Started server and fixed `device_token` model mismatch.
