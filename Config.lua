local addonName, addon = ...

addon.Config = {}
local Config = addon.Config

local configFrame

-- Color palette matching CharacterStats design language
local C = {
	bg          = {0.06, 0.06, 0.06},
	bgLight     = {0.12, 0.12, 0.12},
	bgDark      = {0.08, 0.08, 0.08},
	bgHover     = {0.10, 0.10, 0.10},
	bgDeep      = {0.05, 0.05, 0.05},
	textPrimary = {0.92, 0.91, 0.86},
	textMuted   = {0.70, 0.70, 0.70},
	accent      = {0.78, 0.66, 0.22},
	border      = {0.22, 0.22, 0.22},
	divider     = {0.28, 0.28, 0.28},
}

-- Create a 1px 4-sided border using individual textures (returns border table)
local function CreateBorder(frame, r, g, b, a)
	r = r or C.border[1]
	g = g or C.border[2]
	b = b or C.border[3]
	a = a or 1

	local top = frame:CreateTexture(nil, "OVERLAY")
	top:SetPoint("TOPLEFT",     frame, "TOPLEFT",     0,  0)
	top:SetPoint("TOPRIGHT",    frame, "TOPRIGHT",    0,  0)
	top:SetHeight(1)
	top:SetColorTexture(r, g, b, a)

	local bot = frame:CreateTexture(nil, "OVERLAY")
	bot:SetPoint("BOTTOMLEFT",  frame, "BOTTOMLEFT",  0,  0)
	bot:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0,  0)
	bot:SetHeight(1)
	bot:SetColorTexture(r, g, b, a)

	local lft = frame:CreateTexture(nil, "OVERLAY")
	lft:SetPoint("TOPLEFT",    frame, "TOPLEFT",    0, -1)
	lft:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0,  1)
	lft:SetWidth(1)
	lft:SetColorTexture(r, g, b, a)

	local rgt = frame:CreateTexture(nil, "OVERLAY")
	rgt:SetPoint("TOPRIGHT",    frame, "TOPRIGHT",    0, -1)
	rgt:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0,  1)
	rgt:SetWidth(1)
	rgt:SetColorTexture(r, g, b, a)

	return {top = top, bot = bot, lft = lft, rgt = rgt}
end

-- Set all 4 border textures to a color
local function SetBorderColor(b, r, g, bl, a)
	b.top:SetColorTexture(r, g, bl, a)
	b.bot:SetColorTexture(r, g, bl, a)
	b.lft:SetColorTexture(r, g, bl, a)
	b.rgt:SetColorTexture(r, g, bl, a)
end

