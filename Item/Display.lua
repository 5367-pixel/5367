-- Item-name presentation layer for LaziKoreanQuest / WoW 1.12.1.
--
-- This module never replaces GetItemInfo and never edits item links. It uses
-- the numeric item ID only to replace visible names with the bundled koKR
-- locale. Gameplay APIs and other addons continue to receive native values.

local ItemLocale = LaziKoreanQuestItemLocale
local ItemNames = ItemLocale and ItemLocale.Names
local EnglishNames = ItemLocale and ItemLocale.EnglishNames
local RandomProperties = ItemLocale and ItemLocale.RandomProperties
if type(ItemNames) ~= "table" then return end

local function CleanUnusedMarker(name)
  if type(name) ~= "string" then return name end
  local text = name
  text = string.gsub(text, "^%s*%[4%.x 미사용%]%s*", "")
  text = string.gsub(text, "^%s*%[미사용%]%s*", "")
  text = string.gsub(text, "^%s*미사용%s*", "")
  text = string.gsub(text, "%s*%[미사용%]%s*$", "")
  text = string.gsub(text, "^%s+", "")
  text = string.gsub(text, "%s+$", "")
  return text
end

local function LocalizedNameFromID(itemID)
  local numericID = tonumber(itemID)
  if not numericID then return nil end
  return CleanUnusedMarker(ItemNames[numericID])
end

local function ItemIDFromLink(link)
  if type(link) ~= "string" then return nil end
  local _, _, itemID = string.find(link, "item:(%d+)")
  return tonumber(itemID)
end

local LocalizedNameFromLink

local function RandomPropertyIDFromLink(link)
  if type(link) ~= "string" then return nil end
  -- Vanilla 1.12 item links use item:itemID:enchantID:randomPropertyID:uniqueID.
  local _, _, _, _, randomPropertyID = string.find(link, "item:(%-?%d+):(%-?%d*):(%-?%d*)")
  return tonumber(randomPropertyID)
end

local function TrimItemName(name)
  if type(name) ~= "string" then return nil end
  local text = string.gsub(name, "|c%x%x%x%x%x%x%x%x", "")
  text = string.gsub(text, "|r", "")
  text = string.gsub(text, "^%s+", "")
  text = string.gsub(text, "%s+$", "")
  if text == "" then return nil end
  return text
end

local function NativeNameFromLink(link)
  if type(link) ~= "string" or type(GetItemInfo) ~= "function" then return nil end
  local ok, name = pcall(GetItemInfo, link)
  if ok then return TrimItemName(name) end
  return nil
end

-- Random-property names are supplied by the client rather than item_template.
-- The bundled table therefore contains only the base item name. Preserve the
-- native property and translate the common English suffixes used by 1.12.
local EnglishRandomAffixes = {
  ["of the owl"] = "올빼미의",
  ["of the eagle"] = "독수리의",
  ["of the falcon"] = "매의",
  ["of the whale"] = "고래의",
  ["of the monkey"] = "원숭이의",
  ["of the tiger"] = "호랑이의",
  ["of the bear"] = "곰의",
  ["of the boar"] = "멧돼지의",
  ["of the gorilla"] = "고릴라의",
  ["of the wolf"] = "늑대의",
  ["of strength"] = "힘의",
  ["of stamina"] = "체력의",
  ["of agility"] = "민첩성의",
  ["of intellect"] = "지능의",
  ["of spirit"] = "정신력의",
  ["of power"] = "마력의",
  ["of defense"] = "방어의",
  ["of healing"] = "치유의",
  ["of regeneration"] = "재생의",
  ["of concentration"] = "집중의",
  ["of eluding"] = "회피의",
  ["of marksmanship"] = "명사수의",
  ["of fiery wrath"] = "불타는 분노의",
  ["of frozen wrath"] = "얼어붙은 분노의",
  ["of arcane wrath"] = "비전 마법 강화의",
  ["of shadow wrath"] = "암흑 마법 강화의",
  ["of nature's wrath"] = "자연 마법 강화의",
  ["of the sorcerer"] = "마술사의",
  ["of the physician"] = "치유사의",
}

