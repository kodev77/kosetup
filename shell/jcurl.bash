# jcurl — curl + jq for poking JSON APIs from the terminal (the Postman replacement).
# The status/timing line goes to STDERR via curl's %{stderr} write-out, so only the
# response body reaches the pipe and jq never chokes on it. Everything you pass is
# handed straight to curl: -k, -H, -d, -X, --cookie all behave normally.
# NOT named `jc`: that's a real Debian package (JSON Convert), and a shell function
# would silently shadow the binary if it were ever installed.
#   jcurl https://jsonplaceholder.typicode.com/users/1
#   jcurl -X POST "$URL" -H 'Content-Type: application/json' -d '{"a":1}'
#   jcurl -k https://localhost:8443/api/stages
#   jcurl https://dummyjson.com/http/500      # any status code, for error-path testing
jcurl() {
  local fmt="%{stderr}← %{http_code} · %{time_total}s · %{size_download}B\n"
  # Drop the colour codes when stderr isn't a tty, so 2>file stays clean.
  [ -t 2 ] && fmt="%{stderr}"$'\033[2m'"← %{http_code} · %{time_total}s · %{size_download}B"$'\033[0m'"\n"
  curl -sS -H 'Accept: application/json' -w "$fmt" "$@" | jq
}
