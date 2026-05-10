#!/usr/bin/env bash
set -euo pipefail

SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
  DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
SCRIPT_DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"

if [[ "$EUID" -eq 0 ]]; then
  echo "NON eseguire questo script con sudo"
  exit 1
fi

DRY_RUN_FLAG=()


# shellcheck disable=SC1090

# colori
BOLD=$(tput bold)
RED=$(tput setaf 1)
RESET=$(tput sgr0)

# =========================
# BANNER
# =========================
print_banner() {
  echo "========================================="
  echo "============== BACKUP ==================="
  echo "========================================="
}

# =========================
# CONFERMA
# =========================
confirm_or_exit() {
  read -rp "$1 [y/N]: " CONFIRM
  [[ "$CONFIRM" == "y" || "$CONFIRM" == "Y" ]] || {
    echo "Operazione annullata."
    exit 1
  }
}


print_summary() {
  echo "=== INCLUDE ==="
  if [[ -f "$INCLUDE_FILE" ]]; then
    cat "$INCLUDE_FILE"
  else
    echo "ERRORE: include file non trovato ($INCLUDE_FILE)"
    exit 1
  fi
  echo
}

# =========================
# BACKUP PC
# =========================
backup_pc() {
  NAME="$1"
  DEST="$2"
  SRC="$3"


  DATE=$(date +%F)
  NEW="$DEST/$DATE"

  DEST_ABS=$(realpath "$DEST" 2>/dev/null || echo "$DEST")
  LAST=$(ls -1d "$DEST_ABS"/20* 2>/dev/null | sort | tail -n 1 || true)

  echo "Dispositivo: $NAME"
  echo "Destinazione: $NEW"

  print_summary


  if [ -n "$LAST" ]; then
    echo "Uso link-dest: $LAST"
    LINK=(--link-dest="$LAST")
  else
    echo "Primo snapshot"
    LINK=()
  fi


  # === VALIDAZIONE CONFIG (filesystem) ===
  
  check_includes_fs "$SRC"

  # === CONFERMA ===
  confirm_or_exit "Procedere con backup $NAME?"

  if [[ ${#DRY_RUN_FLAG[@]} -eq 0 ]]; then
    confirm_or_exit "ATTENZIONE: backup reale. Continuare?"
  fi

  mkdir -p "$NEW"

if [[ "${REQUIRE_MOUNT:-1}" -eq 1 ]]; then
  if [[ "$DEST" = /* ]]; then
    if ! mountpoint -q "$(dirname "$DEST")"; then
      echo "${RED}ERRORE: destinazione non montata${RESET}"
      exit 1
    fi
  else
    echo "WARN: DEST relativo, skip controllo mount"
  fi
fi
echo
echo "=== ESECUZIONE RSYNC ==="

while IFS= read -r line || [[ -n "$line" ]]; do
  [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue

  src_path="$SRC/$line"
  dest_path="$NEW/$line"

  if [ -n "$LAST" ]; then
  if [ -d "$src_path" ]; then
    prev_path="$LAST/$line"
  else
    prev_path="$(dirname "$LAST/$line")"
  fi

  if [ -d "$prev_path" ]; then
    LINK_ARG=(--link-dest="$prev_path")
  else
    LINK_ARG=()
  fi
else
  LINK_ARG=()
fi

  if [ -d "$src_path" ]; then
    echo ">> DIR: $line"
    mkdir -p "$dest_path"


    rsync -a "${DRY_RUN_FLAG[@]}" "${LINK_ARG[@]}" \
      --info=progress2 \
      "$src_path/" "$dest_path/"

  elif [ -f "$src_path" ]; then
    echo ">> FILE: $line"
    mkdir -p "$(dirname "$dest_path")"

       rsync -a "${DRY_RUN_FLAG[@]}" "${LINK_ARG[@]}" \
      "$src_path" "$dest_path"
  else
    echo "${RED}SKIP:${RESET} $line"
  fi

done < "$INCLUDE_FILE"
  echo
  echo "=== SPAZIO DISCO ==="
  df -h "$DEST"

  echo "Backup completato: $NAME"
  if [[ ${#DRY_RUN_FLAG[@]} -ne 0 ]]; then
    echo "Pulizia dry run: rimozione $NEW"
    rm -rf "$NEW"
  fi
}

# =========================
# TELEFONO (WIP)
# =========================
backup_phone() {
  echo "=== BACKUP TELEFONO (WIP) ==="
  confirm_or_exit "Procedere comunque?"
  echo "Non implementato"
}

check_includes_fs() {
  local SRC="$1"
  local total=0
  local ok=0

  echo "=== ANALISI CONFIG (filesystem) ==="

  while read -r line; do
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    total=$((total + 1))

  clean_line="${line%/}"

  if [ -e "$SRC/$clean_line" ]; then
      ok=$((ok + 1))
    else
      echo "${RED}MISSING:${RESET} $line"
    fi
  done < "$INCLUDE_FILE"

  echo
  echo "Include validi: $ok/$total"

if [[ "$ok" -ne "$total" ]]; then
  echo "${BOLD}${RED}ATTENZIONE: path mancanti${RESET}"
  return 0
fi
}

# =========================
# MAIN
# =========================

print_banner

# === Modalità ===
echo "=== Modalità ==="
echo "1) Dry run (simulazione)"
echo "2) Backup reale"
read -rp "Scelta: " MODE || exit 1

case "$MODE" in
  1)
    DRY_RUN_FLAG=(--dry-run)
    echo "[DRY RUN ATTIVO]"
    ;;
  2)
    DRY_RUN_FLAG=()
    echo "[MODALITÀ REALE]"
    ;;
  *)
    echo "Scelta non valida"
    exit 1
    ;;
esac

echo
echo "=== Seleziona dispositivo ==="
CONFIG_BASE_DIR="$SCRIPT_DIR/config/prod"

mapfile -t DEVICES < <(find "$CONFIG_BASE_DIR" -mindepth 1 -maxdepth 1 -type d | sort)

if [[ ${#DEVICES[@]} -eq 0 ]]; then
  echo "Nessun dispositivo trovato in $CONFIG_BASE_DIR"
  exit 1
fi

for i in "${!DEVICES[@]}"; do
  name=$(basename "${DEVICES[$i]}")
  echo "$((i+1))) $name"
done

read -rp "Scelta: " CHOICE

INDEX=$((CHOICE-1))

if [[ -z "${DEVICES[$INDEX]:-}" ]]; then
  echo "Scelta non valida"
  exit 1
fi

DEVICE_DIR="${DEVICES[$INDEX]}"
CONFIG_FILE="$DEVICE_DIR/env.conf"
INCLUDE_FILE="$DEVICE_DIR/include.txt"
if [[ ! -f "$INCLUDE_FILE" ]]; then
  echo "Include mancante: $INCLUDE_FILE"
  exit 1
fi

# shellcheck disable=SC1090
source "$CONFIG_FILE"
DEST_BASE="/mnt"

if [[ "$DEST" != /* ]]; then
  DEST_BASE="${DEST_BASE:-/mnt}"
fi
INCLUDE_FILE="$DEVICE_DIR/include.txt"
echo "CONFIG: NAME=$NAME DEST=$DEST SRC=$SRC"
: "${NAME:?NAME non definito in env.conf}"
: "${DEST:?DEST non definito in env.conf}"
: "${SRC:?SRC non definito in env.conf}"
backup_pc "$NAME" "$DEST" "$SRC"