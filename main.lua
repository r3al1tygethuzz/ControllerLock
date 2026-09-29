--==============================================================
-- XENON
-- CONTROLLER AIMLOCK + ESP + WHITELIST
--==============================================================

--==============================================================
-- SERVICES
--==============================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

--==============================================================
-- DUPLICATE CLEANUP
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

    -- Starts at 23.5 as requested
    AimOffset = 23.5,

    ReferenceDistance = 100,

    -- 0 = instant lock
    Smoothing = 0,

    Prediction = 0.08,

    MaxTargetDistance = 500,

    StickyAim = true,

    --==========================================================
    -- VISUALS
    --==========================================================

    ESPEnabled = false,
    ESPShowName = true,
    ESPShowOutline = true,
    ESPWhitelistCheck = true,

    --==========================================================
    -- AIMLOCK
    --==========================================================

    AimbotWhitelistSkip = true,
}

--==============================================================
-- STATE
--==============================================================

local Locked = false
local LockedTarget = nil

local WaitingForButton = false
local MainVisible = true

local Connections = {}

local ESP = {}
local Whitelist = {}

--==============================================================
-- WHITELIST STORAGE
--==============================================================

local WhitelistFile = "XenonWhitelist.json"

local function LoadWhitelist()
    table.clear(Whitelist)

    if type(isfile) ~= "function" then
        return
    end

    if type(readfile) ~= "function" then
        return
    end

    local Success, Data = pcall(function()
        if not isfile(WhitelistFile) then
            return nil
        end

        return readfile(WhitelistFile)
    end)

    if not Success or not Data or Data == "" then
        return
    end

    local DecodeSuccess, Decoded = pcall(function()
        return HttpService:JSONDecode(Data)
    end)

    if not DecodeSuccess or type(Decoded) ~= "table" then
        return
    end

    for _, UserId in ipairs(Decoded) do
        local ID = tonumber(UserId)

        if ID then
            Whitelist[ID] = true
        end
    end
end

local function SaveWhitelist()
    if type(writefile) ~= "function" then
        return
    end

    local Data = {}

    for UserId, Value in pairs(Whitelist) do
        if Value then
            table.insert(Data, tonumber(UserId))
        end
    end

    pcall(function()
        writefile(
            WhitelistFile,
            HttpService:JSONEncode(Data)
        )
    end)
end

LoadWhitelist()

local function IsWhitelisted(Player)
    if not Player then
        return false
    end

    return Whitelist[Player.UserId] == true
end

local function SetWhitelist(Player, Value)
    if not Player then
        return
    end

    if Value then
        Whitelist[Player.UserId] = true
    else
        Whitelist[Player.UserId] = nil
    end

    SaveWhitelist()
end

--==============================================================
-- CONNECTION SYSTEM
--==============================================================

local function Connect(Signal, Callback)
    local Connection = Signal:Connect(Callback)

    table.insert(
        Connections,
        Connection
    )

    return Connection
end

local function DisconnectAll()
    for _, Connection in ipairs(Connections) do
        pcall(function()
            Connection:Disconnect()
        end)
    end

    table.clear(Connections)
end

--==============================================================
-- COLORS
--==============================================================

local BLACK = Color3.fromRGB(8, 8, 8)
local DARK = Color3.fromRGB(14, 14, 14)
local DARKER = Color3.fromRGB(20, 20, 20)
local LIGHT_DARK = Color3.fromRGB(30, 30, 30)

local WHITE = Color3.fromRGB(255, 255, 255)
local GRAY = Color3.fromRGB(150, 150, 150)

local RED = Color3.fromRGB(220, 40, 40)
local DARK_RED = Color3.fromRGB(110, 25, 25)

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

local TopCorner = Instance.new("UICorner")
TopCorner.CornerRadius = UDim.new(0, 14)
TopCorner.Parent = TopBar

local TopBottom = Instance.new("Frame")
TopBottom.BackgroundColor3 = DARK
TopBottom.BorderSizePixel = 0
TopBottom.Position = UDim2.new(0, 0, 1, -14)
TopBottom.Size = UDim2.new(1, 0, 0, 14)
TopBottom.ZIndex = 11
TopBottom.Parent = TopBar

--==============================================================
-- TITLE
--==============================================================

local Title = Instance.new("TextLabel")
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

--==============================================================
-- FLOATING MOBILE BUTTON
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

local FloatCorner = Instance.new("UICorner")
FloatCorner.CornerRadius = UDim.new(0, 10)
FloatCorner.Parent = FloatingToggle

local FloatStroke = Instance.new("UIStroke")
FloatStroke.Color = RED
FloatStroke.Thickness = 1.5
FloatStroke.Parent = FloatingToggle

--==============================================================
-- SCROLL
--==============================================================

local Scroll = Instance.new("ScrollingFrame")
Scroll.Name = "Scroll"
Scroll.BackgroundTransparency = 1
Scroll.BorderSizePixel = 0
Scroll.Position = UDim2.new(0, 10, 0, 66)
Scroll.Size = UDim2.new(1, -20, 1, -76)
Scroll.CanvasSize = UDim2.fromOffset(0, 1500)
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
Layout.Padding = UDim.new(0, 8)
Layout.SortOrder = Enum.SortOrder.LayoutOrder
Layout.Parent = Scroll

--==============================================================
-- RESPONSIVE UI
--==============================================================

local IsMobile = false

