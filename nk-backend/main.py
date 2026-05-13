import os
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from anthropic import Anthropic

# --- App Setup ---
app = FastAPI(title="NK-Abrechnung Backend")

# API-Key kommt aus Umgebungsvariable — NIE hardcoden
client = Anthropic(api_key=os.getenv("ANTHROPIC_API_KEY"))

# --- Request Model ---
class AnalyzeRequest(BaseModel):
    text: str

# --- Routes ---
@app.get("/")
async def root():
    return {"status": "running", "message": "NK-Abrechnung Backend läuft."}

@app.post("/analyze")
async def analyze(request: AnalyzeRequest):
    try:
        message = client.messages.create(
            model="claude-haiku-4-5-20251001",
            max_tokens=1024,
            messages=[
                {
                    "role": "user",
                    "content": request.text
                }
            ]
        )
        return {
            "result": message.content[0].text,
            "model": message.model,
            "usage": {
                "input_tokens": message.usage.input_tokens,
                "output_tokens": message.usage.output_tokens
            }
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
