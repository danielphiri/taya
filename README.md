# Taya

Taya is a small SwiftUI iOS app for capturing short voice memories and turning them into structured cards. A recording flows through live transcription, OpenAI processing, and local persistence so the user can come back to previous captures later.

## What the app does

- Records one voice capture at a time from the home screen.
- Shows live transcript and audio-level feedback while recording.
- Creates stateful memory cards that move through `recording`, `transcribing`, `processing`, `completed`, and `failed` states.
- Uses OpenAI to turn a transcript into a structured result with a title, category, action items, and mood.
- Persists cards locally to disk so they survive relaunches.
- Lets the user retry failed cards, delete cards, and open completed cards for more detail.

## Project structure

- `Taya/Taya/Views`: SwiftUI screens and reusable UI components.
- `Taya/Taya/Models`: App models such as `MemoryCard`, `CaptureState`, `LLMOutput`, and `MemoryCategory`.
- `Taya/Taya/Services/AudioCapture`: Live audio capture, permission handling, and audio capture protocols.
- `Taya/Taya/Services/LLM`: OpenAI integration, request building, response decoding, and LLM protocols.
- `Taya/Taya/Services/Networking`: Network client abstraction and URLSession-backed implementation.
- `Taya/Taya/Services/Persistence`: Disk-backed storage for memory cards.
- `Taya/TayaTests`: View model tests with mocks for audio capture, persistence, and LLM behavior.

## Setup

1. Open the project in Xcode.
2. Create or update `Taya/Config.xcconfig` with your OpenAI API key:

```xcconfig
OPENAI_API_KEY = your_openai_api_key_here
```

3. Make sure the app target is using that xcconfig so `OPENAI_API_KEY` is available in the app bundle.
4. Build and run on an iPhone or Simulator.
5. On first recording attempt, allow microphone and speech recognition permissions.

The app reads `OPENAI_API_KEY` from `Info.plist`, which resolves to the value supplied by `Config.xcconfig`.

## Running the app

Tap the record button to start capture, tap again to stop, then wait for the card to move from transcription into AI processing. Completed cards can be opened for details, and failed cards can be retried or dismissed.

## Testing

The project includes `HomeViewModel` tests that cover:

- back-to-back captures while earlier LLM work is still in flight
- cancelling active work
- deleting cards with pending processing
- retrying failed cards while other cards continue processing

## Areas for improvement

- Localize all user-facing copy instead of embedding strings directly in views and models.
- Split the app into clearer modules or packages, especially around UI, domain/workflow, persistence, and OpenAI integration.
- Move layout constants such as padding, spacing, and sizing into environment-backed design tokens or a shared styling system.
- Tighten dependency inversion further by moving composition out of `HomeViewModel` defaults; protocol boundaries are already present, but a dedicated composition root would reduce coupling to live implementations and singletons.
- Replace the checked-in config secret with a local, ignored config template or a more secure secret-loading approach.

## Short notes

- Production builds would benefit from stronger error reporting and analytics around permission denial, transcription failures, and LLM/network failures.
- A sample config file and a gitignored local config setup would make onboarding safer.
