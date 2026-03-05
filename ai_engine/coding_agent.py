import json
import re
from pathlib import Path
from typing import Any

from ai_engine.tool_router import ToolRouter
from models.ollama_client import OllamaClient


class CodingAgent:
    def __init__(self, client: OllamaClient, tool_router: ToolRouter, model: str = 'qwen3-coder') -> None:
        self.client = client
        self.tool_router = tool_router
        self.model = model

    def execute(
        self,
        prompt: str,
        approved_plan: list[str],
        project_path: Path,
        context: dict[str, Any],
    ) -> dict[str, Any]:
        agent_prompt = f"""
You are the coding agent for MIN MIN, an offline AI coding assistant.
User request: {prompt}
Project path: {project_path}
Approved plan:
{chr(10).join(f'- {step}' for step in approved_plan)}

Repository context:
{json.dumps(context, indent=2)[:12000]}

If you need tools, emit one or more blocks in this exact format (JSON may span multiple lines):
TOOL_CALL
tool_name
{{
  "arg": "value"
}}

Valid tools: read_file, write_file, create_file, delete_file, list_files, search_code, run_terminal, git_commit, git_create_branch, index_repository

The approved plan already acts as user confirmation for edits. Use write_file directly when implementation is needed.
After tool calls, include a final summary.
"""
        raw = self.client.generate(self.model, agent_prompt)
        tool_results = []
        for tool_name, payload in self._parse_tool_calls(raw):
            if tool_name == 'write_file':
                payload.setdefault('require_approval', False)
            try:
                result = self.tool_router.dispatch(tool_name, payload)
            except Exception as exc:
                result = {'error': str(exc)}
            tool_results.append({'tool': tool_name, 'args': payload, 'result': result})
        return {'raw_response': raw, 'tool_results': tool_results}

    def _parse_tool_calls(self, text: str) -> list[tuple[str, dict[str, Any]]]:
        """Parse TOOL_CALL blocks whose JSON payload may span multiple lines."""
        calls: list[tuple[str, dict[str, Any]]] = []
        pattern = re.compile(r'TOOL_CALL\s*\n\s*(\w+)\s*\n\s*(\{.*?\})', re.DOTALL)
        for match in pattern.finditer(text):
            name = match.group(1).strip()
            json_str = match.group(2).strip()
            try:
                payload = json.loads(json_str)
                if isinstance(payload, dict):
                    calls.append((name, payload))
            except json.JSONDecodeError:
                pass
        return calls
