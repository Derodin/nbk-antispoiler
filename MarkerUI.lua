local addonName, addon = ...
local NBK = _G.NBK
local L = NBK.L
local limits = addon.MarkerLimits
local categories = {
    { key = "missed", label = L["AntiSpoiler: Missed spoiler"] },
    { key = "alias", label = L["AntiSpoiler: Name or spelling"] },
    { key = "phrase", label = L["AntiSpoiler: Critical phrase"] },
    { key = "context", label = L["AntiSpoiler: Context example"] },
}
local categoryLabels = {}
for _, category in ipairs(categories) do categoryLabels[category.key] = category.label end

local function display(text)
    return (text:gsub("|", "||"))
end

local function label(NUL, parent, text, y)
    local widget = NUL:CreateLabel(parent, { text = text, justifyH = "LEFT" })
    widget:SetPoint("TOPLEFT", 0, -y)
    widget:SetWidth(520)
    return widget
end

local function button(NUL, parent, title, x, y, width, onClick)
    local widget = NUL:Button(parent, { label = title, height = 26, width = width, onClick = onClick })
    widget:SetPoint("TOPLEFT", x, -y)
    return widget
end

local editor, linePicker, categoryPicker, draft, editorStatus, currentLine, currentCategory

local function chooseLine(line)
    currentLine = line
    currentCategory = line.level == "Context" and "context" or (line.level and "phrase" or "missed")
    categoryPicker:SetValue(currentCategory)
    draft:SetText("")
    editorStatus:SetText("")
end

local function createEditor()
    local NUL = LibStub("NerzorsUILib-1.0")
    editor = NUL:Window({ name = "NBKAntiSpoilerMarkerEditor", title = L["AntiSpoiler: Mark as spoiler"],
        width = 570, height = 365, strata = "DIALOG" })
    local content = editor.content
    label(NUL, content, L["AntiSpoiler: Select a line. Reveal its text when ready."], 0)
    linePicker = NUL:Dropdown(content, { width = 520, height = 25, onSelect = chooseLine })
    linePicker:SetPoint("TOPLEFT", 0, -25)
    categoryPicker = NUL:Dropdown(content, { width = 255, height = 25, options = categories,
        onSelect = function(category) currentCategory = category end })
    categoryPicker:SetPoint("TOPLEFT", 0, -60)
    button(NUL, content, L["AntiSpoiler: Reveal original"], 273, 59, 172, function()
        if currentLine then draft:SetText(display(currentLine.text)) end
    end)
    label(NUL, content, L["AntiSpoiler: Keep just the relevant excerpt. Remove names and private details."], 98)
    draft = NUL:EditBox(content, { multiline = true, width = 520, height = 115, maxLetters = 4096,
        placeholder = L["AntiSpoiler: Enter an excerpt or reveal the original"] })
    draft:SetPoint("TOPLEFT", 0, -125)
    button(NUL, content, L["AntiSpoiler: Save marker"], 0, 253, 170, function()
        local settings = addon.GetSettings()
        if not currentLine or not settings then return end
        local excerpt = draft:GetText():gsub("||", "|"):match("^[ \t\r\n]*(.-)[ \t\r\n]*$")
        local saved, reason = addon.SaveSpoilerMarker(settings, currentCategory, currentLine.level, excerpt)
        if saved then
            editor:Hide()
            NBK:Print(L["AntiSpoiler: Anti-Spoiler: Marker saved."])
        elseif reason == "full" then
            editorStatus:SetText(L["AntiSpoiler: List full. Delete a marker first."])
        else
            editorStatus:SetText(L["AntiSpoiler: Excerpt missing or too long (max. 280 bytes)."])
        end
    end)
    editorStatus = label(NUL, content, "", 288)
    editor:HookScript("OnHide", function()
        draft:SetText("")
        draft:ClearFocus()
        currentLine = nil
        linePicker:SetOptions({})
        linePicker:SetValue(nil)
    end)
end

