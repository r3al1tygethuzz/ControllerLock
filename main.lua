--[[
    ============================================================
                         XENON
              CONTROLLER CAMERA LOCK SYSTEM
    ============================================================

    FEATURES
    ------------------------------------------------------------
    • Controller-only camera lock
    • PlayStation / Xbox controller support
    • Configurable lock button
    • Sticky target system
    • No automatic target switching
    • First Person / Third Person
    • Screen-space static third-person aim offset
    • Prediction
    • Smoothing
    • Hard lock when Smoothing = 0
    • Responsive UI
    • Draggable window
    • Close / reopen button
    • Target status
    • Modern Xenon interface

    DEFAULTS
    ------------------------------------------------------------
    Lock Button: Y
    Camera Mode: Third Person
    Aim Offset: 10
    Smoothing: 0.30
    Prediction: 0.08

    IMPORTANT
    ------------------------------------------------------------
    Third-person Aim Offset is now SCREEN-SPACE based.

    Positive number = aim point BELOW target
    Negative number = aim point ABOVE target

    This prevents the old world-space offset from visually
    drifting as the target gets farther away.
]]

--==============================================================
-- SERVICES
--==============================================================

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

--==============================================================
-- XENON CONFIG
--==============================================================

local Config = {
    LockButton = Enum.KeyCode.ButtonY,

    CameraMode = "Third Person",

    -- Screen-space vertical offset.
    -- Positive = below target.
    -- Negative = above target.
    AimOffset = 10,

    -- 0 = instant/hard lock.
    Smoothing = 0.30,

    -- 0 = no prediction.
    Prediction = 0.08,

    MaxTargetDistance = 500,

    -- Set to true if you want the camera to lock while
    -- the controller button is being pressed.
    -- Normally false = toggle behavior.
    HoldMode = false,
}

--==============================================================
-- STATE
--==============================================================

local LockedTarget = nil
local IsLocked = false

local WaitingForButton = false
local UIVisible = true

local Dragging = false
local DragStart = nil
local StartPosition = nil

local CurrentCharacter = nil

local MainGui
local MainFrame
local FloatingButton

local StatusText
local TargetText
local LockButtonText
local ModeButton

local OffsetBox
local SmoothingBox
local PredictionBox

local ButtonCaptureConnection

--==============================================================
-- UTILITY
--==============================================================

local function clampNumber(value, minimum, maximum, default)
    local number = tonumber(value)

    if number == nil then
        return default
    end

    return math.clamp(number, minimum, maximum)
end

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

local function GetButtonName(keyCode)
    local names = {
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

        [Enum.KeyCode.ButtonDPadUp] = "D-PAD UP",
        [Enum.KeyCode.ButtonDPadDown] = "D-PAD DOWN",
        [Enum.KeyCode.ButtonDPadLeft] = "D-PAD LEFT",
        [Enum.KeyCode.ButtonDPadRight] = "D-PAD RIGHT",

        [Enum.KeyCode.ButtonStart] = "START",
        [Enum.KeyCode.ButtonSelect] = "SELECT",
    }

    return names[keyCode] or tostring(keyCode)
end

--==============================================================
-- CHARACTER VALIDATION
--==============================================================

local function GetCharacterParts(player)
    if not player then
        return nil
    end

    local character = player.Character

    if not character then
        return nil
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local root = character:FindFirstChild("HumanoidRootPart")

    if not humanoid or not root then
        return nil
    end

    if humanoid.Health <= 0 then
        return nil
    end

    return character, humanoid, root
end

local function IsValidTarget(player)
    if not player then
        return false
    end

    if player == LocalPlayer then
        return false
    end

    local character, humanoid, root = GetCharacterParts(player)

    if not character or not humanoid or not root then
        return false
    end

    local localCharacter = LocalPlayer.Character

    if not localCharacter then
        return false
    end

    local localRoot = localCharacter:FindFirstChild("HumanoidRootPart")

    if not localRoot then
        return false
    end

    local distance = (root.Position - localRoot.Position).Magnitude

    if distance > Config.MaxTargetDistance then
        return false
    end

    return true
end

--==============================================================
-- FIND CLOSEST TARGET
--==============================================================

local function FindClosestTarget()
    local closestPlayer = nil
    local closestDistance = math.huge

    local viewportSize = Camera.ViewportSize
    local screenCenter = Vector2.new(
        viewportSize.X / 2,
        viewportSize.Y / 2
    )

    for _, player in ipairs(Players:GetPlayers()) do
        if IsValidTarget(player) then
            local character, humanoid, root = GetCharacterParts(player)

            if character and humanoid and root then
                local screenPosition, onScreen =
                    Camera:WorldToViewportPoint(root.Position)

                if onScreen and screenPosition.Z > 0 then
                    local targetScreenPosition = Vector2.new(
                        screenPosition.X,
                        screenPosition.Y
                    )

                    local distanceFromCenter =
                        (targetScreenPosition - screenCenter).Magnitude

                    if distanceFromCenter < closestDistance then
                        closestDistance = distanceFromCenter
                        closestPlayer = player
                    end
                end
            end
        end
    end

    return closestPlayer
