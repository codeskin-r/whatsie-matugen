# whatsapp-web-matugen

Tema **Material You (matugen)** para **Whatsie** — WhatsApp Web como app nativa en Wayland/Hyprland.

Todo el esquema de colores se genera con [matugen](https://github.com/InioX/matugen) a partir del wallpaper activo, y se inyecta en WhatsApp Web mediante un parche de Whatsie.

## Qué incluye

| Archivo | Descripción |
|---|---|
| `matugen/templates/whatsie.css` | Template matugen: mapa completo de tokens WDS/app de WhatsApp Web → paleta Material You (lavanda `primary-container`, tintes suaves `color-mix`, wordmark estilo Mr. Robot con Barlow Condensed, sin líneas de separación, JetBrains Mono). |
| `matugen/generated/whatsie.css` | CSS ya generado con el wallpaper activo (ejemplo de referencia). |
| `matugen/config.toml` | Config de matugen: registra `[templates.whatsie]` (entrada → salida). |
| `waybar/config.jsonc` | Config de waybar con módulo `tray` (necesario para que Qt registre el `StatusNotifierItem` del icono de Whatsie). |
| `whatsie-patch/mainwindow_webengine.cpp` | Parche de Whatsie: en cada carga de página re-inyecta `~/.config/matugen/generated/whatsie.css` como `<style id="whatsie-matugen-theme">`. |

## Requisitos

- [Whatsie](https://github.com/keshavbhatt/whatsie) (parcheado, ver abajo)
- [matugen](https://github.com/InioX/matugen)
- Waybar con módulo `tray` (cualquier host `StatusNotifierWatcher` sirve)

## Instalación

```sh
# 1. Templates y config de matugen
mkdir -p ~/.config/matugen/templates ~/.config/matugen/generated
cp matugen/templates/whatsie.css ~/.config/matugen/templates/whatsie.css
cp matugen/config.toml ~/.config/matugen/config.toml

# 2. Parche de Whatsie
#    - Aplica whatsie-patch/mainwindow_webengine.cpp en la fuente de Whatsie
#      (añade updatePageTheme() que lee ~/.config/matugen/generated/whatsie.css)
#    - Compila e instala: cmake -B build && cmake --build build && sudo cmake --install build

# 3. Waybar con tray
cp waybar/config.jsonc ~/.config/waybar/config.jsonc
pkill -USR2 -x waybar   # recarga config (registra StatusNotifierWatcher)

# 4. Generar el tema desde el wallpaper activo
matugen --base16-backend wal --mode dark --type scheme-expressive \
  --contrast 0.2 --source-color-index 0 \
  image "$(cat ~/.config/dusky/settings/dusky_theme/dark_wal)"
```

> Nota: lee el wallpaper activo desde `~/.config/dusky/settings/dusky_theme/dark_wal` (estado de dusky). Si usas otro gestor de wallpapers, ajusta esa ruta.

## Problemas comunes

- **No aparece el icono en el system tray**: el `StatusNotifierWatcher` no estaba activo. Añade el módulo `tray` a la config de waybar que estés usando y recarga con `pkill -USR2 -x waybar`. Sin un host registrado, Qt no crea el `org.kde.StatusNotifierItem`.
- **La tematización no corresponde con el wallpaper configurado**: el tema se generó con un wallpaper distinto al activo. Genera de nuevo usando el wallpaper que indica `dark_wal`.
- **Cambios del template**: tras editar el template ejecuta `matugen ... image <wallpaper>` y recarga la página de WhatsApp (Ctrl+R).

## Detalles del tema

- Burbujas salientes: `--mt-primary-container` (lavanda, `#70589a` con el wallpaper de ejemplo).
- Burbujas entrantes: `color-mix(50% primary-container + 50% surface-dim)` — lavanda oscura, distinta de la saliente.
- Sistema/E2E: `--mt-surface-variant`. Empresa: `--mt-tertiary-container`.
- Fondo base: tinte suave de `primary-container` sobre el fondo oscuro (`--mt-soft-bg` / `-2` / `-3`), sin gris neutro.
- Título "WhatsApp": oculta el SVG y lo sustituye por texto en **Barlow Condensed 500** (estilo Mr. Robot), vía Google Fonts.
- Totalmente minimalista: sin líneas de separación ni divisores (`--WDS-lines-*` transparentes).
