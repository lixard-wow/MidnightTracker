local addonName, addon = ...

-- UpgradeTracker module: tracks item upgrade potential and crest needs
addon.UpgradeTracker = {}
local UpgradeTracker = addon.UpgradeTracker

-- Cache for upgrade data
UpgradeTracker.slots = {}
UpgradeTracker.lastFullScan = 0

-- Equipment slot IDs (1-19, excluding tabard/shirt)
local EQUIPMENT_SLOTS = {
	1,  -- Head
	2,  -- Neck
	3,  -- Shoulder
	5,  -- Chest
	6,  -- Waist
	7,  -- Legs
	8,  -- Feet
	9,  -- Wrist
	10, -- Hands
	11, -- Finger 1
	12, -- Finger 2
	13, -- Trinket 1
	14, -- Trinket 2
	15, -- Back
	16, -- Main Hand
	17, -- Off Hand
}

-- Upgrade track constants
-- NOTE: Midnight (12.0+) uses stat-squished item levels (203-289)
-- NOTE: War Within uses pre-squish item levels (642-723)
-- Auto-detect based on character's max item level
local function GetUpgradeTracks()
	-- Detect if we're in Midnight (max ilvl < 400 indicates stat squish)
	local avgItemLevel = GetAverageItemLevel()
	local isMidnight = (avgItemLevel and avgItemLevel < 400)

	if isMidnight then
		-- MIDNIGHT SEASON 1 (Dawncrests) - Item levels 203-289
		return {
			EXPLORER = {
				name = "Explorer",
				minLevel = 203,  -- Item level 203-226
				maxLevel = 226,
				crestID = nil,   -- No crests required
				upgradesPerCrest = 0,
			},
			ADVENTURER = {
				name = "Adventurer",
				minLevel = 224,  -- Item level 224-237
				maxLevel = 237,
				crestID = 3383,  -- Adventurer Dawncrest
				upgradesPerCrest = 15,
			},
			VETERAN = {
				name = "Veteran",
				minLevel = 237,  -- Item level 237-250
				maxLevel = 250,
				crestID = 3342,  -- Veteran Dawncrest
				upgradesPerCrest = 15,
			},
			CHAMPION = {
				name = "Champion",
				minLevel = 250,  -- Item level 250-263
				maxLevel = 263,
				crestID = 3343,  -- Champion Dawncrest
				upgradesPerCrest = 15,
			},
			HERO = {
				name = "Hero",
				minLevel = 263,  -- Item level 263-276
				maxLevel = 276,
				crestID = 3345,  -- Hero Dawncrest
				upgradesPerCrest = 15,
			},
			MYTH = {
				name = "Myth",
				minLevel = 276,  -- Item level 276-289
				maxLevel = 289,
				crestID = 3346,  -- Myth Dawncrest
				upgradesPerCrest = 0,
			},
		}
	else
		-- WAR WITHIN SEASON 3 (Ethereal Crests) - Item levels 642-723
		return {
			EXPLORER = {
				name = "Explorer",
				minLevel = 642,  -- Item level 642-665
				maxLevel = 665,
				crestID = nil,   -- No crests required
				upgradesPerCrest = 0,
			},
			ADVENTURER = {
				name = "Adventurer",
				minLevel = 655,  -- Item level 655-678
				maxLevel = 678,
				crestID = 3284,  -- Weathered Ethereal Crest
				upgradesPerCrest = 15,
			},
			VETERAN = {
				name = "Veteran",
				minLevel = 668,  -- Item level 668-691
				maxLevel = 691,
				crestID = 3286,  -- Carved Ethereal Crest
				upgradesPerCrest = 15,
			},
			CHAMPION = {
				name = "Champion",
				minLevel = 681,  -- Item level 681-704
				maxLevel = 704,
				crestID = 3288,  -- Runed Ethereal Crest
				upgradesPerCrest = 15,
			},
			HERO = {
				name = "Hero",
				minLevel = 694,  -- Item level 694-710
				maxLevel = 710,
				crestID = 3290,  -- Gilded Ethereal Crest
				upgradesPerCrest = 15,
			},
			MYTH = {
				name = "Myth",
				minLevel = 707,  -- Item level 707-723
				maxLevel = 723,
				crestID = nil,   -- Myth track uses different upgrade system
				upgradesPerCrest = 0,
			},
		}
	end
end

local UPGRADE_TRACKS = GetUpgradeTracks()

-- Initialize upgrade tracker
function UpgradeTracker:Initialize()
	-- Initial scan of all equipment
	self:UpdateAllSlots()

	addon.Utils:Debug("UpgradeTracker initialized")
end

-- Update all equipment slots
function UpgradeTracker:UpdateAllSlots()
	-- Refresh upgrade tracks for current expansion
	UPGRADE_TRACKS = GetUpgradeTracks()

	for _, slot in ipairs(EQUIPMENT_SLOTS) do
		self:UpdateSlot(slot)
	end
	self.lastFullScan = time()
end

