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
    try:
        tokens = shlex.split(command, posix=False)
    except ValueError as exc:
        return {'status': 'error', 'stderr': f'Invalid command syntax: {exc}'}
    if not tokens:
        return {'status': 'error', 'stderr': 'Empty command.', 'stdout': '', 'returncode': 1}
    first_token = tokens[0].strip('"\'').lower()
    # Strip path component so "/usr/bin/python" → "python"
    first_token = Path(first_token).name
    if first_token not in SAFE_COMMANDS:
        return {
            'status': 'blocked',
            'stderr': f"Command '{first_token}' is not in the safe whitelist.",
            'stdout': '',
            'returncode': 1,
        }
    # Use list form (shell=False) to prevent shell injection
    try:
        completed = subprocess.run(
            tokens,
            cwd=Path(project_path),
            capture_output=True,
            text=True,
            shell=False,
            timeout=120,
        )
        return {
            'status': 'ok' if completed.returncode == 0 else 'error',
            'stdout': completed.stdout,
            'stderr': completed.stderr,
            'returncode': completed.returncode,
        }
    except FileNotFoundError:
        return {'status': 'error', 'stderr': f"'{first_token}' not found on PATH.", 'stdout': '', 'returncode': 127}
    except subprocess.TimeoutExpired:
        return {'status': 'error', 'stderr': 'Command timed out (120s).', 'stdout': '', 'returncode': 124}
    except OSError as exc:
        return {'status': 'error', 'stderr': str(exc), 'stdout': '', 'returncode': 1}