local function UpdateResponsive()
    local Viewport = workspace.CurrentCamera.ViewportSize

    IsMobile = Viewport.X <= 600

    if Viewport.X <= 600 then
        MainFrame.Size = UDim2.fromOffset(
            math.max(
                260,
                math.min(
                    275,
                    Viewport.X - 20
                )
            ),
            math.max(
                390,
                math.min(
                    440,
                    Viewport.Y - 30
                )
            )
        )

        TopBar.Size =
            UDim2.new(1, 0, 0, 50)

        Scroll.Position =
            UDim2.new(0, 8, 0, 57)

        Scroll.Size =
            UDim2.new(1, -16, 1, -65)

        Title.TextSize = 17
        Title.Position =
            UDim2.new(0, 14, 0, 5)

        Subtitle.TextSize = 7
        Subtitle.Position =
            UDim2.new(0, 15, 0, 28)

        CloseButton.Size =
            UDim2.fromOffset(28, 28)

        CloseButton.Position =
            UDim2.new(1, -9, 0.5, 0)

        Padding.PaddingLeft =
            UDim.new(0, 3)

        Padding.PaddingRight =
            UDim.new(0, 3)

    elseif Viewport.X <= 1000 then
        MainFrame.Size =
            UDim2.fromOffset(320, 490)

        TopBar.Size =
            UDim2.new(1, 0, 0, 54)

        Scroll.Position =
            UDim2.new(0, 9, 0, 62)

        Scroll.Size =
            UDim2.new(1, -18, 1, -70)

        Title.TextSize = 19
        Subtitle.TextSize = 8

        CloseButton.Size =
            UDim2.fromOffset(30, 30)

    else
        MainFrame.Size =
            UDim2.fromOffset(390, 570)

        TopBar.Size =
            UDim2.new(1, 0, 0, 58)

        Scroll.Position =
            UDim2.new(0, 10, 0, 66)

        Scroll.Size =
            UDim2.new(1, -20, 1, -76)

        Title.TextSize = 21
        Subtitle.TextSize = 9

        CloseButton.Size =
            UDim2.fromOffset(32, 32)
    end
end

--==============================================================
-- SECTION CREATOR
--==============================================================

local function CreateSection(Text)
    local Section = Instance.new("TextLabel")

    Section.BackgroundTransparency = 1
    Section.Size =
        UDim2.new(1, 0, 0, 20)

    Section.Font =
        Enum.Font.GothamBold

    Section.Text = Text
    Section.TextColor3 = RED
    Section.TextSize = IsMobile and 10 or 11

    Section.TextXAlignment =
        Enum.TextXAlignment.Left

    Section.ZIndex = 12
    Section.Parent = Scroll

    return Section
end

--==============================================================
-- ROW CREATOR
--==============================================================

local function CreateRow(Height)
    local Row = Instance.new("Frame")

    Row.BackgroundColor3 = DARK
    Row.BorderSizePixel = 0

    Row.Size =
        UDim2.new(1, 0, 0, Height)

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
-- LABEL
--==============================================================

local function CreateLabel(Parent, Text)
    local Label = Instance.new("TextLabel")

    Label.BackgroundTransparency = 1
    Label.Position =
        UDim2.new(0, 12, 0, 0)

    Label.Size =
        UDim2.new(0.55, -12, 1, 0)

    Label.Font =
        Enum.Font.GothamMedium

    Label.Text = Text
    Label.TextColor3 = WHITE
    Label.TextSize = IsMobile and 11 or 13

    Label.TextXAlignment =
        Enum.TextXAlignment.Left

    Label.ZIndex = 13
    Label.Parent = Parent

    return Label
end

--==============================================================
-- CAMERA
--==============================================================

CreateSection("CAMERA")

local CameraRow = CreateRow(42)

CreateLabel(
    CameraRow,
    "Camera Mode"
)

local CameraButton = Instance.new("TextButton")

CameraButton.AnchorPoint =
    Vector2.new(1, 0.5)

CameraButton.Position =
    UDim2.new(1, -8, 0.5, 0)

CameraButton.Size =
    UDim2.new(0.42, 0, 0, 30)

CameraButton.BackgroundColor3 = DARKER
CameraButton.BorderSizePixel = 0
CameraButton.Text = Config.CameraMode
CameraButton.TextColor3 = WHITE
CameraButton.TextSize = 11
CameraButton.Font = Enum.Font.GothamMedium
CameraButton.AutoButtonColor = false
CameraButton.ZIndex = 13
CameraButton.Parent = CameraRow

local CameraCorner = Instance.new("UICorner")
CameraCorner.CornerRadius = UDim.new(0, 6)
CameraCorner.Parent = CameraButton

local CameraOptions = Instance.new("Frame")

CameraOptions.Visible = false
CameraOptions.AnchorPoint =
    Vector2.new(1, 0)

CameraOptions.Position =
    UDim2.new(1, -8, 1, 3)

CameraOptions.Size =
    UDim2.new(0.42, 0, 0, 62)

CameraOptions.BackgroundColor3 = DARKER
CameraOptions.BorderSizePixel = 0
CameraOptions.ZIndex = 50
CameraOptions.Parent = CameraRow

local CameraOptionLayout =
    Instance.new("UIListLayout")

CameraOptionLayout.Parent =
    CameraOptions

local function CameraOption(Text)
    local Option =
        Instance.new("TextButton")

    Option.Size =
        UDim2.new(1, 0, 0, 31)

    Option.BackgroundTransparency = 1
    Option.Text = Text
    Option.TextColor3 = WHITE
    Option.TextSize = 10
    Option.Font = Enum.Font.Gotham
    Option.AutoButtonColor = false
    Option.ZIndex = 51
    Option.Parent = CameraOptions

    Option.Activated:Connect(function()
        Config.CameraMode = Text
        CameraButton.Text = Text
        CameraOptions.Visible = false
    end)
end

CameraOption("First Person")
CameraOption("Third Person")

CameraButton.Activated:Connect(function()
    CameraOptions.Visible =
        not CameraOptions.Visible
end)

--==============================================================
-- INPUT CREATOR
--==============================================================