-- Update single equipment slot
function UpgradeTracker:UpdateSlot(slot)
	-- API availability check
	if not GetInventoryItemLink or not GetDetailedItemLevelInfo or not GetItemInfoFromHyperlink then
		return
	end

	local itemLink = GetInventoryItemLink("player", slot)

	-- Validate item link before proceeding
	if not itemLink or itemLink == "" then
		self.slots[slot] = nil
		return
	end

	-- Parse item info
	local itemID = GetItemInfoFromHyperlink(itemLink)
	if not itemID then
		self.slots[slot] = nil
		return
	end

	-- Get detailed item level (includes upgrades)
	local currentLevel, _, baseLevel = GetDetailedItemLevelInfo(itemLink)
	if not currentLevel then
		self.slots[slot] = nil
		return
	end

	-- Determine upgrade track based on item level
	local track = self:DetermineUpgradeTrack(currentLevel)
	if not track then
		-- Item not upgradeable or at max level
		self.slots[slot] = nil
		return
	end

	-- Calculate crests needed for max upgrade
	local maxLevel = track.maxLevel
	local levelsRemaining = maxLevel - currentLevel
	local crestsNeeded = 0

	if track.crestID and track.upgradesPerCrest > 0 then
		crestsNeeded = math.ceil(levelsRemaining / track.upgradesPerCrest)
	end

	-- Store slot data
	self.slots[slot] = {
		itemID = itemID,
		itemLink = itemLink,
		currentLevel = currentLevel,
		baseLevel = baseLevel,
		maxLevel = maxLevel,
		track = track.name,
		crestID = track.crestID,
		crestsNeeded = crestsNeeded,
		levelsRemaining = levelsRemaining,
		canUpgrade = levelsRemaining > 0 and track.crestID ~= nil,
	}
end

-- Determine which upgrade track an item belongs to
function UpgradeTracker:DetermineUpgradeTrack(itemLevel)
	-- Check each track from highest to lowest
	local tracks = {
		UPGRADE_TRACKS.MYTH,
		UPGRADE_TRACKS.HERO,
		UPGRADE_TRACKS.CHAMPION,
		UPGRADE_TRACKS.VETERAN,
		UPGRADE_TRACKS.ADVENTURER,
		UPGRADE_TRACKS.EXPLORER,
	}

	for _, track in ipairs(tracks) do
		if itemLevel >= track.minLevel and itemLevel <= track.maxLevel then
			return track
		end
	end

	return nil -- Item not on an upgrade track
end

-- Get slot upgrade info
function UpgradeTracker:GetSlotInfo(slot)
	return self.slots[slot]
end

-- Get all slots with upgrade potential
function UpgradeTracker:GetUpgradeableSlots()
	local upgradeable = {}
	for slot, data in pairs(self.slots) do
		if data.canUpgrade then
			table.insert(upgradeable, {
				slot = slot,
				data = data,
			})
		end
	end
	return upgradeable
end

-- Get aggregated crest needs across all slots
function UpgradeTracker:GetCrestNeeds()
	local needs = {}

	for slot, data in pairs(self.slots) do
		if data.canUpgrade and data.crestID then
			if not needs[data.crestID] then
				needs[data.crestID] = {
					crestID = data.crestID,
					quantity = 0,
					track = data.track,
				}
			end
			needs[data.crestID].quantity = needs[data.crestID].quantity + data.crestsNeeded
		end
	end

	return needs
end

-- Check if player is wasting upgrade potential (at crest cap with upgradeable items)
function UpgradeTracker:IsWastingUpgrades()
	if not C_CurrencyInfo then return false end

	local crestNeeds = self:GetCrestNeeds()

	-- Check each crest type
	for crestID, need in pairs(crestNeeds) do
		if need.quantity > 0 then
			local info = C_CurrencyInfo.GetCurrencyInfo(crestID)
			if info and info.maxQuantity and info.maxQuantity > 0 then
				-- At or near cap (within 90%)
				if info.quantity >= (info.maxQuantity * 0.9) then
					return true
				end
			end
		end
	end

	return false
end

-- Get count of items ready to upgrade (have crests available)
function UpgradeTracker:GetReadyToUpgradeCount()
	if not C_CurrencyInfo then return 0 end

	local count = 0
	local crestInventory = {}

	-- Build crest inventory
	for _, track in pairs(UPGRADE_TRACKS) do
		if track.crestID then
			local info = C_CurrencyInfo.GetCurrencyInfo(track.crestID)
			if info then
				crestInventory[track.crestID] = info.quantity
			end
		end
	end

	-- Check each slot
	for slot, data in pairs(self.slots) do
		if data.canUpgrade and data.crestID then
			local available = crestInventory[data.crestID] or 0
			if available >= data.crestsNeeded then
				count = count + 1
			end
		end
	end

	return count
end

-- Get upgrade summary for display/checklist
function UpgradeTracker:GetUpgradeSummary()
	local upgradeableCount = 0
	local readyCount = self:GetReadyToUpgradeCount()
	local wastingCaps = self:IsWastingUpgrades()
	local crestNeeds = self:GetCrestNeeds()

	for slot, data in pairs(self.slots) do
		if data.canUpgrade then
			upgradeableCount = upgradeableCount + 1
		end
	end

	return {
		upgradeableItems = upgradeableCount,
		readyToUpgrade = readyCount,
		wastingCaps = wastingCaps,
		crestNeeds = crestNeeds,
		lastScan = self.lastFullScan,
	}
end

-- Get missing crests summary (for display)
function UpgradeTracker:GetMissingCrestsSummary()
	if not C_CurrencyInfo then return {} end

	local crestNeeds = self:GetCrestNeeds()
	local summary = {}

	for crestID, need in pairs(crestNeeds) do
		local info = C_CurrencyInfo.GetCurrencyInfo(crestID)
		if info then
			local missing = math.max(0, need.quantity - info.quantity)
			if missing > 0 then
				table.insert(summary, {
					crestID = crestID,
					name = info.name,
					needed = need.quantity,
					have = info.quantity,
					missing = missing,
					track = need.track,
				})
			end
		end
	end

	return summary
end
