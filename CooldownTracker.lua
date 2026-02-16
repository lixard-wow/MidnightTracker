local addonName, addon = ...

-- CooldownTracker module: tracks catalyst charges, crafting cooldowns, timers
addon.CooldownTracker = {}
local CooldownTracker = addon.CooldownTracker

-- Constants
local CATALYST_CURRENCY_ID = 3269 -- Ethereal Voidsplinter (TWW Season 3 Catalyst Charges)

-- Cache for cooldown data
CooldownTracker.catalystCharges = 0
CooldownTracker.catalystMaxCharges = 8 -- Season 3 increased max to 8
CooldownTracker.nextCatalystCharge = 0
CooldownTracker.craftingCooldowns = {}
CooldownTracker.lastUpdate = 0

-- Known crafting cooldown spell IDs for The War Within / Midnight
-- NOTE: Most TWW professions use Knowledge Points instead of traditional daily cooldowns
-- Add spell IDs as you discover them in-game or from databases like Wowhead
local CRAFTING_COOLDOWN_SPELLS = {
	-- === ALCHEMY (The War Within) ===
	{spellID = 430624, name = "Gleaming Glory", profession = "Alchemy", cooldown = "24h"},
	-- Other transmutes: Gleaming Chaos, Gleaming Devotion, Gleaming Fury, etc.
	-- {spellID = 0, name = "Gleaming Chaos", profession = "Alchemy", cooldown = "24h"},

	-- === BLACKSMITHING (The War Within) ===
	-- {spellID = 0, name = "Everburning Ignition", profession = "Blacksmithing", cooldown = "24h"},

	-- === TAILORING (The War Within) ===
	-- Cooldown cloth transmutes exist but spell IDs need to be added
	-- {spellID = 0, name = "[Tailoring Cooldown]", profession = "Tailoring", cooldown = "24h"},

	-- === ENGINEERING (The War Within) ===
	-- Invent has a 24-hour cooldown
	-- {spellID = 0, name = "Invent", profession = "Engineering", cooldown = "24h"},

	-- === ENCHANTING (The War Within) ===
	-- {spellID = 0, name = "[Enchanting Cooldown]", profession = "Enchanting", cooldown = "24h"},

	-- === JEWELCRAFTING (The War Within) ===
	-- {spellID = 0, name = "[Jewelcrafting Cooldown]", profession = "Jewelcrafting", cooldown = "24h"},

	-- === INSCRIPTION (The War Within) ===
	-- {spellID = 0, name = "[Inscription Cooldown]", profession = "Inscription", cooldown = "24h"},

	-- === LEATHERWORKING (The War Within) ===
	-- {spellID = 0, name = "[Leatherworking Cooldown]", profession = "Leatherworking", cooldown = "24h"},

	-- === MIDNIGHT PROFESSIONS ===
	-- Add Midnight profession cooldowns when expansion launches and spell IDs become available
}

-- Initialize cooldown tracker
function CooldownTracker:Initialize()
	-- Initial update
	self:UpdateCatalystCharges()
	self:UpdateCooldowns()

	-- Set up periodic update (every 5 seconds)
	self.updateTimer = 0
	local updateFrame = CreateFrame("Frame")
	updateFrame:SetScript("OnUpdate", function(self, elapsed)
		CooldownTracker.updateTimer = CooldownTracker.updateTimer + elapsed
		if CooldownTracker.updateTimer >= 5 then
			CooldownTracker:UpdateCatalystCharges()
			CooldownTracker:UpdateCooldowns()
			CooldownTracker.updateTimer = 0
		end
	end)

	addon.Utils:Debug("CooldownTracker initialized")
end

-- Update catalyst charges
function CooldownTracker:UpdateCatalystCharges()
	if not C_CurrencyInfo then return end

	local info = C_CurrencyInfo.GetCurrencyInfo(CATALYST_CURRENCY_ID)
	if info then
		self.catalystCharges = info.quantity or 0
		self.catalystMaxCharges = info.maxQuantity or 8 -- Default to 8 if API doesn't return max

		-- Calculate next charge time (weekly reset)
		-- Catalyst charges are gained weekly
		local serverTime = GetServerTime()
		local resetTime = self:GetNextWeeklyReset()
		self.nextCatalystCharge = resetTime

		self.lastUpdate = time()
	end
end