local function CreateInputRow(Text, Value)
    local Row = CreateRow(44)

    CreateLabel(Row, Text)

    local Box = Instance.new("TextBox")

    Box.AnchorPoint =
        Vector2.new(1, 0.5)

    Box.Position =
        UDim2.new(1, -8, 0.5, 0)

    Box.Size =
        UDim2.new(0.37, 0, 0, 30)

    Box.BackgroundColor3 = DARKER
    Box.BorderSizePixel = 0
    Box.ClearTextOnFocus = false
    Box.Text = tostring(Value)
    Box.TextColor3 = WHITE
    Box.TextSize = 11
    Box.Font = Enum.Font.GothamMedium
    Box.TextXAlignment =
        Enum.TextXAlignment.Center

    Box.ZIndex = 13
    Box.Parent = Row

    local Corner = Instance.new("UICorner")
    Corner.CornerRadius =
        UDim.new(0, 6)

    Corner.Parent = Box

    return Box
end

--==============================================================
-- AIM SETTINGS
--==============================================================

CreateSection("AIM SETTINGS")

local OffsetBox =
    CreateInputRow(
        "3P Offset",
        Config.AimOffset
    )

OffsetBox.FocusLost:Connect(function()
    local Value =
        tonumber(OffsetBox.Text)

    if Value then
        Value =
            math.clamp(
                Value,
                -100,
                100
            )

        Config.AimOffset = Value
        OffsetBox.Text =
            tostring(Value)
    else
        OffsetBox.Text =
            tostring(Config.AimOffset)
    end
end)

local SmoothBox =
    CreateInputRow(
        "Smoothing",
        Config.Smoothing
    )

SmoothBox.FocusLost:Connect(function()
    local Value =
        tonumber(SmoothBox.Text)

    if Value then
        Value = math.max(0, Value)

        Config.Smoothing =
            Value

        SmoothBox.Text =
            tostring(Value)
    else
        SmoothBox.Text =
            tostring(Config.Smoothing)
    end
end)

local PredictionBox =
    CreateInputRow(
        "Prediction",
        Config.Prediction
    )

PredictionBox.FocusLost:Connect(function()
    local Value =
        tonumber(PredictionBox.Text)

    if Value then
        Value = math.max(0, Value)

        Config.Prediction =
            Value

        PredictionBox.Text =
            tostring(Value)
    else
        PredictionBox.Text =
            tostring(Config.Prediction)
    end
end)

--==============================================================
-- TOGGLE CREATOR
--==============================================================

local function CreateToggleRow(
    Text,
    GetValue,
    SetValue
)
    local Row = CreateRow(44)

    CreateLabel(Row, Text)

    local Button =
        Instance.new("TextButton")

    Button.AnchorPoint =
        Vector2.new(1, 0.5)

    Button.Position =
        UDim2.new(1, -8, 0.5, 0)

    Button.Size =
        UDim2.fromOffset(58, 28)

    Button.BorderSizePixel = 0
    Button.TextColor3 = WHITE
    Button.TextSize = 10
    Button.Font = Enum.Font.GothamBold
    Button.AutoButtonColor = false
    Button.ZIndex = 13
    Button.Parent = Row

    local Corner =
        Instance.new("UICorner")

    Corner.CornerRadius =
        UDim.new(0, 7)

    Corner.Parent = Button

    local function Update()
        if GetValue() then
            Button.Text = "ON"
            Button.BackgroundColor3 =
                RED
        else
            Button.Text = "OFF"
            Button.BackgroundColor3 =
                DARKER
        end
    end

    Button.Activated:Connect(function()
        SetValue(
            not GetValue()
        )

        Update()
    end)

    Update()

    return Row, Button
end

--==============================================================
-- STICKY AIM
--==============================================================

CreateToggleRow(
    "Sticky Aim",

    function()
        return Config.StickyAim
    end,

    function(Value)
        Config.StickyAim =
            Value
    end
)

--==============================================================
-- AIMBOT WHITELIST SKIP
--==============================================================

local _, AimbotWhitelistButton =
    CreateToggleRow(
        "Whitelist Skip",

        function()
            return Config.AimbotWhitelistSkip
        end,

        function(Value)
            Config.AimbotWhitelistSkip =
                Value

            if Value
                and LockedTarget
                and IsWhitelisted(
                    LockedTarget
                ) then

                Locked = false
                LockedTarget = nil
            end
        end
    )

--==============================================================
-- CONTROLLER
--==============================================================

CreateSection("CONTROLLER")

local LockRow =
    CreateRow(44)

CreateLabel(
    LockRow,
    "Lock Button"
)

local LockDisplay =
    Instance.new("TextLabel")

LockDisplay.AnchorPoint =
    Vector2.new(1, 0.5)

LockDisplay.Position =
    UDim2.new(1, -8, 0.5, 0)

LockDisplay.Size =
    UDim2.new(0.37, 0, 0, 30)

LockDisplay.BackgroundColor3 =
    DARKER

LockDisplay.BorderSizePixel = 0

LockDisplay.Text =
    Config.LockButton.Name

LockDisplay.TextColor3 =
    WHITE

LockDisplay.TextSize = 10
LockDisplay.Font =
    Enum.Font.GothamBold

LockDisplay.ZIndex = 13
LockDisplay.Parent = LockRow

local LockCorner =
    Instance.new("UICorner")

LockCorner.CornerRadius =
    UDim.new(0, 6)

LockCorner.Parent =
    LockDisplay

local RebindRow =
    CreateRow(44)

local RebindButton =
    Instance.new("TextButton")

RebindButton.Position =
    UDim2.new(0, 8, 0, 7)

RebindButton.Size =
    UDim2.new(1, -16, 1, -14)

RebindButton.BackgroundColor3 =
    RED

