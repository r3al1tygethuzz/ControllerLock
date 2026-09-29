--// XENON CONTROLLER CAMERA LOCK + ESP
--// Full compact/mobile version
--// Controller-only lock input
--// AIM / ESP / WHITELIST tabs
--// Sticky Aim
--// Prediction X / Prediction Y
--// Adaptive Third Person Offset
--// Above-target correction
--// Smoothing
--// Controller rebinding
--// Persistent whitelist when executor filesystem APIs are available

--==================================================
-- SERVICES
--==================================================

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Camera = workspace.CurrentCamera

--==================================================
-- DUPLICATE EXECUTION CLEANUP
--==================================================

if _G.XenonCleanup then
	pcall(_G.XenonCleanup)
end

pcall(function()
	RunService:UnbindFromRenderStep("XenonCameraLock")
end)

local OldGui = PlayerGui:FindFirstChild("Xenon")
if OldGui then
	OldGui:Destroy()
end

--==================================================
-- CONFIG
--==================================================

local Config = {
	LockButton = Enum.KeyCode.ButtonY,

	CameraMode = "Third Person",

	AimOffset = 23.5,
	ReferenceDistance = 100,

	Smoothing = 0,

	PredictionX = 0.08,
	PredictionY = 0.08,

	MaxTargetDistance = 500,

	StickyAim = true,

	AboveTargetCorrection = true,
	AboveTargetStrength = 0.35,
	AboveTargetMaxCorrection = 20,

	ESPEnabled = false,
	ESPShowName = true,
	ESPShowOutline = true,
	ESPWhitelistCheck = true,

	AimbotWhitelistSkip = true,
}

--==================================================
-- STATE
--==================================================

local Locked = false
local LockedTarget = nil

local CurrentTab = "AIM"
local UIVisible = true
local Rebinding = false

local ESPObjects = {}
local PlayerConnections = {}

local Whitelist = {}

local WhitelistFile = "XenonWhitelist.json"

--==================================================
-- COLORS
--==================================================

local COLORS = {
	Background = Color3.fromRGB(10, 10, 10),
	Panel = Color3.fromRGB(15, 15, 15),
	Panel2 = Color3.fromRGB(20, 20, 20),

	White = Color3.fromRGB(245, 245, 245),
	Gray = Color3.fromRGB(145, 145, 145),
	DarkGray = Color3.fromRGB(45, 45, 45),

	Red = Color3.fromRGB(210, 35, 35),
	RedDark = Color3.fromRGB(125, 20, 20),

	Black = Color3.fromRGB(0, 0, 0),
}

--==================================================
-- UTILITY
--==================================================

local function Create(className, properties)
	local object = Instance.new(className)

	for property, value in pairs(properties or {}) do
		pcall(function()
			object[property] = value
		end)
	end

	return object
end

local function Round(object, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 10)
	corner.Parent = object
	return corner
end

local function Stroke(object, color, transparency, thickness)
	local outline = Instance.new("UIStroke")
	outline.Color = color or COLORS.DarkGray
	outline.Transparency = transparency or 0
	outline.Thickness = thickness or 1
	outline.Parent = object
	return outline
end

local function SafeDestroy(object)
	if object then
		pcall(function()
			object:Destroy()
		end)
	end
end

local function IsAlive(player)
	if not player then
		return false
	end

	local character = player.Character
	if not character then
		return false
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")

	return humanoid
		and root
		and humanoid.Health > 0
end

local function IsWhitelisted(player)
	if not player then
		return false
	end

	return Whitelist[tostring(player.UserId)] == true
end

--==================================================
-- WHITELIST STORAGE
--==================================================

local function SaveWhitelist()
	if not writefile then
		return
	end

	local data = {}

	for userId, enabled in pairs(Whitelist) do
		if enabled then
			table.insert(data, tonumber(userId))
		end
	end

	local encoded

	pcall(function()
		encoded = HttpService:JSONEncode(data)
	end)

	if encoded then
		pcall(function()
			writefile(WhitelistFile, encoded)
		end)
	end
end

local function LoadWhitelist()
	if not readfile or not isfile then
		return
	end

	local exists = false

	pcall(function()
		exists = isfile(WhitelistFile)
	end)

	if not exists then
		return
	end

	local content

	pcall(function()
		content = readfile(WhitelistFile)
	end)

	if not content then
		return
	end

	local success, data = pcall(function()
		return HttpService:JSONDecode(content)
	end)

	if success and type(data) == "table" then
		for _, userId in ipairs(data) do
			Whitelist[tostring(userId)] = true
		end
	end
end

LoadWhitelist()

--==================================================
-- TARGET FUNCTIONS
--==================================================

local function GetLocalRoot()
	local character = LocalPlayer.Character

	if not character then
		return nil
	end

	return character:FindFirstChild("HumanoidRootPart")
end

local function GetPredictedPosition(position, velocity)
	local X = position.X + (velocity.X * Config.PredictionX)

	-- Inverted Y prediction
	local Y = position.Y - (velocity.Y * Config.PredictionY)

	-- No Z prediction
	local Z = position.Z

	return Vector3.new(X, Y, Z)
end

local function GetAdaptiveOffset(root)
	if not root then
		return Config.AimOffset
	end

	local localRoot = GetLocalRoot()

	if not localRoot then
		return Config.AimOffset
	end

	local distance = (root.Position - localRoot.Position).Magnitude

	local adaptiveOffset =
		Config.AimOffset *
		(distance / Config.ReferenceDistance)

	return math.clamp(adaptiveOffset, -100, 100)
