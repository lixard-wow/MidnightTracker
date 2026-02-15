local addonName, addon = ...

-- CooldownTracker module: tracks catalyst charges, crafting cooldowns, timers
addon.CooldownTracker = {}
local CooldownTracker = addon.CooldownTracker

-- Constants
local CATALYST_CURRENCY_ID = 2796 -- Renascent Dream (Catalyst Charges)

-- Cache for cooldown data
CooldownTracker.catalystCharges = 0
CooldownTracker.catalystMaxCharges = 6
CooldownTracker.nextCatalystCharge = 0
CooldownTracker.craftingCooldowns = {}
CooldownTracker.lastUpdate = 0

-- Known crafting cooldown spell IDs (examples - would need to populate with actual spell IDs)
local CRAFTING_COOLDOWN_SPELLS = {
	-- Profession cooldowns would go here
	-- Example: {spellID = 12345, name = "Transmute: Living Steel", profession = "Alchemy"}
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
		self.catalystMaxCharges = info.maxQuantity or 6

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

	self.craftingCooldowns = {}

	for _, spellInfo in ipairs(CRAFTING_COOLDOWN_SPELLS) do
		local cooldownInfo = C_Spell.GetSpellCooldown(spellInfo.spellID)

		if cooldownInfo then
			local startTime = cooldownInfo.startTime
			local duration = cooldownInfo.duration

			local ready = (duration == 0)
			local cooldownEnd = startTime + duration

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