RebindButton.BorderSizePixel = 0
RebindButton.Text =
    "SET LOCK BUTTON"

RebindButton.TextColor3 =
    WHITE

RebindButton.TextSize = 11
RebindButton.Font =
    Enum.Font.GothamBold

RebindButton.AutoButtonColor = false
RebindButton.ZIndex = 13
RebindButton.Parent =
    RebindRow

local RebindCorner =
    Instance.new("UICorner")

RebindCorner.CornerRadius =
    UDim.new(0, 7)

RebindCorner.Parent =
    RebindButton

--==============================================================
-- VISUALS
--==============================================================

CreateSection("VISUALS")

local _, ESPEnabledButton =
    CreateToggleRow(
        "Enabled",

        function()
            return Config.ESPEnabled
        end,

        function(Value)
            Config.ESPEnabled =
                Value
        end
    )

local _, ESPNameButton =
    CreateToggleRow(
        "Show Name",

        function()
            return Config.ESPShowName
        end,

        function(Value)
            Config.ESPShowName =
                Value
        end
    )

local _, ESPOutlineButton =
    CreateToggleRow(
        "Show Outline",

        function()
            return Config.ESPShowOutline
        end,

        function(Value)
            Config.ESPShowOutline =
                Value
        end
    )

local _, ESPWhitelistButton =
    CreateToggleRow(
        "Whitelist Check",

        function()
            return Config.ESPWhitelistCheck
        end,

        function(Value)
            Config.ESPWhitelistCheck =
                Value
        end
    )

--==============================================================
-- WHITELIST
--==============================================================

CreateSection("WHITELIST")

local WhitelistInfo =
    CreateRow(46)

local InfoText =
    Instance.new("TextLabel")

InfoText.BackgroundTransparency = 1
InfoText.Position =
    UDim2.new(0, 10, 0, 3)

InfoText.Size =
    UDim2.new(1, -20, 1, -6)

InfoText.Font =
    Enum.Font.Gotham

InfoText.Text =
    "Tap a player to whitelist / unwhitelist.\nRED = WHITELISTED"

InfoText.TextColor3 =
    GRAY

InfoText.TextSize = 10
InfoText.TextWrapped = true
InfoText.TextXAlignment =
    Enum.TextXAlignment.Left

InfoText.TextYAlignment =
    Enum.TextYAlignment.Center

InfoText.ZIndex = 13
InfoText.Parent =
    WhitelistInfo

local WhitelistContainer =
    Instance.new("Frame")

WhitelistContainer.BackgroundTransparency =
    1

WhitelistContainer.Size =
    UDim2.new(1, 0, 0, 10)

WhitelistContainer.ZIndex = 12
WhitelistContainer.Parent =
    Scroll

local WhitelistLayout =
    Instance.new("UIListLayout")

WhitelistLayout.Padding =
    UDim.new(0, 6)

WhitelistLayout.SortOrder =
    Enum.SortOrder.LayoutOrder

WhitelistLayout.Parent =
    WhitelistContainer

--==============================================================
-- STATUS
--==============================================================

CreateSection("STATUS")

local StatusRow =
    CreateRow(55)

local StatusLabel =
    Instance.new("TextLabel")

StatusLabel.BackgroundTransparency = 1
StatusLabel.Position =
    UDim2.new(0, 12, 0, 5)

StatusLabel.Size =
    UDim2.new(1, -24, 0, 20)

StatusLabel.Font =
    Enum.Font.GothamBold

StatusLabel.Text =
    "UNLOCKED"

StatusLabel.TextColor3 =
    GRAY

StatusLabel.TextSize = 13
StatusLabel.TextXAlignment =
    Enum.TextXAlignment.Left

StatusLabel.ZIndex = 13
StatusLabel.Parent =
    StatusRow

local TargetLabel =
    Instance.new("TextLabel")

TargetLabel.BackgroundTransparency = 1
TargetLabel.Position =
    UDim2.new(0, 12, 0, 27)

TargetLabel.Size =
    UDim2.new(1, -24, 0, 18)

TargetLabel.Font =
    Enum.Font.Gotham

TargetLabel.Text =
    "Target: None"

TargetLabel.TextColor3 =
    GRAY

TargetLabel.TextSize = 10
TargetLabel.TextXAlignment =
    Enum.TextXAlignment.Left

TargetLabel.ZIndex = 13
TargetLabel.Parent =
    StatusRow

--==============================================================
-- ESP
--==============================================================

local FONT = Enum.Font.Gotham
local TEXT_SIZE = 9
local NEUTRAL = Color3.fromRGB(
    255,
    255,
    255
)

local floor = math.floor
local UPDATE_EVERY = 4

local function TeamColor(Player)
    local Team = Player.Team

    if Team then
        local TeamColor =
            Team.TeamColor

        if TeamColor then
            return TeamColor.Color
        end
    end

    return NEUTRAL
end

--==============================================================
-- ESP CLEANUP
--==============================================================

local function CleanupESP(Player)
    local Data = ESP[Player]

    if not Data then
        return
    end

    if Data.gui1 then
        pcall(function()
            Data.gui1:Destroy()
        end)
    end

    if Data.gui2 then
        pcall(function()
            Data.gui2:Destroy()
        end)
    end

    if Data.hl then
        pcall(function()
            Data.hl:Destroy()
        end)
    end

    ESP[Player] = nil
end

--==============================================================
-- ESP COLOR
--==============================================================

local function ApplyESPColor(Player, Data)
    if not Data then
        return
    end

    local Color =
        TeamColor(Player)

    if Data.nLabel then
        Data.nLabel.TextColor3 =
            Color
    end

    if Data.hl then
        Data.hl.OutlineColor =
            Color
    end
end

