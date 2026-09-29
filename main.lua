--==============================================================
-- XENON
-- CONTROLLER CAMERA LOCK SYSTEM
--==============================================================

--==============================================================
-- SERVICES
--==============================================================

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

--==============================================================
-- DUPLICATE EXECUTION CLEANUP
--==============================================================

pcall(function()
	if _G.XenonCleanup then
		_G.XenonCleanup()
	end
end)

local Connections = {}
local Destroyed = false

local function Track(connection)
	table.insert(Connections, connection)
	return connection
end

_G.XenonCleanup = function()
	if Destroyed then
		return
	end

	Destroyed = true

	for _, connection in ipairs(Connections) do
		pcall(function()
			connection:Disconnect()
		end)
	end

	pcall(function()
		RunService:UnbindFromRenderStep("XenonCameraLock")
	end)

	local gui = PlayerGui:FindFirstChild("Xenon")

	if gui then
		gui:Destroy()
	end
end

--==============================================================
-- REMOVE EXISTING XENON
--==============================================================

local ExistingGui = PlayerGui:FindFirstChild("Xenon")

if ExistingGui then
	ExistingGui:Destroy()
end

pcall(function()
	RunService:UnbindFromRenderStep("XenonCameraLock")
end)

--==============================================================
-- CONFIG
--==============================================================

local Config = {

	-- Default controller lock button
	LockButton = Enum.KeyCode.ButtonY,

	-- First Person / Third Person
	CameraMode = "Third Person",

	-- Base adaptive third-person offset.
	--
	-- Positive = below
	-- Negative = above
	AimOffset = 10,

	-- Distance where AimOffset is considered normal.
	ReferenceDistance = 100,

	-- Camera smoothing
	--
	-- 0 = HARD LOCK
	Smoothing = 0,

	-- Prediction
	Prediction = 0.08,

	-- Maximum target distance
	MaxTargetDistance = 500,

	-- TRUE:
	-- Stay on the same target after locking.
	--
	-- FALSE:
	-- Each new lock chooses target by physical distance.
	StickyAim = true,
}

--==============================================================
-- STATE
--==============================================================

local IsLocked = false
local LockedTarget = nil

local WaitingForButton = false

local Dragging = false
local DragStart = nil
local DragStartPosition = nil

--==============================================================
-- GUI REFERENCES
--==============================================================

local ScreenGui
local MainFrame
local FloatingButton

local StatusText
local TargetText

local ModeButton
local Dropdown

local OffsetBox
local SmoothingBox
local PredictionBox

local LockButtonDisplay
local StickyButton

--==============================================================
-- GAMEPAD DETECTION
--==============================================================

local function IsGamepad(input)

	return input.UserInputType == Enum.UserInputType.Gamepad1
		or input.UserInputType == Enum.UserInputType.Gamepad2
		or input.UserInputType == Enum.UserInputType.Gamepad3
		or input.UserInputType == Enum.UserInputType.Gamepad4
		or input.UserInputType == Enum.UserInputType.Gamepad5
		or input.UserInputType == Enum.UserInputType.Gamepad6
		or input.UserInputType == Enum.UserInputType.Gamepad7
		or input.UserInputType == Enum.UserInputType.Gamepad8

end

--==============================================================
-- VALID CONTROLLER BUTTONS
--==============================================================

local SupportedButtons = {

	-- Face buttons
	ButtonA = true,
	ButtonB = true,
	ButtonX = true,
	ButtonY = true,

	-- D-Pad
	DPadUp = true,
	DPadDown = true,
	DPadLeft = true,
	DPadRight = true,

	-- Bumpers
	ButtonL1 = true,
	ButtonR1 = true,

	-- Triggers
	ButtonL2 = true,
	ButtonR2 = true,

	-- Stick clicks
	ButtonL3 = true,
	ButtonR3 = true,

	-- Menu
	ButtonSelect = true,
	ButtonStart = true,

	-- Stick movement
	Thumbstick1 = true,
	Thumbstick2 = true,
}

--==============================================================
-- BUTTON DISPLAY NAME
--==============================================================

local function GetButtonName(keyCode)

	if not keyCode then
		return "UNKNOWN"
	end

	local name = keyCode.Name

	local names = {

		ButtonA = "A / CROSS",
		ButtonB = "B / CIRCLE",
		ButtonX = "X / SQUARE",
		ButtonY = "Y / TRIANGLE",

		DPadUp = "D-PAD UP",
		DPadDown = "D-PAD DOWN",
		DPadLeft = "D-PAD LEFT",
		DPadRight = "D-PAD RIGHT",

		ButtonL1 = "L1 / LB",
		ButtonR1 = "R1 / RB",

		ButtonL2 = "L2 / LT",
		ButtonR2 = "R2 / RT",

		ButtonL3 = "L3",
		ButtonR3 = "R3",

		ButtonSelect = "SELECT / VIEW",
		ButtonStart = "START / MENU",

		Thumbstick1 = "LEFT STICK",
		Thumbstick2 = "RIGHT STICK",
	}

	return names[name] or name
end

--==============================================================
-- NUMBER PARSER
--==============================================================

local function ReadNumber(text, defaultValue, minimum, maximum)

	local value = tonumber(text)

	if value == nil then
		return defaultValue
	end

	return math.clamp(value, minimum, maximum)

end

--==============================================================
-- GET TARGET PARTS
--==============================================================

local function GetTargetParts(player)

	if not player then
		return nil
	end

	if player == LocalPlayer then
		return nil
	end

	local character = player.Character

	if not character then
		return nil
	end

	local humanoid =
		character:FindFirstChildOfClass("Humanoid")

	local root =
		character:FindFirstChild("HumanoidRootPart")

	if not humanoid or not root then
		return nil
	end

	if humanoid.Health <= 0 then
		return nil
	end

	return character, humanoid, root

