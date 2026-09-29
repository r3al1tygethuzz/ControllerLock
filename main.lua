--==============================================================
-- XENON
-- CONTROLLER CAMERA LOCK SYSTEM
-- MOBILE RESPONSIVE EDITION
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

if _G.XenonCleanup then
    pcall(function()
        _G.XenonCleanup()
    end)
end

pcall(function()
    RunService:UnbindFromRenderStep("XenonCameraLock")
end)

local OldGui = PlayerGui:FindFirstChild("Xenon")
if OldGui then
    OldGui:Destroy()
end

--==============================================================
-- CONFIG
--==============================================================

local Config = {
    LockButton = Enum.KeyCode.ButtonY,

    CameraMode = "Third Person",

    -- Third-person vertical offset.
    -- Positive = below target.
    -- Negative = above target.
    AimOffset = 10,

    -- Distance used for adaptive offset.
    ReferenceDistance = 100,

    -- 0 = instant/hard lock.
    Smoothing = 0,

    -- Prediction in seconds.
    Prediction = 0.08,

    MaxTargetDistance = 500,

    -- ON:
    -- Closest to center of camera/viewport.
    --
    -- OFF:
    -- Closest physical distance to local player.
    StickyAim = true,
}

--==============================================================
-- STATE
--==============================================================

local Locked = false
local LockedTarget = nil

local WaitingForButton = false
local MainVisible = true

local Connections = {}

--==============================================================
-- HELPERS
--==============================================================

local function DisconnectAll()
    for _, connection in ipairs(Connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end

    table.clear(Connections)
end

local function Connect(signal, callback)
    local connection = signal:Connect(callback)
    table.insert(Connections, connection)
    return connection
end

--==============================================================
-- GUI
--==============================================================

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "Xenon"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = PlayerGui

--==============================================================
-- COLORS
--==============================================================

local BLACK = Color3.fromRGB(8, 8, 8)
local DARK = Color3.fromRGB(14, 14, 14)
local DARKER = Color3.fromRGB(20, 20, 20)
local LIGHT_DARK = Color3.fromRGB(28, 28, 28)

local WHITE = Color3.fromRGB(245, 245, 245)
local GRAY = Color3.fromRGB(165, 165, 165)
local RED = Color3.fromRGB(220, 40, 40)
local DARK_RED = Color3.fromRGB(120, 25, 25)

--==============================================================
-- MAIN FRAME
--==============================================================

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
MainFrame.Position = UDim2.fromScale(0.5, 0.5)
MainFrame.BackgroundColor3 = BLACK
MainFrame.BorderSizePixel = 0
MainFrame.Visible = true
MainFrame.ZIndex = 10
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 14)
MainCorner.Parent = MainFrame

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(45, 45, 45)
MainStroke.Thickness = 1
MainStroke.Parent = MainFrame

--==============================================================
-- TOP BAR
--==============================================================

local TopBar = Instance.new("Frame")
TopBar.Name = "TopBar"
TopBar.BackgroundColor3 = DARK
TopBar.BorderSizePixel = 0
TopBar.Size = UDim2.new(1, 0, 0, 58)
TopBar.ZIndex = 11
TopBar.Parent = MainFrame

local TopBarCorner = Instance.new("UICorner")
TopBarCorner.CornerRadius = UDim.new(0, 14)
TopBarCorner.Parent = TopBar

local TopBarBottom = Instance.new("Frame")
TopBarBottom.BackgroundColor3 = DARK
TopBarBottom.BorderSizePixel = 0
TopBarBottom.Position = UDim2.new(0, 0, 1, -14)
TopBarBottom.Size = UDim2.new(1, 0, 0, 14)
TopBarBottom.ZIndex = 11
TopBarBottom.Parent = TopBar

--==============================================================
-- TITLE
--==============================================================

local Title = Instance.new("TextLabel")
Title.Name = "Title"
Title.BackgroundTransparency = 1
Title.Position = UDim2.new(0, 18, 0, 7)
Title.Size = UDim2.new(1, -80, 0, 25)
Title.Font = Enum.Font.GothamBold
Title.Text = "XENON"
Title.TextColor3 = WHITE
Title.TextSize = 21
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.ZIndex = 12
Title.Parent = TopBar