local KoreanRandomPrefixes = {
  "올빼미의", "독수리의", "매의", "고래의", "원숭이의",
  "호랑이의", "곰의", "멧돼지의", "고릴라의", "늑대의",
  "힘의", "체력의", "민첩성의", "지능의", "정신력의",
  "마력의", "방어의", "치유의", "재생의", "집중의",
  "회피의", "명사수의", "불타는 분노의", "얼어붙은 분노의",
  "비전 마법 강화의", "암흑 마법 강화의", "자연 마법 강화의",
  "마술사의", "치유사의",
}

local function RandomPropertyPrefix(nativeName, englishBase)
  if not nativeName then return nil end

  for index = 1, table.getn(KoreanRandomPrefixes) do
    local prefix = KoreanRandomPrefixes[index]
    if string.sub(nativeName, 1, string.len(prefix) + 1) == prefix.." " then
      return prefix
    end
  end

  local lowerName = string.lower(nativeName)
  for suffix, prefix in pairs(EnglishRandomAffixes) do
    if string.sub(lowerName, -string.len(suffix)) == suffix then
      return prefix
    end
  end

  -- Some servers return "<affix> <base name>" instead of an "of ..." suffix.
  -- When the exact English base is present, retain the unmatched native text.
  if englishBase then
    local first, last = string.find(nativeName, englishBase, 1, true)
    if first then
      local extra = TrimItemName(string.sub(nativeName, 1, first - 1).." "..string.sub(nativeName, last + 1))
      if extra and extra ~= "" then
        local translated = EnglishRandomAffixes[string.lower(extra)]
        return translated or extra
      end
    end
  end
  return nil
end

local function DisplayNameFromLink(link)
  local localizedName, itemID = LocalizedNameFromLink(link)
  if not localizedName then return nil, itemID end

  local randomPropertyID = RandomPropertyIDFromLink(link)
  if not randomPropertyID or randomPropertyID == 0 then
    return localizedName, itemID
  end

  if RandomProperties then
    local prefix = RandomProperties[randomPropertyID] or RandomProperties[-randomPropertyID]
    prefix = CleanUnusedMarker(prefix)
    if prefix and prefix ~= "" then
      return prefix.." "..localizedName, itemID
    end
  end

  local nativeName = NativeNameFromLink(link)
  if nativeName == localizedName then return localizedName, itemID end
  local englishBase = EnglishNames and itemID and EnglishNames[itemID]
  local prefix = RandomPropertyPrefix(nativeName, englishBase)
  if prefix then return prefix.." "..localizedName, itemID end
  return localizedName, itemID
end

LocalizedNameFromLink = function(link)
  local itemID = ItemIDFromLink(link)
  if not itemID then return nil end
  return LocalizedNameFromID(itemID), itemID
end

function LaziKoreanQuest_GetItemName(itemID)
  return LocalizedNameFromID(itemID)
end

function LaziKoreanQuest_GetDisplayItemName(link)
  return DisplayNameFromLink(link)
end

local function Call0(functionName)
  local callback = getglobal(functionName)
  if type(callback) ~= "function" then return nil end
  local ok, result = pcall(callback)
  if ok and type(result) == "string" then return result end
  return nil
end

local function Call1(functionName, value)
  local callback = getglobal(functionName)
  if type(callback) ~= "function" then return nil end
  local ok, result = pcall(callback, value)
  if ok and type(result) == "string" then return result end
  return nil
end

local function Call2(functionName, first, second)
  local callback = getglobal(functionName)
  if type(callback) ~= "function" then return nil end
  local ok, result = pcall(callback, first, second)
  if ok and type(result) == "string" then return result end
  return nil
