## Setup
1. Install NixOS
2. Set user password (installer should have done this). Check root password.
2. Clone this repository into /config
3. Copy across `hardware-config.nix` to `hosts/hostname`
4. [Optional] Symlink to /etc/nixos
5. Rebuild with `nixos-rebuild switch --flake path#hostname`
6. Setup tailscale
7. Test remote access
8. Add Backblaze environment file and password file (see `common/units/backup.nix`)