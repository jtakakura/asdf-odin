#!/usr/bin/env bash

set -euo pipefail

GH_REPO="https://github.com/odin-lang/Odin"
TOOL_NAME="odin"
TOOL_TEST="odin version"

fail() {
  echo -e "asdf-$TOOL_NAME: $*"
  exit 1
}

curl_opts=(-fsSL)

# NOTE: You might want to remove this if odin is not hosted on GitHub releases.
if [ -n "${GITHUB_API_TOKEN:-}" ]; then
  curl_opts=("${curl_opts[@]}" -H "Authorization: token $GITHUB_API_TOKEN")
fi

sort_versions() {
  sed 'h; s/[+-]/./g; s/.p\([[:digit:]]\)/.z\1/; s/$/.z/; G; s/\n/ /' |
    LC_ALL=C sort -t. -k 1,1 -k 2,2n -k 3,3n -k 4,4n -k 5,5n | awk '{print $2}'
}

list_github_tags() {
  excludes=(0.9.1 llvm-4.0-windows llvm-windows pre-dev-2021-04 0.0.3c 0.0.3d 0.0.4 0.0.5 0.0.5a 0.0.5b 0.0.5c 0.0.5d 0.0.5e 0.0.6 0.0.6a 0.0.6b 0.1.0 0.1.1 0.1.3 0.10.0 0.11.0 0.11.1 0.12.0 0.13.0 0.2.0 0.2.1 0.3.0 0.4.0 0.5.0 0.6.0 0.6.1 0.6.1a 0.6.2 0.7.0 0.7.1 0.8.0 0.8.1 0.9.0)
  git ls-remote --tags --refs "$GH_REPO" |
    grep -o 'refs/tags/.*' | cut -d/ -f3- |
    sed 's/^v//' | sed "$(printf -- "/^%s$/d;" ${excludes[*]})"
}

list_all_versions() {
  # Change this function if odin has other means of determining installable versions.
  list_github_tags
}

download_release() {
  local platform version filename url
  platform="$1"
  version="$2"
  filename="$3"

  url="$GH_REPO/releases/download/${version}/odin-${platform}-amd64-${version}.zip"

  echo "* Downloading $TOOL_NAME release $version..."
  curl "${curl_opts[@]}" -o "$filename" -C - "$url" || fail "Could not download $url"
}

install_version() {
  local install_type platform version install_path platform download_path
  install_type="$1"
  platform="$2"
  version="$3"
  install_path="${4%/bin}/bin"

  if [ "$install_type" != "version" ]; then
    fail "asdf-$TOOL_NAME supports release installs only"
  fi

  if [ -d "$ASDF_DOWNLOAD_PATH/${platform}"_artifacts ]; then
    download_path="$ASDF_DOWNLOAD_PATH/${platform}_artifacts"
  else
    download_path="$ASDF_DOWNLOAD_PATH"
  fi

  (
    mkdir -p "$install_path"

    cp -r "$download_path"/* "$install_path"
    chmod +x "$install_path/$TOOL_NAME"

    local tool_cmd
    tool_cmd="$(echo "$TOOL_TEST" | cut -d' ' -f1)"
    test -x "$install_path/$tool_cmd" || fail "Expected $install_path/$tool_cmd to be executable."

    echo "$TOOL_NAME $version installation was successful!"
  ) || (
    rm -rf "$install_path"
    fail "An error occurred while installing $TOOL_NAME $version."
  )
}
