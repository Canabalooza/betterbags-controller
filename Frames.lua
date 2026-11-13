local _, addonTable = ...

--[[
  Discovers BetterBags' windows by their global frame names (the classic UI
  creates BetterBagsBagBackpack/Bank, the Next UI BetterBagsNext*) and mirrors
  their visibility into GamepadMode.FrameControlsManager. Registration gives
  D-pad navigation, A/B, LT/RT paging and the focus glow (BetterBags windows
  are built on ButtonFrameTemplate, which carries Blizzard's
  FocusFramesInterfaceMixin).
]]

addonTable.Frames = {}
local Frames = addonTable.Frames
local Core = addonTable.Core
local Constants = addonTable.Constants

local Events = Constants.Events

local infoByFrame = {}

local refreshQueued = false

----------------------------------------------------------------------------
-- Lookup
----------------------------------------------------------------------------

function Frames.GetInfo(frame)
  return infoByFrame[frame]
end

function Frames.AnyVisible(kind)
  for frame, info in pairs(infoByFrame) do
    if info.kind == kind and frame:IsVisible() then
      return true
    end
  end
  return false
end

function Frames.GetCounts()
  local known, tracked = 0, 0
  for frame in pairs(infoByFrame) do
    known = known + 1
    if Core.IsTracked(frame) then
      tracked = tracked + 1
    end
  end
  return known, tracked
end

----------------------------------------------------------------------------
-- Finding a sensible button for the cursor to start on
----------------------------------------------------------------------------

local function FindFirstItemButton(frame)
  local root = frame.Container
  if type(root) ~= "table" then
    root = frame
  end
  local best, bestLeft, bestTop

  local function Visit(region, depth)
    if depth > 10 or not region.IsObjectType then
      return
    end
    if region:IsObjectType("ItemButton") then
      if region:IsVisible() then
        local left, top = region:GetLeft(), region:GetTop()
        if left and top then
          local higher = not best or top > bestTop + 0.5
          local sameRowFurtherLeft = best and math.abs(top - bestTop) <= 0.5 and left < bestLeft
          if higher or sameRowFurtherLeft then
            best, bestLeft, bestTop = region, left, top
          end
        end
      end
      return
    end
    for _, child in ipairs({ region:GetChildren() }) do
      Visit(child, depth + 1)
    end
  end

  Visit(root, 0)
  return best
end

local function ApplyTarget(frame)
  local target = FindFirstItemButton(frame)
  if target then
    SmartNavigation:SetTargetButtonForFrame(frame, target)
  end
end

----------------------------------------------------------------------------
-- Registration with the focus manager
----------------------------------------------------------------------------

local function ApplyMarkers(info)
  if info.markersApplied then
    return
  end
  -- Search boxes need a keyboard; keep the cursor out of them.
  local search = info.frame.searchBox or info.frame.SearchWidget or info.frame.SearchBox
  if type(search) == "table" then
    SmartNavigation_MarkFrameIgnored(search)
  end
  info.markersApplied = true
end

local function Register(info)
  if Core.IsTracked(info.frame) then
    return
  end
  ApplyMarkers(info)
  Core.GetFocusManager():FrameShown(info.frame)
end

local function Unregister(info)
  if not Core.IsTracked(info.frame) then
    return
  end
  Core.GetFocusManager():FrameHidden(info.frame)
end

local function OnFrameShow(frame)
  local info = infoByFrame[frame]
  if not info then
    return
  end
  Core.TriggerEvent(Events.FrameVisibilityChanged, info, true)
  if Core.CanTouchGamepadUI() then
    Register(info)
  end
end

local function OnFrameHide(frame)
  local info = infoByFrame[frame]
  if not info then
    return
  end
  Core.TriggerEvent(Events.FrameVisibilityChanged, info, false)
  if Core.CanTouchGamepadUI() then
    Unregister(info)
  end
end

----------------------------------------------------------------------------
-- Callbacks Blizzard's gamepad systems invoke on registered frames
----------------------------------------------------------------------------

local function OnFocusGamepad(frame)
  Core.TriggerEvent(Events.FrameFocused, frame)