local Subtitle = Instance.new("TextLabel")
Subtitle.Name = "Subtitle"
Subtitle.BackgroundTransparency = 1
Subtitle.Position = UDim2.new(0, 19, 0, 32)
Subtitle.Size = UDim2.new(1, -80, 0, 17)
Subtitle.Font = Enum.Font.Gotham
Subtitle.Text = "CONTROLLER CAMERA LOCK"
Subtitle.TextColor3 = GRAY
Subtitle.TextSize = 9
Subtitle.TextXAlignment = Enum.TextXAlignment.Left
Subtitle.ZIndex = 12
Subtitle.Parent = TopBar

--==============================================================
-- CLOSE BUTTON
--==============================================================

local CloseButton = Instance.new("TextButton")
CloseButton.Name = "CloseButton"
CloseButton.AnchorPoint = Vector2.new(1, 0.5)
CloseButton.Position = UDim2.new(1, -12, 0.5, 0)
CloseButton.Size = UDim2.fromOffset(32, 32)
CloseButton.BackgroundColor3 = DARKER
CloseButton.BorderSizePixel = 0
CloseButton.Text = "×"
CloseButton.TextColor3 = WHITE
CloseButton.TextSize = 24
CloseButton.Font = Enum.Font.GothamBold
CloseButton.AutoButtonColor = false
CloseButton.ZIndex = 20
CloseButton.Parent = TopBar

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 8)
CloseCorner.Parent = CloseButton

local CloseStroke = Instance.new("UIStroke")
CloseStroke.Color = DARK_RED
CloseStroke.Thickness = 1
CloseStroke.Parent = CloseButton

--==============================================================
-- CONTENT SCROLL
--==============================================================

local Scroll = Instance.new("ScrollingFrame")
Scroll.Name = "Scroll"
Scroll.BackgroundTransparency = 1
Scroll.BorderSizePixel = 0
Scroll.Position = UDim2.new(0, 10, 0, 66)
Scroll.Size = UDim2.new(1, -20, 1, -76)
Scroll.CanvasSize = UDim2.fromOffset(0, 950)
Scroll.ScrollBarThickness = 3
Scroll.ScrollBarImageColor3 = RED
Scroll.ScrollingDirection = Enum.ScrollingDirection.Y
Scroll.ZIndex = 11
Scroll.Parent = MainFrame

local Padding = Instance.new("UIPadding")
Padding.PaddingLeft = UDim.new(0, 5)
Padding.PaddingRight = UDim.new(0, 5)
Padding.PaddingTop = UDim.new(0, 3)
Padding.PaddingBottom = UDim.new(0, 12)
Padding.Parent = Scroll

local Layout = Instance.new("UIListLayout")
Layout.Padding = UDim.new(0, 9)
Layout.SortOrder = Enum.SortOrder.LayoutOrder
Layout.Parent = Scroll

--==============================================================
-- RESPONSIVE VALUES
--==============================================================

local IsMobile = false

local function UpdateResponsiveState()
    local viewport = workspace.CurrentCamera.ViewportSize

    IsMobile = viewport.X <= 600

    if viewport.X <= 600 then
        MainFrame.Size = UDim2.fromOffset(
            math.max(260, math.min(275, viewport.X - 20)),
            math.max(390, math.min(440, viewport.Y - 30))
        )

        TopBar.Size = UDim2.new(1, 0, 0, 50)

        Scroll.Position = UDim2.new(0, 8, 0, 57)
        Scroll.Size = UDim2.new(1, -16, 1, -65)

        Title.TextSize = 17
        Title.Position = UDim2.new(0, 14, 0, 5)

        Subtitle.TextSize = 7
        Subtitle.Position = UDim2.new(0, 15, 0, 28)

        CloseButton.Size = UDim2.fromOffset(28, 28)
        CloseButton.Position = UDim2.new(1, -9, 0.5, 0)

        Padding.PaddingLeft = UDim.new(0, 3)
        Padding.PaddingRight = UDim.new(0, 3)
        Padding.PaddingTop = UDim.new(0, 2)

    elseif viewport.X <= 1000 then
        MainFrame.Size = UDim2.fromOffset(320, 490)

        TopBar.Size = UDim2.new(1, 0, 0, 54)

        Scroll.Position = UDim2.new(0, 9, 0, 62)
        Scroll.Size = UDim2.new(1, -18, 1, -70)

        Title.TextSize = 19
        Title.Position = UDim2.new(0, 16, 0, 6)

        Subtitle.TextSize = 8
        Subtitle.Position = UDim2.new(0, 17, 0, 30)

        CloseButton.Size = UDim2.fromOffset(30, 30)

        Padding.PaddingLeft = UDim.new(0, 4)
        Padding.PaddingRight = UDim.new(0, 4)

    else
        MainFrame.Size = UDim2.fromOffset(390, 570)

        TopBar.Size = UDim2.new(1, 0, 0, 58)

        Scroll.Position = UDim2.new(0, 10, 0, 66)
        Scroll.Size = UDim2.new(1, -20, 1, -76)

        Title.TextSize = 21
        Title.Position = UDim2.new(0, 18, 0, 7)

        Subtitle.TextSize = 9
        Subtitle.Position = UDim2.new(0, 19, 0, 32)

        CloseButton.Size = UDim2.fromOffset(32, 32)

        Padding.PaddingLeft = UDim.new(0, 5)
        Padding.PaddingRight = UDim.new(0, 5)
    end
