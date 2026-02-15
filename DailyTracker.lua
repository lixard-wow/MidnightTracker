local addonName, addon = ...

-- DailyTracker module: tracks daily quests and Special Assignments
addon.DailyTracker = {}
local DailyTracker = addon.DailyTracker

-- Special Assignment quest IDs (rotating, one active per day)
local SPECIAL_ASSIGNMENTS = {
	{questID = 82355, name = "Cinderbee Surge", zone = "Isle of Dorn", expansion = "War Within"},
	{questID = 81649, name = "Titanic Resurgence", zone = "Isle of Dorn", expansion = "War Within"},
	{questID = 81691, name = "Shadows Below", zone = "Ringing Deeps", expansion = "War Within"},
	{questID = 83229, name = "When the Deeps Stir", zone = "Ringing Deeps", expansion = "War Within"},
	{questID = 82852, name = "Lynx Rescue", zone = "Hallowfall", expansion = "War Within"},
	{questID = 82787, name = "Rise of the Colossals", zone = "Hallowfall", expansion = "War Within"},
	{questID = 82531, name = "A Pound of Cure", zone = "Azj-Kahet", expansion = "War Within"},
	{questID = 82414, name = "Bombs from Behind", zone = "Azj-Kahet", expansion = "War Within"},
}

-- Cache for daily data
DailyTracker.specialAssignments = {}
DailyTracker.dailyQuests = {}

-- Initialize daily tracker
function DailyTracker:Initialize()
	-- Initial update
	self:UpdateSpecialAssignments()

	-- Set up periodic update timer (60 seconds)
	self.updateTimer = 0
	local updateFrame = CreateFrame("Frame")
	updateFrame:SetScript("OnUpdate", function(self, elapsed)
		DailyTracker.updateTimer = DailyTracker.updateTimer + elapsed
		if DailyTracker.updateTimer >= 60 then
			if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
				DailyTracker:UpdateSpecialAssignments()
			end
			DailyTracker.updateTimer = 0
		end
	end)

	addon.Utils:Debug("DailyTracker initialized")
end

-- Update Special Assignment completion status
function DailyTracker:UpdateSpecialAssignments()
	if not C_QuestLog or not C_QuestLog.IsQuestFlaggedCompleted then return end

	self.specialAssignments = {}

	for _, assignment in ipairs(SPECIAL_ASSIGNMENTS) do
		local completed = C_QuestLog.IsQuestFlaggedCompleted(assignment.questID)
		self.specialAssignments[assignment.questID] = {
			name = assignment.name,
			zone = assignment.zone,
			expansion = assignment.expansion,
			completed = completed,
			questID = assignment.questID,
		}
	end
end

-- Get Special Assignment status
function DailyTracker:GetSpecialAssignment(questID)
	return self.specialAssignments[questID]
end

-- Get all Special Assignments
function DailyTracker:GetAllSpecialAssignments()
	return self.specialAssignments
end

-- Get active Special Assignment (if any)
function DailyTracker:GetActiveSpecialAssignment()
	-- Find the first incomplete assignment (only one is active at a time)
	for _, assignment in pairs(self.specialAssignments) do
		if not assignment.completed then
			return assignment
		end
	end
	return nil
end

-- Get incomplete Special Assignments count
function DailyTracker:GetIncompleteSpecialAssignmentCount()
	local count = 0
	for questID, assignment in pairs(self.specialAssignments) do
		if not assignment.completed then
			count = count + 1
		end
	end
	return count
end

-- Get all daily tracking data (for checklist/dashboard)
function DailyTracker:GetAllDailyData()
	return {
		specialAssignments = self.specialAssignments,
		activeAssignment = self:GetActiveSpecialAssignment(),
		incompleteCount = self:GetIncompleteSpecialAssignmentCount(),
	}
end

-- Event handler: quest turned in
function DailyTracker:OnQuestTurnedIn(questID)
	-- Check if this was a Special Assignment
	if self.specialAssignments[questID] then
		-- Update after short delay (API needs time to update)
		C_Timer.After(1, function()
			self:UpdateSpecialAssignments()

			-- Update display
			if addon.Display and addon.Display.UpdateDisplay then
				addon.Display:UpdateDisplay()
			end
		end)

		addon.Utils:Debug(format("Special Assignment completed: %d", questID))
	end
end
