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

obj CargoScore {
    has loss: float,
        revenue: float,
        value: float;
}


def score_cargo(kg: float, price: float, elapsed_hours: float, shelf_life_hours: float, truck_cost: float) -> CargoScore {
    loss = 1.0;
    if shelf_life_hours > 0.0 {
        loss = min(1.0, elapsed_hours / shelf_life_hours);
    }
    revenue = kg * price * (1.0 - loss);
    value = revenue - truck_cost;
    return CargoScore(loss=loss, revenue=revenue, value=value);
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
