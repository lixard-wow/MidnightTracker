local addonName, addon = ...

-- Display module: on-screen currency tracker
addon.Display = {}
local Display = addon.Display

-- Main display frame
local displayFrame
local currencyFrames = {}
local updateTimer = 0

-- Initialize display
function Display:Initialize()
	-- Create main frame
	displayFrame = CreateFrame("Frame", "MidnightTrackerDisplay", UIParent, "BackdropTemplate")
	displayFrame:SetSize(190, 100) -- Will auto-resize
	displayFrame:SetMovable(true)
	displayFrame:SetClampedToScreen(true)
	displayFrame:EnableMouse(true)
	displayFrame:RegisterForDrag("LeftButton")
	displayFrame:SetScript("OnDragStart", displayFrame.StartMoving)
	displayFrame:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		Display:SavePosition()
	end)

	-- Restore saved position or use default
	self:RestorePosition()

	-- Apply scale
	displayFrame:SetScale(addon.db.display.scale or 1.0)

	-- Backdrop (conditional) safely
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

	-- Content frame (no scroll)
	local content = CreateFrame("Frame", nil, displayFrame)
	content:SetPoint("TOPLEFT", 8, -8)
	content:SetPoint("BOTTOMRIGHT", -8, 8)
	displayFrame.content = content

	-- Update on timer and on zone change
	displayFrame:SetScript("OnUpdate", function(self, elapsed)
		updateTimer = updateTimer + elapsed
		if updateTimer >= 1 then -- Update every second
			Display:UpdateDisplay()
			updateTimer = 0
		end
	end)

	-- Register for zone change events
	displayFrame:RegisterEvent("ZONE_CHANGED")
	displayFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
	displayFrame:SetScript("OnEvent", function(self, event)
		if event == "ZONE_CHANGED" or event == "ZONE_CHANGED_NEW_AREA" then
			Display:UpdateDisplay()
		end
	end)

	-- Initial update
	self:UpdateDisplay()

	-- Show by default
	displayFrame:Show()

	addon.Utils:Debug("Display frame initialized")
end

-- Update the display with current currency data
function Display:UpdateDisplay()
	if not displayFrame or not displayFrame.content then return end

	-- Apply scale
	displayFrame:SetScale(addon.db.display.scale or 1.0)

	-- Update backdrop safely
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

	-- Get all trackable data
	local data = addon.Tracker:GetAllTrackables()

	-- Define expansion order (newest to oldest)
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

	-- Get display settings
	local iconsPerRow = addon.db.display.iconsPerRow or 3
	local iconSize = addon.db.display.iconSize or 18

	local xOffset = 2
	local yOffset = -5
	local iconCount = 0
	local colGap = 6 -- gap between columns, matches the icon-to-text gap for even left/right padding

	-- Add Great Vault progress if enabled
	local startYOffset = yOffset
	if addon.db.settings.showGreatVault and data.greatVault then
		yOffset = self:AddGreatVaultDisplay(data.greatVault, yOffset)
	end

	-- Create all currency line frames first (each sized to fit its own text,
	-- not a fixed worst-case width) so columns can be sized per-column below.
	local items = {}
	for _, category in ipairs(sortedCategories) do
		for _, currency in ipairs(category.currencies) do
			table.insert(items, self:CreateCompactCurrencyLine(currency, category.name))
		end
	end

	-- Size each column to the widest item that lands in it, so every line's
	-- right-side padding before the next column matches its left-side padding.
	local colWidths = {}
	for i, currFrame in ipairs(items) do
		local col = (i - 1) % iconsPerRow
		colWidths[col] = math.max(colWidths[col] or 0, currFrame.naturalWidth or (iconSize + 34))
	end

	local colOffsets = {}
	local runningOffset = 0
	for c = 0, iconsPerRow - 1 do
		colOffsets[c] = runningOffset
		runningOffset = runningOffset + (colWidths[c] or (iconSize + 34)) + colGap
	end

	for i, currFrame in ipairs(items) do
		local col = (i - 1) % iconsPerRow
		local row = math.floor((i - 1) / iconsPerRow)

		currFrame:SetPoint("TOPLEFT", displayFrame.content, "TOPLEFT",
			xOffset + colOffsets[col], yOffset - (row * 24))

		table.insert(currencyFrames, currFrame)
		iconCount = iconCount + 1
	end

	-- Calculate size based on content
	local rows = math.max(1, math.ceil(iconCount / iconsPerRow))
	local contentWidth = runningOffset + 4

	-- Calculate total height including Great Vault
	local vaultHeight = math.abs(yOffset) - 5 -- Height used by vault before currencies start
	local currencyHeight = (rows * 24)
	local contentHeight = vaultHeight + currencyHeight + 4

	-- Resize frame to fit content exactly
	displayFrame:SetSize(contentWidth + 16, contentHeight + 16)
	displayFrame.content:SetSize(contentWidth, contentHeight)
