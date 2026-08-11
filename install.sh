#!/bin/bash
# install.sh - build, verify, and install the fastest cowsay on THIS machine as `supercowsay`.
#
#   ./install.sh              # race the candidates, install the winner
#   ./install.sh --user       # install to ~/.local/bin (no sudo)
#   ./install.sh --system     # install to /usr/local/bin (sudo)
#   ./install.sh --prefix DIR # install to DIR/bin
#   ./install.sh --no-race    # skip the benchmark, install cowsay_ultra
#   ./install.sh --uninstall  # remove supercowsay from every known location
#
# Nothing is installed unless it is byte-identical to cowsay_dynamic (verify_identity.sh).
set -uo pipefail
cd "$(dirname "$0")"
NAME=supercowsay
MSG="benchmark"                            # no commas: hyperfine CSV is parsed with awk
PREFIX="" MODE=auto RACE=1 UNINSTALL=0

while [ $# -gt 0 ]; do
  case "$1" in
    --user)      MODE=user ;;
    --system)    MODE=system ;;
    --prefix)    PREFIX="${2:?--prefix needs a directory}"; MODE=prefix; shift ;;
    --no-race)   RACE=0 ;;
    --uninstall) UNINSTALL=1 ;;
    -h|--help)   sed -n '2,11p' "$0" | sed 's/^# \?//'; exit 0 ;;
    *) echo "unknown option: $1 (try --help)"; exit 2 ;;
  esac
  shift
done

say(){ printf '%s\n' "$*"; }
die(){ printf 'error: %s\n' "$*" >&2; exit 1; }

# --- uninstall -------------------------------------------------------------
if [ "$UNINSTALL" = 1 ]; then
  removed=0
  for d in "$HOME/.local/bin" /usr/local/bin /usr/bin; do
    [ -e "$d/$NAME" ] || continue
    if [ -w "$d" ]; then rm -f "$d/$NAME"; else sudo rm -f "$d/$NAME"; fi
    say "removed $d/$NAME"; removed=1
  done
  hash -r 2>/dev/null
  [ "$removed" = 1 ] && say "uninstalled." || say "$NAME was not installed."
  exit 0
fi

# --- build candidates ------------------------------------------------------
say "Building candidates..."
if ! command -v as >/dev/null || ! command -v ld >/dev/null; then
  die "binutils not found. Install with: sudo apt install binutils"
fi
as -o cowsay_dynamic.o cowsay_dynamic.s && ld -o cowsay_dynamic cowsay_dynamic.o -z noexecstack \
  || die "failed to build cowsay_dynamic (the reference implementation)"

CANDIDATES=(./cowsay_dynamic)
if command -v nasm >/dev/null; then
  nasm -f bin -o cowsay_ultra cowsay_ultra.asm && chmod +x cowsay_ultra \
    && CANDIDATES=(./cowsay_ultra ./cowsay_dynamic) \
    || die "failed to build cowsay_ultra"
else
  say "  ! nasm not found - cowsay_ultra (the champion) cannot be built."
  say "    Install it for the fastest binary:  sudo apt install nasm"
  say "    Falling back to cowsay_dynamic."
  RACE=0
fi

# --- verify: never install a cow that lies ---------------------------------
say "Verifying byte-identity..."
VERIFIED=()
for c in "${CANDIDATES[@]}"; do
  if [ "$c" = "./cowsay_dynamic" ]; then VERIFIED+=("$c"); continue; fi   # it is the reference
  if QUIET=1 ./verify_identity.sh "$c" ./cowsay_dynamic; then
    say "  OK  $c is byte-identical to cowsay_dynamic (16/16 cases)"
    VERIFIED+=("$c")
  else
    say "  !! $c FAILED identity - excluded from installation"
  fi
done
[ ${#VERIFIED[@]} -gt 0 ] || die "no candidate passed verification; refusing to install"

# --- race: install what is actually fastest HERE ---------------------------
WINNER="${VERIFIED[0]}"
if [ "$RACE" = 1 ] && [ ${#VERIFIED[@]} -gt 1 ] && command -v hyperfine >/dev/null; then
  say "Racing candidates on this machine..."
  CSV=$(mktemp); PIN=""
  command -v taskset >/dev/null && PIN="taskset -c 0"
  cmds=(); for c in "${VERIFIED[@]}"; do cmds+=("$c $MSG"); done
  if $PIN hyperfine -N --warmup 100 --min-runs 500 --export-csv "$CSV" "${cmds[@]}" >/dev/null 2>&1; then
    while IFS=, read -r cmd mean _; do
      printf '  %-18s %8.1f us\n' "${cmd%% *}" "$(echo "$mean * 1000000" | bc -l)"
    done < <(tail -n +2 "$CSV")
    best=$(tail -n +2 "$CSV" | sort -t, -k2 -g | head -1 | cut -d, -f1)
    WINNER="${best%% *}"
  else
    say "  (benchmark failed; using default champion)"
  fi
  rm -f "$CSV"
elif [ "$RACE" = 1 ] && [ ${#VERIFIED[@]} -gt 1 ]; then
  say "hyperfine not installed - skipping race, using the known champion."
  say "  (cargo install hyperfine, or: sudo apt install hyperfine)"
fi
say "Winner: $WINNER"

# --- pick destination ------------------------------------------------------
case "$MODE" in
  user)   DEST="$HOME/.local/bin" ;;
  system) DEST=/usr/local/bin ;;
  prefix) DEST="$PREFIX/bin" ;;
  auto)   if [ -w /usr/local/bin ]; then DEST=/usr/local/bin
          elif sudo -n true 2>/dev/null; then DEST=/usr/local/bin
          else DEST="$HOME/.local/bin"; fi ;;
esac

mkdir -p "$DEST" 2>/dev/null || sudo mkdir -p "$DEST" || die "cannot create $DEST"
if [ -w "$DEST" ]; then
  install -m 755 "$WINNER" "$DEST/$NAME" || die "install to $DEST failed"
else
  say "Installing to $DEST (needs sudo)..."
  sudo install -m 755 "$WINNER" "$DEST/$NAME" || die "install to $DEST failed"
fi
hash -r 2>/dev/null
say "Installed $WINNER -> $DEST/$NAME"

# --- PATH sanity: is the thing they'll actually run the thing we installed? -
RESOLVED=$(command -v "$NAME" 2>/dev/null)
if [ -z "$RESOLVED" ]; then
  say ""
  say "! $DEST is not on your PATH. Add it:"
  say "    echo 'export PATH=\"$DEST:\$PATH\"' >> ~/.bashrc && exec bash"
elif [ "$RESOLVED" != "$DEST/$NAME" ]; then
  say ""
  say "! Another $NAME shadows this one on your PATH:"
  say "    $RESOLVED  (runs instead of $DEST/$NAME)"
  say "  Remove it with: ./install.sh --uninstall && ./install.sh"
else
  say ""
  "$DEST/$NAME" "supercowsay is installed - moo from anywhere!"
  say "Try:  $NAME \"your message here\""
fi
