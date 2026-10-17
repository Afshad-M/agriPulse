"""agriPulse - Domain Graph Schema (owner: A).

Nodes and edges for the harvest-to-market logistics graph. Pure structure
only, no logic - see logic.jac (A) for scoring/planning and api.jac (A) for
the server contract that reads and writes this graph.

Farmer.language, Hub.district, Harvest.shelf_life_hours, Market.prices and
Truck.cost_per_km are additive fields (defaulted, so existing seed/test
code is unaffected) added so the real baseline computation (logic.jac) has
everything it needs on the graph itself rather than re-deriving it from
data.jac's lookup tables at read time.
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
        cost_per_km: float = 0.0;
}

node Plan {
    has status: str = "draft",
        created_at: str = "";
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
