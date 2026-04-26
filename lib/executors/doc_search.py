"""doc_search executor (#45).

Handles document/invoice triage requests — improvement-cycle tasks that
classify failed document-update and invoice-send queue items by missing
context (recipient, attachments, send method).

Loaded by the dispatcher in lib/ingress.sh when detect_scenario()
returns "doc_search".
"""

import re


def extract_fields(text: str):
    fields = {
        "document_id": "",
        "invoice_target": "",
        "recipient": "",
        "attachments": "",
        "send_method": "",
    }
    missing: list[str] = []
    blocked: list[str] = []
    partial: list[str] = []
    ask_user = ""

    lower = text.lower()

    # Document id (Lark Doc/Wiki token shapes — fldcn/doc/wiki id-ish)
    m = re.search(r"\b((?:fld|doc|wiki|bas|shtcn|nodcn)[A-Za-z0-9_-]{6,})\b", text)
    if m:
        fields["document_id"] = m.group(1)

    # Invoice / 送付 target inference
    if re.search(r"invoice|請求書|請求|invoice\s+send|送付", lower):
        fields["invoice_target"] = "invoice"
    elif "document" in lower or "ドキュメント" in lower:
        fields["invoice_target"] = "document"

    # Recipient / 宛先 hint
    m = re.search(r"\bto\s+([A-Za-z0-9._-][A-Za-z0-9._@ -]{1,60})", text)
    if m:
        fields["recipient"] = m.group(1).strip()
    elif re.search(r"宛先|送信先", text):
        # explicitly mentioned but not parseable — treat as unspecified
        pass

    # Attachments / send method
    if re.search(r"attach|添付", lower):
        fields["attachments"] = "mentioned"
    if re.search(r"\bemail\b|メール", lower):
        fields["send_method"] = "email"
    elif re.search(r"\bim\b|チャット|message", lower):
        fields["send_method"] = "im"
    elif "approval" in lower or "承認" in lower:
        fields["send_method"] = "approval_route"

    # Need at least one of document_id / invoice_target to proceed
    if not (fields["document_id"] or fields["invoice_target"]):
        missing.append("document_id_or_invoice_target")
        partial.append("document_id_or_invoice_target")
        ask_user = (
            "Please specify the document id or invoice target — "
            "for example a Lark Doc token, or 'invoice for <customer>'."
        )

    if fields["invoice_target"] == "invoice" and not fields["recipient"]:
        partial.append("recipient")
        ask_user = ask_user or "Please specify the invoice recipient."

    return fields, missing, blocked, partial, ask_user
