from models.ollama_client import OllamaClient


class SummarizerAgent:
    def __init__(self, client: OllamaClient, model: str = 'minimax-m2:latest') -> None:
        self.client = client
        self.model = model

    def summarize_repository(self, repo_snapshot: dict) -> str:
        prompt = f"""
Summarize this repository for a coding agent.
Focus on architecture, notable modules, dependencies, and likely edit targets.
Keep it under 250 words.

Repository snapshot:
{repo_snapshot}
"""
        summary = self.client.generate(self.model, prompt)
        if summary.strip() and not summary.startswith('[local-model-unavailable]'):
            return summary.strip()
        files = repo_snapshot.get('files', [])
        return f"Repository contains {len(files)} files. Key files: {', '.join(files[:10])}."
