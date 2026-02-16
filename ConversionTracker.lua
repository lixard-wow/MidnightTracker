local addonName, addon = ...

-- Conversion Tracker Module
-- Tracks items that can be converted into other items and shows potential conversions
local ConversionTracker = {}
addon.ConversionTracker = ConversionTracker

-- Conversion rules: sourceItemID → {targetName, requiredAmount, multipleItems (optional)}
-- multipleItems is for cases where multiple items are needed (like Obsidian Keys)
local conversionRules = {
	-- War Within
	[236096] = { -- Coffer Key Shard
		targetName = "Key",
		targetNamePlural = "Keys",
		required = 100,
		description = "100 Shards = 1 Restored Coffer Key",
	},

	-- Dragonflight
	[191251] = { -- Key Fragments
		targetName = "Fragment Key",
		targetNamePlural = "Fragment Keys",
		required = 30,
		description = "30 Fragments = 1 Restored Obsidian Key",
		-- Note: Also needs Key Framing, but we'll handle that separately
		checkMultiple = function()
			-- Check if we also have Key Framings (193201)
			local framings = GetItemCount(193201, true, false, true) or 0
			local fragments = GetItemCount(191251, true, false, true) or 0

			local keysFromFramings = math.floor(framings / 3)
			local keysFromFragments = math.floor(fragments / 30)

			-- Can only make as many keys as the limiting factor
			return math.min(keysFromFramings, keysFromFragments)
		end,
	},

	[193201] = { -- Key Framing
		targetName = "Framing Key",
		targetNamePlural = "Framing Keys",
		required = 3,
		description = "3 Framings + 30 Fragments = 1 Restored Obsidian Key",
		checkMultiple = function()
			-- Check if we also have Key Fragments (191251)
			local framings = GetItemCount(193201, true, false, true) or 0
			local fragments = GetItemCount(191251, true, false, true) or 0

			local keysFromFramings = math.floor(framings / 3)
			local keysFromFragments = math.floor(fragments / 30)

			-- Can only make as many keys as the limiting factor
			return math.min(keysFromFramings, keysFromFragments)
		end,
	},
}

-- Get conversion info for an item
function ConversionTracker:GetConversionInfo(itemID)
	local rule = conversionRules[itemID]
	if not rule then return nil end

	-- Get item count from bags (including bank)
	local count = GetItemCount(itemID, true, false, true) or 0
	if count == 0 then return nil end

	-- Calculate how many target items can be made
	local canMake

	if rule.checkMultiple then
		-- Complex conversion requiring multiple items
		canMake = rule.checkMultiple()
	else
		-- Simple conversion
		canMake = math.floor(count / rule.required)
	end

	if canMake == 0 then return nil end

	return {
		canMake = canMake,
		targetName = canMake == 1 and rule.targetName or rule.targetNamePlural,
		description = rule.description,
		sourceCount = count,
		required = rule.required,
	}
end

-- Get extra info text for display (e.g., "+4 Keys")
function ConversionTracker:GetExtraInfoText(itemID)
	local info = self:GetConversionInfo(itemID)
	if not info then return nil end

	-- Format: "+X Keys" or "+1 Key"
	return format("+%d %s", info.canMake, info.targetName)
end

-- Get detailed tooltip info
function ConversionTracker:GetTooltipInfo(itemID)
	local info = self:GetConversionInfo(itemID)
	if not info then return nil end

	return {
		line1 = format("Can craft: %d %s", info.canMake, info.targetName),
		line2 = info.description,
	}
end

-- Check if an item has conversion info
function ConversionTracker:HasConversion(itemID)
	return conversionRules[itemID] ~= nil
end

-- Get all active conversions (items in bags that can be converted)
function ConversionTracker:GetAllActiveConversions()
	local active = {}

	for itemID, rule in pairs(conversionRules) do
		local info = self:GetConversionInfo(itemID)
		if info then
			table.insert(active, {
				itemID = itemID,
				info = info,
			})
		end
	end

	return active
end

-- Initialize (if needed)
function ConversionTracker:Initialize()
	-- Nothing to initialize yet, but keeping this for future use
	addon.Utils:Debug("ConversionTracker initialized")
end

return ConversionTracker