end


-- Helper: Get gear quality color based on activity level (raid difficulty ID,
-- M+ key level, or delve tier depending on activityType)
local function GetVaultQualityColor(activityType, level)
	if activityType == "Raid" then
		-- Raid difficulty IDs: 17=LFR, 14=Normal, 15=Heroic, 16=Mythic
		if level == 16 then
			return 1, 0.5, 0 -- Orange - Mythic
		elseif level == 15 then
			return 0.64, 0.21, 0.93 -- Purple - Heroic
		elseif level == 14 then
			return 0, 0.44, 0.87 -- Blue - Normal
		elseif level == 17 then
			return 0.12, 1, 0 -- Green - LFR
		else
			return 0.6, 0.6, 0.6 -- Grey - Unknown
		end
	elseif activityType == "M+" then
		-- Mythic+ key level
		if level >= 10 then
			return 1, 0.5, 0 -- Orange - Myth track (M+10+)
		elseif level >= 5 then
			return 0.64, 0.21, 0.93 -- Purple - Hero track (M+5-9)
		elseif level >= 2 then
			return 0, 0.44, 0.87 -- Blue - Champion track (M+2-4)
		elseif level >= 1 then
			return 0.12, 1, 0 -- Green - Mythic 0/low keys
		else
			return 0.6, 0.6, 0.6 -- Grey - No progress
		end
	elseif activityType == "Del" then
		-- Delve tier level
		if level >= 11 then
			return 1, 0.5, 0 -- Orange - Tier 11+
		elseif level >= 8 then
			return 0.64, 0.21, 0.93 -- Purple - Tier 8-10
		elseif level >= 4 then
			return 0, 0.44, 0.87 -- Blue - Tier 4-7
		elseif level >= 1 then
			return 0.12, 1, 0 -- Green - Tier 1-3
		else
			return 0.6, 0.6, 0.6 -- Grey - No progress
		end
	end
	return 0.6, 0.6, 0.6 -- Default grey
end

-- Resolve the font template for the current display.fontSize setting,
-- shared by currency lines and Great Vault labels so they stay in sync.
function Display:GetFontString()
	if addon.db.display.fontSize == "large" then
		return "GameFontNormal"
	elseif addon.db.display.fontSize == "small" then
		return "GameFontHighlightSmall"
	end
	return "GameFontNormalSmall"
end

