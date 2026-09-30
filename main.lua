--==============================================================
-- XENON
-- CONTROLLER CAMERA LOCK + ESP + WHITELIST
-- MOBILE RESPONSIVE EDITION
--==============================================================

--==============================================================
-- SERVICES
--==============================================================

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Camera = workspace.CurrentCamera

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

    -- 3P offset now starts at 23.5
    AimOffset = 23.5,

    -- Distance where the 3P Offset value is exact.
    ReferenceDistance = 40,

    -- 3P tracking
    -- AimOffset is the exact offset at the calibration distance.
    -- Increasing it always moves the aim lower.
    ThirdPersonAnchor = 0.65,
    ThirdPersonCalibrationDistance = 40,
    ThirdPersonMinOffset = 0,
    ThirdPersonMaxOffset = 100,

    Smoothing = 0,

    Prediction = 0.08,

    MaxTargetDistance = 500,

    StickyAim = true,

    -- Lock safety checks
    WallCheck = true,
    KnockedCheck = true,
    UnlockHealth = 10,

    -- ESP
    ESPEnabled = false,
    ESPShowName = true,
    ESPShowOutline = true,
    ESPWhitelistCheck = true,

    -- Aimbot whitelist protection
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

local ESPObjects = {}

local Whitelist = {}

--==============================================================
-- WHITELIST STORAGE
--==============================================================

local WhitelistFileName = "XenonWhitelist.json"

