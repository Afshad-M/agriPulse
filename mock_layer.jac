import from mock_api { mock_merge_routes, mock_breakdown, mock_road_closed, mock_price_crash, mock_new_harvest }

# Split out of api_layer.jac on purpose: api_layer.jac imports from api.jac
# (a server-anchored module, for the real load_seed/baseline_plan RPC
# calls), which makes the WHOLE file server-placed - so a plain `def` in
# it loses its client bridge (E5082, "no client-side presence"). This
# file only imports from mock_api.jac (itself client-safe, no server
# imports), so it stays client-placed and these plain functions resolve
# normally from frontend.jac.

def _unwrap_mock(raw: dict[str, any]) -> dict[str, any] {
    payload = raw["data"]["result"] as dict[str, any];
    payload["source"] = "mock";
    return payload;
}

def:pub fetch_merge_routes() -> dict[str, any] {
    return _unwrap_mock(mock_merge_routes());
}

# event_type matches api.jac's Event.type. `text` is only used by new_harvest.
# :pub here (like mock_api.jac's own functions) is the client-to-client
# export marker, not a server endpoint - this whole module is pinned
# "client" in jac.toml, so there's no server anchor for :pub to register
# an HTTP route against.
def:pub fetch_replan(event_type: str, text: str = "") -> dict[str, any] {
    if event_type == "road_closed" { return _unwrap_mock(mock_road_closed()); }
    if event_type == "price_crash" { return _unwrap_mock(mock_price_crash()); }
    if event_type == "new_harvest" { return _unwrap_mock(mock_new_harvest(text)); }
    return _unwrap_mock(mock_breakdown());
}
