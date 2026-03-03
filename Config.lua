local addonName, addon = ...

-- Config module: settings panel
addon.Config = {}
local Config = addon.Config

local configFrame

-- Helper: Create custom slider
local function CreateCustomSlider(parent, width, min, max, step, defaultValue, label)
	local slider = CreateFrame("Frame", nil, parent)
	slider:SetSize(width, 30)

	slider.label = slider:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	slider.label:SetPoint("BOTTOMLEFT", slider, "TOPLEFT", 0, 5)
	slider.label:SetText(label)
	slider.label:SetTextColor(0.95, 0.95, 0.95)

	slider.valueText = slider:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	slider.valueText:SetPoint("BOTTOMRIGHT", slider, "TOPRIGHT", 0, 5)
	slider.valueText:SetTextColor(0.95, 0.95, 0.95)

	local track = slider:CreateTexture(nil, "BACKGROUND")
	track:SetPoint("LEFT", 0, 0)
	track:SetPoint("RIGHT", 0, 0)
	track:SetHeight(4)
	track:SetColorTexture(0.22, 0.22, 0.24, 1)

	slider.fill = slider:CreateTexture(nil, "BORDER")
	slider.fill:SetPoint("LEFT", 0, 0)
	slider.fill:SetHeight(4)
	slider.fill:SetColorTexture(0.5, 0.58, 0.46, 1)

	slider.thumb = CreateFrame("Button", nil, slider)
	slider.thumb:SetSize(16, 16)
	slider.thumb:SetPoint("LEFT", 0, 0)

	local thumbTex = slider.thumb:CreateTexture(nil, "OVERLAY")
	thumbTex:SetAllPoints()
	thumbTex:SetColorTexture(0.56, 0.63, 0.53, 1)

	slider.min = min
	slider.max = max
	slider.step = step
	slider.value = defaultValue

	function slider:UpdatePosition()
		local percent = (self.value - self.min) / (self.max - self.min)
		self.thumb:SetPoint("LEFT", percent * width, 0)
		self.fill:SetWidth(percent * width)
	end

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

	function slider:GetValue()
		return self.value
	end

	function slider:SetCallback(callback)
		self.onValueChanged = callback
	end

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

	local bg = checkbox:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetColorTexture(0.56, 0.63, 0.53, 1)

	local border = checkbox:CreateTexture(nil, "BORDER")
	border:SetPoint("TOPLEFT", checkbox, "TOPLEFT", 1, -1)
	border:SetPoint("BOTTOMRIGHT", checkbox, "BOTTOMRIGHT", -1, 1)
	border:SetColorTexture(0, 0, 0, 1)

	checkbox.check = checkbox:CreateTexture(nil, "OVERLAY")
	checkbox.check:SetPoint("TOPLEFT", checkbox, "TOPLEFT", 4, -4)
	checkbox.check:SetPoint("BOTTOMRIGHT", checkbox, "BOTTOMRIGHT", -4, 4)
	checkbox.check:SetColorTexture(0.56, 0.63, 0.53, 1)
	checkbox.check:Hide()

	checkbox.label = checkbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	checkbox.label:SetPoint("LEFT", checkbox, "RIGHT", 8, 0)
	checkbox.label:SetText(label)
	checkbox.label:SetTextColor(0.95, 0.95, 0.95)
	checkbox.label:SetJustifyH("LEFT")

	checkbox.checked = checked or false

	function checkbox:UpdateVisual()
		if self.checked then
			self.check:Show()
		else
			self.check:Hide()
		end
	end

	function checkbox:SetChecked(checked)
		self.checked = checked
		self:UpdateVisual()
		if self.onClick then
			self.onClick(checked)
		end
	end

	function checkbox:GetChecked()
		return self.checked
	end

	function checkbox:SetCallback(callback)
		self.onClick = callback
	end

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

	button.bg = button:CreateTexture(nil, "BACKGROUND")
	button.bg:SetAllPoints()
	button.bg:SetColorTexture(0, 0, 0, 1)

	local border = button:CreateTexture(nil, "BORDER")
	border:SetPoint("TOPLEFT", -1, 1)
	border:SetPoint("BOTTOMRIGHT", 1, -1)
	border:SetColorTexture(0.56, 0.63, 0.53, 1)

	button.highlight = button:CreateTexture(nil, "HIGHLIGHT")
	button.highlight:SetAllPoints()
	button.highlight:SetColorTexture(0.56, 0.63, 0.53, 0.18)

	button.text = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	button.text:SetPoint("CENTER")
	button.text:SetText(text)
	button.text:SetTextColor(0.95, 0.95, 0.95)

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

	local bg = configFrame:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetColorTexture(0.04, 0.04, 0.05, 0.98)

	local border = configFrame:CreateTexture(nil, "BORDER")
	border:SetPoint("TOPLEFT", -2, 2)
	border:SetPoint("BOTTOMRIGHT", 2, -2)
	border:SetColorTexture(0, 0, 0, 1)

	local titleBar = configFrame:CreateTexture(nil, "ARTWORK")
	titleBar:SetPoint("TOPLEFT", 0, 0)
	titleBar:SetPoint("TOPRIGHT", 0, 0)
	titleBar:SetHeight(40)
	titleBar:SetColorTexture(0, 0, 0, 1)

	local title = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOP", 0, -12)
	title:SetText("MidnightTracker Settings")
	title:SetTextColor(0.56, 0.63, 0.53)

	local closeBtn = CreateFrame("Button", nil, configFrame)
	closeBtn:SetSize(25, 25)
	closeBtn:SetPoint("TOPRIGHT", -8, -8)

	local closeBg = closeBtn:CreateTexture(nil, "BACKGROUND")
	closeBg:SetAllPoints()
	closeBg:SetColorTexture(0.45, 0.12, 0.12, 1)

	local closeText = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	closeText:SetPoint("CENTER", 0, 1)
	closeText:SetText("x")
	closeText:SetTextColor(1, 1, 1)

	local closeHighlight = closeBtn:CreateTexture(nil, "HIGHLIGHT")
	closeHighlight:SetAllPoints()
	closeHighlight:SetColorTexture(1, 0.2, 0.2, 0.35)

	closeBtn:SetScript("OnClick", function()
		Config:Hide()
	end)

	self:BuildSettings(configFrame)

	addon.Utils:Debug("Config panel initialized")
