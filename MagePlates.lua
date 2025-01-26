-- MagePlates.lua
-- Shows Arcane Explosion (range check only), Frost Nova, and Cone of Cold icons on nameplates.
-- Frost Nova & Cone of Cold use a static cooldown approach based on combat log events.
--
-- Now also tracks player movement via UnitPosition("player"):
--   If moving, add +2 yards to the normal ranges (AE=10→12, FN/CoC=12→14)
--   If NOT moving, we show partial transparency (50%) if the unit is in that +2 yard leeway zone.

------------------------------------------------
-- 0) Movement & CD Settings
------------------------------------------------
local FROST_NOVA_CD = 25  -- example rank 4 Frost Nova in vanilla
local CONE_COLD_CD  = 10  -- example rank 5 Cone of Cold in vanilla

-- We'll store the "end time" of each cooldown:
local frostNovaEndTime = 0
local coneColdEndTime  = 0

-- Movement detection
local isMoving = false
local lastPlayerX, lastPlayerY = 0, 0

------------------------------------------------
-- 1) SavedVars Defaults
------------------------------------------------
local MagePlates_Defaults = {
  enableAE  = true,  -- Arcane Explosion
  enableFN  = true,  -- Frost Nova
  enableCoC = true,  -- Cone of Cold
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
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[MagePlates]|r Arcane Explosion icon: ENABLED.")
    return
  elseif msg == "aeoff" then
    MagePlatesDB.enableAE = false
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[MagePlates]|r Arcane Explosion icon: DISABLED.")
    return
  end

  if msg == "fnon" then
    MagePlatesDB.enableFN = true
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[MagePlates]|r Frost Nova icon: ENABLED.")
    return
  elseif msg == "fnoff" then
    MagePlatesDB.enableFN = false
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[MagePlates]|r Frost Nova icon: DISABLED.")
    return
  end

  if msg == "cocon" then
    MagePlatesDB.enableCoC = true
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[MagePlates]|r Cone of Cold icon: ENABLED.")
    return
  elseif msg == "cocoff" then
    MagePlatesDB.enableCoC = false
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[MagePlates]|r Cone of Cold icon: DISABLED.")
    return
  end

  if msg == "on" then
    MagePlatesDB.enableAE = true
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[MagePlates]|r Arcane Explosion icon: ENABLED.")
    return
  elseif msg == "off" then
    MagePlatesDB.enableAE = false
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[MagePlates]|r Arcane Explosion icon: DISABLED.")
    return
  end

  if msg == "help" or msg == "" then
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[MagePlates]|r usage:")
    DEFAULT_CHAT_FRAME:AddMessage("  /mageplates on/off       -> Toggle Arcane Explosion only")
    DEFAULT_CHAT_FRAME:AddMessage("  /mageplates aeon/aeoff   -> Toggle Arcane Explosion icon")
    DEFAULT_CHAT_FRAME:AddMessage("  /mageplates fnon/fnoff   -> Toggle Frost Nova icon")
    DEFAULT_CHAT_FRAME:AddMessage("  /mageplates cocon/cocoff -> Toggle Cone of Cold icon")
    DEFAULT_CHAT_FRAME:AddMessage("  /mageplates help         -> Show this help text")
    return
  end

  DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[MagePlates]|r: Unrecognized command '"..msg.."'. Type '/mageplates help' for usage.")
end

SLASH_MAGEPLATES1 = "/mageplates"
SLASH_MAGEPLATES2 = "/mp"
SlashCmdList["MAGEPLATES"] = MagePlates_SlashCommand

------------------------------------------------
-- 3) Range Checking + Movement Leeway
------------------------------------------------
-- We still call UnitXP("distanceBetween","player",unit,"AoE") to get distance.
-- If isMoving=true, we add +2 yards to the normal range for a full "hit".
-- If NOT moving, we allow the same +2 yards in a partial zone, but show 50% alpha.

-- Normal ranges
local AE_RANGE  = 10
local FN_RANGE  = 12
local CoC_RANGE = 12

