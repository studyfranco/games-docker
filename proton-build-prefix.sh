#!/bin/bash

# Prepare the Proton prefix of a game image (PROTON_PREFIX_TEMPLATE, like protontricks), one step per Docker layer:
#   RUN proton-build-prefix prefix        create the prefix (done by the first step when missing)
#   RUN proton-build-prefix dotnet48      .NET Framework 4.8
#   RUN proton-build-prefix <verb>        winetricks verb (corefonts, sound=disabled...)
# The game image installs the tools: winetricks cabextract xvfb xauth
# The prefix is copied to STEAM_COMPAT_DATA_PATH at the first start by proton-prefix-init

set -e

for tool in winetricks cabextract Xvfb; do
    if ! command -v "${tool}" > /dev/null; then
        echo "proton-build-prefix: ${tool} not found, install winetricks cabextract xvfb xauth in the game image"
        exit 1
    fi
done

export STEAM_COMPAT_DATA_PATH="${PROTON_PREFIX_TEMPLATE}"
export STEAM_COMPAT_CLIENT_INSTALL_PATH="${STEAMCMD_PATH}"
export WINEPREFIX="${PROTON_PREFIX_TEMPLATE}/pfx"
export WINE="${PROTON_PATH}/files/bin/wine"
export WINESERVER="${PROTON_PATH}/files/bin/wineserver"
export WINEDEBUG="-all"

# Virtual display for the installers
export DISPLAY=:1
Xvfb :1 -screen 0 1024x768x16 > /dev/null 2>&1 &
xvfb_pid=$!
trap 'kill "${xvfb_pid}" 2>/dev/null; rm -rf "${HOME}/.cache" /tmp/.X1-lock 2>/dev/null; true' EXIT
sleep 2

echo "proton-build-prefix: $1 ($("${WINE}" --version))"

if [ ! -f "${STEAM_COMPAT_DATA_PATH}/version" ]; then
    "${PROTON_PATH}/proton" run wineboot --init
    "${WINESERVER}" -w
fi

case "$1" in
    prefix)
        ;;
    dotnet48)
        # Installed directly (the dotnet40 installer of winetricks fails in Proton), as Windows 7:
        # the installer thinks that .NET 4.8 is already there on Windows 10, where it is built in
        winetricks -q --force remove_mono
        mkdir -p "${HOME}/.cache/dotnet48"
        curl -fsSL -o "${HOME}/.cache/dotnet48/ndp48-x86-x64-allos-enu.exe" \
            "https://download.visualstudio.microsoft.com/download/pr/7afca223-55d2-470a-8edc-6a1739ae3252/abd170b4b0ec15ad0222a809b761a036/ndp48-x86-x64-allos-enu.exe"
        "${WINE}" winecfg -v win7
        (cd "${HOME}/.cache/dotnet48" && "${WINE}" ndp48-x86-x64-allos-enu.exe /q /norestart)
        "${WINESERVER}" -w
        "${WINE}" reg add 'HKCU\Software\Wine\DllOverrides' /v mscoree /d native /f
        "${WINE}" winecfg -v win10
        test -f "${WINEPREFIX}/drive_c/windows/Microsoft.NET/Framework64/v4.0.30319/mscorlib.dll"
        ;;
    *)
        winetricks -q --force "$1"
        ;;
esac

"${WINESERVER}" -w
