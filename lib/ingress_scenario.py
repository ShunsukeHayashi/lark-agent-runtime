"""Shared scenario helpers for lib/ingress.sh Python heredocs.

Each heredoc that needs these functions loads this file via:
    exec(open(os.environ["_LARC_SCENARIO_PY"]).read())
"""

import os
import re

REQUIRED_RUNTIME_FIELDS = [
    "base_token",
    "user_table_id",
    "cv_table_id",
    "metrics_table_id",
    "source_table_id",
    "default_view_id",
    "ssot_doc_url",
]


def detect_scenario(task_types, text=""):
    """Map a task-type set (and optionally the message text) to a scenario_id.

    The optional `text` parameter lets us disambiguate scenarios whose task
    types alone are too generic — e.g. a `read_task` that is really a queue
    triage request vs. a normal todo lookup.
    """
    task_set = set(task_types)
    if {"read_base", "send_message"} <= task_set and {"create_document", "update_document", "read_document"} & task_set:
        return "ppal_marketing_ops"
    if {"create_crm_record", "send_crm_followup", "send_message"} & task_set:
        return "crm_followup"
    if "create_expense" in task_set or "submit_approval" in task_set:
        return "expense_approval"
    if "update_document" in task_set or "write_wiki" in task_set:
        return "document_update"

    # Issue #44: queue triage / improvement-cycle requests.
    # Triggered by read_task plus explicit triage/棚卸し/改善サイクル keywords,
    # so plain todo/task lookups still fall through to "generic".
    if "read_task" in task_set and re.search(
        r"triage|棚卸し|改善\s*サイクル|improvement\s+cycle|classify\s+queue|queue\s+health|stale\s+in_progress",
        text or "",
        re.IGNORECASE,
    ):
        return "queue_triage"

    return "generic"


def load_scenario_defaults(lower):
    """Return env-driven runtime defaults for the ppal_marketing_ops scenario.

    Args:
        lower: already-lowercased message text (used for priority-view selection).
    """
    return {
        "base_token": os.getenv("LARC_SCENARIO_BASE_TOKEN", ""),
        "user_table_id": os.getenv("LARC_SCENARIO_USER_TABLE_ID", ""),
        "cv_table_id": os.getenv("LARC_SCENARIO_CV_TABLE_ID", ""),
        "metrics_table_id": os.getenv("LARC_SCENARIO_METRICS_TABLE_ID", ""),
        "source_table_id": os.getenv("LARC_SCENARIO_SOURCE_TABLE_ID", ""),
        "default_view_id": os.getenv(
            "LARC_SCENARIO_PRIORITY_VIEW_ID"
            if re.search(r"hot|follow.?up|priority|urgent", lower)
            else "LARC_SCENARIO_DEFAULT_VIEW_ID",
            "",
        ),
        "ssot_doc_url": os.getenv("LARC_SCENARIO_SSOT_DOC_URL", ""),
    }


def validate_runtime_fields(fields, missing, blocked, ask_user):
    """Check that all required runtime fields are populated.

    Extends missing/blocked in-place and returns the (possibly updated) ask_user string.
    """
    missing_runtime = [n for n in REQUIRED_RUNTIME_FIELDS if not fields.get(n)]
    if missing_runtime:
        missing_set = set(missing)
        blocked_set = set(blocked)
        missing.extend(n for n in missing_runtime if n not in missing_set)
        blocked.extend(n for n in missing_runtime if n not in blocked_set)
        ask_user = ask_user or (
            "Scenario runtime defaults are not configured. Set "
            "LARC_SCENARIO_BASE_TOKEN, LARC_SCENARIO_USER_TABLE_ID, LARC_SCENARIO_CV_TABLE_ID, "
            "LARC_SCENARIO_METRICS_TABLE_ID, LARC_SCENARIO_SOURCE_TABLE_ID, "
            "LARC_SCENARIO_PRIORITY_VIEW_ID or LARC_SCENARIO_DEFAULT_VIEW_ID, and LARC_SCENARIO_SSOT_DOC_URL "
            "before running this PPAL marketing flow."
        )
    return ask_user
