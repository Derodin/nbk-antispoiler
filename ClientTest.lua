local _, addon = ...
local NBK = _G.NBK
local module = {}
local L = NBK.L

local TEST_MESSAGE = "nbkas test"
local PLACEHOLDER = L["AntiSpoiler: [Hidden · Anti-Spoiler · Dev test]"]
local CACHE_LIMIT = 128

local devEnabled, includeOwn = false, false
local filterAvailable, menuAvailable = false, false
local decisions, recentKeys, nextSlot = {}, {}, 1
local observed, replaced, lastLine = 0, 0, nil

local function printStatus()
    NBK:Print(L["AntiSpoiler: Anti-Spoiler Dev | Filter: %s | Self-test: %s | Counted: %d | Replaced: %d"]:format(
        devEnabled and L["AntiSpoiler: on"] or L["AntiSpoiler: off"], includeOwn and L["AntiSpoiler: on"] or L["AntiSpoiler: off"], observed, replaced))
    local settings = addon.GetSettings()
    local mode = L["AntiSpoiler: off"]
    if settings and settings.active then mode = settings.observe and L["AntiSpoiler: observing"] or L["AntiSpoiler: hiding"] end
    NBK:Print(L["AntiSpoiler: Profile: %s v%d | Protection: %s"]:format(addon.GtaVI.id, addon.GtaVI.version, mode))
    NBK:Print(L["AntiSpoiler: Filter API: %s | Chat menu hook: %s"]:format(
        filterAvailable and L["AntiSpoiler: registered"] or L["AntiSpoiler: missing"],
        menuAvailable and L["AntiSpoiler: registered (NBK)"] or L["AntiSpoiler: missing"]))
    if lastLine then
        NBK:Print(L["AntiSpoiler: Last line: %s | ID: %s | %s"]:format(
            lastLine.event, lastLine.id or "-", lastLine.id and L["AntiSpoiler: counted"] or L["AntiSpoiler: no usable ID"]))
        if lastLine.level == "Context" then
            NBK:Print(L["AntiSpoiler: GTA VI | Context | Possible spoiler"])
        elseif lastLine.level then
            NBK:Print(L["AntiSpoiler: GTA VI | %s | %d matches"]:format(lastLine.level, lastLine.count))
        end
    end
end

local function isOwnMessage(sender, senderGUID)
    if addon.IsReadableString(senderGUID) then
        local playerGUID = UnitGUID("player")
        if addon.IsReadableString(playerGUID) then return senderGUID == playerGUID end
    end
    local senderKey = addon.ResolveChatSender(sender)
    local playerKey = addon.ResolveChatSender(NBK:PlayerFullName())
    if senderKey and playerKey then return senderKey == playerKey end
    -- Keep ambiguous senders out of counts until the solo mode is enabled.
    return nil
end

