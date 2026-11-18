local _, addon = ...

local PREFIX = "NBKAS1."
local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
local digits = {}
for i = 1, #alphabet do digits[alphabet:sub(i, i)] = i - 1 end

local MAX_MARKERS = 12
local MAX_EXCERPT_BYTES = 280
local MAX_EXPORT_BYTES = 6400
local categories = { missed = true, alias = true, phrase = true, context = true }
local levels = { [""] = true, Light = true, Medium = true, High = true, Context = true }
addon.MarkerLimits = { markers = MAX_MARKERS, excerpt = MAX_EXCERPT_BYTES, export = MAX_EXPORT_BYTES }

local function encode64(text)
    local result = {}
    local buffer, bits = 0, 0
    for i = 1, #text do
        buffer, bits = buffer * 256 + text:byte(i), bits + 8
        while bits >= 6 do
            bits = bits - 6
            local divisor = 2 ^ bits
            local value = math.floor(buffer / divisor) + 1
            result[#result + 1] = alphabet:sub(value, value)
            buffer = buffer % divisor
        end
    end
    if bits > 0 then
        local value = buffer * 2 ^ (6 - bits) + 1
        result[#result + 1] = alphabet:sub(value, value)
    end
    return table.concat(result)
end

local function decode64(text)
    if #text % 4 == 1 then return nil end
    local result = {}
    local buffer, bits = 0, 0
    for i = 1, #text do
        local value = digits[text:sub(i, i)]
        if value == nil then return nil end
        buffer, bits = buffer * 64 + value, bits + 6
        if bits >= 8 then
            bits = bits - 8
            local divisor = 2 ^ bits
            result[#result + 1] = string.char(math.floor(buffer / divisor))
            buffer = buffer % divisor
        end
    end
    if buffer ~= 0 then return nil end
    return table.concat(result)
end

local function validUtf8(text)
    local i = 1
    while i <= #text do
        local lead = text:byte(i)
        if lead < 128 then
            i = i + 1
        else
            if lead < 194 or lead > 244 then return false end
            local trailing = lead < 224 and 1 or (lead < 240 and 2 or 3)
            local firstMin = lead == 224 and 160 or (lead == 240 and 144 or 128)
            local firstMax = lead == 237 and 159 or (lead == 244 and 143 or 191)
            for offset = 1, trailing do
                local byte = text:byte(i + offset)
                local lo = offset == 1 and firstMin or 128
                local hi = offset == 1 and firstMax or 191
                if not byte or byte < lo or byte > hi then return false end
            end
            i = i + trailing + 1
        end
    end
    return true
end

function addon.IsValidMarker(marker)
    return type(marker) == "table" and type(marker.profile) == "string"
        and #marker.profile <= 20 and marker.profile:match("^[a-z0-9%-]+$") ~= nil
        and type(marker.profileVersion) == "number" and marker.profileVersion >= 1
        and marker.profileVersion <= 999 and marker.profileVersion % 1 == 0
        and categories[marker.category] == true and levels[marker.level] == true
        and type(marker.excerpt) == "string" and #marker.excerpt <= MAX_EXCERPT_BYTES
        and marker.excerpt:find("[^ \t\n\r]") ~= nil
        and not marker.excerpt:find("[%z\1-\8\11\12\14-\31\127]")
        and validUtf8(marker.excerpt)
end

local function pack(value)
    return #value .. ":" .. value
end

function addon.EncodeMarkerExport(markers, addonVersion)
    if #markers == 0 or #markers > MAX_MARKERS then return nil end
    if type(addonVersion) ~= "string" or #addonVersion > 24 or not addonVersion:match("^[%w.%-]+$") then return nil end
    local fields = { pack(addonVersion) }
    for _, marker in ipairs(markers) do
        if not addon.IsValidMarker(marker) then return nil end
        fields[#fields + 1] = pack(marker.profile) .. pack(tostring(marker.profileVersion))
            .. pack(marker.category) .. pack(marker.level) .. pack(marker.excerpt)
    end
    return PREFIX .. encode64(table.concat(fields))
end

function addon.DecodeMarkerExport(text)
    if type(text) ~= "string" or #text > MAX_EXPORT_BYTES then return nil end
    text = text:match("^[ \t\r\n]*(.-)[ \t\r\n]*$")
    if not text or text:sub(1, #PREFIX) ~= PREFIX then return nil end
    local payload = decode64(text:sub(#PREFIX + 1))
    if not payload then return nil end

    local cursor = 1
    local function readField()
        local _, lengthEnd, length = payload:find("^([0-9][0-9]?[0-9]?):", cursor)
        if not lengthEnd then return nil end
        local last = lengthEnd + tonumber(length)
        if last > #payload then return nil end
        cursor = last + 1
        return payload:sub(lengthEnd + 1, last)
    end

    local version = readField()
    if not version or #version > 24 or not version:match("^[%w.%-]+$") then return nil end
    local markers = {}
    while cursor <= #payload do
        if #markers >= MAX_MARKERS then return nil end
        local profile, profileVersion, category, level, excerpt = readField(), readField(), readField(), readField(), readField()
        if not profileVersion or not profileVersion:match("^[1-9][0-9]?[0-9]?$") then return nil end
        local marker = { profile = profile, profileVersion = tonumber(profileVersion), category = category, level = level, excerpt = excerpt }
        if not addon.IsValidMarker(marker) then return nil end
        markers[#markers + 1] = marker
    end
    if #markers == 0 then return nil end
    return { schema = 1, addonVersion = version, markers = markers }
end