end

--==============================================================
-- FLOATING TOGGLE BUTTON
--==============================================================

local FloatingToggle = Instance.new("TextButton")
FloatingToggle.Name = "FloatingToggle"
FloatingToggle.AnchorPoint = Vector2.new(1, 0)
FloatingToggle.Position = UDim2.new(1, -10, 0, 10)
FloatingToggle.Size = UDim2.fromOffset(42, 42)
FloatingToggle.BackgroundColor3 = BLACK
FloatingToggle.BorderSizePixel = 0
FloatingToggle.Text = "X"
FloatingToggle.TextColor3 = WHITE
FloatingToggle.TextSize = 18
FloatingToggle.Font = Enum.Font.GothamBold
FloatingToggle.AutoButtonColor = false
FloatingToggle.ZIndex = 100
FloatingToggle.Parent = ScreenGui

local FloatingCorner = Instance.new("UICorner")
FloatingCorner.CornerRadius = UDim.new(0, 10)
FloatingCorner.Parent = FloatingToggle

local FloatingStroke = Instance.new("UIStroke")
FloatingStroke.Color = RED
FloatingStroke.Thickness = 1.5
FloatingStroke.Parent = FloatingToggle

--==============================================================
-- SECTION CREATOR
--==============================================================

local function CreateSection(text)
    local Section = Instance.new("TextLabel")
    Section.Name = text
    Section.BackgroundTransparency = 1
    Section.Size = UDim2.new(1, 0, 0, 20)
    Section.Font = Enum.Font.GothamBold
    Section.Text = text
    Section.TextColor3 = RED
    Section.TextSize = IsMobile and 10 or 11
    Section.TextXAlignment = Enum.TextXAlignment.Left
    Section.LayoutOrder = 1
    Section.ZIndex = 12
    Section.Parent = Scroll

    return Section
end

--==============================================================
-- GENERIC ROW
--==============================================================

local function CreateRow(height)
    local Row = Instance.new("Frame")
    Row.BackgroundColor3 = DARK
    Row.BorderSizePixel = 0
    Row.Size = UDim2.new(1, 0, 0, height)
    Row.ZIndex = 12
    Row.Parent = Scroll

    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 8)
    Corner.Parent = Row

    local Stroke = Instance.new("UIStroke")
    Stroke.Color = Color3.fromRGB(35, 35, 35)
    Stroke.Thickness = 1
    Stroke.Parent = Row

    return Row
end

--==============================================================
-- LABEL CREATOR
--==============================================================

local function CreateLabel(parent, text)
    local Label = Instance.new("TextLabel")
    Label.BackgroundTransparency = 1
    Label.Position = UDim2.new(0, 12, 0, 0)
    Label.Size = UDim2.new(0.55, -12, 1, 0)
    Label.Font = Enum.Font.GothamMedium
    Label.Text = text
    Label.TextColor3 = WHITE
    Label.TextSize = IsMobile and 11 or 13
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.ZIndex = 13
    Label.Parent = parent

    return Label
end

--==============================================================
-- DROPDOWN
--==============================================================

CreateSection("CAMERA")

local CameraRow = CreateRow(42)
local CameraLabel = CreateLabel(CameraRow, "Camera Mode")

