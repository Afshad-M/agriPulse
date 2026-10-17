# Assumptions (owner: C)

AgriPulse is a hackathon scaffold. **All data is simulated** - there are no
real farmers, hubs, markets, trucks, or deliveries behind any number shown
in the UI.

- Scoring, baseline assignment, route merging, and replanning are
  deterministic code (`logic.jac`). The LLM is never used to compute a
  number.
- The LLM (`llm.jac`) is used only to: parse a farmer's free-text harvest
  report into structured fields (`parse_harvest`), rank candidates
  qualitatively subject to code validation (`prioritize`), draft a
  farmer-facing status message (`farmer_message`), and explain a plan in
  plain language (`explain`).
- Distances, travel hours, and hub/market "open" status are placeholder
  seed values, not real road or market data.
- No persistence guarantees beyond what `jac run`'s local graph store
  provides for this demo.

TODO(C): expand with concrete seed-data assumptions once `data.jac` is
populated.
