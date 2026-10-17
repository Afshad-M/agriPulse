"""agriPulse - Seed / Simulated Data (owner: C).

All data in this project is simulated. See docs/assumptions.md for the full
list of invented numbers. This module holds the representative
Farmer/Harvest/Hub/Market/Truck seed records that load_seed() (api.jac,
owner A) attaches to the graph, plus the route/link tables and crop
metadata A's loader needs to wire up the edges defined in models.jac
(DeliversTo, HubRoute, HubMarketRoute).

Linking convention (documented here since models.jac has no id fields):
- SEED_HARVESTS[i] belongs to SEED_FARMERS[i] - same index, parallel lists.
- SEED_FARMER_HUB_LINKS, SEED_HUB_ROUTES, SEED_HUB_MARKET_ROUTES key off
  the `name`/`plate` fields already on the nodes (the only identifying
  fields available), not synthetic ids.
"""

import from models { Farmer, Harvest, Hub, Market, Truck }

# ---------------------------------------------------------------------------
# Crops (reference data, not a models.jac node - available for logic.jac to
# use in scoring if useful; not required).
# ---------------------------------------------------------------------------

glob CROP_SHELF_LIFE_HOURS: dict[str, float] = {
    "tomato": 72.0,
    "beans": 48.0,
    "leafy_greens": 24.0,
    "carrot": 120.0
};

# ---------------------------------------------------------------------------
# Core seed records (exact models.jac fields).
# ---------------------------------------------------------------------------

glob SEED_HUBS: list[Hub] = [
    Hub(name="Dambulla Hub", capacity_kg=8000.0),
    Hub(name="Nuwara Eliya Hub", capacity_kg=4000.0),
    Hub(name="Kandy Hub", capacity_kg=6000.0),
    Hub(name="Matale Hub", capacity_kg=5000.0)
];

glob SEED_MARKETS: list[Market] = [
    Market(name="Dambulla Economic Centre", demand_kg=4000.0),
    Market(name="Colombo Manning Market", demand_kg=3200.0),
    Market(name="Kandy Market", demand_kg=2500.0)
];

glob SEED_TRUCKS: list[Truck] = [
    Truck(plate="WP CAB-1001", capacity_kg=1000.0),
    Truck(plate="CP CAB-1500", capacity_kg=1500.0),
    Truck(plate="MH CAB-2000", capacity_kg=2000.0)
];

# 12 farmers across Dambulla, Nuwara Eliya, Kandy and Matale. All names,
# phone numbers and harvest numbers are invented for this demo.
glob SEED_FARMERS: list[Farmer] = [
    Farmer(name="Kamal Perera",          phone="+94771234501", location="Dambulla"),
    Farmer(name="Nimal Silva",           phone="+94771234502", location="Dambulla"),
    Farmer(name="Sunil Fernando",        phone="+94771234503", location="Dambulla"),
    Farmer(name="Ranjan Gunawardena",    phone="+94771234504", location="Dambulla"),
    Farmer(name="Chaminda Rathnayake",   phone="+94771234505", location="Dambulla"),
    Farmer(name="Priyantha Jayasuriya",  phone="+94771234506", location="Nuwara Eliya"),
    Farmer(name="Mahinda Wickramasinghe",phone="+94771234507", location="Nuwara Eliya"),
    Farmer(name="Susantha Dissanayake",  phone="+94771234508", location="Kandy"),
    Farmer(name="Anura Bandara",         phone="+94771234509", location="Kandy"),
    Farmer(name="Gayan Senanayake",      phone="+94771234510", location="Matale"),
    Farmer(name="Nalin Kumara",          phone="+94771234511", location="Matale"),
    Farmer(name="Lasantha Weerasinghe",  phone="+94771234512", location="Matale")
];

# Parallel to SEED_FARMERS - SEED_HARVESTS[i] is SEED_FARMERS[i]'s harvest.
# harvested_at is a relative offset from the scenario's simulated "now"
# (e.g. "-1h" = harvested 1 hour before load time); logic.jac can parse
# this cheaply without a real calendar. The first five (Dambulla, tomato)
# are the merge-demo group - see DEMO_MERGE_SCENARIO below.
glob SEED_HARVESTS: list[Harvest] = [
    Harvest(crop="tomato", quantity_kg=180.0, harvested_at="-1h"),
    Harvest(crop="tomato", quantity_kg=150.0, harvested_at="-1h"),
    Harvest(crop="tomato", quantity_kg=200.0, harvested_at="-2h"),
    Harvest(crop="tomato", quantity_kg=160.0, harvested_at="-2h"),
    Harvest(crop="tomato", quantity_kg=190.0, harvested_at="-3h"),

    Harvest(crop="carrot", quantity_kg=300.0, harvested_at="-2h"),
    Harvest(crop="leafy_greens", quantity_kg=90.0, harvested_at="0h"),

    Harvest(crop="beans", quantity_kg=120.0, harvested_at="-5h"),
    Harvest(crop="leafy_greens", quantity_kg=70.0, harvested_at="-3h"),

    Harvest(crop="tomato", quantity_kg=140.0, harvested_at="-1h"),
    Harvest(crop="carrot", quantity_kg=250.0, harvested_at="-6h"),
    Harvest(crop="beans", quantity_kg=110.0, harvested_at="-4h")
];

# ---------------------------------------------------------------------------
# Relationships (additive - not a models.jac node, consumed by A's
# load_seed() to create DeliversTo/HubRoute/HubMarketRoute edges).
# ---------------------------------------------------------------------------

