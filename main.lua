--//========================================================
--// XENON CONTROLLER CAMERA LOCK
--// Full Version
--//========================================================

if _G.XenonCleanup then
    pcall(_G.XenonCleanup)
end

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Camera = workspace.CurrentCamera

--//========================================================
--// CONFIG
--//========================================================

local Config = {
    LockButton = Enum.KeyCode.ButtonY,

    CameraMode = "Third Person",

    AimOffset = 23.5,
    ReferenceDistance = 100,

    Smoothing = 0,

    -- X and Y are now separate
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

--//========================================================
--// STATE
--//========================================================

local Locked = false
local LockedTarget = nil
local WaitingForBind = false
local CurrentTab = "AIM"

local Connections = {}
local ESPObjects = {}
local ESPCharacterConnections = {}

local Whitelist = {}

local FileName = "XenonWhitelist.json"

--//========================================================
--// CONNECTION MANAGEMENT
--//========================================================

local function AddConnection(Connection)
    table.insert(Connections, Connection)
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

--//========================================================
--// WHITELIST SAVE / LOAD
--//========================================================

local function SaveWhitelist()
    if not writefile or not isfile then
        return
    end

    local IDs = {}

    for UserId, Enabled in pairs(Whitelist) do
        if Enabled then
            table.insert(IDs, tonumber(UserId))
        end
    end

    pcall(function()
        writefile(FileName, HttpService:JSONEncode(IDs))
    end)
end

local function LoadWhitelist()
    if not readfile or not isfile then
        return
    end

    if not isfile(FileName) then
        return
    end

    local Success, Data = pcall(function()
        return HttpService:JSONDecode(readfile(FileName))
    end)

    if Success and type(Data) == "table" then
        for _, UserId in ipairs(Data) do
            local NumberId = tonumber(UserId)

            if NumberId then
                Whitelist[NumberId] = true
            end
        end
    end
end

LoadWhitelist()

local function IsWhitelisted(Player)
    return Player and Whitelist[Player.UserId] == true
end

--//========================================================
--// GUI
--//========================================================

local ExistingGUI = PlayerGui:FindFirstChild("Xenon")

if ExistingGUI then
    ExistingGUI:Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "Xenon"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = PlayerGui

local Main = Instance.new("Frame")
Main.Name = "Main"
Main.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
Main.BorderSizePixel = 0
Main.AnchorPoint = Vector2.new(0.5, 0.5)
Main.Position = UDim2.fromScale(0.5, 0.5)
Main.Size = UDim2.fromOffset(390, 570)
Main.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 12)
MainCorner.Parent = Main

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(55, 55, 60)
MainStroke.Thickness = 1
MainStroke.Parent = Main

--//========================================================
--// TOP BAR
--//========================================================

local TopBar = Instance.new("Frame")
TopBar.Name = "TopBar"
TopBar.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
TopBar.BorderSizePixel = 0
TopBar.Size = UDim2.new(1, 0, 0, 48)
TopBar.Parent = Main

local TopCorner = Instance.new("UICorner")
TopCorner.CornerRadius = UDim.new(0, 12)
TopCorner.Parent = TopBar

local Title = Instance.new("TextLabel")
Title.BackgroundTransparency = 1
Title.Position = UDim2.fromOffset(14, 0)
Title.Size = UDim2.new(0, 130, 1, 0)
Title.Font = Enum.Font.GothamBold
Title.Text = "XENON"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 17
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = TopBar

local Close = Instance.new("TextButton")
Close.BackgroundTransparency = 1
Close.Position = UDim2.new(1, -45, 0, 0)
Close.Size = UDim2.fromOffset(45, 45)
Close.Font = Enum.Font.GothamBold
Close.Text = "×"
Close.TextColor3 = Color3.fromRGB(255, 70, 70)
Close.TextSize = 28
Close.AutoButtonColor = false
Close.Parent = TopBar

--//========================================================
--// FLOATING OPEN BUTTON
--//========================================================

local FloatingButton = Instance.new("TextButton")
FloatingButton.Name = "FloatingButton"
FloatingButton.AnchorPoint = Vector2.new(1, 0)
FloatingButton.Position = UDim2.new(1, -15, 0, 15)
FloatingButton.Size = UDim2.fromOffset(42, 42)
FloatingButton.BackgroundColor3 = Color3.fromRGB(18, 18, 21)
FloatingButton.BorderSizePixel = 0
FloatingButton.Font = Enum.Font.GothamBold
FloatingButton.Text = "X"
FloatingButton.TextColor3 = Color3.fromRGB(255, 70, 70)
FloatingButton.TextSize = 17
FloatingButton.Visible = false
FloatingButton.Parent = ScreenGui

local FloatCorner = Instance.new("UICorner")
FloatCorner.CornerRadius = UDim.new(0, 10)
FloatCorner.Parent = FloatingButton

local FloatStroke = Instance.new("UIStroke")
FloatStroke.Color = Color3.fromRGB(55, 55, 60)
FloatStroke.Parent = FloatingButton

--//========================================================
--// TAB BAR
--//========================================================

local TabBar = Instance.new("Frame")
TabBar.Name = "TabBar"
TabBar.BackgroundTransparency = 1
TabBar.Position = UDim2.fromOffset(10, 54)
TabBar.Size = UDim2.new(1, -20, 0, 38)
TabBar.Parent = Main

