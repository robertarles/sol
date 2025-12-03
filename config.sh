#!/usr/bin/env bash
echo "source, do not execute"

eval "$(mise activate zsh)"
eval "$(rbenv init -)"
ruby --version
