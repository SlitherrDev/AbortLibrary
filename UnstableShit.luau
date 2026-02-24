local AbortLibrary = {}
if _G.AbortLibraryLoaded then return end
_G.AbortLibraryLoaded = true


--[[ SERVICES ]]
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local TextService = game:GetService("TextService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")


--[[ REGISTERS ]]
local request, getasset = request or http_request, getsynasset or getcustomasset
local exceptionlist, HoverRegistry = {}, {}
local GUILoader = {}


--[[ VARIABLES ]]
local settingspage, settingslist, categories, exitbutton, backgroundblur, settingstitle, activemenu, targetDotsButton, targetOption, oldDotsBtn
local oldcategory, oldtitle, oldsettings, oldcorner1, oldcorner2, oldiconframe
local firstCategoryInit = true
local bookmarkpages = {}

local CurrentCamera = workspace.CurrentCamera

local isMinimized, isAnimating = false, false
local savedSize, savedPos

LoadingSuccess, FirstInit = false, true
local OriginalLabelText = {}
local isFreezing = false


--[[ CONFIG ]]
local Config = {
    ProfileName = "Default",
    Version = "1.0.1",
    Data = {
        Toggles = {},
        Dropdowns = {},
        Sliders = {},
        ColorPickers = {},
		
        Keybinds = {["GUI"] = Enum.KeyCode.RightAlt},
		Misc = {InterfaceColor = Color3.fromRGB(147, 129, 255)}
    }
}

local function ProfilePath(profile)
	return string.format("%s/%s.json", "abort/profiles", profile or Config.ProfileName)
end

local function serialize(value)
	if typeof(value) == "Color3" then
		return {__type = "Color3", r = value.R, g = value.G, b = value.B}
	elseif typeof(value) == "EnumItem" then
		return {__type = "Enum", enum = tostring(value)}
	elseif type(value) == "table" then
		local new = {}
		for k,v in pairs(value) do
			new[k] = serialize(v)
		end
		return new
	end
	return value
end

local function deserialize(value)
	if type(value) == "table" and value.__type == "Color3" then
		return Color3.new(value.r, value.g, value.b)
	elseif type(value) == "table" and value.__type == "Enum" then
		local enumName = value.enum:match("Enum%.(.+)")
		local enumType, enumValue = enumName:match("(.+)%.(.+)")
		return Enum[enumType][enumValue]
	elseif type(value) == "table" then
		local new = {}
		for k,v in pairs(value) do
			new[k] = deserialize(v)
		end
		return new
	end
	return value
end

function Config:Load(profile)
	local path = ProfilePath(profile)
	if not isfile(path) then
		self:Save()
		return
	end

	local data = HttpService:JSONDecode(readfile(path))
	data = deserialize(data)

	for category, values in pairs(self.Data) do
		data[category] = data[category] or {}
		for k,v in pairs(values) do
			if data[category][k] == nil then
				data[category][k] = v
			end
		end
	end

	self.Data = data
	--print("[Config] Loaded successfully profile:", profile)
end

function Config:Save()
	local path = ProfilePath()
	local success, result = pcall(function()
		writefile(path, HttpService:JSONEncode(serialize(self.Data)))
	end)
	if success then
		--print("[Config] Saved profile:", Config.ProfileName)
	else
		warn("[Config] Failed to save!", result)
	end
end

function Config:Get(category, key, default)
	if self.Data[category] and self.Data[category][key] ~= nil then
		return self.Data[category][key]
	end
	return default
end

function Config:Set(category, key, value)
	self.Data[category] = self.Data[category] or {}
	self.Data[category][key] = value
	self:Save()
end

function Config:Clear(category, key)
	if self.Data[category] then
		self.Data[category][key] = nil
		self:Save()
	end
end

function Config:ResetProfile()
	self.Data = {
		Toggles = {},
		Dropdowns = {},
		Sliders = {},
		ColorPickers = {},
		Keybinds = {["GUI"] = Enum.KeyCode.RightAlt},
		Misc = {InterfaceColor = Color3.fromRGB(147, 129, 255)},
	}
	self:Save()
end


--[[ LAYOUT ]]
local Layout = {
	ToggleDefaults = {
		CircleSize = UDim2.new(0.406, 0,0.867, 0),
		CircleInactivePos = UDim2.new(0.031, 0,0.5, 0),
		CircleActivePos = UDim2.new(0.563, 0,0.5, 0),
		Settings = {
			FrameSize = UDim2.new(0.16, 0,0.487, 0),
		},
		Module = {
			FrameSize = UDim2.new(0.063, 0,0.278, 0),
		}
	},

	tweenInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	Bookmarks = {{"home", "Home", "left", 0}, {"data", "Config", "left", 1}, {"add-friend", "Friends but very longer text", "left", 2}, {"search", "Type here...", "right", 1}, {"settings", "Options", "right", 0}},
	LayoutOrder = 0,
	TextSize = 14,
	MaxTextWidth = 0.6,
	uiScale = 1,
	ScrollUpdates = {},

	GuiRoot = nil,
	GuiBackground = nil,
	GuiAnimator = nil,
}

local Colors = {
	Background = Color3.fromRGB(14, 12, 14),
	BackgroundDark = Color3.fromRGB(16, 14, 16),
	Border = Color3.fromRGB(14, 12, 14),
	TextPrimary = Color3.fromRGB(255, 255, 255),
	TextSecondary = Color3.fromRGB(173, 173, 173),
	TextTertiary = Color3.fromRGB(96, 96, 96),
	ButtonDefault = Color3.fromRGB(173, 173, 173),
	ButtonHover = Color3.fromRGB(255, 255, 255)
}


--[[ CONNECTION MANAGER ]]
local ConnectionManager = {}
ConnectionManager.Connections = {}

function ConnectionManager:Add(instance, key, connection, allowMultiple)
	if not instance or not connection then return end
	self.Connections[instance] = self.Connections[instance] or {}
	self.Connections[instance][key] = self.Connections[instance][key] or {}

	if not allowMultiple then
		for _, conn in ipairs(self.Connections[instance][key]) do
			conn:Disconnect()
		end
		self.Connections[instance][key] = {}
	end

	table.insert(self.Connections[instance][key], connection)
	return connection
end

function ConnectionManager:DisconnectAll()
	for _, instanceTable in pairs(self.Connections) do
		for _, keyTable in pairs(instanceTable) do
			for _, connection in ipairs(keyTable) do
				connection:Disconnect()
			end
		end
	end
	self.Connections = {}
end


--[[ ANIMATORS ]]
local TweensHandler = {}
local function CreateTween(obj, info, props)
	if not obj or not obj.Parent then return end
	if not TweensHandler[obj] then
		TweensHandler[obj] = {}
	end

	for propertyName, _ in pairs(props) do
		local existingTween = TweensHandler[obj] and TweensHandler[obj][propertyName]
		if typeof(existingTween) == "Instance" then
			if existingTween.PlaybackState == Enum.PlaybackState.Playing then
				existingTween:Cancel()
			end
			existingTween:Destroy()
		end
		TweensHandler[obj][propertyName] = nil
	end

	local tween = TweenService:Create(obj, info, props)
	for propertyName, _ in pairs(props) do
		TweensHandler[obj][propertyName] = tween
	end

	tween:Play()
	tween.Completed:Once(function()
		for propertyName, _ in pairs(props) do
			if TweensHandler[obj] then
				TweensHandler[obj][propertyName] = nil
			end
		end

		tween:Destroy()
	end)

	return tween
end

local function HoverException(button: GuiButton, action: "add" | "remove")
	if action == "remove" then
		local index = table.find(exceptionlist, button)
		if index then
			table.remove(exceptionlist, index)
		end
	elseif action == "add" then
		if not table.find(exceptionlist, button) then
			table.insert(exceptionlist, button)
		end
	end
end

local function ApplyHover(button, defaultColor, hoverColor, target: nil, custom: {}) 
	local function resolveColor(value)
		if typeof(value) == "function" then
			return value()
		end
		return value
	end

	local t = target and target or button
	local currentTween = nil
	custom = custom or false

	ConnectionManager:Add(button, "enter", button.MouseEnter:Connect(function()
		if custom and custom.Hover then
			currentTween = CreateTween(t, Layout.tweenInfo, resolveColor(custom.Hover))
		elseif t:IsA("ImageLabel") or t:IsA("ImageButton") then
			currentTween = CreateTween(t, Layout.tweenInfo, {ImageColor3 = resolveColor(hoverColor)})
		else
			currentTween = CreateTween(t, Layout.tweenInfo, {TextColor3 = resolveColor(hoverColor())})
		end
	end))

	ConnectionManager:Add(button, "leave", button.MouseLeave:Connect(function()
		if table.find(exceptionlist, t) then return end
		if custom and custom.Default then
			currentTween = CreateTween(t, Layout.tweenInfo, resolveColor(custom.Default))
		elseif t:IsA("ImageLabel") or t:IsA("ImageButton") then
			currentTween = CreateTween(t, Layout.tweenInfo, {ImageColor3 = resolveColor(defaultColor)})
		else
			currentTween = CreateTween(t, Layout.tweenInfo, {TextColor3 = resolveColor(defaultColor)})
		end
	end))
end

local ProfileData = Config.Data
local ThemeRegistry = {}

function AbortLibrary.RegisterThemeElement(object, property, condition)
	if not object or not property then return end
	ThemeRegistry[object] = ThemeRegistry[object] or {}
	table.insert(ThemeRegistry[object], {Property = property, Condition = condition or function() return true end })
end

function AbortLibrary.RefreshTheme()
	for object, entries in pairs(ThemeRegistry) do
		if object and object.Parent then
			for _, data in ipairs(entries) do
				local conditionResult = true
				if typeof(data.Condition) == "function" then
					conditionResult = data.Condition()
				end

				pcall(function()
					if typeof(conditionResult) == "Color3" then
						CreateTween(object, Layout.tweenInfo, {[data.Property] = conditionResult})

					elseif typeof(conditionResult) == "table" then
						local condition, expected, color = conditionResult[1], conditionResult[2], conditionResult[3]
						if condition ~= expected then
							CreateTween(object, Layout.tweenInfo, {[data.Property] = color})
						end

					elseif conditionResult == true and data.Property and ProfileData.Misc.InterfaceColor then
						CreateTween(object, Layout.tweenInfo, {[data.Property] = ProfileData.Misc.InterfaceColor})
					end
				end)
			end
		else
			ThemeRegistry[object] = nil
		end
	end
end


--[[ ASSETS LOADER ]]
local function LoadAssets()
	local assets = { "abort-logo.png", "add-friend.png", "data.png", "dots.png", "down-arrow.png", "home.png", "keybinds.png", "left-arrow.png", "loading-background.png", "resizer.png", "search.png", "settings.png" }

	for _, asset in ipairs(assets) do
		local path = "abort/assets/" .. asset
		if not isfile(path) then
			local success, res = pcall(function()
				local response = request({
					Url = "https://raw.githubusercontent.com/SlitherrDev/AbortLibrary/main/assets/" .. asset,
					Method = "GET"
				})
				if response.Success then
					writefile(path, response.Body)
				end
			end)

			if not success then
				warn("Failed to load asset:", asset)
			end
		end
	end
	LoadingSuccess = true
end

if game:IsLoaded() then
	for _, folder in ipairs({ "abort", "abort/profiles", "abort/assets" }) do
		if not isfolder(folder) then makefolder(folder) end
	end
	LoadAssets()
else
	print("Game is not supported!")
	return
end


--[[ REUSABLES ]]
local function CreateUICorner(parent, scale, offset)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(scale, offset)
	corner.Parent = parent
	return corner
end

local function CreateUIStroke(parent, thickness, transparency, color, applyToAllSides, borderstrokeposition)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = thickness or 1
	stroke.Transparency = transparency or 0
	stroke.Color = color or Color3.fromRGB(0, 0, 0)
	stroke.ApplyStrokeMode = applyToAllSides or Enum.ApplyStrokeMode.Border
	stroke.BorderStrokePosition = borderstrokeposition or Enum.BorderStrokePosition.Outer
	stroke.Parent = parent
	return stroke
end

