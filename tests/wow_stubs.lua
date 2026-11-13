-- Minimal World of Warcraft API stubs for BetterBags Controller tests.
-- Loaded via dofile from tests/run_tests.lua; frames and globals are real Lua
-- tables that record calls in Stubs.log, and timers/RunNextFrame are run
-- manually by the tests.

Stubs = {}

Stubs.log = {}

function Stubs.Log(message)
  table.insert(Stubs.log, tostring(message))
end

function Stubs.ResetLog()
  Stubs.log = {}
end

function Stubs.LogContains(needle)
  for _, line in ipairs(Stubs.log) do
    if line:find(needle, 1, true) then
      return true
    end
  end
  return false
end

----------------------------------------------------------------------------
-- Timers and frames
----------------------------------------------------------------------------

Stubs.pendingTimers = {}
Stubs.nextFrameQueue = {}

C_Timer = {}

function C_Timer.After(delay, callback)
  table.insert(Stubs.pendingTimers, { delay = delay, callback = callback })
end

function Stubs.RunTimers()
  local due = Stubs.pendingTimers
  Stubs.pendingTimers = {}
  for _, timer in ipairs(due) do
    timer.callback()
  end
end

function RunNextFrame(callback)
  table.insert(Stubs.nextFrameQueue, callback)
end

function Stubs.RunNextFrames()
  local passes = 0
  while #Stubs.nextFrameQueue > 0 and passes < 100 do
    passes = passes + 1
    local queue = Stubs.nextFrameQueue
    Stubs.nextFrameQueue = {}
    for _, callback in ipairs(queue) do
      callback()
    end
  end
end

local registeredEvents = {}

local function RegisterEvent(self, event)
  registeredEvents[event] = registeredEvents[event] or {}
  registeredEvents[event][self] = self
end

local function MakeFrame(name, parent, kind)
  local f = {}
  f.name = name or nil
  f.kind = kind or "Frame"
  f.parent = parent or nil
  f.shown = true
  f.visible = true
  f.alpha = 1
  f.scripts = {}
  f.hooks = { OnShow = {}, OnHide = {} }
  f.children = {}
  f.regions = {}
  f.mouse = false

  -- Real visibility walks the parent chain, like the client does.
  local function AncestorsHidden(node)
    local p = node.parent
    while p do
      if not p.shown then return true end
      p = p.parent
    end
    return false
  end

  function f:IsShown() return f.shown end
  function f:IsVisible() return f.shown and not AncestorsHidden(f) end

  function f:SetName(value) f.name = value end
  function f:GetName() return f.name end
  function f:GetParent() return f.parent end
  function f:SetParent(p) f.parent = p end
  function f:GetChildren() return unpack(f.children) end
  function f:GetRegions() return unpack(f.regions) end
  function f:SetFrameStrata() end
  function f:SetFrameLevel() end
  function f:SetPoint() end
  function f:SetAllPoints() end
  function f:SetSize() end
  function f:SetAlpha(a) f.alpha = a end
  function f:GetAlpha() return f.alpha end
  function f:GetEffectiveScale() return 1 end
  function f:SetMovable() end
  function f:EnableMouse(v) f.mouse = v end
  function f:RegisterForClicks() end
  function f:SetPropagateKeyboardInput() end
  function f:SetAutoHideDelay() end
  function f:SetOrnament() end
  function f:Show()
    f.shown = true
    f.visible = true
    for _, callback in ipairs(f.hooks.OnShow) do
      callback(f)
    end
  end
  function f:Hide()
    f.shown = false
    f.visible = false
    for _, callback in ipairs(f.hooks.OnHide) do
      callback(f)
    end
  end
  function f:GetRect() return 0, 0, 0, 0 end
  function f:SetScript(event, callback) f.scripts[event] = callback end
  function f:GetScript(event) return f.scripts[event] end
  function f:HookScript(event, callback)
    table.insert(f.hooks[event], callback)
  end
  function f:RegisterEvent(event)
    RegisterEvent(f, event)
  end
  function f:Click(buttonName)
    Stubs.Log("Click|" .. tostring(f.name) .. "|" .. tostring(buttonName))
    if f.scripts.OnClick then
      f.scripts.OnClick(f, buttonName)
    end
  end

  function f:GetLeft() return f.x or 0 end
  function f:GetTop() return f.y or 0 end
  function f:GetBottom() return (f.y or 0) - (f.height or 0) end
  function f:IsObjectType(t) return f.kind == t end

  if parent then
    table.insert(parent.children, f)
  end

  if name then
    _G[name] = f
  end
  return f
