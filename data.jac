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

Both describe the same 50 farmers/9 hubs/7 markets/9 trucks; A picks
whichever shape fits however load_seed() ends up implemented.

Island-wide layout: the original 12 farmers/4 hubs/3 markets/3 trucks
(Dambulla/Nuwara Eliya/Kandy/Matale, feeding Dambulla Economic Centre/
Colombo Manning Market/Kandy Market) are UNCHANGED from the original demo
fixture - every id, name and number below f1-f12/hub1-hub4/mk1-mk3/t1-t3
is byte-for-byte what it always was, so the merge/breakdown demo scenarios
(DEMO_MERGE_SCENARIO, DEMO_BREAKDOWN_SCENARIO and their *_IDS/*_EVENT
counterparts) still hold exactly. Everything from f13/hub5/mk4/t4 onward is
a second, separate island-wide component - Jaffna, Anuradhapura, Badulla,
Ratnapura and Galle - with its own hubs, markets and trucks and NO
HubRoute/HubMarketRoute edge back into the original four hubs or three
markets. That separation is deliberate: logic.jac's merge engine only ever
pairs two baseline routes bound for the SAME market_id, so keeping the new
component's hubs shipping only to the new markets guarantees it can never
contend with the original fixture's merge candidates and shift which
routes become "m1"/"m2"/etc.

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
    "carrot": 120.0,
    "onion": 480.0,
    "chili": 96.0,
    "cabbage": 168.0
};

# ---------------------------------------------------------------------------
# Core seed records (exact models.jac fields).
# ---------------------------------------------------------------------------

glob SEED_HUBS: list[Hub] = [
    Hub(name="Dambulla Hub", capacity_kg=8000.0),
    Hub(name="Nuwara Eliya Hub", capacity_kg=4000.0),
    Hub(name="Kandy Hub", capacity_kg=6000.0),
    Hub(name="Matale Hub", capacity_kg=5000.0),
    # Second, separate island-wide component - see the module docstring.
    Hub(name="Jaffna Hub", capacity_kg=5000.0),
    Hub(name="Anuradhapura Hub", capacity_kg=6000.0),
    Hub(name="Badulla Hub", capacity_kg=5000.0),
    Hub(name="Ratnapura Hub", capacity_kg=4500.0),
    Hub(name="Galle Hub", capacity_kg=5000.0)
];

glob SEED_MARKETS: list[Market] = [
    Market(name="Dambulla Economic Centre", demand_kg=4000.0),
    Market(name="Colombo Manning Market", demand_kg=3200.0),
    Market(name="Kandy Market", demand_kg=2500.0),
    Market(name="Jaffna Market", demand_kg=3000.0),
    Market(name="Anuradhapura Economic Centre", demand_kg=3500.0),
    Market(name="Badulla Economic Centre", demand_kg=2800.0),
    Market(name="Galle Market", demand_kg=2600.0)
];

glob SEED_TRUCKS: list[Truck] = [
    Truck(plate="WP CAB-1001", capacity_kg=1000.0),
    Truck(plate="CP CAB-1500", capacity_kg=1500.0),
    Truck(plate="MH CAB-2000", capacity_kg=2000.0),
    Truck(plate="NP LA-3001", capacity_kg=1200.0),
    Truck(plate="NC GA-2200", capacity_kg=1800.0),
    Truck(plate="UP BG-1800", capacity_kg=1400.0),
    Truck(plate="SG RA-2600", capacity_kg=2200.0),
    Truck(plate="SP GL-1900", capacity_kg=1600.0),
    Truck(plate="SP GL-2400", capacity_kg=2000.0)
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
    Farmer(name="Lasantha Weerasinghe",  phone="+94771234512", location="Matale"),

    # Second, separate island-wide component - see the module docstring.
    Farmer(name="Selvam Rajendran",       phone="+94771234513", location="Jaffna"),
    Farmer(name="Thiruchelvam Kandiah",   phone="+94771234514", location="Jaffna"),
    Farmer(name="Vasanthi Sivakumar",     phone="+94771234515", location="Jaffna"),
    Farmer(name="Kumaran Pathmanathan",   phone="+94771234516", location="Jaffna"),
    Farmer(name="Nirmala Sivalingam",     phone="+94771234517", location="Jaffna"),
    Farmer(name="Ratnam Kanagasabai",     phone="+94771234518", location="Jaffna"),
    Farmer(name="Yogeswari Thevarajah",   phone="+94771234519", location="Jaffna"),
    Farmer(name="Sivakumar Arumugam",     phone="+94771234520", location="Jaffna"),

    Farmer(name="Chandana Rajapaksha",    phone="+94771234521", location="Anuradhapura"),
    Farmer(name="Wasantha Herath",        phone="+94771234522", location="Anuradhapura"),
    Farmer(name="Nandasena Ekanayake",    phone="+94771234523", location="Anuradhapura"),
    Farmer(name="Premalatha Gunasekara",  phone="+94771234524", location="Anuradhapura"),
    Farmer(name="Sarath Amarasinghe",     phone="+94771234525", location="Anuradhapura"),
    Farmer(name="Kusumawathi Jayawardena",phone="+94771234526", location="Anuradhapura"),
    Farmer(name="Ajith Karunaratne",      phone="+94771234527", location="Anuradhapura"),
    Farmer(name="Shanthi Pathirana",      phone="+94771234528", location="Anuradhapura"),

    Farmer(name="Ranasinghe Dissanayake", phone="+94771234529", location="Badulla"),
    Farmer(name="Chandrika Senarathna",   phone="+94771234530", location="Badulla"),
    Farmer(name="Upali Wijesinghe",       phone="+94771234531", location="Badulla"),
    Farmer(name="Mallika Abeysekara",     phone="+94771234532", location="Badulla"),
    Farmer(name="Tissa Rathnayaka",       phone="+94771234533", location="Badulla"),
    Farmer(name="Somawathi Rajapakshe",   phone="+94771234534", location="Badulla"),
    Farmer(name="Gunadasa Peiris",        phone="+94771234535", location="Badulla"),
    Farmer(name="Indrani Wickramaratne",  phone="+94771234536", location="Badulla"),

    Farmer(name="Lal Jayasundara",        phone="+94771234537", location="Ratnapura"),
    Farmer(name="Chaminda Ranatunga",     phone="+94771234538", location="Ratnapura"),
    Farmer(name="Hemalatha Kodithuwakku", phone="+94771234539", location="Ratnapura"),
    Farmer(name="Piyasena Gamage",        phone="+94771234540", location="Ratnapura"),
    Farmer(name="Rohini Madushani",       phone="+94771234541", location="Ratnapura"),
    Farmer(name="Bandula Weeratunga",     phone="+94771234542", location="Ratnapura"),
    Farmer(name="Swarna Ellawala",        phone="+94771234543", location="Ratnapura"),

    Farmer(name="Nimal Jayathilaka",      phone="+94771234544", location="Galle"),
    Farmer(name="Anusha Kariyawasam",     phone="+94771234545", location="Galle"),
    Farmer(name="Saman Dharmasena",       phone="+94771234546", location="Galle"),
    Farmer(name="Kumudu Rodrigo",         phone="+94771234547", location="Galle"),
    Farmer(name="Ajantha Fonseka",        phone="+94771234548", location="Galle"),
    Farmer(name="Chithra Gunawardana",    phone="+94771234549", location="Galle"),
    Farmer(name="Mahesh Ratnasiri",       phone="+94771234550", location="Galle")
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
    Harvest(crop="beans", quantity_kg=110.0, harvested_at="-4h"),

    # Parallel to the second-component farmers above (f13-f50).
    Harvest(crop="onion", quantity_kg=140.0, harvested_at="-2h"),
    Harvest(crop="chili", quantity_kg=70.0,  harvested_at="-1h"),
    Harvest(crop="tomato", quantity_kg=160.0, harvested_at="-3h"),
    Harvest(crop="onion", quantity_kg=200.0, harvested_at="-4h"),
    Harvest(crop="chili", quantity_kg=55.0,  harvested_at="-1h"),
    Harvest(crop="onion", quantity_kg=180.0, harvested_at="-2h"),
    Harvest(crop="tomato", quantity_kg=120.0, harvested_at="-2h"),
    Harvest(crop="chili", quantity_kg=65.0,  harvested_at="-3h"),

    Harvest(crop="onion", quantity_kg=220.0, harvested_at="-3h"),
    Harvest(crop="chili", quantity_kg=60.0,  harvested_at="-1h"),
    Harvest(crop="beans", quantity_kg=130.0, harvested_at="-4h"),
    Harvest(crop="onion", quantity_kg=190.0, harvested_at="-2h"),
    Harvest(crop="chili", quantity_kg=75.0,  harvested_at="-2h"),
    Harvest(crop="beans", quantity_kg=110.0, harvested_at="-5h"),
    Harvest(crop="onion", quantity_kg=160.0, harvested_at="-3h"),
    Harvest(crop="beans", quantity_kg=95.0,  harvested_at="-1h"),

    Harvest(crop="cabbage", quantity_kg=150.0, harvested_at="-2h"),
    Harvest(crop="carrot", quantity_kg=200.0, harvested_at="-4h"),
    Harvest(crop="leafy_greens", quantity_kg=80.0, harvested_at="-1h"),
    Harvest(crop="cabbage", quantity_kg=170.0, harvested_at="-3h"),
    Harvest(crop="carrot", quantity_kg=240.0, harvested_at="-5h"),
    Harvest(crop="leafy_greens", quantity_kg=65.0, harvested_at="-1h"),
    Harvest(crop="cabbage", quantity_kg=130.0, harvested_at="-2h"),
    Harvest(crop="carrot", quantity_kg=180.0, harvested_at="-3h"),

    Harvest(crop="beans", quantity_kg=140.0, harvested_at="-3h"),
    Harvest(crop="leafy_greens", quantity_kg=90.0, harvested_at="-1h"),
    Harvest(crop="tomato", quantity_kg=170.0, harvested_at="-2h"),
    Harvest(crop="beans", quantity_kg=120.0, harvested_at="-4h"),
    Harvest(crop="leafy_greens", quantity_kg=75.0, harvested_at="-1h"),
    Harvest(crop="tomato", quantity_kg=200.0, harvested_at="-3h"),
    Harvest(crop="beans", quantity_kg=100.0, harvested_at="-2h"),

    Harvest(crop="tomato", quantity_kg=180.0, harvested_at="-2h"),
    Harvest(crop="beans", quantity_kg=110.0, harvested_at="-3h"),
    Harvest(crop="leafy_greens", quantity_kg=85.0, harvested_at="-1h"),
    Harvest(crop="tomato", quantity_kg=150.0, harvested_at="-2h"),
    Harvest(crop="beans", quantity_kg=130.0, harvested_at="-4h"),
    Harvest(crop="leafy_greens", quantity_kg=70.0, harvested_at="-1h"),
    Harvest(crop="tomato", quantity_kg=160.0, harvested_at="-3h")
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
    {"farmer_name": "Lasantha Weerasinghe", "hub_name": "Matale Hub"},

    # Second, separate island-wide component - see the module docstring.
    {"farmer_name": "Selvam Rajendran", "hub_name": "Jaffna Hub"},
    {"farmer_name": "Thiruchelvam Kandiah", "hub_name": "Jaffna Hub"},
    {"farmer_name": "Vasanthi Sivakumar", "hub_name": "Jaffna Hub"},
    {"farmer_name": "Kumaran Pathmanathan", "hub_name": "Jaffna Hub"},
    {"farmer_name": "Nirmala Sivalingam", "hub_name": "Jaffna Hub"},
    {"farmer_name": "Ratnam Kanagasabai", "hub_name": "Jaffna Hub"},
    {"farmer_name": "Yogeswari Thevarajah", "hub_name": "Jaffna Hub"},
    {"farmer_name": "Sivakumar Arumugam", "hub_name": "Jaffna Hub"},

    {"farmer_name": "Chandana Rajapaksha", "hub_name": "Anuradhapura Hub"},
    {"farmer_name": "Wasantha Herath", "hub_name": "Anuradhapura Hub"},
    {"farmer_name": "Nandasena Ekanayake", "hub_name": "Anuradhapura Hub"},
    {"farmer_name": "Premalatha Gunasekara", "hub_name": "Anuradhapura Hub"},
    {"farmer_name": "Sarath Amarasinghe", "hub_name": "Anuradhapura Hub"},
    {"farmer_name": "Kusumawathi Jayawardena", "hub_name": "Anuradhapura Hub"},
    {"farmer_name": "Ajith Karunaratne", "hub_name": "Anuradhapura Hub"},
    {"farmer_name": "Shanthi Pathirana", "hub_name": "Anuradhapura Hub"},

    {"farmer_name": "Ranasinghe Dissanayake", "hub_name": "Badulla Hub"},
    {"farmer_name": "Chandrika Senarathna", "hub_name": "Badulla Hub"},
    {"farmer_name": "Upali Wijesinghe", "hub_name": "Badulla Hub"},
    {"farmer_name": "Mallika Abeysekara", "hub_name": "Badulla Hub"},
    {"farmer_name": "Tissa Rathnayaka", "hub_name": "Badulla Hub"},
    {"farmer_name": "Somawathi Rajapakshe", "hub_name": "Badulla Hub"},
    {"farmer_name": "Gunadasa Peiris", "hub_name": "Badulla Hub"},
    {"farmer_name": "Indrani Wickramaratne", "hub_name": "Badulla Hub"},

    {"farmer_name": "Lal Jayasundara", "hub_name": "Ratnapura Hub"},
    {"farmer_name": "Chaminda Ranatunga", "hub_name": "Ratnapura Hub"},
    {"farmer_name": "Hemalatha Kodithuwakku", "hub_name": "Ratnapura Hub"},
    {"farmer_name": "Piyasena Gamage", "hub_name": "Ratnapura Hub"},
    {"farmer_name": "Rohini Madushani", "hub_name": "Ratnapura Hub"},
    {"farmer_name": "Bandula Weeratunga", "hub_name": "Ratnapura Hub"},
    {"farmer_name": "Swarna Ellawala", "hub_name": "Ratnapura Hub"},

    {"farmer_name": "Nimal Jayathilaka", "hub_name": "Galle Hub"},
    {"farmer_name": "Anusha Kariyawasam", "hub_name": "Galle Hub"},
    {"farmer_name": "Saman Dharmasena", "hub_name": "Galle Hub"},
    {"farmer_name": "Kumudu Rodrigo", "hub_name": "Galle Hub"},
    {"farmer_name": "Ajantha Fonseka", "hub_name": "Galle Hub"},
    {"farmer_name": "Chithra Gunawardana", "hub_name": "Galle Hub"},
    {"farmer_name": "Mahesh Ratnasiri", "hub_name": "Galle Hub"}
];

# Hand-written distance/hours matrix, hub <-> hub.
glob SEED_HUB_ROUTES: list[dict[str, any]] = [
    {"from_hub": "Dambulla Hub", "to_hub": "Matale Hub", "distance_km": 45.0, "hours": 1.2, "open": True},
    {"from_hub": "Dambulla Hub", "to_hub": "Kandy Hub", "distance_km": 72.0, "hours": 2.0, "open": True},
    {"from_hub": "Kandy Hub", "to_hub": "Matale Hub", "distance_km": 28.0, "hours": 0.8, "open": True},
    {"from_hub": "Kandy Hub", "to_hub": "Nuwara Eliya Hub", "distance_km": 77.0, "hours": 2.5, "open": True},
    {"from_hub": "Matale Hub", "to_hub": "Nuwara Eliya Hub", "distance_km": 95.0, "hours": 3.0, "open": True},

    # Second, separate island-wide component - see the module docstring.
    # Deliberately NOT connected to the four hubs above.
    {"from_hub": "Jaffna Hub", "to_hub": "Anuradhapura Hub", "distance_km": 155.0, "hours": 3.0, "open": True},
    {"from_hub": "Anuradhapura Hub", "to_hub": "Badulla Hub", "distance_km": 195.0, "hours": 4.5, "open": True},
    {"from_hub": "Anuradhapura Hub", "to_hub": "Ratnapura Hub", "distance_km": 180.0, "hours": 4.0, "open": True},
    {"from_hub": "Badulla Hub", "to_hub": "Ratnapura Hub", "distance_km": 95.0, "hours": 2.5, "open": True},
    {"from_hub": "Ratnapura Hub", "to_hub": "Galle Hub", "distance_km": 100.0, "hours": 2.2, "open": True}
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
    {"from_hub": "Matale Hub", "to_market": "Colombo Manning Market", "distance_km": 140.0, "hours": 3.3, "open": True},

    # Second, separate island-wide component - see the module docstring.
    # Deliberately NOT connected to the three markets above.
    {"from_hub": "Jaffna Hub", "to_market": "Jaffna Market", "distance_km": 10.0, "hours": 0.2, "open": True},
    {"from_hub": "Jaffna Hub", "to_market": "Anuradhapura Economic Centre", "distance_km": 155.0, "hours": 3.0, "open": True},
    {"from_hub": "Anuradhapura Hub", "to_market": "Anuradhapura Economic Centre", "distance_km": 8.0, "hours": 0.2, "open": True},
    {"from_hub": "Anuradhapura Hub", "to_market": "Jaffna Market", "distance_km": 155.0, "hours": 3.0, "open": True},
    {"from_hub": "Anuradhapura Hub", "to_market": "Badulla Economic Centre", "distance_km": 195.0, "hours": 4.5, "open": True},
    {"from_hub": "Badulla Hub", "to_market": "Badulla Economic Centre", "distance_km": 12.0, "hours": 0.3, "open": True},
    {"from_hub": "Badulla Hub", "to_market": "Galle Market", "distance_km": 230.0, "hours": 5.0, "open": True},
    {"from_hub": "Ratnapura Hub", "to_market": "Badulla Economic Centre", "distance_km": 95.0, "hours": 2.5, "open": True},
    {"from_hub": "Ratnapura Hub", "to_market": "Galle Market", "distance_km": 100.0, "hours": 2.2, "open": True},
    {"from_hub": "Galle Hub", "to_market": "Galle Market", "distance_km": 15.0, "hours": 0.3, "open": True},
    {"from_hub": "Galle Hub", "to_market": "Badulla Economic Centre", "distance_km": 230.0, "hours": 5.0, "open": True}
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
    "300kg carrots, ready in 2 days, up country near Nuwara Eliya",
    "~150kg onions ready in 3 hours near Jaffna",
    "80kg cabbage ready tomorrow in Badulla"
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
    {"id": "f12", "name": "Lasantha Weerasinghe",    "district": "Matale",      "language": "si"},

    # Second, separate island-wide component - see the module docstring.
    {"id": "f13", "name": "Selvam Rajendran",        "district": "Jaffna",       "language": "ta"},
    {"id": "f14", "name": "Thiruchelvam Kandiah",    "district": "Jaffna",       "language": "ta"},
    {"id": "f15", "name": "Vasanthi Sivakumar",      "district": "Jaffna",       "language": "ta"},
    {"id": "f16", "name": "Kumaran Pathmanathan",    "district": "Jaffna",       "language": "ta"},
    {"id": "f17", "name": "Nirmala Sivalingam",      "district": "Jaffna",       "language": "ta"},
    {"id": "f18", "name": "Ratnam Kanagasabai",      "district": "Jaffna",       "language": "ta"},
    {"id": "f19", "name": "Yogeswari Thevarajah",    "district": "Jaffna",       "language": "ta"},
    {"id": "f20", "name": "Sivakumar Arumugam",      "district": "Jaffna",       "language": "ta"},

    {"id": "f21", "name": "Chandana Rajapaksha",     "district": "Anuradhapura", "language": "si"},
    {"id": "f22", "name": "Wasantha Herath",         "district": "Anuradhapura", "language": "si"},
    {"id": "f23", "name": "Nandasena Ekanayake",     "district": "Anuradhapura", "language": "si"},
    {"id": "f24", "name": "Premalatha Gunasekara",   "district": "Anuradhapura", "language": "si"},
    {"id": "f25", "name": "Sarath Amarasinghe",      "district": "Anuradhapura", "language": "si"},
    {"id": "f26", "name": "Kusumawathi Jayawardena", "district": "Anuradhapura", "language": "si"},
    {"id": "f27", "name": "Ajith Karunaratne",       "district": "Anuradhapura", "language": "si"},
    {"id": "f28", "name": "Shanthi Pathirana",       "district": "Anuradhapura", "language": "si"},

    {"id": "f29", "name": "Ranasinghe Dissanayake",  "district": "Badulla",      "language": "si"},
    {"id": "f30", "name": "Chandrika Senarathna",    "district": "Badulla",      "language": "si"},
    {"id": "f31", "name": "Upali Wijesinghe",        "district": "Badulla",      "language": "si"},
    {"id": "f32", "name": "Mallika Abeysekara",      "district": "Badulla",      "language": "si"},
    {"id": "f33", "name": "Tissa Rathnayaka",        "district": "Badulla",      "language": "si"},
    {"id": "f34", "name": "Somawathi Rajapakshe",    "district": "Badulla",      "language": "si"},
    {"id": "f35", "name": "Gunadasa Peiris",         "district": "Badulla",      "language": "si"},
    {"id": "f36", "name": "Indrani Wickramaratne",   "district": "Badulla",      "language": "si"},

    {"id": "f37", "name": "Lal Jayasundara",         "district": "Ratnapura",    "language": "si"},
    {"id": "f38", "name": "Chaminda Ranatunga",      "district": "Ratnapura",    "language": "si"},
    {"id": "f39", "name": "Hemalatha Kodithuwakku",  "district": "Ratnapura",    "language": "si"},
    {"id": "f40", "name": "Piyasena Gamage",         "district": "Ratnapura",    "language": "si"},
    {"id": "f41", "name": "Rohini Madushani",        "district": "Ratnapura",    "language": "si"},
    {"id": "f42", "name": "Bandula Weeratunga",      "district": "Ratnapura",    "language": "si"},
    {"id": "f43", "name": "Swarna Ellawala",         "district": "Ratnapura",    "language": "si"},

    {"id": "f44", "name": "Nimal Jayathilaka",       "district": "Galle",        "language": "si"},
    {"id": "f45", "name": "Anusha Kariyawasam",      "district": "Galle",        "language": "si"},
    {"id": "f46", "name": "Saman Dharmasena",        "district": "Galle",        "language": "si"},
    {"id": "f47", "name": "Kumudu Rodrigo",          "district": "Galle",        "language": "si"},
    {"id": "f48", "name": "Ajantha Fonseka",         "district": "Galle",        "language": "si"},
    {"id": "f49", "name": "Chithra Gunawardana",     "district": "Galle",        "language": "si"},
    {"id": "f50", "name": "Mahesh Ratnasiri",        "district": "Galle",        "language": "si"}
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
    {"id": "h12", "farmerId": "f12", "crop": "beans",         "kg": 110.0, "readyHour": 4.0, "shelfLifeHours": 48.0},

    # Parallel to the second-component farmers above (f13-f50).
    {"id": "h13", "farmerId": "f13", "crop": "onion",         "kg": 140.0, "readyHour": 2.0, "shelfLifeHours": 480.0},
    {"id": "h14", "farmerId": "f14", "crop": "chili",         "kg": 70.0,  "readyHour": 1.0, "shelfLifeHours": 96.0},
    {"id": "h15", "farmerId": "f15", "crop": "tomato",        "kg": 160.0, "readyHour": 3.0, "shelfLifeHours": 72.0},
    {"id": "h16", "farmerId": "f16", "crop": "onion",         "kg": 200.0, "readyHour": 4.0, "shelfLifeHours": 480.0},
    {"id": "h17", "farmerId": "f17", "crop": "chili",         "kg": 55.0,  "readyHour": 1.0, "shelfLifeHours": 96.0},
    {"id": "h18", "farmerId": "f18", "crop": "onion",         "kg": 180.0, "readyHour": 2.0, "shelfLifeHours": 480.0},
    {"id": "h19", "farmerId": "f19", "crop": "tomato",        "kg": 120.0, "readyHour": 2.0, "shelfLifeHours": 72.0},
    {"id": "h20", "farmerId": "f20", "crop": "chili",         "kg": 65.0,  "readyHour": 3.0, "shelfLifeHours": 96.0},

    {"id": "h21", "farmerId": "f21", "crop": "onion",         "kg": 220.0, "readyHour": 3.0, "shelfLifeHours": 480.0},
    {"id": "h22", "farmerId": "f22", "crop": "chili",         "kg": 60.0,  "readyHour": 1.0, "shelfLifeHours": 96.0},
    {"id": "h23", "farmerId": "f23", "crop": "beans",         "kg": 130.0, "readyHour": 4.0, "shelfLifeHours": 48.0},
    {"id": "h24", "farmerId": "f24", "crop": "onion",         "kg": 190.0, "readyHour": 2.0, "shelfLifeHours": 480.0},
    {"id": "h25", "farmerId": "f25", "crop": "chili",         "kg": 75.0,  "readyHour": 2.0, "shelfLifeHours": 96.0},
    {"id": "h26", "farmerId": "f26", "crop": "beans",         "kg": 110.0, "readyHour": 5.0, "shelfLifeHours": 48.0},
    {"id": "h27", "farmerId": "f27", "crop": "onion",         "kg": 160.0, "readyHour": 3.0, "shelfLifeHours": 480.0},
    {"id": "h28", "farmerId": "f28", "crop": "beans",         "kg": 95.0,  "readyHour": 1.0, "shelfLifeHours": 48.0},

    {"id": "h29", "farmerId": "f29", "crop": "cabbage",       "kg": 150.0, "readyHour": 2.0, "shelfLifeHours": 168.0},
    {"id": "h30", "farmerId": "f30", "crop": "carrot",        "kg": 200.0, "readyHour": 4.0, "shelfLifeHours": 120.0},
    {"id": "h31", "farmerId": "f31", "crop": "leafy_greens",  "kg": 80.0,  "readyHour": 1.0, "shelfLifeHours": 24.0},
    {"id": "h32", "farmerId": "f32", "crop": "cabbage",       "kg": 170.0, "readyHour": 3.0, "shelfLifeHours": 168.0},
    {"id": "h33", "farmerId": "f33", "crop": "carrot",        "kg": 240.0, "readyHour": 5.0, "shelfLifeHours": 120.0},
    {"id": "h34", "farmerId": "f34", "crop": "leafy_greens",  "kg": 65.0,  "readyHour": 1.0, "shelfLifeHours": 24.0},
    {"id": "h35", "farmerId": "f35", "crop": "cabbage",       "kg": 130.0, "readyHour": 2.0, "shelfLifeHours": 168.0},
    {"id": "h36", "farmerId": "f36", "crop": "carrot",        "kg": 180.0, "readyHour": 3.0, "shelfLifeHours": 120.0},

    {"id": "h37", "farmerId": "f37", "crop": "beans",         "kg": 140.0, "readyHour": 3.0, "shelfLifeHours": 48.0},
    {"id": "h38", "farmerId": "f38", "crop": "leafy_greens",  "kg": 90.0,  "readyHour": 1.0, "shelfLifeHours": 24.0},
    {"id": "h39", "farmerId": "f39", "crop": "tomato",        "kg": 170.0, "readyHour": 2.0, "shelfLifeHours": 72.0},
    {"id": "h40", "farmerId": "f40", "crop": "beans",         "kg": 120.0, "readyHour": 4.0, "shelfLifeHours": 48.0},
    {"id": "h41", "farmerId": "f41", "crop": "leafy_greens",  "kg": 75.0,  "readyHour": 1.0, "shelfLifeHours": 24.0},
    {"id": "h42", "farmerId": "f42", "crop": "tomato",        "kg": 200.0, "readyHour": 3.0, "shelfLifeHours": 72.0},
    {"id": "h43", "farmerId": "f43", "crop": "beans",         "kg": 100.0, "readyHour": 2.0, "shelfLifeHours": 48.0},

    {"id": "h44", "farmerId": "f44", "crop": "tomato",        "kg": 180.0, "readyHour": 2.0, "shelfLifeHours": 72.0},
    {"id": "h45", "farmerId": "f45", "crop": "beans",         "kg": 110.0, "readyHour": 3.0, "shelfLifeHours": 48.0},
    {"id": "h46", "farmerId": "f46", "crop": "leafy_greens",  "kg": 85.0,  "readyHour": 1.0, "shelfLifeHours": 24.0},
    {"id": "h47", "farmerId": "f47", "crop": "tomato",        "kg": 150.0, "readyHour": 2.0, "shelfLifeHours": 72.0},
    {"id": "h48", "farmerId": "f48", "crop": "beans",         "kg": 130.0, "readyHour": 4.0, "shelfLifeHours": 48.0},
    {"id": "h49", "farmerId": "f49", "crop": "leafy_greens",  "kg": 70.0,  "readyHour": 1.0, "shelfLifeHours": 24.0},
    {"id": "h50", "farmerId": "f50", "crop": "tomato",        "kg": 160.0, "readyHour": 3.0, "shelfLifeHours": 72.0}
];

glob SEED_HUB_RECORDS: list[dict[str, any]] = [
    {"id": "hub1", "name": "Dambulla Hub",     "district": "Dambulla"},
    {"id": "hub2", "name": "Nuwara Eliya Hub", "district": "Nuwara Eliya"},
    {"id": "hub3", "name": "Kandy Hub",        "district": "Kandy"},
    {"id": "hub4", "name": "Matale Hub",       "district": "Matale"},
    # Second, separate island-wide component - see the module docstring.
    {"id": "hub5", "name": "Jaffna Hub",       "district": "Jaffna"},
    {"id": "hub6", "name": "Anuradhapura Hub", "district": "Anuradhapura"},
    {"id": "hub7", "name": "Badulla Hub",      "district": "Badulla"},
    {"id": "hub8", "name": "Ratnapura Hub",    "district": "Ratnapura"},
    {"id": "hub9", "name": "Galle Hub",        "district": "Galle"}
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
    },
    # Second, separate island-wide component - see the module docstring.
    {
        "id": "mk4", "name": "Jaffna Market",
        "prices": {"onion": 150.0, "chili": 550.0, "tomato": 190.0},
        "demandCapKg": 3000.0
    },
    {
        "id": "mk5", "name": "Anuradhapura Economic Centre",
        "prices": {"onion": 145.0, "chili": 530.0, "beans": 230.0},
        "demandCapKg": 3500.0
    },
    {
        "id": "mk6", "name": "Badulla Economic Centre",
        "prices": {"cabbage": 110.0, "carrot": 175.0, "leafy_greens": 160.0},
        "demandCapKg": 2800.0
    },
    {
        "id": "mk7", "name": "Galle Market",
        "prices": {"tomato": 210.0, "beans": 260.0, "leafy_greens": 190.0},
        "demandCapKg": 2600.0
    }
];

glob SEED_TRUCK_RECORDS: list[dict[str, any]] = [
    {"id": "t1", "name": "WP CAB-1001", "capacityKg": 1000.0, "costPerKm": 100.0, "status": "available"},
    {"id": "t2", "name": "CP CAB-1500", "capacityKg": 1500.0, "costPerKm": 100.0, "status": "available"},
    {"id": "t3", "name": "MH CAB-2000", "capacityKg": 2000.0, "costPerKm": 100.0, "status": "available"},
    # Second, separate island-wide component - see the module docstring.
    {"id": "t4", "name": "NP LA-3001", "capacityKg": 1200.0, "costPerKm": 100.0, "status": "available"},
    {"id": "t5", "name": "NC GA-2200", "capacityKg": 1800.0, "costPerKm": 105.0, "status": "available"},
    {"id": "t6", "name": "UP BG-1800", "capacityKg": 1400.0, "costPerKm": 95.0,  "status": "available"},
    {"id": "t7", "name": "SG RA-2600", "capacityKg": 2200.0, "costPerKm": 110.0, "status": "available"},
    {"id": "t8", "name": "SP GL-1900", "capacityKg": 1600.0, "costPerKm": 100.0, "status": "available"},
    {"id": "t9", "name": "SP GL-2400", "capacityKg": 2000.0, "costPerKm": 105.0, "status": "available"}
];

glob SEED_FARMER_HUB_RECORDS: list[dict[str, any]] = [
    {"farmerId": "f1", "hubId": "hub1"}, {"farmerId": "f2", "hubId": "hub1"},
    {"farmerId": "f3", "hubId": "hub1"}, {"farmerId": "f4", "hubId": "hub1"},
    {"farmerId": "f5", "hubId": "hub1"}, {"farmerId": "f6", "hubId": "hub2"},
    {"farmerId": "f7", "hubId": "hub2"}, {"farmerId": "f8", "hubId": "hub3"},
    {"farmerId": "f9", "hubId": "hub3"}, {"farmerId": "f10", "hubId": "hub4"},
    {"farmerId": "f11", "hubId": "hub4"}, {"farmerId": "f12", "hubId": "hub4"},

    # Second, separate island-wide component - see the module docstring.
    {"farmerId": "f13", "hubId": "hub5"}, {"farmerId": "f14", "hubId": "hub5"},
    {"farmerId": "f15", "hubId": "hub5"}, {"farmerId": "f16", "hubId": "hub5"},
    {"farmerId": "f17", "hubId": "hub5"}, {"farmerId": "f18", "hubId": "hub5"},
    {"farmerId": "f19", "hubId": "hub5"}, {"farmerId": "f20", "hubId": "hub5"},

    {"farmerId": "f21", "hubId": "hub6"}, {"farmerId": "f22", "hubId": "hub6"},
    {"farmerId": "f23", "hubId": "hub6"}, {"farmerId": "f24", "hubId": "hub6"},
    {"farmerId": "f25", "hubId": "hub6"}, {"farmerId": "f26", "hubId": "hub6"},
    {"farmerId": "f27", "hubId": "hub6"}, {"farmerId": "f28", "hubId": "hub6"},

    {"farmerId": "f29", "hubId": "hub7"}, {"farmerId": "f30", "hubId": "hub7"},
    {"farmerId": "f31", "hubId": "hub7"}, {"farmerId": "f32", "hubId": "hub7"},
    {"farmerId": "f33", "hubId": "hub7"}, {"farmerId": "f34", "hubId": "hub7"},
    {"farmerId": "f35", "hubId": "hub7"}, {"farmerId": "f36", "hubId": "hub7"},

    {"farmerId": "f37", "hubId": "hub8"}, {"farmerId": "f38", "hubId": "hub8"},
    {"farmerId": "f39", "hubId": "hub8"}, {"farmerId": "f40", "hubId": "hub8"},
    {"farmerId": "f41", "hubId": "hub8"}, {"farmerId": "f42", "hubId": "hub8"},
    {"farmerId": "f43", "hubId": "hub8"},

    {"farmerId": "f44", "hubId": "hub9"}, {"farmerId": "f45", "hubId": "hub9"},
    {"farmerId": "f46", "hubId": "hub9"}, {"farmerId": "f47", "hubId": "hub9"},
    {"farmerId": "f48", "hubId": "hub9"}, {"farmerId": "f49", "hubId": "hub9"},
    {"farmerId": "f50", "hubId": "hub9"}
];

# Same numbers as SEED_HUB_ROUTES/SEED_HUB_MARKET_ROUTES above, re-keyed by
# id for RouteInfo.distanceKm/hours lookups.
glob SEED_HUB_ROUTE_RECORDS: list[dict[str, any]] = [
    {"fromHubId": "hub1", "toHubId": "hub4", "distanceKm": 45.0, "hours": 1.2, "open": True},
    {"fromHubId": "hub1", "toHubId": "hub3", "distanceKm": 72.0, "hours": 2.0, "open": True},
    {"fromHubId": "hub3", "toHubId": "hub4", "distanceKm": 28.0, "hours": 0.8, "open": True},
    {"fromHubId": "hub3", "toHubId": "hub2", "distanceKm": 77.0, "hours": 2.5, "open": True},
    {"fromHubId": "hub4", "toHubId": "hub2", "distanceKm": 95.0, "hours": 3.0, "open": True},

    # Second, separate island-wide component - see the module docstring.
    {"fromHubId": "hub5", "toHubId": "hub6", "distanceKm": 155.0, "hours": 3.0, "open": True},
    {"fromHubId": "hub6", "toHubId": "hub7", "distanceKm": 195.0, "hours": 4.5, "open": True},
    {"fromHubId": "hub6", "toHubId": "hub8", "distanceKm": 180.0, "hours": 4.0, "open": True},
    {"fromHubId": "hub7", "toHubId": "hub8", "distanceKm": 95.0,  "hours": 2.5, "open": True},
    {"fromHubId": "hub8", "toHubId": "hub9", "distanceKm": 100.0, "hours": 2.2, "open": True}
];

glob SEED_HUB_MARKET_ROUTE_RECORDS: list[dict[str, any]] = [
    {"hubId": "hub1", "marketId": "mk1", "distanceKm": 2.0,   "hours": 0.1,  "open": True},
    {"hubId": "hub1", "marketId": "mk3", "distanceKm": 72.0,  "hours": 2.0,  "open": True},
    {"hubId": "hub1", "marketId": "mk2", "distanceKm": 148.0, "hours": 3.5,  "open": True},
    {"hubId": "hub2", "marketId": "mk3", "distanceKm": 77.0,  "hours": 2.5,  "open": True},
    {"hubId": "hub2", "marketId": "mk2", "distanceKm": 180.0, "hours": 5.0,  "open": True},
    {"hubId": "hub2", "marketId": "mk1", "distanceKm": 100.0, "hours": 3.0,  "open": True},
    {"hubId": "hub3", "marketId": "mk3", "distanceKm": 3.0,   "hours": 0.15, "open": True},
    {"hubId": "hub3", "marketId": "mk2", "distanceKm": 115.0, "hours": 3.0,  "open": True},
    {"hubId": "hub3", "marketId": "mk1", "distanceKm": 72.0,  "hours": 2.0,  "open": True},
    {"hubId": "hub4", "marketId": "mk1", "distanceKm": 45.0,  "hours": 1.2,  "open": True},
    {"hubId": "hub4", "marketId": "mk3", "distanceKm": 28.0,  "hours": 0.8,  "open": True},
    {"hubId": "hub4", "marketId": "mk2", "distanceKm": 140.0, "hours": 3.3,  "open": True},

    # Second, separate island-wide component - see the module docstring.
    {"hubId": "hub5", "marketId": "mk4", "distanceKm": 10.0,  "hours": 0.2, "open": True},
    {"hubId": "hub5", "marketId": "mk5", "distanceKm": 155.0, "hours": 3.0, "open": True},
    {"hubId": "hub6", "marketId": "mk5", "distanceKm": 8.0,   "hours": 0.2, "open": True},
    {"hubId": "hub6", "marketId": "mk4", "distanceKm": 155.0, "hours": 3.0, "open": True},
    {"hubId": "hub6", "marketId": "mk6", "distanceKm": 195.0, "hours": 4.5, "open": True},
    {"hubId": "hub7", "marketId": "mk6", "distanceKm": 12.0,  "hours": 0.3, "open": True},
    {"hubId": "hub7", "marketId": "mk7", "distanceKm": 230.0, "hours": 5.0, "open": True},
    {"hubId": "hub8", "marketId": "mk6", "distanceKm": 95.0,  "hours": 2.5, "open": True},
    {"hubId": "hub8", "marketId": "mk7", "distanceKm": 100.0, "hours": 2.2, "open": True},
    {"hubId": "hub9", "marketId": "mk7", "distanceKm": 15.0,  "hours": 0.3, "open": True},
    {"hubId": "hub9", "marketId": "mk6", "distanceKm": 230.0, "hours": 5.0, "open": True}
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