end

local function GetAimPosition(player)
	if not player or not IsAlive(player) then
		return nil
	end

	local character = player.Character
	local root = character:FindFirstChild("HumanoidRootPart")

	if not root then
		return nil
	end

	local velocity = root.AssemblyLinearVelocity

	if Config.CameraMode == "First Person" then
		local head = character:FindFirstChild("Head")

		if not head then
			return nil
		end

		return GetPredictedPosition(
			head.Position,
			head.AssemblyLinearVelocity
		)
	end

	local predicted = GetPredictedPosition(
		root.Position,
		velocity
	)

	local adaptiveOffset = GetAdaptiveOffset(root)

	local aimPosition =
		predicted -
		Vector3.new(0, adaptiveOffset, 0)

	-- Fix when camera/player is standing above target
	if Config.AboveTargetCorrection then
		local cameraY = Camera.CFrame.Position.Y
		local targetY = predicted.Y

		local verticalDifference =
			cameraY - targetY

		if verticalDifference > 0 then
			local correction =
				verticalDifference *
				Config.AboveTargetStrength

			correction = math.clamp(
				correction,
				0,
				Config.AboveTargetMaxCorrection
			)

			aimPosition =
				aimPosition +
				Vector3.new(0, correction, 0)
		end
	end

	return aimPosition
end

local function IsValidTarget(player)
	if not player then
		return false
	end

	if player == LocalPlayer then
		return false
	end

	if Config.AimbotWhitelistSkip and IsWhitelisted(player) then
		return false
	end

	if not IsAlive(player) then
		return false
	end

	local localRoot = GetLocalRoot()

	if not localRoot then
		return false
	end

	local targetRoot =
		player.Character:FindFirstChild("HumanoidRootPart")

	if not targetRoot then
		return false
	end

	local distance =
		(targetRoot.Position - localRoot.Position).Magnitude

	return distance <= Config.MaxTargetDistance
end

local function FindTarget()
	local closestPlayer = nil
	local closestDistance = math.huge

	local localRoot = GetLocalRoot()

	if not localRoot then
		return nil
	end

	local viewportSize = Camera.ViewportSize
	local center =
		Vector2.new(
			viewportSize.X / 2,
			viewportSize.Y / 2
		)

	for _, player in ipairs(Players:GetPlayers()) do
		if IsValidTarget(player) then
			local character = player.Character
			local root =
				character and
				character:FindFirstChild("HumanoidRootPart")

			if root then
				if Config.StickyAim then
					local screenPosition, visible =
						Camera:WorldToViewportPoint(
							root.Position
						)

					if visible then
						local screenDistance =
							(
								Vector2.new(
									screenPosition.X,
									screenPosition.Y
								) - center
							).Magnitude

						if screenDistance < closestDistance then
							closestDistance = screenDistance
							closestPlayer = player
						end
					end
				else
					local physicalDistance =
						(root.Position - localRoot.Position).Magnitude

					if physicalDistance < closestDistance then
						closestDistance = physicalDistance
						closestPlayer = player
					end
				end
			end
		end
	end

	return closestPlayer
end

--==================================================
-- UNLOCK
--==================================================

local function Unlock()
	Locked = false
	LockedTarget = nil
end

--==================================================
-- LOCK
--==================================================

local function ToggleLock()
	if Rebinding then
		return
	end

	if Locked then
		Unlock()
		return
	end

	local target = FindTarget()

	if target then
		LockedTarget = target
		Locked = true
	end
end

--==================================================
-- GUI
--==================================================

local Gui = Create("ScreenGui", {
	Name = "Xenon",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = PlayerGui,
})

--==================================================
-- RESPONSIVE SIZE
--==================================================

local CameraViewport = Camera.ViewportSize

local ViewWidth = CameraViewport.X
local ViewHeight = CameraViewport.Y

local WindowWidth
local WindowHeight

if ViewWidth <= 360 then
	WindowWidth = math.max(
		270,
		math.min(310, ViewWidth - 14)
	)

	WindowHeight = math.min(
		390,
		math.max(300, ViewHeight - 18)
	)

elseif ViewWidth <= 600 then
	WindowWidth = math.min(315, ViewWidth - 18)
	WindowHeight = math.min(400, ViewHeight - 20)

elseif ViewWidth <= 1000 then
	WindowWidth = 345
	WindowHeight = 470

else
	WindowWidth = 380
	WindowHeight = 520
end

--==================================================
-- MAIN WINDOW
--==================================================

local Main = Create("Frame", {
	Name = "Main",
	Parent = Gui,

	Size = UDim2.fromOffset(
		WindowWidth,
		WindowHeight
	),

	Position = UDim2.new(
		0.5,
		-WindowWidth / 2,
		0.5,
		-WindowHeight / 2
	),

	BackgroundColor3 = COLORS.Background,
	BorderSizePixel = 0,

	ClipsDescendants = true,

	ZIndex = 10,
})

Round(Main, 14)
Stroke(Main, COLORS.DarkGray, 0.25, 1)

--==================================================
-- TOP BAR
--==================================================

local TopBar = Create("Frame", {
	Name = "TopBar",
	Parent = Main,

	Size = UDim2.new(1, -12, 0, 42),
	Position = UDim2.fromOffset(6, 6),

	BackgroundColor3 = COLORS.Panel,
	BorderSizePixel = 0,

	ZIndex = 11,
})

