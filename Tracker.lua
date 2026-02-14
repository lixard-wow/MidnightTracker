local addonName, addon = ...

-- Tracker module: handles data fetching and caching
addon.Tracker = {}
local Tracker = addon.Tracker

-- Cache for currency data
Tracker.currencyCache = {}
Tracker.itemCache = {}
Tracker.weeklyCache = {}

-- Initialize tracker
function Tracker:Initialize()
	-- Scan all currencies on login
	self:UpdateAllCurrencies()

	-- Set up periodic update (every 5 seconds)
	self.updateTimer = 0
	local updateFrame = CreateFrame("Frame")
	updateFrame:SetScript("OnUpdate", function(self, elapsed)
		Tracker.updateTimer = Tracker.updateTimer + elapsed
		if Tracker.updateTimer >= 5 then
			Tracker:UpdateAllCurrencies()
			Tracker.updateTimer = 0
		end
	end)
end

-- Update all tracked currencies
function Tracker:UpdateAllCurrencies()
	for category, currencies in pairs(addon.Data.Currencies) do
		for _, currencyData in ipairs(currencies) do
			local currencyID = currencyData[1]
			self:UpdateCurrency(currencyID)
		end
	end
end

-- Update single currency
function Tracker:UpdateCurrency(currencyID)
	if not C_CurrencyInfo then return end

	local info = C_CurrencyInfo.GetCurrencyInfo(currencyID)
	if info then
		self.currencyCache[currencyID] = {
			name = info.name,
			quantity = info.quantity,
			iconFileID = info.iconFileID,
			maxQuantity = info.maxQuantity,
			maxWeeklyQuantity = info.maxWeeklyQuantity,
			quantityEarnedThisWeek = info.quantityEarnedThisWeek,
			discovered = info.discovered,
			useTotalEarnedForMaxQty = info.useTotalEarnedForMaxQty,
		}
	end
end

-- Resolve effective weekly cap (API-first)
function Tracker:GetEffectiveWeeklyCap(cached, fallbackWeeklyMax)
	if not cached then
		if fallbackWeeklyMax and fallbackWeeklyMax > 0 then
			return fallbackWeeklyMax
		end
		return nil
	end

	-- Preferred source: true weekly cap from API
	if cached.maxWeeklyQuantity and cached.maxWeeklyQuantity > 0 then
		return cached.maxWeeklyQuantity
	end

	-- Some currencies expose capped progress via total-earned max quantity
	if cached.useTotalEarnedForMaxQty and cached.maxQuantity and cached.maxQuantity > 0 then
		return cached.maxQuantity
	end

	-- Fallback to static data if provided
	if fallbackWeeklyMax and fallbackWeeklyMax > 0 then
		return fallbackWeeklyMax
	end

	return nil
end

-- Get currency data from cache
function Tracker:GetCurrency(currencyID)
	return self.currencyCache[currencyID]
end

-- Check if currency is discovered by player
function Tracker:IsCurrencyDiscovered(currencyID)
	local cached = self.currencyCache[currencyID]
	if not cached then
		self:UpdateCurrency(currencyID)
		cached = self.currencyCache[currencyID]
	end
	return cached and cached.discovered
end

-- Get currency amount
function Tracker:GetCurrencyAmount(currencyID)
	local cached = self.currencyCache[currencyID]
	if not cached then
		self:UpdateCurrency(currencyID)
		cached = self.currencyCache[currencyID]
	end
	return cached and cached.quantity or 0
end

-- Event handler: currency updated
function Tracker:OnCurrencyUpdate(currencyID, quantity)
	if currencyID then
		self:UpdateCurrency(currencyID)
	else
		-- If no specific currency, update all tracked currencies
		self:UpdateAllCurrencies()
	end
end

-- Event handler: quest log updated
function Tracker:OnQuestUpdate()
	-- Update weekly quest tracking
	self:UpdateWeeklyActivities()