end

--==============================================================
-- UI STATUS
--==============================================================

local function UpdateStatus()
    if not StatusText then
        return
    end

    if IsLocked and LockedTarget then
        StatusText.Text = "LOCKED"
        StatusText.TextColor3 = Color3.fromRGB(255, 70, 70)
    else
        StatusText.Text = "READY"
        StatusText.TextColor3 = Color3.fromRGB(210, 210, 210)
    end

    if TargetText then
        if IsLocked and LockedTarget then
            TargetText.Text = "TARGET  /  " .. LockedTarget.DisplayName
        else
            TargetText.Text = "TARGET  /  NONE"
        end
    end
end

local function UpdateLockButtonDisplay()
    if LockButtonText then
        LockButtonText.Text =
            "SET LOCK BUTTON     [" ..
            GetButtonName(Config.LockButton) ..
            "]"
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

    -- IMPORTANT:
    -- Target selection happens ONLY here.
    -- It does NOT happen every render frame.
    local target = FindClosestTarget()

    if not target then
        UpdateStatus()
        return
    end

    LockedTarget = target
    IsLocked = true

    UpdateStatus()
end

--==============================================================
-- TOGGLE
--==============================================================

local function ToggleLock()
    if IsLocked then
        Unlock()
    else
        Lock()
    end
end

--==============================================================
-- CAMERA TARGET POSITION
--==============================================================

local function GetPredictedPosition(position, velocity)
    return position + (velocity * Config.Prediction)
end

--==============================================================
-- THIRD PERSON STATIC SCREEN OFFSET
--==============================================================

local function GetStaticScreenOffsetAim(root)
    if not root then
        return nil
    end

    ----------------------------------------------------------------
    -- STEP 1
    -- Predict the target's root position FIRST.
    ----------------------------------------------------------------

    local predictedPosition = GetPredictedPosition(
        root.Position,
        root.AssemblyLinearVelocity
    )

    ----------------------------------------------------------------
    -- STEP 2
    -- Convert predicted target position to viewport coordinates.
    ----------------------------------------------------------------

    local viewportPoint, onScreen =
        Camera:WorldToViewportPoint(predictedPosition)

    if not onScreen or viewportPoint.Z <= 0 then
        return predictedPosition
    end

    ----------------------------------------------------------------
    -- STEP 3
    -- Apply a CONSTANT screen-space vertical offset.
    --
    -- Positive AimOffset = below target.
    -- Negative AimOffset = above target.
    --
    -- This is the important fix.
    --
    -- The old system used:
    --
    --     Root.Position - Vector3.new(0, 10, 0)
    --
    -- which is a WORLD-SPACE offset.
    --
    -- Because perspective changes with distance, that causes
    -- the point to visually move relative to the target.
    --
    -- We now offset the target in SCREEN SPACE instead.
    ----------------------------------------------------------------

    local shiftedY =
        viewportPoint.Y + Config.AimOffset

    ----------------------------------------------------------------
    -- STEP 4
    -- Convert the shifted viewport position back into a world
    -- point at the SAME CAMERA DEPTH as the predicted target.
    ----------------------------------------------------------------

    local ray =
        Camera:ViewportPointToRay(
            viewportPoint.X,
            shiftedY
        )

    local cameraSpacePosition =
        Camera.CFrame:PointToObjectSpace(predictedPosition)

    local targetDepth =
        -cameraSpacePosition.Z

    if targetDepth <= 0 then
        return predictedPosition
    end

    local forwardAmount =
        ray.Direction:Dot(Camera.CFrame.LookVector)

    if math.abs(forwardAmount) < 0.0001 then
        return predictedPosition
    end

    local distanceAlongRay =
        targetDepth / forwardAmount

    return ray.Origin + (ray.Direction * distanceAlongRay)
end

--==============================================================
-- FIRST PERSON AIM
--==============================================================

local function GetFirstPersonAim()
    local target = LockedTarget

    if not target then
        return nil
    end

    local character, humanoid, root =
        GetCharacterParts(target)

    if not character then
        return nil
    end

    local head = character:FindFirstChild("Head")

    if not head then
        return root.Position
    end

    return GetPredictedPosition(
        head.Position,
        head.AssemblyLinearVelocity
    )
