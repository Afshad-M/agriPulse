import from .api_layer { fetch_seed, fetch_baseline_plan }
import from .mock_layer { fetch_merge_routes, fetch_replan }

# Second design pass (C, proposed): deliberately NOT the generic SaaS-
# dashboard look (stat-card grid + soft pill badges + uniform rounded
# shadow-boxes everywhere). Instead: a serif/mono type pairing, bracket-
# style status text ([LIVE], [BROKEN]) instead of pill badges, left-
# accent bars instead of tinted backgrounds, hairline borders instead of
# drop shadows, and a light/dark toggle (two full palettes, same keys).
glob THEME_LIGHT: dict[str, str] = {
    "bg": "#FAF7F0", "sidebar": "#F1ECE0", "panel": "#FFFFFF", "panelAlt": "#F5F1E6",
    "border": "#DBD4C1", "borderStrong": "#B6AC90",
    "ink": "#1C1A13", "muted": "#6B6553", "subtle": "#948C73",
    "green": "#2F6B4F", "blue": "#3A5A8C", "ochre": "#A3691D", "plum": "#6B4A72", "red": "#A23E2E",
    "onAccent": "#FAF7F0"
};

glob THEME_DARK: dict[str, str] = {
    "bg": "#14120E", "sidebar": "#1A1711", "panel": "#1E1A13", "panelAlt": "#242017",
    "border": "#362F23", "borderStrong": "#4B4333",
    "ink": "#ECE6D6", "muted": "#A69D87", "subtle": "#79715D",
    "green": "#5C9A78", "blue": "#6E8FBF", "ochre": "#C99448", "plum": "#A684B0", "red": "#C16955",
    "onAccent": "#14120E"
};