-- Slider widget in CharacterStats style
local function CreateSlider(parent, opts)
	local width = opts.width or 240
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(width, 32)

	f.label = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	f.label:SetPoint("TOPLEFT", 0, 0)
	f.label:SetText(opts.label or "")
	f.label:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

	f.valueText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	f.valueText:SetPoint("TOPRIGHT", 0, 0)
	f.valueText:SetJustifyH("RIGHT")
	f.valueText:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

	-- Track background
	local track = f:CreateTexture(nil, "BACKGROUND")
	track:SetPoint("BOTTOMLEFT",  0, 4)
	track:SetPoint("BOTTOMRIGHT", 0, 4)
	track:SetHeight(4)
	track:SetColorTexture(0.20, 0.20, 0.20, 0.9)

	-- Gold fill
	f.fill = f:CreateTexture(nil, "BORDER")
	f.fill:SetPoint("BOTTOMLEFT", 0, 4)
	f.fill:SetHeight(4)
	f.fill:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.7)

	-- Thumb
	f.thumb = CreateFrame("Button", nil, f)
	f.thumb:SetSize(8, 8)
	local thumbTex = f.thumb:CreateTexture(nil, "OVERLAY")
	thumbTex:SetAllPoints()
	thumbTex:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.95)

	f.min   = opts.min
	f.max   = opts.max
	f.step  = opts.step
	f.value = opts.value or opts.min

	function f:UpdateThumb()
		local pct = (self.value - self.min) / (self.max - self.min)
		local px  = pct * width
		self.thumb:ClearAllPoints()
		self.thumb:SetPoint("LEFT", self, "LEFT", px - 4, -10)
		self.fill:SetWidth(math.max(0, px))
	end

	function f:SetValue(v)
		v = math.max(self.min, math.min(self.max, v))
		if self.step then
			v = math.floor((v / self.step) + 0.5) * self.step
		end
		self.value = v
		self:UpdateThumb()
		if self.onChange then self.onChange(v) end
	end

	function f:GetValue() return self.value end

	function f:SetCallback(fn) self.onChange = fn end

	f.thumb:EnableMouse(true)
	f.thumb:RegisterForDrag("LeftButton")
	f.thumb:SetScript("OnDragStart", function(self) self:GetParent().dragging = true end)
	f.thumb:SetScript("OnDragStop",  function(self) self:GetParent().dragging = false end)

	f:EnableMouse(true)
	f:SetScript("OnMouseDown", function(self, btn)
		if btn ~= "LeftButton" then return end
		local cx    = GetCursorPosition()
		local scale = self:GetEffectiveScale()
		local pct   = math.max(0, math.min(1, (cx / scale - self:GetLeft()) / width))
		self:SetValue(self.min + pct * (self.max - self.min))
		self.dragging = true
	end)
	f:SetScript("OnMouseUp",  function(self) self.dragging = false end)
	f:SetScript("OnUpdate",   function(self)
		if not self.dragging then return end
		local cx    = GetCursorPosition()
		local scale = self:GetEffectiveScale()
		local pct   = math.max(0, math.min(1, (cx / scale - self:GetLeft()) / width))
		self:SetValue(self.min + pct * (self.max - self.min))
	end)

	f:SetValue(f.value)
	return f
end

-- Checkbox in CharacterStats style (14px box, gold check)
local function CreateCheckbox(parent, label, checked)
	local BOX = 14
	local f = CreateFrame("Button", nil, parent)
	f:SetSize(BOX, BOX)

	local bg = f:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetColorTexture(0.10, 0.10, 0.10, 1)

	CreateBorder(f)

	local CHECK_INSET = 3
	f.check = f:CreateTexture(nil, "OVERLAY")
	f.check:SetPoint("TOPLEFT",     f, "TOPLEFT",     CHECK_INSET, -CHECK_INSET)
	f.check:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -CHECK_INSET, CHECK_INSET)
	f.check:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.9)
	f.check:Hide()

	f.labelStr = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	f.labelStr:SetPoint("LEFT", f, "RIGHT", 7, 0)
	f.labelStr:SetText(label or "")
	f.labelStr:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])
	f.labelStr:SetJustifyH("LEFT")

	f.checked = checked or false

	function f:SetChecked(v)
		self.checked = v
		if v then self.check:Show() else self.check:Hide() end
		if self.onClick then self.onClick(v) end
	end

	function f:GetChecked() return self.checked end
	function f:SetCallback(fn) self.onClick = fn end

	f:SetScript("OnClick",   function(self) self:SetChecked(not self.checked) end)
	f:SetScript("OnEnter",   function(self) self.labelStr:SetTextColor(C.textPrimary[1], C.textPrimary[2], C.textPrimary[3]) end)
	f:SetScript("OnLeave",   function(self) self.labelStr:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3]) end)

	if checked then f.check:Show() end
	return f
end

