# gunso.nvim

A small animated walking companion for Neovim. Gunso displays the included
sprite frames in a floating window and advances the animation as you type.

## Requirements

- Neovim
- [`3rd/image.nvim`](https://github.com/3rd/image.nvim)
- ImageMagick (`magick` command) for the default `magick_cli` image processor
- A terminal and image backend supported by `image.nvim` (Kitty, Sixel, or
  Überzug)

Sixel rendering also requires an ImageMagick build with Sixel support. See the
[`image.nvim` installation guide](https://github.com/3rd/image.nvim#plugin-installation)
for backend-specific setup.

With `image.backend = "auto"`, Kitty, Ghostty, and iTerm2 use the Kitty graphics
protocol. Sixel is selected only for recognized Sixel terminal names and when
ImageMagick has Sixel support. A generic `xterm-256color` value is not enough to
assume Sixel support; set `image.backend = "sixel"` explicitly for a Sixel-enabled
xterm. If auto detection does not match your terminal or tmux/SSH environment,
set `image.backend` to `"kitty"`, `"sixel"`, or `"ueberzug"` as appropriate.

## Installation with lazy.nvim

Add this plugin specification to your Lazy plugin files:

```lua
{
  "mukaiyama729/gunso.nvim",
  main = "gunso",
  dependencies = {
    { "3rd/image.nvim", build = false },
  },
  opts = {
    -- Optional: these are the defaults. The frames ship with the plugin.
    frames = { "walk_1.png", "walk_2.png", "walk_3.png" },
    move_step = 1,
    keys_per_step = 1,
  },
}
```

Relative frame names are read from the plugin's `assets/` directory. Absolute
image paths can also be used. You can omit `frames` to use the bundled walking
animation.

## Usage

Gunso starts enabled after setup. In non-visual modes, each key press advances
the animation according to `keys_per_step`.

| Command | Action |
| --- | --- |
| `:GunsoToggle` | Enable or disable Gunso |
| `:GunsoStep` | Advance one frame while enabled |
| `:GunsoReset` | Reset the frame and position |

## Configuration

Pass options through the plugin specification's `opts` table, or call
`require("gunso").setup(opts)` directly:

```lua
require("gunso").setup({
  frames = { "walk_1.png", "walk_2.png", "walk_3.png" },
  move_step = 0, -- keep Gunso in place horizontally
  keys_per_step = 2,
  image = {
    backend = "auto", -- "kitty", "sixel", or "ueberzug" also accepted
    processor = "magick_cli",
    width = 5,
    height = 3,
  },
})
```

Available options and defaults:

| Option | Default | Description |
| --- | --- | --- |
| `frames` | bundled walking frames | Ordered image filenames under `assets/`, or absolute paths |
| `move_step` | `1` | Horizontal movement per animation step; set to `0` to stay still |
| `keys_per_step` | `1` | Number of key presses before advancing one frame |
| `image.backend` | `"auto"` | Image.nvim rendering backend |
| `image.processor` | `"magick_cli"` | Image.nvim image processor |
| `image.width` | `5` | Rendered image width in cells |
| `image.height` | `3` | Rendered image height in cells |

## License

The project includes an Apache-2.0 `LICENSE` file.
