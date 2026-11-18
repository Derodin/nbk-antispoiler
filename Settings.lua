local addonName, addon = ...
local NBK = _G.NBK
local KEY = "AntiSpoiler"
local L = NBK.L

addon.ChannelByEvent = {
    CHAT_MSG_CHANNEL = "channels", CHAT_MSG_SAY = "say", CHAT_MSG_YELL = "yell",
    CHAT_MSG_WHISPER = "whisper", CHAT_MSG_GUILD = "guild", CHAT_MSG_OFFICER = "guild",
    CHAT_MSG_PARTY = "group", CHAT_MSG_PARTY_LEADER = "group",
    CHAT_MSG_RAID = "group", CHAT_MSG_RAID_LEADER = "group", CHAT_MSG_RAID_WARNING = "group",
    CHAT_MSG_INSTANCE_CHAT = "group", CHAT_MSG_INSTANCE_CHAT_LEADER = "group",
}

local channels = {
    { "channels", L["AntiSpoiler: Trade and public channels"] },
    { "say", L["AntiSpoiler: Say"] },
    { "yell", L["AntiSpoiler: Yell"] },
    { "guild", L["AntiSpoiler: Guild and officer chat"] },
    { "group", L["AntiSpoiler: Party, raid and instance chat"] },
    { "whisper", L["AntiSpoiler: Incoming whispers"] },
}
local levels = { "Light", "Medium", "High", "Context" }

NBK:RegisterAddonDB({
    addonName = addonName,
    key = KEY,
    svName = "NerzorsBlacklistKeeperAntiSpoilerDB",
    version = 1,
    defaults = {
        active = false, introductionSeen = false, observe = false, autoMute = true,
        manualMutes = {}, markers = {},
        levels = { Light = true, Medium = true, High = true, Context = true },
        channels = { channels = true, say = true, yell = true, guild = true, group = true, whisper = true },
    },
})

function addon.GetSettings()
    return NBK:GetAddonDB(KEY)
end

function addon.FormatSpoiler(level, count)
    if level == "Context" then
        return L["AntiSpoiler: [Hidden · GTA VI · Context · Possible spoiler]"]
    end
    local pattern = count == 1 and L["AntiSpoiler: [Hidden · GTA VI · %s · %d match]"]
        or L["AntiSpoiler: [Hidden · GTA VI · %s · %d matches]"]
    return pattern:format(level, count)
end

function addon.FormatSenderMute(reason)
    if reason == "manual" then
        return L["AntiSpoiler: [Hidden · Anti-Spoiler · Player muted manually]"]
    end
    return L["AntiSpoiler: [Hidden · Anti-Spoiler · Multiple High matches]"]
end

local toggleProtection
local function chooseProtection(active)
    local settings = addon.GetSettings()
    if not settings then return end
    if settings.active ~= active then
        addon.ClearContext()
        addon.ClearSenderProtection()
    end
    settings.active, settings.introductionSeen = active, true
    if toggleProtection then toggleProtection:SetChecked(active) end
end

local introduction
local examples = {
    { "8fe9a3", "Light", L["AntiSpoiler: One profile match. ‘Grandma loves you’ matches Grandma."] },
    { "ffd27a", "Medium", L["AntiSpoiler: Several matches. ‘Grandma rides a bike in the mission.’"] },
    { "ff848a", "High", L["AntiSpoiler: Critical event. ‘Grandma rides a bike in the mission and falls off.’"] },
    { "83c9ff", "Context", L["AntiSpoiler: Possible spoiler in a reply within one minute in the same conversation. ‘No, she rides a scooter and doesn't fall off.’"] },
}