Round(TopBar, 11)

local Title = Create("TextLabel", {
	Parent = TopBar,

	Size = UDim2.new(1, -60, 1, 0),
	Position = UDim2.fromOffset(14, 0),

	BackgroundTransparency = 1,

	Text = "XENON",
	Font = Enum.Font.GothamBold,
	TextSize = 16,
	TextColor3 = COLORS.White,
	TextXAlignment = Enum.TextXAlignment.Left,

	ZIndex = 12,
})

local Status = Create("TextLabel", {
	Parent = TopBar,

	Size = UDim2.fromOffset(70, 20),
	Position = UDim2.new(1, -88, 0.5, -10),

	BackgroundTransparency = 1,

	Text = "READY",
	Font = Enum.Font.GothamBold,
	TextSize = 9,
	TextColor3 = COLORS.Gray,

	ZIndex = 12,
})

local Close = Create("TextButton", {
	Parent = TopBar,

	Size = UDim2.fromOffset(32, 32),
	Position = UDim2.new(1, -36, 0.5, -16),

	BackgroundColor3 = COLORS.Panel2,
	BorderSizePixel = 0,

	Text = "×",
	Font = Enum.Font.GothamBold,
	TextSize = 20,
	TextColor3 = COLORS.White,

	AutoButtonColor = false,

	ZIndex = 13,
})

Round(Close, 9)

--==================================================
-- TAB BAR
--==================================================

local TabBar = Create("Frame", {
	Name = "TabBar",
	Parent = Main,

	Size = UDim2.new(1, -16, 0, 36),
	Position = UDim2.fromOffset(8, 52),

	BackgroundColor3 = COLORS.Panel,
	BorderSizePixel = 0,

	ZIndex = 11,
})

Round(TabBar, 10)

local TabPadding = Create("UIPadding", {
	Parent = TabBar,

	PaddingLeft = UDim.new(0, 3),
	PaddingRight = UDim.new(0, 3),
	PaddingTop = UDim.new(0, 3),
	PaddingBottom = UDim.new(0, 3),
})

local TabLayout = Create("UIListLayout", {
	Parent = TabBar,

	FillDirection = Enum.FillDirection.Horizontal,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,

	VerticalAlignment = Enum.VerticalAlignment.Center,

	Padding = UDim.new(0, 3),

	SortOrder = Enum.SortOrder.LayoutOrder,
})

local TabButtons = {}

local function CreateTab(name, order)
	local tabWidth =
		math.floor((WindowWidth - 38) / 3)

	local button = Create("TextButton", {
		Name = name .. "Tab",
		Parent = TabBar,

		Size = UDim2.fromOffset(
			tabWidth,
			30
		),

		BackgroundColor3 = COLORS.Panel2,
		BorderSizePixel = 0,

		Text = name,
		Font = Enum.Font.GothamBold,
		TextSize = 9,
		TextColor3 = COLORS.Gray,

		AutoButtonColor = false,

		LayoutOrder = order,

		ZIndex = 12,
	})

	Round(button, 8)

	local indicator = Create("Frame", {
		Name = "Indicator",
		Parent = button,

		Size = UDim2.new(1, -18, 0, 2),
		Position = UDim2.new(0, 9, 1, -5),

		BackgroundColor3 = COLORS.Red,
		BorderSizePixel = 0,

		Visible = false,

		ZIndex = 13,
	})

	Round(indicator, 2)

	TabButtons[name] = {
		Button = button,
		Indicator = indicator,
	}

	return button
end

CreateTab("AIM", 1)
CreateTab("ESP", 2)
CreateTab("WHITELIST", 3)

--==================================================
-- PAGES
--==================================================

local Pages = Create("Frame", {
	Name = "Pages",
	Parent = Main,

	Size = UDim2.new(
		1,
		-16,
		1,
		-98
	),

	Position = UDim2.fromOffset(
		8,
		92
	),

	BackgroundTransparency = 1,

	ZIndex = 11,
})

--==================================================
-- PAGE CREATION
--==================================================

local function CreatePage(name)
	local page = Create("ScrollingFrame", {
		Name = name .. "Page",
		Parent = Pages,

		Size = UDim2.fromScale(1, 1),

		BackgroundTransparency = 1,

		BorderSizePixel = 0,

		ScrollBarThickness = 3,
		ScrollBarImageColor3 = COLORS.Red,

		CanvasSize = UDim2.new(0, 0, 0, 0),

		AutomaticCanvasSize = Enum.AutomaticSize.Y,

		ScrollingDirection = Enum.ScrollingDirection.Y,

		Visible = false,

		ZIndex = 11,
	})

	Create("UIPadding", {
		Parent = page,

		PaddingLeft = UDim.new(0, 2),
		PaddingRight = UDim.new(0, 2),
		PaddingTop = UDim.new(0, 2),
		PaddingBottom = UDim.new(0, 8),
	})

	Create("UIListLayout", {
		Parent = page,

		Padding = UDim.new(0, 7),

		SortOrder = Enum.SortOrder.LayoutOrder,
	})

	return page
end

local AimPage = CreatePage("AIM")
local ESPPage = CreatePage("ESP")
local WhitelistPage = CreatePage("WHITELIST")

--==================================================
-- UI HELPERS
--==================================================