end

function Config:BuildSettings(parent)
	local tabs = {}
	local tabContents = {}

	local tabNames = {"Display", "General", "Expansions"}
	local tabWidth = 120
	local tabHeight = 35
	local tabSpacing = 5
	local tabStartY = -50

	for i, tabName in ipairs(tabNames) do
		local tab = CreateFrame("Button", nil, parent)
		tab:SetSize(tabWidth, tabHeight)
		tab:SetPoint("TOPLEFT", 15 + ((i-1) * (tabWidth + tabSpacing)), tabStartY)
		tab:SetFrameLevel(parent:GetFrameLevel() + 5)

		tab.bg = tab:CreateTexture(nil, "BACKGROUND")
		tab.bg:SetAllPoints()
		tab.bg:SetColorTexture(0.07, 0.07, 0.09, 1)

		local border = tab:CreateTexture(nil, "BORDER")
		border:SetPoint("TOPLEFT", -1, 1)
		border:SetPoint("BOTTOMRIGHT", 1, -1)
		border:SetColorTexture(0.56, 0.63, 0.53, 1)

		tab.highlight = tab:CreateTexture(nil, "HIGHLIGHT")
		tab.highlight:SetAllPoints()
		tab.highlight:SetColorTexture(0.56, 0.63, 0.53, 0.18)

		tab.text = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		tab.text:SetPoint("CENTER")
		tab.text:SetText(tabName)
		tab.text:SetTextColor(0.95, 0.95, 0.95)

		tabs[i] = tab
	end

	-- Scroll frame
	local scrollFrame = CreateFrame("ScrollFrame", nil, parent)
	scrollFrame:SetPoint("TOPLEFT", 15, tabStartY - tabHeight - 15)
	scrollFrame:SetPoint("BOTTOMRIGHT", -15, 15)
	scrollFrame:EnableMouseWheel(true)
	scrollFrame:SetFrameLevel(parent:GetFrameLevel() + 1)

	local scrollbar = CreateFrame("Slider", nil, scrollFrame)
	scrollbar:SetPoint("TOPRIGHT", 0, -5)
	scrollbar:SetPoint("BOTTOMRIGHT", 0, 5)
	scrollbar:SetWidth(12)
	scrollbar:SetOrientation("VERTICAL")
	scrollbar:SetMinMaxValues(0, 100)
	scrollbar:SetValue(0)

	local scrollbarBg = scrollbar:CreateTexture(nil, "BACKGROUND")
	scrollbarBg:SetAllPoints()
	scrollbarBg:SetColorTexture(0.07, 0.07, 0.09, 1)

	local scrollbarThumb = scrollbar:CreateTexture(nil, "OVERLAY")
	scrollbarThumb:SetSize(12, 30)
	scrollbarThumb:SetColorTexture(0.56, 0.63, 0.53, 1)
	scrollbar:SetThumbTexture(scrollbarThumb)

	scrollFrame:SetScript("OnMouseWheel", function(self, delta)
		local current = scrollbar:GetValue()
		local minVal, maxVal = scrollbar:GetMinMaxValues()
		if delta < 0 and current < maxVal then
			scrollbar:SetValue(math.min(maxVal, current + 20))
		elseif delta > 0 and current > minVal then
			scrollbar:SetValue(math.max(minVal, current - 20))
		end
	end)

	scrollbar:SetScript("OnValueChanged", function(self, value)
		scrollFrame:SetVerticalScroll(value)
	end)

	local scrollChild = CreateFrame("Frame", nil, scrollFrame)
	scrollChild:SetSize(750, 2100)
	scrollFrame:SetScrollChild(scrollChild)

	local function UpdateScrollRange(tabIndex)
		local content = tabContents[tabIndex]
		if not content then return end

		if tabIndex == 1 or tabIndex == 2 then
			scrollbar:Hide()
			scrollbar:SetMinMaxValues(0, 0)
			scrollbar:SetValue(0)
			scrollFrame:SetVerticalScroll(0)
		else
			scrollbar:Show()
			local maxScroll = math.max(0, content:GetHeight() - scrollFrame:GetHeight())
			scrollbar:SetMinMaxValues(0, maxScroll)
			scrollbar:SetValue(0)
		end
	end

	scrollFrame:SetScript("OnShow", function(self)
		UpdateScrollRange(1)
	end)

	for i = 1, #tabNames do
		local content = CreateFrame("Frame", nil, scrollChild)
		content:SetPoint("TOPLEFT", 0, 0)
		content:SetPoint("TOPRIGHT", -20, 0)
		if i == 1 or i == 2 then
			content:SetHeight(450)
		else
			content:SetHeight(2100)
		end
		content:Hide()
		tabContents[i] = content

		tabs[i]:SetScript("OnClick", function()
			for j, otherTab in ipairs(tabs) do
				otherTab.bg:SetColorTexture(0.07, 0.07, 0.09, 1)
				otherTab.text:SetTextColor(0.95, 0.95, 0.95)
				otherTab:SetEnabled(true)
				tabContents[j]:Hide()
			end
			tabs[i].bg:SetColorTexture(0.09, 0.11, 0.09, 1)
			tabs[i].text:SetTextColor(0.56, 0.63, 0.53)
			tabs[i]:SetEnabled(false)
			content:Show()
			UpdateScrollRange(i)
		end)
	end

	-- Show first tab by default
	tabContents[1]:Show()
	tabs[1].bg:SetColorTexture(0.09, 0.11, 0.09, 1)
	tabs[1].text:SetTextColor(0.56, 0.63, 0.53)
	tabs[1]:SetEnabled(false)

	self:BuildDisplaySettings(tabContents[1])
	self:BuildGeneralSettings(tabContents[2])
	self:BuildExpansionsSettings(tabContents[3])