local CameraButton = Instance.new("TextButton")
CameraButton.AnchorPoint = Vector2.new(1, 0.5)
CameraButton.Position = UDim2.new(1, -8, 0.5, 0)
CameraButton.Size = UDim2.new(0.42, 0, 0, 30)
CameraButton.BackgroundColor3 = DARKER
CameraButton.BorderSizePixel = 0
CameraButton.Text = Config.CameraMode
CameraButton.TextColor3 = WHITE
CameraButton.TextSize = IsMobile and 10 or 12
CameraButton.Font = Enum.Font.GothamMedium
CameraButton.AutoButtonColor = false
CameraButton.ZIndex = 13
CameraButton.Parent = CameraRow

local CameraCorner = Instance.new("UICorner")
CameraCorner.CornerRadius = UDim.new(0, 6)
CameraCorner.Parent = CameraButton

local CameraOptions = Instance.new("Frame")
CameraOptions.Visible = false
CameraOptions.AnchorPoint = Vector2.new(1, 0)
CameraOptions.Position = UDim2.new(1, -8, 1, 3)
CameraOptions.Size = UDim2.new(0.42, 0, 0, 62)
CameraOptions.BackgroundColor3 = DARKER
CameraOptions.BorderSizePixel = 0
CameraOptions.ZIndex = 50
CameraOptions.Parent = CameraRow

local CameraOptionsCorner = Instance.new("UICorner")
CameraOptionsCorner.CornerRadius = UDim.new(0, 6)
CameraOptionsCorner.Parent = CameraOptions

local CameraOptionLayout = Instance.new("UIListLayout")
CameraOptionLayout.SortOrder = Enum.SortOrder.LayoutOrder
CameraOptionLayout.Parent = CameraOptions

local function CreateCameraOption(text)
    local Option = Instance.new("TextButton")
    Option.Size = UDim2.new(1, 0, 0, 31)
    Option.BackgroundTransparency = 1
    Option.BorderSizePixel = 0
    Option.Text = text
    Option.TextColor3 = WHITE
    Option.TextSize = IsMobile and 9 or 11
    Option.Font = Enum.Font.Gotham
    Option.AutoButtonColor = false
    Option.ZIndex = 51
    Option.Parent = CameraOptions

    Option.Activated:Connect(function()
        Config.CameraMode = text
        CameraButton.Text = text
        CameraOptions.Visible = false
    end)

    return Option
end

CreateCameraOption("First Person")
CreateCameraOption("Third Person")

CameraButton.Activated:Connect(function()
    CameraOptions.Visible = not CameraOptions.Visible
end)

--==============================================================
-- SETTINGS
--==============================================================

CreateSection("AIM SETTINGS")

--==============================================================
-- TEXT BOX CREATOR
--==============================================================

local function CreateInputRow(labelText, defaultValue)
    local Row = CreateRow(44)
    CreateLabel(Row, labelText)

    local Box = Instance.new("TextBox")
    Box.AnchorPoint = Vector2.new(1, 0.5)
    Box.Position = UDim2.new(1, -8, 0.5, 0)
    Box.Size = UDim2.new(0.37, 0, 0, 30)
    Box.BackgroundColor3 = DARKER
    Box.BorderSizePixel = 0
    Box.ClearTextOnFocus = false
    Box.Text = tostring(defaultValue)
    Box.TextColor3 = WHITE
    Box.PlaceholderColor3 = GRAY
    Box.TextSize = IsMobile and 10 or 12
    Box.Font = Enum.Font.GothamMedium
    Box.TextXAlignment = Enum.TextXAlignment.Center
    Box.ZIndex = 13
    Box.Parent = Row

    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 6)
    Corner.Parent = Box

    return Row, Box
end

--==============================================================
-- OFFSET
--==============================================================

local OffsetRow, OffsetBox = CreateInputRow(
    "3P Offset",
    Config.AimOffset
)

OffsetBox.FocusLost:Connect(function()
    local Number = tonumber(OffsetBox.Text)

    if Number then
        Number = math.clamp(Number, -100, 100)
        Config.AimOffset = Number
        OffsetBox.Text = tostring(Number)
    else
        OffsetBox.Text = tostring(Config.AimOffset)
    end
end)

--==============================================================
-- SMOOTHING
--==============================================================

local SmoothRow, SmoothBox = CreateInputRow(
    "Smoothing",
    Config.Smoothing
)

SmoothBox.FocusLost:Connect(function()
    local Number = tonumber(SmoothBox.Text)

    if Number then
        Number = math.max(0, Number)
        Config.Smoothing = Number
        SmoothBox.Text = tostring(Number)
    else
        SmoothBox.Text = tostring(Config.Smoothing)
    end
end)

