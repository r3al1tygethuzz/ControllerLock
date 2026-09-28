--// XENON CONTROLLER CAMERA SYSTEM
--// UI + Controller Lock
--// LocalScript

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

--==================================================
-- CONFIG
--==================================================

local DefaultMode = "Third Person"
local DefaultOffset = 10
local DefaultSmoothing = 0.30
local DefaultPrediction = 0.08
local DefaultLockButton = Enum.KeyCode.ButtonY

local MaxTargetDistance = 500

--==================================================
-- STATE
--==================================================

local CurrentMode = DefaultMode
local AimOffset = DefaultOffset
local Smoothing = DefaultSmoothing
local Prediction = DefaultPrediction
local LockButton = DefaultLockButton

local LockedTarget = nil
local IsLocked = false

local UIVisible = true
local WaitingForButton = false
local DropdownOpen = false

--==================================================
-- HELPERS
--==================================================

local function IsGamepadInput(input)
	return input.UserInputType == Enum.UserInputType.Gamepad1
		or input.UserInputType == Enum.UserInputType.Gamepad2
		or input.UserInputType == Enum.UserInputType.Gamepad3
		or input.UserInputType == Enum.UserInputType.Gamepad4
		or input.UserInputType == Enum.UserInputType.Gamepad5
		or input.UserInputType == Enum.UserInputType.Gamepad6
		or input.UserInputType == Enum.UserInputType.Gamepad7
		or input.UserInputType == Enum.UserInputType.Gamepad8
end

local ButtonNames = {
	[Enum.KeyCode.ButtonA] = "A",
	[Enum.KeyCode.ButtonB] = "B",
	[Enum.KeyCode.ButtonX] = "X",
	[Enum.KeyCode.ButtonY] = "Y",

	[Enum.KeyCode.ButtonL1] = "L1",
	[Enum.KeyCode.ButtonR1] = "R1",
	[Enum.KeyCode.ButtonL2] = "L2",
	[Enum.KeyCode.ButtonR2] = "R2",

	[Enum.KeyCode.ButtonL3] = "L3",
	[Enum.KeyCode.ButtonR3] = "R3",

	[Enum.KeyCode.DPadUp] = "D-PAD UP",
	[Enum.KeyCode.DPadDown] = "D-PAD DOWN",
	[Enum.KeyCode.DPadLeft] = "D-PAD LEFT",
	[Enum.KeyCode.DPadRight] = "D-PAD RIGHT",

	[Enum.KeyCode.ButtonStart] = "START",
	[Enum.KeyCode.ButtonSelect] = "SELECT",
}

local function GetButtonName(button)
	return ButtonNames[button] or button.Name
end

local function ClampNumber(value, default)
	value = tonumber(value)

	if not value then
		return default
	end

	return value
end

--==================================================
-- GUI
--==================================================

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "Xenon"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

--==================================================
-- RESPONSIVE SIZE
--==================================================

local CameraViewport = Camera.ViewportSize

local MainWidth
local MainHeight

if CameraViewport.X <= 500 then
	MainWidth = 300
	MainHeight = 500
elseif CameraViewport.X <= 900 then
	MainWidth = 350
	MainHeight = 525
else
	MainWidth = 390
	MainHeight = 540
end

--==================================================
-- MAIN WINDOW
--==================================================

local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.fromOffset(MainWidth, MainHeight)
Main.Position = UDim2.new(0.5, -MainWidth / 2, 0.5, -MainHeight / 2)
Main.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
Main.BorderSizePixel = 0
Main.ClipsDescendants = true
Main.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 14)
MainCorner.Parent = Main

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(42, 42, 47)
MainStroke.Thickness = 1
MainStroke.Transparency = 0.15
MainStroke.Parent = Main

--==================================================
-- HEADER
--==================================================