end

function Config:BuildDisplaySettings(parent)
	local yOffset = -20

	local sizeLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	sizeLabel:SetPoint("TOPLEFT", 10, yOffset)
	sizeLabel:SetText("Display Size:")
	sizeLabel:SetTextColor(0.95, 0.95, 0.95)
	yOffset = yOffset - 25

	local sizePresets = {
		{name = "Small", scale = 0.8, iconSize = 14, fontSize = "small"},
		{name = "Medium", scale = 1.0, iconSize = 18, fontSize = "normal"},
		{name = "Large", scale = 1.2, iconSize = 24, fontSize = "normal"},
	}

	local sizeButtons = {}

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
			addon.db.display.scale = preset.scale
			addon.db.display.iconSize = preset.iconSize
			addon.db.display.fontSize = preset.fontSize

			for _, b in ipairs(sizeButtons) do
				b:SetEnabled(true)
			end
			self:SetEnabled(false)

			if addon.Display then
				addon.Display:UpdateDisplay()
			end
		end)

		table.insert(sizeButtons, btn)
	end

	yOffset = yOffset - 70

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

	local borderCheck = CreateCustomCheckbox(parent, "Show Border", addon.db.display.showBorder ~= false)
	borderCheck:SetPoint("TOPLEFT", 10, yOffset)
	borderCheck:SetCallback(function(checked)
		addon.db.display.showBorder = checked
		if addon.Display then
			addon.Display:UpdateDisplay()
		end
	end)
	yOffset = yOffset - 30

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

	local showZeroCheck = CreateCustomCheckbox(parent, "Show currencies with 0 count", addon.db.settings.showZeroCurrencies or false)
	showZeroCheck:SetPoint("TOPLEFT", 10, yOffset)
	showZeroCheck:SetCallback(function(checked)
		addon.db.settings.showZeroCurrencies = checked
		if addon.Display then
			addon.Display:UpdateDisplay()
		end
	end)
	yOffset = yOffset - 30

	local showUndiscoveredCheck = CreateCustomCheckbox(parent, "Show undiscovered currencies", addon.db.settings.showUndiscovered or false)
	showUndiscoveredCheck:SetPoint("TOPLEFT", 10, yOffset)
	showUndiscoveredCheck:SetCallback(function(checked)
		addon.db.settings.showUndiscovered = checked
		if addon.Display then
			addon.Display:UpdateDisplay()
		end
	end)
	yOffset = yOffset - 30

	local abbreviateCheck = CreateCustomCheckbox(parent, "Abbreviate large numbers (1.5M instead of 1,500,000)", addon.db.settings.abbreviateNumbers ~= false)
	abbreviateCheck:SetPoint("TOPLEFT", 10, yOffset)
	abbreviateCheck:SetCallback(function(checked)
		addon.db.settings.abbreviateNumbers = checked
		if addon.Display then
			addon.Display:UpdateDisplay()
		end
	end)
	yOffset = yOffset - 30

	local filterZoneCheck = CreateCustomCheckbox(parent, "Only show currencies for current zone", addon.db.settings.filterByZone ~= false)
	filterZoneCheck:SetPoint("TOPLEFT", 10, yOffset)
	filterZoneCheck:SetCallback(function(checked)
		addon.db.settings.filterByZone = checked
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

	local function RecalculateContentHeight()
		local totalHeight = 20
		totalHeight = totalHeight + 30
		for _, frame in ipairs(expansionFrames) do
			totalHeight = totalHeight + frame:GetHeight() + 5
		end
		totalHeight = totalHeight + 20
		parent:SetHeight(totalHeight)
	end

	for i, categoryInfo in ipairs(orderedCategories) do
		local categoryName = categoryInfo.key
		local currencies = addon.Data.Currencies[categoryName]

		if currencies then
			local expansionFrame = CreateFrame("Frame", nil, parent)
			expansionFrame:SetPoint("TOPLEFT", previousFrame, "BOTTOMLEFT", 0, -5)
			expansionFrame:SetPoint("RIGHT", parent, "RIGHT", -20, 0)

			local frameYOffset = 0

			local catCheck = CreateCustomCheckbox(expansionFrame, categoryInfo.name, addon.db.settings.categories[categoryInfo.setting] ~= false)
			catCheck:SetPoint("TOPLEFT", 0, frameYOffset)
			catCheck.label:SetFontObject("GameFontNormalLarge")
			catCheck.label:SetTextColor(0.56, 0.63, 0.53)

			frameYOffset = frameYOffset - 30

			local currencyCheckboxes = {}
			local contentStartY = frameYOffset

			local columnWidth = 350
			local column1X = 20
			local column2X = 380
			local currencyIndex = 0

			for _, currencyInfo in ipairs(currencies) do
				local currencyID = currencyInfo[1]
				local currencyName = currencyInfo[2]

				local col = currencyIndex % 2
				local row = math.floor(currencyIndex / 2)
				local xPos = col == 0 and column1X or column2X
				local yPos = contentStartY - (row * 28)

				local check = CreateCustomCheckbox(expansionFrame, currencyName, addon.db.settings.currencies[currencyID] ~= false)
				check:SetPoint("TOPLEFT", xPos, yPos)
				check.label:SetFontObject("GameFontNormalSmall")
				check.label:SetWidth(columnWidth - 30)

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

			local numRows = math.ceil(#currencies / 2)
			local currenciesHeight = (numRows * 28) + 15
			local expandedHeight = 30 + currenciesHeight
			local collapsedHeight = 30

			local separator = expansionFrame:CreateTexture(nil, "ARTWORK")
			separator:SetHeight(1)
			separator:SetPoint("LEFT", 0, 0)
			separator:SetPoint("RIGHT", 0, 0)
			separator:SetPoint("TOP", 0, -(expandedHeight - 5))
			separator:SetColorTexture(0.56, 0.63, 0.53, 0.45)

			local function UpdateCategoryState(enabled)
				if enabled then
					for _, currCheck in ipairs(currencyCheckboxes) do
						currCheck:Show()
					end
					separator:Show()
					expansionFrame:SetHeight(expandedHeight)
					catCheck.label:SetTextColor(0.56, 0.63, 0.53)
				else
					for _, currCheck in ipairs(currencyCheckboxes) do
						currCheck:Hide()
					end
					separator:Hide()
					expansionFrame:SetHeight(collapsedHeight)
					catCheck.label:SetTextColor(0.6, 0.6, 0.6)
				end
				RecalculateContentHeight()
			end

			UpdateCategoryState(catCheck:GetChecked())

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

	C_Timer.After(0.1, function()
		RecalculateContentHeight()
	end)
end

function Config:SaveSettings()
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