end

local function SetTextFromLink(fontString, link)
  if not fontString or type(fontString.SetText) ~= "function" then return end
  local localizedName = DisplayNameFromLink(link)
  if localizedName then fontString:SetText(localizedName) end
end

-- Tooltip localization ----------------------------------------------------

local function TooltipItemLink(tooltip)
  if not tooltip or type(tooltip.GetItem) ~= "function" then return nil end
  local ok, _, link = pcall(tooltip.GetItem, tooltip)
  if ok and type(link) == "string" then return link end
  return nil
end

local function EnglishTooltipName(firstLine)
  if not firstLine or type(firstLine.GetText) ~= "function" then return nil end
  local text = firstLine:GetText()
  if type(text) ~= "string" or text == "" then return nil end

  -- A nested tooltip call may already have passed through this module. Never
  -- treat the previously composed two-line title as a new English source.
  if string.find(text, "\n", 1, true) then return nil end

  text = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "")
  text = string.gsub(text, "|r", "")
  text = string.gsub(text, "^%s+", "")
  text = string.gsub(text, "%s+$", "")
  if text == "" or not string.find(text, "[A-Za-z]") then return nil end
  return text
end

local function LocalizedCooldownText(text)
  if type(text) ~= "string" then return nil end

  local _, _, value = string.find(text, "^%s*CD:%s*([%d%.]+)%s*sec%s*$")
  if not value then _, _, value = string.find(text, "^%s*CD:%s*([%d%.]+)%s*secs%s*$") end
  if not value then _, _, value = string.find(text, "^%s*CD:%s*([%d%.]+)%s*second%s*$") end
  if not value then _, _, value = string.find(text, "^%s*CD:%s*([%d%.]+)%s*seconds%s*$") end
  if value then return "재사용 대기시간: "..value.."초" end

  _, _, value = string.find(text, "^%s*CD:%s*([%d%.]+)%s*min%s*$")
  if not value then _, _, value = string.find(text, "^%s*CD:%s*([%d%.]+)%s*mins%s*$") end
  if not value then _, _, value = string.find(text, "^%s*CD:%s*([%d%.]+)%s*minute%s*$") end
  if not value then _, _, value = string.find(text, "^%s*CD:%s*([%d%.]+)%s*minutes%s*$") end
  if value then return "재사용 대기시간: "..value.."분" end

  _, _, value = string.find(text, "^%s*CD:%s*([%d%.]+)%s*hr%s*$")
  if not value then _, _, value = string.find(text, "^%s*CD:%s*([%d%.]+)%s*hrs%s*$") end
  if not value then _, _, value = string.find(text, "^%s*CD:%s*([%d%.]+)%s*hour%s*$") end
  if not value then _, _, value = string.find(text, "^%s*CD:%s*([%d%.]+)%s*hours%s*$") end
  if value then return "재사용 대기시간: "..value.."시간" end

  return nil
end

local function ApplyTooltipCooldown(tooltip)
  if not tooltip or type(tooltip.GetName) ~= "function"
    or type(tooltip.NumLines) ~= "function" then return end
  local tooltipName = tooltip:GetName()
  if not tooltipName then return end

  local lineCount = tooltip:NumLines() or 0
  for index = 2, lineCount do
    local line = getglobal(tooltipName.."TextLeft"..index)
    if line and type(line.GetText) == "function" and type(line.SetText) == "function" then
      local localized = LocalizedCooldownText(line:GetText())
      if localized then line:SetText(localized) end
    end
  end
end

