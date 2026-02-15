local addonName, addon = ...

-- Config module: settings panel
addon.Config = {}
local Config = addon.Config

local configFrame

-- Helper: Create custom slider
local function CreateCustomSlider(parent, width, min, max, step, defaultValue, label)
	local slider = CreateFrame("Frame", nil, parent)
	slider:SetSize(width, 30)

	-- Label (left upper)
	slider.label = slider:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	slider.label:SetPoint("BOTTOMLEFT", slider, "TOPLEFT", 0, 5)
	slider.label:SetText(label)
	slider.label:SetTextColor(0.95, 0.95, 0.95)

	-- Value text (right upper)
	slider.valueText = slider:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	slider.valueText:SetPoint("BOTTOMRIGHT", slider, "TOPRIGHT", 0, 5)
	slider.valueText:SetTextColor(0.95, 0.95, 0.95)

	-- Track background
	local track = slider:CreateTexture(nil, "BACKGROUND")
	track:SetPoint("LEFT", 0, 0)
	track:SetPoint("RIGHT", 0, 0)
	track:SetHeight(4)
	track:SetColorTexture(0.22, 0.22, 0.24, 1)

	-- Track fill (shows current value)
	slider.fill = slider:CreateTexture(nil, "BORDER")
	slider.fill:SetPoint("LEFT", 0, 0)
	slider.fill:SetHeight(4)
	slider.fill:SetColorTexture(0.5, 0.58, 0.46, 1)

	-- Thumb (draggable button)
	slider.thumb = CreateFrame("Button", nil, slider)
	slider.thumb:SetSize(16, 16)
	slider.thumb:SetPoint("LEFT", 0, 0)

	local thumbTex = slider.thumb:CreateTexture(nil, "OVERLAY")
	thumbTex:SetAllPoints()
	thumbTex:SetColorTexture(0.56, 0.63, 0.53, 1)

	-- Slider properties
	slider.min = min
	slider.max = max
	slider.step = step
	slider.value = defaultValue

	-- Update visual position
	function slider:UpdatePosition()
		local percent = (self.value - self.min) / (self.max - self.min)
		self.thumb:SetPoint("LEFT", percent * width, 0)
		self.fill:SetWidth(percent * width)
	end

	-- Set value
	function slider:SetValue(value)
		value = math.max(self.min, math.min(self.max, value))
		if self.step then
			value = math.floor((value / self.step) + 0.5) * self.step
		end
		self.value = value
		self:UpdatePosition()
		if self.onValueChanged then
			self.onValueChanged(value)
		end
	end

	-- Get value
	function slider:GetValue()
		return self.value
	end

	-- Set callback
	function slider:SetCallback(callback)
		self.onValueChanged = callback
	end

	-- Mouse handling
	slider.thumb:EnableMouse(true)
	slider.thumb:RegisterForDrag("LeftButton")

	slider.thumb:SetScript("OnDragStart", function(self)
		self:GetParent().isDragging = true
	end)

	slider.thumb:SetScript("OnDragStop", function(self)
		self:GetParent().isDragging = false
	end)

	slider:EnableMouse(true)
	slider:SetScript("OnUpdate", function(self)
		if self.isDragging then
			local cursorX = GetCursorPosition()
			local scale = self:GetEffectiveScale()
			local left = self:GetLeft()
			local relativeX = (cursorX / scale) - left
			local percent = math.max(0, math.min(1, relativeX / width))
			local newValue = self.min + (percent * (self.max - self.min))
			self:SetValue(newValue)
		end
	end)

	-- Click to jump
	slider:SetScript("OnMouseDown", function(self, button)
		if button == "LeftButton" then
			local cursorX = GetCursorPosition()
			local scale = self:GetEffectiveScale()
			local left = self:GetLeft()
			local relativeX = (cursorX / scale) - left
			local percent = math.max(0, math.min(1, relativeX / width))
			local newValue = self.min + (percent * (self.max - self.min))
			self:SetValue(newValue)
			self.isDragging = true
		end
	end)

	slider:SetScript("OnMouseUp", function(self)
		self.isDragging = false
	end)

	slider:SetValue(defaultValue)
	return slider
end

-- Helper: Create custom checkbox
local function CreateCustomCheckbox(parent, label, checked)
	local checkbox = CreateFrame("Button", nil, parent)
	checkbox:SetSize(20, 20)

	-- Box background
	local bg = checkbox:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetColorTexture(0.56, 0.63, 0.53, 1)

	-- Box border
	local border = checkbox:CreateTexture(nil, "BORDER")
	border:SetPoint("TOPLEFT", checkbox, "TOPLEFT", 1, -1)
	border:SetPoint("BOTTOMRIGHT", checkbox, "BOTTOMRIGHT", -1, 1)
	border:SetColorTexture(0, 0, 0, 1)

	-- Check mark
	checkbox.check = checkbox:CreateTexture(nil, "OVERLAY")
	checkbox.check:SetPoint("TOPLEFT", checkbox, "TOPLEFT", 4, -4)
	checkbox.check:SetPoint("BOTTOMRIGHT", checkbox, "BOTTOMRIGHT", -4, 4)
	checkbox.check:SetColorTexture(0.56, 0.63, 0.53, 1)
	checkbox.check:Hide()

	-- Label
	checkbox.label = checkbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	checkbox.label:SetPoint("LEFT", checkbox, "RIGHT", 8, 0)
	checkbox.label:SetText(label)
	checkbox.label:SetTextColor(0.95, 0.95, 0.95)
	checkbox.label:SetJustifyH("LEFT")

	-- State
	checkbox.checked = checked or false

	-- Update visual
	function checkbox:UpdateVisual()
		if self.checked then
			self.check:Show()
		else
			self.check:Hide()
		end
	end

	-- Set checked
	function checkbox:SetChecked(checked)
		self.checked = checked
		self:UpdateVisual()
		if self.onClick then
			self.onClick(checked)
		end
	end

	-- Get checked
	function checkbox:GetChecked()
		return self.checked
	end

	-- Set callback
	function checkbox:SetCallback(callback)
		self.onClick = callback
	end

	-- Click handler
	checkbox:SetScript("OnClick", function(self)
		self:SetChecked(not self.checked)
	end)

	checkbox:UpdateVisual()
	return checkbox
