#!/bin/zsh
# move the files under current directory to the plugin directory ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/hedwig-zsh
# Switch to the directory where this script is
PLUGIN_DIR="$(cd "$(dirname "${(%):-%N}")" && pwd)"
# Copy the files to the plugin directory
# Create the plugin directory if it doesn't exist
mkdir -p "${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/hedwig-zsh"
# Copy the files to the plugin directory
cp "$PLUGIN_DIR/hedwig.zsh" "${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/hedwig-zsh/hedwig.zsh"
cp "$PLUGIN_DIR/utils.zsh" "${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/hedwig-zsh/utils.zsh"
cp "$PLUGIN_DIR/hedwigzsh.plugin.zsh" "${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/hedwig-zsh/hedwigzsh.plugin.zsh"