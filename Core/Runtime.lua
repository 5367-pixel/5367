-- LaziKoreanQuest clean native-frame renderer for WoW 1.12.1.
-- Korean and English share Blizzard's original widgets, preventing duplicate
-- layers, mixed-language frames and unnecessary layout work.

local ADDON_NAME = "VanillaKoreanCore"
local QUEST_FRAME = true
local originalQuestLogUpdate = QuestLog_UpdateQuestDetails
local originalDetailShow = QuestFrameDetailPanel_OnShow
local originalProgressShow = QuestFrameProgressPanel_OnShow
local originalRewardShow = QuestFrameRewardPanel_OnShow
local originalGreetingShow = QuestFrameGreetingPanel_OnShow
local originalGossipUpdate = GossipFrameUpdate

VanillaKoreanCoreDB = VanillaKoreanCoreDB or {}
LaziQuestLanguage = LaziQuestLanguage or "koKR"
if LaziQuestLanguage ~= "koKR" and LaziQuestLanguage ~= "enUS" then
  LaziQuestLanguage = "koKR"
end

local function StripLevel(title)
  if type(title) ~= "string" then return title end
  local _, _, plain = string.find(title, "^%b[]%s*(.*)$")
  return plain or title
end

local function HasLegacyUnusedMarker(marker)
  if type(marker) ~= "string" then return false end
  return string.find(string.lower(marker), "unused", 1, true)
    or string.find(marker, "미사용", 1, true)
end

-- Keep the server's original title intact for quest-ID lookup, then remove
-- obsolete UNUSED annotations only from the text shown to the player.
local function CleanLegacyUnusedTitle(title)
  if type(title) ~= "string" or title == "" then return title end
  local text = title

  for _ = 1, 4 do
    local _, last, marker = string.find(text, "^%s*%[([^%]]+)%]%s*")
    if last and HasLegacyUnusedMarker(marker) then
      text = string.sub(text, last + 1)
    else
      _, last, marker = string.find(text, "^%s*%(([^%)]+)%)%s*")
      if last and HasLegacyUnusedMarker(marker) then
        text = string.sub(text, last + 1)
      else
        break
      end
    end
  end

  local _, prefixEnd = string.find(string.lower(text), "^%s*unused[%s:%-]*")
  if prefixEnd then text = string.sub(text, prefixEnd + 1) end
  text = string.gsub(text, "^%s*미사용[%s:%-]*", "")

  for _ = 1, 4 do
    local first, _, marker = string.find(text, "%s*%[([^%]]+)%]%s*$")
    if first and HasLegacyUnusedMarker(marker) then
      text = string.sub(text, 1, first - 1)
    else
      first, _, marker = string.find(text, "%s*%(([^%)]+)%)%s*$")
      if first and HasLegacyUnusedMarker(marker) then
        text = string.sub(text, 1, first - 1)
      else
        break
      end
    end
  end

  local unusedStart = string.find(string.lower(text), "%s+unused%s*$")
  if unusedStart then text = string.sub(text, 1, unusedStart - 1) end
  text = string.gsub(text, "%s*미사용%s*$", "")
  text = string.gsub(text, "^%s+", "")
  text = string.gsub(text, "%s+$", "")
  if text == "" then return "퀘스트" end
  return text
end

local function Expanded(data, key, fallback)
  local value = data and data[key]
  local result = fallback
  if type(value) == "string" and value ~= "" then
    result = LazinismKoreanQuest_ExpandUnitInfo(value)
  end
  if key == "Title" then return CleanLegacyUnusedTitle(result) end
  return result
end

local function QuestLogData()
  if type(GetQuestLogSelection) ~= "function" then return nil end
  local index = GetQuestLogSelection()
  if not index or index <= 0 then return nil end

  local titleGetter = old_GetQuestLogTitle or GetQuestLogTitle
  local title = titleGetter and StripLevel(titleGetter(index)) or nil
  local questID = LazinismKoreanQuest_SearchIDforName(title, false)
  return LazinismKoreanQuest_GetData(questID), questID
end

local function QuestieCurrentQuestID(preferActive)
  local automation = QuestieOcto and QuestieOcto.QuestAutomation
  if not automation then return nil end

  local pending = automation.pending
  local pendingID = pending and tonumber(pending.questID)
  if pendingID and LazinismKoreanQuest_GetData(pendingID) then return pendingID end

  if type(automation.ResolveCurrentQuest) == "function" then
    local ok, questID = pcall(automation.ResolveCurrentQuest, automation, preferActive and true or false)
    questID = ok and tonumber(questID) or nil
    if questID and LazinismKoreanQuest_GetData(questID) then return questID end
  end
  return nil
