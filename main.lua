--[[
=========================================================
                    XENON
             CONTROLLER CAMERA LOCK
=========================================================

    Xbox + PlayStation Controller Support

    Features:
    • Controller-only lock input
    • Custom controller lock button
    • Sticky target
    • Closest player to controller cursor
    • Adjustable HumanoidRootPart offset
    • Positive number = aim BELOW root
    • Negative number = aim ABOVE root
    • Head / torso recommendations
    • Modern Xenon UI
    • Red / Black / White theme
    • PC / Mobile responsive sizing
    • Draggable top bar
    • Top-right X UI toggle
=========================================================
]]

--========================================================
-- SERVICES
--========================================================

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

--========================================================
-- PLAYER
--========================================================

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

--========================================================
-- CAMERA
--========================================================

local Camera = workspace.CurrentCamera

--========================================================
-- DEFAULT SETTINGS
--========================================================

local LockButton = Enum.KeyCode.ButtonY

-- Positive = below root
-- Negative = above root
local AimOffset = 7

local CameraSmoothness = 0.30
local MaxTargetDistance = 500

--========================================================
-- STATE
--========================================================

local IsLocked = false
local LockedTarget = nil

local WaitingForButton = false
local UIVisible = true

--========================================================
-- CONTROLLER CHECK
--========================================================

local function IsControllerInput(Input)

	if not Input then
		return false
	end

	local Type = Input.UserInputType

	return
		Type == Enum.UserInputType.Gamepad1
		or Type == Enum.UserInputType.Gamepad2
		or Type == Enum.UserInputType.Gamepad3
		or Type == Enum.UserInputType.Gamepad4
		or Type == Enum.UserInputType.Gamepad5
		or Type == Enum.UserInputType.Gamepad6
		or Type == Enum.UserInputType.Gamepad7
		or Type == Enum.UserInputType.Gamepad8
end

--========================================================
-- CONTROLLER BUTTON NAMES
--========================================================

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

	[Enum.KeyCode.DPadUp] = "D-Pad Up",
	[Enum.KeyCode.DPadDown] = "D-Pad Down",
	[Enum.KeyCode.DPadLeft] = "D-Pad Left",
	[Enum.KeyCode.DPadRight] = "D-Pad Right",

	[Enum.KeyCode.ButtonStart] = "Start",
	[Enum.KeyCode.ButtonSelect] = "Select",
}

local function GetButtonName(KeyCode)

	return ButtonNames[KeyCode] or KeyCode.Name

end

--========================================================
-- GUI
--========================================================

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "Xenon"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = PlayerGui

--========================================================
-- RESPONSIVE SIZE
--========================================================

local IsMobile =
	UserInputService.TouchEnabled
	and not UserInputService.KeyboardEnabled

local MainWidth
local MainHeight

if IsMobile then

	MainWidth = 245
	MainHeight = 245

else

	MainWidth = 330
	MainHeight = 255

end

--========================================================
-- MAIN WINDOW
--========================================================

local Main = Instance.new("Frame")
Main.Name = "XenonWindow"

Main.Size = UDim2.fromOffset(
	MainWidth,
	MainHeight
)

Main.Position = UDim2.new(
	0.5,
	-MainWidth / 2,
	0.5,
	-MainHeight / 2
)

Main.BackgroundColor3 = Color3.fromRGB(15, 15, 17)
Main.BorderSizePixel = 0

Main.Active = true
Main.Parent = ScreenGui

--========================================================
-- MAIN CORNER
--========================================================

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 8)
MainCorner.Parent = Main

--========================================================
-- OUTLINE
--========================================================

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(70, 70, 75)
MainStroke.Thickness = 1
MainStroke.Transparency = 0
MainStroke.Parent = Main

--========================================================
-- TOP BAR
--========================================================

local TopBar = Instance.new("Frame")
TopBar.Name = "TopBar"

TopBar.Size = UDim2.new(1, 0, 0, 38)

TopBar.BackgroundColor3 = Color3.fromRGB(22, 22, 25)
TopBar.BorderSizePixel = 0

TopBar.Active = true
TopBar.Parent = Main

--========================================================
-- RED TOP ACCENT
--========================================================

local RedAccent = Instance.new("Frame")
RedAccent.Name = "RedAccent"

