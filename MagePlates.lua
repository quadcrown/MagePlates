-- MagePlates.lua
-- Mage nameplate addon for vanilla 1.12 with:
--   - Arcane Explosion netherwind set detection (>=3 pieces => +2.5 yard range)
--   - Frost Nova/CoC + Arctic Reach detection
--   - Movement leeway + static cooldown approach
--   - *New* filters: hide icons on friendly nameplates or critters
--   - pfUI or default nameplates hooking

------------------------------------------------
-- 0) Settings & Tables
------------------------------------------------

-- Frost Nova / CoC cooldown durations
local FROST_NOVA_CD = 25
local CONE_COLD_CD  = 10

-- Talent: Arctic Reach => +1 yard per rank for Nova/CoC
local arcticReachRank = 0

-- Netherwind set itemIDs (>=3 => netherwindSetActive)
local NetherwindItemIDs = {
  [16914] = true, -- Head
  [16917] = true, -- Shoulders
  [16916] = true, -- Chest
  [16913] = true, -- Gloves
  [16918] = true, -- Wrist
  [16818] = true, -- Belt (verify if correct)
  [16912] = true, -- Boots
  [16915] = true, -- Pants
}

local netherwindSetActive = false

-- We'll store end times for static CDs
local frostNovaEndTime = 0
local coneColdEndTime  = 0

-- Movement detection
local isMoving = false
local lastPlayerX, lastPlayerY = 0, 0

------------------------------------------------
-- 1) Saved Variables & Defaults
------------------------------------------------
local MagePlates_Defaults = {
  enableAE  = true, -- Arcane Explosion
  enableFN  = true, -- Frost Nova
  enableCoC = true, -- Cone of Cold
}

------------------------------------------------
-- 2) Slash Commands
------------------------------------------------
local function MagePlates_SlashCommand(msg)
  if type(msg) ~= "string" then
    msg = ""
  end
  msg = string.lower(msg)

  if msg == "aeon" then
    MagePlatesDB.enableAE = true
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[MagePlates]|r Arcane Explosion: ENABLED.")
    return
  elseif msg == "aeoff" then
    MagePlatesDB.enableAE = false
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[MagePlates]|r Arcane Explosion: DISABLED.")
    return
  end

  if msg == "fnon" then
    MagePlatesDB.enableFN = true
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[MagePlates]|r Frost Nova: ENABLED.")
    return
  elseif msg == "fnoff" then
    MagePlatesDB.enableFN = false
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[MagePlates]|r Frost Nova: DISABLED.")
    return
  end

  if msg == "cocon" then
    MagePlatesDB.enableCoC = true
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[MagePlates]|r Cone of Cold: ENABLED.")
    return
  elseif msg == "cocoff" then
    MagePlatesDB.enableCoC = false
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[MagePlates]|r Cone of Cold: DISABLED.")
    return
  end

  if msg == "on" then
    MagePlatesDB.enableAE = true
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[MagePlates]|r Arcane Explosion: ENABLED.")
    return
  elseif msg == "off" then
    MagePlatesDB.enableAE = false
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[MagePlates]|r Arcane Explosion: DISABLED.")
    return
  end

  if msg == "help" or msg == "" then
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[MagePlates]|r usage:")
    DEFAULT_CHAT_FRAME:AddMessage("  /mageplates on/off       -> Toggle Arcane Explosion only")
    DEFAULT_CHAT_FRAME:AddMessage("  /mageplates aeon/aeoff   -> Toggle Arcane Explosion")
    DEFAULT_CHAT_FRAME:AddMessage("  /mageplates fnon/fnoff   -> Toggle Frost Nova")
    DEFAULT_CHAT_FRAME:AddMessage("  /mageplates cocon/cocoff -> Toggle Cone of Cold")
    DEFAULT_CHAT_FRAME:AddMessage("  /mageplates help         -> Show this help text")
    return
  end

  DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[MagePlates]|r: Unrecognized command '"..msg.."'. Type '/mageplates help' for usage.")
end