--==============================================================
-- PREDICTION
--==============================================================

local PredictionRow, PredictionBox = CreateInputRow(
    "Prediction",
    Config.Prediction
)

PredictionBox.FocusLost:Connect(function()
    local Number = tonumber(PredictionBox.Text)

    if Number then
        Number = math.max(0, Number)
        Config.Prediction = Number
        PredictionBox.Text = tostring(Number)
    else
        PredictionBox.Text = tostring(Config.Prediction)
    end
end)

--==============================================================
-- STICKY AIM
--==============================================================

local StickyRow = CreateRow(44)
CreateLabel(StickyRow, "Sticky Aim")

local StickyButton = Instance.new("TextButton")
StickyButton.AnchorPoint = Vector2.new(1, 0.5)
StickyButton.Position = UDim2.new(1, -8, 0.5, 0)
StickyButton.Size = UDim2.fromOffset(58, 28)
StickyButton.BackgroundColor3 = RED
StickyButton.BorderSizePixel = 0
StickyButton.Text = "ON"
StickyButton.TextColor3 = WHITE
StickyButton.TextSize = IsMobile and 10 or 11
StickyButton.Font = Enum.Font.GothamBold
StickyButton.AutoButtonColor = false
StickyButton.ZIndex = 13
StickyButton.Parent = StickyRow

local StickyCorner = Instance.new("UICorner")
StickyCorner.CornerRadius = UDim.new(0, 7)
StickyCorner.Parent = StickyButton

local function UpdateStickyUI()
    if Config.StickyAim then
        StickyButton.Text = "ON"
        StickyButton.BackgroundColor3 = RED
    else
        StickyButton.Text = "OFF"
        StickyButton.BackgroundColor3 = DARKER
    end
end

StickyButton.Activated:Connect(function()
    Config.StickyAim = not Config.StickyAim
    UpdateStickyUI()
end)

UpdateStickyUI()

--==============================================================
-- LOCK SETTINGS
--==============================================================

CreateSection("CONTROLLER")

local LockRow = CreateRow(44)
CreateLabel(LockRow, "Lock Button")

local LockButtonDisplay = Instance.new("TextLabel")
LockButtonDisplay.AnchorPoint = Vector2.new(1, 0.5)
LockButtonDisplay.Position = UDim2.new(1, -8, 0.5, 0)
LockButtonDisplay.Size = UDim2.new(0.37, 0, 0, 30)
LockButtonDisplay.BackgroundColor3 = DARKER
LockButtonDisplay.BorderSizePixel = 0
LockButtonDisplay.Text = Config.LockButton.Name
LockButtonDisplay.TextColor3 = WHITE
LockButtonDisplay.TextSize = IsMobile and 8 or 10
LockButtonDisplay.Font = Enum.Font.GothamBold
LockButtonDisplay.ZIndex = 13
LockButtonDisplay.Parent = LockRow

local LockDisplayCorner = Instance.new("UICorner")
LockDisplayCorner.CornerRadius = UDim.new(0, 6)
LockDisplayCorner.Parent = LockButtonDisplay

--==============================================================
-- SET LOCK BUTTON
--==============================================================

local RebindRow = CreateRow(44)

local RebindButton = Instance.new("TextButton")
RebindButton.Position = UDim2.new(0, 8, 0, 7)
RebindButton.Size = UDim2.new(1, -16, 1, -14)
RebindButton.BackgroundColor3 = RED
RebindButton.BorderSizePixel = 0
RebindButton.Text = "SET LOCK BUTTON"
RebindButton.TextColor3 = WHITE
RebindButton.TextSize = IsMobile and 10 or 12
RebindButton.Font = Enum.Font.GothamBold
RebindButton.AutoButtonColor = false
RebindButton.ZIndex = 13
RebindButton.Parent = RebindRow

local RebindCorner = Instance.new("UICorner")
RebindCorner.CornerRadius = UDim.new(0, 7)
RebindCorner.Parent = RebindButton

--==============================================================
-- STATUS
--==============================================================

CreateSection("STATUS")

local StatusRow = CreateRow(55)

local StatusLabel = Instance.new("TextLabel")
StatusLabel.BackgroundTransparency = 1
StatusLabel.Position = UDim2.new(0, 12, 0, 5)
StatusLabel.Size = UDim2.new(1, -24, 0, 20)
StatusLabel.Font = Enum.Font.GothamBold
StatusLabel.Text = "UNLOCKED"
StatusLabel.TextColor3 = GRAY
StatusLabel.TextSize = IsMobile and 12 or 14
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.ZIndex = 13
StatusLabel.Parent = StatusRow

