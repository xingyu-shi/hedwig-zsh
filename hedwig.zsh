# default shortcut as Ctrl-o
(( ! ${+HEDWIGZSH_HOTKEY} )) && typeset -g HEDWIGZSH_HOTKEY='^o'
# default ollama model as qwen2.5-coder:3b
(( ! ${+HEDWIGZSH_MODEL} )) && typeset -g HEDWIGZSH_MODEL='gemma3:latest'
# default response number as 5
(( ! ${+HEDWIGZSH_COMMAND_COUNT} )) && typeset -g HEDWIGZSH_COMMAND_COUNT='5'
# default ollama server host
(( ! ${+HEDWIGZSH_URL} )) && typeset -g HEDWIGZSH_URL='http://localhost:11434'
# default ollama time to keep the server alive
(( ! ${+HEDWIGZSH_KEEP_ALIVE} )) && typeset -g HEDWIGZSH_KEEP_ALIVE='1h'

# Source utility functions
source "${0:A:h}/utils.zsh"

# Set up logging with proper permissions
HEDWIGZSH_LOG_FILE="/tmp/hedwigzsh_debug.log"
touch "$HEDWIGZSH_LOG_FILE"
chmod 666 "$HEDWIGZSH_LOG_FILE"

log_debug() {
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  {
    echo "[${timestamp}] $1"
    if [ -n "$2" ]; then
      echo "Data: $2"
      echo "----------------------------------------"
    fi
  } >> "$HEDWIGZSH_LOG_FILE" 2>&1
}

validate_required() {
  # Check required tools are installed
  check_command "jq" || return 1
  check_command "fzf" || return 1
  check_command "curl" || return 1
  
  # Check if Ollama is running
  check_llm_running $HEDWIGZSH_URL || return 1
  
  # Check if the specified model exists
  if ! curl -s "${HEDWIGZSH_URL}/api/tags" | grep -q $HEDWIGZSH_MODEL; then
    echo "🚨 Model ${HEDWIGZSH_MODEL} not found!"
    echo "Please pull it with: ollama pull ${HEDWIGZSH_MODEL}"
    return 1
  fi
}

function get_completions_for() {
  emulate -L zsh
  setopt extended_glob

  local input="$1"
  local -a completions
  
  # Create a temporary file to store completions
  local tmp_file=$(mktemp)
  
  # Create a function to capture completions
  _hedwig_capture_comps() {
    local -a reply
    reply=()
    
    # Set up completion context
    BUFFER="$input"
    CURSOR=${#BUFFER}
    
    # Use compstate to properly initialize completion
    compstate[insert]=menu
    
    # Generate completions without calling _main_complete directly
    zle expand-or-complete
    
    # Save the completions
    print -l -- "${reply[@]}" > $tmp_file
  }
  
  # Create a widget for our function
  zle -N _hedwig_capture_comps
  
  # Call the widget in a clean environment
  {
    # Temporarily override compadd to capture completions
    functions[_original_compadd]=$functions[compadd]
    compadd() {
      reply+=("$@")
      _original_compadd "$@"
    }
    
    # Execute the widget
    _hedwig_capture_comps
    
    # Restore original compadd
    functions[compadd]=$functions[_original_compadd]
    unfunction _original_compadd
  } 2>/dev/null
  
  # Read completions from the temporary file
  completions=("${(@f)$(<$tmp_file)}")
  rm -f $tmp_file
  
  log_debug $completions
  print -l -- $completions
}

fzf_hedwigzsh() {
  setopt extendedglob
  validate_required
  if [ $? -eq 1 ]; then
    return 1
  fi

  HEDWIGZSH_USER_QUERY=$BUFFER
  local completions_output=$(get_completions_for "$HEDWIGZSH_USER_QUERY")
  log_debug "get_completions_for $HEDWIGZSH_USER_QUERY:"
  log_debug "$completions_output"

  zle end-of-line
  zle reset-prompt

  print
  print -u1 "💭Please wait..."

  # Export necessary environment variables to be used by the python script

  # Get absolute path to the script directory
  HEDWIGZSH_COMMANDS=$( interact_with_ollama "$HEDWIGZSH_USER_QUERY" "$HEDWIGZSH_URL" "$HEDWIGZSH_MODEL")
  
  # Check if the command was successful and that the commands is an array
  if [ $? -ne 0 ] || [ -z "$HEDWIGZSH_COMMANDS" ]; then
    log_debug "Failed to parse commands"
    echo "Error: Failed to parse commands"
    echo "Raw response:"
    echo "$HEDWIGZSH_COMMANDS"
    return 0
  fi
  
  log_debug "Extracted commands:" "$HEDWIGZSH_COMMANDS"

  tput cuu 1 # cleanup waiting message

  # Use echo to pipe the commands to fzf
  HEDWIGZSH_SELECTED=$(echo "$HEDWIGZSH_COMMANDS" | fzf --ansi --height=~10 --cycle)
  if [ -n "$HEDWIGZSH_SELECTED" ]; then
    BUFFER="$HEDWIGZSH_SELECTED"
    CURSOR=${#BUFFER}  # Move cursor to end of buffer
    
    # Ensure we're not accepting the line
    zle -R
    zle reset-prompt
    
    log_debug "Selected command:" "$HEDWIGZSH_SELECTED"
  else
    log_debug "No command selected"
  fi
  
  return 0
}

autoload -U fzf_hedwigzsh
zle -N fzf_hedwigzsh
bindkey "$HEDWIGZSH_HOTKEY" fzf_hedwigzsh