SLASH_MAGEPLATES1 = "/mageplates"
SLASH_MAGEPLATES2 = "/mp"
SlashCmdList["MAGEPLATES"] = MagePlates_SlashCommand

------------------------------------------------
-- 3) Talent: Arctic Reach
------------------------------------------------
local function UpdateArcticReachRank()
  local name, _, _, _, rank, _ = GetTalentInfo(3, 11)  -- Frost tab=3, talent=11
  if rank then
    arcticReachRank = rank
  else
    arcticReachRank = 0
  end
end

------------------------------------------------
-- 4) Netherwind Set Detection
------------------------------------------------
local function ExtractItemIDFromLink(itemLink)
  if not itemLink then return nil end
  local s, e, capturedID = string.find(itemLink, "Hitem:(%d+)")
  if capturedID then
    return tonumber(capturedID)
  end
  return nil
end

local function ScanForNetherwind()
  local count = 0
  local slots = {
    "HeadSlot", "NeckSlot", "ShoulderSlot", "BackSlot",
    "ChestSlot", "ShirtSlot", "TabardSlot", "WristSlot",
    "HandsSlot", "WaistSlot", "LegsSlot", "FeetSlot",
    "Finger0Slot", "Finger1Slot", "Trinket0Slot", "Trinket1Slot",
    "MainHandSlot", "SecondaryHandSlot", "RangedSlot", "AmmoSlot"
  }

  for _, slotName in pairs(slots) do
    local slotID = GetInventorySlotInfo(slotName)
    if slotID then
      local itemLink = GetInventoryItemLink("player", slotID)
      if itemLink then
        local itemID = ExtractItemIDFromLink(itemLink)
        if itemID and NetherwindItemIDs[itemID] then
          count = count + 1
        end
      end
    end
  end

  netherwindSetActive = (count >= 5)
end

------------------------------------------------
-- 5) Movement Detection
------------------------------------------------
local isMovingFrame = CreateFrame("Frame", "MagePlates_IsMovingFrame", UIParent)
isMovingFrame.tick = 0
isMovingFrame:SetScript("OnUpdate", function()
  if not this.tick then this.tick = 0 end
  if this.tick > GetTime() then return end
  this.tick = GetTime() + 0.5

  local x, y = UnitPosition("player")
  if x and y then
    local dx = x - lastPlayerX
    local dy = y - lastPlayerY
    local distSq = dx*dx + dy*dy
    if distSq > 0.0001 then
      isMoving = true
    else
      isMoving = false
    end
    lastPlayerX, lastPlayerY = x, y
  end
end)

------------------------------------------------
-- 6) Range Logic
------------------------------------------------
local function GetRangeAlphaForSpell(unit, spellID)
  if not UnitExists(unit) then
    return 0
  end
  local dist = UnitXP("distanceBetween", "player", unit, "AoE")
  if not dist then
    return 0
  end

  local baseRange = 0
  if spellID == "AE" then
    baseRange = 10
    if netherwindSetActive then
      baseRange = baseRange + 2.5
    end
  elseif spellID == "FrostNova" or spellID == "ConeOfCold" then
    baseRange = 10 + arcticReachRank
  else
    baseRange = 10
  end

  if isMoving then
    if dist <= (baseRange + 2) then
      return 1.0
    else
      return 0
    end
  else
    if dist <= baseRange then
      return 1.0
    elseif dist <= (baseRange + 2) then
      return 0.5
    else
      return 0
    end
  end
end

------------------------------------------------
-- 7) Static CD for Nova/CoC
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
-- 8) Icon Layout
------------------------------------------------
local AEIconTexture  = "Interface\\Icons\\Spell_Nature_WispSplode"
local FNIconTexture  = "Interface\\Icons\\Spell_Frost_FrostNova"
local CoCIconTexture = "Interface\\Icons\\Spell_Frost_Glacier"

local ICON_SPACING = 30