end

function CreateFrame(kind, name, parent)
  return MakeFrame(name, parent, kind)
end

----------------------------------------------------------------------------
-- Misc client functions and globals
----------------------------------------------------------------------------

Stubs.inCombat = false

function InCombatLockdown() return Stubs.inCombat end

C_RestrictedActions = {}
function C_RestrictedActions.IsAddOnRestrictionActive(which)
  return Stubs.inCombat
end

function Stubs.SetInCombat(value)
  Stubs.inCombat = value and true or false
end

function GetBuildInfo()
  return "1.60.1", 1, 0, 16001, 70862
end

SlashCmdList = {}

function Stubs.RunSlashCommand(line)
  local command, arg = line:match("^(%S+)%s*(.*)$")
  for name, handler in pairs(SlashCmdList) do
    for suffix = 1, 2 do
      local alias = _G["SLASH_" .. name .. suffix]
      if alias and command and alias:lower() == command:lower() then
        return handler(arg)
      end
    end
  end
  error("no slash command matched " .. tostring(line))
end

function hooksecurefunc(object, name, callback)
  local target, key
  if type(object) == "string" then
    -- hooksecurefunc("GlobalName", hook)
    target, key, callback = _G, object, name
  else
    -- hooksecurefunc(table, "methodName", hook)
    target, key = object, name
  end
  local original = target[key]
  if type(original) ~= "function" then
    Stubs.Log("hooksecurefunc: missing target " .. tostring(name))
    return
  end
  target[key] = function(...)
    local results = { original(...) }
    callback(...)
    return unpack(results)
  end
end

Stubs.currentBinding = {}

function SetOverrideBinding(owner, prio, key, action)
  Stubs.Log("SetOverrideBinding|" .. key .. "|" .. tostring(action))
  Stubs.currentBinding[key] = action
end

function SetOverrideBindingClick(owner, prio, key, buttonName, button)
  local command = "CLICK " .. buttonName .. ":" .. button
  Stubs.Log("SetOverrideBindingClick|" .. key .. "|" .. command)
  Stubs.currentBinding[key] = command
end

function GetBindingAction(key, priorityOnly)
  return Stubs.currentBinding[key]
end

function CursorHasItem() return Stubs.cursorItem end
Stubs.cursorItem = false

function ClearCursor()
  Stubs.cursorItem = false
  Stubs.Log("ClearCursor")
end

Stubs.repairMode = false

function InRepairMode() return Stubs.repairMode end

function ShowUIPanel(frame)
  Stubs.Log("ShowUIPanel|" .. tostring(frame.name))
  frame:Show()
end

function ItemRefTooltip()
  Stubs.Log("ItemRefTooltip:SetHyperlink")
end

function ItemTextWindow()
  Stubs.Log("ItemTextWindow:Show")
end

AnchorUtil = {
  CreateAnchor = function(_, ...)
    return { args = { ... } }
  end,
}

PromptedBindingMixin = { VISIBILITY_TYPE = { ONLY_IF_USABLE = 2 } }

function Stubs.DispatchEvent(event, ...)
  for _, frame in pairs(registeredEvents[event] or {}) do
    if frame.scripts and frame.scripts.OnEvent then
      frame.scripts.OnEvent(frame, event, ...)
    end
  end
end

----------------------------------------------------------------------------
-- UIParent
----------------------------------------------------------------------------

UIParent = MakeFrame("UIParent", nil)
UIParent.x, UIParent.y = 0, 0

function UIParent:SetScript(event, callback)
  self.scripts[event] = callback