local TargetLabel = Instance.new("TextLabel")
TargetLabel.BackgroundTransparency = 1
TargetLabel.Position = UDim2.new(0, 12, 0, 27)
TargetLabel.Size = UDim2.new(1, -24, 0, 18)
TargetLabel.Font = Enum.Font.Gotham
TargetLabel.Text = "Target: None"
TargetLabel.TextColor3 = GRAY
TargetLabel.TextSize = IsMobile and 9 or 10
TargetLabel.TextXAlignment = Enum.TextXAlignment.Left
TargetLabel.ZIndex = 13
TargetLabel.Parent = StatusRow

--==============================================================
-- INSTRUCTIONS
--==============================================================

CreateSection("INFO")

local InfoRow = CreateRow(100)

local Info = Instance.new("TextLabel")
Info.BackgroundTransparency = 1
Info.Position = UDim2.new(0, 12, 0, 8)
Info.Size = UDim2.new(1, -24, 1, -16)
Info.Font = Enum.Font.Gotham
Info.TextColor3 = GRAY
Info.TextSize = IsMobile and 9 or 11
Info.TextWrapped = true
Info.TextXAlignment = Enum.TextXAlignment.Left
Info.TextYAlignment = Enum.TextYAlignment.Top
Info.Text = 
    "Press your selected controller button to lock/unlock.\n\n" ..
    "Sticky ON: targets closest to the center of your camera.\n\n" ..
    "Sticky OFF: targets the physically closest player.\n\n" ..
    "Once locked, the target stays locked until unlocked or invalid."
Info.ZIndex = 13
Info.Parent = InfoRow

--==============================================================
-- UPDATE CANVAS
--==============================================================

local function UpdateCanvas()
    task.defer(function()
        Scroll.CanvasSize = UDim2.fromOffset(
            0,
            Layout.AbsoluteContentSize.Y + 20
        )
    end)
end

Layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(UpdateCanvas)

--==============================================================
-- DRAGGING
--==============================================================

local Dragging = false
local DragStart
local StartPosition

TopBar.InputBegan:Connect(function(Input)
    if Input.UserInputType == Enum.UserInputType.MouseButton1
        or Input.UserInputType == Enum.UserInputType.Touch then

        Dragging = true
        DragStart = Input.Position
        StartPosition = MainFrame.Position

        local ChangedConnection

        ChangedConnection = Input.Changed:Connect(function()
            if Input.UserInputState == Enum.UserInputState.End then
                Dragging = false

                if ChangedConnection then
                    ChangedConnection:Disconnect()
                end
            end
        end)
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

    MainFrame.Position = UDim2.new(
        StartPosition.X.Scale,
        StartPosition.X.Offset + Delta.X,
        StartPosition.Y.Scale,
        StartPosition.Y.Offset + Delta.Y
    )
end)

--==============================================================
-- SUPPORTED CONTROLLER BUTTONS
--==============================================================

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

--==============================================================
-- TARGET VALIDATION
--==============================================================

local function GetCharacterData(Player)
    if not Player then
        return nil
    end

    if Player == LocalPlayer then
        return nil
    end

    local Character = Player.Character

    if not Character then
        return nil
    end

    local Humanoid = Character:FindFirstChildOfClass("Humanoid")
    local Root = Character:FindFirstChild("HumanoidRootPart")

    if not Humanoid or not Root then
        return nil
    end

    if Humanoid.Health <= 0 then
        return nil
    end

    return Character, Humanoid, Root
end

--==============================================================
-- TARGET DISTANCE
--==============================================================

local function GetLocalRoot()
    local Character = LocalPlayer.Character

    if not Character then
        return nil
    end

    return Character:FindFirstChild("HumanoidRootPart")
end

--==============================================================
-- CLOSEST TO CAMERA CENTER
--==============================================================