-- Flat button in CharacterStats style
local function CreateFlatButton(parent, width, height, text)
	local f = CreateFrame("Button", nil, parent)
	f:SetSize(width or 80, height or 22)

	f.bg = f:CreateTexture(nil, "BACKGROUND")
	f.bg:SetAllPoints()
	f.bg:SetColorTexture(C.bgLight[1], C.bgLight[2], C.bgLight[3], 1)

	f.border = CreateBorder(f)

	f.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	f.text:SetPoint("CENTER")
	f.text:SetText(text or "")
	f.text:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

	f:SetScript("OnEnter", function(self)
		self.bg:SetColorTexture(0.18, 0.18, 0.18, 1)
		self.text:SetTextColor(C.textPrimary[1], C.textPrimary[2], C.textPrimary[3])
	end)
	f:SetScript("OnLeave", function(self)
		self.bg:SetColorTexture(C.bgLight[1], C.bgLight[2], C.bgLight[3], 1)
		self.text:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])
	end)
	f:SetScript("OnMouseDown", function(self)
		self.bg:SetColorTexture(C.bgDark[1], C.bgDark[2], C.bgDark[3], 1)
	end)
	f:SetScript("OnMouseUp", function(self)
		self.bg:SetColorTexture(C.bgLight[1], C.bgLight[2], C.bgLight[3], 1)
	end)

	function f:SetActive(active)
		if active then
			self.bg:SetColorTexture(C.bgDark[1], C.bgDark[2], C.bgDark[3], 1)
			self.text:SetTextColor(C.accent[1], C.accent[2], C.accent[3])
			self:Disable()
		else
			self.bg:SetColorTexture(C.bgLight[1], C.bgLight[2], C.bgLight[3], 1)
			self.text:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])
			self:Enable()
		end
	end

	return f
end

-- Section divider line
local function CreateDivider(parent, width)
	local line = parent:CreateTexture(nil, "ARTWORK")
	line:SetHeight(1)
	line:SetWidth(width or 400)
	line:SetColorTexture(C.divider[1], C.divider[2], C.divider[3], 1)
	return line
end

-- Section header label
local function CreateSectionHeader(parent, text)
	local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	fs:SetText(text)
	fs:SetTextColor(C.accent[1], C.accent[2], C.accent[3])
	return fs
end

function Config:Initialize()
	configFrame = CreateFrame("Frame", "MidnightTrackerConfig", UIParent)
	configFrame:SetSize(600, 500)
	configFrame:SetPoint("CENTER")
	configFrame:SetMovable(true)
	configFrame:EnableMouse(true)
	configFrame:SetClampedToScreen(true)
	configFrame:RegisterForDrag("LeftButton")
	configFrame:SetScript("OnDragStart", configFrame.StartMoving)
	configFrame:SetScript("OnDragStop",  configFrame.StopMovingOrSizing)
	configFrame:Hide()
	configFrame:SetFrameStrata("DIALOG")
	table.insert(UISpecialFrames, "MidnightTrackerConfig")

	-- Main background
	local bg = configFrame:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetColorTexture(C.bg[1], C.bg[2], C.bg[3], 0.98)

	-- Outer 1px border
	CreateBorder(configFrame)

	-- Title bar
	local titleBar = configFrame:CreateTexture(nil, "ARTWORK")
	titleBar:SetPoint("TOPLEFT")
	titleBar:SetPoint("TOPRIGHT")
	titleBar:SetHeight(32)
	titleBar:SetColorTexture(C.bgDark[1], C.bgDark[2], C.bgDark[3], 1)

	-- Title bar bottom line
	local titleLine = configFrame:CreateTexture(nil, "ARTWORK")
	titleLine:SetPoint("TOPLEFT",  configFrame, "TOPLEFT",  0, -32)
	titleLine:SetPoint("TOPRIGHT", configFrame, "TOPRIGHT", 0, -32)
	titleLine:SetHeight(1)
	titleLine:SetColorTexture(C.border[1], C.border[2], C.border[3], 1)

	local title = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("LEFT", 12, 0)
	title:SetPoint("TOP",  0, -8)
	title:SetText("MidnightTracker")
	title:SetTextColor(C.textPrimary[1], C.textPrimary[2], C.textPrimary[3])

	-- Close button
	local closeBtn = CreateFrame("Button", nil, configFrame)
	closeBtn:SetSize(24, 24)
	closeBtn:SetPoint("TOPRIGHT", -4, -4)

	local closeBg = closeBtn:CreateTexture(nil, "BACKGROUND")
	closeBg:SetAllPoints()
	closeBg:SetColorTexture(0.15, 0.15, 0.15, 1)

	local closeBorder = CreateBorder(closeBtn)

	local closeText = closeBtn:CreateFontString(nil, "OVERLAY")
	closeText:SetFont(STANDARD_TEXT_FONT, 16)
	closeText:SetPoint("CENTER", 0, 1)
	closeText:SetText("×")
	closeText:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

	closeBtn:SetScript("OnEnter", function(self)
		closeBg:SetColorTexture(0.5, 0.1, 0.1, 1)
		SetBorderColor(closeBorder, 0.7, 0.2, 0.2, 1)
		closeText:SetTextColor(1, 1, 1)
	end)
	closeBtn:SetScript("OnLeave", function(self)
		closeBg:SetColorTexture(0.15, 0.15, 0.15, 1)
		SetBorderColor(closeBorder, C.border[1], C.border[2], C.border[3], 1)
		closeText:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])
	end)
	closeBtn:SetScript("OnClick", function() Config:Hide() end)

	self:BuildSettings(configFrame)

	addon.Utils:Debug("Config panel initialized")
