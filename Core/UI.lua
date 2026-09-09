-- LaziKoreanQuest data lookup for WoW 1.12.1 / TurtleWoW.
-- Keeps the original public function names for addon compatibility.

LKQ_DEBUG_LEVEL = LKQ_DEBUG_LEVEL or 0

function Lkqdebug(message, level)
  if LKQ_DEBUG_LEVEL >= (level or 5) and ChatFrame1 then
    ChatFrame1:AddMessage(tostring(message))
  end
end

KQ_FAILED = "실패"
KQ_QUEST_DESCRIPTION = "내용"
KQ_QUEST_OBJECTIVES = "퀘스트 임무"
KQ_COMPLETE = "완료"
KQ_REQUIRED_MONEY = "필요한 금액:"
KQ_TIME_REMAINING = "남은 시간:"

local CLASS_KO = {
  ["Paladin"]="성기사", ["Warrior"]="전사", ["Priest"]="사제",
  ["Warlock"]="흑마법사", ["Mage"]="마법사", ["Hunter"]="사냥꾼",
  ["Druid"]="드루이드", ["Rogue"]="도적", ["Shaman"]="주술사",
}

local RACE_KO = {
  ["Orc"]="오크", ["Undead"]="언데드", ["Tauren"]="타우렌",
  ["Troll"]="트롤", ["Human"]="인간", ["Dwarf"]="드워프",
  ["Night Elf"]="나이트엘프", ["Gnome"]="노움",
}

local playerName, playerClass, playerRace = "", "", ""
local playerSex = 2
local titleCache, normalizedTitleCache
local questieTitleAliasesBuilt = false

local function AddCache(cache, key, questID)
  if type(key) ~= "string" or key == "" then return end
  local current = cache[key]
  if current == nil then
    cache[key] = questID
  elseif type(current) == "table" then
    for _, existing in ipairs(current) do
      if tostring(existing) == tostring(questID) then return end
    end
    table.insert(current, questID)
  elseif tostring(current) == tostring(questID) then
    return
  else
    cache[key] = { current, questID }
  end
end

-- OctoWoW's koKR quest titles occasionally differ from the bundled database
-- only in word spacing (for example quest 794). Keep exact matching first and
-- use this conservative, whitespace-only key as a safe fallback.
local function NormalizeQuestTitle(title)
  if type(title) ~= "string" or title == "" then return nil end
  local text = title

  for _ = 1, 4 do
    local _, last, marker = string.find(text, "^%s*%[([^%]]+)%]%s*")
    if last and (string.find(string.lower(marker), "unused", 1, true)
      or string.find(marker, "미사용", 1, true)) then
      text = string.sub(text, last + 1)
    else
      break
    end
  end

  text = string.lower(text)
  text = string.gsub(text, "%s+", "")
  return text ~= "" and text or nil
end

function LazinismKoreanQuest_GetData(questID)
  local id = tostring(tonumber(questID) or questID or "")
  if type(KoreanQuestData) == "table" and KoreanQuestData[id] then
    return KoreanQuestData[id]
  end
  if type(TurtleKoreanQuestData) == "table" then
    return TurtleKoreanQuestData[id]
  end
  return nil
end

function LazinismKoreanQuest_ExpandUnitInfo(message)
  local text = message or ""
  text = string.gsub(text, "$[Bb]", "\n")
  text = string.gsub(text, "$[Nn]", playerName)
  text = string.gsub(text, "$[Rr]", playerRace)
  text = string.gsub(text, "$[Cc]", playerClass)
  text = string.gsub(text, "%$[Gg](.-)[:;](.-)[;.]", playerSex == 2 and "%1" or "%2")
  return text
end

local function BuildKoreanCaches()
  if titleCache then return end
  titleCache, normalizedTitleCache = {}, {}

  local function AddDatabase(database)
    if type(database) ~= "table" then return end
    for questID, data in pairs(database) do
      if type(data) == "table" then
        local title = LazinismKoreanQuest_ExpandUnitInfo(data.Title)
        AddCache(titleCache, title, questID)
        AddCache(normalizedTitleCache, NormalizeQuestTitle(title), questID)
      end
    end
  end

  AddDatabase(KoreanQuestData)
  AddDatabase(TurtleKoreanQuestData)
end

-- Objectives and descriptions are large strings. Keeping a second permanent
-- reverse index for every quest costs substantial memory, even though this
-- fallback is reached only when numeric-ID, list and title matching all fail.
-- Scan on that rare path instead and retain only the compact title indexes.
local function FindQuestIDByText(fieldName, text)
  if type(text) ~= "string" or text == "" then return 0 end

  local function SearchDatabase(database)
    if type(database) ~= "table" then return 0 end
    for questID, data in pairs(database) do
      if type(data) == "table"
        and LazinismKoreanQuest_ExpandUnitInfo(data[fieldName]) == text then
        return tonumber(questID) or 0
      end
    end
    return 0
  end

  local questID = SearchDatabase(KoreanQuestData)
  if questID ~= 0 then return questID end
  return SearchDatabase(TurtleKoreanQuestData)
end

