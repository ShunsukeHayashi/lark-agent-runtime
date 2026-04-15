#!/usr/bin/env bash
set -euo pipefail

bundle_files=(
  "README.md"
  "README.zh-CN.md"
  "README.ja.md"
  "CONTRIBUTING.md"
  "CONTRIBUTING.zh-CN.md"
  "CONTRIBUTING.ja.md"
  "LICENSE"
  "PLAYBOOK.md"
  "docs/goal-aligned-playbook.md"
  "docs/permission-model.md"
  "docs/auth-suggest-cases.md"
  "docs/open-source-trilingual-plan.md"
  "docs/release-checklist.md"
  "docs/release-readiness-2026-04-14.md"
  "docs/public-release-candidate-scope.md"
  "docs/public-release-bundle-2026-04-14.md"
  "docs/bundle-a-readiness-2026-04-14.md"
  "docs/bundle-a-manifest-2026-04-14.md"
  "docs/launch-messaging.md"
  "docs/repo-publish-kit.md"
  "docs/terminology-glossary.md"
  "docs/terminology-glossary.zh-CN.md"
  "docs/terminology-glossary.ja.md"
  "scripts/auth-suggest-check.sh"
)

is_bundle_file() {
  local path="$1"
  local file
  for file in "${bundle_files[@]}"; do
    if [[ "$file" == "$path" ]]; then
      return 0
    fi
  done
  return 1
}

printf '== Bundle A File Presence ==\n'
missing=0
for file in "${bundle_files[@]}"; do
  if [[ -e "$file" ]]; then
    printf 'OK   %s\n' "$file"
  else
    printf 'MISS %s\n' "$file"
    missing=1
  fi
done

printf '\n== Working Tree Classification ==\n'
status_output="$(git status --porcelain)"
if [[ -z "$status_output" ]]; then
  printf 'Clean working tree\n'
else
  bundle_hits=()
  outside_hits=()
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    path="${line:3}"
    if is_bundle_file "$path"; then
      bundle_hits+=("$line")
    else
      outside_hits+=("$line")
    fi
  done <<< "$status_output"

  printf '\nBundle A changes:\n'
  if [[ "${#bundle_hits[@]}" -eq 0 ]]; then
    printf '  none\n'
  else
    printf '  %s\n' "${bundle_hits[@]}"
  fi

  printf '\nOutside Bundle A changes:\n'
  if [[ "${#outside_hits[@]}" -eq 0 ]]; then
    printf '  none\n'
  else
    printf '  %s\n' "${outside_hits[@]}"
  fi
fi

printf '\n== Verdict ==\n'
if [[ "$missing" -ne 0 ]]; then
  printf 'HOLD: Bundle A is missing required files.\n'
elif [[ -n "${status_output}" ]]; then
  printf 'READY TO SLICE: Bundle A files exist. Review Bundle A changes and keep outside changes out of the docs-first release.\n'
else
  printf 'READY: Bundle A files exist and working tree is clean.\n'
fi
