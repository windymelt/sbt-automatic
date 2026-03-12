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

_sbt_automatic_start_readiness_check() {
    local sbt_root="$1"
    _SBT_AUTOMATIC_STARTING=1
    _SBT_AUTOMATIC_ZLE_F_SET=""
    exec {_SBT_AUTOMATIC_FD}< <(
        local i=0
        while (( i < 60 )); do
            (cd "$sbt_root" && sbt --client "version") >/dev/null 2>&1 && break
            sleep 2
            (( i++ ))
        done
        echo "done"
    )
}

_sbt_automatic_show_ghost() {
    local fd=$1
    zle -F "$fd"
    exec {fd}<&-
    _SBT_AUTOMATIC_TRIGGER_FD=""
    if [[ -n "$_SBT_AUTOMATIC_STARTING" ]]; then
        POSTDISPLAY=" [Starting sbt server...]"
        zle -R
    fi
}

_sbt_automatic_on_server_ready() {
    local fd=$1
    zle -F "$fd"
    exec {fd}<&-
    _SBT_AUTOMATIC_STARTING=""
    _SBT_AUTOMATIC_FD=""
    _SBT_AUTOMATIC_ZLE_F_SET=""
    POSTDISPLAY=""
    zle -R
}

_sbt_automatic_cancel_ghost() {
    if [[ -n "$_SBT_AUTOMATIC_TRIGGER_FD" ]]; then
        zle -F "$_SBT_AUTOMATIC_TRIGGER_FD" 2>/dev/null
        exec {_SBT_AUTOMATIC_TRIGGER_FD}<&-
        _SBT_AUTOMATIC_TRIGGER_FD=""
    fi
    if [[ -n "$_SBT_AUTOMATIC_FD" ]]; then
        zle -F "$_SBT_AUTOMATIC_FD" 2>/dev/null
        exec {_SBT_AUTOMATIC_FD}<&-
    fi
    _SBT_AUTOMATIC_STARTING=""
    _SBT_AUTOMATIC_FD=""
    _SBT_AUTOMATIC_ZLE_F_SET=""
}

_sbt_automatic_leave() {
    local prev_root="$1"
    _sbt_automatic_cancel_ghost
    local ref_file
    ref_file=$(_sbt_automatic_ref_file "$prev_root")
    local count pid
    count=$(( $(sed -n '1p' "$ref_file" 2>/dev/null || echo 0) - 1 ))
    pid=$(sed -n '2p' "$ref_file" 2>/dev/null)

    if [[ $count -le 0 ]]; then
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            _sbt_automatic_log "stopping sbt server (pid=$pid)" "$prev_root"
            (cd "$prev_root" && sbt --client "shutdown" >> "${prev_root}/.sbt-automatic-log" 2>&1)
        else
            _sbt_automatic_log "sbt server already dead (pid=$pid)" "$prev_root"
        fi
        rm -f "$ref_file"
    else
        printf '%s\n%s\n' "$count" "$pid" > "$ref_file"
    fi
    unset _SBT_AUTOMATIC_ROOT
}

_sbt_automatic_enter() {
    local sbt_root="$1"
    local ref_file
    ref_file=$(_sbt_automatic_ref_file "$sbt_root")
    local count pid
    count=$(( $(sed -n '1p' "$ref_file" 2>/dev/null || echo 0) + 1 ))
    pid=$(sed -n '2p' "$ref_file" 2>/dev/null)

    if [[ $count -eq 1 ]] || { [[ -n "$pid" ]] && ! kill -0 "$pid" 2>/dev/null; }; then
        _sbt_automatic_log "starting sbt server" "$sbt_root"
        sleep infinity | nohup sbt --server --batch --no-colors >> "${sbt_root}/.sbt-automatic-log" 2>&1 &
        pid=$!
        _sbt_automatic_start_readiness_check "$sbt_root"
    fi
    printf '%s\n%s\n' "$count" "$pid" > "$ref_file"
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

# -----------------------------------------------
# Ghost text via zle -F
# -----------------------------------------------

_sbt_automatic_precmd_ghost() {
    if [[ -n "$_SBT_AUTOMATIC_STARTING" ]]; then
        # Register readiness check
        if [[ -z "$_SBT_AUTOMATIC_ZLE_F_SET" && -n "$_SBT_AUTOMATIC_FD" ]]; then
            zle -F "$_SBT_AUTOMATIC_FD" _sbt_automatic_on_server_ready
            _SBT_AUTOMATIC_ZLE_F_SET=1
        fi
        # Trigger fd to set POSTDISPLAY inside zle context
        if [[ -n "$_SBT_AUTOMATIC_TRIGGER_FD" ]]; then
            zle -F "$_SBT_AUTOMATIC_TRIGGER_FD" 2>/dev/null
            exec {_SBT_AUTOMATIC_TRIGGER_FD}<&-
        fi
        exec {_SBT_AUTOMATIC_TRIGGER_FD}< <(echo "show")
        zle -F "$_SBT_AUTOMATIC_TRIGGER_FD" _sbt_automatic_show_ghost
    fi
}

add-zsh-hook precmd _sbt_automatic_precmd_ghost

