import from .api_layer { fetch_seed, fetch_baseline_plan, fetch_merge, fetch_event }

# AgriPulse web app (C). Light, clean dashboard + a mobile-first Farmer view.
# FRONTEND ONLY: everything here talks to the backend through api_layer.jac
# (a thin adapter over the CONTRACT v1 endpoints). Only "truck_breakdown" is
# wired into the UI - it's the one event type apply_replan_event() (logic.jac)
# actually implements - so the disruption panel offers nothing that would
# come back unhandled.

glob C: dict[str, str] = {
    "page": "#F4F7F5", "surface": "#FFFFFF", "surface2": "#F8FAF9",
    "border": "#E1E8E4", "borderStrong": "#C9D4CE",
    "text": "#15231C", "muted": "#566860", "subtle": "#87978F",
    "primary": "#17805A", "primaryDark": "#0F6445", "primarySoft": "#E3F4EB",
    "blue": "#2563EB", "blueSoft": "#E8EFFD",
    "amber": "#B7791F", "amberSoft": "#FDF3DC",
    "violet": "#7C3AED", "violetSoft": "#EFE8FD",
    "red": "#C93B3B", "redSoft": "#FCEAEA",
    "teal": "#0E8A8A", "rose": "#BE3A6B"
};

glob FONT: str = "Inter, -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', sans-serif";

# Farmer-view strings. Sinhala and Tamil are drafts - a native speaker
# should review them before the demo (see docs/assumptions.md).
glob UI_TEXT: dict[str, dict[str, str]] = {
    "en": {
        "hello": "Hello", "pick": "Choose a farmer", "harvest": "Your harvest", "crop": "Crop",
        "qty": "Quantity", "fresh": "Stays fresh for", "delivery": "Your delivery", "truck": "Truck",
        "market": "Market", "distance": "Distance", "time": "Travel time", "loss": "Expected spoilage",
        "shared": "You share this truck with {n} other farmers.", "alone": "Your harvest travels on its own truck.",
        "messages": "Messages for you", "none": "No new messages yet.", "hours": "hours",
        "income": "Expected income", "log": "Tell us about a new harvest",
        "ph": "For example: 80kg beans, ready in 2 hours", "send": "Send"
    },
    "si": {
        "hello": "ආයුබෝවන්", "pick": "ගොවියා තෝරන්න", "harvest": "ඔබේ අස්වැන්න", "crop": "බෝගය",
        "qty": "ප්‍රමාණය", "fresh": "නැවුම්ව පවතින කාලය", "delivery": "ඔබේ ප්‍රවාහනය", "truck": "ට්‍රක් රථය",
        "market": "වෙළඳපොළ", "distance": "දුර", "time": "ගමන් කාලය", "loss": "අපේක්ෂිත නරක් වීම",
        "shared": "ඔබ මෙම ට්‍රක් රථය තවත් ගොවීන් {n} දෙනෙක් සමඟ බෙදාගනී.", "alone": "ඔබේ අස්වැන්න තනිවම ට්‍රක් රථයකින් යයි.",
        "messages": "ඔබට පණිවිඩ", "none": "තවම නව පණිවිඩ නැත.", "hours": "පැය",
        "income": "අපේක්ෂිත ආදායම", "log": "නව අස්වැන්නක් ගැන කියන්න",
        "ph": "උදා: බෝංචි කිලෝ 80ක්, පැය 2කින් සූදානම්", "send": "යවන්න"
    },
    "ta": {
        "hello": "வணக்கம்", "pick": "விவசாயியைத் தேர்ந்தெடுக்கவும்", "harvest": "உங்கள் அறுவடை", "crop": "பயிர்",
        "qty": "அளவு", "fresh": "புதிதாக இருக்கும் காலம்", "delivery": "உங்கள் போக்குவரத்து", "truck": "லாரி",
        "market": "சந்தை", "distance": "தூரம்", "time": "பயண நேரம்", "loss": "எதிர்பார்க்கப்படும் வீணாதல்",
        "shared": "இந்த லாரியை மேலும் {n} விவசாயிகளுடன் பகிர்கிறீர்கள்.", "alone": "உங்கள் அறுவடை தனி லாரியில் செல்கிறது.",
        "messages": "உங்களுக்கான செய்திகள்", "none": "புதிய செய்திகள் இல்லை.", "hours": "மணி",
        "income": "எதிர்பார்க்கப்படும் வருமானம்", "log": "புதிய அறுவடை பற்றி சொல்லுங்கள்",
        "ph": "எ.கா: 80 கிலோ பீன்ஸ், 2 மணி நேரத்தில் தயார்", "send": "அனுப்பு"
    }
};

