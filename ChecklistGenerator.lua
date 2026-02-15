local addonName, addon = ...

-- ChecklistGenerator module: generates prioritized todo lists from tracking data
addon.ChecklistGenerator = {}
local ChecklistGenerator = addon.ChecklistGenerator

-- Priority thresholds
local PRIORITY = {
	HIGH = 40,
	MEDIUM = 20,
	LOW = 0,
}

-- Initialize checklist generator
function ChecklistGenerator:Initialize()
	addon.Utils:Debug("ChecklistGenerator initialized")
end

-- Generate complete checklist from all tracking sources
function ChecklistGenerator:GenerateChecklist()
	local tasks = {}

	-- Validate tracking modules are available
	if not addon.WeeklyTracker and not addon.UpgradeTracker and not addon.CooldownTracker then
		addon.Utils:Debug("ChecklistGenerator: No tracking modules available")
		return tasks
	end

	-- Add vault tasks
	self:AddVaultTasks(tasks)
	addon.Utils:Debug(format("After vault tasks: %d", #tasks))

	-- Add world boss tasks
	self:AddWorldBossTasks(tasks)
	addon.Utils:Debug(format("After world boss tasks: %d", #tasks))

	-- Add upgrade tasks
	self:AddUpgradeTasks(tasks)
	addon.Utils:Debug(format("After upgrade tasks: %d", #tasks))

	-- Add catalyst tasks
	self:AddCatalystTasks(tasks)
	addon.Utils:Debug(format("After catalyst tasks: %d", #tasks))

	-- Add crafting cooldown tasks
	self:AddCraftingTasks(tasks)
	addon.Utils:Debug(format("After crafting tasks: %d", #tasks))

	-- Sort by priority (highest first)
	table.sort(tasks, function(a, b)
		if a.priority == b.priority then
			return a.subject < b.subject -- Alphabetical if same priority
		end
		return a.priority > b.priority
	end)

	return tasks
end

-- Add Great Vault tasks
function ChecklistGenerator:AddVaultTasks(tasks)
	if not addon.WeeklyTracker then return end

	local vaultData = addon.WeeklyTracker:GetVaultProgress()
	if not vaultData then return end

	local vaultTypes = {
		{name = "Raid", data = vaultData.raid, activity = "raid boss"},
		{name = "Mythic+", data = vaultData.mythicplus, activity = "Mythic+ dungeon"},
		{name = "Delve", data = vaultData.world, activity = "Delve"},
	}

	for _, vaultType in ipairs(vaultTypes) do
		if vaultType.data then
			local current = vaultType.data.current or 0
			local thresholds = vaultType.data.thresholds or {3, 5, 8}

			-- Find next incomplete threshold
			local nextThreshold = nil
			local slotsUnlocked = 0

			for i, threshold in ipairs(thresholds) do
				if current >= threshold then
					slotsUnlocked = slotsUnlocked + 1
				else
					nextThreshold = threshold
					break
				end
			end

			-- If not all slots unlocked, add task
			if nextThreshold then
				local remaining = nextThreshold - current
				local priority = self:GetVaultTaskPriority(slotsUnlocked, remaining)

				table.insert(tasks, {
					type = "vault",
					vaultType = vaultType.name,
					subject = format("Complete %s for Great Vault", vaultType.activity),
					description = format("Complete %d more %s to unlock vault slot %d", remaining, vaultType.activity, slotsUnlocked + 1),
					reason = format("Unlocks Great Vault %s slot %d (rewards gear)", vaultType.name, slotsUnlocked + 1),
					priority = priority,
					priorityLabel = self:GetPriorityLabel(priority),
					progress = {current = current, max = nextThreshold},
					completed = false,
				})
			end
		end
	end
end

-- Get vault task priority based on slot and remaining
function ChecklistGenerator:GetVaultTaskPriority(slotsUnlocked, remaining)
	-- Slot 3 (highest reward) = highest priority
	-- Close to completion = higher priority
	local basePriority = (3 - slotsUnlocked) * 15 -- 45, 30, 15 for slots 1, 2, 3

	-- Bonus for being close to completion
	if remaining <= 1 then
		basePriority = basePriority + 10
	elseif remaining <= 2 then
		basePriority = basePriority + 5
	end

	return basePriority
end

-- Add world boss tasks
function ChecklistGenerator:AddWorldBossTasks(tasks)
	if not addon.WeeklyTracker then return end

	local worldBosses = addon.WeeklyTracker:GetAllWorldBosses()
	if not worldBosses then return end

	for questID, boss in pairs(worldBosses) do
		if not boss.completed then
			table.insert(tasks, {
				type = "worldboss",
				questID = questID,
				subject = format("Kill %s", boss.name or "World Boss"),
				description = format("Defeat the weekly world boss: %s", boss.name or "Unknown"),
				reason = "Awards currency and potential gear",
				priority = 25, -- MEDIUM priority
				priorityLabel = "MEDIUM",
				completed = false,
			})
		end
	end
end

-- Add upgrade tasks
function ChecklistGenerator:AddUpgradeTasks(tasks)
	if not addon.UpgradeTracker then return end

	local summary = addon.UpgradeTracker:GetUpgradeSummary()
	if not summary then return end

	-- Task for ready upgrades (have crests available)
	if summary.readyToUpgrade > 0 then
		table.insert(tasks, {
			type = "upgrade",
			subject = format("Upgrade %d item%s", summary.readyToUpgrade, summary.readyToUpgrade > 1 and "s" or ""),
			description = format("You have crests to upgrade %d equipped item%s", summary.readyToUpgrade, summary.readyToUpgrade > 1 and "s" or ""),
			reason = format("Increase item level with available crests (%d items ready)", summary.readyToUpgrade),
			priority = 45, -- HIGH priority (have materials, easy to do)
			priorityLabel = "HIGH",
			completed = false,
		})
	end

	-- Task for wasting caps
	if summary.wastingCaps then
		table.insert(tasks, {
			type = "upgrade_caps",
			subject = "Spend crests before cap",
			description = "You're at or near crest cap with upgradeable items",
			reason = "Wasting potential crest earnings by staying at cap",
			priority = 50, -- HIGH priority (wasting resources)
			priorityLabel = "HIGH",
			completed = false,
		})
	end
end

-- Add catalyst tasks
function ChecklistGenerator:AddCatalystTasks(tasks)
	if not addon.CooldownTracker then return end

	local catalystData = addon.CooldownTracker:GetCatalystCharges()
	if not catalystData then return end

	-- If catalyst charges available
	if catalystData.charges > 0 then
		table.insert(tasks, {
			type = "catalyst",
			subject = format("Use Catalyst (%d charge%s)", catalystData.charges, catalystData.charges > 1 and "s" or ""),
			description = format("Convert items to tier set pieces using %d available catalyst charge%s", catalystData.charges, catalystData.charges > 1 and "s" or ""),
			reason = format("Create tier set pieces for set bonuses (%d charges ready)", catalystData.charges),
			priority = 30, -- MEDIUM priority
			priorityLabel = "MEDIUM",
			completed = false,
		})
	end
end

-- Add crafting cooldown tasks
function ChecklistGenerator:AddCraftingTasks(tasks)
	if not addon.CooldownTracker then return end

	local cooldowns = addon.CooldownTracker:GetAllCooldowns()
	if not cooldowns then return end

	local readyCount = 0
	local readySpells = {}

	for spellID, cooldown in pairs(cooldowns) do
		if cooldown.ready then
			readyCount = readyCount + 1
			table.insert(readySpells, cooldown.name)
		end
	end

	-- If any crafting cooldowns ready
	if readyCount > 0 then
		table.insert(tasks, {
			type = "crafting",
			subject = format("Use crafting cooldown%s (%d ready)", readyCount > 1 and "s" or "", readyCount),
			description = format("Profession cooldowns ready: %s", table.concat(readySpells, ", ")),
			reason = format("%d profession cooldown%s available", readyCount, readyCount > 1 and "s" or ""),
			priority = 15, -- LOW-MEDIUM priority
			priorityLabel = "LOW",
			completed = false,
		})
	end
end

-- Get priority label from numeric priority
function ChecklistGenerator:GetPriorityLabel(priority)
	if priority >= PRIORITY.HIGH then
		return "HIGH"
	elseif priority >= PRIORITY.MEDIUM then
		return "MEDIUM"
	else
		return "LOW"
	end
end

-- Get task priority (for external use)
function ChecklistGenerator:GetTaskPriority(task)
	return task.priority or 0
end

-- Get task reason (for tooltips)
function ChecklistGenerator:GetTaskReason(task)
	return task.reason or "No reason provided"
end

-- Filter out completed tasks
function ChecklistGenerator:FilterCompleted(tasks)
	local filtered = {}
	for _, task in ipairs(tasks) do
		if not task.completed then
			table.insert(filtered, task)
		end
	end
	return filtered
end

-- Sort tasks by value/priority
function ChecklistGenerator:SortByValue(tasks)
	table.sort(tasks, function(a, b)
		return (a.priority or 0) > (b.priority or 0)
	end)
	return tasks
end

-- Sort tasks alphabetically
function ChecklistGenerator:SortAlphabetically(tasks)
	table.sort(tasks, function(a, b)
		return a.subject < b.subject
	end)
	return tasks
end

-- Get checklist with filtering and sorting
function ChecklistGenerator:GetChecklist(options)
	options = options or {}

	local tasks = self:GenerateChecklist()

	-- Filter completed if requested
	if options.autoHideCompleted then
		tasks = self:FilterCompleted(tasks)
	end

	-- Sort by priority or alphabetically
	if options.sortBy == "alphabetical" then
		tasks = self:SortAlphabetically(tasks)
	else
		tasks = self:SortByValue(tasks)
	end

	return tasks
end
