local addonName, addon = ...

-- Display module: on-screen currency tracker
addon.Display = {}
local Display = addon.Display

-- Main display frame (currencies only)
local displayFrame
local currencyFrames = {}
local updateTimer = 0

-- NEW: Progression display frame (Great Vault, Upgrades, Cooldowns, Alt Dashboard)
local progressionFrame
local progressionFrames = {}
local progressionTabs = {}
local currentProgressionTab = 1

-- Checklist window
local checklistFrame
local checklistTasks = {}
local completedTasks = {}

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

	-- Update on timer and on zone change (optimized - 2 second interval for alt dashboard)
	displayFrame:SetScript("OnUpdate", function(self, elapsed)
		updateTimer = updateTimer + elapsed

		-- Adjust update frequency based on view mode
		local viewMode = addon.db.display.viewMode or "current"
		local updateInterval = (viewMode == "alts") and 5 or 1 -- Alt dashboard updates less frequently

		if updateTimer >= updateInterval then
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

	-- Set initial visibility based on city/resting status
	self:UpdateCityVisibility()

	-- Initialize progression window
	self:InitializeProgressionWindow()

	-- Initialize checklist window
	self:InitializeChecklist()

	addon.Utils:Debug("Display frame initialized")
end

-- Update the display with current currency data
function Display:UpdateDisplay()
	if not displayFrame or not displayFrame.content then return end

	-- Check view mode
	local viewMode = addon.db.display.viewMode or "current"

	if viewMode == "alts" then
		self:UpdateAltDashboard()
		return
	end

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
	local columnWidth = iconSize + 65 -- Icon + text (with x/x format) + padding

	local xOffset = 2
	local yOffset = -5
	local iconCount = 0

	-- Currency display shows ONLY currencies (no vault)
	-- Great Vault is shown in the Weekly Tracker window instead

	-- Add currencies by expansion
	for _, category in ipairs(sortedCategories) do
		for _, currency in ipairs(category.currencies) do
			local currFrame = self:CreateCompactCurrencyLine(currency, category.name)

			-- Calculate position (grid layout)
			local col = iconCount % iconsPerRow
			local row = math.floor(iconCount / iconsPerRow)

			currFrame:SetPoint("TOPLEFT", displayFrame.content, "TOPLEFT",
				xOffset + (col * columnWidth), yOffset - (row * 24))

			table.insert(currencyFrames, currFrame)
			iconCount = iconCount + 1
		end
	end

	-- Calculate size based on content (currencies only)
	if iconCount == 0 then
		-- No currencies to show - hide the frame
		displayFrame:Hide()
	else
		local rows = math.max(1, math.ceil(iconCount / iconsPerRow))
		local contentWidth = (iconsPerRow * columnWidth) + 4
		local contentHeight = (rows * 24) + 10 -- 24px per row + padding

		-- Resize frame to fit content exactly
		displayFrame:SetSize(contentWidth + 16, contentHeight + 16)
		displayFrame.content:SetSize(contentWidth, contentHeight)

		-- Only show frame if we're in a city AND not manually hidden
		if IsResting() and not addon.db.display.hidden then
			displayFrame:Show()
		else
			-- Hide if outside city OR manually hidden
			if not IsResting() then
				displayFrame:Hide()
			end
		end
	end
end

-- Helper: Get gear quality color based on activity level
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
			local nameText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
			nameText:SetPoint("LEFT", 0, 0)
			nameText:SetText(vaultType.name .. ":")
			nameText:SetTextColor(0.3, 0.9, 1)

			-- Calculate how many slots unlocked (0-3)
			local current = vaultType.data.current or 0
			local thresholds = vaultType.data.thresholds or {3, 5, 8}
			local slotsUnlocked = 0
			for _, threshold in ipairs(thresholds) do
				if current >= threshold then
					slotsUnlocked = slotsUnlocked + 1
				end
			end

			-- Get level and determine color based on gear quality
			local level = vaultType.data.level or 0
			local r, g, b = GetVaultQualityColor(vaultType.name, level)

			-- Progress text showing slots unlocked
			local progressText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
			progressText:SetPoint("LEFT", nameText, "RIGHT", 3, 0)
			progressText:SetText(format("%d/3", slotsUnlocked))
			progressText:SetTextColor(r, g, b)

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
	local max = currency.max or currency.weeklyMax
	local amountText = ""

	-- Format with cap if available
	if max and max > 0 then
		-- Compact large numbers
		if max >= 1000000 then
			amountText = format("%.1fM/%.1fM", amount / 1000000, max / 1000000)
		elseif max >= 1000 then
			amountText = format("%.1fK/%.1fK", amount / 1000, max / 1000)
		else
			amountText = format("%d/%d", amount, max)
		end
	else
		-- No cap, just show amount
		if amount >= 1000000 then
			amountText = format("%.1fM", amount / 1000000)
		elseif amount >= 1000 then
			amountText = format("%.1fK", amount / 1000)
		else
			amountText = tostring(amount)
		end
	end

	local color = addon.Data:GetCurrencyColor(amount, max)

	-- Determine font size based on settings
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

	-- Tooltip on hover
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

		if currency.weeklyMax and currency.weeklyMax > 0 and currency.earnedThisWeek then
			GameTooltip:AddDoubleLine("This Week:", format("%s / %s", addon.Utils:FormatNumber(currency.earnedThisWeek), addon.Utils:FormatNumber(currency.weeklyMax)), 1, 1, 1, 1, 1, 0)
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

-- ============================================================================
-- CITY VISIBILITY (AUTO-HIDE PANEL 1 OUTSIDE CITIES)
-- ============================================================================

-- Update Panel 1 visibility based on city/resting status
function Display:UpdateCityVisibility()
	if not displayFrame then return end

	local isResting = IsResting()

	-- Only auto-hide if not manually hidden by user
	if isResting then
		-- In city - show Panel 1 (unless user manually hid it)
		if not addon.db.display.hidden then
			displayFrame:Show()
		end
	else
		-- Outside city - hide Panel 1 automatically
		displayFrame:Hide()
	end
end

-- ============================================================================
-- PANEL 2 (PROGRESSION/WEEKLY TRACKER) TOGGLE
-- ============================================================================

-- Show Panel 2
function Display:ShowProgression()
	if progressionFrame then
		progressionFrame:Show()
		if addon.db then
			addon.db.display = addon.db.display or {}
			addon.db.display.progressionHidden = false
		end
	end
end

-- Hide Panel 2
function Display:HideProgression()
	if progressionFrame then
		progressionFrame:Hide()
		if addon.db then
			addon.db.display = addon.db.display or {}
			addon.db.display.progressionHidden = true
		end
	end
end

-- Toggle Panel 2
function Display:ToggleProgression()
	if progressionFrame and progressionFrame:IsShown() then
		self:HideProgression()
	else
		self:ShowProgression()
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

-- ============================================================================
-- CHECKLIST WINDOW
-- ============================================================================

-- Initialize checklist window
function Display:InitializeChecklist()
	-- Create checklist frame
	checklistFrame = CreateFrame("Frame", "MidnightTrackerChecklist", UIParent, "BackdropTemplate")
	checklistFrame:SetSize(350, 400)
	checklistFrame:SetMovable(true)
	checklistFrame:SetClampedToScreen(true)
	checklistFrame:EnableMouse(true)
	checklistFrame:SetFrameStrata("MEDIUM")

	-- Backdrop
	if checklistFrame.SetBackdrop then
		checklistFrame:SetBackdrop({
			bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			tile = true, tileSize = 16, edgeSize = 16,
			insets = { left = 3, right = 3, top = 3, bottom = 3 }
		})
		if checklistFrame.SetBackdropColor then
			checklistFrame:SetBackdropColor(0, 0, 0, 0.9)
		end
		if checklistFrame.SetBackdropBorderColor then
			checklistFrame:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
		end
	end

	-- Title bar
	local titleBar = CreateFrame("Frame", nil, checklistFrame)
	titleBar:SetSize(350, 30)
	titleBar:SetPoint("TOP", 0, 0)
	titleBar:EnableMouse(true)
	titleBar:RegisterForDrag("LeftButton")
	titleBar:SetScript("OnDragStart", function() checklistFrame:StartMoving() end)
	titleBar:SetScript("OnDragStop", function()
		checklistFrame:StopMovingOrSizing()
		Display:SaveChecklistPosition()
	end)

	-- Title text
	local title = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("LEFT", 10, 0)
	title:SetText("Weekly To-Do")
	title:SetTextColor(0.3, 0.9, 1)

	-- Close button
	local closeBtn = CreateFrame("Button", nil, titleBar)
	closeBtn:SetSize(20, 20)
	closeBtn:SetPoint("RIGHT", -5, 0)
	closeBtn:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
	closeBtn:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down")
	closeBtn:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight", "ADD")
	closeBtn:SetScript("OnClick", function()
		Display:HideChecklist()
	end)

	-- Scroll frame for tasks
	local scrollFrame = CreateFrame("ScrollFrame", nil, checklistFrame, "UIPanelScrollFrameTemplate")
	scrollFrame:SetPoint("TOPLEFT", 10, -35)
	scrollFrame:SetPoint("BOTTOMRIGHT", -28, 10)

	local scrollChild = CreateFrame("Frame", nil, scrollFrame)
	scrollChild:SetSize(310, 1)
	scrollFrame:SetScrollChild(scrollChild)
	checklistFrame.scrollChild = scrollChild

	-- Restore position
	self:RestoreChecklistPosition()

	-- Show by default
	if addon.db.display.showChecklist then
		checklistFrame:Show()
	else
		checklistFrame:Hide()
	end

	-- Update checklist
	self:UpdateChecklist()
end

-- Update checklist with current tasks
function Display:UpdateChecklist()
	if not checklistFrame or not checklistFrame.scrollChild then return end

	-- Validate checklist generator is available
	if not addon.ChecklistGenerator then
		addon.Utils:Debug("Display: ChecklistGenerator not available")
		return
	end

	local scrollChild = checklistFrame.scrollChild

	-- Clear existing task frames
	for _, frame in ipairs(checklistTasks) do
		frame:Hide()
		frame:SetParent(nil)
	end
	wipe(checklistTasks)

	-- Generate tasks
	local options = {
		autoHideCompleted = addon.db.settings.autoHideCompleted,
		sortBy = addon.db.settings.checklistPriority == "alphabetical" and "alphabetical" or "value",
	}
	local tasks = addon.ChecklistGenerator:GetChecklist(options)

	-- Debug output
	addon.Utils:Debug(format("Checklist generated %d tasks", #tasks))

	-- Create task frames
	local yOffset = 0

	if #tasks == 0 then
		-- Show helpful message when no tasks
		local emptyFrame = CreateFrame("Frame", nil, scrollChild)
		emptyFrame:SetSize(310, 150)
		emptyFrame:SetPoint("TOPLEFT", 0, 0)

		local emptyText = emptyFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		emptyText:SetPoint("TOP", 0, -20)
		emptyText:SetText("No tasks yet!")
		emptyText:SetTextColor(0.7, 0.7, 0.7)

		local helpText = emptyFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		helpText:SetPoint("TOP", emptyText, "BOTTOM", 0, -10)
		helpText:SetWidth(280)
		helpText:SetJustifyH("CENTER")
		helpText:SetText("Tasks will appear here based on your weekly progress:\n\n• Incomplete Great Vault slots\n• World bosses\n• Available upgrades\n• Catalyst charges\n\nEnable tracking features in /mtrack config")
		helpText:SetTextColor(0.5, 0.5, 0.5)
		helpText:SetSpacing(3)

		table.insert(checklistTasks, emptyFrame)
		yOffset = 150
	else
		for i, task in ipairs(tasks) do
			local taskFrame = self:CreateChecklistTask(task, scrollChild)
			taskFrame:SetPoint("TOPLEFT", 0, -yOffset)
			table.insert(checklistTasks, taskFrame)

			yOffset = yOffset + 50 -- Height per task
		end
	end

	-- Update scroll child height
	scrollChild:SetHeight(math.max(1, yOffset))
end

-- Create a single checklist task frame
function Display:CreateChecklistTask(task, parent)
	local frame = CreateFrame("Frame", nil, parent)
	frame:SetSize(310, 48)

	-- Checkbox
	local checkbox = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
	checkbox:SetSize(24, 24)
	checkbox:SetPoint("TOPLEFT", 0, -2)
	checkbox:SetChecked(task.completed or false)
	checkbox:SetScript("OnClick", function(self)
		task.completed = self:GetChecked()
		-- Mark in completed tasks table
		if task.completed then
			completedTasks[task.type .. "_" .. (task.questID or task.vaultType or "")] = true
		else
			completedTasks[task.type .. "_" .. (task.questID or task.vaultType or "")] = nil
		end
		-- Update checklist
		Display:UpdateChecklist()
	end)

	-- Priority badge
	local priority = task.priorityLabel or "LOW"
	local priorityColor = {0.6, 0.6, 0.6} -- Default grey
	if priority == "HIGH" then
		priorityColor = {1, 0.2, 0.2} -- Red
	elseif priority == "MEDIUM" then
		priorityColor = {1, 0.8, 0} -- Yellow
	end

	local badge = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	badge:SetPoint("TOPRIGHT", 0, -2)
	badge:SetText(format("[%s]", priority))
	badge:SetTextColor(priorityColor[1], priorityColor[2], priorityColor[3])

	-- Task subject
	local subject = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	subject:SetPoint("TOPLEFT", checkbox, "TOPRIGHT", 5, -2)
	subject:SetPoint("RIGHT", badge, "LEFT", -5, 0)
	subject:SetJustifyH("LEFT")
	subject:SetText(task.subject)
	subject:SetTextColor(1, 1, 1)

	-- Task description (smaller, grey)
	local desc = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	desc:SetPoint("TOPLEFT", subject, "BOTTOMLEFT", 0, -3)
	desc:SetPoint("RIGHT", -5, 0)
	desc:SetJustifyH("LEFT")
	desc:SetText(task.description or "")
	desc:SetTextColor(0.7, 0.7, 0.7)

	-- Tooltip on hover
	frame:EnableMouse(true)
	frame:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(task.subject, 1, 1, 1)
		GameTooltip:AddLine(task.description, 0.7, 0.7, 0.7, true)
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine("Why this matters:", 0.3, 0.9, 1)
		GameTooltip:AddLine(task.reason, 1, 1, 1, true)
		GameTooltip:Show()
	end)
	frame:SetScript("OnLeave", function(self)
		GameTooltip:Hide()
	end)

	-- Strikethrough if completed
	if task.completed then
		subject:SetTextColor(0.5, 0.5, 0.5)
		desc:SetTextColor(0.4, 0.4, 0.4)
	end

	frame:Show()
	return frame
end

-- Show checklist window
function Display:ShowChecklist()
	if checklistFrame then
		checklistFrame:Show()
		addon.db.display.showChecklist = true
		self:UpdateChecklist()
	end
end

-- Hide checklist window
function Display:HideChecklist()
	if checklistFrame then
		checklistFrame:Hide()
		addon.db.display.showChecklist = false
	end
end

-- Toggle checklist window
function Display:ToggleChecklist()
	if checklistFrame and checklistFrame:IsShown() then
		self:HideChecklist()
	else
		self:ShowChecklist()
	end
end

-- Save checklist position
function Display:SaveChecklistPosition()
	if not checklistFrame then return end

	local point, _, relativePoint, xOfs, yOfs = checklistFrame:GetPoint()

	if not addon.db.display.checklistPos then
		addon.db.display.checklistPos = {}
	end

	addon.db.display.checklistPos.point = point
	addon.db.display.checklistPos.relativePoint = relativePoint
	addon.db.display.checklistPos.x = xOfs
	addon.db.display.checklistPos.y = yOfs
end

-- Restore checklist position
function Display:RestoreChecklistPosition()
	if not checklistFrame then return end

	if addon.db.display.checklistPos and addon.db.display.checklistPos.point then
		checklistFrame:ClearAllPoints()
		checklistFrame:SetPoint(
			addon.db.display.checklistPos.point,
			UIParent,
			addon.db.display.checklistPos.relativePoint or "CENTER",
			addon.db.display.checklistPos.x or 0,
			addon.db.display.checklistPos.y or 0
		)
	else
		-- Default position (left side of screen)
		checklistFrame:SetPoint("LEFT", UIParent, "LEFT", 20, 0)
	end
end

-- ============================================================================
-- PROGRESSION WINDOW (Separate from Currency Display)
-- ============================================================================

-- Initialize progression window
function Display:InitializeProgressionWindow()
	-- Create progression frame
	progressionFrame = CreateFrame("Frame", "MidnightTrackerProgression", UIParent, "BackdropTemplate")
	progressionFrame:SetSize(300, 250)
	progressionFrame:SetMovable(true)
	progressionFrame:SetClampedToScreen(true)
	progressionFrame:EnableMouse(true)
	progressionFrame:RegisterForDrag("LeftButton")
	progressionFrame:SetScript("OnDragStart", progressionFrame.StartMoving)
	progressionFrame:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		Display:SaveProgressionPosition()
	end)

	-- Backdrop
	if progressionFrame.SetBackdrop then
		progressionFrame:SetBackdrop({
			bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			tile = true, tileSize = 16, edgeSize = 16,
			insets = { left = 3, right = 3, top = 3, bottom = 3 }
		})
		if progressionFrame.SetBackdropColor then
			progressionFrame:SetBackdropColor(0, 0, 0, 0.9)
		end
		if progressionFrame.SetBackdropBorderColor then
			progressionFrame:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
		end
	end

	-- Create tabs at the top
	local tabNames = {"Daily", "Weekly", "Alts"}
	local tabWidth = 95
	local tabHeight = 25
	local tabSpacing = 3

	for i, tabName in ipairs(tabNames) do
		local tab = CreateFrame("Button", nil, progressionFrame)
		tab:SetSize(tabWidth, tabHeight)
		tab:SetPoint("TOPLEFT", 5 + ((i-1) * (tabWidth + tabSpacing)), -5)

		-- Tab background
		tab.bg = tab:CreateTexture(nil, "BACKGROUND")
		tab.bg:SetAllPoints()
		tab.bg:SetColorTexture(0.15, 0.15, 0.15, 0.9)

		-- Tab text
		tab.text = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		tab.text:SetPoint("CENTER")
		tab.text:SetText(tabName)
		tab.text:SetTextColor(0.7, 0.7, 0.7)

		-- Click handler
		tab:SetScript("OnClick", function()
			currentProgressionTab = i
			Display:UpdateProgressionTabs()
			Display:UpdateProgressionWindow()
		end)

		-- Highlight on hover
		tab:SetScript("OnEnter", function(self)
			if currentProgressionTab ~= i then
				self.bg:SetColorTexture(0.25, 0.25, 0.25, 0.9)
			end
		end)

		tab:SetScript("OnLeave", function(self)
			if currentProgressionTab ~= i then
				self.bg:SetColorTexture(0.15, 0.15, 0.15, 0.9)
			end
		end)

		progressionTabs[i] = tab
	end

	-- Content frame (below tabs)
	local content = CreateFrame("Frame", nil, progressionFrame)
	content:SetPoint("TOPLEFT", 8, -35)
	content:SetPoint("BOTTOMRIGHT", -8, 8)
	progressionFrame.content = content

	-- Restore position
	self:RestoreProgressionPosition()

	-- Restore visibility state (show by default if not set)
	if addon.db.display.progressionHidden then
		progressionFrame:Hide()
	else
		progressionFrame:Show()
	end

	-- Update progression window every 2 seconds (faster updates)
	local progTimer = 0
	progressionFrame:SetScript("OnUpdate", function(self, elapsed)
		progTimer = progTimer + elapsed
		if progTimer >= 2 then
			Display:UpdateProgressionWindow()
			progTimer = 0
		end
	end)

	-- Initial update
	self:UpdateProgressionTabs()
	self:UpdateProgressionWindow()
end

-- Update tab highlighting
function Display:UpdateProgressionTabs()
	for i, tab in ipairs(progressionTabs) do
		if i == currentProgressionTab then
			-- Active tab
			tab.bg:SetColorTexture(0.3, 0.3, 0.3, 0.9)
			tab.text:SetTextColor(1, 0.82, 0)
		else
			-- Inactive tab
			tab.bg:SetColorTexture(0.15, 0.15, 0.15, 0.9)
			tab.text:SetTextColor(0.7, 0.7, 0.7)
		end
	end
end

-- Update progression window based on active tab
function Display:UpdateProgressionWindow()
	if not progressionFrame or not progressionFrame.content then return end

	-- Clear existing frames
	for _, frame in ipairs(progressionFrames) do
		frame:Hide()
		frame:SetParent(nil)
	end
	wipe(progressionFrames)

	-- Display content based on active tab
	if currentProgressionTab == 1 then
		self:UpdateProgressionDailyTab()
	elseif currentProgressionTab == 2 then
		self:UpdateProgressionWeeklyTab()
	elseif currentProgressionTab == 3 then
		self:UpdateProgressionAltsTab()
	end
end

-- ============================================================================
-- TAB 1: DAILY ACTIVITIES
-- ============================================================================

function Display:UpdateProgressionDailyTab()
	if not progressionFrame or not progressionFrame.content then return end

	local content = progressionFrame.content
	local yOffset = 0
	local xOffset = 10

	-- Get data
	local data = addon.Tracker:GetAllTrackables()

	-- WoW Token section
	if C_WowTokenPublic and C_WowTokenPublic.GetCurrentMarketPrice then
		local header = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
		header:SetPoint("TOPLEFT", xOffset, yOffset)
		header:SetText("WoW Token")
		header:SetTextColor(1, 0.82, 0)
		table.insert(progressionFrames, header)
		yOffset = yOffset - 20

		local tokenPrice = C_WowTokenPublic.GetCurrentMarketPrice()
		if tokenPrice and tokenPrice > 0 then
			-- Convert copper to gold
			local gold = math.floor(tokenPrice / 10000)

			-- Format with commas (e.g., 123,456g)
			local goldStr = tostring(gold)
			local formatted = goldStr:reverse():gsub("(%d%d%d)", "%1,"):reverse()
			if formatted:sub(1, 1) == "," then
				formatted = formatted:sub(2)
			end

			local priceText = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
			priceText:SetPoint("TOPLEFT", xOffset + 5, yOffset)
			priceText:SetText(format("Current Price: %sg", formatted))
			priceText:SetTextColor(1, 0.84, 0) -- Gold color
			table.insert(progressionFrames, priceText)
			yOffset = yOffset - 18
		else
			local unavailableText = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
			unavailableText:SetPoint("TOPLEFT", xOffset + 5, yOffset)
			unavailableText:SetText("Price unavailable")
			unavailableText:SetTextColor(0.6, 0.6, 0.6)
			table.insert(progressionFrames, unavailableText)
			yOffset = yOffset - 18
		end

		yOffset = yOffset - 8
	end

	-- Cooldowns section
	if addon.db.settings.showCooldowns and addon.CooldownTracker then
		local header = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
		header:SetPoint("TOPLEFT", xOffset, yOffset)
		header:SetText("Cooldowns")
		header:SetTextColor(1, 0.82, 0)
		table.insert(progressionFrames, header)
		yOffset = yOffset - 20

		yOffset = self:AddProgressionCooldowns(content, yOffset, xOffset)
		yOffset = yOffset - 8
	end

	-- Special Assignments section
	if addon.DailyTracker then
		local dailyHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
		dailyHeader:SetPoint("TOPLEFT", xOffset, yOffset)
		dailyHeader:SetText("Special Assignments")
		dailyHeader:SetTextColor(1, 0.82, 0)
		table.insert(progressionFrames, dailyHeader)
		yOffset = yOffset - 20

		local activeAssignment = addon.DailyTracker:GetActiveSpecialAssignment()
		if activeAssignment then
			-- Show active assignment
			local assignmentText = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
			assignmentText:SetPoint("TOPLEFT", xOffset + 5, yOffset)
			assignmentText:SetText(format("%s (%s)", activeAssignment.name, activeAssignment.zone))
			assignmentText:SetTextColor(1, 1, 1)
			table.insert(progressionFrames, assignmentText)
			yOffset = yOffset - 18

			local statusText = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
			statusText:SetPoint("TOPLEFT", xOffset + 10, yOffset)
			if activeAssignment.completed then
				statusText:SetText("✓ Completed")
				statusText:SetTextColor(0, 1, 0)
			else
				statusText:SetText("○ Incomplete")
				statusText:SetTextColor(1, 0.8, 0)
			end
			table.insert(progressionFrames, statusText)
			yOffset = yOffset - 18
		else
			-- All assignments completed
			local completedText = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
			completedText:SetPoint("TOPLEFT", xOffset + 5, yOffset)
			completedText:SetText("✓ All assignments completed!")
			completedText:SetTextColor(0, 1, 0)
			table.insert(progressionFrames, completedText)
			yOffset = yOffset - 18
		end

		yOffset = yOffset - 8
	end

	-- Resize frame
	local contentHeight = math.max(100, math.abs(yOffset) + 15)
	progressionFrame:SetSize(300, contentHeight + 40)
end

-- ============================================================================
-- TAB 2: WEEKLY ACTIVITIES
-- ============================================================================

function Display:UpdateProgressionWeeklyTab()
	if not progressionFrame or not progressionFrame.content then return end

	local content = progressionFrame.content
	local yOffset = 0
	local xOffset = 10
	local contentWidth = 280

	-- Get data
	local data = addon.Tracker:GetAllTrackables()
	local sectionsShown = 0

	-- World Bosses section
	if addon.db.settings.showWorldBosses and addon.WeeklyTracker then
		local worldBosses = addon.WeeklyTracker:GetAllWorldBosses()

		if worldBosses and next(worldBosses) then
			local header = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
			header:SetPoint("TOPLEFT", xOffset, yOffset)
			header:SetText("World Bosses")
			header:SetTextColor(1, 0.82, 0)
			table.insert(progressionFrames, header)
			yOffset = yOffset - 20

			-- Show all world bosses (green if done, yellow if not)
			yOffset = self:AddProgressionWorldBosses(content, worldBosses, yOffset, xOffset)

			yOffset = yOffset - 8
			sectionsShown = sectionsShown + 1
		end
	end

	-- Weekly Quests section
	if addon.WeeklyTracker then
		local weeklyQuests = addon.WeeklyTracker:GetAllWeeklyQuests()

		if weeklyQuests and next(weeklyQuests) then
			-- Group quests by category
			local worldsoulQuests = {}
			local zoneEventQuests = {}

			for questID, quest in pairs(weeklyQuests) do
				if quest.category == "Worldsoul" then
					table.insert(worldsoulQuests, quest)
				elseif quest.category == "Zone Event" then
					table.insert(zoneEventQuests, quest)
				end
			end

			-- Worldsoul Weeklies
			if #worldsoulQuests > 0 then
				local header = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
				header:SetPoint("TOPLEFT", xOffset, yOffset)
				header:SetText("Worldsoul Weeklies")
				header:SetTextColor(1, 0.82, 0)
				table.insert(progressionFrames, header)
				yOffset = yOffset - 20

				for _, quest in ipairs(worldsoulQuests) do
					local questText = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
					questText:SetPoint("TOPLEFT", xOffset + 5, yOffset)
					questText:SetWidth(contentWidth - 10)
					questText:SetJustifyH("LEFT")

					local checkmark = quest.completed and "✓" or "○"
					local color = quest.completed and {0, 1, 0} or {1, 0.8, 0}
					questText:SetText(format("%s %s", checkmark, quest.name))
					questText:SetTextColor(color[1], color[2], color[3])
					table.insert(progressionFrames, questText)
					yOffset = yOffset - 16
				end

				yOffset = yOffset - 8
				sectionsShown = sectionsShown + 1
			end

			-- Zone Events
			if #zoneEventQuests > 0 then
				local header = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
				header:SetPoint("TOPLEFT", xOffset, yOffset)
				header:SetText("Zone Events")
				header:SetTextColor(1, 0.82, 0)
				table.insert(progressionFrames, header)
				yOffset = yOffset - 20

				for _, quest in ipairs(zoneEventQuests) do
					local questText = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
					questText:SetPoint("TOPLEFT", xOffset + 5, yOffset)
					questText:SetWidth(contentWidth - 10)
					questText:SetJustifyH("LEFT")

					local checkmark = quest.completed and "✓" or "○"
					local color = quest.completed and {0, 1, 0} or {1, 0.8, 0}
					local displayName = quest.zone and format("%s (%s)", quest.name, quest.zone) or quest.name
					questText:SetText(format("%s %s", checkmark, displayName))
					questText:SetTextColor(color[1], color[2], color[3])
					table.insert(progressionFrames, questText)
					yOffset = yOffset - 16
				end

				yOffset = yOffset - 8
				sectionsShown = sectionsShown + 1
			end
		end
	end

	-- Raid Lockouts section
	if addon.db.settings.showRaidLockouts and addon.WeeklyTracker then
		local lockouts = addon.WeeklyTracker:GetAllRaidLockouts()
		local hasLockouts = lockouts and next(lockouts)

		if hasLockouts or true then -- Always show section
			local header = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
			header:SetPoint("TOPLEFT", xOffset, yOffset)
			header:SetText("Raid Lockouts")
			header:SetTextColor(1, 0.82, 0)
			table.insert(progressionFrames, header)
			yOffset = yOffset - 20

			if hasLockouts then
				yOffset = self:AddProgressionRaidLockouts(content, lockouts, yOffset, xOffset)
			else
				local noneText = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
				noneText:SetPoint("TOPLEFT", xOffset + 5, yOffset)
				noneText:SetText("No raid lockouts")
				noneText:SetTextColor(0.6, 0.6, 0.6)
				table.insert(progressionFrames, noneText)
				yOffset = yOffset - 16
			end

			yOffset = yOffset - 8
			sectionsShown = sectionsShown + 1
		end
	end

	-- Great Vault section (ALWAYS show in Weekly Tracker)
	if data.greatVault then
		local header = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
		header:SetPoint("TOPLEFT", xOffset, yOffset)
		header:SetText("Great Vault")
		header:SetTextColor(1, 0.82, 0)
		table.insert(progressionFrames, header)
		yOffset = yOffset - 20

		yOffset = self:AddProgressionGreatVault(content, data.greatVault, yOffset, xOffset)
		yOffset = yOffset - 8
		sectionsShown = sectionsShown + 1
	end

	-- Upgrade Context section
	if addon.db.settings.showUpgradeContext and addon.UpgradeTracker then
		local header = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
		header:SetPoint("TOPLEFT", xOffset, yOffset)
		header:SetText("Upgrades")
		header:SetTextColor(1, 0.82, 0)
		table.insert(progressionFrames, header)
		yOffset = yOffset - 20

		yOffset = self:AddProgressionUpgradeContext(content, yOffset, xOffset)
		yOffset = yOffset - 8
		sectionsShown = sectionsShown + 1
	end

	-- Cooldowns section
	if addon.db.settings.showCooldowns and addon.CooldownTracker then
		local header = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
		header:SetPoint("TOPLEFT", xOffset, yOffset)
		header:SetText("Cooldowns")
		header:SetTextColor(1, 0.82, 0)
		table.insert(progressionFrames, header)
		yOffset = yOffset - 20

		yOffset = self:AddProgressionCooldowns(content, yOffset, xOffset)
		yOffset = yOffset - 8
		sectionsShown = sectionsShown + 1
	end

	-- If no sections shown, display message
	if sectionsShown == 0 then
		local emptyText = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		emptyText:SetPoint("TOP", 0, -40)
		emptyText:SetText("Enable features in\n/mtrack config")
		emptyText:SetTextColor(0.6, 0.6, 0.6)
		table.insert(progressionFrames, emptyText)
		yOffset = -80
	end

	-- Resize frame to fit content (add space for tabs)
	local contentHeight = math.max(100, math.abs(yOffset) + 15)
	progressionFrame:SetSize(300, contentHeight + 40)
end

-- ============================================================================
-- TAB 3: ALTS
-- ============================================================================

function Display:UpdateProgressionAltsTab()
	if not progressionFrame or not progressionFrame.content then return end

	local content = progressionFrame.content
	local yOffset = -10
	local xOffset = 5

	-- Lazy-load alt data
	if not addon.AltManager then
		local emptyText = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		emptyText:SetPoint("TOP", 0, -40)
		emptyText:SetText("AltManager not available")
		emptyText:SetTextColor(0.6, 0.6, 0.6)
		table.insert(progressionFrames, emptyText)
		progressionFrame:SetSize(300, 120)
		return
	end

	-- Get all alts
	local sortOrder = addon.db.settings.altSortOrder or "completion"
	local alts = addon.AltManager:GetSortedAlts(sortOrder)

	-- Get crest icons from currency data
	local function GetCrestIcon(currencyID)
		if C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
			local info = C_CurrencyInfo.GetCurrencyInfo(currencyID)
			if info and info.iconFileID then
				return info.iconFileID
			end
		end
		return nil
	end

	-- Column definitions
	local columns = {
		{header = "Character", width = 85, align = "LEFT"},
		{header = "Lvl", width = 28, align = "CENTER"},
		{header = "iLvl", width = 35, align = "CENTER"}, -- Item Level
		{header = "Rating", width = 48, align = "CENTER"}, -- M+ Rating
		{header = "M+", width = 55, align = "CENTER"}, -- Mythic+ vault
		{header = "Raid", width = 50, align = "CENTER"}, -- Raid vault
		{header = "Delve", width = 50, align = "CENTER"}, -- Delve vault
		{header = "icon", width = 35, align = "CENTER", icon = GetCrestIcon(3285)}, -- Weathered Crest
		{header = "icon", width = 35, align = "CENTER", icon = GetCrestIcon(3288)}, -- Carved Crest
		{header = "icon", width = 35, align = "CENTER", icon = GetCrestIcon(3289)}, -- Runed Crest
		{header = "icon", width = 35, align = "CENTER", icon = GetCrestIcon(3290)}, -- Gilded Crest
		{header = "Key", width = 75, align = "LEFT"}, -- Current Keystone
		{header = "Done", width = 38, align = "RIGHT"},
		{header = "", width = 20, align = "CENTER"}, -- Delete button
	}

	-- Calculate total width
	local totalWidth = 10 -- padding
	for _, col in ipairs(columns) do
		totalWidth = totalWidth + col.width
	end

	-- Create header row
	local headerBg = CreateFrame("Frame", nil, content, "BackdropTemplate")
	headerBg:SetSize(totalWidth, 20)
	headerBg:SetPoint("TOPLEFT", xOffset, yOffset)
	if headerBg.SetBackdrop then
		headerBg:SetBackdrop({
			bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
		})
		if headerBg.SetBackdropColor then
			headerBg:SetBackdropColor(0.2, 0.2, 0.2, 0.8)
		end
	end
	table.insert(progressionFrames, headerBg)

	local colX = 5
	for i, col in ipairs(columns) do
		local header = CreateFrame("Button", nil, headerBg)
		header:SetSize(col.width, 20)
		header:SetPoint("LEFT", colX, 0)

		if col.icon then
			-- Use icon instead of text
			local icon = header:CreateTexture(nil, "ARTWORK")
			icon:SetSize(16, 16)
			icon:SetPoint("CENTER")
			icon:SetTexture(col.icon)
			icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
			header.icon = icon
		else
			-- Use text label
			local text = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
			text:SetPoint("CENTER")
			text:SetText(col.header)
			text:SetTextColor(1, 0.82, 0)
			header.text = text

			-- Hover highlight for text headers
			header:SetScript("OnEnter", function()
				if header.text then
					header.text:SetTextColor(1, 1, 0)
				end
			end)
			header:SetScript("OnLeave", function()
				if header.text then
					header.text:SetTextColor(1, 0.82, 0)
				end
			end)
		end

		-- Click to sort
		header:SetScript("OnClick", function()
			if i == 1 then sortOrder = "name"
			elseif i == 3 then sortOrder = "ilvl" -- Item Level
			elseif i == 4 then sortOrder = "rating" -- M+ Rating
			elseif i == 5 or i == 6 or i == 7 then sortOrder = "vault" -- M+, Raid, Delve
			elseif i == 13 then sortOrder = "completion" -- Done %
			end
			addon.db.settings.altSortOrder = sortOrder
			self:UpdateProgressionWindow()
		end)

		table.insert(progressionFrames, header)
		colX = colX + col.width
	end

	yOffset = yOffset - 22

	-- No alts found
	if #alts == 0 then
		local emptyText = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		emptyText:SetPoint("TOP", 0, yOffset - 20)
		emptyText:SetText("No alts found\nLog in with other characters")
		emptyText:SetTextColor(0.6, 0.6, 0.6)
		table.insert(progressionFrames, emptyText)
		progressionFrame:SetSize(totalWidth + 20, 120)
		return
	end

	-- Create rows for each alt
	for _, alt in ipairs(alts) do
		yOffset = self:CreateAltGridRow(content, alt, columns, xOffset, yOffset, totalWidth)
	end

	-- Resize frame
	local contentHeight = math.abs(yOffset) + 15
	progressionFrame:SetSize(totalWidth + 20, contentHeight + 40)
end

--- Create a single alt row for grid display
function Display:CreateAltGridRow(parent, alt, columns, xOffset, yOffset, totalWidth)
	-- Check if this is the current logged-in character
	local currentName = UnitName("player")
	local currentRealm = GetRealmName()
	local isCurrentChar = (alt.name == currentName and alt.realm == currentRealm)

	-- Use live data for current character instead of snapshot (don't modify original alt object)
	local mythicplusData = alt.mythicplus
	if isCurrentChar and addon.MythicPlusTracker then
		mythicplusData = addon.MythicPlusTracker:GetSnapshotData()
	end

	-- Class colors
	local classColors = {
		WARRIOR = {0.78, 0.61, 0.43},
		PALADIN = {0.96, 0.55, 0.73},
		HUNTER = {0.67, 0.83, 0.45},
		ROGUE = {1.00, 0.96, 0.41},
		PRIEST = {1.00, 1.00, 1.00},
		DEATHKNIGHT = {0.77, 0.12, 0.23},
		SHAMAN = {0.00, 0.44, 0.87},
		MAGE = {0.25, 0.78, 0.92},
		WARLOCK = {0.53, 0.53, 0.93},
		MONK = {0.00, 1.00, 0.59},
		DRUID = {1.00, 0.49, 0.04},
		DEMONHUNTER = {0.64, 0.19, 0.79},
		EVOKER = {0.20, 0.58, 0.50},
	}

	-- Row background (alternating)
	local rowBg = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	rowBg:SetSize(totalWidth, 18)
	rowBg:SetPoint("TOPLEFT", xOffset, yOffset)
	if rowBg.SetBackdrop then
		rowBg:SetBackdrop({
			bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
		})
		if rowBg.SetBackdropColor then
			rowBg:SetBackdropColor(0.1, 0.1, 0.1, 0.3)
		end
	end
	table.insert(progressionFrames, rowBg)

	local colX = 5

	-- Column 1: Character name (with class color)
	local classColor = classColors[alt.class] or {1, 1, 1}
	local nameText = rowBg:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	nameText:SetPoint("LEFT", colX, 0)
	nameText:SetWidth(columns[1].width)
	nameText:SetJustifyH("LEFT")
	nameText:SetText(alt.name or "Unknown")
	nameText:SetTextColor(classColor[1], classColor[2], classColor[3])
	colX = colX + columns[1].width

	-- Column 2: Level
	local levelText = rowBg:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	levelText:SetPoint("LEFT", colX, 0)
	levelText:SetWidth(columns[2].width)
	levelText:SetJustifyH("CENTER")
	levelText:SetText(alt.level or "??")
	levelText:SetTextColor(0.8, 0.8, 0.8)
	colX = colX + columns[2].width

	-- Column 3: Item Level
	local ilvlText = rowBg:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	ilvlText:SetPoint("LEFT", colX, 0)
	ilvlText:SetWidth(columns[3].width)
	ilvlText:SetJustifyH("CENTER")

	if mythicplusData and mythicplusData.itemLevel then
		ilvlText:SetText(tostring(mythicplusData.itemLevel))
		local ilvl = mythicplusData.itemLevel
		if ilvl >= 545 then
			ilvlText:SetTextColor(0.64, 0.21, 0.93) -- Purple - Myth track
		elseif ilvl >= 535 then
			ilvlText:SetTextColor(1, 0.5, 0) -- Orange - Hero track
		elseif ilvl >= 525 then
			ilvlText:SetTextColor(0, 0.44, 0.87) -- Blue - Champion track
		elseif ilvl >= 515 then
			ilvlText:SetTextColor(0, 1, 0) -- Green - Veteran track
		else
			ilvlText:SetTextColor(0.6, 0.6, 0.6) -- Gray - Adventurer track
		end
	else
		ilvlText:SetText("-")
		ilvlText:SetTextColor(0.4, 0.4, 0.4)
	end
	colX = colX + columns[3].width

	-- Column 4: M+ Rating
	local ratingFrame = CreateFrame("Frame", nil, rowBg)
	ratingFrame:SetSize(columns[4].width, 18)
	ratingFrame:SetPoint("LEFT", colX, 0)

	local ratingText = ratingFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	ratingText:SetPoint("CENTER")
	ratingText:SetWidth(columns[4].width)
	ratingText:SetJustifyH("CENTER")

	if mythicplusData and mythicplusData.rating then
		local rating = mythicplusData.rating
		ratingText:SetText(tostring(rating))
		if addon.MythicPlusTracker then
			local ratingColor = addon.MythicPlusTracker:GetRatingColor(rating)
			ratingText:SetTextColor(ratingColor[1], ratingColor[2], ratingColor[3])
		else
			if rating >= 2500 then
				ratingText:SetTextColor(1, 0.5, 0)
			elseif rating >= 2000 then
				ratingText:SetTextColor(0.64, 0.21, 0.93)
			elseif rating >= 1500 then
				ratingText:SetTextColor(0, 0.44, 0.87)
			else
				ratingText:SetTextColor(0.6, 0.6, 0.6)
			end
		end

		-- Add tooltip with dungeon scores
		ratingFrame:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(format("%s - M+ Rating: %d", alt.name, rating), 1, 0.82, 0)
			GameTooltip:AddLine(" ")

			if mythicplusData and mythicplusData.dungeons then
				-- Show best runs for each dungeon (prioritize timed runs)
				for dungeonID, dungeonData in pairs(mythicplusData.dungeons) do
					local dungeonName = C_ChallengeMode.GetMapUIInfo(dungeonID) or dungeonData.name or "Unknown"

					-- Get best timed and best overall
					local bestTimed = math.max(dungeonData.fortified.bestTimed or 0, dungeonData.tyrannical.bestTimed or 0)
					local bestOverall = math.max(dungeonData.fortified.best or 0, dungeonData.tyrannical.best or 0)

					if bestTimed > 0 then
						-- Show best timed run with upgrade level
						local bestUpgrade = 0
						if (dungeonData.fortified.bestTimed or 0) >= (dungeonData.tyrannical.bestTimed or 0) then
							bestUpgrade = dungeonData.fortified.bestTimedUpgradeLevel or 0
						else
							bestUpgrade = dungeonData.tyrannical.bestTimedUpgradeLevel or 0
						end
						local upgradeSuffix = string.rep("+", bestUpgrade)
						local displayText = format("%d%s", bestTimed, upgradeSuffix)
						GameTooltip:AddDoubleLine("  " .. dungeonName .. ":", displayText, 0.7, 0.7, 0.7, 0, 1, 0)
					elseif bestOverall > 0 then
						-- Show depleted run in gray (only if no timed runs exist)
						local displayText = format("%d", bestOverall)
						GameTooltip:AddDoubleLine("  " .. dungeonName .. ":", displayText, 0.7, 0.7, 0.7, 0.7, 0.7, 0.7)
					end
				end
			end

			GameTooltip:Show()
		end)
		ratingFrame:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
	else
		ratingText:SetText("-")
		ratingText:SetTextColor(0.4, 0.4, 0.4)
	end
	table.insert(progressionFrames, ratingFrame)
	colX = colX + columns[4].width

	-- Column 5: Mythic+ vault (key levels for each slot: slot1/slot2/slot3)
	local mplusFrame = CreateFrame("Frame", nil, rowBg)
	mplusFrame:SetSize(columns[5].width, 18)
	mplusFrame:SetPoint("LEFT", colX, 0)

	local mplusText = mplusFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	mplusText:SetPoint("CENTER")
	mplusText:SetWidth(columns[5].width)
	mplusText:SetJustifyH("CENTER")

	if alt.vault and alt.vault.mythicplus then
		local current = alt.vault.mythicplus.current or 0
		local levels = alt.vault.mythicplus.levels or {0, 0, 0}
		local thresholds = alt.vault.mythicplus.thresholds or {3, 5, 8}

		-- Show key level for each slot (0 if not unlocked)
		local slot1 = current >= thresholds[1] and levels[1] or 0
		local slot2 = current >= thresholds[2] and levels[2] or 0
		local slot3 = current >= thresholds[3] and levels[3] or 0

		local mplusStr = format("%d/%d/%d", slot1, slot2, slot3)
		mplusText:SetText(mplusStr)

		-- Color based on slots unlocked
		local slots = self:GetVaultSlotsUnlocked(alt.vault.mythicplus)
		if slots >= 3 then
			mplusText:SetTextColor(0, 1, 0) -- Green - max slots
		elseif slots >= 1 then
			mplusText:SetTextColor(1, 0.8, 0) -- Yellow - some slots
		else
			mplusText:SetTextColor(0.5, 0.5, 0.5) -- Gray - no slots
		end

		-- Add tooltip with weekly runs
		mplusFrame:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(format("%s - Weekly M+ Runs", alt.name), 1, 0.82, 0)
			GameTooltip:AddLine(" ")

			-- Weekly dungeon runs breakdown
			if mythicplusData and mythicplusData.weeklyRuns and #mythicplusData.weeklyRuns > 0 then

				-- Build runs map from weeklyRuns
				local runsMap = {}
				for _, run in ipairs(mythicplusData.weeklyRuns) do
					local mapID = run.mapID
					if not runsMap[mapID] then
						runsMap[mapID] = {
							name = nil,
							runs = {}
						}
					end
					table.insert(runsMap[mapID].runs, {
						level = run.level,
						completed = run.completed
					})
				end

				-- Display all dungeons that were actually run
				for mapID, data in pairs(runsMap) do
					-- ALWAYS get dungeon name from API (don't trust snapshot data)
					local dungeonName = "Unknown Dungeon"
					if C_ChallengeMode and C_ChallengeMode.GetMapUIInfo then
						dungeonName = C_ChallengeMode.GetMapUIInfo(mapID) or dungeonName
					end

					-- Build run text with color coding
					local runText = ""
					for i, run in ipairs(data.runs) do
						if i > 1 then runText = runText .. ", " end

						-- Color code: green if timed, red if overtime
						if run.completed then
							runText = runText .. "|cFF00FF00" .. tostring(run.level) .. "|r"
						else
							runText = runText .. "|cFFFF0000" .. tostring(run.level) .. "|r"
						end
					end

					GameTooltip:AddDoubleLine("  " .. dungeonName .. ":", runText, 0.7, 0.7, 0.7, 1, 1, 1)
				end
			end

			GameTooltip:Show()
		end)
		mplusFrame:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
	else
		mplusText:SetText("0/0/0")
		mplusText:SetTextColor(0.5, 0.5, 0.5)
	end
	table.insert(progressionFrames, mplusFrame)
	colX = colX + columns[5].width

	-- Column 6: Raid vault (difficulty for each slot: slot1/slot2/slot3)
	local raidFrame = CreateFrame("Frame", nil, rowBg)
	raidFrame:SetSize(columns[6].width, 18)
	raidFrame:SetPoint("LEFT", colX, 0)

	local raidText = raidFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	raidText:SetPoint("CENTER")
	raidText:SetWidth(columns[6].width)
	raidText:SetJustifyH("CENTER")

	if alt.vault and alt.vault.raid then
		local current = alt.vault.raid.current or 0
		local levels = alt.vault.raid.levels or {0, 0, 0}
		local thresholds = alt.vault.raid.thresholds or {3, 5, 8}

		-- Convert difficulty IDs to letters (14=Normal, 15=Heroic, 16=Mythic)
		local function getDiffLetter(level)
			return level == 16 and "M" or (level == 15 and "H" or (level == 14 and "N" or "-"))
		end

		-- Show difficulty letter for each slot (- if not unlocked)
		local slot1 = current >= thresholds[1] and getDiffLetter(levels[1]) or "-"
		local slot2 = current >= thresholds[2] and getDiffLetter(levels[2]) or "-"
		local slot3 = current >= thresholds[3] and getDiffLetter(levels[3]) or "-"

		local raidStr = format("%s/%s/%s", slot1, slot2, slot3)
		raidText:SetText(raidStr)

		local slots = self:GetVaultSlotsUnlocked(alt.vault.raid)
		if slots >= 3 then
			raidText:SetTextColor(0, 1, 0) -- Green - max slots
		elseif slots >= 1 then
			raidText:SetTextColor(1, 0.8, 0) -- Yellow - some slots
		else
			raidText:SetTextColor(0.5, 0.5, 0.5) -- Gray - no slots
		end

		-- Add tooltip showing raid lockouts
		raidFrame:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(format("%s - Raid Lockouts", alt.name), 1, 0.82, 0)
			GameTooltip:AddLine(" ")

			if alt.raids and next(alt.raids) then
				-- Group by highest difficulty
				local raidsByInstance = {}
				for instanceID, difficulties in pairs(alt.raids) do
					local highestDiff = nil
					local highestDiffID = 0
					for diffID, lockout in pairs(difficulties) do
						if diffID > highestDiffID then
							highestDiffID = diffID
							highestDiff = lockout
						end
					end
					if highestDiff then
						raidsByInstance[instanceID] = {lockout = highestDiff, diffID = highestDiffID}
					end
				end

				-- Display each raid
				for instanceID, data in pairs(raidsByInstance) do
					local lockout = data.lockout
					local diffID = data.diffID
					local raidName = lockout.instanceName or "Unknown Raid"
					local diffName = diffID == 17 and "L" or (diffID == 14 and "N" or (diffID == 15 and "H" or "M"))
					local progress = format("%d/%d", lockout.encounterProgress or 0, lockout.numEncounters or 0)

					GameTooltip:AddDoubleLine("  " .. raidName .. ":", format("%s - %s", diffName, progress), 0.7, 0.7, 0.7, 1, 1, 1)
				end
			else
				GameTooltip:AddLine("  No raid lockouts", 0.6, 0.6, 0.6)
			end

			GameTooltip:Show()
		end)
		raidFrame:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
	else
		raidText:SetText("-/-/-")
		raidText:SetTextColor(0.5, 0.5, 0.5)
	end
	table.insert(progressionFrames, raidFrame)
	colX = colX + columns[6].width

	-- Column 7: Delve vault (tier for each slot: slot1/slot2/slot3)
	local delveFrame = CreateFrame("Frame", nil, rowBg)
	delveFrame:SetSize(columns[7].width, 18)
	delveFrame:SetPoint("LEFT", colX, 0)

	local delveText = delveFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	delveText:SetPoint("CENTER")
	delveText:SetWidth(columns[7].width)
	delveText:SetJustifyH("CENTER")

	if alt.vault and alt.vault.world then
		local current = alt.vault.world.current or 0
		local levels = alt.vault.world.levels or {0, 0, 0}
		local thresholds = alt.vault.world.thresholds or {3, 5, 8}

		-- Show tier level for each slot (0 if not unlocked)
		local slot1 = current >= thresholds[1] and levels[1] or 0
		local slot2 = current >= thresholds[2] and levels[2] or 0
		local slot3 = current >= thresholds[3] and levels[3] or 0

		local delveStr = format("%d/%d/%d", slot1, slot2, slot3)
		delveText:SetText(delveStr)

		local slots = self:GetVaultSlotsUnlocked(alt.vault.world)
		if slots >= 3 then
			delveText:SetTextColor(0, 1, 0) -- Green - max slots
		elseif slots >= 1 then
			delveText:SetTextColor(1, 0.8, 0) -- Yellow - some slots
		else
			delveText:SetTextColor(0.5, 0.5, 0.5) -- Gray - no slots
		end

		-- Add tooltip showing delve progress
		delveFrame:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(format("%s - Delve Progress", alt.name), 1, 0.82, 0)
			GameTooltip:AddLine(" ")

			GameTooltip:AddDoubleLine("Highest Tier:", format("Tier %d", level), 0.7, 0.7, 0.7, 1, 1, 1)
			GameTooltip:AddDoubleLine("Activities:", format("%d / 8", current), 0.7, 0.7, 0.7, 1, 1, 1)
			GameTooltip:AddLine(" ")
			GameTooltip:AddLine("Vault Slots:", 1, 0.82, 0)
			GameTooltip:AddDoubleLine("  Slot 1:", slot1 > 0 and format("Tier %d", slot1) or "Not unlocked", 0.7, 0.7, 0.7, slot1 > 0 and 0 or 1, slot1 > 0 and 1 or 0.5, slot1 > 0 and 0 or 0.5)
			GameTooltip:AddDoubleLine("  Slot 2:", slot2 > 0 and format("Tier %d", slot2) or "Not unlocked", 0.7, 0.7, 0.7, slot2 > 0 and 0 or 1, slot2 > 0 and 1 or 0.5, slot2 > 0 and 0 or 0.5)
			GameTooltip:AddDoubleLine("  Slot 3:", slot3 > 0 and format("Tier %d", slot3) or "Not unlocked", 0.7, 0.7, 0.7, slot3 > 0 and 0 or 1, slot3 > 0 and 1 or 0.5, slot3 > 0 and 0 or 0.5)

			GameTooltip:Show()
		end)
		delveFrame:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
	else
		delveText:SetText("0/0/0")
		delveText:SetTextColor(0.5, 0.5, 0.5)
	end
	table.insert(progressionFrames, delveFrame)
	colX = colX + columns[7].width

	-- Column 8: Weathered Crest (3285)
	local weatheredText = rowBg:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	weatheredText:SetPoint("LEFT", colX, 0)
	weatheredText:SetWidth(columns[8].width)
	weatheredText:SetJustifyH("CENTER")
	if alt.currencies and alt.currencies[3285] then
		local amount = alt.currencies[3285].amount or 0
		weatheredText:SetText(tostring(amount))
		weatheredText:SetTextColor(0.6, 0.6, 0.6)
	else
		weatheredText:SetText("0")
		weatheredText:SetTextColor(0.4, 0.4, 0.4)
	end
	colX = colX + columns[8].width

	-- Column 9: Carved Crest (3288)
	local carvedText = rowBg:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	carvedText:SetPoint("LEFT", colX, 0)
	carvedText:SetWidth(columns[9].width)
	carvedText:SetJustifyH("CENTER")
	if alt.currencies and alt.currencies[3288] then
		local amount = alt.currencies[3288].amount or 0
		carvedText:SetText(tostring(amount))
		carvedText:SetTextColor(0.6, 0.6, 0.6)
	else
		carvedText:SetText("0")
		carvedText:SetTextColor(0.4, 0.4, 0.4)
	end
	colX = colX + columns[9].width

	-- Column 10: Runed Crest (3289)
	local runedText = rowBg:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	runedText:SetPoint("LEFT", colX, 0)
	runedText:SetWidth(columns[10].width)
	runedText:SetJustifyH("CENTER")
	if alt.currencies and alt.currencies[3289] then
		local amount = alt.currencies[3289].amount or 0
		runedText:SetText(tostring(amount))
		runedText:SetTextColor(0.6, 0.6, 0.6)
	else
		runedText:SetText("0")
		runedText:SetTextColor(0.4, 0.4, 0.4)
	end
	colX = colX + columns[10].width

	-- Column 11: Gilded Crest (3290)
	local gildedText = rowBg:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	gildedText:SetPoint("LEFT", colX, 0)
	gildedText:SetWidth(columns[11].width)
	gildedText:SetJustifyH("CENTER")
	if alt.currencies and alt.currencies[3290] then
		local amount = alt.currencies[3290].amount or 0
		gildedText:SetText(tostring(amount))
		gildedText:SetTextColor(0.6, 0.6, 0.6)
	else
		gildedText:SetText("0")
		gildedText:SetTextColor(0.4, 0.4, 0.4)
	end
	colX = colX + columns[11].width

	-- Column 12: Current Keystone
	local keyText = rowBg:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	keyText:SetPoint("LEFT", colX, 0)
	keyText:SetWidth(columns[12].width)
	keyText:SetJustifyH("LEFT")
	if mythicplusData and mythicplusData.currentKey then
		local key = mythicplusData.currentKey
		local abbrev = ""
		for word in string.gmatch(key.name, "%S+") do
			abbrev = abbrev .. string.sub(word, 1, 1)
		end
		local keyStr = format("%s+%d", abbrev, key.level)
		keyText:SetText(keyStr)
		if key.level >= 10 then
			keyText:SetTextColor(1, 0.5, 0)
		elseif key.level >= 7 then
			keyText:SetTextColor(0.64, 0.21, 0.93)
		else
			keyText:SetTextColor(0.6, 0.6, 0.6)
		end
	else
		keyText:SetText("No key")
		keyText:SetTextColor(0.4, 0.4, 0.4)
	end
	colX = colX + columns[12].width

	-- Column 13: Completion %
	local doneText = rowBg:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	doneText:SetPoint("LEFT", colX, 0)
	doneText:SetWidth(columns[13].width)
	doneText:SetJustifyH("RIGHT")
	local completion = alt.completionPercent or 0
	doneText:SetText(format("%d%%", completion))
	if completion >= 80 then
		doneText:SetTextColor(0, 1, 0)
	elseif completion >= 40 then
		doneText:SetTextColor(1, 0.8, 0)
	else
		doneText:SetTextColor(0.5, 0.5, 0.5)
	end
	colX = colX + columns[13].width

	-- Column 14: Delete button
	local deleteBtn = CreateFrame("Button", nil, rowBg)
	deleteBtn:SetSize(16, 16)
	deleteBtn:SetPoint("LEFT", colX + 2, 0)
	deleteBtn:SetNormalTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
	deleteBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")

	-- Create key for this alt
	local altKey = format("%s-%s", alt.realm, alt.name)

	-- Don't allow deleting current character
	if isCurrentChar then
		deleteBtn:SetAlpha(0.3)
		deleteBtn:SetEnabled(false)
	else
		deleteBtn:SetScript("OnClick", function()
			-- Confirmation with blacklist option
			StaticPopupDialogs["MIDNIGHTTRACKER_DELETE_ALT"] = {
				text = format("Delete tracking data for %s?\n\n|cffFFFF00Delete|r - Character will be re-tracked if you log in again\n|cffFF6B6BDelete & Don't Track|r - Character will be blacklisted", alt.name),
				button1 = "Delete",
				button2 = "Delete & Don't Track",
				button3 = "Cancel",
				OnAccept = function()
					-- Delete without blacklist
					if addon.AltManager and addon.AltManager.DeleteAlt then
						addon.AltManager:DeleteAlt(altKey, false)
						if addon.Display and addon.Display.UpdateDisplay then
							addon.Display:UpdateDisplay()
						end
					end
				end,
				OnAlt = function()
					-- Delete and blacklist
					if addon.AltManager and addon.AltManager.DeleteAlt then
						addon.AltManager:DeleteAlt(altKey, true)
						if addon.Display and addon.Display.UpdateDisplay then
							addon.Display:UpdateDisplay()
						end
					end
				end,
				timeout = 0,
				whileDead = true,
				hideOnEscape = true,
				preferredIndex = 3,
			}
			StaticPopup_Show("MIDNIGHTTRACKER_DELETE_ALT")
		end)

		deleteBtn:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(format("Delete %s", alt.name), 1, 0.82, 0)
			GameTooltip:AddLine("Remove from alt tracking", 1, 1, 1)
			GameTooltip:Show()
		end)

		deleteBtn:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
	end

	return yOffset - 18
