local addonName, addon = ...

-- Create addon namespace
MidnightTracker = addon

-- Version info
addon.version = "1.0.0"
addon.name = "MidnightTracker"

-- Default saved variables
local defaults = {
	minimap = {
		hide = false,
		minimapPos = 225,
		lock = false,
	},
	display = {
		hidden = false,
		point = "TOPRIGHT",
		relativePoint = "TOPRIGHT",
		xOfs = -20,
		yOfs = -200,
		-- Appearance
		scale = 1.0,
		iconsPerRow = 3,
		iconSize = 18,
		showBorder = true,
		showBackground = true,
		backgroundOpacity = 0.8,
		-- Font
		fontSize = "normal", -- small, normal, large
		-- Spacing
		iconSpacing = 52,
	},
	settings = {
		showZeroCurrencies = false,
		showUndiscovered = false,
		filterByZone = false, -- Only show currencies relevant to current zone (off by default; toggle with /mtrack filter)
		-- Great Vault
		showGreatVault = true,
		showVaultRaid = true,
		showVaultMythicPlus = true,
		showVaultWorld = true,
		categories = {
			showMidnight = true,
			showWarWithin = true,
			showPvP = true,
			showDragonflight = true,
			showShadowlands = false,
			showBFA = false,
			showLegion = false,
			showWoD = false,
			showMoP = false,
			showCataclysm = false,
			showWotLK = false,
			showBC = false,
			showSeasonal = true,
		},
		currencies = {
			-- Individual currency tracking (currencyID = enabled)
			-- Empty by default, all enabled unless specified
		},
	},
}

-- Initialize saved variables with defaults
local function InitializeDefaults(target, defaults)
	for k, v in pairs(defaults) do
		if type(v) == "table" then
			if target[k] == nil then
				target[k] = {}
			end
			InitializeDefaults(target[k], v)
		elseif target[k] == nil then
			target[k] = v
		end
	end
end

-- Event frame
local eventFrame = CreateFrame("Frame")
addon.eventFrame = eventFrame

-- Event handlers
local eventHandlers = {}

-- PLAYER_LOGIN: Initialize addon when player logs in
eventHandlers.PLAYER_LOGIN = function()
	-- Initialize saved variables
	if not MidnightTrackerDB then
		MidnightTrackerDB = {}
	end
	InitializeDefaults(MidnightTrackerDB, defaults)
	addon.db = MidnightTrackerDB

	-- One-time settings repair: older saved configs hide all Midnight currencies
	-- (zone filter on with no Midnight zone detection, plus key currencies disabled).
	if not addon.db.settingsRepairV2 then
		addon.db.settings.filterByZone = false   -- zone detection has no Midnight maps yet
		wipe(addon.db.settings.currencies)        -- re-enable every individually-disabled currency
		addon.db.settingsRepairV2 = true
		print("|cff00ff00[MidnightTracker]|r Repaired display settings (zone filter off, all currencies re-enabled).")
	end

	-- Initialize tracker module
	if addon.Tracker and addon.Tracker.Initialize then
		addon.Tracker:Initialize()
	end

	-- Initialize minimap icon
	if addon.Minimap and addon.Minimap.Initialize then
		addon.Minimap:Initialize()
	end

	-- Initialize on-screen display
	if addon.Display and addon.Display.Initialize then
		addon.Display:Initialize()
	end

	-- Print welcome message
	print(format("|cff00ff00%s|r v%s loaded. Type /mtrack for commands.", addon.name, addon.version))
end

-- CURRENCY_DISPLAY_UPDATE: Fired when currency changes
eventHandlers.CURRENCY_DISPLAY_UPDATE = function(currencyID, quantity)
	-- Update cached currency data
	if addon.Tracker and addon.Tracker.OnCurrencyUpdate then
		addon.Tracker:OnCurrencyUpdate(currencyID, quantity)
	end
end