end

--==============================================================
-- THIRD PERSON AIM
--==============================================================

local function GetThirdPersonAim()
    local target = LockedTarget

    if not target then
        return nil
    end

    local character, humanoid, root =
        GetCharacterParts(target)

    if not character then
        return nil
    end

    return GetStaticScreenOffsetAim(root)
end

--==============================================================
-- CAMERA UPDATE
--==============================================================

local function UpdateCamera(deltaTime)
    if not IsLocked then
        return
    end

    ----------------------------------------------------------------
    -- NEVER FIND A NEW TARGET HERE.
    --
    -- This preserves sticky target behavior.
    ----------------------------------------------------------------

    local target = LockedTarget

    if not target then
        Unlock()
        return
    end

    ----------------------------------------------------------------
    -- If the original target becomes invalid, unlock.
    -- DO NOT switch to another player.
    ----------------------------------------------------------------

    if not IsValidTarget(target) then
        Unlock()
        return
    end

    local aimPosition

    if Config.CameraMode == "First Person" then
        aimPosition = GetFirstPersonAim()
    else
        aimPosition = GetThirdPersonAim()
    end

    if not aimPosition then
        Unlock()
        return
    end

    local cameraPosition = Camera.CFrame.Position

    local direction =
        aimPosition - cameraPosition

    if direction.Magnitude <= 0.001 then
        return
    end

    local desiredCFrame =
        CFrame.lookAt(
            cameraPosition,
            aimPosition
        )

    ----------------------------------------------------------------
    -- HARD LOCK
    --
    -- Smoothing = 0 means absolutely no interpolation.
    ----------------------------------------------------------------

    if Config.Smoothing <= 0 then
        Camera.CFrame = desiredCFrame
        return
    end

    ----------------------------------------------------------------
    -- SMOOTH LOCK
    ----------------------------------------------------------------

    local smoothingAlpha =
        1 - math.exp(
            -Config.Smoothing *
            deltaTime *
            60
        )

    smoothingAlpha =
        math.clamp(
            smoothingAlpha,
            0,
            1
        )

    Camera.CFrame =
        Camera.CFrame:Lerp(
            desiredCFrame,
            smoothingAlpha
        )
end

--==============================================================
-- GUI CREATION
--==============================================================

MainGui = Instance.new("ScreenGui")
MainGui.Name = "Xenon"
MainGui.ResetOnSpawn = false
MainGui.IgnoreGuiInset = true
MainGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
MainGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

--==============================================================
-- MAIN FRAME
--==============================================================

MainFrame = Instance.new("Frame")
MainFrame.Name = "Main"
MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
MainFrame.Position = UDim2.fromScale(0.5, 0.5)
MainFrame.Size = UDim2.fromOffset(390, 540)
MainFrame.BackgroundColor3 = Color3.fromRGB(17, 17, 19)
MainFrame.BorderSizePixel = 0
MainFrame.Parent = MainGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 14)
MainCorner.Parent = MainFrame

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(55, 55, 58)
MainStroke.Thickness = 1
MainStroke.Transparency = 0.25
MainStroke.Parent = MainFrame

--==============================================================
-- RESPONSIVE SIZE
--==============================================================

local function UpdateResponsiveSize()
    local viewport = Camera.ViewportSize

    if viewport.X <= 600 then
        MainFrame.Size = UDim2.fromOffset(300, 500)
    elseif viewport.X <= 1000 then
        MainFrame.Size = UDim2.fromOffset(350, 525)
    else
        MainFrame.Size = UDim2.fromOffset(390, 540)
    end
end

UpdateResponsiveSize()

Camera:GetPropertyChangedSignal("ViewportSize"):Connect(
    UpdateResponsiveSize
)

--==============================================================
-- TOP BAR
--==============================================================

local TopBar = Instance.new("Frame")
TopBar.Name = "TopBar"
TopBar.Size = UDim2.new(1, 0, 0, 76)
TopBar.BackgroundTransparency = 1
TopBar.Parent = MainFrame

-- Red top line

local RedLine = Instance.new("Frame")
RedLine.Size = UDim2.new(1, -30, 0, 2)
RedLine.Position = UDim2.fromOffset(15, 0)
RedLine.BackgroundColor3 = Color3.fromRGB(235, 45, 55)
RedLine.BorderSizePixel = 0
RedLine.Parent = TopBar

local RedCorner = Instance.new("UICorner")
RedCorner.CornerRadius = UDim.new(1, 0)
RedCorner.Parent = RedLine

-- X logo

