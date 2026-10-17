"""agriPulse - Entry Point.

Combines server-side endpoints with the client-side UI.
"""

import from endpoints { Message, PostMessage, ListMessages }

# New domain contract (owner: A) - skeleton endpoints, not yet wired into the
# UI. Imported here only so they register as live endpoints at /function/*.
import from api { load_seed, baseline_plan, merge_routes, replan_on_event }

# Client-side UI

import from .frontend { app as ClientApp }

def:pub app -> JsxElement {
    <ClientApp/>
}
