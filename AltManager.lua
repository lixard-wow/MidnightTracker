local addonName, addon = ...

-- AltManager module: manages account-wide character snapshots and alt tracking
addon.AltManager = {}
local AltManager = addon.AltManager

-- Initialize alt manager
function AltManager:Initialize()
	-- Ensure alts table exists in saved variables
	if not addon.db.alts then
		addon.db.alts = {}
	end

	-- Ensure blacklist exists
	if not addon.db.altBlacklist then
		addon.db.altBlacklist = {}
	end

	-- Clean up old snapshots (older than 2 weeks)
	self:CleanOldSnapshots()

	addon.Utils:Debug("AltManager initialized")
end

-- Save current character snapshot on logout
function AltManager:SaveCurrentCharacterSnapshot()
	-- Validate saved variables exist
	if not addon.db or not addon.db.alts then
		addon.Utils:Debug("AltManager: Cannot save snapshot - DB not initialized")
		return
	end

	-- Validate player info
	local name = UnitName("player")
	local realm = GetRealmName()

	if not name or not realm then
		addon.Utils:Debug("AltManager: Cannot save snapshot - invalid player info")
		return
	end

	local key = format("%s-%s", realm, name)

	-- Check if character is blacklisted
	if addon.db.altBlacklist and addon.db.altBlacklist[key] then
		addon.Utils:Debug(format("AltManager: Skipping blacklisted character: %s", key))
		return
	end

	-- Gather character data
	local class, classFilename = UnitClass("player")
	local level = UnitLevel("player")

	-- Gather weekly snapshot data
	local snapshot = {
		name = name,
		realm = realm,
		class = classFilename,
		level = level,
		lastSeen = time(),
		weekStart = self:GetWeekStartTime(),
	}

	-- Vault progress
	if addon.WeeklyTracker then
		snapshot.vault = addon.WeeklyTracker:GetVaultProgress()
	end

	-- Currency earnings
	snapshot.currencies = {}
	if addon.Tracker then
		-- Get key currencies
		local keyCurrencies = {2815, 3008, 3285, 3288, 3289, 3290} -- Resonance, Valorstones, Crests
		for _, currencyID in ipairs(keyCurrencies) do
			local cached = addon.Tracker:GetCurrency(currencyID)
			if cached then
				snapshot.currencies[currencyID] = {
					amount = cached.quantity,
					earnedThisWeek = cached.quantityEarnedThisWeek,
				}
			end
		end
	end

	-- Raid lockouts
	if addon.WeeklyTracker then
		snapshot.raids = addon.WeeklyTracker:GetAllRaidLockouts()
	end

	-- World bosses
	if addon.WeeklyTracker then
		snapshot.worldBosses = addon.WeeklyTracker:GetAllWorldBosses()
	end

	-- Cooldowns
	if addon.CooldownTracker then
		snapshot.cooldowns = {
			catalyst = addon.CooldownTracker:GetCatalystCharges(),
		}
	end

	-- Mythic+ data
	if addon.MythicPlusTracker then
		snapshot.mythicplus = addon.MythicPlusTracker:GetSnapshotData()
	end

	-- Calculate completion percentage
	snapshot.completionPercent = self:CalculateCompletionPercent(snapshot)

	-- Save snapshot
	addon.db.alts[key] = snapshot

	addon.Utils:Debug(format("Saved snapshot for %s", key))
end

-- Calculate weekly completion percentage for a character
function AltManager:CalculateCompletionPercent(snapshot)
	local points = 0
	local maxPoints = 0

	-- Vault progress (30 points max - 10 per category)
	if snapshot.vault then
		maxPoints = maxPoints + 30
		local vaultTypes = {"raid", "mythicplus", "world"}
		for _, vType in ipairs(vaultTypes) do
			if snapshot.vault[vType] then
				local current = snapshot.vault[vType].current or 0
				local max = 8
				points = points + (current / max) * 10
			end
		end
	end

	-- Raid lockouts (20 points max)
	if snapshot.raids then
		maxPoints = maxPoints + 20
		local totalBosses = 0
		local killedBosses = 0
		for instanceID, difficulties in pairs(snapshot.raids) do
			for diffID, lockout in pairs(difficulties) do
				totalBosses = totalBosses + (lockout.numEncounters or 0)
				killedBosses = killedBosses + (lockout.encounterProgress or 0)
			end
		end
		if totalBosses > 0 then
			points = points + (killedBosses / totalBosses) * 20
		end
	end

	-- World bosses (10 points max)
	if snapshot.worldBosses then
		maxPoints = maxPoints + 10
		local total = 0
		local completed = 0
		for questID, boss in pairs(snapshot.worldBosses) do
			total = total + 1
			if boss.completed then
				completed = completed + 1
			end
		end
		if total > 0 then
			points = points + (completed / total) * 10
		end
	end

	if maxPoints == 0 then return 0 end
	return (points / maxPoints) * 100
end

-- Get week start time (for weekly reset tracking)
function AltManager:GetWeekStartTime()
	-- US region resets on Tuesday at 15:00 UTC
	-- EU region resets on Wednesday at 07:00 UTC
	local serverTime = GetServerTime()
	local region = GetCVar("portal") or "US"

	local weekday = date("%w", serverTime) -- 0 = Sunday, 1 = Monday, etc.
	local resetDay = (region == "EU") and 3 or 2

	-- Calculate days since last reset
	local daysSinceReset = (weekday - resetDay + 7) % 7

	return serverTime - (daysSinceReset * 24 * 60 * 60)
end

