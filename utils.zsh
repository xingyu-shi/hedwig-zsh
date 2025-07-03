#!/usr/bin/env zsh

# Function to detect the operating system
detect_os() {
    case "$(uname -s)" in
        Linux*)     echo "linux";;
        Darwin*)    echo "mac";;
        CYGWIN*)    echo "windows";;
        MINGW*)     echo "windows";;
        *)          echo "unknown";;
    esac
}

# Function to get OS-specific package manager command
get_package_manager_install_cmd() {
    local os=$(detect_os)
    case "$os" in
        "linux")
            if command -v apt-get &> /dev/null; then
                echo "sudo apt-get install -y"
            elif command -v dnf &> /dev/null; then
                echo "sudo dnf install -y"
            elif command -v yum &> /dev/null; then
                echo "sudo yum install -y"
            elif command -v pacman &> /dev/null; then
                echo "sudo pacman -S --noconfirm"
            else
                echo "unknown"
            fi
            ;;
        "mac")
            if command -v brew &> /dev/null; then
                echo "brew install"
            else
                echo "unknown"
            fi
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# Function to check if a command exists and suggest installation
check_command() {
    local cmd="$1"
    local package_name="${2:-$1}"  # Use first argument as package name if second is not provided
    
    if ! command -v "$cmd" &> /dev/null; then
        local install_cmd=$(get_package_manager_install_cmd)
        if [ "$install_cmd" = "unknown" ]; then
            echo "🚨 $cmd not found! Please install it manually."
        else
            echo "🚨 $cmd not found! You can install it with: $install_cmd $package_name"
        fi
        return 1
    fi
    return 0
}

check_llm_running() {
  local url="$1"

  if [[ -z "$url" ]]; then
    echo "🚨 please provide a valid base url of llm service"
    return 1
  fi

  # 使用 curl 检查 URL 返回状态码
  local status_code
  status_code=$(curl -s -o /dev/null -w "%{http_code}" "$url")

  if [[ "$status_code" == "200" ]]; then
    return 0
  else
    echo "🚨 LLM service unavailable, status code:($status_code)"
  fi
}

# Extract potential tab completions for the current prefix
get_tab_completion_context() {
  local current_prefix="$1"
  if [[ -z "$current_prefix" ]]; then
    echo ""
    return
  fi
  local suggestions=$(compgen -A command -- "$current_prefix" | awk '!seen[$0]++' | tr '\n' ' ')
  echo "$suggestions"
}

get_history_context() {
    # Include the deduplicated history commands as context if available with history command
  local history_commands=$(fc -l -n 1 | grep -v '^#' | grep -v '^$' | tail -n 30 | sed 's/"/\\"/g' | awk '!seen[$0]++' | awk '{print "#" NR "#" $0}' | tr '\n' ' ')
  # local history_commands=$(history | sed 's/^ *[0-9]* *//' | grep -v '^$' )
  echo "$history_commands"
}

interact_with_ollama() {
  local user_query="$1"
  local llm_base_url="$2"
  local llm_model="$3"

  if [[ -z "$user_query" ]]; then
    echo "Usage: interact_with_ollama \"your task description\""
    return 1
  fi
  if [[ -z "$llm_base_url" ]]; then
    echo "🚨 Please provide a valid base URL for the LLM service."
    return 1
  fi
  if [[ -z "$llm_model" ]]; then
    echo "🚨 Please provide a valid model name for the LLM service."
    return 1
  fi
  
  local history_commands=$(get_history_context)
  
  local payload=$(cat <<EOF
{
  "model": "$llm_model",
  "messages": [
    {
      "role": "user",
      "content": "You are an intelligent shell assistant. Based on the current user command "$user_query" and the shell history "$history_commands", infer and generate the most likely complete and executable shell command(s) the user intends to run. Use history to understand context and fill in missing parts. Suggest multiple possible commands if needed. Output a compact one-line JSON object: {"commands": ["command1", "command2", ...]}. Do not include comments or explanations."
    }
  ]
}
EOF
)

  local content=$(curl -s -X POST "$llm_base_url/v1/chat/completions" \
    -H "Content-Type: application/json" \
    -d "$payload" | jq -c '.' | jq -r '.choices[0].message.content // empty')

  
  if [[ -z "$content" ]]; then
    echo "❌ No content found in the response. Please check the LLM service."
    return 1
  fi

  # 提取 JSON 内容（markdown-wrapped block）
  local json_block=$(echo "$content" | sed -n '/```json/,/```/p' | sed '1d;$d')

  if [[ -z "$json_block" ]]; then
    echo "⚠️ No markdown-wrapped JSON content found. Original output:"
    echo "$content"
    return 1
  fi

  # 提取 commands 列表
  local commands=$(echo "$json_block" | jq -r '.commands[]?')

  if [[ -z "$commands" ]]; then
    echo "⚠️ No 'commands' field found in JSON. Original content:"
    echo "$json_block"
    return 1
  fi

  echo "✅ Retrieved commands: "
  echo "$commands"
}