local function CreateSection(parent, text)
	local label = Create("TextLabel", {
		Parent = parent,

		Size = UDim2.new(1, -4, 0, 22),

		BackgroundTransparency = 1,

		Text = text,
		Font = Enum.Font.GothamBold,
		TextSize = 9,
		TextColor3 = COLORS.Red,

		TextXAlignment = Enum.TextXAlignment.Left,

		ZIndex = 12,
	})

	return label
end

local function CreateRow(parent, title, subtitle)
	local row = Create("Frame", {
		Parent = parent,

		Size = UDim2.new(1, -4, 0, 44),

		BackgroundColor3 = COLORS.Panel,
		BorderSizePixel = 0,

		ZIndex = 12,
	})

	Round(row, 9)

	local titleLabel = Create("TextLabel", {
		Parent = row,

		Size = UDim2.new(1, -100, 0, 19),
		Position = UDim2.fromOffset(10, 4),

		BackgroundTransparency = 1,

		Text = title,
		Font = Enum.Font.GothamSemibold,
		TextSize = 10,
		TextColor3 = COLORS.White,

		TextXAlignment = Enum.TextXAlignment.Left,

		ZIndex = 13,
	})

	local subLabel = Create("TextLabel", {
		Parent = row,

		Size = UDim2.new(1, -100, 0, 15),
		Position = UDim2.fromOffset(10, 23),

		BackgroundTransparency = 1,

		Text = subtitle or "",
		Font = Enum.Font.Gotham,
		TextSize = 7,
		TextColor3 = COLORS.Gray,

		TextXAlignment = Enum.TextXAlignment.Left,

		ZIndex = 13,
	})

	return row
end

local function CreateToggle(parent, title, subtitle, initial, callback)
	local row = CreateRow(parent, title, subtitle)

	local button = Create("TextButton", {
		Parent = row,

		Size = UDim2.fromOffset(54, 25),
		Position = UDim2.new(1, -64, 0.5, -12.5),

		BackgroundColor3 =
			initial and COLORS.Red or COLORS.DarkGray,

		BorderSizePixel = 0,

		Text = initial and "ON" or "OFF",
		Font = Enum.Font.GothamBold,
		TextSize = 8,

		TextColor3 = COLORS.White,

		AutoButtonColor = false,

		ZIndex = 14,
	})

	Round(button, 8)

	local state = initial

	local function Update(value)
		state = value

		button.Text = value and "ON" or "OFF"

		button.BackgroundColor3 =
			value and COLORS.Red or COLORS.DarkGray

		if callback then
			callback(value)
		end
	end

	button.Activated:Connect(function()
		Update(not state)
	end)

	return row, button, Update
end

local function CreateTextBox(parent, title, subtitle, value, callback)
	local row = CreateRow(parent, title, subtitle)

	local box = Create("TextBox", {
		Parent = row,

		Size = UDim2.fromOffset(72, 27),
		Position = UDim2.new(1, -82, 0.5, -13.5),

		BackgroundColor3 = COLORS.Panel2,
		BorderSizePixel = 0,

		Text = tostring(value),

		Font = Enum.Font.GothamSemibold,
		TextSize = 9,
		TextColor3 = COLORS.White,

		ClearTextOnFocus = false,

		TextXAlignment = Enum.TextXAlignment.Center,

		ZIndex = 14,
	})

	Round(box, 8)
	Stroke(box, COLORS.DarkGray, 0.35, 1)

	box.FocusLost:Connect(function()
		local number = tonumber(box.Text)

		if number then
			callback(number)
		else
			box.Text = tostring(value)
		end
	end)

	return row, box
end

local function CreateDropdown(parent, title, subtitle, options, current, callback)
	local row = CreateRow(parent, title, subtitle)

	local button = Create("TextButton", {
		Parent = row,

		Size = UDim2.fromOffset(110, 27),
		Position = UDim2.new(1, -120, 0.5, -13.5),

		BackgroundColor3 = COLORS.Panel2,
		BorderSizePixel = 0,

		Text = current,

		Font = Enum.Font.GothamSemibold,
		TextSize = 8,
		TextColor3 = COLORS.White,

		AutoButtonColor = false,

		ZIndex = 14,
	})

	Round(button, 8)

	local index = 1

	for i, option in ipairs(options) do
		if option == current then
			index = i
			break
		end
	end

	button.Activated:Connect(function()
		index += 1

		if index > #options then
			index = 1
		end

		local selected = options[index]

		button.Text = selected

		callback(selected)
	end)

	return row, button
end

local function CreateAction(parent, title, subtitle, text, callback)
	local row = CreateRow(parent, title, subtitle)

	local button = Create("TextButton", {
		Parent = row,

		Size = UDim2.fromOffset(100, 27),
		Position = UDim2.new(1, -110, 0.5, -13.5),

		BackgroundColor3 = COLORS.Red,
		BorderSizePixel = 0,

		Text = text,

		Font = Enum.Font.GothamBold,
		TextSize = 8,
		TextColor3 = COLORS.White,

		AutoButtonColor = false,

		ZIndex = 14,
	})

	Round(button, 8)

	button.Activated:Connect(callback)

	return row, button
end

--==================================================
-- AIM PAGE
--==================================================

CreateSection(AimPage, "CAMERA")

CreateDropdown(
	AimPage,
	"Camera Mode",
	"Choose first or third person",
	{"First Person", "Third Person"},
	Config.CameraMode,
	function(value)
		Config.CameraMode = value
	end
)

