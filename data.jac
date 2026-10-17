"""agriPulse - Seed / Simulated Data (owner: C).

All data in this project is simulated. This module will hold the
representative Farmer/Harvest/Hub/Market/Truck seed records that
load_seed() (api.jac, owner A) attaches to the graph. Skeleton only -
the globs below are empty until owner C fills them in.
"""

import from models { Farmer, Harvest, Hub, Market, Truck }

glob SEED_FARMERS: list[Farmer] = [];
glob SEED_HARVESTS: list[Harvest] = [];
glob SEED_HUBS: list[Hub] = [];
glob SEED_MARKETS: list[Market] = [];
glob SEED_TRUCKS: list[Truck] = [];

# TODO(C): populate the globs above with simulated demo records.