def:pub app -> JsxElement {
    has state: dict[str, any] = {},
        score: dict[str, any] = {},
        base_routes_n: int = 0,
        steps: list[dict[str, any]] = [],
        messages: list[dict[str, any]] = [],
        event_report: dict[str, any] = {},
        removed_ids: list[str] = [],
        added_ids: list[str] = [],
        loading: bool = True,
        running: bool = False,
        error: str = "",
        scenario: str = "Baseline: every farmer ships alone",
        data_source: str = "real",
        view: str = "dashboard",
        lang: str = "en",
        sel_farmer: str = "",
        sel_truck: str = "",
        farmer_text: str = "",
        farmer_sent_text: str = "",
        farmer_reply_text: str = "",
        farmer_reply_is_fallback: bool = False;

    async can with entry {
        await load_all(False);
    }

    # ---------- derived data (plain reads of state) ----------
    farmers = (state["farmers"] as list[dict[str, any]]) if state else [];
    harvests = (state["harvests"] as list[dict[str, any]]) if state else [];
    hubs = (state["hubs"] as list[dict[str, any]]) if state else [];
    markets = (state["markets"] as list[dict[str, any]]) if state else [];
    trucks = (state["trucks"] as list[dict[str, any]]) if state else [];
    routes = (state["routes"] as list[dict[str, any]]) if state else [];
    plans = (state["plans"] as list[dict[str, any]]) if state else [];
    base_score = score["baseline"] as dict[str, any] if score else {};
    agent_score = score["agent"] as dict[str, any] if score else {};

    farmer_name_by_id: dict[str, str] = {};
    for f in farmers { farmer_name_by_id[f["id"] as str] = f["name"] as str; }
    truck_name_by_id: dict[str, str] = {};
    truck_cap_by_id: dict[str, float] = {};
    truck_color_by_id: dict[str, str] = {};
    palette = [C["blue"], C["amber"], C["violet"], C["teal"], C["rose"]];
    for i in range(len(trucks)) {
        tid = trucks[i]["id"] as str;
        truck_name_by_id[tid] = trucks[i]["name"] as str;
        truck_cap_by_id[tid] = trucks[i]["capacityKg"] as float;
        truck_color_by_id[tid] = palette[i % len(palette)];
    }
    hub_name_by_id: dict[str, str] = {};
    for h in hubs { hub_name_by_id[h["id"] as str] = h["name"] as str; }
    market_name_by_id: dict[str, str] = {};
    for m in markets { market_name_by_id[m["id"] as str] = m["name"] as str; }
    plan_by_route: dict[str, dict[str, any]] = {};
    for p in plans { plan_by_route[p["routeId"] as str] = p; }
    harvest_by_farmer: dict[str, dict[str, any]] = {};
    for hv in harvests { harvest_by_farmer[hv["farmerId"] as str] = hv; }
    route_by_farmer: dict[str, dict[str, any]] = {};
    for r in routes {
        for fid in (r["farmerIds"] as list[str]) { route_by_farmer[fid] = r; }
    }

    eff_farmer = sel_farmer if sel_farmer in farmer_name_by_id else (farmers[0]["id"] as str if len(farmers) > 0 else "");
    eff_truck = sel_truck if sel_truck in truck_name_by_id else (trucks[0]["id"] as str if len(trucks) > 0 else "");

    my_messages: list[dict[str, any]] = [];
    my_name = farmer_name_by_id[eff_farmer] if eff_farmer in farmer_name_by_id else "";
    for mg in messages {
        if (mg["farmerId"] as str) == eff_farmer or (mg["farmerName"] as str) == my_name {
            my_messages.append(mg);
        }
    }

    def fmt_int(n: float) -> str {
        s = str(int(round(n)));
        neg = s.startswith("-");
        if neg { s = s[1:]; }
        out = "";
        count = 0;
        i = len(s) - 1;
        while i >= 0 {
            out = s[i] + out;
            count += 1;
            if count % 3 == 0 and i > 0 { out = "," + out; }
            i -= 1;
        }
        return ("-" + out) if neg else out;
    }

    def pretty(name: str) -> str {
        return name.replace("_", " ");
    }

    b_sp = base_score["spoilagePct"] as float if base_score else 0.0;
    a_sp = agent_score["spoilagePct"] as float if agent_score else 0.0;
    b_in = base_score["income"] as float if base_score else 0.0;
    a_in = agent_score["income"] as float if agent_score else 0.0;
    b_tc = base_score["truckCost"] as float if base_score else 0.0;
    a_tc = agent_score["truckCost"] as float if agent_score else 0.0;
    changed = (abs(a_sp - b_sp) > 0.0001) or (abs(a_in - b_in) > 0.5) or (abs(a_tc - b_tc) > 0.5);
    sp_delta = (("-" if a_sp < b_sp else "+") + str(round(abs(a_sp - b_sp), 1)) + " pts") if changed else "no change yet";
    in_delta = (("+" if a_in >= b_in else "-") + fmt_int(abs(a_in - b_in)) + " LKR") if changed else "no change yet";
    tc_delta = (("-" if a_tc <= b_tc else "+") + fmt_int(abs(a_tc - b_tc)) + " LKR") if changed else "no change yet";
    sp_good = changed and a_sp < b_sp;
    in_good = changed and a_in > b_in;
    tc_good = changed and a_tc < b_tc;
    trips_now = len(routes);

    # ---------- route network drawing (computed, then rendered) ----------
    hub_used: list[str] = [];
    mkt_used: list[str] = [];
    lane_total: dict[str, int] = {};
    for r in routes {
        d_hub = (r["hubIds"] as list[str])[0] if len(r["hubIds"] as list[str]) > 0 else "";
        d_mkt = r["marketId"] as str;
        if d_hub not in hub_used { hub_used.append(d_hub); }
        if d_mkt not in mkt_used { mkt_used.append(d_mkt); }
        d_key = d_hub + "->" + d_mkt;
        lane_total[d_key] = (lane_total[d_key] if d_key in lane_total else 0) + 1;
    }
    row_n = max(max(len(hub_used), len(mkt_used)), 1);
    svg_h = 40 + row_n * 74;
    hub_y: dict[str, float] = {};
    for i in range(len(hub_used)) { hub_y[hub_used[i]] = 52.0 + i * 74.0; }
    mkt_y: dict[str, float] = {};
    for i in range(len(mkt_used)) { mkt_y[mkt_used[i]] = 52.0 + i * 74.0; }
    lane_seen: dict[str, int] = {};
    paths: list[dict[str, any]] = [];
    for r in routes {
        p_hub = (r["hubIds"] as list[str])[0] if len(r["hubIds"] as list[str]) > 0 else "";
        p_mkt = r["marketId"] as str;
        p_key = p_hub + "->" + p_mkt;
        k = lane_seen[p_key] if p_key in lane_seen else 0;
        lane_seen[p_key] = k + 1;
        total = lane_total[p_key] if p_key in lane_total else 1;
        off = (k - (total - 1) / 2.0) * 7.0;
        y1 = (hub_y[p_hub] if p_hub in hub_y else 52.0) + off;
        y2 = (mkt_y[p_mkt] if p_mkt in mkt_y else 52.0) + off;
        n_f = len(r["farmerIds"] as list[str]);
        w = min(3.0 + n_f * 1.6, 13.0) if total <= 3 else min(2.5 + n_f * 1.2, 9.0);
        d_str = "M 190 " + str(round(y1, 1)) + " C 340 " + str(round(y1, 1)) + ", 470 " + str(round(y2, 1)) + ", 620 " + str(round(y2, 1));
        t_id = r["truckId"] as str;
        paths.append({"id": r["id"], "d": d_str, "w": w, "color": truck_color_by_id[t_id] if t_id in truck_color_by_id else C["subtle"]});
    }

    # ---------- shared styles ----------
    card = {"backgroundColor": C["surface"], "border": "1px solid " + C["border"], "borderRadius": "14px", "boxShadow": "0 1px 2px rgba(16,24,20,0.04)"};
    h2 = {"margin": "0", "fontSize": "17px", "fontWeight": "650", "letterSpacing": "-0.01em", "color": C["text"]};
    small_label = {"fontSize": "12px", "fontWeight": "600", "color": C["subtle"], "letterSpacing": "0.04em", "textTransform": "uppercase"};
    btn_primary = {"padding": "11px 18px", "backgroundColor": C["primary"], "color": "#FFFFFF", "border": "1px solid " + C["primary"], "borderRadius": "10px", "fontSize": "14px", "fontWeight": "600", "cursor": "pointer", "fontFamily": "inherit"};
    btn_ghost = {"padding": "9px 14px", "backgroundColor": C["surface"], "color": C["text"], "border": "1px solid " + C["borderStrong"], "borderRadius": "10px", "fontSize": "14px", "fontWeight": "500", "cursor": "pointer", "fontFamily": "inherit"};
    field = {"width": "100%", "padding": "10px 12px", "backgroundColor": C["surface"], "color": C["text"], "border": "1px solid " + C["borderStrong"], "borderRadius": "10px", "fontSize": "14px", "fontFamily": "inherit", "boxSizing": "border-box"};
    t = UI_TEXT[lang] if lang in UI_TEXT else UI_TEXT["en"];

    # ---------- actions ----------
    async def load_all(force_seed: bool) {
        loading = True;
        error = "";
        try {
            # The backend rebuilds ONE shared graph on every load_seed, and
            # overlapping rebuilds can fail or leave an empty read. So read
            # the baseline FIRST and only seed when the graph is empty (or
            # when Reset forces it). Each attempt is retried.
            base = {};
            attempt = 0;
            ready = False;
            need_seed = force_seed;
            while attempt < 6 and not ready {
                try {
                    if need_seed {
                        await fetch_seed();
                        need_seed = False;
                    }
                    base = await fetch_baseline_plan();
                    if len(base["state"]["routes"] as list[dict[str, any]]) > 0 {
                        ready = True;
                    } else {
                        need_seed = True;
                    }
                } except Exception {
                    need_seed = True;
                }
                attempt += 1;
            }
            if not ready { raise Exception("backend not ready"); }
            state = base["state"] as dict[str, any];
            score = base["score"] as dict[str, any];
            base_routes_n = len(base["state"]["routes"] as list[dict[str, any]]);
            steps = [];
            messages = [];
            event_report = {};
            removed_ids = [];
            added_ids = [];
            scenario = "Baseline: every farmer ships alone";
            data_source = "real";
        } except Exception {
            error = "Could not reach the planning backend. Check that the server is running, then press Reset.";
        }
        loading = False;
    }

    async def run_merge() {
        if running { return; }
        running = True;
        error = "";
        try {
            res = await fetch_merge();
            state = res["state"] as dict[str, any];
            score = res["score"] as dict[str, any];
            steps = res["steps"] as list[dict[str, any]];
            event_report = {};
            removed_ids = [];
            added_ids = [];
            scenario = "After merge: farmers pooled onto shared trucks";
            data_source = "real";
        } except Exception {
            error = "The merge step failed. Press Reset and try again.";
        }
        running = False;
    }

    async def run_event() {
        if running { return; }
        running = True;
        error = "";
        t_id = eff_truck;
        label = "Truck breakdown: " + (truck_name_by_id[t_id] if t_id in truck_name_by_id else "truck");
        try {
            res = await fetch_event("truck_breakdown", t_id, "", "", "", "");
            dd = res["diff"] as dict[str, any];
            notes_list = dd["notes"] as list[str];
            state = res["state"] as dict[str, any];
            score = res["score"] as dict[str, any];
            messages = res["messages"] as list[dict[str, any]];
            removed_ids = dd["removedRouteIds"] as list[str];
            added_ids = dd["addedRouteIds"] as list[str];
            event_report = {"title": label, "explanation": res["explanation"] as str, "notes": notes_list};
            data_source = "real";
            scenario = label;
        } except Exception {
            error = "That event could not be applied. Press Reset and try again.";
            event_report = {};
        }
        running = False;
    }

    async def send_farmer_harvest() {
        text_in = farmer_text.strip();
        if len(text_in) == 0 or running { return; }
        running = True;
        error = "";
        fid = eff_farmer;
        sent_text = text_in;
        label = "New harvest: " + (farmer_name_by_id[fid] if fid in farmer_name_by_id else "farmer");
        try {
            res = await fetch_event("new_harvest", "", "", "", "", text_in, fid);
            dd = res["diff"] as dict[str, any];
            notes_list = dd["notes"] as list[str];
            reply_msgs = res["messages"] as list[dict[str, any]];
            if len(reply_msgs) > 0 {
                farmer_reply_text = reply_msgs[0]["text"] as str;
                farmer_reply_is_fallback = reply_msgs[0]["isFallback"] as bool;
            } else {
                # Parse failure (or anything else with no per-farmer message) -
                # show the backend's note verbatim, never a faked confirmation.
                farmer_reply_text = notes_list[0] if len(notes_list) > 0 else "";
                farmer_reply_is_fallback = False;
            }
            state = res["state"] as dict[str, any];
            score = res["score"] as dict[str, any];
            messages = reply_msgs;
            removed_ids = dd["removedRouteIds"] as list[str];
            added_ids = dd["addedRouteIds"] as list[str];
            event_report = {"title": label, "explanation": res["explanation"] as str, "notes": notes_list};
            data_source = "real";
            scenario = label;
            farmer_sent_text = sent_text;
            farmer_text = "";
        } except Exception {
            error = "That event could not be applied. Press Reset and try again.";
        }
        running = False;
    }

    # ---------- view ----------
    return <div style={{"minHeight": "100vh", "backgroundColor": C["page"], "color": C["text"], "fontFamily": FONT, "fontSize": "15px", "lineHeight": "1.55"}}>
      <header style={{"position": "sticky", "top": "0", "zIndex": "20", "backgroundColor": C["surface"], "borderBottom": "1px solid " + C["border"]}}>
        <div style={{"maxWidth": "1200px", "margin": "0 auto", "padding": "12px 24px", "display": "flex", "alignItems": "center", "gap": "20px", "flexWrap": "wrap"}}>
          <div style={{"display": "flex", "alignItems": "center", "gap": "10px"}}>
            <div style={{"width": "34px", "height": "34px", "borderRadius": "10px", "backgroundColor": C["primary"], "color": "#FFFFFF", "display": "grid", "placeItems": "center", "fontWeight": "700", "fontSize": "17px"}}>A</div>
            <div>
              <div style={{"fontWeight": "700", "fontSize": "17px", "letterSpacing": "-0.01em", "lineHeight": "1.2"}}>AgriPulse</div>
              <div style={{"fontSize": "12px", "color": C["muted"]}}>Harvest-to-market planning agent</div>
            </div>
          </div>
          <nav style={{"display": "flex", "gap": "4px", "backgroundColor": C["page"], "padding": "4px", "borderRadius": "12px", "border": "1px solid " + C["border"]}}>
            <button onClick={lambda (e: MouseEvent) { view = "dashboard"; }} style={{"padding": "8px 16px", "borderRadius": "9px", "border": "none", "cursor": "pointer", "fontFamily": "inherit", "fontSize": "14px", "fontWeight": "600", "backgroundColor": C["surface"] if view == "dashboard" else "transparent", "color": C["text"] if view == "dashboard" else C["muted"], "boxShadow": "0 1px 2px rgba(16,24,20,0.08)" if view == "dashboard" else "none"}}>Dashboard</button>
            <button onClick={lambda (e: MouseEvent) { view = "farmer"; }} style={{"padding": "8px 16px", "borderRadius": "9px", "border": "none", "cursor": "pointer", "fontFamily": "inherit", "fontSize": "14px", "fontWeight": "600", "backgroundColor": C["surface"] if view == "farmer" else "transparent", "color": C["text"] if view == "farmer" else C["muted"], "boxShadow": "0 1px 2px rgba(16,24,20,0.08)" if view == "farmer" else "none"}}>Farmer view</button>
          </nav>
          <div style={{"marginLeft": "auto", "display": "flex", "alignItems": "center", "gap": "12px", "flexWrap": "wrap"}}>
            <span style={{"fontSize": "13px", "color": C["muted"]}}>All data simulated</span>
            <button onClick={lambda (e: MouseEvent) { load_all(True); }} disabled={loading or running} style={{"padding": "7px 14px", "backgroundColor": C["surface"], "color": C["text"], "border": "1px solid " + C["borderStrong"], "borderRadius": "9px", "fontSize": "13px", "fontWeight": "600", "cursor": "pointer", "fontFamily": "inherit", "opacity": "0.5" if (loading or running) else "1"}}>Reset demo</button>
          </div>
        </div>
      </header>

      <main style={{"maxWidth": "1200px", "margin": "0 auto", "padding": "24px"}}>
        {if error { <div role="alert" style={{"padding": "14px 16px", "marginBottom": "18px", "backgroundColor": C["redSoft"], "border": "1px solid " + C["red"], "color": C["red"], "borderRadius": "12px", "fontSize": "14px"}}>{error}</div> }}
        {if loading { <div role="status" style={{"padding": "40px 20px", "textAlign": "center", "color": C["muted"], "backgroundColor": C["surface"], "border": "1px solid " + C["border"], "borderRadius": "14px"}}>Loading the farm network and baseline plan…</div> }}

        {if not loading {
          <div>
            {if view == "dashboard" {
              <div>
                <div style={{"display": "flex", "justifyContent": "space-between", "alignItems": "flex-end", "gap": "16px", "flexWrap": "wrap", "marginBottom": "18px"}}>
                  <div>
                    <h1 style={{"margin": "0 0 4px", "fontSize": "28px", "fontWeight": "700", "letterSpacing": "-0.02em"}}>Sri Lanka produce network</h1>
                    <div style={{"color": C["muted"], "fontSize": "15px"}}>{scenario}</div>
                  </div>
                  <div style={{"display": "flex", "alignItems": "center", "gap": "8px", "fontSize": "13px", "fontWeight": "600", "color": C["primaryDark"], "backgroundColor": C["primarySoft"], "padding": "7px 12px", "borderRadius": "999px"}}>
                    <span style={{"width": "8px", "height": "8px", "borderRadius": "50%", "backgroundColor": C["primary"], "display": "inline-block"}}></span>
                    Live backend · {str(len(farmers))} farmers · {str(len(hubs))} hubs · {str(len(markets))} markets
                  </div>
                </div>

                <div style={{"display": "grid", "gridTemplateColumns": "repeat(auto-fit, minmax(min(100%, 150px), 1fr))", "gap": "14px", "marginBottom": "18px"}}>
                  <div style={card}><div style={{"padding": "18px 20px"}}>
                    <div style={small_label}>Spoilage</div>
                    <div style={{"fontSize": "30px", "fontWeight": "700", "letterSpacing": "-0.02em", "fontVariantNumeric": "tabular-nums"}}>{str(round(a_sp, 1))}%</div>
                    <div style={{"fontSize": "13px", "color": C["muted"]}}>Baseline {str(round(b_sp, 1))}%</div>
                    <div style={{"marginTop": "8px", "fontSize": "13px", "fontWeight": "600", "color": C["primaryDark"] if sp_good else C["subtle"]}}>{sp_delta}</div>
                  </div></div>
                  <div style={card}><div style={{"padding": "18px 20px"}}>
                    <div style={small_label}>Farmer income</div>
                    <div style={{"fontSize": "30px", "fontWeight": "700", "letterSpacing": "-0.02em", "fontVariantNumeric": "tabular-nums"}}>{fmt_int(a_in)}</div>
                    <div style={{"fontSize": "13px", "color": C["muted"]}}>Baseline {fmt_int(b_in)} LKR</div>
                    <div style={{"marginTop": "8px", "fontSize": "13px", "fontWeight": "600", "color": C["primaryDark"] if in_good else C["subtle"]}}>{in_delta}</div>
                  </div></div>
                  <div style={card}><div style={{"padding": "18px 20px"}}>
                    <div style={small_label}>Truck cost</div>
                    <div style={{"fontSize": "30px", "fontWeight": "700", "letterSpacing": "-0.02em", "fontVariantNumeric": "tabular-nums"}}>{fmt_int(a_tc)}</div>
                    <div style={{"fontSize": "13px", "color": C["muted"]}}>Baseline {fmt_int(b_tc)} LKR</div>
                    <div style={{"marginTop": "8px", "fontSize": "13px", "fontWeight": "600", "color": C["primaryDark"] if tc_good else C["subtle"]}}>{tc_delta}</div>
                  </div></div>
                  <div style={card}><div style={{"padding": "18px 20px"}}>
                    <div style={small_label}>Truck trips</div>
                    <div style={{"fontSize": "30px", "fontWeight": "700", "letterSpacing": "-0.02em", "fontVariantNumeric": "tabular-nums"}}>{str(trips_now)}</div>
                    <div style={{"fontSize": "13px", "color": C["muted"]}}>Baseline {str(base_routes_n)} solo trips</div>
                    <div style={{"marginTop": "8px", "fontSize": "13px", "fontWeight": "600", "color": C["primaryDark"] if trips_now < base_routes_n else C["subtle"]}}>{("-" + str(base_routes_n - trips_now) + " trips") if trips_now < base_routes_n else "no change yet"}</div>
                  </div></div>
                </div>

                <div style={card}>
                  <div style={{"padding": "20px 22px"}}>
                    <div style={{"display": "flex", "justifyContent": "space-between", "alignItems": "center", "flexWrap": "wrap", "gap": "12px", "marginBottom": "16px"}}>
                      <h2 style={h2}>Run the agent</h2>
                      <div style={{"fontSize": "13px", "color": C["muted"]}}>Step 1: merge routes. Step 2: break something and watch it re-plan.</div>
                    </div>
                    <div style={{"display": "grid", "gridTemplateColumns": "repeat(auto-fit, minmax(min(100%, 320px), 1fr))", "gap": "16px"}}>
                      <div style={{"padding": "16px", "backgroundColor": C["surface2"], "border": "1px solid " + C["border"], "borderRadius": "12px"}}>
                        <div style={small_label}>1 · Pool farmers</div>
                        <p style={{"margin": "6px 0 12px", "fontSize": "14px", "color": C["muted"]}}>Combine solo trips onto shared trucks wherever capacity and net value allow.</p>
                        <button onClick={lambda (e: MouseEvent) { run_merge(); }} disabled={running} style={{"padding": "11px 18px", "backgroundColor": C["primary"], "color": "#FFFFFF", "border": "1px solid " + C["primary"], "borderRadius": "10px", "fontSize": "14px", "fontWeight": "600", "cursor": "pointer", "fontFamily": "inherit", "opacity": "0.55" if running else "1"}}>{"Working…" if running else "Merge routes"}</button>
                      </div>
                      <div style={{"padding": "16px", "backgroundColor": C["surface2"], "border": "1px solid " + C["border"], "borderRadius": "12px"}}>
                        <div style={small_label}>2 · Simulate a truck breakdown</div>
                        <div style={{"marginTop": "10px"}}>
                          <select value={eff_truck} onChange={lambda (e: ChangeEvent) { sel_truck = e.target.value; }} style={field}>
                            {for tr in trucks { <option key={tr["id"] as str} value={tr["id"] as str}>{tr["name"]} · {fmt_int(tr["capacityKg"] as float)} kg</option> }}
                          </select>
                        </div>
                        <div style={{"marginTop": "12px"}}>
                          <button onClick={lambda (e: MouseEvent) { run_event(); }} disabled={running} style={{"padding": "10px 16px", "backgroundColor": C["text"], "color": "#FFFFFF", "border": "1px solid " + C["text"], "borderRadius": "10px", "fontSize": "14px", "fontWeight": "600", "cursor": "pointer", "fontFamily": "inherit", "opacity": "0.55" if running else "1"}}>{"Working…" if running else "Run event"}</button>
                        </div>
                      </div>
                    </div>
                  </div>
                </div>

                <div style={{"display": "grid", "gridTemplateColumns": "repeat(auto-fit, minmax(min(100%, 420px), 1fr))", "gap": "18px", "marginTop": "18px", "alignItems": "start"}}>
                  <div style={card}>
                    <div style={{"padding": "18px 22px", "borderBottom": "1px solid " + C["border"], "display": "flex", "justifyContent": "space-between", "alignItems": "baseline", "flexWrap": "wrap", "gap": "8px"}}>
                      <h2 style={h2}>Route network</h2>
                      <span style={{"fontSize": "13px", "color": C["muted"]}}>Line thickness = farmers on that truck</span>
                    </div>
                    <div style={{"padding": "8px 12px 4px", "overflowX": "auto"}}>
                      <svg viewBox={"0 0 820 " + str(svg_h)} style={{"width": "100%", "height": "auto", "minWidth": "560px"}} role="img" aria-label="Routes from hubs to markets, coloured by truck">
                        {for pa in paths { <path key={pa["id"] as str} d={pa["d"] as str} fill="none" stroke={pa["color"] as str} strokeWidth={pa["w"] as float} strokeLinecap="round" opacity="0.8" /> }}
                        {for hid in hub_used {
                          hy = hub_y[hid] if hid in hub_y else 52.0;
                          <g key={"h" + hid}>
                            <circle cx="190" cy={hy} r="9" fill="#FFFFFF" stroke={C["text"]} strokeWidth="2.5" />
                            <text x="172" y={hy + 5} textAnchor="end" fontSize="13" fontWeight="600" fill={C["text"]}>{hub_name_by_id[hid] if hid in hub_name_by_id else "Hub"}</text>
                          </g>
                        }}
                        {for mid in mkt_used {
                          my = mkt_y[mid] if mid in mkt_y else 52.0;
                          <g key={"m" + mid}>
                            <circle cx="620" cy={my} r="9" fill={C["primary"]} stroke="#FFFFFF" strokeWidth="2.5" />
                            <text x="638" y={my + 5} fontSize="13" fontWeight="600" fill={C["text"]}>{market_name_by_id[mid] if mid in market_name_by_id else "Market"}</text>
                          </g>
                        }}
                      </svg>
                    </div>
                    <div style={{"padding": "4px 22px 16px", "display": "flex", "gap": "14px", "flexWrap": "wrap", "fontSize": "13px", "color": C["muted"]}}>
                      {for tk in trucks { <span key={tk["id"] as str} style={{"display": "inline-flex", "alignItems": "center", "gap": "6px"}}><span style={{"width": "14px", "height": "4px", "borderRadius": "2px", "backgroundColor": truck_color_by_id[tk["id"] as str], "display": "inline-block"}}></span>{tk["name"]}</span> }}
                    </div>
                    <div style={{"borderTop": "1px solid " + C["border"]}}>
                      {for r in routes {
                        rid = r["id"] as str;
                        r_ids = r["farmerIds"] as list[str];
                        r_n = len(r_ids);
                        names_txt = "";
                        shown = 0;
                        for fid in r_ids {
                            if shown < 2 { names_txt = names_txt + ("" if shown == 0 else ", ") + (farmer_name_by_id[fid] if fid in farmer_name_by_id else "Farmer"); }
                            shown += 1;
                        }
                        if r_n > 2 { names_txt = names_txt + " +" + str(r_n - 2) + " more"; }
                        r_hub = (r["hubIds"] as list[str])[0] if len(r["hubIds"] as list[str]) > 0 else "";
                        r_mkt = r["marketId"] as str;
                        r_truck = r["truckId"] as str;
                        r_plan = plan_by_route[rid] if rid in plan_by_route else {};
                        is_removed = rid in removed_ids;
                        is_added = rid in added_ids;
                        accent = C["red"] if is_removed else C["primary"] if is_added else (truck_color_by_id[r_truck] if r_truck in truck_color_by_id else C["border"]);
                        <div key={rid} style={{"display": "flex", "gap": "14px", "padding": "14px 22px 14px 0", "borderBottom": "1px solid " + C["border"], "alignItems": "stretch"}}>
                          <div style={{"width": "4px", "borderRadius": "0 4px 4px 0", "backgroundColor": accent, "flexShrink": "0"}}></div>
                          <div style={{"flex": "1", "minWidth": "0"}}>
                            <div style={{"display": "flex", "justifyContent": "space-between", "gap": "10px", "flexWrap": "wrap"}}>
                              <div style={{"fontWeight": "600"}}>{("Shared truck · " + str(r_n) + " farmers") if r_n > 1 else "Solo trip · 1 farmer"}<span style={{"marginLeft": "8px", "fontSize": "12px", "fontWeight": "500", "color": C["subtle"]}}>{rid}</span>{if is_added { <span style={{"marginLeft": "8px", "fontSize": "12px", "fontWeight": "600", "color": C["primaryDark"], "backgroundColor": C["primarySoft"], "padding": "2px 8px", "borderRadius": "999px"}}>new</span> }}{if is_removed { <span style={{"marginLeft": "8px", "fontSize": "12px", "fontWeight": "600", "color": C["red"], "backgroundColor": C["redSoft"], "padding": "2px 8px", "borderRadius": "999px"}}>removed</span> }}</div>
                              <div style={{"fontSize": "13px", "color": C["muted"]}}>{truck_name_by_id[r_truck] if r_truck in truck_name_by_id else "Truck"}</div>
                            </div>
                            <div style={{"fontSize": "13px", "color": C["muted"], "marginTop": "2px"}}>{names_txt}</div>
                            <div style={{"fontSize": "13px", "color": C["muted"], "marginTop": "4px"}}>{hub_name_by_id[r_hub] if r_hub in hub_name_by_id else "Hub"} to {market_name_by_id[r_mkt] if r_mkt in market_name_by_id else "Market"} · {str(round(r["distanceKm"] as float, 1))} km · {str(round(r["hours"] as float, 1))} h{(" · spoilage " + str(round(r_plan["expectedSpoilagePct"] as float, 1)) + "% · income " + fmt_int(r_plan["expectedIncome"] as float) + " LKR") if r_plan else ""}</div>
                          </div>
                        </div>
                      }}
                    </div>
                  </div>

                  <div style={{"display": "flex", "flexDirection": "column", "gap": "18px"}}>
                    <div style={card}>
                      <div style={{"padding": "18px 22px", "borderBottom": "1px solid " + C["border"]}}><h2 style={h2}>Agent activity</h2></div>
                      <div style={{"padding": "16px 22px"}}>
                        {if len(steps) == 0 and not event_report { <p style={{"margin": "0", "color": C["muted"], "fontSize": "14px"}}>Nothing yet. Press <strong>Merge routes</strong> to watch the agent pool farmers step by step.</p> }}
                        {if len(steps) > 0 {
                          <div>
                            <div style={{"fontSize": "13px", "fontWeight": "600", "color": C["primaryDark"], "marginBottom": "8px"}}>Merge: {str(len(steps))} steps</div>
                            <div style={{"maxHeight": "260px", "overflowY": "auto", "paddingRight": "6px"}}>
                              {for st in steps { <div key={st["newRouteId"] as str} style={{"display": "flex", "gap": "10px", "padding": "8px 0", "borderBottom": "1px solid " + C["border"], "fontSize": "13px"}}><span style={{"flexShrink": "0", "width": "22px", "height": "22px", "borderRadius": "50%", "backgroundColor": C["primarySoft"], "color": C["primaryDark"], "display": "grid", "placeItems": "center", "fontSize": "12px", "fontWeight": "700"}}>{str(st["stepNo"])}</span><span style={{"color": C["muted"]}}>{st["reason"]}</span></div> }}
                            </div>
                          </div>
                        }}
                        {if event_report {
                          <div style={{"marginTop": "14px" if len(steps) > 0 else "0", "padding": "14px 16px", "borderRadius": "12px", "backgroundColor": C["surface2"], "border": "1px solid " + C["border"]}}>
                            <div style={{"display": "flex", "justifyContent": "space-between", "gap": "8px", "flexWrap": "wrap", "alignItems": "center"}}>
                              <strong style={{"fontSize": "14px"}}>{event_report["title"]}</strong>
                            </div>
                            {for note in (event_report["notes"] as list[str]) { <p key={note} style={{"margin": "8px 0 0", "fontSize": "13px", "color": C["muted"]}}>{note}</p> }}
                            <p style={{"margin": "8px 0 0", "fontSize": "14px"}}>{event_report["explanation"]}</p>
                          </div>
                        }}
                      </div>
                    </div>

                    <div style={card}>
                      <div style={{"padding": "18px 22px", "borderBottom": "1px solid " + C["border"]}}><h2 style={h2}>Fleet</h2></div>
                      <div style={{"padding": "6px 22px 10px"}}>
                        {for tk in trucks {
                          tkid = tk["id"] as str;
                          is_broken = tk["status"] as str == "broken";
                          <div key={tkid} style={{"display": "flex", "justifyContent": "space-between", "alignItems": "center", "padding": "10px 0", "borderBottom": "1px solid " + C["border"], "gap": "10px"}}>
                            <span style={{"display": "inline-flex", "alignItems": "center", "gap": "8px"}}><span style={{"width": "10px", "height": "10px", "borderRadius": "3px", "backgroundColor": truck_color_by_id[tkid], "display": "inline-block"}}></span>{tk["name"]}<span style={{"fontSize": "12px", "color": C["subtle"]}}>{fmt_int(tk["capacityKg"] as float)} kg · {fmt_int(tk["costPerKm"] as float)} LKR/km</span></span>
                            <span style={{"fontSize": "12px", "fontWeight": "600", "padding": "3px 10px", "borderRadius": "999px", "color": C["red"] if is_broken else C["primaryDark"], "backgroundColor": C["redSoft"] if is_broken else C["primarySoft"]}}>{"broken down" if is_broken else "available"}</span>
                          </div>
                        }}
                      </div>
                    </div>

                    <div style={card}>
                      <div style={{"padding": "18px 22px", "borderBottom": "1px solid " + C["border"]}}><h2 style={h2}>Market prices</h2><div style={{"fontSize": "13px", "color": C["muted"], "marginTop": "2px"}}>LKR per kg</div></div>
                      <div style={{"padding": "6px 22px 10px"}}>
                        {for mk in markets {
                          mkid = mk["id"] as str;
                          mk_prices = mk["prices"] as dict[str, float];
                          <div key={mkid} style={{"padding": "10px 0", "borderBottom": "1px solid " + C["border"]}}>
                            <div style={{"display": "flex", "justifyContent": "space-between", "gap": "8px", "flexWrap": "wrap"}}>
                              <strong style={{"fontSize": "14px"}}>{mk["name"]}</strong>
                              <span style={{"fontSize": "12px", "color": C["subtle"]}}>demand cap {fmt_int(mk["demandCapKg"] as float)} kg</span>
                            </div>
                            <div style={{"display": "flex", "gap": "6px", "flexWrap": "wrap", "marginTop": "6px"}}>
                              {for cn in mk_prices.keys() {
                                <span key={cn} style={{"fontSize": "12px", "padding": "3px 9px", "borderRadius": "999px", "backgroundColor": C["surface2"], "border": "1px solid " + C["border"], "color": C["muted"], "fontWeight": "500"}}>{pretty(cn)} {str(mk_prices[cn])}</span>
                              }}
                            </div>
                          </div>
                        }}
                      </div>
                    </div>
                  </div>
                </div>

                {if len(messages) > 0 {
                  <div style={{"marginTop": "18px"}}>
                    <div style={card}>
                      <div style={{"padding": "18px 22px", "borderBottom": "1px solid " + C["border"]}}><h2 style={h2}>Farmer messages</h2><div style={{"fontSize": "13px", "color": C["muted"], "marginTop": "2px"}}>Sent to each affected farmer in their own language.</div></div>
                      <div style={{"padding": "4px 22px 8px"}}>
                        {for msg in messages {
                          <div key={(msg["farmerId"] as str) + (msg["language"] as str)} style={{"padding": "12px 0", "borderBottom": "1px solid " + C["border"], "display": "flex", "gap": "12px", "alignItems": "flex-start"}}>
                            <div style={{"width": "32px", "height": "32px", "borderRadius": "50%", "backgroundColor": C["primarySoft"], "color": C["primaryDark"], "display": "grid", "placeItems": "center", "fontWeight": "700", "fontSize": "13px", "flexShrink": "0"}}>{(msg["farmerName"] as str)[0]}</div>
                            <div style={{"flex": "1", "minWidth": "0"}}>
                              <div style={{"display": "flex", "gap": "8px", "alignItems": "center", "flexWrap": "wrap"}}>
                                <strong style={{"fontSize": "14px"}}>{msg["farmerName"]}</strong>
                                <span style={{"fontSize": "11px", "fontWeight": "700", "color": C["subtle"], "letterSpacing": "0.04em"}}>{(msg["language"] as str).upper()}</span>
                                {if msg["isFallback"] { <span style={{"fontSize": "11px", "fontWeight": "600", "padding": "2px 8px", "borderRadius": "999px", "color": C["subtle"], "backgroundColor": C["surface2"]}}>Template message</span> }}
                              </div>
                              <div style={{"marginTop": "3px", "fontSize": "15px"}}>{msg["text"]}</div>
                            </div>
                          </div>
                        }}
                      </div>
                    </div>
                  </div>
                }}
              </div>
            }}

            {if view == "farmer" {
              <div style={{"maxWidth": "720px", "margin": "0 auto"}}>
                <div style={{"display": "flex", "gap": "10px", "flexWrap": "wrap", "alignItems": "center", "marginBottom": "16px"}}>
                  <select value={eff_farmer} onChange={lambda (e: ChangeEvent) { sel_farmer = e.target.value; farmer_sent_text = ""; farmer_reply_text = ""; }} aria-label={t["pick"]} style={{"flex": "1", "minWidth": "200px", "padding": "12px 14px", "border": "1px solid " + C["borderStrong"], "borderRadius": "12px", "fontSize": "16px", "fontFamily": "inherit", "backgroundColor": C["surface"], "color": C["text"]}}>
                    {for fm in farmers { <option key={fm["id"] as str} value={fm["id"] as str}>{fm["name"]} · {fm["district"]}</option> }}
                  </select>
                  <div style={{"display": "flex", "gap": "4px", "padding": "4px", "backgroundColor": C["surface"], "border": "1px solid " + C["border"], "borderRadius": "12px"}}>
                    <button onClick={lambda (e: MouseEvent) { lang = "en"; }} style={{"padding": "9px 14px", "border": "none", "borderRadius": "9px", "cursor": "pointer", "fontFamily": "inherit", "fontSize": "15px", "fontWeight": "600", "backgroundColor": C["primary"] if lang == "en" else "transparent", "color": "#FFFFFF" if lang == "en" else C["muted"]}}>English</button>
                    <button onClick={lambda (e: MouseEvent) { lang = "si"; }} style={{"padding": "9px 14px", "border": "none", "borderRadius": "9px", "cursor": "pointer", "fontFamily": "inherit", "fontSize": "15px", "fontWeight": "600", "backgroundColor": C["primary"] if lang == "si" else "transparent", "color": "#FFFFFF" if lang == "si" else C["muted"]}}>සිංහල</button>
                    <button onClick={lambda (e: MouseEvent) { lang = "ta"; }} style={{"padding": "9px 14px", "border": "none", "borderRadius": "9px", "cursor": "pointer", "fontFamily": "inherit", "fontSize": "15px", "fontWeight": "600", "backgroundColor": C["primary"] if lang == "ta" else "transparent", "color": "#FFFFFF" if lang == "ta" else C["muted"]}}>தமிழ்</button>
                  </div>
                </div>

                {if eff_farmer {
                  <div>
                    <div style={card}>
                      <div style={{"padding": "22px"}}>
                        <div style={{"fontSize": "26px", "fontWeight": "700", "letterSpacing": "-0.01em"}}>{t["hello"]}, {farmer_name_by_id[eff_farmer]}</div>
                        {for fm in farmers { if (fm["id"] as str) == eff_farmer { <div key={eff_farmer} style={{"color": C["muted"], "fontSize": "16px", "marginTop": "2px"}}>{fm["district"]}</div> } }}
                      </div>
                    </div>

                    {if eff_farmer in harvest_by_farmer {
                      <div style={{"marginTop": "14px"}}>
                        <div style={card}>
                          <div style={{"padding": "20px 22px"}}>
                            <div style={small_label}>{t["harvest"]}</div>
                            <div style={{"display": "grid", "gridTemplateColumns": "repeat(auto-fit, minmax(150px, 1fr))", "gap": "14px", "marginTop": "12px"}}>
                              <div><div style={{"fontSize": "13px", "color": C["muted"]}}>{t["crop"]}</div><div style={{"fontSize": "20px", "fontWeight": "650"}}>{pretty(harvest_by_farmer[eff_farmer]["crop"] as str)}</div></div>
                              <div><div style={{"fontSize": "13px", "color": C["muted"]}}>{t["qty"]}</div><div style={{"fontSize": "20px", "fontWeight": "650"}}>{fmt_int(harvest_by_farmer[eff_farmer]["kg"] as float)} kg</div></div>
                              <div><div style={{"fontSize": "13px", "color": C["muted"]}}>{t["fresh"]}</div><div style={{"fontSize": "20px", "fontWeight": "650"}}>{fmt_int(harvest_by_farmer[eff_farmer]["shelfLifeHours"] as float)} {t["hours"]}</div></div>
                            </div>
                          </div>
                        </div>
                      </div>
                    }}

                    {if eff_farmer in route_by_farmer {
                      <div style={{"marginTop": "14px"}}>
                        <div style={card}>
                          <div style={{"padding": "20px 22px"}}>
                            <div style={small_label}>{t["delivery"]}</div>
                            {for fr in [route_by_farmer[eff_farmer]] {
                              fr_id = fr["id"] as str;
                              fr_n = len(fr["farmerIds"] as list[str]);
                              fr_truck = fr["truckId"] as str;
                              fr_mkt = fr["marketId"] as str;
                              fr_plan = plan_by_route[fr_id] if fr_id in plan_by_route else {};
                              <div key={fr_id}>
                                <div style={{"marginTop": "10px", "padding": "12px 14px", "borderRadius": "12px", "backgroundColor": C["primarySoft"] if fr_n > 1 else C["surface2"], "color": C["primaryDark"] if fr_n > 1 else C["muted"], "fontSize": "16px", "fontWeight": "600"}}>{t["shared"].replace("{n}", str(fr_n - 1)) if fr_n > 1 else t["alone"]}</div>
                                <div style={{"display": "grid", "gridTemplateColumns": "repeat(auto-fit, minmax(150px, 1fr))", "gap": "14px", "marginTop": "14px"}}>
                                  <div><div style={{"fontSize": "13px", "color": C["muted"]}}>{t["truck"]}</div><div style={{"fontSize": "17px", "fontWeight": "650"}}>{truck_name_by_id[fr_truck] if fr_truck in truck_name_by_id else "-"}</div></div>
                                  <div><div style={{"fontSize": "13px", "color": C["muted"]}}>{t["market"]}</div><div style={{"fontSize": "17px", "fontWeight": "650"}}>{market_name_by_id[fr_mkt] if fr_mkt in market_name_by_id else "-"}</div></div>
                                  <div><div style={{"fontSize": "13px", "color": C["muted"]}}>{t["distance"]}</div><div style={{"fontSize": "17px", "fontWeight": "650"}}>{str(round(fr["distanceKm"] as float, 1))} km</div></div>
                                  <div><div style={{"fontSize": "13px", "color": C["muted"]}}>{t["time"]}</div><div style={{"fontSize": "17px", "fontWeight": "650"}}>{str(round(fr["hours"] as float, 1))} {t["hours"]}</div></div>
                                  {if fr_plan { <div><div style={{"fontSize": "13px", "color": C["muted"]}}>{t["loss"]}</div><div style={{"fontSize": "17px", "fontWeight": "650"}}>{str(round(fr_plan["expectedSpoilagePct"] as float, 1))}%</div></div> }}
                                </div>
                              </div>
                            }}
                          </div>
                        </div>
                      </div>
                    }}

                    <div style={{"marginTop": "14px"}}>
                      <div style={card}>
                        <div style={{"padding": "20px 22px"}}>
                          <div style={small_label}>{t["messages"]}</div>
                          {for msg in my_messages {
                            <div key={(msg["farmerId"] as str) + (msg["language"] as str)} style={{"marginTop": "12px", "padding": "14px 16px", "backgroundColor": C["surface2"], "border": "1px solid " + C["border"], "borderRadius": "12px", "fontSize": "17px"}}>
                              {if msg["isFallback"] { <div style={{"marginBottom": "6px"}}><span style={{"fontSize": "11px", "fontWeight": "600", "padding": "2px 8px", "borderRadius": "999px", "color": C["subtle"], "backgroundColor": C["surface"]}}>Template message</span></div> }}
                              {msg["text"]}
                            </div>
                          }}
                          {if len(my_messages) == 0 { <p style={{"margin": "10px 0 0", "color": C["muted"], "fontSize": "16px"}}>{t["none"]}</p> }}
                        </div>
                      </div>
                    </div>

                    <div style={{"marginTop": "14px"}}>
                      <div style={card}>
                        <div style={{"padding": "20px 22px"}}>
                          <div style={small_label}>{t["log"]}</div>
                          <textarea value={farmer_text} onChange={lambda (e: ChangeEvent) { farmer_text = e.target.value; }} rows={3} placeholder={t["ph"]} style={{"width": "100%", "marginTop": "10px", "padding": "12px 14px", "border": "1px solid " + C["borderStrong"], "borderRadius": "12px", "fontSize": "17px", "fontFamily": "inherit", "boxSizing": "border-box"}}></textarea>
                          <button onClick={lambda (e: MouseEvent) { send_farmer_harvest(); }} disabled={running} style={{"marginTop": "12px", "width": "100%", "padding": "14px", "backgroundColor": C["primary"], "color": "#FFFFFF", "border": "none", "borderRadius": "12px", "fontSize": "17px", "fontWeight": "650", "cursor": "pointer", "fontFamily": "inherit", "opacity": "0.55" if running else "1"}}>{"Working…" if running else t["send"]}</button>

                          {if farmer_sent_text {
                            <div style={{"marginTop": "16px", "display": "flex", "flexDirection": "column", "gap": "10px"}}>
                              <div style={{"alignSelf": "flex-end", "maxWidth": "85%", "padding": "12px 14px", "backgroundColor": C["primary"], "color": "#FFFFFF", "borderRadius": "14px 14px 4px 14px", "fontSize": "16px"}}>{farmer_sent_text}</div>
                              {if farmer_reply_text {
                                <div style={{"alignSelf": "flex-start", "maxWidth": "85%", "padding": "12px 14px", "backgroundColor": C["surface2"], "border": "1px solid " + C["border"], "borderRadius": "14px 14px 14px 4px", "fontSize": "16px"}}>
                                  {if farmer_reply_is_fallback { <div style={{"marginBottom": "6px"}}><span style={{"fontSize": "11px", "fontWeight": "600", "padding": "2px 8px", "borderRadius": "999px", "color": C["subtle"], "backgroundColor": C["surface"]}}>Template message</span></div> }}
                                  {farmer_reply_text}
                                </div>
                              }}
                            </div>
                          }}
                        </div>
                      </div>
                    </div>
                  </div>
                }}
              </div>
            }}
          </div>
        }}
      </main>
      <footer style={{"textAlign": "center", "padding": "22px", "fontSize": "13px", "color": C["subtle"]}}>All data simulated · Built in Jac for the Jaseci AI Hackathon 2026</footer>
    </div>;
}