local Logo = Instance.new("TextLabel")
Logo.BackgroundTransparency = 1
Logo.Position = UDim2.fromOffset(18, 16)
Logo.Size = UDim2.fromOffset(35, 35)
Logo.Font = Enum.Font.GothamBlack
Logo.Text = "X"
Logo.TextSize = 30
Logo.TextColor3 = Color3.fromRGB(235, 45, 55)
Logo.Parent = TopBar

-- Title

local Title = Instance.new("TextLabel")
Title.BackgroundTransparency = 1
Title.Position = UDim2.fromOffset(57, 12)
Title.Size = UDim2.new(1, -120, 0, 25)
Title.Font = Enum.Font.GothamBold
Title.Text = "XENON"
Title.TextSize = 21
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.TextColor3 = Color3.fromRGB(245, 245, 245)
Title.Parent = TopBar

local Subtitle = Instance.new("TextLabel")
Subtitle.BackgroundTransparency = 1
Subtitle.Position = UDim2.fromOffset(58, 38)
Subtitle.Size = UDim2.new(1, -125, 0, 18)
Subtitle.Font = Enum.Font.GothamMedium
Subtitle.Text = "CONTROLLER CAMERA SYSTEM"
Subtitle.TextSize = 9
Subtitle.TextXAlignment = Enum.TextXAlignment.Left
Subtitle.TextColor3 = Color3.fromRGB(120, 120, 125)
Subtitle.Parent = TopBar

--==============================================================
-- CLOSE BUTTON
--==============================================================

local CloseButton = Instance.new("TextButton")
CloseButton.Name = "Close"
CloseButton.AnchorPoint = Vector2.new(1, 0)
CloseButton.Position = UDim2.new(1, -15, 0, 15)
CloseButton.Size = UDim2.fromOffset(40, 40)
CloseButton.BackgroundColor3 = Color3.fromRGB(35, 35, 38)
CloseButton.BorderSizePixel = 0
CloseButton.Text = "×"
CloseButton.TextSize = 27
CloseButton.Font = Enum.Font.GothamBold
CloseButton.TextColor3 = Color3.fromRGB(230, 230, 230)
CloseButton.Parent = TopBar

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 9)
CloseCorner.Parent = CloseButton

CloseButton.MouseEnter:Connect(function()
    CloseButton.BackgroundColor3 =
        Color3.fromRGB(180, 35, 45)
end)

CloseButton.MouseLeave:Connect(function()
    CloseButton.BackgroundColor3 =
        Color3.fromRGB(35, 35, 38)
end)

--==============================================================
-- SCROLLING CONTENT
--==============================================================

local Scroll = Instance.new("ScrollingFrame")
Scroll.Name = "Content"
Scroll.Position = UDim2.fromOffset(12, 78)
Scroll.Size = UDim2.new(1, -24, 1, -90)
Scroll.BackgroundTransparency = 1
Scroll.BorderSizePixel = 0
Scroll.ScrollBarThickness = 3
Scroll.ScrollBarImageColor3 =
    Color3.fromRGB(80, 80, 85)
Scroll.CanvasSize = UDim2.new(0, 0, 0, 700)
Scroll.Parent = MainFrame

local ContentLayout = Instance.new("UIListLayout")
ContentLayout.Padding = UDim.new(0, 9)
ContentLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
ContentLayout.SortOrder = Enum.SortOrder.LayoutOrder
ContentLayout.Parent = Scroll

--==============================================================
-- HELPER: SECTION LABEL
--==============================================================

local function CreateSection(text)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -10, 0, 20)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamBold
    label.Text = text
    label.TextSize = 10
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextColor3 = Color3.fromRGB(115, 115, 120)
    label.LayoutOrder = 1
    label.Parent = Scroll

    return label
end

--==============================================================
-- STATUS CARD
--==============================================================

local StatusCard = Instance.new("Frame")
StatusCard.Size = UDim2.new(1, -10, 0, 66)
StatusCard.BackgroundColor3 = Color3.fromRGB(24, 24, 27)
StatusCard.BorderSizePixel = 0
StatusCard.LayoutOrder = 2
StatusCard.Parent = Scroll

local StatusCorner = Instance.new("UICorner")
StatusCorner.CornerRadius = UDim.new(0, 10)
StatusCorner.Parent = StatusCard

local StatusTitle = Instance.new("TextLabel")
StatusTitle.BackgroundTransparency = 1
StatusTitle.Position = UDim2.fromOffset(14, 9)
StatusTitle.Size = UDim2.new(0.5, 0, 0, 16)
StatusTitle.Font = Enum.Font.GothamMedium
StatusTitle.Text = "SYSTEM STATUS"
StatusTitle.TextSize = 9
StatusTitle.TextXAlignment = Enum.TextXAlignment.Left
StatusTitle.TextColor3 = Color3.fromRGB(110, 110, 115)
StatusTitle.Parent = StatusCard

