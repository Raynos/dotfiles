# iTerm2 config

Full iTerm2 settings, versioned via iTerm2's "load settings from a custom
folder" feature. `./install.sh` (run automatically from `bootstrap.sh`)
points iTerm2 at this directory; restart iTerm2 afterwards.

## What's tracked

- `com.googlecode.iterm2.plist` — the complete settings file, XML format:
  the `Default` / `Vibe` / `House` profiles (`bin/herdr-attach` switches
  between them by name), global key mappings, pointer actions, and
  appearance settings.

- `DynamicProfiles/*.json` — extra profiles as iTerm2 dynamic profiles,
  symlinked into `~/Library/Application Support/iTerm2/DynamicProfiles/` by
  `install.sh`. iTerm2 hot-reloads these and never writes to them, so they are
  safe to edit while it runs (the plist is not: iTerm2 rewrites it on every
  auto-save, clobbering hand edits). Each declares a plist profile as
  `Dynamic Profile Parent Name` and overrides colors only.
  - `Wildshard.json` — the `wildshard` herdr session. Late afternoon in a
    pine forest, lifted from the game's `progress/004-late-afternoon-lighting.png`:
    forest-floor umber bg `#1a1410`, hazy parchment fg `#dcd3bf`, sun-amber
    cursor `#f0a830`, olive-grass green `#7a9a3c`, haze-sky blue `#5d8aa8`,
    pine-shade water cyan `#4f9a8a`, rust red `#c25a3c`, heather magenta
    `#a86b8a`. Distinct from House (emerald + neon) and Vibe (solarized teal).

Machine noise (window frame positions, Sparkle updater state, `NoSync*`
runtime keys) was stripped from the initial export, and iTerm2 never writes
`NoSync*` keys to a custom folder.

## Editing

Edit settings through the iTerm2 UI as normal. With
Settings > General > Settings > "Save changes" set to **Automatically**,
iTerm2 writes them back to this file and they show up in `git status`.
iTerm2 rewrites the plist wholesale, which is why this uses the custom
folder mechanism instead of a symlink into `~/Library/Preferences`.