--==============================================================
-- ESP SHOULD EXIST
--==============================================================

local function ShouldESP(Player)
    if Player == LocalPlayer then
        return false
    end

    if not Config.ESPEnabled then
        return false
    end

    if Config.ESPWhitelistCheck
        and IsWhitelisted(Player) then

        return false
    end

    return true
end

--==============================================================
-- ESP CHARACTER
--==============================================================

local function OnESPCharacter(
    Player,
    Character
)
    CleanupESP(Player)

    if not ShouldESP(Player) then
        return
    end

    local Root =
        Character:WaitForChild(
            "HumanoidRootPart",
            5
        )

    if not Root
        or not Root.Parent
        or not Character.Parent then

        return
    end

    local Data = {
        root = Root,
        nLabel = nil,
        dLabel = nil,
        hl = nil,
        gui1 = nil,
        gui2 = nil,
        lastDist = -1,
        lastTeam = Player.Team,
    }

    --==========================================================
    -- NAME
    --==========================================================

    if Config.ESPShowName then
        local Gui1 =
            Instance.new("BillboardGui")

        Gui1.Name =
            "NameESP"

        Gui1.AlwaysOnTop = true

        Gui1.Size =
            UDim2.fromOffset(
                90,
                12
            )

        Gui1.StudsOffsetWorldSpace =
            Vector3.new(
                0,
                3,
                0
            )

        Gui1.Adornee =
            Root

        Gui1.Parent =
            Root

        local NameLabel =
            Instance.new("TextLabel")

        NameLabel.BackgroundTransparency =
            1

        NameLabel.Size =
            UDim2.fromScale(
                1,
                1
            )

        NameLabel.Font =
            FONT

        NameLabel.TextSize =
            TEXT_SIZE

        NameLabel.TextColor3 =
            WHITE

        NameLabel.TextStrokeTransparency =
            0

        NameLabel.Text =
            Player.DisplayName
            or Player.Name

        NameLabel.Parent =
            Gui1

        Data.gui1 =
            Gui1

        Data.nLabel =
            NameLabel
    end

    --==========================================================
    -- DISTANCE
    --==========================================================

    local Gui2 =
        Instance.new("BillboardGui")

    Gui2.Name =
        "DistESP"

    Gui2.AlwaysOnTop = true

    Gui2.Size =
        UDim2.fromOffset(
            75,
            12
        )

    Gui2.StudsOffsetWorldSpace =
        Vector3.new(
            0,
            -3,
            0
        )

    Gui2.Adornee =
        Root

    Gui2.Parent =
        Root

    local DistanceLabel =
        Instance.new("TextLabel")

    DistanceLabel.BackgroundTransparency =
        1

    DistanceLabel.Size =
        UDim2.fromScale(
            1,
            1
        )

    DistanceLabel.Font =
        FONT

    DistanceLabel.TextSize =
        TEXT_SIZE

    DistanceLabel.TextColor3 =
        WHITE

    DistanceLabel.TextStrokeTransparency =
        0

    DistanceLabel.Text =
        "0 studs"

    DistanceLabel.Parent =
        Gui2

    Data.gui2 =
        Gui2

    Data.dLabel =
        DistanceLabel

    --==========================================================
    -- HIGHLIGHT
    --==========================================================

    if Config.ESPShowOutline then
        local Highlight =
            Instance.new("Highlight")

        Highlight.FillTransparency =
            1

        Highlight.OutlineTransparency =
            0

        Highlight.DepthMode =
            Enum.HighlightDepthMode.AlwaysOnTop

        Highlight.Adornee =
            Character

        Highlight.Parent =
            Character

        Data.hl =
            Highlight
    end

    ESP[Player] =
        Data

    ApplyESPColor(
        Player,
        Data
    )
end

--==============================================================
-- ESP ATTACH
--==============================================================

local function AttachESP(Player)
    if Player == LocalPlayer then
        return
    end

    if Player.Character then
        task.spawn(
            OnESPCharacter,
            Player,
            Player.Character
        )
    end

    Connect(
        Player.CharacterAdded,
        function(Character)
            task.spawn(
                OnESPCharacter,
                Player,
                Character
            )
        end
    )
end

--==============================================================
-- UPDATE ESP PLAYER
--==============================================================

local function UpdateESPPlayer(Player)
    if Player == LocalPlayer then
        return
    end

    CleanupESP(Player)

    if not ShouldESP(Player) then
        return
    end

    if Player.Character then
        task.spawn(
            OnESPCharacter,
            Player,
            Player.Character
        )
    end
end

--==============================================================
-- UPDATE ALL ESP
--==============================================================

local function UpdateAllESP()
    for _, Player in ipairs(
        Players:GetPlayers()
    ) do
        if Player ~= LocalPlayer then
            UpdateESPPlayer(Player)
        end
    end
end

--==============================================================
-- ESP TOGGLE CONNECTIONS
--==============================================================

ESPEnabledButton.Activated:Connect(
    function()
        task.defer(
            UpdateAllESP
        )
    end
)

ESPNameButton.Activated:Connect(
    function()
        task.defer(
            UpdateAllESP
        )
    end
)

ESPOutlineButton.Activated:Connect(
    function()
        task.defer(
            UpdateAllESP
        )
    end
)

ESPWhitelistButton.Activated:Connect(
    function()
        task.defer(
            UpdateAllESP
        )
    end
)

--==============================================================
-- WHITELIST UI
--==============================================================

local function ClearWhitelistUI()
    for _, Child in ipairs(
        WhitelistContainer:GetChildren()
    ) do
        if Child:IsA("TextButton") then
            Child:Destroy()
        end
    end
end

