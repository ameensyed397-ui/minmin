from pathlib import Path
from typing import Any

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

from ai_engine.agent_controller import AgentController


ROOT = Path(__file__).resolve().parent
app = FastAPI(title="Pocket Claude API", version="0.1.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
controller = AgentController(ROOT)


class ProjectLoadRequest(BaseModel):
    path: str


class PlanRequest(BaseModel):
    prompt: str = Field(min_length=1)
    project_path: str = Field(min_length=1)


class ExecuteRequest(BaseModel):
    prompt: str = Field(min_length=1)
    project_path: str = Field(min_length=1)
    approved_plan: list[str]


class CommandRequest(BaseModel):
    command: str = Field(min_length=1)
    project_path: str = Field(min_length=1)


class FileReadRequest(BaseModel):
    path: str = Field(min_length=1)


@app.get('/health')
def health() -> dict[str, str]:
    return {'status': 'ok'}


@app.post('/api/projects/load')
def load_project(request: ProjectLoadRequest) -> dict[str, Any]:
    return controller.load_project(request.path)


@app.post('/api/chat/plan')
def create_plan(request: PlanRequest) -> dict[str, Any]:
    return controller.create_plan(request.project_path, request.prompt)


@app.post('/api/chat/execute')
def execute_plan(request: ExecuteRequest) -> dict[str, Any]:
    return controller.execute_plan(
        project_path=request.project_path,
        prompt=request.prompt,
        approved_plan=request.approved_plan,
    )


@app.post('/api/terminal/run')
def run_command(request: CommandRequest) -> dict[str, Any]:
    return controller.run_terminal(request.project_path, request.command)


@app.get('/api/files')
def list_files(project_path: str) -> dict[str, Any]:
    return controller.list_files(project_path)


@app.post('/api/files/read')
def read_file(request: FileReadRequest) -> dict[str, Any]:
    target = Path(request.path).resolve()
    if not target.is_absolute():
        raise HTTPException(status_code=400, detail='Absolute path required.')
    try:
        return {'path': str(target), 'content': target.read_text(encoding='utf-8')}
    except FileNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except PermissionError as exc:
        raise HTTPException(status_code=403, detail=str(exc)) from exc
    except (IsADirectoryError, UnicodeDecodeError, OSError) as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
