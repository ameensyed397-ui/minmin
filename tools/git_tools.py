import subprocess
from pathlib import Path


def git_commit(message: str, project_path: str, **_: object) -> dict[str, object]:
    cwd = Path(project_path)
    subprocess.run(['git', 'add', '-A'], cwd=cwd, capture_output=True, timeout=60)
    result = subprocess.run(
        ['git', 'commit', '-m', message],
        cwd=cwd,
        capture_output=True,
        text=True,
        timeout=60,
    )
    return {'stdout': result.stdout, 'stderr': result.stderr, 'returncode': result.returncode}


def git_create_branch(name: str, project_path: str, **_: object) -> dict[str, object]:
    branch = name if name.startswith('codex/') else f'codex/{name}'
    result = subprocess.run(
        ['git', 'checkout', '-b', branch],
        cwd=Path(project_path),
        capture_output=True,
        text=True,
        timeout=60,
    )
    return {'branch': branch, 'stdout': result.stdout, 'stderr': result.stderr, 'returncode': result.returncode}