end

local function OnUnfocusGamepad(frame)
  Core.TriggerEvent(Events.FrameUnfocused, frame)
end

local function OnSmartNavSelect(frame)
  addonTable.Legend.RequestRefresh(frame)
end

local function Setup(frame, kind)
  if infoByFrame[frame] then
    return
  end
  local info = { frame = frame, kind = kind }
  infoByFrame[frame] = info

  frame:HookScript("OnShow", OnFrameShow)
  frame:HookScript("OnHide", OnFrameHide)

  frame.FocusGamepad = OnFocusGamepad
  frame.UnfocusGamepad = OnUnfocusGamepad
  frame.SmartNavigationCloseHandler = addonTable.Actions.CloseHandler
  frame.SmartNavigationOnSelect = OnSmartNavSelect
  frame.smartNavPanelInfoAddedCallback = function()
    if Core.CanTouchGamepadUI() then
      ApplyTarget(frame)
    end
  end

  if frame:IsVisible() then
    OnFrameShow(frame)
  end
end

----------------------------------------------------------------------------
-- Resolving BetterBags windows by name
----------------------------------------------------------------------------

local pendingNames = {}

function Frames.ResolvePending()
  for name, kind in pairs(pendingNames) do
    local frame = _G[name]
    if type(frame) == "table" and type(frame.HookScript) == "function" then
      pendingNames[name] = nil
      Setup(frame, kind)
    end
  end
end

local function RetryResolution()
  if not Core.IsInitialized() then
    return
  end
  Frames.ResolvePending()
  if next(pendingNames) ~= nil then
    C_Timer.After(Constants.RESOLVE_RETRY_SECONDS, RetryResolution)
  end
end

----------------------------------------------------------------------------
-- Keeping Blizzard's bookkeeping in step with reality
----------------------------------------------------------------------------

-- Brings the focus manager in line with what is visible; used at login, after
-- combat and when the Gamepad UI is switched on.
function Frames.Sync()
  Frames.ResolvePending()
  if not Core.CanTouchGamepadUI() then
    return
  end
  for frame, info in pairs(infoByFrame) do
    local visible = frame:IsVisible()
    local tracked = Core.IsTracked(frame)
    if visible and not tracked then
      Register(info)
    elseif not visible and tracked then
      Unregister(info)
    end
  end
  local focused = Core.GetFocusedFrame()
  if focused and infoByFrame[focused] then
    OnFocusGamepad(focused)
  end
end

-- BetterBags re-parents item buttons on every layout pass, which
-- SmartNavigation does not notice on its own.
local function RefreshNavigation()
  if not Core.CanTouchGamepadUI() then
    return
  end
  for frame in pairs(infoByFrame) do
    if frame:IsVisible() and Core.IsTracked(frame) then
      SmartNavigation:RefreshButtonGroups(frame)
      if SmartNavigation:GetActiveFrame() == frame then
        local current = SmartNavigation:GetCurrentButton()
        if not current or not current:IsVisible() or not Core.IsDescendant(current, frame) then
          ApplyTarget(frame)
        end
        addonTable.Legend.RequestRefresh(frame)
      end
    end
  end
end

function Frames.RequestRefresh()
  if refreshQueued then
    return
  end
  refreshQueued = true
  Core.NextFrame(function()
    refreshQueued = false
    RefreshNavigation()
  end)
end

----------------------------------------------------------------------------
-- Setup
----------------------------------------------------------------------------

local function RefreshTick()
  if not Core.IsInitialized() then
    return
  end
  if Core.IsGamepadUIEnabled() then
    Frames.RequestRefresh()
  end
  C_Timer.After(Constants.REFRESH_SECONDS, RefreshTick)
end

function Frames.Initialize()
  for name, kind in pairs(Constants.WINDOW_NAMES) do
    pendingNames[name] = kind
  end
  Frames.ResolvePending()
  C_Timer.After(Constants.RESOLVE_RETRY_SECONDS, RetryResolution)
  C_Timer.After(Constants.REFRESH_SECONDS, RefreshTick)
end
