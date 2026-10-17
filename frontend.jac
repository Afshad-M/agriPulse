import from .api_layer { fetch_seed, fetch_baseline_plan }
import from .mock_layer { fetch_merge_routes, fetch_replan }

# Entire new UI (C, proposed - see PR description): dark professional
# dashboard with a persistent sidebar, genuinely different layout from the
# earlier single-column stacked page. load_seed/baseline_plan now call A's
# real endpoints (typed RPC via api_layer.jac); merge_routes/replan_on_event
# still use B's mock data since those two are still server-side stubs.
# Every fetch result carries source: "real" | "mock", shown as a badge -
# the same transparency principle as the isFallback badge on LLM messages.
glob THEME: dict[str, str] = {
    "bg": "#0D1210", "sidebar": "#111713", "panel": "#161D18", "panelAlt": "#1B2420",
    "border": "#262F29", "borderStrong": "#374239",
    "ink": "#EDF2EE", "muted": "#96A49B", "subtle": "#67766C",
    "green": "#3FBF7F", "greenSoft": "rgba(63,191,127,0.14)", "greenStrong": "#5FD99A",
    "blue": "#5AA8EE", "blueSoft": "rgba(90,168,238,0.14)",
    "ochre": "#E3AE48", "ochreSoft": "rgba(227,174,72,0.14)",
    "plum": "#C090E6", "plumSoft": "rgba(192,144,230,0.14)",
    "red": "#E57C70", "redSoft": "rgba(229,124,112,0.14)",
    "radius": "12px", "radiusSm": "7px"
};

glob EVENT_BUTTONS: list[dict[str, str]] = [
    {"type": "truck_breakdown", "label": "Truck breakdown"},
    {"type": "road_closed", "label": "Road closed"},
    {"type": "price_crash", "label": "Price crash"}
];