local function ApplyTooltipName(tooltip, fallbackLink)
  if not tooltip or type(tooltip.GetName) ~= "function" then return end
  ApplyTooltipCooldown(tooltip)
  local link = TooltipItemLink(tooltip) or fallbackLink
  local localizedName, itemID = DisplayNameFromLink(link)
  if not localizedName then return end

  local tooltipName = tooltip:GetName()
  if not tooltipName then return end
  local firstLine = getglobal(tooltipName.."TextLeft1")
  if firstLine and type(firstLine.SetText) == "function" then
    local englishName = EnglishTooltipName(firstLine)
    if not englishName and EnglishNames and itemID then
      englishName = EnglishNames[itemID]
    end
    local displayName = localizedName
    if englishName and englishName ~= localizedName then
      -- Keep the Korean item-quality color on line one and show the native
      -- English name immediately below it in a quieter gray.
      displayName = localizedName.."\n|cffb0b0b0("..englishName..")|r"
    end
    firstLine:SetText(displayName)
    -- Recalculate width and height for the two-line title.
    if type(tooltip.Show) == "function" then tooltip:Show() end
  end
end

local TooltipResolvers = {
  SetHyperlink = function(_, link)
    return link
  end,
  SetBagItem = function(_, bag, slot)
    return Call2("GetContainerItemLink", bag, slot)
  end,
  SetInventoryItem = function(_, unit, slot)
    return Call2("GetInventoryItemLink", unit, slot)
  end,
  SetLootItem = function(_, slot)
    return Call1("GetLootSlotLink", slot)
  end,
  SetLootRollItem = function(_, rollID)
    return Call1("GetLootRollItemLink", rollID)
  end,
  SetMerchantItem = function(_, index)
    return Call1("GetMerchantItemLink", index)
  end,
  SetBuybackItem = function(_, index)
    return Call1("GetBuybackItemLink", index)
  end,
  SetQuestItem = function(_, itemType, index)
    return Call2("GetQuestItemLink", itemType, index)
  end,
  SetQuestLogItem = function(_, itemType, index)
    return Call2("GetQuestLogItemLink", itemType, index)
  end,
  SetTradePlayerItem = function(_, index)
    return Call1("GetTradePlayerItemLink", index)
  end,
  SetTradeTargetItem = function(_, index)
    return Call1("GetTradeTargetItemLink", index)
  end,
  SetAuctionItem = function(_, listType, index)
    return Call2("GetAuctionItemLink", listType, index)
  end,
  SetAuctionSellItem = function()
    return Call0("GetAuctionSellItemLink")
  end,
  SetCraftItem = function(_, skillIndex, reagentIndex)
    if reagentIndex then
      return Call2("GetCraftReagentItemLink", skillIndex, reagentIndex)
    end
    return Call1("GetCraftItemLink", skillIndex)
  end,
  SetTradeSkillItem = function(_, skillIndex, reagentIndex)
    if reagentIndex then
      return Call2("GetTradeSkillReagentItemLink", skillIndex, reagentIndex)
    end
    return Call1("GetTradeSkillItemLink", skillIndex)
  end,
  SetInboxItem = function(_, index)
    return Call1("GetInboxItemLink", index)
  end,
  SetSendMailItem = function()
    return Call0("GetSendMailItemLink")
  end,
  -- SetAction can represent an item or a spell. Tooltip:GetItem safely tells
  -- the two cases apart, so this resolver intentionally has no fallback.
  SetAction = false,
}

local function HookTooltipMethod(tooltip, methodName, resolver)
  local original = tooltip and tooltip[methodName]
  if type(original) ~= "function" then return end

  tooltip[methodName] = function(...)
    -- WoW 1.12 uses Lua 5.0's implicit arg table for vararg functions. Calling
    -- unpack(arg) keeps the exact native method signature, including methods
    -- with no explicit parameters.
    local callArguments = arg
    local first, second, third, fourth, fifth = original(unpack(callArguments))
    local currentTooltip = callArguments[1] or tooltip
    local fallbackLink
    if type(resolver) == "function" then
      local ok, value = pcall(resolver, unpack(callArguments))
      if ok then fallbackLink = value end
    end
    ApplyTooltipName(currentTooltip, fallbackLink)
    return first, second, third, fourth, fifth
  end
