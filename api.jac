"""agriPulse - Server Contract Endpoints (owner: A).

Public HTTP contract for scenario setup, baseline planning, route merging,
and replanning on events. Added alongside endpoints.jac (the template's
guestbook demo, left untouched) rather than replacing it - this module is
the new domain contract. Skeleton only: each endpoint will eventually seed
from data.jac (C) and delegate to logic.jac (A); for now they return
trivial stub values so the contract shape is fixed early.
"""

import from models { Plan }

def:pub load_seed() -> dict[str, int] {
    # TODO(A/C): attach data.jac's SEED_* records onto the graph via models.jac edges.
    return {"farmers": 0, "harvests": 0, "hubs": 0, "markets": 0, "trucks": 0};
}

def:pub baseline_plan() -> list[Plan] {
    # TODO(A): call logic.baseline_plan() over the seeded graph and persist the result.
    return [];
}

def:pub merge_routes() -> list[Plan] {
    # TODO(A): spawn logic.MergeRoutes and report the merged plans.
    return [];
}

def:pub replan_on_event(reason: str) -> list[Plan] {
    # TODO(A): spawn logic.ReplanOnEvent(reason=reason) and report the updated plans.
    return [];
}