end

--==============================================================
-- TARGET VALIDATION
--==============================================================

local function IsValidTarget(player)

	local character, humanoid, root =
		GetTargetParts(player)

	if not character then
		return false
	end

	local localCharacter =
		LocalPlayer.Character

	if not localCharacter then
		return false
	end

	local localRoot =
		localCharacter:FindFirstChild(
			"HumanoidRootPart"
		)

	if not localRoot then
		return false
	end

	local distance =
		(root.Position - localRoot.Position).Magnitude

	if distance > Config.MaxTargetDistance then
		return false
	end

	return true

end

--==============================================================
-- FIND CLOSEST TO SCREEN CENTER
--==============================================================

local function FindClosestToCursor()

	local Camera =
		workspace.CurrentCamera

	if not Camera then
		return nil
	end

	local viewport =
		Camera.ViewportSize

	local center =
		Vector2.new(
			viewport.X / 2,
			viewport.Y / 2
		)

	local closestTarget = nil
	local closestScreenDistance = math.huge

	for _, player in ipairs(Players:GetPlayers()) do

		if player ~= LocalPlayer then

			local character, humanoid, root =
				GetTargetParts(player)

			if character and humanoid and root then

				local distance =
					(root.Position -
						Camera.CFrame.Position).Magnitude

				if distance <= Config.MaxTargetDistance then

					local screenPosition, onScreen =
						Camera:WorldToViewportPoint(
							root.Position
						)

					if onScreen
						and screenPosition.Z > 0 then

						local point =
							Vector2.new(
								screenPosition.X,
								screenPosition.Y
							)

						local screenDistance =
							(point - center).Magnitude

						if screenDistance <
							closestScreenDistance then

							closestScreenDistance =
								screenDistance

							closestTarget =
								player
						end
					end
				end
			end
		end
	end

	return closestTarget

end

--==============================================================
-- FIND CLOSEST BY PHYSICAL DISTANCE
--==============================================================

local function FindClosestByDistance()

	local localCharacter =
		LocalPlayer.Character

	if not localCharacter then
		return nil
	end

	local localRoot =
		localCharacter:FindFirstChild(
			"HumanoidRootPart"
		)

	if not localRoot then
		return nil
	end

	local closestTarget = nil
	local closestDistance = math.huge

	for _, player in ipairs(Players:GetPlayers()) do

		if player ~= LocalPlayer then

			local character, humanoid, root =
				GetTargetParts(player)

			if character and humanoid and root then

				local distance =
					(root.Position -
						localRoot.Position).Magnitude

				if distance <= Config.MaxTargetDistance then

					if distance < closestDistance then

						closestDistance =
							distance

						closestTarget =
							player
					end
				end
			end
		end
	end

	return closestTarget

end

--==============================================================
-- FIND TARGET
--==============================================================

local function FindTarget()

	-- Sticky ON:
	-- New lock chooses closest to cursor.

	-- Sticky OFF:
	-- New lock chooses physically closest.

	if Config.StickyAim then
		return FindClosestToCursor()
	else
		return FindClosestByDistance()
	end

end

--==============================================================
-- UPDATE STATUS
--==============================================================

local function UpdateStatus()

	if StatusText then

		if IsLocked and LockedTarget then

			StatusText.Text =
				"LOCKED"

			StatusText.TextColor3 =
				Color3.fromRGB(
					240,
					55,
					65
				)

		else

			StatusText.Text =
				"READY"

			StatusText.TextColor3 =
				Color3.fromRGB(
					210,
					210,
					210
				)

		end
	end

	if TargetText then

		if IsLocked and LockedTarget then

			TargetText.Text =
				"TARGET / " ..
				LockedTarget.DisplayName

		else

			TargetText.Text =
				"TARGET / NONE"

		end
	end

end

--==============================================================
-- UPDATE BUTTON DISPLAY
--==============================================================

local function UpdateLockButtonDisplay()

	if not LockButtonDisplay then
		return
	end

	if WaitingForButton then

		LockButtonDisplay.Text =
			"PRESS CONTROLLER BUTTON..."

	else

		LockButtonDisplay.Text =
			"SET LOCK BUTTON     [" ..
			GetButtonName(Config.LockButton) ..
			"]"

	end

end

--==============================================================
-- UPDATE STICKY BUTTON
--==============================================================

local function UpdateStickyButton()

	if not StickyButton then
		return
	end

	if Config.StickyAim then

		StickyButton.Text =
			"STICKY AIM     [ON]"

		StickyButton.TextColor3 =
			Color3.fromRGB(
				240,
				240,
				240
			)

	else

		StickyButton.Text =
			"STICKY AIM     [OFF]"

		StickyButton.TextColor3 =
			Color3.fromRGB(
				180,
				180,
				185
			)

	end

end

--==============================================================
-- UNLOCK
--==============================================================

local function Unlock()

	IsLocked = false
	LockedTarget = nil

	UpdateStatus()

end

--==============================================================
-- LOCK
--==============================================================

local function Lock()

	if IsLocked then
		return
	end

	local target =
		FindTarget()

	if not target then
		return
	end

	LockedTarget =
		target

	IsLocked = true

	UpdateStatus()

end

--==============================================================
-- TOGGLE LOCK
--==============================================================

local function ToggleLock()

	if IsLocked then
		Unlock()
	else
		Lock()
	end

end

--==============================================================
-- CREATE GUI
--==============================================================

ScreenGui =
	Instance.new("ScreenGui")

ScreenGui.Name =
	"Xenon"

ScreenGui.ResetOnSpawn = false

