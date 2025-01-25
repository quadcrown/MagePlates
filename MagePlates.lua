-- MagePlates.lua
-- Shows Arcane Explosion (range check only), Frost Nova, and Cone of Cold icons on nameplates.
-- Frost Nova & Cone of Cold do NOT read real cooldowns; instead, they track a static timer
-- after we detect "Your Frost Nova" or "Your Cone of Cold" in the combat log.
--
-- Slash commands: /mageplates (or /mp)
--   aeon/aeoff  -> toggle Arcane Explosion icon
--   fnon/fnoff  -> toggle Frost Nova icon
--   cocon/cocoff-> toggle Cone of Cold icon
--   on/off      -> quick toggle for AE only
--   help        -> usage info

------------------------------------------------
-- 0) Static Cooldown Settings
------------------------------------------------
local FROST_NOVA_CD = 25 -- seconds (example rank 4 Frost Nova in vanilla)
local CONE_COLD_CD  = 10 -- seconds (example rank 5 Cone of Cold in vanilla)

-- We'll store the "end time" of each cooldown:
local frostNovaEndTime = 0
local coneColdEndTime  = 0

------------------------------------------------
-- 1) SavedVars Defaults
------------------------------------------------
local MagePlates_Defaults = {
  enableAE  = true,  -- Arcane Explosion (10 yds)
  enableFN  = false,  -- Frost Nova (12 yds, static cd)
  enableCoC = false,  -- Cone of Cold (12 yds, static cd)
}

------------------------------------------------
-- 2) Slash Commands
------------------------------------------------
local function MagePlates_SlashCommand(msg)
  if type(msg) ~= "string" then
    msg = ""
  end
  msg = string.lower(msg)

  -- Arcane Explosion toggles
  if msg == "aeon" then
    MagePlatesDB.enableAE = true
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[MagePlates]|r Arcane Explosion icon: ENABLED.")
    return
  elseif msg == "aeoff" then
    MagePlatesDB.enableAE = false
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[MagePlates]|r Arcane Explosion icon: DISABLED.")
    return
  end

  -- Frost Nova toggles
  if msg == "fnon" then
    MagePlatesDB.enableFN = true
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[MagePlates]|r Frost Nova icon: ENABLED.")
    return
  elseif msg == "fnoff" then
    MagePlatesDB.enableFN = false
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[MagePlates]|r Frost Nova icon: DISABLED.")
    return
  end

  -- Cone of Cold toggles
  if msg == "cocon" then
    MagePlatesDB.enableCoC = true
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[MagePlates]|r Cone of Cold icon: ENABLED.")
    return
  elseif msg == "cocoff" then
    MagePlatesDB.enableCoC = false
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[MagePlates]|r Cone of Cold icon: DISABLED.")
    return
  end

  -- Quick on/off = Arcane Explosion only
  if msg == "on" then
    MagePlatesDB.enableAE = true
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[MagePlates]|r Arcane Explosion icon: ENABLED.")
    return
  elseif msg == "off" then
    MagePlatesDB.enableAE = false
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[MagePlates]|r Arcane Explosion icon: DISABLED.")
    return
  end

  -- Help
  if msg == "help" or msg == "" then
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[MagePlates]|r usage:")
    DEFAULT_CHAT_FRAME:AddMessage("  /mageplates on/off       -> Toggle Arcane Explosion only")
    DEFAULT_CHAT_FRAME:AddMessage("  /mageplates aeon/aeoff   -> Toggle Arcane Explosion icon")
    DEFAULT_CHAT_FRAME:AddMessage("  /mageplates fnon/fnoff   -> Toggle Frost Nova icon")
    DEFAULT_CHAT_FRAME:AddMessage("  /mageplates cocon/cocoff -> Toggle Cone of Cold icon")
    DEFAULT_CHAT_FRAME:AddMessage("  /mageplates help         -> Show this help text")
    return
  end

  -- Unknown command
  DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[MagePlates]|r: Unrecognized command '"..msg.."'. Type '/mageplates help' for usage.")
end

SLASH_MAGEPLATES1 = "/mageplates"
SLASH_MAGEPLATES2 = "/mp"
SlashCmdList["MAGEPLATES"] = MagePlates_SlashCommand

------------------------------------------------
-- 3) Range Check
------------------------------------------------
local function IsUnitInRange(unit, maxRange)
  if not UnitExists(unit) then
    return false
  end
  local dist = UnitXP("distanceBetween", "player", unit, "AoE")
  if dist and dist <= maxRange then
    return true
  end
  return false