local function CreateWhitelistEntry(Player)
    local Entry =
        Instance.new("TextButton")

    Entry.Name =
        "Whitelist_" ..
        tostring(Player.UserId)

    Entry.Size =
        UDim2.new(
            1,
            0,
            0,
            40
        )

    Entry.BackgroundColor3 =
        IsWhitelisted(Player)
        and RED
        or DARK

    Entry.BorderSizePixel = 0

    Entry.Text =
        Player.DisplayName ..
        "  @" ..
        Player.Name

    Entry.TextColor3 =
        WHITE

    Entry.TextSize =
        IsMobile and 9 or 11

    Entry.Font =
        Enum.Font.GothamMedium

    Entry.TextXAlignment =
        Enum.TextXAlignment.Left

    Entry.AutoButtonColor = false
    Entry.ZIndex = 13
    Entry.Parent =
        WhitelistContainer

    local EntryPadding =
        Instance.new("UIPadding")

    EntryPadding.PaddingLeft =
        UDim.new(0, 12)

    EntryPadding.Parent =
        Entry

    local Corner =
        Instance.new("UICorner")

    Corner.CornerRadius =
        UDim.new(0, 8)

    Corner.Parent =
        Entry

    Entry.Activated:Connect(
        function()

            local NewValue =
                not IsWhitelisted(
                    Player
                )

            SetWhitelist(
                Player,
                NewValue
            )

            if NewValue then
                Entry.BackgroundColor3 =
                    RED
            else
                Entry.BackgroundColor3 =
                    DARK
            end

            -- If they were currently
            -- locked and whitelist skip
            -- is enabled, unlock.
            if Locked
                and LockedTarget == Player
                and Config.AimbotWhitelistSkip
                and NewValue then

                Locked = false
                LockedTarget = nil
            end

            UpdateStatus()

            UpdateESPPlayer(
                Player
            )
        end
    )

    return Entry
end

local function RefreshWhitelistUI()
    ClearWhitelistUI()

    local PlayerList =
        Players:GetPlayers()

    table.sort(
        PlayerList,
        function(A, B)
            return A.Name:lower() <
                B.Name:lower()
        end
    )

    for _, Player in ipairs(
        PlayerList
    ) do
        if Player ~= LocalPlayer then
            CreateWhitelistEntry(
                Player
            )
        end
    end

    task.defer(
        function()
            WhitelistContainer.Size =
                UDim2.new(
                    1,
                    0,
                    0,
                    WhitelistLayout
                        .AbsoluteContentSize
                        .Y
                )
        end
    )
end

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

    local Character =
        Player.Character

    if not Character then
        return nil
    end

    local Humanoid =
        Character:FindFirstChildOfClass(
            "Humanoid"
        )

    local Root =
        Character:FindFirstChild(
            "HumanoidRootPart"
        )

    if not Humanoid or not Root then
        return nil
    end

    if Humanoid.Health <= 0 then
        return nil
    end

    return Character,
        Humanoid,
        Root
end

--==============================================================
-- LOCAL ROOT
--==============================================================

local function GetLocalRoot()
    local Character =
        LocalPlayer.Character

    if not Character then
        return nil
    end

    return Character:FindFirstChild(
        "HumanoidRootPart"
    )
end

--==============================================================
-- CLOSEST TO CAMERA CENTER
--==============================================================

local function GetClosestToCursor()
    local CurrentCamera =
        workspace.CurrentCamera

    if not CurrentCamera then
        return nil
    end

    local Viewport =
        CurrentCamera.ViewportSize

    local Center =
        Vector2.new(
            Viewport.X / 2,
            Viewport.Y / 2
        )

    local BestPlayer = nil
    local BestDistance =
        math.huge

    for _, Player in ipairs(
        Players:GetPlayers()
    ) do

        if Player ~= LocalPlayer
            and not (
                Config.AimbotWhitelistSkip
                and IsWhitelisted(
                    Player
                )
            ) then

            local Character,
                Humanoid,
                Root =
                GetCharacterData(
                    Player
                )

            if Character
                and Humanoid
                and Root then

                local WorldDistance =
                    (
                        Root.Position -
                        CurrentCamera.CFrame.Position
                    ).Magnitude

                if WorldDistance <=
                    Config.MaxTargetDistance then

                    local ScreenPosition,
                        OnScreen =
                        CurrentCamera:
                        WorldToViewportPoint(
                            Root.Position
                        )

                    if OnScreen
                        and ScreenPosition.Z > 0 then

                        local ScreenDistance =
                            (
                                Vector2.new(
                                    ScreenPosition.X,
                                    ScreenPosition.Y
                                ) -
                                Center
                            ).Magnitude

                        if ScreenDistance <
                            BestDistance then

                            BestDistance =
                                ScreenDistance

                            BestPlayer =
                                Player
                        end
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
    local LocalRoot =
        GetLocalRoot()

    if not LocalRoot then
        return nil
    end

    local BestPlayer = nil

    local BestDistance =
        Config.MaxTargetDistance

    for _, Player in ipairs(
        Players:GetPlayers()
    ) do

        if Player ~= LocalPlayer
            and not (
                Config.AimbotWhitelistSkip
                and IsWhitelisted(
                    Player
                )
            ) then

            local Character,
                Humanoid,
                Root =
                GetCharacterData(
                    Player
                )

            if Character
                and Humanoid
                and Root then

                local Distance =
                    (
                        Root.Position -
                        LocalRoot.Position
                    ).Magnitude

                if Distance <=
                    BestDistance then

                    BestDistance =
                        Distance

                    BestPlayer =
                        Player
                end
            end
        end
    end

    return BestPlayer
end

--==============================================================
-- FIND TARGET
--==============================================================

local function FindTarget()
    if Config.StickyAim then
        return GetClosestToCursor()
    end

    return GetClosestByDistance()
end

--==============================================================
-- PREDICTION
--==============================================================