ScreenGui.IgnoreGuiInset = true

ScreenGui.ZIndexBehavior =
	Enum.ZIndexBehavior.Sibling

ScreenGui.Parent =
	PlayerGui

--==============================================================
-- MAIN FRAME
--==============================================================

MainFrame =
	Instance.new("Frame")

MainFrame.Name =
	"Main"

MainFrame.AnchorPoint =
	Vector2.new(
		0.5,
		0.5
	)

MainFrame.Position =
	UDim2.fromScale(
		0.5,
		0.5
	)

MainFrame.Size =
	UDim2.fromOffset(
		390,
		570
	)

MainFrame.BackgroundColor3 =
	Color3.fromRGB(
		17,
		17,
		19
	)

MainFrame.BorderSizePixel = 0

MainFrame.Parent =
	ScreenGui

local MainCorner =
	Instance.new("UICorner")

MainCorner.CornerRadius =
	UDim.new(
		0,
		14
	)

MainCorner.Parent =
	MainFrame

local MainStroke =
	Instance.new("UIStroke")

MainStroke.Color =
	Color3.fromRGB(
		65,
		65,
		70
	)

MainStroke.Thickness = 1

MainStroke.Transparency = 0.25

MainStroke.Parent =
	MainFrame

--==============================================================
-- RESPONSIVE SIZE
--==============================================================

local function UpdateSize()

	local Camera =
		workspace.CurrentCamera

	if not Camera then
		return
	end

	local viewport =
		Camera.ViewportSize

	if viewport.X <= 600 then

		MainFrame.Size =
			UDim2.fromOffset(
				300,
				525
			)

	elseif viewport.X <= 1000 then

		MainFrame.Size =
			UDim2.fromOffset(
				350,
				550
			)

	else

		MainFrame.Size =
			UDim2.fromOffset(
				390,
				570
			)

	end

end

UpdateSize()

--==============================================================
-- TOP BAR
--==============================================================

local TopBar =
	Instance.new("Frame")

TopBar.Size =
	UDim2.new(
		1,
		0,
		0,
		76
	)

TopBar.BackgroundTransparency = 1

TopBar.Parent =
	MainFrame

--==============================================================
-- RED LINE
--==============================================================

local RedLine =
	Instance.new("Frame")

RedLine.Position =
	UDim2.fromOffset(
		15,
		0
	)

RedLine.Size =
	UDim2.new(
		1,
		-30,
		0,
		2
	)

RedLine.BackgroundColor3 =
	Color3.fromRGB(
		235,
		45,
		55
	)

RedLine.BorderSizePixel = 0

RedLine.Parent =
	TopBar

local RedCorner =
	Instance.new("UICorner")

RedCorner.CornerRadius =
	UDim.new(
		1,
		0
	)

RedCorner.Parent =
	RedLine

--==============================================================
-- LOGO
--==============================================================

local Logo =
	Instance.new("TextLabel")

Logo.BackgroundTransparency = 1

Logo.Position =
	UDim2.fromOffset(
		18,
		14
	)

Logo.Size =
	UDim2.fromOffset(
		35,
		38
	)

Logo.Font =
	Enum.Font.GothamBlack

Logo.Text =
	"X"

Logo.TextSize = 30

Logo.TextColor3 =
	Color3.fromRGB(
		235,
		45,
		55
	)

Logo.Parent =
	TopBar

--==============================================================
-- TITLE
--==============================================================

local Title =
	Instance.new("TextLabel")

Title.BackgroundTransparency = 1

Title.Position =
	UDim2.fromOffset(
		57,
		12
	)

Title.Size =
	UDim2.new(
		1,
		-120,
		0,
		25
	)

Title.Font =
	Enum.Font.GothamBold

Title.Text =
	"XENON"

Title.TextSize = 21

Title.TextXAlignment =
	Enum.TextXAlignment.Left

Title.TextColor3 =
	Color3.fromRGB(
		245,
		245,
		245
	)

Title.Parent =
	TopBar

--==============================================================
-- SUBTITLE
--==============================================================

local Subtitle =
	Instance.new("TextLabel")

Subtitle.BackgroundTransparency = 1

Subtitle.Position =
	UDim2.fromOffset(
		58,
		38
	)

Subtitle.Size =
	UDim2.new(
		1,
		-125,
		0,
		18
	)

Subtitle.Font =
	Enum.Font.GothamMedium

Subtitle.Text =
	"CONTROLLER CAMERA SYSTEM"

Subtitle.TextSize = 9

Subtitle.TextXAlignment =
	Enum.TextXAlignment.Left

Subtitle.TextColor3 =
	Color3.fromRGB(
		120,
		120,
		125
	)

Subtitle.Parent =
	TopBar

--==============================================================
-- CLOSE BUTTON
--==============================================================

local CloseButton =
	Instance.new("TextButton")

CloseButton.AnchorPoint =
	Vector2.new(
		1,
		0
	)

CloseButton.Position =
	UDim2.new(
		1,
		-15,
		0,
		15
	)

CloseButton.Size =
	UDim2.fromOffset(
		40,
		40
	)

CloseButton.BackgroundColor3 =
	Color3.fromRGB(
		35,
		35,
		38
	)

CloseButton.BorderSizePixel = 0

CloseButton.Text =
	"×"

CloseButton.TextSize = 27

CloseButton.Font =
	Enum.Font.GothamBold

CloseButton.TextColor3 =
	Color3.fromRGB(
		230,
		230,
		230
	)

CloseButton.Parent =
	TopBar

local CloseCorner =
	Instance.new("UICorner")

CloseCorner.CornerRadius =
	UDim.new(
		0,
		9
	)

CloseCorner.Parent =
	CloseButton

