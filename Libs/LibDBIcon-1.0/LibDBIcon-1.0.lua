-----------------------------------------------------------------------
-- LibDBIcon-1.0
--
-- Allows addons to easily create a lightweight minimap icon as an alternative to heavier LDB displays.
--

local DBICON10 = "LibDBIcon-1.0"
local DBICON10_MINOR = 44
if not LibStub then error(DBICON10 .. " requires LibStub.") end
local ldb = LibStub("LibDataBroker-1.1", true)
if not ldb then error(DBICON10 .. " requires LibDataBroker-1.1.") end
local lib = LibStub:NewLibrary(DBICON10, DBICON10_MINOR)
if not lib then return end

lib.objects = lib.objects or {}
lib.callbackRegistered = lib.callbackRegistered or nil
lib.callbacks = lib.callbacks or LibStub("CallbackHandler-1.0"):New(lib)
lib.notCreated = lib.notCreated or {}
lib.radius = lib.radius or 5
local next, Minimap, CreateFrame = next, Minimap, CreateFrame
local DraggingControl

local function getAnchors(frame)
	local x, y = frame:GetCenter()
	if not x or not y then return "CENTER" end
	local hhalf = (x > UIParent:GetWidth()*2/3) and "RIGHT" or (x < UIParent:GetWidth()/3) and "LEFT" or ""
	local vhalf = (y > UIParent:GetHeight()/2) and "TOP" or "BOTTOM"
	return vhalf..hhalf, frame, (vhalf == "TOP" and "BOTTOM" or "TOP")..hhalf
end

local function onEnter(self)
	if self.isDragging then return end
	if self.dataObject.OnTooltipShow then
		GameTooltip:SetOwner(self, "ANCHOR_NONE")
		GameTooltip:SetPoint(getAnchors(self))
		self.dataObject.OnTooltipShow(GameTooltip)
		GameTooltip:Show()
	elseif self.dataObject.OnEnter then
		self.dataObject.OnEnter(self)
	end
end

local function onLeave(self)
	GameTooltip:Hide()
	if self.dataObject.OnLeave then
		self.dataObject.OnLeave(self)
	end
end

local onDragStart, updatePosition

do
	local minimapShapes = {
		["ROUND"] = {true, true, true, true},
		["SQUARE"] = {false, false, false, false},
		["CORNER-TOPLEFT"] = {false, false, false, true},
		["CORNER-TOPRIGHT"] = {false, false, true, false},
		["CORNER-BOTTOMLEFT"] = {false, true, false, false},
		["CORNER-BOTTOMRIGHT"] = {true, false, false, false},
		["SIDE-LEFT"] = {false, true, false, true},
		["SIDE-RIGHT"] = {true, false, true, false},
		["SIDE-TOP"] = {false, false, true, true},
		["SIDE-BOTTOM"] = {true, true, false, false},
		["TRICORNER-TOPLEFT"] = {false, true, true, true},
		["TRICORNER-TOPRIGHT"] = {true, false, true, true},
		["TRICORNER-BOTTOMLEFT"] = {true, true, false, true},
		["TRICORNER-BOTTOMRIGHT"] = {true, true, true, false},
	}

	local rad, cos, sin, sqrt, max, min = math.rad, math.cos, math.sin, math.sqrt, math.max, math.min
	function updatePosition(button, position)
		local angle = rad(position or 225)
		local x, y, q = cos(angle), sin(angle), 1
		if x < 0 then q = q + 1 end
		if y > 0 then q = q + 2 end
		local minimapShape = GetMinimapShape and GetMinimapShape() or "ROUND"
		local quadTable = minimapShapes[minimapShape]
		local w = (Minimap:GetWidth() / 2) + lib.radius
		local h = (Minimap:GetHeight() / 2) + lib.radius
		if quadTable[q] then
			x, y = x*w, y*h
		else
			local diagRadiusW = sqrt(2*(w)^2)-10
			local diagRadiusH = sqrt(2*(h)^2)-10
			x = max(-w, min(x*diagRadiusW, w))
			y = max(-h, min(y*diagRadiusH, h))
		end
		button:SetPoint("CENTER", Minimap, "CENTER", x, y)
	end

	function onDragStart(self)
		self:LockHighlight()
		self.isDragging = true
		DraggingControl = self
		lib.callbacks:Fire("IconDragStart", self, self.dataObject.name)
	end
end

local function onDragStop(self)
	self:UnlockHighlight()
	DraggingControl = nil
	self.isDragging = nil
	lib.callbacks:Fire("IconDragStop", self, self.dataObject.name)
end

local function onUpdateFunc(self)
	if DraggingControl == self then
		local mx, my = Minimap:GetCenter()
		local px, py = GetCursorPosition()
		local scale = Minimap:GetEffectiveScale()
		px, py = px / scale, py / scale
		local pos = 225
		if self.db then
			pos = deg(atan2(py - my, px - mx)) % 360
			self.db.minimapPos = pos
		else
			pos = deg(atan2(py - my, px - mx)) % 360
			self.minimapPos = pos
		end
		updatePosition(self, pos)
	end
