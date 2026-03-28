#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_DIR="$ROOT_DIR/packages/third_party/kernel"
NOTICE_FILE="$ROOT_DIR/NOTICE"
SDK_REPO_URL="${SDK_REPO_URL:-https://github.com/dart-lang/sdk.git}"

usage() {
  cat <<'EOF'
Usage: tool/update_vendored_kernel.sh <sdk-ref>

Fetches pkg/kernel from the given dart-lang/sdk ref, replaces the vendored
kernel package in packages/third_party/kernel, and updates NOTICE provenance.

Examples:
  tool/update_vendored_kernel.sh 3.11.3
  tool/update_vendored_kernel.sh refs/tags/3.11.3
  tool/update_vendored_kernel.sh main

Environment:
  SDK_REPO_URL  Override the Git repository URL. Defaults to the public
                dart-lang/sdk repository.
EOF
}

require_command() {
  local command_name="$1"
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Missing required command: $command_name" >&2
    exit 1
  fi
}

normalize_ref_for_notice() {
  local ref="$1"
  if [[ "$ref" == refs/tags/* ]]; then
    printf '%s\n' "${ref#refs/tags/}"
    return
  fi

  printf '%s\n' "$ref"
}

update_notice() {
  local notice_path="$1"
  local version_label="$2"
  local commit_sha="$3"

  NOTICE_PATH="$notice_path" \
  VERSION_LABEL="$version_label" \
  COMMIT_SHA="$commit_sha" \
  perl -0pi -e '
    my $notice = $ENV{NOTICE_PATH};
    my $version = $ENV{VERSION_LABEL};
    my $sha = $ENV{COMMIT_SHA};
    s{Source: https://github.com/dart-lang/sdk/tree/[^\n]+/pkg/kernel}
     {"Source: https://github.com/dart-lang/sdk/tree/$version/pkg/kernel"}e;
    s{Version: Dart SDK [^\n]+}
     {"Version: Dart SDK $version (commit $sha)"}e;
  ' "$notice_path"
}

main() {
  if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
  fi

  if [[ "$#" -ne 1 ]]; then
    usage >&2
    exit 1
  fi

  require_command git
  require_command rsync
  require_command perl

  local requested_ref="$1"
  local notice_ref
  notice_ref="$(normalize_ref_for_notice "$requested_ref")"

  local temp_dir
  temp_dir="$(mktemp -d)"
  trap 'rm -rf "$temp_dir"' EXIT

  echo "Cloning dart-lang/sdk ($requested_ref)..."
  git clone \
    --filter=blob:none \
    --no-checkout \
    "$SDK_REPO_URL" \
    "$temp_dir/sdk" >/dev/null

  git -C "$temp_dir/sdk" sparse-checkout init --cone >/dev/null
  git -C "$temp_dir/sdk" sparse-checkout set pkg/kernel >/dev/null
  git -C "$temp_dir/sdk" checkout "$requested_ref" >/dev/null

  local resolved_sha
  resolved_sha="$(git -C "$temp_dir/sdk" rev-parse HEAD)"

  if [[ ! -d "$temp_dir/sdk/pkg/kernel" ]]; then
    echo "pkg/kernel was not found at ref: $requested_ref" >&2
    exit 1
  fi

  echo "Updating vendored kernel in $TARGET_DIR..."
  rm -rf "$TARGET_DIR"
  mkdir -p "$TARGET_DIR"
  rsync -a --delete "$temp_dir/sdk/pkg/kernel/" "$TARGET_DIR/"

  echo "Refreshing NOTICE provenance..."
  update_notice "$NOTICE_FILE" "$notice_ref" "$resolved_sha"

  cat <<EOF
Vendored kernel updated successfully.
  ref:    $notice_ref
  commit: $resolved_sha

Next steps:
  1. Review changes under packages/third_party/kernel
  2. Run dart pub get
  3. Run formatter and relevant tests
EOF
}

main "$@"
