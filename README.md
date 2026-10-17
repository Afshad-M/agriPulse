# AgriPulse

An agent that watches smallholder harvests, trucks, roads and market
prices, pools farmers into shared routes that beat spoilage, and re-plans
live when something breaks. Built in [Jac](https://www.jaseci.org/) for the
Jaseci AI Hackathon 2026 (University of Moratuwa, 17 Oct 2026).

**All data simulated.** Nothing in this project is connected to real
farmers, hubs, markets, or trucks — see [`docs/assumptions.md`](docs/assumptions.md)
for the full list of invented numbers.

## The problem

Smallholder farmers often ship produce to market alone — paying for a solo
truck and waiting hours for pickup while the harvest loses value to
spoilage. When something goes wrong en route (a truck breaks down, a road
closes, a price crashes) nobody re-plans in real time.

## What it does

1. **Loads** simulated seed data onto the graph (`data.jac` → `api.jac`).
2. Computes a **baseline** plan — every farmer ships alone (`logic.jac`).
3. Runs a **merge walker** that pools farmers onto shared trucks wherever
   capacity and net value allow (`logic.MergeRoutes`).
4. **Re-plans live** on events (truck breakdown, road closed, price crash)
   via `logic.ReplanOnEvent`, explains the decision, and messages each
   affected farmer.
5. Shows a **scoreboard**: baseline vs AgriPulse, computed by code, never
   hardcoded.

## How Jac and Jaseci were used

- **Graph**: `Farmer`, `Harvest`, `Hub`, `Market`, `Truck`, and `Plan` are
  nodes; routes are edges (`models.jac`) — the data model *is* the graph.
- **Walkers**: `MergeRoutes` and `ReplanOnEvent` (`logic.jac`) traverse and
  mutate the graph.
- **`by llm()`**: four functions in `llm.jac` delegate to an LLM where code
  can't do the job — parsing free-text harvest reports, prioritising under
  a capacity shortage (code-validated), and writing farmer messages and
  plan explanations. The LLM never computes a number; every function has a
  labelled, deterministic fallback for when the model fails.
- **Client UI**: the single-page demo is built in Jac client code
  (`frontend.jac`, `components/`).
- **Jac Hammer**: used for deployment.

## Project layout

```
agriPulse/
├── models.jac       (A) — graph node/edge definitions
├── logic.jac        (A) — scoring, merge, re-plan walkers
├── api.jac          (A) — server contract endpoints
├── data.jac         (C) — seed data, routes, demo scenarios
├── llm.jac          (C) — parse_harvest, prioritize, farmer_message, explain
├── frontend.jac /
│   frontend.impl.jac,
│   components/      (B) — client UI
├── docs/            (C) — assumptions
└── CLAUDE.md, AGENTS.md — project rules & Jac tooling workflow
```

## Running locally

```bash
jac install
jac run --dev main.jac   # app at http://localhost:8000
```

## Team

| Lane | Owner | Covers |
|---|---|---|
| Graph, logic, walkers | A | `models.jac`, `logic.jac`, `api.jac`, tests |
| Client UI | B | `frontend.jac`, `components/`, API layer |
| Data, LLM, storytelling | C | `data.jac`, `llm.jac`, docs, README |