end

function UIParent:RegisterEvent(event)
  RegisterEvent(self, event)
end

----------------------------------------------------------------------------
-- Blizzard container state (what IsBagOpen() and item queries read)
----------------------------------------------------------------------------

Stubs.containerItemInfo = {} -- [bagID] = { [slotID] = info }

local function SetContainerItem(bagID, slotID, itemID, stackCount)
  Stubs.containerItemInfo[bagID] = Stubs.containerItemInfo[bagID] or {}
  Stubs.containerItemInfo[bagID][slotID] = {
    itemID = itemID or nil,
    stackCount = stackCount or nil,
    hasItem = itemID ~= nil,
    quality = 1,
    hasLoot = false,
    isLocked = false,
  }
end

SetContainerItem(0, 1, 5000, 3) -- backpack slot 1: a stack of 3
SetContainerItem(0, 2, 5001, 1)
SetContainerItem(3, 1, 6000, 1) -- bank bag

C_Container = {}

function C_Container.GetContainerNumSlots(bagID) return 5 end

function C_Container.GetContainerItemInfo(bagID, slotID)
  return (Stubs.containerItemInfo[bagID] or {})[slotID]
end

function C_Container.GetContainerItemLink(bagID, slotID)
  local info = C_Container.GetContainerItemInfo(bagID, slotID)
  if not info or not info.itemID then
    return nil
  end
  return "|cff00ff00Stub Item " .. tostring(info.itemID) .. "|r"
end

function C_Container.GetContainerItemDurability(bagID, slotID)
  return 20, 100
end

function C_Container.GetContainerItemCooldown(bagID, slotID) return 0, 0, 0 end

function C_Container.GetContainerItemPurchaseInfo() return false end

function C_Container.GetItemCount(itemID) return 1 end

function C_Container.SplitContainerItem(bagID, slotID, count)
  Stubs.Log("C_Container.SplitContainerItem|" .. bagID .. "|" .. slotID .. "|" .. tostring(count))
end

C_Item = {}

function C_Item.IsEquippableItem(itemID)
  return itemID == 5001
end

function C_Item.IsUsableItem(itemID)
  return itemID == 5002
end

function C_Item.IsNonConsumable() return false end

function C_Item.DidItemfailToUse() return false end

Stubs.interaction = nil

Enum = {
  PlayerInteractionType = { Banker = 3 },
  AddOnRestrictionType = { Combat = 1 },
}

C_PlayerInteractionManager = {}

function C_PlayerInteractionManager.IsInteractingWithNpcOfType(kind)
  return Stubs.interaction == kind
end

----------------------------------------------------------------------------
-- Blizzard gamepad globals
----------------------------------------------------------------------------

GAMEPAD_FACE_BOTTOM = "PAD1"
GAMEPAD_FACE_RIGHT = "PAD2"
GAMEPAD_FACE_LEFT = "PAD3"
GAMEPAD_FACE_TOP = "PAD4"

Stubs.gamepadEnabled = true

InputUtil = {}

function InputUtil.IsGamepadUIEnabled()
  return Stubs.gamepadEnabled
end

function InputUtil.IsGamepadControlMode()
  return Stubs.gamepadEnabled
end

function Stubs.SetGamepadUIEnabled(value)
  Stubs.gamepadEnabled = value and true or false
end

Stubs.stack = nil

function debugstack(...)
  return Stubs.stack or "stubs\n"
end

GamepadSharedUtility = {}

function GamepadSharedUtility.CreatePromptedBinding(key, debugName)
  local prompt = { key = key, debugName = debugName, bindings = {} }
  function prompt:AddFooterBinding(options)
    table.insert(prompt.bindings, options)
  end
  return prompt
end