local TabLayout = Instance.new("UIListLayout")
TabLayout.FillDirection = Enum.FillDirection.Horizontal
TabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
TabLayout.VerticalAlignment = Enum.VerticalAlignment.Center
TabLayout.Padding = UDim.new(0, 6)
TabLayout.Parent = TabBar

local Pages = Instance.new("Frame")
Pages.Name = "Pages"
Pages.BackgroundTransparency = 1
Pages.Position = UDim2.fromOffset(10, 98)
Pages.Size = UDim2.new(1, -20, 1, -108)
Pages.Parent = Main

local function CreateTabButton(Name)
    local Button = Instance.new("TextButton")
    Button.Name = Name .. "Tab"
    Button.BackgroundColor3 = Color3.fromRGB(25, 25, 29)
    Button.BorderSizePixel = 0
    Button.Size = UDim2.fromOffset(105, 34)
    Button.Font = Enum.Font.GothamSemibold
    Button.Text = Name
    Button.TextColor3 = Color3.fromRGB(150, 150, 155)
    Button.TextSize = 12
    Button.AutoButtonColor = false
    Button.Parent = TabBar

    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 7)
    Corner.Parent = Button

    return Button
end

local AimTab = CreateTabButton("AIM")
local ESPTab = CreateTabButton("ESP")
local WhitelistTab = CreateTabButton("WHITELIST")

--//========================================================
--// PAGE CREATION
--//========================================================

local AimPage = Instance.new("ScrollingFrame")
AimPage.Name = "AIM"
AimPage.BackgroundTransparency = 1
AimPage.BorderSizePixel = 0
AimPage.Size = UDim2.fromScale(1, 1)
AimPage.CanvasSize = UDim2.new()
AimPage.ScrollBarThickness = 3
AimPage.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 85)
AimPage.Parent = Pages

local AimLayout = Instance.new("UIListLayout")
AimLayout.Padding = UDim.new(0, 8)
AimLayout.Parent = AimPage

local ESPPage = Instance.new("ScrollingFrame")
ESPPage.Name = "ESP"
ESPPage.BackgroundTransparency = 1
ESPPage.BorderSizePixel = 0
ESPPage.Size = UDim2.fromScale(1, 1)
ESPPage.CanvasSize = UDim2.new()
ESPPage.ScrollBarThickness = 3
ESPPage.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 85)
ESPPage.Visible = false
ESPPage.Parent = Pages

local ESPLayout = Instance.new("UIListLayout")
ESPLayout.Padding = UDim.new(0, 8)
ESPLayout.Parent = ESPPage

local WhitelistPage = Instance.new("ScrollingFrame")
WhitelistPage.Name = "WHITELIST"
WhitelistPage.BackgroundTransparency = 1
WhitelistPage.BorderSizePixel = 0
WhitelistPage.Size = UDim2.fromScale(1, 1)
WhitelistPage.CanvasSize = UDim2.new()
WhitelistPage.ScrollBarThickness = 3
WhitelistPage.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 85)
WhitelistPage.Visible = false
WhitelistPage.Parent = Pages

local WhitelistLayout = Instance.new("UIListLayout")
WhitelistLayout.Padding = UDim.new(0, 5)
WhitelistLayout.Parent = WhitelistPage

--//========================================================
--// TAB SWITCHING
--//========================================================

local function UpdateTabVisuals()
    local Tabs = {
        {Button = AimTab, Name = "AIM"},
        {Button = ESPTab, Name = "ESP"},
        {Button = WhitelistTab, Name = "WHITELIST"},
    }

    for _, Info in ipairs(Tabs) do
        if CurrentTab == Info.Name then
            Info.Button.BackgroundColor3 = Color3.fromRGB(190, 35, 45)
            Info.Button.TextColor3 = Color3.fromRGB(255, 255, 255)
        else
            Info.Button.BackgroundColor3 = Color3.fromRGB(25, 25, 29)
            Info.Button.TextColor3 = Color3.fromRGB(150, 150, 155)
        end
    end
end

local function SwitchTab(Name)
    CurrentTab = Name

    AimPage.Visible = Name == "AIM"
    ESPPage.Visible = Name == "ESP"
    WhitelistPage.Visible = Name == "WHITELIST"

    UpdateTabVisuals()
end

AddConnection(AimTab.Activated:Connect(function()
    SwitchTab("AIM")
end))

AddConnection(ESPTab.Activated:Connect(function()
    SwitchTab("ESP")
end))

AddConnection(WhitelistTab.Activated:Connect(function()
    SwitchTab("WHITELIST")
end))

UpdateTabVisuals()

--//========================================================
--// UI HELPERS
--//========================================================

local function CreateSection(Page, Text)
    local Label = Instance.new("TextLabel")
    Label.BackgroundTransparency = 1
    Label.Size = UDim2.new(1, -5, 0, 28)
    Label.Font = Enum.Font.GothamBold
    Label.Text = Text
    Label.TextColor3 = Color3.fromRGB(255, 65, 75)
    Label.TextSize = 13
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = Page

    return Label
end

local function CreateRow(Page, Height)
    local Frame = Instance.new("Frame")
    Frame.BackgroundColor3 = Color3.fromRGB(23, 23, 27)
    Frame.BorderSizePixel = 0
    Frame.Size = UDim2.new(1, -5, 0, Height or 48)
    Frame.Parent = Page

    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 8)
    Corner.Parent = Frame

    return Frame
end

