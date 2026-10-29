# sourced from ~/.zshrc, anything after the source line wins.
# NOCTILUCA_FASTFETCH=0 or NOCTILUCA_TRANSIENT=0 before it turns those off

[[ -o interactive ]] || return
(( ${+_NOCT_LOADED} )) && return
typeset -g _NOCT_LOADED=1

typeset -gA NOCT
_noct_colors="${XDG_CONFIG_HOME:-$HOME/.config}/noctiluca/colors.zsh"
[[ -r $_noct_colors ]] && source "$_noct_colors"
unset _noct_colors
# fallback if the generated colours are missing
: ${NOCT[mute]:='#8a9594'} ${NOCT[dim]:='#afbaba'} ${NOCT[text]:='#e6f1f1'} ${NOCT[line]:='#363f3f'}
: ${NOCT[glow]:='#7fdddd'} ${NOCT[glow_hi]:='#c5f6f5'} ${NOCT[glow_lo]:='#1c5757'} ${NOCT[signal]:='#eb8376'}
: ${NOCT[yellow]:='#b8ab78'} ${NOCT[green]:='#90b790'} ${NOCT[blue]:='#89afd6'} ${NOCT[magenta]:='#c79bbd'}
: ${NOCT[ink]:='#0c1414'} ${NOCT[menu]:='38;2;28;87;87'} ${NOCT[menu_text]:='38;2;197;246;245'}

_noct_mix() {
  local a=${1#\#} b=${2#\#} out='#' i
  for i in 1 3 5; do
    out+=$(printf '%02x' $(( (0x${a[i,i+1]} * $3 + 0x${b[i,i+1]} * (100 - $3)) / 100 )))
  done
  REPLY=$out
}
_noct_mix ${NOCT[mute]} ${NOCT[ink]} 55; NOCT[faint]=$REPLY

setopt auto_cd interactive_comments no_beep auto_pushd pushd_ignore_dups pushd_silent
setopt extended_glob glob_dots no_flow_control

_noct_state="${XDG_STATE_HOME:-$HOME/.local/state}/zsh"
_noct_cache="${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
[[ -d $_noct_state ]] || mkdir -p "$_noct_state"
[[ -d $_noct_cache ]] || mkdir -p "$_noct_cache"

HISTFILE="$_noct_state/history"
HISTSIZE=50000
SAVEHIST=50000
setopt share_history extended_history hist_ignore_all_dups hist_ignore_space hist_reduce_blanks hist_verify

autoload -Uz compinit
compinit -d "$_noct_cache/zcompdump"
zmodload zsh/complist
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'
# selected row in the accent instead of reverse video
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS} "ma=${NOCT[menu]/#38;/48;};${NOCT[menu_text]}"
zstyle ':completion:*' group-name ''
zstyle ':completion:*' squeeze-slashes true
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "$_noct_cache/completion"
zstyle ':completion:*:descriptions' format "%F{${NOCT[line]}}──%f %F{${NOCT[glow]}}%d%f"
zstyle ':completion:*:messages' format "%F{${NOCT[dim]}}%d%f"
zstyle ':completion:*:warnings' format "%F{${NOCT[mute]}}nothing to complete%f"
zstyle ':completion:*:corrections' format "%F{${NOCT[yellow]}}%d (errors: %e)%f"
zstyle ':completion:*:default' list-prompt '%S%M matches%s'
unset _noct_state _noct_cache

bindkey -e
autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey '^[[A' up-line-or-beginning-search       # up/down search history for what's typed
bindkey '^[[B' down-line-or-beginning-search
bindkey '^[OA' up-line-or-beginning-search
bindkey '^[OB' down-line-or-beginning-search
bindkey '^[[1;5C' forward-word                   # ctrl+right / ctrl+left
bindkey '^[[1;5D' backward-word
bindkey '^[[H' beginning-of-line                 # home / end / delete
bindkey '^[[F' end-of-line
bindkey '^[[3~' delete-char
bindkey '^H' backward-kill-word                  # ctrl+backspace
bindkey -M menuselect '^[[Z' reverse-menu-complete