local function CreateAnimatedList(parent: Instance, axis: string?, padding: UDim?, alignment, autolayout: boolean)
	autolayout = autolayout or false
	axis = (axis == "X" or axis == "x") and "X" or "Y"
	padding = padding or UDim.new(0, 6)
	alignment = alignment or { horizontal = "center", vertical = "top" }
	local debounceTime = 0.05
	local lastUpdate = 0
	local updating = false

	local function computePadding(base: number)
		return (base * padding.Scale) + padding.Offset
	end

	local function updateLayoutOrder()
		if autolayout then
			local children = {}
			for _, c in ipairs(parent:GetChildren()) do
				if c:IsA("GuiObject") and c.Visible then
					table.insert(children, c)
				end
			end
			for i, c in ipairs(children) do
				c.LayoutOrder = i
			end
		end
	end

	local function update()
		if updating then return end
		updating = true
		
		if not parent or not parent.Parent then
			updating = false
			return
		end
		
		updateLayoutOrder()
		local children = {}
		for _, c in ipairs(parent:GetChildren()) do
			if c:IsA("GuiObject") and c.Visible then
				table.insert(children, c)
			end
		end
		table.sort(children, function(a, b)
			return (a.LayoutOrder or 0) < (b.LayoutOrder or 0)
		end)

		local size = parent.AbsoluteSize
		local pad = (axis == "Y") and computePadding(size.Y) or computePadding(size.X)
		local totalSize = pad
		for _, c in ipairs(children) do
			local len = (axis == "Y") and c.AbsoluteSize.Y or c.AbsoluteSize.X
			totalSize += len + pad
		end
		
		if parent:IsA("ScrollingFrame") then
			parent.CanvasSize = UDim2.new(0, 0, 0, 0)
			for _,item in pairs(parent:GetChildren()) do
				if item:IsA("GuiObject") then
					item.Size = UDim2.new(0, item.AbsoluteSize.X, 0, item.AbsoluteSize.Y)
				end
			end
			
			parent.CanvasSize = UDim2.new(0, 0, 0, totalSize)
		end

		local startOffset
		local dir = 1
		if axis == "Y" then
			if alignment.vertical == "bottom" then
				dir = -1
				startOffset = size.Y / Layout.uiScale - pad
			elseif alignment.vertical == "center" then
				startOffset = ((size.Y / Layout.uiScale) - totalSize) / 2 + pad
			else
				startOffset = pad
			end
		else
			if alignment.horizontal == "right" then
				dir = -1
				startOffset = size.X / Layout.uiScale - pad
			elseif alignment.horizontal == "center" then
				startOffset = ((size.X / Layout.uiScale) - totalSize) / 2 + pad
			else
				startOffset = pad
			end
		end

		local offset = 0
		for _, c in ipairs(children) do
			local w, h = c.AbsoluteSize.X / Layout.uiScale, c.AbsoluteSize.Y / Layout.uiScale
			local posX, posY = 0, 0
			if axis == "Y" then
				if alignment.horizontal == "center" then
					posX = ((size.X / Layout.uiScale) - w) / 2
				elseif alignment.horizontal == "right" then
					posX = (size.X / Layout.uiScale) - w
				end
				if dir == 1 then
					posY = startOffset + offset
					offset += h + pad
				else
					posY = startOffset - h - offset
					offset += h + pad
				end
			else
				if alignment.vertical == "center" then
					posY = ((size.Y / Layout.uiScale) - h) / 2
				elseif alignment.vertical == "bottom" then
					posY = (size.Y / Layout.uiScale) - h
				end
				if dir == 1 then
					posX = startOffset + offset
					offset += w + pad
				else
					posX = startOffset - w - offset
					offset += w + pad
				end
			end
			local targetPos = UDim2.new(0, posX, 0, posY)
			CreateTween(c, Layout.tweenInfo, { Position = targetPos })
		end

		updating = false
	end

	local function connectChildSignals(c)
		if not c:IsA("GuiObject") then return end
		ConnectionManager:Add(c, "LayoutOrder", c:GetPropertyChangedSignal("LayoutOrder"):Connect(update)) 
		ConnectionManager:Add(c, "Visible", c:GetPropertyChangedSignal("Visible"):Connect(update)) 
		ConnectionManager:Add(c, "AbsoluteSize", c:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			lastUpdate = os.clock()
		end))
	end

	ConnectionManager:Add(parent, "ChildAdded", parent.ChildAdded:Connect(function(c)
		connectChildSignals(c)
		task.defer(update)
	end))

	ConnectionManager:Add(parent, "ChildRemoved", parent.ChildRemoved:Connect(function()
		update()
	end)) 

	ConnectionManager:Add(parent, "AbsoluteSize", parent:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		task.defer(function()
			if not updating then update() end
		end)
	end))

	for _, c in ipairs(parent:GetChildren()) do
		connectChildSignals(c)
	end

	ConnectionManager:Add(RunService, "Heartbeat", RunService.Heartbeat:Connect(function()
		if os.clock() - lastUpdate < debounceTime then
			update()
		end
	end), true)

	update()
	return update
end

local function MakeReorderable(dotsButton: GuiButton, optionButton: GuiObject, updateList)
	local parent = optionButton.Parent
	if not parent then return end

	local isDragging = false
	local dragStartY = 0
	local dragOffsetY = 0
	local dragThreshold = 5
	local hasMoved = false
	local originalZIndex = optionButton.ZIndex
	local dragTween = nil
	local holdStart = 0
	local holdTime = 0.125

	local function GetSortedChildren()
		local children = {}
		for _, c in ipairs(parent:GetChildren()) do
			if c:IsA("GuiObject") and c.Visible then
				table.insert(children, c)
			end
		end
		table.sort(children, function(a, b)
			return (a.LayoutOrder or 0) < (b.LayoutOrder or 0)
		end)
		return children
	end

	ConnectionManager:Add(dotsButton, "InputBegan", dotsButton.InputBegan:Connect(function(input) 
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
		holdStart = tick()

		task.spawn(function()
			while UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
				if tick() - holdStart >= holdTime and not isDragging then
					isDragging = true
					hasMoved = false
					dragStartY = input.Position.Y
					dragOffsetY = input.Position.Y - optionButton.AbsolutePosition.Y
					CreateTween(optionButton, TweenInfo.new(0.1), { BackgroundTransparency = 0.5 })
					optionButton.ZIndex = originalZIndex + 10
					break
				end
				task.wait(0.05)
			end
		end)
	end))

	ConnectionManager:Add(UserInputService, "Reorderable_InputChanged", UserInputService.InputChanged:Connect(function(input)
		if not isDragging or input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
		local deltaY = input.Position.Y - dragStartY
		if not hasMoved and math.abs(deltaY) > dragThreshold * Layout.uiScale then
			hasMoved = true
		end
		if not hasMoved then return end

		local uiScale = Layout.uiScale
		local parentAbsY = parent.AbsolutePosition.Y / uiScale
		local parentHeight = parent.AbsoluteSize.Y / uiScale
		local optHeight = optionButton.AbsoluteSize.Y / uiScale
		local mouseY = input.Position.Y / uiScale
		local clampedY = math.clamp(mouseY - (dragOffsetY / uiScale), parentAbsY, parentAbsY + parentHeight - optHeight)
		if dragTween then dragTween:Cancel() end
		dragTween = CreateTween(optionButton, TweenInfo.new(0.05), {
			Position = UDim2.new(optionButton.Position.X.Scale, optionButton.Position.X.Offset, 0, clampedY - parentAbsY)
		})

		local list = GetSortedChildren()
		local pad = 6 / uiScale
		local itemHeight = optHeight + pad
		local centerY = (clampedY - parentAbsY) + optHeight / 2
		local targetIdx = math.clamp(math.floor(centerY / itemHeight + 0.5), 1, #list)
		local myIdx = table.find(list, optionButton)
		if not myIdx or targetIdx == myIdx then return end
		table.remove(list, myIdx)
		table.insert(list, targetIdx, optionButton)
		for i, obj in ipairs(list) do
			obj.LayoutOrder = i
		end
	end), true)

	ConnectionManager:Add(UserInputService, "Reorderable_InputEnded", UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			if isDragging then
				isDragging = false
				CreateTween(optionButton, TweenInfo.new(0.2), { BackgroundTransparency = 0 })
				optionButton.ZIndex = originalZIndex
				if hasMoved then
					updateList()
				end
			end
		end
	end), true)
end

local function CreateUIPadding(parent, padding)
	local paddingInstance = Instance.new("UIPadding")
	paddingInstance.PaddingLeft = padding.PaddingLeft or UDim.new(0, 0)
	paddingInstance.PaddingRight = padding.PaddingRight or UDim.new(0, 0)
	paddingInstance.PaddingTop = padding.PaddingTop or UDim.new(0, 0)
	paddingInstance.PaddingBottom = padding.PaddingBottom or UDim.new(0, 0)

	paddingInstance.Parent = parent
	return paddingInstance
end

local function CreateButton(parent, text, size, position, callback, buttonProps)
	local button = Instance.new("TextButton")
	button.Size = size or UDim2.new(0, 0, 0, 0)
	button.Position = position or UDim2.new(0, 0, 0, 0)
	button.Text = text
	button.BackgroundColor3 = (buttonProps and buttonProps.BackgroundColor) or Color3.fromRGB(255, 255, 255)
	button.AutomaticSize = buttonProps.AutomaticSize or Enum.AutomaticSize.None
	button.TextColor3 = (buttonProps and buttonProps.TextColor) or Colors.ButtonDefault
	button.TextTransparency = (buttonProps and buttonProps.TextTransparency) or 0
	button.Font = (buttonProps and buttonProps.Font) or Enum.Font.GothamBold
	button.TextSize = (buttonProps and buttonProps.TextSize) or Layout.TextSize
	button.LayoutOrder = (buttonProps and buttonProps.LayoutOrder) or 0
	button.BackgroundTransparency = (buttonProps and buttonProps.BackgroundTransparency) or 0
	button.ZIndex = (buttonProps and buttonProps.ZIndex) or 0
	button.TextXAlignment = (buttonProps and buttonProps.TextXAlignment) or Enum.TextXAlignment.Center
	button.TextStrokeTransparency = (buttonProps and buttonProps.TextStrokeTransparency) or 1
	if buttonProps.Visible ~= nil then button.Visible = buttonProps.Visible else button.Visible = true end
	button.TextStrokeColor3 = (buttonProps and buttonProps.TextStrokeColor) or Color3.fromRGB(0, 0, 0)
	button.BorderSizePixel = (buttonProps and buttonProps.BorderSizePixel) or 0
	button.BorderColor3 = (buttonProps and buttonProps.BorderColor) or Color3.fromRGB(0, 0, 0)
	button.TextScaled = (buttonProps and buttonProps.TextScaled) or false
	button.AnchorPoint = (buttonProps and buttonProps.AnchorPoint) or Vector2.new(0, 0)
	button.AutoButtonColor = false

	if not buttonProps.SkipHover then
		ApplyHover(button, function() return Colors.TextSecondary end, function() return Colors.TextPrimary end, buttonProps.HoverTarget or nil, buttonProps.CustomHover or false)
	end

	ConnectionManager:Add(button, "Callback", button.MouseButton1Click:Connect(callback)) 
	button.Parent = parent
	return button
end

local function CreateFrame(parent, size, position, clips, frameProps)
	local frame = Instance.new("Frame")
	frameProps = frameProps or {}

	frame.Size = size or UDim2.new(0, 0, 0, 0)
	frame.Position = position or UDim2.new(0, 0, 0, 0)
	frame.BackgroundColor3 = frameProps.BackgroundColor or Color3.fromRGB(255, 255, 255)
	frame.BackgroundTransparency = frameProps.BackgroundTransparency or 0
	frame.AnchorPoint = frameProps.AnchorPoint or Vector2.new(0, 0)
	frame.ZIndex = frameProps.ZIndex or 0
	if frameProps.Visible ~= nil then frame.Visible = frameProps.Visible else frame.Visible = true end
	frame.Active = frameProps.Active or false
	frame.ClipsDescendants = clips or false
	frame.Name = frameProps.Name or "Frame"
	frame.BorderSizePixel = 0
	frame.Parent = parent

	return frame
end

local function CreateUIAspectRatio(parent, ratio)
	ratio = ratio or (parent.AbsoluteSize.X / parent.AbsoluteSize.Y)
	if ratio > 0 then
		local constraint = Instance.new("UIAspectRatioConstraint")
		constraint.AspectRatio = ratio
		constraint.Parent = parent
	end
end

local function CreateImageLabel(parent, size, position, imageUrl, imageProps)
	imageProps = imageProps or {}
	local imgLabel = Instance.new("ImageLabel")
	imgLabel.Size = size or UDim2.new(0, 0, 0, 0)
	imgLabel.Position = position or UDim2.new(0, 0, 0, 0)
	imgLabel.Image = imageUrl
	imgLabel.ImageTransparency = imageProps.ImageTransparency or 0
	imgLabel.BackgroundTransparency = imageProps.BackgroundTransparency or 1
	imgLabel.ImageColor3 = imageProps.ImageColor3 or Colors.TextPrimary
	imgLabel.AnchorPoint = imageProps.AnchorPoint or Vector2.new(0, 0)
	if imageProps.ZIndex then imgLabel.ZIndex = imageProps.ZIndex end
	imgLabel.Parent = parent
	return imgLabel
end

local function TextBoundsHiddenCalc(label, text)
	local l = label:Clone()
	l.Visible = false
	l.Parent = label.Parent
	l.Text = text
	task.wait()
	local b = l.TextBounds.X / Layout.uiScale
	l:Destroy()
	return b
end

local function TextTruncate(label, untruncate, suffix, dynamicrefresh)
	dynamicrefresh = dynamicrefresh or false
	untruncate = untruncate or false
	suffix = suffix or "…"

	if untruncate then
		if OriginalLabelText[label] then
			label.Text = OriginalLabelText[label][1]
			OriginalLabelText[label] = nil
		end
		return
	end

	if dynamicrefresh then label.TextTransparency = 1 end
	if not OriginalLabelText[label] or label.Text ~= OriginalLabelText[label][1] then
		OriginalLabelText[label] = {label.Text, TextBoundsHiddenCalc(label, label.Text)}
	end

	local function Apply()
		local text = OriginalLabelText[label][1]
		local maxWidth = label.AbsoluteSize.X / Layout.uiScale
		local low, high = 1, #text
		local bestFit = text
		local fullWidth = TextBoundsHiddenCalc(label, text)

		if fullWidth <= maxWidth then
			label.Text = text
			return
		end

		while low <= high do
			local mid = math.floor((low + high) / 2)
			local testText = string.sub(text, 1, mid) .. suffix
			local testWidth = TextBoundsHiddenCalc(label, testText)

			if testWidth > maxWidth then
				high = mid - 1
			else
				bestFit = testText
				low = mid + 1
			end
		end

		label.Text = bestFit
	end

	ConnectionManager:Add(label, "Size",label:GetPropertyChangedSignal("AbsoluteSize"):Connect(Apply))
	ConnectionManager:Add(label, "Text",label:GetPropertyChangedSignal("Text"):Connect(Apply))

	Apply()
	if dynamicrefresh then
		task.defer(function()
			label.TextTransparency = 0
		end)
	end
end

