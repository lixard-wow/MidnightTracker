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
		-- NEW: View mode and layout
		viewMode = "current", -- "current" or "alts"
		showChecklist = false, -- Hidden by default, toggle with /mtrack checklist
		checklistPos = {point = "CENTER", x = 0, y = 0},
		progressionPos = {point = "TOPRIGHT", relativePoint = "TOPRIGHT", x = -20, y = -400},
		collapsedSections = {}, -- Track collapsed state per section
	},
	settings = {
		showZeroCurrencies = false,
		showUndiscovered = false,
		filterByZone = true, -- Only show currencies relevant to current zone
		abbreviateNumbers = true, -- Abbreviate large numbers (1.5M instead of 1,500,000)
		showConversionInfo = true, -- Show +X info for convertible items
		showItems = true, -- Track items alongside currencies
		-- Great Vault (shown in Weekly Tracker window, not currency display)
		showGreatVault = false,
		showVaultRaid = true,
		showVaultMythicPlus = true,
		showVaultWorld = true,
		-- NEW: Weekly & Progression
		showWeeklyResets = false,
		showRaidLockouts = true,  -- Show in Weekly Tracker window
		showWorldBosses = true,   -- Show in Weekly Tracker window
		showUpgradeContext = false,
		warnWastedUpgrades = true,
		showCooldowns = true,     -- Show in Weekly Tracker window
		-- NEW: Checklist & Alts
		showChecklist = false, -- Checklist window hidden by default
		autoHideCompleted = true,
		checklistPriority = "value", -- "value" or "alphabetical"
		altSortOrder = "completion", -- "completion", "name", or "vault"
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
	-- NEW: Upgrade tracking data
	upgrades = {
		slots = {},
	},
	-- NEW: Account-wide alt data
	alts = {},
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

	-- Initialize weekly tracker
	if addon.WeeklyTracker and addon.WeeklyTracker.Initialize then
		addon.WeeklyTracker:Initialize()
	end

	-- Initialize daily tracker
	if addon.DailyTracker and addon.DailyTracker.Initialize then
		addon.DailyTracker:Initialize()
	end

	-- Initialize upgrade tracker
	if addon.UpgradeTracker and addon.UpgradeTracker.Initialize then
		addon.UpgradeTracker:Initialize()
	end

	-- Initialize conversion tracker
	if addon.ConversionTracker and addon.ConversionTracker.Initialize then
		addon.ConversionTracker:Initialize()
	end

	-- Initialize cooldown tracker
	if addon.CooldownTracker and addon.CooldownTracker.Initialize then
		addon.CooldownTracker:Initialize()
	end

	-- Initialize M+ tracker
	if addon.MythicPlusTracker and addon.MythicPlusTracker.Initialize then
		addon.MythicPlusTracker:Initialize()
	end

	-- Initialize dungeon tracker
	if addon.DungeonTracker and addon.DungeonTracker.Initialize then
		addon.DungeonTracker:Initialize()
	end

	-- Initialize checklist generator
	if addon.ChecklistGenerator and addon.ChecklistGenerator.Initialize then
		addon.ChecklistGenerator:Initialize()
	end

	-- Initialize alt manager
	if addon.AltManager and addon.AltManager.Initialize then
		addon.AltManager:Initialize()
	end

	-- Request WoW Token price update
	if C_WowTokenPublic and C_WowTokenPublic.UpdateMarketPrice then
		C_WowTokenPublic.UpdateMarketPrice()
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
	-- Also update vault progress when weekly rewards update
	if addon.WeeklyTracker and addon.WeeklyTracker.UpdateVaultProgress then
		addon.WeeklyTracker:UpdateVaultProgress()
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
	if addon.WeeklyTracker and addon.WeeklyTracker.UpdateWorldBosses then
		addon.WeeklyTracker:UpdateWorldBosses()
	end
end

-- QUEST_TURNED_IN: Fired when a quest is completed
eventHandlers.QUEST_TURNED_IN = function(questID, xpReward, moneyReward)
	if addon.DailyTracker and addon.DailyTracker.OnQuestTurnedIn then
		addon.DailyTracker:OnQuestTurnedIn(questID)
	end
end

-- UPDATE_INSTANCE_INFO: Fired when raid lockout info is available
eventHandlers.UPDATE_INSTANCE_INFO = function()
	if addon.WeeklyTracker and addon.WeeklyTracker.UpdateRaidLockouts then
		addon.WeeklyTracker:UpdateRaidLockouts()
	end
end

-- ENCOUNTER_END: Fired when an encounter (boss fight) ends
eventHandlers.ENCOUNTER_END = function(encounterID, encounterName, difficultyID, groupSize, success)
	if addon.WeeklyTracker and addon.WeeklyTracker.OnEncounterEnd then
		addon.WeeklyTracker:OnEncounterEnd(encounterID, encounterName, difficultyID, groupSize, success)
	end
	-- Also update vault progress after boss kills
	if addon.WeeklyTracker and addon.WeeklyTracker.UpdateVaultProgress then
		addon.WeeklyTracker:UpdateVaultProgress()
	end
end

-- PLAYER_EQUIPMENT_CHANGED: Fired when player equips/unequips items
eventHandlers.PLAYER_EQUIPMENT_CHANGED = function(slot, equipped)
	if addon.UpgradeTracker and addon.UpgradeTracker.UpdateSlot then
		addon.UpgradeTracker:UpdateSlot(slot)
	end

	-- Update item level for M+ tracker
	if addon.MythicPlusTracker and addon.MythicPlusTracker.OnEquipmentChanged then
		addon.MythicPlusTracker:OnEquipmentChanged()
	end
end

-- CHALLENGE_MODE_COMPLETED: Fired when M+ dungeon is completed
eventHandlers.CHALLENGE_MODE_COMPLETED = function()
	if addon.MythicPlusTracker and addon.MythicPlusTracker.OnChallengeCompleted then
		-- Get completion info
		local mapID = C_ChallengeMode.GetActiveChallengeMapID()
		local level = C_ChallengeMode.GetActiveKeystoneInfo()
		addon.MythicPlusTracker:OnChallengeCompleted(mapID, level, true)
	end
end

-- SPELL_UPDATE_COOLDOWN: Fired when spell cooldowns update
eventHandlers.SPELL_UPDATE_COOLDOWN = function()
	if addon.CooldownTracker and addon.CooldownTracker.UpdateCooldowns then
		addon.CooldownTracker:UpdateCooldowns()
	end
end

-- UNIT_SPELLCAST_SUCCEEDED: Fired when player successfully casts a spell
eventHandlers.UNIT_SPELLCAST_SUCCEEDED = function(unitTarget, castGUID, spellID)
	if unitTarget == "player" and addon.CooldownTracker and addon.CooldownTracker.OnSpellCast then
		addon.CooldownTracker:OnSpellCast(spellID)
	end
end

-- PLAYER_LOGOUT: Fired when player logs out
eventHandlers.PLAYER_LOGOUT = function()
	if addon.AltManager and addon.AltManager.SaveCurrentCharacterSnapshot then
		addon.AltManager:SaveCurrentCharacterSnapshot()
	end
end

-- PLAYER_LEAVING_WORLD: Fired when switching characters or logging out (backup save)
eventHandlers.PLAYER_LEAVING_WORLD = function()
	if addon.AltManager and addon.AltManager.SaveCurrentCharacterSnapshot then
		addon.AltManager:SaveCurrentCharacterSnapshot()
	end
end

-- PLAYER_UPDATE_RESTING: Fired when resting state changes (entering/leaving cities)
eventHandlers.PLAYER_UPDATE_RESTING = function()
	-- Auto-hide Panel 1 (currency) when leaving cities
	if addon.Display and addon.Display.UpdateCityVisibility then
		addon.Display:UpdateCityVisibility()
	end
end

-- BAG_UPDATE: Fired when bag contents change (for item tracking)
eventHandlers.BAG_UPDATE = function(bagID)
	-- Update display to refresh item counts
	if addon.Display and addon.Display.UpdateDisplay then
		addon.Display:UpdateDisplay()
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

-- Abbreviate large numbers (1500000 -> "1.5M", 5200 -> "5.2K")
function addon.Utils:AbbreviateNumber(num)
	if not num then return "0" end

	-- Check if abbreviation is enabled in settings
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

-- Format number with optional abbreviation based on settings
function addon.Utils:FormatAmount(num)
	if not num then return "0" end

	-- Use abbreviation if enabled (default: true)
	if addon.db and addon.db.settings and addon.db.settings.abbreviateNumbers ~= false then
		return self:AbbreviateNumber(num)
	else
		return self:FormatNumber(num)
	end
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
	elseif msg == "showzero" or msg == "show zero" or msg == "hidezero" or msg == "hide zero" then
		addon.db.settings.showZeroCurrencies = not addon.db.settings.showZeroCurrencies
		local status = addon.db.settings.showZeroCurrencies and "Showing all currencies/items (including 0)" or "Hiding currencies/items with 0 count"
		addon.Utils:Print(status)
		-- Force display update
		if addon.Display and addon.Display.UpdateDisplay then
			addon.Display:UpdateDisplay()
		end
	elseif msg == "abbreviate" or msg == "abbrev" then
		addon.db.settings.abbreviateNumbers = not addon.db.settings.abbreviateNumbers
		addon.Utils:Print(format("Abbreviate numbers: %s", addon.db.settings.abbreviateNumbers and "ON (1.5M)" or "OFF (1,500,000)"))
		-- Force display update
		if addon.Display and addon.Display.UpdateDisplay then
			addon.Display:UpdateDisplay()
		end
	elseif msg == "conversion" or msg == "convert" then
		addon.db.settings.showConversionInfo = not addon.db.settings.showConversionInfo
		addon.Utils:Print(format("Show conversion info: %s", addon.db.settings.showConversionInfo and "ON (+X Keys)" or "OFF"))
		-- Force display update
		if addon.Display and addon.Display.UpdateDisplay then
			addon.Display:UpdateDisplay()
		end
	elseif msg == "items" or msg == "showitems" then
		addon.db.settings.showItems = not addon.db.settings.showItems
		addon.Utils:Print(format("Track items: %s", addon.db.settings.showItems and "ON" or "OFF (currencies only)"))
		-- Force display update
		if addon.Display and addon.Display.UpdateDisplay then
			addon.Display:UpdateDisplay()
		end
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
		addon.Utils:Print("Checking Ethereal Crests:")
		local crests = {3284, 3286, 3288, 3290}
		for _, id in ipairs(crests) do
			local info = C_CurrencyInfo.GetCurrencyInfo(id)
			if info then
				local enabled = addon.db.settings.currencies[id]
				local enabledText = enabled == nil and "default" or (enabled and "enabled" or "DISABLED")
				print(format("  [%d] %s: %d (discovered: %s, %s)", id, info.name, info.quantity, tostring(info.discovered), enabledText))

				-- Show caps if present
				if info.maxQuantity and info.maxQuantity > 0 then
					if info.useTotalEarnedForMaxQty then
						print(format("    Season Cap: %d / %d (total earned)", info.totalEarned or 0, info.maxQuantity))
					else
						print(format("    Cap: %d / %d", info.quantity, info.maxQuantity))
					end
				end

				-- Show weekly cap if present
				if info.maxWeeklyQuantity and info.maxWeeklyQuantity > 0 then
					print(format("    Weekly: %d / %d", info.quantityEarnedThisWeek or 0, info.maxWeeklyQuantity))
				end
			else
				print(format("  [%d] Not found", id))
			end
		end
	elseif msg == "findcrests" or msg == "scancurrency" then
		addon.Utils:Print("Scanning for Ethereal Crest currency IDs...")
		print("Looking for currencies with 'Ethereal' or 'Crest' in the name:")
		-- Scan common ID ranges
		for id = 3280, 3300 do
			local info = C_CurrencyInfo.GetCurrencyInfo(id)
			if info and info.name then
				local name = info.name:lower()
				if name:find("ethereal") or name:find("crest") then
					local discovered = info.discovered and "✓" or "✗"
					print(format("  [%d] %s: %d (discovered: %s)", id, info.name, info.quantity, discovered))
				end
			end
		end
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
	elseif msg == "checklist" then
		if addon.Display and addon.Display.ToggleChecklist then
			addon.Display:ToggleChecklist()
		end
	elseif msg == "panel2" or msg == "weekly" or msg == "progression" then
		if addon.Display and addon.Display.ToggleProgression then
			addon.Display:ToggleProgression()
		end
	elseif msg == "alts" then
		if addon.Display and addon.Display.ToggleViewMode then
			-- Toggle to alt dashboard view
			addon.db.display.viewMode = "alts"
			addon.Display:UpdateDisplay()
			addon.Utils:Print("Switched to Alt Dashboard view")
		end
	elseif msg == "current" then
		if addon.Display and addon.Display.ToggleViewMode then
			-- Toggle to current character view
			addon.db.display.viewMode = "current"
			addon.Display:UpdateDisplay()
			addon.Utils:Print("Switched to Current Character view")
		end
	elseif msg == "cooldowns" or msg == "cd" then
		-- Show profession cooldowns
		if addon.CooldownTracker then
			addon.Utils:Print("Profession Cooldowns:")
			local allCooldowns = addon.CooldownTracker:GetAllCooldowns()
			local count = 0
			for spellID, cooldown in pairs(allCooldowns) do
				local status = cooldown.ready and "|cFF00FF00Ready|r" or format("|cFFFF0000%s|r", addon.CooldownTracker:FormatTimeRemaining(cooldown.timeRemaining))
				print(format("  %s (%s): %s", cooldown.name, cooldown.profession, status))
				count = count + 1
			end
			if count == 0 then
				print("  (no profession cooldowns tracked)")
				print("  Add spell IDs to CooldownTracker.lua CRAFTING_COOLDOWN_SPELLS table")
			end

			-- Show catalyst
			local catalyst = addon.CooldownTracker:GetCatalystCharges()
			print(" ")
			addon.Utils:Print(format("Catalyst Charges: %d/%d", catalyst.charges, catalyst.maxCharges))
		end
	elseif msg == "config" or msg == "options" then
		if addon.Config and addon.Config.Toggle then
			addon.Config:Toggle()
		end
	elseif msg:match("^blacklist") then
		local cmd = msg:match("^blacklist%s+(%S+)")
		local name = msg:match("^blacklist%s+%S+%s+(.+)")

		if cmd == "list" then
			-- Show blacklisted characters
			if addon.AltManager then
				local blacklist = addon.AltManager:GetBlacklist()
				local count = 0
				addon.Utils:Print("Blacklisted characters:")
				for key, _ in pairs(blacklist) do
					print("  " .. key)
					count = count + 1
				end
				if count == 0 then
					print("  (none)")
				end
			end
		elseif cmd == "add" and name then
			-- Blacklist a character (format: Realm-Name)
			if addon.AltManager then
				addon.AltManager:BlacklistAlt(name)
				addon.Utils:Print("Blacklisted: " .. name)
			end
		elseif cmd == "remove" and name then
			-- Remove from blacklist
			if addon.AltManager then
				addon.AltManager:UnblacklistAlt(name)
				addon.Utils:Print("Removed from blacklist: " .. name)
			end
		else
			addon.Utils:Print("Blacklist commands:")
			print("  /mtrack blacklist list - Show blacklisted characters")
			print("  /mtrack blacklist add <Realm-Name> - Blacklist a character")
			print("  /mtrack blacklist remove <Realm-Name> - Remove from blacklist")
		end
	else
		addon.Utils:Print("Commands:")
		print("  /mtrack show - Show Panel 1 (Currency)")
		print("  /mtrack hide - Hide Panel 1 (Currency)")
		print("  /mtrack toggle - Toggle Panel 1 (Currency)")
		print("  /mtrack panel2 - Toggle Panel 2 (Weekly Tracker)")
		print("  /mtrack weekly - Toggle Panel 2 (Weekly Tracker)")
		print("  /mtrack checklist - Toggle smart checklist window")
		print("  /mtrack alts - Switch to alt dashboard view")
		print("  /mtrack current - Switch to current character view")
		print("  /mtrack showzero - Toggle hiding currencies/items with 0 count")
		print("  /mtrack hidezero - Same as showzero (toggle hide when zero)")
		print("  /mtrack abbreviate - Toggle number abbreviation (1.5M vs 1,500,000)")
		print("  /mtrack conversion - Toggle conversion info (+X Keys for craftables)")
		print("  /mtrack items - Toggle item tracking (alongside currencies)")
		print("  /mtrack minimap show - Show minimap icon")
		print("  /mtrack minimap hide - Hide minimap icon")
		print("  /mtrack reset - Reset minimap icon position")
		print("  /mtrack debug - Toggle debug mode")
		print("  /mtrack zone - Show zone detection info")
		print("  /mtrack crests - Check crest counts and caps (detailed)")
		print("  /mtrack cooldowns - Show profession cooldowns and catalyst charges")
		print("  /mtrack trackables - Show what's being displayed")
		print("  /mtrack categories - Show enabled/disabled categories")
		print("  /mtrack showall - Enable all expansion categories")
		print("  /mtrack blacklist list - Show blacklisted alts")
		print("  /mtrack blacklist add <Realm-Name> - Blacklist a character")
		print("  /mtrack blacklist remove <Realm-Name> - Unblacklist a character")
		print("  /mtrack config - Open configuration panel")
		print(" ")
		print("Short commands: /mtk or /midnighttracker also work")
	end
end
