from pathlib import Path

_SKIP_DIRS = {'.git', '.minmin_index', '__pycache__', 'node_modules', '.dart_tool', 'build', '.gradle'}


def list_project_files(project_path: Path) -> list[str]:
    return [
        str(path)
        for path in project_path.rglob('*')
        if path.is_file() and not _SKIP_DIRS.intersection(path.parts)
    ]