local function GetClosestToCursor()
    local Camera = workspace.CurrentCamera

    if not Camera then
        return nil
    end

    local Viewport = Camera.ViewportSize
    local Center = Vector2.new(
        Viewport.X / 2,
        Viewport.Y / 2
    )

    local BestPlayer = nil
    local BestDistance = math.huge

    for _, Player in ipairs(Players:GetPlayers()) do
        local Character, Humanoid, Root = GetCharacterData(Player)

        if Character and Humanoid and Root then
            local WorldDistance = (Root.Position - Camera.CFrame.Position).Magnitude

            if WorldDistance <= Config.MaxTargetDistance then
                local ScreenPosition, OnScreen =
                    Camera:WorldToViewportPoint(Root.Position)

                if OnScreen and ScreenPosition.Z > 0 then
                    local ScreenDistance =
                        (Vector2.new(ScreenPosition.X, ScreenPosition.Y) - Center).Magnitude

                    if ScreenDistance < BestDistance then
                        BestDistance = ScreenDistance
                        BestPlayer = Player
                    end
                end
            end
        end
    end

    return BestPlayer
end

--==============================================================
-- CLOSEST PHYSICAL PLAYER
--==============================================================

local function GetClosestByDistance()
    local LocalRoot = GetLocalRoot()

    if not LocalRoot then
        return nil
    end

    local BestPlayer = nil
    local BestDistance = Config.MaxTargetDistance

    for _, Player in ipairs(Players:GetPlayers()) do
        local Character, Humanoid, Root = GetCharacterData(Player)

        if Character and Humanoid and Root then
            local Distance =
                (Root.Position - LocalRoot.Position).Magnitude

            if Distance <= BestDistance then
                BestDistance = Distance
                BestPlayer = Player
            end
        end
    end

    return BestPlayer
end

--==============================================================
-- TARGET SELECTION
--==============================================================

local function FindTarget()
    if Config.StickyAim then
        return GetClosestToCursor()
    else
        return GetClosestByDistance()
    end
end

--==============================================================
-- PREDICTION
--==============================================================

local function GetPredictedPosition(Position, Velocity)
    return Position + (Velocity * Config.Prediction)
end

--==============================================================
-- ADAPTIVE THIRD PERSON OFFSET
--==============================================================

local function GetAdaptiveOffset(TargetRoot)
    local Camera = workspace.CurrentCamera

    if not Camera or not TargetRoot then
        return Config.AimOffset
    end

    local Distance =
        (TargetRoot.Position - Camera.CFrame.Position).Magnitude

    local Adaptive =
        Config.AimOffset *
        (Distance / Config.ReferenceDistance)

    return math.clamp(Adaptive, -100, 100)
end

--==============================================================
-- GET AIM POSITION
--==============================================================

local function GetAimPosition(Player)
    local Character, Humanoid, Root = GetCharacterData(Player)

    if not Character or not Humanoid or not Root then
        return nil
    end

    if Config.CameraMode == "First Person" then
        local Head = Character:FindFirstChild("Head")

        if Head then
            return GetPredictedPosition(
                Head.Position,
                Head.AssemblyLinearVelocity
            )
        end

        return GetPredictedPosition(
            Root.Position,
            Root.AssemblyLinearVelocity
        )
    end

    -- THIRD PERSON

    local Predicted =
        GetPredictedPosition(
            Root.Position,
            Root.AssemblyLinearVelocity
        )

    local Offset = GetAdaptiveOffset(Root)

    return Predicted - Vector3.new(0, Offset, 0)
end

--==============================================================
-- STATUS
--==============================================================

local function UpdateStatus()
    if Locked and LockedTarget then
        StatusLabel.Text = "LOCKED"
        StatusLabel.TextColor3 = RED

        TargetLabel.Text =
            "Target: " .. LockedTarget.Name
    else
        StatusLabel.Text = "UNLOCKED"
        StatusLabel.TextColor3 = GRAY

        TargetLabel.Text = "Target: None"
    end
end

--==============================================================
-- UNLOCK
--==============================================================

local function Unlock()
    Locked = false
    LockedTarget = nil

    UpdateStatus()
end

--==============================================================
-- LOCK
--==============================================================

local function Lock()
    if Locked then
        Unlock()
        return
    end

    local Target = FindTarget()

    if not Target then
        UpdateStatus()
        return
    end

    LockedTarget = Target
    Locked = true

    UpdateStatus()
end

--==============================================================
-- TARGET VALIDATION
--==============================================================

local function IsTargetValid(Player)
    if not Player then
        return false
    end

    if Player.Parent ~= Players then
        return false
    end

    local Character, Humanoid, Root =
        GetCharacterData(Player)

    return Character ~= nil
        and Humanoid ~= nil
        and Root ~= nil