local function CreateLabel(Parent, Text)
    local Label = Instance.new("TextLabel")
    Label.BackgroundTransparency = 1
    Label.Position = UDim2.fromOffset(12, 0)
    Label.Size = UDim2.new(0.58, 0, 1, 0)
    Label.Font = Enum.Font.GothamMedium
    Label.Text = Text
    Label.TextColor3 = Color3.fromRGB(225, 225, 230)
    Label.TextSize = 12
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = Parent

    return Label
end

local function CreateTextBox(Page, Text, Value)
    local Row = CreateRow(Page, 52)

    CreateLabel(Row, Text)

    local Box = Instance.new("TextBox")
    Box.AnchorPoint = Vector2.new(1, 0.5)
    Box.Position = UDim2.new(1, -10, 0.5, 0)
    Box.Size = UDim2.fromOffset(105, 32)
    Box.BackgroundColor3 = Color3.fromRGB(13, 13, 16)
    Box.BorderSizePixel = 0
    Box.ClearTextOnFocus = false
    Box.Font = Enum.Font.Gotham
    Box.Text = tostring(Value)
    Box.TextColor3 = Color3.fromRGB(255, 255, 255)
    Box.TextSize = 12
    Box.Parent = Row

    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 6)
    Corner.Parent = Box

    local Stroke = Instance.new("UIStroke")
    Stroke.Color = Color3.fromRGB(55, 55, 60)
    Stroke.Parent = Box

    return Box
end

local function CreateToggle(Page, Text, Default, Callback)
    local Row = CreateRow(Page, 50)

    CreateLabel(Row, Text)

    local Button = Instance.new("TextButton")
    Button.AnchorPoint = Vector2.new(1, 0.5)
    Button.Position = UDim2.new(1, -10, 0.5, 0)
    Button.Size = UDim2.fromOffset(64, 30)
    Button.BorderSizePixel = 0
    Button.Font = Enum.Font.GothamBold
    Button.TextSize = 11
    Button.AutoButtonColor = false
    Button.Parent = Row

    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(1, 0)
    Corner.Parent = Button

    local State = Default

    local function Refresh()
        if State then
            Button.BackgroundColor3 = Color3.fromRGB(190, 35, 45)
            Button.TextColor3 = Color3.fromRGB(255, 255, 255)
            Button.Text = "ON"
        else
            Button.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
            Button.TextColor3 = Color3.fromRGB(170, 170, 175)
            Button.Text = "OFF"
        end
    end

    AddConnection(Button.Activated:Connect(function()
        State = not State
        Callback(State)
        Refresh()
    end))

    Refresh()

    return Button, function(NewState)
        State = NewState
        Refresh()
    end
end

local function CreateInfoRow(Page, Text, Value)
    local Row = CreateRow(Page, 48)

    CreateLabel(Row, Text)

    local ValueLabel = Instance.new("TextLabel")
    ValueLabel.AnchorPoint = Vector2.new(1, 0.5)
    ValueLabel.Position = UDim2.new(1, -12, 0.5, 0)
    ValueLabel.Size = UDim2.fromOffset(150, 30)
    ValueLabel.BackgroundTransparency = 1
    ValueLabel.Font = Enum.Font.GothamSemibold
    ValueLabel.Text = Value
    ValueLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    ValueLabel.TextSize = 11
    ValueLabel.TextXAlignment = Enum.TextXAlignment.Right
    ValueLabel.Parent = Row

    return ValueLabel
end

--//========================================================
--// AIM PAGE
--//========================================================

CreateSection(AimPage, "CAMERA")

local CameraModeRow = CreateRow(AimPage, 52)
CreateLabel(CameraModeRow, "Camera Mode")

local CameraModeButton = Instance.new("TextButton")
CameraModeButton.AnchorPoint = Vector2.new(1, 0.5)
CameraModeButton.Position = UDim2.new(1, -10, 0.5, 0)
CameraModeButton.Size = UDim2.fromOffset(120, 32)
CameraModeButton.BackgroundColor3 = Color3.fromRGB(13, 13, 16)
CameraModeButton.BorderSizePixel = 0
CameraModeButton.Font = Enum.Font.GothamMedium
CameraModeButton.Text = Config.CameraMode
CameraModeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
CameraModeButton.TextSize = 11
CameraModeButton.Parent = CameraModeRow

local CameraModeCorner = Instance.new("UICorner")
CameraModeCorner.CornerRadius = UDim.new(0, 6)
CameraModeCorner.Parent = CameraModeButton

AddConnection(CameraModeButton.Activated:Connect(function()
    if Config.CameraMode == "Third Person" then
        Config.CameraMode = "First Person"
    else
        Config.CameraMode = "Third Person"
    end

    CameraModeButton.Text = Config.CameraMode
end))

local AimOffsetBox = CreateTextBox(
    AimPage,
    "3P Adaptive Offset",
    Config.AimOffset
)

local SmoothingBox = CreateTextBox(
    AimPage,
    "Smoothing",
    Config.Smoothing
)

--// IMPORTANT:
--// Separate X and Y prediction controls

local PredictionXBox = CreateTextBox(
    AimPage,
    "Prediction X",
    Config.PredictionX
)

local PredictionYBox = CreateTextBox(
    AimPage,
    "Prediction Y",
    Config.PredictionY
)

CreateSection(AimPage, "TARGETING")

CreateToggle(
    AimPage,
    "Sticky Aim",
    Config.StickyAim,
    function(State)
        Config.StickyAim = State
    end
)

CreateToggle(
    AimPage,
    "Whitelist Skip",
    Config.AimbotWhitelistSkip,
    function(State)
        Config.AimbotWhitelistSkip = State

        if LockedTarget and State and IsWhitelisted(LockedTarget) then
            Locked = false
            LockedTarget = nil
        end
    end
)

