"""agriPulse - Seed / Simulated Data (owner: C).

All data in this project is simulated. See docs/assumptions.md for the full
list of invented numbers.

Two seed shapes live here, for two different consumers:

1. The original models.jac-node shape (SEED_FARMERS, SEED_HARVESTS, ...) -
   for attaching onto the persisted graph (Farmer/Harvest/Hub/Market/Truck
   nodes + DeliversTo/HubRoute/HubMarketRoute edges), if/when load_seed()
   builds the graph directly.
2. The newer CONTRACT v1 shape (SEED_FARMER_RECORDS, SEED_HARVEST_RECORDS,
   ...), added once api.jac defined FarmerInfo/HarvestInfo/HubInfo/
   MarketInfo/TruckInfo (richer: ids, per-crop prices, shelf life per
   harvest). These are plain list[dict], not api.jac's obj types - data.jac
   deliberately does NOT import from api.jac to avoid a circular import
   (api.jac's load_seed() is meant to import FROM data.jac). load_seed()
   builds each FarmerInfo(...)/etc. from these dicts' exact field names.

Both describe the same 12 farmers/4 hubs/3 markets/3 trucks; A picks
whichever shape fits however load_seed() ends up implemented.

Linking convention (documented here since models.jac has no id fields):
- SEED_HARVESTS[i] belongs to SEED_FARMERS[i] - same index, parallel lists.
- SEED_FARMER_HUB_LINKS, SEED_HUB_ROUTES, SEED_HUB_MARKET_ROUTES key off
  the `name`/`plate` fields already on the nodes (the only identifying
  fields available), not synthetic ids.
- In the CONTRACT v1 section, SEED_HARVEST_RECORDS[i]["farmerId"] always
  matches SEED_FARMER_RECORDS[i]["id"] (same index too, same reason).
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

glob SEED_FARMER_HUB_LINKS: list[dict[str, any]] = [
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
glob SEED_HUB_ROUTES: list[dict[str, any]] = [
    {"from_hub": "Dambulla Hub", "to_hub": "Matale Hub", "distance_km": 45.0, "hours": 1.2, "open": True},
    {"from_hub": "Dambulla Hub", "to_hub": "Kandy Hub", "distance_km": 72.0, "hours": 2.0, "open": True},
    {"from_hub": "Kandy Hub", "to_hub": "Matale Hub", "distance_km": 28.0, "hours": 0.8, "open": True},
    {"from_hub": "Kandy Hub", "to_hub": "Nuwara Eliya Hub", "distance_km": 77.0, "hours": 2.5, "open": True},
    {"from_hub": "Matale Hub", "to_hub": "Nuwara Eliya Hub", "distance_km": 95.0, "hours": 3.0, "open": True}
];

# Hand-written distance/hours matrix, hub -> market.
glob SEED_HUB_MARKET_ROUTES: list[dict[str, any]] = [
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

# =============================================================================
# CONTRACT v1 (api.jac) seed records - plain dicts, field names match
# FarmerInfo/HarvestInfo/HubInfo/MarketInfo/TruckInfo exactly (camelCase per
# api.jac's own convention). Money is LKR, per api.jac's docstring. Intended
# drop-in replacement for api.jac's _placeholder_state() farmers/harvests/
# hubs/markets/trucks lists in load_seed().
# =============================================================================

glob SEED_FARMER_RECORDS: list[dict[str, any]] = [
    {"id": "f1",  "name": "Kamal Perera",           "district": "Dambulla",    "language": "si"},
    {"id": "f2",  "name": "Nimal Silva",             "district": "Dambulla",    "language": "si"},
    {"id": "f3",  "name": "Sunil Fernando",          "district": "Dambulla",    "language": "si"},
    {"id": "f4",  "name": "Ranjan Gunawardena",      "district": "Dambulla",    "language": "si"},
    {"id": "f5",  "name": "Chaminda Rathnayake",     "district": "Dambulla",    "language": "si"},
    {"id": "f6",  "name": "Priyantha Jayasuriya",    "district": "Nuwara Eliya","language": "ta"},
    {"id": "f7",  "name": "Mahinda Wickramasinghe",  "district": "Nuwara Eliya","language": "ta"},
    {"id": "f8",  "name": "Susantha Dissanayake",    "district": "Kandy",       "language": "si"},
    {"id": "f9",  "name": "Anura Bandara",           "district": "Kandy",       "language": "si"},
    {"id": "f10", "name": "Gayan Senanayake",        "district": "Matale",      "language": "si"},
    {"id": "f11", "name": "Nalin Kumara",            "district": "Matale",      "language": "si"},
    {"id": "f12", "name": "Lasantha Weerasinghe",    "district": "Matale",      "language": "si"}
];

# Parallel to SEED_FARMER_RECORDS - SEED_HARVEST_RECORDS[i].farmerId ==
# SEED_FARMER_RECORDS[i].id. readyHour = hours from scenario start until
# the harvest is ready for pickup (0 = ready now). The first five
# (Dambulla, tomato) are the merge-demo group.
glob SEED_HARVEST_RECORDS: list[dict[str, any]] = [
    {"id": "h1",  "farmerId": "f1",  "crop": "tomato",        "kg": 180.0, "readyHour": 1.0, "shelfLifeHours": 72.0},
    {"id": "h2",  "farmerId": "f2",  "crop": "tomato",        "kg": 150.0, "readyHour": 1.0, "shelfLifeHours": 72.0},
    {"id": "h3",  "farmerId": "f3",  "crop": "tomato",        "kg": 200.0, "readyHour": 2.0, "shelfLifeHours": 72.0},
    {"id": "h4",  "farmerId": "f4",  "crop": "tomato",        "kg": 160.0, "readyHour": 2.0, "shelfLifeHours": 72.0},
    {"id": "h5",  "farmerId": "f5",  "crop": "tomato",        "kg": 190.0, "readyHour": 3.0, "shelfLifeHours": 72.0},
    {"id": "h6",  "farmerId": "f6",  "crop": "carrot",        "kg": 300.0, "readyHour": 2.0, "shelfLifeHours": 120.0},
    {"id": "h7",  "farmerId": "f7",  "crop": "leafy_greens",  "kg": 90.0,  "readyHour": 0.5, "shelfLifeHours": 24.0},
    {"id": "h8",  "farmerId": "f8",  "crop": "beans",         "kg": 120.0, "readyHour": 5.0, "shelfLifeHours": 48.0},
    {"id": "h9",  "farmerId": "f9",  "crop": "leafy_greens",  "kg": 70.0,  "readyHour": 3.0, "shelfLifeHours": 24.0},
    {"id": "h10", "farmerId": "f10", "crop": "tomato",        "kg": 140.0, "readyHour": 1.0, "shelfLifeHours": 72.0},
    {"id": "h11", "farmerId": "f11", "crop": "carrot",        "kg": 250.0, "readyHour": 6.0, "shelfLifeHours": 120.0},
    {"id": "h12", "farmerId": "f12", "crop": "beans",         "kg": 110.0, "readyHour": 4.0, "shelfLifeHours": 48.0}
];

glob SEED_HUB_RECORDS: list[dict[str, any]] = [
    {"id": "hub1", "name": "Dambulla Hub",     "district": "Dambulla"},
    {"id": "hub2", "name": "Nuwara Eliya Hub", "district": "Nuwara Eliya"},
    {"id": "hub3", "name": "Kandy Hub",        "district": "Kandy"},
    {"id": "hub4", "name": "Matale Hub",       "district": "Matale"}
];

# prices: LKR per kg, keyed by crop (per api.jac's MarketInfo docstring).
glob SEED_MARKET_RECORDS: list[dict[str, any]] = [
    {
        "id": "mk1", "name": "Dambulla Economic Centre",
        "prices": {"tomato": 180.0, "beans": 220.0, "leafy_greens": 150.0, "carrot": 160.0},
        "demandCapKg": 4000.0
    },
    {
        "id": "mk2", "name": "Colombo Manning Market",
        "prices": {"tomato": 240.0, "beans": 280.0, "leafy_greens": 200.0, "carrot": 210.0},
        "demandCapKg": 3200.0
    },
    {
        "id": "mk3", "name": "Kandy Market",
        "prices": {"tomato": 200.0, "beans": 250.0, "leafy_greens": 170.0, "carrot": 180.0},
        "demandCapKg": 2500.0
    }
];

glob SEED_TRUCK_RECORDS: list[dict[str, any]] = [
    {"id": "t1", "name": "WP CAB-1001", "capacityKg": 1000.0, "costPerKm": 45.0, "status": "available"},
    {"id": "t2", "name": "CP CAB-1500", "capacityKg": 1500.0, "costPerKm": 60.0, "status": "available"},
    {"id": "t3", "name": "MH CAB-2000", "capacityKg": 2000.0, "costPerKm": 75.0, "status": "available"}
];

glob SEED_FARMER_HUB_RECORDS: list[dict[str, any]] = [
    {"farmerId": "f1", "hubId": "hub1"}, {"farmerId": "f2", "hubId": "hub1"},
    {"farmerId": "f3", "hubId": "hub1"}, {"farmerId": "f4", "hubId": "hub1"},
    {"farmerId": "f5", "hubId": "hub1"}, {"farmerId": "f6", "hubId": "hub2"},
    {"farmerId": "f7", "hubId": "hub2"}, {"farmerId": "f8", "hubId": "hub3"},
    {"farmerId": "f9", "hubId": "hub3"}, {"farmerId": "f10", "hubId": "hub4"},
    {"farmerId": "f11", "hubId": "hub4"}, {"farmerId": "f12", "hubId": "hub4"}
];

# Same numbers as SEED_HUB_ROUTES/SEED_HUB_MARKET_ROUTES above, re-keyed by
# id for RouteInfo.distanceKm/hours lookups. Each edge also carries its own
# "id" so a road_closed event (Event.edgeId) can address it directly.
glob SEED_HUB_ROUTE_RECORDS: list[dict[str, any]] = [
    {"id": "hub1-hub4", "fromHubId": "hub1", "toHubId": "hub4", "distanceKm": 45.0, "hours": 1.2, "open": True},
    {"id": "hub1-hub3", "fromHubId": "hub1", "toHubId": "hub3", "distanceKm": 72.0, "hours": 2.0, "open": True},
    {"id": "hub3-hub4", "fromHubId": "hub3", "toHubId": "hub4", "distanceKm": 28.0, "hours": 0.8, "open": True},
    {"id": "hub3-hub2", "fromHubId": "hub3", "toHubId": "hub2", "distanceKm": 77.0, "hours": 2.5, "open": True},
    {"id": "hub4-hub2", "fromHubId": "hub4", "toHubId": "hub2", "distanceKm": 95.0, "hours": 3.0, "open": True}
];

glob SEED_HUB_MARKET_ROUTE_RECORDS: list[dict[str, any]] = [
    {"id": "hub1-mk1", "hubId": "hub1", "marketId": "mk1", "distanceKm": 2.0,   "hours": 0.1,  "open": True},
    {"id": "hub1-mk3", "hubId": "hub1", "marketId": "mk3", "distanceKm": 72.0,  "hours": 2.0,  "open": True},
    {"id": "hub1-mk2", "hubId": "hub1", "marketId": "mk2", "distanceKm": 148.0, "hours": 3.5,  "open": True},
    {"id": "hub2-mk3", "hubId": "hub2", "marketId": "mk3", "distanceKm": 77.0,  "hours": 2.5,  "open": True},
    {"id": "hub2-mk2", "hubId": "hub2", "marketId": "mk2", "distanceKm": 180.0, "hours": 5.0,  "open": True},
    {"id": "hub2-mk1", "hubId": "hub2", "marketId": "mk1", "distanceKm": 100.0, "hours": 3.0,  "open": True},
    {"id": "hub3-mk3", "hubId": "hub3", "marketId": "mk3", "distanceKm": 3.0,   "hours": 0.15, "open": True},
    {"id": "hub3-mk2", "hubId": "hub3", "marketId": "mk2", "distanceKm": 115.0, "hours": 3.0,  "open": True},
    {"id": "hub3-mk1", "hubId": "hub3", "marketId": "mk1", "distanceKm": 72.0,  "hours": 2.0,  "open": True},
    {"id": "hub4-mk1", "hubId": "hub4", "marketId": "mk1", "distanceKm": 45.0,  "hours": 1.2,  "open": True},
    {"id": "hub4-mk3", "hubId": "hub4", "marketId": "mk3", "distanceKm": 28.0,  "hours": 0.8,  "open": True},
    {"id": "hub4-mk2", "hubId": "hub4", "marketId": "mk2", "distanceKm": 140.0, "hours": 3.3,  "open": True}
];

# id-based counterpart to DEMO_MERGE_SCENARIO/DEMO_BREAKDOWN_SCENARIO above -
# ready for Event(type=..., truckId=..., ...) and RouteInfo construction.
glob DEMO_MERGE_SCENARIO_IDS: dict[str, any] = {
    "farmerIds": ["f1", "f2", "f3", "f4", "f5"],
    "hubId": "hub1",
    "truckId": "t1",
    "marketId": "mk3",
    "totalKg": 880.0
};

glob DEMO_BREAKDOWN_EVENT: dict[str, any] = {
    "type": "truck_breakdown",
    "truckId": "t1"
};

# ---------------------------------------------------------------------------
# The other three Event types from the contract (road_closed, price_crash,
# new_harvest) - only truck_breakdown had a demo scenario before. All code
# matches Event(type, truckId, edgeId, marketId, crop, text) exactly.
# ---------------------------------------------------------------------------

# Closes the exact edge the merge scenario planned to use (hub1 -> mk3),
# so firing this right after a merge forces a real reroute - e.g. via
# hub1-mk1 (2km, trivial) or hub1-hub3 -> hub3-mk3 through Kandy Hub.
glob DEMO_ROAD_CLOSED_EVENT: dict[str, any] = {
    "type": "road_closed",
    "edgeId": "hub1-mk3",
    "_description": "Dambulla Hub -> Kandy Market closed. Forces the merged 5-farmer tomato route off its planned path."
};

# Tomato price crashes at Kandy Market (mk3) - the same market the merge
# scenario chose for its better price (200 vs 180 at Dambulla Economic
# Centre), so this specifically undercuts why the merge picked it.
glob DEMO_PRICE_CRASH_EVENT: dict[str, any] = {
    "type": "price_crash",
    "marketId": "mk3",
    "crop": "tomato",
    "_description": "Kandy Market tomato price crashes. Dambulla Economic Centre (180/kg) becomes the better destination."
};
# Not part of the Event contract itself (Event carries no price field) -
# supplementary reference value if logic.jac wants a concrete new price
# rather than just reacting to "this market/crop is no longer viable".
glob DEMO_PRICE_CRASH_NEW_PRICE: float = 90.0;

# Free-text input for parse_harvest() feeding a live new_harvest event -
# a 13th farmer's harvest arriving after the initial load_seed().
glob DEMO_NEW_HARVEST_EVENT: dict[str, any] = {
    "type": "new_harvest",
    "text": "Lasantha just harvested another 80kg of beans near Matale, ready in about 2 hours"
};
