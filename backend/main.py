import os
import re
import json
from contextlib import asynccontextmanager
from dotenv import load_dotenv
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Dict, Any, Optional
from groq import Groq

load_dotenv()

client = Groq(api_key=os.getenv("GROQ_API_KEY"))
MODEL = "llama-3.1-8b-instant"

_retriever = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    global _retriever
    try:
        from knowledge_base.retriever import MentalHealthRetriever
        from knowledge_base.documents import DOCUMENTS
        _retriever = MentalHealthRetriever(DOCUMENTS)
        print(f"[RAG] Knowledge base loaded: {len(DOCUMENTS)} documents")
    except Exception as e:
        print(f"[RAG] WARNING: Could not load knowledge base: {e}")
        _retriever = None
    yield


app = FastAPI(lifespan=lifespan)
app.add_middleware(
    CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"]
)


def chat(messages: list, temperature: float = 0.7) -> str:
    resp = client.chat.completions.create(
        model=MODEL, messages=messages, temperature=temperature
    )
    return resp.choices[0].message.content.strip()


def _retrieve_crisis_criteria(patient_message: str) -> str:
    if _retriever is None:
        return ""
    crisis_docs = [d for d in _retriever._docs if d["domain"] == "Crisis"]
    if not crisis_docs:
        return ""
    from rank_bm25 import BM25Okapi
    bm25 = BM25Okapi([d["text"].lower().split() for d in crisis_docs])
    scores = bm25.get_scores(patient_message.lower().split())
    ranked = sorted(zip(scores, crisis_docs), key=lambda x: x[0], reverse=True)
    top = [doc for _, doc in ranked[:3]] or crisis_docs[:3]
    return "\n\n".join(f"[{d['title']}]\n{d['text']}" for d in top)


def _build_rag_section(patient_message: str, flags: List[str]) -> str:
    if _retriever is None:
        return ""
    chunks = _retriever.retrieve(query=patient_message, dsm5_flags=flags, top_k=2)
    if not chunks:
        return ""
    chunk_texts = "\n\n".join(
        f"[{i + 1}] {c['title']}: {c['text']}" for i, c in enumerate(chunks)
    )
    return (
        "\n\n---\nRELEVANT THERAPEUTIC TECHNIQUES:\n"
        "The following evidence-based techniques are relevant to what the patient said. "
        "Weave one of them naturally into your response as a concrete suggestion. "
        "Do not quote verbatim or reference by number. Do not list all of them — choose the most fitting one.\n\n"
        + chunk_texts
        + "\n---"
    )


# ── Health ────────────────────────────────────────────────────────────────────

@app.get("/health")
def health():
    return {"status": "ok"}


# ── Chat ──────────────────────────────────────────────────────────────────────

class ChatRequest(BaseModel):
    patientMessage: str
    conversationHistory: List[Dict[str, str]] = []
    messageCount: int = 0
    patientContext: Dict[str, Any] = {}
    sessionId: str = ""


