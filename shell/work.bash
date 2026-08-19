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

# ASP.NET dev-cert trust for OpenSSL-based clients (curl, HttpClient between
# the Aspire services). `dotnet dev-certs https --trust` exports the cert here,
# but OpenSSL only honors it when the directory is on SSL_CERT_DIR — the trust
# command prints exactly this export as its [110] guidance. Chrome/NSS trust is
# separate (certutil into ~/.pki/nssdb; see work-cli notes).
if [ -d "$HOME/.aspnet/dev-certs/trust" ]; then
  export SSL_CERT_DIR="$HOME/.aspnet/dev-certs/trust:${SSL_CERT_DIR:-/etc/ssl/certs}"
fi