--==============================================================
-- SCROLLING CONTENT
--==============================================================

local Scroll =
	Instance.new("ScrollingFrame")

Scroll.Name =
	"Content"

Scroll.Position =
	UDim2.fromOffset(
		12,
		78
	)

Scroll.Size =
	UDim2.new(
		1,
		-24,
		1,
		-90
	)

Scroll.BackgroundTransparency = 1

Scroll.BorderSizePixel = 0

Scroll.ScrollBarThickness = 3

Scroll.ScrollBarImageColor3 =
	Color3.fromRGB(
		85,
		85,
		90
	)

Scroll.CanvasSize =
	UDim2.new(
		0,
		0,
		0,
		900
	)

Scroll.Parent =
	MainFrame

local Layout =
	Instance.new("UIListLayout")

Layout.Padding =
	UDim.new(
		0,
		9
	)

Layout.HorizontalAlignment =
	Enum.HorizontalAlignment.Center

Layout.SortOrder =
	Enum.SortOrder.LayoutOrder

Layout.Parent =
	Scroll

--==============================================================
-- SECTION
--==============================================================

local function CreateSection(text, order)

	local label =
		Instance.new("TextLabel")

	label.Size =
		UDim2.new(
			1,
			-10,
			0,
			20
		)

	label.BackgroundTransparency = 1

	label.Font =
		Enum.Font.GothamBold

	label.Text =
		text

	label.TextSize = 10

	label.TextXAlignment =
		Enum.TextXAlignment.Left

	label.TextColor3 =
		Color3.fromRGB(
			115,
			115,
			120
		)

	label.LayoutOrder =
		order

	label.Parent =
		Scroll

	return label

end

--==============================================================
-- STATUS
--==============================================================

local StatusCard =
	Instance.new("Frame")

StatusCard.Size =
	UDim2.new(
		1,
		-10,
		0,
		66
	)

StatusCard.BackgroundColor3 =
	Color3.fromRGB(
		24,
		24,
		27
	)

StatusCard.BorderSizePixel = 0

StatusCard.LayoutOrder = 1

StatusCard.Parent =
	Scroll

local StatusCorner =
	Instance.new("UICorner")

StatusCorner.CornerRadius =
	UDim.new(
		0,
		10
	)

StatusCorner.Parent =
	StatusCard

local StatusLabel =
	Instance.new("TextLabel")

StatusLabel.BackgroundTransparency = 1

StatusLabel.Position =
	UDim2.fromOffset(
		14,
		8
	)

StatusLabel.Size =
	UDim2.new(
		0.5,
		0,
		0,
		16
	)

StatusLabel.Font =
	Enum.Font.GothamMedium

StatusLabel.Text =
	"SYSTEM STATUS"

StatusLabel.TextSize = 9

StatusLabel.TextXAlignment =
	Enum.TextXAlignment.Left

StatusLabel.TextColor3 =
	Color3.fromRGB(
		110,
		110,
		115
	)

StatusLabel.Parent =
	StatusCard

StatusText =
	Instance.new("TextLabel")

StatusText.BackgroundTransparency = 1

StatusText.Position =
	UDim2.fromOffset(
		14,
		28
	)

StatusText.Size =
	UDim2.new(
		0.5,
		0,
		0,
		24
	)

StatusText.Font =
	Enum.Font.GothamBold

StatusText.Text =
	"READY"

StatusText.TextSize = 15

StatusText.TextXAlignment =
	Enum.TextXAlignment.Left

StatusText.TextColor3 =
	Color3.fromRGB(
		210,
		210,
		210
	)

StatusText.Parent =
	StatusCard

TargetText =
	Instance.new("TextLabel")

TargetText.BackgroundTransparency = 1

TargetText.AnchorPoint =
	Vector2.new(
		1,
		0
	)

TargetText.Position =
	UDim2.new(
		1,
		-14,
		0,
		28
	)

TargetText.Size =
	UDim2.new(
		0.45,
		0,
		0,
		20
	)

TargetText.Font =
	Enum.Font.GothamMedium

TargetText.Text =
	"TARGET / NONE"

TargetText.TextSize = 9

TargetText.TextXAlignment =
	Enum.TextXAlignment.Right

TargetText.TextColor3 =
	Color3.fromRGB(
		130,
		130,
		135
	)

TargetText.Parent =
	StatusCard

--==============================================================
-- CAMERA MODE
--==============================================================

CreateSection(
	"CAMERA MODE",
	2
)

ModeButton =
	Instance.new("TextButton")

ModeButton.Size =
	UDim2.new(
		1,
		-10,
		0,
		46
	)

ModeButton.BackgroundColor3 =
	Color3.fromRGB(
		24,
		24,
		27
	)

ModeButton.BorderSizePixel = 0

ModeButton.Font =
	Enum.Font.GothamMedium

ModeButton.Text =
	"THIRD PERSON"

ModeButton.TextSize = 11

ModeButton.TextXAlignment =
	Enum.TextXAlignment.Left

ModeButton.TextColor3 =
	Color3.fromRGB(
		230,
		230,
		230
	)

ModeButton.LayoutOrder = 3

ModeButton.Parent =
	Scroll

local ModePadding =
	Instance.new("UIPadding")

ModePadding.PaddingLeft =
	UDim.new(
		0,
		14
	)

ModePadding.Parent =
	ModeButton

local ModeCorner =
	Instance.new("UICorner")

ModeCorner.CornerRadius =
	UDim.new(
		0,
		9
	)

ModeCorner.Parent =
	ModeButton

--==============================================================
-- DROPDOWN
--==============================================================

Dropdown =
	Instance.new("Frame")