local Header = Instance.new("Frame")
Header.Name = "Header"
Header.Size = UDim2.new(1, 0, 0, 78)
Header.BackgroundColor3 = Color3.fromRGB(14, 14, 17)
Header.BorderSizePixel = 0
Header.Parent = Main

local HeaderCorner = Instance.new("UICorner")
HeaderCorner.CornerRadius = UDim.new(0, 14)
HeaderCorner.Parent = Header

local HeaderBottom = Instance.new("Frame")
HeaderBottom.Size = UDim2.new(1, 0, 0, 1)
HeaderBottom.Position = UDim2.new(0, 0, 1, -1)
HeaderBottom.BackgroundColor3 = Color3.fromRGB(35, 35, 39)
HeaderBottom.BorderSizePixel = 0
HeaderBottom.Parent = Header

local RedAccent = Instance.new("Frame")
RedAccent.Size = UDim2.new(1, -36, 0, 2)
RedAccent.Position = UDim2.new(0, 18, 1, -3)
RedAccent.BackgroundColor3 = Color3.fromRGB(225, 35, 45)
RedAccent.BorderSizePixel = 0
RedAccent.Parent = Header

--==================================================
-- XENON LOGO
--==================================================

local LogoBox = Instance.new("Frame")
LogoBox.Size = UDim2.fromOffset(42, 42)
LogoBox.Position = UDim2.new(0, 18, 0, 18)
LogoBox.BackgroundColor3 = Color3.fromRGB(22, 22, 26)
LogoBox.BorderSizePixel = 0
LogoBox.Parent = Header

local LogoCorner = Instance.new("UICorner")
LogoCorner.CornerRadius = UDim.new(0, 10)
LogoCorner.Parent = LogoBox

local LogoStroke = Instance.new("UIStroke")
LogoStroke.Color = Color3.fromRGB(100, 25, 30)
LogoStroke.Thickness = 1
LogoStroke.Parent = LogoBox

local LogoText = Instance.new("TextLabel")
LogoText.Size = UDim2.fromScale(1, 1)
LogoText.BackgroundTransparency = 1
LogoText.Text = "X"
LogoText.TextColor3 = Color3.fromRGB(235, 45, 55)
LogoText.Font = Enum.Font.GothamBlack
LogoText.TextSize = 24
LogoText.Parent = LogoBox

--==================================================
-- HEADER TEXT
--==================================================

local Title = Instance.new("TextLabel")
Title.BackgroundTransparency = 1
Title.Position = UDim2.new(0, 70, 0, 15)
Title.Size = UDim2.new(1, -125, 0, 28)
Title.Text = "XENON"
Title.TextColor3 = Color3.fromRGB(245, 245, 247)
Title.Font = Enum.Font.GothamBlack
Title.TextSize = 21
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

local Subtitle = Instance.new("TextLabel")
Subtitle.BackgroundTransparency = 1
Subtitle.Position = UDim2.new(0, 71, 0, 42)
Subtitle.Size = UDim2.new(1, -125, 0, 17)
Subtitle.Text = "CONTROLLER CAMERA SYSTEM"
Subtitle.TextColor3 = Color3.fromRGB(125, 125, 132)
Subtitle.Font = Enum.Font.GothamMedium
Subtitle.TextSize = 8
Subtitle.TextXAlignment = Enum.TextXAlignment.Left
Subtitle.Parent = Header

--==================================================
-- CLOSE BUTTON
--==================================================

local CloseButton = Instance.new("TextButton")
CloseButton.Name = "Close"
CloseButton.Size = UDim2.fromOffset(38, 38)
CloseButton.Position = UDim2.new(1, -50, 0, 19)
CloseButton.BackgroundColor3 = Color3.fromRGB(24, 24, 28)
CloseButton.BorderSizePixel = 0
CloseButton.Text = "×"
CloseButton.TextColor3 = Color3.fromRGB(210, 210, 214)
CloseButton.Font = Enum.Font.GothamMedium
CloseButton.TextSize = 25
CloseButton.AutoButtonColor = false
CloseButton.Parent = Header

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 10)
CloseCorner.Parent = CloseButton

