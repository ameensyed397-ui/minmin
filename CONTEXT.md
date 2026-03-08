# MIN MIN — Agent Collaboration Context

> This file is the single source of truth for any AI agent (or human) picking up this project.
> Keep it updated whenever you make significant changes.

---

## What Is MIN MIN

An **offline-first mobile AI coding assistant**. As of v2.0, it is a fully standalone Android app — no PC backend required. On-device AI inference is powered by `flutter_gemma` (MediaPipe LLM Inference API) running a Gemma 2B-IT model the user downloads once (~1.5 GB `.task` file). The Python/FastAPI backend still exists for power users who want full multi-agent agentic features, but the mobile app no longer connects to it.

---

## Repository Layout

```
minmin/
├── main.py                     # FastAPI entry point — port 8787
├── requirements.txt            # Python deps (uvicorn, fastapi, faiss, sentence-transformers, tree-sitter)
├── CONTEXT.md                  # ← this file
├── README.md
│
├── ai_engine/
│   ├── agent_controller.py     # Orchestrates all agents; SQLite logging
│   ├── planner_agent.py        # Calls GLM-4.7 via Ollama → numbered plan list
│   ├── coding_agent.py         # Calls Qwen3-Coder → parses TOOL_CALL blocks → dispatches tools
│   ├── summarizer_agent.py     # Calls MiniMax M2.1 → repo summary ≤ 250 words
│   └── tool_router.py          # Maps tool names → handler functions
│
├── tools/
│   ├── file_tools.py           # read_file, write_file, create_file, delete_file, list_files, search_code
│   ├── terminal_tools.py       # run_terminal — whitelist-gated subprocess
│   ├── git_tools.py            # git_commit, git_create_branch
│   └── repo_tools.py           # list_project_files (skips .git, build, __pycache__, etc.)
│
├── indexer/
│   ├── repo_indexer.py         # Walks repo → extracts symbols → stores embeddings
│   ├── embedding_generator.py  # sentence-transformers all-MiniLM-L6-v2 (SHA-256 fallback)
│   └── vector_store.py         # FAISS index + metadata.json (per-project in .minmin_index/)
│
├── models/
│   └── ollama_client.py        # POST /api/generate to Ollama; 180 s timeout; graceful failure
│
├── storage/
│   ├── schema.sql              # memory_entries(id, created_at, kind, payload_json)
│   └── memory.db               # SQLite auto-created on first run
│
├── scripts/
│   ├── setup.sh                # Linux/macOS: venv + pip + flutter pub get
│   └── setup.ps1               # Windows: same via PowerShell
│
└── mobile_app/                 # Flutter app (v2.0 — fully standalone)
    ├── pubspec.yaml            # see "Flutter App (v2.0)" section for full dep list
    ├── android/
    │   ├── app/build.gradle    # minSdk=24; packagingOptions pickFirst libOpenCL.so
    │   ├── app/proguard-rules.pro  # MediaPipe + Play Core dontwarn rules
    │   └── gradle.properties   # kotlin.incremental=false (cross-drive build fix)
    ├── lib/
    │   ├── main.dart           # Dark theme, AiService provider, routes SetupScreen↔ChatScreen
    │   ├── setup_screen.dart   # NEW: first-run model picker (file_picker → AiService.loadModel)
    │   ├── ai_service.dart     # flutter_gemma wrapper; ModelStatus enum; ChatMessage class
    │   ├── chat_screen.dart    # ChatGPT-style dark UI, streaming tokens, file attach, drawer
    │   ├── project_manager.dart# dart:io local file scanning; file_picker folder selection
    │   ├── code_viewer.dart    # Syntax-highlighted viewer (flutter_highlight) + dark/light toggle
    │   ├── file_browser.dart   # Scrollable file list (kept, used as fallback widget)
    │   ├── memory_manager.dart # ChangeNotifier for chat entries (kept but unused in v2)
    │   └── terminal_panel.dart # Command I/O display (kept but not wired in v2 ChatScreen)
    └── build/app/outputs/flutter-apk/
        ├── app-arm64-v8a-release.apk   (26.6 MB) ← INSTALL THIS on modern Android (64-bit ARM)
        └── app-armeabi-v7a-release.apk (15.9 MB) ← 32-bit ARM fallback
```

---

## Flutter App (v2.0) — Standalone On-Device AI

### pubspec.yaml dependencies
| Package | Version |
|---|---|
| provider | ^6.1.2 |
| http | ^1.2.2 (kept, unused for now) |
| flutter_gemma | ^0.2.1 (resolved 0.2.4) |
| file_picker | ^8.1.2 |
| shared_preferences | ^2.3.2 |
| path_provider | ^2.1.4 |
| url_launcher | ^6.3.0 |
| flutter_highlight | ^0.7.0 |
| highlight | ^0.7.0 |

### flutter_gemma 0.2.4 API (IMPORTANT for future agents)
- **Init / load:** `FlutterGemmaPlugin.instance.init(modelPath: path, maxTokens: 1024, temperature: 0.8, topK: 40, randomSeed: 42)`
  - This loads the model AND initialises the inference engine in one call.
  - There is NO separate `loadAssetModel` method in 0.2.x.