-- Get next weekly reset time
function CooldownTracker:GetNextWeeklyReset()
	-- US region resets on Tuesday at 15:00 UTC
	-- EU region resets on Wednesday at 07:00 UTC
	-- This is a simplified calculation
	local serverTime = GetServerTime()
	local region = GetCVar("portal") or "US"

	-- Calculate days until next reset
	local weekday = date("%w", serverTime) -- 0 = Sunday, 1 = Monday, etc.
	local resetDay = (region == "EU") and 3 or 2 -- Wednesday = 3, Tuesday = 2

	local daysUntilReset = (resetDay - weekday) % 7
	if daysUntilReset == 0 then
		-- Check if reset has already happened today
		local resetHour = (region == "EU") and 7 or 15
		local currentHour = tonumber(date("%H", serverTime))
		if currentHour >= resetHour then
			daysUntilReset = 7
		end
	end

	local secondsUntilReset = daysUntilReset * 24 * 60 * 60
	return serverTime + secondsUntilReset
end

-- Get catalyst charge info
function CooldownTracker:GetCatalystCharges()
	return {
		charges = self.catalystCharges,
		maxCharges = self.catalystMaxCharges,
		nextCharge = self.nextCatalystCharge,
		timeUntilNext = math.max(0, self.nextCatalystCharge - GetServerTime()),
	}
end

-- Update all tracked cooldowns
function CooldownTracker:UpdateCooldowns()
	if not C_Spell or not C_Spell.GetSpellCooldown then return end

	-- Skip update during combat to avoid taint issues with protected spell data
	if InCombatLockdown() then return end

	self.craftingCooldowns = {}

	for _, spellInfo in ipairs(CRAFTING_COOLDOWN_SPELLS) do
		-- Use pcall to safely handle any taint issues
		local success, cooldownInfo = pcall(C_Spell.GetSpellCooldown, spellInfo.spellID)

		if success and cooldownInfo then
			-- Extract values safely
			local startTime = cooldownInfo.startTime
			local duration = cooldownInfo.duration

			-- Only proceed if we got valid numeric values
			if type(startTime) == "number" and type(duration) == "number" then
				local ready = false
				local cooldownEnd = 0

				-- Use simple logic without direct comparisons to avoid taint
				if duration then
					cooldownEnd = startTime + duration
					-- Check if cooldown is ready by checking if end time has passed
					ready = (GetTime() >= cooldownEnd)
				else
					ready = true
				end

				self.craftingCooldowns[spellInfo.spellID] = {
					spellID = spellInfo.spellID,
					name = spellInfo.name,
					profession = spellInfo.profession,
					ready = ready,
					cooldownEnd = cooldownEnd,
					timeRemaining = math.max(0, cooldownEnd - GetTime()),
				}
			end
		end
	end
end

-- Get crafting cooldown for specific spell
function CooldownTracker:GetCraftingCooldown(spellID)
	return self.craftingCooldowns[spellID]
end

-- Get all crafting cooldowns
function CooldownTracker:GetAllCooldowns()
	return self.craftingCooldowns
end

-- Event handler: spell cast succeeded
function CooldownTracker:OnSpellCast(spellID)
	-- Check if this is a tracked crafting spell
	for _, spellInfo in ipairs(CRAFTING_COOLDOWN_SPELLS) do
		if spellInfo.spellID == spellID then
			-- Update this specific cooldown
			C_Timer.After(0.5, function()
				self:UpdateCooldowns()
			end)
			break
		end
	end
end

-- Get ready cooldowns count
function CooldownTracker:GetReadyCooldownsCount()
	local count = 0
	for spellID, cooldown in pairs(self.craftingCooldowns) do
		if cooldown.ready then
			count = count + 1
		end
	end
	return count
end

-- Get all cooldown data for checklist/dashboard
function CooldownTracker:GetAllCooldownData()
	return {
		catalyst = self:GetCatalystCharges(),
		crafting = self.craftingCooldowns,
		readyCount = self:GetReadyCooldownsCount(),
		lastUpdate = self.lastUpdate,
	}
end

-- Format time remaining as readable string
function CooldownTracker:FormatTimeRemaining(seconds)
	if seconds <= 0 then
		return "Ready"
	end

	local days = math.floor(seconds / 86400)
	local hours = math.floor((seconds % 86400) / 3600)
	local minutes = math.floor((seconds % 3600) / 60)

	if days > 0 then
		return format("%dd %dh", days, hours)
	elseif hours > 0 then
		return format("%dh %dm", hours, minutes)
	elseif minutes > 0 then
		return format("%dm", minutes)
	else
		return format("%ds", seconds)
	end
end
