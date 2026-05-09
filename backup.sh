#!/usr/bin/env bash
set -euo pipefail

if [[ "$EUID" -eq 0 ]]; then
  echo "NON eseguire questo script con sudo"
  exit 1
fi

DRY_RUN_FLAG=()
CONFIG_DIR="./config"
INCLUDE_FILE="$CONFIG_DIR/include.txt"

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
  cat "$INCLUDE_FILE"
  echo
}

# =========================
# BACKUP PC
# =========================
backup_pc() {
  NAME="$1"
  DEST="$2"
  SRC="$HOME"

  DATE=$(date +%F)
  NEW="$DEST/$DATE"

  DEST_ABS=$(realpath "$DEST")
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

  if ! mountpoint -q "$(realpath "$DEST")/.."; then
    echo "${RED}ERRORE: $DEST non è montato${RESET}"
    exit 1
  fi

echo
echo "=== ESECUZIONE RSYNC ==="

while read -r line; do
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
read -rp "Scelta: " MODE

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
echo "1) Fisso Arch"
echo "2) Laptop"
echo "3) Telefono"
read -rp "Scelta: " CHOICE

case "$CHOICE" in
  1) backup_pc "Fisso Arch" "./Fisso Arch" ;;
  2) backup_pc "Laptop" "./Laptop" ;;
  3) backup_phone ;;
  *) echo "Scelta non valida"; exit 1 ;;
esac