CreateTextBox(
	AimPage,
	"Third Person Offset",
	"Positive = below / negative = above",
	Config.AimOffset,
	function(value)
		Config.AimOffset = math.clamp(value, -100, 100)
	end
)

CreateTextBox(
	AimPage,
	"Smoothing",
	"0 = instant lock",
	Config.Smoothing,
	function(value)
		Config.Smoothing = math.max(0, value)
	end
)

CreateSection(AimPage, "PREDICTION")

CreateTextBox(
	AimPage,
	"Prediction X",
	"Horizontal prediction",
	Config.PredictionX,
	function(value)
		Config.PredictionX = value
	end
)

CreateTextBox(
	AimPage,
	"Prediction Y",
	"Inverted vertical prediction",
	Config.PredictionY,
	function(value)
		Config.PredictionY = value
	end
)

CreateSection(AimPage, "TARGETING")

CreateToggle(
	AimPage,
	"Sticky Aim",
	"ON = closest to controller/camera cursor",
	Config.StickyAim,
	function(value)
		Config.StickyAim = value
	end
)

CreateToggle(
	AimPage,
	"Aimbot Whitelist Skip",
	"Ignore players marked in whitelist",
	Config.AimbotWhitelistSkip,
	function(value)
		Config.AimbotWhitelistSkip = value

		if LockedTarget and IsWhitelisted(LockedTarget) then
			Unlock()
		end
	end
)

CreateAction(
	AimPage,
	"Lock Button",
	"Controller-only lock input",
	Config.LockButton.Name,
	function()
		if Rebinding then
			return
		end

		Rebinding = true
	end
)

CreateSection(AimPage, "CONTROLLER")

local ControllerInfo = Create("TextLabel", {
	Parent = AimPage,

	Size = UDim2.new(1, -4, 0, 50),

	BackgroundColor3 = COLORS.Panel,
	BorderSizePixel = 0,

	Text =
		"LOCK: " .. Config.LockButton.Name ..
		"\nPress Set Lock Button, then press a supported controller input.",

	Font = Enum.Font.Gotham,
	TextSize = 8,
	TextColor3 = COLORS.Gray,

	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Center,

	ZIndex = 12,
})

Round(ControllerInfo, 9)

CreateSection(AimPage, "CORRECTION")

CreateToggle(
	AimPage,
	"Above Target Correction",
	"Corrects when camera is higher than target",
	Config.AboveTargetCorrection,
	function(value)
		Config.AboveTargetCorrection = value
	end
)

CreateTextBox(
	AimPage,
	"Correction Strength",
	"Vertical correction multiplier",
	Config.AboveTargetStrength,
	function(value)
		Config.AboveTargetStrength = math.max(0, value)
	end
)

CreateTextBox(
	AimPage,
	"Max Correction",
	"Maximum vertical correction",
	Config.AboveTargetMaxCorrection,
	function(value)
		Config.AboveTargetMaxCorrection =
			math.max(0, value)
	end
)

--==================================================
-- ESP PAGE
--==================================================

CreateSection(ESPPage, "ESP")

CreateToggle(
	ESPPage,
	"ESP Enabled",
	"Enable player ESP",
	Config.ESPEnabled,
	function(value)
		Config.ESPEnabled = value
	end
)

CreateToggle(
	ESPPage,
	"Show Name",
	"Show player name above head",
	Config.ESPShowName,
	function(value)
		Config.ESPShowName = value
	end
)

CreateToggle(
	ESPPage,
	"Show Outline",
	"Show team-colored outline",
	Config.ESPShowOutline,
	function(value)
		Config.ESPShowOutline = value
	end
)

CreateToggle(
	ESPPage,
	"ESP Whitelist Check",
	"Hide ESP for whitelisted players",
	Config.ESPWhitelistCheck,
	function(value)
		Config.ESPWhitelistCheck = value
	end
)

CreateSection(ESPPage, "STYLE")

local ESPInfo = Create("TextLabel", {
	Parent = ESPPage,

	Size = UDim2.new(1, -4, 0, 68),

	BackgroundColor3 = COLORS.Panel,
	BorderSizePixel = 0,

	Text =
		"XENON ESP\n" ..
		"• Gotham font\n" ..
		"• Team-colored name / outline\n" ..
		"• Distance shown at feet\n" ..
		"• Distance updates every few frames",

	Font = Enum.Font.Gotham,
	TextSize = 8,
	TextColor3 = COLORS.Gray,

	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Center,

	ZIndex = 12,
})

Round(ESPInfo, 9)

--==================================================
-- WHITELIST PAGE
--==================================================

CreateSection(
	WhitelistPage,
	"SERVER WHITELIST"
)

local WhitelistInfo = Create("TextLabel", {
	Parent = WhitelistPage,

	Size = UDim2.new(1, -4, 0, 42),

	BackgroundColor3 = COLORS.Panel,
	BorderSizePixel = 0,

	Text =
		"Tap a player to toggle whitelist.\n" ..
		"Grey = normal   •   Red = whitelisted",

	Font = Enum.Font.Gotham,
	TextSize = 8,
	TextColor3 = COLORS.Gray,

	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Center,

	ZIndex = 12,
})

Round(WhitelistInfo, 9)

local WhitelistList = Create("Frame", {
	Parent = WhitelistPage,

	Size = UDim2.new(1, -4, 0, 0),

	BackgroundTransparency = 1,

	AutomaticSize = Enum.AutomaticSize.Y,

	ZIndex = 12,
})