for _p in /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh \
          /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh; do
  [[ -r $_p ]] && { source "$_p"; break; }
done
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=${NOCT[faint]}"
ZSH_AUTOSUGGEST_STRATEGY=(history completion)

for _p in /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh \
          /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh; do
  [[ -r $_p ]] && { source "$_p"; break; }
done
unset _p
if (( ${+ZSH_HIGHLIGHT_STYLES} )); then
  ZSH_HIGHLIGHT_STYLES[default]="fg=${NOCT[text]}"
  ZSH_HIGHLIGHT_STYLES[command]="fg=${NOCT[glow]}"
  ZSH_HIGHLIGHT_STYLES[builtin]="fg=${NOCT[glow]}"
  ZSH_HIGHLIGHT_STYLES[alias]="fg=${NOCT[glow]}"
  ZSH_HIGHLIGHT_STYLES[function]="fg=${NOCT[glow]}"
  ZSH_HIGHLIGHT_STYLES[precommand]="fg=${NOCT[glow_hi]},italic"
  ZSH_HIGHLIGHT_STYLES[reserved-word]="fg=${NOCT[magenta]}"
  ZSH_HIGHLIGHT_STYLES[unknown-token]="fg=${NOCT[signal]}"
  ZSH_HIGHLIGHT_STYLES[path]="fg=${NOCT[text]},underline"
  ZSH_HIGHLIGHT_STYLES[path_prefix]="fg=${NOCT[dim]},underline"
  ZSH_HIGHLIGHT_STYLES[single-quoted-argument]="fg=${NOCT[yellow]}"
  ZSH_HIGHLIGHT_STYLES[double-quoted-argument]="fg=${NOCT[yellow]}"
  ZSH_HIGHLIGHT_STYLES[dollar-quoted-argument]="fg=${NOCT[yellow]}"
  ZSH_HIGHLIGHT_STYLES[single-hyphen-option]="fg=${NOCT[dim]}"
  ZSH_HIGHLIGHT_STYLES[double-hyphen-option]="fg=${NOCT[dim]}"
  ZSH_HIGHLIGHT_STYLES[globbing]="fg=${NOCT[magenta]}"
  ZSH_HIGHLIGHT_STYLES[redirection]="fg=${NOCT[mute]}"
  ZSH_HIGHLIGHT_STYLES[commandseparator]="fg=${NOCT[mute]}"
  ZSH_HIGHLIGHT_STYLES[comment]="fg=${NOCT[mute]},italic"
  ZSH_HIGHLIGHT_STYLES[assign]="fg=${NOCT[blue]}"
fi

if (( $+commands[eza] )); then
  alias ls='eza --group-directories-first --icons=auto'
  alias ll='eza -l --group-directories-first --icons=auto --git --time-style=relative --no-user'
  alias la='eza -la --group-directories-first --icons=auto --git --time-style=relative --no-user'
  alias lt='eza --tree --level=2 --icons=auto --group-directories-first'
else
  alias ls='ls --color=auto --group-directories-first'
  alias ll='ls -lh'
  alias la='ls -lah'
fi
alias grep='grep --color=auto'
alias diff='diff --color=auto'
alias ..='cd ..'
alias ...='cd ../..'

#   ~/code/noctiluca on  main +* ⇡1  took 3.2s
# ❯
setopt prompt_subst
autoload -Uz add-zsh-hook add-zle-hook-widget vcs_info
zmodload zsh/datetime

zstyle ':vcs_info:*' enable git
zstyle ':vcs_info:git:*' check-for-changes true
zstyle ':vcs_info:git:*' stagedstr '+'
zstyle ':vcs_info:git:*' unstagedstr '*'
zstyle ':vcs_info:git:*' formats '%b' '%c%u'
zstyle ':vcs_info:git:*' actionformats '%b|%a' '%c%u'

typeset -g _noct_started=0 _noct_took="" _noct_first=1

_noct_preexec() {
  _noct_started=$EPOCHREALTIME
  # after clear, no gap at the top
  [[ ${1[(w)1]} == (clear|reset) ]] && _noct_first=1
}

