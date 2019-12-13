#!/bin/bash

set -u

trap "exit 1" TERM
export TOP_PID=$$

: "${WFC_REPO:=balena-io/wifi-connect}"
: "${WFC_INSTALL_ROOT:=/usr/local}"

SCRIPT='raspbian-install.sh'
NAME='WiFi Connect Raspbian Installer'

INSTALL_BIN_DIR="$WFC_INSTALL_ROOT/sbin"
INSTALL_UI_DIR="$WFC_INSTALL_ROOT/share/wifi-connect/ui"

WFC_VERSION="4.2.5"
RELEASE_URL="https://github.com/balena-io/wifi-connect/releases/download/v$WFC_VERSION/wifi-connect-v$WFC_VERSION-linux-rpi.tar.gz"

CONFIRMATION=true

usage() {
    cat 1>&2 <<EOF
$NAME 1.0.1 (2018-21-03)

USAGE:
    $SCRIPT [FLAGS]

FLAGS:
    -y                      Disable confirmation prompt
    -h, --help              Prints help information
EOF
}

main() {
    for arg in "$@"; do
        case "$arg" in
            -h|--help)
                usage
                exit 0
                ;;
            -y)
                CONFIRMATION=false
                ;;
            *)
                ;;
        esac
    done

    need_cmd id
    need_cmd curl
    need_cmd systemctl
    need_cmd apt-get
    need_cmd grep
    need_cmd mktemp

    check_os_version

    install_wfc
    # install_custom_ui

    say "Run 'wifi-connect --help' for available options"
}

check_os_version() {
    local _version=""

    if [ -f /etc/os-release ]; then
        _version=$(grep -oP 'VERSION="\K[^"]+' /etc/os-release)
    fi

    # if [ "$_version" != "9 (stretch)" ]; then
    #     err "Distribution not based on Debian 9 (stretch)"
    # fi
}

service_load_state() {
    ensure systemctl -p LoadState --value show "$1"
}

service_active_state() {
    ensure systemctl -p ActiveState --value show "$1"
}

confirm_installation() {
    if [ "$CONFIRMATION" = false ]; then
        return
    fi

    printf '\33[1;36m%s:\33[0m ' "$NAME"

    read -r -p "Continue to install NetworkManager and disable dhcpcd? [y/N] " response
    response=${response,,}  # convert to lowercase
    if [[ ! $response =~ ^(yes|y)$ ]]; then
        exit 0
    fi
}

install_wfc() {
    local _regex='browser_download_url": "\K.*rpi\.tar\.gz'
    local _arch_url
    local _wfc_version
    local _download_dir

    say "Retrieving latest release from $RELEASE_URL..."

    _download_dir=$(ensure mktemp -d)

    ensure curl -Ls "$RELEASE_URL" | tar -xz -C "$_download_dir"

    ensure sudo mv "$_download_dir/wifi-connect" $INSTALL_BIN_DIR

    ensure sudo mkdir -p $INSTALL_UI_DIR

    ensure sudo rm -rdf $INSTALL_UI_DIR

    ensure sudo mv "$_download_dir/ui" $INSTALL_UI_DIR

    ensure rm -rdf "$_download_dir"

    _wfc_version=$(ensure wifi-connect --version)

    say "Successfully installed $_wfc_version"
}

# install_custom_ui() {
#     local _download_dir
#     _download_dir=$(ensure mktemp -d)
#
#    say "Retrieving latest custom ui release from $CUI_RELEASE_URL..."
#
#    ensure curl -Ls "$CUI_RELEASE_URL" | tar -xz -C "$_download_dir"
#
#    ensure sudo mkdir -p $INSTALL_UI_DIR
#
#    ensure sudo rm -rdf $INSTALL_UI_DIR
#
#    ensure sudo mv "$_download_dir/wifi-connect-$CUI_VERSION/ui" $INSTALL_UI_DIR
#
#    ensure rm -rdf "$_download_dir"
#
#    say "Successfully installed custom ui $CUI_VERSION"
# }

say() {
    printf '\33[1m%s:\33[0m %s\n' "$NAME" "$1"
}

err() {
    printf '\33[1;31m%s:\33[0m %s\n' "$NAME" "$1" >&2
    kill -s TERM $TOP_PID
}

need_cmd() {
    if ! command -v "$1" > /dev/null 2>&1; then
        err "need '$1' (command not found)"
    fi
}

ensure() {
    "$@"
    if [ $? != 0 ]; then
        err "command failed: $*";
    fi
}

main "$@" || exit 1