end

function Config:BuildSettings(parent)
	local tabs        = {}
	local tabContents = {}
	local tabNames    = {"Display", "General", "Expansions"}

	-- Tab bar (below title bar)
	local TAB_Y   = -33   -- top of tab bar, 1px below title line
	local TAB_H   = 27
	local TAB_PAD = 24    -- horizontal text padding per tab
	local TAB_GAP = 8
	local tabX    = 12

	for i, name in ipairs(tabNames) do
		local tab = CreateFrame("Button", nil, parent)
		tab:SetHeight(TAB_H)
		tab:SetPoint("TOPLEFT", tabX, TAB_Y)

		-- Measure text width to size tab
		local measure = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		measure:SetText(name)
		measure:Hide()
		local tw = measure:GetStringWidth() + TAB_PAD
		tab:SetWidth(tw)
		tabX = tabX + tw + TAB_GAP

		-- Background
		tab.bg = tab:CreateTexture(nil, "BACKGROUND")
		tab.bg:SetAllPoints()
		tab.bg:SetColorTexture(C.bgDeep[1], C.bgDeep[2], C.bgDeep[3], 1)

		-- 4 individual border textures so we can color top separately
		tab.bTop = tab:CreateTexture(nil, "BORDER")
		tab.bTop:SetPoint("TOPLEFT",  tab, "TOPLEFT",  0, 0)
		tab.bTop:SetPoint("TOPRIGHT", tab, "TOPRIGHT", 0, 0)
		tab.bTop:SetHeight(1)
		tab.bTop:SetColorTexture(C.border[1], C.border[2], C.border[3], 1)

		tab.bBot = tab:CreateTexture(nil, "BORDER")
		tab.bBot:SetPoint("BOTTOMLEFT",  tab, "BOTTOMLEFT",  0, 0)
		tab.bBot:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", 0, 0)
		tab.bBot:SetHeight(1)
		tab.bBot:SetColorTexture(C.border[1], C.border[2], C.border[3], 1)

		tab.bLft = tab:CreateTexture(nil, "BORDER")
		tab.bLft:SetPoint("TOPLEFT",    tab, "TOPLEFT",    0, -1)
		tab.bLft:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", 0,  1)
		tab.bLft:SetWidth(1)
		tab.bLft:SetColorTexture(C.border[1], C.border[2], C.border[3], 1)

		tab.bRgt = tab:CreateTexture(nil, "BORDER")
		tab.bRgt:SetPoint("TOPRIGHT",    tab, "TOPRIGHT",    0, -1)
		tab.bRgt:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", 0,  1)
		tab.bRgt:SetWidth(1)
		tab.bRgt:SetColorTexture(C.border[1], C.border[2], C.border[3], 1)

		tab.label = tab:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		tab.label:SetPoint("CENTER")
		tab.label:SetText(name)
		tab.label:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

		tab:SetScript("OnEnter", function(self)
			if not self.active then
				self.bg:SetColorTexture(C.bgHover[1], C.bgHover[2], C.bgHover[3], 1)
				self.label:SetTextColor(C.textPrimary[1], C.textPrimary[2], C.textPrimary[3])
			end
		end)
		tab:SetScript("OnLeave", function(self)
			if not self.active then
				self.bg:SetColorTexture(C.bgDeep[1], C.bgDeep[2], C.bgDeep[3], 1)
				self.label:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])
			end
		end)

		tabs[i] = tab
	end

	-- Content area: below tab bar
	local CONTENT_TOP = TAB_Y - TAB_H - 1

	-- Scroll frame for tab contents
	local scrollFrame = CreateFrame("ScrollFrame", nil, parent)
	scrollFrame:SetPoint("TOPLEFT",     12, CONTENT_TOP)
	scrollFrame:SetPoint("BOTTOMRIGHT", -12, 12)
	scrollFrame:EnableMouseWheel(true)
	scrollFrame:SetFrameLevel(parent:GetFrameLevel() + 1)

	-- Scrollbar
	local scrollbar = CreateFrame("Slider", nil, scrollFrame)
	scrollbar:SetPoint("TOPRIGHT",    0, -2)
	scrollbar:SetPoint("BOTTOMRIGHT", 0,  2)
	scrollbar:SetWidth(6)
	scrollbar:SetOrientation("VERTICAL")
	scrollbar:SetMinMaxValues(0, 0)
	scrollbar:SetValue(0)
	scrollbar:Hide()

	local sbTrack = scrollbar:CreateTexture(nil, "BACKGROUND")
	sbTrack:SetAllPoints()
	sbTrack:SetColorTexture(0.15, 0.15, 0.15, 1)

	local sbThumb = scrollbar:CreateTexture(nil, "OVERLAY")
	sbThumb:SetSize(6, 30)
	sbThumb:SetColorTexture(0.40, 0.40, 0.40, 1)
	scrollbar:SetThumbTexture(sbThumb)

	scrollFrame:SetScript("OnMouseWheel", function(self, delta)
		local cur = scrollbar:GetValue()
		local mn, mx = scrollbar:GetMinMaxValues()
		scrollbar:SetValue(math.max(mn, math.min(mx, cur - delta * 40)))
	end)
	scrollbar:SetScript("OnValueChanged", function(self, v)
		scrollFrame:SetVerticalScroll(v)
	end)

	local scrollChild = CreateFrame("Frame", nil, scrollFrame)
	scrollChild:SetSize(560, 1)
	scrollFrame:SetScrollChild(scrollChild)

	local function ShowTab(idx)
		for j, t in ipairs(tabs) do
			-- Reset all to inactive style
			t.active = false
			t.bg:SetColorTexture(C.bgDeep[1], C.bgDeep[2], C.bgDeep[3], 1)
			t.bTop:SetColorTexture(C.border[1], C.border[2], C.border[3], 1)
			t.bBot:SetColorTexture(C.border[1], C.border[2], C.border[3], 1)
			t.bLft:SetColorTexture(C.border[1], C.border[2], C.border[3], 1)
			t.bRgt:SetColorTexture(C.border[1], C.border[2], C.border[3], 1)
			t.label:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])
			t:Enable()
			tabContents[j]:Hide()
		end

		-- Active tab style: dark bg, gold top border, side borders at 0.6 alpha, no bottom border
		local t = tabs[idx]
		t.active = true
		t.bg:SetColorTexture(C.bgDark[1], C.bgDark[2], C.bgDark[3], 1)
		t.bTop:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1)
		t.bLft:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.6)
		t.bRgt:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.6)
		t.bBot:SetColorTexture(C.bgDark[1], C.bgDark[2], C.bgDark[3], 0)  -- hidden
		t.label:SetTextColor(C.textPrimary[1], C.textPrimary[2], C.textPrimary[3])
		t:Disable()

		tabContents[idx]:Show()

		-- Update scrollbar
		local ch = tabContents[idx]:GetHeight()
		local sh = scrollFrame:GetHeight()
		local maxScroll = math.max(0, ch - sh)
		scrollbar:SetMinMaxValues(0, maxScroll)
		scrollbar:SetValue(0)
		if maxScroll > 0 then scrollbar:Show() else scrollbar:Hide() end
	end

	for i = 1, #tabNames do
		local content = CreateFrame("Frame", nil, scrollChild)
		content:SetPoint("TOPLEFT",  0, 0)
		content:SetPoint("TOPRIGHT", -20, 0)
		content:SetHeight(400)
		content:Hide()
		tabContents[i] = content

		tabs[i]:SetScript("OnClick", function() ShowTab(i) end)
	end

	-- Build panel contents
	self:BuildDisplaySettings(tabContents[1])
	self:BuildGeneralSettings(tabContents[2])
	self:BuildExpansionsSettings(tabContents[3])

	ShowTab(1)