function GamepadSharedUtility.CreatePromptedBindingFooter(owner, debugName)
  local footer = { debugName = debugName, prompts = {}, isShown = false }
  _G[debugName] = footer
  function footer:AddPromptedBinding(prompt)
    table.insert(footer.prompts, prompt)
  end
  function footer:Finalize()
    footer.finalized = true
  end
  function footer:SetCustomAnchor(anchor)
    footer.customAnchor = anchor
  end
  function footer:ApplyInputLegendAttachment()
    footer.attached = true
  end
  function footer:ShowAndActivateBindings()
    footer.isShown = true
    Stubs.Log("PromptedBindingFooter.ShowAndActivateBindings|" .. debugName)
  end
  function footer:HideAndDeactivateBindings()
    footer.isShown = false
    Stubs.Log("PromptedBindingFooter.HideAndDeactivateBindings|" .. debugName)
  end
  function footer:Refresh()
    footer.refreshes = (footer.refreshes or 0) + 1
    Stubs.Log("PromptedBindingFooter.Refresh|" .. debugName)
  end
  return footer
end

GamepadMode = {}

local focusManager = {
  shownFrames = {},
  isUIFocused = false,
  focusedFrame = nil,
}

function focusManager:FrameShown(frame)
  Stubs.Log("GamepadMode.FrameControlsManager.FrameShown|" .. tostring(frame:GetName()))
  table.insert(self.shownFrames, frame)
  if frame.smartNavPanelInfoAddedCallback then
    frame.smartNavPanelInfoAddedCallback()
  end
end

function focusManager:FrameHidden(frame)
  Stubs.Log("GamepadMode.FrameControlsManager.FrameHidden|" .. tostring(frame:GetName()))
  for index, shownFrame in ipairs(self.shownFrames) do
    if shownFrame == frame then
      table.remove(self.shownFrames, index)
      break
    end
  end
  if self.focusedFrame == frame then
    self.isUIFocused = false
    self.focusedFrame = nil
  end
  if SmartNavigation.activeFrame == frame then
    SmartNavigation.activeFrame = nil
  end
end

function focusManager:FocusFrame(frame)
  self.focusedFrame = frame
  self.isUIFocused = true
  SmartNavigation.activeFrame = frame
  if frame.UnfocusGamepad then
    frame:UnfocusGamepad()
  end
  if frame.FocusGamepad then
    frame:FocusGamepad()
  end
end

GamepadMode.FrameControlsManager = focusManager
Stubs.focusManager = focusManager

SmartNavigation = {}

function SmartNavigation_IsGamepadControlMode()
  return Stubs.gamepadEnabled
end

function SmartNavigation_IsCurrentButtonClickable()
  return true
end

function SmartNavigation_IsCurrentButtonDestructive()
  return false
end

function SmartNavigation:SetTargetButtonForFrame(frame, button)
  Stubs.Log("SmartNavigation.SetTargetButtonForFrame|" .. tostring(frame:GetName()) .. "|" .. tostring(button:GetName()))
  self.targets = self.targets or {}
  self.targets[frame] = button
  if self.activeFrame == frame then
    self.currentButton = button
  end
end

function SmartNavigation:GetActiveFrame()
  return self.activeFrame
end

function SmartNavigation:GetCurrentButton()
  return self.currentButton
end

function SmartNavigation:RefreshButtonGroups(frame)
  Stubs.Log("SmartNavigation.RefreshButtonGroups|" .. tostring(frame:GetName()))
end

function SmartNavigation_MarkFrameIgnored(frame)
  Stubs.Log("SmartNavigation_MarkFrameIgnored|" .. tostring(frame:GetName()))
  frame.ignored = true
end

MenuFrame = { SetDisplayMode = function() end }

MenuUtil = {}
Stubs.activeContextMenu = nil

function MenuUtil.CreateContextMenu(owner, populate)
  local menu = { owner = owner, entries = {} }
  function menu:SetTag(tag)
    menu.tag = tag
    Stubs.Log("Menu.SetTag|" .. tostring(tag))
  end
  function menu:CreateButton(label, callback)
    table.insert(menu.entries, { label = label, callback = callback })
  end
  function menu:CreateDivider() end
  function menu:CreateTitle(label) end
  Stubs.activeContextMenu = menu
  populate(nil, menu)
end