--==================================================
-- CONTENT
--==================================================

local Content = Instance.new("ScrollingFrame")
Content.Name = "Content"
Content.Position = UDim2.new(0, 14, 0, 88)
Content.Size = UDim2.new(1, -28, 1, -102)
Content.BackgroundTransparency = 1
Content.BorderSizePixel = 0
Content.ScrollBarThickness = 2
Content.ScrollBarImageColor3 = Color3.fromRGB(90, 90, 95)
Content.CanvasSize = UDim2.new(0, 0, 0, 0)
Content.AutomaticCanvasSize = Enum.AutomaticSize.Y
Content.Parent = Main

local ContentPadding = Instance.new("UIPadding")
ContentPadding.PaddingBottom = UDim.new(0, 12)
ContentPadding.Parent = Content

local ContentLayout = Instance.new("UIListLayout")
ContentLayout.Padding = UDim.new(0, 9)
ContentLayout.SortOrder = Enum.SortOrder.LayoutOrder
ContentLayout.Parent = Content

--==================================================
-- SECTION HELPER
--==================================================

local function CreateSection(title, height)
	local Frame = Instance.new("Frame")
	Frame.Size = UDim2.new(1, -2, 0, height)
	Frame.BackgroundColor3 = Color3.fromRGB(17, 17, 20)
	Frame.BorderSizePixel = 0
	Frame.LayoutOrder = 1
	Frame.Parent = Content

	local Corner = Instance.new("UICorner")
	Corner.CornerRadius = UDim.new(0, 10)
	Corner.Parent = Frame

	local Stroke = Instance.new("UIStroke")
	Stroke.Color = Color3.fromRGB(35, 35, 40)
	Stroke.Thickness = 1
	Stroke.Transparency = 0.25
	Stroke.Parent = Frame

	local TitleLabel = Instance.new("TextLabel")
	TitleLabel.BackgroundTransparency = 1
	TitleLabel.Position = UDim2.new(0, 13, 0, 9)
	TitleLabel.Size = UDim2.new(1, -26, 0, 17)
	TitleLabel.Text = title
	TitleLabel.TextColor3 = Color3.fromRGB(155, 155, 162)
	TitleLabel.Font = Enum.Font.GothamBold
	TitleLabel.TextSize = 9
	TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
	TitleLabel.Parent = Frame

	return Frame
end

--==================================================
-- STATUS SECTION
--==================================================

local StatusSection = CreateSection("TARGET STATUS", 66)

local StatusDot = Instance.new("Frame")
StatusDot.Size = UDim2.fromOffset(8, 8)
StatusDot.Position = UDim2.new(0, 14, 0, 35)
StatusDot.BackgroundColor3 = Color3.fromRGB(90, 90, 95)
StatusDot.BorderSizePixel = 0
StatusDot.Parent = StatusSection

local StatusDotCorner = Instance.new("UICorner")
StatusDotCorner.CornerRadius = UDim.new(1, 0)
StatusDotCorner.Parent = StatusDot

local StatusText = Instance.new("TextLabel")
StatusText.BackgroundTransparency = 1
StatusText.Position = UDim2.new(0, 31, 0, 29)
StatusText.Size = UDim2.new(1, -42, 0, 22)
StatusText.Text = "UNLOCKED"
StatusText.TextColor3 = Color3.fromRGB(170, 170, 175)
StatusText.Font = Enum.Font.GothamBold
StatusText.TextSize = 12
StatusText.TextXAlignment = Enum.TextXAlignment.Left
StatusText.Parent = StatusSection

