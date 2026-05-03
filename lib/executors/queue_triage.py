"""queue_triage executor (#44).

Handles 'improvement cycle' tasks that ask the agent to triage stale
in_progress and failed queue items and classify them into:
  - recover           : retryable (transient infra failure)
  - delegate          : needs a different agent / scope
  - approval-waiting  : HITL boundary, not a true failure

This executor is loaded by the dispatcher in lib/ingress.sh when
detect_scenario() returns "queue_triage".
"""

import re


def extract_fields(text: str):
    fields = {
        "queue_filter": "",      # e.g. "status=failed" or "status=in_progress"
        "time_window": "",       # e.g. "7d" / "24h" / "stale"
        "output_target": "",     # where the classification report should go
    }
    missing: list[str] = []
    blocked: list[str] = []
    partial: list[str] = []
    ask_user = ""

    lower = text.lower()

    # Status filter inference
    if "failed" in lower and "in_progress" in lower:
        fields["queue_filter"] = "status_in:failed,in_progress"
    elif "failed" in lower or "失敗" in lower:
        fields["queue_filter"] = "status=failed"
    elif "in_progress" in lower or "stuck" in lower or "stale" in lower or "進行中" in lower:
        fields["queue_filter"] = "status=in_progress"
    elif "preview" in lower:
        fields["queue_filter"] = "status=pending_preview"

    # Time window inference
    m = re.search(r"(\d+)\s*(?:d|day|days|日)", lower)
    if m:
        fields["time_window"] = f"{m.group(1)}d"
    elif "stale" in lower or "古い" in lower:
        fields["time_window"] = "stale"
    elif "recent" in lower or "直近" in lower:
        fields["time_window"] = "7d"

    # Output target inference (Lark Doc / Wiki keyword)
    if re.search(r"\bdoc\b|ドキュメント", lower):
        fields["output_target"] = "lark_doc"
    elif "wiki" in lower or "知识库" in lower or "ナレッジ" in lower:
        fields["output_target"] = "lark_wiki"

    # Acceptance: queue_filter must be set, otherwise the executor cannot proceed.
    # Time window is a soft requirement — defaults to 'stale' if not given.
    if not fields["queue_filter"]:
        missing.append("queue_filter")
        partial.append("queue_filter")
        ask_user = (
            "Please specify which queue states to triage. "
            "Example: 'classify failed and in_progress queue items from the last 7 days'."
        )

    if not fields["time_window"]:
        fields["time_window"] = "stale"  # default fallback; not blocking

    return fields, missing, blocked, partial, ask_user
