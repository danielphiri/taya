# Taya Memory Capture

An iOS app that turns messy, unstructured voice moments into structured memory cards.

Core loop:
User taps record → speaks → taps stop → transcript is structured via OpenAI → memory card is saved → user can immediately record again.

This app is designed to feel instant and trustworthy. If a user ever wonders "did it save?", we've failed.

---

## Demo Summary

• On-device transcription using `SFSpeechRecognizer`  
• Structured LLM processing via OpenAI  
• SwiftUI memory cards persisted across launches  
• Back-to-back recordings supported with zero state bleed  
• No UI blocking during LLM processing  

---

# Architecture Overview

## High-Level Flow

Idle  
→ Recording  
→ Transcribing  
→ Processing (LLM in-flight)  
→ Persisting  
→ Card Saved  

The critical requirement is that **new recordings can begin while previous LLM calls are still running**.

This is solved using:
- A dedicated `CapturePipelineActor`
- Structured concurrency (`Task`, `async/await`)
- Explicit capture IDs
- Fire-and-forget processing tasks that never block UI state

---

# System Design

## 1. Voice Capture

- `AVAudioEngine` for recording
- `SFSpeechRecognizer` for on-device transcription
- Visual feedback via pulsing SwiftUI record orb
- Simulator fallback: hardcoded transcript (clearly marked)

Transcription produces a raw `String`.

---

## 2. LLM Processing (OpenAI)

Transcript is sent to OpenAI with a strict system prompt requiring JSON output:

```json
{
  "title": "short, specific summary",
  "category": "Shopping | Learning | Meeting | People | Other",
  "action_items": ["array", "of", "tasks"],
  "mood": "sentiment string"
}