end

--- Get vault slots unlocked from vault data
function Display:GetVaultSlotsUnlocked(vaultData)
	if not vaultData then return 0 end

	local current = vaultData.current or 0
	local thresholds = vaultData.thresholds or {3, 5, 8}
	local slots = 0

	for _, threshold in ipairs(thresholds) do
		if current >= threshold then
			slots = slots + 1
		end
	end

	return slots
end

-- Add World Bosses to progression window
function Display:AddProgressionWorldBosses(parent, worldBosses, yOffset, xOffset)
	if not worldBosses then return yOffset end

	for questID, boss in pairs(worldBosses) do
		local text = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		text:SetPoint("TOPLEFT", xOffset + 5, yOffset)
		text:SetText(boss.name or "World Boss")

		-- Color: Green if completed, Yellow if not
		if boss.completed then
			text:SetTextColor(0, 1, 0) -- Green
		else
			text:SetTextColor(1, 0.8, 0) -- Yellow
		end

		table.insert(progressionFrames, text)
		yOffset = yOffset - 18
	end

	return yOffset
end

-- Add Raid Lockouts to progression window
function Display:AddProgressionRaidLockouts(parent, lockouts, yOffset, xOffset)
	if not lockouts then return yOffset end

	local diffNames = {
		[14] = "N",
		[15] = "H",
		[16] = "M",
		[17] = "LFR",
	}

	for instanceID, difficulties in pairs(lockouts) do
		for diffID, lockout in pairs(difficulties) do
			local killed = lockout.encounterProgress or 0
			local total = lockout.numEncounters or 0
			local diffName = diffNames[diffID] or tostring(diffID)

			local text = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
			text:SetPoint("TOPLEFT", xOffset + 5, yOffset)
			text:SetText(format("%s (%s): %d/%d", lockout.name, diffName, killed, total))

			if killed == total then
				text:SetTextColor(0, 1, 0)
			elseif killed > 0 then
				text:SetTextColor(1, 0.8, 0)
			else
				text:SetTextColor(0.7, 0.7, 0.7)
			end

			table.insert(progressionFrames, text)
			yOffset = yOffset - 18
		end
	end

	return yOffset
