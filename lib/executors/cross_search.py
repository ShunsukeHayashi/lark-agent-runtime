"""cross_search executor (#47).

Wiki/Drive/Base cross-source improvement-area extraction. Aggregates
recent done/failed records across multiple data sources and outputs a
report to a Lark Doc or Wiki node.

Loaded by the dispatcher in lib/ingress.sh when detect_scenario()
returns "cross_search".
"""

import os
import re


def extract_fields(text: str):
    fields = {
        "search_scope": [],   # list of (source, token) tuples; serialized as comma-separated
        "output_target": "",  # lark_doc | lark_wiki
        "output_token": "",   # the actual doc/wiki token if extractable
        "time_window": "",    # e.g. "7d" / "stale"
        "frequency_threshold": "",  # min count to flag as 'improvement area'
    }
    missing: list[str] = []
    blocked: list[str] = []
    partial: list[str] = []
    ask_user = ""

    lower = text.lower()
    scope = []

    # Wiki scope detection
    if re.search(r"\bwiki\b|知识库|ナレッジ", lower):
        wiki_token = os.environ.get("LARC_WIKI_SPACE_ID", "")
        scope.append(("wiki", wiki_token))

    # Drive scope
    if re.search(r"\bdrive\b|ドライブ", lower):
        drive_token = os.environ.get("LARC_DRIVE_FOLDER_TOKEN", "")
        scope.append(("drive", drive_token))

    # Base scope
    if re.search(r"\bbase\b|\bbitable\b|多维表格", lower):
        base_token = os.environ.get("LARC_BASE_APP_TOKEN", "")
        scope.append(("base", base_token))

    fields["search_scope"] = [f"{src}:{tok}" for src, tok in scope]

    # Output target inference
    m = re.search(r"\b((?:doc|wiki|nodcn)[A-Za-z0-9_-]{6,})\b", text)
    if m:
        fields["output_token"] = m.group(1)
        if m.group(1).startswith("nodcn") or "wiki" in lower:
            fields["output_target"] = "lark_wiki"
        else:
            fields["output_target"] = "lark_doc"

    # Time window
    m2 = re.search(r"(\d+)\s*(?:d|day|days|日)", lower)
    if m2:
        fields["time_window"] = f"{m2.group(1)}d"
    elif "recent" in lower or "直近" in lower:
        fields["time_window"] = "7d"
    elif "stale" in lower or "古い" in lower:
        fields["time_window"] = "stale"

    # Frequency threshold (default 3 if not specified)
    m3 = re.search(r"(?:threshold|min[_-]?count|頻度)[:\s=]+(\d+)", lower)
    fields["frequency_threshold"] = m3.group(1) if m3 else "3"

    # At least one search scope must be specified to proceed
    if not scope:
        missing.append("search_scope")
        blocked.append("search_scope")
        ask_user = (
            "Please specify at least one of: wiki, drive, or base "
            "as the cross-search scope. Example: "
            "'aggregate failed records across wiki and base from the last 7 days'."
        )

    # Tokens for declared sources should be configured
    unconfigured = [src for src, tok in scope if not tok]
    if unconfigured:
        partial.extend(f"token:{src}" for src in unconfigured)
        ask_user = ask_user or (
            f"Scope tokens not configured for: {', '.join(unconfigured)}. "
            "Set LARC_WIKI_SPACE_ID / LARC_DRIVE_FOLDER_TOKEN / LARC_BASE_APP_TOKEN as needed."
        )

    if not fields["output_target"]:
        partial.append("output_target")

    return fields, missing, blocked, partial, ask_user