local function ArrangeIconsCentered(icons, parent, offsetY)
  local n = table.getn(icons)
  if n == 0 then return end

  for i=1, n do
    local data = icons[i]
    local icon = data.icon
    icon:ClearAllPoints()
    local offsetX = (i - (n+1)/2) * ICON_SPACING
    icon:SetPoint("TOP", parent, "TOP", offsetX, offsetY)

    if data.timerFS then
      data.timerFS:ClearAllPoints()
      data.timerFS:SetPoint("CENTER", icon, "CENTER", 0, 0)
    end
  end
end

------------------------------------------------
-- 9) pfUI Nameplates
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

    ------------------------------------------------
    --  Filter out friendly and critter
    ------------------------------------------------
    if UnitIsFriend("player", unitToCheck) then
      plate.aeIcon:Hide()
      plate.fnIcon:Hide()
      plate.fnTimer:Hide()
      plate.cocIcon:Hide()
      plate.cocTimer:Hide()
      return
    end
    local ctype = UnitCreatureType(unitToCheck)
    if ctype == "Critter" then
      plate.aeIcon:Hide()
      plate.fnIcon:Hide()
      plate.fnTimer:Hide()
      plate.cocIcon:Hide()
      plate.cocTimer:Hide()
      return
    end

    local shown = {}

    -- Arcane Explosion
    if MagePlatesDB.enableAE then
      local alpha = GetRangeAlphaForSpell(unitToCheck, "AE")
      if alpha > 0 then
        plate.aeIcon:SetAlpha(alpha)
        plate.aeIcon:Show()
        table.insert(shown, { icon = plate.aeIcon })
      else
        plate.aeIcon:Hide()
      end
    else
      plate.aeIcon:Hide()
    end

    -- Frost Nova
    if MagePlatesDB.enableFN then
      local fnLeft = GetStaticCooldownLeft("FrostNova")
      if fnLeft == 0 or fnLeft <= 3 then
        local alpha = GetRangeAlphaForSpell(unitToCheck, "FrostNova")
        if alpha > 0 then
          plate.fnIcon:SetAlpha(alpha)
          if fnLeft == 0 then
            plate.fnIcon:Show()
            plate.fnTimer:Hide()
            plate.fnTimer:SetText("")
            table.insert(shown, { icon = plate.fnIcon })
          else
            plate.fnIcon:Show()
            plate.fnTimer:Show()
            plate.fnTimer:SetTextColor(1, 0, 0, 1)
            plate.fnTimer:SetText(tostring(math.floor(fnLeft)))
            table.insert(shown, { icon = plate.fnIcon, timerFS = plate.fnTimer })
          end
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
    else
      plate.fnIcon:Hide()
      plate.fnTimer:Hide()
      plate.fnTimer:SetText("")
    end

    -- Cone of Cold
    if MagePlatesDB.enableCoC then
      local cocLeft = GetStaticCooldownLeft("ConeOfCold")
      if cocLeft == 0 or cocLeft <= 3 then
        local alpha = GetRangeAlphaForSpell(unitToCheck, "ConeOfCold")
        if alpha > 0 then
          plate.cocIcon:SetAlpha(alpha)
          if cocLeft == 0 then
            plate.cocIcon:Show()
            plate.cocTimer:Hide()
            plate.cocTimer:SetText("")
            table.insert(shown, { icon = plate.cocIcon })
          else
            plate.cocIcon:Show()
            plate.cocTimer:Show()
            plate.cocTimer:SetTextColor(1, 0, 0, 1)
            plate.cocTimer:SetText(tostring(math.floor(cocLeft)))
            table.insert(shown, { icon = plate.cocIcon, timerFS = plate.cocTimer })
          end
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
    else
      plate.cocIcon:Hide()
      plate.cocTimer:Hide()
      plate.cocTimer:SetText("")
    end

    ArrangeIconsCentered(shown, plate.health, 60)
  end
end