end

function Config:BuildDisplaySettings(parent)
	local y = -16
	local PAD = 14

	-- Size presets section
	local hdr1 = CreateSectionHeader(parent, "Display Size")
	hdr1:SetPoint("TOPLEFT", PAD, y)
	y = y - 20

	local div1 = CreateDivider(parent, 540)
	div1:SetPoint("TOPLEFT", PAD, y)
	y = y - 14

	local sizePresets = {
		{name = "Small",  scale = 0.8, iconSize = 14, fontSize = "small"},
		{name = "Medium", scale = 1.0, iconSize = 18, fontSize = "normal"},
		{name = "Large",  scale = 1.2, iconSize = 24, fontSize = "normal"},
	}

	local currentPreset = "Medium"
	for _, p in ipairs(sizePresets) do
		if addon.db.display.scale    == p.scale    and
		   addon.db.display.iconSize == p.iconSize and
		   addon.db.display.fontSize == p.fontSize then
			currentPreset = p.name
			break
		end
	end

	local sizeButtons = {}
	for i, preset in ipairs(sizePresets) do
		local btn = CreateFlatButton(parent, 90, 22, preset.name)
		btn:SetPoint("TOPLEFT", PAD + (i - 1) * 100, y)

		if preset.name == currentPreset then btn:SetActive(true) end

		btn:SetScript("OnClick", function(self)
			addon.db.display.scale    = preset.scale
			addon.db.display.iconSize = preset.iconSize
			addon.db.display.fontSize = preset.fontSize
			for _, b in ipairs(sizeButtons) do b:SetActive(false) end
			self:SetActive(true)
			if addon.Display then addon.Display:UpdateDisplay() end
		end)

		table.insert(sizeButtons, btn)
	end
	y = y - 40

	-- Sliders section
	local hdr2 = CreateSectionHeader(parent, "Layout")
	hdr2:SetPoint("TOPLEFT", PAD, y)
	y = y - 20

	local div2 = CreateDivider(parent, 540)
	div2:SetPoint("TOPLEFT", PAD, y)
	y = y - 18

	local rowSlider = CreateSlider(parent, {
		label = "Icons Per Row",
		width = 300,
		min   = 1,
		max   = 20,
		step  = 1,
		value = addon.db.display.iconsPerRow or 3,
	})
	rowSlider:SetPoint("TOPLEFT", PAD, y)
	rowSlider.valueText:SetFormattedText("%d", rowSlider:GetValue())
	rowSlider:SetCallback(function(v)
		addon.db.display.iconsPerRow = v
		rowSlider.valueText:SetFormattedText("%d", v)
		if addon.Display then addon.Display:UpdateDisplay() end
	end)
	y = y - 50

	local opSlider = CreateSlider(parent, {
		label = "Background Opacity",
		width = 300,
		min   = 0,
		max   = 1,
		step  = 0.05,
		value = addon.db.display.backgroundOpacity or 0.8,
	})
	opSlider:SetPoint("TOPLEFT", PAD, y)
	opSlider.valueText:SetFormattedText("%d%%", opSlider:GetValue() * 100)
	opSlider:SetCallback(function(v)
		addon.db.display.backgroundOpacity = v
		opSlider.valueText:SetFormattedText("%d%%", v * 100)
		if addon.Display then addon.Display:UpdateDisplay() end
	end)
	y = y - 50

	-- Toggles section
	local hdr3 = CreateSectionHeader(parent, "Options")
	hdr3:SetPoint("TOPLEFT", PAD, y)
	y = y - 20

	local div3 = CreateDivider(parent, 540)
	div3:SetPoint("TOPLEFT", PAD, y)
	y = y - 18

	local CHECK_STEP = 28

	local borderCheck = CreateCheckbox(parent, "Show Border", addon.db.display.showBorder ~= false)
	borderCheck:SetPoint("TOPLEFT", PAD, y)
	borderCheck:SetCallback(function(v)
		addon.db.display.showBorder = v
		if addon.Display then addon.Display:UpdateDisplay() end
	end)
	y = y - CHECK_STEP

	local bgCheck = CreateCheckbox(parent, "Show Background", addon.db.display.showBackground ~= false)
	bgCheck:SetPoint("TOPLEFT", PAD, y)
	bgCheck:SetCallback(function(v)
		addon.db.display.showBackground = v
		if addon.Display then addon.Display:UpdateDisplay() end
	end)
	y = y - CHECK_STEP

	parent:SetHeight(math.abs(y) + 20)
