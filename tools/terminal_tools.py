import shlex
import subprocess
from pathlib import Path


SAFE_COMMANDS = {
    'dir',
    'ls',
    'pwd',
    'echo',
    'python',
    'python3',
    'pip',
    'flutter',
    'dart',
    'npm',
    'node',
    'git',
}


def run_terminal(command: str, project_path: str, **_: object) -> dict[str, object]:
    tokens = shlex.split(command, posix=False)
    if not tokens:
        return {'status': 'error', 'stderr': 'Empty command.'}
    if tokens[0].lower() not in SAFE_COMMANDS:
        return {'status': 'blocked', 'stderr': f"Command '{tokens[0]}' is not in the safe whitelist."}
    completed = subprocess.run(
        command,
        cwd=Path(project_path),
        capture_output=True,
        text=True,
        shell=True,
        timeout=120,
    )
    return {
        'status': 'ok' if completed.returncode == 0 else 'error',
        'stdout': completed.stdout,
        'stderr': completed.stderr,
        'returncode': completed.returncode,
    }