------------------------------------------------
-- 10) Default Blizzard Nameplates
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

        ------------------------------------------------
        -- Filter out friendly + critter
        ------------------------------------------------
        if UnitIsFriend("player", unitToCheck) then
          aeIcon:Hide()
          fnIcon:Hide()
          fnTimer:Hide()
          cocIcon:Hide()
          cocTimer:Hide()
        end
        local ctype = UnitCreatureType(unitToCheck)
        if ctype == "Critter" then
          aeIcon:Hide()
          fnIcon:Hide()
          fnTimer:Hide()
          cocIcon:Hide()
          cocTimer:Hide()
        end

        local shown = {}

        -- Arcane Explosion
        if MagePlatesDB.enableAE then
          local alpha = GetRangeAlphaForSpell(unitToCheck, "AE")
          if alpha > 0 then
            aeIcon:SetAlpha(alpha)
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
        if MagePlatesDB.enableFN then
          if fnLeft == 0 or fnLeft <= 3 then
            local alpha = GetRangeAlphaForSpell(unitToCheck, "FrostNova")
            if alpha > 0 then
              fnIcon:SetAlpha(alpha)
              if fnLeft == 0 then
                fnIcon:Show()
                fnTimer:Hide()
                fnTimer:SetText("")
                table.insert(shown, { icon = fnIcon })
              else
                fnIcon:Show()
                fnTimer:Show()
                fnTimer:SetTextColor(1, 0, 0, 1)
                fnTimer:SetText(tostring(math.floor(fnLeft)))
                table.insert(shown, { icon = fnIcon, timerFS = fnTimer })
              end
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
        else
          fnIcon:Hide()
          fnTimer:Hide()
          fnTimer:SetText("")
        end

        -- Cone of Cold
        local cocLeft = GetStaticCooldownLeft("ConeOfCold")
        if MagePlatesDB.enableCoC then
          if cocLeft == 0 or cocLeft <= 3 then
            local alpha = GetRangeAlphaForSpell(unitToCheck, "ConeOfCold")
            if alpha > 0 then
              cocIcon:SetAlpha(alpha)
              if cocLeft == 0 then
                cocIcon:Show()
                cocTimer:Hide()
                cocTimer:SetText("")
                table.insert(shown, { icon = cocIcon })
              else
                cocIcon:Show()
                cocTimer:Show()
                cocTimer:SetTextColor(1, 0, 0, 1)
                cocTimer:SetText(tostring(math.floor(cocLeft)))
                table.insert(shown, { icon = cocIcon, timerFS = cocTimer })
              end
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
        else
          cocIcon:Hide()
          cocTimer:Hide()
          cocTimer:SetText("")
        end

        ArrangeIconsCentered(shown, frame, 30) -- offset=30
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
-- 11) Deferred Hook Setup
------------------------------------------------
local function MagePlates_SetupHooks()
  UpdateArcticReachRank()
  ScanForNetherwind()

  if pfUI and pfUI.nameplates then
    HookPfuiNameplates()
  else
    HookDefaultNameplates()
  end
end

------------------------------------------------
-- 12) Main Addon Frame & Events
------------------------------------------------
local MagePlatesFrame = CreateFrame("Frame", "MagePlates_MainFrame")
MagePlatesFrame:RegisterEvent("VARIABLES_LOADED")
MagePlatesFrame:RegisterEvent("PLAYER_LOGIN")

-- Gear check triggers
MagePlatesFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
MagePlatesFrame:RegisterEvent("UNIT_INVENTORY_CHANGED")

-- Arctic Reach re-check
MagePlatesFrame:RegisterEvent("CHARACTER_POINTS_CHANGED")

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

  elseif event == "PLAYER_LOGIN" then
    local _, playerGUID = UnitExists("player")
    MagePlatesDB.playerGUID = playerGUID
    UpdateArcticReachRank()
    ScanForNetherwind()

  elseif event == "PLAYER_ENTERING_WORLD" then
    ScanForNetherwind()

  elseif event == "UNIT_INVENTORY_CHANGED" then
    if arg1 == "player" then
      ScanForNetherwind()
    end

  elseif event == "CHARACTER_POINTS_CHANGED" then
    UpdateArcticReachRank()
  end

  if event == "VARIABLES_LOADED" then
    MagePlates_SetupHooks()
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[MagePlates]|r loaded. Type '/mageplates help' for options.")
  end
end)