end

local function QuestFrameData(preferActive)
  local title = type(GetTitleText) == "function" and StripLevel(GetTitleText()) or nil
  if not title then return nil end
  local questID = QuestieCurrentQuestID(preferActive)
    or LazinismKoreanQuest_SearchIDforName(title, QUEST_FRAME)
  return LazinismKoreanQuest_GetData(questID), questID
end

local function SetButtonText()
  if not LaziQuestLanguageButton or not LaziQuestLanguageButton.text then return end
  LaziQuestLanguageButton.text:SetText(LaziQuestLanguage == "koKR" and "[한국어]" or "[영어 원문]")
end

local function FirstLocalizedTitle(value)
  if type(value) == "string" or type(value) == "number" then
    local data = LazinismKoreanQuest_GetData(tonumber(value) or value)
    return Expanded(data, "Title", nil)
  end
  if type(value) ~= "table" then return nil end

  for _, nested in pairs(value) do
    local title = FirstLocalizedTitle(nested)
    if title then return title end
  end
  return nil
end

local function LocalizedQuestTitle(title)
  if type(title) ~= "string" or title == "" then return nil end

  -- Duplicate English titles are stored as nested disambiguation tables. All
  -- entries with the same title share the same Korean display title, so one
  -- valid localized entry is sufficient for the greeting button.
  local localized = FirstLocalizedTitle(type(KoreanQuestList) == "table" and KoreanQuestList[title])
  if localized then return localized end
  return FirstLocalizedTitle(type(TurtleKoreanQuestList) == "table" and TurtleKoreanQuestList[title])
end

local function ReplaceGreetingButtonTitle(button, originalTitle)
  if not button or type(originalTitle) ~= "string" or originalTitle == "" then return end
  local localizedTitle = LocalizedQuestTitle(originalTitle)
  local displayTitle = localizedTitle or CleanLegacyUnusedTitle(originalTitle)
  if not displayTitle or displayTitle == originalTitle then return end

  -- Preserve level prefixes, colors and formatting added by FrameXML or other
  -- addons. Only the raw quest-title portion is replaced.
  local visibleText = button:GetText() or originalTitle
  local first, last = string.find(visibleText, originalTitle, 1, true)
  if first then
    button:SetText(string.sub(visibleText, 1, first - 1)..displayTitle..string.sub(visibleText, last + 1))
  elseif visibleText == originalTitle then
    button:SetText(displayTitle)
  else
    return
  end

  if button.GetTextHeight then button:SetHeight(button:GetTextHeight() + 2) end
end

local function TranslateGreetingQuestTitles()
  if LaziQuestLanguage ~= "koKR" then return end
  if type(GetNumActiveQuests) ~= "function" or type(GetNumAvailableQuests) ~= "function" then return end

  local activeCount = GetNumActiveQuests() or 0
  local availableCount = GetNumAvailableQuests() or 0

  if type(GetActiveTitle) == "function" then
    for index = 1, activeCount do
      ReplaceGreetingButtonTitle(getglobal("QuestTitleButton"..index), GetActiveTitle(index))
    end
  end

  if type(GetAvailableTitle) == "function" then
    for index = 1, availableCount do
      ReplaceGreetingButtonTitle(
        getglobal("QuestTitleButton"..(activeCount + index)),
        GetAvailableTitle(index)
      )
    end
  end
end

local function TranslateGossipQuestTitles()
  if LaziQuestLanguage ~= "koKR" then return end

  -- GossipFrame uses a separate set of buttons from QuestFrame. Translate only
  -- quest entries; normal trainer/vendor/dialogue options must stay untouched.
  local buttonCount = tonumber(NUMGOSSIPBUTTONS) or 32
  for index = 1, buttonCount do
    local button = getglobal("GossipTitleButton"..index)
    if button and (button.type == "Available" or button.type == "Active")
      and (not button.IsVisible or button:IsVisible()) then
      ReplaceGreetingButtonTitle(button, button:GetText())
    end
  end
end