end

-- Add Great Vault to progression window
function Display:AddProgressionGreatVault(parent, vaultData, yOffset, xOffset)
	local vaultTypes = {
		{name = "Raid", data = vaultData.raid},
		{name = "M+", data = vaultData.mythicplus},
		{name = "Delves", data = vaultData.world},
	}

	for _, vaultType in ipairs(vaultTypes) do
		if vaultType.data then
			local current = vaultType.data.current or 0
			local thresholds = vaultType.data.thresholds or {3, 5, 8}
			local slotsUnlocked = 0

			for _, threshold in ipairs(thresholds) do
				if current >= threshold then
					slotsUnlocked = slotsUnlocked + 1
				end
			end

			local text = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
			text:SetPoint("TOPLEFT", xOffset + 5, yOffset)
			text:SetText(format("%s: %d/3 slots", vaultType.name, slotsUnlocked))

			if slotsUnlocked == 3 then
				text:SetTextColor(0, 1, 0)
			elseif slotsUnlocked > 0 then
				text:SetTextColor(1, 0.8, 0)
			else
				text:SetTextColor(0.7, 0.7, 0.7)
			end

			table.insert(progressionFrames, text)
			yOffset = yOffset - 18
		end
	end

	return yOffset
end

-- Add Upgrade Context to progression window
function Display:AddProgressionUpgradeContext(parent, yOffset, xOffset)
	local summary = addon.UpgradeTracker:GetUpgradeSummary()
	if not summary then
		local text = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		text:SetPoint("TOPLEFT", xOffset + 5, yOffset)
		text:SetText("No upgradeable items")
		text:SetTextColor(0.6, 0.6, 0.6)
		table.insert(progressionFrames, text)
		return yOffset - 18
	end

	if summary.readyToUpgrade > 0 then
		local text = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		text:SetPoint("TOPLEFT", xOffset + 5, yOffset)
		text:SetText(format("✓ Ready: %d items", summary.readyToUpgrade))
		text:SetTextColor(0, 1, 0)
		table.insert(progressionFrames, text)
		yOffset = yOffset - 18
	end

	if summary.wastingCaps then
		local text = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		text:SetPoint("TOPLEFT", xOffset + 5, yOffset)
		text:SetText("⚠ At crest cap!")
		text:SetTextColor(1, 0.3, 0.3)
		table.insert(progressionFrames, text)
		yOffset = yOffset - 18
	end

	if summary.upgradeableItems > 0 and summary.readyToUpgrade == 0 then
		local text = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		text:SetPoint("TOPLEFT", xOffset + 5, yOffset)
		text:SetText(format("%d items need crests", summary.upgradeableItems))
		text:SetTextColor(0.7, 0.7, 0.7)
		table.insert(progressionFrames, text)
		yOffset = yOffset - 18
	end

	return yOffset
