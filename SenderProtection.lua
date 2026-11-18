local _, addon = ...

local STRIKE_WINDOW = 300
local MUTE_DURATION = 300
local MAX_SENDERS = 256
local history = {}

function addon.ClearSenderProtection(sender)
    if sender then
        history[sender] = nil
    else
        history = {}
    end
end

function addon.IsTemporarilyMuted(sender, now)
    local entry = history[sender]
    return entry ~= nil and entry.mutedUntil ~= nil and now < entry.mutedUntil
end

function addon.RecordHighSpoiler(sender, lineID, now, name, realm)
    local entry = history[sender]
    if entry and addon.IsTemporarilyMuted(sender, now) then return end
    if entry and not entry.mutedUntil and now - entry.firstAt <= STRIKE_WINDOW then
        if lineID ~= entry.firstLine then entry.mutedUntil = now + MUTE_DURATION end
        return
    end

    local count, oldestStrike, oldestTime = 0, nil, math.huge
    for key, other in pairs(history) do
        local expired = other.mutedUntil and now >= other.mutedUntil
            or not other.mutedUntil and now - other.firstAt > STRIKE_WINDOW
        if expired then
            history[key] = nil
        else
            count = count + 1
            if not other.mutedUntil and other.firstAt < oldestTime then
                oldestStrike, oldestTime = key, other.firstAt
            end
        end
    end
    if count >= MAX_SENDERS then
        if not oldestStrike then return end
        history[oldestStrike] = nil
    end
    history[sender] = { firstAt = now, firstLine = lineID, name = name, realm = realm }
end

function addon.SetManualSpoilerMute(settings, sender, name, realm, muted)
    if muted then
        settings.manualMutes[sender] = { name = name, realm = realm }
    else
        settings.manualMutes[sender] = nil
    end
    addon.ClearSenderProtection(sender)
end

function addon.GetMutedSenders(settings, now)
    local entries = {}
    local function entryFor(sender, data)
        local entry = entries[sender]
        if not entry then
            -- Older manual mutes stored only true under the normalized key.
            local name, realm = strsplit("-", sender, 2)
            if type(data) == "table" then name, realm = data.name or name, data.realm or realm end
            entry = { key = sender, name = name, realm = realm }
            entries[sender] = entry
        end
        return entry
    end
    for sender, data in pairs(settings.manualMutes) do
        if data then entryFor(sender, data).manual = true end
    end
    for sender, data in pairs(history) do
        if addon.IsTemporarilyMuted(sender, now) then
            entryFor(sender, data).expiresAt = data.mutedUntil
        end
    end
    local sorted = {}
    for _, entry in pairs(entries) do sorted[#sorted + 1] = entry end
    table.sort(sorted, function(a, b) return a.key < b.key end)
    return sorted
end