Dropdown.Size =
	UDim2.new(
		1,
		-10,
		0,
		88
	)

Dropdown.BackgroundColor3 =
	Color3.fromRGB(
		21,
		21,
		24
	)

Dropdown.BorderSizePixel = 0

Dropdown.Visible = false

Dropdown.LayoutOrder = 4

Dropdown.Parent =
	Scroll

local DropdownCorner =
	Instance.new("UICorner")

DropdownCorner.CornerRadius =
	UDim.new(
		0,
		9
	)

DropdownCorner.Parent =
	Dropdown

local FirstPersonButton =
	Instance.new("TextButton")

FirstPersonButton.Position =
	UDim2.fromOffset(
		4,
		4
	)

FirstPersonButton.Size =
	UDim2.new(
		1,
		-8,
		0,
		38
	)

FirstPersonButton.BackgroundColor3 =
	Color3.fromRGB(
		30,
		30,
		33
	)

FirstPersonButton.BorderSizePixel = 0

FirstPersonButton.Font =
	Enum.Font.GothamMedium

FirstPersonButton.Text =
	"FIRST PERSON"

FirstPersonButton.TextSize = 10

FirstPersonButton.TextColor3 =
	Color3.fromRGB(
		220,
		220,
		220
	)

FirstPersonButton.Parent =
	Dropdown

local FPcorner =
	Instance.new("UICorner")

FPcorner.CornerRadius =
	UDim.new(
		0,
		7
	)

FPcorner.Parent =
	FirstPersonButton

local ThirdPersonButton =
	Instance.new("TextButton")

ThirdPersonButton.Position =
	UDim2.fromOffset(
		4,
		46
	)

ThirdPersonButton.Size =
	UDim2.new(
		1,
		-8,
		0,
		38
	)

ThirdPersonButton.BackgroundColor3 =
	Color3.fromRGB(
		30,
		30,
		33
	)

ThirdPersonButton.BorderSizePixel = 0

ThirdPersonButton.Font =
	Enum.Font.GothamMedium

ThirdPersonButton.Text =
	"THIRD PERSON"

ThirdPersonButton.TextSize = 10

ThirdPersonButton.TextColor3 =
	Color3.fromRGB(
		220,
		220,
		220
	)

ThirdPersonButton.Parent =
	Dropdown

local TPcorner =
	Instance.new("UICorner")

TPcorner.CornerRadius =
	UDim.new(
		0,
		7
	)

TPcorner.Parent =
	ThirdPersonButton

--==============================================================
-- INPUT CREATOR
--==============================================================

local function CreateInput(labelText, defaultText, order)

	local container =
		Instance.new("Frame")

	container.Size =
		UDim2.new(
			1,
			-10,
			0,
			68
		)

	container.BackgroundColor3 =
		Color3.fromRGB(
			24,
			24,
			27
		)

	container.BorderSizePixel = 0

	container.LayoutOrder =
		order

	container.Parent =
		Scroll

	local corner =
		Instance.new("UICorner")

	corner.CornerRadius =
		UDim.new(
			0,
			9
		)

	corner.Parent =
		container

	local label =
		Instance.new("TextLabel")

	label.BackgroundTransparency = 1

	label.Position =
		UDim2.fromOffset(
			13,
			7
		)

	label.Size =
		UDim2.new(
			1,
			-26,
			0,
			18
		)

	label.Font =
		Enum.Font.GothamMedium

	label.Text =
		labelText

	label.TextSize = 9

	label.TextXAlignment =
		Enum.TextXAlignment.Left

	label.TextColor3 =
		Color3.fromRGB(
			145,
			145,
			150
		)

	label.Parent =
		container

	local box =
		Instance.new("TextBox")

	box.Position =
		UDim2.fromOffset(
			12,
			31
		)

	box.Size =
		UDim2.new(
			1,
			-24,
			0,
			27
		)

	box.BackgroundColor3 =
		Color3.fromRGB(
			16,
			16,
			18
		)

	box.BorderSizePixel = 0

	box.ClearTextOnFocus = false

	box.Font =
		Enum.Font.GothamMedium

	box.Text =
		defaultText

	box.TextSize = 10

	box.TextColor3 =
		Color3.fromRGB(
			235,
			235,
			235
		)

	box.Parent =
		container

	local boxCorner =
		Instance.new("UICorner")

	boxCorner.CornerRadius =
		UDim.new(
			0,
			7
		)

	boxCorner.Parent =
		box

	return box

end

--==============================================================
-- AIM SETTINGS
--==============================================================

CreateSection(
	"AIM SETTINGS",
	5
)

OffsetBox =
	CreateInput(
		"ADAPTIVE THIRD PERSON OFFSET",
		"10",
		6
	)

Track(
	OffsetBox.FocusLost:Connect(
		function()

			Config.AimOffset =
				ReadNumber(
					OffsetBox.Text,
					10,
					-100,
					100
				)

			OffsetBox.Text =
				tostring(
					Config.AimOffset
				)

		end
	)
)

--==============================================================
-- RECOMMENDATION
--==============================================================

local Recommendation =
	Instance.new("TextLabel")

Recommendation.Size =
	UDim2.new(
		1,
		-10,
		0,
		46
	)

Recommendation.BackgroundColor3 =
	Color3.fromRGB(
		24,
		24,
		27
	)

Recommendation.BorderSizePixel = 0

Recommendation.Font =
	Enum.Font.GothamMedium

Recommendation.Text =
	"HEAD  ≈  FIRST PERSON\n" ..
	"POSITIVE OFFSET = BELOW  •  NEGATIVE = ABOVE"

Recommendation.TextSize = 9

Recommendation.TextWrapped = true

Recommendation.TextXAlignment =
	Enum.TextXAlignment.Left

