local _, addon = ...
local NBK = _G.NBK
local L = NBK.L
local window, list, status

local function reasonFor(entry, now)
    if entry.manual then
        return L["AntiSpoiler: Manually hidden · persistent"]
    end
    local seconds = math.max(0, math.ceil(entry.expiresAt - now))
    return (L["AntiSpoiler: Multiple High matches · %d:%02d remaining"])
        :format(math.floor(seconds / 60), seconds % 60)
end

function addon.BlacklistMutedSender(entry)
    if NBK:IsBlacklisted(entry.name, entry.realm) then return true end
    local reason = entry.manual and (L["AntiSpoiler: Anti-Spoiler: manually muted"])
        or (L["AntiSpoiler: Anti-Spoiler: multiple High matches"])
    local added, failure = NBK:AddPlayer(entry.name, entry.realm, reason)
    if not added then
        NBK:Print((L["AntiSpoiler: Anti-Spoiler: could not add NBK entry (%s)."])
            :format(tostring(failure)))
        return false
    end
    local contextMenu = NBK:GetModule("ContextMenu")
    if contextMenu and contextMenu.RefreshListWindow then contextMenu:RefreshListWindow() end
    return true
end

local function refresh()
    local settings = addon.GetSettings()
    if not settings then return end
    local entries = addon.GetMutedSenders(settings, GetTime())
    local mode = L["AntiSpoiler: Protection active"]
    if not settings.active or settings.observe then mode = L["AntiSpoiler: Protection paused"] end
    status:SetText((L["AntiSpoiler: %s · %d muted players"]):format(mode, #entries))
    list:SetData(entries)
end

function addon.ShowMutedPlayers()
    if not window then
        local NUL = LibStub("NerzorsUILib-1.0")
        window = NUL:Window({ name = "NBKAntiSpoilerMutedPlayers", title = L["AntiSpoiler: Muted players"],
            width = 690, height = 390, strata = "DIALOG" })
        status = NUL:CreateLabel(window.content, { text = "", justifyH = "LEFT" })
        status:SetPoint("TOPLEFT", 0, 0)
        list = NUL:ScrollList(window.content, {
            rowHeight = 56,
            emptyText = L["AntiSpoiler: No muted players"],
            rowBuilder = function(row)
                local name = NUL:CreateLabel(row, { text = "", wrap = false, justifyH = "LEFT" })
                name:SetPoint("TOPLEFT", 8, -8)
                name:SetPoint("TOPRIGHT", row, "TOPRIGHT", -255, -8)
                local reason = NUL:CreateLabel(row, { text = "", size = "sm", wrap = false, justifyH = "LEFT" })
                reason:SetPoint("TOPLEFT", row, "TOPLEFT", 8, -31)
                reason:SetPoint("TOPRIGHT", row, "TOPRIGHT", -255, -31)
                local release = NUL:Button(row, {
                    label = L["AntiSpoiler: Unmute"], width = 95, height = 25, fit = false,
                    onClick = function()
                        local entry = row.mutedSender
                        addon.SetManualSpoilerMute(addon.GetSettings(), entry.key, entry.name, entry.realm, false)
                        refresh()
                    end,
                })
                release:SetPoint("RIGHT", -143, 0)
                local blacklist = NUL:Button(row, {
                    width = 132, height = 25, fit = false,
                    onClick = function()
                        addon.BlacklistMutedSender(row.mutedSender)
                        refresh()
                    end,
                })
                blacklist:SetPoint("RIGHT", -5, 0)
                return function(_, entry)
                    row.mutedSender = entry
                    local displayName = NBK:DisplayName(entry.name, entry.realm)
                    name:SetText((displayName:gsub("|", "||")))
                    reason:SetText(reasonFor(entry, GetTime()))
                    local alreadyAdded = NBK:IsBlacklisted(entry.name, entry.realm)
                    blacklist.label:SetText(alreadyAdded and (L["AntiSpoiler: Already in NBK"])
                        or (L["AntiSpoiler: Add to NBK"]))
                    blacklist:SetEnabled(not alreadyAdded)
                end
            end,
        })
        list.container:SetPoint("TOPLEFT", window.content, "TOPLEFT", 0, -30)
        list.container:SetPoint("BOTTOMRIGHT", window.content, "BOTTOMRIGHT", 0, 0)
        local elapsed = 0
        window:HookScript("OnShow", refresh)
        window:HookScript("OnUpdate", function(_, delta)
            elapsed = elapsed + delta
            if elapsed >= 1 then
                elapsed = 0
                refresh()
            end
        end)
    end
    window:Show()
    refresh()
end