CreateToggle(
    AimPage,
    "Above Target Correction",
    Config.AboveTargetCorrection,
    function(State)
        Config.AboveTargetCorrection = State
    end
)

local AboveStrengthBox = CreateTextBox(
    AimPage,
    "Vertical Correction",
    Config.AboveTargetStrength
)

local AboveMaxBox = CreateTextBox(
    AimPage,
    "Max Correction",
    Config.AboveTargetMaxCorrection
)

CreateSection(AimPage, "CONTROLLER")

local LockButtonLabel = CreateInfoRow(
    AimPage,
    "Lock Button",
    Config.LockButton.Name
)

local SetLockButton = Instance.new("TextButton")
SetLockButton.BackgroundColor3 = Color3.fromRGB(190, 35, 45)
SetLockButton.BorderSizePixel = 0
SetLockButton.Size = UDim2.new(1, -5, 0, 44)
SetLockButton.Font = Enum.Font.GothamBold
SetLockButton.Text = "SET LOCK BUTTON"
SetLockButton.TextColor3 = Color3.fromRGB(255, 255, 255)
SetLockButton.TextSize = 12
SetLockButton.Parent = AimPage

local SetLockCorner = Instance.new("UICorner")
SetLockCorner.CornerRadius = UDim.new(0, 8)
SetLockCorner.Parent = SetLockButton

local BindStatus = Instance.new("TextLabel")
BindStatus.BackgroundTransparency = 1
BindStatus.Size = UDim2.new(1, -5, 0, 28)
BindStatus.Font = Enum.Font.Gotham
BindStatus.Text = "Controller input only"
BindStatus.TextColor3 = Color3.fromRGB(125, 125, 130)
BindStatus.TextSize = 10
BindStatus.Parent = AimPage

local function ParseNumber(Box, Default)
    local Number = tonumber(Box.Text)

    if Number == nil then
        Box.Text = tostring(Default)
        return Default
    end

    return Number
end

AddConnection(AimOffsetBox.FocusLost:Connect(function()
    Config.AimOffset = math.clamp(
        ParseNumber(AimOffsetBox, Config.AimOffset),
        -100,
        100
    )
    AimOffsetBox.Text = tostring(Config.AimOffset)
end))

AddConnection(SmoothingBox.FocusLost:Connect(function()
    Config.Smoothing = math.max(
        0,
        ParseNumber(SmoothingBox, Config.Smoothing)
    )
    SmoothingBox.Text = tostring(Config.Smoothing)
end))

AddConnection(PredictionXBox.FocusLost:Connect(function()
    Config.PredictionX = ParseNumber(
        PredictionXBox,
        Config.PredictionX
    )
    PredictionXBox.Text = tostring(Config.PredictionX)
end))

AddConnection(PredictionYBox.FocusLost:Connect(function()
    Config.PredictionY = ParseNumber(
        PredictionYBox,
        Config.PredictionY
    )
    PredictionYBox.Text = tostring(Config.PredictionY)
end))

AddConnection(AboveStrengthBox.FocusLost:Connect(function()
    Config.AboveTargetStrength = math.max(
        0,
        ParseNumber(
            AboveStrengthBox,
            Config.AboveTargetStrength
        )
    )

    AboveStrengthBox.Text = tostring(Config.AboveTargetStrength)
end))

AddConnection(AboveMaxBox.FocusLost:Connect(function()
    Config.AboveTargetMaxCorrection = math.max(
        0,
        ParseNumber(
            AboveMaxBox,
            Config.AboveTargetMaxCorrection
        )
    )

    AboveMaxBox.Text = tostring(Config.AboveTargetMaxCorrection)
end))

--//========================================================
--// ESP PAGE
--//========================================================

CreateSection(ESPPage, "ESP")

CreateToggle(
    ESPPage,
    "Enable ESP",
    Config.ESPEnabled,
    function(State)
        Config.ESPEnabled = State
    end
)

CreateToggle(
    ESPPage,
    "Show Name",
    Config.ESPShowName,
    function(State)
        Config.ESPShowName = State
    end
)

CreateToggle(
    ESPPage,
    "Show Outline",
    Config.ESPShowOutline,
    function(State)
        Config.ESPShowOutline = State
    end
)

CreateToggle(
    ESPPage,
    "Whitelist Check",
    Config.ESPWhitelistCheck,
    function(State)
        Config.ESPWhitelistCheck = State
    end
)

CreateInfoRow(
    ESPPage,
    "Distance",
    "Always shown"
)

--//========================================================
--// WHITELIST PAGE
--//========================================================

CreateSection(WhitelistPage, "SERVER PLAYERS")

local WhitelistInfo = Instance.new("TextLabel")
WhitelistInfo.BackgroundTransparency = 1
WhitelistInfo.Size = UDim2.new(1, -5, 0, 34)
WhitelistInfo.Font = Enum.Font.Gotham
WhitelistInfo.Text = "Tap a player to whitelist them."
WhitelistInfo.TextColor3 = Color3.fromRGB(145, 145, 150)
WhitelistInfo.TextSize = 10
WhitelistInfo.TextXAlignment = Enum.TextXAlignment.Left
WhitelistInfo.Parent = WhitelistPage

local WhitelistEntries = {}

