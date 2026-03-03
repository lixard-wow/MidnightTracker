local addonName, addon = ...

-- Minimap module: minimap icon and tooltip
addon.Minimap = {}
local Minimap = addon.Minimap

local LibDBIcon
local ldb

function Minimap:Initialize()
	LibDBIcon = LibStub("LibDBIcon-1.0", true)
	if not LibDBIcon then
		addon.Utils:Print("Error: LibDBIcon-1.0 not found!")
		return
	end

	local LDB = LibStub("LibDataBroker-1.1", true)
	if not LDB then
		addon.Utils:Print("Error: LibDataBroker-1.1 not found!")
		return
	end

	ldb = LDB:NewDataObject("MidnightTracker", {
		type = "data source",
		text = "MidnightTracker",
		icon = "Interface\\Icons\\INV_Misc_Coin_01",
		OnClick = function(self, button)
			Minimap:OnClick(button)
		end,
		OnTooltipShow = function(tooltip)
			Minimap:BuildTooltip(tooltip)
		end,
	})

	LibDBIcon:Register("MidnightTracker", ldb, addon.db.minimap)

	addon.Utils:Debug("Minimap icon initialized")
end

function Minimap:OnClick(button)
	if button == "LeftButton" then
		if addon.Display and addon.Display.Toggle then
			addon.Display:Toggle()
		end
	elseif button == "RightButton" then
		if addon.Config and addon.Config.Toggle then
			addon.Config:Toggle()
		end
	end
end

function Minimap:BuildTooltip(tooltip)
	if not tooltip then return end

	tooltip:AddDoubleLine(
		addon.Utils:ColorText("MidnightTracker", 0, 1, 0),
		addon.Utils:ColorText("v" .. addon.version, 0.5, 0.5, 0.5)
	)
	tooltip:AddLine(" ")

	-- Weekly reset timer
	local resetSeconds = addon.Data:GetTimeUntilWeeklyReset()
	if resetSeconds then
		local resetText = addon.Data:FormatTimeRemaining(resetSeconds)
		tooltip:AddDoubleLine(
			"Weekly Reset:",
			addon.Utils:ColorText(resetText, 1, 1, 0)
		)
		tooltip:AddLine(" ")
	end

	-- Show currencies by category
	local data = addon.Tracker:GetAllTrackables()

	if data.categories and #data.categories > 0 then
		for _, category in ipairs(data.categories) do
			tooltip:AddLine(addon.Utils:ColorText(category.name, 1, 0.8, 0))

			for _, currency in ipairs(category.currencies) do
				self:AddCurrencyLine(tooltip, currency)
			end

			tooltip:AddLine(" ")
		end
	else
		tooltip:AddLine("No currencies discovered yet.")
		tooltip:AddLine(" ")
	end

	tooltip:AddLine(" ")
	tooltip:AddLine(addon.Utils:ColorText("Left-Click:", 0.7, 0.7, 0.7) .. " Toggle display")
	tooltip:AddLine(addon.Utils:ColorText("Right-Click:", 0.7, 0.7, 0.7) .. " Open settings")
end

function Minimap:AddCurrencyLine(tooltip, currency)
	local amount = currency.amount or 0
	local max = currency.max
	local weeklyMax = currency.weeklyMax
	local earnedThisWeek = currency.earnedThisWeek

	local amountText = addon.Utils:FormatNumber(amount)

	if max and max > 0 then
		amountText = format("%s / %s", amountText, addon.Utils:FormatNumber(max))
	end

	local color = addon.Data:GetCurrencyColor(amount, max or weeklyMax)

	tooltip:AddDoubleLine(
		"  " .. currency.name,
		addon.Utils:ColorText(amountText, color[1], color[2], color[3])
	)

	if earnedThisWeek and earnedThisWeek > 0 and weeklyMax then
		local weeklyText
		if weeklyMax > 0 then
			weeklyText = format("(+%s / %s weekly)",
				addon.Utils:FormatNumber(earnedThisWeek),
				addon.Utils:FormatNumber(weeklyMax)
			)
		else
			weeklyText = format("(+%s this week)", addon.Utils:FormatNumber(earnedThisWeek))
		end
		tooltip:AddDoubleLine("", addon.Utils:ColorText(weeklyText, 0.7, 0.7, 0.7))
	end
end

function Minimap:Show()
	if LibDBIcon then
		addon.db.minimap.hide = false
		LibDBIcon:Show("MidnightTracker")
	end
end

function Minimap:Hide()
	if LibDBIcon then
		addon.db.minimap.hide = true
		LibDBIcon:Hide("MidnightTracker")
	end
end

function Minimap:UpdatePosition()
	if LibDBIcon then
		LibDBIcon:Refresh("MidnightTracker", addon.db.minimap)
	end
end

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
