-- Minimap.lua
-- LvlHistory — Bouton minimap
-- Clic gauche : toggle fenêtre principale
-- Clic droit  : menu contextuel (debug, reset, hide button)
-- Draggable autour de la minimap
-- Auteur : Tibizcui | Famille : TibiSuite

LvlHistory.Minimap = LvlHistory.Minimap or {}
local MM = LvlHistory.Minimap
LvlHistory.L = LvlHistory.L or {}
local L = LvlHistory.L
local function Loc(key, default) return L[key] or default end

-- ─────────────────────────────────────────────
-- Constantes
-- ─────────────────────────────────────────────
local BUTTON_SIZE   = 32
local DEFAULT_ANGLE = 220

-- ─────────────────────────────────────────────
-- Construction du bouton : socle v23 (UI.MinimapButton, audit poids
-- 2026-11-13, lot 5), style "tracker". Nom, angle sauvegarde
-- (LvlHistoryDB.settings.minimapAngle), infobulle et menu contextuel
-- inchanges ; le socle gere position, glisser, zoom et collecteurs.
-- ─────────────────────────────────────────────

local minimapButton

local function BuildButton()
    local UIm = _G.TibiMidnight
    if not (UIm and UIm.MinimapButton) then return end
    minimapButton = UIm.MinimapButton({
        name = "LvlHistoryMinimapButton", style = "tracker", default = DEFAULT_ANGLE,
        icon = "Interface\\AddOns\\LvlHistory\\Media\\icon",
        getAngle = function()
            return LvlHistoryDB and LvlHistoryDB.settings and LvlHistoryDB.settings.minimapAngle
        end,
        setAngle = function(a)
            if LvlHistoryDB and LvlHistoryDB.settings then LvlHistoryDB.settings.minimapAngle = a end
        end,
        onClick = function(button, self)
            if button == "LeftButton" then
                LvlHistory.UI.Toggle()
            elseif button == "RightButton" then
                MM.ShowContextMenu(self)
            end
        end,
        tooltip = function(tt)
            tt:AddLine(LvlHistory.Utils.Colorize("LvlHistory", "5EE223"))
            tt:AddLine(" ")
            local db = LvlHistory.db
            if db then
                tt:AddDoubleLine(Loc("TT_MODE", "Mode"),
                    LvlHistory.Utils.ModeLabel(db.mode), 0.7, 0.7, 0.7, 1, 1, 1)
                tt:AddDoubleLine(Loc("TT_LEVEL", "Niveau"),
                    tostring(db.level or UnitLevel("player")), 0.7, 0.7, 0.7, 1, 1, 1)
                if db.mode == "leveling" then
                    tt:AddDoubleLine("XP/h",
                        LvlHistory.Utils.FormatXPH(db.session.xph), 0.7, 0.7, 0.7, 1, 1, 1)
                else
                    tt:AddDoubleLine(Loc("TT_GOLDH", "Or/h"),
                        LvlHistory.Utils.FormatGold(db.farming.goldPerHour, true),
                        0.7, 0.7, 0.7, 1, 1, 1)
                end
                local elapsed = time() - (db.session.startTime or time())
                tt:AddDoubleLine(Loc("TT_SESSION", "Session"),
                    LvlHistory.Utils.FormatTime(elapsed, true), 0.7, 0.7, 0.7, 1, 1, 1)
            end
            tt:AddLine(" ")
            tt:AddLine("|cFFFFD700" .. Loc("TT_LEFTCLICK", "Clic gauche") .. "|r : " .. Loc("TT_TOGGLE", "Ouvrir/Fermer"), 0.7, 0.7, 0.7)
            tt:AddLine("|cFFFFD700" .. Loc("TT_RIGHTCLICK", "Clic droit") .. "|r  : " .. Loc("TT_OPTIONS", "Options"),       0.7, 0.7, 0.7)
            tt:AddLine("|cFFFFD700" .. Loc("TT_DRAG", "Glisser") .. "|r     : " .. Loc("TT_REPOSITION", "Repositionner"), 0.7, 0.7, 0.7)
        end,
    })
