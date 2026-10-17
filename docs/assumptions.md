# Assumptions (owner: C)

AgriPulse is a hackathon scaffold. **All data is simulated** — there are no
real farmers, hubs, markets, trucks, or deliveries behind any number shown
in the UI.

- Scoring, baseline assignment, route merging, and replanning are
  deterministic code (`logic.jac`). The LLM is never used to compute a
  number.
- The LLM (`llm.jac`) is used only to: parse a farmer's free-text harvest
  report into structured fields (`parse_harvest`), rank candidates
  qualitatively subject to code validation (`prioritize`), draft a
  farmer-facing status message (`farmer_message`), and explain a plan in
  plain language (`explain`). Every one of these falls back to a clearly
  labelled, deterministic message on any model failure or invalid output —
  never a silent guess.
- Distances, travel hours, and hub/market "open" status are placeholder
  seed values (`data.jac`), not real road or market data.

## Seed data specifics (`data.jac`)

- **12 farmers** across four Sri Lankan districts (Dambulla, Nuwara Eliya,
  Kandy, Matale). Names, phone numbers, and harvest quantities are
  invented for this demo.
- **4 crops** with an illustrative shelf-life lookup (not a `models.jac`
  field, just reference data for scoring): tomato 72h, beans 48h, leafy
  greens 24h, carrot 120h.
- **4 hubs**, each with an illustrative `capacity_kg`.
- **3 markets** (Dambulla Economic Centre, Colombo Manning Market, Kandy
  Market), each with a single illustrative aggregate `demand_kg` — the
  `Market` node has no per-crop price or per-crop cap field, so this is a
  simplification versus the original pitch's richer buyer model.
- **3 trucks** (1000kg / 1500kg / 2000kg capacity) with invented plate
  numbers.
- A **hand-written** hub↔hub and hub→market distance/hours matrix
  (`SEED_HUB_ROUTES`, `SEED_HUB_MARKET_ROUTES`) — not from any maps API.
- `harvested_at` on each `Harvest` is a simulated relative offset from
  scenario load time (e.g. `"-2h"` = harvested 2 hours before load), not a
  real timestamp.
- A ready-made **5-farmer merge scenario** (`DEMO_MERGE_SCENARIO`): five
  Dambulla tomato farmers, 880kg combined, well within the smallest
  truck's 1000kg capacity — the "five trips become one" demo moment.
- A matching **truck-breakdown scenario** (`DEMO_BREAKDOWN_SCENARIO`) for
  the live re-plan demo moment.

## Known gaps / open items for the team

- `models.jac`'s `Harvest` node has no shelf-life or farmer-reference
  field, and no edge links a `Harvest` to its `Farmer` or `Hub` yet.
  `data.jac` documents the convention that `SEED_HARVESTS[i]` belongs to
  `SEED_FARMERS[i]` (same index) until a real edge exists — flag to A if a
  different convention is wanted.
- `Market` has one aggregate `demand_kg`, not per-crop price/cap as in the
  original pitch. If per-crop pricing is wanted for the scoreboard story,
  that's a `models.jac` change (A) before `data.jac` can supply it.
- This was validated locally with the `jac` CLI available in this
  environment; if that differs from the version the team standardised on
  (per the playbook's 9:15 version-match step), re-run `jac check` against
  the agreed version before merging.
