#!/usr/bin/env bash

set -euo pipefail

TMP_DIR="$(dirname $(mktemp -u -t asdf-blender-XXXX))/"
BLENDER_DOWNLOADS="https://download.blender.org/release/"

fail() {
  echo 1>&2 -e "asdf-blender: $*"
  exit 1
}

curl_opt="-fsSL"

platform() {
  local operating_system="$(uname -o)"
  local machine="$(uname -m)"

  case $operating_system in
  GNU/Linux)
    case $machine in
    x86_64)
      echo "linux-x86_64"
      ;;
    *)
      fail "Unsupported machine type ($machine)"
      ;;
    esac
    ;;
  *)
    fail "Unsupported operating system type ($operating_system)"
    ;;
  esac
}

list_all_versions() {
  list_binary_releases_cached | grep "$(platform)" | cut -f 2
}

download_release() {
  local version="$1"
  local filename="$2"

  local url=$(list_binary_releases_cached | grep "$(platform)" | grep "$version" | cut -f 3)
  local cached="${TMP_DIR}$(basename "$url")"

  if [ -e $cached ]; then
    echo "* Using cached blender release $version..."
  else
    echo "* Downloading blender release $version..."
    curl "$curl_opt" -o "$cached" -C - "$url" || (
      rm $cached
      fail "Could not download $url"
    )
  fi
  cp $cached $filename
}

install_version() {
  local install_type="$1"
  local version="$2"
  local install_path="$3"

  if [ "$install_type" != "version" ]; then
    fail "asdf-blender supports release installs only"
  fi

  local url=$(list_binary_releases_cached | grep "$(platform)" | grep "$version" | cut -f 3)
  local release_file="$install_path/$(basename "$url")"

  (
    mkdir -p "$install_path"
    download_release "$version" "$release_file"
    tar -xf "$release_file" -C "$install_path" --strip-components=1 || fail "Could not extract $release_file"
    rm "$release_file"

    local tool_cmd="$(echo "blender" | cut -d' ' -f2-)"
    test -x "$install_path/$tool_cmd" || fail "Expected $install_path/bin/$tool_cmd to be executable."

    echo "blender $version installation was successful!"
  ) || (
    rm -rf "$install_path"
    fail "An error ocurred while installing blender $version."
  )
}

list_binary_release_directories() {
  local url="$BLENDER_DOWNLOADS"
  (
    curl "$curl_opt" -C - "$url" |
      grep -E 'href="Blender[[:digit:]]' |
      sed -r 's/.*href="(Blender.*)\/".*/\1/g'
  ) || fail "Could not fetch release directories from $url"
}

list_binary_releases_cached() {
  local cached_list_path="${TMP_DIR}asdf-blender-cached-binary-releases"
  local timeout="$((30 * 60))"

  if [ -e "$cached_list_path" ] && [ "$(($(date +%s) - $(stat -L --format %Y $cached_list_path)))" -lt "$timeout" ]; then
    cat "$cached_list_path"
  else
    list_binary_releases | tee "$cached_list_path"
  fi
}

list_binary_releases() {
  local url

  for binary_release_directory in $(list_binary_release_directories); do
    url="$BLENDER_DOWNLOADS$binary_release_directory/"
    (
      releases=$(curl "$curl_opt" -C - "$url" | grep -E 'href="blender' | sed -r 's/.*href="(blender.*)".*/\1/g')
      for release in $releases; do
        print_release "$release" "$url$release"
      done
    ) || fail "Could not fetch releases from $url"
  done
}

blender_version_identifier() {
  local release="$1"
  (
    echo "$release" | sed -r 's/blender-?([[:digit:]]\.[^-_.]+).*/\1/g'
  ) || fail "Couldn't parse version in $release"
}

linux_platform_identifier() {
  local release="$1"
  local release_i="${release,,}"

  if [[ $release_i =~ linux64 || $release_i =~ x86_64 ]]; then
    echo "linux-x86_64"
    return 0
  elif [[ $release_i =~ i686 || $release_i =~ i386 ]]; then
    echo "linux-i386"
    return 0
  elif [[ $release_i =~ powerpc ]]; then
    echo "linux-ppc"
    return 0
  elif [[ $release_i =~ alpha ]]; then
    echo "linux-alpha"
    return 0
  else
    fail "Couldn't parse platform in $release"
  fi
}

macos_platform_identifier() {
  local release="$1"
  local release_i="${release,,}"

  if [[ $release_i =~ powerpc || $release_i =~ ppc ]]; then
    echo "darwin-ppc"
    return 0
  elif [[ $release_i =~ i386 || $release_i =~ intel ]]; then
    echo "darwin-i386"
    return 0
  elif [[ $release_i =~ x86_64 ]]; then
    echo "darwin-x86_64"
    return 0
  else
    echo "darwin-x86_64"
    return 0
  fi
}

linux_libc_identifier() {
  local release="$1"
  local release_i="${release,,}"

  if [[ $release_i =~ libc ]]; then
    echo "$release" | sed -r 's/.*[_-](g?libc[^-]+).*/\1/g'
  else
    echo ""
  fi
}

linux_linked_identifier() {
  local release="$1"
  local release_i="${release,,}"

  if [[ $release_i =~ "static" ]]; then
    echo "static"
  else
    echo ""
  fi
}

python_identifier() {
  local release="$1"
  local release_i="${release,,}"

  if [[ $release_i =~ py ]]; then
    if [[ $release_i =~ py2\.?3 ]]; then
      echo "py2.3"
    elif [[ $release_i =~ py2\.?4 ]]; then
      echo "py2.4"
    elif [[ $release_i =~ py2\.?5 ]]; then
      echo "py2.5"
    elif [[ $release_i =~ py2\.?6 ]]; then
      echo "py2.6"
    elif [[ $release_i =~ newpy ]]; then
      echo "newpy"
    else
      fail "Couldn't parse python version in $release"
    fi
  else
    echo ""
  fi
}

release_identifier() {
  local release="$1"
  local identifier=$(blender_version_identifier "$release")
  local libc=$(linux_libc_identifier "$release")

  if [ -n "$libc" ]; then
    identifier="$identifier-$libc"
  fi
  py=$(python_identifier "$release")
  if [ -n "$py" ]; then
    identifier="$identifier-$py"
  fi
  linked=$(linux_linked_identifier "$release")
  if [ -n "$linked" ]; then
    identifier="$identifier-$linked"
  fi

  echo "$identifier-bin"
}

print_release() {
  local platform identifier
  local release="$1"
  local release_i="${release,,}"
  local url="$2"

  if [[ $release_i =~ linux ]]; then
    platform=$(linux_platform_identifier "$release")
    identifier=$(release_identifier "$release")
    echo -e "$platform\t$identifier\t$url"
    return 0
  fi

  if [[ $release_i =~ macos || $release_i =~ osx ]]; then
    platform=$(macos_platform_identifier "$release")
    identifier=$(release_identifier "$release")
    echo -e "$platform\t$identifier\t$url"
    return 0
  fi

  if [[ $release_i =~ win || $release_i =~ freebsd || $release_i =~ solaris || $release_i =~ irix || $release_i =~ ubuntu || $release_i =~ beos || $release_i =~ mdv || $release_i =~ source || $release_i =~ script ]]; then
    # Ignore platform for now
    return 0
  fi

  fail "Couldn't parse release $release"
}