local function RefreshVisibleQuest()
  if QuestLogFrame and QuestLogFrame:IsVisible() and type(QuestLog_UpdateQuestDetails) == "function" then
    QuestLog_UpdateQuestDetails(true)
  end
  if QuestFrame and QuestFrame:IsVisible() then
    if QuestFrameDetailPanel and QuestFrameDetailPanel:IsVisible() and type(QuestFrameDetailPanel_OnShow) == "function" then
      QuestFrameDetailPanel_OnShow()
    elseif QuestFrameProgressPanel and QuestFrameProgressPanel:IsVisible() and type(QuestFrameProgressPanel_OnShow) == "function" then
      QuestFrameProgressPanel_OnShow()
    elseif QuestFrameRewardPanel and QuestFrameRewardPanel:IsVisible() and type(QuestFrameRewardPanel_OnShow) == "function" then
      QuestFrameRewardPanel_OnShow()
    elseif QuestFrameGreetingPanel and QuestFrameGreetingPanel:IsVisible() and type(QuestFrameGreetingPanel_OnShow) == "function" then
      QuestFrameGreetingPanel_OnShow()
    end
  end
  if GossipFrame and GossipFrame:IsVisible() and type(GossipFrameUpdate) == "function" then
    GossipFrameUpdate()
  end
end

local function ToggleLanguage()
  LaziQuestLanguage = LaziQuestLanguage == "koKR" and "enUS" or "koKR"
  VanillaKoreanCoreDB = VanillaKoreanCoreDB or {}
  VanillaKoreanCoreDB.language = LaziQuestLanguage
  SetButtonText()
  RefreshVisibleQuest()
end

local function CreateLanguageButton()
  if LaziQuestLanguageButton then
    SetButtonText()
    return
  end

  local parent = EQL3_QuestLogDetailScrollChildFrame or QuestLogDetailScrollChildFrame
  if not parent then return end

  local button = CreateFrame("Button", "LaziQuestLanguageButton", parent)
  button:SetWidth(78)
  button:SetHeight(18)
  button:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -12, -8)
  button:RegisterForClicks("LeftButtonUp")

  button.text = button:CreateFontString("LaziQuestLanguageButtonText", "OVERLAY", "GameFontWhite")
  button.text:SetAllPoints(button)
  button.text:SetJustifyH("RIGHT")

  button:SetScript("OnClick", ToggleLanguage)
  button:SetScript("OnEnter", function()
    button.text:SetTextColor(1, 0.82, 0)
    if GameTooltip then
      GameTooltip:SetOwner(button, "ANCHOR_BOTTOMRIGHT")
      if LaziQuestLanguage == "koKR" then
        GameTooltip:SetText("클릭하면 영어로 전환합니다.", 1, 1, 1)
      else
        GameTooltip:SetText("클릭하면 한국어로 전환합니다.", 1, 1, 1)
      end
      GameTooltip:Show()
    end
  end)
  button:SetScript("OnLeave", function()
    button.text:SetTextColor(1, 1, 1)
    if GameTooltip then GameTooltip:Hide() end
  end)

  LaziQuestLanguageButton = button
  SetButtonText()
end

function QuestLog_UpdateQuestDetails(doNotScroll)
  originalQuestLogUpdate(doNotScroll)
  CreateLanguageButton()
  if LaziQuestLanguage ~= "koKR" then return end

  local data = QuestLogData()
  local index = GetQuestLogSelection()
  if not index or index <= 0 then return end
  local nativeTitle = GetQuestLogTitle(index) or ""
  local nativeDescription, nativeObjectives = GetQuestLogQuestText()
  local title = Expanded(data, "Title", nativeTitle)
  if IsCurrentQuestFailed and IsCurrentQuestFailed() then
    title = title.." - ("..KQ_FAILED..")"
  end

  local titleWidget = EQL3_QuestLogQuestTitle or QuestLogQuestTitle
  local objectiveWidget = EQL3_QuestLogObjectivesText or QuestLogObjectivesText
  local descriptionWidget = EQL3_QuestLogQuestDescription or QuestLogQuestDescription
  if titleWidget then titleWidget:SetText(title) end
  if objectiveWidget then objectiveWidget:SetText(Expanded(data, "Objectives", nativeObjectives or "")) end
  if descriptionWidget then descriptionWidget:SetText(Expanded(data, "Description", nativeDescription or "")) end

  local scrollFrame = EQL3_QuestLogDetailScrollFrame or QuestLogDetailScrollFrame
  if scrollFrame and scrollFrame.UpdateScrollChildRect then scrollFrame:UpdateScrollChildRect() end
