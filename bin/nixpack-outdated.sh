#!/usr/bin/env bash
set -euo pipefail

# Check argument count first (avoids unbound variable error)
if [[ $# -ne 1 ]]; then
  echo "Usage: $0 path/to/sources.csv" >&2
  exit 1
fi

CSV_FILE="$1"

# Check file exists
if [[ ! -e "$CSV_FILE" ]]; then
  echo "Error: File does not exist: $CSV_FILE" >&2
  exit 1
fi

# Ensure it's a regular file
if [[ ! -f "$CSV_FILE" ]]; then
  echo "Error: Not a regular file: $CSV_FILE" >&2
  exit 1
fi

# Ensure file is readable
if [[ ! -r "$CSV_FILE" ]]; then
  echo "Error: File is not readable: $CSV_FILE" >&2
  exit 1
fi

echo "Using CSV file: $CSV_FILE"

while IFS=, read -r name owner repo branch rev; do
  # skip header or empty lines
  [ -z "$name" ] && continue
  [[ "$name" == "name" ]] && continue

  remote_rev=$(git ls-remote "git@github.com:${owner}/${repo}" "refs/heads/${branch}" | cut -f1)

  if [ -z "$remote_rev" ]; then
    echo "Warning: could not fetch branch $branch for $owner/$repo"
    continue
  fi

  if [ "$remote_rev" != "$rev" ]; then
    echo "OUTDATED: $name: https://github.com/${owner}/${repo}/commits/${branch} $remote_rev"
  else
    echo "LATEST: $name: https://github.com/${owner}/${repo}/commits/${branch} $remote_rev"
  fi
done < "$CSV_FILE"