RedAccent.Size = UDim2.new(0, 4, 1, 0)

RedAccent.BackgroundColor3 = Color3.fromRGB(220, 25, 35)
RedAccent.BorderSizePixel = 0

RedAccent.Parent = TopBar

--========================================================
-- XENON TITLE
--========================================================

local Title = Instance.new("TextLabel")
Title.Name = "Title"

Title.Size = UDim2.new(1, -60, 1, 0)
Title.Position = UDim2.fromOffset(14, 0)

Title.BackgroundTransparency = 1

Title.Text = "XENON"
Title.TextColor3 = Color3.fromRGB(245, 245, 245)
Title.TextSize = 17
Title.Font = Enum.Font.GothamBold
Title.TextXAlignment = Enum.TextXAlignment.Left

Title.Parent = TopBar

--========================================================
-- SUBTITLE
--========================================================

local Subtitle = Instance.new("TextLabel")
Subtitle.Name = "Subtitle"

Subtitle.Size = UDim2.new(1, -60, 1, 0)
Subtitle.Position = UDim2.fromOffset(77, 0)

Subtitle.BackgroundTransparency = 1

Subtitle.Text = "CONTROLLER LOCK"
Subtitle.TextColor3 = Color3.fromRGB(125, 125, 130)
Subtitle.TextSize = 9
Subtitle.Font = Enum.Font.GothamMedium
Subtitle.TextXAlignment = Enum.TextXAlignment.Left

Subtitle.Parent = TopBar

--========================================================
-- TOP RIGHT X
--========================================================

local ToggleUI = Instance.new("TextButton")
ToggleUI.Name = "ToggleUI"

ToggleUI.Size = UDim2.fromOffset(34, 34)
ToggleUI.Position = UDim2.new(1, -37, 0, 2)

ToggleUI.BackgroundColor3 = Color3.fromRGB(28, 28, 31)
ToggleUI.BorderSizePixel = 0

ToggleUI.Text = "×"
ToggleUI.TextColor3 = Color3.fromRGB(235, 235, 235)
ToggleUI.TextSize = 29
ToggleUI.Font = Enum.Font.GothamBold

ToggleUI.Parent = TopBar

local ToggleCorner = Instance.new("UICorner")
ToggleCorner.CornerRadius = UDim.new(0, 6)
ToggleCorner.Parent = ToggleUI

--========================================================
-- STATUS
--========================================================

local Status = Instance.new("TextLabel")
Status.Name = "Status"

Status.Size = UDim2.new(1, -24, 0, 24)
Status.Position = UDim2.fromOffset(12, 49)

Status.BackgroundTransparency = 1

Status.Text = "LOCK BUTTON  •  Y"
Status.TextColor3 = Color3.fromRGB(210, 210, 215)
Status.TextSize = 12
Status.Font = Enum.Font.GothamMedium
Status.TextXAlignment = Enum.TextXAlignment.Left

Status.Parent = Main

--========================================================
-- LOCK STATUS
--========================================================

local LockStatus = Instance.new("TextLabel")
LockStatus.Name = "LockStatus"

LockStatus.Size = UDim2.new(1, -24, 0, 20)
LockStatus.Position = UDim2.fromOffset(12, 70)

LockStatus.BackgroundTransparency = 1

LockStatus.Text = "●  UNLOCKED"
LockStatus.TextColor3 = Color3.fromRGB(150, 150, 155)
LockStatus.TextSize = 10
LockStatus.Font = Enum.Font.GothamMedium
LockStatus.TextXAlignment = Enum.TextXAlignment.Left

LockStatus.Parent = Main

--========================================================
-- OFFSET LABEL
--========================================================

local OffsetLabel = Instance.new("TextLabel")
OffsetLabel.Name = "OffsetLabel"

OffsetLabel.Size = UDim2.new(1, -24, 0, 20)
OffsetLabel.Position = UDim2.fromOffset(12, 95)

OffsetLabel.BackgroundTransparency = 1

OffsetLabel.Text = "AIM OFFSET FROM HUMANOID ROOT"
OffsetLabel.TextColor3 = Color3.fromRGB(180, 180, 185)
OffsetLabel.TextSize = 10
OffsetLabel.Font = Enum.Font.GothamMedium
OffsetLabel.TextXAlignment = Enum.TextXAlignment.Left