local function fullUnTruncWidth(label)
	return OriginalLabelText[label][2] or label.TextBounds.X / Layout.uiScale
end

local function updateBothDynamic(titleLabel, titleProps, descLabel, descProps, parent)
	local totalWidth = parent.AbsoluteSize.X / Layout.uiScale
	if totalWidth <= 0 then return end

	local titleMaxWidth = totalWidth * titleProps.MaxScale
	local descMaxWidth  = totalWidth * descProps.MaxScale

	local usedTitleWidth = fullUnTruncWidth(titleLabel)
	local usedDescWidth  = fullUnTruncWidth(descLabel)

	local extraForTitle = math.max(0, descMaxWidth - usedDescWidth)
	local extraForDesc  = math.max(0, titleMaxWidth - usedTitleWidth)

	local finalTitleWidth = math.min(usedTitleWidth, titleMaxWidth + extraForTitle)
	local finalDescWidth  = math.min(usedDescWidth, descMaxWidth + extraForDesc)

	if titleLabel.Size.X.Offset ~= finalTitleWidth then
		CreateTween(titleLabel, Layout.tweenInfo, {Size = UDim2.new(0, finalTitleWidth, 1, 0)})
		CreateTween(descLabel, Layout.tweenInfo, {Position = UDim2.new(0.138, finalTitleWidth, 0.5, 0)})
	end

	if descLabel.Size.X.Offset ~= finalDescWidth then
		CreateTween(descLabel, Layout.tweenInfo, {Size = UDim2.new(0, finalDescWidth, 1, 0)})
	end
end

local function CreateTextLabel(parent, text, size, position, textProps)
	local label = Instance.new("TextLabel")
	label.Text = text
	label.Size = size or UDim2.new(0, 0, 0, 0)
	label.BackgroundColor3 = textProps.BackgroundColor or Colors.Background
	label.AutomaticSize = textProps.AutomaticSize or Enum.AutomaticSize.None
	label.Position = position or UDim2.new(0, 0, 0, 0)
	label.TextColor3 = textProps.TextColor or Colors.TextSecondary
	label.Font = textProps.Font or Enum.Font.GothamBold
	label.TextSize = textProps.TextSize or Layout.TextSize
	if textProps.Visible ~= nil then label.Visible = textProps.Visible else label.Visible = true end
	label.TextScaled = textProps.TextScaled or false
	label.TextWrapped = textProps.TextWrapped or false
	label.TextStrokeTransparency = textProps.TextStrokeTransparency or 0
	label.TextXAlignment = textProps.TextXAlignment or Enum.TextXAlignment.Center
	label.TextStrokeColor3 = textProps.TextStrokeColor or Color3.fromRGB(0, 0, 0)
	label.TextYAlignment = textProps.TextYAlignment or Enum.TextYAlignment.Center
	label.BackgroundTransparency = textProps.BackgroundTransparency or 1
	if textProps.AnchorPoint then label.AnchorPoint = textProps.AnchorPoint end
	if textProps.ZIndex then label.ZIndex = textProps.ZIndex end

	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = textProps.TextSize or 12
	constraint.Parent = label

	label.Parent = parent
	label.TextTruncate = textProps.TextTruncate or Enum.TextTruncate.None

	if textProps.DynamicTruncate then
		label.Visible = false
		TextTruncate(label)
		task.delay(0.15, function()
			label.Visible = true
		end)
	end

	if textProps.MaxScale then
		label.Size = UDim2.new(0, parent.AbsoluteSize.X * textProps.MaxScale, 1, 0)
		return label, textProps
	else
		return label
	end
end

local function updateLabelsWidth(parent, labelA, propA, labelB, propB)
	local self = {}

	function self:update()
		if parent.AbsoluteSize.X > 0 then
			updateBothDynamic(labelA, propA, labelB, propB, parent)
		end
	end

	self.connections = {
		ConnectionManager:Add(labelA, "TextChanged", labelA:GetPropertyChangedSignal("Text"):Connect(function()
			self:update()
		end)),

		ConnectionManager:Add(labelB, "TextChanged", labelB:GetPropertyChangedSignal("Text"):Connect(function()
			self:update()
		end))
	}

	self:update()
	return self
end

local function CreateImageButton(parent, size, position, imageUrl, callback, imageProps)
	imageProps = imageProps or {}
	local imgButton = Instance.new("ImageButton")
	imgButton.Size = size or UDim2.new(0, 0, 0, 0)
	imgButton.Position = position or UDim2.new(0, 0, 0, 0)
	imgButton.Image = imageUrl
	imgButton.BackgroundColor3 = imageProps.BackgroundColor or Color3.fromRGB(255, 255, 255)
	imgButton.BackgroundTransparency = imageProps.BackgroundTransparency or 1
	imgButton.ImageTransparency = imageProps.ImageTransparency or 0
	imgButton.ImageColor3 = imageProps.ImageColor3 or Colors.ButtonDefault
	imgButton.AnchorPoint = imageProps.AnchorPoint or Vector2.new(0, 0)
	if imageProps.ZIndex then imgButton.ZIndex = imageProps.ZIndex end
	imgButton.Parent = parent
	
	if not imageProps.SkipHover then
		ApplyHover(imageProps.CustomHoverButton or imgButton, function() return Colors.TextSecondary end, function() return Colors.TextPrimary end, imageProps.HoverTarget or nil, imageProps.CustomHover or false)
	end

	ConnectionManager:Add(imgButton, "Callback", imgButton.MouseButton1Click:Connect(callback)) 
	return imgButton
end

local function CreateScrollingFrame(parent, size, position, scrollProps)
	scrollProps = scrollProps or {}
	local scrollingFrame = Instance.new("ScrollingFrame")
	scrollingFrame.Size = size
	scrollingFrame.Position = position
	scrollingFrame.Name = scrollProps.Name or "ScrollingFrame"
	scrollingFrame.AnchorPoint = scrollProps.AnchorPoint or Vector2.new(0, 0)
	scrollingFrame.BackgroundTransparency = scrollProps.BackgroundTransparency or 1
	scrollingFrame.ScrollingDirection = scrollProps.ScrollingDirection or Enum.ScrollingDirection.Y
	if scrollProps.Visible ~= nil then scrollingFrame.Visible = scrollProps.Visible else scrollingFrame.Visible = true end
	scrollingFrame.CanvasSize = scrollProps.CanvasSize or UDim2.new(0, 0, 0, 0)
	scrollingFrame.ScrollBarThickness = scrollProps.ScrollBarThickness or 3
	if scrollProps.ScrollBarImageColor3 then scrollingFrame.ScrollBarImageColor3 = scrollProps.ScrollBarImageColor3 end
	scrollingFrame.AutomaticCanvasSize = scrollProps.AutomaticCanvasSize or Enum.AutomaticSize.None
	scrollingFrame.BorderSizePixel = 0
	scrollingFrame.ZIndex = scrollProps.ZIndex or 1
	scrollingFrame.Parent = parent
	return scrollingFrame
end

local function CreateTextBox(parent, size, position, textBoxProps, textChangedCallback)
	textBoxProps = textBoxProps or {}
	local textBox = Instance.new("TextBox")
	textBox.Size = size or UDim2.new(0, 0, 0, 0)
	textBox.Position = position or UDim2.new(0, 0, 0, 0)
	textBox.BackgroundTransparency = textBoxProps.BackgroundTransparency or 1
	textBox.Text = textBoxProps.Text or ""
	textBox.Font = textBoxProps.Font or Enum.Font.GothamBold
	textBox.TextColor3 = textBoxProps.TextColor or Colors.ButtonDefault
	textBox.TextTransparency = textBoxProps.TextTransparency or 0
	textBox.PlaceholderText = textBoxProps.PlaceholderText or ""
	textBox.PlaceholderColor3 = textBoxProps.PlaceholderColor3 or Colors.TextSecondary
	textBox.TextWrapped = textBoxProps.TextWrapped or false
	textBox.TextScaled = textBoxProps.TextScaled or false
	textBox.ZIndex = textBoxProps.ZIndex or 1
	textBox.Interactable = textBoxProps.Interactable ~= false
	textBox.ClearTextOnFocus = textBoxProps.ClearTextOnFocus or false
	textBox.TextStrokeTransparency = textBoxProps.TextStrokeTransparency or 0
	textBox.TextStrokeColor3 = textBoxProps.TextStrokeColor or Color3.fromRGB(0, 0, 0)
	textBox.TextXAlignment = textBoxProps.TextXAlignment or Enum.TextXAlignment.Left
	textBox.TextYAlignment = textBoxProps.TextYAlignment or Enum.TextYAlignment.Center
	textBox.TextSize = textBoxProps.TextSize or Layout.TextSize
	textBox.TextWrapped = textBoxProps.TextWrapped or false
	if textBoxProps.AnchorPoint then textBox.AnchorPoint = textBoxProps.AnchorPoint end
	textBox.Parent = parent

	if textBoxProps.HoverTarget then
		ApplyHover(textBox, function() return Colors.TextSecondary end, function() return Colors.TextPrimary end, textBoxProps.HoverTarget or nil, textBoxProps.CustomHover or false)
	end

	if textBoxProps.MaxLetters then
		ConnectionManager:Add(textBox, "TextboxLetters", textBox:GetPropertyChangedSignal("Text"):Connect(function()
			if #textBox.Text > textBoxProps.MaxLetters then
				textBox.Text = textBox.Text:sub(1, textBoxProps.MaxLetters)
			end

			local min,max = textBoxProps.Min, textBoxProps.Max
			if min and max then
				local num = tonumber(textBox.Text) or 0
				local clamped = math.clamp(num, min, max)
				textBox.Text = tostring(clamped)
				textChangedCallback(clamped)
				return
			end
			textChangedCallback(textBox.Text)
		end))
	end

	return textBox
end

local function DragFrame(frame)
	local tweenInfo = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local dragging = false
	local dragInput, dragStart, startPos

	local function update(input)
		local delta = input.Position - dragStart
		local targetPos = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X / Layout.uiScale, startPos.Y.Scale, startPos.Y.Offset + delta.Y / Layout.uiScale)

		TweenService:Create(frame, tweenInfo, {Position = targetPos}):Play()
		TweenService:Create(Layout.GuiAnimator, tweenInfo, {Position = targetPos}):Play()
	end

	ConnectionManager:Add(frame, "drag_begin", frame.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			dragStart = input.Position
			startPos = frame.Position

			ConnectionManager:Add(input, "Changed", input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end))
		end
	end))

	ConnectionManager:Add(frame, "drag_changed", frame.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			dragInput = input
		end
	end))

	ConnectionManager:Add(frame, "drag_update", UserInputService.InputChanged:Connect(function(input)
		if input == dragInput and dragging then
			update(input)
		end
	end))
end

local function ToggleMinimize(mustminimize)
	if isAnimating then return end
	isAnimating = true

	if not isMinimized or mustminimize then
		Layout.GuiAnimator.Position = Layout.GuiBackground.Position
		Layout.GuiBackground.Visible = false
		Layout.GuiAnimator.Visible = true
		savedSize, savedPos = Layout.GuiAnimator.Size, Layout.GuiBackground.Position
		local targetSize = UDim2.new(savedSize.X.Scale, savedSize.X.Offset, 0, 0)
		local targetPos = UDim2.new(savedPos.X.Scale, savedPos.X.Offset, savedPos.Y.Scale, savedPos.Y.Offset + savedSize.Y.Offset / 2)

		local tween = CreateTween(Layout.GuiAnimator, Layout.tweenInfo, { Size = targetSize, Position = targetPos })
		ConnectionManager:Add(tween, "Completed", tween.Completed:Connect(function() 
			isMinimized = true
			isAnimating = false
		end))
	else
		local tween = CreateTween(Layout.GuiAnimator, Layout.tweenInfo, { Size = savedSize, Position = savedPos })
		ConnectionManager:Add(tween, "Completed", tween.Completed:Connect(function() 
			isMinimized = false
			isAnimating = false

			Layout.GuiBackground.Visible = true
			Layout.GuiAnimator.Visible = false
		end))
	end
end

local function StartKeybindListener(callback, excludedList)
	excludedList = excludedList or { Enum.KeyCode.Tab, Enum.KeyCode.Escape} -- Profiledata GUI KEYBIND
	local excluded = {}
	for _, keyEnum in ipairs(excludedList) do
		if typeof(keyEnum) == "EnumItem" then
			excluded[keyEnum] = true
		end
	end
	local connection
	connection = ConnectionManager:Add(UserInputService, "keybindlisten", UserInputService.InputBegan:Connect(function(input, processed) 
		if processed then return end
		if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
		if excluded[input.KeyCode] then return end
		callback(input.KeyCode)
		connection:Disconnect()
	end))
	return connection
end

local function adjustDescriptionForKeybind(desclabel, option, descProps, controller, targetWidth, minDistance)
	minDistance = minDistance or 5 / Layout.uiScale

	local optionLeft = option.AbsolutePosition.X
	local optionWidth = option.AbsoluteSize.X

	local keybindRightEdge = optionLeft + (optionWidth * 0.8)
	local keybindLeftEdge = keybindRightEdge - targetWidth

	local descRightEdge = desclabel.AbsolutePosition.X + desclabel.AbsoluteSize.X
	local currentGap = keybindLeftEdge - descRightEdge

	local neededReduction = minDistance - currentGap
	local scaleReduction = neededReduction / optionWidth

	local newMaxScale = descProps.MaxScale - scaleReduction
	newMaxScale = math.clamp(newMaxScale, 0.15, 0.35)

	if math.abs(descProps.MaxScale - newMaxScale) > 0.02 then
		descProps.MaxScale = newMaxScale
		controller:update()
	end
end


