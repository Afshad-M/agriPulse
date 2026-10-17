"""agriPulse - Plan summary card (owner: B). Skeleton only - no logic yet."""

def:pub PlanCard(status: str, createdAt: str) -> JsxElement {
    <div
        style={{
            "padding": "0.75rem 1rem",
            "marginBottom": "0.5rem",
            "backgroundColor": "#f1f8f4",
            "border": "1px solid #d7ead9",
            "borderRadius": "8px"
        }}
    >
        {#* TODO(B): flesh out the plan summary layout *#}
        <strong>{status}</strong>
        <p style={{"margin": "0.25rem 0 0", "color": "#555"}}>{createdAt}</p>
    </div>
}
