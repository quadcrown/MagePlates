-- MagePlates.lua
-- Shows an Arcane Explosion icon on nameplates if they are within 10 yards of the player.
--
-- Slash commands: /mageplates or /mp
--   on   : enable AE icon on nameplates
--   off  : disable AE icon on nameplates
--   help : usage info

------------------------------------------------
-- 0) Saved Variables & Defaults
------------------------------------------------
-- Do NOT assume MagePlatesDB is defined yet. We only define a local fallback:
local MagePlates_Defaults = {
  enabled = true, -- Show Arcane Explosion icon by default
}

------------------------------------------------
-- 1) Slash Command Handler
------------------------------------------------
local function MagePlates_SlashCommand(msg)
  if type(msg) ~= "string" then
    msg = ""
  end
  msg = string.lower(msg)

  if msg == "on" then
    MagePlatesDB.enabled = true
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[MagePlates]|r AE icon: |cff00ff00ENABLED|r.")
  elseif msg == "off" then
    MagePlatesDB.enabled = false
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[MagePlates]|r AE icon: |cffff0000DISABLED|r.")
  elseif msg == "help" or msg == "" then
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[MagePlates]|r usage:")
    DEFAULT_CHAT_FRAME:AddMessage("  /mageplates on    -> Enable Arcane Explosion icon on nameplates")
    DEFAULT_CHAT_FRAME:AddMessage("  /mageplates off   -> Disable Arcane Explosion icon on nameplates")
    DEFAULT_CHAT_FRAME:AddMessage("  /mageplates help  -> Show this help text")
  else
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[MagePlates]|r: Unrecognized command '"..msg.."'. Type '/mageplates help' for usage.")
  end
end

-- Create slash commands
SLASH_MAGEPLATES1 = "/mageplates"
SLASH_MAGEPLATES2 = "/mp"
SlashCmdList["MAGEPLATES"] = MagePlates_SlashCommand

------------------------------------------------
-- 2) Range Check Function
------------------------------------------------
-- Uses your UnitXP distance call:
--   /script local result = UnitXP("distanceBetween", "player", "target", "AoE");
-- We assume it returns a numeric distance to be tested against <= 10.
------------------------------------------------
local function IsUnitInArcaneExplosionRange(unit)
  if not UnitExists(unit) then
    return false
  end
  local distance = UnitXP("distanceBetween", "player", unit, "AoE")
  if distance and distance <= 10 then
    return true
  end
  return false
end

------------------------------------------------
-- 3) Arcane Explosion Icon
------------------------------------------------
local AEIconTexture = "Interface\\Icons\\Spell_Nature_WispSplode"

------------------------------------------------
-- 4) pfUI Nameplate Hook
------------------------------------------------
local function HookPfuiNameplates()
  if not pfUI or not pfUI.nameplates then return end

  local oldOnCreate = pfUI.nameplates.OnCreate
  pfUI.nameplates.OnCreate = function(frame)
    oldOnCreate(frame)

    local plate = frame.nameplate
    if not plate or not plate.health then return end

    local aeIcon = plate.health:CreateTexture(nil, "OVERLAY")
    aeIcon:SetTexture(AEIconTexture)
    aeIcon:SetWidth(25)
    aeIcon:SetHeight(25)
    aeIcon:SetPoint("TOP", plate.health, "TOP", 0, 50)
    aeIcon:Hide()
    plate.aeIcon = aeIcon
  end

  local oldOnDataChanged = pfUI.nameplates.OnDataChanged
  pfUI.nameplates.OnDataChanged = function(self, plate)
    oldOnDataChanged(self, plate)
    if not plate or not plate.aeIcon then
      return
    end

    -- If the addon is disabled, hide
    if not MagePlatesDB.enabled then
      plate.aeIcon:Hide()
      return
    end

    -- Try to get a unit reference from pfUI
    local guid = plate.parent:GetName(1)
    if guid and UnitExists(guid) then
      if IsUnitInArcaneExplosionRange(guid) then
        plate.aeIcon:Show()
      else
        plate.aeIcon:Hide()
      end
    else
      -- Fallback to "target"
      if IsUnitInArcaneExplosionRange("target") then
        plate.aeIcon:Show()
      else
        plate.aeIcon:Hide()
      end
    end
  end
end

------------------------------------------------
-- 5) Default Blizzard Nameplates
------------------------------------------------
local nameplateCache = {}

local function CreatePlateElements(frame)
  local aeIcon = frame:CreateTexture(nil, "OVERLAY")
  aeIcon:SetTexture(AEIconTexture)
  aeIcon:SetWidth(25)
  aeIcon:SetHeight(25)
  aeIcon:SetPoint("TOP", frame, "TOP", 0, 60)
  aeIcon:Hide()

  nameplateCache[frame] = {
    aeIcon = aeIcon,
  }
end

local function UpdateDefaultNameplates()
  local frames = { WorldFrame:GetChildren() }
  for i, frame in pairs(frames) do
    if frame:IsVisible() and frame:GetName() == nil then
      local healthBar = frame:GetChildren()
      if healthBar and healthBar:IsObjectType("StatusBar") then

        if not nameplateCache[frame] then
          CreatePlateElements(frame)
        end

        local aeIcon = nameplateCache[frame].aeIcon

        if not MagePlatesDB.enabled then
          aeIcon:Hide()
        else
          local guid = frame:GetName(1)
          local unitToCheck

          if guid and guid ~= "0x0000000000000000" and UnitExists(guid) then
            unitToCheck = guid
          else
            unitToCheck = "target"
          end

          if IsUnitInArcaneExplosionRange(unitToCheck) then
            aeIcon:Show()
          else
            aeIcon:Hide()
          end
        end
      end
    end
  end
end

local function HookDefaultNameplates()
  local updater = CreateFrame("Frame", "MagePlates_DefaultFrame")
  updater.tick = 0
  updater:SetScript("OnUpdate", function()
    if not this.tick then
      this.tick = 0
    end
    if this.tick > GetTime() then
      return
    end
    this.tick = GetTime() + 0.5
    UpdateDefaultNameplates()
  end)
end

------------------------------------------------
-- 6) Deferred Hook Setup
------------------------------------------------
local function MagePlates_SetupHooks()
  -- Decide which nameplate system to hook AFTER MagePlatesDB is ready
  if pfUI and pfUI.nameplates then
    HookPfuiNameplates()
  else
    HookDefaultNameplates()
  end
end

------------------------------------------------
-- 7) Main Addon Frame & Events
------------------------------------------------
local MagePlatesFrame = CreateFrame("Frame", "MagePlates_MainFrame")
MagePlatesFrame:RegisterEvent("VARIABLES_LOADED")
MagePlatesFrame:RegisterEvent("PLAYER_LOGIN")

MagePlatesFrame:SetScript("OnEvent", function()
  if event == "VARIABLES_LOADED" then
    -- Create or reuse MagePlatesDB
    if not MagePlatesDB then
      MagePlatesDB = {}
    end

    -- Fill in any missing defaults
    for k, v in pairs(MagePlates_Defaults) do
      if MagePlatesDB[k] == nil then
        MagePlatesDB[k] = v
      end
    end

    -- Now that we have MagePlatesDB, set up nameplate hooks
    MagePlates_SetupHooks()

    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[MagePlates]|r loaded. Type '/mageplates help' for options.")

  elseif event == "PLAYER_LOGIN" then
    -- If your 1.12 server returns a second return from UnitExists, store it
    local _, playerGUID = UnitExists("player")
    MagePlatesDB.playerGUID = playerGUID
  end
end)
