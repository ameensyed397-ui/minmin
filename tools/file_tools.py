from pathlib import Path


def _safe_path(path: str, project_path: str | None = None) -> Path | None:
    """Resolve path and optionally enforce it stays within project_path."""
    target = Path(path).resolve()
    if project_path:
        root = Path(project_path).resolve()
        try:
            target.relative_to(root)
        except ValueError:
            return None  # path escapes project root
    return target


def read_file(path: str, project_path: str | None = None, **_: object) -> dict[str, str]:
    target = _safe_path(path, project_path)
    if target is None:
        return {'error': f'Path traversal denied: {path}'}
    try:
        return {'path': str(target), 'content': target.read_text(encoding='utf-8')}
    except FileNotFoundError:
        return {'error': f'File not found: {path}'}
    except PermissionError:
        return {'error': f'Permission denied: {path}'}
    except (IsADirectoryError, UnicodeDecodeError, OSError) as exc:
        return {'error': str(exc)}


def write_file(path: str, content: str, require_approval: bool = True,
               project_path: str | None = None, **_: object) -> dict[str, object]:
    target = _safe_path(path, project_path)
    if target is None:
        return {'error': f'Path traversal denied: {path}'}
    try:
        target.parent.mkdir(parents=True, exist_ok=True)
        if require_approval:
            return {
                'status': 'approval_required',
                'path': str(target),
                'preview': content[:5000],
            }
        target.write_text(content, encoding='utf-8')
        return {'status': 'written', 'path': str(target)}
    except PermissionError:
        return {'error': f'Permission denied: {path}'}
    except OSError as exc:
        return {'error': str(exc)}


def create_file(path: str, content: str = '',
                project_path: str | None = None, **_: object) -> dict[str, str]:
    target = _safe_path(path, project_path)
    if target is None:
        return {'error': f'Path traversal denied: {path}'}
    try:
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(content, encoding='utf-8')
        return {'status': 'created', 'path': str(target)}
    except PermissionError:
        return {'error': f'Permission denied: {path}'}
    except OSError as exc:
        return {'error': str(exc)}


def delete_file(path: str, project_path: str | None = None, **_: object) -> dict[str, str]:
    target = _safe_path(path, project_path)
    if target is None:
        return {'error': f'Path traversal denied: {path}'}
    try:
        target.unlink(missing_ok=True)
        return {'status': 'deleted', 'path': str(target)}
    except PermissionError:
        return {'error': f'Permission denied: {path}'}
    except OSError as exc:
        return {'error': str(exc)}


def list_files(path: str, project_path: str | None = None, **_: object) -> dict[str, list[str]]:
    root = _safe_path(path, project_path) or Path(path).resolve()
    return {
        'files': [
            str(file)
            for file in root.rglob('*')
            if file.is_file() and '.git' not in file.parts
        ]
    }


def search_code(query: str, path: str, project_path: str | None = None,
                **_: object) -> dict[str, list[str]]:
    root = _safe_path(path, project_path) or Path(path).resolve()
    matches = []
    lowered = query.lower()
    for file in root.rglob('*'):
        if file.is_file():
            try:
                text = file.read_text(encoding='utf-8')
            except (UnicodeDecodeError, OSError):
                continue
            if lowered in text.lower():
                matches.append(str(file))
    return {'matches': matches[:100]}