function Stubs.HasContextEntry(label)
  local menu = Stubs.activeContextMenu
  assert(menu, "no context menu open")
  for _, entry in ipairs(menu.entries) do
    if entry.label == label then
      return true
    end
  end
  return false
end

StackSplitFrame = {}

function StackSplitFrame:OpenStackSplitFrame(maxSplit, button, point1, point2)
  Stubs.Log("StackSplitFrame:OpenStackSplitFrame|" .. tostring(maxSplit))
end

----------------------------------------------------------------------------
-- Item buttons and anchors
----------------------------------------------------------------------------

local itemButtonCounter = 0

function Stubs.MakeItemButton(parent, index)
  itemButtonCounter = itemButtonCounter + 1
  local button = MakeFrame("ContainerItemButton" .. itemButtonCounter, parent, "ItemButton")
  button.id = index
  button.hasItem = true
  button.quality = 1
  button.isBag = false
  button.isSoulBound = false
  button.buttonContext = "ButtonContext_ContainerFrameItemButton"
  button.bagID = 0
  button.BGR = { itemID = 5000, itemQuality = 1 }
  function button:GetID() return self.id end
  function button:GetBagID() return self.bagID end
  function button:UpdateTooltip() end
  function button:IsReadable() return false end
  function button:Click(buttonKind)
    Stubs.Log(tostring(self:GetName()) .. ":Click|" .. tostring(buttonKind))
  end
  return button
end

function Stubs.AddAnchor(region, parent, point, x, y)
  region.x = (parent.x or 0) + x
  region.y = (parent.y or 0) + y
  region.width = 20
  region.height = 20
end

----------------------------------------------------------------------------
-- Blizzard frames BetterBags Controller interacts with
----------------------------------------------------------------------------

-- BetterBags re-parents Blizzard's own bag frames under a sneaky frame
-- (core/init.lua), which is what makes them invisible to the gamepad UI.
BetterBagsHiddenParent = MakeFrame("BetterBagsHiddenParent", UIParent)
BetterBagsHiddenParent.shown = false
BetterBagsHiddenParent.visible = false

ContainerFrameCombinedBags = MakeFrame("ContainerFrameCombinedBags", BetterBagsHiddenParent)
ContainerFrameCombinedBags.shown = false
ContainerFrameCombinedBags.visible = false

BankFrame = MakeFrame("BankFrame", BetterBagsHiddenParent)
BankFrame.shown = false
BankFrame.visible = false
BankFrame.Close = function(self) self:Hide() end

function ToggleBackpack_Combined()
  if ContainerFrameCombinedBags:IsShown() then
    ContainerFrameCombinedBags:Hide()
  else
    ContainerFrameCombinedBags:Show()
  end
end

MerchantFrame = MakeFrame("MerchantFrame", UIParent)
MerchantFrame.shown = false
MerchantFrame.visible = false
MerchantFrame.selectedTab = 1

----------------------------------------------------------------------------
-- BetterBags surface
----------------------------------------------------------------------------

Stubs.betterBags = { backpack = nil, bank = nil, toggles = 0 }

function Stubs.MakeWindow(name)
  local window = MakeFrame(name, UIParent)
  window.shown = false
  window.visible = false

  for i = 1, 5 do
    local item = Stubs.MakeItemButton(window, i)
    item.name = name .. "Item" .. i
    _G[item.name] = item
    Stubs.AddAnchor(item, window, "CENTER", 50 * i, 0)
  end
  window.searchBox = MakeFrame(name .. "SearchBox", window)

  _G[name] = window
  return window
end

Stubs.betterBags.backpack = Stubs.MakeWindow("BetterBagsBagBackpack")
Stubs.betterBags.bank = Stubs.MakeWindow("BetterBagsBagBank")

function BetterBags_ToggleBags()
  Stubs.betterBags.toggles = Stubs.betterBags.toggles + 1
  if Stubs.betterBags.backpack:IsVisible() then
    Stubs.betterBags.backpack:Hide()
    Stubs.betterBags.bank:Hide()
  else
    Stubs.betterBags.backpack:Show()
    Stubs.betterBags.bank:Show()
  end
end