local StatusButtonText = Instance.new("TextLabel")
StatusButtonText.BackgroundTransparency = 1
StatusButtonText.Position = UDim2.new(1, -80, 0, 29)
StatusButtonText.Size = UDim2.fromOffset(66, 22)
StatusButtonText.Text = "Y"
StatusButtonText.TextColor3 = Color3.fromRGB(220, 45, 55)
StatusButtonText.Font = Enum.Font.GothamBlack
StatusButtonText.TextSize = 13
StatusButtonText.TextXAlignment = Enum.TextXAlignment.Right
StatusButtonText.Parent = StatusSection

--==================================================
-- MODE SECTION
--==================================================

local ModeSection = CreateSection("CAMERA MODE", 91)

local ModeButton = Instance.new("TextButton")
ModeButton.Size = UDim2.new(1, -26, 0, 39)
ModeButton.Position = UDim2.new(0, 13, 0, 39)
ModeButton.BackgroundColor3 = Color3.fromRGB(23, 23, 27)
ModeButton.BorderSizePixel = 0
ModeButton.Text = ""
ModeButton.AutoButtonColor = false
ModeButton.Parent = ModeSection

local ModeCorner = Instance.new("UICorner")
ModeCorner.CornerRadius = UDim.new(0, 8)
ModeCorner.Parent = ModeButton

local ModeText = Instance.new("TextLabel")
ModeText.BackgroundTransparency = 1
ModeText.Position = UDim2.new(0, 12, 0, 0)
ModeText.Size = UDim2.new(1, -40, 1, 0)
ModeText.Text = CurrentMode
ModeText.TextColor3 = Color3.fromRGB(235, 235, 238)
ModeText.Font = Enum.Font.GothamSemibold
ModeText.TextSize = 11
ModeText.TextXAlignment = Enum.TextXAlignment.Left
ModeText.Parent = ModeButton

local ModeArrow = Instance.new("TextLabel")
ModeArrow.BackgroundTransparency = 1
ModeArrow.Position = UDim2.new(1, -30, 0, 0)
ModeArrow.Size = UDim2.fromOffset(20, 39)
ModeArrow.Text = "⌄"
ModeArrow.TextColor3 = Color3.fromRGB(130, 130, 135)
ModeArrow.Font = Enum.Font.GothamBold
ModeArrow.TextSize = 15
ModeArrow.Parent = ModeButton

--==================================================
-- DROPDOWN
--==================================================

local Dropdown = Instance.new("Frame")
Dropdown.Name = "Dropdown"
Dropdown.Size = UDim2.new(1, -26, 0, 82)
Dropdown.Position = UDim2.new(0, 13, 0, 80)
Dropdown.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
Dropdown.BorderSizePixel = 0
Dropdown.Visible = false
Dropdown.ZIndex = 20
Dropdown.Parent = ModeSection

local DropdownCorner = Instance.new("UICorner")
DropdownCorner.CornerRadius = UDim.new(0, 8)
DropdownCorner.Parent = Dropdown

local function CreateModeOption(text, y)
	local Button = Instance.new("TextButton")
	Button.Size = UDim2.new(1, -8, 0, 34)
	Button.Position = UDim2.new(0, 4, 0, y)
	Button.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
	Button.BorderSizePixel = 0
	Button.Text = text
	Button.TextColor3 = Color3.fromRGB(215, 215, 220)
	Button.Font = Enum.Font.GothamMedium
	Button.TextSize = 10
	Button.TextXAlignment = Enum.TextXAlignment.Left
	Button.AutoButtonColor = false
	Button.ZIndex = 21
	Button.Parent = Dropdown

	local Padding = Instance.new("UIPadding")
	Padding.PaddingLeft = UDim.new(0, 10)
	Padding.Parent = Button

	Button.MouseEnter:Connect(function()
		Button.BackgroundColor3 = Color3.fromRGB(38, 38, 43)
	end)

	Button.MouseLeave:Connect(function()
		Button.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
	end)

	Button.MouseButton1Click:Connect(function()
		CurrentMode = text
		ModeText.Text = text
		Dropdown.Visible = false
		DropdownOpen = false
	end)

	return Button
end

