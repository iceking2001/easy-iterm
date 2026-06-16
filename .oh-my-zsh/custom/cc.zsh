# cc - Claude Code launcher with composable sub-options
#
# Replaces the old cc / cc-danger / cc-gitrepo / cc-proxy aliases with a single
# dispatcher. Leading sub-options are consumed and accumulated (order-independent);
# the first non-sub-option word and everything after it is passed straight to claude.
#
#   cc                       -> claude
#   cc gitrepo               -> claude --add-dir <repo>
#   cc danger gitrepo proxy  -> all three combined
#   cc gitrepo "fix the bug" -> claude --add-dir <repo> "fix the bug"
#   cc continue              -> claude --continue
#   cc resume [id]           -> claude --resume [id]   (interactive picker if no id)
#   cc model-opus            -> claude --model "opus[1m]"
#   cc model-sonnet          -> claude --model "sonnet[1m]"
#
# NOTE: remove any `alias cc=...` from ~/.zshrc, otherwise the alias shadows this
# function and sub-options will not be recognized.
cc() {
  local -a flags envs
  local _cc_proxy="http://cnnjproxy-gfw.tw.trendnet.org:8080"
  while (( $# )); do
    case "$1" in
      danger)       flags+=(--allow-dangerously-skip-permissions --permission-mode bypassPermissions) ;;
      gitrepo)      flags+=(--add-dir /Users/henry_lou/Workspace/gitrepo) ;;
      proxy)        envs+=(HTTPS_PROXY=$_cc_proxy HTTP_PROXY=$_cc_proxy) ;;
      continue)     flags+=(--continue) ;;
      resume)       flags+=(--resume) ;;
      # NOTE: opus[1m]/sonnet[1m] MUST stay quoted. Unquoted, zsh treats the bare
      # [1m] as a glob (a char class) and aborts with "no matches found: sonnet[1m]".
      model-opus)   flags+=(--model "opus[1m]") ;;
      model-sonnet) flags+=(--model "sonnet[1m]") ;;
      *)            break ;;   # first non-sub-option: stop, pass the rest through
    esac
    shift
  done
  env "${envs[@]}" claude "${flags[@]}" "$@"
}
