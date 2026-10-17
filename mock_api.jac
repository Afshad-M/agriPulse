"""agriPulse - Mock API / Canned Responses (owner: B).

Canned Plan data for demos when the real pipeline (api.jac) isn't wired up
yet, or when running offline without a seeded graph. All data is simulated.
Skeleton only - no logic yet.
"""

import from models { Plan }

def mock_baseline_plan() -> list[Plan] {
    # TODO(B): return a few canned Plan records for demo mode.
    return [];
}

def mock_merge_routes() -> list[Plan] {
    # TODO(B): canned merged-route demo data.
    return [];
}
