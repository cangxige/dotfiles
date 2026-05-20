# Zsh plugin list (managed by dotfiles).
# Missing plugins are skipped so this config can boot on minimal/offline hosts.

typeset -a _dotfiles_requested_plugins
typeset -a plugins

if [[ -n "${DOTFILES_ZSH_PLUGINS:-}" ]]; then
  _dotfiles_requested_plugins=(${=DOTFILES_ZSH_PLUGINS})
else
  _dotfiles_requested_plugins=(
    git
    z
    zsh-autosuggestions
    zsh-syntax-highlighting
  )
fi

plugins=()
for _dotfiles_plugin in "${_dotfiles_requested_plugins[@]}"; do
  if [[ -d "${ZSH:-$HOME/.oh-my-zsh}/plugins/$_dotfiles_plugin" ||
        -d "${ZSH_CUSTOM:-${ZSH:-$HOME/.oh-my-zsh}/custom}/plugins/$_dotfiles_plugin" ]]; then
    plugins+=("$_dotfiles_plugin")
  fi
done

unset _dotfiles_plugin _dotfiles_requested_plugins
