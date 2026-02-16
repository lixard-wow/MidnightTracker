local addonName, addon = ...

-- MythicPlusTracker module: tracks M+ rating, keystones, and run history
addon.MythicPlusTracker = {}
local MythicPlusTracker = addon.MythicPlusTracker

-- Season identifier (update each season)
local CURRENT_SEASON = "tww-season-3"

-- TWW Season 3 Dungeon IDs (update for current season)
local SEASON_DUNGEONS = {
	-- Example IDs - these need to be updated with actual TWW S3 dungeon IDs
	{id = 507, name = "Ara-Kara, City of Echoes"},
	{id = 499, name = "Priory of the Sacred Flame"},
	{id = 501, name = "The Stonevault"},
	{id = 505, name = "The Dawnbreaker"},
	{id = 502, name = "City of Threads"},
	{id = 503, name = "Darkflame Cleft"},
	{id = 353, name = "Siege of Boralus"},
	{id = 375, name = "Mists of Tirna Scithe"},
	-- Add remaining dungeons
}

-- Cache for current character data
MythicPlusTracker.rating = 0
MythicPlusTracker.itemLevel = 0
MythicPlusTracker.currentKey = nil
MythicPlusTracker.dungeonData = {}
MythicPlusTracker.weeklyRuns = {}

-- Initialize tracker
function MythicPlusTracker:Initialize()
	-- Initial data load
	self:UpdateRating()
	self:UpdateItemLevel()
	self:UpdateCurrentKey()
	self:UpdateDungeonData()

	-- Set up periodic updates
	self.updateTimer = 0
	local updateFrame = CreateFrame("Frame")
	updateFrame:SetScript("OnUpdate", function(self, elapsed)
		MythicPlusTracker.updateTimer = MythicPlusTracker.updateTimer + elapsed
		if MythicPlusTracker.updateTimer >= 5 then
			-- Update every 5 seconds
			MythicPlusTracker:UpdateCurrentKey()
			MythicPlusTracker.updateTimer = 0
		end
	end)

	addon.Utils:Debug("MythicPlusTracker initialized")
end

-- Update M+ rating
function MythicPlusTracker:UpdateRating()
	if not C_PlayerInfo or not C_PlayerInfo.GetPlayerMythicPlusRatingSummary then
		self.rating = 0
		return
	end

	local summary = C_PlayerInfo.GetPlayerMythicPlusRatingSummary("player")
	if summary then
		self.rating = summary.currentSeasonScore or 0
	end
end

-- Update item level
function MythicPlusTracker:UpdateItemLevel()
	local avgItemLevel, avgItemLevelEquipped = GetAverageItemLevel()
	self.itemLevel = math.floor(avgItemLevelEquipped or 0)
end

-- Update current keystone
function MythicPlusTracker:UpdateCurrentKey()
	if not C_MythicPlus then
		self.currentKey = nil
		return
	end

	local mapID = C_MythicPlus.GetOwnedKeystoneChallengeMapID()
	local level = C_MythicPlus.GetOwnedKeystoneLevel()

	if mapID and level then
		local name = C_ChallengeMode.GetMapUIInfo(mapID)
		self.currentKey = {
			dungeonID = mapID,
			level = level,
			name = name or "Unknown Dungeon"
		}
	else
		self.currentKey = nil
	end
end

