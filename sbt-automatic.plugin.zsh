# shellcheck shell=bash
# sbt-automatic.plugin.zsh

# Guard
[[ -n "$_SBT_AUTOMATIC_LOADED" ]] && return
_SBT_AUTOMATIC_LOADED=1

# -----------------------------------------------
# Internal functions
# -----------------------------------------------

_sbt_automatic_find_root() {
    local dir="$PWD"
    while [[ "$dir" != "/" ]]; do
        [[ -f "$dir/build.sbt" ]] && echo "$dir" && return 0
        dir="${dir:h}"
    done
    return 1
}

_sbt_automatic_log() {
    local msg
    msg="[sbt-automatic] $1 ($2)"
    echo "$msg"
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> "${2}/.sbt-automatic-log"
}

_sbt_automatic_ref_file() {
    local encoded
    encoded="${1//\//_}"
    echo "/tmp/${encoded}.sbt-session-count"
}

_sbt_automatic_leave() {
    local prev_root="$1"
    local ref_file
    ref_file=$(_sbt_automatic_ref_file "$prev_root")
    local count
    count=$(( $(cat "$ref_file" 2>/dev/null || echo 0) - 1 ))

    if [[ $count -le 0 ]]; then
        _sbt_automatic_log "stopping sbt server" "$prev_root"
        (cd "$prev_root" && sbt --client "shutdown" >> "${prev_root}/.sbt-automatic-log" 2>&1)
        rm -f "$ref_file"
    else
        echo "$count" > "$ref_file"
    fi
    unset _SBT_AUTOMATIC_ROOT
}

_sbt_automatic_enter() {
    local sbt_root="$1"
    local ref_file
    ref_file=$(_sbt_automatic_ref_file "$sbt_root")
    local count
    count=$(( $(cat "$ref_file" 2>/dev/null || echo 0) + 1 ))

    echo "$count" > "$ref_file"
    if [[ $count -eq 1 ]]; then
        _sbt_automatic_log "starting sbt server" "$sbt_root"
        sleep infinity | nohup sbt --server --batch --no-colors >> "${sbt_root}/.sbt-automatic-log" 2>&1 &
    fi
    _SBT_AUTOMATIC_ROOT="$sbt_root"
}

_sbt_automatic_chpwd() {
    local sbt_root
    sbt_root=$(_sbt_automatic_find_root)

    if [[ -n "$_SBT_AUTOMATIC_ROOT" && "$sbt_root" != "$_SBT_AUTOMATIC_ROOT" ]]; then
        _sbt_automatic_leave "$_SBT_AUTOMATIC_ROOT"
    fi

    if [[ -n "$sbt_root" && "$sbt_root" != "$_SBT_AUTOMATIC_ROOT" ]]; then
        _sbt_automatic_enter "$sbt_root"
    fi
}

_sbt_automatic_exit() {
    [[ -n "$_SBT_AUTOMATIC_ROOT" ]] && _sbt_automatic_leave "$_SBT_AUTOMATIC_ROOT"
}

# -----------------------------------------------
# Hooks
# -----------------------------------------------

autoload -Uz add-zsh-hook
add-zsh-hook chpwd _sbt_automatic_chpwd
add-zsh-hook zshexit _sbt_automatic_exit

