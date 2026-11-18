local _, addon = ...
local profile = addon.GtaVI
if not profile then return end

local function tokenize(text)
    local tokens = {}
    for token in text:gmatch("[a-z0-9$\128-\255]+") do
        tokens[#tokens + 1] = token
    end
    return tokens
end

local function normalize(text)
    return (addon.NormalizeChatText(text):gsub("’", "'"):gsub("‘", "'")
        :gsub("[\r\n]", " "):gsub("„", '"'):gsub("“", '"'):gsub("”", '"')
        :gsub("«", '"'):gsub("»", '"'):gsub("¿", " "):gsub("¡", " "):gsub("…", "."))
end

local function indexRules(rules)
    local index = {}
    for _, rule in ipairs(rules) do
        for i = 3, #rule do
            local tokens = tokenize(normalize(rule[i]))
            local first = tokens[1]
            index[first] = index[first] or {}
            local options = index[first]
            options[#options + 1] = { kind = rule[1], id = rule[2], tokens = tokens }
        end
    end
    for _, options in pairs(index) do
        table.sort(options, function(a, b) return #a.tokens > #b.tokens end)
    end
    return index
end

local function longestRule(index, tokens, start)
    local options = index[tokens[start]]
    if not options then return nil end
    for _, rule in ipairs(options) do
        local matched = true
        for offset = 2, #rule.tokens do
            if tokens[start + offset - 1] ~= rule.tokens[offset] then
                matched = false
                break
            end
        end
        if matched then return rule end
    end
end

local function missionDeath(tokens, start)
    if tokens[start] ~= "geht" or tokens[start + 1] ~= "in" then return false end
    local mission = start + 2
    local article = tokens[mission]
    if article == "der" or article == "dieser" or article == "einer" then mission = mission + 1 end
    if tokens[mission] ~= "mission" and tokens[mission] ~= "mision" then return false end
    for i = mission + 1, math.min(mission + 5, #tokens) do
        if tokens[i] == "drauf" then return true end
    end
    return false
end

local function countEntries(entries)
    local count = 0
    for _ in pairs(entries) do count = count + 1 end
    return count
end

local function classifySentence(index, sentence, isQuestion)
    local tokens = tokenize(sentence)
    local anchors, hints, aliases, weak = {}, {}, {}, {}
    local details = { figures = {}, anchors = anchors, hints = hints, actions = {}, verbs = {}, references = {} }
    details.wordCount = #tokens
    for _, token in ipairs(tokens) do
        local reference = addon.GtaVI.references[token]
        if reference then details.references[reference] = true end
        local verb = addon.GtaVI.verbs[token]
        if verb then details.verbs[verb] = true end
        if addon.GtaVI.corrections[token] then details.correction = true end
    end
    local critical, direct, wow, maybe, explicitTopic = false, false, false, isQuestion, false
    local afterFigure
    local position = 1
    while position <= #tokens do
        if missionDeath(tokens, position) then
            critical = true
            details.actions.death = true
        end
        local rule = longestRule(index, tokens, position)
        if rule then
            local kind = rule.kind
            if kind == "figure" or kind == "place" or kind == "topic" then
                anchors[rule.id] = true
                if kind == "figure" then
                    afterFigure = position + #rule.tokens
                    details.figures[rule.id] = true
                end
                if kind == "topic" then explicitTopic = true end
            elseif kind == "hint" then
                hints[rule.id] = true
            elseif kind == "alias" then
                aliases[rule.id] = true
            elseif kind == "weak" then
                weak[rule.id] = true
            elseif kind == "event" or kind == "action" then
                critical = true
                details.actions[rule.id] = true
                if kind == "event" and afterFigure == position then direct = true end
            elseif kind == "wow" then
                wow = true
            elseif kind == "maybe" then
                maybe = true
            end
            position = position + #rule.tokens
        else
            position = position + 1
        end
    end

    if wow and not explicitTopic then return details end
    if next(anchors) then
        for id in pairs(weak) do
            anchors[id] = true
            if addon.GtaVI.genders[id] then details.figures[id] = true end
        end
    end
    if next(anchors) or next(hints) then
        for id in pairs(aliases) do
            anchors[id] = true
            details.figures[id] = true
        end
    end
    details.usable = true
    if next(anchors) then
        details.count = countEntries(anchors) + countEntries(hints)
        details.high = critical and not maybe and (details.count >= 2 or direct)
    end
    return details
end

local index = indexRules(profile.rules)

function addon.ClassifySpoiler(text)
    local combined = {}
    local details = { sentences = {} }
    local highCount
    text = normalize(text)
    for sentence, punctuation in text:gmatch("([^.!?;]+)([.!?;]*)") do
        local evidence = classifySentence(index, sentence, punctuation:find("?", 1, true) ~= nil)
        details.sentences[#details.sentences + 1] = evidence
        if evidence.high and not highCount then highCount = evidence.count end
        if evidence.count then
            for id in pairs(evidence.anchors) do combined[id] = true end
            for id in pairs(evidence.hints) do combined[id] = true end
        end
    end
    if highCount then return "High", highCount, details end
    local count = countEntries(combined)
    if count >= 2 then return "Medium", count, details end
    if count == 1 then return "Light", count, details end
    return nil, nil, details
end