CreateModeOption("First Person", 4)
CreateModeOption("Third Person", 42)

ModeButton.MouseButton1Click:Connect(function()
	DropdownOpen = not DropdownOpen
	Dropdown.Visible = DropdownOpen
	ModeArrow.Text = DropdownOpen and "⌃" or "⌄"
end)

--==================================================
-- INPUT FIELD HELPER
--==================================================

local function CreateInputSection(title, description, defaultValue, height)
	local Section = CreateSection(title, height)

	local Desc = Instance.new("TextLabel")
	Desc.BackgroundTransparency = 1
	Desc.Position = UDim2.new(0, 13, 0, 30)
	Desc.Size = UDim2.new(1, -100, 0, 26)
	Desc.Text = description
	Desc.TextColor3 = Color3.fromRGB(105, 105, 112)
	Desc.Font = Enum.Font.GothamMedium
	Desc.TextSize = 8
	Desc.TextWrapped = true
	Desc.TextXAlignment = Enum.TextXAlignment.Left
	Desc.Parent = Section

	local Box = Instance.new("TextBox")
	Box.Size = UDim2.fromOffset(75, 38)
	Box.Position = UDim2.new(1, -88, 0, 34)
	Box.BackgroundColor3 = Color3.fromRGB(24, 24, 28)
	Box.BorderSizePixel = 0
	Box.Text = tostring(defaultValue)
	Box.PlaceholderText = tostring(defaultValue)
	Box.TextColor3 = Color3.fromRGB(240, 240, 243)
	Box.PlaceholderColor3 = Color3.fromRGB(100, 100, 105)
	Box.Font = Enum.Font.GothamBold
	Box.TextSize = 11
	Box.ClearTextOnFocus = false
	Box.Parent = Section

	local Corner = Instance.new("UICorner")
	Corner.CornerRadius = UDim.new(0, 8)
	Corner.Parent = Box

	local Stroke = Instance.new("UIStroke")
	Stroke.Color = Color3.fromRGB(45, 45, 50)
	Stroke.Thickness = 1
	Stroke.Parent = Box

	return Section, Box
end

--==================================================
-- AIM OFFSET
--==================================================

local OffsetSection, OffsetBox = CreateInputSection(
	"AIM OFFSET",
	"Third Person • Positive = below target",
	DefaultOffset,
	79
)

local OffsetRecommendation = Instance.new("TextLabel")
OffsetRecommendation.BackgroundTransparency = 1
OffsetRecommendation.Position = UDim2.new(0, 13, 1, -18)
OffsetRecommendation.Size = UDim2.new(1, -100, 0, 12)
OffsetRecommendation.Text = "HEAD ≈ -2.5   •   TORSO ≈ 0"
OffsetRecommendation.TextColor3 = Color3.fromRGB(190, 45, 55)
OffsetRecommendation.Font = Enum.Font.GothamBold
OffsetRecommendation.TextSize = 7
OffsetRecommendation.TextXAlignment = Enum.TextXAlignment.Left
OffsetRecommendation.Parent = OffsetSection

OffsetBox.FocusLost:Connect(function()
	AimOffset = ClampNumber(OffsetBox.Text, DefaultOffset)
	OffsetBox.Text = tostring(AimOffset)
end)

--==================================================
-- SMOOTHING
--==================================================

local SmoothingSection, SmoothingBox = CreateInputSection(
	"SMOOTHING",
	"0 = instant • Higher = smoother camera movement",
	DefaultSmoothing,
	79
)

SmoothingBox.FocusLost:Connect(function()
	Smoothing = math.max(0, ClampNumber(SmoothingBox.Text, DefaultSmoothing))
	SmoothingBox.Text = string.format("%.2f", Smoothing)
end)

--==================================================
-- PREDICTION
--==================================================

local PredictionSection, PredictionBox = CreateInputSection(
	"PREDICTION",
	"Compensates for target movement before camera lock",
	DefaultPrediction,
	79
)