end

local function onClick(self, b)
	if self.dataObject.OnClick then
		self.dataObject.OnClick(self, b)
	end
end

local function onMouseDown(self)
	self.icon:SetTexCoord(0, 1, 0, 1)
end

local function onMouseUp(self)
	self.icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
end

local defaultCoords = {0, 1, 0, 1}
local function updateTexture(self, iconpath, texCoords)
	self.icon:SetTexture(iconpath or [[Interface\Icons\INV_Misc_QuestionMark]])
	self.icon:SetTexCoord(unpack(texCoords or self.dataObject.iconCoords or defaultCoords))
end

do
	local deg, atan2 = deg or math.deg, atan2 or math.atan2
	local function createButton(name, object, db)
		local button = CreateFrame("Button", "LibDBIcon10_"..name, Minimap)
		button:SetFrameStrata("MEDIUM")
		button:SetFrameLevel(8)
		button:SetSize(31, 31)
		button:RegisterForClicks("anyUp")
		button:RegisterForDrag("LeftButton")
		button:SetHighlightTexture(136477)
		button:GetHighlightTexture():SetSize(18, 18)
		button:GetHighlightTexture():ClearAllPoints()
		button:GetHighlightTexture():SetPoint("TOPLEFT", 6, -7)
		local overlay = button:CreateTexture(nil, "OVERLAY")
		overlay:SetSize(50, 50)
		overlay:SetTexture(136430)
		overlay:SetPoint("TOPLEFT")
		local background = button:CreateTexture(nil, "BACKGROUND")
		background:SetSize(20, 20)
		background:SetTexture(136467)
		background:SetPoint("TOPLEFT", 7, -6)
		local icon = button:CreateTexture(nil, "ARTWORK")
		icon:SetSize(17, 17)
		icon:SetTexture(object.icon)
		icon:SetPoint("TOPLEFT", 7, -6)
		button.icon = icon
		button.dataObject = object
		button.db = db

		button:SetScript("OnEnter", onEnter)
		button:SetScript("OnLeave", onLeave)
		button:SetScript("OnClick", onClick)
		button:SetScript("OnDragStart", onDragStart)
		button:SetScript("OnDragStop", onDragStop)
		button:SetScript("OnMouseDown", onMouseDown)
		button:SetScript("OnMouseUp", onMouseUp)
		button:SetScript("OnUpdate", onUpdateFunc)

		lib.objects[name] = button

		if db and db.hide then
			button:Hide()
		else
			button:Show()
		end
		updatePosition(button, db and db.minimapPos or object.minimapPos or 225)
		return button
	end
	function lib:Register(name, object, db)
		if not object.icon then error("Can't register LDB objects without icons set!") end
		if lib.objects[name] or lib.notCreated[name] then error(DBICON10.. ": Object '"..name.."' is already registered.") end
		if not db or not db.hide then
			local button = createButton(name, object, db)
			updateTexture(button, object.icon, object.iconCoords)
		else
			lib.notCreated[name] = {obj = object, db = db}
		end
		lib.callbacks:Fire("IconRegistered", name, object, db)
	end
end

function lib:Lock(name)
	local button = lib.objects[name]
	if button then
		button:SetScript("OnDragStart", nil)
		button:SetScript("OnDragStop", nil)
	end
end

function lib:Unlock(name)
	local button = lib.objects[name]
	if button then
		button:SetScript("OnDragStart", onDragStart)
		button:SetScript("OnDragStop", onDragStop)
	end
end

function lib:Hide(name)
	local button = lib.objects[name]
	if button then
		button:Hide()
	end
end

function lib:Show(name)
	local button = lib.objects[name]
	if button then
		button:Show()
		updatePosition(button, button.db and button.db.minimapPos or button.dataObject.minimapPos or 225)
	end
end

function lib:IsRegistered(name)
	return lib.objects[name] or lib.notCreated[name]
end

function lib:Refresh(name, db)
	local button = lib.objects[name]
	if button then
		updateTexture(button, button.dataObject.icon, button.dataObject.iconCoords)
		updatePosition(button, db and db.minimapPos or button.dataObject.minimapPos or 225)
	end
end

function lib:GetMinimapButton(name)
	return lib.objects[name]
end

do
	local function OnMinimapEnter(self)
		if self.IsActive and self:IsActive() then
			for _, button in next, lib.objects do
				button:Show()
			end
		end
	end
	local function OnMinimapLeave(self)
		for _, button in next, lib.objects do
			if button.db and button.db.hide then
				button:Hide()
			end
		end
	end
	Minimap:HookScript("OnEnter", OnMinimapEnter)
	Minimap:HookScript("OnLeave", OnMinimapLeave)
end
