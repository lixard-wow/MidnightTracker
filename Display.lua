local addonName, addon = ...

-- Display module: on-screen currency tracker
addon.Display = {}
local Display = addon.Display

local displayFrame
local currencyFrames = {}
local updateTimer = 0

function Display:Initialize()
	displayFrame = CreateFrame("Frame", "MidnightTrackerDisplay", UIParent, "BackdropTemplate")
	displayFrame:SetSize(190, 100)
	displayFrame:SetMovable(true)
	displayFrame:SetClampedToScreen(true)
	displayFrame:EnableMouse(true)
	displayFrame:RegisterForDrag("LeftButton")
	displayFrame:SetScript("OnDragStart", displayFrame.StartMoving)
	displayFrame:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		Display:SavePosition()
	end)

	self:RestorePosition()

	displayFrame:SetScale(addon.db.display.scale or 1.0)

	-- Backdrop
	if displayFrame.SetBackdrop then
		if addon.db.display.showBackground or addon.db.display.showBorder then
			displayFrame:SetBackdrop({
				bgFile = addon.db.display.showBackground and "Interface\\ChatFrame\\ChatFrameBackground" or nil,
				edgeFile = addon.db.display.showBorder and "Interface\\Tooltips\\UI-Tooltip-Border" or nil,
				tile = true, tileSize = 16, edgeSize = 16,
				insets = { left = 3, right = 3, top = 3, bottom = 3 }
			})
			local opacity = addon.db.display.backgroundOpacity or 0.8
			if displayFrame.SetBackdropColor then
				displayFrame:SetBackdropColor(0, 0, 0, addon.db.display.showBackground and opacity or 0)
			end
			if displayFrame.SetBackdropBorderColor then
				displayFrame:SetBackdropBorderColor(0.4, 0.4, 0.4, addon.db.display.showBorder and 1 or 0)
			end
		else
			displayFrame:SetBackdrop(nil)
		end
	end

	-- Content frame
	local content = CreateFrame("Frame", nil, displayFrame)
	content:SetPoint("TOPLEFT", 8, -8)
	content:SetPoint("BOTTOMRIGHT", -8, 8)
	displayFrame.content = content

	-- Update timer
	displayFrame:SetScript("OnUpdate", function(self, elapsed)
		updateTimer = updateTimer + elapsed
		if updateTimer >= 1 then
			Display:UpdateDisplay()
			updateTimer = 0
		end
	end)

	-- Zone change events
	displayFrame:RegisterEvent("ZONE_CHANGED")
	displayFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
	displayFrame:SetScript("OnEvent", function(self, event)
		if event == "ZONE_CHANGED" or event == "ZONE_CHANGED_NEW_AREA" then
			Display:UpdateDisplay()
		end
	end)

	self:UpdateDisplay()
	self:UpdateCityVisibility()

	addon.Utils:Debug("Display initialized")
end

function Display:UpdateDisplay()
	if not displayFrame or not displayFrame.content then return end

	-- Apply scale
	displayFrame:SetScale(addon.db.display.scale or 1.0)

	-- Update backdrop
	if displayFrame.SetBackdrop then
		if addon.db.display.showBackground or addon.db.display.showBorder then
			displayFrame:SetBackdrop({
				bgFile = addon.db.display.showBackground and "Interface\\ChatFrame\\ChatFrameBackground" or nil,
				edgeFile = addon.db.display.showBorder and "Interface\\Tooltips\\UI-Tooltip-Border" or nil,
				tile = true, tileSize = 16, edgeSize = 16,
				insets = { left = 3, right = 3, top = 3, bottom = 3 }
			})
			local opacity = addon.db.display.backgroundOpacity or 0.8
			if displayFrame.SetBackdropColor then
				displayFrame:SetBackdropColor(0, 0, 0, addon.db.display.showBackground and opacity or 0)
			end
			if displayFrame.SetBackdropBorderColor then
				displayFrame:SetBackdropBorderColor(0.4, 0.4, 0.4, addon.db.display.showBorder and 1 or 0)
			end
		else
			displayFrame:SetBackdrop(nil)
		end
	end

	-- Clear existing frames
	for _, frame in ipairs(currencyFrames) do
		frame:Hide()
		frame:SetParent(nil)
	end
	wipe(currencyFrames)

	-- Get currency data
	local data = addon.Tracker:GetAllTrackables()

	-- Expansion display order (newest first)
	local expansionOrder = {
		"Midnight",
		"War Within",
		"Dragonflight",
		"Shadowlands",
		"Battle for Azeroth",
		"Legion",
		"Warlords of Draenor",
		"Mists of Pandaria",
		"Cataclysm",
		"Wrath of the Lich King",
		"Burning Crusade",
		"PvP Currencies",
		"Seasonal Events",
	}

	-- Sort categories by expansion order
	local sortedCategories = {}
	if data.categories then
		for _, orderName in ipairs(expansionOrder) do
			for _, category in ipairs(data.categories) do
				if category.name == orderName then
					table.insert(sortedCategories, category)
					break
				end
			end
		end
	end

	-- Layout settings
	local iconsPerRow = addon.db.display.iconsPerRow or 3
	local iconSize = addon.db.display.iconSize or 18
	local columnWidth = iconSize + 65

	local xOffset = 2
	local yOffset = -5
	local iconCount = 0

	-- Add currencies
	for _, category in ipairs(sortedCategories) do
		for _, currency in ipairs(category.currencies) do
			local currFrame = self:CreateCompactCurrencyLine(currency, category.name)

			local col = iconCount % iconsPerRow
			local row = math.floor(iconCount / iconsPerRow)

			currFrame:SetPoint("TOPLEFT", displayFrame.content, "TOPLEFT",
				xOffset + (col * columnWidth), yOffset - (row * 24))

			table.insert(currencyFrames, currFrame)
			iconCount = iconCount + 1
		end
	end

	-- Resize frame to fit content
	if iconCount == 0 then
		displayFrame:Hide()
	else
		local rows = math.max(1, math.ceil(iconCount / iconsPerRow))
		local contentWidth = (iconsPerRow * columnWidth) + 4
		local contentHeight = (rows * 24) + 10

		displayFrame:SetSize(contentWidth + 16, contentHeight + 16)
		displayFrame.content:SetSize(contentWidth, contentHeight)

		-- Don't override manual show/hide - only manage visibility on initial load
		if not addon.db.display.hidden then
			displayFrame:Show()
		end
	end