end

-- Add Cooldowns to progression window
function Display:AddProgressionCooldowns(parent, yOffset, xOffset)
	local data = addon.CooldownTracker:GetAllCooldownData()
	if not data then
		local text = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		text:SetPoint("TOPLEFT", xOffset + 5, yOffset)
		text:SetText("No cooldowns tracked")
		text:SetTextColor(0.6, 0.6, 0.6)
		table.insert(progressionFrames, text)
		return yOffset - 18
	end

	if data.catalyst and data.catalyst.charges ~= nil then
		local text = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		text:SetPoint("TOPLEFT", xOffset + 5, yOffset)
		local maxCharges = data.catalyst.maxCharges or 6
		text:SetText(format("Catalyst: %d/%d charges", data.catalyst.charges, maxCharges))

		if data.catalyst.charges > 0 then
			text:SetTextColor(0, 1, 0)
		else
			text:SetTextColor(0.6, 0.6, 0.6)
		end

		table.insert(progressionFrames, text)
		yOffset = yOffset - 18
	end

	if data.readyCount and data.readyCount > 0 then
		local text = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		text:SetPoint("TOPLEFT", xOffset + 5, yOffset)
		text:SetText(format("✓ %d crafting cooldown%s ready", data.readyCount, data.readyCount > 1 and "s" or ""))
		text:SetTextColor(0, 1, 0)
		table.insert(progressionFrames, text)
		yOffset = yOffset - 18
	end

	return yOffset
