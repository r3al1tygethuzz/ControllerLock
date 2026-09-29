--============================================================
-- XENON
-- CONTROLLER CAMERA LOCK / ESP
-- FIXED AIM-POINT METHOD
--============================================================

--============================================================
-- SERVICES
--============================================================

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local GuiService = game:GetService("GuiService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Camera = workspace.CurrentCamera

--============================================================
-- CLEAN PREVIOUS XENON
--============================================================

if _G.XenonCleanup then
	pcall(_G.XenonCleanup)
end

pcall(function()
	RunService:UnbindFromRenderStep("XenonCameraLock")
end)

local ExistingGui = PlayerGui:FindFirstChild("Xenon")

if ExistingGui then
	ExistingGui:Destroy()
end

--============================================================
-- CONFIG
--============================================================

local Config = {

	-- Controller
	LockButton = Enum.KeyCode.ButtonY,

	-- Camera
	CameraMode = "Third Person",

	-- Fixed third-person vertical aim offset
	-- Positive = below root
	-- Negative = above root
	AimOffset = 23.5,

	-- Prediction
	PredictionX = 0.08,
	PredictionY = 0.08,

	-- Camera smoothing
	Smoothing = 0,

	-- Targeting
	MaxTargetDistance = 500,
	StickyAim = true,

	-- Whitelist
	AimbotWhitelistSkip = true,

	-- ESP
	ESPEnabled = false,
	ESPShowName = true,
	ESPShowOutline = true,
	ESPWhitelistCheck = true,
}

--============================================================
-- STATE
--============================================================

local Locked = false
local LockedTarget = nil

-- THIS IS THE IMPORTANT PART
-- The aim offset is captured once when locking.
local LockedAimOffset = 0

local CurrentTab = "AIM"
local UIVisible = true
local Rebinding = false

local ESPObjects = {}
local PlayerConnections = {}

local Whitelist = {}

local WhitelistFile = "XenonWhitelist.json"

--============================================================
-- COLORS
--============================================================

local COLORS = {
	Background = Color3.fromRGB(9, 9, 9),
	Panel = Color3.fromRGB(15, 15, 15),
	Panel2 = Color3.fromRGB(23, 23, 23),

	White = Color3.fromRGB(245, 245, 245),
	Gray = Color3.fromRGB(145, 145, 145),
	DarkGray = Color3.fromRGB(48, 48, 48),

	Red = Color3.fromRGB(215, 35, 35),
	Black = Color3.fromRGB(0, 0, 0),
}

--============================================================
-- UTILITY
--============================================================

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

	corner.CornerRadius =
		UDim.new(0, radius)

	corner.Parent = object

	return corner
end

local function AddStroke(
	object,
	color,
	transparency,
	thickness
)

	local stroke = Instance.new("UIStroke")

	stroke.Color = color
	stroke.Transparency = transparency or 0
	stroke.Thickness = thickness or 1

	stroke.Parent = object

	return stroke
end

--============================================================
-- PLAYER CHECKS
--============================================================

local function IsAlive(player)

	if not player then
		return false
	end

	local character = player.Character

	if not character then
		return false
	end

	local humanoid =
		character:FindFirstChildOfClass(
			"Humanoid"
		)

	local root =
		character:FindFirstChild(
			"HumanoidRootPart"
		)

	return
		humanoid ~= nil
		and root ~= nil
		and humanoid.Health > 0
end

local function GetLocalRoot()

	local character =
		LocalPlayer.Character

	if not character then
		return nil
	end

	return character:FindFirstChild(
		"HumanoidRootPart"
	)
end

--============================================================
-- WHITELIST
--============================================================

local function IsWhitelisted(player)

	if not player then
		return false
	end

	return
		Whitelist[
			tostring(player.UserId)
		] == true
end

--============================================================
-- LOAD WHITELIST
--============================================================

local function LoadWhitelist()

	if not readfile or not isfile then
		return
	end

	local exists = false

	pcall(function()
		exists = isfile(
			WhitelistFile
		)
	end)

	if not exists then
		return
	end

	local content

	pcall(function()
		content = readfile(
			WhitelistFile
		)
	end)

	if not content then
		return
	end

	local success, data =
		pcall(function()
			return HttpService:JSONDecode(
				content
			)
		end)

	if success and type(data) == "table" then

		for _, userId in ipairs(data) do

			Whitelist[
				tostring(userId)
			] = true

		end

	end
end

--============================================================
-- SAVE WHITELIST
--============================================================

local function SaveWhitelist()

	if not writefile then
		return
	end

	local list = {}

	for userId, enabled in pairs(
		Whitelist
	) do

		if enabled then
			table.insert(
				list,
				tonumber(userId)
			)
		end

	end

	local encoded

	pcall(function()

		encoded =
			HttpService:JSONEncode(
				list
			)

	end)

	if encoded then

		pcall(function()

			writefile(
				WhitelistFile,
				encoded
			)

		end)

	end
end

LoadWhitelist()

--============================================================
-- PREDICTION
--============================================================

local function GetPredictedPosition(
	position,
	velocity
)

	-- X = normal prediction
	local X =
		position.X +
		(
			velocity.X *
			Config.PredictionX
		)

	-- Y = inverted prediction
	local Y =
		position.Y -
		(
			velocity.Y *
			Config.PredictionY
		)

	-- Z = NO prediction
	local Z =
		position.Z

	return Vector3.new(
		X,
		Y,
		Z
	)
end

--============================================================
-- FIXED AIM POSITION
--============================================================

local function GetFixedThirdPersonAimPosition(
	player
)

	if not player then
		return nil
	end

	local character =
		player.Character

	if not character then
		return nil
	end

	local root =
		character:FindFirstChild(
			"HumanoidRootPart"
		)

	if not root then
		return nil
	end

	-- Prediction happens from root.
	local predicted =
		GetPredictedPosition(
			root.Position,
			root.AssemblyLinearVelocity
		)

	-- IMPORTANT:
	-- This is a FIXED world-space vertical offset.
	--
	-- It does NOT:
	-- * use camera height
	-- * use target distance
	-- * adapt every frame
	-- * move upward because the camera is above target
	--
	-- The same offset is maintained for the
	-- entire lock.
	local aimPosition =
		predicted +
		Vector3.new(
			0,
			-LockedAimOffset,
			0
		)

	return aimPosition
end

--============================================================
-- FIRST PERSON AIM
--============================================================

local function GetFirstPersonAimPosition(
	player
)

	if not player then
		return nil
	end

	local character =
		player.Character

	if not character then
		return nil
	end

	local head =
		character:FindFirstChild(
			"Head"
		)

	if not head then
		return nil
	end

	return GetPredictedPosition(
		head.Position,
		head.AssemblyLinearVelocity
	)
end

--============================================================
-- FINAL AIM POSITION
--============================================================

local function GetAimPosition(player)

	if not player then
		return nil
	end

	if not IsAlive(player) then
		return nil
	end

	if Config.CameraMode ==
		"First Person"
	then

		return GetFirstPersonAimPosition(
			player
		)

	end

	return GetFixedThirdPersonAimPosition(
		player
	)
end

--============================================================
-- TARGET VALIDATION
--============================================================

local function IsValidTarget(player)

	if not player then
		return false
	end

	if player == LocalPlayer then
		return false
	end

	if Config.AimbotWhitelistSkip
		and IsWhitelisted(player)
	then
		return false
	end

	if not IsAlive(player) then
		return false
	end

	local localRoot =
		GetLocalRoot()

	if not localRoot then
		return false
	end

	local character =
		player.Character

	if not character then
		return false
	end

	local root =
		character:FindFirstChild(
			"HumanoidRootPart"
		)

	if not root then
		return false
	end

	local distance =
		(
			root.Position -
			localRoot.Position
		).Magnitude

	if distance >
		Config.MaxTargetDistance
	then
		return false
	end

	return true
end

--============================================================
-- FIND TARGET
--============================================================

local function FindTarget()

	local bestPlayer = nil
	local bestDistance = math.huge

	local localRoot =
		GetLocalRoot()

	if not localRoot then
		return nil
	end

	local viewport =
		Camera.ViewportSize

	local center =
		Vector2.new(
			viewport.X / 2,
			viewport.Y / 2
		)

	for _, player in ipairs(
		Players:GetPlayers()
	) do

		if IsValidTarget(player) then

			local character =
				player.Character

			local root =
				character
				and character:FindFirstChild(
					"HumanoidRootPart"
				)

			if root then

				if Config.StickyAim then

					-- New lock:
					-- choose the player closest
					-- to screen center.
					local screenPosition,
						visible =
						Camera:WorldToViewportPoint(
							root.Position
						)

					if visible then

						local screenDistance =
							(
								Vector2.new(
									screenPosition.X,
									screenPosition.Y
								)
								-
								center
							).Magnitude

						if screenDistance <
							bestDistance
						then

							bestDistance =
								screenDistance

							bestPlayer =
								player
						end
					end

				else

					-- New lock:
					-- physical distance only.
					local physicalDistance =
						(
							root.Position -
							localRoot.Position
						).Magnitude

					if physicalDistance <
						bestDistance
					then

						bestDistance =
							physicalDistance

						bestPlayer =
							player
					end
				end
			end
		end
	end

	return bestPlayer
end

--============================================================
-- UNLOCK
--============================================================

local function Unlock()

	Locked = false
	LockedTarget = nil

	-- Reset captured offset.
	LockedAimOffset = 0
end

--============================================================
-- LOCK
--============================================================

local function LockTarget(target)

	if not target then
		return
	end

	if not IsValidTarget(target) then
		return
	end

	local character =
		target.Character

	if not character then
		return
	end

	local root =
		character:FindFirstChild(
			"HumanoidRootPart"
		)

	if not root then
		return
	end

	--========================================================
	-- CAPTURE THE AIM POINT ONCE
	--========================================================
	--
	-- From this point onward the vertical offset does not
	-- depend on camera height or target distance.
	--
	-- If AimOffset = 23.5:
	--
	-- Root Y - 23.5
	--
	-- remains the vertical target point for the lock.
	--
	LockedAimOffset =
		Config.AimOffset

	LockedTarget =
		target

	Locked = true
end

--============================================================
-- TOGGLE LOCK
--============================================================

local function ToggleLock()

	if Rebinding then
		return
	end

	if Locked then

		Unlock()

		return
	end

	local target =
		FindTarget()

	if target then

		LockTarget(
			target
		)

	end
end

--============================================================
-- GUI
--============================================================

local Gui = Create("ScreenGui", {

	Name = "Xenon",

	Parent = PlayerGui,

	ResetOnSpawn = false,

	IgnoreGuiInset = true,

	ZIndexBehavior =
		Enum.ZIndexBehavior.Global,

	DisplayOrder = 1000000,

	Enabled = true,
})

--============================================================
-- DEVICE DETECTION
--============================================================

local IsPhone =
	UserInputService.TouchEnabled
	and not GuiService:IsTenFootInterface()

local IsControllerPhone =
	IsPhone
	and UserInputService.GamepadEnabled

--============================================================
-- RESPONSIVE SIZE
--============================================================

local viewport =
	Camera.ViewportSize

local screenWidth =
	viewport.X

local screenHeight =
	viewport.Y

local WindowWidth
local WindowHeight

if IsPhone then

	-- VERY COMPACT PHONE MODE

	WindowWidth =
		math.min(
			260,
			math.max(
				235,
				screenWidth - 24
			)
		)

	WindowHeight =
		math.min(
			305,
			math.max(
				275,
				screenHeight - 24
			)
		)

else

	-- PC

	WindowWidth = 380
	WindowHeight = 520

end

--============================================================
-- MAIN WINDOW
--============================================================

local Main = Create("Frame", {

	Name = "Main",

	Parent = Gui,

	Size =
		UDim2.fromOffset(
			WindowWidth,
			WindowHeight
		),

	Position =
		UDim2.new(
			0.5,
			-WindowWidth / 2,
			0.5,
			-WindowHeight / 2
		),

	BackgroundColor3 =
		COLORS.Background,

	BorderSizePixel = 0,

	ClipsDescendants = true,

	ZIndex = 100,
})

Round(
	Main,
	IsPhone and 11 or 14
)

AddStroke(
	Main,
	COLORS.DarkGray,
	0.2,
	1
)

--============================================================
-- UI DIMENSIONS
--============================================================

local TopHeight
local TabHeight
local PageTop

if IsPhone then

	TopHeight = 34
	TabHeight = 30
	PageTop = 72

else

	TopHeight = 42
	TabHeight = 36
	PageTop = 92

end

--============================================================
-- TOP BAR
--============================================================

local TopBar = Create("Frame", {

	Name = "TopBar",

	Parent = Main,

	Size =
		UDim2.new(
			1,
			-10,
			0,
			TopHeight
		),

	Position =
		UDim2.fromOffset(
			5,
			5
		),

	BackgroundColor3 =
		COLORS.Panel,

	BorderSizePixel = 0,

	ZIndex = 101,
})

Round(
	TopBar,
	IsPhone and 8 or 11
)

--============================================================
-- TITLE
--============================================================

local Title = Create("TextLabel", {

	Parent = TopBar,

	Size =
		UDim2.new(
			1,
			-55,
			1,
			0
		),

	Position =
		UDim2.fromOffset(
			IsPhone and 9 or 14,
			0
		),

	BackgroundTransparency = 1,

	Text = "XENON",

	Font =
		Enum.Font.GothamBold,

	TextSize =
		IsPhone and 12 or 16,

	TextColor3 =
		COLORS.White,

	TextXAlignment =
		Enum.TextXAlignment.Left,

	ZIndex = 102,
})

--============================================================
-- STATUS
--============================================================

local Status = Create("TextLabel", {

	Parent = TopBar,

	Size =
		UDim2.fromOffset(
			IsPhone and 48 or 65,
			18
		),

	Position =
		UDim2.new(
			1,
			IsPhone and -83 or -100,
			0.5,
			-9
		),

	BackgroundTransparency = 1,

	Text = "READY",

	Font =
		Enum.Font.GothamBold,

	TextSize =
		IsPhone and 7 or 9,

	TextColor3 =
		COLORS.Gray,

	ZIndex = 102,
})

--============================================================
-- CLOSE
--============================================================

local Close = Create("TextButton", {

	Parent = TopBar,

	Size =
		UDim2.fromOffset(
			IsPhone and 25 or 32,
			IsPhone and 25 or 32
		),

	Position =
		UDim2.new(
			1,
			IsPhone and -28 or -36,
			0.5,
			IsPhone and -12.5 or -16
		),

	BackgroundColor3 =
		COLORS.Panel2,

	BorderSizePixel = 0,

	Text = "×",

	Font =
		Enum.Font.GothamBold,

	TextSize =
		IsPhone and 15 or 20,

	TextColor3 =
		COLORS.White,

	AutoButtonColor = false,

	ZIndex = 103,
})

Round(
	Close,
	IsPhone and 7 or 9
)

--============================================================
-- TAB BAR
--============================================================

local TabBar = Create("Frame", {

	Name = "TabBar",

	Parent = Main,

	Size =
		UDim2.new(
			1,
			-12,
			0,
			TabHeight
		),

	Position =
		UDim2.fromOffset(
			6,
			TopHeight + 10
		),

	BackgroundColor3 =
		COLORS.Panel,

	BorderSizePixel = 0,

	ZIndex = 101,
})

Round(
	TabBar,
	IsPhone and 8 or 10
)

Create("UIPadding", {

	Parent = TabBar,

	PaddingLeft =
		UDim.new(0, 3),

	PaddingRight =
		UDim.new(0, 3),

	PaddingTop =
		UDim.new(0, 3),

	PaddingBottom =
		UDim.new(0, 3),
})

local TabLayout = Create(
	"UIListLayout",
	{

		Parent = TabBar,

		FillDirection =
			Enum.FillDirection.Horizontal,

		HorizontalAlignment =
			Enum.HorizontalAlignment.Center,

		VerticalAlignment =
			Enum.VerticalAlignment.Center,

		Padding =
			UDim.new(
				0,
				IsPhone and 2 or 3
			),

		SortOrder =
			Enum.SortOrder.LayoutOrder,
	}
)

local TabButtons = {}

local function CreateTab(
	name,
	order
)

	local availableWidth =
		WindowWidth - 24

	local tabWidth =
		math.floor(
			availableWidth / 3
		)

	local button = Create(
		"TextButton",
		{

			Name =
				name .. "Tab",

			Parent =
				TabBar,

			Size =
				UDim2.fromOffset(
					tabWidth,
					TabHeight - 6
				),

			BackgroundColor3 =
				COLORS.Panel2,

			BorderSizePixel = 0,

			Text = name,

			Font =
				Enum.Font.GothamBold,

			TextSize =
				IsPhone and 7 or 9,

			TextColor3 =
				COLORS.Gray,

			AutoButtonColor = false,

			LayoutOrder = order,

			ZIndex = 102,
		}
	)

	Round(
		button,
		IsPhone and 6 or 8
	)

	local indicator = Create(
		"Frame",
		{

			Parent = button,

			Size =
				UDim2.new(
					1,
					-10,
					0,
					2
				),

			Position =
				UDim2.new(
					0,
					5,
					1,
					-4
				),

			BackgroundColor3 =
				COLORS.Red,

			BorderSizePixel = 0,

			Visible = false,

			ZIndex = 103,
		}
	)

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

--============================================================
-- PAGES
--============================================================

local Pages = Create("Frame", {

	Name = "Pages",

	Parent = Main,

	Size =
		UDim2.new(
			1,
			-12,
			1,
			-(PageTop + 6)
		),

	Position =
		UDim2.fromOffset(
			6,
			PageTop
		),

	BackgroundTransparency = 1,

	ZIndex = 101,
})

--============================================================
-- CREATE PAGE
--============================================================

local function CreatePage(name)

	local page = Create(
		"ScrollingFrame",
		{

			Name =
				name .. "Page",

			Parent =
				Pages,

			Size =
				UDim2.fromScale(
					1,
					1
				),

			BackgroundTransparency = 1,

			BorderSizePixel = 0,

			ScrollBarThickness =
				IsPhone and 2 or 3,

			ScrollBarImageColor3 =
				COLORS.Red,

			CanvasSize =
				UDim2.new(
					0,
					0,
					0,
					0
				),

			AutomaticCanvasSize =
				Enum.AutomaticSize.Y,

			ScrollingDirection =
				Enum.ScrollingDirection.Y,

			Visible = false,

			ZIndex = 101,
		}
	)

	Create(
		"UIPadding",
		{

			Parent = page,

			PaddingLeft =
				UDim.new(
					0,
					IsPhone and 1 or 2
				),

			PaddingRight =
				UDim.new(
					0,
					IsPhone and 1 or 2
				),

			PaddingTop =
				UDim.new(0, 1),

			PaddingBottom =
				UDim.new(0, 5),
		}
	)

	Create(
		"UIListLayout",
		{

			Parent = page,

			Padding =
				UDim.new(
					0,
					IsPhone and 4 or 7
				),

			SortOrder =
				Enum.SortOrder.LayoutOrder,
		}
	)

	return page
end

local AimPage =
	CreatePage("AIM")

local ESPPage =
	CreatePage("ESP")

local WhitelistPage =
	CreatePage("WHITELIST")

--============================================================
-- UI HELPERS
--============================================================

local function CreateSection(
	parent,
	text
)

	return Create(
		"TextLabel",
		{

			Parent = parent,

			Size =
				UDim2.new(
					1,
					-2,
					0,
					IsPhone and 16 or 22
				),

			BackgroundTransparency = 1,

			Text = text,

			Font =
				Enum.Font.GothamBold,

			TextSize =
				IsPhone and 7 or 9,

			TextColor3 =
				COLORS.Red,

			TextXAlignment =
				Enum.TextXAlignment.Left,

			ZIndex = 102,
		}
	)
end

--============================================================
-- ROW
--============================================================

local function CreateRow(
	parent,
	title,
	subtitle
)

	local rowHeight =
		IsPhone and 35 or 44

	local row = Create(
		"Frame",
		{

			Parent = parent,

			Size =
				UDim2.new(
					1,
					-2,
					0,
					rowHeight
				),

			BackgroundColor3 =
				COLORS.Panel,

			BorderSizePixel = 0,

			ZIndex = 102,
		}
	)

	Round(
		row,
		IsPhone and 7 or 9
	)

	Create(
		"TextLabel",
		{

			Parent = row,

			Size =
				UDim2.new(
					1,
					-90,
					0,
					IsPhone and 16 or 19
				),

			Position =
				UDim2.fromOffset(
					IsPhone and 8 or 10,
					IsPhone and 2 or 4
				),

			BackgroundTransparency = 1,

			Text = title,

			Font =
				Enum.Font.GothamSemibold,

			TextSize =
				IsPhone and 8 or 10,

			TextColor3 =
				COLORS.White,

			TextXAlignment =
				Enum.TextXAlignment.Left,

			ZIndex = 103,
		}
	)

	Create(
		"TextLabel",
		{

			Parent = row,

			Size =
				UDim2.new(
					1,
					-90,
					0,
					IsPhone and 12 or 15
				),

			Position =
				UDim2.fromOffset(
					IsPhone and 8 or 10,
					IsPhone and 17 or 23
				),

			BackgroundTransparency = 1,

			Text = subtitle or "",

			Font =
				Enum.Font.Gotham,

			TextSize =
				IsPhone and 6 or 7,

			TextColor3 =
				COLORS.Gray,

			TextXAlignment =
				Enum.TextXAlignment.Left,

			ZIndex = 103,
		}
	)

	return row
end

--============================================================
-- TOGGLE
--============================================================

local function CreateToggle(
	parent,
	title,
	subtitle,
	initial,
	callback
)

	local row =
		CreateRow(
			parent,
			title,
			subtitle
		)

	local button = Create(
		"TextButton",
		{

			Parent = row,

			Size =
				UDim2.fromOffset(
					IsPhone and 45 or 54,
					IsPhone and 22 or 25
				),

			Position =
				UDim2.new(
					1,
					IsPhone and -53 or -64,
					0.5,
					IsPhone and -11 or -12.5
				),

			BackgroundColor3 =
				initial
				and COLORS.Red
				or COLORS.DarkGray,

			BorderSizePixel = 0,

			Text =
				initial
				and "ON"
				or "OFF",

			Font =
				Enum.Font.GothamBold,

			TextSize =
				IsPhone and 7 or 8,

			TextColor3 =
				COLORS.White,

			AutoButtonColor = false,

			ZIndex = 104,
		}
	)

	Round(
		button,
		IsPhone and 7 or 8
	)

	local state = initial

	local function Update(value)

		state = value

		button.Text =
			value
			and "ON"
			or "OFF"

		button.BackgroundColor3 =
			value
			and COLORS.Red
			or COLORS.DarkGray

		if callback then
			callback(value)
		end
	end

	button.Activated:Connect(
		function()
			Update(not state)
		end
	)

	return row, button, Update
end

--============================================================
-- TEXT BOX
--============================================================

local function CreateTextBox(
	parent,
	title,
	subtitle,
	value,
	callback
)

	local row =
		CreateRow(
			parent,
			title,
			subtitle
		)

	local box = Create(
		"TextBox",
		{

			Parent = row,

			Size =
				UDim2.fromOffset(
					IsPhone and 55 or 72,
					IsPhone and 22 or 27
				),

			Position =
				UDim2.new(
					1,
					IsPhone and -63 or -82,
					0.5,
					IsPhone and -11 or -13.5
				),

			BackgroundColor3 =
				COLORS.Panel2,

			BorderSizePixel = 0,

			Text =
				tostring(value),

			Font =
				Enum.Font.GothamSemibold,

			TextSize =
				IsPhone and 7 or 9,

			TextColor3 =
				COLORS.White,

			ClearTextOnFocus = false,

			TextXAlignment =
				Enum.TextXAlignment.Center,

			ZIndex = 104,
		}
	)

	Round(
		box,
		IsPhone and 6 or 8
	)

	AddStroke(
		box,
		COLORS.DarkGray,
		0.3,
		1
	)

	box.FocusLost:Connect(
		function()

			local number =
				tonumber(
					box.Text
				)

			if number then

				callback(number)

			else

				box.Text =
					tostring(value)

			end
		end
	)

	return row, box
end

--============================================================
-- DROPDOWN
--============================================================

local function CreateDropdown(
	parent,
	title,
	subtitle,
	options,
	current,
	callback
)

	local row =
		CreateRow(
			parent,
			title,
			subtitle
		)

	local button = Create(
		"TextButton",
		{

			Parent = row,

			Size =
				UDim2.fromOffset(
					IsPhone and 82 or 110,
					IsPhone and 22 or 27
				),

			Position =
				UDim2.new(
					1,
					IsPhone and -90 or -120,
					0.5,
					IsPhone and -11 or -13.5
				),

			BackgroundColor3 =
				COLORS.Panel2,

			BorderSizePixel = 0,

			Text = current,

			Font =
				Enum.Font.GothamSemibold,

			TextSize =
				IsPhone and 6 or 8,

			TextColor3 =
				COLORS.White,

			AutoButtonColor = false,

			ZIndex = 104,
		}
	)

	Round(
		button,
		IsPhone and 6 or 8
	)

	local index = 1

	for i, option in ipairs(
		options
	) do

		if option == current then

			index = i

			break
		end
	end

	button.Activated:Connect(
		function()

			index += 1

			if index > #options then
				index = 1
			end

			local selected =
				options[index]

			button.Text =
				selected

			callback(selected)
		end
	)

	return row, button
end

--============================================================
-- ACTION BUTTON
--============================================================

local function CreateAction(
	parent,
	title,
	subtitle,
	text,
	callback
)

	local row =
		CreateRow(
			parent,
			title,
			subtitle
		)

	local button = Create(
		"TextButton",
		{

			Parent = row,

			Size =
				UDim2.fromOffset(
					IsPhone and 75 or 100,
					IsPhone and 22 or 27
				),

			Position =
				UDim2.new(
					1,
					IsPhone and -83 or -110,
					0.5,
					IsPhone and -11 or -13.5
				),

			BackgroundColor3 =
				COLORS.Red,

			BorderSizePixel = 0,

			Text = text,

			Font =
				Enum.Font.GothamBold,

			TextSize =
				IsPhone and 6 or 8,

			TextColor3 =
				COLORS.White,

			AutoButtonColor = false,

			ZIndex = 104,
		}
	)

	Round(
		button,
		IsPhone and 6 or 8
	)

	button.Activated:Connect(
		callback
	)

	return row, button
end

--============================================================
-- AIM PAGE
--============================================================

CreateSection(
	AimPage,
	"CAMERA"
)

CreateDropdown(
	AimPage,
	"Camera Mode",
	"First / third person",
	{
		"First Person",
		"Third Person"
	},
	Config.CameraMode,
	function(value)

		Config.CameraMode =
			value

	end
)

CreateTextBox(
	AimPage,
	"Fixed Aim Offset",
	"Positive = below target",
	Config.AimOffset,
	function(value)

		Config.AimOffset =
			math.clamp(
				value,
				-100,
				100
			)

	end
)

CreateTextBox(
	AimPage,
	"Smoothing",
	"0 = instant",
	Config.Smoothing,
	function(value)

		Config.Smoothing =
			math.max(
				0,
				value
			)

	end
)

CreateSection(
	AimPage,
	"PREDICTION"
)

CreateTextBox(
	AimPage,
	"Prediction X",
	"Normal X prediction",
	Config.PredictionX,
	function(value)

		Config.PredictionX =
			value

	end
)

CreateTextBox(
	AimPage,
	"Prediction Y",
	"Inverted Y prediction",
	Config.PredictionY,
	function(value)

		Config.PredictionY =
			value

	end
)

CreateSection(
	AimPage,
	"TARGETING"
)

CreateToggle(
	AimPage,
	"Sticky Aim",
	"Screen-center priority on new lock",
	Config.StickyAim,
	function(value)

		Config.StickyAim =
			value

	end
)

CreateToggle(
	AimPage,
	"Whitelist Skip",
	"Ignore whitelisted players",
	Config.AimbotWhitelistSkip,
	function(value)

		Config.AimbotWhitelistSkip =
			value

		if LockedTarget
			and IsWhitelisted(
				LockedTarget
			)
		then

			Unlock()

		end
	end
)

--============================================================
-- CONTROLLER INFO
--============================================================

local ControllerInfo

local LockButtonRow

LockButtonRow =
	CreateAction(
		AimPage,
		"Lock Button",
		"Controller only",
		Config.LockButton.Name,
		function()

			Rebinding = true

			if ControllerInfo then

				ControllerInfo.Text =
					"WAITING FOR CONTROLLER INPUT..."

			end
		end
	)

CreateSection(
	AimPage,
	"CONTROLLER"
)

ControllerInfo = Create(
	"TextLabel",
	{

		Parent = AimPage,

		Size =
			UDim2.new(
				1,
				-2,
				0,
				IsPhone and 35 or 50
			),

		BackgroundColor3 =
			COLORS.Panel,

		BorderSizePixel = 0,

		Text =
			"LOCK: " ..
			Config.LockButton.Name ..
			"\nController-only lock input.",

		Font =
			Enum.Font.Gotham,

		TextSize =
			IsPhone and 6 or 8,

		TextColor3 =
			COLORS.Gray,

		TextWrapped = true,

		TextXAlignment =
			Enum.TextXAlignment.Left,

		TextYAlignment =
			Enum.TextYAlignment.Center,

		ZIndex = 102,
	}
)

Round(
	ControllerInfo,
	IsPhone and 7 or 9
)

--============================================================
-- FIXED AIM INFORMATION
--============================================================

local FixedAimInfo = Create(
	"TextLabel",
	{

		Parent = AimPage,

		Size =
			UDim2.new(
				1,
				-2,
				0,
				IsPhone and 48 or 62
			),

		BackgroundColor3 =
			COLORS.Panel,

		BorderSizePixel = 0,

		Text =
			"FIXED AIM METHOD\n" ..
			"No camera-height correction.\n" ..
			"No distance-based vertical movement.\n" ..
			"Aim offset is captured when locking.",

		Font =
			Enum.Font.Gotham,

		TextSize =
			IsPhone and 6 or 8,

		TextColor3 =
			COLORS.Gray,

		TextWrapped = true,

		TextXAlignment =
			Enum.TextXAlignment.Left,

		TextYAlignment =
			Enum.TextYAlignment.Center,

		ZIndex = 102,
	}
)

Round(
	FixedAimInfo,
	IsPhone and 7 or 9
)

--============================================================
-- ESP PAGE
--============================================================

CreateSection(
	ESPPage,
	"ESP"
)

CreateToggle(
	ESPPage,
	"ESP Enabled",
	"Enable player ESP",
	Config.ESPEnabled,
	function(value)

		Config.ESPEnabled =
			value

	end
)

CreateToggle(
	ESPPage,
	"Show Name",
	"Name above head",
	Config.ESPShowName,
	function(value)

		Config.ESPShowName =
			value

	end
)

CreateToggle(
	ESPPage,
	"Show Outline",
	"Team-colored outline",
	Config.ESPShowOutline,
	function(value)

		Config.ESPShowOutline =
			value

	end
)

CreateToggle(
	ESPPage,
	"ESP Whitelist",
	"Hide whitelisted players",
	Config.ESPWhitelistCheck,
	function(value)

		Config.ESPWhitelistCheck =
			value

	end
)

CreateSection(
	ESPPage,
	"STYLE"
)

local ESPInfo = Create(
	"TextLabel",
	{

		Parent = ESPPage,

		Size =
			UDim2.new(
				1,
				-2,
				0,
				IsPhone and 50 or 68
			),

		BackgroundColor3 =
			COLORS.Panel,

		BorderSizePixel = 0,

		Text =
			"XENON ESP\n" ..
			"Team colors • Names • Distance",

		Font =
			Enum.Font.Gotham,

		TextSize =
			IsPhone and 7 or 8,

		TextColor3 =
			COLORS.Gray,

		TextXAlignment =
			Enum.TextXAlignment.Left,

		TextYAlignment =
			Enum.TextYAlignment.Center,

		ZIndex = 102,
	}
)

Round(
	ESPInfo,
	IsPhone and 7 or 9
)

--============================================================
-- WHITELIST PAGE
--============================================================

CreateSection(
	WhitelistPage,
	"SERVER WHITELIST"
)

local WhitelistInfo = Create(
	"TextLabel",
	{

		Parent = WhitelistPage,

		Size =
			UDim2.new(
				1,
				-2,
				0,
				IsPhone and 34 or 42
			),

		BackgroundColor3 =
			COLORS.Panel,

		BorderSizePixel = 0,

		Text =
			"Tap player to toggle\n" ..
			"Grey = normal • Red = whitelist",

		Font =
			Enum.Font.Gotham,

		TextSize =
			IsPhone and 6 or 8,

		TextColor3 =
			COLORS.Gray,

		TextXAlignment =
			Enum.TextXAlignment.Left,

		TextYAlignment =
			Enum.TextYAlignment.Center,

		ZIndex = 102,
	}
)

Round(
	WhitelistInfo,
	IsPhone and 7 or 9
)

local WhitelistList = Create(
	"Frame",
	{

		Parent = WhitelistPage,

		Size =
			UDim2.new(
				1,
				-2,
				0,
				0
			),

		BackgroundTransparency = 1,

		AutomaticSize =
			Enum.AutomaticSize.Y,

		ZIndex = 102,
	}
)

Create(
	"UIListLayout",
	{

		Parent =
			WhitelistList,

		Padding =
			UDim.new(
				0,
				IsPhone and 4 or 6
			),

		SortOrder =
			Enum.SortOrder.Name,
	}
)

--============================================================
-- WHITELIST REFRESH
--============================================================

local function RefreshWhitelistUI()

	for _, child in ipairs(
		WhitelistList:GetChildren()
	) do

		if child:IsA("TextButton") then
			child:Destroy()
		end
	end

	for _, player in ipairs(
		Players:GetPlayers()
	) do

		if player ~= LocalPlayer then

			local enabled =
				IsWhitelisted(
					player
				)

			local button = Create(
				"TextButton",
				{

					Name =
						player.Name,

					Parent =
						WhitelistList,

					Size =
						UDim2.new(
							1,
							0,
							0,
							IsPhone and 32 or 40
						),

					BackgroundColor3 =
						enabled
						and COLORS.Red
						or COLORS.Panel,

					BorderSizePixel = 0,

					Text =
						player.DisplayName ..
						"  @" ..
						player.Name,

					Font =
						Enum.Font.GothamSemibold,

					TextSize =
						IsPhone and 7 or 9,

					TextColor3 =
						COLORS.White,

					TextXAlignment =
						Enum.TextXAlignment.Left,

					AutoButtonColor = false,

					ZIndex = 103,
				}
			)

			Round(
				button,
				IsPhone and 7 or 9
			)

			Create(
				"UIPadding",
				{

					Parent = button,

					PaddingLeft =
						UDim.new(
							0,
							IsPhone and 8 or 12
						),
				}
			)

			button.Activated:Connect(
				function()

					local id =
						tostring(
							player.UserId
						)

					Whitelist[id] =
						not IsWhitelisted(
							player
						)

					SaveWhitelist()

					if
						LockedTarget ==
							player
						and
						Config.AimbotWhitelistSkip
						and
						IsWhitelisted(
							player
						)
					then

						Unlock()

					end

					RefreshWhitelistUI()
				end
			)
		end
	end
end

RefreshWhitelistUI()

--============================================================
-- TAB SWITCHING
--============================================================

local PagesByName = {

	AIM = AimPage,
	ESP = ESPPage,
	WHITELIST = WhitelistPage,
}

local function SetTab(name)

	CurrentTab = name

	for pageName, page in pairs(
		PagesByName
	) do

		page.Visible =
			pageName == name

	end

	for tabName, data in pairs(
		TabButtons
	) do

		local active =
			tabName == name

		data.Button.BackgroundColor3 =
			active
			and COLORS.Red
			or COLORS.Panel2

		data.Button.TextColor3 =
			active
			and COLORS.White
			or COLORS.Gray

		data.Indicator.Visible =
			active
	end
end

for name, data in pairs(
	TabButtons
) do

	data.Button.Activated:Connect(
		function()
			SetTab(name)
		end
	)
end

SetTab("AIM")

--============================================================
-- DRAGGING
--============================================================

local Dragging = false
local DragStart
local StartPosition

TopBar.InputBegan:Connect(
	function(input)

		if
			input.UserInputType ==
				Enum.UserInputType.MouseButton1
			or
			input.UserInputType ==
				Enum.UserInputType.Touch
		then

			Dragging = true

			DragStart =
				input.Position

			StartPosition =
				Main.Position

			input.Changed:Connect(
				function()

					if
						input.UserInputState ==
							Enum.UserInputState.End
					then

						Dragging = false

					end
				end
			)
		end
	end
)

UserInputService.InputChanged:Connect(
	function(input)

		if not Dragging then
			return
		end

		if
			input.UserInputType ~=
				Enum.UserInputType.MouseMovement
			and
			input.UserInputType ~=
				Enum.UserInputType.Touch
		then

			return
		end

		local delta =
			input.Position -
			DragStart

		Main.Position =
			UDim2.new(

				StartPosition.X.Scale,

				StartPosition.X.Offset +
					delta.X,

				StartPosition.Y.Scale,

				StartPosition.Y.Offset +
					delta.Y
			)
	end
)

--============================================================
-- FLOATING BUTTON
--============================================================

local Floating = Create(
	"TextButton",
	{

		Name =
			"XenonFloating",

		Parent =
			Gui,

		Size =
			UDim2.fromOffset(
				IsPhone and 34 or 42,
				IsPhone and 34 or 42
			),

		Position =
			UDim2.new(
				1,
				IsPhone and -42 or -54,
				0,
				IsPhone and 8 or 12
			),

		BackgroundColor3 =
			COLORS.Red,

		BorderSizePixel = 0,

		Text = "X",

		Font =
			Enum.Font.GothamBold,

		TextSize =
			IsPhone and 12 or 15,

		TextColor3 =
			COLORS.White,

		AutoButtonColor = false,

		Visible = false,

		ZIndex = 1000,
	}
)

Round(
	Floating,
	IsPhone and 9 or 12
)

--============================================================
-- UI VISIBILITY
--============================================================

local function SetUIVisible(value)

	UIVisible = value

	Main.Visible =
		value

	Floating.Visible =
		not value
end

Close.Activated:Connect(
	function()

		SetUIVisible(false)

	end
)

Floating.Activated:Connect(
	function()

		SetUIVisible(true)

	end
)

--============================================================
-- CONTROLLER BUTTONS
--============================================================

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

--============================================================
-- REBIND CONTROLLER
--============================================================

local function SetLockButton(key)

	Config.LockButton =
		key

	Rebinding = false

	ControllerInfo.Text =
		"LOCK: " ..
		Config.LockButton.Name ..
		"\nController-only lock input."
end

UserInputService.InputBegan:Connect(
	function(input)

		--====================================================
		-- CONTROLLER ONLY
		--====================================================

		if
			input.UserInputType ~=
				Enum.UserInputType.Gamepad1
		then

			return
		end

		if not SupportedButtons[
			input.KeyCode
		] then

			return
		end

		if Rebinding then

			SetLockButton(
				input.KeyCode
			)

			return
		end

		if
			input.KeyCode ==
				Config.LockButton
		then

			ToggleLock()

		end
	end
)

--============================================================
-- THUMBSTICK REBIND
--============================================================

UserInputService.InputChanged:Connect(
	function(input)

		if not Rebinding then
			return
		end

		if
			input.UserInputType ~=
				Enum.UserInputType.Gamepad1
		then

			return
		end

		if
			input.KeyCode ~=
				Enum.KeyCode.Thumbstick1
			and
			input.KeyCode ~=
				Enum.KeyCode.Thumbstick2
		then

			return
		end

		if input.Position.Magnitude >
			0.65
		then

			SetLockButton(
				input.KeyCode
			)

		end
	end
)

--============================================================
-- ESP
--============================================================

local function GetTeamColor(player)

	if player.Team then
		return player.Team.TeamColor.Color
	end

	return COLORS.White
end

--============================================================
-- REMOVE ESP
--============================================================

local function RemoveESP(player)

	local data =
		ESPObjects[player]

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

	ESPObjects[player] =
		nil
end

--============================================================
-- ESP COLORS
--============================================================

local function ApplyESPColor(
	data,
	player
)

	if not data then
		return
	end

	local color =
		GetTeamColor(player)

	if data.NameLabel then

		data.NameLabel.TextColor3 =
			color

	end

	if data.DistanceLabel then

		data.DistanceLabel.TextColor3 =
			color

	end

	if data.Highlight then

		data.Highlight.OutlineColor =
			color

	end
end

--============================================================
-- CREATE ESP
--============================================================

local function CreateESP(player)

	if player == LocalPlayer then
		return
	end

	RemoveESP(player)

	if not Config.ESPEnabled then
		return
	end

	if
		Config.ESPWhitelistCheck
		and IsWhitelisted(player)
	then

		return
	end

	local character =
		player.Character

	if not character then
		return
	end

	local head =
		character:FindFirstChild(
			"Head"
		)

	local root =
		character:FindFirstChild(
			"HumanoidRootPart"
		)

	if not head or not root then
		return
	end

	local data = {}

	--========================================================
	-- NAME
	--========================================================

	if Config.ESPShowName then

		local billboard =
			Create(
				"BillboardGui",
				{

					Name =
						"XenonName",

					Parent =
						head,

					Adornee =
						head,

					Size =
						UDim2.fromOffset(
							180,
							24
						),

					StudsOffset =
						Vector3.new(
							0,
							2.8,
							0
						),

					AlwaysOnTop =
						true,

					ResetOnSpawn =
						false,
				}
			)

		local label =
			Create(
				"TextLabel",
				{

					Parent =
						billboard,

					Size =
						UDim2.fromScale(
							1,
							1
						),

					BackgroundTransparency =
						1,

					Text =
						player.Name,

					Font =
						Enum.Font.Gotham,

					TextSize = 9,

					TextColor3 =
						GetTeamColor(
							player
						),

					TextStrokeTransparency =
						0.2,

					TextStrokeColor3 =
						COLORS.Black,
				}
			)

		data.NameBillboard =
			billboard

		data.NameLabel =
			label
	end

	--========================================================
	-- DISTANCE
	--========================================================

	local distanceBillboard =
		Create(
			"BillboardGui",
			{

				Name =
					"XenonDistance",

				Parent =
					root,

				Adornee =
					root,

				Size =
					UDim2.fromOffset(
						180,
						22
					),

				StudsOffset =
					Vector3.new(
						0,
						-3,
						0
					),

				AlwaysOnTop =
					true,

				ResetOnSpawn =
					false,
			}
		)

	local distanceLabel =
		Create(
			"TextLabel",
			{

				Parent =
					distanceBillboard,

				Size =
					UDim2.fromScale(
						1,
						1
					),

				BackgroundTransparency =
					1,

				Text =
					"0 studs",

				Font =
					Enum.Font.Gotham,

				TextSize = 9,

				TextColor3 =
					GetTeamColor(
						player
					),

				TextStrokeTransparency =
					0.2,

				TextStrokeColor3 =
					COLORS.Black,
			}
		)

	data.DistanceBillboard =
		distanceBillboard

	data.DistanceLabel =
		distanceLabel

	--========================================================
	-- OUTLINE
	--========================================================

	if Config.ESPShowOutline then

		local highlight =
			Create(
				"Highlight",
				{

					Name =
						"XenonHighlight",

					Parent =
						character,

					Adornee =
						character,

					DepthMode =
						Enum.HighlightDepthMode.AlwaysOnTop,

					FillTransparency =
						1,

					OutlineTransparency =
						0,

					OutlineColor =
						GetTeamColor(
							player
						),
				}
			)

		data.Highlight =
			highlight
	end

	ESPObjects[player] =
		data

	ApplyESPColor(
		data,
		player
	)
end

--============================================================
-- REFRESH ESP
--============================================================

local function RefreshESP(player)

	if player == LocalPlayer then
		return
	end

	if not Config.ESPEnabled then

		RemoveESP(player)

		return
	end

	if
		Config.ESPWhitelistCheck
		and IsWhitelisted(player)
	then

		RemoveESP(player)

		return
	end

	CreateESP(player)
end

local function RefreshAllESP()

	for _, player in ipairs(
		Players:GetPlayers()
	) do

		if player ~= LocalPlayer then

			RefreshESP(player)

		end
	end
end

--============================================================
-- PLAYER CONNECTIONS
--============================================================

local function ConnectPlayer(player)

	if player == LocalPlayer then
		return
	end

	PlayerConnections[player] =
		PlayerConnections[player]
		or {}

	table.insert(
		PlayerConnections[player],

		player.CharacterAdded:Connect(
			function()

				task.wait(0.15)

				RemoveESP(player)

				if Config.ESPEnabled then
					CreateESP(player)
				end

				-- NEVER RETARGET
				if LockedTarget ==
					player
				then

					Unlock()

				end
			end
		)
	)

	table.insert(
		PlayerConnections[player],

		player:GetPropertyChangedSignal(
			"Team"
		):Connect(
			function()

				local data =
					ESPObjects[player]

				if data then

					ApplyESPColor(
						data,
						player
					)

				end
			end
		)
	)
end

for _, player in ipairs(
	Players:GetPlayers()
) do

	ConnectPlayer(player)

end

Players.PlayerAdded:Connect(
	function(player)

		ConnectPlayer(player)

		task.wait(0.2)

		RefreshESP(player)

		RefreshWhitelistUI()
	end
)

Players.PlayerRemoving:Connect(
	function(player)

		RemoveESP(player)

		if LockedTarget ==
			player
		then

			Unlock()

		end

		if PlayerConnections[player] then

			for _, connection in ipairs(
				PlayerConnections[player]
			) do

				pcall(function()

					connection:Disconnect()

				end)
			end

			PlayerConnections[player] =
				nil
		end

		RefreshWhitelistUI()
	end
)

--============================================================
-- LOCAL CHARACTER
--============================================================

LocalPlayer.CharacterAdded:Connect(
	function()

		Unlock()

	end
)

--============================================================
-- ESP UPDATE
--============================================================

local ESPCounter = 0

RunService.Heartbeat:Connect(
	function()

		if not Config.ESPEnabled then
			return
		end

		ESPCounter += 1

		if ESPcounter and false then
			return
		end

		if ESPCounter % 4 ~= 0 then
			return
		end

		local localRoot =
			GetLocalRoot()

		if not localRoot then
			return
		end

		for player, data in pairs(
			ESPObjects
		) do

			if not player.Parent then

				RemoveESP(player)

				continue
			end

			if not IsAlive(player) then

				RemoveESP(player)

				continue
			end

			if
				Config.ESPWhitelistCheck
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

			if root then

				local distance =
					(
						root.Position -
						localRoot.Position
					).Magnitude

				if data.DistanceLabel then

					data.DistanceLabel.Text =
						math.floor(
							distance
						)
						..
						" studs"

				end
			end

			ApplyESPColor(
				data,
				player
			)
		end
	end
)

--============================================================
-- ESP WATCHER
--============================================================

task.spawn(
	function()

		local lastEnabled =
			Config.ESPEnabled

		local lastName =
			Config.ESPShowName

		local lastOutline =
			Config.ESPShowOutline

		local lastWhitelist =
			Config.ESPWhitelistCheck

		while Gui.Parent do

			task.wait(0.2)

			if
				lastEnabled ~=
					Config.ESPEnabled
				or
				lastName ~=
					Config.ESPShowName
				or
				lastOutline ~=
					Config.ESPShowOutline
				or
				lastWhitelist ~=
					Config.ESPWhitelistCheck
			then

				lastEnabled =
					Config.ESPEnabled

				lastName =
					Config.ESPShowName

				lastOutline =
					Config.ESPShowOutline

				lastWhitelist =
					Config.ESPWhitelistCheck

				RefreshAllESP()

			end
		end
	end
)

--============================================================
-- CAMERA LOCK
--============================================================

RunService:BindToRenderStep(
	"XenonCameraLock",

	Enum.RenderPriority.Last.Value,

	function()

		if not Locked then

			Status.Text =
				"READY"

			Status.TextColor3 =
				COLORS.Gray

			return
		end

		--====================================================
		-- TARGET MUST STAY THE SAME
		--====================================================

		if not LockedTarget then

			Unlock()

			return
		end

		--====================================================
		-- NO RETARGETING
		--====================================================

		if not IsValidTarget(
			LockedTarget
		) then

			Unlock()

			return
		end

		--====================================================
		-- GET AIM POINT
		--====================================================

		local aimPosition =
			GetAimPosition(
				LockedTarget
			)

		if not aimPosition then

			Unlock()

			return
		end

		local cameraPosition =
			Camera.CFrame.Position

		local desired =
			CFrame.lookAt(
				cameraPosition,
				aimPosition
			)

		--====================================================
		-- SMOOTHING
		--====================================================

		if Config.Smoothing <= 0 then

			Camera.CFrame =
				desired

		else

			local alpha =
				math.clamp(
					1 / Config.Smoothing,
					0.01,
					1
				)

			Camera.CFrame =
				Camera.CFrame:Lerp(
					desired,
					alpha
				)
		end

		Status.Text =
			"LOCKED"

		Status.TextColor3 =
			COLORS.Red
	end
)

--============================================================
-- CLEANUP
--============================================================

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

	for player, connections in pairs(
		PlayerConnections
	) do

		for _, connection in ipairs(
			connections
		) do

			pcall(function()

				connection:Disconnect()

			end)
		end

		PlayerConnections[player] =
			nil
	end

	for player in pairs(
		ESPObjects
	) do

		RemoveESP(player)

	end

	pcall(function()

		Gui:Destroy()

	end)

	_G.XenonCleanup = nil
end

--============================================================
-- INITIAL ESP
--============================================================

if Config.ESPEnabled then

	RefreshAllESP()

end

--============================================================
-- START
--============================================================

SetUIVisible(true)

print(
	"Xenon loaded"
)

print(
	"Fixed aim-point system enabled"
)

print(
	"Lock button:",
	Config.LockButton.Name
)

print(
	"Mobile:",
	IsPhone
)

print(
	"Controller:",
	UserInputService.GamepadEnabled
)
