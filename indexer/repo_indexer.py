import ast
from pathlib import Path
from typing import Any

from indexer.embedding_generator import EmbeddingGenerator
from indexer.vector_store import VectorStore

_SKIP_DIRS = {'.git', '.minmin_index', '__pycache__', 'node_modules', '.dart_tool', 'build', '.gradle'}

TREE_SITTER_LANGUAGE_MAP = {
    '.py': 'python',
    '.dart': 'dart',
    '.js': 'javascript',
    '.jsx': 'javascript',
    '.ts': 'typescript',
    '.tsx': 'tsx',
}


class RepoIndexer:
    def __init__(self, index_root: Path) -> None:
        self.index_root = index_root
        self.embedder = EmbeddingGenerator()
        self._tree_sitter_parser = None
        self._tree_sitter_languages = None
        try:
            from tree_sitter import Parser
            from tree_sitter_languages import get_language

            self._tree_sitter_parser = Parser
            self._tree_sitter_languages = get_language
        except Exception:
            self._tree_sitter_parser = None
            self._tree_sitter_languages = None

    def index_repository(self, project_path: Path) -> dict[str, Any]:
        project_path = project_path.resolve()
        snippets: list[str] = []
        metadata: list[dict[str, Any]] = []
        files: list[str] = []
        for file in project_path.rglob('*'):
            if not file.is_file() or _SKIP_DIRS.intersection(file.parts):
                continue
            files.append(str(file))
            if file.suffix in TREE_SITTER_LANGUAGE_MAP:
                summary = self._extract_symbols(file)
                snippets.append(summary['chunk'])
                metadata.append(summary)
        store = VectorStore(self.index_root / project_path.name)
        embeddings = self.embedder.encode(snippets) if snippets else []
        store.save(embeddings, metadata)
        return {'project_path': str(project_path), 'files': files, 'symbols': metadata}

    def get_repository_snapshot(self, project_path: Path) -> dict[str, Any]:
        store = VectorStore(self.index_root / project_path.name)
        return {
            'project_path': str(project_path.resolve()),
            'files': [
                str(p) for p in project_path.rglob('*')
                if p.is_file() and not _SKIP_DIRS.intersection(p.parts)
            ][:200],
            'symbols': store.load_metadata(),
        }

    def _extract_symbols(self, path: Path) -> dict[str, Any]:
        text = path.read_text(encoding='utf-8', errors='ignore')
        functions: list[str] = []
        classes: list[str] = []
        imports: list[str] = []

        if self._tree_sitter_parser is not None and self._tree_sitter_languages is not None:
            try:
                lang = self._tree_sitter_languages(TREE_SITTER_LANGUAGE_MAP[path.suffix])
                try:
                    parser = self._tree_sitter_parser(lang)  # tree-sitter >= 0.22 API
                except TypeError:
                    parser = self._tree_sitter_parser()      # tree-sitter < 0.22 API
                    parser.language = lang
                tree = parser.parse(text.encode('utf-8'))
                for node in tree.root_node.children:
                    if 'import' in node.type:
                        imports.append(text[node.start_byte:node.end_byte].strip())
                    if 'class' in node.type:
                        classes.append(text[node.start_byte:node.end_byte].splitlines()[0][:80])
                    if 'function' in node.type or 'method' in node.type:
                        functions.append(text[node.start_byte:node.end_byte].splitlines()[0][:80])
            except Exception:
                pass

        if path.suffix == '.py' and not (functions or classes or imports):
            try:
                tree = ast.parse(text)
                for node in ast.walk(tree):
                    if isinstance(node, ast.FunctionDef):
                        functions.append(node.name)
                    elif isinstance(node, ast.ClassDef):
                        classes.append(node.name)
                    elif isinstance(node, (ast.Import, ast.ImportFrom)):
                        imports.append(ast.unparse(node))
            except SyntaxError:
                pass

        if not (functions or classes or imports):
            for line in text.splitlines():
                stripped = line.strip()
                if stripped.startswith('import ') or stripped.startswith('from '):
                    imports.append(stripped)
                if ' class ' in f' {stripped} ' or stripped.startswith('class '):
                    classes.append(stripped[:80])
                if stripped.startswith('def ') or stripped.startswith('void ') or '=>' in stripped:
                    functions.append(stripped[:80])

        return {
            'path': str(path),
            'functions': functions[:50],
            'classes': classes[:50],
            'imports': imports[:50],
            'chunk': text[:4000],
        }