end

if type(originalDetailShow) == "function" then
  function QuestFrameDetailPanel_OnShow()
    originalDetailShow()
    if LaziQuestLanguage ~= "koKR" then return end
    local data = QuestFrameData(false)

    if QuestTitleText then QuestTitleText:SetText(Expanded(data, "Title", GetTitleText() or "")) end
    if QuestDescription then QuestDescription:SetText(Expanded(data, "Description", GetQuestText() or "")) end
    if QuestObjectiveText then QuestObjectiveText:SetText(Expanded(data, "Objectives", GetObjectiveText() or "")) end
    if QuestDetailScrollFrame and QuestDetailScrollFrame.UpdateScrollChildRect then
      QuestDetailScrollFrame:UpdateScrollChildRect()
    end
  end
end

-- Progress and completion text existed in the database but the old renderer
-- never used it. These guarded hooks cover those pages without assuming that
-- every custom FrameXML build exposes the same widgets.
if type(originalProgressShow) == "function" then
  function QuestFrameProgressPanel_OnShow()
    originalProgressShow()
    if LaziQuestLanguage ~= "koKR" then return end
    local data = QuestFrameData(true)
    if QuestProgressTitleText then QuestProgressTitleText:SetText(Expanded(data, "Title", GetTitleText() or "")) end
    local progress = Expanded(data, "Progress", nil)
    if QuestProgressText and progress then QuestProgressText:SetText(progress) end
  end
end

if type(originalRewardShow) == "function" then
  function QuestFrameRewardPanel_OnShow()
    originalRewardShow()
    if LaziQuestLanguage ~= "koKR" then return end
    local data = QuestFrameData(true)
    if QuestRewardTitleText then QuestRewardTitleText:SetText(Expanded(data, "Title", GetTitleText() or "")) end
    local completion = Expanded(data, "Completion", nil)
    if QuestRewardText and completion then QuestRewardText:SetText(completion) end
  end
end

-- The native NPC greeting page gets its clickable quest titles directly from
-- the server. Translate only the visible labels and leave IDs/click handlers
-- untouched, so accepting and turning in quests behaves exactly as before.
if type(originalGreetingShow) == "function" then
  function QuestFrameGreetingPanel_OnShow()
    originalGreetingShow()
    TranslateGreetingQuestTitles()
  end
end

-- NPCs that mix dialogue and quests use GossipFrame instead of QuestFrame.
-- This is the path used by Mangletooth's repeatable Blood Shard blessings.
if type(originalGossipUpdate) == "function" then
  function GossipFrameUpdate()
    originalGossipUpdate()
    TranslateGossipQuestTitles()
  end
end

local eventFrame = CreateFrame("Frame", "VanillaKoreanCoreControlFrame")
eventFrame:RegisterEvent("VARIABLES_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("QUEST_GREETING")
eventFrame:RegisterEvent("GOSSIP_SHOW")
local pendingTitleRefresh = false
local function ApplyPendingTitleRefresh()
  eventFrame:SetScript("OnUpdate", nil)
  if not pendingTitleRefresh then return end
  pendingTitleRefresh = false
  TranslateGreetingQuestTitles()
  TranslateGossipQuestTitles()
end
eventFrame:SetScript("OnEvent", function()
  if event == "VARIABLES_LOADED" then
    VanillaKoreanCoreDB = VanillaKoreanCoreDB or {}
    local saved = VanillaKoreanCoreDB.language
    if saved == "koKR" or saved == "enUS" then LaziQuestLanguage = saved end
    SetButtonText()
  elseif event == "PLAYER_LOGIN" then
    LaziKoreanQuestInitialize()
    VanillaKoreanCoreDB = VanillaKoreanCoreDB or {}
    VanillaKoreanCoreDB.language = LaziQuestLanguage
    if ChatFrame1 then
      ChatFrame1:AddMessage("|CFF3399FFVanillaKoreanCore |cff00ff00통합 한글화 애드온을 불러왔습니다.|r")
    end
  elseif event == "QUEST_GREETING" or event == "GOSSIP_SHOW" then
    -- Run once on the next frame as well. This wins safely when another addon
    -- redraws the quest buttons later in the same event dispatch.
    pendingTitleRefresh = true
    eventFrame:SetScript("OnUpdate", ApplyPendingTitleRefresh)
  end
end)
