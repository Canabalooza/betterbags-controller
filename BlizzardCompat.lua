local _, addonTable = ...

--[[
  Keeps the client's bag state consistent while BetterBags hides Blizzard's
  own bag frames under BetterBagsSneakyFrame: the radial menu's Bags entry
  calls ToggleBackpack_Combined, and IsBagOpen reads
  ContainerFrameCombinedBags, which BetterBags has made invisible. Also
  unregisters the ghost focus Blizzard registers for those hidden frames.
]]

addonTable.BlizzardCompat = {}
local BlizzardCompat = addonTable.BlizzardCompat
local Core = addonTable.Core
local Constants = addonTable.Constants

----------------------------------------------------------------------------
-- Ghost focus for the hidden Blizzard frames
----------------------------------------------------------------------------

local function IsOrphanedBlizzardFrame(frame)
  local name = frame.GetName and frame:GetName()
  if not name then
    return false
  end
  if Constants.ORPHANED_BLIZZARD_FRAMES[name] then
    return true
  end
  return name:match(Constants.ORPHANED_BLIZZARD_FRAME_PATTERN) ~= nil
end

local function OnFocusManagerFrameShown(manager, frame)
  if not Core.CanTouchGamepadUI() then
    return
  end
  if IsOrphanedBlizzardFrame(frame) and Core.IsTracked(frame) then
    manager:FrameHidden(frame)
  end
end

----------------------------------------------------------------------------
-- Radial menu "Bags" entry and IsBagOpen() state
----------------------------------------------------------------------------

local function AnyBackpackVisible()
  return addonTable.Frames.AnyVisible(Constants.Kind.Backpack)
end

local function IsBlizzardBagFrameHiddenByBetterBags()
  return ContainerFrameCombinedBags ~= nil
    and not ContainerFrameCombinedBags:IsVisible()
    and ContainerFrameCombinedBags:GetParent() ~= UIParent
end

local function OnToggleBackpackCombined()
  if not Core.IsGamepadUIEnabled() or not IsBlizzardBagFrameHiddenByBetterBags() then
    return
  end
  -- React only to direct calls (the radial menu); calls that came through
  -- BetterBags' own open/close path are already reflected in its windows.
  local stack = debugstack(1, 10, 0) or ""
  if stack:find("`ToggleBackpack'", 1, true)
    or stack:find("ToggleAllBags", 1, true)
    or stack:find("BetterBags_ToggleBags", 1, true)
    or stack:find("OpenAllBags", 1, true)
    or stack:find("CloseAllBags", 1, true) then
    return
  end
  local blizzardSaysOpen = ContainerFrameCombinedBags:IsShown()
  if blizzardSaysOpen ~= AnyBackpackVisible() then
    BetterBags_ToggleBags()
  end
end

local function OnBetterBagsFrameVisibilityChanged(info, shown)
  if (info.kind ~= Constants.Kind.Backpack and info.kind ~= Constants.Kind.Bank)
    or not Core.IsGamepadUIEnabled() then
    return
  end
  if not IsBlizzardBagFrameHiddenByBetterBags() then
    return
  end
  if shown then
    if not ContainerFrameCombinedBags:IsShown() then
      ContainerFrameCombinedBags:Show()
    end
  elseif not AnyBackpackVisible() and ContainerFrameCombinedBags:IsShown() then
    ContainerFrameCombinedBags:Hide()
  end
end

----------------------------------------------------------------------------
-- Setup
----------------------------------------------------------------------------

function BlizzardCompat.Initialize()
  local manager = Core.GetFocusManager()
  if manager and type(manager.FrameShown) == "function" then
    hooksecurefunc(manager, "FrameShown", OnFocusManagerFrameShown)
  end
  if type(ToggleBackpack_Combined) == "function" then
    hooksecurefunc("ToggleBackpack_Combined", OnToggleBackpackCombined)
  end
  Core.RegisterCallback(Constants.Events.FrameVisibilityChanged, OnBetterBagsFrameVisibilityChanged)
end
