

glob THEME: dict[str, str] = {
    "page": "#F5F7F4", "panel": "#FFFFFF", "border": "#D8DDD5",
    "ink": "#1E2B26", "muted": "#5B6A62", "green": "#1F6B4A",
    "slate": "#7A8780", "blue": "#2F6DB5", "ochre": "#C98A1B",
    "plum": "#8A4F8F", "red": "#C2412D"
};

def:pub app -> JsxElement {
    has chosen: str = "",
        merged: bool = False;

    def select_route(e: MouseEvent) {
        chosen = "North Field" if chosen != "North Field" else "";
    }

    def confirm_merge(e: MouseEvent) {
        if chosen { merged = True; chosen = ""; }
    }

    return <div style={{"minHeight":"100vh", "backgroundColor":THEME["page"], "color":THEME["ink"], "fontFamily":"system-ui, -apple-system, BlinkMacSystemFont, sans-serif", "fontSize":"16px"}}>
      <header style={{"display":"flex", "alignItems":"center", "justifyContent":"space-between", "gap":"16px", "padding":"18px 28px", "borderBottom":"1px solid " + THEME["border"], "backgroundColor":THEME["panel"]}}>
        <div style={{"display":"flex", "alignItems":"center", "gap":"12px"}}>
          <div style={{"width":"34px", "height":"34px", "display":"grid", "placeItems":"center", "backgroundColor":THEME["green"], "color":"white", "fontWeight":"700", "borderRadius":"4px"}}>A</div>
          <div><strong style={{"fontSize":"20px"}}>AgriPulse</strong><div style={{"fontSize":"14px", "color":THEME["muted"]}}>Regional route operations</div></div>
        </div>
        <div style={{"fontSize":"14px", "color":THEME["muted"]}}>Network status <strong style={{"color":THEME["green"]}}>Operational</strong></div>
      </header>
      <main style={{"padding":"28px", "maxWidth":"1440px", "margin":"0 auto"}}>
        <div style={{"display":"flex", "alignItems":"end", "justifyContent":"space-between", "gap":"16px", "flexWrap":"wrap", "marginBottom":"22px"}}>
          <div><h1 style={{"fontSize":"28px", "margin":"0 0 6px"}}>Route network</h1><p style={{"margin":"0", "color":THEME["muted"]}}>Review regional lanes and consolidate overlapping routes.</p></div>
          <button onClick={confirm_merge} disabled={not chosen} style={{"padding":"11px 16px", "backgroundColor":THEME["green"], "color":"white", "border":"1px solid " + THEME["green"], "borderRadius":"4px", "fontSize":"16px", "fontWeight":"600", "cursor":"pointer"}}>Merge selected routes</button>
        </div>
        <section style={{"display":"grid", "gridTemplateColumns":"repeat(auto-fit, minmax(180px, 1fr))", "border":"1px solid " + THEME["border"], "backgroundColor":THEME["panel"], "marginBottom":"20px"}}>
          <div style={{"padding":"18px 20px", "borderRight":"1px solid " + THEME["border"]}}><div style={{"fontSize":"14px", "color":THEME["muted"]}}>Active routes</div><div style={{"fontSize":"32px", "fontWeight":"600", "fontVariantNumeric":"tabular-nums"}}>24</div><div style={{"color":THEME["muted"]}}>Across 6 regions</div></div>
          <div style={{"padding":"18px 20px", "borderRight":"1px solid " + THEME["border"]}}><div style={{"fontSize":"14px", "color":THEME["muted"]}}>Weekly capacity</div><div style={{"fontSize":"32px", "fontWeight":"600", "fontVariantNumeric":"tabular-nums"}}>186 t</div><div style={{"color":THEME["muted"]}}>Scheduled this week</div></div>
          <div style={{"padding":"18px 20px", "borderRight":"1px solid " + THEME["border"]}}><div style={{"fontSize":"14px", "color":THEME["muted"]}}>Potential overlap</div><div style={{"fontSize":"32px", "fontWeight":"600", "fontVariantNumeric":"tabular-nums", "color":THEME["ochre"]}}>3 lanes</div><div style={{"color":THEME["muted"]}}>Review suggested</div></div>
          <div style={{"padding":"18px 20px"}}><div style={{"fontSize":"14px", "color":THEME["muted"]}}>Network score</div><div style={{"fontSize":"32px", "fontWeight":"600", "fontVariantNumeric":"tabular-nums"}}>92</div><div style={{"color":THEME["muted"]}}>Out of 100</div></div>
        </section>
        <div style={{"display":"grid", "gridTemplateColumns":"minmax(0, 2fr) minmax(280px, 1fr)", "gap":"20px"}}>
          <section style={{"border":"1px solid " + THEME["border"], "backgroundColor":THEME["panel"], "minWidth":"0"}}>
            <div style={{"padding":"18px 20px", "borderBottom":"1px solid " + THEME["border"], "display":"flex", "justifyContent":"space-between", "alignItems":"center", "flexWrap":"wrap", "gap":"8px"}}><div><h2 style={{"margin":"0 0 4px", "fontSize":"20px"}}>Regional network</h2><div style={{"color":THEME["muted"]}}>Select a lane to review a proposed merge</div></div><span style={{"fontSize":"14px", "color":THEME["muted"]}}>Central Valley · Live simulation</span></div>
            <div style={{"padding":"24px", "minHeight":"360px", "position":"relative", "overflow":"hidden", "backgroundColor":"#FAFBF9"}}>
              <div style={{"position":"absolute", "inset":"0", "opacity":"0.35", "backgroundImage":"linear-gradient(#D8DDD5 1px, transparent 1px), linear-gradient(90deg, #D8DDD5 1px, transparent 1px)", "backgroundSize":"42px 42px"}}></div>
              <svg viewBox="0 0 760 330" style={{"position":"relative", "width":"100%", "height":"330px"}} role="img" aria-label="Route network map with farms, hub and distribution center">
                <path d="M95 240 C190 215 235 145 345 165 S500 230 650 120" fill="none" stroke={THEME["blue"]} strokeWidth="5" />
                <path d="M95 240 C185 260 252 220 345 165 S500 85 650 120" fill="none" stroke={THEME["ochre"]} strokeWidth="5" />
                <path d="M95 240 C185 260 252 220 345 165 S500 85 650 120" fill="none" stroke={THEME["plum"]} strokeWidth="3" strokeDasharray="9 8" />
                <path d="M345 165 L490 285" fill="none" stroke={THEME["green"]} strokeWidth="5" />
                <circle cx="95" cy="240" r="13" fill={THEME["green"]} /><circle cx="345" cy="165" r="15" fill={THEME["green"]} /><circle cx="650" cy="120" r="13" fill={THEME["green"]} /><circle cx="490" cy="285" r="11" fill={THEME["green"]} />
                <text x="72" y="278" fill={THEME["ink"]} fontSize="15">North Farm</text><text x="310" y="145" fill={THEME["ink"]} fontSize="15">Packing hub</text><text x="600" y="99" fill={THEME["ink"]} fontSize="15">East Market</text><text x="447" y="315" fill={THEME["ink"]} fontSize="15">South depot</text>
              </svg>
              <button onClick={select_route} style={{"position":"absolute", "left":"29%", "top":"40%", "padding":"8px 11px", "backgroundColor":THEME["panel"], "color":THEME["ink"], "border":"1px solid " + THEME["green"], "borderRadius":"4px", "fontSize":"14px", "cursor":"pointer", "outline":"2px solid " + (THEME["green"] if chosen else "transparent")}}>North Field {" · Selected" if chosen else " · Select lane"}</button>
            </div>
            <div style={{"padding":"14px 20px", "borderTop":"1px solid " + THEME["border"], "display":"flex", "flexWrap":"wrap", "gap":"18px", "fontSize":"14px"}}><span><b style={{"color":THEME["blue"]}}>━</b> Truck 1</span><span><b style={{"color":THEME["ochre"]}}>━</b> Truck 2</span><span><b style={{"color":THEME["plum"]}}>┄</b> Proposed route</span><span><b style={{"color":THEME["green"]}}>●</b> Distribution point</span></div>
          </section>
          <aside style={{"display":"flex", "flexDirection":"column", "gap":"16px"}}>
            <section style={{"border":"1px solid " + THEME["border"], "backgroundColor":THEME["panel"], "padding":"18px 20px"}}><h2 style={{"margin":"0 0 14px", "fontSize":"20px"}}>Route review</h2><div style={{"padding":"12px", "border":"1px dashed " + THEME["red"], "marginBottom":"12px"}}><strong style={{"color":THEME["red"]}}>Removed</strong><div style={{"marginTop":"4px"}}>North Field → East Market</div><div style={{"fontSize":"14px", "color":THEME["muted"]}}>Overlaps with the Central Valley lane</div></div><div style={{"padding":"12px", "border":"1px solid " + THEME["green"]}}><strong style={{"color":THEME["green"]}}>New</strong><div style={{"marginTop":"4px"}}>North Farm → Packing hub → East Market</div><div style={{"fontSize":"14px", "color":THEME["muted"]}}>Consolidates 2 deliveries into 1 lane</div></div>
              {if merged { <div role="status" style={{"padding":"12px", "marginTop":"14px", "backgroundColor":"#EAF3ED", "border":"1px solid " + THEME["green"], "color":THEME["green"]}}>Merge confirmed. The route plan is updated.</div> }}
              {if chosen { <p style={{"fontSize":"14px", "color":THEME["muted"]}}>North Field selected. Confirm the merge to apply the simulated route change.</p> }}
            </section>
            <section style={{"border":"1px solid " + THEME["border"], "backgroundColor":THEME["panel"], "padding":"18px 20px"}}><h2 style={{"margin":"0 0 12px", "fontSize":"20px"}}>Fleet activity</h2><div style={{"display":"flex", "justifyContent":"space-between", "padding":"10px 0", "borderBottom":"1px solid " + THEME["border"]}}><span>Truck 1 · North route</span><strong style={{"color":THEME["blue"]}}>On route</strong></div><div style={{"display":"flex", "justifyContent":"space-between", "padding":"10px 0", "borderBottom":"1px solid " + THEME["border"]}}><span>Truck 2 · East route</span><strong style={{"color":THEME["ochre"]}}>Loading</strong></div><div style={{"display":"flex", "justifyContent":"space-between", "padding":"10px 0"}}><span>Truck 3 · South route</span><strong style={{"color":THEME["plum"]}}>Scheduled</strong></div></section>
          </aside>
        </div>
      </main>
      <footer style={{"padding":"16px 28px", "textAlign":"center", "fontSize":"14px", "color":THEME["muted"], "borderTop":"1px solid " + THEME["border"]}}>All data simulated</footer>
    </div>;
}
