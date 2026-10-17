# AgriPulse - project rules

AgriPulse is a hackathon scaffold. These rules govern how this project is
built; see `AGENTS.md` for the Jac tooling workflow (guides, `jac check`,
`jac run`) that applies while following them.

- **100% Jac.** No hand-written Python, JavaScript, TypeScript, CSS, or
  HTML files. Backend, graph, walkers, `by llm()` functions, seed data, and
  client UI are all Jac. Markdown and config (`jac.toml`, `.gitignore`) are
  fine.
- Run `jac guide <name>` before writing or editing Jac; validate every
  change with the jac MCP tools (or `jac check`) before calling it done.
- Run the app with `jac run` (`jac start` was removed; use
  `jac run --dev main.jac` for the dev server with hot reload).
- All data is simulated. Say so in the UI footer and in `README.md`.
- Scoring and merge/replan (`logic.jac`) are deterministic code. The LLM
  never computes numbers.
- `by llm()` is used only for: `parse_harvest`, `prioritize` (validated in
  code, never trusted blindly), `farmer_message`, and `explain` - all in
  `llm.jac`.
- Never commit secrets. Use `.env` / `jac.toml` for configuration and keys.

## Ownership

- **A** = `models.jac`, `logic.jac`, `api.jac`, and the `*.test.jac` test
  annexes.
- **B** = client: `api_layer.jac`, `mock_api.jac`, `frontend.jac`,
  `frontend.impl.jac`, and `components/`.
- **C** = `data.jac`, `llm.jac`, `docs/`, `README.md`.

Don't edit outside your lane without asking.