StatusText = Instance.new("TextLabel")
StatusText.BackgroundTransparency = 1
StatusText.Position = UDim2.fromOffset(14, 27)
StatusText.Size = UDim2.new(0.5, 0, 0, 25)
StatusText.Font = Enum.Font.GothamBold
StatusText.Text = "READY"
StatusText.TextSize = 15
StatusText.TextXAlignment = Enum.TextXAlignment.Left
StatusText.TextColor3 = Color3.fromRGB(210, 210, 210)
StatusText.Parent = StatusCard

TargetText = Instance.new("TextLabel")
TargetText.BackgroundTransparency = 1
TargetText.AnchorPoint = Vector2.new(1, 0)
TargetText.Position = UDim2.new(1, -14, 0, 25)
TargetText.Size = UDim2.new(0.45, 0, 0, 20)
TargetText.Font = Enum.Font.GothamMedium
TargetText.Text = "TARGET / NONE"
TargetText.TextSize = 9
TargetText.TextXAlignment = Enum.TextXAlignment.Right
TargetText.TextColor3 = Color3.fromRGB(130, 130, 135)
TargetText.Parent = StatusCard

--==============================================================
-- MODE SECTION
--==============================================================

CreateSection("CAMERA MODE")

ModeButton = Instance.new("TextButton")
ModeButton.Size = UDim2.new(1, -10, 0, 46)
ModeButton.BackgroundColor3 = Color3.fromRGB(24, 24, 27)
ModeButton.BorderSizePixel = 0
ModeButton.Font = Enum.Font.GothamMedium
ModeButton.Text = "THIRD PERSON                         ▼"
ModeButton.TextSize = 11
ModeButton.TextXAlignment = Enum.TextXAlignment.Left
ModeButton.TextColor3 = Color3.fromRGB(230, 230, 230)
ModeButton.LayoutOrder = 3
ModeButton.Parent = Scroll

local ModePadding = Instance.new("UIPadding")
ModePadding.PaddingLeft = UDim.new(0, 14)
ModePadding.Parent = ModeButton

local ModeCorner = Instance.new("UICorner")
ModeCorner.CornerRadius = UDim.new(0, 9)
ModeCorner.Parent = ModeButton

--==============================================================
-- MODE DROPDOWN
--==============================================================

local Dropdown = Instance.new("Frame")
Dropdown.Size = UDim2.new(1, -10, 0, 88)
Dropdown.BackgroundColor3 = Color3.fromRGB(21, 21, 24)
Dropdown.BorderSizePixel = 0
Dropdown.Visible = false
Dropdown.LayoutOrder = 4
Dropdown.Parent = Scroll

local DropdownCorner = Instance.new("UICorner")
DropdownCorner.CornerRadius = UDim.new(0, 9)
DropdownCorner.Parent = Dropdown

local FirstPersonButton = Instance.new("TextButton")
FirstPersonButton.Size = UDim2.new(1, -8, 0, 38)
FirstPersonButton.Position = UDim2.fromOffset(4, 4)
FirstPersonButton.BackgroundColor3 = Color3.fromRGB(30, 30, 33)
FirstPersonButton.BorderSizePixel = 0
FirstPersonButton.Font = Enum.Font.GothamMedium
FirstPersonButton.Text = "FIRST PERSON"
FirstPersonButton.TextSize = 10
FirstPersonButton.TextColor3 = Color3.fromRGB(220, 220, 220)
FirstPersonButton.Parent = Dropdown

local FPcorner = Instance.new("UICorner")
FPcorner.CornerRadius = UDim.new(0, 7)
FPcorner.Parent = FirstPersonButton

local ThirdPersonButton = Instance.new("TextButton")
ThirdPersonButton.Size = UDim2.new(1, -8, 0, 38)
ThirdPersonButton.Position = UDim2.fromOffset(4, 46)
ThirdPersonButton.BackgroundColor3 = Color3.fromRGB(30, 30, 33)
ThirdPersonButton.BorderSizePixel = 0
ThirdPersonButton.Font = Enum.Font.GothamMedium
ThirdPersonButton.Text = "THIRD PERSON"
ThirdPersonButton.TextSize = 10
ThirdPersonButton.TextColor3 = Color3.fromRGB(220, 220, 220)
ThirdPersonButton.Parent = Dropdown

local TPcorner = Instance.new("UICorner")
TPcorner.CornerRadius = UDim.new(0, 7)
TPcorner.Parent = ThirdPersonButton

--==============================================================
-- INPUT FIELD CREATOR
--==============================================================

