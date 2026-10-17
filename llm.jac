"""agriPulse - LLM-Delegated Functions (owner: C).

by llm() only, for exactly these four functions: parse_harvest, prioritize,
farmer_message, explain. The LLM never computes domain numbers (distances,
scores, capacities) - see CLAUDE.md.

Every public function here wraps its `by llm()` call and never lets a model
failure reach the caller as an exception: on any error (auth, rate limit,
timeout, malformed output) it returns a clearly labelled fallback instead,
per CLAUDE.md. `prioritize`'s output is additionally validated in code - if
the model drops or invents an option, the fallback (original order) is used
rather than trusting the model blindly.
"""

import from jaclang.byllm.lib { Model }

glob llm: Model = Model(model_name="gpt-4o-mini");

# ---------------------------------------------------------------------------
# parse_harvest: messy free text -> structured HarvestDraft.
# ---------------------------------------------------------------------------

obj HarvestDraft {
    has crop: str,
        quantity_kg: float,
        notes: str = "",
        is_fallback: bool = False;
}
sem HarvestDraft.crop = "The crop name mentioned in the message.";
sem HarvestDraft.quantity_kg = "Estimated harvest quantity in kilograms.";
sem HarvestDraft.notes = "Any extra context from the farmer's message.";

def _parse_harvest_llm(message: str) -> HarvestDraft by llm();
sem _parse_harvest_llm = "Parse a farmer's free-text harvest report into structured fields.";
sem _parse_harvest_llm.message = "Raw text message from the farmer describing their harvest.";

def parse_harvest(message: str) -> HarvestDraft {
    try {
        return _parse_harvest_llm(message);
    } except Exception {
        return HarvestDraft(
            crop="unknown",
            quantity_kg=0.0,
            notes="[fallback] could not parse message: " + message,
            is_fallback=True
        );
    }
}


# ---------------------------------------------------------------------------
# prioritize: rank candidates by qualitative urgency. Code validates the
# result is a reordering of the given candidates before trusting it.
# ---------------------------------------------------------------------------

def _prioritize_llm(candidates: list[str]) -> list[str] by llm();
sem _prioritize_llm = "Rank candidate harvest/hub pairings by qualitative urgency, most urgent first. Caller validates the result in code - this never replaces deterministic scoring.";
sem _prioritize_llm.candidates = "Candidate descriptions to rank.";

def prioritize(candidates: list[str]) -> list[str] {
    if len(candidates) == 0 {
        return [];
    }
    try {
        ranked = _prioritize_llm(candidates);
        if sorted(ranked) == sorted(candidates) {
            return ranked;
        }
        # Model dropped, duplicated or invented an option - don't trust it.
        return candidates;
    } except Exception {
        return candidates;
    }
}


# ---------------------------------------------------------------------------
# farmer_message: per-farmer notification of what changed, in en/si/ta.
# ---------------------------------------------------------------------------

# Per-language fallbacks so a model failure never drops a non-English
# farmer back to English. Machine-drafted (Sinhala/Tamil) - please have a
# native speaker on the team sanity-check these before the demo; if they
# need a fix, edit here only (never silently swap in English).
glob FARMER_MESSAGE_FALLBACK_EN: str = "[fallback] Your delivery plan has been updated due to a change in the network. A team member will confirm pickup details shortly.";
glob FARMER_MESSAGE_FALLBACK_SI: str = "[fallback] ජාල වෙනසක් නිසා ඔබේ බෙදාහැරීමේ සැලැස්ම යාවත්කාලීන කර ඇත. කණ්ඩායම් සාමාජිකයෙක් ඉක්මනින් එකතු කිරීමේ විස්තර තහවුරු කරනු ඇත.";
glob FARMER_MESSAGE_FALLBACK_TA: str = "[fallback] பிணையத்தில் ஏற்பட்ட மாற்றம் காரணமாக உங்கள் டெலிவரி திட்டம் புதுப்பிக்கப்பட்டுள்ளது. குழு உறுப்பினர் விரைவில் சேகரிப்பு விவரங்களை உறுதிப்படுத்துவார்.";

# Back-compat alias - existing callers / the earlier smoke test referenced
# this single-language constant. Keep pointing at the English fallback.
glob FARMER_MESSAGE_FALLBACK: str = FARMER_MESSAGE_FALLBACK_EN;

glob FARMER_MESSAGE_FALLBACKS: dict[str, str] = {
    "en": FARMER_MESSAGE_FALLBACK_EN,
    "si": FARMER_MESSAGE_FALLBACK_SI,
    "ta": FARMER_MESSAGE_FALLBACK_TA
};

def _farmer_message_llm(plan_summary: str, language: str) -> str by llm();
sem _farmer_message_llm = "Draft a short (2-3 sentence) status message to a farmer about their delivery plan, written natively in the given language - not a literal translation from English. Use a warm, respectful, plain-spoken tone appropriate for addressing a smallholder farmer directly (not formal officialese). Mention concretely what changed and the new expected timing.";
sem _farmer_message_llm.plan_summary = "A short deterministic summary of the farmer's plan.";
sem _farmer_message_llm.language = "Target language code: 'en' for English, 'si' for Sinhala, 'ta' for Tamil. Write entirely in that language (script included for si/ta), not transliterated.";

def farmer_message(plan_summary: str, language: str = "en") -> str {
    fallback = FARMER_MESSAGE_FALLBACKS[language] if language in FARMER_MESSAGE_FALLBACKS else FARMER_MESSAGE_FALLBACK_EN;
    try {
        return _farmer_message_llm(plan_summary, language);
    } except Exception {
        return fallback;
    }
}


# ---------------------------------------------------------------------------
# explain: one-paragraph "why I did this" for the UI.
# ---------------------------------------------------------------------------

glob EXPLAIN_FALLBACK: str = "[fallback] The agent updated the plan in response to a network change, selecting the option with the best score among the available alternatives.";

def _explain_llm(plan_summary: str) -> str by llm();
sem _explain_llm = "Explain, in plain language for a judge/observer, why a plan was chosen: what changed, what alternatives existed, and why this one scored best.";
sem _explain_llm.plan_summary = "A short deterministic summary of the plan or decision.";

def explain(plan_summary: str) -> str {
    try {
        return _explain_llm(plan_summary);
    } except Exception {
        return EXPLAIN_FALLBACK;
    }
}
