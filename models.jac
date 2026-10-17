"""agriPulse - Domain Graph Schema (owner: A).

Nodes and edges for the harvest-to-market logistics graph. Pure structure
only, no logic - see logic.jac (A) for scoring/planning and api.jac (A) for
the server contract that reads and writes this graph.
"""

node Farmer {
    has name: str,
        phone: str = "",
        location: str = "";
}

node Harvest {
    has crop: str,
        quantity_kg: float = 0.0,
        harvested_at: str = "";
}

node Hub {
    has name: str,
        capacity_kg: float = 0.0;
}

node Market {
    has name: str,
        demand_kg: float = 0.0;
}

node Truck {
    has plate: str,
        capacity_kg: float = 0.0;
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
