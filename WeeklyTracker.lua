local addonName, addon = ...

-- WeeklyTracker module: tracks raid lockouts, vault progress, world bosses, weekly quests
addon.WeeklyTracker = {}
local WeeklyTracker = addon.WeeklyTracker

-- Cache for weekly data
WeeklyTracker.raidLockouts = {}
WeeklyTracker.worldBosses = {}
WeeklyTracker.weeklyQuests = {}
WeeklyTracker.vaultProgress = nil
WeeklyTracker.lastLockoutUpdate = 0

-- Raid instance IDs (War Within and recent expansions)
local RAID_INSTANCES = {
	-- War Within
	{id = 1273, name = "Nerub-ar Palace", expansion = "War Within"},
	{id = 1296, name = "Liberation of Undermine", expansion = "War Within"},
	-- Dragonflight
	{id = 1200, name = "Vault of the Incarnates", expansion = "Dragonflight"},
	{id = 1207, name = "Aberrus, the Shadowed Crucible", expansion = "Dragonflight"},
	{id = 1208, name = "Amirdrassil, the Dream's Hope", expansion = "Dragonflight"},
}

-- Difficulty IDs
local DIFFICULTY = {
	LFR = 17,
	NORMAL = 14,
	HEROIC = 15,
	MYTHIC = 16,
}

-- World boss quest IDs (War Within - rotating weekly)
local WORLD_BOSS_QUESTS = {
	{questID = 81630, name = "Kordac, the Dormant Protector", zone = "Isle of Dorn", expansion = "War Within"},
	{questID = 82653, name = "Aggregation of Horrors", zone = "Ringing Deeps", expansion = "War Within"},
	{questID = 81653, name = "Shurrai, Atrocity of the Undersea", zone = "Hallowfall", expansion = "War Within"},
	{questID = 81624, name = "Orta, the Broken Mountain", zone = "Azj-Kahet", expansion = "War Within"},
}

-- Weekly quest IDs (War Within)
local WEEKLY_QUESTS = {
	-- Worldsoul Weeklies (Call of the Worldsoul - choose 1 per week)
	{questID = 82449, name = "The Call of the Worldsoul", category = "Worldsoul", expansion = "War Within"},
	{questID = 82452, name = "Worldsoul: World Quests", category = "Worldsoul", expansion = "War Within"},
	{questID = 82482, name = "Worldsoul: Snuffling", category = "Worldsoul", expansion = "War Within"},
	{questID = 82453, name = "Worldsoul: Encore!", category = "Worldsoul", expansion = "War Within"},
	{questID = 82511, name = "Worldsoul: Awakening Machine", category = "Worldsoul", expansion = "War Within"},
	{questID = 82512, name = "Worldsoul: World Boss", category = "Worldsoul", expansion = "War Within"},
	{questID = 87417, name = "Worldsoul: Dungeons", category = "Worldsoul", expansion = "War Within"},
	{questID = 87419, name = "Worldsoul: Delves", category = "Worldsoul", expansion = "War Within"},

	-- Zone Event Weeklies
	{questID = 83240, name = "The Theater Troupe", category = "Zone Event", zone = "Isle of Dorn", expansion = "War Within"},
	{questID = 76586, name = "Spreading the Light", category = "Zone Event", zone = "Hallowfall", expansion = "War Within"},
}

-- Initialize weekly tracker
function WeeklyTracker:Initialize()
	-- Request saved instance info on login
	RequestRaidInfo()

	-- Initial update
	self:UpdateRaidLockouts()
	self:UpdateVaultProgress()
	self:UpdateWorldBosses()
	self:UpdateWeeklyQuests()

	-- Set up periodic update timer (60 seconds for lockouts - optimized for performance)
	self.updateTimer = 0
	local updateFrame = CreateFrame("Frame")
	updateFrame:SetScript("OnUpdate", function(self, elapsed)
		WeeklyTracker.updateTimer = WeeklyTracker.updateTimer + elapsed
		if WeeklyTracker.updateTimer >= 60 then
			-- Only update if APIs are available
			if GetNumSavedInstances and GetSavedInstanceInfo then
				WeeklyTracker:UpdateRaidLockouts()
			end
			if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
				WeeklyTracker:UpdateWorldBosses()
				WeeklyTracker:UpdateWeeklyQuests()
			end
			WeeklyTracker.updateTimer = 0
		end
	end)

	addon.Utils:Debug("WeeklyTracker initialized")
end

-- Update raid lockout data
function WeeklyTracker:UpdateRaidLockouts()
	-- API availability check
	if not GetNumSavedInstances or not GetSavedInstanceInfo then
		addon.Utils:Debug("WeeklyTracker: Raid lockout APIs not available")
		return
	end

	-- Clear old lockouts
	self.raidLockouts = {}

	-- Scan saved instances
	local numSaved = GetNumSavedInstances()
	for i = 1, numSaved do
		local name, id, reset, difficultyID, locked, extended, instanceIDMostSig, isRaid, maxPlayers, difficultyName, numEncounters, encounterProgress = GetSavedInstanceInfo(i)

		-- Only track raids (not dungeons)
		if isRaid and locked then
			if not self.raidLockouts[id] then
				self.raidLockouts[id] = {}
			end

			self.raidLockouts[id][difficultyID] = {
				name = name,
				reset = reset,
				locked = locked,
				extended = extended,
				numEncounters = numEncounters,
				encounterProgress = encounterProgress,
				difficultyName = difficultyName,
				maxPlayers = maxPlayers,
			}
		end
	end

	self.lastLockoutUpdate = time()