end


-- Save progression window position
function Display:SaveProgressionPosition()
	if not progressionFrame then return end

	local point, _, relativePoint, xOfs, yOfs = progressionFrame:GetPoint()

	if not addon.db.display.progressionPos then
		addon.db.display.progressionPos = {}
	end

	addon.db.display.progressionPos.point = point
	addon.db.display.progressionPos.relativePoint = relativePoint
	addon.db.display.progressionPos.x = xOfs
	addon.db.display.progressionPos.y = yOfs
end

-- Restore progression window position
function Display:RestoreProgressionPosition()
	if not progressionFrame then return end

	if addon.db.display.progressionPos and addon.db.display.progressionPos.point then
		progressionFrame:ClearAllPoints()
		progressionFrame:SetPoint(
			addon.db.display.progressionPos.point,
			UIParent,
			addon.db.display.progressionPos.relativePoint or "TOPRIGHT",
			addon.db.display.progressionPos.x or -20,
			addon.db.display.progressionPos.y or -400
		)
	else
		-- Default position (below currency display)
		progressionFrame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -20, -400)
	end
end

-- ============================================================================
-- VIEW MODE TOGGLE & ALT DASHBOARD
-- ============================================================================

-- Toggle view mode between current character and alt dashboard
function Display:ToggleViewMode()
	local currentMode = addon.db.display.viewMode or "current"

	if currentMode == "current" then
		addon.db.display.viewMode = "alts"
	else
		addon.db.display.viewMode = "current"
	end

	self:UpdateDisplay()
