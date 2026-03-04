local addonName, addon = ...

-- Tracker module: handles currency data fetching and caching
addon.Tracker = {}
local Tracker = addon.Tracker

-- Cache for currency data
Tracker.currencyCache = {}

function Tracker:Initialize()
	self:UpdateAllCurrencies()

	-- Periodic update every 5 seconds
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

function Tracker:UpdateAllCurrencies()
	for category, currencies in pairs(addon.Data.Currencies) do
		for _, currencyData in ipairs(currencies) do
			self:UpdateCurrency(currencyData[1])
		end
	end
end

function Tracker:UpdateCurrency(currencyID)
	if not C_CurrencyInfo then return end

	local info = C_CurrencyInfo.GetCurrencyInfo(currencyID)
	if info then
		self.currencyCache[currencyID] = {
			name = info.name,
			quantity = info.quantity,
			totalEarned = info.totalEarned,
			iconFileID = info.iconFileID,
			maxQuantity = info.maxQuantity,
			maxWeeklyQuantity = info.maxWeeklyQuantity,
			quantityEarnedThisWeek = info.quantityEarnedThisWeek,
			discovered = info.discovered,
			useTotalEarnedForMaxQty = info.useTotalEarnedForMaxQty,
		}
	end
end

function Tracker:GetEffectiveWeeklyCap(cached, fallbackWeeklyMax)
	if not cached then
		if fallbackWeeklyMax and fallbackWeeklyMax > 0 then
			return fallbackWeeklyMax
		end
		return nil
	end

	if cached.maxWeeklyQuantity and cached.maxWeeklyQuantity > 0 then
		return cached.maxWeeklyQuantity
	end

	if cached.useTotalEarnedForMaxQty and cached.maxQuantity and cached.maxQuantity > 0 then
		return cached.maxQuantity
	end

	if fallbackWeeklyMax and fallbackWeeklyMax > 0 then
		return fallbackWeeklyMax
	end

	return nil
end

function Tracker:GetCurrency(currencyID)
	return self.currencyCache[currencyID]
end

function Tracker:IsCurrencyDiscovered(currencyID)
	local cached = self.currencyCache[currencyID]
	if not cached then
		self:UpdateCurrency(currencyID)
		cached = self.currencyCache[currencyID]
	end
	return cached and cached.discovered
end

function Tracker:GetCurrencyAmount(currencyID)
	local cached = self.currencyCache[currencyID]
	if not cached then
		self:UpdateCurrency(currencyID)
		cached = self.currencyCache[currencyID]
	end
	return cached and cached.quantity or 0
end

function Tracker:OnCurrencyUpdate(currencyID, quantity)
	if currencyID then
		self:UpdateCurrency(currencyID)
	else
		self:UpdateAllCurrencies()
	end
end

-- Get current zone expansion
function Tracker:GetCurrentExpansion()
	local mapID = C_Map.GetBestMapForUnit("player")
	if not mapID then return "Midnight" end

	local mapInfo = C_Map.GetMapInfo(mapID)
	if not mapInfo then return "Midnight" end

	local majorCities = {
		[2393] = "Midnight", -- Silvermoon City (Midnight)
		[2339] = "War Within", -- Dornogal
		[2112] = "Dragonflight",
		[1670] = "Shadowlands",
		[1161] = "BFA",
		[1165] = "BFA",
		[1220] = "Legion",
		[627] = "Legion",
		[1009] = "WoD",
		[1011] = "WoD",
		[390] = "MoP",
		[391] = "MoP",
		[84] = "Cataclysm",
		[85] = "Cataclysm",
		[125] = "WotLK",
		[111] = "BC",
	}

	if majorCities[mapID] then
		return majorCities[mapID]
	end

	local directMapExpansion = {
		-- Midnight zones
		[2395] = "Midnight", -- Eversong Woods
		[2437] = "Midnight", -- Zul'Aman
		[2413] = "Midnight", -- Harandar
		[2405] = "Midnight", -- Voidstorm
		-- War Within zones
		[2248] = "War Within",
		[2255] = "War Within",
		[2213] = "War Within",
		[2214] = "War Within",
		[2367] = "War Within",
		[2359] = "War Within",
		[2369] = "War Within",
		[2370] = "War Within",
		[2371] = "War Within",
		[2372] = "War Within",
		[2373] = "War Within",
		[2374] = "War Within",
		[2481] = "War Within",
		[2569] = "War Within",
	}

	if directMapExpansion[mapID] then
		return directMapExpansion[mapID]
	end

	while mapInfo and mapInfo.mapType ~= Enum.UIMapType.Cosmic do
		if mapInfo.mapType == Enum.UIMapType.Continent then
			local continentToExpansion = {
				[2274] = "Midnight",
				[2248] = "War Within",
				[1978] = "Dragonflight",
				[1550] = "Shadowlands",
				[875] = "BFA",
				[876] = "BFA",
				[619] = "Legion",
				[572] = "WoD",
			}
			return continentToExpansion[mapInfo.mapID] or "Midnight"
		end
		mapInfo = mapInfo.parentMapID and C_Map.GetMapInfo(mapInfo.parentMapID)
	end

	return "Midnight"
end

function Tracker:IsCurrencyRelevantToZone(categoryName, expansion)
	local filterByZone = addon.db and addon.db.settings and addon.db.settings.filterByZone
	if not filterByZone then
		return true
	end

	if categoryName == "PvP Currencies" then
		return true
	end

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
		["Seasonal Events"] = nil,
	}

	return categoryExpansions[categoryName] == expansion
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

-- Get all trackable currency data
function Tracker:GetAllTrackables()
	local data = {
		categories = {},
		weeklyReset = addon.Data:GetTimeUntilWeeklyReset(),
	}

	local currentExpansion = self:GetCurrentExpansion()

	for category, currencies in pairs(addon.Data.Currencies) do
		local filterByZone = addon.db and addon.db.settings and addon.db.settings.filterByZone
		local categoryKey = self:GetCategorySettingKey(category)
		local categoryEnabled = not addon.db or not addon.db.settings or addon.db.settings.categories[categoryKey] ~= false
		local showCategory = false

		if not categoryEnabled then
			showCategory = false
		elseif not filterByZone then
			showCategory = true
		else
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
						-- For total-earned currencies (crests), show total earned and the season cap
						local displayAmount = cached.quantity
						local displayMax = cached.maxQuantity or weeklyMax
						if cached.useTotalEarnedForMaxQty then
							displayAmount = cached.totalEarned or cached.quantity
						end

						if cached.discovered and (cached.quantity > 0 or showZero) then
							table.insert(categoryData.currencies, {
								id = currencyID,
								name = displayName or cached.name,
								amount = displayAmount,
								icon = cached.iconFileID,
								max = displayMax,
								weeklyMax = effectiveWeeklyMax,
								earnedThisWeek = cached.quantityEarnedThisWeek,
							})
						elseif not cached.discovered and showUndiscovered then
							table.insert(categoryData.currencies, {
								id = currencyID,
								name = displayName or cached.name,
								amount = 0,
								icon = cached.iconFileID or iconFileID,
								max = displayMax,
								weeklyMax = effectiveWeeklyMax,
								earnedThisWeek = 0,
							})
						end
					end
				end
			end

			if #categoryData.currencies > 0 then
				table.insert(data.categories, categoryData)
			end
		end
	end

	return data
end