local function filterLine(_, event, text, sender, ...)
    local settings = addon.GetSettings()
    local profileActive = settings and settings.active
    local profileEnabled = profileActive and settings.channels[addon.ChannelByEvent[event]]
    if not (devEnabled or profileActive) or not addon.IsReadableString(text) then return false end

    -- WoW supplies the line ID and GUID as arguments 11 and 12.
    local fullChannel, _, _, zoneID, _, baseChannel, _, lineID, senderGUID = select(2, ...)
    if (issecretvalue and issecretvalue(lineID)) or type(lineID) ~= "number" or lineID <= 0 then
        lineID = nil
    end
    local lineKey = lineID and (event .. ":" .. lineID)
    local replacement = lineKey and decisions[lineKey]
    if replacement == nil then
        if not includeOwn and isOwnMessage(sender, senderGUID) ~= false then return false end
        local level, count
        replacement = false
        if devEnabled and text:lower():match("^ *" .. TEST_MESSAGE .. " *$") then
            replacement = PLACEHOLDER
        elseif profileActive then
            local author, name, realm = addon.ResolveChatSender(sender)
            local now = GetTime()
            local mute
            if author and not settings.observe then
                if settings.manualMutes[author] then
                    mute = "manual"
                elseif settings.autoMute and addon.IsTemporarilyMuted(author, now) then
                    mute = "repeat"
                end
            end
            if mute then
                replacement = addon.FormatSenderMute(mute)
            elseif profileEnabled then
                local evidence
                level, count, evidence = addon.ClassifySpoiler(text)
                if lineKey then
                    local contextAuthor = author
                    if not contextAuthor and addon.IsReadableString(senderGUID) then contextAuthor = senderGUID end
                    local scope = contextAuthor and addon.ContextScope(event, contextAuthor, zoneID, fullChannel, baseChannel)
                    if scope and addon.CheckContext(scope, contextAuthor, now, evidence, level) then level = "Context" end
                    if author and level == "High" and settings.levels.High and settings.autoMute and not settings.observe then
                        addon.RecordHighSpoiler(author, lineKey, now, name, realm)
                    end
                end
                if level and settings.levels[level] and not settings.observe then
                    replacement = addon.FormatSpoiler(level, count)
                end
            elseif not devEnabled then
                return false
            end
            if lineKey and author and (profileEnabled or mute) then
                local channel = addon.IsReadableString(baseChannel) and baseChannel or event:sub(10)
                addon.RememberMarkerLine(author, sender, event, lineID, channel, level, text, now)
            end
        end
        lastLine = { event = event, id = lineID, level = level, count = count }
        if lineKey then
            local previousKey = recentKeys[nextSlot]
            if previousKey then decisions[previousKey] = nil end
            recentKeys[nextSlot] = lineKey
            nextSlot = nextSlot % CACHE_LIMIT + 1
            decisions[lineKey] = replacement
            observed = observed + 1
            if replacement then replaced = replaced + 1 end
        end
    end

    -- Keep the original event arguments, including the player link metadata.
    if replacement then return false, replacement, sender, ... end
    return false
end

local function readMenuID(value)
    if issecretvalue and issecretvalue(value) then return nil, L["AntiSpoiler: protected"] end
    local valueType = type(value)
    local number
    if valueType == "number" then
        number = value
    elseif valueType == "string" and value:match("^[0-9]+$") then
        number = tonumber(value)
    end
    if number and number > 0 and number < math.huge and number % 1 == 0 then
        return number, valueType
    end
    return nil, L["AntiSpoiler: %s (invalid ID)"]:format(valueType)
end