Create("UIListLayout", {
	Parent = WhitelistList,

	Padding = UDim.new(0, 6),

	SortOrder = Enum.SortOrder.Name,
})

local function RefreshWhitelistUI()
	for _, child in ipairs(WhitelistList:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end

	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer then
			local whitelisted =
				IsWhitelisted(player)

			local button = Create("TextButton", {
				Name = player.Name,
				Parent = WhitelistList,

				Size = UDim2.new(1, 0, 0, 40),

				BackgroundColor3 =
					whitelisted
					and COLORS.Red
					or COLORS.Panel,

				BorderSizePixel = 0,

				Text = player.DisplayName ..
					"  @" ..
					player.Name,

				Font = Enum.Font.GothamSemibold,
				TextSize = 9,

				TextColor3 = COLORS.White,

				TextXAlignment = Enum.TextXAlignment.Left,

				AutoButtonColor = false,

				ZIndex = 13,
			})

			Round(button, 9)

			Create("UIPadding", {
				Parent = button,
				PaddingLeft = UDim.new(0, 12),
			})

			button.Activated:Connect(function()
				local key = tostring(player.UserId)

				Whitelist[key] =
					not IsWhitelisted(player)

				SaveWhitelist()

				if LockedTarget == player
					and Config.AimbotWhitelistSkip
					and IsWhitelisted(player)
				then
					Unlock()
				end

				RefreshWhitelistUI()
			end)
		end
	end
end

RefreshWhitelistUI()

--==================================================
-- TAB SWITCHING
--==================================================

local PagesByName = {
	AIM = AimPage,
	ESP = ESPPage,
	WHITELIST = WhitelistPage,
}

local function SetTab(tabName)
	CurrentTab = tabName

	for name, page in pairs(PagesByName) do
		page.Visible = name == tabName
	end

	for name, data in pairs(TabButtons) do
		local active = name == tabName

		data.Button.BackgroundColor3 =
			active
			and COLORS.Red
			or COLORS.Panel2

		data.Button.TextColor3 =
			active
			and COLORS.White
			or COLORS.Gray

		data.Indicator.Visible = active
	end
end

for name, data in pairs(TabButtons) do
	data.Button.Activated:Connect(function()
		SetTab(name)
	end)
end

SetTab("AIM")

--==================================================
-- DRAGGING
--==================================================

local Dragging = false
local DragStart
local StartPosition

TopBar.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
	then
		Dragging = true
		DragStart = input.Position
		StartPosition = Main.Position

		input.Changed:Connect(function()
			if input.UserInputState ==
				Enum.UserInputState.End
			then
				Dragging = false
			end
		end)
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if not Dragging then
		return
	end

	if input.UserInputType ~= Enum.UserInputType.MouseMovement
		and input.UserInputType ~= Enum.UserInputType.Touch
	then
		return
	end

	local delta =
		input.Position - DragStart

	Main.Position =
		UDim2.new(
			StartPosition.X.Scale,
			StartPosition.X.Offset + delta.X,
			StartPosition.Y.Scale,
			StartPosition.Y.Offset + delta.Y
		)
end)

--==================================================
-- FLOATING BUTTON
--==================================================

local Floating = Create("TextButton", {
	Name = "XenonFloating",

	Parent = Gui,

	Size = UDim2.fromOffset(42, 42),

	Position = UDim2.new(
		1,
		-54,
		0,
		12
	),

	BackgroundColor3 = COLORS.Red,

	BorderSizePixel = 0,

	Text = "X",

	Font = Enum.Font.GothamBold,
	TextSize = 15,
	TextColor3 = COLORS.White,

	AutoButtonColor = false,

	Visible = false,

	ZIndex = 100,
})

Round(Floating, 12)

Stroke(Floating, COLORS.White, 0.8, 1)

local function SetUIVisible(value)
	UIVisible = value

	Main.Visible = value
	Floating.Visible = not value
end

Close.Activated:Connect(function()
	SetUIVisible(false)
end)

Floating.Activated:Connect(function()
	SetUIVisible(true)
end)

--==================================================
-- CONTROLLER INPUT
--==================================================

local SupportedButtons = {
	[Enum.KeyCode.ButtonA] = true,
	[Enum.KeyCode.ButtonB] = true,
	[Enum.KeyCode.ButtonX] = true,
	[Enum.KeyCode.ButtonY] = true,

	[Enum.KeyCode.DPadUp] = true,
	[Enum.KeyCode.DPadDown] = true,
	[Enum.KeyCode.DPadLeft] = true,
	[Enum.KeyCode.DPadRight] = true,

	[Enum.KeyCode.ButtonL1] = true,
	[Enum.KeyCode.ButtonR1] = true,

	[Enum.KeyCode.ButtonSelect] = true,
	[Enum.KeyCode.ButtonStart] = true,

	[Enum.KeyCode.ButtonL3] = true,
	[Enum.KeyCode.ButtonR3] = true,

	[Enum.KeyCode.Thumbstick1] = true,
	[Enum.KeyCode.Thumbstick2] = true,

	[Enum.KeyCode.ButtonL2] = true,
	[Enum.KeyCode.ButtonR2] = true,
}

