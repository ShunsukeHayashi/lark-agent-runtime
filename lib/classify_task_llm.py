#!/usr/bin/env python3
"""LLM-based task classifier for LARC ingress.

Reads a scope-map JSON and a free-form task description, calls an LLM
(z.ai GLM-4.6 by default) and returns the matched task_type keys as JSON
on stdout: {"task_types": ["...", ...]}.

Design notes:
- Emits {"task_types": []} on any failure (network, key missing, bad JSON).
- Stderr carries diagnostic messages; stdout is parsed by the caller.
- Exit code is always 0 so the caller can fall back to regex on empty result.

Env vars:
  LARC_CLASSIFIER_API_KEY    API key (falls back to ZAI_API_KEY, ANTHROPIC_API_KEY)
  LARC_CLASSIFIER_BASE_URL   OpenAI-compatible base (default: z.ai GLM endpoint)
  LARC_CLASSIFIER_MODEL      Model id (default: glm-4.6)
  LARC_CLASSIFIER_TIMEOUT    Seconds (default: 8)
"""
from __future__ import annotations

import json
import os
import re
import sys

DEFAULT_BASE_URL = "https://api.z.ai/api/coding/paas/v4"
DEFAULT_MODEL = "glm-4.6"
DEFAULT_TIMEOUT = 8.0


def _log(msg: str) -> None:
    print(f"[classify_task_llm] {msg}", file=sys.stderr)


def _build_prompt(task_desc: str, task_catalog: dict) -> str:
    catalog_lines = [
        f"- {key}: {meta.get('description', '')}"
        for key, meta in task_catalog.items()
    ]
    catalog_block = "\n".join(catalog_lines)
    return (
        "You classify a user's task request into zero or more task_type keys "
        "from the provided catalog. The request may be in Japanese, English, "
        "or Chinese. Pick only keys that clearly match the user's intent.\n\n"
        "Rules:\n"
        "1. Output a single JSON object: {\"task_types\": [\"key1\", \"key2\"]}\n"
        "2. Keys must be exactly from the catalog (case-sensitive).\n"
        "3. Empty array if no clear match.\n"
        "4. Prefer specific keys over generic ones (e.g. create_expense over read_base).\n"
        "5. Include all plausibly relevant keys — downstream uses highest-risk gate.\n"
        "6. No prose, no markdown, no code fences. JSON only.\n\n"
        f"Catalog ({len(task_catalog)} keys):\n{catalog_block}\n\n"
        f"User task:\n{task_desc}\n\n"
        "JSON:"
    )


def _extract_json(text: str) -> dict | None:
    """Pull the first JSON object from raw LLM output."""
    text = text.strip()
    if text.startswith("```"):
        text = re.sub(r"^```(?:json)?\s*", "", text)
        text = re.sub(r"\s*```\s*$", "", text)
    match = re.search(r"\{.*?\}", text, re.DOTALL)
    if not match:
        return None
    try:
        return json.loads(match.group(0))
    except json.JSONDecodeError:
        return None


def classify(task_desc: str, task_catalog: dict) -> list[str]:
    api_key = (
        os.environ.get("LARC_CLASSIFIER_API_KEY")
        or os.environ.get("ZAI_API_KEY")
        or os.environ.get("ANTHROPIC_API_KEY")
    )
    if not api_key:
        _log("no API key found; returning empty")
        return []

    base_url = os.environ.get("LARC_CLASSIFIER_BASE_URL", DEFAULT_BASE_URL).rstrip("/")
    model = os.environ.get("LARC_CLASSIFIER_MODEL", DEFAULT_MODEL)
    try:
        timeout = float(os.environ.get("LARC_CLASSIFIER_TIMEOUT", DEFAULT_TIMEOUT))
    except ValueError:
        timeout = DEFAULT_TIMEOUT

    prompt = _build_prompt(task_desc, task_catalog)

    try:
        import httpx
    except ImportError:
        _log("httpx not installed; returning empty")
        return []

    try:
        resp = httpx.post(
            f"{base_url}/chat/completions",
            headers={
                "Authorization": f"Bearer {api_key}",
                "Content-Type": "application/json",
            },
            json={
                "model": model,
                "messages": [{"role": "user", "content": prompt}],
                "max_tokens": 300,
                "temperature": 0,
                "thinking": {"type": "disabled"},
            },
            timeout=timeout,
        )
    except Exception as exc:
        _log(f"request failed: {exc}")
        return []

    if resp.status_code != 200:
        _log(f"non-200 response: {resp.status_code} {resp.text[:200]}")
        return []

    try:
        payload = resp.json()
        content = payload["choices"][0]["message"]["content"]
    except (KeyError, ValueError, IndexError) as exc:
        _log(f"bad response shape: {exc}")
        return []

    parsed = _extract_json(content or "")
    if not parsed or "task_types" not in parsed:
        _log(f"could not parse JSON from: {content[:200]}")
        return []

    raw = parsed.get("task_types") or []
    if not isinstance(raw, list):
        return []
    valid = [tk for tk in raw if isinstance(tk, str) and tk in task_catalog]
    return sorted(set(valid))


def main() -> int:
    if len(sys.argv) != 3:
        print(
            "usage: classify_task_llm.py <scope-map.json> <task description>",
            file=sys.stderr,
        )
        print('{"task_types": []}')
        return 0

    map_path, task_desc = sys.argv[1], sys.argv[2]

    try:
        with open(map_path, "r", encoding="utf-8") as f:
            scope_map = json.load(f)
    except Exception as exc:
        _log(f"cannot read {map_path}: {exc}")
        print('{"task_types": []}')
        return 0

    catalog = scope_map.get("tasks", {})
    task_types = classify(task_desc, catalog)
    print(json.dumps({"task_types": task_types}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