Recommendation.TextYAlignment =
	Enum.TextYAlignment.Center

Recommendation.TextColor3 =
	Color3.fromRGB(
		150,
		150,
		155
	)

Recommendation.LayoutOrder = 7

Recommendation.Parent =
	Scroll

local RecCorner =
	Instance.new("UICorner")

RecCorner.CornerRadius =
	UDim.new(
		0,
		9
	)

RecCorner.Parent =
	Recommendation

local RecPadding =
	Instance.new("UIPadding")

RecPadding.PaddingLeft =
	UDim.new(
		0,
		13
	)

RecPadding.Parent =
	Recommendation

--==============================================================
-- SMOOTHING
--==============================================================

SmoothingBox =
	CreateInput(
		"SMOOTHING  (0 = HARD LOCK)",
		"0",
		8
	)

Track(
	SmoothingBox.FocusLost:Connect(
		function()

			Config.Smoothing =
				ReadNumber(
					SmoothingBox.Text,
					0,
					0,
					10
				)

			SmoothingBox.Text =
				string.format(
					"%.2f",
					Config.Smoothing
				)

		end
	)
)

--==============================================================
-- PREDICTION
--==============================================================

PredictionBox =
	CreateInput(
		"PREDICTION",
		"0.08",
		9
	)

Track(
	PredictionBox.FocusLost:Connect(
		function()

			Config.Prediction =
				ReadNumber(
					PredictionBox.Text,
					0.08,
					0,
					2
				)

			PredictionBox.Text =
				string.format(
					"%.2f",
					Config.Prediction
				)

		end
	)
)

--==============================================================
-- TARGETING
--==============================================================

CreateSection(
	"TARGETING",
	10
)

--==============================================================
-- STICKY BUTTON
--==============================================================

StickyButton =
	Instance.new("TextButton")

StickyButton.Size =
	UDim2.new(
		1,
		-10,
		0,
		48
	)

StickyButton.BackgroundColor3 =
	Color3.fromRGB(
		24,
		24,
		27
	)

StickyButton.BorderSizePixel = 0

StickyButton.Font =
	Enum.Font.GothamBold

StickyButton.TextSize = 10

StickyButton.TextXAlignment =
	Enum.TextXAlignment.Left

StickyButton.LayoutOrder = 11

StickyButton.Parent =
	Scroll

local StickyPadding =
	Instance.new("UIPadding")

StickyPadding.PaddingLeft =
	UDim.new(
		0,
		14
	)

StickyPadding.Parent =
	StickyButton

local StickyCorner =
	Instance.new("UICorner")

StickyCorner.CornerRadius =
	UDim.new(
		0,
		9
	)

StickyCorner.Parent =
	StickyButton

UpdateStickyButton()

Track(
	StickyButton.MouseButton1Click:Connect(
		function()

			Config.StickyAim =
				not Config.StickyAim

			UpdateStickyButton()

		end
	)
)

--==============================================================
-- LOCK BUTTON
--==============================================================

LockButtonDisplay =
	Instance.new("TextButton")

LockButtonDisplay.Size =
	UDim2.new(
		1,
		-10,
		0,
		48
	)

LockButtonDisplay.BackgroundColor3 =
	Color3.fromRGB(
		24,
		24,
		27
	)

LockButtonDisplay.BorderSizePixel = 0

LockButtonDisplay.Font =
	Enum.Font.GothamBold

LockButtonDisplay.TextSize = 10

LockButtonDisplay.TextXAlignment =
	Enum.TextXAlignment.Left

LockButtonDisplay.TextColor3 =
	Color3.fromRGB(
		230,
		230,
		230
	)

LockButtonDisplay.LayoutOrder = 12

LockButtonDisplay.Parent =
	Scroll

local ButtonPadding =
	Instance.new("UIPadding")

ButtonPadding.PaddingLeft =
	UDim.new(
		0,
		14
	)

ButtonPadding.Parent =
	LockButtonDisplay

local ButtonCorner =
	Instance.new("UICorner")

ButtonCorner.CornerRadius =
	UDim.new(
		0,
		9
	)

ButtonCorner.Parent =
	LockButtonDisplay

UpdateLockButtonDisplay()

Track(
	LockButtonDisplay.MouseButton1Click:Connect(
		function()

			if WaitingForButton then
				return
			end

			WaitingForButton = true

			UpdateLockButtonDisplay()

		end
	)
)

--==============================================================
-- GUIDE
--==============================================================

local Guide =
	Instance.new("TextLabel")

Guide.Size =
	UDim2.new(
		1,
		-10,
		0,
		92
	)

Guide.BackgroundColor3 =
	Color3.fromRGB(
		24,
		24,
		27
	)

Guide.BorderSizePixel = 0

Guide.Font =
	Enum.Font.GothamMedium

Guide.Text =
	"XENON CONTROLLER GUIDE\n\n" ..
	"Sticky ON  =  stays on your selected target.\n" ..
	"Sticky OFF =  selects the physically closest target.\n" ..
	"Lock button toggles the camera lock."

Guide.TextSize = 9

Guide.TextWrapped = true

Guide.TextXAlignment =
	Enum.TextXAlignment.Left

Guide.TextYAlignment =
	Enum.TextYAlignment.Center

Guide.TextColor3 =
	Color3.fromRGB(
		145,
		145,
		150
	)

Guide.LayoutOrder = 13

Guide.Parent =
	Scroll

local GuideCorner =
	Instance.new("UICorner")

GuideCorner.CornerRadius =
	UDim.new(
		0,
		9
	)

GuideCorner.Parent =
	Guide

local GuidePadding =
	Instance.new("UIPadding")