-- When Questie-Octo is present, accept its Korean title spellings as aliases
-- for the same Lazi quest IDs. This does not copy or overwrite any Lazi text.
local function AddQuestieTitleAliases()
  if questieTitleAliasesBuilt then return end
  local api = QuestieOcto and QuestieOcto.DatabaseAPI
  if not api or type(api.GetQuestIDs) ~= "function" or type(api.GetQuestTitle) ~= "function" then return end
  if type(api.IsReady) == "function" and not api:IsReady() then return end

  local questIDs = api:GetQuestIDs() or {}
  for index = 1, table.getn(questIDs) do
    local questID = tonumber(questIDs[index])
    if questID and LazinismKoreanQuest_GetData(questID) then
      AddCache(normalizedTitleCache, NormalizeQuestTitle(api:GetQuestTitle(questID)), questID)
    end
  end
  questieTitleAliasesBuilt = true
end

local function CachedID(cache, text)
  if type(text) ~= "string" or text == "" then return 0 end
  local value = cache[text]
  if type(value) == "table" then value = value[1] end
  return tonumber(value) or 0
end

local function UniqueCachedID(cache, text)
  if type(text) ~= "string" or text == "" then return 0 end
  local value = cache[text]
  if type(value) == "table" then return 0 end
  return tonumber(value) or 0
end

local function CurrentQuestLogID()
  if type(GetQuestLogSelection) ~= "function" then return nil end
  local index = GetQuestLogSelection()
  if not index or index <= 0 then return nil end

  if C_QuestLog and type(C_QuestLog.GetQuestIDForLogIndex) == "function" then
    local questID = C_QuestLog.GetQuestIDForLogIndex(index)
    questID = tonumber(questID)
    if questID and LazinismKoreanQuest_GetData(questID) then return questID end
  end

  -- Questie-Octo can be used when present, but is never required.
  local api = QuestieOcto and QuestieOcto.API
  if api and type(api.GetQuestIDForLogIndex) == "function" then
    local rawQuestID = api:GetQuestIDForLogIndex(index)
    local questID = tonumber(rawQuestID)
    if questID and LazinismKoreanQuest_GetData(questID) then return questID end
  end
  return nil
end

function LazinismKoreanQuest_SearchFromList(list, title, description, objectives)
  if type(list) ~= "table" or type(title) ~= "string" then return 0 end
  local entry = list[title]
  if type(entry) == "string" or type(entry) == "number" then
    return tonumber(entry) or 0
  end
  if type(entry) ~= "table" then return 0 end

  if objectives and (type(entry[objectives]) == "string" or type(entry[objectives]) == "number") then
    return tonumber(entry[objectives]) or 0
  end

  for key, value in pairs(entry) do
    if type(key) == "string" and objectives and string.find(objectives, key, 1, true) then
      if type(value) == "string" or type(value) == "number" then
        return tonumber(value) or 0
      elseif type(value) == "table" and description then
        for part, questID in pairs(value) do
          if type(part) == "string" and string.find(description, part, 1, true) then
            return tonumber(questID) or 0
          end
        end
      end
    end
  end

  if description then
    for key, value in pairs(entry) do
      if type(key) == "string" and string.find(description, key, 1, true)
        and (type(value) == "string" or type(value) == "number") then
        return tonumber(value) or 0
      end
    end
  end
  return 0
end

function LazinismKoreanQuest_SearchIDforName(title, isQuestFrame)
  -- Quest-log pages have a stable numeric ID through ClassicAPI. This avoids
  -- failures after another addon localizes or decorates the visible title.
  if not isQuestFrame then
    local questID = CurrentQuestLogID()
    if questID then return questID end
  end

  local description, objectives
  if isQuestFrame then
    description = type(GetQuestText) == "function" and GetQuestText() or nil
    objectives = type(GetObjectiveText) == "function" and GetObjectiveText() or nil
  elseif type(GetQuestLogQuestText) == "function" then
    description, objectives = GetQuestLogQuestText()
  end

  local questID = LazinismKoreanQuest_SearchFromList(KoreanQuestList, title, description, objectives)
  if questID ~= 0 then return questID end

  questID = LazinismKoreanQuest_SearchFromList(TurtleKoreanQuestList, title, description, objectives)
  if questID ~= 0 then return questID end

  -- Build the larger reverse caches only when ID/list lookup really failed.
  BuildKoreanCaches()
  AddQuestieTitleAliases()
  questID = CachedID(titleCache, title)
  if questID ~= 0 then return questID end
  questID = UniqueCachedID(normalizedTitleCache, NormalizeQuestTitle(title))
  if questID ~= 0 then return questID end
  questID = FindQuestIDByText("Objectives", objectives)
  if questID ~= 0 then return questID end
  return FindQuestIDByText("Description", description)
end

function LaziKoreanQuestInitialize()
  playerName = UnitName("player") or ""
  local className = UnitClass("player") or ""
  local raceName = UnitRace("player") or ""
  if GetLocale and GetLocale() == "enUS" then
    playerClass = CLASS_KO[className] or className
    playerRace = RACE_KO[raceName] or raceName
  else
    playerClass = className
    playerRace = raceName
  end
  playerSex = UnitSex("player") or 2
  titleCache, normalizedTitleCache = nil, nil
  questieTitleAliasesBuilt = false
end

function QuestIDsToTable(text, separator)
  local result, start = {}, 1
  while true do
    local first, last = string.find(text, separator, start, true)
    if not first then
      table.insert(result, string.sub(text, start))
      return result
    end
    table.insert(result, string.sub(text, start, first - 1))
    start = last + 1
  end
end
