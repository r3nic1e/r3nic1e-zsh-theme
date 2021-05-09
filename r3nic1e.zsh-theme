# vim:ft=zsh ts=2 sw=2 sts=2

CURRENT_BG='NONE'

case ${SOLARIZED_THEME:-dark} in
    light) CURRENT_FG='white';;
    *)     CURRENT_FG='black';;
esac

# Special Powerline characters

() {
  local LC_ALL="" LC_CTYPE="en_US.UTF-8"
  # NOTE: This segment separator character is correct.  In 2012, Powerline changed
  # the code points they use for their special characters. This is the new code point.
  # If this is not working for you, you probably have an old version of the
  # Powerline-patched fonts installed. Download and install the new version.
  # Do not submit PRs to change this unless you have reviewed the Powerline code point
  # history and have new information.
  # This is defined using a Unicode escape sequence so it is unambiguously readable, regardless of
  # what font the user is viewing this source code in. Do not replace the
  # escape sequence with a single literal character.
  # Do not change this! Do not make it '\u2b80'; that is the old, wrong code point.
  SEGMENT_SEPARATOR=$'\ue0b0'
  SEGMENT_RIGHT_SEPARATOR=$'\ue0b2'
}

# Begin a segment
# Takes two arguments, background and foreground. Both can be omitted,
# rendering default background/foreground.
prompt_segment() {
  local bg fg
  [[ -n $1 ]] && bg="%K{$1}" || bg="%k"
  [[ -n $2 ]] && fg="%F{$2}" || fg="%f"
  if [[ $CURRENT_BG != 'NONE' && $1 != $CURRENT_BG ]]; then
    echo -n " %{$bg%F{$CURRENT_BG}%}$SEGMENT_SEPARATOR%{$fg%} "
  else
    echo -n "%{$bg%}%{$fg%} "
  fi
  CURRENT_BG=$1
  [[ -n $3 ]] && echo -n $3
}

# Begin a segment
# Takes two arguments, background and foreground. Both can be omitted,
# rendering default background/foreground.
prompt_right_segment() {
  local bg fg
  [[ -n $1 ]] && bg="%K{$1}" || bg="%k"
  [[ -n $1 ]] && pbg="%F{$1}" || pbg="%f"
  [[ -n $2 ]] && fg="%F{$2}" || fg="%f"
  echo -n " %{$pbg%K{$CURRENT_BG}%}$SEGMENT_RIGHT_SEPARATOR%{$bg$fg%} "
  CURRENT_BG=$1
  [[ -n $3 ]] && echo -n $3
}

# End the prompt, closing any open segments
prompt_end() {
  if [[ -n $CURRENT_BG ]]; then
    echo -n " %{%k%F{$CURRENT_BG}%}$SEGMENT_SEPARATOR"
  else
    echo -n "%{%k%}"
  fi
  echo -n "%{%f%}"
  CURRENT_BG=''
}

# Open the prompt
prompt_right_start() {
  CURRENT_BG='black'
}

# Git: branch/detached head, dirty status
prompt_git() {
  (( $+commands[git] )) || return
  if [[ "$(git config --get oh-my-zsh.hide-status 2>/dev/null)" = 1 ]]; then
    return
  fi
  local PL_BRANCH_CHAR
  () {
    local LC_ALL="" LC_CTYPE="en_US.UTF-8"
    PL_BRANCH_CHAR=$'\ue0a0'         # 
  }
  local ref dirty mode repo_path

  if [[ "$(git rev-parse --is-inside-work-tree 2>/dev/null)" = "true" ]]; then
    repo_path=$(git rev-parse --git-dir 2>/dev/null)
    dirty=$(parse_git_dirty)
    ref="➦ $(git describe --tags --exact-match 2> /dev/null)" || ref="➦ $(git symbolic-ref -q --short HEAD 2>/dev/null)" || "➦ $(git rev-parse --short HEAD 2> /dev/null)"
    if [[ -n $dirty ]]; then
      prompt_segment 92 black
    else
      prompt_segment 24 $CURRENT_FG
    fi

    if [[ -e "${repo_path}/BISECT_LOG" ]]; then
      mode=" <B>"
    elif [[ -e "${repo_path}/MERGE_HEAD" ]]; then
      mode=" >M<"
    elif [[ -e "${repo_path}/rebase" || -e "${repo_path}/rebase-apply" || -e "${repo_path}/rebase-merge" || -e "${repo_path}/../.dotest" ]]; then
      mode=" >R>"
    fi

    setopt promptsubst
    autoload -Uz vcs_info

    zstyle ':vcs_info:*' enable git
    zstyle ':vcs_info:*' get-revision true
    zstyle ':vcs_info:*' check-for-changes true
    zstyle ':vcs_info:*' stagedstr '✚'
    zstyle ':vcs_info:*' unstagedstr '±'
    zstyle ':vcs_info:*' formats ' %u%c'
    zstyle ':vcs_info:*' actionformats ' %u%c'
    vcs_info
    echo -n "${ref/refs\/heads\//$PL_BRANCH_CHAR }${vcs_info_msg_0_%% }${mode}"
  fi
}

# Dir: current working directory
prompt_dir() {
  prompt_segment 240 $CURRENT_FG '%~'
}

# Status:
# - was there an error
# - am I root
# - are there background jobs?
prompt_status() {
  local -a symbols

  [[ $RETVAL -ne 0 ]] && symbols+="%{%F{red}%}✘ $RETVAL "
  [[ $UID -eq 0 ]] && symbols+="%{%F{yellow}%}⚡"
  [[ $(jobs -l | wc -l) -gt 0 ]] && symbols+="%{%F{cyan}%}⚙"

  [[ -n "$symbols" ]] && prompt_segment black default "$symbols"
}

# Get current kubectl context
prompt_kubernetes() {
  (( $+commands[kubectl] )) || return

  local context
  context="$(kubectl config current-context 2> /dev/null)"
  namespace="$(kubectl config get-contexts $context --no-headers 2> /dev/null | awk '{print $5}')"

  prompt_segment 32 $CURRENT_FG "⎈ $namespace@$context"
}

prompt_battery() {
  battery_pct=$(battery_pct_remaining)
  if battery_is_charging; then
    prompt_right_segment 22 $CURRENT_FG "⚡$(battery_pct)%%"
    return
  fi

  local color
  if [[ $battery_pct -gt 50 ]]; then
    color="22"
  elif [[ $battery_pct -gt 20 ]]; then
    color="yellow"
  else
    color="red"
  fi

  prompt_right_segment $color $CURRENT_FG "🔋$(battery_pct)%% $(battery_time_remaining)"
}

prompt_time() {
  prompt_right_segment 240 $CURRENT_FG "%*"
}

## Main prompt
build_prompt() {
  RETVAL=$?
  prompt_git
  prompt_kubernetes
  prompt_dir
  prompt_status
  prompt_end
}

## Right prompt
build_rprompt() {
  prompt_right_start
  prompt_battery
  prompt_time
}

PROMPT='%{%f%b%k%}$(build_prompt)
❯ '
RPROMPT='%{%f%b%k%}$(build_rprompt) '
