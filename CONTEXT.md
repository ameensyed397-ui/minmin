# MIN MIN — Agent Collaboration Context

> This file is the single source of truth for any AI agent (or human) picking up this project.
> Keep it updated whenever you make significant changes.

---

## What Is MIN MIN

An **offline-first mobile AI coding assistant**. A Flutter Android app talks to a local Python/FastAPI backend that orchestrates three Ollama-backed agents (planner, coder, summariser) over a codebase on the same machine.

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
└── mobile_app/                 # Flutter app
    ├── pubspec.yaml            # provider, http, flutter_highlight, highlight; dev: flutter_test, flutter_lints
    ├── lib/
    │   ├── main.dart           # MaterialApp → MultiProvider(ProjectManager, MemoryManager) → ChatScreen
    │   ├── chat_screen.dart    # Main screen: project bar, chat, file browser, code viewer, terminal
    │   ├── ai_service.dart     # HTTP calls to backend (ping, loadProject, createPlan, executePlan, …)
    │   ├── code_viewer.dart    # Syntax-highlighted viewer (flutter_highlight) + dark/light toggle
    │   ├── file_browser.dart   # Scrollable list of project files; tap → opens in CodeViewer
    │   ├── terminal_panel.dart # Command input + output display
    │   ├── project_manager.dart# ChangeNotifier: backendUrl, projectPath, summary, files
    │   └── memory_manager.dart # ChangeNotifier: chat entries (role + message)
    └── build/app/outputs/flutter-apk/
        ├── app-arm64-v8a-release.apk   ← INSTALL THIS on modern Android (64-bit ARM)
        ├── app-armeabi-v7a-release.apk ← 32-bit ARM fallback
        └── app-x86_64-release.apk      ← emulators / x86 tablets
```

---

## Agent / Model Config

| Agent | Model | Endpoint |
|---|---|---|
| Planner | `glm4.7` | `POST /api/chat/plan` |
| Coder | `qwen3-coder` | `POST /api/chat/execute` |
| Summariser | `minimax-m2:latest` | Used internally in load/plan |

All models are **configurable** — change the `model=` kwarg in the constructor or pass a custom one.
Ollama base URL defaults to `http://127.0.0.1:11434`; override via env var `OLLAMA_BASE_URL`.

---

## Backend API Surface

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

## Flutter App Flow

1. User sets **Backend URL** (e.g. `http://192.168.1.x:8787`) and taps the wifi icon to ping.
2. User enters **Project path** (absolute path on the PC running the backend) and taps **Load**.
3. Backend indexes the repo, summariser writes a summary → shown in the prompt card.
4. User types a **Prompt** → taps **Plan** → backend calls planner agent → plan shown.
5. User reviews plan → taps **Approve & Run** → coder agent executes plan using tools.
6. Results and tool outputs appear in the chat. Files changed on the backend machine.

---

## Running the Backend

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

Use `--host 0.0.0.0` so your phone (on same LAN) can reach it.

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