local function UpdateWhitelistEntry(Player)
    local Button = WhitelistEntries[Player]

    if not Button then
        return
    end

    if IsWhitelisted(Player) then
        Button.BackgroundColor3 = Color3.fromRGB(190, 35, 45)
        Button.TextColor3 = Color3.fromRGB(255, 255, 255)
    else
        Button.BackgroundColor3 = Color3.fromRGB(32, 32, 36)
        Button.TextColor3 = Color3.fromRGB(185, 185, 190)
    end
end

local function CreateWhitelistEntry(Player)
    if Player == LocalPlayer then
        return
    end

    if WhitelistEntries[Player] then
        return
    end

    local Button = Instance.new("TextButton")
    Button.Name = tostring(Player.UserId)
    Button.BackgroundColor3 = Color3.fromRGB(32, 32, 36)
    Button.BorderSizePixel = 0
    Button.Size = UDim2.new(1, -5, 0, 42)
    Button.Font = Enum.Font.GothamMedium
    Button.Text = Player.DisplayName .. "  @" .. Player.Name
    Button.TextColor3 = Color3.fromRGB(185, 185, 190)
    Button.TextSize = 11
    Button.TextXAlignment = Enum.TextXAlignment.Left
    Button.AutoButtonColor = false
    Button.Parent = WhitelistPage

    local Padding = Instance.new("UIPadding")
    Padding.PaddingLeft = UDim.new(0, 12)
    Padding.Parent = Button

    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 7)
    Corner.Parent = Button

    WhitelistEntries[Player] = Button

    UpdateWhitelistEntry(Player)

    AddConnection(Button.Activated:Connect(function()
        local UserId = Player.UserId

        if Whitelist[UserId] then
            Whitelist[UserId] = nil
        else
            Whitelist[UserId] = true
        end

        SaveWhitelist()
        UpdateWhitelistEntry(Player)

        if LockedTarget == Player and Config.AimbotWhitelistSkip then
            Locked = false
            LockedTarget = nil
        end
    end))
end

local function RemoveWhitelistEntry(Player)
    local Button = WhitelistEntries[Player]

    if Button then
        Button:Destroy()
        WhitelistEntries[Player] = nil
    end
end

for _, Player in ipairs(Players:GetPlayers()) do
    CreateWhitelistEntry(Player)
end

AddConnection(Players.PlayerAdded:Connect(function(Player)
    CreateWhitelistEntry(Player)
end))

AddConnection(Players.PlayerRemoving:Connect(function(Player)
    RemoveWhitelistEntry(Player)

    if LockedTarget == Player then
        Locked = false
        LockedTarget = nil
    end
end))

--//========================================================
--// DRAGGING
--//========================================================

local Dragging = false
local DragStart
local StartPosition

AddConnection(TopBar.InputBegan:Connect(function(Input)
    if Input.UserInputType == Enum.UserInputType.MouseButton1
        or Input.UserInputType == Enum.UserInputType.Touch then

        Dragging = true
        DragStart = Input.Position
        StartPosition = Main.Position

        local EndConnection

        EndConnection = Input.Changed:Connect(function()
            if Input.UserInputState == Enum.UserInputState.End then
                Dragging = false

                if EndConnection then
                    EndConnection:Disconnect()
                end
            end
        end)
    end
end))

AddConnection(UserInputService.InputChanged:Connect(function(Input)
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
end))

--//========================================================
--// OPEN / CLOSE
--//========================================================

AddConnection(Close.Activated:Connect(function()
    Main.Visible = false
    FloatingButton.Visible = true
end))

AddConnection(FloatingButton.Activated:Connect(function()
    Main.Visible = not Main.Visible
end))

--//========================================================
--// RESPONSIVE SIZE
--//========================================================

local function UpdateUISize()
    local Viewport = Camera.ViewportSize
    local Width = Viewport.X

    if Width <= 600 then
        Main.Size = UDim2.fromOffset(
            math.max(260, math.min(275, Width - 20)),
            440
        )
    elseif Width <= 1000 then
        Main.Size = UDim2.fromOffset(320, 490)
    else
        Main.Size = UDim2.fromOffset(390, 570)
    end
end

UpdateUISize()

AddConnection(Camera:GetPropertyChangedSignal("ViewportSize"):Connect(
    UpdateUISize
))

--//========================================================
--// TARGET FUNCTIONS
--//========================================================

local function GetCharacter(Player)
    if not Player then
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

local function IsValidTarget(Player)
    if not Player or Player == LocalPlayer then
        return false
    end

    if Config.AimbotWhitelistSkip and IsWhitelisted(Player) then
        return false
    end

    local Character, Humanoid, Root = GetCharacter(Player)

    if not Character or not Humanoid or not Root then
        return false
    end

    local LocalCharacter = LocalPlayer.Character

    if not LocalCharacter then
        return false
    end

    local LocalRoot = LocalCharacter:FindFirstChild("HumanoidRootPart")

    if not LocalRoot then
        return false
    end

    local Distance = (Root.Position - LocalRoot.Position).Magnitude

    return Distance <= Config.MaxTargetDistance
end

--//========================================================
--// TARGET SELECTION
--//========================================================

local function FindClosestToCursor()
    local Center = Vector2.new(
        Camera.ViewportSize.X / 2,
        Camera.ViewportSize.Y / 2
    )

    local BestPlayer = nil
    local BestDistance = math.huge

    for _, Player in ipairs(Players:GetPlayers()) do
        if IsValidTarget(Player) then
            local _, _, Root = GetCharacter(Player)

            if Root then
                local ScreenPosition, OnScreen =
                    Camera:WorldToViewportPoint(Root.Position)

                if OnScreen and ScreenPosition.Z > 0 then
                    local ScreenDistance =
                        (Vector2.new(
                            ScreenPosition.X,
                            ScreenPosition.Y
                        ) - Center).Magnitude

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

