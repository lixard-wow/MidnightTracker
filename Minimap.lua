local addonName, addon = ...

-- Minimap module: handles minimap icon and tooltip
addon.Minimap = {}
local Minimap = addon.Minimap

-- LibDBIcon reference
local LibDBIcon

-- LDB data object
local ldb

-- Initialize minimap icon
function Minimap:Initialize()
	-- Get LibDBIcon library
	LibDBIcon = LibStub("LibDBIcon-1.0", true)
	if not LibDBIcon then
		addon.Utils:Print("Error: LibDBIcon-1.0 not found!")
		return
	end

	-- Create LDB data object
	local LDB = LibStub("LibDataBroker-1.1", true)
	if not LDB then
		addon.Utils:Print("Error: LibDataBroker-1.1 not found!")
		return
	end

	ldb = LDB:NewDataObject("MidnightTracker", {
		type = "data source",
		text = "MidnightTracker",
		icon = "Interface\\Icons\\INV_Misc_Coin_01", -- Default coin icon
		OnClick = function(self, button)
			Minimap:OnClick(button)
		end,
		OnTooltipShow = function(tooltip)
			Minimap:BuildTooltip(tooltip)
		end,
	})

	-- Register with LibDBIcon
	LibDBIcon:Register("MidnightTracker", ldb, addon.db.minimap)

	addon.Utils:Debug("Minimap icon initialized")
end

-- Click handler
function Minimap:OnClick(button)
	if button == "LeftButton" then
		if IsShiftKeyDown() then
			-- Shift+Left click: toggle Panel 2 (Weekly Tracker)
			if addon.Display and addon.Display.ToggleProgression then
				addon.Display:ToggleProgression()
			end
		else
			-- Left click: toggle Panel 1 (Currency)
			if addon.Display and addon.Display.Toggle then
				addon.Display:Toggle()
			end
		end
	elseif button == "RightButton" then
		-- Right click: open config panel
		if addon.Config and addon.Config.Toggle then
			addon.Config:Toggle()
		end
	end
end

-- Build tooltip
function Minimap:BuildTooltip(tooltip)
	if not tooltip then return end

	-- Set title
	tooltip:AddDoubleLine(
		addon.Utils:ColorText("MidnightTracker", 0, 1, 0),
		addon.Utils:ColorText("v" .. addon.version, 0.5, 0.5, 0.5)
	)
	tooltip:AddLine(" ")

	-- Get all trackable data
	local data = addon.Tracker:GetAllTrackables()

	-- Show weekly reset timer
	if data.weeklyReset then
		local resetText = addon.Data:FormatTimeRemaining(data.weeklyReset)
		tooltip:AddDoubleLine(
			"Weekly Reset:",
			addon.Utils:ColorText(resetText, 1, 1, 0)
		)
		tooltip:AddLine(" ")
	end

	-- Show Great Vault progress
	if data.greatVault then
		tooltip:AddLine(addon.Utils:ColorText("Great Vault Progress", 0.3, 0.9, 1))
		self:AddGreatVaultProgress(tooltip, data.greatVault)
		tooltip:AddLine(" ")
	end

	-- Show currencies by category
	if data.categories and #data.categories > 0 then
		for _, category in ipairs(data.categories) do
			-- Category header
			tooltip:AddLine(addon.Utils:ColorText(category.name, 1, 0.8, 0))

			-- Show currencies in this category
			for _, currency in ipairs(category.currencies) do
				self:AddCurrencyLine(tooltip, currency)
			end

			tooltip:AddLine(" ")
		end
	else
		tooltip:AddLine("No currencies discovered yet.")
		tooltip:AddLine(" ")
	end

	-- Add instructions
	tooltip:AddLine(" ")
	tooltip:AddLine(addon.Utils:ColorText("Click Actions:", 1, 0.82, 0))
	tooltip:AddLine(addon.Utils:ColorText("Left-Click:", 0.7, 0.7, 0.7) .. " Toggle Panel 1 (Currency)")
	tooltip:AddLine(addon.Utils:ColorText("Shift+Left-Click:", 0.7, 0.7, 0.7) .. " Toggle Panel 2 (Weekly)")
	tooltip:AddLine(addon.Utils:ColorText("Right-Click:", 0.7, 0.7, 0.7) .. " Open Settings")
	tooltip:AddLine(" ")
	tooltip:AddLine(addon.Utils:ColorText("Commands:", 1, 0.82, 0))
	tooltip:AddLine(addon.Utils:ColorText("/mtrack", 0.7, 0.7, 0.7) .. " - Show command list")
	tooltip:AddLine(addon.Utils:ColorText("/mtrack checklist", 0.7, 0.7, 0.7) .. " - Toggle todo list")
