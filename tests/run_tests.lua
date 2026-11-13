-- Loads the addon files in TOC order against tests/wow_stubs.lua and walks
-- through the main scenarios. Run with: python3 tests/run.py

local root = ...
assert(root, "pass the addon root directory as the first argument")

dofile(root .. "/tests/wow_stubs.lua")

local function ReadToc()
  local files = {}
  for line in io.lines(root .. "/BetterBags_Controller.toc") do
    line = line:gsub("\r", "")
    if line ~= "" and not line:match("^##") and not line:match("^#") then
      table.insert(files, line)
    end
  end
  return files
end

-- Any read of a global the stubs do not define is a bug in the addon (a typo
-- or a missing stub), except for globals the addon probes on purpose and the
-- Blizzard translation-string constants looked up by Locales.Get.
local optionalGlobals = {
  BetterBagsNextBackpack = true,
  BetterBagsNextBank = true,
  BetterBagsNextGuildBank = true,
  BetterBagsNextVendor = true,
  StackSplitSplit = true,
  NUM_STACK_SPLIT = true,
  GameTooltip = true,
}
setmetatable(_G, {
  __index = function(_, key)
    if optionalGlobals[key] or (type(key) == "string" and
        (key:match("^BTN?_[A-Z]") or key:match("^[A-Z][A-Z0-9_]*$"))) then
      return nil
    end
    error("read of undefined global '" .. tostring(key) .. "'", 2)
  end,
})

-- Capture print output into the stub log so status-command assertions work.
local realPrint = print
print = function(...)
  local parts = {}
  for i = 1, select("#", ...) do
    parts[i] = tostring(select(i, ...))
  end
  Stubs.Log(table.concat(parts, " "))
end

local addonTable = {}
for _, name in ipairs(ReadToc()) do
  local chunk = assert(loadfile(root .. "/" .. name))
  chunk(nil, addonTable)
end

local function assertEqual(actual, expected, message)
  if actual ~= expected then
    error((message or "assertion failed") .. " (expected " .. tostring(expected)
      .. ", got " .. tostring(actual) .. ")", 2)
  end
end

local function assertTrue(value, message)
  if not value then
    error(message or "assertion failed", 2)
  end
end

----------------------------------------------------------------------------
-- Login
----------------------------------------------------------------------------

local function TestLogin()
  Stubs.DispatchEvent("PLAYER_LOGIN")
  Stubs.RunNextFrames()

  assertTrue(addonTable.Core.IsInitialized(), "expected initialization with BetterBags loaded")
  local backpack = Stubs.betterBags.backpack
  local bank = Stubs.betterBags.bank
  assertTrue(addonTable.Frames.GetInfo(backpack), "backpack window discovered")
  assertTrue(addonTable.Frames.GetInfo(bank), "bank window discovered")
  assertEqual(addonTable.Frames.GetInfo(backpack).kind, "backpack")
  assertEqual(addonTable.Frames.GetInfo(bank).kind, "bank")
  assertTrue(_G.BetterBagsController_InputButton, "proxy button created")
  assertTrue(not Stubs.LogContains("FrameControlsManager.FrameShown"),
    "no registration while the windows are hidden")
end

----------------------------------------------------------------------------
-- Opening and focusing the backpack
----------------------------------------------------------------------------

local function TestBackpackOpenAndFocus()
  Stubs.ResetLog()
  local backpack = Stubs.betterBags.backpack

  backpack:Show()
  Stubs.focusManager:FocusFrame(backpack)
  Stubs.RunNextFrames()

  assertTrue(Stubs.LogContains("FrameControlsManager.FrameShown|BetterBagsBagBackpack"),
    "backpack registered with the focus manager")
  assertTrue(Stubs.LogContains("SmartNavigation_MarkFrameIgnored|BetterBagsBagBackpackSearchBox"),
    "search box marked ignored")
  assertTrue(Stubs.LogContains("SetTargetButtonForFrame|BetterBagsBagBackpack|BetterBagsBagBackpackItem1"),
    "initial smart-navigation target set on focus")
  assertTrue(_G.BetterBagsControllerFooter and _G.BetterBagsControllerFooter.isShown,
    "prompt footer shown on focus")
  assertTrue(Stubs.LogContains("SetOverrideBindingClick|PAD3|CLICK BetterBagsController_InputButton:Context"),
    "X override bound")
  assertTrue(Stubs.LogContains("SetOverrideBindingClick|PAD4|CLICK BetterBagsController_InputButton:More"),
    "Y override bound")
  assertTrue(_G.ContainerFrameCombinedBags:IsShown(),
    "Blizzard combined-bags state mirrored while BetterBags backpack is open")
end

----------------------------------------------------------------------------
-- Action labels and proxy clicks
----------------------------------------------------------------------------

