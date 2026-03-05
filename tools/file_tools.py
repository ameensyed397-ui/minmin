from pathlib import Path


def read_file(path: str, **_: object) -> dict[str, str]:
    target = Path(path)
    return {'path': str(target), 'content': target.read_text(encoding='utf-8')}


def write_file(path: str, content: str, require_approval: bool = True, **_: object) -> dict[str, object]:
    target = Path(path)
    target.parent.mkdir(parents=True, exist_ok=True)
    if require_approval:
        return {
            'status': 'approval_required',
            'path': str(target),
            'preview': content[:5000],
        }
    target.write_text(content, encoding='utf-8')
    return {'status': 'written', 'path': str(target)}


def create_file(path: str, content: str = '', **_: object) -> dict[str, str]:
    target = Path(path)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(content, encoding='utf-8')
    return {'status': 'created', 'path': str(target)}


def delete_file(path: str, **_: object) -> dict[str, str]:
    target = Path(path)
    target.unlink(missing_ok=True)
    return {'status': 'deleted', 'path': str(target)}


def list_files(path: str, **_: object) -> dict[str, list[str]]:
    root = Path(path)
    return {
        'files': [
            str(file)
            for file in root.rglob('*')
            if file.is_file() and '.git' not in file.parts
        ]
    }


def search_code(query: str, path: str, **_: object) -> dict[str, list[str]]:
    root = Path(path)
    matches = []
    lowered = query.lower()
    for file in root.rglob('*'):
        if file.is_file():
            try:
                text = file.read_text(encoding='utf-8')
            except UnicodeDecodeError:
                continue
            if lowered in text.lower():
                matches.append(str(file))
    return {'matches': matches[:100]}
