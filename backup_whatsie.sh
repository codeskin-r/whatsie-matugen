#!/usr/bin/env bash
# ==============================================================================
#  WHATSIE BACKUP/RESTORE
#  Protege la configuracion de theming Material You (matugen) de Whatsie
#  ante el Dusky Updater o una reinstalacion del paquete AUR.
#
#  Contexto: el Dusky Updater hace `git reset --hard` del repo en ~/dusky y
#  reinstalar el paquete AUR de Whatsie restaura el binario sin parche y puede
#  sobrescribir config local. Este script guarda el estado y lo restaura.
#
#  Uso:
#    backup_whatsie.sh backup     # Guarda el estado actual (snapshot)
#    backup_whatsie.sh restore    # Restaura el snapshot
#    backup_whatsie.sh list       # Muestra que hay guardado
#
#  El snapshot se guarda en ~/.local/state/dusky/whatsie_backup/
# ==============================================================================
set -Eeuo pipefail

BACKUP_BASE="${XDG_STATE_HOME:-$HOME/.local/state}/dusky/whatsie_backup"
SNAPSHOT_DIR="$BACKUP_BASE/snapshot"
MANIFEST="$BACKUP_BASE/MANIFEST.txt"

# ------------------------------------------------------------------------------
#  Rutas protegidas (config real de Whatsie + theming matugen)
#  Nota: las caches (QtWebEngine/Cache_Data) se omiten por ser regenerables.
# ------------------------------------------------------------------------------
declare -ra PROTECTED_PATHS=(
    # Config principal de Whatsie (ventana, tema, permisos)
    "$HOME/.config/org.keshavnrj.ubuntu/WhatSie.conf"

    # Template matugen de Whatsie (el que define la paleta en WhatsApp Web)
    "$HOME/.config/matugen/templates/whatsie.css"

    # CSS ya generado que se inyecta en la pagina
    "$HOME/.config/matugen/generated/whatsie.css"

    # Cara, favicon y ajustes de Whatsie (excluye cache WebEngine)
    "$HOME/.local/share/org.keshavnrj.ubuntu/WhatSie"

    # Repo/proyecto local (contiene el patch y templates de referencia)
    "$HOME/Proyectos/whatsie-matugen"
)

# ------------------------------------------------------------------------------
#  Rutas de cache regenerables que se EXCLUYEN del backup (no se necesitan)
# ------------------------------------------------------------------------------
declare -ra EXCLUDE_PATTERNS=(
    "**/Cache_Data"
    "**/GPUCache"
    "**/QtWebEngine"
)

# ------------------------------------------------------------------------------
#  Helpers
# ------------------------------------------------------------------------------
log() {
    local level="$1" msg="$2"
    case "$level" in
        OK)   echo "[OK]   $msg" ;;
        WARN) echo "[WARN] $msg" >&2 ;;
        ERR)  echo "[ERROR] $msg" >&2 ;;
        *)    echo "[$level] $msg" ;;
    esac
}

copy_path() {
    local src="$1" dst="$2"
    local pattern="" base=""

    # Respetar exclusiones de cache (regenerables)
    for pattern in "${EXCLUDE_PATTERNS[@]}"; do
        case "$src" in
            $pattern)
                return 0
                ;;
        esac
    done

    if [[ -L "$src" ]]; then
        ln -s "$(readlink -- "$src")" "$dst"
    elif [[ -d "$src" ]]; then
        local -a rsync_args=( -a )
        for pattern in "${EXCLUDE_PATTERNS[@]}"; do
            rsync_args+=( --exclude="$pattern" )
        done
        rsync "${rsync_args[@]}" "$src/" "$dst/"
    elif [[ -f "$src" ]]; then
        cp -a "$src" "$dst"
    fi
}

# ------------------------------------------------------------------------------
#  Backup
# ------------------------------------------------------------------------------
do_backup() {
    log OK "Creando snapshot de Whatsie en: $SNAPSHOT_DIR"
    rm -rf "$SNAPSHOT_DIR"
    mkdir -p "$SNAPSHOT_DIR"
    : > "$MANIFEST"

    printf '# %s\n' "$(date -Is)" >> "$MANIFEST"

    for src in "${PROTECTED_PATHS[@]}"; do
        if [[ -e "$src" || -L "$src" ]]; then
            local rel="${src#$HOME/}"
            local dst="$SNAPSHOT_DIR/$(dirname "$rel")"
            mkdir -p "$dst"
            copy_path "$src" "$dst/$(basename "$src")"
            printf '%s\n' "$rel" >> "$MANIFEST"
            log OK "  ✓ $rel"
        else
            log WARN "  (no existe) $rel"
        fi
    done

    log OK "Backup completado. ${#PROTECTED_PATHS[@]} rutas revisadas."
}

# ------------------------------------------------------------------------------
#  Restore
# ------------------------------------------------------------------------------
do_restore() {
    if [[ ! -d "$SNAPSHOT_DIR" ]]; then
        log ERR "No hay snapshot previo: $SNAPSHOT_DIR"
        log ERR "Ejecuta: backup_whatsie.sh backup"
        exit 1
    fi

    log OK "Restaurando Whatsie desde el snapshot..."
    local count=0

    for src in "${PROTECTED_PATHS[@]}"; do
        local rel="${src#$HOME/}"
        local bak="$SNAPSHOT_DIR/$rel"
        if [[ -e "$bak" || -L "$bak" ]]; then
            rm -rf "$src"
            mkdir -p "$(dirname "$src")"
            copy_path "$bak" "$src"
            ((count++))
            log OK "  ↺ $rel"
        else
            log WARN "  (sin backup) $rel"
        fi
    done

    log OK "$count rutas restauradas."
    log OK "Si el binario Whatsie quedo sin parche, recompila el paquete AUR:"
    log OK "  makepkg -si  (en el dir del PKGBUILD, con v6-webview-matugen.patch)"
}

# ------------------------------------------------------------------------------
#  List
# ------------------------------------------------------------------------------
do_list() {
    if [[ ! -d "$SNAPSHOT_DIR" ]]; then
        log ERR "No hay snapshot previo."
        exit 1
    fi
    echo "Snapshot de Whatsie en: $SNAPSHOT_DIR"
    echo "Creado: $(head -n1 "$MANIFEST" 2>/dev/null | sed 's/^# //')"
    echo "Contenido:"
    find "$SNAPSHOT_DIR" -mindepth 1 | sed "s|^$SNAPSHOT_DIR/||" | sort
}

# ------------------------------------------------------------------------------
#  Main
# ------------------------------------------------------------------------------
case "${1:-}" in
    backup)  do_backup ;;
    restore) do_restore ;;
    list)    do_list ;;
    *)
        echo "Uso: $0 {backup|restore|list}"
        exit 1
        ;;
esac