local function FindClosestPhysical()
    local LocalCharacter = LocalPlayer.Character

    if not LocalCharacter then
        return nil
    end

    local LocalRoot = LocalCharacter:FindFirstChild("HumanoidRootPart")

    if not LocalRoot then
        return nil
    end

    local BestPlayer = nil
    local BestDistance = math.huge

    for _, Player in ipairs(Players:GetPlayers()) do
        if IsValidTarget(Player) then
            local _, _, Root = GetCharacter(Player)

            if Root then
                local Distance =
                    (Root.Position - LocalRoot.Position).Magnitude

                if Distance < BestDistance then
                    BestDistance = Distance
                    BestPlayer = Player
                end
            end
        end
    end

    return BestPlayer
end

local function FindTarget()
    if Config.StickyAim then
        return FindClosestToCursor()
    end

    return FindClosestPhysical()
end

--//========================================================
--// PREDICTION
--//========================================================

local function GetPredictedPosition(Position, Velocity)
    local X = Position.X + (Velocity.X * Config.PredictionX)

    -- Y prediction is inverted
    local Y = Position.Y - (Velocity.Y * Config.PredictionY)

    -- Z deliberately has no prediction
    local Z = Position.Z

    return Vector3.new(X, Y, Z)
end

--//========================================================
--// ADAPTIVE OFFSET
--//========================================================

local function GetAdaptiveOffset(Root)
    local LocalCharacter = LocalPlayer.Character

    if not LocalCharacter then
        return Config.AimOffset
    end

    local LocalRoot = LocalCharacter:FindFirstChild("HumanoidRootPart")

    if not LocalRoot then
        return Config.AimOffset
    end

    local Distance =
        (Root.Position - LocalRoot.Position).Magnitude

    local Offset =
        Config.AimOffset *
        (Distance / Config.ReferenceDistance)

    return math.clamp(Offset, -100, 100)
end

--//========================================================
--// AIM POSITION
--//========================================================

local function GetAimPosition(Player)
    local Character, Humanoid, Root = GetCharacter(Player)

    if not Character or not Humanoid or not Root then
        return nil
    end

    local Velocity = Root.AssemblyLinearVelocity

    if Config.CameraMode == "First Person" then
        local Head = Character:FindFirstChild("Head")

        if not Head then
            return nil
        end

        return GetPredictedPosition(
            Head.Position,
            Velocity
        )
    end

    local Predicted =
        GetPredictedPosition(
            Root.Position,
            Velocity
        )

    local AdaptiveOffset =
        GetAdaptiveOffset(Root)

    local AimPosition =
        Predicted -
        Vector3.new(0, AdaptiveOffset, 0)

    -- Fix for looking down from above a target.
    if Config.AboveTargetCorrection then
        local CameraY = Camera.CFrame.Position.Y
        local TargetY = Predicted.Y

        local VerticalDifference =
            CameraY - TargetY

        if VerticalDifference > 0 then
            local Correction =
                VerticalDifference *
                Config.AboveTargetStrength

            Correction = math.clamp(
                Correction,
                0,
                Config.AboveTargetMaxCorrection
            )

            AimPosition =
                AimPosition +
                Vector3.new(0, Correction, 0)
        end
    end

    return AimPosition
end

--//========================================================
--// CAMERA LOCK
--//========================================================

local function Unlock()
    Locked = false
    LockedTarget = nil
end

local function Lock()
    if Locked then
        Unlock()
        return
    end

    local Target = FindTarget()

    if not Target then
        return
    end

    LockedTarget = Target
    Locked = true
end

--//========================================================
--// CONTROLLER INPUT
--//========================================================

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

    [Enum.KeyCode.ButtonL2] = true,
    [Enum.KeyCode.ButtonR2] = true,

    [Enum.KeyCode.Thumbstick1] = true,
    [Enum.KeyCode.Thumbstick2] = true,
}

local function IsSupportedButton(KeyCode)
    return SupportedButtons[KeyCode] == true
end

AddConnection(UserInputService.InputBegan:Connect(function(Input, GameProcessed)
    if GameProcessed then
        return
    end

    if Input.UserInputType ~= Enum.UserInputType.Gamepad1 then
        return
    end

    local KeyCode = Input.KeyCode

    if WaitingForBind then
        if IsSupportedButton(KeyCode) then
            Config.LockButton = KeyCode
            LockButtonLabel.Text = KeyCode.Name

            WaitingForBind = false
            SetLockButton.Text = "SET LOCK BUTTON"
            BindStatus.Text = "Bound to " .. KeyCode.Name
        end

        return
    end

    if KeyCode == Config.LockButton then
        Lock()
    end
end))

--//========================================================
--// STICK REBINDING
--//========================================================

local StickLastState = {
    [Enum.KeyCode.Thumbstick1] = false,
    [Enum.KeyCode.Thumbstick2] = false,
}