local function TestContextAndMoreActions()
  Stubs.ResetLog()
  local backpack = Stubs.betterBags.backpack
  local item1 = _G.BetterBagsBagBackpackItem1

  Stubs.focusManager:FocusFrame(backpack)
  SmartNavigation.currentButton = item1

  assertEqual(addonTable.Actions.GetSelectLabel(backpack), "Select", "select label")

  -- Plain container item: no X action.
  Stubs.containerItemInfo[0][1].hasLoot = false
  assertEqual(addonTable.Actions.GetContextLabel(backpack), nil, "no X action on a plain item")

  -- An openable container: X opens it.
  Stubs.containerItemInfo[0][1].hasLoot = true
  assertEqual(addonTable.Actions.GetContextLabel(backpack), "Open", "X opens a bag with loot")

  _G.BetterBagsController_InputButton:Click("Context")
  Stubs.RunNextFrames()
  assertTrue(Stubs.LogContains("BetterBagsBagBackpackItem1:Click|RightButton"),
    "X performs the context action")

  -- Y opens the more-actions menu with Split Stack on a stack.
  assertTrue(addonTable.Actions.CanOpenMoreActions(backpack), "Y available on the backpack")
  _G.BetterBagsController_InputButton:Click("More")
  Stubs.RunNextFrames()
  assertTrue(Stubs.LogContains("Menu.SetTag|MENU_BETTERBAGS_CONTROLLER_MORE_ACTIONS"),
    "more-actions menu opened")
  assertTrue(Stubs.HasContextEntry("Split Stack"), "split stack entry present")
  assertTrue(not Stubs.HasContextEntry("Sort Bags"), "no Baganator sort entry")

  -- Y is hidden while holding an item.
  Stubs.cursorItem = true
  assertTrue(not addonTable.Actions.CanOpenMoreActions(backpack), "Y hidden with cursor item")
  assertEqual(addonTable.Actions.GetSelectLabel(backpack), "Place", "A places while holding")
  Stubs.cursorItem = false

  Stubs.containerItemInfo[0][1].hasLoot = false
end

----------------------------------------------------------------------------
-- Vendor context actions
----------------------------------------------------------------------------

local function TestVendorContext()
  Stubs.ResetLog()
  local backpack = Stubs.betterBags.backpack
  local item1 = _G.BetterBagsBagBackpackItem1

  MerchantFrame:Show()
  MerchantFrame.selectedTab = 1
  Stubs.focusManager:FocusFrame(backpack)
  SmartNavigation.currentButton = item1

  assertEqual(addonTable.Actions.GetContextLabel(backpack), "Sell", "X sells at a vendor")

  Stubs.repairMode = true
  assertEqual(addonTable.Actions.GetContextLabel(backpack), "Repair", "X repairs in repair mode")
  Stubs.repairMode = false

  Stubs.cursorItem = true
  assertEqual(addonTable.Actions.GetContextLabel(backpack), nil, "no X while holding an item")
  Stubs.cursorItem = false

  MerchantFrame:Hide()
end

----------------------------------------------------------------------------
-- Closing and the radial menu
----------------------------------------------------------------------------

local function TestCloseAndRadial()
  Stubs.ResetLog()
  local backpack = Stubs.betterBags.backpack
  local bank = Stubs.betterBags.bank
  local item1 = _G.BetterBagsBagBackpackItem1

  Stubs.focusManager:FocusFrame(backpack)
  SmartNavigation.currentButton = item1

  assertEqual(addonTable.Actions.CloseHandler(backpack), true, "close handler handled B")
  assertTrue(not backpack:IsVisible(), "B closed the BetterBags backpack")
  assertTrue(not bank:IsVisible(), "B closed all BetterBags windows")
  assertTrue(Stubs.LogContains("FrameControlsManager.FrameHidden|BetterBagsBagBackpack"),
    "unregistered on hide")
  assertTrue(Stubs.LogContains("PromptedBindingFooter.HideAndDeactivateBindings"),
    "footer hidden on hide")
  assertTrue(not _G.ContainerFrameCombinedBags:IsShown(),
    "Blizzard combined-bags state mirrored closed")

  -- The radial menu's Bags entry must open BetterBags instead.
  Stubs.stack = "GamepadRadial.lua:619: in function <GamepadRadial.lua:618>\n"
  ToggleBackpack_Combined()
  Stubs.RunNextFrames()
  assertTrue(backpack:IsVisible(), "radial Bags opened BetterBags")
  assertTrue(_G.ContainerFrameCombinedBags:IsShown(), "combined state mirrored open")

  -- Calls that came through BetterBags' own path are ignored.
  Stubs.stack = "`ToggleBackpack' called\n"
  local togglesBefore = Stubs.betterBags.toggles
  ToggleBackpack_Combined()
  assertEqual(Stubs.betterBags.toggles, togglesBefore, "guarded against BetterBags' own calls")
  Stubs.stack = nil
end

----------------------------------------------------------------------------
-- Gamepad UI transitions
----------------------------------------------------------------------------