-- WEEKLY_REWARDS_UPDATE: weekly data changed (vault/reset/caps)
eventHandlers.WEEKLY_REWARDS_UPDATE = function()
	if addon.Tracker and addon.Tracker.UpdateAllCurrencies then
		addon.Tracker:UpdateAllCurrencies()
	end
end

-- PLAYER_MONEY: Fired when player money changes (in case we track gold)
eventHandlers.PLAYER_MONEY = function()
	-- Could update gold tracking here if needed
end

-- QUEST_LOG_UPDATE: Fired when quest log updates (for weekly quest tracking)
eventHandlers.QUEST_LOG_UPDATE = function()
	if addon.Tracker and addon.Tracker.OnQuestUpdate then
		addon.Tracker:OnQuestUpdate()
	end
end

-- Event dispatcher
eventFrame:SetScript("OnEvent", function(self, event, ...)
	if eventHandlers[event] then
		eventHandlers[event](...)
	end
end)

-- Register events
for event, _ in pairs(eventHandlers) do
	eventFrame:RegisterEvent(event)
end

-- Utility functions
addon.Utils = {}

-- Print function with addon prefix
function addon.Utils:Print(msg)
	print(format("|cff00ff00[%s]|r %s", addon.name, msg))
end

-- Debug print (only if debug mode enabled)
function addon.Utils:Debug(msg)
	if addon.db and addon.db.settings and addon.db.settings.debug then
		print(format("|cffff0000[%s Debug]|r %s", addon.name, msg))
	end
end

-- Format number with comma separators
function addon.Utils:FormatNumber(num)
	if not num then return "0" end
	local formatted = tostring(num)
	local k
	while true do
		formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
		if k == 0 then break end
	end
	return formatted
end

-- Get color code string
function addon.Utils:GetColorCode(r, g, b)
	return format("|cff%02x%02x%02x", r * 255, g * 255, b * 255)
end

-- Color text
function addon.Utils:ColorText(text, r, g, b)
	return format("%s%s|r", self:GetColorCode(r, g, b), text)
end

-- Slash commands
SLASH_MIDNIGHTTRACKER1 = "/midnighttracker"
SLASH_MIDNIGHTTRACKER2 = "/mtrack"
SLASH_MIDNIGHTTRACKER3 = "/mtk"