--[[ ROOT MODULES ]]
function AbortLibrary.DestroyRoot()
	if not Layout.GuiRoot then return end
	ConnectionManager:DisconnectAll()
	Layout.GuiRoot:Destroy()
	_G.AbortLibraryLoaded = false
	
	ThemeRegistry = {}
	HoverRegistry = {}
	exceptionlist = {}
end

function AbortLibrary.CreateRoot()
	if not LoadingSuccess then return end

	local root = CoreGui:FindFirstChild("AbortGui")
	if root then return end

	root = Instance.new("ScreenGui", CoreGui)
	root.Name = "AbortGui"
	root.DisplayOrder = math.huge
	root.IgnoreGuiInset = true
	root.ResetOnSpawn = false
	Layout.GuiRoot = root
	
	Config:Load("Default")
	ProfileData = Config.Data
	AbortLibrary.RefreshTheme()

	local uiScale = Instance.new("UIScale", root)
	local DESIGNWIDTH, DESIGNHEIGHT = 2560, 1440
	local function updateScale()
		local view = CurrentCamera.ViewportSize
		local scaleX = view.X / DESIGNWIDTH
		local scaleY = view.Y / DESIGNHEIGHT
		Layout.uiScale = math.min(scaleX, scaleY)
		uiScale.Scale = Layout.uiScale
	end

	updateScale()
	ConnectionManager:Add(CurrentCamera, "ViewportSize", CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)) 
end


--[[ GUI MODULES ]]
function GUILoader.LoadLoadingScreen()
	local background = CreateFrame(Layout.GuiRoot, UDim2.new(0.345, 0, 0.388, 0), UDim2.new(0.5, 0, 0.5, 0), true, {BackgroundColor = Color3.fromHex("161316"), AnchorPoint = Vector2.new(0.5, 0.5)})
	DragFrame(background)
	CreateUICorner(background, 0.022, 0)
	CreateUIStroke(background, 3, 0, Colors.Border, Enum.ApplyStrokeMode.Border, Enum.BorderStrokePosition.Inner)
	CreateUIAspectRatio(background, 1.674)
	Layout.GuiBackground = background

	local backgroundimage = CreateImageLabel(background, UDim2.new(1,0,1,0), UDim2.new(0,0,0,0), getasset("abort/assets/loading-background.png"), {BackgroundTransparency = 1, ZIndex = 50})
	CreateUICorner(backgroundimage, 0.022, 0)

	Layout.GuiAnimator = background:Clone()
	Layout.GuiAnimator.Visible = false
	Layout.GuiAnimator.Parent = Layout.GuiRoot

	local loadinglogo = CreateImageLabel(backgroundimage, UDim2.new(0.335,0,0.124,0), UDim2.new(0.5,0,0.35,0), getasset("abort/assets/abort-logo.png"), {ZIndex = 51, AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, ImageColor3 = Colors.TextPrimary})

	local loadingbar = CreateFrame(backgroundimage, UDim2.new(0.305,0,0.011,0), UDim2.new(0.5,0,0.5,0), false, {BackgroundColor = Colors.Background, BackgroundTransparency = 0, AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 51 })
	CreateUICorner(loadingbar, 1, 0)

	local barfill = CreateFrame(loadingbar, UDim2.new(0,0,1,0), UDim2.new(0,0,0,0), false, {BackgroundColor = ProfileData.Misc.InterfaceColor, BackgroundTransparency = 0, ZIndex = 52})
	CreateUICorner(barfill, 1, 0)

	local outputtext = CreateTextLabel(backgroundimage, "Output text", UDim2.new(0.305,0,0.067,0), UDim2.new(0.5,0,0.44,0), {TextSize=14, ZIndex=51, TextScaled = true, TextWrapped = true, TextColor = Colors.TextSecondary, AnchorPoint = Vector2.new(0.5, 0.5)})
	return background, loadinglogo, loadingbar, barfill, outputtext, backgroundimage
end

function GUILoader.LoadTopbar()
	local topbar = CreateFrame(Layout.GuiBackground, UDim2.new(1,0,0.089,0), UDim2.new(0,0,-0.089,0), false, {BackgroundColor = Colors.Background, ZIndex = 2})
	CreateUICorner(topbar, 0.3, 0)

	local barlogo = CreateImageLabel(topbar, UDim2.new(0.187,0,0.875,0), UDim2.new(-0.027,0,0.5,0), getasset("abort/assets/abort-logo.png"), {AnchorPoint = Vector2.new(0, 0.5), BackgroundTransparency = 1, ImageColor3 = Colors.TextPrimary, ZIndex = 2})
	CreateFrame(topbar, UDim2.new(1, 0,0.375, 0), UDim2.new(0, 0,0.625, 0), false, {BackgroundColor = Colors.Background})

	local closebutton = CreateButton(topbar, "×", UDim2.new(0.033,0,0.625,0), UDim2.new(0.953,0,0.5,0), function()
		ToggleMinimize()
		task.delay(0.15, function()
			AbortLibrary.DestroyRoot(Layout.GuiRoot)
		end)
	end, {BackgroundTransparency = 1, Font = Enum.Font.Arimo, TextScaled = true, TextSize = 12, ZIndex = 2, AnchorPoint = Vector2.new(0, 0.5)})

	local minimalizebutton = CreateButton(topbar, "−", UDim2.new(0.033,0,0.625,0), UDim2.new(0.913,0,0.5,0), function()
		ToggleMinimize()
	end, {BackgroundTransparency = 1, Font = Enum.Font.Arimo, TextScaled = true, TextSize = 12, ZIndex = 2, AnchorPoint = Vector2.new(0, 0.5)})
	
	return topbar
end

local function managesettingui(enable, scrollingframe)
	if settingspage then
		for _, v in pairs(settingspage:GetChildren()) do
			if v:IsA("ScrollingFrame") and v ~= scrollingframe then
				v.Visible = false
			end
		end
	end

	if enable then
		CreateTween(settingspage, Layout.tweenInfo, {Position = UDim2.new(0.693, 0, 0.089, 0)})
		CreateTween(backgroundblur, Layout.tweenInfo, {BackgroundTransparency = 0.75})
		if categories and activemenu then
			CreateTween(categories, Layout.tweenInfo, {Position = UDim2.new(-0.18, 0, 0.414, 0)})
			CreateTween(activemenu, Layout.tweenInfo, {Position = UDim2.new(0.008, 0, 0.414, 0)})
		end
		scrollingframe.Visible = true
	else
		CreateTween(settingspage, Layout.tweenInfo, {Position = UDim2.new(1, 0, 0.089, 0)})
		CreateTween(backgroundblur, Layout.tweenInfo, {BackgroundTransparency = 1})
		if categories and activemenu then
			CreateTween(categories, Layout.tweenInfo, {Position = UDim2.new(0, 0, 0.414, 0)})
			CreateTween(activemenu, Layout.tweenInfo, {Position = UDim2.new(0.18, 0, 0.414, 0)})
		end
		task.wait(0.1)
		scrollingframe.Visible = false
	end
end

function GUILoader.LoadBookmarks()
	local bookmarks = CreateFrame(Layout.GuiBackground, UDim2.new(1, 0,0.133, 0), UDim2.new(0, 0,-0.133, 0), false, {BackgroundTransparency = 1})
	
	local function CreateBookmarkContainer(alignment: "left" | "right", padding, positionX)
		local zone = CreateFrame(bookmarks, UDim2.new(0.5,0,1,0), UDim2.new(positionX,0,0,0), false, {BackgroundTransparency = 1})
		CreateAnimatedList(zone, "X", UDim.new(0.014, 0), {horizontal = alignment, vertical = "center"})
		CreateUIPadding(zone, {[padding] = UDim.new(0.04, 0)})
		return zone
	end
	
	local function CreateBookmarkButton(icon, container, order, text, name)
		local btn = CreateButton(container, text or "", UDim2.new(0.111, 0, 0.667, 0), nil, function() end, {LayoutOrder = order, BackgroundColor = Colors.Background, BackgroundTransparency = 0, ZIndex = 2})
		btn.TextTransparency = 1
		CreateUICorner(btn, 0.25, 0)

		local img = CreateImageLabel(btn, UDim2.new(0.35, 0, 0.35, 0), UDim2.new(0.5, 0, 0.5, 0), icon, {ImageColor3 = Colors.TextSecondary, AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 2})
		CreateUIAspectRatio(img)

		local l = Instance.new("UIListLayout", btn)
		l.FillDirection = Enum.FillDirection.Horizontal
		l.VerticalAlignment = Enum.VerticalAlignment.Center
		l.HorizontalAlignment = Enum.HorizontalAlignment.Center
		l.Padding = UDim.new(0, 16 * Layout.uiScale)

		ApplyHover(btn, function() return Colors.TextSecondary end, function() return Colors.TextPrimary end, img)
		if name ~= "search" and name ~= "settings" then
			local label = CreateTextLabel(btn, text or "", nil, UDim2.new(0.5, 0, 0.5, 0), {AutomaticSize = Enum.AutomaticSize.X, TextColor = Colors.TextPrimary,TextSize = Layout.TextSize,AnchorPoint = Vector2.new(0.5, 0.5),BackgroundTransparency = 0, ZIndex = 2})
			label.Visible = false
			return btn, img, label
		end

		return btn, img
	end
	
	local function CreateBookmarkPage(name)
		if name == "search" or name == "settings" then return end
		local page = CreateFrame(Layout.GuiBackground, UDim2.new(1, 0,0.778, 0), UDim2.new(0, 0,0.222, 0), false, {Visible = false, Name = name, BackgroundTransparency = 1})
		return page
	end
	
	local leftbookmarkcontainer = CreateBookmarkContainer("left", "PaddingLeft", 0)
	local rightbookmarkcontainer = CreateBookmarkContainer("right", "PaddingRight", 0.5)
	
	local function SetBookmarkButton(activate, bookmark, bookmarkpage, btn, img, label, searchbar)
		if bookmarkpage and not searchbar then bookmarkpage.Visible = activate end

		if activate and not searchbar then
			if label then label.Visible = true end
			img.ImageColor3 = Colors.TextPrimary
			HoverException(img, "add")
			HoverException(btn, "add")
			CreateTween(btn, Layout.tweenInfo, {Size = UDim2.new(0.173, label and label.TextBounds.X / Layout.uiScale or 0, 0.667, 0)})
		elseif not searchbar then
			if label then
				label.Visible = false
				CreateTween(label, Layout.tweenInfo, {Position = UDim2.new(0.5, 0, 0.5, 0)})
			end

			img.ImageColor3 = Colors.TextSecondary
			HoverException(img, "remove")
			HoverException(btn, "remove")
			CreateTween(btn, Layout.tweenInfo, {Size = UDim2.new(0.111, 0, 0.667, 0)})
		end
	end



	for _,bookmark in Layout.Bookmarks do
		local bookmarkcontainer = (bookmark[3] == "left") and leftbookmarkcontainer or rightbookmarkcontainer
		local btn, img, label = CreateBookmarkButton(getasset("abort/assets/"..bookmark[1]..".png"), bookmarkcontainer, bookmark[4],bookmark[2], bookmark[1])
		local bookmarkpage = CreateBookmarkPage(bookmark[1])
		bookmarkpages[bookmark[1]] = { Page = bookmarkpage, Button = btn, Icon = img, Label = label }

		if FirstInit and bookmarkpage then
			SetBookmarkButton(true, bookmark, bookmarkpage, btn, img, label)
			FirstInit = false
		end

		if bookmark[1] == "search" then
			local searchbox = CreateTextBox(btn, UDim2.new(0, btn.TextBounds.X / Layout.uiScale + 1, 0.5, 0), UDim2.new(0.5, 0, 0.5, 0), {TextWrapped = true, ZIndex = 2, Interactable = false, Text = "Type here...", PlaceholderText = "Type here...", TextColor = Colors.TextPrimary, PlaceholderColor3 = Colors.TextSecondary, TextSize = 14, AnchorPoint = Vector2.new(0.5, 0.5)})
			bookmarkpages[bookmark[1]].Label = searchbox
			searchbox.Visible = false
		elseif bookmark[1] == "settings" then
			settingspage = CreateFrame(Layout.GuiBackground, UDim2.new(0.307, 0,0.911, 0), UDim2.new(1, 0,0.089, 0), false, {BackgroundColor = Colors.Background, Name = "settings", ZIndex = 2})
			CreateUICorner(settingspage, 0.043, 0)

			settingslist = CreateScrollingFrame(settingspage, UDim2.new(1, 0,0.927, 0), UDim2.new(0, 0,0.073, 0), {AutomaticCanvasSize = Enum.AutomaticSize.None, ZIndex = 2, ScrollBarImageColor3 = Colors.TextSecondary, Name = "SettingsContainer"})
			CreateAnimatedList(settingslist, "Y", UDim.new(0.025, 0))

			backgroundblur = CreateFrame(Layout.GuiBackground, UDim2.new(1, 0,0.911, 0), UDim2.new(0, 0,0.089, 0), false, {BackgroundTransparency = 1, Name = "backgroundblur", BackgroundColor = Color3.fromRGB(0, 0, 0), Active = true, ZIndex = 1})
			CreateUICorner(backgroundblur, 0.029, 0)

			exitbutton = CreateImageButton(settingspage, UDim2.new(0.065, 0,0.037, 0), UDim2.new(0.065, 0,0.017, 0), getasset("abort/assets/left-arrow.png"), function() 
				managesettingui(false, settingslist)

				if targetDotsButton and targetOption then
					CreateTween(targetDotsButton, Layout.tweenInfo, {ImageColor3 = Colors.TextSecondary})
					HoverException(targetDotsButton, "remove")

					local configKey = oldcategory .. "_" .. oldtitle
					if targetOption and HoverRegistry[targetOption] and not Config:Get("Toggles", configKey, false) then
						HoverException(targetOption, "remove")
						HoverRegistry[targetOption](false, {
							Option = targetOption,
							SettingsFrame = oldsettings,
							Corner1 = oldcorner1,
							Corner2 = oldcorner2,
							IconFrame = oldiconframe,
						})
					end

					targetOption = nil
					targetDotsButton = nil
					oldDotsBtn = nil
				end

			end, {BackgroundColor = Colors.ButtonDefault, ImageColor3 = Colors.TextSecondary, ZIndex = 2})

			settingstitle = CreateTextLabel(settingspage, "Options", UDim2.new(0.738, 0,0.024, 0), UDim2.new(0.195, 0,0.024, 0), {TextColor = Colors.TextPrimary, TextSize = 16, ZIndex = 2, TextXAlignment = Enum.TextXAlignment.Left})
			TextTruncate(settingstitle)
		elseif bookmark[1] == "home" then
			categories = CreateFrame(bookmarkpage, UDim2.new(0.18, 0,0.829, 0), UDim2.new(0, 0,0.414, 0), false, {AnchorPoint = Vector2.new(0,0.5), Name = "categories", BackgroundTransparency = 1})
			CreateAnimatedList(categories, "Y", UDim.new(0.029, 0))
		end

		ConnectionManager:Add(btn, "MouseClick", btn.MouseButton1Click:Connect(function()
			if bookmark[1] ~= "settings" then
				for pageName, data in pairs(bookmarkpages) do
					SetBookmarkButton(false, bookmark, data.Page, data.Button, data.Icon, data.Label, bookmark[1] == "search" and true or false)

					local searchBox = data.Button and data.Button:FindFirstChildOfClass("TextBox")
					if searchBox then
						searchBox.Text = "Type here..."
						searchBox.Interactable = false
					end										
				end

				if bookmarkpage then
					bookmarkpage.Visible = true
				end
			end

			if bookmark[1] == "settings" then -- show settings and hide categories
				settingstitle.Text = "Options"
				TextTruncate(settingstitle)
				managesettingui(true, settingslist)	
			elseif bookmarkpages["search"] then
				local searchData = bookmarkpages["search"]
				HoverException(searchData.Icon, "remove")
				HoverException(searchData.Button, "remove")
				searchData.Icon.ImageColor3 = Colors.TextSecondary
			end

			if bookmark[1] ~= "settings" then
				local data = bookmarkpages[bookmark[1]]
				SetBookmarkButton(true, bookmark, data.Page, data.Button, data.Icon, data.Label)

				if bookmark[1] == "search" then
					local searchBox = btn:FindFirstChildOfClass("TextBox")
					if searchBox then
						task.defer(function()
							searchBox.Text = ""
							searchBox.Interactable = true
							searchBox:CaptureFocus()
						end)
					end
				end
			end
		end))
	end
	
	return bookmarks