OffsetLabel.Parent = Main

--========================================================
-- OFFSET BOX
--========================================================

local OffsetBox = Instance.new("TextBox")
OffsetBox.Name = "OffsetBox"

OffsetBox.Size = UDim2.new(1, -24, 0, 34)
OffsetBox.Position = UDim2.fromOffset(12, 117)

OffsetBox.BackgroundColor3 = Color3.fromRGB(24, 24, 27)
OffsetBox.BorderSizePixel = 0

OffsetBox.Text = tostring(AimOffset)

OffsetBox.PlaceholderText = "7"
OffsetBox.PlaceholderColor3 = Color3.fromRGB(90, 90, 95)

OffsetBox.TextColor3 = Color3.fromRGB(240, 240, 240)
OffsetBox.TextSize = 13
OffsetBox.Font = Enum.Font.GothamMedium

OffsetBox.ClearTextOnFocus = false

OffsetBox.Parent = Main

local OffsetStroke = Instance.new("UIStroke")
OffsetStroke.Color = Color3.fromRGB(55, 55, 60)
OffsetStroke.Thickness = 1
OffsetStroke.Parent = OffsetBox

local OffsetCorner = Instance.new("UICorner")
OffsetCorner.CornerRadius = UDim.new(0, 5)
OffsetCorner.Parent = OffsetBox

--========================================================
-- RECOMMENDATIONS
--========================================================

local Recommendation = Instance.new("TextLabel")
Recommendation.Name = "Recommendation"

Recommendation.Size = UDim2.new(1, -24, 0, 32)
Recommendation.Position = UDim2.fromOffset(12, 155)

Recommendation.BackgroundTransparency = 1

Recommendation.Text =
	"HEAD  ≈  -2.5     •     TORSO  ≈  0"

Recommendation.TextColor3 = Color3.fromRGB(135, 135, 140)
Recommendation.TextSize = 9
Recommendation.Font = Enum.Font.GothamMedium
Recommendation.TextXAlignment = Enum.TextXAlignment.Left

Recommendation.Parent = Main

--========================================================
-- SET BUTTON
--========================================================

local SetButton = Instance.new("TextButton")
SetButton.Name = "SetButton"

SetButton.Size = UDim2.new(1, -24, 0, 34)
SetButton.Position = UDim2.new(0, 12, 1, -46)

SetButton.BackgroundColor3 = Color3.fromRGB(190, 25, 35)
SetButton.BorderSizePixel = 0

SetButton.Text = "SET LOCK BUTTON"
SetButton.TextColor3 = Color3.fromRGB(255, 255, 255)
SetButton.TextSize = 11
SetButton.Font = Enum.Font.GothamBold

SetButton.Parent = Main

local SetCorner = Instance.new("UICorner")
SetCorner.CornerRadius = UDim.new(0, 5)
SetCorner.Parent = SetButton

--========================================================
-- FLOATING OPEN BUTTON
--========================================================

local FloatingButton = Instance.new("TextButton")
FloatingButton.Name = "FloatingToggle"

FloatingButton.Size = UDim2.fromOffset(45, 45)
FloatingButton.Position = UDim2.new(1, -58, 0, 12)

FloatingButton.BackgroundColor3 = Color3.fromRGB(16, 16, 18)
FloatingButton.BorderSizePixel = 0

FloatingButton.Text = "×"
FloatingButton.TextColor3 = Color3.fromRGB(230, 30, 40)
FloatingButton.TextSize = 34
FloatingButton.Font = Enum.Font.GothamBold

FloatingButton.Visible = false

FloatingButton.Parent = ScreenGui

local FloatingCorner = Instance.new("UICorner")
FloatingCorner.CornerRadius = UDim.new(0, 8)
FloatingCorner.Parent = FloatingButton

local FloatingStroke = Instance.new("UIStroke")
FloatingStroke.Color = Color3.fromRGB(200, 25, 35)
FloatingStroke.Thickness = 1
FloatingStroke.Parent = FloatingButton

--========================================================
-- UI UPDATE
--========================================================

