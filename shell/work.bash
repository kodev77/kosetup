# work/dev environment (enabled by `install.sh --work`)

# .NET SDK from dotnet-install.sh at ~/.dotnet (no system package on Devuan;
# guard keeps this harmless on machines using a distro dotnet package instead)
if [ -d "$HOME/.dotnet" ]; then
  export DOTNET_ROOT="$HOME/.dotnet"
  export PATH="$PATH:$HOME/.dotnet:$HOME/.dotnet/tools"
fi
export DOTNET_CLI_TELEMETRY_OPTOUT=1
export DOTNET_NOLOGO=1

# Aspire CLI (installed by get-aspire-cli.sh)
[ -d "$HOME/.aspire/bin" ] && export PATH="$HOME/.aspire/bin:$PATH"