local function SetLockButton(keyCode)
	Config.LockButton = keyCode
	Rebinding = false

	ControllerInfo.Text =
		"LOCK: " ..
		Config.LockButton.Name ..
		"\nPress Set Lock Button, then press a supported controller input."
end

UserInputService.InputBegan:Connect(function(input, processed)
	if input.UserInputType ~= Enum.UserInputType.Gamepad1 then
		return
	end

	if not SupportedButtons[input.KeyCode] then
		return
	end

	if Rebinding then
		SetLockButton(input.KeyCode)
		return
	end

	if input.KeyCode == Config.LockButton then
		ToggleLock()
	end
end)

UserInputService.InputChanged:Connect(function(input, processed)
	if not Rebinding then
		return
	end

	if input.UserInputType ~= Enum.UserInputType.Gamepad1 then
		return
	end

	if input.KeyCode ~= Enum.KeyCode.Thumbstick1
		and input.KeyCode ~= Enum.KeyCode.Thumbstick2
	then
		return
	end

	if input.Position.Magnitude > 0.65 then
		SetLockButton(input.KeyCode)
	end
end)

--==================================================
-- ESP
--==================================================

local function GetTeamColor(player)
	if player.Team then
		return player.Team.TeamColor.Color
	end

	return COLORS.White
end

local function ApplyESPColor(data, player)
	if not data then
		return
	end

	local color = GetTeamColor(player)

	if data.NameLabel then
		data.NameLabel.TextColor3 = color
	end

	if data.Highlight then
		data.Highlight.OutlineColor = color
	end
end

local function RemoveESP(player)
	local data = ESPObjects[player]

	if not data then
		return
	end

	if data.NameBillboard then
		data.NameBillboard:Destroy()
	end

	if data.DistanceBillboard then
		data.DistanceBillboard:Destroy()
	end

	if data.Highlight then
		data.Highlight:Destroy()
	end

	ESPObjects[player] = nil
end

local function CreateESP(player)
	if player == LocalPlayer then
		return
	end

	RemoveESP(player)

	if not Config.ESPEnabled then
		return
	end

	if Config.ESPWhitelistCheck
		and IsWhitelisted(player)
	then
		return
	end

	if not player.Character then
		return
	end

	local character = player.Character
	local head = character:FindFirstChild("Head")
	local root = character:FindFirstChild("HumanoidRootPart")

	if not head or not root then
		return
	end

	local data = {}

	-- Name
	if Config.ESPShowName then
		local billboard = Create("BillboardGui", {
			Name = "XenonName",
			Parent = head,

			Adornee = head,

			Size = UDim2.fromOffset(180, 24),

			StudsOffset = Vector3.new(0, 2.8, 0),

			AlwaysOnTop = true,

			ResetOnSpawn = false,

			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		})

		local label = Create("TextLabel", {
			Parent = billboard,

			Size = UDim2.fromScale(1, 1),

			BackgroundTransparency = 1,

			Text = player.Name,

			Font = Enum.Font.Gotham,

			TextSize = 9,

			TextColor3 = GetTeamColor(player),

			TextStrokeTransparency = 0.2,

			TextStrokeColor3 = COLORS.Black,

			TextXAlignment = Enum.TextXAlignment.Center,
		})

		data.NameBillboard = billboard
		data.NameLabel = label
	end

	-- Distance
	local distanceBillboard = Create("BillboardGui", {
		Name = "XenonDistance",
		Parent = root,

		Adornee = root,

		Size = UDim2.fromOffset(180, 22),

		StudsOffset = Vector3.new(0, -3, 0),

		AlwaysOnTop = true,

		ResetOnSpawn = false,

		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})

	local distanceLabel = Create("TextLabel", {
		Parent = distanceBillboard,

		Size = UDim2.fromScale(1, 1),

		BackgroundTransparency = 1,

		Text = "0 studs",

		Font = Enum.Font.Gotham,

		TextSize = 9,

		TextColor3 = GetTeamColor(player),

		TextStrokeTransparency = 0.2,

		TextStrokeColor3 = COLORS.Black,

		TextXAlignment = Enum.TextXAlignment.Center,
	})

	data.DistanceBillboard = distanceBillboard
	data.DistanceLabel = distanceLabel

	-- Outline
	if Config.ESPShowOutline then
		local highlight = Create("Highlight", {
			Name = "XenonHighlight",
			Parent = character,

			Adornee = character,

			DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,

			FillTransparency = 1,

			OutlineTransparency = 0,

			OutlineColor = GetTeamColor(player),
		})

		data.Highlight = highlight
	end

	ESPObjects[player] = data

	ApplyESPColor(data, player)
end

local function RefreshESP(player)
	if player == LocalPlayer then
		return
	end

	if not Config.ESPEnabled then
		RemoveESP(player)
		return
	end

	if Config.ESPWhitelistCheck
		and IsWhitelisted(player)
	then
		RemoveESP(player)
		return
	end

	CreateESP(player)
end

local function RefreshAllESP()
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer then
			RefreshESP(player)
		end
	end
end

--==================================================
-- PLAYER ESP CONNECTIONS
--==================================================

local function ConnectPlayer(player)
	if player == LocalPlayer then
		return
	end

	if PlayerConnections[player] then
		for _, connection in ipairs(PlayerConnections[player]) do
			pcall(function()
				connection:Disconnect()
			end)
		end
	end

	PlayerConnections[player] = {}

	table.insert(
		PlayerConnections[player],
		player.CharacterAdded:Connect(function()
			task.wait(0.15)

			RemoveESP(player)

			if Config.ESPEnabled then
				CreateESP(player)
			end

			if LockedTarget == player then
				Unlock()
			end
		end)
	)

	table.insert(
		PlayerConnections[player],
		player:GetPropertyChangedSignal("Team"):Connect(function()
			local data = ESPObjects[player]

			if data then
				ApplyESPColor(data, player)
			end
		end)
	)
