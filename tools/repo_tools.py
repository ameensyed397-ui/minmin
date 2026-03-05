from pathlib import Path


def list_project_files(project_path: Path) -> list[str]:
    return [
        str(path)
        for path in project_path.rglob('*')
        if path.is_file() and '.git' not in path.parts and '.pocket_claude_index' not in path.parts
    ]