local function LoadWhitelist()
    table.clear(Whitelist)

    if type(isfile) ~= "function" then
        return
    end

    if type(readfile) ~= "function" then
        return
    end

    local Success, Data = pcall(function()
        if not isfile(WhitelistFileName) then
            return nil
        end

        return readfile(WhitelistFileName)
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
        local NumberId = tonumber(UserId)

        if NumberId then
            Whitelist[NumberId] = true
        end
    end
end

local function SaveWhitelist()
    if type(writefile) ~= "function" then
        return
    end

    local Data = {}

    for UserId, IsWhitelisted in pairs(Whitelist) do
        if IsWhitelisted then
            table.insert(Data, tonumber(UserId))
        end
    end

    pcall(function()
        writefile(
            WhitelistFileName,
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

local function SetWhitelist(Player, State)
    if not Player then
        return
    end

    if State then
        Whitelist[Player.UserId] = true
    else
        Whitelist[Player.UserId] = nil
    end

    SaveWhitelist()
end

--==============================================================
-- CONNECTION HELPERS
--==============================================================

local function DisconnectAll()
    for _, Connection in ipairs(Connections) do
        pcall(function()
            Connection:Disconnect()
        end)
    end

    table.clear(Connections)
end

local function Connect(Signal, Callback)
    local Connection = Signal:Connect(Callback)

    table.insert(
        Connections,
        Connection
    )

    return Connection
end

--==============================================================
-- GUI
--==============================================================

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "Xenon"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- Keep XENON above other PlayerGui interfaces while it is open.
-- Closing the UI still hides the XENON interface normally.
ScreenGui.DisplayOrder = 1000000
ScreenGui.Parent = PlayerGui

--==============================================================
-- COLORS
--==============================================================

local BLACK = Color3.fromRGB(8, 8, 8)
local DARK = Color3.fromRGB(14, 14, 14)
local DARKER = Color3.fromRGB(20, 20, 20)
local LIGHT_DARK = Color3.fromRGB(30, 30, 30)

local WHITE = Color3.fromRGB(245, 245, 245)
local GRAY = Color3.fromRGB(150, 150, 150)

local RED = Color3.fromRGB(220, 40, 40)
local DARK_RED = Color3.fromRGB(110, 25, 25)

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
MainFrame.ZIndex = 1
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
-- CLOSE
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
-- SCROLL
--==============================================================

local Scroll = Instance.new("ScrollingFrame")
Scroll.Name = "TabAim"
Scroll.BackgroundTransparency = 1
Scroll.BorderSizePixel = 0
Scroll.Position = UDim2.new(0, 10, 0, 108)
Scroll.Size = UDim2.new(1, -20, 1, -118)
Scroll.CanvasSize = UDim2.fromOffset(0, 1200)
Scroll.ScrollBarThickness = 3
Scroll.ScrollBarImageColor3 = RED
Scroll.ScrollingDirection = Enum.ScrollingDirection.Y
Scroll.ZIndex = 11
Scroll.Parent = MainFrame

local function ConfigureTabContainer(Container, Name)
    Container.Name = Name
    Container.BackgroundTransparency = 1
    Container.BorderSizePixel = 0
    Container.Position = Scroll.Position
    Container.Size = Scroll.Size
    Container.CanvasSize = UDim2.fromOffset(0, 1200)
    Container.ScrollBarThickness = 3
    Container.ScrollBarImageColor3 = RED
    Container.ScrollingDirection = Enum.ScrollingDirection.Y
    Container.ZIndex = 11
    Container.Visible = false
    Container.Parent = MainFrame

    local Padding = Instance.new("UIPadding")
    Padding.PaddingLeft = UDim.new(0, 5)
    Padding.PaddingRight = UDim.new(0, 5)
    Padding.PaddingTop = UDim.new(0, 3)
    Padding.PaddingBottom = UDim.new(0, 12)
    Padding.Parent = Container

    local Layout = Instance.new("UIListLayout")
    Layout.Padding = UDim.new(0, 8)
    Layout.SortOrder = Enum.SortOrder.LayoutOrder
    Layout.Parent = Container

    return Layout
end

local VisualsTab = Instance.new("ScrollingFrame")
local WhitelistTab = Instance.new("ScrollingFrame")

local AimLayout = Instance.new("UIListLayout")
AimLayout.Padding = UDim.new(0, 8)
AimLayout.SortOrder = Enum.SortOrder.LayoutOrder
AimLayout.Parent = Scroll

local AimPadding = Instance.new("UIPadding")
AimPadding.PaddingLeft = UDim.new(0, 5)
AimPadding.PaddingRight = UDim.new(0, 5)
AimPadding.PaddingTop = UDim.new(0, 3)
AimPadding.PaddingBottom = UDim.new(0, 12)
AimPadding.Parent = Scroll

local VisualsLayout = ConfigureTabContainer(VisualsTab, "TabVisuals")
local WhitelistLayout = ConfigureTabContainer(WhitelistTab, "TabWhitelist")

local TabBar = Instance.new("Frame")
TabBar.Name = "TabBar"
TabBar.BackgroundColor3 = DARK
TabBar.BorderSizePixel = 0
TabBar.Position = UDim2.new(0, 10, 0, 66)
TabBar.Size = UDim2.new(1, -20, 0, 38)
TabBar.ZIndex = 20
TabBar.Parent = MainFrame

local TabBarCorner = Instance.new("UICorner")
TabBarCorner.CornerRadius = UDim.new(0, 8)
TabBarCorner.Parent = TabBar

local TabPadding = Instance.new("UIPadding")
TabPadding.PaddingLeft = UDim.new(0, 4)
TabPadding.PaddingRight = UDim.new(0, 4)
TabPadding.Parent = TabBar

local TabLayout = Instance.new("UIListLayout")
TabLayout.FillDirection = Enum.FillDirection.Horizontal
TabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
TabLayout.VerticalAlignment = Enum.VerticalAlignment.Center
TabLayout.SortOrder = Enum.SortOrder.LayoutOrder
TabLayout.Padding = UDim.new(0, 2)
TabLayout.Parent = TabBar

local CurrentTabContainer = Scroll
local CurrentTabName = "AIM"
local TabButtons = {}
local TabIndicators = {}

local function CreateTab(Name, Order)
    local Button = Instance.new("TextButton")
    Button.Name = Name .. "Tab"
    Button.LayoutOrder = Order
    Button.BackgroundTransparency = 1
    Button.BorderSizePixel = 0
    Button.Size = UDim2.new(1/3, -3, 1, 0)
    Button.Text = Name
    Button.TextColor3 = GRAY
    Button.TextSize = 11
    Button.Font = Enum.Font.GothamSemibold
    Button.AutoButtonColor = false
    Button.ZIndex = 22
    Button.Parent = TabBar

    local Indicator = Instance.new("Frame")
    Indicator.Name = "Indicator"
    Indicator.AnchorPoint = Vector2.new(0.5, 1)
    Indicator.Position = UDim2.new(0.5, 0, 1, 0)
    Indicator.Size = UDim2.new(0.55, 0, 0, 2)
    Indicator.BackgroundColor3 = RED
    Indicator.BorderSizePixel = 0
    Indicator.Visible = false
    Indicator.ZIndex = 23
    Indicator.Parent = Button

    TabButtons[Name] = Button
    TabIndicators[Name] = Indicator

    return Button
end

local AimTabButton = CreateTab("AIM", 1)
local VisualsTabButton = CreateTab("VISUALS", 2)
local WhitelistTabButton = CreateTab("WHITELIST", 3)

local function UpdateTabCanvas(Container, Layout)
    Container.CanvasSize = UDim2.fromOffset(0, Layout.AbsoluteContentSize.Y + 25)
end

local function SetActiveTab(Name)
    local Containers = {
        AIM = Scroll,
        VISUALS = VisualsTab,
        WHITELIST = WhitelistTab,
    }

    local Layouts = {
        AIM = AimLayout,
        VISUALS = VisualsLayout,
        WHITELIST = WhitelistLayout,
    }

    local Container = Containers[Name]
    if not Container then return end

    CurrentTabName = Name
    CurrentTabContainer = Container

    for TabName, TabButton in pairs(TabButtons) do
        local Active = TabName == Name
        TabButton.TextColor3 = Active and WHITE or GRAY
        TabIndicators[TabName].Visible = Active
    end

    for TabName, TabContainer in pairs(Containers) do
        TabContainer.Visible = TabName == Name
    end

    UpdateTabCanvas(Container, Layouts[Name])
end

AimTabButton.Activated:Connect(function() SetActiveTab("AIM") end)
VisualsTabButton.Activated:Connect(function() SetActiveTab("VISUALS") end)
WhitelistTabButton.Activated:Connect(function() SetActiveTab("WHITELIST") end)

SetActiveTab("AIM")

--==============================================================
-- MOBILE RESPONSIVE
--==============================================================

local IsMobile = false

local function UpdateResponsiveState()
    local Viewport = Camera.ViewportSize

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

        TopBar.Size = UDim2.new(1, 0, 0, 50)

        TabBar.Position =
            UDim2.new(0, 8, 0, 57)
        TabBar.Size =
            UDim2.new(1, -16, 0, 34)

        Scroll.Position =
            UDim2.new(0, 8, 0, 99)
        Scroll.Size =
            UDim2.new(1, -16, 1, -107)
        VisualsTab.Position = Scroll.Position
        VisualsTab.Size = Scroll.Size
        WhitelistTab.Position = Scroll.Position
        WhitelistTab.Size = Scroll.Size

        for _, Button in pairs(TabButtons) do
            Button.TextSize = 9
        end

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

        AimPadding.PaddingLeft =
            UDim.new(0, 3)
        AimPadding.PaddingRight =
            UDim.new(0, 3)

    elseif Viewport.X <= 1000 then
        MainFrame.Size =
            UDim2.fromOffset(320, 490)

        TopBar.Size =
            UDim2.new(1, 0, 0, 54)

        TabBar.Position =
            UDim2.new(0, 9, 0, 62)
        TabBar.Size =
            UDim2.new(1, -18, 0, 36)

        Scroll.Position =
            UDim2.new(0, 9, 0, 104)
        Scroll.Size =
            UDim2.new(1, -18, 1, -112)
        VisualsTab.Position = Scroll.Position
        VisualsTab.Size = Scroll.Size
        WhitelistTab.Position = Scroll.Position
        WhitelistTab.Size = Scroll.Size

        for _, Button in pairs(TabButtons) do
            Button.TextSize = 10
        end

        Title.TextSize = 19

        Subtitle.TextSize = 8

        CloseButton.Size =
            UDim2.fromOffset(30, 30)

        AimPadding.PaddingLeft =
            UDim.new(0, 4)
        AimPadding.PaddingRight =
            UDim.new(0, 4)

    else
        MainFrame.Size =
            UDim2.fromOffset(390, 570)

        TopBar.Size =
            UDim2.new(1, 0, 0, 58)

        TabBar.Position =
            UDim2.new(0, 10, 0, 66)
        TabBar.Size =
            UDim2.new(1, -20, 0, 38)

        Scroll.Position =
            UDim2.new(0, 10, 0, 108)
        Scroll.Size =
            UDim2.new(1, -20, 1, -118)
        VisualsTab.Position = Scroll.Position
        VisualsTab.Size = Scroll.Size
        WhitelistTab.Position = Scroll.Position
        WhitelistTab.Size = Scroll.Size

        for _, Button in pairs(TabButtons) do
            Button.TextSize = 11
        end

        Title.TextSize = 21

        Subtitle.TextSize = 9

        CloseButton.Size =
            UDim2.fromOffset(32, 32)

        AimPadding.PaddingLeft =
            UDim.new(0, 5)
        AimPadding.PaddingRight =
            UDim.new(0, 5)
    end
end

--==============================================================
-- FLOATING BUTTON
--==============================================================

local FloatingToggle = Instance.new("TextButton")
FloatingToggle.Name = "FloatingToggle"
FloatingToggle.AnchorPoint = Vector2.new(1, 0)
FloatingToggle.Position =
    UDim2.new(1, -10, 0, 10)

FloatingToggle.Size =
    UDim2.fromOffset(42, 42)

FloatingToggle.BackgroundColor3 = BLACK
FloatingToggle.BorderSizePixel = 0
FloatingToggle.Text = "X"
FloatingToggle.TextColor3 = WHITE
FloatingToggle.TextSize = 18
FloatingToggle.Font = Enum.Font.GothamBold
FloatingToggle.AutoButtonColor = false
FloatingToggle.ZIndex = 100000
FloatingToggle.Parent = ScreenGui

local FloatingCorner = Instance.new("UICorner")
FloatingCorner.CornerRadius = UDim.new(0, 10)
FloatingCorner.Parent = FloatingToggle

local FloatingStroke = Instance.new("UIStroke")
FloatingStroke.Color = RED
FloatingStroke.Thickness = 1.5
FloatingStroke.Parent = FloatingToggle

--==============================================================
-- SECTION
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
    Section.Parent = CurrentTabContainer

    return Section
end

--==============================================================
-- ROW
--==============================================================

local function CreateRow(Height)
    local Row = Instance.new("Frame")

    Row.BackgroundColor3 = DARK
    Row.BorderSizePixel = 0

    Row.Size =
        UDim2.new(1, 0, 0, Height)

    Row.ZIndex = 12
    Row.Parent = CurrentTabContainer

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
-- CAMERA SECTION
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

local CameraOptionsCorner = Instance.new("UICorner")
CameraOptionsCorner.CornerRadius = UDim.new(0, 6)
CameraOptionsCorner.Parent = CameraOptions

local CameraOptionLayout = Instance.new("UIListLayout")
CameraOptionLayout.Parent = CameraOptions

local function CreateCameraOption(Text)
    local Option = Instance.new("TextButton")

    Option.Size =
        UDim2.new(1, 0, 0, 31)

    Option.BackgroundTransparency = 1
    Option.BorderSizePixel = 0
    Option.Text = Text
    Option.TextColor3 = WHITE
    Option.TextSize = IsMobile and 9 or 11
    Option.Font = Enum.Font.Gotham
    Option.AutoButtonColor = false
    Option.ZIndex = 51
    Option.Parent = CameraOptions

    Option.Activated:Connect(function()
        Config.CameraMode = Text
        CameraButton.Text = Text
        CameraOptions.Visible = false
    end)

    return Option
end

CreateCameraOption("First Person")
CreateCameraOption("Third Person")

CameraButton.Activated:Connect(function()
    CameraOptions.Visible =
        not CameraOptions.Visible
end)

--==============================================================
-- AIM SETTINGS
--==============================================================

CreateSection("AIM SETTINGS")

local function CreateInputRow(LabelText, DefaultValue)
    local Row = CreateRow(44)

    CreateLabel(Row, LabelText)

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
    Box.Text = tostring(DefaultValue)
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
-- 3P OFFSET
--==============================================================

local OffsetRow, OffsetBox =
    CreateInputRow(
        "3P Offset",
        Config.AimOffset
    )

OffsetBox.FocusLost:Connect(function()
    local Number = tonumber(OffsetBox.Text)

    if Number then
        Number =
            math.clamp(Number, -100, 100)

        Config.AimOffset = Number

        OffsetBox.Text =
            tostring(Number)
    else
        OffsetBox.Text =
            tostring(Config.AimOffset)
    end
end)

--==============================================================
-- SMOOTHING
--==============================================================

local SmoothRow, SmoothBox =
    CreateInputRow(
        "Smoothing",
        Config.Smoothing
    )

SmoothBox.FocusLost:Connect(function()
    local Number = tonumber(SmoothBox.Text)

    if Number then
        Number = math.max(0, Number)

        Config.Smoothing = Number

        SmoothBox.Text =
            tostring(Number)
    else
        SmoothBox.Text =
            tostring(Config.Smoothing)
    end
end)

--==============================================================
-- PREDICTION
--==============================================================

local PredictionRow, PredictionBox =
    CreateInputRow(
        "Prediction",
        Config.Prediction
    )

PredictionBox.FocusLost:Connect(function()
    local Number = tonumber(PredictionBox.Text)

    if Number then
        Number = math.max(0, Number)

        Config.Prediction = Number

        PredictionBox.Text =
            tostring(Number)
    else
        PredictionBox.Text =
            tostring(Config.Prediction)
    end
end)

--==============================================================
-- TOGGLE CREATOR
--==============================================================

local function CreateToggleRow(
    LabelText,
    GetValue,
    SetValue
)
    local Row = CreateRow(44)

    CreateLabel(Row, LabelText)

    local Button = Instance.new("TextButton")

    Button.AnchorPoint =
        Vector2.new(1, 0.5)

    Button.Position =
        UDim2.new(1, -8, 0.5, 0)

    Button.Size =
        UDim2.fromOffset(58, 28)

    Button.BorderSizePixel = 0
    Button.TextColor3 = WHITE
    Button.TextSize = IsMobile and 10 or 11
    Button.Font = Enum.Font.GothamBold
    Button.AutoButtonColor = false
    Button.ZIndex = 13
    Button.Parent = Row

    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 7)
    Corner.Parent = Button

    local function Update()
        if GetValue() then
            Button.Text = "ON"
            Button.BackgroundColor3 = RED
        else
            Button.Text = "OFF"
            Button.BackgroundColor3 = DARKER
        end
    end

    Button.Activated:Connect(function()
        SetValue(not GetValue())
        Update()
    end)

    Update()

    return Row, Button
end

--==============================================================
-- STICKY AIM
--==============================================================

local StickyRow, StickyButton =
    CreateToggleRow(
        "Sticky Aim",

        function()
            return Config.StickyAim
        end,

        function(Value)
            Config.StickyAim = Value
        end
    )

--==============================================================
-- AIMBOT WHITELIST SKIP
--==============================================================

local AimWhitelistRow, AimWhitelistButton =
    CreateToggleRow(
        "Whitelist Skip",

        function()
            return Config.AimbotWhitelistSkip
        end,

        function(Value)
            Config.AimbotWhitelistSkip = Value

            -- If currently locked onto someone who is
            -- now protected, immediately unlock.
            if Value and LockedTarget then
                if IsWhitelisted(LockedTarget) then
                    Locked = false
                    LockedTarget = nil
                end
            end
        end
    )

--==============================================================
-- LOCK SAFETY CHECKS
--==============================================================

local WallCheckRow, WallCheckButton =
    CreateToggleRow(
        "Wall Check",

        function()
            return Config.WallCheck
        end,

        function(Value)
            Config.WallCheck = Value

            -- Re-check the current target immediately when enabled.
            if Value and LockedTarget then
                -- Validation also checks the knocked/health condition.
                -- The render loop will perform the full check next frame.
            end
        end
    )

local KnockedRow, KnockedButton =
    CreateToggleRow(
        "Knocked Check",

        function()
            return Config.KnockedCheck
        end,

        function(Value)
            Config.KnockedCheck = Value

            -- If the current target is already below the unlock
            -- threshold, immediately release the lock when enabled.
            if Value and LockedTarget then
                local Character = LockedTarget.Character
                local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")

                if Humanoid and Humanoid.Health <= Config.UnlockHealth then
                    Locked = false
                    LockedTarget = nil
                end
            end
        end
    )

local HealthRow, HealthBox =
    CreateInputRow(
        "Unlock Health",
        Config.UnlockHealth
    )

HealthBox.FocusLost:Connect(function()
    local Number = tonumber(HealthBox.Text)

    if Number then
        Number = math.max(0, Number)
        Config.UnlockHealth = Number
        HealthBox.Text = tostring(Number)

        -- If the new threshold makes the current target invalid,
        -- unlock immediately instead of waiting for the next frame.
        if LockedTarget and Config.KnockedCheck then
            local Character = LockedTarget.Character
            local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")

            if Humanoid and Humanoid.Health <= Config.UnlockHealth then
                Locked = false
                LockedTarget = nil
            end
        end
    else
        HealthBox.Text = tostring(Config.UnlockHealth)
    end
end)

--==============================================================
-- CONTROLLER
--==============================================================

CreateSection("CONTROLLER")

local LockRow = CreateRow(44)

CreateLabel(
    LockRow,
    "Lock Button"
)

local LockButtonDisplay = Instance.new("TextLabel")

LockButtonDisplay.AnchorPoint =
    Vector2.new(1, 0.5)

LockButtonDisplay.Position =
    UDim2.new(1, -8, 0.5, 0)

LockButtonDisplay.Size =
    UDim2.new(0.37, 0, 0, 30)

LockButtonDisplay.BackgroundColor3 =
    DARKER

LockButtonDisplay.BorderSizePixel = 0
LockButtonDisplay.Text =
    Config.LockButton.Name

LockButtonDisplay.TextColor3 = WHITE
LockButtonDisplay.TextSize = IsMobile and 8 or 10
LockButtonDisplay.Font =
    Enum.Font.GothamBold

LockButtonDisplay.ZIndex = 13
LockButtonDisplay.Parent = LockRow

local LockCorner = Instance.new("UICorner")
LockCorner.CornerRadius = UDim.new(0, 6)
LockCorner.Parent = LockButtonDisplay

local RebindRow = CreateRow(44)

local RebindButton = Instance.new("TextButton")

RebindButton.Position =
    UDim2.new(0, 8, 0, 7)

RebindButton.Size =
    UDim2.new(1, -16, 1, -14)

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
-- VISUALS
--==============================================================

SetActiveTab("VISUALS")
CreateSection("VISUALS")

local ESPEnabledRow, ESPEnabledButton =
    CreateToggleRow(
        "Enabled",

        function()
            return Config.ESPEnabled
        end,

        function(Value)
            Config.ESPEnabled = Value
        end
    )

local ESPNameRow, ESPNameButton =
    CreateToggleRow(
        "Show Name",

        function()
            return Config.ESPShowName
        end,

        function(Value)
            Config.ESPShowName = Value
        end
    )

local ESPOutlineRow, ESPOutlineButton =
    CreateToggleRow(
        "Show Outline",

        function()
            return Config.ESPShowOutline
        end,

        function(Value)
            Config.ESPShowOutline = Value
        end
    )

local ESPWhitelistRow, ESPWhitelistButton =
    CreateToggleRow(
        "Whitelist Check",

        function()
            return Config.ESPWhitelistCheck
        end,

        function(Value)
            Config.ESPWhitelistCheck = Value
        end
    )

--==============================================================
-- WHITELIST
--==============================================================

SetActiveTab("WHITELIST")
CreateSection("WHITELIST")

local WhitelistInfoRow = CreateRow(45)

local WhitelistInfo = Instance.new("TextLabel")

WhitelistInfo.BackgroundTransparency = 1
WhitelistInfo.Position =
    UDim2.new(0, 10, 0, 4)

WhitelistInfo.Size =
    UDim2.new(1, -20, 1, -8)

WhitelistInfo.Font =
    Enum.Font.Gotham

WhitelistInfo.Text =
    "Tap a player to whitelist / unwhitelist them.\nRED = WHITELISTED"

WhitelistInfo.TextColor3 = GRAY
WhitelistInfo.TextSize = IsMobile and 9 or 10
WhitelistInfo.TextWrapped = true
WhitelistInfo.TextXAlignment =
    Enum.TextXAlignment.Left

WhitelistInfo.TextYAlignment =
    Enum.TextYAlignment.Center

WhitelistInfo.ZIndex = 13
WhitelistInfo.Parent = WhitelistInfoRow

local WhitelistContainer = Instance.new("Frame")

WhitelistContainer.Name =
    "WhitelistContainer"

WhitelistContainer.BackgroundTransparency = 1
WhitelistContainer.Size =
    UDim2.new(1, 0, 0, 10)

WhitelistContainer.ZIndex = 12
WhitelistContainer.Parent = CurrentTabContainer

local WhitelistLayout = Instance.new("UIListLayout")
WhitelistLayout.Padding =
    UDim.new(0, 6)

WhitelistLayout.SortOrder =
    Enum.SortOrder.LayoutOrder

WhitelistLayout.Parent =
    WhitelistContainer

--==============================================================
-- STATUS
--==============================================================

SetActiveTab("AIM")
CreateSection("STATUS")

local StatusRow = CreateRow(55)

local StatusLabel = Instance.new("TextLabel")

StatusLabel.BackgroundTransparency = 1
StatusLabel.Position =
    UDim2.new(0, 12, 0, 5)

StatusLabel.Size =
    UDim2.new(1, -24, 0, 20)

StatusLabel.Font =
    Enum.Font.GothamBold

StatusLabel.Text = "UNLOCKED"
StatusLabel.TextColor3 = GRAY
StatusLabel.TextSize = IsMobile and 12 or 14
StatusLabel.TextXAlignment =
    Enum.TextXAlignment.Left

StatusLabel.ZIndex = 13
StatusLabel.Parent = StatusRow

local TargetLabel = Instance.new("TextLabel")

TargetLabel.BackgroundTransparency = 1
TargetLabel.Position =
    UDim2.new(0, 12, 0, 27)

TargetLabel.Size =
    UDim2.new(1, -24, 0, 18)

TargetLabel.Font =
    Enum.Font.Gotham

TargetLabel.Text =
    "Target: None"

TargetLabel.TextColor3 = GRAY
TargetLabel.TextSize = IsMobile and 9 or 10
TargetLabel.TextXAlignment =
    Enum.TextXAlignment.Left

TargetLabel.ZIndex = 13
TargetLabel.Parent = StatusRow

--==============================================================
-- WHITELIST UI
--==============================================================

local function ClearWhitelistUI()
    for _, Child in ipairs(
        WhitelistContainer:GetChildren()
    ) do
        if Child:IsA("Frame") then
            Child:Destroy()
        end
    end
end

local function CreateWhitelistEntry(Player)
    local Entry = Instance.new("TextButton")

    Entry.Name =
        "Whitelist_" .. Player.UserId

    Entry.Size =
        UDim2.new(1, 0, 0, 40)

    Entry.BackgroundColor3 =
        IsWhitelisted(Player)
        and RED
        or DARK

    Entry.BorderSizePixel = 0

    Entry.Text =
        Player.DisplayName ..
        "  @" ..
        Player.Name

    Entry.TextColor3 = WHITE

    Entry.TextSize =
        IsMobile and 9 or 11

    Entry.Font =
        Enum.Font.GothamMedium

    Entry.TextXAlignment =
        Enum.TextXAlignment.Left

    Entry.AutoButtonColor = false
    Entry.ZIndex = 13
    Entry.Parent = WhitelistContainer

    local Padding = Instance.new("UIPadding")
    Padding.PaddingLeft =
        UDim.new(0, 12)
    Padding.Parent = Entry

    local Corner = Instance.new("UICorner")
    Corner.CornerRadius =
        UDim.new(0, 8)
    Corner.Parent = Entry

    local function Refresh()
        if IsWhitelisted(Player) then
            Entry.BackgroundColor3 = RED
        else
            Entry.BackgroundColor3 = DARK
        end
    end

    Entry.Activated:Connect(function()
        SetWhitelist(
            Player,
            not IsWhitelisted(Player)
        )

        Refresh()

        -- If aimbot whitelist skip is active and
        -- this player is currently targeted, unlock.
        if Locked
            and LockedTarget == Player
            and Config.AimbotWhitelistSkip
            and IsWhitelisted(Player) then

            Locked = false
            LockedTarget = nil
        end
    end)

    return Entry
end

local function RefreshWhitelistUI()
    ClearWhitelistUI()

    local PlayerList = Players:GetPlayers()

    table.sort(
        PlayerList,
        function(A, B)
            return A.Name:lower() <
                B.Name:lower()
        end
    )

    for _, Player in ipairs(PlayerList) do
        if Player ~= LocalPlayer then
            CreateWhitelistEntry(Player)
        end
    end

    task.defer(function()
        WhitelistContainer.Size =
            UDim2.new(
                1,
                0,
                0,
                WhitelistLayout.AbsoluteContentSize.Y
            )
    end)
end

--==============================================================
-- ESP
--==============================================================

local function DestroyESP(Player)
    local Data = ESPObjects[Player]

    if not Data then
        return
    end

    if Data.Highlight then
        pcall(function()
            Data.Highlight:Destroy()
        end)
    end

    if Data.NameGui then
        pcall(function()
            Data.NameGui:Destroy()
        end)
    end

    ESPObjects[Player] = nil
end

local function CreateESP(Player)
    if Player == LocalPlayer then
        return
    end

    DestroyESP(Player)

    local Character = Player.Character

    if not Character then
        return
    end

    local Data = {}

    --==========================================================
    -- OUTLINE
    --==========================================================

    if Config.ESPShowOutline then
        local Highlight =
            Instance.new("Highlight")

        Highlight.Name =
            "XenonESP"

        Highlight.Adornee =
            Character

        Highlight.FillTransparency = 1

        Highlight.OutlineTransparency = 0

        Highlight.OutlineColor = WHITE

        Highlight.DepthMode =
            Enum.HighlightDepthMode.AlwaysOnTop

        Highlight.Parent = Character

        Data.Highlight = Highlight
    end

    --==========================================================
    -- NAME
    --==========================================================

    if Config.ESPShowName then
        local Head =
            Character:FindFirstChild("Head")

        local Root =
            Character:FindFirstChild(
                "HumanoidRootPart"
            )

        local Adornee =
            Head or Root

        if Adornee then
            local Billboard =
                Instance.new("BillboardGui")

            Billboard.Name =
                "XenonName"

            Billboard.Adornee =
                Adornee

            Billboard.Size =
                UDim2.fromOffset(150, 30)

            Billboard.StudsOffset =
                Vector3.new(0, 2.7, 0)

            Billboard.AlwaysOnTop = true

            Billboard.MaxDistance = 1000

            Billboard.Parent = Adornee

            local NameLabel =
                Instance.new("TextLabel")

            NameLabel.BackgroundTransparency = 1
            NameLabel.Size =
                UDim2.fromScale(1, 1)

            NameLabel.Font =
                Enum.Font.GothamBold

            NameLabel.Text =
                Player.DisplayName ..
                "  @" ..
                Player.Name

            NameLabel.TextColor3 =
                WHITE

            NameLabel.TextStrokeTransparency =
                0.3

            NameLabel.TextSize = 12

            NameLabel.Parent =
                Billboard

            Data.NameGui = Billboard
        end
    end

    ESPObjects[Player] = Data
end

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

local function UpdateESPPlayer(Player)
    if Player == LocalPlayer then
        return
    end

    if ShouldESP(Player) then
        CreateESP(Player)
    else
        DestroyESP(Player)
    end
end

local function UpdateAllESP()
    for _, Player in ipairs(
        Players:GetPlayers()
    ) do
        UpdateESPPlayer(Player)
    end
end

-- Rebuild ESP when settings change.

ESPEnabledButton.Activated:Connect(function()
    task.defer(UpdateAllESP)
end)

ESPNameButton.Activated:Connect(function()
    task.defer(UpdateAllESP)
end)

ESPOutlineButton.Activated:Connect(function()
    task.defer(UpdateAllESP)
end)

ESPWhitelistButton.Activated:Connect(function()
    task.defer(UpdateAllESP)
end)

--==============================================================
-- PLAYER EVENTS
--==============================================================

Connect(
    Players.PlayerAdded,
    function(Player)
        task.defer(function()
            RefreshWhitelistUI()

            if Player.Character then
                UpdateESPPlayer(Player)
            end
        end)

        Player.CharacterAdded:Connect(function()
            task.wait(0.5)

            UpdateESPPlayer(Player)
        end)
    end
)

Connect(
    Players.PlayerRemoving,
    function(Player)
        if Player == LockedTarget then
            Locked = false
            LockedTarget = nil
        end

        DestroyESP(Player)

        task.defer(function()
            RefreshWhitelistUI()
        end)
    end
)

for _, Player in ipairs(
    Players:GetPlayers()
) do
    if Player ~= LocalPlayer then
        Connect(
            Player.CharacterAdded,
            function()
                task.wait(0.5)

                UpdateESPPlayer(Player)
            end
        )
    end
end

--==============================================================
-- TARGET DATA
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
-- LOCK SAFETY CHECKS
--==============================================================

local function IsTargetBelowUnlockHealth(Player)
    if not Player then
        return true
    end

    local Character = Player.Character
    if not Character then
        return true
    end

    local Humanoid = Character:FindFirstChildOfClass("Humanoid")
    if not Humanoid then
        return true
    end

    return Humanoid.Health <= Config.UnlockHealth
end

local function IsHeadVisible(Player)
    if not Player then
        return false
    end

    local Character = Player.Character
    if not Character then
        return false
    end

    local Head = Character:FindFirstChild("Head")
    local CurrentCamera = workspace.CurrentCamera

    if not Head or not CurrentCamera then
        return false
    end

    local Origin = CurrentCamera.CFrame.Position
    local Direction = Head.Position - Origin

    if Direction.Magnitude <= 0.01 then
        return true
    end

    local Params = RaycastParams.new()
    Params.FilterType = Enum.RaycastFilterType.Exclude
    Params.FilterDescendantsInstances = {
        LocalPlayer.Character
    }
    Params.IgnoreWater = true

    local Result = workspace:Raycast(
        Origin,
        Direction,
        Params
    )

    if not Result then
        return true
    end

    -- Any hit belonging to the target means there is no wall between
    -- the camera and the target's head. Otherwise something is blocking it.
    return Result.Instance:IsDescendantOf(Character)
end

local function IsTargetLockable(Player)
    if not Player then
        return false
    end

    if Config.KnockedCheck and IsTargetBelowUnlockHealth(Player) then
        return false
    end

    if Config.WallCheck and not IsHeadVisible(Player) then
        return false
    end

    return true
end


--==============================================================
-- CAMERA CENTER TARGET
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
    local BestDistance = math.huge

    for _, Player in ipairs(
        Players:GetPlayers()
    ) do

        if
            not (
                Config.AimbotWhitelistSkip
                and IsWhitelisted(Player)
            )
        then

            local Character,
                Humanoid,
                Root =
                GetCharacterData(Player)

            if Character
                and Humanoid
                and Root
                and IsTargetLockable(Player) then

                local WorldDistance =
                    (
                        Root.Position -
                        CurrentCamera.CFrame.Position
                    ).Magnitude

                if WorldDistance <=
                    Config.MaxTargetDistance then

                    local ScreenPosition,
                        OnScreen =
                        CurrentCamera:WorldToViewportPoint(
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
-- PHYSICAL DISTANCE TARGET
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

        if
            not (
                Config.AimbotWhitelistSkip
                and IsWhitelisted(Player)
            )
        then

            local Character,
                Humanoid,
                Root =
                GetCharacterData(Player)

            if Character
                and Humanoid
                and Root
                and IsTargetLockable(Player) then

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
        Velocity * Config.Prediction
end

--==============================================================
-- THIRD PERSON ADAPTIVE OFFSET
--==============================================================

local function GetAdaptiveOffset(TargetRoot)
    if not TargetRoot then
        return Config.AimOffset
    end

    local CurrentCamera = workspace.CurrentCamera
    if not CurrentCamera then
        return Config.AimOffset
    end

    local Character = TargetRoot.Parent
    if not Character then
        return Config.AimOffset
    end

    -- The calibration point is the distance where AimOffset is exact.
    -- 23.5 at 40 studs therefore becomes the baseline.
    -- This is intentionally calculated from distance only: no expensive
    -- per-frame screen feedback and no correction fighting the user value.
    local Head = Character:FindFirstChild("Head")
    local Alpha = math.clamp(Config.ThirdPersonAnchor, 0, 1)

    local AnchorPosition = TargetRoot.Position
    if Head then
        AnchorPosition = TargetRoot.Position:Lerp(Head.Position, Alpha)
    end

    local Distance =
        (AnchorPosition - CurrentCamera.CFrame.Position).Magnitude

    local CalibrationDistance =
        math.max(Config.ReferenceDistance, 1)

    local DistanceScale =
        Distance / CalibrationDistance

    -- Scale the offset so the same camera-angle relationship is retained
    -- when the target gets closer or farther away.
    local FinalOffset =
        Config.AimOffset * DistanceScale

    return math.clamp(
        FinalOffset,
        Config.ThirdPersonMinOffset,
        Config.ThirdPersonMaxOffset
    )
end

--==============================================================
-- AIM POSITION
--==============================================================

local function GetAimPosition(Player)
    local Character,
        Humanoid,
        Root =
        GetCharacterData(Player)

    if not Character
        or not Humanoid
        or not Root then

        return nil
    end

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

    -- In third person, predict from the same upper-body anchor
    -- used by the adaptive correction. Keeping both calculations
    -- on the same point prevents the dot from separating from the
    -- target when distance or movement changes.
    local Head =
        Character:FindFirstChild("Head")

    local AnchorPosition
    local AnchorVelocity

    if Head then
        local AnchorAlpha =
            math.clamp(
                Config.ThirdPersonAnchor,
                0,
                1
            )

        AnchorPosition =
            Root.Position:Lerp(
                Head.Position,
                AnchorAlpha
            )

        AnchorVelocity =
            Root.AssemblyLinearVelocity:Lerp(
                Head.AssemblyLinearVelocity,
                AnchorAlpha
            )
    else
        AnchorPosition = Root.Position
        AnchorVelocity = Root.AssemblyLinearVelocity
    end

    local Predicted =
        GetPredictedPosition(
            AnchorPosition,
            AnchorVelocity
        )

    local Offset =
        GetAdaptiveOffset(Root)

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
        and IsWhitelisted(Target) then

        return
    end

    if not IsTargetLockable(Target) then
        UpdateStatus()
        return
    end

    LockedTarget =
        Target

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

    if Config.AimbotWhitelistSkip
        and IsWhitelisted(Player) then

        return false
    end

    local Character,
        Humanoid,
        Root =
        GetCharacterData(Player)

    if Character == nil
        or Humanoid == nil
        or Root == nil then

        return false
    end

    -- WallCheck is deliberately evaluated every render frame so a target
    -- can immediately unlock when they move behind cover.
    if Config.KnockedCheck
        and IsTargetBelowUnlockHealth(Player) then

        return false
    end

    if Config.WallCheck
        and not IsHeadVisible(Player) then

        return false
    end

    return true
end

--==============================================================
-- CONTROLLER BUTTONS
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

                LockButtonDisplay.Text =
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
-- REBIND
--==============================================================

RebindButton.Activated:Connect(function()
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
end)

--==============================================================
-- CLOSE
--==============================================================

CloseButton.Activated:Connect(function()
    MainVisible = false

    MainFrame.Visible =
        false

    FloatingToggle.Text =
        "+"
end)

--==============================================================
-- FLOATING TOGGLE
--==============================================================

FloatingToggle.Activated:Connect(function()
    MainVisible =
        not MainVisible

    MainFrame.Visible =
        MainVisible

    if MainVisible then
        FloatingToggle.Text =
            "X"
    else
        FloatingToggle.Text =
            "+"
    end
end)

FloatingToggle.MouseEnter:Connect(function()
    FloatingToggle.BackgroundColor3 =
        LIGHT_DARK
end)

FloatingToggle.MouseLeave:Connect(function()
    FloatingToggle.BackgroundColor3 =
        BLACK
end)

--==============================================================
-- LOCAL CHARACTER
--==============================================================

Connect(
    LocalPlayer.CharacterAdded,
    function()
        Unlock()
    end
)

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

TopBar.InputBegan:Connect(function(Input)

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
end)

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
-- RESPONSIVE CAMERA
--==============================================================

UpdateResponsiveState()

Camera:GetPropertyChangedSignal(
    "ViewportSize"
):Connect(
    UpdateResponsiveState
)

--==============================================================
-- CANVAS SIZE
--==============================================================

AimLayout:GetPropertyChangedSignal(
    "AbsoluteContentSize"
):Connect(function()
    UpdateTabCanvas(Scroll, AimLayout)
end)

VisualsLayout:GetPropertyChangedSignal(
    "AbsoluteContentSize"
):Connect(function()
    UpdateTabCanvas(VisualsTab, VisualsLayout)
end)

WhitelistLayout:GetPropertyChangedSignal(
    "AbsoluteContentSize"
):Connect(function()
    UpdateTabCanvas(WhitelistTab, WhitelistLayout)
end)

WhitelistLayout:GetPropertyChangedSignal(
    "AbsoluteContentSize"
):Connect(
    function()

        WhitelistContainer.Size =
            UDim2.new(
                1,
                0,
                0,
                WhitelistLayout.AbsoluteContentSize.Y
            )
    end
)

--==============================================================
-- INITIAL WHITELIST UI
--==============================================================

RefreshWhitelistUI()

--==============================================================
-- INITIAL ESP
--==============================================================

task.defer(function()
    UpdateAllESP()
end)

--==============================================================
-- CLEANUP
--==============================================================

_G.XenonCleanup = function()

    pcall(function()
        RunService:UnbindFromRenderStep(
            "XenonCameraLock"
        )
    end)

    for Player in pairs(ESPObjects) do
        DestroyESP(Player)
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
-- INITIAL STATUS
--==============================================================

UpdateStatus()

print("======================================")
print("XENON LOADED")
print("3P Offset:", Config.AimOffset)
print("Lock Button:", Config.LockButton.Name)
print("Sticky Aim:", Config.StickyAim)
print("Aimbot Whitelist Skip:",
    Config.AimbotWhitelistSkip)
print("ESP:", Config.ESPEnabled)
print("Whitelist entries:",
    tostring(#Players:GetPlayers() - 1))
print("======================================")