-- Clean up snapshots older than 2 weeks
function AltManager:CleanOldSnapshots()
	if not addon.db or not addon.db.alts then return end

	local cutoff = time() - (14 * 24 * 60 * 60) -- 2 weeks ago

	for key, snapshot in pairs(addon.db.alts) do
		if snapshot.lastSeen and snapshot.lastSeen < cutoff then
			addon.db.alts[key] = nil
			addon.Utils:Debug(format("Cleaned old snapshot: %s", key))
		end
	end
end

-- Get all alts
function AltManager:GetAllAlts()
	if not addon.db or not addon.db.alts then return {} end
	return addon.db.alts
end

-- Get specific alt data
function AltManager:GetAltData(realmChar)
	if not addon.db or not addon.db.alts then return nil end
	return addon.db.alts[realmChar]
end

-- Delete a specific alt (optionally blacklist to prevent re-tracking)
function AltManager:DeleteAlt(realmChar, addToBlacklist)
	if not addon.db or not addon.db.alts then return false end

	if addon.db.alts[realmChar] then
		addon.db.alts[realmChar] = nil
		addon.Utils:Debug(format("Deleted alt: %s", realmChar))

		-- Optionally add to blacklist
		if addToBlacklist then
			self:BlacklistAlt(realmChar)
		end

		return true
	end

	return false
end

-- Add character to blacklist (prevents auto-tracking)
function AltManager:BlacklistAlt(realmChar)
	if not addon.db or not addon.db.altBlacklist then
		addon.db.altBlacklist = {}
	end

	addon.db.altBlacklist[realmChar] = true
	addon.Utils:Debug(format("Blacklisted alt: %s", realmChar))
end

-- Remove character from blacklist (allows tracking again)
function AltManager:UnblacklistAlt(realmChar)
	if not addon.db or not addon.db.altBlacklist then return end

	addon.db.altBlacklist[realmChar] = nil
	addon.Utils:Debug(format("Removed from blacklist: %s", realmChar))
end

-- Check if character is blacklisted
function AltManager:IsBlacklisted(realmChar)
	if not addon.db or not addon.db.altBlacklist then return false end
	return addon.db.altBlacklist[realmChar] == true
end

-- Get all blacklisted characters
function AltManager:GetBlacklist()
	if not addon.db or not addon.db.altBlacklist then return {} end
	return addon.db.altBlacklist
end

-- Get account-wide currency total
function AltManager:GetAccountCurrencyTotal(currencyID)
	if not addon.db or not addon.db.alts then return 0 end

	local total = 0

	for key, alt in pairs(addon.db.alts) do
		if alt.currencies and alt.currencies[currencyID] then
			total = total + (alt.currencies[currencyID].amount or 0)
		end
	end

	return total
end

-- Get alts with incomplete vault slots
function AltManager:GetVaultEligibleAlts()
	if not addon.db or not addon.db.alts then return {} end

	local eligible = {}

	for key, alt in pairs(addon.db.alts) do
		if alt.vault then
			local hasIncompleteSlot = false

			local vaultTypes = {"raid", "mythicplus", "world"}
			for _, vType in ipairs(vaultTypes) do
				if alt.vault[vType] then
					local current = alt.vault[vType].current or 0
					local thresholds = alt.vault[vType].thresholds or {3, 5, 8}

					-- Check if any slot incomplete
					for _, threshold in ipairs(thresholds) do
						if current < threshold then
							hasIncompleteSlot = true
							break
						end
					end
				end
			end

			if hasIncompleteSlot then
				table.insert(eligible, {
					key = key,
					data = alt,
				})
			end
		end
	end

	return eligible
end

-- Sort alts by criteria
function AltManager:SortAlts(alts, sortOrder)
	sortOrder = sortOrder or "completion"

	if sortOrder == "completion" then
		-- Sort by completion percentage (highest first)
		table.sort(alts, function(a, b)
			local aPercent = a.completionPercent or 0
			local bPercent = b.completionPercent or 0
			return aPercent > bPercent
		end)
	elseif sortOrder == "name" then
		-- Sort alphabetically by name
		table.sort(alts, function(a, b)
			return a.name < b.name
		end)
	elseif sortOrder == "vault" then
		-- Sort by vault completion (most incomplete first)
		table.sort(alts, function(a, b)
			local aVault = self:GetVaultSlotCount(a)
			local bVault = self:GetVaultSlotCount(b)
			return aVault < bVault -- Less complete = higher priority
		end)
	elseif sortOrder == "ilvl" then
		-- Sort by item level (highest first)
		table.sort(alts, function(a, b)
			local aIlvl = (a.mythicplus and a.mythicplus.itemLevel) or 0
			local bIlvl = (b.mythicplus and b.mythicplus.itemLevel) or 0
			return aIlvl > bIlvl
		end)
	elseif sortOrder == "rating" then
		-- Sort by M+ rating (highest first)
		table.sort(alts, function(a, b)
			local aRating = (a.mythicplus and a.mythicplus.rating) or 0
			local bRating = (b.mythicplus and b.mythicplus.rating) or 0
			return aRating > bRating
		end)
	end

	return alts
end

-- Get total vault slots unlocked for an alt
function AltManager:GetVaultSlotCount(alt)
	if not alt.vault then return 0 end

	local total = 0
	local vaultTypes = {"raid", "mythicplus", "world"}

	for _, vType in ipairs(vaultTypes) do
		if alt.vault[vType] then
			local current = alt.vault[vType].current or 0
			local thresholds = alt.vault[vType].thresholds or {3, 5, 8}

			for _, threshold in ipairs(thresholds) do
				if current >= threshold then
					total = total + 1
				end
			end
		end
	end

	return total
end

-- Get alts as sorted array
function AltManager:GetSortedAlts(sortOrder)
	local alts = {}

	for key, data in pairs(self:GetAllAlts()) do
		table.insert(alts, data)
	end

	return self:SortAlts(alts, sortOrder)
end