-- Update per-dungeon data
function MythicPlusTracker:UpdateDungeonData()
	if not C_MythicPlus or not C_MythicPlus.GetRunHistory then
		return
	end

	-- Don't track M+ for non-max level characters
	local maxLevel = GetMaxLevelForPlayerExpansion()
	local currentLevel = UnitLevel("player")
	if currentLevel < maxLevel then
		self.dungeonData = {}
		self.weeklyRuns = {}
		return
	end

	-- Get all-time run history for best tracking
	local allRunHistory = C_MythicPlus.GetRunHistory(true, true) -- includePreviousWeeks=true, includeIncomplete=true

	-- Get this week's runs for vault tracking
	local weeklyRunHistory = C_MythicPlus.GetRunHistory(false, true) -- includePreviousWeeks=false, includeIncomplete=true

	-- Initialize dungeon data structure
	self.dungeonData = {}
	self.weeklyRuns = {}

	for _, dungeon in ipairs(SEASON_DUNGEONS) do
		-- Get name from API instead of hardcoded list
		local apiName = C_ChallengeMode.GetMapUIInfo(dungeon.id)
		self.dungeonData[dungeon.id] = {
			name = apiName or dungeon.name,  -- Use API name, fallback to hardcoded
			fortified = {
				best = 0,
				bestUpgradeLevel = 0,
				bestTimed = 0,
				bestTimedUpgradeLevel = 0,
				rating = 0,
				weeklyRuns = {}
			},
			tyrannical = {
				best = 0,
				bestUpgradeLevel = 0,
				bestTimed = 0,
				bestTimedUpgradeLevel = 0,
				rating = 0,
				weeklyRuns = {}
			},
			seasonBest = 0,
			seasonBestUpgradeLevel = 0
		}
	end

	-- Process all-time run history for best tracking
	if allRunHistory then
		for _, run in ipairs(allRunHistory) do
			local mapID = run.mapChallengeModeID
			local level = run.level
			local completed = run.completed
			local isTyrannical = run.affixIDs and self:IsTyrannical(run.affixIDs)
			local affixKey = isTyrannical and "tyrannical" or "fortified"

			-- Calculate upgrade level (chests)
			local upgradeLevel = 0
			if completed then
				-- Default to 1 chest for any timed key
				upgradeLevel = 1

				-- Calculate actual chest level if timing data available
				if run.durationSec and run.completionMilliseconds then
					local timeTaken = run.completionMilliseconds / 1000
					local timeLimit = run.durationSec
					local timeRemaining = timeLimit - timeTaken
					local percentRemaining = (timeRemaining / timeLimit) * 100

					if percentRemaining >= 40 then
						upgradeLevel = 3  -- +++
					elseif percentRemaining >= 20 then
						upgradeLevel = 2  -- ++
					elseif percentRemaining > 0 then
						upgradeLevel = 1  -- +
					end
				end
			end

			-- Update dungeonData (best runs from all time)
			if self.dungeonData[mapID] then
				local affixData = self.dungeonData[mapID][affixKey]

				-- Update best
				if level > affixData.best then
					affixData.best = level
					affixData.bestUpgradeLevel = upgradeLevel
				end

				-- Update best timed
				if completed and level > affixData.bestTimed then
					affixData.bestTimed = level
					affixData.bestTimedUpgradeLevel = upgradeLevel
				end

				-- NOTE: Do NOT add to weeklyRuns here - this is all-time data
				-- weeklyRuns is populated separately from weeklyRunHistory below

				-- Update season best
				if level > self.dungeonData[mapID].seasonBest then
					self.dungeonData[mapID].seasonBest = level
					self.dungeonData[mapID].seasonBestUpgradeLevel = upgradeLevel
				end
			else
				-- Create dungeonData entry for dungeons not in SEASON_DUNGEONS
				-- ALWAYS get name from API, not hardcoded list
				local dungeonName = C_ChallengeMode.GetMapUIInfo(mapID)
				self.dungeonData[mapID] = {
					name = dungeonName or "Unknown Dungeon",
					fortified = {
						best = affixKey == "fortified" and level or 0,
						bestUpgradeLevel = affixKey == "fortified" and upgradeLevel or 0,
						bestTimed = (affixKey == "fortified" and completed) and level or 0,
						bestTimedUpgradeLevel = (affixKey == "fortified" and completed) and upgradeLevel or 0,
						rating = 0,
						weeklyRuns = {} -- Initialize empty - populated from weeklyRunHistory below
					},
					tyrannical = {
						best = affixKey == "tyrannical" and level or 0,
						bestUpgradeLevel = affixKey == "tyrannical" and upgradeLevel or 0,
						bestTimed = (affixKey == "tyrannical" and completed) and level or 0,
						bestTimedUpgradeLevel = (affixKey == "tyrannical" and completed) and upgradeLevel or 0,
						rating = 0,
						weeklyRuns = {} -- Initialize empty - populated from weeklyRunHistory below
					},
					seasonBest = level,
					seasonBestUpgradeLevel = upgradeLevel
				}
			end
		end
	end

	-- Process this week's runs for vault tracking
	if weeklyRunHistory then
		for _, run in ipairs(weeklyRunHistory) do
			local mapID = run.mapChallengeModeID
			local level = run.level
			local completed = run.completed
			local isTyrannical = run.affixIDs and self:IsTyrannical(run.affixIDs)
			local affixKey = isTyrannical and "tyrannical" or "fortified"

			-- Calculate upgrade level
			local upgradeLevel = 0
			if completed then
				upgradeLevel = 1
				if run.durationSec and run.completionMilliseconds then
					local timeTaken = run.completionMilliseconds / 1000
					local timeLimit = run.durationSec
					local timeRemaining = timeLimit - timeTaken
					local percentRemaining = (timeRemaining / timeLimit) * 100

					if percentRemaining >= 40 then
						upgradeLevel = 3
					elseif percentRemaining >= 20 then
						upgradeLevel = 2
					elseif percentRemaining > 0 then
						upgradeLevel = 1
					end
				end
			end

			-- Add to weeklyRuns for vault tracking
			table.insert(self.weeklyRuns, {
				mapID = mapID,
				level = level,
				completed = completed,
				affix = affixKey,
				upgradeLevel = upgradeLevel
			})
		end
	end

	-- Get rating per dungeon from API
	if C_PlayerInfo and C_PlayerInfo.GetPlayerMythicPlusRatingSummary then
		local summary = C_PlayerInfo.GetPlayerMythicPlusRatingSummary("player")
		if summary and summary.runs then
			for _, run in ipairs(summary.runs) do
				local mapID = run.challengeModeID
				if self.dungeonData[mapID] then
					-- API provides fort/tyrann ratings
					if run.finishedSuccess then
						local isTyrannical = run.isTyrannical
						local affixKey = isTyrannical and "tyrannical" or "fortified"
						self.dungeonData[mapID][affixKey].rating = run.mapScore or 0
					end
				end
			end
		end
	end
