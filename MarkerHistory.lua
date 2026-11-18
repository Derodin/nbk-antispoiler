local _, addon = ...

local MAX_RECENT = 64
local RECENT_SECONDS = 120
local recent = {}

local function prune(now)
    while #recent > 0 and now - recent[#recent].at > RECENT_SECONDS do table.remove(recent) end
end

function addon.ClearRecentMarkerLines()
    recent = {}
end

function addon.RememberMarkerLine(author, sender, event, lineID, channel, level, text, now)
    if #text > 4096 then return end
    prune(now)
    for _, line in ipairs(recent) do
        if line.event == event and line.lineID == lineID then return end
    end
    table.insert(recent, 1, {
        author = author, sender = sender, event = event, lineID = lineID, channel = channel,
        level = level, text = addon.PlainMarkerText(text), at = now, clock = date("%H:%M:%S"),
    })
    if #recent > MAX_RECENT then table.remove(recent) end
end

function addon.GetRecentMarkerLines(author, lineID, now)
    prune(now)
    local matches, selected, ambiguous = {}, nil, false
    for _, line in ipairs(recent) do
        if not author or line.author == author then
            if #matches < addon.MarkerLimits.markers then matches[#matches + 1] = line end
            if lineID and line.lineID == lineID then
                if selected then ambiguous = true else selected = line end
            end
        end
    end
    if ambiguous then selected = nil end
    if selected then
        for _, line in ipairs(matches) do
            if line == selected then return matches, selected end
        end
        matches[#matches] = selected
    end
    return matches, selected
end

function addon.SaveSpoilerMarker(settings, category, level, excerpt)
    local markers = settings.markers
    if #markers >= addon.MarkerLimits.markers then return false, "full" end
    local marker = {
        profile = addon.GtaVI.id, profileVersion = addon.GtaVI.version,
        category = category, level = level or "", excerpt = excerpt,
    }
    if not addon.IsValidMarker(marker) then return false, "invalid" end
    table.insert(markers, 1, marker)
    return true
end
