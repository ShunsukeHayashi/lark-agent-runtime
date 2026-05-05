#!/usr/bin/env python3
"""base2pdf-render — Lark Base レコード JSON をテンプレートに差し込んで Markdown 出力。

Usage:
    cat record.json | python3 base2pdf-render.py --template path/to/template.md --output rendered.md

Template syntax:
    {{var}}           — 単純変数
    {{nested.field}}  — ネスト参照
    {{#each items}}   — ループ開始
    {{/each}}         — ループ終了
    {{calc:expr}}     — 計算式 (frontmatter calculations を参照)

Frontmatter example:
    ---
    name: invoice-standard
    industry: common
    description: 標準請求書テンプレ
    required_fields: [invoice_number, customer_name, items]
    calculations:
      subtotal: sum(items.amount)
      tax: subtotal * 0.10
      total: subtotal + tax
    ---
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any

try:
    import yaml  # type: ignore
except ImportError:
    yaml = None


def parse_frontmatter(text: str) -> tuple[dict[str, Any], str]:
    """Return (frontmatter_dict, body)."""
    if not text.startswith("---\n"):
        return {}, text
    end = text.find("\n---\n", 4)
    if end == -1:
        return {}, text
    fm_text = text[4:end]
    body = text[end + 5 :]
    if yaml is not None:
        try:
            data = yaml.safe_load(fm_text) or {}
            return data, body
        except yaml.YAMLError:
            pass
    # Fallback: very loose key:value parser
    fm: dict[str, Any] = {}
    for line in fm_text.splitlines():
        if ":" in line and not line.lstrip().startswith("-"):
            k, _, v = line.partition(":")
            fm[k.strip()] = v.strip()
    return fm, body


def lookup(ctx: dict[str, Any], path: str) -> Any:
    """Dot-path lookup. Returns "" if any step missing."""
    cur: Any = ctx
    for part in path.split("."):
        if isinstance(cur, dict):
            cur = cur.get(part, "")
        else:
            return ""
    return cur if cur is not None else ""


def render_each(body: str, ctx: dict[str, Any]) -> str:
    """Expand {{#each NAME}} ... {{/each}} blocks.

    Surrounding newlines around the block markers are absorbed so that
    iterations produce contiguous lines (markdown table rows etc.).
    """
    pattern = re.compile(
        r"\{\{#each\s+([\w\.]+)\}\}\n?(.+?)\n?\{\{/each\}\}",
        re.DOTALL,
    )

    def repl(m: re.Match[str]) -> str:
        list_name = m.group(1)
        block = m.group(2)
        items = lookup(ctx, list_name)
        if not isinstance(items, list):
            return ""
        rendered_items: list[str] = []
        for it in items:
            local_ctx = dict(ctx)
            if isinstance(it, dict):
                local_ctx.update(it)
            else:
                local_ctx["this"] = it
            rendered_items.append(render_vars(block, local_ctx))
        return "\n".join(rendered_items)

    return pattern.sub(repl, body)


def render_vars(text: str, ctx: dict[str, Any]) -> str:
    """Replace {{var}} and {{nested.field}}."""
    pattern = re.compile(r"\{\{\s*([\w\.]+)\s*\}\}")

    def repl(m: re.Match[str]) -> str:
        key = m.group(1)
        val = lookup(ctx, key)
        if isinstance(val, (dict, list)):
            return json.dumps(val, ensure_ascii=False)
        return format_scalar(val)

    return pattern.sub(repl, text)


def format_scalar(v: Any) -> str:
    """Integer-valued floats render as integers (1000000.0 → 1000000).
    Non-integer floats keep up to 2 decimal places."""
    if isinstance(v, float):
        if v.is_integer():
            return str(int(v))
        return f"{v:.2f}".rstrip("0").rstrip(".")
    return str(v)


def apply_calculations(ctx: dict[str, Any], calcs: dict[str, str]) -> None:
    """Apply calculation expressions in order. Mutates ctx in place.

    Supported expressions (very limited, intentionally):
      - sum(LIST.FIELD)
      - VAR * NUMBER
      - VAR + VAR
      - VAR - VAR
    """
    if not calcs:
        return
    for name, expr in calcs.items():
        ctx[name] = eval_expr(expr.strip(), ctx)


def eval_expr(expr: str, ctx: dict[str, Any]) -> float:
    # sum(LIST.FIELD)
    m = re.match(r"sum\(([\w\.]+)\)$", expr)
    if m:
        path = m.group(1)
        if "." in path:
            list_name, field = path.split(".", 1)
            items = lookup(ctx, list_name)
        else:
            items = lookup(ctx, path)
            field = ""
        total = 0.0
        if isinstance(items, list):
            for it in items:
                v = it.get(field, 0) if isinstance(it, dict) and field else it
                try:
                    total += float(v)
                except (TypeError, ValueError):
                    pass
        return total

    # arithmetic VAR OP NUMBER_OR_VAR
    m = re.match(r"([\w\.]+)\s*([\+\-\*\/])\s*(.+)$", expr)
    if m:
        a = _to_number(lookup(ctx, m.group(1)))
        op = m.group(2)
        b_str = m.group(3).strip()
        b = _resolve_operand(b_str, ctx)
        if op == "+":
            return a + b
        if op == "-":
            return a - b
        if op == "*":
            return a * b
        if op == "/":
            return a / b if b else 0.0

    # bare number or var
    return _resolve_operand(expr.strip(), ctx)


def _resolve_operand(s: str, ctx: dict[str, Any]) -> float:
    """Try numeric literal first, then ctx variable lookup."""
    try:
        return float(s)
    except ValueError:
        pass
    if re.match(r"^[a-zA-Z_]\w*(\.[\w]+)*$", s):
        return _to_number(lookup(ctx, s))
    return 0.0


def _to_number(v: Any) -> float:
    try:
        return float(v)
    except (TypeError, ValueError):
        return 0.0


def extract_record_fields(record_json: dict[str, Any]) -> dict[str, Any]:
    """Lark Base record JSON → flat field dict.

    Lark Base record shape:
      { "data": { "record": { "fields": { "顧客名": "...", "金額": 1000, ... } } } }
    """
    data = record_json.get("data", record_json)
    rec = data.get("record", data)
    fields = rec.get("fields", rec)
    if not isinstance(fields, dict):
        return {}
    return fields


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--template", required=True, help="Template .md path")
    ap.add_argument("--output", required=True, help="Output .md path")
    ap.add_argument("--input", help="Input record JSON path (default: stdin)")
    args = ap.parse_args()

    template_text = Path(args.template).read_text(encoding="utf-8")
    fm, body = parse_frontmatter(template_text)

    if args.input:
        record_json = json.loads(Path(args.input).read_text(encoding="utf-8"))
    else:
        record_json = json.loads(sys.stdin.read())

    ctx = extract_record_fields(record_json)

    calcs = fm.get("calculations") or {}
    if isinstance(calcs, dict):
        apply_calculations(ctx, calcs)

    body = render_each(body, ctx)
    body = render_vars(body, ctx)

    Path(args.output).write_text(body, encoding="utf-8")
    print(f"rendered → {args.output}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