end

-- Update alt dashboard view
function Display:UpdateAltDashboard()
	if not progressionFrame or not progressionFrame.content then return end

	-- Lazy-load alt data (only fetch when viewing dashboard)
	if not addon.AltManager then
		addon.Utils:Debug("Display: AltManager not available")
		return
	end

	-- Update backdrop
	if progressionFrame.SetBackdrop then
		if addon.db.display.showBackground or addon.db.display.showBorder then
			progressionFrame:SetBackdrop({
				bgFile = addon.db.display.showBackground and "Interface\\ChatFrame\\ChatFrameBackground" or nil,
				edgeFile = addon.db.display.showBorder and "Interface\\Tooltips\\UI-Tooltip-Border" or nil,
				tile = true, tileSize = 16, edgeSize = 16,
				insets = { left = 3, right = 3, top = 3, bottom = 3 }
			})
			local opacity = addon.db.display.backgroundOpacity or 0.8
			if progressionFrame.SetBackdropColor then
				progressionFrame:SetBackdropColor(0, 0, 0, addon.db.display.showBackground and opacity or 0)
			end
			if progressionFrame.SetBackdropBorderColor then
				progressionFrame:SetBackdropBorderColor(0.4, 0.4, 0.4, addon.db.display.showBorder and 1 or 0)
			end
		else
			progressionFrame:SetBackdrop(nil)
		end
	end

	-- Clear existing frames
	for _, frame in ipairs(progressionFrames) do
		frame:Hide()
		frame:SetParent(nil)
	end
	wipe(progressionFrames)

	local yOffset = -5
	local xOffset = 5

	-- Header: View mode toggle button
	local header = CreateFrame("Frame", nil, progressionFrame.content)
	header:SetSize(280, 25)
	header:SetPoint("TOPLEFT", xOffset, yOffset)

	local headerText = header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	headerText:SetPoint("LEFT", 0, 0)
	headerText:SetText("Alt Dashboard")
	headerText:SetTextColor(0.3, 0.9, 1)

	-- Toggle button
	local toggleBtn = CreateFrame("Button", nil, header)
	toggleBtn:SetSize(120, 20)
	toggleBtn:SetPoint("RIGHT", 0, 0)
	toggleBtn:SetNormalFontObject("GameFontNormalSmall")
	toggleBtn:SetText("View: Alts \226\150\188") -- Down arrow
	toggleBtn:SetScript("OnClick", function()
		Display:ToggleViewMode()
	end)

	-- Button background
	local btnBg = toggleBtn:CreateTexture(nil, "BACKGROUND")
	btnBg:SetAllPoints()
	btnBg:SetColorTexture(0.2, 0.2, 0.2, 0.8)

	-- Button highlight
	local btnHighlight = toggleBtn:CreateTexture(nil, "HIGHLIGHT")
	btnHighlight:SetAllPoints()
	btnHighlight:SetColorTexture(0.3, 0.3, 0.3, 0.5)

	table.insert(progressionFrames, header)
	yOffset = yOffset - 30

	-- Sort order label and selector
	local sortLabel = CreateFrame("Frame", nil, progressionFrame.content)
	sortLabel:SetSize(280, 20)
	sortLabel:SetPoint("TOPLEFT", xOffset, yOffset)

	local sortText = sortLabel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	sortText:SetPoint("LEFT", 0, 0)
	sortText:SetText("Sort by:")
	sortText:SetTextColor(0.7, 0.7, 0.7)

	-- Sort button
	local sortOrder = addon.db.settings.altSortOrder or "completion"
	local sortLabels = {
		completion = "Completion",
		name = "Name",
		vault = "Vault",
	}

	local sortBtn = CreateFrame("Button", nil, sortLabel)
	sortBtn:SetSize(100, 18)
	sortBtn:SetPoint("LEFT", sortText, "RIGHT", 5, 0)
	sortBtn:SetNormalFontObject("GameFontNormalSmall")
	sortBtn:SetText(sortLabels[sortOrder] .. " \226\150\188")
	sortBtn:SetScript("OnClick", function()
		-- Cycle through sort orders
		local orders = {"completion", "name", "vault"}
		local currentIndex = 1
		for i, order in ipairs(orders) do
			if order == addon.db.settings.altSortOrder then
				currentIndex = i
				break
			end
		end
		local nextIndex = (currentIndex % #orders) + 1
		addon.db.settings.altSortOrder = orders[nextIndex]
		Display:UpdateDisplay()
	end)

	local sortBtnBg = sortBtn:CreateTexture(nil, "BACKGROUND")
	sortBtnBg:SetAllPoints()
	sortBtnBg:SetColorTexture(0.15, 0.15, 0.15, 0.8)

	local sortBtnHighlight = sortBtn:CreateTexture(nil, "HIGHLIGHT")
	sortBtnHighlight:SetAllPoints()
	sortBtnHighlight:SetColorTexture(0.25, 0.25, 0.25, 0.5)

	table.insert(progressionFrames, sortLabel)
	yOffset = yOffset - 25

	-- Divider line
	local divider = progressionFrame.content:CreateTexture(nil, "ARTWORK")
	divider:SetSize(280, 1)
	divider:SetPoint("TOPLEFT", xOffset, yOffset)
	divider:SetColorTexture(0.3, 0.3, 0.3, 1)
	yOffset = yOffset - 5

	-- Get sorted alts (lazy-loaded - only when dashboard visible)
	local alts = addon.AltManager:GetSortedAlts(addon.db.settings.altSortOrder)

	-- Handle empty alt list
	if not alts or #alts == 0 then
		local noAltsText = progressionFrame.content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		noAltsText:SetPoint("TOPLEFT", xOffset, yOffset)
		noAltsText:SetText("No alts logged this week")
		noAltsText:SetTextColor(0.7, 0.7, 0.7)
		yOffset = yOffset - 30
	end

	-- Display each alt
	for _, alt in ipairs(alts) do
		local altFrame = self:CreateAltRow(alt)
		altFrame:SetPoint("TOPLEFT", progressionFrame.content, "TOPLEFT", xOffset, yOffset)
		table.insert(progressionFrames, altFrame)
		yOffset = yOffset - 55
	end

	-- Account totals section
	yOffset = yOffset - 10
	local totalsHeader = progressionFrame.content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	totalsHeader:SetPoint("TOPLEFT", xOffset, yOffset)
	totalsHeader:SetText("Account Totals")
	totalsHeader:SetTextColor(0.3, 0.9, 1)
	yOffset = yOffset - 20

	-- Key currency totals
	local keyCurrencies = {
		{id = 2815, name = "Resonance"},
		{id = 3008, name = "Valorstones"},
	}

	for _, curr in ipairs(keyCurrencies) do
		local total = addon.AltManager:GetAccountCurrencyTotal(curr.id)
		if total > 0 then
			local totalFrame = progressionFrame.content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
			totalFrame:SetPoint("TOPLEFT", xOffset + 10, yOffset)
			totalFrame:SetText(format("%s: %s", curr.name, addon.Utils:FormatNumber(total)))
			totalFrame:SetTextColor(0.7, 0.7, 0.7)
			yOffset = yOffset - 16
		end
	end

	-- Calculate content size (add space for tabs)
	local contentHeight = math.abs(yOffset) + 10
	progressionFrame:SetSize(300, contentHeight + 40)
	progressionFrame.content:SetSize(290, contentHeight)
end

-- Create a single alt row for dashboard
function Display:CreateAltRow(alt)
	local frame = CreateFrame("Frame", nil, progressionFrame.content)
	frame:SetSize(280, 50)

	-- Character name and class (colored)
	local classColors = {
		WARRIOR = {0.78, 0.61, 0.43},
		PALADIN = {0.96, 0.55, 0.73},
		HUNTER = {0.67, 0.83, 0.45},
		ROGUE = {1.00, 0.96, 0.41},
		PRIEST = {1.00, 1.00, 1.00},
		DEATHKNIGHT = {0.77, 0.12, 0.23},
		SHAMAN = {0.00, 0.44, 0.87},
		MAGE = {0.41, 0.80, 0.94},
		WARLOCK = {0.58, 0.51, 0.79},
		MONK = {0.00, 1.00, 0.59},
		DRUID = {1.00, 0.49, 0.04},
		DEMONHUNTER = {0.64, 0.19, 0.79},
		EVOKER = {0.20, 0.58, 0.50},
	}

	local classColor = classColors[alt.class] or {1, 1, 1}

	local nameText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	nameText:SetPoint("TOPLEFT", 0, 0)
	nameText:SetText(format("%s (%d)", alt.name, alt.level or 80))
	nameText:SetTextColor(classColor[1], classColor[2], classColor[3])

	-- Completion percentage
	local completionText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	completionText:SetPoint("TOPRIGHT", 0, 0)
	local percent = alt.completionPercent or 0
	completionText:SetText(format("%.0f%%", percent))

	-- Color based on completion
	if percent >= 75 then
		completionText:SetTextColor(0, 1, 0) -- Green
	elseif percent >= 40 then
		completionText:SetTextColor(1, 0.8, 0) -- Yellow
	else
		completionText:SetTextColor(1, 0.3, 0.3) -- Red
	end

	-- Vault progress
	local vaultText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	vaultText:SetPoint("TOPLEFT", 10, -16)

	if alt.vault then
		local raidSlots = self:GetVaultSlotsUnlocked(alt.vault.raid)
		local mplusSlots = self:GetVaultSlotsUnlocked(alt.vault.mythicplus)
		local worldSlots = self:GetVaultSlotsUnlocked(alt.vault.world)

		vaultText:SetText(format("Vault: %d/%d/%d", raidSlots, mplusSlots, worldSlots))
	else
		vaultText:SetText("Vault: 0/0/0")
	end
	vaultText:SetTextColor(0.7, 0.7, 0.7)

	-- Key currencies
	local currText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	currText:SetPoint("TOPLEFT", 10, -30)

	local resonance = (alt.currencies and alt.currencies[2815] and alt.currencies[2815].amount) or 0
	local valor = (alt.currencies and alt.currencies[3008] and alt.currencies[3008].amount) or 0

	currText:SetText(format("Res: %s  |  Valor: %s",
		addon.Utils:FormatNumber(resonance),
		addon.Utils:FormatNumber(valor)))
	currText:SetTextColor(0.6, 0.6, 0.6)

	-- Last seen
	if alt.lastSeen then
		local daysSince = math.floor((time() - alt.lastSeen) / 86400)
		if daysSince > 0 then
			local lastSeenText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
			lastSeenText:SetPoint("TOPRIGHT", 0, -16)
			lastSeenText:SetText(format("(%dd ago)", daysSince))
			lastSeenText:SetTextColor(0.5, 0.5, 0.5)
		end
	end

	frame:Show()
	return frame
end

-- Helper: Get vault slots unlocked from vault data
function Display:GetVaultSlotsUnlocked(vaultData)
	if not vaultData then return 0 end

	local current = vaultData.current or 0
	local thresholds = vaultData.thresholds or {3, 5, 8}
	local slots = 0

	for _, threshold in ipairs(thresholds) do
		if current >= threshold then
			slots = slots + 1
		end
	end

	return slots
end

-- ============================================================================
-- COLLAPSIBLE SECTIONS
-- ============================================================================

-- Create a collapsible section header
function Display:CreateSectionHeader(title, sectionKey, collapsed, yOffset)
	local frame = CreateFrame("Button", nil, displayFrame.content)
	frame:SetSize(180, 16)
	frame:SetPoint("TOPLEFT", displayFrame.content, "TOPLEFT", 2, yOffset)

	-- Arrow (expand/collapse indicator)
	local arrow = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	arrow:SetPoint("LEFT", 0, 0)
	arrow:SetText(collapsed and "\226\150\186" or "\226\150\188") -- Right arrow or down arrow
	arrow:SetTextColor(0.3, 0.9, 1)

	-- Title text
	local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	text:SetPoint("LEFT", arrow, "RIGHT", 5, 0)
	text:SetText(title)
	text:SetTextColor(0.3, 0.9, 1)

	-- Click to toggle
	frame:SetScript("OnClick", function()
		addon.db.display.collapsedSections[sectionKey] = not addon.db.display.collapsedSections[sectionKey]
		Display:UpdateDisplay()
	end)

	-- Highlight on hover
	frame:SetScript("OnEnter", function()
		arrow:SetTextColor(0.5, 1, 1)
		text:SetTextColor(0.5, 1, 1)
	end)

	frame:SetScript("OnLeave", function()
		arrow:SetTextColor(0.3, 0.9, 1)
		text:SetTextColor(0.3, 0.9, 1)
	end)

	frame:Show()
	return frame
end

-- Add upgrade context display section
function Display:AddUpgradeContextDisplay(yOffset)
	if not addon.UpgradeTracker then return yOffset end

	local summary = addon.UpgradeTracker:GetUpgradeSummary()
	if not summary then return yOffset end

	local xOffset = 10

	-- Ready to upgrade count
	if summary.readyToUpgrade > 0 then
		local readyFrame = displayFrame.content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		readyFrame:SetPoint("TOPLEFT", xOffset, yOffset)
		readyFrame:SetText(format("Ready: %d item%s", summary.readyToUpgrade, summary.readyToUpgrade > 1 and "s" or ""))
		readyFrame:SetTextColor(0, 1, 0) -- Green
		yOffset = yOffset - 14
	end

	-- Wasting caps warning
	if summary.wastingCaps then
		local wasteFrame = displayFrame.content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		wasteFrame:SetPoint("TOPLEFT", xOffset, yOffset)
		wasteFrame:SetText("WARNING: At crest cap!")
		wasteFrame:SetTextColor(1, 0.3, 0.3) -- Red
		yOffset = yOffset - 14
	end

	-- Missing crests summary
	local missing = addon.UpgradeTracker:GetMissingCrestsSummary()
	if #missing > 0 then
		local missingFrame = displayFrame.content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		missingFrame:SetPoint("TOPLEFT", xOffset, yOffset)
		local crestText = format("Need: %d %s", missing[1].missing, missing[1].track)
		missingFrame:SetText(crestText)
		missingFrame:SetTextColor(0.7, 0.7, 0.7)
		yOffset = yOffset - 14
	end

	yOffset = yOffset - 5 -- Extra spacing
	return yOffset
end

-- Add cooldown display section
function Display:AddCooldownDisplay(yOffset)
	if not addon.CooldownTracker then return yOffset end

	local data = addon.CooldownTracker:GetAllCooldownData()
	if not data then return yOffset end

	local xOffset = 10

	-- Catalyst charges
	if data.catalyst and data.catalyst.charges then
		local catFrame = displayFrame.content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		catFrame:SetPoint("TOPLEFT", xOffset, yOffset)

		local chargeText = format("Catalyst: %d/6 charge%s",
			data.catalyst.charges,
			data.catalyst.charges ~= 1 and "s" or "")

		catFrame:SetText(chargeText)

		if data.catalyst.charges > 0 then
			catFrame:SetTextColor(0, 1, 0) -- Green if charges available
		else
			catFrame:SetTextColor(0.6, 0.6, 0.6) -- Grey if none
		end

		yOffset = yOffset - 14
	end

	-- Ready crafting cooldowns
	if data.readyCount and data.readyCount > 0 then
		local craftFrame = displayFrame.content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		craftFrame:SetPoint("TOPLEFT", xOffset, yOffset)
		craftFrame:SetText(format("Crafting: %d ready", data.readyCount))
		craftFrame:SetTextColor(0, 1, 0) -- Green
		yOffset = yOffset - 14
	end

	yOffset = yOffset - 5 -- Extra spacing
	return yOffset
end