end

-- ─────────────────────────────────────────────
-- Menu contextuel (clic droit)
-- ─────────────────────────────────────────────

local contextMenu

function MM.ShowContextMenu(anchor)
    if not contextMenu then
        contextMenu = CreateFrame("Frame", "LvlHistoryContextMenu", UIParent, "UIDropDownMenuTemplate")
    end

    local menuList = {
        {
            text         = LvlHistory.Utils.Colorize("LvlHistory", "5EE223"),
            isTitle      = true,
            notCheckable = true,
        },
        {
            text         = Loc("MENU_TOGGLE", "Ouvrir / Fermer"),
            notCheckable = true,
            func         = function() LvlHistory.UI.Toggle() end,
        },
        {
            text         = Loc("MENU_DEBUG", "Debug") .. " : " .. (LvlHistory.debug and "|cff2ECC71ON|r" or "|cffFF4444OFF|r"),
            notCheckable = true,
            func         = function()
                LvlHistory.debug = not LvlHistory.debug
                if LvlHistoryDB and LvlHistoryDB.settings then
                    LvlHistoryDB.settings.debug = LvlHistory.debug
                end
                if CloseDropDownMenus then CloseDropDownMenus() end
            end,
        },
        {
            text         = Loc("MENU_HIDE_BUTTON", "Masquer le bouton"),
            notCheckable = true,
            func         = function()
                MM.Hide()
                if LvlHistoryDB and LvlHistoryDB.settings then
                    LvlHistoryDB.settings.minimapButton = false
                end
                if CloseDropDownMenus then CloseDropDownMenus() end
                LvlHistory.Utils.Log(Loc("BUTTON_HIDDEN_LOG", "Bouton masqué - /lvlh minimap pour réafficher"))
            end,
        },
        { text = " ", notCheckable = true, disabled = true },
        {
            text         = "|cffFF4444" .. Loc("MENU_RESET_CHAR", "Réinitialiser ce perso") .. "|r",
            notCheckable = true,
            func         = function()
                if CloseDropDownMenus then CloseDropDownMenus() end
                print(LvlHistory.Utils.Colorize("[LvlHistory]", "5EE223")
                    .. " " .. Loc("RESET_CONFIRM_HINT", "Tapez |cffFFFFFF/lvlh reset confirm|r pour confirmer."))
            end,
        },
    }

    -- EasyMenu a disparu en 11.0 : menu natif MenuUtil, EasyMenu en repli
    if MenuUtil and MenuUtil.CreateContextMenu then
        MenuUtil.CreateContextMenu(anchor, function(_, root)
            for _, item in ipairs(menuList) do
                if item.isTitle then
                    root:CreateTitle(item.text)
                elseif item.disabled then
                    root:CreateDivider()
                else
                    root:CreateButton(item.text, function() item.func() end)
                end
            end
        end)
    elseif EasyMenu then
        EasyMenu(menuList, contextMenu, anchor, 0, 0, "MENU")
    end
end

-- ─────────────────────────────────────────────
-- API publique
-- ─────────────────────────────────────────────

function MM.Show()
    if not minimapButton then BuildButton() end
    if minimapButton then minimapButton:Show() end
end

function MM.Hide()
    if minimapButton then minimapButton:Hide() end
end

function MM.Toggle()
    if not minimapButton then
        MM.Show()
        return
    end
    if minimapButton:IsShown() then
        MM.Hide()
    else
        MM.Show()
    end
end

function MM.IsShown()
    return minimapButton and minimapButton:IsShown() or false
end

--- Appelé par Core.lua après PLAYER_LOGIN
function MM.Init()
    local show = true
    if LvlHistoryDB and LvlHistoryDB.settings then
        show = LvlHistoryDB.settings.minimapButton ~= false
    end
    if show then MM.Show() end
end