local function buildMenuProbe(rootDescription, contextData)
    local fields, ids = {}, {}
    local lineIDStatus = L["AntiSpoiler: missing"]
    if not (issecretvalue and issecretvalue(contextData)) and type(contextData) == "table" then
        for key, value in pairs(contextData) do
            if not (issecretvalue and issecretvalue(key)) and type(key) == "string" then
                fields[#fields + 1] = key
                local lowerKey = key:lower()
                if lowerKey:find("line", 1, true) or lowerKey:find("message", 1, true) then
                    local id, status = readMenuID(value)
                    if id then ids[#ids + 1] = key .. "=" .. id end
                    if key == "lineID" then lineIDStatus = status end
                end
            end
        end
    end
    table.sort(fields)
    table.sort(ids)
    rootDescription:CreateButton(L["AntiSpoiler: NBK Anti-Spoiler: Check chat menu"], function()
        NBK:Print(L["AntiSpoiler: Anti-Spoiler Dev | Menu fields: %s"]:format(#fields > 0 and table.concat(fields, ", ") or "-"))
        NBK:Print(L["AntiSpoiler: ID candidates: %s"]:format(#ids > 0 and table.concat(ids, ", ") or "-"))
        NBK:Print("lineID: " .. lineIDStatus)
    end)
end

local function buildPlayerMenu(rootDescription, name, realm, _unit, contextData)
    local settings = addon.GetSettings()
    if not settings or not addon.IsReadableString(name) then return end
    local sender = addon.IsReadableString(realm) and (name .. "-" .. realm) or name
    local author, resolvedName, resolvedRealm = addon.ResolveChatSender(sender)
    if not author and not devEnabled then return end

    rootDescription:CreateDivider()
    rootDescription:CreateTitle("|cff83c9ffNBK - ANTI SPOILER|r")
    if author then
        local recent = addon.GetRecentMarkerLines(author, nil, GetTime())
        if #recent > 0 then
            local lineID
            if not (issecretvalue and issecretvalue(contextData)) and type(contextData) == "table" then
                lineID = readMenuID(contextData.lineID)
            end
            rootDescription:CreateButton(L["AntiSpoiler: Mark as spoiler …"], function()
                addon.ShowMarkerEditor(author, lineID)
            end)
        end
        local hideLabel = L["AntiSpoiler: Hide all messages"]
        local showLabel = L["AntiSpoiler: Restore messages"]
        local manualMutes = settings.manualMutes
        rootDescription:CreateButton(manualMutes[author] and showLabel or hideLabel, function()
            addon.SetManualSpoilerMute(settings, author, resolvedName, resolvedRealm, not manualMutes[author])
        end)
        if addon.IsTemporarilyMuted(author, GetTime()) then
            rootDescription:CreateButton(L["AntiSpoiler: Lift temporary mute"], function()
                addon.ClearSenderProtection(author)
            end)
        end
    end
    if devEnabled then buildMenuProbe(rootDescription, contextData) end
end

local function handleCommand(input)
    local command = input:lower():match("^%s*(.-)%s*$")
    if command == "on" then
        devEnabled = filterAvailable
    elseif command == "off" then
        devEnabled, includeOwn = false, false
    elseif command == "self on" then
        local settings = addon.GetSettings()
        if not (devEnabled or (settings and settings.active and filterAvailable)) then
            NBK:Print(L["AntiSpoiler: Anti-Spoiler Dev: Enable GTA VI protection or enter /nbkspoiler on first."])
            return
        end
        includeOwn = true
    elseif command == "self off" then
        includeOwn = false
    elseif command == "reset" then
        decisions, recentKeys, nextSlot = {}, {}, 1
        observed, replaced, lastLine = 0, 0, nil
        addon.ClearContext()
        addon.ClearSenderProtection()
        addon.ClearRecentMarkerLines()
    elseif command == "intro" then
        addon.ShowIntroduction()
        return
    elseif command == "mark" then
        addon.ShowMarkerEditor()
        return
    elseif command == "markers" then
        addon.ShowSavedMarkers()
        return
    elseif command == "muted" then
        addon.ShowMutedPlayers()
        return
    elseif command ~= "status" then
        NBK:Print("/nbkspoiler on | off | self on | self off | reset | status | intro | mark | markers | muted")
        if command ~= "" then return end
    end
    printStatus()
end

function module:DecodeMarkerExport(text)
    if not addon.DecodeMarkerExport then return nil end
    return addon.DecodeMarkerExport(text)
end

function module:OnEnable()
    if not addon.ClassifySpoiler or not addon.CheckContext or not addon.EnableSettings or not addon.RecordHighSpoiler
        or not addon.RememberMarkerLine or not addon.ShowMarkerEditor or not addon.DecodeMarkerExport or not addon.ShowMutedPlayers then
        NBK:Print(L["AntiSpoiler: Anti-Spoiler: GTA VI profile could not load. Chat filter is off."])
        return
    end
    local addFilter = (ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter) or ChatFrame_AddMessageEventFilter
    if addFilter then
        for event in pairs(addon.ChannelByEvent) do addFilter(event, filterLine) end
        filterAvailable = true
        NBK:RegisterEvent("PLAYER_ENTERING_WORLD", function() addon.ClearContext() end)
        NBK:RegisterEvent("ZONE_CHANGED_NEW_AREA", function() addon.ClearContext() end)
        NBK:RegisterEvent("GROUP_ROSTER_UPDATE", function() addon.ClearContext("group") end)
        NBK:RegisterEvent("CHAT_MSG_CHANNEL_NOTICE", function(_, notice)
            if addon.IsReadableString(notice) and (notice == "YOU_JOINED" or notice == "YOU_LEFT"
                or notice == "SUSPENDED" or notice == "RESUMED") then
                addon.ClearContext("channel")
            end
        end)
    end
    local contextMenu = NBK:GetModule("ContextMenu")
    if Menu and Menu.ModifyMenu and contextMenu and contextMenu.RegisterAction then
        contextMenu:RegisterAction({
            key = "antispoiler_player_actions",
            order = 1000,
            builder = buildPlayerMenu,
        })
        menuAvailable = true
    end
    SLASH_NBKANTISPOILER1 = "/nbkspoiler"
    SlashCmdList.NBKANTISPOILER = handleCommand
    addon.EnableSettings()
end

NBK:RegisterModule("AntiSpoiler", module)