end

-- Helper: Create custom button
local function CreateCustomButton(parent, width, height, text)
	local button = CreateFrame("Button", nil, parent)
	button:SetSize(width, height)

	-- Background
	button.bg = button:CreateTexture(nil, "BACKGROUND")
	button.bg:SetAllPoints()
	button.bg:SetColorTexture(0, 0, 0, 1)

	-- Border
	local border = button:CreateTexture(nil, "BORDER")
	border:SetPoint("TOPLEFT", -1, 1)
	border:SetPoint("BOTTOMRIGHT", 1, -1)
	border:SetColorTexture(0.56, 0.63, 0.53, 1)

	-- Highlight
	button.highlight = button:CreateTexture(nil, "HIGHLIGHT")
	button.highlight:SetAllPoints()
	button.highlight:SetColorTexture(0.56, 0.63, 0.53, 0.18)

	-- Text
	button.text = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	button.text:SetPoint("CENTER")
	button.text:SetText(text)
	button.text:SetTextColor(0.95, 0.95, 0.95)

	-- Disabled state (selected)
	function button:SetEnabled(enabled)
		if enabled then
			self.bg:SetColorTexture(0.07, 0.07, 0.09, 1)
			self.text:SetTextColor(0.95, 0.95, 0.95)
			self:Enable()
		else
			self.bg:SetColorTexture(0.09, 0.11, 0.09, 1)
			self.text:SetTextColor(0.56, 0.63, 0.53, 1)
			self:Disable()
		end
	end

	return button
end

function Config:Initialize()
	-- Create config panel
	configFrame = CreateFrame("Frame", "MidnightTrackerConfig", UIParent)
	configFrame:SetSize(650, 550)
	configFrame:SetPoint("CENTER")
	configFrame:SetMovable(true)
	configFrame:EnableMouse(true)
	configFrame:SetClampedToScreen(true)
	configFrame:RegisterForDrag("LeftButton")
	configFrame:SetScript("OnDragStart", configFrame.StartMoving)
	configFrame:SetScript("OnDragStop", configFrame.StopMovingOrSizing)
	configFrame:Hide()
	configFrame:SetFrameStrata("DIALOG")

	-- Background
	local bg = configFrame:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetColorTexture(0.04, 0.04, 0.05, 0.98)

	-- Border
	local border = configFrame:CreateTexture(nil, "BORDER")
	border:SetPoint("TOPLEFT", -2, 2)
	border:SetPoint("BOTTOMRIGHT", 2, -2)
	border:SetColorTexture(0, 0, 0, 1)

	-- Title bar
	local titleBar = configFrame:CreateTexture(nil, "ARTWORK")
	titleBar:SetPoint("TOPLEFT", 0, 0)
	titleBar:SetPoint("TOPRIGHT", 0, 0)
	titleBar:SetHeight(40)
	titleBar:SetColorTexture(0, 0, 0, 1)

	-- Title
	local title = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOP", 0, -12)
	title:SetText("MidnightTracker Settings")
	title:SetTextColor(0.56, 0.63, 0.53)

	-- Close button
	local closeBtn = CreateFrame("Button", nil, configFrame)
	closeBtn:SetSize(25, 25)
	closeBtn:SetPoint("TOPRIGHT", -8, -8)

	local closeBg = closeBtn:CreateTexture(nil, "BACKGROUND")
	closeBg:SetAllPoints()
	closeBg:SetColorTexture(0.45, 0.12, 0.12, 1)

	local closeText = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	closeText:SetPoint("CENTER", 0, 1)
	closeText:SetText("×")
	closeText:SetTextColor(1, 1, 1)

	local closeHighlight = closeBtn:CreateTexture(nil, "HIGHLIGHT")
	closeHighlight:SetAllPoints()
	closeHighlight:SetColorTexture(1, 0.2, 0.2, 0.35)

	closeBtn:SetScript("OnClick", function()
		Config:Hide()
	end)

	-- Build settings
	self:BuildSettings(configFrame)

	addon.Utils:Debug("Config panel initialized")
end