local function GetPredictedPosition(
    Position,
    Velocity
)
    return Position +
        Velocity *
        Config.Prediction
end

--==============================================================
-- ADAPTIVE OFFSET
--==============================================================

local function GetAdaptiveOffset(
    TargetRoot
)
    local CurrentCamera =
        workspace.CurrentCamera

    if not CurrentCamera
        or not TargetRoot then

        return Config.AimOffset
    end

    local Distance =
        (
            TargetRoot.Position -
            CurrentCamera.CFrame.Position
        ).Magnitude

    local Adaptive =
        Config.AimOffset *
        (
            Distance /
            Config.ReferenceDistance
        )

    return math.clamp(
        Adaptive,
        -100,
        100
    )
end

--==============================================================
-- AIM POSITION
--==============================================================

local function GetAimPosition(Player)
    local Character,
        Humanoid,
        Root =
        GetCharacterData(
            Player
        )

    if not Character
        or not Humanoid
        or not Root then

        return nil
    end

    -- FIRST PERSON
    if Config.CameraMode ==
        "First Person" then

        local Head =
            Character:FindFirstChild(
                "Head"
            )

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

    local Offset =
        GetAdaptiveOffset(
            Root
        )

    return Predicted -
        Vector3.new(
            0,
            Offset,
            0
        )
end

--==============================================================
-- STATUS
--==============================================================

local function UpdateStatus()
    if Locked
        and LockedTarget then

        StatusLabel.Text =
            "LOCKED"

        StatusLabel.TextColor3 =
            RED

        TargetLabel.Text =
            "Target: " ..
            LockedTarget.Name
    else
        StatusLabel.Text =
            "UNLOCKED"

        StatusLabel.TextColor3 =
            GRAY

        TargetLabel.Text =
            "Target: None"
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

    local Target =
        FindTarget()

    if not Target then
        UpdateStatus()
        return
    end

    if Config.AimbotWhitelistSkip
        and IsWhitelisted(
            Target
        ) then

        return
    end

    LockedTarget =
        Target

    Locked = true

    UpdateStatus()
end

--==============================================================
-- TARGET VALID
--==============================================================

local function IsTargetValid(Player)
    if not Player then
        return false
    end

    if Player.Parent ~= Players then
        return false
    end

    if Config.AimbotWhitelistSkip
        and IsWhitelisted(
            Player
        ) then

        return false
    end

    local Character,
        Humanoid,
        Root =
        GetCharacterData(
            Player
        )

    return Character ~= nil
        and Humanoid ~= nil
        and Root ~= nil
end

--==============================================================
-- SUPPORTED CONTROLLER INPUTS
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
-- CONTROLLER INPUT
--==============================================================

Connect(
    UserInputService.InputBegan,
    function(Input, GameProcessed)

        if GameProcessed then
            return
        end

        if Input.UserInputType ~=
            Enum.UserInputType.Gamepad1 then

            return
        end

        -- REBIND
        if WaitingForButton then

            if SupportedButtons[
                Input.KeyCode
            ] then

                Config.LockButton =
                    Input.KeyCode

                LockDisplay.Text =
                    Input.KeyCode.Name

                WaitingForButton = false

                RebindButton.Text =
                    "SET LOCK BUTTON"

                RebindButton.BackgroundColor3 =
                    RED
            end

            return
        end

        -- LOCK
        if Input.KeyCode ==
            Config.LockButton then

            Lock()
        end
    end
)

--==============================================================
-- REBIND BUTTON
--==============================================================

RebindButton.Activated:Connect(
    function()

        WaitingForButton =
            not WaitingForButton

        if WaitingForButton then

            RebindButton.Text =
                "PRESS CONTROLLER BUTTON..."

            RebindButton.BackgroundColor3 =
                DARK_RED

        else

            RebindButton.Text =
                "SET LOCK BUTTON"

            RebindButton.BackgroundColor3 =
                RED
        end
    end
)

--==============================================================
-- CLOSE / OPEN
--==============================================================

CloseButton.Activated:Connect(
    function()

        MainVisible = false
        MainFrame.Visible = false

        FloatingToggle.Text = "+"
    end
)

FloatingToggle.Activated:Connect(
    function()

        MainVisible =
            not MainVisible

        MainFrame.Visible =
            MainVisible

        if MainVisible then
            FloatingToggle.Text = "X"
        else
            FloatingToggle.Text = "+"
        end
    end
)

--==============================================================
-- PLAYER EVENTS
--==============================================================

Connect(
    Players.PlayerAdded,
    function(Player)

        task.defer(
            RefreshWhitelistUI
        )

        if Player.Character then
            task.defer(
                function()
                    UpdateESPPlayer(
                        Player
                    )
                end
            )
        end

        Connect(
            Player.CharacterAdded,
            function(Character)

                task.wait(0.5)

                if ShouldESP(Player) then
                    OnESPCharacter(
                        Player,
                        Character
                    )
                end
            end
        )
    end
)

Connect(
    Players.PlayerRemoving,
    function(Player)

        if Player ==
            LockedTarget then

            Unlock()
        end

        CleanupESP(Player)

        task.defer(
            RefreshWhitelistUI
        )
    end
)

Connect(
    LocalPlayer.CharacterAdded,
    function()
        Unlock()
    end
)

--==============================================================
-- EXISTING ESP PLAYERS
--==============================================================

for _, Player in ipairs(
    Players:GetPlayers()
) do

    if Player ~= LocalPlayer then
        AttachESP(Player)
    end
end

--==============================================================
-- ESP DISTANCE / TEAM UPDATE
--==============================================================

local ESPFrame = 0