end

-- Create a compact currency line (icon + value)
function Display:CreateCompactCurrencyLine(currency, categoryName)
	local iconSize = addon.db.display.iconSize or 18
	local frame = CreateFrame("Button", nil, displayFrame.content)
	frame:SetSize(iconSize + 32, iconSize + 4)
	frame:EnableMouse(true)

	-- Icon
	if currency.icon and currency.icon > 0 then
		local icon = frame:CreateTexture(nil, "ARTWORK")
		icon:SetSize(iconSize, iconSize)
		icon:SetPoint("LEFT", 0, 0)

		local success = pcall(function()
			icon:SetTexture(currency.icon)
		end)

		if success then
			icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
		else
			icon:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
			icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
		end
		frame.icon = icon
	end

	-- Amount text
	local amount = currency.amount or 0
	local max = currency.max or currency.weeklyMax
	local amountText = ""

	if max and max > 0 then
		amountText = format("%s/%s", addon.Utils:AbbreviateNumber(amount), addon.Utils:AbbreviateNumber(max))
	else
		amountText = addon.Utils:AbbreviateNumber(amount)
	end

	local color = addon.Data:GetCurrencyColor(amount, max)

	local fontString = "GameFontNormalSmall"
	if addon.db.display.fontSize == "large" then
		fontString = "GameFontNormal"
	elseif addon.db.display.fontSize == "small" then
		fontString = "GameFontHighlightSmall"
	end

	local amountStr = frame:CreateFontString(nil, "OVERLAY", fontString)
	amountStr:SetPoint("LEFT", iconSize + 2, 0)
	amountStr:SetText(addon.Utils:ColorText(amountText, color[1], color[2], color[3]))
	amountStr:SetJustifyH("LEFT")
	frame.amount = amountStr

	-- Tooltip
	frame:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(currency.name, 1, 1, 1)

		if categoryName then
			GameTooltip:AddLine(categoryName, 0.7, 0.7, 0.7)
		end

		local fullAmount = addon.Utils:FormatNumber(currency.amount or 0)
		if currency.max and currency.max > 0 then
			GameTooltip:AddDoubleLine("Amount:", format("%s / %s", fullAmount, addon.Utils:FormatNumber(currency.max)), 1, 1, 1, color[1], color[2], color[3])
		else
			GameTooltip:AddDoubleLine("Amount:", fullAmount, 1, 1, 1, color[1], color[2], color[3])
		end

		GameTooltip:Show()
	end)

	frame:SetScript("OnLeave", function(self)
		GameTooltip:Hide()
	end)

	frame:Show()
	return frame
end

function Display:Show()
	if displayFrame then
		displayFrame:Show()
		if addon.db then
			addon.db.display.hidden = false
		end
	end
end

function Display:Hide()
	if displayFrame then
		displayFrame:Hide()
		if addon.db then
			addon.db.display.hidden = true
		end
	end
end

function Display:Toggle()
	if displayFrame and displayFrame:IsShown() then
		self:Hide()
	else
		self:Show()
	end
end

function Display:UpdateCityVisibility()
	if not displayFrame then return end

	if IsResting() then
		if not addon.db.display.hidden then
			displayFrame:Show()
		end
	else
		displayFrame:Hide()
	end
end

function Display:SavePosition()
	if not displayFrame then return end
	local point, _, relativePoint, xOfs, yOfs = displayFrame:GetPoint()
	if point then
		addon.db.display.point = point
		addon.db.display.relativePoint = relativePoint
		addon.db.display.xOfs = xOfs
		addon.db.display.yOfs = yOfs
	end
end

function Display:RestorePosition()
	if not displayFrame then return end
	local point = addon.db.display.point or "TOPRIGHT"
	local relativePoint = addon.db.display.relativePoint or "TOPRIGHT"
	local xOfs = addon.db.display.xOfs or -20
	local yOfs = addon.db.display.yOfs or -200

	displayFrame:ClearAllPoints()
	displayFrame:SetPoint(point, UIParent, relativePoint, xOfs, yOfs)
end