function Config:BuildSettings(parent)
	-- Create custom tab buttons
	local tabs = {}
	local tabContents = {}

	local tabNames = {"Display", "General", "Expansions", "Weekly", "Checklist"}
	local tabWidth = 120
	local tabHeight = 35
	local tabSpacing = 5
	local tabStartY = -50

	for i, tabName in ipairs(tabNames) do
		-- Create custom tab button
		local tab = CreateFrame("Button", nil, parent)
		tab:SetSize(tabWidth, tabHeight)
		tab:SetPoint("TOPLEFT", 15 + ((i-1) * (tabWidth + tabSpacing)), tabStartY)
		tab:SetFrameLevel(parent:GetFrameLevel() + 5)

		-- Tab background
		tab.bg = tab:CreateTexture(nil, "BACKGROUND")
		tab.bg:SetAllPoints()
		tab.bg:SetColorTexture(0.07, 0.07, 0.09, 1)

		-- Tab border
		local border = tab:CreateTexture(nil, "BORDER")
		border:SetPoint("TOPLEFT", -1, 1)
		border:SetPoint("BOTTOMRIGHT", 1, -1)
		border:SetColorTexture(0.56, 0.63, 0.53, 1)

		-- Tab highlight on hover
		tab.highlight = tab:CreateTexture(nil, "HIGHLIGHT")
		tab.highlight:SetAllPoints()
		tab.highlight:SetColorTexture(0.56, 0.63, 0.53, 0.18)

		-- Tab text
		tab.text = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		tab.text:SetPoint("CENTER")
		tab.text:SetText(tabName)
		tab.text:SetTextColor(0.95, 0.95, 0.95)

		tabs[i] = tab
	end

	-- Create scroll frame below tabs
	local scrollFrame = CreateFrame("ScrollFrame", nil, parent)
	scrollFrame:SetPoint("TOPLEFT", 15, tabStartY - tabHeight - 15)
	scrollFrame:SetPoint("BOTTOMRIGHT", -15, 15)
	scrollFrame:EnableMouseWheel(true)
	scrollFrame:SetFrameLevel(parent:GetFrameLevel() + 1)

	-- Custom scrollbar
	local scrollbar = CreateFrame("Slider", nil, scrollFrame)
	scrollbar:SetPoint("TOPRIGHT", 0, -5)
	scrollbar:SetPoint("BOTTOMRIGHT", 0, 5)
	scrollbar:SetWidth(12)
	scrollbar:SetOrientation("VERTICAL")
	scrollbar:SetMinMaxValues(0, 100)
	scrollbar:SetValue(0)

	-- Scrollbar background
	local scrollbarBg = scrollbar:CreateTexture(nil, "BACKGROUND")
	scrollbarBg:SetAllPoints()
	scrollbarBg:SetColorTexture(0.07, 0.07, 0.09, 1)

	-- Scrollbar thumb
	local scrollbarThumb = scrollbar:CreateTexture(nil, "OVERLAY")
	scrollbarThumb:SetSize(12, 30)
	scrollbarThumb:SetColorTexture(0.56, 0.63, 0.53, 1)
	scrollbar:SetThumbTexture(scrollbarThumb)

	-- Mouse wheel scrolling
	scrollFrame:SetScript("OnMouseWheel", function(self, delta)
		local current = scrollbar:GetValue()
		local minVal, maxVal = scrollbar:GetMinMaxValues()
		if delta < 0 and current < maxVal then
			scrollbar:SetValue(math.min(maxVal, current + 20))
		elseif delta > 0 and current > minVal then
			scrollbar:SetValue(math.max(minVal, current - 20))
		end
	end)

	-- Scrollbar updates scroll position
	scrollbar:SetScript("OnValueChanged", function(self, value)
		scrollFrame:SetVerticalScroll(value)
	end)

	local scrollChild = CreateFrame("Frame", nil, scrollFrame)
	scrollChild:SetSize(750, 2100)
	scrollFrame:SetScrollChild(scrollChild)

	-- Function to update scroll range based on active tab
	local function UpdateScrollRange(tabIndex)
		local content = tabContents[tabIndex]
		if not content then return end

		-- Tabs 1 and 2 don't need scrolling
		if tabIndex == 1 or tabIndex == 2 then
			scrollbar:Hide()
			scrollbar:SetMinMaxValues(0, 0)
			scrollbar:SetValue(0)
			scrollFrame:SetVerticalScroll(0)
		else
			-- Tab 3 (Expansions) - calculate actual content height
			scrollbar:Show()
			local maxScroll = math.max(0, content:GetHeight() - scrollFrame:GetHeight())
			scrollbar:SetMinMaxValues(0, maxScroll)
			scrollbar:SetValue(0)
		end
	end

	-- Update scrollbar range when needed
	scrollFrame:SetScript("OnShow", function(self)
		UpdateScrollRange(1) -- Default to tab 1
	end)

	-- Create content frames inside scroll child
	for i = 1, #tabNames do
		local content = CreateFrame("Frame", nil, scrollChild)
		content:SetPoint("TOPLEFT", 0, 0)
		content:SetPoint("TOPRIGHT", -20, 0)
		-- Set initial height (will be adjusted after content is built)
		if i == 1 or i == 2 then
			content:SetHeight(450) -- Fits without scrolling
		else
			content:SetHeight(2100) -- Expansions tab needs more space
		end
		content:Hide()
		tabContents[i] = content

		-- Update tab click handler
		tabs[i]:SetScript("OnClick", function()
			-- Deselect all tabs
			for j, otherTab in ipairs(tabs) do
				otherTab.bg:SetColorTexture(0.07, 0.07, 0.09, 1)
				otherTab.text:SetTextColor(0.95, 0.95, 0.95)
				otherTab:SetEnabled(true)
				tabContents[j]:Hide()
			end
			-- Select this tab
			tabs[i].bg:SetColorTexture(0.09, 0.11, 0.09, 1)
			tabs[i].text:SetTextColor(0.56, 0.63, 0.53)
			tabs[i]:SetEnabled(false)
			content:Show()
			-- Reset scroll position and update scroll range
			UpdateScrollRange(i)
		end)
	end

	-- Show first tab by default
	tabContents[1]:Show()
	tabs[1].bg:SetColorTexture(0.09, 0.11, 0.09, 1)
	tabs[1].text:SetTextColor(0.56, 0.63, 0.53)
	tabs[1]:SetEnabled(false)

	-- === TAB 1: DISPLAY SETTINGS ===
	self:BuildDisplaySettings(tabContents[1])

	-- === TAB 2: GENERAL SETTINGS ===
	self:BuildGeneralSettings(tabContents[2])

	-- === TAB 3: EXPANSIONS ===
	self:BuildExpansionsSettings(tabContents[3])

	-- === TAB 4: WEEKLY & PROGRESSION ===
	self:BuildWeeklyProgressionSettings(tabContents[4])

	-- === TAB 5: CHECKLIST & ALTS ===
	self:BuildChecklistAltsSettings(tabContents[5])
