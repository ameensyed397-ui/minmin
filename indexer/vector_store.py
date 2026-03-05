import json
from pathlib import Path


class VectorStore:
    def __init__(self, index_dir: Path) -> None:
        self.index_dir = index_dir
        self.index_dir.mkdir(parents=True, exist_ok=True)
        self.index_file = self.index_dir / 'index.faiss'
        self.metadata_file = self.index_dir / 'metadata.json'
        self._faiss = None
        try:
            import faiss

            self._faiss = faiss
        except Exception:
            self._faiss = None

    def save(self, embeddings: list[list[float]], metadata: list[dict]) -> None:
        self.metadata_file.write_text(json.dumps(metadata, indent=2), encoding='utf-8')
        if not embeddings or self._faiss is None:
            return
        import numpy as np

        matrix = np.array(embeddings, dtype='float32')
        index = self._faiss.IndexFlatL2(matrix.shape[1])
        index.add(matrix)
        self._faiss.write_index(index, str(self.index_file))

    def load_metadata(self) -> list[dict]:
        if not self.metadata_file.exists():
            return []
        return json.loads(self.metadata_file.read_text(encoding='utf-8'))
