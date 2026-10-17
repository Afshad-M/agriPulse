"""agriPulse - Deterministic Planning Logic (owner: A).

Scoring, baseline assignment, route merging, and replanning. This is plain
deterministic code - it never delegates a numeric computation to an LLM
(see CLAUDE.md and llm.jac). Skeleton only: stubs return trivial defaults
until the scoring/assignment rules are implemented.
"""

import from models { Harvest, Hub, Plan }

def score_route(distance_km: float, hours: float, open: bool) -> float {
    # TODO(A): deterministic scoring formula over distance/hours/open.
    return 0.0;
}

def baseline_plan(harvests: list[Harvest], hubs: list[Hub]) -> list[Plan] {
    # TODO(A): deterministic baseline harvest-to-hub assignment.
    return [];
}

walker MergeRoutes {
    """Consolidate overlapping hub<->market routes into merged Plan(s)."""
    has reports: list[Plan] = [];

    can run with Root entry {
        # TODO(A): merge/consolidate overlapping routes.
        skip;
    }
}

walker ReplanOnEvent {
    """Recompute the plan after a disruption event (e.g. a closed route)."""
    has reason: str = "",
        reports: list[Plan] = [];

    can run with Root entry {
        # TODO(A): recompute plan after self.reason disrupts the graph.
        skip;
    }
}