GuidePadding.PaddingLeft =
	UDim.new(
		0,
		13
	)

GuidePadding.PaddingRight =
	UDim.new(
		0,
		13
	)

GuidePadding.Parent =
	Guide

--==============================================================
-- FOOTER
--==============================================================

local Footer =
	Instance.new("TextLabel")

Footer.Size =
	UDim2.new(
		1,
		-10,
		0,
		30
	)

Footer.BackgroundTransparency = 1

Footer.Font =
	Enum.Font.GothamBold

Footer.Text =
	"XENON  //  CONTROLLER SYSTEM"

Footer.TextSize = 8

Footer.TextColor3 =
	Color3.fromRGB(
		80,
		80,
		85
	)

Footer.LayoutOrder = 14

Footer.Parent =
	Scroll

--==============================================================
-- MODE DROPDOWN
--==============================================================

Track(
	ModeButton.MouseButton1Click:Connect(
		function()

			Dropdown.Visible =
				not Dropdown.Visible

			if Dropdown.Visible then

				Scroll.CanvasSize =
					UDim2.new(
						0,
						0,
						0,
						1000
					)

			else

				Scroll.CanvasSize =
					UDim2.new(
						0,
						0,
						0,
						900
					)

			end

		end
	)
)

Track(
	FirstPersonButton.MouseButton1Click:Connect(
		function()

			Config.CameraMode =
				"First Person"

			ModeButton.Text =
				"FIRST PERSON"

			Dropdown.Visible = false

			Scroll.CanvasSize =
				UDim2.new(
					0,
					0,
					0,
					900
				)

		end
	)
)

Track(
	ThirdPersonButton.MouseButton1Click:Connect(
		function()

			Config.CameraMode =
				"Third Person"

			ModeButton.Text =
				"THIRD PERSON"

			Dropdown.Visible = false

			Scroll.CanvasSize =
				UDim2.new(
					0,
					0,
					0,
					900
				)

		end
	)
)

--==============================================================
-- DRAGGING
--==============================================================

Track(
	TopBar.InputBegan:Connect(
		function(input)

			if input.UserInputType ==
				Enum.UserInputType.MouseButton1
				or input.UserInputType ==
				Enum.UserInputType.Touch then

				Dragging = true

				DragStart =
					input.Position

				DragStartPosition =
					MainFrame.Position

				input.Changed:Connect(
					function()

						if input.UserInputState ==
							Enum.UserInputState.End then

							Dragging = false

						end

					end
				)

			end

		end
	)
)

Track(
	UserInputService.InputChanged:Connect(
		function(input)

			if not Dragging then
				return
			end

			if input.UserInputType ==
				Enum.UserInputType.MouseMovement
				or input.UserInputType ==
				Enum.UserInputType.Touch then

				local delta =
					input.Position -
					DragStart

				MainFrame.Position =
					UDim2.new(
						DragStartPosition.X.Scale,
						DragStartPosition.X.Offset +
							delta.X,

						DragStartPosition.Y.Scale,
						DragStartPosition.Y.Offset +
							delta.Y
					)

			end

		end
	)
)

--==============================================================
-- FLOATING X
--==============================================================

FloatingButton =
	Instance.new("TextButton")

FloatingButton.Name =
	"FloatingX"

FloatingButton.AnchorPoint =
	Vector2.new(
		1,
		0
	)

FloatingButton.Position =
	UDim2.new(
		1,
		-18,
		0,
		18
	)

FloatingButton.Size =
	UDim2.fromOffset(
		48,
		48
	)

FloatingButton.BackgroundColor3 =
	Color3.fromRGB(
		22,
		22,
		25
	)

FloatingButton.BorderSizePixel = 0

FloatingButton.Font =
	Enum.Font.GothamBlack

FloatingButton.Text =
	"X"

FloatingButton.TextSize = 22

FloatingButton.TextColor3 =
	Color3.fromRGB(
		235,
		45,
		55
	)

FloatingButton.Visible = false

FloatingButton.Parent =
	ScreenGui

local FloatingCorner =
	Instance.new("UICorner")

FloatingCorner.CornerRadius =
	UDim.new(
		0,
		12
	)

FloatingCorner.Parent =
	FloatingButton

local FloatingStroke =
	Instance.new("UIStroke")

FloatingStroke.Color =
	Color3.fromRGB(
		70,
		70,
		75
	)

FloatingStroke.Thickness = 1

FloatingStroke.Parent =
	FloatingButton

--==============================================================
-- CLOSE
--==============================================================

Track(
	CloseButton.MouseButton1Click:Connect(
		function()

			MainFrame.Visible = false
			FloatingButton.Visible = true

		end
	)
)

--==============================================================
-- REOPEN
--==============================================================

Track(
	FloatingButton.MouseButton1Click:Connect(
		function()

			MainFrame.Visible = true
			FloatingButton.Visible = false

		end
	)
)

--==============================================================
-- CONTROLLER INPUT
--==============================================================

Track(
	UserInputService.InputBegan:Connect(
		function(input, processed)

			if not IsGamepad(input) then
				return
			end

			local keyName =
				input.KeyCode.Name

			--==================================================
			-- BUTTON REBINDING
			--==================================================

			if WaitingForButton then

				if not SupportedButtons[keyName] then
					return
				end

				WaitingForButton = false

				Config.LockButton =
					input.KeyCode

				UpdateLockButtonDisplay()

				return

			end

			--==================================================
			-- LOCK TOGGLE
			--==================================================

			if input.KeyCode ==
				Config.LockButton then

				ToggleLock()

			end

		end
	)
)

--==============================================================
-- PLAYER REMOVING
--==============================================================