end

--==============================================================
-- CONTROLLER INPUT
--==============================================================

UserInputService.InputBegan:Connect(function(Input, GameProcessed)
    if GameProcessed then
        return
    end

    if Input.UserInputType ~= Enum.UserInputType.Gamepad1 then
        return
    end

    -- REBIND MODE
    if WaitingForButton then
        if SupportedButtons[Input.KeyCode] then
            Config.LockButton = Input.KeyCode
            LockButtonDisplay.Text = Input.KeyCode.Name

            WaitingForButton = false
            RebindButton.Text = "SET LOCK BUTTON"
            RebindButton.BackgroundColor3 = RED
        end

        return
    end

    -- NORMAL LOCK INPUT
    if Input.KeyCode == Config.LockButton then
        Lock()
    end
end)

--==============================================================
-- SET LOCK BUTTON
--==============================================================

RebindButton.Activated:Connect(function()
    WaitingForButton = not WaitingForButton

    if WaitingForButton then
        RebindButton.Text = "PRESS CONTROLLER BUTTON..."
        RebindButton.BackgroundColor3 = DARK_RED
    else
        RebindButton.Text = "SET LOCK BUTTON"
        RebindButton.BackgroundColor3 = RED
    end
end)

--==============================================================
-- UI CLOSE
--==============================================================

CloseButton.Activated:Connect(function()
    MainFrame.Visible = false
    MainVisible = false
    FloatingToggle.Text = "+"
end)

--==============================================================
-- FLOATING TOGGLE
--==============================================================

FloatingToggle.Activated:Connect(function()
    MainVisible = not MainVisible
    MainFrame.Visible = MainVisible

    if MainVisible then
        FloatingToggle.Text = "X"
    else
        FloatingToggle.Text = "+"
    end
end)

FloatingToggle.MouseEnter:Connect(function()
    FloatingToggle.BackgroundColor3 = LIGHT_DARK
end)

FloatingToggle.MouseLeave:Connect(function()
    FloatingToggle.BackgroundColor3 = BLACK
end)

--==============================================================
-- PLAYER REMOVING
--==============================================================

Players.PlayerRemoving:Connect(function(Player)
    if Player == LockedTarget then
        Unlock()
    end
end)

--==============================================================
-- LOCAL CHARACTER RESPAWN
--==============================================================

LocalPlayer.CharacterAdded:Connect(function()
    Unlock()
end)

--==============================================================
-- CAMERA LOCK
--==============================================================

RunService:BindToRenderStep(
    "XenonCameraLock",
    Enum.RenderPriority.Last.Value,
    function()
        if not Locked then
            return
        end

        if not IsTargetValid(LockedTarget) then
            Unlock()
            return
        end

        local Camera = workspace.CurrentCamera

        if not Camera then
            return
        end

        local AimPosition =
            GetAimPosition(LockedTarget)

        if not AimPosition then
            Unlock()
            return
        end

        local CameraPosition =
            Camera.CFrame.Position

        local DesiredCFrame =
            CFrame.lookAt(
                CameraPosition,
                AimPosition
            )

        -- Hard lock.
        if Config.Smoothing <= 0 then
            Camera.CFrame = DesiredCFrame
            return
        end

        -- Smooth lock.
        local Alpha =
            math.clamp(
                1 / (Config.Smoothing + 1),
                0,
                1
            )

        Camera.CFrame =
            Camera.CFrame:Lerp(
                DesiredCFrame,
                Alpha
            )
    end
)

--==============================================================
-- RESPONSIVE UPDATE
--==============================================================

UpdateResponsiveState()

workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(
    function()
        UpdateResponsiveState()
    end
)

--==============================================================
-- CLEANUP FUNCTION
--==============================================================

_G.XenonCleanup = function()
    pcall(function()
        RunService:UnbindFromRenderStep("XenonCameraLock")
    end)

    DisconnectAll()

    local Gui = PlayerGui:FindFirstChild("Xenon")

    if Gui then
        Gui:Destroy()
    end

    _G.XenonCleanup = nil
end

--==============================================================
-- INITIAL UPDATE
--==============================================================

UpdateStatus()
UpdateCanvas()

print("Xenon Controller Camera Lock loaded.")
print("Lock Button:", Config.LockButton.Name)
print("Camera Mode:", Config.CameraMode)
print("Sticky Aim:", Config.StickyAim)
