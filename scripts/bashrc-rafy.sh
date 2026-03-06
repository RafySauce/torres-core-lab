figlet -c "$(hostname)"

case $- in
    *i*) ;;
      *) return;;
esac

HISTCONTROL=ignoreboth
shopt -s histappend
HISTSIZE=1000
HISTFILESIZE=2000
shopt -s checkwinsize

force_color_prompt=yes

if [ "$force_color_prompt" = yes ]; then
    PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
else
    PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
fi
unset force_color_prompt

if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
fi

RAINBOW=(
  '\e[1;31m'
  '\e[1;33m'
  '\e[1;32m'
  '\e[1;36m'
  '\e[1;34m'
  '\e[1;35m'
)

LABELS=("🖥️  Host:" "📦  Uptime:" "🧠  Memory:" "💾  Disk:" "🌐  IP:")
VALUES=(
  "$(hostname)"
  "$(uptime -p)"
  "$(free -h | awk '/Mem:/ {print $3 " / " $2}')"
  "$(df -h / | awk 'NR==2 {print $3 " / " $2 " used"}')"
  "$(hostname -I | awk '{print $1}')"
)

echo ""
for i in "${!LABELS[@]}"; do
  COLOR=${RAINBOW[$((i % ${#RAINBOW[@]}))]}
  echo -e "${COLOR}${LABELS[$i]} \e[1;37m${VALUES[$i]}\e[0m"
done
echo ""

alias ll='ls -alF'
alias gs='git status'
alias update='sudo apt update && sudo apt upgrade'

export PATH=$PATH:/usr/sbin
```

Commit and push it. Then get me the raw GitHub URL — it'll look like:
```
https://raw.githubusercontent.com/RafySauce/torres-core-lab/main/scripts/bashrc-rafy.sh