glob SEED_FARMER_HUB_LINKS: list[dict] = [
    {"farmer_name": "Kamal Perera", "hub_name": "Dambulla Hub"},
    {"farmer_name": "Nimal Silva", "hub_name": "Dambulla Hub"},
    {"farmer_name": "Sunil Fernando", "hub_name": "Dambulla Hub"},
    {"farmer_name": "Ranjan Gunawardena", "hub_name": "Dambulla Hub"},
    {"farmer_name": "Chaminda Rathnayake", "hub_name": "Dambulla Hub"},
    {"farmer_name": "Priyantha Jayasuriya", "hub_name": "Nuwara Eliya Hub"},
    {"farmer_name": "Mahinda Wickramasinghe", "hub_name": "Nuwara Eliya Hub"},
    {"farmer_name": "Susantha Dissanayake", "hub_name": "Kandy Hub"},
    {"farmer_name": "Anura Bandara", "hub_name": "Kandy Hub"},
    {"farmer_name": "Gayan Senanayake", "hub_name": "Matale Hub"},
    {"farmer_name": "Nalin Kumara", "hub_name": "Matale Hub"},
    {"farmer_name": "Lasantha Weerasinghe", "hub_name": "Matale Hub"}
];

# Hand-written distance/hours matrix, hub <-> hub.
glob SEED_HUB_ROUTES: list[dict] = [
    {"from_hub": "Dambulla Hub", "to_hub": "Matale Hub", "distance_km": 45.0, "hours": 1.2, "open": True},
    {"from_hub": "Dambulla Hub", "to_hub": "Kandy Hub", "distance_km": 72.0, "hours": 2.0, "open": True},
    {"from_hub": "Kandy Hub", "to_hub": "Matale Hub", "distance_km": 28.0, "hours": 0.8, "open": True},
    {"from_hub": "Kandy Hub", "to_hub": "Nuwara Eliya Hub", "distance_km": 77.0, "hours": 2.5, "open": True},
    {"from_hub": "Matale Hub", "to_hub": "Nuwara Eliya Hub", "distance_km": 95.0, "hours": 3.0, "open": True}
];

# Hand-written distance/hours matrix, hub -> market.
glob SEED_HUB_MARKET_ROUTES: list[dict] = [
    {"from_hub": "Dambulla Hub", "to_market": "Dambulla Economic Centre", "distance_km": 2.0, "hours": 0.1, "open": True},
    {"from_hub": "Dambulla Hub", "to_market": "Kandy Market", "distance_km": 72.0, "hours": 2.0, "open": True},
    {"from_hub": "Dambulla Hub", "to_market": "Colombo Manning Market", "distance_km": 148.0, "hours": 3.5, "open": True},
    {"from_hub": "Nuwara Eliya Hub", "to_market": "Kandy Market", "distance_km": 77.0, "hours": 2.5, "open": True},
    {"from_hub": "Nuwara Eliya Hub", "to_market": "Colombo Manning Market", "distance_km": 180.0, "hours": 5.0, "open": True},
    {"from_hub": "Nuwara Eliya Hub", "to_market": "Dambulla Economic Centre", "distance_km": 100.0, "hours": 3.0, "open": True},
    {"from_hub": "Kandy Hub", "to_market": "Kandy Market", "distance_km": 3.0, "hours": 0.15, "open": True},
    {"from_hub": "Kandy Hub", "to_market": "Colombo Manning Market", "distance_km": 115.0, "hours": 3.0, "open": True},
    {"from_hub": "Kandy Hub", "to_market": "Dambulla Economic Centre", "distance_km": 72.0, "hours": 2.0, "open": True},
    {"from_hub": "Matale Hub", "to_market": "Dambulla Economic Centre", "distance_km": 45.0, "hours": 1.2, "open": True},
    {"from_hub": "Matale Hub", "to_market": "Kandy Market", "distance_km": 28.0, "hours": 0.8, "open": True},
    {"from_hub": "Matale Hub", "to_market": "Colombo Manning Market", "distance_km": 140.0, "hours": 3.3, "open": True}
];

# ---------------------------------------------------------------------------
# Demo scenarios (for the merge and breakdown moments in the live demo).
# ---------------------------------------------------------------------------

glob DEMO_MERGE_SCENARIO: dict[str, any] = {
    "description": "Five Dambulla tomato farmers ship solo at baseline; merge_routes should pool them onto one truck (total well under the smallest truck's 1000kg capacity).",
    "farmer_names": ["Kamal Perera", "Nimal Silva", "Sunil Fernando", "Ranjan Gunawardena", "Chaminda Rathnayake"],
    "hub_name": "Dambulla Hub",
    "suggested_truck_plate": "WP CAB-1001",
    "suggested_market_name": "Kandy Market",
    "total_kg": 880.0
};

glob DEMO_BREAKDOWN_SCENARIO: dict[str, any] = {
    "description": "Fire truck_breakdown on WP CAB-1001 after the merge above to trigger ReplanOnEvent; CP CAB-1500 (Kandy Hub) or MH CAB-2000 (Matale Hub) are the spare-capacity alternatives.",
    "truck_plate": "WP CAB-1001",
    "affected_farmer_names": ["Kamal Perera", "Nimal Silva", "Sunil Fernando", "Ranjan Gunawardena", "Chaminda Rathnayake"]
};

# Sample free-text inputs for parse_harvest() (llm.jac) smoke-testing / demo.
glob PARSE_HARVEST_DEMO_INPUTS: list[str] = [
    "~200kg tomato ready tomorrow near Dambulla",
    "about 90 kilos of leafy greens, ready today, Kandy area",
    "300kg carrots, ready in 2 days, up country near Nuwara Eliya"
];
