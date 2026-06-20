#############################################
# CAF Plugin: Web Search
# Provides: search, fetch_url
#############################################

plugin_web_search_init() {
  register_tool "search"     "tool_search"
  register_tool "fetch_url"  "tool_fetch_url"
  return 0
}

#############################################
# Search the web via DuckDuckGo
#############################################
tool_search() {
  local query="$1"
  local num="${2:-$CAF_MAX_SEARCH_RESULTS}"
  local backend="${CAF_SEARCH_BACKEND:-duckduckgo}"

  case "$backend" in
    duckduckgo)
      _duckduckgo_search "$query" "$num"
      ;;
    searxng)
      _searxng_search "$query" "$num"
      ;;
    *)
      _duckduckgo_search "$query" "$num"
      ;;
  esac
}

_duckduckgo_search() {
  local query="$1"
  local num="$2"

  log_info "Searching DuckDuckGo for: $query"

  local encoded
  encoded=$(printf '%s' "$query" | jq -sRr @uri)

  local results
  results=$(curl -s "https://html.duckduckgo.com/html/?q=${encoded}" \
    -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64) CAF/1.0" 2>/dev/null)

  if [ -z "$results" ]; then
    log_warn "No search results returned"
    echo "[]"
    return 1
  fi

  # Extract results from DuckDuckGo HTML
  echo "$results" | sed -n '
    /<a rel="nofollow" class="result__a" href="[^"]*">/{
      s/.*href="\([^"]*\)".*>\(.*\)<\/a>.*/\1|\2/
      s/<[^>]*>//g
      p
    }
  ' | head -n "$num" | while IFS='|' read -r url title; do
    title=$(echo "$title" | sed 's/&amp;/\&/g; s/&lt;/</g; s/&gt;/>/g; s/&quot;/"/g; s/&#39;/'"'"'/g')
    echo "  [$title]($url)"
  done

  echo ""
  echo "Raw results saved for tool consumption."
  # Save structured results for the agent
  echo "$results" | sed -n '
    /<a rel="nofollow" class="result__a" href="[^"]*">/{
      s/.*href="\([^"]*\)".*>\(.*\)<\/a>.*/\1||\2/
      s/<[^>]*>//g
      p
    }
  ' | head -n "$num" | jq -R -s 'split("\n") | map(select(length > 0) | split("||") | {url: .[0], title: .[1]})' > /tmp/caf_search_results.json 2>/dev/null

  return 0
}

_searxng_search() {
  local query="$1"
  local num="$2"
  local url="${CAF_SEARXNG_URL}/search?q=$(printf '%s' "$query" | jq -sRr @uri)&format=json"

  curl -s "$url" | jq -r '.results[:'"$num"'] | .[] | "  [\(.title)](\(.url))"'
}

#############################################
# Fetch a URL and return its contents
#############################################
tool_fetch_url() {
  local url="$1"
  local max_chars="${2:-10000}"
  local timeout="${3:-15}"

  if [ -z "$url" ]; then
    log_error "fetch_url: URL required"
    return 1
  fi

  log_info "Fetching: $url"

  local content
  content=$(curl -sL --max-time "$timeout" \
    -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64) CAF/1.0" \
    "$url" 2>/dev/null | head -c "$max_chars")

  local length
  length=$(echo "$content" | wc -c)

  # Strip HTML tags for readability
  echo "$content" | sed 's/<[^>]*>//g; s/&amp;/\&/g; s/&lt;/</g; s/&gt;/>/g; s/&nbsp;/ /g' | head -c "$max_chars"

  log_info "Fetched $length bytes from $url"
  return 0
}

#############################################
# Register plugin
#############################################
plugin_web_search_init