- **Inference:** `FlutterGemmaPlugin.instance.getResponseAsync(prompt: text)` → returns `Stream<String?>` (token strings are nullable).
- **Gemma prompt format:** `<start_of_turn>user\n{msg}<end_of_turn>\n<start_of_turn>model\n`

### First-run flow
1. `SetupScreen` shown on fresh install (no saved model path in SharedPreferences).
2. User taps **Select Model File** → `file_picker` opens → user picks the `.task` file (~1.5 GB Gemma 2B-IT).
3. `AiService.loadModel(path)` calls `FlutterGemmaPlugin.instance.init(...)`.
4. On success, path saved to SharedPreferences → app navigates to `ChatScreen` (and will go there directly on all future launches).

### Android configuration
- `minSdk = 24` (MediaPipe LLM Inference API requirement)
- `packagingOptions { pickFirst("**/libOpenCL.so") }` in `app/build.gradle`
- ProGuard rules in `android/app/proguard-rules.pro` (MediaPipe + Play Core `dontwarn` entries)
- `kotlin.incremental=false` in `android/gradle.properties` — fixes Kotlin incremental compilation crash caused by cross-drive paths (project on D:, Kotlin cache on C:)

### What was removed from v1
- All HTTP calls to the FastAPI backend
- Backend URL configuration field
- Terminal tab / `TerminalPanel` wired in ChatScreen
- `memory_manager.dart` usage from ChatScreen (file kept but not used)

---

## Agent / Model Config (Backend — unchanged)

| Agent | Model | Endpoint |
|---|---|---|
| Planner | `glm4.7` | `POST /api/chat/plan` |
| Coder | `qwen3-coder` | `POST /api/chat/execute` |
| Summariser | `minimax-m2:latest` | Used internally in load/plan |

All models are **configurable** — change the `model=` kwarg in the constructor or pass a custom one.
Ollama base URL defaults to `http://127.0.0.1:11434`; override via env var `OLLAMA_BASE_URL`.

---

## Backend API Surface (unchanged, for power users)

```
GET  /health                    → {"status": "ok"}
POST /api/projects/load         → {project_path, summary, files[], index{}}
POST /api/chat/plan             → {project_path, prompt, plan[], summary}
POST /api/chat/execute          → {project_path, prompt, approved_plan, result{raw_response, tool_results[]}}
POST /api/terminal/run          → {status, stdout, stderr, returncode}
GET  /api/files?project_path=   → {project_path, files[]}
POST /api/files/read            → {path, content}
```

---

## Tool Call Protocol (Coder Agent)

The coding agent emits free-text with embedded tool calls in this format:

```
TOOL_CALL
tool_name
{
  "arg": "value"
}
```

Valid tools: `read_file`, `write_file`, `create_file`, `delete_file`, `list_files`,
`search_code`, `run_terminal`, `git_commit`, `git_create_branch`, `index_repository`

`write_file` requires `require_approval: false` to actually write (the planner approval flow sets this automatically).

---

## Flutter App v2.0 — User Flow

1. On first launch: **SetupScreen** — user taps "Select Model File" and picks the `.task` file from local storage (downloaded once from HuggingFace; `url_launcher` opens the HuggingFace page).
2. Model loads on-device via MediaPipe → app transitions to **ChatScreen** (persisted via SharedPreferences on all future launches).
3. User types a prompt → response streams token-by-token from `getResponseAsync`.
4. User can attach a local file (via `file_picker`) to include its content in the prompt context.
5. Project folder can be selected to browse local files in the drawer.

---

## Running the Backend (power users only)

```bash
# Windows
cd d:/projects/minmin
.venv\Scripts\activate           # or run scripts/setup.ps1 first
uvicorn main:app --reload --host 0.0.0.0 --port 8787
```

```bash
# Linux / macOS
cd /path/to/minmin
source .venv/bin/activate
uvicorn main:app --reload --host 0.0.0.0 --port 8787
```

The v2.0 mobile app does NOT connect to this backend. It is available for users who want the full multi-agent agentic pipeline (planner → coder → tools).

---

## Installing the APK

```bash
# Via adb (phone connected by USB with USB debugging on)
adb install mobile_app/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk

# Or just copy the APK to the phone and open it (allow unknown sources in settings)
```

---

## Known Limitations / Next Steps

- [ ] **Streaming** — all model calls are blocking HTTP. Long responses time out. Add SSE streaming.
- [ ] **Memory browser UI** — backend logs everything to SQLite but there is no Flutter screen to browse it.
- [ ] **Git tools UI** — `git_commit` / `git_create_branch` exist in backend, not wired in the app.
- [ ] **Multi-project tabs** — `ProjectManager` holds one project at a time.
- [ ] **Approval flow** — `write_file` with `require_approval: true` returns a preview; the app doesn't yet show a diff/approval dialog before the coder writes.
- [ ] **Dark mode** — app is light-only (CodeViewer has its own dark/light toggle).
- [ ] **Auth** — no API key / auth between app and backend (LAN-only is assumed).

---

## Environment Snapshot (last updated 2026-03-08)

| Tool | Version |
|---|---|
| Flutter | 3.41.4 stable |
| Dart | 3.11.1 |
| Python | 3.11+ |
| FastAPI | 0.116.1 |
| Ollama | latest |
| Target Android | API 21+ (arm64-v8a recommended) |
