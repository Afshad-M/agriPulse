"""agriPulse - LLM-Delegated Functions (owner: C).

by llm() only, for exactly these four functions: parse_harvest, prioritize,
farmer_message, explain. The LLM never computes domain numbers (distances,
scores, capacities) - see CLAUDE.md. `prioritize`'s output is validated in
code (logic.jac / api.jac), not trusted blindly.
"""

import from jaclang.byllm.lib { Model }

glob llm: Model = Model(model_name="gpt-4o-mini");

obj HarvestDraft {
    has crop: str,
        quantity_kg: float,
        notes: str = "";
}
sem HarvestDraft.crop = "The crop name mentioned in the message.";
sem HarvestDraft.quantity_kg = "Estimated harvest quantity in kilograms.";
sem HarvestDraft.notes = "Any extra context from the farmer's message.";

def parse_harvest(message: str) -> HarvestDraft by llm();
sem parse_harvest = "Parse a farmer's free-text harvest report into structured fields.";
sem parse_harvest.message = "Raw text message from the farmer describing their harvest.";

def prioritize(candidates: list[str]) -> list[str] by llm();
sem prioritize = "Rank candidate harvest/hub pairings by qualitative urgency, most urgent first. Caller validates the result in code - this never replaces deterministic scoring.";
sem prioritize.candidates = "Candidate descriptions to rank.";

def farmer_message(plan_summary: str) -> str by llm();
sem farmer_message = "Draft a short, friendly status message to a farmer about their delivery plan.";
sem farmer_message.plan_summary = "A short deterministic summary of the farmer's plan.";

def explain(plan_summary: str) -> str by llm();
sem explain = "Explain, in plain language, why a plan was chosen.";
sem explain.plan_summary = "A short deterministic summary of the plan or decision.";