end

function Config:BuildGeneralSettings(parent)
	local y   = -16
	local PAD = 14

	local hdr = CreateSectionHeader(parent, "Behavior")
	hdr:SetPoint("TOPLEFT", PAD, y)
	y = y - 20

	local div = CreateDivider(parent, 540)
	div:SetPoint("TOPLEFT", PAD, y)
	y = y - 18

	local CHECK_STEP = 28

	local checks = {
		{
			label    = "Show currencies with 0 count",
			setting  = "showZeroCurrencies",
			default  = false,
		},
		{
			label    = "Show undiscovered currencies",
			setting  = "showUndiscovered",
			default  = false,
		},
		{
			label    = "Abbreviate large numbers  (e.g. 1.5M instead of 1,500,000)",
			setting  = "abbreviateNumbers",
			default  = true,
		},
		{
			label    = "Only show currencies for current zone",
			setting  = "filterByZone",
			default  = true,
		},
	}

	for _, info in ipairs(checks) do
		local val = addon.db.settings[info.setting]
		if val == nil then val = info.default end
		local cb = CreateCheckbox(parent, info.label, val)
		cb:SetPoint("TOPLEFT", PAD, y)
		cb:SetCallback(function(v)
			addon.db.settings[info.setting] = v
			if addon.Display then addon.Display:UpdateDisplay() end
		end)
		y = y - CHECK_STEP
	end

	parent:SetHeight(math.abs(y) + 20)
