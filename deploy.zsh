#!/bin/zsh
# move the files under current directory to the plugin directory ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/hedwig-zsh
# Switch to the directory where this script is
PLUGIN_DIR="$(cd "$(dirname "${(%):-%N}")" && pwd)"
# Copy the files to the plugin directory
# Create the plugin directory if it doesn't exist
ROOT_DIR="${ZSH_CUSTOM:-/Users/xingyushi/.oh-my-zsh/custom}/plugins/hedwig-zsh"
mkdir -p "$ROOT_DIR"
# Copy the files to the plugin directory
cp "$PLUGIN_DIR/hedwig.zsh" "$ROOT_DIR/hedwig.zsh"
cp "$PLUGIN_DIR/utils.zsh" "$ROOT_DIR/utils.zsh"
cp "$PLUGIN_DIR/hedwig-zsh.plugin.zsh" "$ROOT_DIR/hedwig-zsh.plugin.zsh"