AddConnection(UserInputService.InputChanged:Connect(function(Input)
    if not WaitingForBind then
        return
    end

    if Input.UserInputType ~= Enum.UserInputType.Gamepad1 then
        return
    end

    if Input.KeyCode ~= Enum.KeyCode.Thumbstick1
        and Input.KeyCode ~= Enum.KeyCode.Thumbstick2 then
        return
    end

    local Position = Input.Position

    local Magnitude =
        Vector2.new(
            Position.X,
            Position.Y
        ).Magnitude

    if Magnitude > 0.65 then
        if not StickLastState[Input.KeyCode] then
            Config.LockButton = Input.KeyCode

            LockButtonLabel.Text = Input.KeyCode.Name

            WaitingForBind = false

            SetLockButton.Text = "SET LOCK BUTTON"
            BindStatus.Text =
                "Bound to " .. Input.KeyCode.Name

            StickLastState[Input.KeyCode] = true
        end
    else
        StickLastState[Input.KeyCode] = false
    end
end))

AddConnection(SetLockButton.Activated:Connect(function()
    WaitingForBind = true

    SetLockButton.Text = "PRESS CONTROLLER BUTTON"

    BindStatus.Text =
        "Press any supported controller input"
end))

--//========================================================
--// CAMERA RENDER LOOP
--//========================================================

local RenderName = "XenonCameraLock"

pcall(function()
    RunService:UnbindFromRenderStep(RenderName)
end)