local function CreateInput(
    labelText,
    defaultText,
    placeholderText,
    layoutOrder
)
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, -10, 0, 68)
    container.BackgroundColor3 = Color3.fromRGB(24, 24, 27)
    container.BorderSizePixel = 0
    container.LayoutOrder = layoutOrder
    container.Parent = Scroll

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 9)
    corner.Parent = container

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Position = UDim2.fromOffset(13, 8)
    label.Size = UDim2.new(1, -26, 0, 18)
    label.Font = Enum.Font.GothamMedium
    label.Text = labelText
    label.TextSize = 9
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextColor3 = Color3.fromRGB(145, 145, 150)
    label.Parent = container

    local box = Instance.new("TextBox")
    box.Position = UDim2.fromOffset(12, 31)
    box.Size = UDim2.new(1, -24, 0, 27)
    box.BackgroundColor3 = Color3.fromRGB(16, 16, 18)
    box.BorderSizePixel = 0
    box.ClearTextOnFocus = false
    box.Font = Enum.Font.GothamMedium
    box.PlaceholderText = placeholderText
    box.PlaceholderColor3 = Color3.fromRGB(90, 90, 95)
    box.Text = defaultText
    box.TextSize = 10
    box.TextColor3 = Color3.fromRGB(235, 235, 235)
    box.Parent = container

    local boxCorner = Instance.new("UICorner")
    boxCorner.CornerRadius = UDim.new(0, 7)
    boxCorner.Parent = box

    return box
end

--==============================================================
-- AIM OFFSET
--==============================================================

CreateSection("AIM SETTINGS")

OffsetBox = CreateInput(
    "THIRD PERSON SCREEN OFFSET",
    tostring(Config.AimOffset),
    "Positive = below / Negative = above",
    5
)

OffsetBox.FocusLost:Connect(function()
    Config.AimOffset = clampNumber(
        OffsetBox.Text,
        -500,
        500,
        10
    )

    OffsetBox.Text = tostring(Config.AimOffset)
end)

--==============================================================
-- RECOMMENDATION
--==============================================================

local Recommendation = Instance.new("TextLabel")
Recommendation.Size = UDim2.new(1, -10, 0, 34)
Recommendation.BackgroundColor3 = Color3.fromRGB(24, 24, 27)
Recommendation.BorderSizePixel = 0
Recommendation.Font = Enum.Font.GothamMedium
Recommendation.Text =
    "HEAD  ≈  FIRST PERSON\n" ..
    "TORSO  ≈  THIRD PERSON"
Recommendation.TextSize = 9
Recommendation.TextXAlignment = Enum.TextXAlignment.Left
Recommendation.TextYAlignment = Enum.TextYAlignment.Center
Recommendation.TextColor3 = Color3.fromRGB(150, 150, 155)
Recommendation.LayoutOrder = 6
Recommendation.Parent = Scroll

local RecCorner = Instance.new("UICorner")
RecCorner.CornerRadius = UDim.new(0, 9)
RecCorner.Parent = Recommendation

local RecPadding = Instance.new("UIPadding")
RecPadding.PaddingLeft = UDim.new(0, 13)
RecPadding.Parent = Recommendation

--==============================================================
-- SMOOTHING
--==============================================================

SmoothingBox = CreateInput(
    "SMOOTHING",
    string.format("%.2f", Config.Smoothing),
    "0 = instant / hard lock",
    7
)

SmoothingBox.FocusLost:Connect(function()
    Config.Smoothing = clampNumber(
        SmoothingBox.Text,
        0,
        10,
        0.30
    )

    SmoothingBox.Text =
        string.format("%.2f", Config.Smoothing)
end)

--==============================================================
-- PREDICTION
--==============================================================

PredictionBox = CreateInput(
    "PREDICTION",
    string.format("%.2f", Config.Prediction),
    "0 = no prediction",
    8
)

PredictionBox.FocusLost:Connect(function()
    Config.Prediction = clampNumber(
        PredictionBox.Text,
        0,
        2,
        0.08
    )

    PredictionBox.Text =
        string.format("%.2f", Config.Prediction)
end)

--==============================================================
-- LOCK BUTTON
--==============================================================

CreateSection("CONTROLLER")

local SetButton = Instance.new("TextButton")
SetButton.Size = UDim2.new(1, -10, 0, 48)
SetButton.BackgroundColor3 = Color3.fromRGB(24, 24, 27)
SetButton.BorderSizePixel = 0
SetButton.Font = Enum.Font.GothamBold
SetButton.TextSize = 10
SetButton.TextXAlignment = Enum.TextXAlignment.Left
SetButton.TextColor3 = Color3.fromRGB(230, 230, 230)
SetButton.LayoutOrder = 9
SetButton.Parent = Scroll

