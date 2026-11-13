#!/bin/bash
# Rebuild stale CV PDFs, build the whole Jekyll site, check it, and serve it at http://127.0.0.1:4000.
# Usage: preview.sh              build, check, and keep serving (long-running)
#        preview.sh --no-serve   build into _site/ and check only
set -eo pipefail

cd "$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
PORT=4000
URL="http://127.0.0.1:$PORT"

# 1. CV PDFs: recompile only when the .tex is newer than the .pdf
CV_DIR="_pages/CV_pdf"
export PATH="/Library/TeX/texbin:$PATH"

compile_cv() {  # $1 = .tex file, $2 = latexmk engine flag
  local tex="$1" pdf="${1%.tex}.pdf"
  if [ ! -f "$CV_DIR/$pdf" ] || [ "$CV_DIR/$tex" -nt "$CV_DIR/$pdf" ]; then
    echo "==> Compiling $CV_DIR/$tex"
    (cd "$CV_DIR" && latexmk "$2" -interaction=nonstopmode -halt-on-error "$tex" >/dev/null 2>&1) \
      || { echo "LaTeX failed, see $CV_DIR/${tex%.tex}.log"; exit 1; }
  else
    echo "==> $CV_DIR/$pdf is up to date"
  fi
}

compile_cv main.tex -pdf
compile_cv main-cn.tex -xelatex

# 2. Ruby: Homebrew Ruby 3.2; the system Ruby 2.6 cannot run this Gemfile
export PATH="/usr/local/opt/ruby@3.2/bin:$HOME/.gem/ruby/3.2.0/bin:$PATH"
export BUNDLE_PATH=vendor/bundle
# Without this, Bundler 4 switches to the 1.17.2 recorded in Gemfile.lock, which crashes on Ruby 3.2
export BUNDLE_VERSION=system

if ! bundle check >/dev/null 2>&1; then
  echo "==> Installing gems into vendor/bundle"
  SDKROOT="$(xcrun --show-sdk-path)"
  export SDKROOT ARCHFLAGS="-arch x86_64"
  export CPATH="$SDKROOT/usr/include/c++/v1:$SDKROOT/usr/include"
  export CPPFLAGS="-I$SDKROOT/usr/include/c++/v1 -I$SDKROOT/usr/include"
  export CXXFLAGS="$CPPFLAGS -stdlib=libc++"
  export LDFLAGS="-L$SDKROOT/usr/lib"
  bundle install
fi

check_output() {
  local failed=0 f leaked
  for f in index.html Research/index.html cv/index.html cv-cn/index.html 404.html \
           _pages/CV_pdf/main.pdf _pages/CV_pdf/main-cn.pdf files/supplement.pdf; do
    [ -f "_site/$f" ] || { echo "MISSING: _site/$f"; failed=1; }
  done
  leaked="$(find _site \( -path '_site/.cursor*' -o -name '*.tex' -o -name '*.aux' -o -name '*.log' \
    -o -name '*.out' -o -name '*.fls' -o -name '*.fdb_latexmk' -o -name '*.synctex.gz' -o -name '*.sh' \
    -o -name '*.xdv' -o -name '*.gem' \) -print)"
  if [ -n "$leaked" ]; then
    echo "Files that should not be published:"
    echo "$leaked"
    failed=1
  fi
  return "$failed"
}

# 3a. Build only
if [ "$1" = "--no-serve" ]; then
  echo "==> jekyll build"
  bundle exec jekyll build
  check_output
  echo "==> OK: $(find _site -type f | wc -l | tr -d ' ') files in _site/"
  exit 0
fi

# 3b. Build and serve: jekyll serve does the full build itself
lsof -ti:"$PORT" -sTCP:LISTEN | xargs kill 2>/dev/null || true
sleep 1
echo "==> jekyll serve"
bundle exec jekyll serve --port "$PORT" &
SERVER_PID=$!
trap 'kill "$SERVER_PID" 2>/dev/null || true' EXIT
trap 'exit 130' INT TERM HUP

for _ in $(seq 90); do
  curl -s -o /dev/null "$URL/" && break
  kill -0 "$SERVER_PID" 2>/dev/null || { echo "jekyll serve exited before the site was ready"; exit 1; }
  sleep 1
done

check_output
failed=0
for p in / /Research/ /cv/ /cv-cn/ /_pages/CV_pdf/main.pdf /_pages/CV_pdf/main-cn.pdf /files/supplement.pdf; do
  code="$(curl -s -o /dev/null -w '%{http_code}' "$URL$p")"
  [ "$code" = 200 ] || { echo "HTTP $code: $p"; failed=1; }
done
[ "$failed" -eq 0 ] || exit 1

echo "==> Preview ready: $URL/"
# Stopping the server with kill makes jekyll exit non-zero, but that is a normal shutdown
wait "$SERVER_PID" || true
echo "==> Preview server stopped"
