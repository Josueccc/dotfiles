source /usr/share/cachyos-fish-config/cachyos-config.fish

# overwrite greeting: desactiva fastfetch (definido en cachyos-config.fish)
function fish_greeting
    # vacío = sin saludo; descomenta para un saludo propio:
    # echo "Hola, (whoami). Bienvenido/a a CachyOS."
end

# opencode (installed by https://opencode.ai/install into ~/.opencode/bin)
fish_add_path "$HOME/.opencode/bin"
