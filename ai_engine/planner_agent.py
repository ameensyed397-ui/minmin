import re
from pathlib import Path

from models.ollama_client import OllamaClient


class PlannerAgent:
    def __init__(self, client: OllamaClient, model: str = 'glm4.7') -> None:
        self.client = client
        self.model = model

    def generate_plan(self, prompt: str, project_path: Path, repo_summary: str) -> list[str]:
        planner_prompt = f"""
You are the planning agent for an offline coding assistant.
Project path: {project_path}
User request: {prompt}

Repository summary:
{repo_summary}

Return a concise numbered plan with 3-7 executable steps, one per line, no markdown.
"""
        response = self.client.generate(self.model, planner_prompt)
        steps = [
            re.sub(r'^[\s\-\d\.\)]+', '', line).strip()
            for line in response.splitlines()
            if line.strip()
        ]
        steps = [s for s in steps if s]
        if steps:
            return steps[:7]
        return [
            'inspect repository structure',
            'identify files related to the request',
            'implement the requested changes',
            'run a safe verification command',
        ]