end

local function brighten(color,step)
	step = step or 10
	return Color3.fromRGB(math.clamp(color.R * 255 + step, 0, 255), math.clamp(color.G * 255 + step, 0, 255), math.clamp(color.B * 255 + step, 0, 255))
end


--[[ GUI ITEMS ]]
local function CreateOpButton(container, name, descwidth, btnhover, additionalProps)
	additionalProps = additionalProps or {}
	local optionbutton = CreateButton(container, "", UDim2.new(0.869, 0, 0.081, 0), nil, function() end, {Visible = additionalProps.Visible or true, SkipHover = true, TextColor = Colors.TextSecondary, ZIndex = 3, BackgroundTransparency = additionalProps.BackgroundTransparency or 1, Active = false, Name = name, LayoutOrder = additionalProps.LayoutOrder or Layout.LayoutOrder})
	Layout.LayoutOrder += 1 
	local desc = CreateTextLabel(optionbutton, name, UDim2.new(descwidth and descwidth or 0.75, 0, 1, 0), additionalProps.Position or nil, {AnchorPoint = additionalProps.AnchorPoint or Vector2.new(0, 0), TextSize = additionalProps.TextSize or 14, TextXAlignment = additionalProps.TextXAlignment or Enum.TextXAlignment.Left, ZIndex = 3, BackgroundTransparency = 1})
	if btnhover then ApplyHover(optionbutton, function() return Colors.TextSecondary end, function() return Colors.TextPrimary end, desc) end
	TextTruncate(desc)
	return optionbutton, desc
end

local function CreateToggle(parentFrame, defaultState, position, clickTarget, onChange, categoryName, toggleName, sizeType)
	sizeType = sizeType or "Settings"
	local td = Layout.ToggleDefaults

	local toggleframe = CreateFrame(parentFrame, td[sizeType].FrameSize, position, false, {
		BackgroundColor = ProfileData.Misc.InterfaceColor, 
		BackgroundTransparency = defaultState and 0 or 1, 
		AnchorPoint = Vector2.new(0, 0.5), 
		ZIndex = 2
	})

	CreateUICorner(toggleframe, 1, 0)
	CreateUIAspectRatio(toggleframe)
	AbortLibrary.RegisterThemeElement(toggleframe, "BackgroundColor3")

	local toggleStroke = CreateUIStroke(toggleframe, 1, 0, defaultState and ProfileData.Misc.InterfaceColor or Colors.TextSecondary, Enum.ApplyStrokeMode.Border, Enum.BorderStrokePosition.Outer)

	local toggle = CreateFrame(toggleframe, td.CircleSize, 
		defaultState and td.CircleActivePos or td.CircleInactivePos, 
		false, {
			ZIndex = 2, 
			BackgroundColor = defaultState and Colors.TextPrimary or Colors.TextSecondary, 
			AnchorPoint = Vector2.new(0, 0.5)
		})
	CreateUICorner(toggle, 1, 0)
	CreateUIAspectRatio(toggle)

	local isActive = defaultState
	AbortLibrary.RegisterThemeElement(toggleStroke, "Color", function() -- if NOT is active then select color textsecondary
		if isActive then
			return ProfileData.Misc.InterfaceColor
		else
			return Colors.TextSecondary
		end
	end)

	local function activate()
		if isActive then
			CreateTween(toggleframe, Layout.tweenInfo, {BackgroundTransparency = 0})
			CreateTween(toggle, Layout.tweenInfo, {Position = td.CircleActivePos, BackgroundColor3 = Colors.TextPrimary})
			CreateTween(toggleStroke, Layout.tweenInfo, {Color = ProfileData.Misc.InterfaceColor})
		else
			CreateTween(toggleframe, Layout.tweenInfo, {BackgroundTransparency = 1})
			CreateTween(toggle, Layout.tweenInfo, {Position = td.CircleInactivePos, BackgroundColor3 = Colors.TextSecondary})
			CreateTween(toggleStroke, Layout.tweenInfo, {Color = Colors.TextSecondary})
		end
	end

	ConnectionManager:Add(clickTarget, "toggle", clickTarget.MouseButton1Click:Connect(function()
		isActive = not isActive

		activate()
		if onChange then onChange(isActive) end
		AbortLibrary.RefreshTheme()
	end))

	return toggleframe, function(newState)
		isActive = newState
		activate()
	end
end

AbortLibrary.AddToggle = function(a, b, c, d, skipInternalInit)
	skipInternalInit = skipInternalInit or false
	local container, name, description, callback
	if type(a) == "string" then
		name, description, callback = a, b, c
		container = settingslist
	else
		container, name, description, callback = a, b, c, d
	end

	local categoryName = container.Name:gsub("menu", "")
	local optionbutton, descLabel = CreateOpButton(container, name, nil, true)
	local saveKey = container.Name.."_"..name
	local savedState = Config:Get("Toggles", saveKey, false)

	local function updateDescVisual(state)
		if state then
			HoverException(descLabel, "add")
			CreateTween(descLabel, Layout.tweenInfo, {TextColor3 = Colors.TextPrimary})
		else
			if not table.find(exceptionlist, descLabel) then
				CreateTween(descLabel, Layout.tweenInfo, {TextColor3 = Colors.TextSecondary})
			end
			HoverException(descLabel, "remove")
		end
	end

	local toggleFrame, setToggleFunc = CreateToggle(optionbutton, savedState, UDim2.new(0.84, 0, 0.5, 0), optionbutton, function(state) 
		updateDescVisual(state)

		Config:Set("Toggles", saveKey, state)
		if callback then callback(state) end
	end, categoryName, name, "Settings")

	updateDescVisual(savedState)
	if savedState and callback and not skipInternalInit then
		task.defer(function()
			callback(savedState)
		end)
	end

	return saveKey
end