function addon.ShowIntroduction()
    if not introduction then
        local NUL = LibStub("NerzorsUILib-1.0")
        introduction = NUL:Window({
            name = "NBKAntiSpoilerIntroduction", title = "NBK - Anti-Spoiler", width = 560, height = 540, strata = "DIALOG",
        })
        local content = introduction.content
        local scroll = CreateFrame("ScrollFrame", nil, content, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
        scroll:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -22, 42)
        local scrollContent = CreateFrame("Frame", nil, scroll)
        scrollContent:SetSize(1, 1)
        scroll:SetScrollChild(scrollContent)
        NUL:_AttachThemedScrollBar(scroll, content)

        local heading = NUL:CreateLabel(scrollContent, {
            text = L["AntiSpoiler: GTA VI in WoW chat"], size = "xl", justifyH = "LEFT",
        })
        heading:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 4, -2)

        local paragraphs = {
            L["AntiSpoiler: Suspected spoilers are replaced with a notice in your chat. These examples are fictional."],
        }
        for _, row in ipairs(examples) do
            paragraphs[#paragraphs + 1] = ("|cff%s%s|r\n%s"):format(row[1], row[2], row[3])
        end
        paragraphs[#paragraphs + 1] = L["AntiSpoiler: Mute players\nTwo High matches within five minutes hide the player's later messages for five minutes. Right-click to hide or restore all of their messages."]
        paragraphs[#paragraphs + 1] = L["AntiSpoiler: Report missed spoilers\nRight-click the chat name and choose Mark as spoiler. In My spoiler markers, create an encoded string for a GitHub issue. The developer addon reads it for review."]

        -- One text flow lets WoW wrap paragraphs without positioning siblings
        -- from text measurements that may still reflect the hidden window.
        local body = NUL:CreateLabel(scrollContent, {
            text = table.concat(paragraphs, "\n\n"), justifyH = "LEFT", justifyV = "TOP",
        })
        body:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -8)
        body:SetSpacing(3)

        local function updateScrollSize()
            local width = scroll:GetWidth()
            if width <= 8 then return end
            scrollContent:SetWidth(width)
            heading:SetWidth(width - 8)
            body:SetWidth(width - 8)
            scrollContent:SetHeight(math.max(scroll:GetHeight(), heading:GetStringHeight() + body:GetStringHeight() + 28))
        end
        scroll:HookScript("OnSizeChanged", updateScrollSize)
        scroll:HookScript("OnShow", function()
            updateScrollSize()
            C_Timer.After(0, updateScrollSize)
        end)

        local function button(label, style, offset, active)
            local control = NUL:Button(content, {
                label = label, style = style, width = 185, height = 28,
                onClick = function()
                    local settings = addon.GetSettings()
                    if settings then chooseProtection(active or settings.active) end
                    introduction:Hide()
                end,
            })
            control:SetPoint("BOTTOMLEFT", content, "BOTTOMLEFT", offset, 0)
        end
        button(L["AntiSpoiler: Enable protection"], "primary", 4, true)
        button(L["AntiSpoiler: Skip for now"], "secondary", 199, false)
    end
    introduction:Show()
end

local function buildSettings(parent)
    local NUL = LibStub("NerzorsUILib-1.0")
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetAllPoints()
    local settings = addon.GetSettings()
    if not settings then return panel end

    local y = 0
    local function checkbox(options, key, label)
        local check = NUL:Checkbox(panel, {
            label = label, checked = options[key],
            onChange = function(checked)
                options[key] = checked
                if key == "active" or options == settings.channels then addon.ClearContext() end
                if key == "active" or key == "autoMute" or key == "observe" or key == "High" then
                    addon.ClearSenderProtection()
                end
            end,
        })
        check:SetPoint("TOPLEFT", 0, y)
        y = y - 26
        return check
    end

    toggleProtection = checkbox(settings, "active", L["AntiSpoiler: Enable GTA VI protection"])
    checkbox(settings, "observe", L["AntiSpoiler: Observe only"])
    checkbox(settings, "autoMute", L["AntiSpoiler: Mute for 5 minutes after two High matches"])
    y = y - 6
    for _, level in ipairs(levels) do
        checkbox(settings.levels, level, (L["AntiSpoiler: Hide %s"]):format(level))
    end
    y = y - 6
    for _, channel in ipairs(channels) do
        checkbox(settings.channels, channel[1], channel[2])
    end
    local button = NUL:Button(panel, {
        label = L["AntiSpoiler: Open introduction"], height = 24,
        onClick = addon.ShowIntroduction,
    })
    button:SetPoint("TOPLEFT", 0, y)
    y = y - 33
    local recent = NUL:Button(panel, {
        label = L["AntiSpoiler: Recent chat lines"], height = 24, onClick = function() addon.ShowMarkerEditor() end,
    })
    recent:SetPoint("TOPLEFT", 0, y)
    y = y - 30
    local markers = NUL:Button(panel, {
        label = L["AntiSpoiler: My spoiler markers"], height = 24, onClick = addon.ShowSavedMarkers,
    })
    markers:SetPoint("TOPLEFT", 0, y)
    y = y - 30
    local muted = NUL:Button(panel, {
        label = L["AntiSpoiler: Muted players"], height = 24, onClick = addon.ShowMutedPlayers,
    })
    muted:SetPoint("TOPLEFT", 0, y)
    panel.lastY = y - 30
    return panel
end

function addon.EnableSettings()
    NBK:GetModule("Config"):RegisterTab({
        key = KEY, labelKey = "Anti-Spoiler", build = buildSettings, order = 24, category = "modules",
    })
    local settings = addon.GetSettings()
    if settings and not settings.introductionSeen then addon.ShowIntroduction() end
end
