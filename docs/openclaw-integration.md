# OpenClaw Integration

LARC is intended to be consumed by OpenClaw as a local governance/runtime CLI, not as a second full plugin stack.

## Recommended path

```text
OpenClaw Agent
  -> larc ingress openclaw
  -> official openclaw-lark plugin
  -> Lark / Feishu
  -> larc ingress done|fail|followup
```

## Why this path

- Keep OpenClaw as the brain and dialog runtime
- Keep LARC as permission / gate / queue / lifecycle control
- Reuse the official `openclaw-lark` plugin for atomic Feishu operations
- Avoid duplicating a second large plugin surface

## Quick start

Install the OpenClaw skill:

```bash
bash scripts/install-openclaw-larc-runtime-skill.sh
```

Build a bundle for the next governed action:

```bash
bin/larc ingress openclaw --agent main --days 14
```

Dispatch directly to OpenClaw embedded mode:

```bash
bin/larc ingress openclaw --queue-id <queue-id> --execute
```

Dispatch through the Gateway:

```bash
bin/larc ingress openclaw --queue-id <queue-id> --gateway --execute
```