-- Add Great Vault progress display
function Display:AddGreatVaultDisplay(vaultData, yOffset)
	-- Add each vault type that's enabled vertically
	local vaultTypes = {
		{name = "Raid", data = vaultData.raid, setting = "showVaultRaid"},
		{name = "M+", data = vaultData.mythicplus, setting = "showVaultMythicPlus"},
		{name = "Del", data = vaultData.world, setting = "showVaultWorld"},
	}

	local xOffset = 2
	local vaultWidth = 100 -- Width for each vault row

	for _, vaultType in ipairs(vaultTypes) do
		if addon.db.settings[vaultType.setting] and vaultType.data then
			local frame = CreateFrame("Frame", nil, displayFrame.content)
			frame:SetSize(vaultWidth, 16)
			frame:SetPoint("TOPLEFT", displayFrame.content, "TOPLEFT", xOffset, yOffset)

			-- Name label
			local nameText = frame:CreateFontString(nil, "OVERLAY", self:GetFontString())
			nameText:SetPoint("LEFT", 0, 0)
			nameText:SetText(vaultType.name .. ":")
			nameText:SetTextColor(0.3, 0.9, 1)

			-- Show how many of your total landed in each slot's own segment
			-- (capped at that segment's size, e.g. raid 2/4/6 = segments of 2/2/2).
			-- Full segment = reward quality color for that slot, partial = red
			-- (in progress), zero = white (not started).
			local current = vaultType.data.current or 0
			local thresholds = vaultType.data.thresholds or {2, 4, 8}
			local levels = vaultType.data.levels or {}
			local parts = {}
			local remaining = current
			local prevThreshold = 0
			for i, threshold in ipairs(thresholds) do
				local capacity = threshold - prevThreshold
				local fill = math.min(remaining, capacity)
				remaining = remaining - fill

				if capacity > 0 and fill >= capacity then
					local r, g, b = GetVaultQualityColor(vaultType.name, levels[i] or 0)
					table.insert(parts, addon.Utils:ColorText(tostring(fill), r, g, b))
				elseif fill > 0 then
					table.insert(parts, addon.Utils:ColorText(tostring(fill), 1, 0, 0))
				else
					table.insert(parts, addon.Utils:ColorText(tostring(fill), 1, 1, 1))
				end

				prevThreshold = threshold
			end

			local progressText = frame:CreateFontString(nil, "OVERLAY", self:GetFontString())
			progressText:SetPoint("LEFT", nameText, "RIGHT", 3, 0)
			progressText:SetText(table.concat(parts, "/"))

			frame:Show()
			table.insert(currencyFrames, frame)
			yOffset = yOffset - 16 -- Move down for next vault type
		end
	end

	-- Add extra spacing after vault section
	yOffset = yOffset - 7

	return yOffset
end

-- Create a simple text line
function Display:CreateTextLine(text, r, g, b)
	local frame = CreateFrame("Frame", nil, displayFrame.content)
	frame:SetSize(200, 16)

	local fs = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	fs:SetPoint("LEFT")
	fs:SetText(addon.Utils:ColorText(text, r, g, b))
	fs:SetJustifyH("LEFT")

	frame:Show()
	return frame
end

-- Create a compact currency line (icon + value only)
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

	-- Amount (compact)
	local amount = currency.amount or 0
	local amountText = addon.Utils:FormatNumber(amount)

	-- Compact large numbers
	if amount >= 1000000 then
		amountText = format("%.1fM", amount / 1000000)
	elseif amount >= 1000 then
		amountText = format("%.1fK", amount / 1000)
	end

	local color = addon.Data:GetCurrencyColor(amount, currency.max or currency.cap)

	-- Crests get an inline readout matching how Blizzard's own tooltip frames it:
	-- "total"-cap crests show current/cap (the balance itself is the progress),
	-- "weekly"-cap currencies show earned-this-week/cap, uncapped crests show just the amount.
	local isCrest = currency.name and currency.name:lower():find("crest") ~= nil
	local displayText
	if isCrest and currency.cap and currency.cap > 0 and currency.capType == "total" then
		local capColor = addon.Data:GetCurrencyColor(amount, currency.cap)
		displayText = addon.Utils:ColorText(format("%d/%d", amount, currency.cap), capColor[1], capColor[2], capColor[3])
	elseif isCrest and currency.cap and currency.cap > 0 and currency.capType == "weekly" then
		local earned = currency.earnedThisWeek or 0
		local capColor = addon.Data:GetCurrencyColor(earned, currency.cap)
		local progText = format(" (%d/%d)", earned, currency.cap)
		displayText = addon.Utils:ColorText(amountText, color[1], color[2], color[3])
			.. addon.Utils:ColorText(progText, capColor[1], capColor[2], capColor[3])
	else
		displayText = addon.Utils:ColorText(amountText, color[1], color[2], color[3])
	end

	local amountStr = frame:CreateFontString(nil, "OVERLAY", self:GetFontString())
	amountStr:SetPoint("LEFT", iconSize + 2, 0)
	amountStr:SetText(displayText)
	amountStr:SetJustifyH("LEFT")
	frame.amount = amountStr

	-- Size the frame to its own text (icon + gap + text + a right pad matching the left icon gap)
	-- so the trailing space before the next column equals the leading space before the icon.
	local naturalWidth = iconSize + 2 + amountStr:GetStringWidth() + 6
	frame:SetSize(naturalWidth, iconSize + 4)
	frame.naturalWidth = naturalWidth

	-- Tooltip on hover
	frame:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(currency.name, 1, 1, 1)

		if categoryName then
			GameTooltip:AddLine(categoryName, 0.7, 0.7, 0.7)
		end

		local fullAmount = addon.Utils:FormatNumber(currency.amount or 0)

		if isCrest then
			if currency.capType == "total" and currency.cap and currency.cap > 0 then
				-- Season/hold cap: current balance IS the progress, no separate weekly figure
				local capColor = addon.Data:GetCurrencyColor(currency.amount or 0, currency.cap)
				GameTooltip:AddDoubleLine("Quantity:", format("%s / %s", fullAmount, addon.Utils:FormatNumber(currency.cap)), 1, 1, 1, capColor[1], capColor[2], capColor[3])
			elseif currency.capType == "weekly" and currency.cap and currency.cap > 0 then
				GameTooltip:AddDoubleLine("Total held:", fullAmount, 1, 1, 1, color[1], color[2], color[3])
				local capColor = addon.Data:GetCurrencyColor(currency.earnedThisWeek or 0, currency.cap)
				GameTooltip:AddDoubleLine("This week:", format("%s / %s", addon.Utils:FormatNumber(currency.earnedThisWeek or 0), addon.Utils:FormatNumber(currency.cap)), 1, 1, 1, capColor[1], capColor[2], capColor[3])
			else
				-- Uncapped: just the quantity, matching Blizzard's own tooltip for uncapped crests
				GameTooltip:AddDoubleLine("Quantity:", fullAmount, 1, 1, 1, color[1], color[2], color[3])
			end
		else
			if currency.max and currency.max > 0 then
				GameTooltip:AddDoubleLine("Amount:", format("%s / %s", fullAmount, addon.Utils:FormatNumber(currency.max)), 1, 1, 1, color[1], color[2], color[3])
			else
				GameTooltip:AddDoubleLine("Amount:", fullAmount, 1, 1, 1, color[1], color[2], color[3])
			end

			if currency.capType == "weekly" and currency.cap and currency.cap > 0 and currency.earnedThisWeek then
				GameTooltip:AddDoubleLine("This Week:", format("%s / %s", addon.Utils:FormatNumber(currency.earnedThisWeek), addon.Utils:FormatNumber(currency.cap)), 1, 1, 1, 1, 1, 0)
			end
		end

		GameTooltip:Show()
	end)

	frame:SetScript("OnLeave", function(self)
		GameTooltip:Hide()
	end)

	frame:Show()
	return frame