@app.post("/chat")
def chat_endpoint(req: ChatRequest):
    try:
        flags = req.patientContext.get("dsm5Flags", [])
        language = req.patientContext.get("language", "English")
        flag_text = ", ".join(flags) if flags else "general wellbeing"

        rag_section = _build_rag_section(req.patientMessage, flags)

        mc = req.messageCount
        if mc <= 3:
            phase_guidance = (
                "PHASE — LISTENING: Your only job right now is to understand.\n"
                "- If this is message 0 or 1, greet them warmly and ask what's on their mind today.\n"
                "- Ask 1–2 open, curious questions. Do NOT suggest techniques yet — jumping to solutions too early feels dismissive.\n"
                "- Examples: 'Can you tell me more about what's been happening?' / 'When did this start for you?' / 'What does a typical day feel like right now?'\n"
                "- Respond like a caring friend: 2–3 sentences, conversational, no clinical structure."
            )
        elif mc <= 9:
            phase_guidance = (
                "PHASE — SUPPORT: You know the patient's situation now. Continue the conversation naturally.\n"
                "- If the moment is right, gently offer ONE small suggestion — frame it as a friend sharing an idea, not a clinical prescription.\n"
                "- Keep asking follow-up questions. Show you remember what they said earlier in the conversation.\n"
                "- Vary your responses: sometimes just validate, sometimes ask, sometimes gently suggest. Never rigidly do all three every time.\n"
                "- 2–4 sentences. No rigid structure. Sound human, not like a helpdesk bot."
            )
        else:
            phase_guidance = (
                "PHASE — TRANSITION: You've built real rapport over this conversation. It's time to naturally encourage professional support.\n"
                "- Make the therapist suggestion personal and specific — reference something the patient actually shared with you.\n"
                "  Good: 'Given what you told me about [X], I really think your therapist could help you work through that specifically.'\n"
                "  Bad: 'You should see a therapist.' (too generic, feels like a dismissal)\n"
                "- You can still respond to their message and continue talking — the therapist suggestion is woven naturally into your reply, not a closing statement.\n"
                "- Frame it as a caring next step you genuinely recommend, not as ending the conversation."
            )

        system = (
            f"You are a warm, empathetic support companion for PsyCare. "
            f"Think of yourself as a caring friend who genuinely understands mental health — not a clinical chatbot.\n"
            f"The patient's main areas of concern: {flag_text}.\n"
            f"Always respond in {language}.\n\n"
            f"{phase_guidance}\n\n"
            f"NON-NEGOTIABLE RULES (apply in every phase):\n"
            f"- NEVER diagnose or label any condition. If the patient describes symptoms, acknowledge their feelings "
            f"and encourage them to discuss it with their therapist — never name a disorder.\n"
            f"- If they say 'nothing works' or express hopelessness, validate deeply first, then offer one very small, specific action.\n"
            f"- Responses must feel personal and responsive — not generic. Reference what they actually just said.\n"
            f"- You are a support tool, not a replacement for professional care."
            + rag_section
        )

        messages = [{"role": "system", "content": system}]
        for m in req.conversationHistory[-10:]:
            messages.append(
                {"role": m.get("role", "user"), "content": m.get("content", "")}
            )
        messages.append({"role": "user", "content": req.patientMessage})

        return {"response": chat(messages)}
    except Exception as e:
        return {"error": "groq_unavailable", "detail": str(e)}


# ── Red flag ──────────────────────────────────────────────────────────────────

class RedFlagRequest(BaseModel):
    patientMessage: str
    conversationHistory: List[Dict[str, str]] = []
    sessionId: str = ""


@app.post("/red-flag")
def red_flag(req: RedFlagRequest):
    try:
        criteria = _retrieve_crisis_criteria(req.patientMessage)
        criteria_section = (
            f"\n\nCLINICAL CRITERIA (evidence-based — use these to assess risk):\n{criteria}"
            if criteria else ""
        )
        system = (
            "You are a clinical crisis detection assistant for a mental health app. "
            "Your job is to determine if a patient message indicates HIGH-RISK self-harm or suicidal crisis "
            "requiring immediate therapist notification.\n\n"
            "SEVERITY DEFINITIONS:\n"
            "  critical — expressed INTENT to self-harm/suicide WITH a specific plan or imminent time frame, "
            "OR confirmed access to means right now, OR explicit farewell statements.\n"
            "  high — expressed INTENT to self-harm or active suicidal ideation WITHOUT a specific plan "
            "or confirmed means.\n"
            "  none — everything else: general distress, hopelessness, sadness, anger, passive ideation "
            "('I wish I weren't here'), frustration, or venting WITHOUT expressed intent to act.\n\n"
            "IMPORTANT: Do NOT flag general distress or dark feelings as high/critical. "
            "The bar is expressed INTENT to harm, not emotional pain alone. "
            "When intent is ambiguous, default to 'none'."
            + criteria_section
            + "\n\nReply with ONLY valid JSON (no markdown, no explanation):\n"
            '{"isRedFlag": true/false, "severity": "none" | "high" | "critical"}\n'
            'isRedFlag must be true ONLY when severity is "high" or "critical".'
        )
        recent = req.conversationHistory[-4:] if req.conversationHistory else []
        context = "\n".join(
            [f"{m['role'].upper()}: {m['content']}" for m in recent]
        )
        user_content = (
            f"Recent context:\n{context}\n\nLatest message: {req.patientMessage}"
            if context
            else req.patientMessage
        )
        messages = [
            {"role": "system", "content": system},
            {"role": "user", "content": user_content},
        ]
        raw = chat(messages, temperature=0.1)
        match = re.search(r"\{.*\}", raw, re.DOTALL)
        result = json.loads(match.group()) if match else {"isRedFlag": False, "severity": "none"}
        # Normalise: only high/critical are valid alert severities
        if result.get("severity") not in ("high", "critical"):
            result["isRedFlag"] = False
            result["severity"] = "none"
        return result
    except Exception:
        return {"isRedFlag": False, "severity": "none", "serviceError": True}