function AbortLibrary.AddSlider(container, name, min, max, startA: "For single and dual", startB: "Only for dual", step, callback, slider_type: "single" | "dual", custom_dot_color, skipInternalInit)
	skipInternalInit = skipInternalInit or false
	slider_type = slider_type or "single"
	local isDual = slider_type == "dual"
	startA = startA > min and startA or min
	startB = startB and startB > min and startB or max
	startB = startB > startA and startB or startA

	local saved = Config:Get("Sliders", name, {startA, startB})
	if type(saved) == "table" then
		startA = saved[1] or startA
		startB = saved[2] or startB
	else
		startA = saved or startA
	end

	local mainbtn = CreateOpButton(container, name, isDual and 0.65 or 0.85, false)
	local btn = CreateFrame(mainbtn, UDim2.new(1, 0, 1, 0))
	local list = Instance.new("UIListLayout", btn)
	list.Padding = UDim.new(0, 5 / Layout.uiScale)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Right
	list.FillDirection = Enum.FillDirection.Horizontal
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.VerticalAlignment = Enum.VerticalAlignment.Center

	local function getColor() return custom_dot_color or ProfileData.Misc.InterfaceColor end

	local cont = CreateButton(container, "", UDim2.new(0.869, 0, 0.03, 0), nil, function() end, {BackgroundColor = Colors.BackgroundDark, ZIndex = 2, AnchorPoint = Vector2.new(0, 0), ClipsDescendants = false})
	CreateUICorner(cont, 0.3, 0)

	local base = CreateFrame(cont, UDim2.new(1, 0, 0, 3), UDim2.new(0.5, 0, 0.5, 0), false, {BackgroundTransparency = 0.9, BackgroundColor = Colors.TextTertiary, ZIndex = 3, AnchorPoint = Vector2.new(0.5, 0.5)})
	CreateUICorner(base, 1, 0)

	local fill = CreateFrame(base, UDim2.new(0.5, 0, 0, 3), UDim2.new(0.25, 0, 0.5, 0), false, {BackgroundColor = getColor(), ZIndex = 3, AnchorPoint = Vector2.new(0, 0.5)})
	AbortLibrary.RegisterThemeElement(fill, "BackgroundColor3")
	CreateUICorner(fill, 1, 0)

	local left = CreateButton(base, "", UDim2.new(0, 11, 0, 11), UDim2.new(0.25, 0, 0.5, 0), function() end, {BackgroundColor = getColor(), CustomHover = {Hover = function() return {BackgroundColor3 = brighten(getColor(), 40)} end, Default = function() return {BackgroundColor3 = getColor()} end},ZIndex = 4, AnchorPoint = Vector2.new(0.5, 0.5)})
	AbortLibrary.RegisterThemeElement(left, "BackgroundColor3", function() return getColor() end) 

	CreateUICorner(left, 1, 0)
	CreateUIStroke(left, 3, 0, Colors.BackgroundDark)

	local right
	if isDual then
		right = CreateButton(base, "", UDim2.new(0, 11, 0, 11), UDim2.new(0.75, 0, 0.5, 0), function() end, {BackgroundColor = getColor(), CustomHover = {Hover = function() return {BackgroundColor3 = brighten(getColor(), 40)} end, Default = function() return {BackgroundColor3 = getColor()} end},ZIndex = 4, AnchorPoint = Vector2.new(0.5, 0.5)})
		CreateUICorner(right, 1, 0)
		CreateUIStroke(right, 3, 0, Colors.BackgroundDark)
		AbortLibrary.RegisterThemeElement(right, "BackgroundColor3", function() return getColor() end) 
	end

	local leftRel = (startA - min) / (max - min)
	local rightRel = isDual and ((startB or max) - min) / (max - min) or 1
	local valA, valB = startA, isDual and (startB or max) or max
	local data = {min, max, step}

	local function SetDot(dot, value, isLeft)
		local rel = (value - data[1]) / (data[2] - data[1])
		if isLeft then
			leftRel = rel
		else
			rightRel = rel
		end
		CreateTween(dot, Layout.tweenInfo, {Position = UDim2.new(rel, 0, 0.5, 0)})
	end

	local function updateFill()
		if isDual then
			local lx = math.clamp(leftRel, 0, rightRel)
			local rx = math.clamp(rightRel, lx, 1)
			CreateTween(fill, Layout.tweenInfo, {Position = UDim2.new(lx, 0, 0.5, 0)})
			CreateTween(fill, Layout.tweenInfo, {Size = UDim2.new(rx - lx, 0, 0, 3)})
		else
			local lx = math.clamp(leftRel, 0, 1)
			CreateTween(fill, Layout.tweenInfo, {Position = UDim2.new(0, 0, 0.5, 0)})
			CreateTween(fill, Layout.tweenInfo, {Size = UDim2.new(lx, 0, 0, 3)})
		end

		Config:Set("Sliders", name, {valA, valB})
	end

	local function updateSelector(selector, box, onlytween)
		onlytween = onlytween or false
		if onlytween then
			CreateTween(selector, Layout.tweenInfo, {Size = UDim2.new(0, box.TextBounds.X+2 / Layout.uiScale, 0, 2)})
			CreateTween(selector, Layout.tweenInfo, {Position = UDim2.new(1, -box.TextBounds.X-2 / Layout.uiScale, 1, -2)})
			CreateTween(box, Layout.tweenInfo, {Size = UDim2.new(0, box.TextBounds.X/Layout.uiScale, 1, 0)})
		end
		ConnectionManager:Add(box, "Focused", box.Focused:Connect(function() HoverException(selector, "add") end)) 
		ConnectionManager:Add(box, "FocusLost", box.FocusLost:Connect(function() HoverException(selector, "remove") CreateTween(selector, Layout.tweenInfo, {BackgroundColor3 = Colors.TextTertiary}) end)) 
	end

	local function enforceOrder()
		if isDual and valA > valB then
			valA = valB
		end
		SetDot(left, valA, true)
		if isDual then
			SetDot(right, valB, false)
		end
		updateFill()
		callback(valA, isDual and valB or nil)
		AbortLibrary.RefreshTheme()
	end

	local boxA
	local Selector = CreateFrame(nil, UDim2.new(0,0,0,2), UDim2.new(0, 0, 1, -2), false, {BackgroundTransparency = 0.8, BackgroundColor = Colors.TextTertiary, ZIndex = 4})
	CreateUICorner(Selector, 1, 0)
	boxA = CreateTextBox(btn, UDim2.new(1, 0, 1, 0), UDim2.new(isDual and 0.65 or 0.85, 0, 0.5, 0), {Layout = 1, HoverTarget = Selector, CustomHover={Hover={BackgroundColor3=Colors.TextSecondary},Default={BackgroundColor3=Colors.TextTertiary}}, Text = tostring(valA), TextColor = Colors.TextPrimary, MaxLetters = tonumber(#tostring(math.abs(max))), PlaceholderText = tostring(min), TextSize = 13, AnchorPoint = Vector2.new(0, 0.5), BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 3
	}, function() updateSelector(Selector, boxA, true) end)

	ConnectionManager:Add(boxA, "FocusLostCustom", boxA.FocusLost:Connect(function()
		local num = tonumber(boxA.Text)
		if not num then boxA.Text = tostring(valA) return end
		if isDual then
			valA = math.clamp(num, min, valB)
		else
			valA = math.clamp(num, min, max)
		end

		boxA.Text = tostring(valA)
		enforceOrder()
	end))

	Selector.Parent = boxA
	updateSelector(Selector, boxA, true)

	local boxB
	if isDual then
		local Selector2 = Selector:Clone()
		CreateImageLabel(btn, UDim2.new(0, 15 * Layout.uiScale,0, 15 * Layout.uiScale), UDim2.new(0.865, 0, 0.5, 0), getasset("abort/assets/resizer.png"), {Layout = 2, ImageColor3 = Colors.TextPrimary, ZIndex = 4, AnchorPoint = Vector2.new(0.5, 0.5)})
		boxB = CreateTextBox(btn, UDim2.new(0.15, 0, 1, 0), UDim2.new(0.85, 0, 0.5, 0), {HoverTarget = Selector2,CustomHover={Hover={BackgroundColor3=Colors.TextSecondary},Default={BackgroundColor3=Colors.TextTertiary}},Text = tostring(valB), TextColor = Colors.TextPrimary, MaxLetters = tonumber(#tostring(math.abs(max))), PlaceholderText = tostring(max),TextSize = 13, AnchorPoint = Vector2.new(0, 0.5), BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 4, Layout = 3
		}, function() updateSelector(Selector2, boxB, true) end)

		ConnectionManager:Add(boxB, "FocusLostCustom", boxB.FocusLost:Connect(function()
			local num = tonumber(boxB.Text)
			if not num then boxB.Text = tostring(valB) return end
			valB = math.clamp(num, valA, max)
			boxB.Text = tostring(valB)
			enforceOrder()
		end))

		Selector2.Parent = boxB
		updateSelector(Selector2, boxB, true)
	end

	SetDot(left, valA, true)
	if isDual then SetDot(right, valB, false) end
	
	if not skipInternalInit then
		enforceOrder()
	else
		updateFill()
	end

	data.TextBoxA = boxA
	if isDual then data.TextBoxB = boxB end

	local function DragDot(dot, otherDot, isLeft)
		local dragging = false
		local lastValue

		ConnectionManager:Add(dot, "InputBegan", dot.InputBegan:Connect(function(input) 
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				HoverException(dot, "add")
				dragging = true
				dot.ZIndex = 10
				if otherDot then otherDot.ZIndex = 4 end
			end
		end))

		ConnectionManager:Add(UserInputService, "Dot_InputEnded", UserInputService.InputEnded:Connect(function(input) 
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				HoverException(dot, "remove")
				CreateTween(dot, Layout.tweenInfo, {BackgroundColor3 = getColor()})
				dragging = false
				updateFill()
			end
		end), true)

		ConnectionManager:Add(UserInputService, "Dot_InputChanged", UserInputService.InputChanged:Connect(function(input)
			if not dragging or input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
			local parent = dot.Parent
			local absPos = parent.AbsolutePosition
			local absSize = parent.AbsoluteSize
			local rel = math.clamp((input.Position.X - absPos.X) / absSize.X, 0, 1)

			if isLeft then
				if isDual then rel = math.min(rel, rightRel) end
				leftRel = rel
				valA = math.floor(((rel * (max - min) + min) / step) + 0.5) * step
			else
				if isDual then rel = math.max(rel, leftRel) end
				rightRel = rel
				valB = math.floor(((rel * (max - min) + min) / step) + 0.5) * step
			end

			CreateTween(dot, Layout.tweenInfo, {Position = UDim2.new(rel, 0, 0.5, 0)})
			updateFill()
			if isLeft then
				data.TextBoxA.Text = tostring(valA)
			elseif isDual then
				data.TextBoxB.Text = tostring(valB)
			end
			callback(valA, isDual and valB or nil)
			AbortLibrary.RefreshTheme()
		end), true)
	end

	DragDot(left, right, true)
	if isDual then DragDot(right, left, false) end

	return {background = base, fill = fill, dot = left, boxA = boxA, btn = btn,
		SetValue = function(v)
			valA = math.clamp(v, min, max)
			leftRel = (valA - min) / (max - min)
			SetDot(left, valA, true)
			updateFill()
		end,
		GetValue = function() return valA end
	}
end

local function TheSameOptionButtonShittyHover(optionbutton, desc)
	local clearTween = function()
		CreateTween(desc, Layout.tweenInfo, {TextColor3 = Colors.TextSecondary})
		CreateTween(optionbutton, Layout.tweenInfo, {BackgroundTransparency = 1})
	end
	ConnectionManager:Add(optionbutton, "Menter", optionbutton.MouseEnter:Connect(function() 
		CreateTween(desc, Layout.tweenInfo, {TextColor3 = Colors.TextPrimary})
		CreateTween(optionbutton, Layout.tweenInfo, {BackgroundTransparency = 0.9})
	end))
	ConnectionManager:Add(optionbutton, "Mleave", optionbutton.MouseLeave:Connect(function()
		if table.find(exceptionlist, optionbutton) then return end
		clearTween()
	end))
	return clearTween
end

function AbortLibrary.AddDropdown(container, name, options, default, callback, skipInternalInit)
	skipInternalInit = skipInternalInit or false
	local optionbutton, desc = CreateOpButton(container, name, 0.8, false)
	local removeTween = TheSameOptionButtonShittyHover(optionbutton, desc)
	Layout.LayoutOrder += 1
	CreateUIPadding(optionbutton, {["PaddingLeft"] = UDim.new(0.05, 0)})
	CreateUICorner(optionbutton, 0, 4 * Layout.uiScale)
	CreateUIStroke(optionbutton, 1, 0, Colors.TextTertiary)

	local arrow = CreateImageLabel(optionbutton, UDim2.new(0, 12 * Layout.uiScale, 0, 12 * Layout.uiScale), UDim2.new(0.92, 0, 0.5, 0), getasset("abort/assets/down-arrow.png"), {ImageColor3 = Colors.TextSecondary,ZIndex = 3,AnchorPoint = Vector2.new(0.5, 0.5)})
	local listFrame = CreateFrame(optionbutton, UDim2.new(1.05, 0, 0, 0), UDim2.new(-0.05, 0, 1, 0), true, {BackgroundColor = Colors.BackgroundDark, ZIndex = 11, Visible = false})
	CreateUIStroke(listFrame, 1, 0, Colors.TextTertiary)
	CreateUICorner(listFrame, 0, 4 * Layout.uiScale)
	
	local fakelist = CreateFrame(container, UDim2.new(0,0,0,0), nil, false, {Visible = false, BackgroundTransparency = 1})

	local open = false
	local selected = Config:Get("Dropdowns", name, default) or options[1]
	local function updateDesc()
		desc.Text = name..": "..selected
		TextTruncate(desc, false, nil, true)
	end

	updateDesc()
	if not skipInternalInit and callback then
		task.defer(function() callback(selected) end)
	end
	
	local function toggleList()
		open = not open
		if open then
			HoverException(optionbutton, "add")
			listFrame.Visible = true
			CreateTween(fakelist, Layout.tweenInfo, {Size = UDim2.new(1,0,0,#options * (26 * Layout.uiScale) )})
			CreateTween(listFrame, Layout.tweenInfo, {Size = UDim2.new(1.05,0,0,#options * (26 * Layout.uiScale) )}).Completed:Once(function()
				fakelist.Visible = true
			end)
			CreateTween(arrow, Layout.tweenInfo, {Rotation = 180})
		else
			HoverException(optionbutton, "remove")
			removeTween()
			CreateTween(fakelist, Layout.tweenInfo, {Size = UDim2.new(1,0,0,0)})
			CreateTween(listFrame, Layout.tweenInfo, {Size = UDim2.new(1.05,0,0,0)}).Completed:Once(function()
				listFrame.Visible = false
				fakelist.Visible = false
			end)
			CreateTween(arrow, Layout.tweenInfo, {Rotation = 0})
		end
	end

	for _, opt in ipairs(options) do
		local optButton = CreateButton(listFrame, opt, UDim2.new(0.9, 0, 0, 13 * Layout.uiScale), nil, function()
			selected = opt
			callback(opt)
			toggleList()
			updateDesc()
			Config:Set("Dropdowns", name, selected)
		end, {TextXAlignment = Enum.TextXAlignment.Center,BackgroundTransparency = 1,TextColor = Colors.TextSecondary,TextSize = 13,ZIndex = 12})
		TextTruncate(optButton)
		ApplyHover(optButton, function() return Colors.TextSecondary end, function() return Colors.TextPrimary end)
	end

	CreateAnimatedList(listFrame, "Y", UDim.new(0, ( #options*(13*Layout.uiScale) )/(#options+1)), nil, true)
	ConnectionManager:Add(optionbutton, "click", optionbutton.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			toggleList()
		end
	end))
end

function AbortLibrary.AddSeparator(container)
	CreateFrame(container, UDim2.new(0.95, 0, 0, 1), nil, false, {BackgroundTransparency = 0.5, ZIndex = 3, BackgroundColor = Colors.TextTertiary, LayoutOrder = Layout.LayoutOrder})
	Layout.LayoutOrder += 1
end

function AbortLibrary.AddColorPicker(container, name, defaultColor, callback, skipInternalInit)
	callback = callback or function() end
	local saved = Config:Get("ColorPickers", name, {r = defaultColor and defaultColor.R or 1, g = defaultColor and defaultColor.G or 0, b = defaultColor and defaultColor.B or 0})
	local currentColor = Color3.new(saved.r, saved.g, saved.b)

	local colorslider = AbortLibrary.AddSlider(container, name, 0, 1, 0.8, nil, 0.01, function() end, "single", Color3.fromRGB(215, 215, 215))
	colorslider["boxA"]:Destroy()
	local base, fill, dot, boxholder = colorslider.background, colorslider.fill, colorslider.dot, colorslider.btn
	fill.BackgroundTransparency = 1
	base.BackgroundColor3 = Color3.fromRGB(255,255,255)
	base.BackgroundTransparency = 0

	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0.00, Color3.fromRGB(0, 0, 0)),
		ColorSequenceKeypoint.new(0.01, Color3.fromRGB(255, 70, 70)),
		ColorSequenceKeypoint.new(0.20, Color3.fromRGB(255, 200, 0)),
		ColorSequenceKeypoint.new(0.40, Color3.fromRGB(80, 255, 150)),
		ColorSequenceKeypoint.new(0.60, Color3.fromRGB(70, 170, 255)),
		ColorSequenceKeypoint.new(0.80, Color3.fromRGB(147, 129, 255)),
		ColorSequenceKeypoint.new(0.99, Color3.fromRGB(255, 80, 200)),
		ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255, 255, 255))
	})
	gradient.Parent = base

	local function findGradientTimeByColor(gradientObj, color)
		local keypoints = gradientObj.Color.Keypoints
		for _, k in ipairs(keypoints) do
			if math.floor(k.Value.R*255+0.5) == math.floor(color.R*255+0.5)
				and math.floor(k.Value.G*255+0.5) == math.floor(color.G*255+0.5)
				and math.floor(k.Value.B*255+0.5) == math.floor(color.B*255+0.5) then
				return k.Time
			end
		end

		local bestPos, bestDiff = 0, math.huge
		for i = 1, #keypoints - 1 do
			local k1, k2 = keypoints[i], keypoints[i + 1]
			for step = 0, 1, 0.001 do
				local c = k1.Value:Lerp(k2.Value, step)
				local diff = (c.R-color.R)^2+(c.G-color.G)^2+(c.B-color.B)^2
				if diff < bestDiff then
					bestDiff = diff
					bestPos = k1.Time + (k2.Time - k1.Time)*step
				end
			end
		end

		return bestPos
	end

	local function sampleGradient(grad, t)
		local keys = grad.Color.Keypoints
		for i = 1, #keys - 1 do
			local k1, k2 = keys[i], keys[i + 1]
			if t >= k1.Time and t <= k2.Time then
				local alpha = (t - k1.Time) / (k2.Time - k1.Time)
				return k1.Value:Lerp(k2.Value, alpha)
			end
		end
		return keys[#keys].Value
	end

	local targetPos = findGradientTimeByColor(gradient, currentColor)
	colorslider.SetValue(targetPos)

	local colorBtn = CreateButton(boxholder, "", UDim2.new(0, boxholder.AbsoluteSize.Y/1.5, 0, boxholder.AbsoluteSize.Y/1.5), UDim2.new(0.85, 0, 0.5, 0), function() end, {BackgroundColor=currentColor, AnchorPoint=Vector2.new(0,0.5), ZIndex=4})
	CreateUICorner(colorBtn, 0.25, 0)
	CreateUIStroke(colorBtn, 2, 0, Color3.fromRGB(40,40,40))

	local dragging = false
	local function updateFromPos(rel)
		local col = sampleGradient(gradient, rel)
		currentColor = col
		colorBtn.BackgroundColor3 = col
		local r,g,b = math.floor(col.R*255+0.5), math.floor(col.G*255+0.5), math.floor(col.B*255+0.5)
		callback(Color3.fromRGB(r,g,b))
		Config:Set("ColorPickers", name, {r = col.R, g = col.G, b = col.B})
	end

	if not skipInternalInit then updateFromPos(targetPos) end
	ConnectionManager:Add(dot, "pickerdot_Inputbegan", dot.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true end
	end))

	ConnectionManager:Add(UserInputService, "pickerdot_InputEnded", UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
	end), true)

	ConnectionManager:Add(UserInputService, "pickerdot_InputChanged", UserInputService.InputChanged:Connect(function(input) 
		if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			local relative = math.clamp((input.Position.X - base.AbsolutePosition.X) / base.AbsoluteSize.X, 0, 1)
			updateFromPos(relative)
		end
	end), true)

	return {
		Color = function() return currentColor end,
		Position = function() return targetPos end
	}
end

function AbortLibrary.AddKeybindListener(container, db_keybind, description, callback, skipInternalInit)
	skipInternalInit = skipInternalInit or false
	local text if db_keybind and db_keybind.Name then text = "BOUND | " .. db_keybind.Name else text = "UNBOUND | CLICK TO BIND" end
	local optionbutton, desc = CreateOpButton(container, text, 0.8, false, {TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0)})
	local clearTween = TheSameOptionButtonShittyHover(optionbutton, desc)
	CreateUICorner(optionbutton, 0, 4 * Layout.uiScale)
	CreateUIStroke(optionbutton, 1, 0, Colors.TextTertiary)
	
	if not skipInternalInit and callback then
		task.defer(function()
			callback(db_keybind)
		end)
	end
	
	local listener, active
	optionbutton.MouseButton1Click:Connect(function()
		HoverException(optionbutton, "add")
		active = not active

		if active then
			if listener then listener:Disconnect() listener = nil end
			desc.Text = "PRESS A KEY TO ASSIGN..."
			TextTruncate(desc)

			listener = StartKeybindListener(function(new_key)
				active = false
				HoverException(optionbutton, "remove")
				clearTween()
				desc.Text = "BOUND | "..new_key.Name
				TextTruncate(desc)
				callback(new_key)
			end)
		else
			HoverException(optionbutton, "remove")
			clearTween()
			if listener then listener:Disconnect() listener = nil end
			desc.Text = "UNBOUND | CLICK TO BIND"
			TextTruncate(desc)
			callback(nil)
		end
	end)

	return optionbutton
end

AbortLibrary.CreateMainToggle = function(category, title, desc, callback)
	local desclabel, descProps, controller
	local categoryName = category[1].Name:gsub("menu", "")
	local configKey = categoryName.."_"..title
	local defaultState = Config:Get("Toggles", configKey, false)
	local optionOrderCounter = 0

	local buttonsettings = CreateScrollingFrame(settingspage, UDim2.new(1, 0, 0.927, 0), UDim2.new(0, 0, 0.073, 0), {AutomaticCanvasSize = Enum.AutomaticSize.None, ZIndex = 2, ScrollBarImageColor3 = Colors.TextSecondary, Name = category.Name})
	CreateAnimatedList(buttonsettings, "Y", UDim.new(0.025, 0), nil, true)

	local option = CreateButton(category[1], "", UDim2.new(1, 0, 0.171, 0), nil, function() end, {BackgroundColor = Colors.Background, LayoutOrder = optionOrderCounter, Active = false})
	CreateUICorner(option, 0.208, 0)

	local iconframe = CreateFrame(option, UDim2.new(0.125, 0, 1, 0), UDim2.new(0, 0, 0, 0), false, {BackgroundColor = Colors.BackgroundDark})
	CreateUICorner(iconframe, 0.25, 0)

	local cornerhider1 = CreateFrame(iconframe, UDim2.new(0.3, 0,1, 0), UDim2.new(0.7, 0,0, 0), false, {BackgroundColor = Colors.Background})

	local settingsframe = CreateFrame(option, UDim2.new(0.06, 0, 1, 0), UDim2.new(0.94, 0, 0, 0), false, {BackgroundColor = Colors.BackgroundDark})
	CreateUICorner(settingsframe, 0.5, 0)
	local cornerhider2 = CreateFrame(settingsframe, UDim2.new(0.3, 0,1, 0), nil, false, {BackgroundColor = Colors.Background})

	local baseOption = Colors.Background
	local baseIcon = Colors.BackgroundDark
	local baseSettings = Colors.BackgroundDark
	local baseCorner = Colors.Background

	local hoverOption = brighten(baseOption)
	local hoverSettings = brighten(baseSettings)
	local hoverCorner = brighten(baseCorner)
	optionOrderCounter = optionOrderCounter + 1

	local buttoninserts = {
		Container = buttonsettings,
		internalToggles = {},
		internalDropdowns = {},
		internalSliders = {},
		internalColorPickers = {},
		internalKeybinds = {},
		_initialized = false,

		_initCallbacks = function(self)
			if self._initialized then return end
			self._initialized = true
			task.defer(function()
				local parentState = Config:Get("Toggles", configKey, false)
				for _, list in ipairs{{self.internalToggles, "Toggles"}, {self.internalDropdowns, "Dropdowns"}, {self.internalSliders, "Sliders"}, {self.internalColorPickers, "ColorPickers"}, {self.internalKeybinds, "Keybinds"}} do
					for _, data in ipairs(list[1]) do
						if data.callback then
							if list[2] == "Toggles" then
								local val = Config:Get("Toggles", data.key, false)
								data.callback(val, parentState)
							elseif list[2] == "Dropdowns" then
								local val = Config:Get("Dropdowns", data.name, data.default)
								data.callback(val, parentState)
							elseif list[2] == "Sliders" then
								local s = Config:Get("Sliders", data.name, {data.startA, data.startB})
								if data.startB then
									data.callback(s[1], s[2], parentState)
								else
									data.callback(s[1], nil, parentState)
								end
							elseif list[2] == "Keybinds" then
								local savedkey = Config:Get("Keybinds", data.key, nil)
								if savedkey then 
									data.callback(savedkey, parentState)
								end
							else
								local c = Config:Get("ColorPickers", data.name, data.default)
								local val = Color3.new(c.r, c.g, c.b)
								data.callback(val, parentState)
							end
						end
					end
				end
			end)
		end,

		AddToggle = function(self, title, desc, cb) 
			local k = AbortLibrary.AddToggle(self.Container, title, desc, function(s) if cb then cb(s, Config:Get("Toggles", configKey, false)) end end, true)
			table.insert(self.internalToggles, {key = k, callback = cb})
			self:_initCallbacks()
		end,

		AddDropdown = function(self, name, opts, def, cb)
			AbortLibrary.AddDropdown(self.Container, name, opts, def, function(s) if cb then cb(s, Config:Get("Toggles", configKey, false)) end end)
			table.insert(self.internalDropdowns, {name = name, default = def, callback = cb})
			self:_initCallbacks()
		end,

		AddSlider = function(self, name, min, max, a, b, step, cb, typ, col)
			local s = AbortLibrary.AddSlider(self.Container, name, min, max, a, b, step, function(v1, v2) if cb then cb(v1, v2, Config:Get("Toggles", configKey, false)) end end, typ, col, true)
			table.insert(self.internalSliders, {name = name, startA = a, startB = b, callback = cb})
			self:_initCallbacks()
			return s
		end,

		AddColorPicker = function(self, name, def, cb)
			local p = AbortLibrary.AddColorPicker(self.Container, name, def, function(c) if cb then cb(c, Config:Get("Toggles", configKey, false)) end end)
			table.insert(self.internalColorPickers, {name = name, default = def, callback = cb})
			self:_initCallbacks()
			return p
		end,
		
		AddKeybind = function(self, name, defaultKey, cb)
			local key = configKey.."_"..name
			local savedKey = Config:Get("Keybinds", key, nil)
			local optionbutton = AbortLibrary.AddKeybindListener(self.Container,savedKey or defaultKey,"",function(new_key)if new_key then Config:Set("Keybinds", key, new_key) else Config:Set("Keybinds", key, nil) end
			if cb then cb(new_key, Config:Get("Toggles", configKey, false)) end end, false)
			table.insert(self.internalKeybinds, {key = key, callback = cb})
			self:_initCallbacks()
			return optionbutton
		end,
		
		AddSeparator = function(self) AbortLibrary.AddSeparator(self.Container) end,
	}

	local function setHover(state, properties)
		properties = properties or {}
		CreateTween(properties and properties.Option or option, Layout.tweenInfo, {BackgroundColor3 = state and hoverOption or baseOption})
		CreateTween(properties and properties.SettingsFrame or settingsframe, Layout.tweenInfo, {BackgroundColor3 = state and hoverSettings or baseSettings})
		CreateTween(properties and properties.Corner1 or cornerhider1, Layout.tweenInfo, {BackgroundColor3 = state and hoverCorner or baseCorner})
		CreateTween(properties and properties.Corner2 or cornerhider2, Layout.tweenInfo, {BackgroundColor3 = state and hoverCorner or baseCorner})
		CreateTween(properties and properties.IconFrame or iconframe, Layout.tweenInfo, {BackgroundColor3 = state and hoverSettings or baseSettings})
	end

	HoverRegistry[option] = function(state, properties)
		setHover(state, properties)
	end

	local active, exiticon, keybindlistener, keybindicon = false, nil, nil, nil
	local function KeybindSet(key)
		keybindlistener.Text = key.Name
		keybindlistener.TextTransparency = 0.6
		keybindlistener.BackgroundTransparency = 0
		keybindicon.Visible = false

		local newWidth = math.max(keybindlistener.AbsoluteSize.Y, keybindlistener.TextBounds.X / Layout.uiScale) + (16/Layout.uiScale)
		local oldWidth = keybindlistener.AbsoluteSize.Y
		local delta = newWidth - oldWidth

		CreateTween(keybindlistener, Layout.tweenInfo, {
			Size = UDim2.new(0, newWidth, 0.278, 0),
			Position = UDim2.new(0.8, -delta, 0.5, 0)})

		task.defer(function()
			adjustDescriptionForKeybind(desclabel, option, descProps, controller, newWidth)
		end)
	end

	local listener, justassigned = nil, false
	keybindlistener = CreateButton(option, "", Layout.ToggleDefaults["Module"].FrameSize, UDim2.new(0.8, 0, 0.5, 0), function() -- keybind pressed
		active = not active
		exiticon.Visible = active
		keybindicon.Visible = not active

		if active then
			if listener then listener:Disconnect() listener = nil end
			keybindlistener.TextTransparency = 1

			listener = StartKeybindListener(function(new_key)
				justassigned = true
				KeybindSet(new_key)
				active = false
				exiticon.Visible = false
				Config:Set("Keybinds", configKey, new_key)
			end)
		else 
			if listener then listener:Disconnect() listener = nil end

			exiticon.Visible = false
			keybindicon.Visible = true
			keybindlistener.TextTransparency = 1
			keybindlistener.BackgroundTransparency = 1
			keybindlistener.Size = Layout.ToggleDefaults["Module"].FrameSize
			CreateTween(keybindlistener, Layout.tweenInfo, {
				Size = UDim2.new(0, keybindlistener.AbsoluteSize.Y, 0, keybindlistener.AbsoluteSize.Y),
				Position = UDim2.new(0.8, 0, 0.5, 0)})

			descProps.MaxScale = 0.35
			controller:update()
			justassigned = false
			Config:Set("Keybinds", configKey, nil)
		end
	end, {ZIndex = 3, AnchorPoint = Vector2.new(0, 0.5), TextSize = 12, TextColor = Colors.TextSecondary, TextTransparency = 0.6, BackgroundColor = brighten(Colors.Background, 10), BackgroundTransparency = 1})

	keybindlistener.Size = UDim2.new(0, keybindlistener.AbsoluteSize.Y, 0, keybindlistener.AbsoluteSize.Y)
	local keybindstroke = CreateUIStroke(keybindlistener, 1, 0.6, Colors.TextTertiary)
	CreateUICorner(keybindlistener, 1, 0)

	exiticon = CreateTextLabel(keybindlistener, "×", UDim2.new(0.8, 0, 0.8, 0), UDim2.new(0.5, 0, 0.5, 0), {Visible = false, BackgroundTransparency = 1, Font = Enum.Font.Arimo, TextScaled = true, TextSize = 12, ZIndex = 4, AnchorPoint = Vector2.new(0.5, 0.5)})
	keybindicon = CreateImageLabel(keybindlistener, UDim2.new(0.5, 0, 0.5, 0), UDim2.new(0.5, 0, 0.5, 0), getasset("abort/assets/keybinds.png"), {ImageTransparency = 0.6, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 4, ImageColor3 = Colors.TextTertiary, SkipHover = true})

	ConnectionManager:Add(keybindlistener, "HoverEnter", keybindlistener.MouseEnter:Connect(function()
		CreateTween(keybindstroke, Layout.tweenInfo, {Color = Colors.TextSecondary})
		CreateTween(keybindicon,   Layout.tweenInfo, {ImageColor3 = Colors.TextSecondary})
	end))

	ConnectionManager:Add(keybindlistener, "HoverLeave", keybindlistener.MouseLeave:Connect(function()
		CreateTween(keybindstroke, Layout.tweenInfo, {Color = Colors.TextTertiary})
		CreateTween(keybindicon,   Layout.tweenInfo, {ImageColor3 = Colors.TextTertiary})
	end))

	local hovering = false
	ConnectionManager:Add(option, "enter", option.MouseEnter:Connect(function()
		keybindlistener.Visible = true
		hovering = true
		if not table.find(exceptionlist or {}, option) then
			setHover(true)
		end
	end))

	ConnectionManager:Add(option, "leave", option.MouseLeave:Connect(function()
		hovering = false
		if not table.find(exceptionlist or {}, option) then
			keybindlistener.Visible = false
			setHover(false)
		end
	end))

	local dotsButton
	dotsButton = CreateImageButton(settingsframe, UDim2.new(0.588, 0,0.278, 0), UDim2.new(0.6, 0, 0.5, 0), getasset("abort/assets/dots.png"), function()
		if dotsButton == oldDotsBtn then return end
		if targetDotsButton then
			HoverException(targetDotsButton, "remove")
			CreateTween(targetDotsButton, Layout.tweenInfo, {ImageColor3 = Colors.TextSecondary})

			local old_configKey = oldcategory.."_"..oldtitle
			if not Config:Get("Toggles", old_configKey, false) then
				HoverException(targetOption, "remove")
				setHover(false, {
					Option = targetOption,
					SettingsFrame = oldsettings,
					Corner1 = oldcorner1,
					Corner2 = oldcorner2,
					IconFrame = oldiconframe,
				})
			end
		end

		oldsettings, oldcorner1, oldcorner2, oldiconframe = settingsframe, cornerhider1, cornerhider2, iconframe
		oldcategory = category[1].Name:gsub("menu", "")
		oldtitle = title
		targetDotsButton = dotsButton
		targetOption = option
		oldDotsBtn = dotsButton

		HoverException(dotsButton, "add")
		HoverException(option, "add")
		settingstitle.Text = title .. " Options"
		TextTruncate(settingstitle)
		managesettingui(true, buttonsettings)
	end, {BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 3})

	MakeReorderable(dotsButton, option, category[2])

	local function updateToggleVisual(state, skipCallback)
		if state then
			setHover(true)
			HoverException(option, "add")
			keybindlistener.Visible = true
		else
			if not hovering then keybindlistener.Visible = false end
			if targetOption ~= option then
				HoverException(option, "remove")
			end
		end
		
		for _, list in ipairs{{buttoninserts.internalToggles, "Toggles"}, {buttoninserts.internalDropdowns, "Dropdowns"}, {buttoninserts.internalSliders, "Sliders"}, {buttoninserts.internalColorPickers, "ColorPickers", {buttoninserts.internalKeybinds, "Keybinds"}}} do
			for _, data in ipairs(list[1]) do
				if data.callback then
					if list[2] == "Toggles" then
						local val = Config:Get("Toggles", data.key, false)
						data.callback(val, state)
					elseif list[2] == "Dropdowns" then
						local val = Config:Get("Dropdowns", data.name, data.default)
						data.callback(val, state)
					elseif list[2] == "Sliders" then
						local s = Config:Get("Sliders", data.name, {data.startA, data.startB})
						data.callback(s[1], s[2], state)
					elseif list[2] == "Keybinds" then
						local val = Config:Get("Keybinds", data.key, nil)
						data.callback(val, state)
 					else
						local c = Config:Get("ColorPickers", data.name, data.default)
						local val = Color3.new(c.r, c.g, c.b)
						data.callback(val, state)
					end
				end
			end
		end

		AbortLibrary.RegisterThemeElement(iconframe, "BackgroundColor3", function()
			if state then
				return ProfileData.Misc.InterfaceColor
			elseif hovering then
				return brighten(Colors.BackgroundDark)
			else
				return Colors.BackgroundDark
			end
		end)

		if not skipCallback and callback then
			callback(state)
		end
		AbortLibrary.RefreshTheme()
	end

	local toggleFrame, setToggleFunc = CreateToggle(option, defaultState, UDim2.new(0.85, 0, 0.5, 0), option, function(state)
		Config:Set("Toggles", configKey, state)
		updateToggleVisual(state, false)
	end, categoryName, title, "Module")
	updateToggleVisual(defaultState, true)

	local titlelabel, titleProps = CreateTextLabel(option, title, nil, UDim2.new(0.11, 0, 0.5, 0), {DynamicTruncate = true, MaxScale = 0.3, BackgroundTransparency = 1, TextSize = 16, TextColor = Colors.TextPrimary, TextXAlignment = Enum.TextXAlignment.Left, AnchorPoint = Vector2.new(0, 0.5)})
	desclabel, descProps = CreateTextLabel(option, desc, nil, nil, {DynamicTruncate = true, MaxScale = 0.35, BackgroundTransparency = 1, TextColor = Colors.TextTertiary, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, AnchorPoint = Vector2.new(0, 0.5)})
	controller = updateLabelsWidth(option, titlelabel, titleProps, desclabel, descProps)
	desclabel.Position = UDim2.new(0.138, titlelabel.Size.X.Offset, 0.5, 0)

	local savedKey = Config:Get("Keybinds", configKey, nil)
	if savedKey then
		KeybindSet(savedKey)
	end
	
	_G.AbortLoaded:Wait()
	ConnectionManager:Add(UserInputService, "keybind_clicked_"..configKey, UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		local currentKey = Config:Get("Keybinds", configKey, nil)
		if input.KeyCode == currentKey and not justassigned then
			local currentState = Config:Get("Toggles", configKey, false)
			local newState = not currentState
			Config:Set("Toggles", configKey, newState)
			updateToggleVisual(newState, false)
			if setToggleFunc then
				setToggleFunc(newState)
			end

			if not newState and not hovering then
				setHover(false)
			end
		else
			justassigned = false
		end
	end))

	return buttoninserts
end

AbortLibrary.CreateCategory = function(name)
	local homePage = bookmarkpages["home"]
	
	local categorybutton = CreateButton(homePage.Page:WaitForChild("categories"), name, UDim2.new(0.741, 0, 0.086, 0), nil, function() end, {TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1, LayoutOrder = Layout.LayoutOrder})
	Layout.LayoutOrder += 1
	categorybutton.Name = name

	local hoverframe = CreateFrame(categorybutton, UDim2.new(0, 0, 0, 2), UDim2.new(0, 0, 1, 0), false, {BackgroundColor = ProfileData.Misc.InterfaceColor, Name = "hoverframe"})
	AbortLibrary.RegisterThemeElement(hoverframe, "BackgroundColor3")
	CreateUICorner(hoverframe, 1, 0)

	local mainmenu = CreateScrollingFrame(homePage.Page, UDim2.new(0.676, 0, 0.829, 0), UDim2.new(0.18, 0, 0.414, 0), {AnchorPoint = Vector2.new(0, 0.5), Name = name .. "menu", Visible = false, BackgroundTransparency = 1, AutomaticCanvasSize = Enum.AutomaticSize.None})
	local mainmenulist = CreateAnimatedList(mainmenu, "Y", UDim.new(0.017, 0))

	if firstCategoryInit then
		HoverException(categorybutton, "add")
		activemenu = mainmenu
		hoverframe.Size = UDim2.new(0, categorybutton.TextBounds.X, 0, 2)
		categorybutton.TextColor3 = Colors.TextPrimary
		homePage.Page[name .. "menu"].Visible = true
		firstCategoryInit = false
	end

	ConnectionManager:Add(categorybutton, "category", categorybutton.MouseButton1Click:Connect(function()
		activemenu = mainmenu
		CreateTween(hoverframe, Layout.tweenInfo, {Size = UDim2.new(0, categorybutton.TextBounds.X, 0, 2)})
		HoverException(categorybutton, "add")

		CreateTween(categorybutton, Layout.tweenInfo, {TextColor3 = Colors.TextPrimary})
		homePage.Page[name .. "menu"].Visible = true

		for _, n in pairs(homePage.Page.categories:GetChildren()) do
			if n.Name ~= categorybutton.Name and n:FindFirstChild("hoverframe") then
				CreateTween(n.hoverframe, Layout.tweenInfo, {Size = UDim2.new(0, 0, 0, 2)})
				CreateTween(n, Layout.tweenInfo, {TextColor3 = Colors.TextSecondary})
				homePage.Page[n.Name .. "menu"].Visible = false
				HoverException(n, "remove")
			end
		end
	end))

	return {mainmenu, mainmenulist}
end


--[[ MAIN INIT ]]
function GUILoader.LoadGui()
	if not Layout.GuiRoot then return end
	local background, loadinglogo, loadingbar, barfill, outputtext, backgroundimage = GUILoader.LoadLoadingScreen()
	local topbar = GUILoader.LoadTopbar(background)
	local bookmarks = GUILoader.LoadBookmarks()	
	topbar.Visible = false
	bookmarks.Visible = false
	
	local event = Instance.new("BindableEvent")
	_G.AbortLoaded = event.Event
	
	function AbortLibrary.LoadOptions()
		AbortLibrary.AddColorPicker(settingslist, "GUI Theme", ProfileData.Misc.InterfaceColor, function(color)
			Config:Set("Misc", "InterfaceColor", color)
			AbortLibrary.RefreshTheme()
		end)

		local gui_bind_toggle, gui_bind_listener, gui_bind_input

		gui_bind_toggle = AbortLibrary.AddToggle(settingslist, "GUI Toggle bind", "", function(state)
			if gui_bind_listener then gui_bind_listener.Visible = state end

			if state then
				gui_bind_input = ConnectionManager:Add(UserInputService, gui_bind_toggle, UserInputService.InputBegan:Connect(function(input, gameProcessed)
					if gameProcessed then return end
					if input.KeyCode == Config:Get("Keybinds", "GUI", nil) then
						ToggleMinimize()
					end
				end))
			elseif gui_bind_input then
				gui_bind_input:Disconnect()
				gui_bind_input = nil		
			end
		end)

		gui_bind_listener = AbortLibrary.AddKeybindListener(settingslist, Config:Get("Keybinds", "GUI", nil), "", function(new_key)
			Config:Set("Keybinds", "GUI", new_key)
		end)

		gui_bind_listener.Visible = Config:Get("Toggles", gui_bind_toggle, false)

		local gui_uninject_toggle, gui_uninject_listener, gui_uninject_input

		gui_uninject_toggle = AbortLibrary.AddToggle(settingslist, "GUI Uninject bind", "", function(state)
			if gui_uninject_listener then gui_uninject_listener.Visible = state end

			if state then
				gui_uninject_input = ConnectionManager:Add(UserInputService, gui_uninject_toggle, UserInputService.InputBegan:Connect(function(input, gameProcessed)
					if gameProcessed then return end
					if input.KeyCode == Config:Get("Keybinds", "Uninject", nil) then
						ToggleMinimize(true)
						task.delay(0.15, function()
							AbortLibrary.DestroyRoot()
						end)
					end
				end))
			elseif gui_uninject_input then
				gui_uninject_input:Disconnect()
				gui_uninject_input = nil		
			end
		end)

		gui_uninject_listener = AbortLibrary.AddKeybindListener(settingslist,Config:Get("Keybinds", "Uninject", nil), "", function(new_key)
			Config:Set("Keybinds", "Uninject", new_key)
		end)

		gui_uninject_listener.Visible = Config:Get("Toggles", gui_uninject_toggle, false)
	end
	
	local totalItems = 4
	local loadedItems = 0

	local function updateProgress()
		loadedItems = loadedItems + 1
		local progress = math.min(loadedItems / totalItems, 1)
		CreateTween(barfill, TweenInfo.new(0.2), {Size = UDim2.new(progress, 0, 1, 0)})

		if loadedItems >= totalItems then
			topbar.Visible = true
			bookmarks.Visible = true

			CreateTween(topbar, TweenInfo.new(0.1), {Position=UDim2.new(0,0,0,0)})
			CreateTween(bookmarks, TweenInfo.new(0.1), {Position = UDim2.new(0, 0,0.089, 0)})

			CreateTween(loadingbar, TweenInfo.new(0.3), {BackgroundTransparency=1})
			CreateTween(barfill, TweenInfo.new(0.3), {BackgroundTransparency=1})
			CreateTween(outputtext, TweenInfo.new(0.3), {TextTransparency=1})
			CreateTween(loadinglogo, TweenInfo.new(0.3), {ImageTransparency=1}).Completed:Once(function()
				backgroundimage.ZIndex = 0
			end)
			event:Fire()
		end
	end

	task.spawn(function()
		AbortLibrary.LoadOptions()
		updateProgress()
	end)
	
	task.spawn(function()
		for i=0, totalItems-1 do
			task.wait(math.random(0.5,2))
			updateProgress()
		end
	end)

	CreateTween(barfill, TweenInfo.new(0.5), {Size=UDim2.new(0.3,0,1,0)})
end

AbortLibrary.CreateRoot()
GUILoader.LoadGui()


return AbortLibrary