end

------------------------------------------------
-- 4) Event Frame for Static Cooldown Tracking
------------------------------------------------
local SpellCDFrame = CreateFrame("Frame", "MagePlates_SpellCDFrame", UIParent)
SpellCDFrame:RegisterEvent("CHAT_MSG_SPELL_SELF_DAMAGE")
SpellCDFrame:RegisterEvent("CHAT_MSG_SPELL_SELF_BUFF")

SpellCDFrame:SetScript("OnEvent", function()
  local msg = arg1 or ""
  if string.find(msg, "Your Frost Nova") then
    frostNovaEndTime = GetTime() + FROST_NOVA_CD
  end
  if string.find(msg, "Your Cone of Cold") then
    coneColdEndTime = GetTime() + CONE_COLD_CD
  end
end)

local function GetStaticCooldownLeft(spell)
  local now = GetTime()
  if spell == "FrostNova" then
    local left = frostNovaEndTime - now
    return (left > 0) and left or 0
  elseif spell == "ConeOfCold" then
    local left = coneColdEndTime - now
    return (left > 0) and left or 0
  end
  return 0
end

------------------------------------------------
-- 5) Icon Textures
------------------------------------------------
local AEIconTexture  = "Interface\\Icons\\Spell_Nature_WispSplode"
local FNIconTexture  = "Interface\\Icons\\Spell_Frost_FrostNova"
local CoCIconTexture = "Interface\\Icons\\Spell_Frost_Glacier"

------------------------------------------------
-- 6) Icon Offsets
------------------------------------------------
-- pfUI nameplates remain at the original Y offset (60).
-- Default Blizzard nameplates need a smaller Y offset (30).
local ICON_SPACING = 30

-- We'll make our ArrangeIconsCentered take an explicit offset argument:
local function ArrangeIconsCentered(icons, parent, offsetY)
  local n = table.getn(icons) -- 1.12 does not have '#'
  if n == 0 then return end

  for i = 1, n do
    local iconData = icons[i]
    local icon = iconData.icon
    icon:ClearAllPoints()
    local offsetX = (i - (n + 1) / 2) * ICON_SPACING
    icon:SetPoint("TOP", parent, "TOP", offsetX, offsetY)

    if iconData.timerFS then
      iconData.timerFS:ClearAllPoints()
      iconData.timerFS:SetPoint("CENTER", icon, "CENTER", 0, 0)
    end
  end
end