SlashCmdList["MIDNIGHTTRACKER"] = function(msg)
	msg = string.lower(msg or "")

	if msg == "show" then
		if addon.Display and addon.Display.Show then
			addon.Display:Show()
			addon.Utils:Print("Display shown.")
		end
	elseif msg == "hide" then
		if addon.Display and addon.Display.Hide then
			addon.Display:Hide()
			addon.Utils:Print("Display hidden.")
		end
	elseif msg == "toggle" then
		if addon.Display and addon.Display.Toggle then
			addon.Display:Toggle()
		end
	elseif msg == "minimap show" then
		if addon.Minimap and addon.Minimap.Show then
			addon.Minimap:Show()
			addon.Utils:Print("Minimap icon shown.")
		end
	elseif msg == "minimap hide" then
		if addon.Minimap and addon.Minimap.Hide then
			addon.Minimap:Hide()
			addon.Utils:Print("Minimap icon hidden.")
		end
	elseif msg == "reset" then
		addon.db.minimap.minimapPos = 225
		if addon.Minimap and addon.Minimap.UpdatePosition then
			addon.Minimap:UpdatePosition()
		end
		addon.Utils:Print("Minimap position reset.")
	elseif msg == "showzero" or msg == "show zero" then
		addon.db.settings.showZeroCurrencies = not addon.db.settings.showZeroCurrencies
		addon.Utils:Print(format("Show zero currencies: %s", addon.db.settings.showZeroCurrencies and "ON" or "OFF"))
		-- Force display update
		if addon.Display and addon.Display.UpdateDisplay then
			addon.Display:UpdateDisplay()
		end
	elseif msg == "filter" then
		addon.db.settings.filterByZone = not addon.db.settings.filterByZone
		addon.Utils:Print(format("Filter by zone: %s", addon.db.settings.filterByZone and "ON" or "OFF"))
		if addon.Display and addon.Display.UpdateDisplay then
			addon.Display:UpdateDisplay()
		end
	elseif msg == "fix" then
		-- One-shot recovery: undo every setting that can blank the display
		addon.db.settings.filterByZone = false
		addon.db.settings.showZeroCurrencies = true
		addon.db.settings.showGreatVault = true
		-- Re-enable every individually-disabled currency
		wipe(addon.db.settings.currencies)
		-- Enable all expansion categories
		for k in pairs(addon.db.settings.categories) do
			addon.db.settings.categories[k] = true
		end
		-- Restore a sane layout and make sure the frame is visible
		addon.db.display.iconsPerRow = 3
		addon.db.display.hidden = false
		if addon.Display and addon.Display.Show then
			addon.Display:Show()
		end
		if addon.Display and addon.Display.UpdateDisplay then
			addon.Display:UpdateDisplay()
		end
		addon.Utils:Print("Reset display settings: zone filter OFF, all currencies/categories enabled, show-zero ON. Use /mtrack trackables to see what's tracked.")
	elseif msg == "debug" then
		addon.db.settings.debug = not addon.db.settings.debug
		addon.Utils:Print(format("Debug mode: %s", addon.db.settings.debug and "ON" or "OFF"))
	elseif msg == "zone" or msg == "zoneinfo" then
		local mapID = C_Map.GetBestMapForUnit("player")
		local mapInfo = mapID and C_Map.GetMapInfo(mapID)
		local expansion = addon.Tracker and addon.Tracker:GetCurrentExpansion()
		addon.Utils:Print("Zone Debug Info:")
		print(format("  Map ID: %s", tostring(mapID)))
		print(format("  Map Name: %s", mapInfo and mapInfo.name or "Unknown"))
		print(format("  Detected Expansion: %s", tostring(expansion)))
		print(format("  Filter Enabled: %s", addon.db.settings.filterByZone and "Yes" or "No"))
	elseif msg == "currency" or msg == "crests" then
		addon.Utils:Print("Crest raw API data (qty | maxQty | maxWeekly | earnedWeek | totalEarnedCap | discovered):")
		local crests = {
			3442, 3443, 3444, 3445, 3446,   -- Midnight Mistcrests (Season 2)
			3285, 3287, 3289, 3291,         -- War Within Ethereal Crests
		}
		for _, id in ipairs(crests) do
			local info = C_CurrencyInfo.GetCurrencyInfo(id)
			if info then
				print(format("  [%d] %s: q=%s max=%s wMax=%s earnW=%s totalCap=%s disc=%s",
					id, tostring(info.name),
					tostring(info.quantity),
					tostring(info.maxQuantity),
					tostring(info.maxWeeklyQuantity),
					tostring(info.quantityEarnedThisWeek),
					tostring(info.useTotalEarnedForMaxQty),
					tostring(info.discovered)))
			else
				print(format("  [%d] Not found", id))
			end
		end
	elseif msg == "scancrests" then
		addon.Utils:Print("Scanning currency IDs 3200-3500 for crests (id = real name):")
		for id = 3200, 3500 do
			local info = C_CurrencyInfo.GetCurrencyInfo(id)
			if info and info.name and info.name:lower():find("crest") then
				print(format("  [%d] %s (q=%s)", id, info.name, tostring(info.quantity)))
			end
		end
		addon.Utils:Print("Scan complete.")
	elseif string.sub(msg, 1, 5) == "scan " then
		local keyword = string.lower(string.sub(msg, 6))
		addon.Utils:Print(format("Scanning currency IDs 1500-4000 for '%s' (id = real name):", keyword))
		for id = 1500, 4000 do
			local info = C_CurrencyInfo.GetCurrencyInfo(id)
			if info and info.name and info.name:lower():find(keyword) then
				print(format("  [%d] %s (q=%s max=%s wMax=%s totalCap=%s disc=%s)",
					id, info.name, tostring(info.quantity), tostring(info.maxQuantity),
					tostring(info.maxWeeklyQuantity), tostring(info.useTotalEarnedForMaxQty), tostring(info.discovered)))
			end
		end
		addon.Utils:Print("Scan complete.")
	elseif msg == "trackables" or msg == "display" then
		addon.Utils:Print("Currencies being tracked for display:")
		local data = addon.Tracker:GetAllTrackables()
		if data.categories then
			for _, category in ipairs(data.categories) do
				print(format("Category: %s (%d currencies)", category.name, #category.currencies))
				for _, curr in ipairs(category.currencies) do
					print(format("  [%d] %s: %d", curr.id, curr.name, curr.amount))
				end
			end
		else
			print("  No categories found")
		end
	elseif msg == "showall" or msg == "enableall" then
		addon.Utils:Print("Enabling all expansion categories...")
		addon.db.settings.categories.showMidnight = true
		addon.db.settings.categories.showWarWithin = true
		addon.db.settings.categories.showPvP = true
		addon.db.settings.categories.showDragonflight = true
		addon.db.settings.categories.showShadowlands = true
		addon.db.settings.categories.showBFA = true
		addon.db.settings.categories.showLegion = true
		addon.db.settings.categories.showWoD = true
		addon.db.settings.categories.showMoP = true
		addon.db.settings.categories.showCataclysm = true
		addon.db.settings.categories.showWotLK = true
		addon.db.settings.categories.showBC = true
		addon.db.settings.categories.showSeasonal = true
		addon.Utils:Print("All categories enabled!")
		if addon.Display then
			addon.Display:UpdateDisplay()
		end
	elseif msg == "categories" or msg == "cats" then
		addon.Utils:Print("Category Status:")
		local cats = {
			{"Midnight", "showMidnight"},
			{"War Within", "showWarWithin"},
			{"PvP", "showPvP"},
			{"Dragonflight", "showDragonflight"},
			{"Shadowlands", "showShadowlands"},
			{"BfA", "showBFA"},
			{"Legion", "showLegion"},
			{"WoD", "showWoD"},
			{"MoP", "showMoP"},
			{"Cataclysm", "showCataclysm"},
			{"WotLK", "showWotLK"},
			{"BC", "showBC"},
			{"Seasonal", "showSeasonal"},
		}
		for _, cat in ipairs(cats) do
			local enabled = addon.db.settings.categories[cat[2]]
			local status = enabled and "ENABLED" or "DISABLED"
			print(format("  %s: %s", cat[1], status))
		end
		print(" ")
		print(format("Show Zero Currencies: %s", addon.db.settings.showZeroCurrencies and "ON" or "OFF"))
		print(format("Filter by Zone: %s", addon.db.settings.filterByZone and "ON" or "OFF"))
	elseif msg == "config" or msg == "options" then
		if addon.Config and addon.Config.Toggle then
			addon.Config:Toggle()
		end
	else
		addon.Utils:Print("Commands:")
		print("  /mtrack show - Show on-screen display")
		print("  /mtrack hide - Hide on-screen display")
		print("  /mtrack toggle - Toggle on-screen display")
		print("  /mtrack showzero - Toggle showing currencies with 0 amount")
		print("  /mtrack filter - Toggle filtering currencies by current zone")
		print("  /mtrack fix - Reset settings that can blank the display")
		print("  /mtrack minimap show - Show minimap icon")
		print("  /mtrack minimap hide - Hide minimap icon")
		print("  /mtrack reset - Reset minimap icon position")
		print("  /mtrack debug - Toggle debug mode")
		print("  /mtrack zone - Show zone detection info")
		print("  /mtrack currency - Check crest discovery status")
		print("  /mtrack trackables - Show what's being displayed")
		print("  /mtrack categories - Show enabled/disabled categories")
		print("  /mtrack showall - Enable all expansion categories")
		print("  /mtrack config - Open configuration panel")
		print(" ")
		print("Short commands: /mtk or /midnighttracker also work")
	end
end