end

-- Add currency line to tooltip
function Minimap:AddCurrencyLine(tooltip, currency)
	local name = currency.name
	local amount = currency.amount or 0
	local max = currency.max
	local weeklyMax = currency.weeklyMax
	local earnedThisWeek = currency.earnedThisWeek

	-- Format amount with commas
	local amountText = addon.Utils:FormatNumber(amount)

	-- Add max if available
	if max and max > 0 then
		amountText = format("%s / %s", amountText, addon.Utils:FormatNumber(max))
	end

	-- Get color based on cap
	local color = addon.Data:GetCurrencyColor(amount, max or weeklyMax)

	-- Add the line
	tooltip:AddDoubleLine(
		"  " .. name,
		addon.Utils:ColorText(amountText, color[1], color[2], color[3])
	)

	-- Add weekly earning if available
	if earnedThisWeek and earnedThisWeek > 0 and weeklyMax then
		local weeklyText = format("(+%s this week)", addon.Utils:FormatNumber(earnedThisWeek))
		if weeklyMax > 0 then
			weeklyText = format("(+%s / %s weekly)",
				addon.Utils:FormatNumber(earnedThisWeek),
				addon.Utils:FormatNumber(weeklyMax)
			)
		end
		tooltip:AddDoubleLine("", addon.Utils:ColorText(weeklyText, 0.7, 0.7, 0.7))
	end
end

-- Add Great Vault progress bars
function Minimap:AddGreatVaultProgress(tooltip, vaultData)
	-- Raid progress
	if vaultData.raid then
		local bars = self:CreateProgressBars(vaultData.raid.current, vaultData.raid.thresholds)
		tooltip:AddDoubleLine(
			"  Raid:",
			format("%d/8 %s", vaultData.raid.current, bars)
		)
	end

	-- Mythic+ progress
	if vaultData.mythicplus then
		local bars = self:CreateProgressBars(vaultData.mythicplus.current, vaultData.mythicplus.thresholds)
		tooltip:AddDoubleLine(
			"  Mythic+:",
			format("%d/8 %s", vaultData.mythicplus.current, bars)
		)
	end

	-- World/Delves progress
	if vaultData.world then
		local bars = self:CreateProgressBars(vaultData.world.current, vaultData.world.thresholds)
		tooltip:AddDoubleLine(
			"  World/Delves:",
			format("%d/8 %s", vaultData.world.current, bars)
		)
	end
end

-- Create progress bar visualization
function Minimap:CreateProgressBars(current, thresholds)
	local bars = ""
	for i, threshold in ipairs(thresholds) do
		if current >= threshold then
			bars = bars .. addon.Utils:ColorText("█", 0, 1, 0) -- Green filled
		else
			bars = bars .. addon.Utils:ColorText("█", 0.3, 0.3, 0.3) -- Gray empty
		end
	end
	return bars
end

-- Show minimap icon
function Minimap:Show()
	if LibDBIcon then
		addon.db.minimap.hide = false
		LibDBIcon:Show("MidnightTracker")
	end
end

-- Hide minimap icon
function Minimap:Hide()
	if LibDBIcon then
		addon.db.minimap.hide = true
		LibDBIcon:Hide("MidnightTracker")
	end
end

-- Update minimap icon position
function Minimap:UpdatePosition()
	if LibDBIcon then
		LibDBIcon:Refresh("MidnightTracker", addon.db.minimap)
	end
end

-- Lock/unlock minimap icon
function Minimap:SetLocked(locked)
	if LibDBIcon then
		addon.db.minimap.lock = locked
		if locked then
			LibDBIcon:Lock("MidnightTracker")
		else
			LibDBIcon:Unlock("MidnightTracker")
		end
	end
end
