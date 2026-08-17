# iTerm2 config

Full iTerm2 settings, versioned via iTerm2's "load settings from a custom
folder" feature. `./install.sh` (run automatically from `bootstrap.sh`)
points iTerm2 at this directory; restart iTerm2 afterwards.

## What's tracked

- `com.googlecode.iterm2.plist` — the complete settings file, XML format:
  the `Default` / `Vibe` / `House` profiles (`bin/herdr-attach` switches
  between them by name), global key mappings, pointer actions, and
  appearance settings.

Machine noise (window frame positions, Sparkle updater state, `NoSync*`
runtime keys) was stripped from the initial export, and iTerm2 never writes
`NoSync*` keys to a custom folder.

## Editing

Edit settings through the iTerm2 UI as normal. With
Settings > General > Settings > "Save changes" set to **Automatically**,
iTerm2 writes them back to this file and they show up in `git status`.
iTerm2 rewrites the plist wholesale, which is why this uses the custom
folder mechanism instead of a symlink into `~/Library/Preferences`.