# ── Patient summary ───────────────────────────────────────────────────────────

class PatientSummaryRequest(BaseModel):
    assessmentText: str = ""
    description: str = ""


@app.post("/patient-summary")
def patient_summary(req: PatientSummaryRequest):
    try:
        messages = [
            {
                "role": "system",
                "content": (
                    "You are a clinical assistant writing for a therapist. "
                    "Write a concise 3-4 sentence summary of a patient based on their assessment and self-description. "
                    "Be professional and empathetic. Do not diagnose — describe patterns and areas of concern only."
                ),
            },
            {
                "role": "user",
                "content": (
                    f"Assessment results: {req.assessmentText}\n"
                    f"Patient self-description: {req.description}"
                ),
            },
        ]
        return {"summary": chat(messages, temperature=0.4)}
    except Exception as e:
        return {"error": str(e)}


# ── Emotional support ─────────────────────────────────────────────────────────

class EmotionalSupportRequest(BaseModel):
    type: str
    patientText: str = ""
    firstMessage: Optional[str] = None
    secondMessage: Optional[str] = None
    method: Optional[str] = None


@app.post("/emotional-support")
def emotional_support(req: EmotionalSupportRequest):
    try:
        if req.type == "welcome":
            prompt = (
                f"A patient wrote: '{req.patientText}'. "
                f"Write a warm, empathetic 2-sentence welcome that acknowledges their feelings "
                f"and invites them to share more."
            )
        elif req.type == "comfort":
            prompt = (
                f"A patient shared: '{req.firstMessage}' and then '{req.secondMessage}'. "
                f"Write a 2-3 sentence comforting response that validates their experience "
                f"and suggests one small concrete action."
            )
        elif req.type == "no_help":
            prompt = (
                f"A patient said they don't need help right now: '{req.patientText}'. "
                f"Write a kind 1-2 sentence closing that respects their choice and leaves the door open."
            )
        elif req.type == "struggling":
            prompt = (
                f"A patient said they are struggling: '{req.patientText}'. "
                f"Write a 2-3 sentence empathetic response acknowledging their struggle, "
                f"suggesting one small concrete step, and encouraging them to speak with their therapist."
            )
        elif req.type == "method_guidance":
            prompt = (
                f"A patient wants to try '{req.method}' for their concern: '{req.patientText}'. "
                f"Write a 2-3 sentence supportive response guiding them through this approach. "
                f"Remind them their therapist can provide deeper guidance."
            )
        else:
            prompt = f"Respond empathetically to: '{req.patientText}' and suggest one concrete action."

        messages = [
            {
                "role": "system",
                "content": (
                    "You are a compassionate mental health support assistant. "
                    "Keep responses warm and brief. "
                    "Always include at least one concrete, actionable suggestion. "
                    "Never diagnose."
                ),
            },
            {"role": "user", "content": prompt},
        ]
        return {"response": chat(messages)}
    except Exception as e:
        return {"error": str(e)}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
