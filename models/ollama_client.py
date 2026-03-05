import os

import requests


class OllamaClient:
    def __init__(self, base_url: str | None = None) -> None:
        self.base_url = base_url or os.getenv('OLLAMA_BASE_URL', 'http://127.0.0.1:11434')

    def generate(self, model: str, prompt: str) -> str:
        try:
            response = requests.post(
                f'{self.base_url}/api/generate',
                json={'model': model, 'prompt': prompt, 'stream': False},
                timeout=180,
            )
            response.raise_for_status()
            payload = response.json()
            return payload.get('response', '')
        except Exception as exc:
            return f'[local-model-unavailable] {exc}'
