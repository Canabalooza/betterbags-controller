local _, addonTable = ...

local Constants = {}
addonTable.Constants = Constants

-- Name of the hidden button that X/Y override bindings click into.
Constants.PROXY_BUTTON_NAME = "BetterBagsController_InputButton"

-- buttonContext value inherited from ContainerFrameItemButtonTemplate.
Constants.ITEM_BUTTON_CONTEXT = "ButtonContext_ContainerFrameItemButton"

-- Window kinds.
Constants.Kind = {
  Backpack = "backpack",
  Bank = "bank",
  Guild = "guild",
  Panel = "panel", -- vendor and other secondary windows
}

-- BetterBags window frames, by global frame name. The classic UI creates
-- BetterBagsBagBackpack/BetterBagsBagBank; the Next UI creates BetterBagsNext*.
-- Windows that do not exist (Next disabled, guild bank never opened) are
-- simply never resolved.
Constants.WINDOW_NAMES = {
  BetterBagsBagBackpack = Constants.Kind.Backpack,
  BetterBagsBagBank = Constants.Kind.Bank,
  BetterBagsNextBackpack = Constants.Kind.Backpack,
  BetterBagsNextBank = Constants.Kind.Bank,
  BetterBagsNextGuildBank = Constants.Kind.Guild,
  BetterBagsNextVendor = Constants.Kind.Panel,
}

-- Click button names delivered to the proxy by the X/Y override bindings.
Constants.VirtualButton = {
  Context = "Context",
  More = "More",
}

-- Internal events dispatched through Core.TriggerEvent.
Constants.Events = {
  FrameVisibilityChanged = "FrameVisibilityChanged", -- (info, shown)
  FrameFocused = "FrameFocused",                     -- (frame)
  FrameUnfocused = "FrameUnfocused",                 -- (frame)
}

-- Blizzard frames BetterBags parents into BetterBagsSneakyFrame.
Constants.ORPHANED_BLIZZARD_FRAMES = {
  BankFrame = true,
  ContainerFrameCombinedBags = true,
}
Constants.ORPHANED_BLIZZARD_FRAME_PATTERN = "^ContainerFrame%d+$"

-- Screen height (px) below which the prompt legend is placed above the window.
Constants.LEGEND_FLIP_THRESHOLD = 56

-- Seconds between attempts to pick up BetterBags windows that were not
-- created yet (the Next UI's vendor and guild bank windows are lazy).
Constants.RESOLVE_RETRY_SECONDS = 5

-- Seconds between navigation refreshes while the Gamepad UI is on; BetterBags
-- relayouts its windows without announcing it.
Constants.REFRESH_SECONDS = 2
