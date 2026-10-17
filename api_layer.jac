"""agriPulse - Client API Layer (owner: B).

Thin wrappers the UI calls to reach the server contract (api.jac, owner A),
so components never await api.jac functions directly and swapping in
mock_api.jac for a demo is a one-line change. Skeleton only - no logic yet.
"""

import from models { Plan }

async def fetch_baseline_plan() -> list[Plan] {
    # TODO(B): await the real api.baseline_plan(), or fall back to mock_api.
    return [];
}

async def fetch_merge_routes() -> list[Plan] {
    # TODO(B): await api.merge_routes().
    return [];
}

async def fetch_replan(reason: str) -> list[Plan] {
    # TODO(B): await api.replan_on_event(reason).
    return [];
}