end

-- Show display
function Display:Show()
	if displayFrame then
		displayFrame:Show()
		if addon.db then
			addon.db.display = addon.db.display or {}
			addon.db.display.hidden = false
		end
	end
end

-- Hide display
function Display:Hide()
	if displayFrame then
		displayFrame:Hide()
		if addon.db then
			addon.db.display = addon.db.display or {}
			addon.db.display.hidden = true
		end
	end
end

-- Toggle display
function Display:Toggle()
	if displayFrame and displayFrame:IsShown() then
		self:Hide()
	else
		self:Show()
	end
end

-- Save frame position
function Display:SavePosition()
	if not displayFrame then return end

	local point, _, relativePoint, xOfs, yOfs = displayFrame:GetPoint()

	if not addon.db.display then
		addon.db.display = {}
	end

	addon.db.display.point = point
	addon.db.display.relativePoint = relativePoint
	addon.db.display.xOfs = xOfs
	addon.db.display.yOfs = yOfs
end

-- Restore frame position
function Display:RestorePosition()
	if not displayFrame then return end

	if addon.db.display and addon.db.display.point then
		displayFrame:ClearAllPoints()
		displayFrame:SetPoint(
			addon.db.display.point,
			UIParent,
			addon.db.display.relativePoint or "TOPRIGHT",
			addon.db.display.xOfs or -20,
			addon.db.display.yOfs or -200
		)
	else
		-- Default position
		displayFrame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -20, -200)
	end
end