function addon.ShowMarkerEditor(author, lineID)
    local lines, exact = addon.GetRecentMarkerLines(author, lineID, GetTime())
    if #lines == 0 then
        NBK:Print(L["AntiSpoiler: Anti-Spoiler: No recent chat line to mark."])
        return
    end
    if not editor then createEditor() end
    local options = {}
    for _, line in ipairs(lines) do
        options[#options + 1] = { key = line, label = display(("%s · %s · %s · #%s"):format(
            line.clock, line.sender, line.channel, line.lineID)) }
    end
    linePicker:SetOptions(options)
    if exact or #lines == 1 then
        local line = exact or lines[1]
        linePicker:SetValue(line)
        chooseLine(line)
    else
        linePicker:SetValue(nil)
        currentLine = nil
        categoryPicker:SetValue(nil)
        draft:SetText("")
        editorStatus:SetText(L["AntiSpoiler: Please choose the matching line."])
    end
    editor:Show()
end

local savedWindow, savedPicker, summary, output, outputLabel
local currentMarker, selected = nil, {}

local function clearOutput()
    output:SetText("")
    output:ClearFocus()
    outputLabel:SetText(L["AntiSpoiler: Copy field"])
end

local function refreshSaved()
    local markers = addon.GetSettings().markers
    local options, count, retained = {}, 0, false
    for index, marker in ipairs(markers) do
        if marker == currentMarker then retained = true end
        local included = selected[marker]
        if included then count = count + 1 end
        options[#options + 1] = { key = marker, label = ("%s #%d · %s · %s"):format(
            included and "[x]" or "[ ]", index, categoryLabels[marker.category] or "?", marker.level ~= "" and marker.level or "–") }
    end
    if not retained then currentMarker = markers[1] end
    savedPicker:SetOptions(options)
    savedPicker:SetValue(currentMarker)
    summary:SetText((L["AntiSpoiler: %d of %d markers selected for export"]):format(count, #markers))
end

local function createSavedWindow()
    local NUL = LibStub("NerzorsUILib-1.0")
    savedWindow = NUL:Window({ name = "NBKAntiSpoilerSavedMarkers", title = L["AntiSpoiler: My spoiler markers"],
        width = 570, height = 365, strata = "DIALOG" })
    local content = savedWindow.content
    summary = label(NUL, content, "", 0)
    savedPicker = NUL:Dropdown(content, { width = 520, height = 25, onSelect = function(marker)
        currentMarker = marker
        clearOutput()
    end })
    savedPicker:SetPoint("TOPLEFT", 0, -27)
    button(NUL, content, L["AntiSpoiler: Toggle selection"], 0, 63, 171, function()
        if not currentMarker then return end
        selected[currentMarker] = not selected[currentMarker] or nil
        clearOutput()
        refreshSaved()
    end)
    button(NUL, content, L["AntiSpoiler: Reveal excerpt"], 182, 63, 168, function()
        if not currentMarker then return end
        outputLabel:SetText(L["AntiSpoiler: Excerpt · contains spoilers"])
        output:SetText(display(currentMarker.excerpt))
        output:ClearFocus()
    end)
    button(NUL, content, L["AntiSpoiler: Delete marker"], 361, 63, 159, function()
        for index, marker in ipairs(addon.GetSettings().markers) do
            if marker == currentMarker then
                table.remove(addon.GetSettings().markers, index)
                selected[marker] = nil
                clearOutput()
                refreshSaved()
                return
            end
        end
    end)
    outputLabel = label(NUL, content, "", 112)
    output = NUL:EditBox(content, { multiline = true, width = 520, height = 122, maxLetters = limits.export })
    output:SetPoint("TOPLEFT", 0, -137)
    button(NUL, content, L["AntiSpoiler: Create export"], 0, 271, 170, function()
        local markers = {}
        for _, marker in ipairs(addon.GetSettings().markers) do
            if selected[marker] then markers[#markers + 1] = marker end
        end
        clearOutput()
        if #markers == 0 then
            outputLabel:SetText(L["AntiSpoiler: Select at least one marker."])
            return
        end
        local readVersion = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
        local version = readVersion and readVersion(addonName, "Version") or "unknown"
        local encoded = addon.EncodeMarkerExport(markers, version)
        if not encoded then
            outputLabel:SetText(L["AntiSpoiler: Could not create the export."])
            return
        end
        outputLabel:SetText(L["AntiSpoiler: Encoded export · press Ctrl+C to copy"])
        output:SetText(encoded)
        output:SetFocus()
        output.editBox:HighlightText()
    end)
    savedWindow:HookScript("OnHide", clearOutput)
end

function addon.ShowSavedMarkers()
    if not addon.GetSettings() then return end
    if not savedWindow then createSavedWindow() end
    clearOutput()
    refreshSaved()
    savedWindow:Show()
end
