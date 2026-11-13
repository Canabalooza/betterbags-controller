# BetterBags Controller

Gamepad / controller support for [BetterBags](https://github.com/Cidan/BetterBags) on the
WoW Forever Gamepad UI. Port of
[Baganator Controller](https://github.com/YourBr0ther/baganator-controller) to BetterBags'
window system; it works alongside BetterBags as a separate add-on and does not modify
BetterBags itself.

## What it does

- Registers BetterBags' Backpack, Bank, Guild Bank, and vendor windows with Blizzard's
  gamepad focus manager so the Gamepad UI cursor can move into them.
- A (select) follows the item under the cursor; X and Y are bound to a BetterBags-aware
  context action (open container / sell / repair) and a more-actions menu (split stack,
  pick up).
- Shows the button-prompt footer while a BetterBags window is focused.
- Bridges the Gamepad radial menu's "Bags" entry and Blizzard's bag state so BetterBags
  windows open and close instead of the hidden Blizzard frames.
- Defers every protected gamepad call while add-on restrictions (combat) are active and
  replays the changes afterwards.

## Requirements

- WoW Forever (interface 16001, build 70862 or newer) with the Gamepad UI enabled.
- BetterBags installed and loaded.

Forever's gamepad key bindings are static; the add-on rides Blizzard's focus system and
the radial menu rather than registering new keybinds, so it should stay compatible with
future binding changes.

## Install

Unpack into `Interface/AddOns/BetterBags_Controller` so that
`BetterBags_Controller.toc` sits in that folder. The add-on loads after BetterBags and
initializes on login.

## Commands

- `/bbbc` or `/betterbagscontroller` — prints the current environment: gamepad API
  availability, Gamepad UI state, combat restriction, discovered BetterBags windows,
  and the focused frame.

## Tests

The stub test harness runs the add-on outside the client:

```
python3 tests/run.py
```

Requires a Python with the `lupa` Lua 5.1 runtime.

## License

MIT — see [LICENSE](LICENSE). Based on Baganator Controller by YourBr0ther
(<https://github.com/YourBr0ther/baganator-controller>).
