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

interact_with_ollama() {
  local user_query="$1"
  local llm_base_url="$2"
  local llm_model="$3"

  if [[ -z "$user_query" ]]; then
    echo "Usage: interact_with_ollama \"your task description\""
    return 1
  fi

  local payload=$(cat <<EOF
{
  "model": "$llm_model",
  "messages": [
    {
      "role": "user",
      "content": "Generate shell commands for the following task: $user_query. Provide multiple relevant commands if available. Output in JSON format. The JSON needs to include a key named 'commands' with a list of commands."
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

