# MIN MIN

MIN MIN is an offline-first mobile AI coding assistant inspired by terminal coding agents. It combines a Flutter client with a local Python runtime that orchestrates multiple Ollama-backed agents for planning, coding, summarization, repository indexing, and memory.

## Architecture

- `mobile_app/`: Flutter UI for Android, iOS, and tablets
- `ai_engine/`: multi-agent orchestration and API layer
- `tools/`: controlled file, terminal, repository, and git tools
- `indexer/`: repository scanning, metadata extraction, embeddings, and FAISS storage
- `models/`: Ollama client
- `storage/`: SQLite memory database

## Agent Roles

- `GLM-4.7`: planner and validator
- `Qwen3-Coder`: implementation and debugging
- `MiniMax M2.1`: summarization, documentation, and long-context compression

All model names are configurable at runtime. The default implementation expects an Ollama-compatible API.

## Features

- Repository indexing with metadata extraction and embeddings
- Plan-first workflow with explicit approval before edits
- Controlled tool execution for files, terminal, git, and indexing
- Persistent SQLite memory for prompts, plans, decisions, and changes
- Responsive Flutter workspace with chat, files, code preview, and terminal
- Offline-first architecture designed around local inference endpoints

## Backend Setup

1. Create a Python 3.11+ virtual environment.
2. Install dependencies:

```bash
pip install -r requirements.txt
```

3. Start Ollama and make sure the required models are available:

```bash
ollama pull qwen3-coder
ollama pull glm4.7
ollama pull minimax-m2:latest
```

4. Start the backend:

```bash
uvicorn main:app --reload --host 127.0.0.1 --port 8787
```

## Flutter Setup

### Prerequisites

Install Flutter stable from https://docs.flutter.dev/get-started/install

### First-time platform scaffold

The `mobile_app/` directory contains only the Dart source. Before building you must generate the Android and iOS platform directories once:

```bash
cd mobile_app
flutter create --org com.minmin --project-name minmin .
```

This creates `android/` and `ios/` without touching existing Dart files.

### Install packages and run

```bash
flutter pub get
flutter run
```

The app defaults to `http://127.0.0.1:8787` for the backend. On a physical device, update the Backend URL field in the app to your host machine's LAN IP (e.g. `http://192.168.1.x:8787`).

## Security Model

- File edits are staged as proposed actions and require approval.
- Terminal commands run through a whitelist-based sandbox.
- Git actions are explicit tool calls.

## Build Outputs

Android APK:

```bash
flutter build apk --release
```

iOS app archive (requires macOS + Xcode):

```bash
flutter build ipa
```

Prebuilt APK/IPA files are not committed because they depend on local Flutter, Android SDK, and Apple signing toolchains.