RunService:BindToRenderStep(
    RenderName,
    Enum.RenderPriority.Last.Value,
    function()
        if not Locked then
            return
        end

        if not LockedTarget then
            Unlock()
            return
        end

        if not IsValidTarget(LockedTarget) then
            Unlock()
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

        local Direction =
            AimPosition - CameraPosition

        if Direction.Magnitude <= 0.001 then
            return
        end

        local DesiredCFrame =
            CFrame.lookAt(
                CameraPosition,
                AimPosition
            )

        if Config.Smoothing <= 0 then
            Camera.CFrame = DesiredCFrame
        else
            local Alpha =
                math.clamp(
                    1 / (Config.Smoothing + 1),
                    0.01,
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

--//========================================================
--// ESP
--//========================================================

local function GetTeamColor(Player)
    if Player.Team then
        return Player.Team.TeamColor.Color
    end

    return Color3.fromRGB(255, 255, 255)
end

local function CleanupESP(Player)
    local Data = ESPObjects[Player]

    if Data then
        if Data.Highlight then
            Data.Highlight:Destroy()
        end

        if Data.NameBillboard then
            Data.NameBillboard:Destroy()
        end

        if Data.DistanceBillboard then
            Data.DistanceBillboard:Destroy()
        end

        ESPObjects[Player] = nil
    end
end

local function ApplyESPColor(Player)
    local Data = ESPObjects[Player]

    if not Data then
        return
    end

    local Color = GetTeamColor(Player)

    if Data.NameLabel then
        Data.NameLabel.TextColor3 = Color
    end

    if Data.DistanceLabel then
        Data.DistanceLabel.TextColor3 = Color
    end

    if Data.Highlight then
        Data.Highlight.OutlineColor = Color
    end
end

local function CreateESP(Player, Character)
    if Player == LocalPlayer then
        return
    end

    if not Config.ESPEnabled then
        return
    end

    if Config.ESPWhitelistCheck and IsWhitelisted(Player) then
        return
    end

    CleanupESP(Player)

    local Head = Character:FindFirstChild("Head")
    local Root = Character:FindFirstChild("HumanoidRootPart")

    if not Head or not Root then
        return
    end

    local Data = {}

    --// Name
    if Config.ESPShowName then
        local NameBillboard = Instance.new("BillboardGui")
        NameBillboard.Name = "XenonName"
        NameBillboard.Adornee = Head
        NameBillboard.AlwaysOnTop = true
        NameBillboard.Size = UDim2.fromOffset(180, 24)
        NameBillboard.StudsOffset = Vector3.new(0, 2.7, 0)
        NameBillboard.Parent = Head

        local NameLabel = Instance.new("TextLabel")
        NameLabel.BackgroundTransparency = 1
        NameLabel.Size = UDim2.fromScale(1, 1)
        NameLabel.Font = Enum.Font.Gotham
        NameLabel.Text = Player.DisplayName
        NameLabel.TextSize = 9
        NameLabel.TextStrokeTransparency = 0.5
        NameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        NameLabel.Parent = NameBillboard

        Data.NameBillboard = NameBillboard
        Data.NameLabel = NameLabel
    end

    --// Distance
    local DistanceBillboard = Instance.new("BillboardGui")
    DistanceBillboard.Name = "XenonDistance"
    DistanceBillboard.Adornee = Root
    DistanceBillboard.AlwaysOnTop = true
    DistanceBillboard.Size = UDim2.fromOffset(160, 22)
    DistanceBillboard.StudsOffset = Vector3.new(0, -3, 0)
    DistanceBillboard.Parent = Root

    local DistanceLabel = Instance.new("TextLabel")
    DistanceLabel.BackgroundTransparency = 1
    DistanceLabel.Size = UDim2.fromScale(1, 1)
    DistanceLabel.Font = Enum.Font.Gotham
    DistanceLabel.TextSize = 9
    DistanceLabel.TextStrokeTransparency = 0.5
    DistanceLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    DistanceLabel.Parent = DistanceBillboard

    Data.DistanceBillboard = DistanceBillboard
    Data.DistanceLabel = DistanceLabel

    --// Outline
    if Config.ESPShowOutline then
        local Highlight = Instance.new("Highlight")
        Highlight.Name = "XenonHighlight"
        Highlight.Adornee = Character
        Highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        Highlight.FillTransparency = 1
        Highlight.OutlineTransparency = 0
        Highlight.Parent = Character

        Data.Highlight = Highlight
    end

    ESPObjects[Player] = Data

    ApplyESPColor(Player)
end

local function UpdateESP(Player)
    local Data = ESPObjects[Player]

    if not Data then
        return
    end

    if not Config.ESPEnabled then
        CleanupESP(Player)
        return
    end

    if Config.ESPWhitelistCheck and IsWhitelisted(Player) then
        CleanupESP(Player)
        return
    end

    local Character, Humanoid, Root =
        GetCharacter(Player)

    if not Character or not Humanoid or not Root then
        CleanupESP(Player)
        return
    end

    if Data.DistanceLabel then
        local LocalCharacter = LocalPlayer.Character
        local LocalRoot =
            LocalCharacter and
            LocalCharacter:FindFirstChild("HumanoidRootPart")

        if LocalRoot then
            local Distance =
                math.floor(
                    (Root.Position - LocalRoot.Position).Magnitude
                )

            Data.DistanceLabel.Text =
                tostring(Distance) .. " studs"
        end
    end

    ApplyESPColor(Player)
end

local function OnESPCharacter(Player, Character)
    task.spawn(function()
        local Head =
            Character:WaitForChild(
                "Head",
                5
            )

        local Root =
            Character:WaitForChild(
                "HumanoidRootPart",
                5
            )

        if not Head or not Root then
            return
        end

        if Player.Character ~= Character then
            return
        end

        if Config.ESPEnabled then
            CreateESP(Player, Character)
        end
    end)
end

local function TrackESPPlayer(Player)
    if Player == LocalPlayer then
        return
    end

    if ESPCharacterConnections[Player] then
        ESPCharacterConnections[Player]:Disconnect()
    end

    ESPCharacterConnections[Player] =
        Player.CharacterAdded:Connect(function(Character)
            CleanupESP(Player)
            OnESPCharacter(Player, Character)
        end)

    table.insert(
        Connections,
        ESPCharacterConnections[Player]
    )

    if Player.Character then
        OnESPCharacter(Player, Player.Character)
    end
end

for _, Player in ipairs(Players:GetPlayers()) do
    TrackESPPlayer(Player)
end

AddConnection(Players.PlayerAdded:Connect(function(Player)
    TrackESPPlayer(Player)
end))

AddConnection(Players.PlayerRemoving:Connect(function(Player)
    CleanupESP(Player)

    if ESPCharacterConnections[Player] then
        ESPCharacterConnections[Player]:Disconnect()
        ESPCharacterConnections[Player] = nil
    end
end))

--//========================================================
--// LOCAL CHARACTER RESPAWN
--//========================================================

AddConnection(LocalPlayer.CharacterAdded:Connect(function()
    Unlock()
end))

--//========================================================
--// ESP REFRESH
--//========================================================

local HeartbeatCounter = 0

AddConnection(RunService.Heartbeat:Connect(function()
    HeartbeatCounter += 1

    if HeartbeatCounter < 4 then
        return
    end

    HeartbeatCounter = 0

    for _, Player in ipairs(Players:GetPlayers()) do
        if Player ~= LocalPlayer then
            UpdateESP(Player)
        end
    end
end))

--//========================================================
--// ESP CONFIG REFRESH
--//========================================================

local function RefreshAllESP()
    for _, Player in ipairs(Players:GetPlayers()) do
        if Player ~= LocalPlayer then
            CleanupESP(Player)

            if Config.ESPEnabled then
                if not (
                    Config.ESPWhitelistCheck
                    and IsWhitelisted(Player)
                ) then
                    if Player.Character then
                        CreateESP(
                            Player,
                            Player.Character
                        )
                    end
                end
            end
        end
    end
end

-- Replace ESP toggle callbacks with refresh-aware behavior
-- by observing configuration every heartbeat.
local PreviousESPEnabled = Config.ESPEnabled
local PreviousESPName = Config.ESPShowName
local PreviousESPOutline = Config.ESPShowOutline
local PreviousESPWhitelist = Config.ESPWhitelistCheck

AddConnection(RunService.Heartbeat:Connect(function()
    if PreviousESPEnabled ~= Config.ESPEnabled
        or PreviousESPName ~= Config.ESPShowName
        or PreviousESPOutline ~= Config.ESPShowOutline
        or PreviousESPWhitelist ~= Config.ESPWhitelistCheck then

        PreviousESPEnabled = Config.ESPEnabled
        PreviousESPName = Config.ESPShowName
        PreviousESPOutline = Config.ESPShowOutline
        PreviousESPWhitelist = Config.ESPWhitelistCheck

        RefreshAllESP()
    end
end))

--//========================================================
--// CLEANUP
--//========================================================

_G.XenonCleanup = function()
    Locked = false
    LockedTarget = nil

    pcall(function()
        RunService:UnbindFromRenderStep(RenderName)
    end)

    for Player in pairs(ESPObjects) do
        CleanupESP(Player)
    end

    for Player, Connection in pairs(ESPCharacterConnections) do
        pcall(function()
            Connection:Disconnect()
        end)

        ESPCharacterConnections[Player] = nil
    end

    DisconnectAll()

    if ScreenGui then
        ScreenGui:Destroy()
    end
end

--//========================================================
--// FINAL UI REFRESH
--//========================================================

SwitchTab("AIM")

LockButtonLabel.Text = Config.LockButton.Name

print("Xenon Controller Camera Lock loaded.")
print("Lock Button:", Config.LockButton.Name)
print("Prediction X:", Config.PredictionX)
print("Prediction Y:", Config.PredictionY)