Track(
	Players.PlayerRemoving:Connect(
		function(player)

			if player ==
				LockedTarget then

				Unlock()

			end

		end
	)
)

--==============================================================
-- LOCAL PLAYER RESPAWN
--==============================================================

Track(
	LocalPlayer.CharacterAdded:Connect(
		function()

			Unlock()

		end
	)
)

--==============================================================
-- PREDICTION
--==============================================================

local function GetPredictedPosition(
	position,
	velocity
)

	return position +
		velocity *
		Config.Prediction

end

--==============================================================
-- FIRST PERSON AIM
--==============================================================

local function GetFirstPersonAim()

	local target =
		LockedTarget

	if not target then
		return nil
	end

	local character, humanoid, root =
		GetTargetParts(target)

	if not character then
		return nil
	end

	local head =
		character:FindFirstChild("Head")

	if head then

		return GetPredictedPosition(
			head.Position,
			head.AssemblyLinearVelocity
		)

	end

	return GetPredictedPosition(
		root.Position,
		root.AssemblyLinearVelocity
	)

end

--==============================================================
-- THIRD PERSON ADAPTIVE AIM
--==============================================================

local function GetThirdPersonAim()

	local target =
		LockedTarget

	if not target then
		return nil
	end

	local character, humanoid, root =
		GetTargetParts(target)

	if not character then
		return nil
	end

	local Camera =
		workspace.CurrentCamera

	if not Camera then
		return nil
	end

	--==========================================================
	-- PREDICT FIRST
	--==========================================================

	local predictedPosition =
		GetPredictedPosition(
			root.Position,
			root.AssemblyLinearVelocity
		)

	--==========================================================
	-- CAMERA -> TARGET DISTANCE
	--==========================================================

	local distance =
		(
			predictedPosition -
			Camera.CFrame.Position
		).Magnitude

	--==========================================================
	-- ADAPTIVE STUD OFFSET
	--==========================================================
	--
	-- Base setting:
	--
	-- 10
	--
	-- Reference distance:
	--
	-- 100 studs
	--
	-- Therefore approximately:
	--
	-- 50 studs  -> 5 studs
	-- 100 studs -> 10 studs
	-- 200 studs -> 20 studs
	--
	-- The offset changes automatically with distance.
	--==========================================================

	local referenceDistance =
		math.max(
			Config.ReferenceDistance,
			1
		)

	local adaptiveOffset =
		Config.AimOffset *
		(
			distance /
			referenceDistance
		)

	-- Keep it within sane bounds.

	adaptiveOffset =
		math.clamp(
			adaptiveOffset,
			-100,
			100
		)

	--==========================================================
	-- FINAL AIM POINT
	--==========================================================

	local aimPosition =
		predictedPosition -
		Vector3.new(
			0,
			adaptiveOffset,
			0
		)

	return aimPosition

end

--==============================================================
-- CAMERA UPDATE
--==============================================================

local function UpdateCamera(deltaTime)

	if not IsLocked then
		return
	end

	local target =
		LockedTarget

	if not target then

		Unlock()

		return

	end

	--==========================================================
	-- STICKY TARGET PROTECTION
	--==========================================================
	--
	-- Even when Sticky Aim is ON or OFF:
	--
	-- once a target is locked, we DO NOT replace it.
	--
	-- If it becomes invalid, we unlock.
	--==========================================================

	if not IsValidTarget(target) then

		Unlock()

		return

	end

	--==========================================================
	-- AIM POINT
	--==========================================================

	local aimPosition

	if Config.CameraMode ==
		"First Person" then

		aimPosition =
			GetFirstPersonAim()

	else

		aimPosition =
			GetThirdPersonAim()

	end

	if not aimPosition then

		Unlock()

		return

	end

	--==========================================================
	-- CAMERA
	--==========================================================

	local Camera =
		workspace.CurrentCamera

	if not Camera then
		return
	end

	local cameraPosition =
		Camera.CFrame.Position

	local direction =
		aimPosition -
		cameraPosition

	if direction.Magnitude <
		0.001 then

		return

	end

	local desired =
		CFrame.lookAt(
			cameraPosition,
			aimPosition
		)

	--==========================================================
	-- HARD LOCK
	--==========================================================

	if Config.Smoothing <= 0 then

		Camera.CFrame =
			desired

		return

	end

	--==========================================================
	-- SMOOTHING
	--==========================================================

	local alpha =
		1 -
		math.exp(
			-Config.Smoothing *
			deltaTime *
			60
		)

	alpha =
		math.clamp(
			alpha,
			0,
			1
		)

	Camera.CFrame =
		Camera.CFrame:Lerp(
			desired,
			alpha
		)

end

--==============================================================
-- CAMERA RENDER LOOP
--==============================================================

RunService:BindToRenderStep(
	"XenonCameraLock",
	Enum.RenderPriority.Last.Value,
	function(deltaTime)

		if Destroyed then
			return
		end

		local success, errorMessage =
			pcall(function()

				UpdateCamera(deltaTime)

			end)

		if not success then

			warn(
				"[XENON CAMERA ERROR] " ..
				tostring(errorMessage)
			)

			Unlock()

		end

	end
)

--==============================================================
-- FINALIZE
--==============================================================

UpdateStatus()
UpdateLockButtonDisplay()
UpdateStickyButton()

print("========================================")
print("XENON CONTROLLER SYSTEM LOADED")
print("Lock:", GetButtonName(Config.LockButton))
print("Mode:", Config.CameraMode)
print("Sticky Aim:", Config.StickyAim)
print("Offset:", Config.AimOffset)
print("Reference Distance:", Config.ReferenceDistance)
print("Smoothing:", Config.Smoothing)
print("Prediction:", Config.Prediction)
print("========================================")
