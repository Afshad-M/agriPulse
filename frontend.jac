import from .api_layer { fetch_seed, fetch_baseline_plan, fetch_merge_routes, fetch_replan }

glob THEME: dict[str, str] = {
    "page": "#F5F7F4", "panel": "#FFFFFF", "border": "#D8DDD5",
    "ink": "#1E2B26", "muted": "#5B6A62", "green": "#1F6B4A",
    "slate": "#7A8780", "blue": "#2F6DB5", "ochre": "#C98A1B",
    "plum": "#8A4F8F", "red": "#C2412D"
};

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
        scenario: str = "Baseline plan";

    can with entry {
        result = fetch_seed();
        baseline = fetch_baseline_plan();
        state = result["data"]["result"]["state"] as dict[str, any];
        score = baseline["data"]["result"]["score"] as dict[str, any];
        loading = False;
    }

    def merge_routes_action(e: MouseEvent) {
        try {
            result = fetch_merge_routes();
            payload = result["data"]["result"] as dict[str, any];
            state = payload["state"] as dict[str, any];
            score = payload["score"] as dict[str, any];
            steps = payload["steps"] as list[dict[str, any]];
            scenario = "Merged routes";
            event_done = False;
        } except Exception {
            error = "Route merge failed. Retry the merge action.";
        }
    }

    def breakdown_action(e: MouseEvent) {
        try {
            result = fetch_replan("truck_breakdown");
            payload = result["data"]["result"] as dict[str, any];
            state = payload["state"] as dict[str, any];
            score = payload["score"] as dict[str, any];
            diff = payload["diff"] as dict[str, any];
            messages = payload["messages"] as list[dict[str, any]];
            explanation = payload["explanation"] as str;
            scenario = "Truck breakdown response";
            event_done = True;
        } except Exception {
            error = "Breakdown replanning failed. Retry the event.";
        }
    }

    routes = (state["routes"] as list[dict[str, any]]) if state else [];
    farmers = (state["farmers"] as list[dict[str, any]]) if state else [];
    hubs = (state["hubs"] as list[dict[str, any]]) if state else [];
    markets = (state["markets"] as list[dict[str, any]]) if state else [];
    trucks = (state["trucks"] as list[dict[str, any]]) if state else [];
    harvests = (state["harvests"] as list[dict[str, any]]) if state else [];
    baseline_score = score["baseline"] as dict[str, any] if score else {};
    agent_score = score["agent"] as dict[str, any] if score else {};
    removed_ids = diff["removedRouteIds"] as list[str] if diff else [];
    added_ids = diff["addedRouteIds"] as list[str] if diff else [];
    truck_1 = THEME["blue"];
    truck_2 = THEME["ochre"];
    truck_3 = THEME["plum"];

    return <div style={{"minHeight":"100vh", "backgroundColor":THEME["page"], "color":THEME["ink"], "fontFamily":"system-ui, -apple-system, BlinkMacSystemFont, sans-serif", "fontSize":"16px"}}>
      <header style={{"display":"flex", "alignItems":"center", "justifyContent":"space-between", "gap":"16px", "padding":"18px 28px", "borderBottom":"1px solid " + THEME["border"], "backgroundColor":THEME["panel"]}}>
        <div style={{"display":"flex", "alignItems":"center", "gap":"12px"}}><div style={{"width":"34px", "height":"34px", "display":"grid", "placeItems":"center", "backgroundColor":THEME["green"], "color":"white", "fontWeight":"700", "borderRadius":"4px"}}>A</div><div><strong style={{"fontSize":"20px"}}>AgriPulse</strong><div style={{"fontSize":"14px", "color":THEME["muted"]}}>Harvest-to-market coordination</div></div></div>
        <span style={{"fontSize":"14px", "color":THEME["muted"]}}>{scenario} · All data simulated</span>
      </header>
      <main style={{"padding":"24px", "maxWidth":"1480px", "margin":"0 auto"}}>
        <div style={{"display":"flex", "alignItems":"end", "justifyContent":"space-between", "gap":"16px", "flexWrap":"wrap", "marginBottom":"20px"}}><div><h1 style={{"fontSize":"28px", "margin":"0 0 6px"}}>Sri Lanka produce network</h1><p style={{"margin":"0", "color":THEME["muted"]}}>Harvest readiness, route performance and disruption planning.</p></div><div style={{"display":"flex", "gap":"10px", "flexWrap":"wrap"}}><button onClick={merge_routes_action} disabled={loading} style={{"padding":"10px 14px", "backgroundColor":THEME["green"], "color":"white", "border":"1px solid " + THEME["green"], "borderRadius":"4px", "fontSize":"16px", "fontWeight":"600"}}>Merge routes</button><button onClick={breakdown_action} disabled={loading} style={{"padding":"10px 14px", "backgroundColor":THEME["panel"], "color":THEME["ink"], "border":"1px solid " + THEME["border"], "borderRadius":"4px", "fontSize":"16px"}}>Simulate truck breakdown</button></div></div>
        {if loading { <div role="status" style={{"padding":"16px", "backgroundColor":THEME["panel"], "border":"1px solid " + THEME["border"]}}>Loading simulated market and route data…</div> }}
        {if error { <div role="alert" style={{"padding":"14px", "marginBottom":"16px", "color":THEME["red"], "backgroundColor":THEME["panel"], "border":"1px solid " + THEME["red"]}}>{error}</div> }}
        {if not loading {
          <div>
            <section style={{"display":"grid", "gridTemplateColumns":"repeat(auto-fit, minmax(155px, 1fr))", "border":"1px solid " + THEME["border"], "backgroundColor":THEME["panel"], "marginBottom":"18px"}}>
              <div style={{"padding":"16px 18px", "borderRight":"1px solid " + THEME["border"]}}><div style={{"color":THEME["muted"]}}>Farmers</div><strong style={{"fontSize":"32px", "fontVariantNumeric":"tabular-nums"}}>{str(len(farmers))}</strong><div>Across local districts</div></div>
              <div style={{"padding":"16px 18px", "borderRight":"1px solid " + THEME["border"]}}><div style={{"color":THEME["muted"]}}>Ready harvest</div><strong style={{"fontSize":"32px", "fontVariantNumeric":"tabular-nums"}}>{str(len(harvests))}</strong><div>Crop lots available</div></div>
              <div style={{"padding":"16px 18px", "borderRight":"1px solid " + THEME["border"]}}><div style={{"color":THEME["muted"]}}>Collection hubs</div><strong style={{"fontSize":"32px", "fontVariantNumeric":"tabular-nums"}}>{str(len(hubs))}</strong><div>Regional consolidation</div></div>
              <div style={{"padding":"16px 18px", "borderRight":"1px solid " + THEME["border"]}}><div style={{"color":THEME["muted"]}}>Markets</div><strong style={{"fontSize":"32px", "fontVariantNumeric":"tabular-nums"}}>{str(len(markets))}</strong><div>Demand and crop prices</div></div>
              <div style={{"padding":"16px 18px"}}><div style={{"color":THEME["muted"]}}>Active routes</div><strong style={{"fontSize":"32px", "fontVariantNumeric":"tabular-nums"}}>{str(len(routes))}</strong><div>{str(len(trucks))} trucks in fleet</div></div>
            </section>
            <div style={{"display":"grid", "gridTemplateColumns":"minmax(0, 1.8fr) minmax(290px, 1fr)", "gap":"18px", "alignItems":"start"}}>
              <section style={{"backgroundColor":THEME["panel"], "border":"1px solid " + THEME["border"], "minWidth":"0"}}>
                <div style={{"padding":"16px 18px", "borderBottom":"1px solid " + THEME["border"]}}><h2 style={{"margin":"0 0 4px", "fontSize":"20px"}}>Route network</h2><div style={{"color":THEME["muted"]}}>Each line links farmers, collection hubs and a destination market.</div></div>
                <div style={{"padding":"18px", "overflowX":"auto"}}><svg viewBox="0 0 800 310" style={{"width":"100%", "minWidth":"580px", "height":"300px", "backgroundColor":"#FAFBF9"}} role="img" aria-label="Simulated farmer, hub and market route network">
                  {if event_done { <path d="M70 232 C190 232 220 145 355 145 S530 80 710 80" fill="none" stroke={THEME["red"]} strokeWidth="5" strokeDasharray="10 8" /> }}
                  {if not event_done { <path d="M70 72 C190 72 210 145 355 145 S510 80 710 80" fill="none" stroke={truck_1} strokeWidth="5" /> }}
                  <path d="M70 145 C185 145 220 145 355 145 S520 220 710 220" fill="none" stroke={truck_2} strokeWidth="5" />
                  {if not event_done { <path d="M70 232 C190 232 220 145 355 145 S530 80 710 80" fill="none" stroke={truck_3} strokeWidth="5" /> }}
                  <circle cx="355" cy="145" r="13" fill={THEME["green"]}/><circle cx="710" cy="80" r="12" fill={THEME["green"]}/><circle cx="710" cy="220" r="12" fill={THEME["green"]}/>
                  <text x="22" y="42" fill={THEME["ink"]} fontSize="15">Farmer districts</text><text x="290" y="122" fill={THEME["ink"]} fontSize="15">Collection hubs</text><text x="654" y="53" fill={THEME["ink"]} fontSize="15">Pettah</text><text x="654" y="253" fill={THEME["ink"]} fontSize="15">Kandy</text>
                  <circle cx="92" cy="72" r="7" fill={THEME["green"]}/><circle cx="92" cy="145" r="7" fill={THEME["green"]}/><circle cx="92" cy="232" r="7" fill={THEME["green"]}/>
                </svg></div>
                <div style={{"padding":"12px 18px", "borderTop":"1px solid " + THEME["border"], "display":"flex", "gap":"16px", "flexWrap":"wrap", "fontSize":"14px"}}><span><b style={{"color":truck_1}}>━</b> LakSavi 01</span><span><b style={{"color":truck_2}}>━</b> LakSavi 02</span>{if not event_done { <span><b style={{"color":truck_3}}>━</b> LakSavi 03</span> }}{if event_done { <span><b style={{"color":THEME["red"]}}>┄</b> Removed</span><span><b style={{"color":THEME["green"]}}>━</b> New route</span> }}</div>
                <div style={{"padding":"0 18px 18px"}}><h3 style={{"fontSize":"18px"}}>Routes and assignments</h3>
                  {for route in routes {
                    removed = route["id"] in removed_ids;
                    added = route["id"] in added_ids;
                    truck_id = route["truckId"] as str;
                    assigned_name = "LakSavi 01" if truck_id == "truck01" else "LakSavi 02" if truck_id == "truck02" else "LakSavi 03";
                    <div key={route["id"]} style={{"display":"flex", "justifyContent":"space-between", "flexWrap":"wrap", "gap":"8px", "padding":"12px", "border":"1px dashed " + THEME["red"] if removed else "1px solid " + THEME["green"] if added else "1px solid " + THEME["border"], "marginBottom":"8px"}}><span><strong>{route["id"]}</strong> · {str(len(route["farmerIds"] as list[str]))} farmer lots → {route["marketId"]}{" · Removed" if removed else " · New" if added else ""}</span><span>{assigned_name} · {str(route["distanceKm"])} km</span></div>
                  }}
                </div>
              </section>
              <aside style={{"display":"flex", "flexDirection":"column", "gap":"16px"}}>
                <section style={{"padding":"16px 18px", "backgroundColor":THEME["panel"], "border":"1px solid " + THEME["border"]}}><h2 style={{"fontSize":"20px", "margin":"0 0 12px"}}>Baseline and agent score</h2>
                  {if score { <div>
                    <div style={{"display":"grid", "gridTemplateColumns":"1fr 1fr 1fr", "gap":"8px", "padding":"10px 0", "borderBottom":"1px solid " + THEME["border"]}}><strong>Measure</strong><strong>Baseline</strong><strong>Agent</strong><span>Spoilage</span><span>{str(baseline_score["spoilagePct"])}%</span><b>{str(agent_score["spoilagePct"])}%</b><span>Income</span><span>LKR {str(baseline_score["income"])}</span><b>LKR {str(agent_score["income"])}</b><span>Truck cost</span><span>LKR {str(baseline_score["truckCost"])}</span><b>LKR {str(agent_score["truckCost"])}</b></div>
                    <div style={{"display":"grid", "gridTemplateColumns":"1fr 1fr", "gap":"8px", "padding":"12px 0"}}><strong>Agent plan</strong><strong>Score</strong><span>Spoilage</span><b>{str(agent_score["spoilagePct"])}%</b><span>Income</span><b>LKR {str(agent_score["income"])}</b><span>Truck cost</span><b>LKR {str(agent_score["truckCost"])}</b></div>
                  </div> } else { <p>Scores will appear after the baseline plan loads.</p> }}
                  {if len(steps) > 0 { <div style={{"padding":"12px", "backgroundColor":"#EAF3ED", "border":"1px solid " + THEME["green"]}}><strong>Route merge complete</strong>{for step in steps { <p key={step["newRouteId"]} style={{"margin":"8px 0 0"}}>Step {str(step["stepNo"])}: {step["reason"]}</p> }}</div> }}
                  {if event_done { <div style={{"padding":"12px", "backgroundColor":"#FFF5E8", "border":"1px solid " + THEME["ochre"], "marginTop":"10px"}}><strong>Removed</strong> route r-merged-03<br/><strong>New</strong> routes r-event-01 and r-event-02<p>{explanation}</p></div> }}
                </section>
                <section style={{"padding":"16px 18px", "backgroundColor":THEME["panel"], "border":"1px solid " + THEME["border"]}}><h2 style={{"fontSize":"20px", "margin":"0 0 12px"}}>Fleet status</h2>{for truck in trucks { <div key={truck["id"]} style={{"padding":"10px 0", "borderBottom":"1px solid " + THEME["border"], "display":"flex", "justifyContent":"space-between", "gap":"10px"}}><span>{truck["name"]} · {str(truck["capacityKg"])} kg</span><strong style={{"color":THEME["red"] if truck["status"] == "broken" else THEME["green"]}}>{truck["status"]}</strong></div> }}</section>
                <section style={{"padding":"16px 18px", "backgroundColor":THEME["panel"], "border":"1px solid " + THEME["border"]}}><h2 style={{"fontSize":"20px", "margin":"0 0 12px"}}>Market prices</h2>{for market in markets { <div key={market["id"]} style={{"padding":"10px 0", "borderBottom":"1px solid " + THEME["border"]}}><strong>{market["name"]}</strong><div style={{"fontSize":"14px", "color":THEME["muted"]}}>Tomato LKR {(market["prices"] as dict[str, any])["Tomato"]}/kg · demand {str(market["demandCapKg"])} kg</div></div> }}</section>
              </aside>
            </div>
            {if event_done { <section style={{"padding":"16px 18px", "backgroundColor":THEME["panel"], "border":"1px solid " + THEME["border"], "marginTop":"18px"}}><h2 style={{"fontSize":"20px"}}>Farmer updates</h2>{for message in messages { <div key={message["farmerId"]} style={{"padding":"10px 0", "borderTop":"1px solid " + THEME["border"]}}><strong>{message["farmerName"]}</strong> · {message["language"]} <span>{message["text"]}</span>{if message["isFallback"] { <span style={{"color":THEME["ochre"]}}> · fallback message</span> }}</div> }}</section> }}
          </div>
        }}
      </main>
      <footer style={{"padding":"16px 24px", "textAlign":"center", "fontSize":"14px", "color":THEME["muted"], "borderTop":"1px solid " + THEME["border"]}}>All data simulated</footer>
    </div>;
}
