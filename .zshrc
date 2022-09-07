# zsh config

HISTFILE=~/.zsh/histfile
HISTSIZE=1000
SAVEHIST=10000

bindkey -v

unsetopt beep
zstyle :compinstall filename '$HOME/.zshrc'
autoload -Uz compinit
compinit

# prompt

if (( $+commands[git] ))
then
  git="$commands[git]"
else
  git="/usr/bin/git"
fi

git_branch() {
  echo $($git symbolic-ref HEAD 2>/dev/null | awk -F/ {'print $NF'})
}
git_prompt_info () {
  ref=$($git symbolic-ref HEAD 2>/dev/null) || return
  echo "${ref#refs/heads/}"
}

git_dirty() {
  if $(! $git status -s &> /dev/null)
  then
    echo ""
  else
    if [[ $($git status --porcelain) == "" ]]
    then
      echo "| %F{yellow} $(git_prompt_info)%f "
    else
      echo "| %F{yellow} $(git_prompt_info)*%f "
    fi
  fi
}

folders() {
  echo $(($(ls -la | grep ^d | wc -l)-2))
}
files() {
  echo $(ls -la | grep ^- | wc -l)
}

precmd() { print -rP " %F{45} %~ ( $(folders),  $(files))%f $(git_dirty)| %F{1} %n%f" }
PROMPT=" %F{48}%f "

# aliases

alias ls="exa -la"
alias dotfiles="/usr/bin/git --git-dir=$HOME/.dotfiles --work-tree=$HOME"
eval "$(thefuck --alias)"