local SetButtonPadding = Instance.new("UIPadding")
SetButtonPadding.PaddingLeft = UDim.new(0, 14)
SetButtonPadding.Parent = SetButton

local SetButtonCorner = Instance.new("UICorner")
SetButtonCorner.CornerRadius = UDim.new(0, 9)
SetButtonCorner.Parent = SetButton

LockButtonText = SetButton

UpdateLockButtonDisplay()

--==============================================================
-- BUTTON CAPTURE
--==============================================================

SetButton.MouseButton1Click:Connect(function()
    if WaitingForButton then
        return
    end

    WaitingForButton = true

    SetButton.Text = "PRESS CONTROLLER BUTTON..."

    if ButtonCaptureConnection then
        ButtonCaptureConnection:Disconnect()
        ButtonCaptureConnection = nil
    end

    ButtonCaptureConnection =
        UserInputService.InputBegan:Connect(function(
            input,
            processed
        )
            if not WaitingForButton then
                return
            end

            if not IsGamepadInput(input) then
                return
            end

            if input.KeyCode == Enum.KeyCode.Unknown then
                return
            end

            WaitingForButton = false

            Config.LockButton = input.KeyCode

            UpdateLockButtonDisplay()

            if ButtonCaptureConnection then
                ButtonCaptureConnection:Disconnect()
                ButtonCaptureConnection = nil
            end
        end)
end)

--==============================================================
-- GUIDE
--==============================================================

local Guide = Instance.new("TextLabel")
Guide.Size = UDim2.new(1, -10, 0, 82)
Guide.BackgroundColor3 = Color3.fromRGB(24, 24, 27)
Guide.BorderSizePixel = 0
Guide.Font = Enum.Font.GothamMedium
Guide.Text =
    "XENON CONTROLLER GUIDE\n\n" ..
    "Press your configured controller button to lock.\n" ..
    "Press it again to unlock.\n" ..
    "Xenon stays on the original target until unlocked."
Guide.TextSize = 9
Guide.TextWrapped = true
Guide.TextXAlignment = Enum.TextXAlignment.Left
Guide.TextYAlignment = Enum.TextYAlignment.Center
Guide.TextColor3 = Color3.fromRGB(145, 145, 150)
Guide.LayoutOrder = 10
Guide.Parent = Scroll

local GuideCorner = Instance.new("UICorner")
GuideCorner.CornerRadius = UDim.new(0, 9)
GuideCorner.Parent = Guide

local GuidePadding = Instance.new("UIPadding")
GuidePadding.PaddingLeft = UDim.new(0, 13)
GuidePadding.PaddingRight = UDim.new(0, 13)
GuidePadding.Parent = Guide

--==============================================================
-- FOOTER
--==============================================================

local Footer = Instance.new("TextLabel")
Footer.Size = UDim2.new(1, -10, 0, 30)
Footer.BackgroundTransparency = 1
Footer.Font = Enum.Font.GothamBold
Footer.Text = "XENON  //  CONTROLLER SYSTEM"
Footer.TextSize = 8
Footer.TextColor3 = Color3.fromRGB(80, 80, 85)
Footer.LayoutOrder = 11
Footer.Parent = Scroll

--==============================================================
-- DROPDOWN LOGIC
--==============================================================

ModeButton.MouseButton1Click:Connect(function()
    Dropdown.Visible = not Dropdown.Visible

    if Dropdown.Visible then
        Scroll.CanvasSize = UDim2.new(0, 0, 0, 790)
    else
        Scroll.CanvasSize = UDim2.new(0, 0, 0, 700)
    end
end)

FirstPersonButton.MouseButton1Click:Connect(function()
    Config.CameraMode = "First Person"

    ModeButton.Text =
        "FIRST PERSON                         ▼"

    Dropdown.Visible = false
    Scroll.CanvasSize = UDim2.new(0, 0, 0, 700)
end)

ThirdPersonButton.MouseButton1Click:Connect(function()
    Config.CameraMode = "Third Person"

    ModeButton.Text =
        "THIRD PERSON                         ▼"

    Dropdown.Visible = false
    Scroll.CanvasSize = UDim2.new(0, 0, 0, 700)
end)

--==============================================================
-- DRAGGING
--==============================================================

TopBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then

        Dragging = true
        DragStart = input.Position
        StartPosition = MainFrame.Position

        input.Changed:Connect(function()
            if input.UserInputState ==
                Enum.UserInputState.End then

                Dragging = false
            end
        end)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if not Dragging then
        return
    end

    if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then

        local delta =
            input.Position - DragStart

        MainFrame.Position =
            UDim2.new(
                StartPosition.X.Scale,
                StartPosition.X.Offset + delta.X,
                StartPosition.Y.Scale,
                StartPosition.Y.Offset + delta.Y
            )
    end