end

function Config:BuildExpansionsSettings(parent)
	local y   = -16
	local PAD = 14

	local infoText = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	infoText:SetPoint("TOPLEFT", PAD, y)
	infoText:SetText("Enable expansions and individual currencies to show in the tracker.")
	infoText:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])
	infoText:SetWidth(540)
	y = y - 28

	local orderedCategories = {
		{name = "Midnight",               key = addon.Data.Categories.MIDNIGHT,    setting = "showMidnight"},
		{name = "War Within",             key = addon.Data.Categories.WARWITHIN,   setting = "showWarWithin"},
		{name = "Dragonflight",           key = addon.Data.Categories.DRAGONFLIGHT,setting = "showDragonflight"},
		{name = "Shadowlands",            key = addon.Data.Categories.SHADOWLANDS, setting = "showShadowlands"},
		{name = "Battle for Azeroth",     key = addon.Data.Categories.BFA,         setting = "showBFA"},
		{name = "Legion",                 key = addon.Data.Categories.LEGION,      setting = "showLegion"},
		{name = "Warlords of Draenor",    key = addon.Data.Categories.WOD,         setting = "showWoD"},
		{name = "Mists of Pandaria",      key = addon.Data.Categories.MOP,         setting = "showMoP"},
		{name = "Cataclysm",              key = addon.Data.Categories.CATACLYSM,   setting = "showCataclysm"},
		{name = "Wrath of the Lich King", key = addon.Data.Categories.WOTLK,       setting = "showWotLK"},
		{name = "Burning Crusade",        key = addon.Data.Categories.BC,          setting = "showBC"},
		{name = "PvP Currencies",         key = addon.Data.Categories.PVP,         setting = "showPvP"},
		{name = "Seasonal Events",        key = addon.Data.Categories.SEASONAL,    setting = "showSeasonal"},
	}

	local expansionFrames = {}

	local function RecalcHeight()
		local total = math.abs(y) + 16
		for _, ef in ipairs(expansionFrames) do
			total = total + ef:GetHeight() + 6
		end
		parent:SetHeight(total)
	end

	local prevBottom = infoText

	for _, catInfo in ipairs(orderedCategories) do
		local catKey   = catInfo.key
		local currencies = addon.Data.Currencies[catKey]

		if currencies then
		local ef = CreateFrame("Frame", nil, parent)
		ef:SetPoint("TOPLEFT",  prevBottom, "BOTTOMLEFT",  0, -6)
		ef:SetPoint("TOPRIGHT", parent,     "TOPRIGHT",   -PAD, 0)

		local fy = 0

		-- Category header checkbox
		local catEnabled = addon.db.settings.categories[catInfo.setting] ~= false
		local catCheck = CreateCheckbox(ef, catInfo.name, catEnabled)
		catCheck:SetPoint("TOPLEFT", 0, fy)
		catCheck.labelStr:SetFontObject("GameFontNormal")
		catCheck.labelStr:SetTextColor(
			catEnabled and C.accent[1] or C.textMuted[1],
			catEnabled and C.accent[2] or C.textMuted[2],
			catEnabled and C.accent[3] or C.textMuted[3]
		)
		fy = fy - 26

		-- Currency checkboxes in 2 columns
		local currencyChecks = {}
		local COL_W = 260
		local COL1X = 18
		local COL2X = 18 + COL_W
		local ROW_H = 22

		for ci, currInfo in ipairs(currencies) do
			local cid   = currInfo[1]
			local cname = currInfo[2]
			local col   = (ci - 1) % 2
			local row   = math.floor((ci - 1) / 2)
			local xPos  = col == 0 and COL1X or COL2X
			local yPos  = fy - row * ROW_H

			if addon.db.settings.currencies[cid] == nil then
				addon.db.settings.currencies[cid] = true
			end

			local cc = CreateCheckbox(ef, cname, addon.db.settings.currencies[cid] ~= false)
			cc:SetPoint("TOPLEFT", xPos, yPos)
			cc.labelStr:SetWidth(COL_W - 28)

			cc:SetCallback(function(v)
				addon.db.settings.currencies[cid] = v
				if addon.Display then addon.Display:UpdateDisplay() end
			end)

			table.insert(currencyChecks, cc)
		end

		local numRows        = math.ceil(#currencies / 2)
		local expandedHeight = 26 + numRows * ROW_H + 10
		local collapsedHeight = 26

		-- Bottom divider line for category
		local sep = ef:CreateTexture(nil, "ARTWORK")
		sep:SetHeight(1)
		sep:SetPoint("BOTTOMLEFT",  ef, "BOTTOMLEFT",  0, 4)
		sep:SetPoint("BOTTOMRIGHT", ef, "BOTTOMRIGHT", 0, 4)
		sep:SetColorTexture(C.border[1], C.border[2], C.border[3], 0.6)

		local function SetCategoryState(enabled)
			catCheck.labelStr:SetTextColor(
				enabled and C.accent[1] or C.textMuted[1],
				enabled and C.accent[2] or C.textMuted[2],
				enabled and C.accent[3] or C.textMuted[3]
			)
			for _, cc in ipairs(currencyChecks) do
				if enabled then cc:Show() else cc:Hide() end
			end
			sep:SetShown(enabled)
			ef:SetHeight(enabled and expandedHeight or collapsedHeight)
			RecalcHeight()
		end

		SetCategoryState(catEnabled)

		catCheck:SetCallback(function(v)
			addon.db.settings.categories[catInfo.setting] = v
			SetCategoryState(v)
			if addon.Display then addon.Display:UpdateDisplay() end
		end)

		prevBottom = ef
		table.insert(expansionFrames, ef)

		end -- if currencies
	end

	C_Timer.After(0.1, RecalcHeight)
end

function Config:Show()
	if not configFrame then self:Initialize() end
	configFrame:Show()
end

function Config:Hide()
	if configFrame then configFrame:Hide() end
end

function Config:Toggle()
	if configFrame and configFrame:IsShown() then
		self:Hide()
	else
		self:Show()
	end
end