end

-- Update weekly activity tracking
function Tracker:UpdateWeeklyActivities()
	if not addon.Data.WeeklyActivities then return end

	for _, activity in ipairs(addon.Data.WeeklyActivities) do
		if activity.type == "quest" and activity.questID then
			-- Check if weekly quest is completed
			local completed = C_QuestLog.IsQuestFlaggedCompleted(activity.questID)
			self.weeklyCache[activity.name] = {
				completed = completed,
				type = "quest",
			}
		end
	end
end

-- Get Great Vault progress
function Tracker:GetGreatVaultProgress()
	if not C_WeeklyRewards then return nil end

	local activities = C_WeeklyRewards.GetActivities()
	if not activities then return nil end

	local progress = {
		raid = {current = 0, max = 8, thresholds = {2, 4, 8}, level = 0},
		mythicplus = {current = 0, max = 8, thresholds = {2, 4, 8}, level = 0},
		world = {current = 0, max = 8, thresholds = {2, 4, 8}, level = 0},
	}

	-- Parse activities and count progress
	for _, activityInfo in ipairs(activities) do
		if activityInfo.type == Enum.WeeklyRewardChestThresholdType.Raid then
			progress.raid.current = activityInfo.progress or 0
			progress.raid.level = math.max(progress.raid.level, activityInfo.level or 0)
		elseif activityInfo.type == Enum.WeeklyRewardChestThresholdType.Activities then
			-- Mythic+ dungeons
			progress.mythicplus.current = activityInfo.progress or 0
			progress.mythicplus.level = math.max(progress.mythicplus.level, activityInfo.level or 0)
		elseif activityInfo.type == Enum.WeeklyRewardChestThresholdType.World then
			-- World activities (including delves)
			progress.world.current = activityInfo.progress or 0
			progress.world.level = math.max(progress.world.level, activityInfo.level or 0)
		end
	end

	return progress
end

