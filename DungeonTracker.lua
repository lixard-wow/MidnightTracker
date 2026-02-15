local addonName, addon = ...

-- DungeonTracker module: per-dungeon tracking and cross-alt comparison
addon.DungeonTracker = {}
local DungeonTracker = addon.DungeonTracker

-- Initialize tracker
function DungeonTracker:Initialize()
	addon.Utils:Debug("DungeonTracker initialized")
end

-- Get best runs across all alts for a specific dungeon
function DungeonTracker:GetBestRunsForDungeon(dungeonID)
	if not addon.AltManager or not addon.MythicPlusTracker then
		return nil
	end

	local alts = addon.AltManager:GetAllAlts()
	local bestRuns = {
		fortified = {level = 0, character = nil, timed = false},
		tyrannical = {level = 0, character = nil, timed = false}
	}

	for key, alt in pairs(alts) do
		if alt.mythicplus and alt.mythicplus.dungeons and alt.mythicplus.dungeons[dungeonID] then
			local dungeonData = alt.mythicplus.dungeons[dungeonID]

			-- Check fortified
			if dungeonData.fortified then
				if dungeonData.fortified.bestTimed > bestRuns.fortified.level then
					bestRuns.fortified.level = dungeonData.fortified.bestTimed
					bestRuns.fortified.character = alt.name
					bestRuns.fortified.timed = true
				elseif dungeonData.fortified.best > bestRuns.fortified.level then
					bestRuns.fortified.level = dungeonData.fortified.best
					bestRuns.fortified.character = alt.name
					bestRuns.fortified.timed = false
				end
			end

			-- Check tyrannical
			if dungeonData.tyrannical then
				if dungeonData.tyrannical.bestTimed > bestRuns.tyrannical.level then
					bestRuns.tyrannical.level = dungeonData.tyrannical.bestTimed
					bestRuns.tyrannical.character = alt.name
					bestRuns.tyrannical.timed = true
				elseif dungeonData.tyrannical.best > bestRuns.tyrannical.level then
					bestRuns.tyrannical.level = dungeonData.tyrannical.best
					bestRuns.tyrannical.character = alt.name
					bestRuns.tyrannical.timed = false
				end
			end
		end
	end

	return bestRuns
end

-- Get all dungeon data across all alts
function DungeonTracker:GetAccountWideDungeonData()
	if not addon.MythicPlusTracker then
		return {}
	end

	local dungeons = addon.MythicPlusTracker:GetSeasonDungeons()
	local accountData = {}

	for _, dungeon in ipairs(dungeons) do
		accountData[dungeon.id] = {
			name = dungeon.name,
			bestRuns = self:GetBestRunsForDungeon(dungeon.id),
			altProgress = self:GetDungeonProgressByAlt(dungeon.id)
		}
	end

	return accountData
end

-- Get per-alt progress for a specific dungeon
function DungeonTracker:GetDungeonProgressByAlt(dungeonID)
	if not addon.AltManager then
		return {}
	end

	local alts = addon.AltManager:GetAllAlts()
	local progress = {}

	for key, alt in pairs(alts) do
		if alt.mythicplus and alt.mythicplus.dungeons and alt.mythicplus.dungeons[dungeonID] then
			local dungeonData = alt.mythicplus.dungeons[dungeonID]

			progress[key] = {
				name = alt.name,
				class = alt.class,
				fortified = {
					best = dungeonData.fortified.best or 0,
					bestTimed = dungeonData.fortified.bestTimed or 0,
					rating = dungeonData.fortified.rating or 0
				},
				tyrannical = {
					best = dungeonData.tyrannical.best or 0,
					bestTimed = dungeonData.tyrannical.bestTimed or 0,
					rating = dungeonData.tyrannical.rating or 0
				},
				seasonBest = dungeonData.seasonBest or 0
			}
		else
			-- No data for this dungeon on this alt
			progress[key] = {
				name = alt.name,
				class = alt.class,
				fortified = {best = 0, bestTimed = 0, rating = 0},
				tyrannical = {best = 0, bestTimed = 0, rating = 0},
				seasonBest = 0
			}
		end
	end

	return progress
end

-- Get alts that need vault progress
function DungeonTracker:GetAltsNeedingVault()
	if not addon.AltManager then
		return {}
	end

	local alts = addon.AltManager:GetAllAlts()
	local needingVault = {}

	for key, alt in pairs(alts) do
		if alt.mythicplus and alt.mythicplus.weeklyVault then
			local activities = alt.mythicplus.weeklyVault.activities or 0
			local remaining = alt.mythicplus.weeklyVault.remaining or 8

			-- Characters with less than max vault (8 keys)
			if remaining > 0 then
				table.insert(needingVault, {
					name = alt.name,
					class = alt.class,
					activities = activities,
					remaining = remaining,
					rating = alt.mythicplus.rating or 0
				})
			end
		end
	end

	-- Sort by most remaining first
	table.sort(needingVault, function(a, b)
		return a.remaining > b.remaining
	end)

	return needingVault
end

-- Get highest rated alt
function DungeonTracker:GetHighestRatedAlt()
	if not addon.AltManager then
		return nil
	end

	local alts = addon.AltManager:GetAllAlts()
	local highest = {name = nil, rating = 0}

	for key, alt in pairs(alts) do
		if alt.mythicplus and alt.mythicplus.rating then
			if alt.mythicplus.rating > highest.rating then
				highest.name = alt.name
				highest.rating = alt.mythicplus.rating
				highest.class = alt.class
			end
		end
	end

	return highest
end

-- Get dungeon completion summary
function DungeonTracker:GetCompletionSummary()
	if not addon.MythicPlusTracker then
		return {}
	end

	local dungeons = addon.MythicPlusTracker:GetSeasonDungeons()
	local summary = {
		totalDungeons = #dungeons,
		completedFort = 0,
		completedTyrann = 0,
		timedFort = 0,
		timedTyrann = 0
	}

	-- Check current character
	local mpData = addon.MythicPlusTracker:GetAllData()
	if mpData and mpData.dungeons then
		for dungeonID, data in pairs(mpData.dungeons) do
			if data.fortified.best > 0 then
				summary.completedFort = summary.completedFort + 1
				if data.fortified.bestTimed > 0 then
					summary.timedFort = summary.timedFort + 1
				end
			end

			if data.tyrannical.best > 0 then
				summary.completedTyrann = summary.completedTyrann + 1
				if data.tyrannical.bestTimed > 0 then
					summary.timedTyrann = summary.timedTyrann + 1
				end
			end
		end
	end

	return summary
end

-- Format dungeon level display
function DungeonTracker:FormatDungeonLevel(level, timed)
	if level == 0 then
		return "-"
	end

	local color = timed and {0, 1, 0} or {1, 0.8, 0}
	local symbol = timed and "+" or ""
	return addon.Utils:ColorText(format("%d%s", level, symbol), color[1], color[2], color[3])
end
