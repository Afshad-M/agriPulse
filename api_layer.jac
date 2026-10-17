import from mock_api { mock_load_seed, mock_baseline_plan, mock_merge_routes, mock_breakdown }

glob USE_MOCK_API: bool = True;

def fetch_seed() -> dict[str, any] {
    if USE_MOCK_API { return mock_load_seed(); }
    return mock_load_seed();
}

def fetch_baseline_plan() -> dict[str, any] {
    if USE_MOCK_API { return mock_baseline_plan(); }
    return mock_baseline_plan();
}

def fetch_merge_routes() -> dict[str, any] {
    if USE_MOCK_API { return mock_merge_routes(); }
    return mock_merge_routes();
}

def fetch_replan(reason: str) -> dict[str, any] {
    if USE_MOCK_API { return mock_breakdown(); }
    return mock_breakdown();
}