glob FONT_SERIF: str = "'Iowan Old Style', 'Palatino Linotype', Palatino, Georgia, 'Times New Roman', serif";
glob FONT_MONO: str = "ui-monospace, 'SF Mono', Menlo, Consolas, 'Liberation Mono', monospace";
glob FONT_SANS: str = "-apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif";

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
        data_source: str = "real",
        theme_mode: str = "light";

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

    def set_theme(mode: str) {
        theme_mode = mode;
    }

    THEME = THEME_LIGHT if theme_mode == "light" else THEME_DARK;

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

    # Real seed (data.jac) and B's mock data use different truck ids/names
    # entirely, so route rows look the truck up by id rather than
    # assuming a fixed id scheme.
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

    return <div style={{"minHeight":"100vh", "display":"flex", "backgroundColor":THEME["bg"], "color":THEME["ink"], "fontFamily":FONT_SANS, "fontSize":"15px", "lineHeight":"1.55"}}>
      <aside style={{"width":"268px", "flexShrink":"0", "backgroundColor":THEME["sidebar"], "borderRight":"1px solid " + THEME["border"], "display":"flex", "flexDirection":"column", "padding":"26px 20px", "position":"sticky", "top":"0", "height":"100vh", "overflowY":"auto"}}>

        <div style={{"marginBottom":"28px"}}>
          <div style={{"fontFamily":FONT_MONO, "fontSize":"11px", "letterSpacing":"0.12em", "color":THEME["subtle"], "marginBottom":"2px"}}>AGRIPULSE</div>
          <div style={{"fontFamily":FONT_SERIF, "fontStyle":"italic", "fontSize":"15px", "color":THEME["muted"]}}>Harvest-to-market agent</div>
          <div style={{"display":"flex", "gap":"10px", "marginTop":"10px", "fontFamily":FONT_MONO, "fontSize":"11px"}}>
            <span onClick={lambda (e: MouseEvent) { set_theme("light"); }} style={{"cursor":"pointer", "color": THEME["ink"] if theme_mode == "light" else THEME["subtle"], "textDecoration": "underline" if theme_mode == "light" else "none", "fontWeight": "700" if theme_mode == "light" else "400"}}>LIGHT</span>
            <span style={{"color":THEME["border"]}}>/</span>
            <span onClick={lambda (e: MouseEvent) { set_theme("dark"); }} style={{"cursor":"pointer", "color": THEME["ink"] if theme_mode == "dark" else THEME["subtle"], "textDecoration": "underline" if theme_mode == "dark" else "none", "fontWeight": "700" if theme_mode == "dark" else "400"}}>DARK</span>
          </div>
        </div>

        <div style={{"paddingTop":"14px", "paddingBottom":"18px", "borderTop":"1px solid " + THEME["border"], "marginBottom":"4px"}}>
          <div style={{"fontFamily":FONT_MONO, "fontSize":"10px", "letterSpacing":"0.1em", "color":THEME["subtle"], "marginBottom":"6px"}}>SCENARIO</div>
          <div style={{"fontFamily":FONT_SERIF, "fontSize":"18px", "marginBottom":"8px"}}>{scenario}</div>
          <div style={{"fontFamily":FONT_MONO, "fontSize":"11px", "fontWeight":"700", "letterSpacing":"0.04em", "color": THEME["green"] if data_source == "real" else THEME["ochre"]}}>{"[ LIVE — code-computed ]" if data_source == "real" else "[ SIMULATED — mock ]"}</div>
        </div>

        <div style={{"paddingTop":"14px", "paddingBottom":"18px", "borderTop":"1px solid " + THEME["border"]}}>
          <div style={{"fontFamily":FONT_MONO, "fontSize":"10px", "letterSpacing":"0.1em", "color":THEME["subtle"], "marginBottom":"12px"}}>SIMULATE AN EVENT</div>
          <div style={{"display":"flex", "flexDirection":"column", "marginBottom":"16px"}}>
            {for btn in EVENT_BUTTONS {
              is_active = active_event == btn["type"];
              <button
                key={btn["type"]}
                onClick={lambda (e: MouseEvent) { handle_event_click(e, btn["type"], btn["label"]); }}
                disabled={loading}
                style={{
                  "width":"100%", "textAlign":"left", "padding":"9px 0 9px 12px", "marginBottom":"2px",
                  "backgroundColor":"transparent", "color": THEME["ink"] if is_active else THEME["muted"],
                  "borderTop":"none", "borderRight":"none", "borderBottom":"none",
                  "borderLeft": "3px solid " + (THEME["green"] if is_active else "transparent"),
                  "fontSize":"14px", "fontWeight": "700" if is_active else "400", "fontFamily":"inherit",
                  "cursor":"pointer", "opacity": "0.5" if loading else "1"
                }}
              >{btn["label"]}</button>
            }}
          </div>
          <div style={{"fontFamily":FONT_MONO, "fontSize":"10px", "letterSpacing":"0.1em", "color":THEME["subtle"], "marginBottom":"8px"}}>NEW HARVEST</div>
          <textarea
            value={new_harvest_text}
            onChange={handle_new_harvest_input}
            placeholder="~80kg beans near Matale, ready in 2 hours"
            rows={3}
            style={{"width":"100%", "padding":"8px 0", "backgroundColor":"transparent", "color":THEME["ink"], "border":"none", "borderBottom":"1px solid " + THEME["borderStrong"], "borderRadius":"0", "fontSize":"13px", "resize":"vertical", "marginBottom":"10px", "fontFamily":"inherit"}}
          />
          <button onClick={submit_new_harvest} disabled={loading} style={{"width":"100%", "padding":"9px 0", "backgroundColor":"transparent", "color":THEME["blue"], "border":"1px solid " + THEME["blue"], "borderRadius":"0", "fontSize":"13px", "fontWeight":"700", "fontFamily":FONT_MONO, "letterSpacing":"0.03em", "cursor":"pointer", "opacity": "0.5" if loading else "1"}}>LOG HARVEST</button>
        </div>

        <div style={{"paddingTop":"18px", "borderTop":"1px solid " + THEME["border"]}}>
          <button onClick={merge_routes_action} disabled={loading} style={{"width":"100%", "padding":"11px 0", "backgroundColor":THEME["green"], "color":THEME["onAccent"], "border":"none", "borderRadius":"0", "fontSize":"14px", "fontWeight":"700", "fontFamily":FONT_SERIF, "fontStyle":"italic", "cursor":"pointer", "opacity": "0.5" if loading else "1"}}>Merge routes</button>
        </div>

        <div style={{"marginTop":"auto", "fontFamily":FONT_SERIF, "fontStyle":"italic", "fontSize":"12px", "color":THEME["subtle"], "paddingTop":"18px", "borderTop":"1px solid " + THEME["border"]}}>All data simulated. Built in Jac for the Jaseci AI Hackathon.</div>
      </aside>

      <main style={{"flex":"1", "padding":"34px 38px", "maxWidth":"1240px"}}>
        <div style={{"marginBottom":"26px"}}>
          <h1 style={{"fontFamily":FONT_SERIF, "fontSize":"32px", "fontWeight":"400", "margin":"0 0 6px", "letterSpacing":"-0.01em"}}>Sri Lanka produce network</h1>
          <p style={{"margin":"0", "color":THEME["muted"], "fontFamily":FONT_SERIF, "fontStyle":"italic", "fontSize":"15px"}}>Harvest readiness, route performance and disruption planning.</p>
        </div>
        {if error { <div role="alert" style={{"padding":"12px 16px", "marginBottom":"18px", "color":THEME["red"], "borderLeft":"3px solid " + THEME["red"], "backgroundColor":THEME["panelAlt"], "fontSize":"14px"}}>{error}</div> }}
        {if loading { <div role="status" style={{"padding":"16px 0", "color":THEME["muted"], "fontFamily":FONT_SERIF, "fontStyle":"italic"}}>Loading seed and baseline data…</div> }}
        {if not loading {
          <div>
            <div style={{"display":"flex", "flexWrap":"wrap", "borderTop":"1px solid " + THEME["borderStrong"], "borderBottom":"1px solid " + THEME["borderStrong"], "padding":"16px 0", "marginBottom":"26px"}}>
              <div style={{"paddingRight":"28px", "marginRight":"28px", "borderRight":"1px solid " + THEME["border"]}}><div style={{"fontFamily":FONT_MONO, "fontSize":"10px", "letterSpacing":"0.08em", "color":THEME["subtle"]}}>FARMERS</div><div style={{"fontFamily":FONT_MONO, "fontSize":"26px", "fontWeight":"700"}}>{str(len(farmers))}</div></div>
              <div style={{"paddingRight":"28px", "marginRight":"28px", "borderRight":"1px solid " + THEME["border"]}}><div style={{"fontFamily":FONT_MONO, "fontSize":"10px", "letterSpacing":"0.08em", "color":THEME["subtle"]}}>HARVESTS</div><div style={{"fontFamily":FONT_MONO, "fontSize":"26px", "fontWeight":"700"}}>{str(len(harvests))}</div></div>
              <div style={{"paddingRight":"28px", "marginRight":"28px", "borderRight":"1px solid " + THEME["border"]}}><div style={{"fontFamily":FONT_MONO, "fontSize":"10px", "letterSpacing":"0.08em", "color":THEME["subtle"]}}>HUBS</div><div style={{"fontFamily":FONT_MONO, "fontSize":"26px", "fontWeight":"700"}}>{str(len(hubs))}</div></div>
              <div style={{"paddingRight":"28px", "marginRight":"28px", "borderRight":"1px solid " + THEME["border"]}}><div style={{"fontFamily":FONT_MONO, "fontSize":"10px", "letterSpacing":"0.08em", "color":THEME["subtle"]}}>MARKETS</div><div style={{"fontFamily":FONT_MONO, "fontSize":"26px", "fontWeight":"700"}}>{str(len(markets))}</div></div>
              <div><div style={{"fontFamily":FONT_MONO, "fontSize":"10px", "letterSpacing":"0.08em", "color":THEME["subtle"]}}>ROUTES</div><div style={{"fontFamily":FONT_MONO, "fontSize":"26px", "fontWeight":"700"}}>{str(len(routes))}<span style={{"fontSize":"14px", "color":THEME["subtle"], "fontWeight":"400"}}> / {str(len(trucks))} trucks</span></div></div>
            </div>

            <div style={{"display":"grid", "gridTemplateColumns":"minmax(0, 1.7fr) minmax(280px, 1fr)", "gap":"30px", "alignItems":"start"}}>
              <section style={{"minWidth":"0"}}>
                <div style={{"display":"flex", "justifyContent":"space-between", "alignItems":"baseline", "borderBottom":"1px solid " + THEME["borderStrong"], "paddingBottom":"8px", "marginBottom":"4px"}}>
                  <h2 style={{"fontFamily":FONT_SERIF, "fontWeight":"400", "margin":"0", "fontSize":"19px"}}>Routes and assignments</h2>
                  <span style={{"fontFamily":FONT_MONO, "fontSize":"12px", "color":THEME["subtle"]}}>{str(len(routes))} active</span>
                </div>
                <div style={{"display":"flex", "gap":"16px", "flexWrap":"wrap", "padding":"10px 0", "borderBottom":"1px solid " + THEME["border"], "marginBottom":"4px", "fontFamily":FONT_MONO, "fontSize":"12px"}}>
                  {for t in trucks { <span key={t["id"]} style={{"color":truck_color_by_id[t["id"] as str], "borderLeft":"3px solid " + truck_color_by_id[t["id"] as str], "paddingLeft":"6px"}}>{t["name"]}</span> }}
                  {if event_done { <span style={{"color":THEME["red"], "borderLeft":"3px dashed " + THEME["red"], "paddingLeft":"6px"}}>removed</span><span style={{"color":THEME["green"], "borderLeft":"3px solid " + THEME["green"], "paddingLeft":"6px"}}>new</span> }}
                </div>
                <div>
                  {for route in routes {
                    removed = route["id"] in removed_ids;
                    added = route["id"] in added_ids;
                    truck_id = route["truckId"] as str;
                    assigned_name = truck_name_by_id[truck_id] if truck_id in truck_name_by_id else truck_id;
                    accent = THEME["red"] if removed else THEME["green"] if added else THEME["border"];
                    status_word = "REMOVED" if removed else "NEW" if added else "";
                    <div key={route["id"]} style={{"display":"flex", "justifyContent":"space-between", "flexWrap":"wrap", "gap":"8px", "padding":"11px 0 11px 14px", "borderLeft":"3px solid " + accent, "borderBottom":"1px solid " + THEME["border"]}}>
                      <span><strong style={{"fontFamily":FONT_MONO}}>{route["id"]}</strong> · {str(len(route["farmerIds"] as list[str]))} farmer lots → {route["marketId"]}{"  ·  " + status_word if status_word else ""}</span>
                      <span style={{"color":THEME["muted"], "fontFamily":FONT_MONO, "fontSize":"13px"}}>{assigned_name} · {str(route["distanceKm"])}km</span>
                    </div>
                  }}
                  {if len(routes) == 0 { <p style={{"color":THEME["muted"], "fontFamily":FONT_SERIF, "fontStyle":"italic"}}>No routes yet.</p> }}
                </div>
              </section>

              <aside style={{"display":"flex", "flexDirection":"column", "gap":"28px"}}>
                <section>
                  <h2 style={{"fontFamily":FONT_SERIF, "fontWeight":"400", "margin":"0 0 10px", "fontSize":"19px", "borderBottom":"1px solid " + THEME["borderStrong"], "paddingBottom":"8px"}}>Baseline and agent score</h2>
                  {if score { <div>
                    <div style={{"display":"grid", "gridTemplateColumns":"1fr 1fr 1fr", "gap":"6px", "padding":"2px 0 10px", "fontFamily":FONT_MONO, "fontSize":"12px"}}>
                      <span style={{"color":THEME["subtle"]}}>MEASURE</span><span style={{"color":THEME["subtle"]}}>BASELINE</span><span style={{"color":THEME["subtle"]}}>AGENT</span>
                      <span style={{"fontFamily":FONT_SANS}}>Spoilage</span><span style={{"color":THEME["muted"]}}>{str(round(baseline_score["spoilagePct"] as float, 1))}%</span><b style={{"color": THEME["green"] if spoilage_better else THEME["ink"]}}>{str(round(agent_score["spoilagePct"] as float, 1))}%{" ↓" if spoilage_better else ""}</b>
                      <span style={{"fontFamily":FONT_SANS}}>Income</span><span style={{"color":THEME["muted"]}}>{str(round(baseline_score["income"] as float, 0))}</span><b style={{"color": THEME["green"] if income_better else THEME["ink"]}}>{str(round(agent_score["income"] as float, 0))}{" ↑" if income_better else ""}</b>
                      <span style={{"fontFamily":FONT_SANS}}>Truck cost</span><span style={{"color":THEME["muted"]}}>{str(round(baseline_score["truckCost"] as float, 0))}</span><b style={{"color": THEME["green"] if cost_better else THEME["ink"]}}>{str(round(agent_score["truckCost"] as float, 0))}{" ↓" if cost_better else ""}</b>
                    </div>
                  </div> } else { <p style={{"color":THEME["muted"], "fontFamily":FONT_SERIF, "fontStyle":"italic"}}>Scores will appear after the baseline plan loads.</p> }}
                  {if len(steps) > 0 { <div style={{"padding":"10px 0 10px 12px", "borderLeft":"3px solid " + THEME["green"], "marginTop":"10px"}}><div style={{"fontFamily":FONT_MONO, "fontSize":"11px", "letterSpacing":"0.05em", "color":THEME["green"], "fontWeight":"700", "marginBottom":"4px"}}>MERGE COMPLETE</div>{for step in steps { <p key={step["newRouteId"]} style={{"margin":"4px 0 0", "fontSize":"13px", "color":THEME["muted"]}}>{str(step["stepNo"])}. {step["reason"]}</p> }}</div> }}
                  {if event_done { <div style={{"padding":"10px 0 10px 12px", "borderLeft":"3px solid " + THEME["ochre"], "marginTop":"10px"}}>
                    {if len(removed_ids) > 0 { <p style={{"margin":"0 0 4px", "fontSize":"13px"}}><span style={{"fontFamily":FONT_MONO, "fontSize":"11px", "color":THEME["ochre"]}}>REMOVED</span> {" · ".join(removed_ids)}</p> }}
                    {if len(added_ids) > 0 { <p style={{"margin":"0 0 6px", "fontSize":"13px"}}><span style={{"fontFamily":FONT_MONO, "fontSize":"11px", "color":THEME["ochre"]}}>NEW</span> {" · ".join(added_ids)}</p> }}
                    {for note in diff_notes { <p key={note} style={{"margin":"0 0 4px", "fontSize":"12px", "color":THEME["muted"]}}>{note}</p> }}
                    <p style={{"fontSize":"13px", "marginTop":"8px", "fontFamily":FONT_SERIF}}>{explanation}</p>
                  </div> }}
                </section>
                <section>
                  <h2 style={{"fontFamily":FONT_SERIF, "fontWeight":"400", "margin":"0 0 8px", "fontSize":"19px", "borderBottom":"1px solid " + THEME["borderStrong"], "paddingBottom":"8px"}}>Fleet status</h2>
                  {for truck in trucks { <div key={truck["id"]} style={{"padding":"7px 0", "borderBottom":"1px solid " + THEME["border"], "display":"flex", "justifyContent":"space-between", "alignItems":"center"}}><span>{truck["name"]} <span style={{"color":THEME["subtle"], "fontFamily":FONT_MONO, "fontSize":"12px"}}>{str(truck["capacityKg"])}kg</span></span><span style={{"fontFamily":FONT_MONO, "fontSize":"11px", "fontWeight":"700", "color":THEME["red"] if truck["status"] == "broken" else THEME["green"]}}>[{(truck["status"] as str).upper()}]</span></div> }}
                </section>
                <section>
                  <h2 style={{"fontFamily":FONT_SERIF, "fontWeight":"400", "margin":"0 0 8px", "fontSize":"19px", "borderBottom":"1px solid " + THEME["borderStrong"], "paddingBottom":"8px"}}>Market prices</h2>
                  {for market in markets {
                    prices = market["prices"] as dict[str, float];
                    <div key={market["id"]} style={{"padding":"7px 0", "borderBottom":"1px solid " + THEME["border"]}}>
                      <div>{market["name"]}</div>
                      <div style={{"fontSize":"12px", "color":THEME["muted"], "fontFamily":FONT_MONO, "marginTop":"2px"}}>{for crop in prices.keys() { <span key={crop}>{crop} {str(prices[crop])}  </span> }}· demand {str(market["demandCapKg"])}kg</div>
                    </div>
                  }}
                </section>
              </aside>
            </div>

            {if event_done { <section style={{"marginTop":"30px"}}>
              <h2 style={{"fontFamily":FONT_SERIF, "fontWeight":"400", "margin":"0 0 8px", "fontSize":"19px", "borderBottom":"1px solid " + THEME["borderStrong"], "paddingBottom":"8px"}}>Farmer updates</h2>
              {for message in messages { <div key={message["farmerId"]} style={{"padding":"10px 0", "borderBottom":"1px solid " + THEME["border"], "display":"flex", "alignItems":"baseline", "gap":"10px", "flexWrap":"wrap"}}>
                <strong>{message["farmerName"]}</strong>
                <span style={{"fontFamily":FONT_MONO, "fontSize":"11px", "color":THEME["subtle"]}}>[{(message["language"] as str).upper()}]</span>
                <span>{message["text"]}</span>
                {if message["isFallback"] { <span style={{"fontFamily":FONT_MONO, "fontSize":"11px", "fontWeight":"700", "color":THEME["ochre"]}}>[FALLBACK]</span> }}
              </div> }}
            </section> }}
          </div>
        }}
      </main>
    </div>;
}
