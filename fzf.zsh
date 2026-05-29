# fzf shell integration
# Enables three default keybindings:
#   CTRL-T  file picker (insert path into command line)
#   CTRL-R  history search
#   ALT-C   cd into directory
eval "$(fzf --zsh)"

# Use fd as the default find command (respects .gitignore, shows hidden files)
export FZF_DEFAULT_COMMAND='fd --hidden --follow --exclude .git'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'

# Global fzf UI: reverse layout (input at top), half-height, bordered
export FZF_DEFAULT_OPTS='--layout=reverse --height=50% --border'

# CTRL-T: file picker with preview
#   Enter    open in vim
#   Ctrl-V   open in VSCode
#   Ctrl-O   reveal in Finder (or open if file)
export FZF_CTRL_T_OPTS="
  --preview '~/.oh-my-zsh/custom/scripts/fx-preview.sh {}'
  --preview-window right:60%:wrap
  --bind 'enter:become(vim {})'
  --bind 'ctrl-v:execute(code {})'
  --bind 'ctrl-o:execute([ -d {} ] && open {} || open -R {})'
  --header 'Enter:vim  Ctrl-V:VSCode  Ctrl-O:Finder'
"

# ALT-C: directory picker with tree preview
export FZF_ALT_C_OPTS="
  --preview 'tree -L 2 -C {} 2>/dev/null || ls -la {}'
  --preview-window right:60%
"

# CTRL-R: history search with optional preview (toggle with Ctrl-/)
export FZF_CTRL_R_OPTS="
  --preview 'echo {}'
  --preview-window up:3:hidden:wrap
  --bind 'ctrl-/:toggle-preview'
"

# --- Completion (** trigger) ---
# Override the paths/dirs fzf uses when completing with ** e.g. vim **<TAB>
_fzf_compgen_path() {
  fd --hidden --follow --exclude ".git" . "$1"
}

_fzf_compgen_dir() {
  fd --type d --hidden --follow --exclude ".git" . "$1"
}

export FZF_COMPLETION_OPTS='--border --info=inline'
export FZF_COMPLETION_PATH_OPTS='--walker file,dir,follow,hidden'
export FZF_COMPLETION_DIR_OPTS='--walker dir,follow'

# Per-command completion previews (triggered by ** e.g. cd **<TAB>)
_fzf_comprun() {
  local command=$1
  shift
  case "$command" in
    cd)           fzf --preview 'tree -L 2 -C {} 2>/dev/null || ls -la {}' "$@" ;;
    export|unset) fzf --preview "eval 'echo \$'{}" "$@" ;;
    ssh)          fzf --preview 'dig {}' "$@" ;;
    *)            fzf --preview '~/.oh-my-zsh/custom/scripts/fx-preview.sh {}' "$@" ;;
  esac
}

# --- Live ripgrep search (CTRL-G) ---
# Searches file contents in real time; preview highlights the matched line.
# rg outputs file:line:content → fzf splits on ':' → preview receives file:line
#   Enter    open in vim at matched line
#   Ctrl-V   open in VSCode at matched line
_fzf_rg() {
  local selected
  selected=$(
    rg --line-number --no-heading --color=always --smart-case "${*:-}" 2>/dev/null |
      fzf --ansi \
          --delimiter ':' \
          --preview '~/.oh-my-zsh/custom/scripts/fx-preview.sh {1}:{2}' \
          --preview-window 'right:60%:+{2}+3/3:wrap' \
          --bind 'change:reload:rg --line-number --no-heading --color=always --smart-case {q} 2>/dev/null || true' \
          --bind 'ctrl-v:become(echo vscode:{1}:{2})' \
          --header 'Enter:vim  Ctrl-V:VSCode'
  ) || return

  if [[ $selected == vscode:* ]]; then
    local rest=${selected#vscode:}
    local file=${rest%%:*}
    local line=${rest#*:}
    code --goto "$file:$line"
  else
    local file=${selected%%:*}
    local line=${selected#*:}
    line=${line%%:*}
    vim +"$line" "$file"
  fi
}
zle -N _fzf_rg
bindkey '^G' _fzf_rg