PredictionBox.FocusLost:Connect(function()
	Prediction = math.max(0, ClampNumber(PredictionBox.Text, DefaultPrediction))
	PredictionBox.Text = string.format("%.2f", Prediction)
end)

--==================================================
-- LOCK BUTTON
--==================================================

local LockSection = CreateSection("LOCK BUTTON", 82)

local LockDescription = Instance.new("TextLabel")
LockDescription.BackgroundTransparency = 1
LockDescription.Position = UDim2.new(0, 13, 0, 31)
LockDescription.Size = UDim2.new(1, -115, 0, 35)
LockDescription.Text = "Controller input used to toggle target lock."
LockDescription.TextColor3 = Color3.fromRGB(105, 105, 112)
LockDescription.Font = Enum.Font.GothamMedium
LockDescription.TextSize = 8
LockDescription.TextWrapped = true
LockDescription.TextXAlignment = Enum.TextXAlignment.Left
LockDescription.Parent = LockSection

local SetButton = Instance.new("TextButton")
SetButton.Size = UDim2.fromOffset(82, 38)
SetButton.Position = UDim2.new(1, -95, 0, 30)
SetButton.BackgroundColor3 = Color3.fromRGB(145, 27, 35)
SetButton.BorderSizePixel = 0
SetButton.Text = "BUTTON Y"
SetButton.TextColor3 = Color3.fromRGB(255, 255, 255)
SetButton.Font = Enum.Font.GothamBold
SetButton.TextSize = 8
SetButton.AutoButtonColor = false
SetButton.Parent = LockSection

local SetCorner = Instance.new("UICorner")
SetCorner.CornerRadius = UDim.new(0, 8)
SetCorner.Parent = SetButton

SetButton.MouseEnter:Connect(function()
	SetButton.BackgroundColor3 = Color3.fromRGB(185, 32, 42)
end)

SetButton.MouseLeave:Connect(function()
	if not WaitingForButton then
		SetButton.BackgroundColor3 = Color3.fromRGB(145, 27, 35)
	end
end)

--==================================================
-- GUIDE
--==================================================

local GuideSection = CreateSection("MODE GUIDE", 103)

local GuideText = Instance.new("TextLabel")
GuideText.BackgroundTransparency = 1
GuideText.Position = UDim2.new(0, 13, 0, 31)
GuideText.Size = UDim2.new(1, -26, 0, 62)
GuideText.Text =
	"THIRD PERSON\n" ..
	"Camera aims around the torso / lower body.\n\n" ..
	"FIRST PERSON\n" ..
	"Camera aims directly toward the target's head."

GuideText.TextColor3 = Color3.fromRGB(145, 145, 151)
GuideText.Font = Enum.Font.GothamMedium
GuideText.TextSize = 8
GuideText.TextWrapped = true
GuideText.TextXAlignment = Enum.TextXAlignment.Left
GuideText.TextYAlignment = Enum.TextYAlignment.Top
GuideText.Parent = GuideSection

--==================================================
-- FOOTER
--==================================================

local Footer = Instance.new("TextLabel")
Footer.BackgroundTransparency = 1
Footer.Size = UDim2.new(1, -2, 0, 18)
Footer.Text = "XENON  //  CONTROLLER SYSTEM"
Footer.TextColor3 = Color3.fromRGB(65, 65, 70)
Footer.Font = Enum.Font.GothamBold
Footer.TextSize = 7
Footer.TextXAlignment = Enum.TextXAlignment.Center
Footer.LayoutOrder = 99
Footer.Parent = Content

--==================================================
-- FLOATING REOPEN BUTTON
--==================================================

local Reopen = Instance.new("TextButton")
Reopen.Name = "Reopen"
Reopen.Size = UDim2.fromOffset(48, 48)
Reopen.Position = UDim2.new(1, -68, 0, 20)
Reopen.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
Reopen.BorderSizePixel = 0
Reopen.Text = "X"
Reopen.TextColor3 = Color3.fromRGB(230, 35, 45)
Reopen.Font = Enum.Font.GothamBlack
Reopen.TextSize = 19
Reopen.Visible = false
Reopen.AutoButtonColor = false
Reopen.Parent = ScreenGui

