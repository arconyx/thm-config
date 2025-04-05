{ pkgs, ... }:

{
  imports = [
    ./common.nix
  ];

  home = {
    username = "arc";
    homeDirectory = "/home/arc";

    # Packages that should be installed to the user profile.
    packages = with pkgs; [
      nixd
      nixfmt-rfc-style
      tlrc
      curlie
      nix-tree
    ];

    # Only for generic aliases compatible across shells
    shellAliases = {
      ls = "eza";
      cat = "bat";
    };
  };

  programs = {
    bat.enable = true;
    direnv.enable = true;
    fd.enable = true;

    bash = {
      enable = true;
      enableCompletion = true;
      bashrcExtra = ''
        export PATH="$PATH:$HOME/bin:$HOME/.local/bin:$HOME/go/bin"
      '';
    };

    eza = {
      enable = true;
      icons = "auto";
    };

    fzf = {
      enable = true;
      defaultCommand = "fd --type f --strip-cwd-prefix";
    };

    git = {
      enable = true;
      delta = {
        enable = true;
        options.navigate = true;
      };
      extraConfig = {
        init.defaultBranch = "main";
        merge.conflictstyle = "zdiff3";
        pull.ff = "only";
      };
      userName = "ArcOnyx";
      userEmail = "11323309+arconyx@users.noreply.github.com";
    };

    neovim = {
      enable = true;
      defaultEditor = true;
      vimAlias = true;
      extraConfig = ''
        set number
        set shiftwidth=4 smarttab
        set tabstop=7 softtabstop=0
      '';
      plugins = with pkgs.vimPlugins; [
        {
          plugin = nvim-lspconfig;
          type = "lua";
          config = ''
            require'lspconfig'.nixd.setup{}
          '';
        }
        {
          plugin = nvim-treesitter.withAllGrammars;
          type = "lua";
          config = builtins.readFile ./dotfiles/treesitter.lua;
        }
        {
          plugin = monokai-pro-nvim;
          config = "colorscheme monokai-pro";
        }
        {
          plugin = comment-nvim;
          type = "lua";
          config = ''
            require'Comment'.setup{}
          '';
        }
      ];
    };

    ripgrep = {
      enable = true;
      arguments = [ "--smart-case" ];
    };

    ssh = {
      enable = true;
      hashKnownHosts = true;
    };
  };
}
