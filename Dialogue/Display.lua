-- NPC dialogue presentation for WoW 1.12.1.
-- The server does not expose broadcast_text.entry to addons, so this module
-- uses the verified English source text as its lookup key.

local Dialogue = LaziKoreanQuestDialogue
local Static = Dialogue and Dialogue.Static
local Templates = Dialogue and Dialogue.Templates
if type(Static) ~= "table" then return end

local Runtime = {}
local runtimeBuilt = false

local EnglishRaces = {
  Human = "Human", Orc = "Orc", Dwarf = "Dwarf",
  NightElf = "Night Elf", Scourge = "Undead", Tauren = "Tauren",
  Gnome = "Gnome", Troll = "Troll", Goblin = "Goblin",
  HighElf = "High Elf", BloodElf = "Blood Elf",
}

local EnglishClasses = {
  WARRIOR = "Warrior", PALADIN = "Paladin", HUNTER = "Hunter",
  ROGUE = "Rogue", PRIEST = "Priest", SHAMAN = "Shaman",
  MAGE = "Mage", WARLOCK = "Warlock", DRUID = "Druid",
  DEMONHUNTER = "Demon Hunter",
}

local function Normalize(text)
  if type(text) ~= "string" then return nil end
  text = string.gsub(text, "\r\n", "\n")
  text = string.gsub(text, "\r", "\n")
  text = string.gsub(text, "^%s+", "")
  text = string.gsub(text, "%s+$", "")
  return text
end

local function PlayerValues(useEnglish)
  local playerName = type(UnitName) == "function" and UnitName("player") or ""
  local raceLocalized, raceEnglish
  local classLocalized, classEnglish
  if type(UnitRace) == "function" then
    raceLocalized, raceEnglish = UnitRace("player")
  end
  if type(UnitClass) == "function" then
    classLocalized, classEnglish = UnitClass("player")
  end
  local race = raceLocalized
  local className = classLocalized
  if useEnglish then
    race = EnglishRaces[raceEnglish] or raceEnglish or raceLocalized
    className = EnglishClasses[classEnglish] or classEnglish or classLocalized
  end
  return playerName or "", race or "", className or ""
end

local function Expand(text, useEnglish)
  if type(text) ~= "string" then return nil end
  local playerName, race, className = PlayerValues(useEnglish)
  local sex = type(UnitSex) == "function" and UnitSex("player") or 2

  text = string.gsub(text, "%$[gG]([^:;]-):([^;]-);", function(male, female)
    if sex == 3 then return female end
    return male
  end)
  text = string.gsub(text, "%$[nN]", playerName)
  text = string.gsub(text, "%$[rR]", race)
  text = string.gsub(text, "%$[cC]", className)
  text = string.gsub(text, "%$[bB]", "\n")
  return Normalize(text)
end

local function BuildRuntime()
  if runtimeBuilt then return end
  Runtime = {}
  if type(Templates) ~= "table" then
    runtimeBuilt = true
    return
  end
  for index = 1, table.getn(Templates) do
    local source = Templates[index][1]
    local target = Templates[index][2]
    local translated = Expand(target, false)
    local englishKey = Expand(source, true)
    local localizedKey = Expand(source, false)
    if englishKey and translated then Runtime[englishKey] = translated end
    if localizedKey and translated then Runtime[localizedKey] = translated end
  end
  runtimeBuilt = true

  -- Runtime now contains every player-specific expansion. The source template
  -- table is no longer needed during this login session.
  Dialogue.Templates = nil
  Templates = nil
end

local function Translate(text)
  local key = Normalize(text)
  if not key or key == "" then return text end
  return Static[key] or Runtime[key] or text
end

function LaziKoreanQuest_TranslateDialogue(text)
  return Translate(text)
end

local function TranslateFontString(fontString)
  if not fontString or type(fontString.GetText) ~= "function"
    or type(fontString.SetText) ~= "function" then return end
  local original = fontString:GetText()
  local translated = Translate(original)
  if translated and translated ~= original then fontString:SetText(translated) end
end

local function RefreshGossip()
  TranslateFontString(GossipGreetingText)
  TranslateFontString(QuestGreetingText)
  for index = 1, 32 do
    TranslateFontString(getglobal("GossipTitleButton"..index))
  end
end

local frame = CreateFrame("Frame", "VanillaKoreanCoreDialogueFrame")
local refreshPasses = 0
local refreshElapsed = 0

local function DeferredRefresh()
  refreshElapsed = refreshElapsed + (arg1 or 0)
  if refreshElapsed < 0.05 then return end
  refreshElapsed = 0
  RefreshGossip()
  refreshPasses = refreshPasses - 1
  if refreshPasses <= 0 then
    frame:SetScript("OnUpdate", nil)
  end
end

local function ScheduleRefresh()
  RefreshGossip()
  refreshPasses = 2
  refreshElapsed = 0
  frame:SetScript("OnUpdate", DeferredRefresh)
end

local MonsterChatEvents = {
  CHAT_MSG_MONSTER_SAY = true,
  CHAT_MSG_MONSTER_YELL = true,
  CHAT_MSG_MONSTER_WHISPER = true,
  CHAT_MSG_MONSTER_EMOTE = true,
  CHAT_MSG_RAID_BOSS_EMOTE = true,
  CHAT_MSG_RAID_BOSS_WHISPER = true,
}

local function InstallChatHook()
  if Dialogue.ChatHookInstalled or type(ChatFrame_OnEvent) ~= "function" then return end
  Dialogue.ChatHookInstalled = true
  local original = ChatFrame_OnEvent
  ChatFrame_OnEvent = function(eventName)
    local currentEvent = eventName or event
    local previousText = arg1
    if MonsterChatEvents[currentEvent] and type(arg1) == "string" then
      arg1 = Translate(arg1)
    end
    local first, second, third, fourth, fifth = original(eventName)
    arg1 = previousText
    return first, second, third, fourth, fifth
  end
end

local function HookRefreshFunction(functionName)
  Dialogue.RefreshHooks = Dialogue.RefreshHooks or {}
  if Dialogue.RefreshHooks[functionName] then return end
  local original = getglobal(functionName)
  if type(original) ~= "function" then return end
  Dialogue.RefreshHooks[functionName] = true
  setglobal(functionName, function(...)
    local callArguments = arg
    local first, second, third, fourth, fifth = original(unpack(callArguments))
    ScheduleRefresh()
    return first, second, third, fourth, fifth
  end)
end

BuildRuntime()
InstallChatHook()
HookRefreshFunction("GossipFrameUpdate")
HookRefreshFunction("QuestFrameGreetingPanel_OnShow")

frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("GOSSIP_SHOW")
frame:RegisterEvent("QUEST_GREETING")
frame:SetScript("OnEvent", function()
  if event == "PLAYER_ENTERING_WORLD" then
    BuildRuntime()
    InstallChatHook()
    HookRefreshFunction("GossipFrameUpdate")
    HookRefreshFunction("QuestFrameGreetingPanel_OnShow")
  end
  ScheduleRefresh()
end)
