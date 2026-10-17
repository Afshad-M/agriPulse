"""agriPulse - Domain Graph Schema (owner: A).

Nodes and edges for the harvest-to-market logistics graph. Pure structure
only, no logic - see logic.jac (A) for scoring/planning and api.jac (A) for
the server contract that reads and writes this graph.

Farmer.language, Hub.district, Harvest.shelf_life_hours, Market.prices and
Truck.cost_per_km are additive fields (defaulted, so existing seed/test
code is unaffected) added so the real baseline computation (logic.jac) has
everything it needs on the graph itself rather than re-deriving it from
data.jac's lookup tables at read time. Plan's additive fields do the same
job for the "current plan" (baseline or merged routes) that merge_routes()
persists - see docs/assumptions.md. Truck.status is additive too, but is
never seeded - it starts "available" and is only ever flipped to "broken"
by replan_on_event()'s truck_breakdown handling (logic.jac); load_seed()
resets it by rebuilding Truck nodes from scratch.
"""

node Farmer {
    has name: str,
        phone: str = "",
        location: str = "",
        language: str = "";
}

node Harvest {
    has crop: str,
        quantity_kg: float = 0.0,
        harvested_at: str = "",
        shelf_life_hours: float = 0.0;
}

node Hub {
    has name: str,
        capacity_kg: float = 0.0,
        district: str = "";
}

node Market {
    has name: str,
        demand_kg: float = 0.0,
        prices: dict[str, float] = {};   # LKR per kg, keyed by crop
}

node Truck {
    has plate: str,
        capacity_kg: float = 0.0,
        cost_per_km: float = 0.0,
        status: str = "available";   # "available" | "broken" - set by replan_on_event()
}

node Plan {
    """The persisted 'current plan' - one Plan per current route (baseline
    or merged). merge_routes() (logic.jac/api.jac) wipes and rewrites all
    Plan nodes each call; a later replan step is meant to read/update them
    rather than recompute from scratch. Fields beyond status/created_at
    are additive (defaulted) and mirror a route+plan pair 1:1 so this one
    node is enough to answer State.routes/State.plans for the current plan."""
    has status: str = "draft",
        created_at: str = "",
        route_id: str = "",
        truck_id: str = "",
        farmer_ids: list[str] = [],
        hub_ids: list[str] = [],
        market_id: str = "",
        distance_km: float = 0.0,
        hours: float = 0.0,
        spoilage_pct: float = 0.0,
        expected_income: float = 0.0,
        truck_cost: float = 0.0;
}

edge DeliversTo: Farmer --> Hub {}

edge HubRoute: Hub --> Hub {
    has distance_km: float = 0.0,
        hours: float = 0.0,
        open: bool = True;
}

edge HubMarketRoute: Hub --> Market {
    has distance_km: float = 0.0,
        hours: float = 0.0,
        open: bool = True;
}

edge Assignment: Truck --> Plan {}
