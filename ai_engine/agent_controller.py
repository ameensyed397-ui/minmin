import json
import sqlite3
from pathlib import Path
from typing import Any

from ai_engine.coding_agent import CodingAgent
from ai_engine.planner_agent import PlannerAgent
from ai_engine.summarizer_agent import SummarizerAgent
from ai_engine.tool_router import ToolRouter
from indexer.repo_indexer import RepoIndexer
from models.ollama_client import OllamaClient
from tools.repo_tools import list_project_files


class AgentController:
    def __init__(self, root: Path) -> None:
        self.root = root
        self.db_path = root / 'storage' / 'memory.db'
        self.schema_path = root / 'storage' / 'schema.sql'
        self.client = OllamaClient()
        self.planner = PlannerAgent(self.client)
        self.summarizer = SummarizerAgent(self.client)
        self.tool_router = ToolRouter(root)
        self.coder = CodingAgent(self.client, self.tool_router)
        self.indexer = RepoIndexer(root / '.minmin_index')
        self._init_db()

    def _init_db(self) -> None:
        self.db_path.parent.mkdir(parents=True, exist_ok=True)
        with sqlite3.connect(self.db_path) as connection:
            connection.executescript(self.schema_path.read_text(encoding='utf-8'))

    def _log_memory(self, kind: str, payload: dict[str, Any]) -> None:
        with sqlite3.connect(self.db_path) as connection:
            connection.execute(
                'INSERT INTO memory_entries(kind, payload_json) VALUES(?, ?)',
                (kind, json.dumps(payload)),
            )

    def load_project(self, project_path: str) -> dict[str, Any]:
        project = Path(project_path).resolve()
        index_summary = self.indexer.index_repository(project)
        repo_summary = self.summarizer.summarize_repository(index_summary)
        payload = {
            'project_path': str(project),
            'summary': repo_summary,
            'files': list_project_files(project),
            'index': index_summary,
        }
        self._log_memory('project_load', payload)
        return payload

    def create_plan(self, project_path: str, prompt: str) -> dict[str, Any]:
        project = Path(project_path).resolve()
        repo_snapshot = self.indexer.get_repository_snapshot(project)
        summary = self.summarizer.summarize_repository(repo_snapshot)
        plan = self.planner.generate_plan(prompt=prompt, project_path=project, repo_summary=summary)
        payload = {'project_path': str(project), 'prompt': prompt, 'plan': plan, 'summary': summary}
        self._log_memory('plan', payload)
        return payload

    def execute_plan(self, project_path: str, prompt: str, approved_plan: list[str]) -> dict[str, Any]:
        project = Path(project_path).resolve()
        context = self.indexer.get_repository_snapshot(project)
        result = self.coder.execute(prompt=prompt, approved_plan=approved_plan, project_path=project, context=context)
        payload = {
            'project_path': str(project),
            'prompt': prompt,
            'approved_plan': approved_plan,
            'result': result,
        }
        self._log_memory('execution', payload)
        return payload

    def run_terminal(self, project_path: str, command: str) -> dict[str, Any]:
        result = self.tool_router.dispatch(
            'run_terminal',
            {'command': command, 'project_path': project_path},
        )
        self._log_memory('terminal', {'project_path': project_path, 'command': command, 'result': result})
        return result

    def list_files(self, project_path: str) -> dict[str, Any]:
        project = Path(project_path).resolve()
        return {'project_path': str(project), 'files': list_project_files(project)}