_noct_precmd() {
  local code=$?
  if (( _noct_first )); then _noct_first=0; else print; fi

  _noct_took=""
  if (( _noct_started > 0 )); then
    local s=$(( EPOCHREALTIME - _noct_started ))
    if (( s >= 2 )); then
      if (( s >= 60 )); then _noct_took="$(( ${s%.*} / 60 ))m $(( ${s%.*} % 60 ))s"
      else _noct_took="$(printf '%.1fs' $s)"; fi
    fi
    _noct_started=0
  fi

  vcs_info
  local git=""
  if [[ -n ${vcs_info_msg_0_} ]]; then
    git=" %F{${NOCT[mute]}}on%f %F{${NOCT[glow]}} ${vcs_info_msg_0_}%f"
    [[ -n ${vcs_info_msg_1_} ]] && git+=" %F{${NOCT[yellow]}}${vcs_info_msg_1_}%f"
    local ab
    ab=$(command git rev-list --left-right --count @{upstream}...HEAD 2>/dev/null)
    if [[ -n $ab ]]; then
      local behind=${ab%%[[:space:]]*} ahead=${ab##*[[:space:]]}
      (( ahead > 0 )) && git+=" %F{${NOCT[dim]}}⇡${ahead}%f"
      (( behind > 0 )) && git+=" %F{${NOCT[dim]}}⇣${behind}%f"
    fi
  fi

  local here=${(%):-%~} parent="" leaf
  if [[ $here == */* ]]; then parent="${here%/*}/"; leaf="${here##*/}"; else leaf=$here; fi

  local extra=""
  [[ -n $_noct_took ]] && extra+="  %F{${NOCT[mute]}}took ${_noct_took}%f"
  (( code != 0 )) && extra+="  %F{${NOCT[signal]}}exit ${code}%f"
  [[ -n $VIRTUAL_ENV ]] && extra+="  %F{${NOCT[dim]}}(${VIRTUAL_ENV:t})%f"
  [[ -n $SSH_CONNECTION ]] && extra="  %F{${NOCT[glow_hi]}}%n@%m%f${extra}"
  (( ${#jobstates} > 0 )) && extra+="  %F{${NOCT[mute]}}${#jobstates} in background%f"

  local arrow="%F{${NOCT[glow]}}❯%f"
  (( code != 0 )) && arrow="%F{${NOCT[signal]}}❯%f"
  _noct_full="%F{${NOCT[mute]}}${parent//\%/%%}%f%B%F{${NOCT[text]}}${leaf//\%/%%}%f%b${git}${extra}"$'\n'"${arrow} "
  _noct_short="%F{${NOCT[mute]}}❯%f "
  PROMPT=$_noct_full

  print -Pn "\e]2;%~\a"
}

_noct_transient() {
  [[ ${NOCTILUCA_TRANSIENT:-1} == 1 && $CONTEXT == start ]] || return
  PROMPT=$_noct_short
  zle .reset-prompt
}

_noct_title() { print -n "\e]2;${1[(w)1]}\a" }

add-zsh-hook preexec _noct_preexec
add-zsh-hook preexec _noct_title
add-zsh-hook precmd _noct_precmd
add-zle-hook-widget line-finish _noct_transient
RPROMPT=''

# skip it if your own .zshrc already runs fastfetch
_noct_rc_fetches() {
  local rc="${ZDOTDIR:-$HOME}/.zshrc" line
  [[ -r $rc ]] || return 1
  for line in "${(@f)$(<$rc)}"; do
    [[ $line == [[:space:]]#\#* ]] && continue
    [[ $line == *fastfetch* && $line != *NOCTILUCA_FASTFETCH* ]] && return 0
  done
  return 1
}
if [[ ${NOCTILUCA_FASTFETCH:-1} == 1 && $TERM == xterm-kitty && -z $SSH_CONNECTION && $SHLVL -le 1 ]] \
   && (( $+commands[fastfetch] )) && ! _noct_rc_fetches; then
  fastfetch
fi
unfunction _noct_rc_fetches