end)

--==============================================================
-- FLOATING REOPEN BUTTON
--==============================================================

FloatingButton = Instance.new("TextButton")
FloatingButton.Name = "FloatingX"
FloatingButton.AnchorPoint = Vector2.new(1, 0)
FloatingButton.Position = UDim2.new(1, -18, 0, 18)
FloatingButton.Size = UDim2.fromOffset(48, 48)
FloatingButton.BackgroundColor3 = Color3.fromRGB(22, 22, 25)
FloatingButton.BorderSizePixel = 0
FloatingButton.Font = Enum.Font.GothamBlack
FloatingButton.Text = "X"
FloatingButton.TextSize = 22
FloatingButton.TextColor3 = Color3.fromRGB(235, 45, 55)
FloatingButton.Visible = false
FloatingButton.Parent = MainGui

local FloatingCorner = Instance.new("UICorner")
FloatingCorner.CornerRadius = UDim.new(0, 12)
FloatingCorner.Parent = FloatingButton

local FloatingStroke = Instance.new("UIStroke")
FloatingStroke.Color = Color3.fromRGB(70, 70, 75)
FloatingStroke.Thickness = 1
FloatingStroke.Parent = FloatingButton

--==============================================================
-- CLOSE / REOPEN
--==============================================================

CloseButton.MouseButton1Click:Connect(function()
    UIVisible = false

    MainFrame.Visible = false
    FloatingButton.Visible = true
end)

FloatingButton.MouseButton1Click:Connect(function()
    UIVisible = true

    MainFrame.Visible = true
    FloatingButton.Visible = false
end)

--==============================================================
-- PLAYER REMOVING
--==============================================================

Players.PlayerRemoving:Connect(function(player)
    if player == LockedTarget then
        Unlock()
    end
end)

--==============================================================
-- LOCAL CHARACTER RESPAWN
--==============================================================

LocalPlayer.CharacterAdded:Connect(function(character)
    CurrentCharacter = character

    -- Don't carry an old target lock through respawn.
    Unlock()
end)

CurrentCharacter = LocalPlayer.Character

--==============================================================
-- CONTROLLER INPUT
--==============================================================

UserInputService.InputBegan:Connect(function(
    input,
    processed
)
    ----------------------------------------------------------------
    -- STRICT CONTROLLER-ONLY LOCK INPUT
    ----------------------------------------------------------------

    if not IsGamepadInput(input) then
        return
    end

    if input.KeyCode ~= Config.LockButton then
        return
    end

    if WaitingForButton then
        return
    end

    if Config.HoldMode then
        if not IsLocked then
            Lock()
        end
    else
        ToggleLock()
    end
end)

--==============================================================
-- CONTROLLER HOLD MODE RELEASE
--==============================================================

UserInputService.InputEnded:Connect(function(input)
    if not IsGamepadInput(input) then
        return
    end

    if input.KeyCode ~= Config.LockButton then
        return
    end

    if Config.HoldMode then
        Unlock()
    end
end)

--==============================================================
-- CAMERA RENDER LOOP
--==============================================================

-- IMPORTANT:
--
-- We run AFTER Roblox's normal camera update.
--
-- This is especially important when Smoothing = 0.
--
-- Camera priority is intentionally very late so the default
-- camera doesn't immediately overwrite Xenon's CFrame.
--

local CameraPriority

pcall(function()
    CameraPriority = Enum.RenderPriority.Last.Value
end)

if not CameraPriority then
    CameraPriority =
        Enum.RenderPriority.Camera.Value + 100
end

RunService:BindToRenderStep(
    "XenonCameraLock",
    CameraPriority,
    function(deltaTime)
        UpdateCamera(deltaTime)
    end
)

--==============================================================
-- CLEANUP IF SCRIPT IS REEXECUTED
--==============================================================

-- Store a marker so another execution can clean up the old
-- render binding.

local ExistingMarker =
    MainGui:FindFirstChild("XenonMarker")

if ExistingMarker then
    ExistingMarker:Destroy()
end

local Marker = Instance.new("BoolValue")
Marker.Name = "XenonMarker"
Marker.Value = true
Marker.Parent = MainGui

--==============================================================
-- INITIAL STATUS
--==============================================================

UpdateStatus()
UpdateLockButtonDisplay()

print("Xenon Controller Camera System loaded.")
print("Lock Button:", GetButtonName(Config.LockButton))
print("Camera Mode:", Config.CameraMode)
print("Aim Offset:", Config.AimOffset)
print("Smoothing:", Config.Smoothing)
print("Prediction:", Config.Prediction)