------------------------------------------------
-- 7) pfUI Nameplates
------------------------------------------------
local function HookPfuiNameplates()
  if not pfUI or not pfUI.nameplates then return end

  local oldOnCreate = pfUI.nameplates.OnCreate
  pfUI.nameplates.OnCreate = function(frame)
    oldOnCreate(frame)

    local plate = frame.nameplate
    if not plate or not plate.health then return end

    -- Arcane Explosion
    local aeIcon = plate.health:CreateTexture(nil, "OVERLAY")
    aeIcon:SetTexture(AEIconTexture)
    aeIcon:SetWidth(25)
    aeIcon:SetHeight(25)
    aeIcon:Hide()
    plate.aeIcon = aeIcon

    -- Frost Nova
    local fnIcon = plate.health:CreateTexture(nil, "OVERLAY")
    fnIcon:SetTexture(FNIconTexture)
    fnIcon:SetWidth(25)
    fnIcon:SetHeight(25)
    fnIcon:Hide()
    plate.fnIcon = fnIcon

    local fnTimer = plate.health:CreateFontString(nil, "OVERLAY")
    fnTimer:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
    fnTimer:Hide()
    plate.fnTimer = fnTimer

    -- Cone of Cold
    local cocIcon = plate.health:CreateTexture(nil, "OVERLAY")
    cocIcon:SetTexture(CoCIconTexture)
    cocIcon:SetWidth(25)
    cocIcon:SetHeight(25)
    cocIcon:Hide()
    plate.cocIcon = cocIcon

    local cocTimer = plate.health:CreateFontString(nil, "OVERLAY")
    cocTimer:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
    cocTimer:Hide()
    plate.cocTimer = cocTimer
  end

  local oldOnDataChanged = pfUI.nameplates.OnDataChanged
  pfUI.nameplates.OnDataChanged = function(self, plate)
    oldOnDataChanged(self, plate)

    if not plate or not plate.aeIcon or not plate.fnIcon or not plate.cocIcon then
      return
    end

    local guid = plate.parent:GetName(1)
    local unitToCheck = (guid and UnitExists(guid)) and guid or "target"

    local shown = {}

    -- Arcane Explosion
    if MagePlatesDB.enableAE then
      if IsUnitInRange(unitToCheck, 10) then
        plate.aeIcon:Show()
        table.insert(shown, { icon = plate.aeIcon })
      else
        plate.aeIcon:Hide()
      end
    else
      plate.aeIcon:Hide()
    end

    -- Frost Nova
    if MagePlatesDB.enableFN and IsUnitInRange(unitToCheck, 12) then
      local fnLeft = GetStaticCooldownLeft("FrostNova")
      if fnLeft == 0 then
        plate.fnIcon:Show()
        plate.fnTimer:Hide()
        plate.fnTimer:SetText("")
        table.insert(shown, { icon = plate.fnIcon })
      elseif fnLeft <= 3 then
        plate.fnIcon:Show()
        plate.fnTimer:Show()
        plate.fnTimer:SetTextColor(1, 0, 0, 1)
        plate.fnTimer:SetText(tostring(math.floor(fnLeft)))
        table.insert(shown, { icon = plate.fnIcon, timerFS = plate.fnTimer })
      else
        plate.fnIcon:Hide()
        plate.fnTimer:Hide()
        plate.fnTimer:SetText("")
      end
    else
      plate.fnIcon:Hide()
      plate.fnTimer:Hide()
      plate.fnTimer:SetText("")
    end

    -- Cone of Cold
    if MagePlatesDB.enableCoC and IsUnitInRange(unitToCheck, 12) then
      local cocLeft = GetStaticCooldownLeft("ConeOfCold")
      if cocLeft == 0 then
        plate.cocIcon:Show()
        plate.cocTimer:Hide()
        plate.cocTimer:SetText("")
        table.insert(shown, { icon = plate.cocIcon })
      elseif cocLeft <= 3 then
        plate.cocIcon:Show()
        plate.cocTimer:Show()
        plate.cocTimer:SetTextColor(1, 0, 0, 1)
        plate.cocTimer:SetText(tostring(math.floor(cocLeft)))
        table.insert(shown, { icon = plate.cocIcon, timerFS = plate.cocTimer })
      else
        plate.cocIcon:Hide()
        plate.cocTimer:Hide()
        plate.cocTimer:SetText("")
      end
    else
      plate.cocIcon:Hide()
      plate.cocTimer:Hide()
      plate.cocTimer:SetText("")
    end

    -- For pfUI nameplates, we keep the original 60 offset.
    ArrangeIconsCentered(shown, plate.health, 60)
  end
end

------------------------------------------------
-- 8) Default Blizzard Nameplates
------------------------------------------------
local nameplateCache = {}

local function CreatePlateElements(frame)
  local aeIcon = frame:CreateTexture(nil, "OVERLAY")
  aeIcon:SetTexture(AEIconTexture)
  aeIcon:SetWidth(25)
  aeIcon:SetHeight(25)
  aeIcon:Hide()

  local fnIcon = frame:CreateTexture(nil, "OVERLAY")
  fnIcon:SetTexture(FNIconTexture)
  fnIcon:SetWidth(25)
  fnIcon:SetHeight(25)
  fnIcon:Hide()

  local fnTimer = frame:CreateFontString(nil, "OVERLAY")
  fnTimer:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
  fnTimer:Hide()

  local cocIcon = frame:CreateTexture(nil, "OVERLAY")
  cocIcon:SetTexture(CoCIconTexture)
  cocIcon:SetWidth(25)
  cocIcon:SetHeight(25)
  cocIcon:Hide()

  local cocTimer = frame:CreateFontString(nil, "OVERLAY")
  cocTimer:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
  cocTimer:Hide()

  nameplateCache[frame] = {
    aeIcon   = aeIcon,
    fnIcon   = fnIcon,
    fnTimer  = fnTimer,
    cocIcon  = cocIcon,
    cocTimer = cocTimer,
  }
end

