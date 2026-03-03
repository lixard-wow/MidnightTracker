local addonName, addon = ...

-- Create addon namespace
MidnightTracker = addon

-- Version info
addon.version = "2.0.0"
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
		scale = 1.0,
		iconsPerRow = 3,
		iconSize = 18,
		showBorder = true,
		showBackground = true,
		backgroundOpacity = 0.8,
		fontSize = "normal",
		iconSpacing = 52,
	},
	settings = {
		showZeroCurrencies = false,
		showUndiscovered = false,
		filterByZone = true,
		abbreviateNumbers = true,
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
		currencies = {},
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

eventHandlers.PLAYER_LOGIN = function()
	if not MidnightTrackerDB then
		MidnightTrackerDB = {}
	end
	InitializeDefaults(MidnightTrackerDB, defaults)
	addon.db = MidnightTrackerDB

	-- Clean out old saved variable keys from previous version
	addon.db.upgrades = nil
	addon.db.alts = nil

	if addon.Tracker and addon.Tracker.Initialize then
		addon.Tracker:Initialize()
	end

	if addon.Minimap and addon.Minimap.Initialize then
		addon.Minimap:Initialize()
	end

	if addon.Display and addon.Display.Initialize then
		addon.Display:Initialize()
	end

	print(format("|cff00ff00%s|r v%s loaded. Type /mtrack for commands.", addon.name, addon.version))
end

eventHandlers.CURRENCY_DISPLAY_UPDATE = function(currencyID, quantity)
	if addon.Tracker and addon.Tracker.OnCurrencyUpdate then
		addon.Tracker:OnCurrencyUpdate(currencyID, quantity)
	end
end

eventHandlers.PLAYER_UPDATE_RESTING = function()
	if addon.Display and addon.Display.UpdateCityVisibility then
		addon.Display:UpdateCityVisibility()
	end
end

-- Event dispatcher
eventFrame:SetScript("OnEvent", function(self, event, ...)
	if eventHandlers[event] then
		eventHandlers[event](...)
	end
end)

for event, _ in pairs(eventHandlers) do
	eventFrame:RegisterEvent(event)
end

-- Utility functions
addon.Utils = {}

function addon.Utils:Print(msg)
	print(format("|cff00ff00[%s]|r %s", addon.name, msg))
end

function addon.Utils:Debug(msg)
	if addon.db and addon.db.settings and addon.db.settings.debug then
		print(format("|cffff0000[%s Debug]|r %s", addon.name, msg))
	end
end

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

function addon.Utils:AbbreviateNumber(num)
	if not num then return "0" end

	if addon.db and addon.db.settings and addon.db.settings.abbreviateNumbers == false then
		return tostring(num)
	end

	if num >= 1000000 then
		return format("%.1fM", num / 1000000)
	elseif num >= 1000 then
		return format("%.1fK", num / 1000)
	else
		return tostring(num)
	end
end

function addon.Utils:FormatAmount(num)
	if not num then return "0" end

	if addon.db and addon.db.settings and addon.db.settings.abbreviateNumbers ~= false then
		return self:AbbreviateNumber(num)
	else
		return self:FormatNumber(num)
	end
end

function addon.Utils:GetColorCode(r, g, b)
	return format("|cff%02x%02x%02x", r * 255, g * 255, b * 255)
end

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
	elseif msg == "showzero" or msg == "hidezero" then
		addon.db.settings.showZeroCurrencies = not addon.db.settings.showZeroCurrencies
		local status = addon.db.settings.showZeroCurrencies and "Showing all currencies (including 0)" or "Hiding currencies with 0 count"
		addon.Utils:Print(status)
		if addon.Display and addon.Display.UpdateDisplay then
			addon.Display:UpdateDisplay()
		end
	elseif msg == "abbreviate" or msg == "abbrev" then
		addon.db.settings.abbreviateNumbers = not addon.db.settings.abbreviateNumbers
		addon.Utils:Print(format("Abbreviate numbers: %s", addon.db.settings.abbreviateNumbers and "ON (1.5M)" or "OFF (1,500,000)"))
		if addon.Display and addon.Display.UpdateDisplay then
			addon.Display:UpdateDisplay()
		end
	elseif msg == "debug" then
		addon.db.settings.debug = not addon.db.settings.debug
		addon.Utils:Print(format("Debug mode: %s", addon.db.settings.debug and "ON" or "OFF"))
	elseif msg == "zone" then
		local mapID = C_Map.GetBestMapForUnit("player")
		local mapInfo = mapID and C_Map.GetMapInfo(mapID)
		local expansion = addon.Tracker and addon.Tracker:GetCurrentExpansion()
		addon.Utils:Print("Zone Debug Info:")
		print(format("  Map ID: %s", tostring(mapID)))
		print(format("  Map Name: %s", mapInfo and mapInfo.name or "Unknown"))
		print(format("  Detected Expansion: %s", tostring(expansion)))
		print(format("  Filter Enabled: %s", addon.db.settings.filterByZone and "Yes" or "No"))
	elseif msg == "trackables" or msg == "display" then
		addon.Utils:Print("Currencies being tracked:")
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
		for key, _ in pairs(addon.db.settings.categories) do
			addon.db.settings.categories[key] = true
		end
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
		print(format("  Show Zero: %s", addon.db.settings.showZeroCurrencies and "ON" or "OFF"))
		print(format("  Filter by Zone: %s", addon.db.settings.filterByZone and "ON" or "OFF"))
	elseif msg == "config" or msg == "options" then
		if addon.Config and addon.Config.Toggle then
			addon.Config:Toggle()
		end
	else
		addon.Utils:Print("Commands:")
		print("  /mtrack show - Show currency display")
		print("  /mtrack hide - Hide currency display")
		print("  /mtrack toggle - Toggle currency display")
		print("  /mtrack showzero - Toggle showing currencies with 0 count")
		print("  /mtrack abbreviate - Toggle number abbreviation")
		print("  /mtrack minimap show - Show minimap icon")
		print("  /mtrack minimap hide - Hide minimap icon")
		print("  /mtrack reset - Reset minimap icon position")
		print("  /mtrack categories - Show enabled/disabled categories")
		print("  /mtrack showall - Enable all expansion categories")
		print("  /mtrack trackables - Show what's being displayed")
		print("  /mtrack zone - Show zone detection info")
		print("  /mtrack config - Open settings panel")
		print("  /mtrack debug - Toggle debug mode")
	end
end