local ReopenCorner = Instance.new("UICorner")
ReopenCorner.CornerRadius = UDim.new(1, 0)
ReopenCorner.Parent = Reopen

local ReopenStroke = Instance.new("UIStroke")
ReopenStroke.Color = Color3.fromRGB(120, 25, 32)
ReopenStroke.Thickness = 1.5
ReopenStroke.Parent = Reopen

--==================================================
-- UI VISIBILITY
--==================================================

local function CloseUI()
	UIVisible = false
	Main.Visible = false
	Reopen.Visible = true
end

local function OpenUI()
	UIVisible = true
	Main.Visible = true
	Reopen.Visible = false
end

CloseButton.MouseButton1Click:Connect(CloseUI)
Reopen.MouseButton1Click:Connect(OpenUI)

--==================================================
-- DRAGGING
--==================================================

local Dragging = false
local DragStart
local StartPosition

Header.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then

		Dragging = true
		DragStart = input.Position
		StartPosition = Main.Position

		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
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
		and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end

	local Delta = input.Position - DragStart

	Main.Position = UDim2.new(
		StartPosition.X.Scale,
		StartPosition.X.Offset + Delta.X,
		StartPosition.Y.Scale,
		StartPosition.Y.Offset + Delta.Y
	)
end)

--==================================================
-- TARGET FINDER
--==================================================

local function GetClosestTarget()
	local ClosestPlayer = nil
	local ClosestDistance = math.huge

	local Viewport = Camera.ViewportSize
	local ScreenCenter = Vector2.new(
		Viewport.X / 2,
		Viewport.Y / 2
	)

	for _, Player in ipairs(Players:GetPlayers()) do

		if Player ~= LocalPlayer then

			local Character = Player.Character

			if Character then

				local Humanoid = Character:FindFirstChildOfClass("Humanoid")
				local Root = Character:FindFirstChild("HumanoidRootPart")

				if Humanoid
					and Root
					and Humanoid.Health > 0 then

					local DistanceFromCamera =
						(Camera.CFrame.Position - Root.Position).Magnitude

					if DistanceFromCamera <= MaxTargetDistance then

						local ScreenPosition, OnScreen =
							Camera:WorldToViewportPoint(Root.Position)

						if OnScreen then

							local ScreenDistance =
								(Vector2.new(
									ScreenPosition.X,
									ScreenPosition.Y
								) - ScreenCenter).Magnitude

							if ScreenDistance < ClosestDistance then
								ClosestDistance = ScreenDistance
								ClosestPlayer = Player
							end

						end
					end
				end
			end
		end
	end

	return ClosestPlayer
end

--==================================================
-- VALID TARGET
--==================================================

local function IsValidTarget(Player)

	if not Player then
		return false
	end

	if Player.Parent ~= Players then
		return false
	end

	local Character = Player.Character

	if not Character then
		return false
	end

	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	local Root = Character:FindFirstChild("HumanoidRootPart")

	if not Humanoid or not Root then
		return false
	end

	if Humanoid.Health <= 0 then
		return false
	end

	return true
end

--==================================================
-- UI STATUS
--==================================================

local function UpdateStatus()

	StatusButtonText.Text = GetButtonName(LockButton)

	if IsLocked and IsValidTarget(LockedTarget) then

		StatusText.Text = "LOCKED"
		StatusText.TextColor3 = Color3.fromRGB(240, 240, 243)

		StatusDot.BackgroundColor3 =
			Color3.fromRGB(230, 40, 50)

		StatusButtonText.TextColor3 =
			Color3.fromRGB(235, 40, 50)

	else

		StatusText.Text = "UNLOCKED"
		StatusText.TextColor3 =
			Color3.fromRGB(170, 170, 175)

		StatusDot.BackgroundColor3 =
			Color3.fromRGB(80, 80, 86)

		StatusButtonText.TextColor3 =
			Color3.fromRGB(170, 40, 48)

	end