local function UpdateDefaultNameplates()
  local frames = { WorldFrame:GetChildren() }
  for _, frame in pairs(frames) do
    if frame:IsVisible() and frame:GetName() == nil then
      local healthBar = frame:GetChildren()
      if healthBar and healthBar:IsObjectType("StatusBar") then

        if not nameplateCache[frame] then
          CreatePlateElements(frame)
        end

        local aeIcon   = nameplateCache[frame].aeIcon
        local fnIcon   = nameplateCache[frame].fnIcon
        local fnTimer  = nameplateCache[frame].fnTimer
        local cocIcon  = nameplateCache[frame].cocIcon
        local cocTimer = nameplateCache[frame].cocTimer

        local guid = frame:GetName(1)
        local unitToCheck = (guid and guid ~= "0x0000000000000000" and UnitExists(guid)) and guid or "target"

        local shown = {}

        -- Arcane Explosion
        if MagePlatesDB.enableAE then
          if IsUnitInRange(unitToCheck, 10) then
            aeIcon:Show()
            table.insert(shown, { icon = aeIcon })
          else
            aeIcon:Hide()
          end
        else
          aeIcon:Hide()
        end

        -- Frost Nova
        local fnLeft = GetStaticCooldownLeft("FrostNova")
        if MagePlatesDB.enableFN and IsUnitInRange(unitToCheck, 12) then
          if fnLeft == 0 then
            fnIcon:Show()
            fnTimer:Hide()
            fnTimer:SetText("")
            table.insert(shown, { icon = fnIcon })
          elseif fnLeft <= 3 then
            fnIcon:Show()
            fnTimer:Show()
            fnTimer:SetTextColor(1, 0, 0, 1)
            fnTimer:SetText(tostring(math.floor(fnLeft)))
            table.insert(shown, { icon = fnIcon, timerFS = fnTimer })
          else
            fnIcon:Hide()
            fnTimer:Hide()
            fnTimer:SetText("")
          end
        else
          fnIcon:Hide()
          fnTimer:Hide()
          fnTimer:SetText("")
        end

        -- Cone of Cold
        local cocLeft = GetStaticCooldownLeft("ConeOfCold")
        if MagePlatesDB.enableCoC and IsUnitInRange(unitToCheck, 12) then
          if cocLeft == 0 then
            cocIcon:Show()
            cocTimer:Hide()
            cocTimer:SetText("")
            table.insert(shown, { icon = cocIcon })
          elseif cocLeft <= 3 then
            cocIcon:Show()
            cocTimer:Show()
            cocTimer:SetTextColor(1, 0, 0, 1)
            cocTimer:SetText(tostring(math.floor(cocLeft)))
            table.insert(shown, { icon = cocIcon, timerFS = cocTimer })
          else
            cocIcon:Hide()
            cocTimer:Hide()
            cocTimer:SetText("")
          end
        else
          cocIcon:Hide()
          cocTimer:Hide()
          cocTimer:SetText("")
        end

        -- For default Blizzard plates, use offsetY=30 (half of 60).
        ArrangeIconsCentered(shown, frame, 30)
      end
    end
  end
end

local function HookDefaultNameplates()
  local updater = CreateFrame("Frame", "MagePlates_DefaultFrame")
  updater.tick = 0
  updater:SetScript("OnUpdate", function()
    if not this.tick then this.tick = 0 end
    if this.tick > GetTime() then return end
    this.tick = GetTime() + 0.5
    UpdateDefaultNameplates()
  end)
end

------------------------------------------------
-- 9) Deferred Hook Setup
------------------------------------------------
local function MagePlates_SetupHooks()
  if pfUI and pfUI.nameplates then
    HookPfuiNameplates()
  else
    HookDefaultNameplates()
  end
end

------------------------------------------------
-- 10) Main Addon Frame & SavedVars
------------------------------------------------
local MagePlatesFrame = CreateFrame("Frame", "MagePlates_MainFrame")
MagePlatesFrame:RegisterEvent("VARIABLES_LOADED")
MagePlatesFrame:RegisterEvent("PLAYER_LOGIN")

MagePlatesFrame:SetScript("OnEvent", function()
  if event == "VARIABLES_LOADED" then
    if not MagePlatesDB then
      MagePlatesDB = {}
    end
    for k, v in pairs(MagePlates_Defaults) do
      if MagePlatesDB[k] == nil then
        MagePlatesDB[k] = v
      end
    end

    MagePlates_SetupHooks()
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[MagePlates]|r loaded. Type '/mageplates help' for options.")

  elseif event == "PLAYER_LOGIN" then
    local _, playerGUID = UnitExists("player")
    MagePlatesDB.playerGUID = playerGUID
  end
end)
