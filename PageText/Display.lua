-- Readable books, notes, letters and plaques for WoW 1.12.1.
VanillaKoreanCoreDB = VanillaKoreanCoreDB or {}
VanillaKoreanCorePageText = VanillaKoreanCorePageText or {}

local Text = VanillaKoreanCorePageText.Text or {}
local Templates = VanillaKoreanCorePageText.Templates or {}
local OriginalItemTextGetText = ItemTextGetText

local CLASS_EN = {
  DRUID="Druid", HUNTER="Hunter", MAGE="Mage", PALADIN="Paladin",
  PRIEST="Priest", ROGUE="Rogue", SHAMAN="Shaman", WARLOCK="Warlock", WARRIOR="Warrior"
}
local RACE_EN = {
  Dwarf="Dwarf", Gnome="Gnome", Human="Human", NightElf="Night Elf",
  Orc="Orc", Scourge="Undead", Tauren="Tauren", Troll="Troll"
}

local function Settings()
  if not VanillaKoreanCoreDB.PageText then
    VanillaKoreanCoreDB.PageText = { enabled = true }
  end
  return VanillaKoreanCoreDB.PageText
end

local function Normalize(text)
  if type(text) ~= "string" then return text end
  text = string.gsub(text, "\r\n", "\n")
  text = string.gsub(text, "\r", "\n")
  text = string.gsub(text, "%$B", "\n")
  return text
end

local function HasKorean(text)
  if type(text) ~= "string" then return false end
  local i
  for i = 1, string.len(text) do
    local byte = string.byte(text, i)
    if byte and byte >= 234 and byte <= 237 then return true end
  end
  return false
end

local function Expand(text, english)
  if type(text) ~= "string" then return text end
  local playerName = UnitName("player") or ""
  local localizedRace, raceToken = UnitRace("player")
  local localizedClass, classToken = UnitClass("player")
  local race = localizedRace or ""
  local className = localizedClass or ""
  if english then
    race = RACE_EN[raceToken] or raceToken or race
    className = CLASS_EN[classToken] or classToken or className
  end
  text = string.gsub(text, "%$[Nn]", function() return playerName end)
  text = string.gsub(text, "%$[Rr]", function() return race end)
  text = string.gsub(text, "%$[Cc]", function() return className end)
  local sex = UnitSex("player")
  text = string.gsub(text, "%$[Gg]([^:;]-):([^;]-);", function(male, female)
    if sex == 3 then return female end
    return male
  end)
  return text
end

local function Translate(text)
  if type(text) ~= "string" or text == "" then return text end
  if Settings().enabled == false then return text end
  if VanillaKoreanCoreDB.language == "enUS" then return text end
  if HasKorean(text) then return text end

  local normalized = Normalize(text)
  local translated = Text[normalized]
  if translated then return Expand(translated, false) end

  local i, pair
  for i, pair in ipairs(Templates) do
    if Normalize(Expand(pair[1], true)) == normalized then
      return Expand(pair[2], false)
    end
  end
  return text
end

function VanillaKoreanCore_TranslatePageText(text)
  return Translate(text)
end

if type(OriginalItemTextGetText) == "function" then
  function ItemTextGetText()
    return Translate(OriginalItemTextGetText())
  end
end

SLASH_VANILLAKOREANCOREPAGE1 = "/vkcpage"
SlashCmdList["VANILLAKOREANCOREPAGE"] = function(message)
  message = string.lower(message or "")
  if message == "on" then
    Settings().enabled = true
    DEFAULT_CHAT_FRAME:AddMessage("|cff3399ffVanillaKoreanCore:|r 책·쪽지 한글화를 켰습니다.")
  elseif message == "off" then
    Settings().enabled = false
    DEFAULT_CHAT_FRAME:AddMessage("|cff3399ffVanillaKoreanCore:|r 책·쪽지 한글화를 껐습니다.")
  else
    DEFAULT_CHAT_FRAME:AddMessage("|cff3399ffVanillaKoreanCore:|r /vkcpage on|off")
  end
end
