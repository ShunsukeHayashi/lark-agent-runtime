"""crm_admin executor (#46).

Handles CRM administration tasks (read_base / update_base_record) where
the input must specify base_token + record_id + field_path. Distinct from
the inline 'crm_followup' scenario, which is a customer-facing flow
(create record + send follow-up). This executor is for the operator-side
classification of failed/preview CRM queue items.

Partial resolution of #41: extract_fields here recognizes when an
update is a CRM follow-up step and tags retry_only_eligible. The runtime
two-audit-row split (true #41 fix) is still TODO and depends on either
worker.sh becoming step-aware or openclaw-lark plugin emitting per-step
audit calls. See ADR-0001 'Consequences' section.

Loaded by the dispatcher in lib/ingress.sh when detect_scenario()
returns "crm_admin".
"""

import re


def extract_fields(text: str):
    fields = {
        "base_token": "",
        "record_id": "",
        "field_path": "",
        "classification_hint": "",
        "retry_only_eligible": "",
    }
    missing: list[str] = []
    blocked: list[str] = []
    partial: list[str] = []
    ask_user = ""

    # Base token (Lark Base shape: bascnXXXXXX or bsbcnXXXXXX)
    m = re.search(r"\b((?:bas|bsb)[A-Za-z0-9_-]{6,})\b", text)
    if m:
        fields["base_token"] = m.group(1)

    # Record id (Base record shape: recXXXXXX)
    m = re.search(r"\b(rec[A-Za-z0-9_-]{6,})\b", text)
    if m:
        fields["record_id"] = m.group(1)

    # Field path / column hint
    m = re.search(r"field[:\s=]+([A-Za-z0-9_]+)", text, re.IGNORECASE)
    if m:
        fields["field_path"] = m.group(1)

    # Classification hint from message context
    lower = text.lower()
    if "failed" in lower and "permission" in lower:
        fields["classification_hint"] = "permission-missing"
    elif "input" in lower and "missing" in lower:
        fields["classification_hint"] = "input-missing"
    elif "retry" in lower or "再実行" in lower:
        fields["classification_hint"] = "re-runnable"

    # #41 hint: if the task is a send-only retry (record exists, only message failed)
    if re.search(r"send[\s_-]*(?:only|message)|フォロー.?アップ.*再送", lower):
        fields["retry_only_eligible"] = "true"

    # Required input: base_token. Without it, the executor cannot proceed.
    if not fields["base_token"]:
        missing.append("base_token")
        blocked.append("base_token")
        ask_user = (
            "Please provide the Lark Base token (bascnXXXXXX). "
            "CRM admin operations require an explicit base_token."
        )

    # record_id is optional — when absent, classification can still run on the whole table
    if not fields["record_id"]:
        partial.append("record_id")

    return fields, missing, blocked, partial, ask_user