-- We'll return "alpha" to indicate how visible the icon should be, or 0 if it's out of range and should be hidden.
local function GetRangeAlphaForSpell(unit, spellName)
  if not UnitExists(unit) then
    return 0
  end

  local dist = UnitXP("distanceBetween", "player", unit, "AoE")
  if not dist then
    return 0
  end

  -- Decide the base normalRange
  local normalRange = 0
  if spellName == "AE" then
    normalRange = AE_RANGE
  elseif spellName == "FrostNova" then
    normalRange = FN_RANGE
  elseif spellName == "ConeOfCold" then
    normalRange = CoC_RANGE
  end

  -- If moving => we treat normalRange+2 as the 'full' range
  if isMoving then
    if dist <= (normalRange + 2.5) then
      return 1.0 -- fully visible
    else
      return 0   -- hide
    end
  else
    -- Not moving => normal range is full alpha, extended range is half alpha
    if dist <= normalRange then
      return 1.0
    elseif dist <= (normalRange + 2.5) then
      return 0.3
    else
      return 0
    end
  end
end

------------------------------------------------
-- 4) Static CD Tracking
------------------------------------------------
local SpellCDFrame = CreateFrame("Frame", "MagePlates_SpellCDFrame", UIParent)
SpellCDFrame:RegisterEvent("CHAT_MSG_SPELL_SELF_DAMAGE")
SpellCDFrame:RegisterEvent("CHAT_MSG_SPELL_SELF_BUFF")

SpellCDFrame:SetScript("OnEvent", function()
  local msg = arg1 or ""
  -- Detect Frost Nova usage
  if string.find(msg, "Your Frost Nova") then
    frostNovaEndTime = GetTime() + FROST_NOVA_CD
  end
  -- Detect Cone of Cold usage
  if string.find(msg, "Your Cone of Cold") then
    coneColdEndTime = GetTime() + CONE_COLD_CD
  end
end)

-- Return how many seconds remain on the static CD for "FrostNova" or "ConeOfCold"
local function GetStaticCooldownLeft(spell)
  local now = GetTime()
  if spell == "FrostNova" then
    local left = frostNovaEndTime - now
    return left > 0 and left or 0
  elseif spell == "ConeOfCold" then
    local left = coneColdEndTime - now
    return left > 0 and left or 0
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
-- 6) Icon Positioning
------------------------------------------------
-- We have different Y offsets for pfUI vs. default plates, so we'll pass in offsetY.
local ICON_SPACING = 30

local function ArrangeIconsCentered(icons, parent, offsetY)
  local n = table.getn(icons)  -- vanilla 1.12 => table.getn
  if n == 0 then return end

  for i = 1, n do
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
-- 7) Movement Detection
------------------------------------------------
-- We update "isMoving" once every 0.5 sec by comparing UnitPosition("player").
local MovementCheckFrame = CreateFrame("Frame", "MagePlates_MovementFrame", UIParent)
MovementCheckFrame.tick = 0
MovementCheckFrame:SetScript("OnUpdate", function()
  if not this.tick then this.tick = 0 end
  if this.tick > GetTime() then
    return
  end
  this.tick = GetTime() + 0.05

  local x, y = UnitPosition("player")
  if x and y then
    local dx = x - lastPlayerX
    local dy = y - lastPlayerY
    -- If moved more than a tiny amount, consider the player 'moving'
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
-- 8) pfUI Nameplates
------------------------------------------------
local function HookPfuiNameplates()
  if not pfUI or not pfUI.nameplates then return end

  local oldOnCreate = pfUI.nameplates.OnCreate
  pfUI.nameplates.OnCreate = function(frame)
    oldOnCreate(frame)
    local plate = frame.nameplate
    if not plate or not plate.health then return end

    -- AE
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

    -- Arcane Explosion (no static CD)
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
        -- Off CD or <=3 => possible show
        local alpha = GetRangeAlphaForSpell(unitToCheck, "FrostNova")
        if alpha > 0 then
          plate.fnIcon:SetAlpha(alpha)

          if fnLeft == 0 then
            plate.fnIcon:Show()
            plate.fnTimer:Hide()
            plate.fnTimer:SetText("")
            table.insert(shown, { icon = plate.fnIcon })
          else
            -- <=3 => show a red timer
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
        -- More than 3 left => hide
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

    -- pfUI offset stays at 60
    ArrangeIconsCentered(shown, plate.health, 60)
  end
end

------------------------------------------------
-- 9) Default Blizzard Nameplates
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

        -- For default Blizzard plates, let's use offsetY=30
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
-- 10) Deferred Hook Setup
------------------------------------------------
local function MagePlates_SetupHooks()
  if pfUI and pfUI.nameplates then
    HookPfuiNameplates()
  else
    HookDefaultNameplates()
  end
end

------------------------------------------------
-- 11) Main Addon Frame & SavedVars
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