local function UpdateUI()

	Status.Text =
		"LOCK BUTTON  •  "
		.. GetButtonName(LockButton)

	if IsLocked then

		LockStatus.Text = "●  LOCKED"

		LockStatus.TextColor3 =
			Color3.fromRGB(225, 35, 45)

	else

		LockStatus.Text = "●  UNLOCKED"

		LockStatus.TextColor3 =
			Color3.fromRGB(150, 150, 155)

	end

end

UpdateUI()

--========================================================
-- UI TOGGLE
--========================================================

local function SetUIVisible(Visible)

	UIVisible = Visible

	Main.Visible = Visible

	FloatingButton.Visible = not Visible

end

ToggleUI.MouseButton1Click:Connect(function()

	SetUIVisible(false)

end)

FloatingButton.MouseButton1Click:Connect(function()

	SetUIVisible(true)

end)

--========================================================
-- DRAGGING
--========================================================

local Dragging = false
local DragStart
local StartPosition

TopBar.InputBegan:Connect(function(Input)

	if Input.UserInputType == Enum.UserInputType.MouseButton1
		or Input.UserInputType == Enum.UserInputType.Touch then

		Dragging = true

		DragStart = Input.Position
		StartPosition = Main.Position

	end

end)

TopBar.InputEnded:Connect(function(Input)

	if Input.UserInputType == Enum.UserInputType.MouseButton1
		or Input.UserInputType == Enum.UserInputType.Touch then

		Dragging = false

	end

end)

UserInputService.InputChanged:Connect(function(Input)

	if not Dragging then
		return
	end

	if Input.UserInputType ~= Enum.UserInputType.MouseMovement
		and Input.UserInputType ~= Enum.UserInputType.Touch then

		return
	end

	local Delta = Input.Position - DragStart

	Main.Position = UDim2.new(
		StartPosition.X.Scale,
		StartPosition.X.Offset + Delta.X,

		StartPosition.Y.Scale,
		StartPosition.Y.Offset + Delta.Y
	)

end)

--========================================================
-- OFFSET VALIDATION
--========================================================

local function UpdateOffset()

	local Text = OffsetBox.Text

	local Number = tonumber(Text)

	if Number == nil then

		OffsetBox.Text = tostring(AimOffset)

		return

	end

	-- Prevent NaN / infinity style values.
	if Number ~= Number
		or Number == math.huge
		or Number == -math.huge then

		OffsetBox.Text = tostring(AimOffset)

		return

	end

	AimOffset = Number

end

OffsetBox.FocusLost:Connect(function()

	UpdateOffset()

end)

--========================================================
-- RECOMMENDATION CLICK
--========================================================

Recommendation.Active = true

Recommendation.InputBegan:Connect(function(Input)

	if Input.UserInputType ~= Enum.UserInputType.MouseButton1
		and Input.UserInputType ~= Enum.UserInputType.Touch then

		return
	end

	-- No automatic change here.
	-- Recommendations are displayed so the user
	-- can manually enter the desired value.

end)

--========================================================
-- CHARACTER INFO
--========================================================

local function GetCharacterInfo(Player)

	if not Player then
		return nil
	end

	local Character = Player.Character

	if not Character then
		return nil
	end

	local Humanoid =
		Character:FindFirstChildOfClass("Humanoid")

	local Root =
		Character:FindFirstChild("HumanoidRootPart")

	if not Humanoid or not Root then
		return nil
	end

	if Humanoid.Health <= 0 then
		return nil
	end

	return Character, Humanoid, Root

end

--========================================================
-- VALID TARGET
--========================================================

local function IsValidTarget(Player)

	if not Player then
		return false
	end

	if Player == LocalPlayer then
		return false
	end

	local Character, Humanoid, Root =
		GetCharacterInfo(Player)

	if not Character or not Humanoid or not Root then
		return false
	end

	local LocalCharacter = LocalPlayer.Character

	if not LocalCharacter then
		return false
	end

	local LocalRoot =
		LocalCharacter:FindFirstChild("HumanoidRootPart")

	if not LocalRoot then
		return false
	end

	local Distance =
		(Root.Position - LocalRoot.Position).Magnitude

	if Distance > MaxTargetDistance then
		return false
	end

	return true

end

--========================================================
-- FIND CLOSEST TO CONTROLLER CURSOR
--========================================================