end

-- Get raid lockout for specific instance and difficulty
function WeeklyTracker:GetRaidLockout(instanceID, difficultyID)
	if not self.raidLockouts[instanceID] then
		return nil
	end
	return self.raidLockouts[instanceID][difficultyID]
end

-- Get all raid lockouts
function WeeklyTracker:GetAllRaidLockouts()
	return self.raidLockouts
end

-- Update Great Vault progress (delegate to Tracker module which already handles this)
function WeeklyTracker:UpdateVaultProgress()
	if not C_WeeklyRewards then return end

	-- Use existing vault tracking from Tracker module
	self.vaultProgress = addon.Tracker and addon.Tracker:GetGreatVaultProgress()
end

-- Get Great Vault progress
function WeeklyTracker:GetVaultProgress()
	return self.vaultProgress
end

-- Update world boss completion status
function WeeklyTracker:UpdateWorldBosses()
	if not C_QuestLog or not C_QuestLog.IsQuestFlaggedCompleted then return end

	self.worldBosses = {}

	for _, boss in ipairs(WORLD_BOSS_QUESTS) do
		local completed = C_QuestLog.IsQuestFlaggedCompleted(boss.questID)
		self.worldBosses[boss.questID] = {
			name = boss.name,
			expansion = boss.expansion,
			completed = completed,
			questID = boss.questID,
		}
	end
end

-- Get world boss status
function WeeklyTracker:GetWorldBossStatus(questID)
	return self.worldBosses[questID]
end

-- Get all world boss statuses
function WeeklyTracker:GetAllWorldBosses()
	return self.worldBosses
end

-- Update weekly quest completion status
function WeeklyTracker:UpdateWeeklyQuests()
	if not C_QuestLog or not C_QuestLog.IsQuestFlaggedCompleted then return end

	for _, quest in ipairs(WEEKLY_QUESTS) do
		local completed = C_QuestLog.IsQuestFlaggedCompleted(quest.questID)
		self.weeklyQuests[quest.questID] = {
			name = quest.name,
			category = quest.category,
			zone = quest.zone,
			expansion = quest.expansion,
			completed = completed,
			questID = quest.questID,
		}
	end
end

-- Get weekly quest status
function WeeklyTracker:GetWeeklyQuestStatus(questID)
	return self.weeklyQuests[questID]
end

-- Get all weekly quests
function WeeklyTracker:GetAllWeeklyQuests()
	return self.weeklyQuests
end

-- Get weekly quests by category
function WeeklyTracker:GetWeeklyQuestsByCategory(category)
	local quests = {}
	for questID, quest in pairs(self.weeklyQuests) do
		if quest.category == category then
			table.insert(quests, quest)
		end
	end
	return quests
end

-- Get incomplete weekly quests count
function WeeklyTracker:GetIncompleteWeeklyQuestsCount()
	local count = 0
	for questID, quest in pairs(self.weeklyQuests) do
		if not quest.completed then
			count = count + 1
		end
	end
	return count
end

-- Event handler: encounter ended (boss kill)
function WeeklyTracker:OnEncounterEnd(encounterID, encounterName, difficultyID, groupSize, success)
	if not success then return end

	-- Raid boss killed, request updated lockout info
	RequestRaidInfo()

	-- Update lockouts after short delay (API needs time to update)
	C_Timer.After(2, function()
		self:UpdateRaidLockouts()
	end)

	addon.Utils:Debug(format("Encounter ended: %s (%d) - Difficulty %d - Success: %s",
		encounterName or "Unknown", encounterID or 0, difficultyID or 0, tostring(success)))
end

-- Get weekly reset time remaining
function WeeklyTracker:GetTimeUntilReset()
	-- Use Data module's existing function if available
	if addon.Data and addon.Data.GetTimeUntilWeeklyReset then
		return addon.Data:GetTimeUntilWeeklyReset()
	end

	-- Fallback: calculate manually
	local serverTime = GetServerTime()
	local resetTime = GetServerTime() -- Would need proper calculation
	return resetTime - serverTime
end

-- Get all weekly tracking data (for checklist/dashboard)
function WeeklyTracker:GetAllWeeklyData()
	return {
		raidLockouts = self.raidLockouts,
		worldBosses = self.worldBosses,
		weeklyQuests = self.weeklyQuests,
		vaultProgress = self.vaultProgress,
		lastUpdate = self.lastLockoutUpdate,
		timeUntilReset = self:GetTimeUntilReset(),
	}
end

-- Check if any raid has incomplete lockouts
function WeeklyTracker:HasIncompleteRaids()
	for instanceID, difficulties in pairs(self.raidLockouts) do
		for diffID, lockout in pairs(difficulties) do
			if lockout.encounterProgress < lockout.numEncounters then
				return true
			end
		end
	end
	return false
end

-- Get raid completion percentage across all difficulties
function WeeklyTracker:GetRaidCompletionPercent()
	local totalBosses = 0
	local killedBosses = 0

	for instanceID, difficulties in pairs(self.raidLockouts) do
		for diffID, lockout in pairs(difficulties) do
			totalBosses = totalBosses + lockout.numEncounters
			killedBosses = killedBosses + lockout.encounterProgress
		end
	end

	if totalBosses == 0 then return 0 end
	return (killedBosses / totalBosses) * 100
end

-- Get incomplete world bosses count
function WeeklyTracker:GetIncompleteWorldBossCount()
	local count = 0
	for questID, boss in pairs(self.worldBosses) do
		if not boss.completed then
			count = count + 1
		end
	end
	return count
end