def:pub app -> JsxElement {
    has state: dict[str, any] = {},
        score: dict[str, any] = {},
        diff: dict[str, any] = {},
        steps: list[dict[str, any]] = [],
        messages: list[dict[str, any]] = [],
        explanation: str = "",
        loading: bool = True,
        error: str = "",
        event_done: bool = False,
        scenario: str = "Baseline plan",
        active_event: str = "",
        new_harvest_text: str = "",
        data_source: str = "real";

    async can with entry {
        try {
            seed_result = await fetch_seed();
            baseline_result = await fetch_baseline_plan();
            state = baseline_result["state"] as dict[str, any];
            score = baseline_result["score"] as dict[str, any];
            data_source = baseline_result["source"] as str;
        } except Exception {
            error = "Failed to load seed/baseline data from the server.";
        }
        loading = False;
    }

    def merge_routes_action(e: MouseEvent) {
        error = "";
        try {
            payload = fetch_merge_routes();
            state = payload["state"] as dict[str, any];
            score = payload["score"] as dict[str, any];
            steps = payload["steps"] as list[dict[str, any]];
            data_source = payload["source"] as str;
            scenario = "Merged routes";
            event_done = False;
            active_event = "";
        } except Exception {
            error = "Route merge failed. Retry the merge action.";
        }
    }

    def apply_replan_result(payload: dict[str, any], label: str, event_type: str) {
        state = payload["state"] as dict[str, any];
        score = payload["score"] as dict[str, any];
        diff = payload["diff"] as dict[str, any];
        messages = payload["messages"] as list[dict[str, any]];
        explanation = payload["explanation"] as str;
        data_source = payload["source"] as str;
        scenario = label;
        active_event = event_type;
        event_done = True;
    }

    def fire_event(event_type: str, label: str) {
        error = "";
        try {
            payload = fetch_replan(event_type);
            apply_replan_result(payload, label, event_type);
        } except Exception {
            error = label + " failed. Retry the event.";
        }
    }

    def handle_event_click(e: MouseEvent, event_type: str, label: str) {
        fire_event(event_type, label);
    }

    def handle_new_harvest_input(e: ChangeEvent) {
        new_harvest_text = e.target.value;
    }

    def submit_new_harvest(e: MouseEvent) {
        error = "";
        if len(new_harvest_text.strip()) == 0 {
            error = "Enter a harvest description before submitting.";
            return;
        }
        try {
            payload = fetch_replan("new_harvest", new_harvest_text);
            apply_replan_result(payload, "New harvest logged", "new_harvest");
            new_harvest_text = "";
        } except Exception {
            error = "New harvest submission failed. Retry.";
        }
    }

    farmers = (state["farmers"] as list[dict[str, any]]) if state else [];
    harvests = (state["harvests"] as list[dict[str, any]]) if state else [];
    hubs = (state["hubs"] as list[dict[str, any]]) if state else [];
    markets = (state["markets"] as list[dict[str, any]]) if state else [];
    trucks = (state["trucks"] as list[dict[str, any]]) if state else [];
    routes = (state["routes"] as list[dict[str, any]]) if state else [];
    baseline_score = score["baseline"] as dict[str, any] if score else {};
    agent_score = score["agent"] as dict[str, any] if score else {};
    removed_ids = diff["removedRouteIds"] as list[str] if diff else [];
    added_ids = diff["addedRouteIds"] as list[str] if diff else [];
    diff_notes = diff["notes"] as list[str] if diff and "notes" in diff else [];

    # Trucks differ between the real seed (data.jac) and B's mock data (ids,
    # names, how many), so route rows look the truck's real name up by id
    # instead of assuming fixed ids like the earlier version did.
    truck_name_by_id: dict[str, str] = {};
    for t in trucks { truck_name_by_id[t["id"] as str] = t["name"] as str; }
    truck_color_by_id: dict[str, str] = {};
    truck_palette = [THEME["blue"], THEME["ochre"], THEME["plum"], THEME["green"], THEME["red"]];
    for i in range(len(trucks)) {
        truck_color_by_id[trucks[i]["id"] as str] = truck_palette[i % len(truck_palette)];
    }

    spoilage_better = (agent_score["spoilagePct"] as float) < (baseline_score["spoilagePct"] as float) if score else False;
    income_better = (agent_score["income"] as float) > (baseline_score["income"] as float) if score else False;
    cost_better = (agent_score["truckCost"] as float) < (baseline_score["truckCost"] as float) if score else False;
    delta_color = THEME["greenStrong"];
    neutral_color = THEME["ink"];

    return <div style={{"minHeight":"100vh", "display":"flex", "backgroundColor":THEME["bg"], "color":THEME["ink"], "fontFamily":"system-ui, -apple-system, BlinkMacSystemFont, sans-serif", "fontSize":"15px", "lineHeight":"1.5"}}>
      <aside style={{"width":"272px", "flexShrink":"0", "backgroundColor":THEME["sidebar"], "borderRight":"1px solid " + THEME["border"], "display":"flex", "flexDirection":"column", "padding":"22px 18px", "gap":"22px", "position":"sticky", "top":"0", "height":"100vh", "overflowY":"auto"}}>
        <div style={{"display":"flex", "alignItems":"center", "gap":"10px"}}>
          <div style={{"width":"34px", "height":"34px", "display":"grid", "placeItems":"center", "backgroundColor":THEME["green"], "color":"#0D1210", "fontWeight":"800", "fontSize":"16px", "borderRadius":THEME["radiusSm"]}}>A</div>
          <div><strong style={{"fontSize":"17px", "letterSpacing":"-0.01em"}}>AgriPulse</strong><div style={{"fontSize":"12px", "color":THEME["muted"]}}>Harvest-to-market agent</div></div>
        </div>

        <div style={{"padding":"12px 14px", "backgroundColor":THEME["panel"], "border":"1px solid " + THEME["border"], "borderRadius":THEME["radius"]}}>
          <div style={{"fontSize":"11px", "color":THEME["subtle"], "textTransform":"uppercase", "letterSpacing":"0.04em", "marginBottom":"6px"}}>Current scenario</div>
          <div style={{"fontSize":"14px", "fontWeight":"600", "marginBottom":"8px"}}>{scenario}</div>
          <span style={{"display":"inline-block", "padding":"3px 9px", "borderRadius":"999px", "fontSize":"11px", "fontWeight":"700", "letterSpacing":"0.02em", "backgroundColor": THEME["greenSoft"] if data_source == "real" else THEME["ochreSoft"], "color": THEME["greenStrong"] if data_source == "real" else THEME["ochre"]}}>{"● LIVE (code-computed)" if data_source == "real" else "● SIMULATED (mock)"}</span>
        </div>

        <div>
          <div style={{"fontSize":"11px", "color":THEME["subtle"], "textTransform":"uppercase", "letterSpacing":"0.04em", "marginBottom":"10px"}}>Simulate an event</div>
          <div style={{"display":"flex", "flexDirection":"column", "gap":"8px", "marginBottom":"14px"}}>
            {for btn in EVENT_BUTTONS {
              is_active = active_event == btn["type"];
              <button
                key={btn["type"]}
                onClick={lambda (e: MouseEvent) { handle_event_click(e, btn["type"], btn["label"]); }}
                disabled={loading}
                style={{
                  "width":"100%", "textAlign":"left", "padding":"10px 12px",
                  "backgroundColor": THEME["green"] if is_active else THEME["panel"],
                  "color": "#0D1210" if is_active else THEME["ink"],
                  "border":"1px solid " + (THEME["green"] if is_active else THEME["border"]),
                  "borderRadius":THEME["radiusSm"], "fontSize":"14px", "fontWeight":"600",
                  "cursor":"pointer", "opacity": "0.5" if loading else "1"
                }}
              >{btn["label"]}</button>
            }}
          </div>
          <textarea
            value={new_harvest_text}
            onChange={handle_new_harvest_input}
            placeholder="New harvest, free text - e.g. '~80kg beans near Matale, ready in 2 hours'"
            rows={3}
            style={{"width":"100%", "padding":"10px 12px", "backgroundColor":THEME["panel"], "color":THEME["ink"], "border":"1px solid " + THEME["border"], "borderRadius":THEME["radiusSm"], "fontSize":"13px", "resize":"vertical", "marginBottom":"8px", "fontFamily":"inherit"}}
          />
          <button onClick={submit_new_harvest} disabled={loading} style={{"width":"100%", "padding":"10px 12px", "backgroundColor":THEME["blue"], "color":"#0D1210", "border":"1px solid " + THEME["blue"], "borderRadius":THEME["radiusSm"], "fontSize":"14px", "fontWeight":"700", "cursor":"pointer", "opacity": "0.5" if loading else "1"}}>Log new harvest</button>
        </div>

        <button onClick={merge_routes_action} disabled={loading} style={{"width":"100%", "padding":"12px", "backgroundColor":"transparent", "color":THEME["green"], "border":"1.5px solid " + THEME["green"], "borderRadius":THEME["radiusSm"], "fontSize":"14px", "fontWeight":"700", "cursor":"pointer", "opacity": "0.5" if loading else "1"}}>⇄ Merge routes</button>

        <div style={{"marginTop":"auto", "fontSize":"11px", "color":THEME["subtle"], "paddingTop":"14px", "borderTop":"1px solid " + THEME["border"]}}>All data simulated. Built in Jac for the Jaseci AI Hackathon.</div>
      </aside>

      <main style={{"flex":"1", "padding":"28px 32px", "maxWidth":"1240px"}}>
        <div style={{"marginBottom":"22px"}}><h1 style={{"fontSize":"26px", "margin":"0 0 6px", "letterSpacing":"-0.015em"}}>Sri Lanka produce network</h1><p style={{"margin":"0", "color":THEME["muted"]}}>Harvest readiness, route performance and disruption planning.</p></div>
        {if error { <div role="alert" style={{"padding":"14px 16px", "marginBottom":"16px", "color":THEME["red"], "backgroundColor":THEME["redSoft"], "border":"1px solid " + THEME["red"], "borderRadius":THEME["radius"]}}>{error}</div> }}
        {if loading { <div role="status" style={{"padding":"18px", "backgroundColor":THEME["panel"], "border":"1px solid " + THEME["border"], "borderRadius":THEME["radius"], "color":THEME["muted"]}}>Loading seed and baseline data…</div> }}
        {if not loading {
          <div>
            <section style={{"display":"grid", "gridTemplateColumns":"repeat(auto-fit, minmax(150px, 1fr))", "border":"1px solid " + THEME["border"], "backgroundColor":THEME["panel"], "borderRadius":THEME["radius"], "marginBottom":"20px", "overflow":"hidden"}}>
              <div style={{"padding":"16px 18px", "borderRight":"1px solid " + THEME["border"]}}><div style={{"color":THEME["muted"], "fontSize":"12px", "fontWeight":"600", "letterSpacing":"0.02em", "textTransform":"uppercase"}}>Farmers</div><strong style={{"fontSize":"30px", "fontVariantNumeric":"tabular-nums", "color":THEME["greenStrong"]}}>{str(len(farmers))}</strong></div>
              <div style={{"padding":"16px 18px", "borderRight":"1px solid " + THEME["border"]}}><div style={{"color":THEME["muted"], "fontSize":"12px", "fontWeight":"600", "letterSpacing":"0.02em", "textTransform":"uppercase"}}>Harvests</div><strong style={{"fontSize":"30px", "fontVariantNumeric":"tabular-nums", "color":THEME["greenStrong"]}}>{str(len(harvests))}</strong></div>
              <div style={{"padding":"16px 18px", "borderRight":"1px solid " + THEME["border"]}}><div style={{"color":THEME["muted"], "fontSize":"12px", "fontWeight":"600", "letterSpacing":"0.02em", "textTransform":"uppercase"}}>Hubs</div><strong style={{"fontSize":"30px", "fontVariantNumeric":"tabular-nums", "color":THEME["greenStrong"]}}>{str(len(hubs))}</strong></div>
              <div style={{"padding":"16px 18px", "borderRight":"1px solid " + THEME["border"]}}><div style={{"color":THEME["muted"], "fontSize":"12px", "fontWeight":"600", "letterSpacing":"0.02em", "textTransform":"uppercase"}}>Markets</div><strong style={{"fontSize":"30px", "fontVariantNumeric":"tabular-nums", "color":THEME["greenStrong"]}}>{str(len(markets))}</strong></div>
              <div style={{"padding":"16px 18px"}}><div style={{"color":THEME["muted"], "fontSize":"12px", "fontWeight":"600", "letterSpacing":"0.02em", "textTransform":"uppercase"}}>Routes</div><strong style={{"fontSize":"30px", "fontVariantNumeric":"tabular-nums", "color":THEME["greenStrong"]}}>{str(len(routes))}</strong><div style={{"fontSize":"12px", "color":THEME["subtle"]}}>{str(len(trucks))} trucks</div></div>
            </section>

            <div style={{"display":"grid", "gridTemplateColumns":"minmax(0, 1.7fr) minmax(280px, 1fr)", "gap":"18px", "alignItems":"start"}}>
              <section style={{"backgroundColor":THEME["panel"], "border":"1px solid " + THEME["border"], "borderRadius":THEME["radius"], "minWidth":"0", "overflow":"hidden"}}>
                <div style={{"padding":"16px 18px", "borderBottom":"1px solid " + THEME["border"]}}><h2 style={{"margin":"0 0 4px", "fontSize":"17px"}}>Routes and assignments</h2><div style={{"color":THEME["muted"], "fontSize":"13px"}}>{str(len(routes))} active {"route" if len(routes) == 1 else "routes"} across {str(len(trucks))} trucks.</div></div>
                <div style={{"display":"flex", "gap":"8px", "flexWrap":"wrap", "padding":"12px 18px", "borderBottom":"1px solid " + THEME["border"]}}>
                  {for t in trucks { <span key={t["id"]} style={{"padding":"4px 10px", "borderRadius":"999px", "backgroundColor":"rgba(255,255,255,0.04)", "color":truck_color_by_id[t["id"] as str], "fontWeight":"600", "fontSize":"12px", "border":"1px solid " + THEME["border"]}}>● {t["name"]}</span> }}
                  {if event_done { <span style={{"padding":"4px 10px", "borderRadius":"999px", "backgroundColor":THEME["redSoft"], "color":THEME["red"], "fontWeight":"600", "fontSize":"12px"}}>┄ Removed</span><span style={{"padding":"4px 10px", "borderRadius":"999px", "backgroundColor":THEME["greenSoft"], "color":THEME["greenStrong"], "fontWeight":"600", "fontSize":"12px"}}>● New route</span> }}
                </div>
                <div style={{"padding":"8px 18px 18px"}}>
                  {for route in routes {
                    removed = route["id"] in removed_ids;
                    added = route["id"] in added_ids;
                    truck_id = route["truckId"] as str;
                    assigned_name = truck_name_by_id[truck_id] if truck_id in truck_name_by_id else truck_id;
                    row_bg = THEME["redSoft"] if removed else THEME["greenSoft"] if added else THEME["panelAlt"];
                    row_border = "1px dashed " + THEME["red"] if removed else "1px solid " + THEME["green"] if added else "1px solid " + THEME["border"];
                    <div key={route["id"]} style={{"display":"flex", "justifyContent":"space-between", "flexWrap":"wrap", "gap":"8px", "padding":"12px 14px", "backgroundColor":row_bg, "border":row_border, "borderRadius":THEME["radiusSm"], "marginTop":"8px"}}>
                      <span><strong>{route["id"]}</strong> · {str(len(route["farmerIds"] as list[str]))} farmer lots → {route["marketId"]}{" · Removed" if removed else " · New" if added else ""}</span>
                      <span style={{"color":THEME["muted"]}}>{assigned_name} · {str(route["distanceKm"])} km</span>
                    </div>
                  }}
                  {if len(routes) == 0 { <p style={{"color":THEME["muted"], "fontSize":"14px"}}>No routes yet.</p> }}
                </div>
              </section>

              <aside style={{"display":"flex", "flexDirection":"column", "gap":"16px"}}>
                <section style={{"padding":"16px 18px", "backgroundColor":THEME["panel"], "border":"1px solid " + THEME["border"], "borderRadius":THEME["radius"]}}><h2 style={{"fontSize":"17px", "margin":"0 0 12px"}}>Baseline and agent score</h2>
                  {if score { <div>
                    <div style={{"display":"grid", "gridTemplateColumns":"1fr 1fr 1fr", "gap":"8px", "padding":"4px 0 10px", "borderBottom":"1px solid " + THEME["border"], "fontSize":"13px"}}>
                      <strong style={{"color":THEME["muted"], "fontSize":"11px", "textTransform":"uppercase", "letterSpacing":"0.02em"}}>Measure</strong><strong style={{"color":THEME["muted"], "fontSize":"11px", "textTransform":"uppercase", "letterSpacing":"0.02em"}}>Baseline</strong><strong style={{"color":THEME["muted"], "fontSize":"11px", "textTransform":"uppercase", "letterSpacing":"0.02em"}}>Agent</strong>
                      <span>Spoilage</span><span style={{"color":THEME["muted"]}}>{str(round(baseline_score["spoilagePct"] as float, 1))}%</span><b style={{"color": delta_color if spoilage_better else neutral_color}}>{str(round(agent_score["spoilagePct"] as float, 1))}%{" ↓" if spoilage_better else ""}</b>
                      <span>Income</span><span style={{"color":THEME["muted"]}}>LKR {str(round(baseline_score["income"] as float, 0))}</span><b style={{"color": delta_color if income_better else neutral_color}}>LKR {str(round(agent_score["income"] as float, 0))}{" ↑" if income_better else ""}</b>
                      <span>Truck cost</span><span style={{"color":THEME["muted"]}}>LKR {str(round(baseline_score["truckCost"] as float, 0))}</span><b style={{"color": delta_color if cost_better else neutral_color}}>LKR {str(round(agent_score["truckCost"] as float, 0))}{" ↓" if cost_better else ""}</b>
                    </div>
                  </div> } else { <p style={{"color":THEME["muted"]}}>Scores will appear after the baseline plan loads.</p> }}
                  {if len(steps) > 0 { <div style={{"padding":"12px", "backgroundColor":THEME["greenSoft"], "border":"1px solid " + THEME["green"], "borderRadius":THEME["radiusSm"], "marginTop":"12px"}}><strong style={{"color":THEME["greenStrong"]}}>Route merge complete</strong>{for step in steps { <p key={step["newRouteId"]} style={{"margin":"6px 0 0", "fontSize":"13px"}}>Step {str(step["stepNo"])}: {step["reason"]}</p> }}</div> }}
                  {if event_done { <div style={{"padding":"12px", "backgroundColor":THEME["ochreSoft"], "border":"1px solid " + THEME["ochre"], "borderRadius":THEME["radiusSm"], "marginTop":"12px"}}>
                    {if len(removed_ids) > 0 { <p style={{"margin":"0 0 4px", "fontSize":"13px"}}><strong style={{"color":THEME["ochre"]}}>Removed</strong> {" · ".join(removed_ids)}</p> }}
                    {if len(added_ids) > 0 { <p style={{"margin":"0 0 6px", "fontSize":"13px"}}><strong style={{"color":THEME["ochre"]}}>New</strong> {" · ".join(added_ids)}</p> }}
                    {for note in diff_notes { <p key={note} style={{"margin":"0 0 4px", "fontSize":"12px", "color":THEME["muted"]}}>{note}</p> }}
                    <p style={{"fontSize":"13px", "marginTop":"6px"}}>{explanation}</p>
                  </div> }}
                </section>
                <section style={{"padding":"16px 18px", "backgroundColor":THEME["panel"], "border":"1px solid " + THEME["border"], "borderRadius":THEME["radius"]}}><h2 style={{"fontSize":"17px", "margin":"0 0 10px"}}>Fleet status</h2>{for truck in trucks { <div key={truck["id"]} style={{"padding":"8px 0", "borderBottom":"1px solid " + THEME["border"], "display":"flex", "justifyContent":"space-between", "alignItems":"center", "gap":"10px"}}><span>{truck["name"]} · {str(truck["capacityKg"])} kg</span><strong style={{"padding":"3px 10px", "borderRadius":"999px", "fontSize":"12px", "backgroundColor": THEME["redSoft"] if truck["status"] == "broken" else THEME["greenSoft"], "color":THEME["red"] if truck["status"] == "broken" else THEME["greenStrong"]}}>{truck["status"]}</strong></div> }}</section>
                <section style={{"padding":"16px 18px", "backgroundColor":THEME["panel"], "border":"1px solid " + THEME["border"], "borderRadius":THEME["radius"]}}><h2 style={{"fontSize":"17px", "margin":"0 0 10px"}}>Market prices</h2>{for market in markets {
                  prices = market["prices"] as dict[str, float];
                  <div key={market["id"]} style={{"padding":"8px 0", "borderBottom":"1px solid " + THEME["border"]}}>
                    <strong>{market["name"]}</strong>
                    <div style={{"fontSize":"12px", "color":THEME["muted"], "marginTop":"2px"}}>{for crop in prices.keys() { <span key={crop}>{crop} LKR {str(prices[crop])}/kg&nbsp;&nbsp;</span> }}· demand {str(market["demandCapKg"])} kg</div>
                  </div>
                }}</section>
              </aside>
            </div>

            {if event_done { <section style={{"padding":"16px 18px", "backgroundColor":THEME["panel"], "border":"1px solid " + THEME["border"], "borderRadius":THEME["radius"], "marginTop":"18px"}}><h2 style={{"fontSize":"17px", "marginBottom":"4px"}}>Farmer updates</h2>{for message in messages { <div key={message["farmerId"]} style={{"padding":"10px 0", "borderTop":"1px solid " + THEME["border"], "display":"flex", "alignItems":"baseline", "gap":"8px", "flexWrap":"wrap"}}><strong>{message["farmerName"]}</strong><span style={{"fontSize":"11px", "color":THEME["subtle"], "textTransform":"uppercase", "letterSpacing":"0.02em"}}>{message["language"]}</span><span>{message["text"]}</span>{if message["isFallback"] { <span style={{"padding":"2px 8px", "borderRadius":"999px", "backgroundColor":THEME["ochreSoft"], "color":THEME["ochre"], "fontSize":"11px", "fontWeight":"600"}}>fallback</span> }}</div> }}</section> }}
          </div>
        }}
      </main>
    </div>;
}
