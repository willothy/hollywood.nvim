# hollywood.nvim

📸 Action! A flexible, elegant and featureful code action menu.

> **Warning** <br/>
> This plugin is in an early stage of development and is not quite ready for use.

## Goals

- Extensible action sources
  - Builtin LSP source
  - Easy to implement sources to execute arbitrary actions based on context
    - Custom source preview providers
- Elegant code action menu
  - UI based on Nui.nvim
  - Three-panel split
    - Action select menu
    - Selected action info
    - Action diff / preview
  - Customizable sorting behavior
- Performant
  - Actions should be fetched asynchronously and lazily added to the menu
  - The menu should appear quickly if actions are available
    - Per-source timeout config
