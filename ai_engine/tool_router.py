from pathlib import Path
from typing import Any, Callable

from indexer.repo_indexer import RepoIndexer
from tools.file_tools import create_file, delete_file, list_files, read_file, search_code, write_file
from tools.git_tools import git_commit, git_create_branch
from tools.terminal_tools import run_terminal


class ToolRouter:
    def __init__(self, root: Path) -> None:
        self.root = root
        self.indexer = RepoIndexer(root / '.minmin_index')
        self.handlers: dict[str, Callable[..., Any]] = {
            'read_file': read_file,
            'write_file': write_file,
            'create_file': create_file,
            'delete_file': delete_file,
            'list_files': list_files,
            'search_code': search_code,
            'run_terminal': run_terminal,
            'git_commit': git_commit,
            'git_create_branch': git_create_branch,
            'index_repository': self._index_repository,
        }

    def dispatch(self, tool_name: str, payload: dict[str, Any]) -> Any:
        if tool_name not in self.handlers:
            raise ValueError(f'Unsupported tool: {tool_name}')
        return self.handlers[tool_name](**payload)

    def _index_repository(self, project_path: str) -> dict[str, Any]:
        return self.indexer.index_repository(Path(project_path))