end

local function InstallTooltipHooks()
  if ItemLocale.TooltipHooksInstalled then return end
  ItemLocale.TooltipHooksInstalled = true

  local tooltipNames = { "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2" }
  for index = 1, table.getn(tooltipNames) do
    local tooltip = getglobal(tooltipNames[index])
    if tooltip then
      for methodName, resolver in pairs(TooltipResolvers) do
        HookTooltipMethod(tooltip, methodName, resolver)
      end
    end
  end
end

-- Native frame labels -----------------------------------------------------

local function ApplyQuestItemPrefix(prefix, maximum, linkFunction)
  for index = 1, maximum do
    local button = getglobal(prefix..index)
    if button and (not button.IsVisible or button:IsVisible())
      and button.rewardType ~= "spell" then
      local itemType = button.type
      local itemIndex = type(button.GetID) == "function" and button:GetID() or nil
      if itemType and itemIndex then
        SetTextFromLink(getglobal(prefix..index.."Name"), Call2(linkFunction, itemType, itemIndex))
      end
    end
  end
end

local function RefreshQuestItemNames()
  ApplyQuestItemPrefix("QuestDetailItem", 10, "GetQuestItemLink")
  ApplyQuestItemPrefix("QuestProgressItem", 6, "GetQuestItemLink")
  ApplyQuestItemPrefix("QuestRewardItem", 10, "GetQuestItemLink")
  ApplyQuestItemPrefix("QuestLogItem", 10, "GetQuestLogItemLink")
end

local function RefreshLootItemNames()
  local maximum = tonumber(LOOTFRAME_NUMBUTTONS) or 4
  for index = 1, maximum do
    local button = getglobal("LootButton"..index)
    if button and button.slot and (not button.IsVisible or button:IsVisible()) then
      SetTextFromLink(getglobal("LootButton"..index.."Text"), Call1("GetLootSlotLink", button.slot))
    end
  end
end

local function RefreshMerchantItemNames()
  if not MerchantFrame or not MerchantFrame.selectedTab then return end

  if MerchantFrame.selectedTab == 1 then
    local maximum = tonumber(MERCHANT_ITEMS_PER_PAGE) or 10
    for index = 1, maximum do
      local button = getglobal("MerchantItem"..index.."ItemButton")
      local itemIndex = button and type(button.GetID) == "function" and button:GetID() or nil
      if itemIndex and itemIndex > 0 then
        SetTextFromLink(getglobal("MerchantItem"..index.."Name"), Call1("GetMerchantItemLink", itemIndex))
      end
    end

    local buybackIndex = type(GetNumBuybackItems) == "function" and GetNumBuybackItems() or 0
    if buybackIndex and buybackIndex > 0 then
      SetTextFromLink(MerchantBuyBackItemName, Call1("GetBuybackItemLink", buybackIndex))
    end
  else
    local maximum = tonumber(BUYBACK_ITEMS_PER_PAGE) or 12
    for index = 1, maximum do
      SetTextFromLink(getglobal("MerchantItem"..index.."Name"), Call1("GetBuybackItemLink", index))
    end
  end
end

local function RefreshAuctionNames(listType, buttonPrefix, maximum, scrollFrame)
  if not scrollFrame or type(FauxScrollFrame_GetOffset) ~= "function" then return end
  local offset = FauxScrollFrame_GetOffset(scrollFrame) or 0
  for index = 1, maximum do
    local button = getglobal(buttonPrefix..index)
    if button and (not button.IsVisible or button:IsVisible()) then
      local link = Call2("GetAuctionItemLink", listType, offset + index)
      SetTextFromLink(getglobal(buttonPrefix..index.."Name"), link)
    end
  end
end