local function TestGamepadTransition()
  Stubs.ResetLog()
  local backpack = Stubs.betterBags.backpack

  Stubs.focusManager:FocusFrame(backpack)
  Stubs.RunNextFrames()
  assertTrue(_G.BetterBagsControllerFooter.isShown, "footer visible with gamepad on")

  Stubs.SetGamepadUIEnabled(false)
  Stubs.DispatchEvent("INPUT_DEVICE_INTERFACE_TRANSITION")
  Stubs.RunNextFrames()

  assertTrue(not _G.BetterBagsControllerFooter.isShown, "footer hidden when leaving the Gamepad UI")
  assertTrue(Stubs.LogContains("SetOverrideBinding|PAD3"), "X override cleared for keyboard mode")

  Stubs.SetGamepadUIEnabled(true)
  Stubs.DispatchEvent("INPUT_DEVICE_INTERFACE_TRANSITION")
  Stubs.RunNextFrames()
  Stubs.focusManager:FocusFrame(backpack)

  assertTrue(_G.BetterBagsControllerFooter.isShown, "footer restored when entering the Gamepad UI")
end

----------------------------------------------------------------------------
-- Combat deferral
----------------------------------------------------------------------------

local function TestCombatDeferral()
  local bank = Stubs.betterBags.bank
  bank:Hide() -- registered again below, after combat

  Stubs.ResetLog()
  local backpack = Stubs.betterBags.backpack

  Stubs.SetInCombat(true)

  backpack:Hide()
  assertTrue(not Stubs.LogContains("FrameControlsManager.FrameHidden"),
    "no focus-manager call in combat")
  bank:Show()
  assertTrue(not Stubs.LogContains("FrameControlsManager.FrameShown|BetterBagsBagBank"),
    "no registration in combat")

  Stubs.SetInCombat(false)
  Stubs.DispatchEvent("PLAYER_REGEN_ENABLED")
  Stubs.RunNextFrames()

  assertTrue(Stubs.LogContains("FrameControlsManager.FrameHidden|BetterBagsBagBackpack"),
    "deferred unregister after combat")
  assertTrue(Stubs.LogContains("FrameControlsManager.FrameShown|BetterBagsBagBank"),
    "deferred register after combat")
  bank:Hide()
end

----------------------------------------------------------------------------
-- Late windows (Next UI vendor)
----------------------------------------------------------------------------

local function TestLateWindow()
  Stubs.ResetLog()

  local vendor = Stubs.MakeWindow("BetterBagsNextVendor")
  vendor:Show()
  assertTrue(not addonTable.Frames.GetInfo(vendor), "unknown window ignored before resolution")

  Stubs.RunTimers()
  Stubs.RunNextFrames()

  local info = addonTable.Frames.GetInfo(vendor)
  assertTrue(info, "late window resolved by name")
  assertEqual(info.kind, "panel", "vendor window kind")
  assertTrue(Stubs.LogContains("FrameControlsManager.FrameShown|BetterBagsNextVendor"),
    "late window registered")
  vendor:Hide()
end

----------------------------------------------------------------------------
-- Layout refresh after BetterBags re-parents buttons
----------------------------------------------------------------------------

local function TestLayoutRefresh()
  Stubs.ResetLog()
  local backpack = Stubs.betterBags.backpack
  local item1 = _G.BetterBagsBagBackpackItem1
  local item2 = _G.BetterBagsBagBackpackItem2

  backpack:Show()
  Stubs.focusManager:FocusFrame(backpack)
  Stubs.RunNextFrames()
  SmartNavigation.currentButton = item1

  -- A BetterBags layout pass hides the current button.
  item1:Hide()
  addonTable.Frames.RequestRefresh()
  Stubs.RunNextFrames()

  assertTrue(Stubs.LogContains("SmartNavigation.RefreshButtonGroups|BetterBagsBagBackpack"),
    "button groups refreshed")
  assertTrue(Stubs.LogContains("SetTargetButtonForFrame|BetterBagsBagBackpack|BetterBagsBagBackpackItem2"),
    "retargeted to the next visible item")
  assertTrue(SmartNavigation.currentButton == item2, "current button moved")
  item1:Show()
  backpack:Hide()
end

----------------------------------------------------------------------------
-- Slash status command
----------------------------------------------------------------------------

local function TestStatusCommand()
  Stubs.ResetLog()
  Stubs.RunSlashCommand("/bbbc")
  assertTrue(Stubs.LogContains("BetterBags windows known"), "status command prints a report")
end

----------------------------------------------------------------------------

local tests = {
  TestLogin,
  TestBackpackOpenAndFocus,
  TestContextAndMoreActions,
  TestVendorContext,
  TestCloseAndRadial,
  TestGamepadTransition,
  TestCombatDeferral,
  TestLateWindow,
  TestLayoutRefresh,
  TestStatusCommand,
}

for _, test in ipairs(tests) do
  test()
end

print = realPrint
print("all BetterBags Controller stub tests passed")
