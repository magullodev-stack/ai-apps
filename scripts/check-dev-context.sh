#!/usr/bin/env bash
set -euo pipefail

fail() {
  echo "[check-dev-context] ERROR: $1" >&2
  exit 1
}

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"

[[ -d "${repo_root}/.git" ]] || fail "la raiz detectada (${repo_root}) no es un repositorio Git"

expected_owner_repo="magullodev-stack/ai-apps"
canonical_url_ssh="git@github.com:${expected_owner_repo}.git"
canonical_url_ssh_nogit="git@github.com:${expected_owner_repo}"
canonical_url_https="https://github.com/${expected_owner_repo}.git"
canonical_url_https_nogit="https://github.com/${expected_owner_repo}"
canonical_url_ssh_proto="ssh://git@github.com/${expected_owner_repo}.git"
canonical_url_ssh_proto_nogit="ssh://git@github.com/${expected_owner_repo}"

remote_url="$(git -C "${repo_root}" remote get-url origin 2>/dev/null || true)"
[[ -n "${remote_url}" ]] || fail "no existe el remoto origin en ${repo_root}"

case "${remote_url}" in
  "${canonical_url_ssh}"|"${canonical_url_ssh_nogit}"|"${canonical_url_https}"|"${canonical_url_https_nogit}"|"${canonical_url_ssh_proto}"|"${canonical_url_ssh_proto_nogit}")
    ;;
  *)
    if [[ "${remote_url}" == *"magullodev-stack/quiz10"* ]]; then
      fail "origin apunta al repositorio antiguo magullodev-stack/quiz10 (${remote_url})"
    fi
    if [[ "${remote_url}" == *"github.com"* ]]; then
      fail "origin no apunta a ${expected_owner_repo}: ${remote_url}"
    fi
    fail "no se esta trabajando en ${expected_owner_repo}; origin actual: ${remote_url}"
    ;;
esac

current_branch="$(git -C "${repo_root}" branch --show-current)"
[[ "${current_branch}" == "dev" ]] || fail "rama activa invalida: ${current_branch} (se requiere dev)"

if ! git -C "${repo_root}" fetch origin dev >/dev/null 2>&1; then
  fail "git fetch origin dev fallo (verifica red y autenticacion SSH)"
fi

head_sha="$(git -C "${repo_root}" rev-parse HEAD)"
origin_dev_sha="$(git -C "${repo_root}" rev-parse origin/dev)"

[[ "${head_sha}" == "${origin_dev_sha}" ]] || fail "HEAD (${head_sha}) no coincide con origin/dev (${origin_dev_sha})"

echo "[check-dev-context] OK branch=${current_branch} sha=${head_sha}"