-- Get current zone expansion
function Tracker:GetCurrentExpansion()
	local mapID = C_Map.GetBestMapForUnit("player")
	if not mapID then return "War Within" end -- Default to current expansion

	local mapInfo = C_Map.GetMapInfo(mapID)
	if not mapInfo then return "War Within" end

	-- Major cities (show only that expansion's currencies)
	local majorCities = {
		-- War Within
		[2339] = "War Within", -- Dornogal
		-- Dragonflight
		[2112] = "Dragonflight", -- Valdrakken
		-- Shadowlands
		[1670] = "Shadowlands", -- Oribos
		-- BFA
		[1161] = "BFA", -- Boralus (Alliance)
		[1165] = "BFA", -- Dazar'alor (Horde)
		-- Legion
		[1220] = "Legion", -- Dalaran (Legion)
		[627] = "Legion", -- Dalaran (Legion, alternative ID)
		-- WoD
		[1009] = "WoD", -- Stormshield (Alliance)
		[1011] = "WoD", -- Warspear (Horde)
		-- MoP
		[390] = "MoP", -- Shrine of Seven Stars (Alliance)
		[391] = "MoP", -- Shrine of Two Moons (Horde)
		-- Cataclysm (uses main cities)
		[84] = "Cataclysm", -- Stormwind
		[85] = "Cataclysm", -- Orgrimmar
		-- WotLK
		[125] = "WotLK", -- Dalaran (Northrend)
		-- BC
		[111] = "BC", -- Shattrath City
	}

	-- Check if in major city first
	if majorCities[mapID] then
		return majorCities[mapID]
	end

	-- Direct map ID to expansion (for dungeons/instances/zones)
	local directMapExpansion = {
		-- War Within Zones
		[2248] = "War Within", -- Isle of Dorn
		[2255] = "War Within", -- Azj-Kahet
		[2213] = "War Within", -- Hallowfall
		[2214] = "War Within", -- The Ringing Deeps
		-- War Within Dungeons
		[2367] = "War Within", -- Ara-Kara
		[2359] = "War Within", -- City of Threads
		[2369] = "War Within", -- The Rookery
		[2370] = "War Within", -- Priory of the Sacred Flame
		[2371] = "War Within", -- The Stonevault
		[2372] = "War Within", -- Darkflame Cleft
		[2373] = "War Within", -- Cinderbrew Meadery
		[2374] = "War Within", -- The Dawnbreaker
		-- War Within Raids
		[2481] = "War Within", -- Nerub-ar Palace
		[2569] = "War Within", -- Liberation of Undermine
	}

	if directMapExpansion[mapID] then
		return directMapExpansion[mapID]
	end

	-- Get continent/expansion by walking up the map tree
	while mapInfo and mapInfo.mapType ~= Enum.UIMapType.Cosmic do
		if mapInfo.mapType == Enum.UIMapType.Continent then
			-- Map continent IDs to expansions
			local continentToExpansion = {
				[2274] = "Midnight", -- Quel'Thalas (Midnight)
				[2248] = "War Within", -- Khaz Algar
				[1978] = "Dragonflight", -- Dragon Isles
				[1550] = "Shadowlands", -- Shadowlands
				[875] = "BFA", -- Zandalar
				[876] = "BFA", -- Kul Tiras
				[619] = "Legion", -- Broken Isles
				[572] = "WoD", -- Draenor
			}
			return continentToExpansion[mapInfo.mapID] or "War Within"
		end
		mapInfo = mapInfo.parentMapID and C_Map.GetMapInfo(mapInfo.parentMapID)
	end

	-- Default to current expansion if can't determine
	return "War Within"
end

-- Check if currency should be shown based on zone
function Tracker:IsCurrencyRelevantToZone(categoryName, expansion)
	-- Filter by zone setting
	local filterByZone = addon.db and addon.db.settings and addon.db.settings.filterByZone
	if not filterByZone then
		return true -- Show all if filter disabled
	end

	-- PvP is always relevant (universal currency)
	if categoryName == "PvP Currencies" then
		return true
	end

	-- Map category to expansion
	local categoryExpansions = {
		["Midnight"] = "Midnight",
		["War Within"] = "War Within",
		["Dragonflight"] = "Dragonflight",
		["Shadowlands"] = "Shadowlands",
		["Battle for Azeroth"] = "BFA",
		["Legion"] = "Legion",
		["Warlords of Draenor"] = "WoD",
		["Mists of Pandaria"] = "MoP",
		["Cataclysm"] = "Cataclysm",
		["Wrath of the Lich King"] = "WotLK",
		["Burning Crusade"] = "BC",
		["Seasonal Events"] = nil, -- Filtered by zone
	}

	local categoryExp = categoryExpansions[categoryName]

	return categoryExp == expansion
end

-- Get all trackable data for tooltip
function Tracker:GetAllTrackables()
	local data = {
		categories = {},
		weeklyReset = addon.Data:GetTimeUntilWeeklyReset(),
	}

	-- Get current expansion for filtering
	local currentExpansion = self:GetCurrentExpansion()

	-- Build currency data by category
	for category, currencies in pairs(addon.Data.Currencies) do
		local filterByZone = addon.db and addon.db.settings and addon.db.settings.filterByZone
		local categoryKey = self:GetCategorySettingKey(category)
		local categoryEnabled = not addon.db or not addon.db.settings or addon.db.settings.categories[categoryKey] ~= false
		local showCategory = false

		-- Always respect category enabled/disabled setting
		if not categoryEnabled then
			showCategory = false
		elseif not filterByZone then
			-- Zone filtering OFF: show if category is enabled
			showCategory = true
		else
			-- Zone filtering ON: show if category is enabled AND relevant to zone
			if self:IsCurrencyRelevantToZone(category, currentExpansion) then
				showCategory = true
			end
		end

		if showCategory then
				local categoryData = {
					name = category,
					currencies = {},
				}

				for _, currencyInfo in ipairs(currencies) do
					local currencyID = currencyInfo[1]
					local displayName = currencyInfo[2]
					local weeklyMax = currencyInfo[3]
					local iconFileID = currencyInfo[4]

					-- Check if currency is enabled (default: enabled unless explicitly disabled)
					local currencyEnabled = true
					if addon.db and addon.db.settings and addon.db.settings.currencies then
						if addon.db.settings.currencies[currencyID] ~= nil then
							currencyEnabled = addon.db.settings.currencies[currencyID]
						end
					end

					if currencyEnabled then
						local cached = self:GetCurrency(currencyID)
						local showZero = addon.db and addon.db.settings and addon.db.settings.showZeroCurrencies
						local showUndiscovered = addon.db and addon.db.settings and addon.db.settings.showUndiscovered

						if cached then
							local effectiveWeeklyMax = self:GetEffectiveWeeklyCap(cached, weeklyMax)
							-- Show discovered currencies with amount > 0 or when showZero is enabled
							if cached.discovered and (cached.quantity > 0 or showZero) then
								table.insert(categoryData.currencies, {
									id = currencyID,
									name = displayName or cached.name,
									amount = cached.quantity,
									icon = cached.iconFileID,
									max = cached.maxQuantity or weeklyMax,
									weeklyMax = effectiveWeeklyMax,
									earnedThisWeek = cached.quantityEarnedThisWeek,
								})
							-- Show undiscovered currencies when showUndiscovered is enabled
							elseif not cached.discovered and showUndiscovered then
								table.insert(categoryData.currencies, {
									id = currencyID,
									name = displayName or cached.name,
									amount = 0,
									icon = cached.iconFileID or iconFileID,
									max = cached.maxQuantity or weeklyMax,
									weeklyMax = effectiveWeeklyMax,
									earnedThisWeek = 0,
								})
							end
						end
					end
				end

				-- Only add category if it has currencies to display
				if #categoryData.currencies > 0 then
					table.insert(data.categories, categoryData)
				end
		end
	end

	-- Add Great Vault progress
	local vaultProgress = self:GetGreatVaultProgress()
	if vaultProgress then
		data.greatVault = vaultProgress
	end

	return data
end

-- Convert category name to settings key
function Tracker:GetCategorySettingKey(categoryName)
	local keyMap = {
		["Midnight"] = "showMidnight",
		["War Within"] = "showWarWithin",
		["PvP Currencies"] = "showPvP",
		["Dragonflight"] = "showDragonflight",
		["Shadowlands"] = "showShadowlands",
		["Battle for Azeroth"] = "showBFA",
		["Legion"] = "showLegion",
		["Warlords of Draenor"] = "showWoD",
		["Mists of Pandaria"] = "showMoP",
		["Cataclysm"] = "showCataclysm",
		["Wrath of the Lich King"] = "showWotLK",
		["Burning Crusade"] = "showBC",
		["Seasonal Events"] = "showSeasonal",
	}
	return keyMap[categoryName] or "showSeasonal"
end

-- Get item count
function Tracker:GetItemCount(itemID)
	if not C_Item then
		-- Fallback for older API
		return GetItemCount(itemID, true) or 0
	end
	return C_Item.GetItemCount(itemID, true) or 0
end

-- Update item cache
function Tracker:UpdateItem(itemID)
	local count = self:GetItemCount(itemID)
	self.itemCache[itemID] = {
		count = count,
		lastUpdate = time(),
	}
end

-- Get cached item count
function Tracker:GetCachedItemCount(itemID)
	local cached = self.itemCache[itemID]
	if not cached or (time() - cached.lastUpdate) > 5 then
		self:UpdateItem(itemID)
		cached = self.itemCache[itemID]
	end
	return cached and cached.count or 0
end
