import hashlib


class EmbeddingGenerator:
    def __init__(self) -> None:
        self._model = None
        try:
            from sentence_transformers import SentenceTransformer

            self._model = SentenceTransformer('all-MiniLM-L6-v2')
        except Exception:
            self._model = None

    def encode(self, texts: list[str]) -> list[list[float]]:
        if self._model is not None:
            return self._model.encode(texts, normalize_embeddings=True).tolist()
        return [self._fallback_vector(text) for text in texts]

    def _fallback_vector(self, text: str) -> list[float]:
        digest = hashlib.sha256(text.encode('utf-8')).digest()
        values = [byte / 255.0 for byte in digest]
        while len(values) < 128:
            values.extend(values[: 128 - len(values)])
        return values[:128]