end

function Config:BuildDisplaySettings(parent)
	local yOffset = -20

	-- Size presets
	local sizeLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	sizeLabel:SetPoint("TOPLEFT", 10, yOffset)
	sizeLabel:SetText("Display Size:")
	sizeLabel:SetTextColor(0.95, 0.95, 0.95)
	yOffset = yOffset - 25

	local sizePresets = {
		{
			name = "Small",
			scale = 0.8,
			iconSize = 14,
			fontSize = "small"
		},
		{
			name = "Medium",
			scale = 1.0,
			iconSize = 18,
			fontSize = "normal"
		},
		{
			name = "Large",
			scale = 1.2,
			iconSize = 24,
			fontSize = "normal"
		}
	}

	local sizeButtons = {}

	-- Determine current preset (or default to Medium)
	local currentPreset = "Medium"
	for _, preset in ipairs(sizePresets) do
		if addon.db.display.scale == preset.scale and
		   addon.db.display.iconSize == preset.iconSize and
		   addon.db.display.fontSize == preset.fontSize then
			currentPreset = preset.name
			break
		end
	end

	for i, preset in ipairs(sizePresets) do
		local btn = CreateCustomButton(parent, 100, 32, preset.name)
		btn:SetPoint("TOPLEFT", 10 + ((i-1) * 110), yOffset)

		if preset.name == currentPreset then
			btn:SetEnabled(false)
		end

		btn:SetScript("OnClick", function(self)
			-- Apply preset values (don't change icons per row)
			addon.db.display.scale = preset.scale
			addon.db.display.iconSize = preset.iconSize
			addon.db.display.fontSize = preset.fontSize

			-- Update all buttons
			for _, b in ipairs(sizeButtons) do
				b:SetEnabled(true)
			end
			self:SetEnabled(false)

			-- Update display
			if addon.Display then
				addon.Display:UpdateDisplay()
			end
		end)

		table.insert(sizeButtons, btn)
	end

	yOffset = yOffset - 70

	-- Icons per row slider
	local rowSlider = CreateCustomSlider(parent, 300, 1, 20, 1, addon.db.display.iconsPerRow or 3, "Icons Per Row")
	rowSlider:SetPoint("TOPLEFT", 10, yOffset)
	rowSlider.valueText:SetFormattedText("%d", rowSlider:GetValue())
	rowSlider:SetCallback(function(value)
		addon.db.display.iconsPerRow = value
		rowSlider.valueText:SetFormattedText("%d", value)
		if addon.Display then
			addon.Display:UpdateDisplay()
		end
	end)
	yOffset = yOffset - 60

	-- Background opacity slider
	local opacitySlider = CreateCustomSlider(parent, 300, 0, 1, 0.1, addon.db.display.backgroundOpacity or 0.8, "Background Opacity")
	opacitySlider:SetPoint("TOPLEFT", 10, yOffset)
	opacitySlider.valueText:SetFormattedText("%d%%", opacitySlider:GetValue() * 100)
	opacitySlider:SetCallback(function(value)
		addon.db.display.backgroundOpacity = value
		opacitySlider.valueText:SetFormattedText("%d%%", value * 100)
		if addon.Display then
			addon.Display:UpdateDisplay()
		end
	end)
	yOffset = yOffset - 60

	-- Show border checkbox
	local borderCheck = CreateCustomCheckbox(parent, "Show Border", addon.db.display.showBorder ~= false)
	borderCheck:SetPoint("TOPLEFT", 10, yOffset)
	borderCheck:SetCallback(function(checked)
		addon.db.display.showBorder = checked
		if addon.Display then
			addon.Display:UpdateDisplay()
		end
	end)
	yOffset = yOffset - 30

	-- Show background checkbox
	local bgCheck = CreateCustomCheckbox(parent, "Show Background", addon.db.display.showBackground ~= false)
	bgCheck:SetPoint("TOPLEFT", 10, yOffset)
	bgCheck:SetCallback(function(checked)
		addon.db.display.showBackground = checked
		if addon.Display then
			addon.Display:UpdateDisplay()
		end
	end)
end

function Config:BuildGeneralSettings(parent)
	local yOffset = -20

	-- Show zero currencies checkbox
	local showZeroCheck = CreateCustomCheckbox(parent, "Show currencies with 0 amount", addon.db.settings.showZeroCurrencies or false)
	showZeroCheck:SetPoint("TOPLEFT", 10, yOffset)
	showZeroCheck:SetCallback(function(checked)
		addon.db.settings.showZeroCurrencies = checked
		if addon.Display then
			addon.Display:UpdateDisplay()
		end
	end)
	yOffset = yOffset - 30

	-- Show undiscovered currencies checkbox
	local showUndiscoveredCheck = CreateCustomCheckbox(parent, "Show undiscovered currencies", addon.db.settings.showUndiscovered or false)
	showUndiscoveredCheck:SetPoint("TOPLEFT", 10, yOffset)
	showUndiscoveredCheck:SetCallback(function(checked)
		addon.db.settings.showUndiscovered = checked
		if addon.Display then
			addon.Display:UpdateDisplay()
		end
	end)
	yOffset = yOffset - 30

	-- Filter by zone checkbox
	local filterZoneCheck = CreateCustomCheckbox(parent, "Only show currencies for current zone", addon.db.settings.filterByZone ~= false)
	filterZoneCheck:SetPoint("TOPLEFT", 10, yOffset)
	filterZoneCheck:SetCallback(function(checked)
		addon.db.settings.filterByZone = checked
		if addon.Display then
			addon.Display:UpdateDisplay()
		end
	end)
	yOffset = yOffset - 40

	-- Great Vault header
	local vaultLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	vaultLabel:SetPoint("TOPLEFT", 10, yOffset)
	vaultLabel:SetText("Great Vault:")
	vaultLabel:SetTextColor(0.56, 0.63, 0.53)
	yOffset = yOffset - 25

	-- Show Great Vault checkbox
	local showVaultCheck = CreateCustomCheckbox(parent, "Show Great Vault", addon.db.settings.showGreatVault ~= false)
	showVaultCheck:SetPoint("TOPLEFT", 20, yOffset)
	showVaultCheck:SetCallback(function(checked)
		addon.db.settings.showGreatVault = checked
		if addon.Display then
			addon.Display:UpdateDisplay()
		end
	end)
	yOffset = yOffset - 30

	-- Show Vault Raid
	local vaultRaidCheck = CreateCustomCheckbox(parent, "Raid", addon.db.settings.showVaultRaid ~= false)
	vaultRaidCheck:SetPoint("TOPLEFT", 40, yOffset)
	vaultRaidCheck.label:SetFontObject("GameFontNormalSmall")
	vaultRaidCheck:SetCallback(function(checked)
		addon.db.settings.showVaultRaid = checked
		if addon.Display then
			addon.Display:UpdateDisplay()
		end
	end)
	yOffset = yOffset - 25

	-- Show Vault Mythic+
	local vaultMplusCheck = CreateCustomCheckbox(parent, "Mythic+", addon.db.settings.showVaultMythicPlus ~= false)
	vaultMplusCheck:SetPoint("TOPLEFT", 40, yOffset)
	vaultMplusCheck.label:SetFontObject("GameFontNormalSmall")
	vaultMplusCheck:SetCallback(function(checked)
		addon.db.settings.showVaultMythicPlus = checked
		if addon.Display then
			addon.Display:UpdateDisplay()
		end
	end)
	yOffset = yOffset - 25

	-- Show Vault World
	local vaultWorldCheck = CreateCustomCheckbox(parent, "World/Delves", addon.db.settings.showVaultWorld ~= false)
	vaultWorldCheck:SetPoint("TOPLEFT", 40, yOffset)
	vaultWorldCheck.label:SetFontObject("GameFontNormalSmall")
	vaultWorldCheck:SetCallback(function(checked)
		addon.db.settings.showVaultWorld = checked
		if addon.Display then
			addon.Display:UpdateDisplay()
		end
	end)
end

function Config:BuildExpansionsSettings(parent)
	local yOffset = -20

	local instructionText = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	instructionText:SetPoint("TOPLEFT", 10, yOffset)
	instructionText:SetText("Check expansion to enable/expand. Uncheck to disable/collapse. Uncheck individual currencies to hide them.")
	instructionText:SetTextColor(0.8, 0.8, 0.8)

	-- Ordered category list
	local orderedCategories = {
		{name = "Midnight", key = addon.Data.Categories.MIDNIGHT, setting = "showMidnight"},
		{name = "War Within", key = addon.Data.Categories.WARWITHIN, setting = "showWarWithin"},
		{name = "Dragonflight", key = addon.Data.Categories.DRAGONFLIGHT, setting = "showDragonflight"},
		{name = "Shadowlands", key = addon.Data.Categories.SHADOWLANDS, setting = "showShadowlands"},
		{name = "Battle for Azeroth", key = addon.Data.Categories.BFA, setting = "showBFA"},
		{name = "Legion", key = addon.Data.Categories.LEGION, setting = "showLegion"},
		{name = "Warlords of Draenor", key = addon.Data.Categories.WOD, setting = "showWoD"},
		{name = "Mists of Pandaria", key = addon.Data.Categories.MOP, setting = "showMoP"},
		{name = "Cataclysm", key = addon.Data.Categories.CATACLYSM, setting = "showCataclysm"},
		{name = "Wrath of the Lich King", key = addon.Data.Categories.WOTLK, setting = "showWotLK"},
		{name = "Burning Crusade", key = addon.Data.Categories.BC, setting = "showBC"},
		{name = "PvP Currencies", key = addon.Data.Categories.PVP, setting = "showPvP"},
		{name = "Seasonal Events", key = addon.Data.Categories.SEASONAL, setting = "showSeasonal"},
	}

	local previousFrame = instructionText
	local expansionFrames = {}

	-- Function to recalculate total content height
	local function RecalculateContentHeight()
		local totalHeight = 20 -- Initial offset
		totalHeight = totalHeight + 30 -- Instruction text height
		for _, frame in ipairs(expansionFrames) do
			totalHeight = totalHeight + frame:GetHeight() + 5 -- Frame height + spacing
		end
		totalHeight = totalHeight + 20 -- Bottom padding
		parent:SetHeight(totalHeight)
	end

	-- Build expansion sections
	for i, categoryInfo in ipairs(orderedCategories) do
		local categoryName = categoryInfo.key
		local currencies = addon.Data.Currencies[categoryName]

		if currencies then
			-- Create container frame for this expansion
			local expansionFrame = CreateFrame("Frame", nil, parent)
			expansionFrame:SetPoint("TOPLEFT", previousFrame, "BOTTOMLEFT", 0, -5)
			expansionFrame:SetPoint("RIGHT", parent, "RIGHT", -20, 0)

			local frameYOffset = 0

			-- Category header with checkbox
			local catCheck = CreateCustomCheckbox(expansionFrame, categoryInfo.name, addon.db.settings.categories[categoryInfo.setting] ~= false)
			catCheck:SetPoint("TOPLEFT", 0, frameYOffset)
			catCheck.label:SetFontObject("GameFontNormalLarge")
			catCheck.label:SetTextColor(0.56, 0.63, 0.53)

			frameYOffset = frameYOffset - 30

			-- Store currency checkboxes and content for this category
			local currencyCheckboxes = {}
			local contentStartY = frameYOffset

			-- Display currencies in 2 columns
			local currencyIndex = 0
			local columnWidth = 350
			local column1X = 20
			local column2X = 380

			for _, currencyInfo in ipairs(currencies) do
				local currencyID = currencyInfo[1]
				local currencyName = currencyInfo[2]

				-- Determine column position
				local col = currencyIndex % 2
				local row = math.floor(currencyIndex / 2)
				local xPos = col == 0 and column1X or column2X
				local yPos = contentStartY - (row * 28)

				local check = CreateCustomCheckbox(expansionFrame, currencyName, addon.db.settings.currencies[currencyID] ~= false)
				check:SetPoint("TOPLEFT", xPos, yPos)
				check.label:SetFontObject("GameFontNormalSmall")
				check.label:SetWidth(columnWidth - 30)

				-- Initialize if not set
				if addon.db.settings.currencies[currencyID] == nil then
					addon.db.settings.currencies[currencyID] = true
				end

				check:SetCallback(function(checked)
					addon.db.settings.currencies[currencyID] = checked
					if addon.Display then
						addon.Display:UpdateDisplay()
					end
				end)

				table.insert(currencyCheckboxes, check)
				currencyIndex = currencyIndex + 1
			end

			-- Calculate heights
			local numRows = math.ceil(#currencies / 2)
			local currenciesHeight = (numRows * 28) + 15
			local expandedHeight = 30 + currenciesHeight
			local collapsedHeight = 30

			-- Separator line
			local separator = expansionFrame:CreateTexture(nil, "ARTWORK")
			separator:SetHeight(1)
			separator:SetPoint("LEFT", 0, 0)
			separator:SetPoint("RIGHT", 0, 0)
			separator:SetPoint("TOP", 0, -(expandedHeight - 5))
			separator:SetColorTexture(0.56, 0.63, 0.53, 0.45)

			-- Function to update collapsed state
			local function UpdateCategoryState(enabled)
				if enabled then
					-- Expanded: show all currencies and separator
					for _, currCheck in ipairs(currencyCheckboxes) do
						currCheck:Show()
					end
					separator:Show()
					expansionFrame:SetHeight(expandedHeight)
					catCheck.label:SetTextColor(0.56, 0.63, 0.53)
				else
					-- Collapsed: hide all currencies and separator
					for _, currCheck in ipairs(currencyCheckboxes) do
						currCheck:Hide()
					end
					separator:Hide()
					expansionFrame:SetHeight(collapsedHeight)
					catCheck.label:SetTextColor(0.6, 0.6, 0.6)
				end
				-- Recalculate total content height
				RecalculateContentHeight()
			end

			-- Set initial state
			UpdateCategoryState(catCheck:GetChecked())

			-- Update state when category checkbox is clicked
			catCheck:SetCallback(function(checked)
				addon.db.settings.categories[categoryInfo.setting] = checked
				UpdateCategoryState(checked)
				if addon.Display then
					addon.Display:UpdateDisplay()
				end
			end)

			previousFrame = expansionFrame
			table.insert(expansionFrames, expansionFrame)
		end
	end

	-- Calculate initial content height
	C_Timer.After(0.1, function()
		RecalculateContentHeight()
	end)
end

function Config:SaveSettings()
	-- Settings are saved directly to addon.db
	if addon.Tracker then
		addon.Tracker:UpdateAllCurrencies()
	end
end

function Config:Show()
	if not configFrame then
		self:Initialize()
	end
	configFrame:Show()
end

function Config:RefreshCurrentTab()
	if not configFrame then return end
	-- Re-initialize to refresh the current tab content
	configFrame:Hide()
	self:Initialize()
	configFrame:Show()
end

function Config:Hide()
	if configFrame then
		configFrame:Hide()
	end
end

function Config:Toggle()
	if configFrame and configFrame:IsShown() then
		self:Hide()
	else
		self:Show()
	end
end

-- ============================================================================
-- TAB 4: WEEKLY & PROGRESSION SETTINGS
-- ============================================================================

function Config:BuildWeeklyProgressionSettings(parent)
	local yOffset = -20

	-- Section title
	local title = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 10, yOffset)
	title:SetText("Weekly & Progression Tracking")
	title:SetTextColor(0.56, 0.63, 0.53)
	yOffset = yOffset - 35

	-- Show Weekly Reset Timer
	local weeklyResetCheck = CreateCustomCheckbox(parent, "Show Weekly Reset Timer", addon.db.settings.showWeeklyResets)
	weeklyResetCheck:SetPoint("TOPLEFT", 10, yOffset)
	weeklyResetCheck:SetCallback(function(checked)
		addon.db.settings.showWeeklyResets = checked
		if addon.Display and addon.Display.UpdateDisplay then
			addon.Display:UpdateDisplay()
		end
	end)
	yOffset = yOffset - 35

	-- Show Raid Lockouts
	local raidLockoutsCheck = CreateCustomCheckbox(parent, "Show Raid Lockouts", addon.db.settings.showRaidLockouts)
	raidLockoutsCheck:SetPoint("TOPLEFT", 10, yOffset)
	raidLockoutsCheck:SetCallback(function(checked)
		addon.db.settings.showRaidLockouts = checked
		if addon.Display and addon.Display.UpdateDisplay then
			addon.Display:UpdateDisplay()
		end
	end)
	yOffset = yOffset - 35

	-- Show World Boss Status
	local worldBossCheck = CreateCustomCheckbox(parent, "Show World Boss Status", addon.db.settings.showWorldBosses)
	worldBossCheck:SetPoint("TOPLEFT", 10, yOffset)
	worldBossCheck:SetCallback(function(checked)
		addon.db.settings.showWorldBosses = checked
		if addon.Display and addon.Display.UpdateDisplay then
			addon.Display:UpdateDisplay()
		end
	end)
	yOffset = yOffset - 35

	-- Show Upgrade Context
	local upgradeContextCheck = CreateCustomCheckbox(parent, "Show Upgrade Context", addon.db.settings.showUpgradeContext)
	upgradeContextCheck:SetPoint("TOPLEFT", 10, yOffset)
	upgradeContextCheck:SetCallback(function(checked)
		addon.db.settings.showUpgradeContext = checked
		if addon.Display and addon.Display.UpdateDisplay then
			addon.Display:UpdateDisplay()
		end
	end)
	yOffset = yOffset - 35

	-- Warn About Wasted Upgrades
	local wasteWarningCheck = CreateCustomCheckbox(parent, "Warn About Wasted Upgrades", addon.db.settings.warnWastedUpgrades)
	wasteWarningCheck:SetPoint("TOPLEFT", 10, yOffset)
	wasteWarningCheck:SetCallback(function(checked)
		addon.db.settings.warnWastedUpgrades = checked
		if addon.Display and addon.Display.UpdateDisplay then
			addon.Display:UpdateDisplay()
		end
	end)
	yOffset = yOffset - 35

	-- Show Cooldowns
	local cooldownsCheck = CreateCustomCheckbox(parent, "Show Cooldowns", addon.db.settings.showCooldowns)
	cooldownsCheck:SetPoint("TOPLEFT", 10, yOffset)
	cooldownsCheck:SetCallback(function(checked)
		addon.db.settings.showCooldowns = checked
		if addon.Display and addon.Display.UpdateDisplay then
			addon.Display:UpdateDisplay()
		end
	end)
	yOffset = yOffset - 35

	-- Help text
	local helpText = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	helpText:SetPoint("TOPLEFT", 10, yOffset)
	helpText:SetPoint("RIGHT", -10, 0)
	helpText:SetJustifyH("LEFT")
	helpText:SetText("These settings control which weekly reset and progression features are shown in the main display.")
	helpText:SetTextColor(0.7, 0.7, 0.7)
	helpText:SetSpacing(3)
end

-- ============================================================================
-- TAB 5: CHECKLIST & ALTS SETTINGS
-- ============================================================================

function Config:BuildChecklistAltsSettings(parent)
	local yOffset = -20

	-- Section title
	local title = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 10, yOffset)
	title:SetText("Checklist & Alt Dashboard")
	title:SetTextColor(0.56, 0.63, 0.53)
	yOffset = yOffset - 35

	-- Checklist subsection
	local checklistTitle = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	checklistTitle:SetPoint("TOPLEFT", 10, yOffset)
	checklistTitle:SetText("Smart Checklist Settings")
	checklistTitle:SetTextColor(0.95, 0.95, 0.95)
	yOffset = yOffset - 30

	-- Show Smart Checklist
	local checklistCheck = CreateCustomCheckbox(parent, "Show Smart Checklist", addon.db.settings.showChecklist)
	checklistCheck:SetPoint("TOPLEFT", 20, yOffset)
	checklistCheck:SetCallback(function(checked)
		addon.db.settings.showChecklist = checked
		addon.db.display.showChecklist = checked
		if checked and addon.Display and addon.Display.ShowChecklist then
			addon.Display:ShowChecklist()
		elseif not checked and addon.Display and addon.Display.HideChecklist then
			addon.Display:HideChecklist()
		end
	end)
	yOffset = yOffset - 35

	-- Auto-Hide Completed Tasks
	local autoHideCheck = CreateCustomCheckbox(parent, "Auto-Hide Completed Tasks", addon.db.settings.autoHideCompleted)
	autoHideCheck:SetPoint("TOPLEFT", 20, yOffset)
	autoHideCheck:SetCallback(function(checked)
		addon.db.settings.autoHideCompleted = checked
		if addon.Display and addon.Display.UpdateChecklist then
			addon.Display:UpdateChecklist()
		end
	end)
	yOffset = yOffset - 35

	-- Priority Order label
	local priorityLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	priorityLabel:SetPoint("TOPLEFT", 20, yOffset)
	priorityLabel:SetText("Task Sort Order:")
	priorityLabel:SetTextColor(0.95, 0.95, 0.95)

	-- Priority dropdown buttons
	local priorityValue = CreateCustomButton(parent, 120, 25, addon.db.settings.checklistPriority == "alphabetical" and "Alphabetical" or "Priority")
	priorityValue:SetPoint("LEFT", priorityLabel, "RIGHT", 10, 0)
	priorityValue:SetScript("OnClick", function(self)
		-- Toggle between value and alphabetical
		if addon.db.settings.checklistPriority == "value" then
			addon.db.settings.checklistPriority = "alphabetical"
			self.text:SetText("Alphabetical")
		else
			addon.db.settings.checklistPriority = "value"
			self.text:SetText("Priority")
		end
		if addon.Display and addon.Display.UpdateChecklist then
			addon.Display:UpdateChecklist()
		end
	end)
	yOffset = yOffset - 45

	-- Alt Dashboard subsection
	local altTitle = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	altTitle:SetPoint("TOPLEFT", 10, yOffset)
	altTitle:SetText("Alt Dashboard Settings")
	altTitle:SetTextColor(0.95, 0.95, 0.95)
	yOffset = yOffset - 30

	-- Alt Sort Order label
	local altSortLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	altSortLabel:SetPoint("TOPLEFT", 20, yOffset)
	altSortLabel:SetText("Alt Sort Order:")
	altSortLabel:SetTextColor(0.95, 0.95, 0.95)

	-- Alt sort dropdown buttons
	local sortOrders = {
		{key = "completion", label = "Completion %"},
		{key = "name", label = "Name"},
		{key = "vault", label = "Vault Progress"},
	}
	local currentSort = addon.db.settings.altSortOrder or "completion"
	local currentLabel = "Completion %"
	for _, order in ipairs(sortOrders) do
		if order.key == currentSort then
			currentLabel = order.label
			break
		end
	end

	local altSortValue = CreateCustomButton(parent, 120, 25, currentLabel)
	altSortValue:SetPoint("LEFT", altSortLabel, "RIGHT", 10, 0)
	altSortValue:SetScript("OnClick", function(self)
		-- Cycle through sort orders
		local currentIndex = 1
		for i, order in ipairs(sortOrders) do
			if order.key == addon.db.settings.altSortOrder then
				currentIndex = i
				break
			end
		end
		local nextIndex = (currentIndex % #sortOrders) + 1
		addon.db.settings.altSortOrder = sortOrders[nextIndex].key
		self.text:SetText(sortOrders[nextIndex].label)
		if addon.Display and addon.Display.UpdateDisplay then
			addon.Display:UpdateDisplay()
		end
	end)
	yOffset = yOffset - 50

	-- Blacklist Manager subsection
	local blacklistTitle = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	blacklistTitle:SetPoint("TOPLEFT", 10, yOffset)
	blacklistTitle:SetText("Blacklisted Characters")
	blacklistTitle:SetTextColor(0.95, 0.95, 0.95)
	yOffset = yOffset - 25

	-- Get blacklist
	local blacklist = addon.AltManager and addon.AltManager:GetBlacklist() or {}
	local hasBlacklist = next(blacklist) ~= nil

	if hasBlacklist then
		local blacklistInfo = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		blacklistInfo:SetPoint("TOPLEFT", 20, yOffset)
		blacklistInfo:SetText("These characters won't be tracked:")
		blacklistInfo:SetTextColor(0.8, 0.8, 0.8)
		yOffset = yOffset - 20

		for realmChar, _ in pairs(blacklist) do
			-- Extract name from key (Realm-Name)
			local name = realmChar:match("%-(.+)") or realmChar

			-- Character name
			local charText = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
			charText:SetPoint("TOPLEFT", 30, yOffset)
			charText:SetText(name)
			charText:SetTextColor(1, 0.5, 0.5)

			-- Remove button
			local removeBtn = CreateCustomButton(parent, 80, 20, "Remove")
			removeBtn:SetPoint("LEFT", charText, "RIGHT", 10, 0)
			removeBtn:SetScript("OnClick", function()
				if addon.AltManager and addon.AltManager.UnblacklistAlt then
					addon.AltManager:UnblacklistAlt(realmChar)
					-- Refresh config panel
					if addon.Config and addon.Config.RefreshCurrentTab then
						addon.Config:RefreshCurrentTab()
					end
				end
			end)

			yOffset = yOffset - 25
		end
	else
		local noneText = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		noneText:SetPoint("TOPLEFT", 20, yOffset)
		noneText:SetText("No blacklisted characters")
		noneText:SetTextColor(0.6, 0.6, 0.6)
		yOffset = yOffset - 20
	end

	yOffset = yOffset - 10

	-- Help text
	local helpText = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	helpText:SetPoint("TOPLEFT", 10, yOffset)
	helpText:SetPoint("RIGHT", -10, 0)
	helpText:SetJustifyH("LEFT")
	helpText:SetText("The checklist generates priority tasks from your weekly progress. Use /mtrack checklist to toggle it. The alt dashboard shows all characters' weekly progress - use /mtrack alts to switch views.")
	helpText:SetTextColor(0.7, 0.7, 0.7)
	helpText:SetSpacing(3)
end