local function FindClosestTarget()

	local ViewportSize = Camera.ViewportSize

	local CursorPosition = Vector2.new(
		ViewportSize.X / 2,
		ViewportSize.Y / 2
	)

	local ClosestPlayer = nil
	local ClosestDistance = math.huge

	for _, Player in ipairs(Players:GetPlayers()) do

		if IsValidTarget(Player) then

			local Character, Humanoid, Root =
				GetCharacterInfo(Player)

			if Character and Humanoid and Root then

				local ScreenPosition, OnScreen =
					Camera:WorldToViewportPoint(
						Root.Position
					)

				if OnScreen and ScreenPosition.Z > 0 then

					local TargetPosition =
						Vector2.new(
							ScreenPosition.X,
							ScreenPosition.Y
						)

					local Distance =
						(TargetPosition - CursorPosition).Magnitude

					if Distance < ClosestDistance then

						ClosestDistance = Distance
						ClosestPlayer = Player

					end

				end

			end

		end

	end

	return ClosestPlayer

end

--========================================================
-- UNLOCK
--========================================================

local function Unlock()

	IsLocked = false
	LockedTarget = nil

	UpdateUI()

end

--========================================================
-- LOCK
--========================================================

local function Lock()

	-- Target is selected ONLY when locking.
	local Target = FindClosestTarget()

	if not Target then
		return
	end

	LockedTarget = Target
	IsLocked = true

	UpdateUI()

end

--========================================================
-- TOGGLE LOCK
--========================================================

local function ToggleLock()

	if IsLocked then

		Unlock()

	else

		Lock()

	end

end

--========================================================
-- SET CONTROLLER BUTTON
--========================================================

SetButton.MouseButton1Click:Connect(function()

	WaitingForButton = true

	SetButton.Text = "PRESS CONTROLLER BUTTON"

	Status.Text = "WAITING FOR CONTROLLER..."

end)

--========================================================
-- INPUT
--========================================================

UserInputService.InputBegan:Connect(function(Input, GameProcessed)

	--====================================================
	-- SETTING A NEW LOCK BUTTON
	--====================================================

	if WaitingForButton then

		if not IsControllerInput(Input) then
			return
		end

		if Input.KeyCode == Enum.KeyCode.Unknown then
			return
		end

		LockButton = Input.KeyCode

		WaitingForButton = false

		SetButton.Text = "SET LOCK BUTTON"

		UpdateUI()

		return

	end

	--====================================================
	-- NORMAL LOCK INPUT
	--====================================================

	if not IsControllerInput(Input) then
		return
	end

	if GameProcessed then
		return
	end

	if Input.KeyCode == LockButton then

		ToggleLock()

	end

end)

--========================================================
-- CAMERA LOCK
--========================================================

RunService:BindToRenderStep(
	"XenonCameraLock",
	Enum.RenderPriority.Camera.Value + 1,

	function(DeltaTime)

		if not IsLocked then
			return
		end

		--================================================
		-- STICKY TARGET
		--
		-- NEVER search for another player here.
		--================================================

		if not LockedTarget then

			Unlock()

			return

		end

		local Character, Humanoid, Root =
			GetCharacterInfo(LockedTarget)

		-- Original target is gone/dead.
		-- Unlock instead of switching targets.
		if not Character or not Humanoid or not Root then

			Unlock()

			return

		end

		--================================================
		-- AIM OFFSET
		--
		-- +7 = 7 studs below root
		-- -7 = 7 studs above root
		--  0 = root
		--================================================

		local AimPosition =
			Root.Position
			- Vector3.new(
				0,
				AimOffset,
				0
			)

		-- Keep current third-person camera position.
		local CameraPosition =
			Camera.CFrame.Position

		local DesiredCFrame =
			CFrame.lookAt(
				CameraPosition,
				AimPosition
			)

		-- Smooth camera movement.
		local Alpha =
			1 - math.pow(
				1 - CameraSmoothness,
				DeltaTime * 60
			)

		Camera.CFrame =
			Camera.CFrame:Lerp(
				DesiredCFrame,
				Alpha
			)

	end
)

--========================================================
-- PLAYER REMOVAL
--========================================================

Players.PlayerRemoving:Connect(function(Player)

	if Player == LockedTarget then

		Unlock()

	end

end)

--========================================================
-- END XENON
--========================================================
