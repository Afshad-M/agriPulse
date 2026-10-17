import from api { load_seed, baseline_plan, merge_routes, replan_on_event, Event,
    FarmerInfo, HarvestInfo, HubInfo, MarketInfo, TruckInfo,
    RouteInfo, PlanInfo, State, ScoreSet, Score, MergeStep, Reassignment, Message }

# Thin CLIENT DATA ADAPTER over the backend contract (CONTRACT v1) - no
# business logic lives here. Every function just calls the matching
# api.jac endpoint in-process and flattens the typed result to plain
# dicts the UI renders. When the backend changes behaviour (e.g. a real
# replan_on_event replacing the stub), nothing in this file or the UI
# needs to change: same endpoints, same shapes.
#
# This module is pinned "server" in jac.toml's [placement.pins] on
# purpose: it imports api.jac -> logic.jac, whose graph-filter syntax
# the client bundler can't lower (E5097) if this file gets inferred
# client. Pinned server + def:pub, each fetch_* function becomes an RPC
# endpoint the client bridges to with `await`.
#
# Event id conventions the UI sends (the Event contract only says "str"):
#   truck_breakdown -> truckId = the TruckInfo.id
#   road_closed     -> edgeId  = "<hubId>-><marketId>" (ids from the state)
#   price_crash     -> marketId = MarketInfo.id, crop = a crop key
#   new_harvest     -> text = free text typed by a farmer/planner

def _farmer_to_dict(f: FarmerInfo) -> dict[str, any] {
    return {"id": f.id, "name": f.name, "district": f.district, "language": f.language};
}

def _harvest_to_dict(h: HarvestInfo) -> dict[str, any] {
    return {"id": h.id, "farmerId": h.farmerId, "crop": h.crop, "kg": h.kg,
            "readyHour": h.readyHour, "shelfLifeHours": h.shelfLifeHours};
}

def _hub_to_dict(h: HubInfo) -> dict[str, any] {
    return {"id": h.id, "name": h.name, "district": h.district};
}

def _market_to_dict(m: MarketInfo) -> dict[str, any] {
    return {"id": m.id, "name": m.name, "prices": m.prices, "demandCapKg": m.demandCapKg};
}

def _truck_to_dict(t: TruckInfo) -> dict[str, any] {
    return {"id": t.id, "name": t.name, "capacityKg": t.capacityKg,
            "costPerKm": t.costPerKm, "status": t.status};
}

def _route_to_dict(r: RouteInfo) -> dict[str, any] {
    return {"id": r.id, "truckId": r.truckId, "farmerIds": r.farmerIds, "hubIds": r.hubIds,
            "marketId": r.marketId, "distanceKm": r.distanceKm, "hours": r.hours};
}

def _plan_to_dict(p: PlanInfo) -> dict[str, any] {
    return {"routeId": p.routeId, "expectedSpoilagePct": p.expectedSpoilagePct,
            "expectedIncome": p.expectedIncome, "truckCost": p.truckCost};
}

def _state_to_dict(s: State) -> dict[str, any] {
    return {
        "farmers": [_farmer_to_dict(f) for f in s.farmers],
        "harvests": [_harvest_to_dict(h) for h in s.harvests],
        "hubs": [_hub_to_dict(h) for h in s.hubs],
        "markets": [_market_to_dict(m) for m in s.markets],
        "trucks": [_truck_to_dict(t) for t in s.trucks],
        "routes": [_route_to_dict(r) for r in s.routes],
        "plans": [_plan_to_dict(p) for p in s.plans]
    };
}

def _score_set_to_dict(ss: ScoreSet) -> dict[str, any] {
    return {"spoilagePct": ss.spoilagePct, "income": ss.income, "truckCost": ss.truckCost};
}

def _score_to_dict(sc: Score) -> dict[str, any] {
    return {"baseline": _score_set_to_dict(sc.baseline), "agent": _score_set_to_dict(sc.agent)};
}

def:pub fetch_seed() -> dict[str, any] {
    result = load_seed();
    return {"state": _state_to_dict(result.state), "source": "real"};
}

def:pub fetch_baseline_plan() -> dict[str, any] {
    result = baseline_plan();
    return {
        "state": _state_to_dict(result.state),
        "score": _score_to_dict(result.score),
        "source": "real"
    };
}

def _step_to_dict(s: MergeStep) -> dict[str, any] {
    return {"stepNo": s.stepNo, "mergedRouteIds": s.mergedRouteIds,
            "newRouteId": s.newRouteId, "reason": s.reason};
}

def _reassignment_to_dict(r: Reassignment) -> dict[str, any] {
    return {"routeId": r.routeId, "fromTruckId": r.fromTruckId, "toTruckId": r.toTruckId};
}

def _message_to_dict(m: Message) -> dict[str, any] {
    return {"farmerId": m.farmerId, "farmerName": m.farmerName, "language": m.language,
            "text": m.text, "isFallback": m.isFallback};
}

def:pub fetch_merge() -> dict[str, any] {
    result = merge_routes();
    return {
        "steps": [_step_to_dict(s) for s in result.steps],
        "state": _state_to_dict(result.state),
        "score": _score_to_dict(result.score),
        "source": "real"
    };
}

# Event.notes is a plain str in the contract; the UI renders a list, so a
# non-empty note becomes a one-item list.
def:pub fetch_event(event_type: str, truck_id: str, edge_id: str, market_id: str,
                    crop: str, text: str) -> dict[str, any] {
    event = Event(
        type=event_type,
        truckId=truck_id if truck_id else None,
        edgeId=edge_id if edge_id else None,
        marketId=market_id if market_id else None,
        crop=crop if crop else None,
        text=text if text else None,
    );
    result = replan_on_event(event);
    notes = [result.diff.notes] if result.diff.notes else [];
    return {
        "diff": {
            "removedRouteIds": result.diff.removedRouteIds,
            "addedRouteIds": result.diff.addedRouteIds,
            "reassigned": [_reassignment_to_dict(r) for r in result.diff.reassigned],
            "notes": notes
        },
        "state": _state_to_dict(result.state),
        "score": _score_to_dict(result.score),
        "explanation": result.explanation,
        "messages": [_message_to_dict(m) for m in result.messages],
        "source": "real"
    };
}