Connect(
    RunService.Heartbeat,
    function()

        ESPFrame += 1

        if ESPFrame %
            UPDATE_EVERY ~= 0 then

            return
        end

        local Character =
            LocalPlayer.Character

        local LocalRoot =
            Character
            and Character:
                FindFirstChild(
                    "HumanoidRootPart"
                )

        if not LocalRoot then
            return
        end

        local Position =
            LocalRoot.Position

        for Player, Data in pairs(ESP) do

            if Data.root
                and Data.root.Parent then

                --==================================================
                -- DISTANCE
                --==================================================

                local Distance =
                    floor(
                        (
                            Position -
                            Data.root.Position
                        ).Magnitude
                    )

                if Distance ~=
                    Data.lastDist then

                    Data.lastDist =
                        Distance

                    if Data.dLabel then
                        Data.dLabel.Text =
                            Distance ..
                            " studs"
                    end
                end

                --==================================================
                -- TEAM COLOR
                --==================================================

                if Player.Team ~=
                    Data.lastTeam then

                    Data.lastTeam =
                        Player.Team

                    ApplyESPColor(
                        Player,
                        Data
                    )
                end

                --==================================================
                -- WHITELIST
                --==================================================

                if
                    Config.ESPWhitelistCheck
                    and IsWhitelisted(
                        Player
                    ) then

                    CleanupESP(Player)

                end

            else
                CleanupESP(Player)
            end
        end
    end
)

--==============================================================
-- AIMLOCK RENDER
--==============================================================

RunService:BindToRenderStep(
    "XenonCameraLock",
    Enum.RenderPriority.Last.Value,
    function()

        if not Locked then
            return
        end

        if not IsTargetValid(
            LockedTarget
        ) then

            Unlock()
            return
        end

        local CurrentCamera =
            workspace.CurrentCamera

        if not CurrentCamera then
            return
        end

        local AimPosition =
            GetAimPosition(
                LockedTarget
            )

        if not AimPosition then
            Unlock()
            return
        end

        local CameraPosition =
            CurrentCamera.CFrame.Position

        local DesiredCFrame =
            CFrame.lookAt(
                CameraPosition,
                AimPosition
            )

        -- HARD LOCK
        if Config.Smoothing <= 0 then

            CurrentCamera.CFrame =
                DesiredCFrame

            return
        end

        -- SMOOTH LOCK
        local Alpha =
            math.clamp(
                1 /
                (
                    Config.Smoothing +
                    1
                ),
                0,
                1
            )

        CurrentCamera.CFrame =
            CurrentCamera.CFrame:Lerp(
                DesiredCFrame,
                Alpha
            )
    end
)

--==============================================================
-- DRAGGING
--==============================================================

local Dragging = false
local DragStart
local StartPosition

TopBar.InputBegan:Connect(
    function(Input)

        if Input.UserInputType ==
            Enum.UserInputType.MouseButton1
            or
            Input.UserInputType ==
            Enum.UserInputType.Touch then

            Dragging = true

            DragStart =
                Input.Position

            StartPosition =
                MainFrame.Position

            local ChangedConnection

            ChangedConnection =
                Input.Changed:Connect(
                    function()

                        if Input.UserInputState ==
                            Enum.UserInputState.End then

                            Dragging = false

                            if ChangedConnection then
                                ChangedConnection:Disconnect()
                            end
                        end
                    end
                )
        end
    end
)

Connect(
    UserInputService.InputChanged,
    function(Input)

        if not Dragging then
            return
        end

        if Input.UserInputType ~=
            Enum.UserInputType.MouseMovement
            and
            Input.UserInputType ~=
            Enum.UserInputType.Touch then

            return
        end

        local Delta =
            Input.Position -
            DragStart

        MainFrame.Position =
            UDim2.new(
                StartPosition.X.Scale,
                StartPosition.X.Offset +
                    Delta.X,

                StartPosition.Y.Scale,
                StartPosition.Y.Offset +
                    Delta.Y
            )
    end
)

--==============================================================
-- CANVAS UPDATES
--==============================================================

Layout:GetPropertyChangedSignal(
    "AbsoluteContentSize"
):Connect(
    function()

        Scroll.CanvasSize =
            UDim2.fromOffset(
                0,
                Layout.AbsoluteContentSize.Y +
                    25
            )
    end
)

WhitelistLayout:GetPropertyChangedSignal(
    "AbsoluteContentSize"
):Connect(
    function()

        WhitelistContainer.Size =
            UDim2.new(
                1,
                0,
                0,
                WhitelistLayout
                    .AbsoluteContentSize.Y
            )
    end
)

--==============================================================
-- RESPONSIVE CAMERA
--==============================================================

UpdateResponsive()

workspace.CurrentCamera:
    GetPropertyChangedSignal(
        "ViewportSize"
    ):Connect(
        UpdateResponsive
    )

--==============================================================
-- INITIAL UI
--==============================================================

RefreshWhitelistUI()
UpdateAllESP()
UpdateStatus()

--==============================================================
-- CLEANUP
--==============================================================

_G.XenonCleanup = function()

    pcall(function()
        RunService:UnbindFromRenderStep(
            "XenonCameraLock"
        )
    end)

    for Player in pairs(ESP) do
        CleanupESP(Player)
    end

    DisconnectAll()

    local Gui =
        PlayerGui:FindFirstChild(
            "Xenon"
        )

    if Gui then
        Gui:Destroy()
    end

    _G.XenonCleanup = nil
end

--==============================================================
-- DONE
--==============================================================

print("======================================")
print("XENON LOADED")
print("Aim Offset:", Config.AimOffset)
print("Lock Button:", Config.LockButton.Name)
print("Sticky Aim:", Config.StickyAim)
print(
    "Aimbot Whitelist Skip:",
    Config.AimbotWhitelistSkip
)
print(
    "ESP:",
    Config.ESPEnabled
)
print("======================================")
