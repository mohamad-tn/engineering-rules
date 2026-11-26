#!/usr/bin/env bash
# shellcheck shell=bash
# .NET engine: ASP.NET Core, console apps, libraries, Blazor, MAUI (build only).

run_dotnet() {
  local target
  target="$(find . -maxdepth 1 \( -name '*.sln' -o -name '*.slnx' \) | sort | head -n 1)"
  [[ -n "$target" ]] || target="$(find . -maxdepth 1 -name '*.csproj' | sort | head -n 1)"
  [[ -n "$target" ]] || { fail deps "no .sln or .csproj in this directory"; return 0; }
  echo "  target: ${target#./}"

  have dotnet || { notrun deps "dotnet SDK is not installed"; return 0; }

  # SDK pin
  if [[ -f global.json ]]; then
    pass sdk-pin "global.json present"
  else
    warn sdk-pin "no global.json: pin the SDK version (rollForward: disable)"
  fi

  # deps: locked restore when lock files exist
  if [[ -n "$(find . -name packages.lock.json -not -path '*/obj/*' -print -quit)" ]]; then
    gate_net deps -- dotnet restore "$target" --locked-mode
  else
    warn lockfiles "no packages.lock.json: set RestorePackagesWithLockFile=true"
    gate_net deps -- dotnet restore "$target"
  fi

  gate format -- dotnet format "$target" --verify-no-changes --no-restore
  gate build -- dotnet build "$target" --no-restore -c Release -warnaserror

  if grep -rqs --include='*.csproj' 'Microsoft.NET.Test.Sdk' .; then
    gate test -- dotnet test "$target" --no-build -c Release
  else
    skip test "no test project (Microsoft.NET.Test.Sdk) found"
  fi

  gate_net audit -- bash "${STACK_TOOLS_DIR}/dotnet-vuln-check.sh" "$target"
}