end

--==================================================
-- LOCK
--==================================================

local function Unlock()

	IsLocked = false
	LockedTarget = nil

	UpdateStatus()
end

local function Lock()

	local Target = GetClosestTarget()

	if not Target then
		return
	end

	LockedTarget = Target
	IsLocked = true

	UpdateStatus()
end

local function ToggleLock()

	if IsLocked then
		Unlock()
	else
		Lock()
	end
end

--==================================================
-- CONTROLLER BUTTON CONFIG
--==================================================

SetButton.MouseButton1Click:Connect(function()

	if WaitingForButton then
		return
	end

	WaitingForButton = true

	SetButton.Text = "PRESS..."
	SetButton.BackgroundColor3 =
		Color3.fromRGB(190, 35, 45)
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)

	-- Controller button configuration
	if WaitingForButton then

		if IsGamepadInput(input) then

			local Key = input.KeyCode

			if ButtonNames[Key] then

				LockButton = Key
				WaitingForButton = false

				SetButton.Text =
					"BUTTON " .. GetButtonName(LockButton)

				SetButton.BackgroundColor3 =
					Color3.fromRGB(145, 27, 35)

				UpdateStatus()
			end
		end

		return
	end

	-- Actual lock input
	if IsGamepadInput(input) then

		if input.KeyCode == LockButton then
			ToggleLock()
		end
	end
end)

--==================================================
-- PLAYER REMOVING
--==================================================

Players.PlayerRemoving:Connect(function(Player)

	if Player == LockedTarget then
		Unlock()
	end

end)

--==================================================
-- CHARACTER RESET
--==================================================

LocalPlayer.CharacterAdded:Connect(function()
	Unlock()
end)

--==================================================
-- CAMERA LOCK
--==================================================

RunService:BindToRenderStep(
	"XenonCameraLock",
	Enum.RenderPriority.Camera.Value + 1,
	function(DeltaTime)

		if not IsLocked then
			return
		end

		if not IsValidTarget(LockedTarget) then
			Unlock()
			return
		end

		local Character = LockedTarget.Character
		local Root = Character:FindFirstChild("HumanoidRootPart")

		if not Root then
			Unlock()
			return
		end

		local AimPosition

		--==========================================
		-- FIRST PERSON
		--==========================================

		if CurrentMode == "First Person" then

			local Head = Character:FindFirstChild("Head")

			if not Head then
				Unlock()
				return
			end

			AimPosition =
				Head.Position
				+ Head.AssemblyLinearVelocity * Prediction

		--==========================================
		-- THIRD PERSON
		--==========================================

		else

			AimPosition =
				Root.Position
				+ Root.AssemblyLinearVelocity * Prediction

			-- Positive = below root
			-- Negative = above root

			AimPosition =
				AimPosition
				- Vector3.new(0, AimOffset, 0)
		end

		local CameraPosition = Camera.CFrame.Position

		local DesiredCFrame =
			CFrame.lookAt(
				CameraPosition,
				AimPosition
			)

		--==========================================
		-- SMOOTHING
		--==========================================

		if Smoothing <= 0 then

			Camera.CFrame = DesiredCFrame

		else

			local Alpha =
				1 - math.exp(
					-Smoothing * DeltaTime * 60
				)

			Alpha = math.clamp(
				Alpha,
				0,
				1
			)

			Camera.CFrame =
				Camera.CFrame:Lerp(
					DesiredCFrame,
					Alpha
				)
		end
	end
)

--==================================================
-- INITIAL STATUS
--==================================================

SetButton.Text =
	"BUTTON " .. GetButtonName(LockButton)

UpdateStatus()
