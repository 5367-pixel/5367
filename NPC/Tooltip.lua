-- NPC tooltip module for VanillaKoreanCore.dll (WoW 1.12.1)
VanillaKoreanCoreDB = VanillaKoreanCoreDB or {}
VanillaKoreanCoreNPC = VanillaKoreanCoreNPC or {}

local byEnglish = nil
local lastEnglish = nil

local function Settings()
    if not VanillaKoreanCoreDB.NPCNames then
        VanillaKoreanCoreDB.NPCNames = { enabled = true, showEnglish = true }
    end
    return VanillaKoreanCoreDB.NPCNames
end

local function Print(message)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff3399ffVanillaKoreanCore:|r " .. message)
    end
end

local function BuildIndexes()
    if byEnglish then return end
    byEnglish = {}
    local id, row
    local names = VanillaKoreanCoreNPC.Names or {}
    for id, row in pairs(names) do
        if row and row[1] and row[2] then
            byEnglish[row[1]] = row[2]
        end
    end
    VanillaKoreanCoreNPC.Names = nil
end

local function TranslateTooltip(tip)
    local settings = Settings()
    if settings.enabled == false or not tip then return end
    -- Do not let this module process item/spell tooltips or player tooltips.
    if type(tip.GetUnit) ~= "function" then return end
    local unitName, unitToken = tip:GetUnit()
    if not unitToken then return end
    if type(UnitIsPlayer) == "function" and UnitIsPlayer(unitToken) then return end
    local title = getglobal(tip:GetName() .. "TextLeft1")
    if not title then return end
    local shown = title:GetText()
    if not shown or shown == "" then return end

    BuildIndexes()
    local korean = byEnglish[shown]
    -- Only translate an exact English source name. Native Korean names must
    -- remain untouched; reverse matching used to add unwanted blank rows.
    if not korean then return end
    local english = shown
    title:SetText(korean .. "*")

    if english and settings.showEnglish ~= false and lastEnglish ~= english then
        lastEnglish = english
        local count = tip:NumLines()
        tip:AddLine("")
        local i
        for i = count, 2, -1 do
            local oldLeft = getglobal(tip:GetName() .. "TextLeft" .. i)
            local oldRight = getglobal(tip:GetName() .. "TextRight" .. i)
            local newLeft = getglobal(tip:GetName() .. "TextLeft" .. (i + 1))
            local newRight = getglobal(tip:GetName() .. "TextRight" .. (i + 1))
            if oldLeft and newLeft then
                local r, g, b = oldLeft:GetTextColor()
                newLeft:SetText(oldLeft:GetText() or "")
                newLeft:SetTextColor(r, g, b)
                if oldLeft:IsShown() then newLeft:Show() else newLeft:Hide() end
            end
            if oldRight and newRight then
                local r, g, b = oldRight:GetTextColor()
                newRight:SetText(oldRight:GetText() or "")
                newRight:SetTextColor(r, g, b)
                if oldRight:IsShown() then newRight:Show() else newRight:Hide() end
            end
        end
        local line2 = getglobal(tip:GetName() .. "TextLeft2")
        local line2Right = getglobal(tip:GetName() .. "TextRight2")
        if line2 then
            line2:SetText("(" .. english .. ")")
            line2:SetTextColor(0.65, 0.75, 0.85)
            line2:Show()
        end
        if line2Right then line2Right:SetText("") line2Right:Hide() end
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("VARIABLES_LOADED")
frame:SetScript("OnEvent", function()
    Settings()
end)

local oldShow = GameTooltip:GetScript("OnShow")
GameTooltip:SetScript("OnShow", function()
    if oldShow then oldShow() end
    TranslateTooltip(GameTooltip)
end)

local oldHide = GameTooltip:GetScript("OnHide")
GameTooltip:SetScript("OnHide", function()
    lastEnglish = nil
    if oldHide then oldHide() end
end)

SLASH_VANILLAKOREANCORENPC1 = "/vkc"
SLASH_VANILLAKOREANCORENPC2 = "/knpc"
SlashCmdList["VANILLAKOREANCORENPC"] = function(message)
    message = string.lower(message or "")
    local settings = Settings()
    if message == "on" then
        settings.enabled = true
        Print("NPC 툴팁 한글화를 켰습니다.")
    elseif message == "off" then
        settings.enabled = false
        Print("NPC 툴팁 한글화를 껐습니다.")
    elseif message == "english on" then
        settings.showEnglish = true
        Print("한글 이름 아래에 영문명을 표시합니다.")
    elseif message == "english off" then
        settings.showEnglish = false
        Print("영문명 병기를 숨깁니다.")
    else
        Print("/vkc on|off, /vkc english on|off")
    end
end
