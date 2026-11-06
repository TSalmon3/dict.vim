#!/usr/bin/env bash
set -euo pipefail

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"

VERSION=${1:-}
DIST=${2:-"$ROOT/dist"}

die()  { printf '错误: %s\n' "$*" >&2; exit 1; }
info() { printf '==> %s\n' "$*"; }

if [ -z "$VERSION" ]; then
  printf '用法: %s <VERSION> [DIST]\n' "$(basename "$0")" >&2
  exit 1
fi

[[ "$VERSION" =~ ^[A-Za-z0-9._-]+$ ]] \
  || die "VERSION 只能包含字母、数字、点、下划线、连字符"

ARCHIVE="$DIST/dict-data-$VERSION.tar.gz"
SUM="$ARCHIVE.sha256"

info "版本: $VERSION"
info "目标目录: $DIST"

# ---- 1. 发布前检查 ----
info "检查数据"
[ -d dict ] || die "缺少 dict/ 目录"

for f in \
  dict/character/char_base.json \
  dict/character/char_detail.json \
  dict/character/related.json \
  dict/word/word.json \
  dict/word_en/stardict.csv
do
  [ -f "$f" ] || die "缺少 $f"
done

[ -f dict/idiom/idiom.json ] \
  || printf '警告: 缺少 dict/idiom/idiom.json，导入时会少成语补缺\n' >&2

# ---- 2. 打包 ----
command -v gzip >/dev/null 2>&1 || die "需要 gzip"
mkdir -p "$DIST"

TMP="$ARCHIVE.tmp"
trap 'rm -f "$TMP"' EXIT

info "打包 $ARCHIVE"
tar --exclude='.DS_Store' --exclude='__pycache__' --exclude='*.pyc' \
    -cf - dict | gzip -n > "$TMP"

gzip -t "$TMP"
mv -f "$TMP" "$ARCHIVE"
trap - EXIT
rm -f "$SUM"

info "包内顶层:"
tar -tzf "$ARCHIVE" | head -10 || true
du -h "$ARCHIVE"

# ---- 3. SHA256 ----
if command -v shasum >/dev/null 2>&1; then
  SHA=(shasum -a 256)
elif command -v sha256sum >/dev/null 2>&1; then
  SHA=(sha256sum)
else
  die "需要 shasum 或 sha256sum"
fi

(
  cd "$DIST"
  "${SHA[@]}" "$(basename "$ARCHIVE")" > "$(basename "$SUM")"
  "${SHA[@]}" -c "$(basename "$SUM")" >/dev/null
)

HASH=$(cut -d' ' -f1 "$SUM")
info "完成: $ARCHIVE"
info "SHA256: $HASH"
