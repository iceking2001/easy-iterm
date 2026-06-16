# Completion / menu-selection key bindings
#
# Goal: one Tab on an ambiguous completion drops straight into an interactive,
# arrow-navigable highlight menu, and ESC cancels that menu.
#
# Background / why this is needed:
#   - oh-my-zsh sets `zstyle ':completion:*' menu select` (interactive menu) plus
#     `setopt auto_menu`. With auto_menu the menu only starts on the *second* Tab;
#     the first Tab just prints a passive listing. During that listing the line is
#     still in the main keymap, where the `sudo` plugin owns `^[^[` (double-ESC ->
#     prepend sudo). So pressing ESC on the first-Tab listing toggled sudo instead
#     of cancelling -- ESC never reached the menuselect binding below.
#   - MENU_COMPLETE makes menu completion start on the *first* Tab; combined with
#     `menu select` the first Tab now enters the `menuselect` keymap, where the sudo
#     plugin has no binding and ESC cancels cleanly.
#
# Tab itself stays bound to fzf-completion (see fzf.zsh), so the `**<Tab>` fzf
# trigger keeps working; MENU_COMPLETE only affects fzf's fallback completion path.
zmodload zsh/complist
setopt MENU_COMPLETE

# Inside the menuselect keymap, ESC -> send-break aborts the menu and restores the
# command line. ESC shares its first byte with the arrow-key escape sequences
# (^[[A, ^[OA, ...), so a lone ESC waits up to $KEYTIMEOUT (currently 400ms) before
# firing. Lowering KEYTIMEOUT makes ESC snappier but also tightens the sudo
# double-ESC window, so it is intentionally left untouched here.
bindkey -M menuselect '\e' send-break
