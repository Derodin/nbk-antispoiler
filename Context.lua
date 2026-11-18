local _, addon = ...

local MAX_LINES = 8
local MAX_AGE = 60
local MAX_CONVERSATIONS = 32
local conversations = {}
local kinds = {
    CHAT_MSG_SAY = "say", CHAT_MSG_YELL = "yell",
    CHAT_MSG_GUILD = "guild", CHAT_MSG_OFFICER = "officer",
    CHAT_MSG_PARTY = "party", CHAT_MSG_PARTY_LEADER = "party",
    CHAT_MSG_RAID = "raid", CHAT_MSG_RAID_LEADER = "raid", CHAT_MSG_RAID_WARNING = "raid",
    CHAT_MSG_INSTANCE_CHAT = "instance", CHAT_MSG_INSTANCE_CHAT_LEADER = "instance",
}

function addon.ClearContext(family)
    if not family then
        conversations = {}
        return
    end
    for key in pairs(conversations) do
        if family == "group" and (key == "party" or key == "raid" or key == "instance")
            or family == "channel" and key:sub(1, 8) == "channel:" then
            conversations[key] = nil
        end
    end
end

function addon.ContextScope(event, sender, zoneID, fullChannel, baseChannel)
    if event == "CHAT_MSG_WHISPER" then return "whisper:" .. sender end
    if event ~= "CHAT_MSG_CHANNEL" then return kinds[event] end
    if (issecretvalue and issecretvalue(zoneID)) or type(zoneID) ~= "number" or zoneID < 0 then return nil end
    -- The full channel can disambiguate local copies of a built-in channel.
    -- Strip the presentation number. Custom channels have no built-in ID.
    local name
    if addon.IsReadableString(fullChannel) then
        name = fullChannel:gsub("^%d+%.%s*", "")
    elseif addon.IsReadableString(baseChannel) then
        name = baseChannel
    end
    if not addon.IsReadableString(name) then return nil end
    return "channel:" .. zoneID .. ":" .. addon.NormalizeChatText(name)
end

local function overlaps(left, right)
    for value in pairs(left) do
        if right[value] then return true end
    end
    return false
end

local function storyHint(hints)
    return hints.mission or hints.chapter or hints.ending
end

local function onlyFigure(evidence)
    local figure = next(evidence.figures)
    if figure and not next(evidence.figures, figure) then return figure end
end

local function referTo(reply, figure)
    local reference = next(reply.references)
    return reference ~= nil and not next(reply.references, reference) and addon.GtaVI.genders[figure] == reference
end

local function conflicts(history, start, figure, reply)
    for i = start, #history do
        for _, evidence in ipairs(history[i].sentences) do
            for other in pairs(evidence.figures) do
                if evidence.usable and other ~= figure and referTo(reply, other) then return true end
            end
        end
    end
    return false
end

local function replyToHigh(history, reply)
    local candidate, newestMatch
    local matchedActions = {}
    for i = #history, 1, -1 do
        for _, evidence in ipairs(history[i].sentences) do
            local figure = evidence.high and onlyFigure(evidence)
            if figure and referTo(reply, figure) then
                local correction = reply.correction and reply.wordCount <= 7 and not next(reply.actions)
                    and overlaps(reply.verbs, evidence.verbs)
                if correction or overlaps(reply.actions, evidence.actions) then
                    if candidate and figure ~= candidate then return false end
                    candidate, newestMatch = figure, newestMatch or i
                    for kind in pairs(evidence.actions) do
                        if correction or reply.actions[kind] then matchedActions[kind] = true end
                    end
                end
            end
        end
    end
    local action = next(matchedActions)
    return action ~= nil and not next(matchedActions, action) and not conflicts(history, newestMatch, candidate, reply)
end

local function canJoinTopic(left, right, figure)
    for other in pairs(right.figures) do
        if other ~= figure then return false end
    end
    if overlaps(left.anchors, right.anchors) then return true end
    if not next(right.anchors) and not referTo(right, figure) then return false end
    return (left.hints.mission and right.hints.mission)
        or (left.hints.chapter and right.hints.chapter) or (left.hints.ending and right.hints.ending)
end

local function topicChain(history, sender, reply)
    if not next(reply.actions) or not storyHint(reply.hints) then return false end
    for i = 1, #history - 2 do
        local first = history[i]
        if first.sender ~= sender then
            for _, opening in ipairs(first.sentences) do
                local figure = opening.usable and onlyFigure(opening)
                if figure and referTo(reply, figure) and not conflicts(history, i, figure, reply) then
                    local secondSenders = {}
                    for j = i + 1, #history do
                        local line = history[j]
                        if line.sender ~= first.sender and line.sender ~= sender then
                            for _, evidence in ipairs(line.sentences) do
                                if evidence.usable and canJoinTopic(opening, evidence, figure) then
                                    for author in pairs(secondSenders) do
                                        if author ~= line.sender then return true end
                                    end
                                    secondSenders[line.sender] = true
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return false
end

local function prune(now)
    local oldestKey, oldestTime, count = nil, math.huge, 0
    for key, history in pairs(conversations) do
        local updated = history[#history].at
        if now - updated > MAX_AGE then
            conversations[key] = nil
        else
            count = count + 1
            if updated < oldestTime then oldestKey, oldestTime = key, updated end
        end
    end
    if count >= MAX_CONVERSATIONS then return oldestKey end
end

function addon.CheckContext(key, sender, now, evidence, level)
    local oldest = prune(now)
    local history = conversations[key]
    if not history then
        if oldest then conversations[oldest] = nil end
        history = {}
        conversations[key] = history
    end
    while history[1] and now - history[1].at > MAX_AGE do table.remove(history, 1) end

    local context = false
    if not level then
        for _, sentence in ipairs(evidence.sentences) do
            if sentence.usable and next(sentence.references)
                and (replyToHigh(history, sentence) or topicChain(history, sender, sentence)) then
                context = true
                break
            end
        end
    end

    history[#history + 1] = { at = now, sender = sender, sentences = context and {} or evidence.sentences }
    if #history > MAX_LINES then table.remove(history, 1) end
    return context
end