end

-- Check if affix set includes Tyrannical
function MythicPlusTracker:IsTyrannical(affixIDs)
	-- Tyrannical affix ID = 9, Fortified = 10
	for _, affixID in ipairs(affixIDs) do
		if affixID == 9 then
			return true
		end
	end
	return false
end

-- Get vault activity counts
function MythicPlusTracker:GetVaultActivityCounts()
	local total = #self.weeklyRuns
	local remaining = math.max(0, 8 - total) -- 8 keys for max vault

	return {
		activities = total,
		remaining = remaining
	}
end

-- Get snapshot data for alt manager
function MythicPlusTracker:GetSnapshotData()
	-- Don't save M+ data for non-max level characters
	local maxLevel = GetMaxLevelForPlayerExpansion()
	local currentLevel = UnitLevel("player")

	if currentLevel < maxLevel then
		-- Return empty data for non-max level characters
		return {
			season = CURRENT_SEASON,
			rating = 0,
			itemLevel = self.itemLevel,
			currentKey = nil,
			dungeons = {},
			weeklyVault = {activities = 0, remaining = 8},
			weeklyRuns = {}
		}
	end

	return {
		season = CURRENT_SEASON,
		rating = self.rating,
		itemLevel = self.itemLevel,
		currentKey = self.currentKey,
		dungeons = self.dungeonData,
		weeklyVault = self:GetVaultActivityCounts(),
		weeklyRuns = self.weeklyRuns  -- Include all runs with completion status
	}
end

-- Event: Challenge mode completed
function MythicPlusTracker:OnChallengeCompleted(mapID, level, success)
	-- Refresh data after completing a key
	C_Timer.After(1, function()
		self:UpdateRating()
		self:UpdateDungeonData()

		-- Update display
		if addon.Display and addon.Display.UpdateDisplay then
			addon.Display:UpdateDisplay()
		end
	end)
end

-- Event: Equipment changed (item level update)
function MythicPlusTracker:OnEquipmentChanged()
	self:UpdateItemLevel()
end

-- Get all data
function MythicPlusTracker:GetAllData()
	return {
		rating = self.rating,
		itemLevel = self.itemLevel,
		currentKey = self.currentKey,
		dungeons = self.dungeonData,
		weeklyRuns = self.weeklyRuns,
		vaultCounts = self:GetVaultActivityCounts()
	}
end

-- Get season dungeons list
function MythicPlusTracker:GetSeasonDungeons()
	return SEASON_DUNGEONS
end

-- Get rating color
function MythicPlusTracker:GetRatingColor(rating)
	if not C_ChallengeMode or not C_ChallengeMode.GetDungeonScoreRarityColor then
		return {1, 1, 1}
	end

	local color = C_ChallengeMode.GetDungeonScoreRarityColor(rating)
	if color then
		return {color.r, color.g, color.b}
	end
	return {1, 1, 1}
end