local function InstallAuctionHooks()
  if ItemLocale.AuctionHooksInstalled then return end
  if type(AuctionFrameBrowse_Update) ~= "function" then return end
  ItemLocale.AuctionHooksInstalled = true

  local originalBrowseUpdate = AuctionFrameBrowse_Update
  AuctionFrameBrowse_Update = function()
    originalBrowseUpdate()
    RefreshAuctionNames("list", "BrowseButton", tonumber(NUM_BROWSE_TO_DISPLAY) or 8, BrowseScrollFrame)
  end

  if type(AuctionFrameBid_Update) == "function" then
    local originalBidUpdate = AuctionFrameBid_Update
    AuctionFrameBid_Update = function()
      originalBidUpdate()
      RefreshAuctionNames("bidder", "BidButton", tonumber(NUM_BIDS_TO_DISPLAY) or 9, BidScrollFrame)
    end
  end

  if type(AuctionFrameAuctions_Update) == "function" then
    local originalAuctionsUpdate = AuctionFrameAuctions_Update
    AuctionFrameAuctions_Update = function()
      originalAuctionsUpdate()
      RefreshAuctionNames("owner", "AuctionsButton", tonumber(NUM_AUCTIONS_TO_DISPLAY) or 9, AuctionsScrollFrame)
    end
  end
end

-- Wrap native refresh functions only after LaziKoreanQuest has installed its
-- quest-text hooks. This keeps the existing quest renderer completely intact.
if type(QuestFrameItems_Update) == "function" then
  local originalQuestFrameItemsUpdate = QuestFrameItems_Update
  QuestFrameItems_Update = function(questState)
    originalQuestFrameItemsUpdate(questState)
    RefreshQuestItemNames()
  end
end

if type(QuestFrameProgressItems_Update) == "function" then
  local originalQuestProgressItemsUpdate = QuestFrameProgressItems_Update
  QuestFrameProgressItems_Update = function()
    originalQuestProgressItemsUpdate()
    RefreshQuestItemNames()
  end
end

if type(QuestLog_UpdateQuestDetails) == "function" then
  local originalQuestLogUpdate = QuestLog_UpdateQuestDetails
  QuestLog_UpdateQuestDetails = function(doNotScroll)
    originalQuestLogUpdate(doNotScroll)
    RefreshQuestItemNames()
  end
end

if type(LootFrame_Update) == "function" then
  local originalLootFrameUpdate = LootFrame_Update
  LootFrame_Update = function()
    originalLootFrameUpdate()
    RefreshLootItemNames()
  end
end

if type(MerchantFrame_Update) == "function" then
  local originalMerchantFrameUpdate = MerchantFrame_Update
  MerchantFrame_Update = function()
    originalMerchantFrameUpdate()
    RefreshMerchantItemNames()
  end
end

InstallTooltipHooks()
InstallAuctionHooks()

local refreshFrame = CreateFrame("Frame", "VanillaKoreanCoreItemLocaleFrame")
refreshFrame:RegisterEvent("ADDON_LOADED")
refreshFrame:RegisterEvent("QUEST_ITEM_UPDATE")
refreshFrame:RegisterEvent("QUEST_LOG_UPDATE")
refreshFrame:RegisterEvent("LOOT_OPENED")
refreshFrame:RegisterEvent("LOOT_SLOT_CLEARED")
refreshFrame:RegisterEvent("MERCHANT_SHOW")
refreshFrame:RegisterEvent("MERCHANT_UPDATE")

local refreshPending = false
local function ApplyPendingRefresh()
  refreshFrame:SetScript("OnUpdate", nil)
  if not refreshPending then return end
  refreshPending = false
  RefreshQuestItemNames()
  RefreshLootItemNames()
  RefreshMerchantItemNames()
end

refreshFrame:SetScript("OnEvent", function()
  if event == "ADDON_LOADED" then
    InstallAuctionHooks()
  end
  refreshPending = true
  refreshFrame:SetScript("OnUpdate", ApplyPendingRefresh)
end)