end

for _, player in ipairs(Players:GetPlayers()) do
	ConnectPlayer(player)
end

Players.PlayerAdded:Connect(function(player)
	ConnectPlayer(player)

	task.wait(0.2)

	RefreshESP(player)

	RefreshWhitelistUI()
end)

Players.PlayerRemoving:Connect(function(player)
	RemoveESP(player)

	if LockedTarget == player then
		Unlock()
	end

	if PlayerConnections[player] then
		for _, connection in ipairs(PlayerConnections[player]) do
			pcall(function()
				connection:Disconnect()
			end)
		end

		PlayerConnections[player] = nil
	end

	RefreshWhitelistUI()
end)

--==================================================
-- LOCAL CHARACTER RESET
--==================================================

LocalPlayer.CharacterAdded:Connect(function()
	Unlock()
end)

--==================================================
-- ESP UPDATE LOOP
--==================================================

local ESPCounter = 0

RunService.Heartbeat:Connect(function()
	if not Config.ESPEnabled then
		return
	end

	ESPCounter += 1

	if ESPCounter % 4 ~= 0 then
		return
	end

	local localRoot = GetLocalRoot()

	if not localRoot then
		return
	end

	for player, data in pairs(ESPObjects) do
		if not player.Parent then
			RemoveESP(player)
			continue
		end

		if not IsAlive(player) then
			RemoveESP(player)
			continue
		end

		if Config.ESPWhitelistCheck
			and IsWhitelisted(player)
		then
			RemoveESP(player)
			continue
		end

		local root =
			player.Character
			and player.Character:FindFirstChild(
				"HumanoidRootPart"
			)

		if root and data.DistanceLabel then
			local distance =
				(root.Position - localRoot.Position).Magnitude

			data.DistanceLabel.Text =
				math.floor(distance) ..
				" studs"
		end

		ApplyESPColor(data, player)
	end
end)

--==================================================
-- ESP CONFIG REFRESH
--==================================================

task.spawn(function()
	local lastEnabled = Config.ESPEnabled
	local lastName = Config.ESPShowName
	local lastOutline = Config.ESPShowOutline
	local lastWhitelist = Config.ESPWhitelistCheck

	while Gui.Parent do
		task.wait(0.2)

		if
			lastEnabled ~= Config.ESPEnabled
			or lastName ~= Config.ESPShowName
			or lastOutline ~= Config.ESPShowOutline
			or lastWhitelist ~= Config.ESPWhitelistCheck
		then
			lastEnabled = Config.ESPEnabled
			lastName = Config.ESPShowName
			lastOutline = Config.ESPShowOutline
			lastWhitelist = Config.ESPWhitelistCheck

			RefreshAllESP()
		end
	end
end)

--==================================================
-- CAMERA LOCK
--==================================================

RunService:BindToRenderStep(
	"XenonCameraLock",
	Enum.RenderPriority.Last.Value,
	function()
		if not Locked then
			Status.Text = "READY"
			Status.TextColor3 = COLORS.Gray
			return
		end

		if not LockedTarget then
			Unlock()
			return
		end

		if Config.AimbotWhitelistSkip
			and IsWhitelisted(LockedTarget)
		then
			Unlock()
			return
		end

		if not IsValidTarget(LockedTarget) then
			Unlock()
			return
		end

		local aimPosition =
			GetAimPosition(LockedTarget)

		if not aimPosition then
			Unlock()
			return
		end

		local cameraPosition =
			Camera.CFrame.Position

		local desiredCFrame =
			CFrame.lookAt(
				cameraPosition,
				aimPosition
			)

		if Config.Smoothing <= 0 then
			Camera.CFrame = desiredCFrame
		else
			local alpha =
				math.clamp(
					1 / Config.Smoothing,
					0.01,
					1
				)

			Camera.CFrame =
				Camera.CFrame:Lerp(
					desiredCFrame,
					alpha
				)
		end

		Status.Text = "LOCKED"
		Status.TextColor3 = COLORS.Red
	end
)

--==================================================
-- CLEANUP
--==================================================

local Cleaned = false

_G.XenonCleanup = function()
	if Cleaned then
		return
	end

	Cleaned = true

	Unlock()

	pcall(function()
		RunService:UnbindFromRenderStep(
			"XenonCameraLock"
		)
	end)

	for player, connections in pairs(PlayerConnections) do
		for _, connection in ipairs(connections) do
			pcall(function()
				connection:Disconnect()
			end)
		end

		PlayerConnections[player] = nil
	end

	for player in pairs(ESPObjects) do
		RemoveESP(player)
	end

	SafeDestroy(Gui)

	if _G.XenonCleanup then
		_G.XenonCleanup = nil
	end
end

--==================================================
-- INITIAL ESP
--==================================================

if Config.ESPEnabled then
	RefreshAllESP()
end

--==================================================
-- FINAL UI STATE
--==================================================

SetUIVisible(true)

print("Xenon Controller Camera Lock loaded.")
print("Lock Button:", Config.LockButton.Name)
