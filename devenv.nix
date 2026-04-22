{ pkgs, ... }:

{
  languages.elixir = {
    enable = true;
    package = pkgs.beam.packages.erlang_27.elixir_1_19;
  };

  packages = with pkgs; [
    gnumake
    gcc
  ] ++ pkgs.lib.optionals pkgs.stdenv.isLinux [ pkgs.libgpiod pkgs.i2c-tools ];

  enterShell = ''
    echo "Elixir $(elixir --version | head -1)"
    echo "Mix $(mix --version)"
  '';
}
