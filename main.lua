--//========================================================
--// XENON CONTROLLER CAMERA LOCK
--// MOBILE-FIRST COMPLETE BUILD
--//========================================================

--//========================================================
--// DUPLICATE EXECUTION CLEANUP
--//========================================================

if _G.XenonCleanup then
    pcall(_G.XenonCleanup)
end

--//========================================================
--// SERVICES
--//========================================================

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Camera = workspace.CurrentCamera

--//========================================================
--// CONFIG
--//========================================================

local Config = {
    -- Controller
    LockButton = Enum.KeyCode.ButtonY,

    -- Camera
    CameraMode = "Third Person",

    -- Third-person adaptive offset
    AimOffset = 23.5,
    ReferenceDistance = 100,

    -- Camera smoothing
    Smoothing = 0,

    -- Separate prediction
    PredictionX = 0.08,
    PredictionY = 0.08,

    -- Targeting
    MaxTargetDistance = 500,
    StickyAim = true,

    -- Above-target correction
    AboveTargetCorrection = true,
    AboveTargetStrength = 0.35,
    AboveTargetMaxCorrection = 20,

    -- ESP
    ESPEnabled = false,
    ESPShowName = true,
    ESPShowOutline = true,
    ESPWhitelistCheck = true,

    -- Aimbot whitelist
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
--// WHITELIST FILE SYSTEM
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
        writefile(
            FileName,
            HttpService:JSONEncode(IDs)
        )
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
        return HttpService:JSONDecode(
            readfile(FileName)
        )
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
    if not Player then
        return false
    end

    return Whitelist[Player.UserId] == true
end

--//========================================================
--// GUI ROOT
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

--//========================================================
--// MAIN WINDOW
--//========================================================

local Main = Instance.new("Frame")
Main.Name = "Main"
Main.AnchorPoint = Vector2.new(0.5, 0.5)
Main.Position = UDim2.fromScale(0.5, 0.5)
Main.Size = UDim2.fromOffset(350, 520)
Main.BackgroundColor3 = Color3.fromRGB(14, 14, 17)
Main.BorderSizePixel = 0
Main.ClipsDescendants = true
Main.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 12)
MainCorner.Parent = Main

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(48, 48, 54)
MainStroke.Thickness = 1
MainStroke.Parent = Main

--//========================================================
--// TOP BAR
--//========================================================

local TopBar = Instance.new("Frame")
TopBar.Name = "TopBar"
TopBar.Size = UDim2.new(1, 0, 0, 46)
TopBar.BackgroundColor3 = Color3.fromRGB(19, 19, 23)
TopBar.BorderSizePixel = 0
TopBar.Parent = Main

local TopBarBottom = Instance.new("Frame")
TopBarBottom.Size = UDim2.new(1, 0, 0, 1)
TopBarBottom.Position = UDim2.new(0, 0, 1, -1)
TopBarBottom.BackgroundColor3 = Color3.fromRGB(42, 42, 47)
TopBarBottom.BorderSizePixel = 0
TopBarBottom.Parent = TopBar

local Title = Instance.new("TextLabel")
Title.BackgroundTransparency = 1
Title.Position = UDim2.fromOffset(14, 0)
Title.Size = UDim2.new(1, -70, 1, 0)
Title.Font = Enum.Font.GothamBold
Title.Text = "XENON"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 16
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = TopBar

local SubTitle = Instance.new("TextLabel")
SubTitle.BackgroundTransparency = 1
SubTitle.AnchorPoint = Vector2.new(0, 0.5)
SubTitle.Position = UDim2.new(0, 67, 0.5, 0)
SubTitle.Size = UDim2.fromOffset(80, 20)
SubTitle.Font = Enum.Font.GothamMedium
SubTitle.Text = "CONTROLLER"
SubTitle.TextColor3 = Color3.fromRGB(125, 125, 132)
SubTitle.TextSize = 8
SubTitle.TextXAlignment = Enum.TextXAlignment.Left
SubTitle.Parent = TopBar

local Close = Instance.new("TextButton")
Close.Name = "Close"
Close.AnchorPoint = Vector2.new(1, 0.5)
Close.Position = UDim2.new(1, -7, 0.5, 0)
Close.Size = UDim2.fromOffset(34, 34)
Close.BackgroundTransparency = 1
Close.BorderSizePixel = 0
Close.Font = Enum.Font.GothamBold
Close.Text = "×"
Close.TextColor3 = Color3.fromRGB(235, 55, 65)
Close.TextSize = 24
Close.AutoButtonColor = false
Close.Parent = TopBar

--//========================================================
--// TAB BAR
--//========================================================

local TabBar = Instance.new("Frame")
TabBar.Name = "TabBar"
TabBar.Position = UDim2.fromOffset(8, 54)
TabBar.Size = UDim2.new(1, -16, 0, 38)
TabBar.BackgroundColor3 = Color3.fromRGB(19, 19, 23)
TabBar.BorderSizePixel = 0
TabBar.Parent = Main

local TabCorner = Instance.new("UICorner")
TabCorner.CornerRadius = UDim.new(0, 8)
TabCorner.Parent = TabBar

local TabPadding = Instance.new("UIPadding")
TabPadding.PaddingLeft = UDim.new(0, 4)
TabPadding.PaddingRight = UDim.new(0, 4)
TabPadding.PaddingTop = UDim.new(0, 4)
TabPadding.PaddingBottom = UDim.new(0, 4)
TabPadding.Parent = TabBar

local TabLayout = Instance.new("UIListLayout")
TabLayout.FillDirection = Enum.FillDirection.Horizontal
TabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
TabLayout.VerticalAlignment = Enum.VerticalAlignment.Center
TabLayout.Padding = UDim.new(0, 4)
TabLayout.SortOrder = Enum.SortOrder.LayoutOrder
TabLayout.Parent = TabBar

--//========================================================
--// PAGE CONTAINER
--//========================================================

local Pages = Instance.new("Frame")
Pages.Name = "Pages"
Pages.Position = UDim2.fromOffset(8, 100)
Pages.Size = UDim2.new(1, -16, 1, -108)
Pages.BackgroundTransparency = 1
Pages.BorderSizePixel = 0
Pages.ClipsDescendants = true
Pages.Parent = Main

--//========================================================
--// TAB BUTTON
--//========================================================

local function CreateTabButton(Name, Order)
    local Button = Instance.new("TextButton")
    Button.Name = Name .. "Tab"
    Button.LayoutOrder = Order
    Button.Size = UDim2.new(1 / 3, -4, 1, -8)
    Button.BackgroundColor3 = Color3.fromRGB(27, 27, 31)
    Button.BorderSizePixel = 0
    Button.Font = Enum.Font.GothamSemibold
    Button.Text = Name
    Button.TextColor3 = Color3.fromRGB(135, 135, 142)
    Button.TextSize = 10
    Button.AutoButtonColor = false
    Button.Parent = TabBar

    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 6)
    Corner.Parent = Button

    return Button
end

local AimTab = CreateTabButton("AIM", 1)
local ESPTab = CreateTabButton("ESP", 2)
local WhitelistTab = CreateTabButton("WHITELIST", 3)

--//========================================================
--// PAGE CREATOR
--//========================================================

local function CreatePage(Name)
    local Page = Instance.new("ScrollingFrame")
    Page.Name = Name
    Page.Size = UDim2.fromScale(1, 1)
    Page.BackgroundTransparency = 1
    Page.BorderSizePixel = 0
    Page.ScrollBarThickness = 3
    Page.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 86)
    Page.CanvasSize = UDim2.new()
    Page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    Page.ScrollingDirection = Enum.ScrollingDirection.Y
    Page.Visible = false
    Page.Parent = Pages

    local Padding = Instance.new("UIPadding")
    Padding.PaddingLeft = UDim.new(0, 1)
    Padding.PaddingRight = UDim.new(0, 4)
    Padding.PaddingTop = UDim.new(0, 3)
    Padding.PaddingBottom = UDim.new(0, 8)
    Padding.Parent = Page

    local Layout = Instance.new("UIListLayout")
    Layout.Padding = UDim.new(0, 7)
    Layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    Layout.SortOrder = Enum.SortOrder.LayoutOrder
    Layout.Parent = Page

    return Page
end

local AimPage = CreatePage("AIM")
local ESPPage = CreatePage("ESP")
local WhitelistPage = CreatePage("WHITELIST")

--//========================================================
--// TAB SWITCHING
--//========================================================

local function UpdateTabs()
    local TabInfo = {
        {
            Button = AimTab,
            Name = "AIM"
        },
        {
            Button = ESPTab,
            Name = "ESP"
        },
        {
            Button = WhitelistTab,
            Name = "WHITELIST"
        }
    }

    for _, Info in ipairs(TabInfo) do
        if CurrentTab == Info.Name then
            Info.Button.BackgroundColor3 =
                Color3.fromRGB(190, 35, 45)

            Info.Button.TextColor3 =
                Color3.fromRGB(255, 255, 255)
        else
            Info.Button.BackgroundColor3 =
                Color3.fromRGB(27, 27, 31)

            Info.Button.TextColor3 =
                Color3.fromRGB(135, 135, 142)
        end
    end
end

local function SwitchTab(Name)
    CurrentTab = Name

    AimPage.Visible = Name == "AIM"
    ESPPage.Visible = Name == "ESP"
    WhitelistPage.Visible = Name == "WHITELIST"

    UpdateTabs()
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

--//========================================================
--// UI HELPERS
--//========================================================

local function CreateSection(Page, Text)
    local Section = Instance.new("TextLabel")
    Section.Size = UDim2.new(1, -4, 0, 25)
    Section.BackgroundTransparency = 1
    Section.Font = Enum.Font.GothamBold
    Section.Text = Text
    Section.TextColor3 = Color3.fromRGB(235, 60, 70)
    Section.TextSize = 11
    Section.TextXAlignment = Enum.TextXAlignment.Left
    Section.Parent = Page

    return Section
end

local function CreateRow(Page, Height)
    local Row = Instance.new("Frame")
    Row.Size = UDim2.new(1, -4, 0, Height or 48)
    Row.BackgroundColor3 = Color3.fromRGB(22, 22, 26)
    Row.BorderSizePixel = 0
    Row.Parent = Page

    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 8)
    Corner.Parent = Row

    return Row
end

local function CreateRowLabel(Row, Text)
    local Label = Instance.new("TextLabel")
    Label.Position = UDim2.fromOffset(12, 0)
    Label.Size = UDim2.new(0.55, 0, 1, 0)
    Label.BackgroundTransparency = 1
    Label.Font = Enum.Font.GothamMedium
    Label.Text = Text
    Label.TextColor3 = Color3.fromRGB(225, 225, 230)
    Label.TextSize = 11
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = Row

    return Label
end

local function CreateTextBox(Page, Text, Value)
    local Row = CreateRow(Page, 48)

    CreateRowLabel(Row, Text)

    local Box = Instance.new("TextBox")
    Box.AnchorPoint = Vector2.new(1, 0.5)
    Box.Position = UDim2.new(1, -9, 0.5, 0)
    Box.Size = UDim2.fromOffset(105, 30)
    Box.BackgroundColor3 = Color3.fromRGB(12, 12, 15)
    Box.BorderSizePixel = 0
    Box.ClearTextOnFocus = false
    Box.Font = Enum.Font.Gotham
    Box.Text = tostring(Value)
    Box.TextColor3 = Color3.fromRGB(255, 255, 255)
    Box.TextSize = 11
    Box.Parent = Row

    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 6)
    Corner.Parent = Box

    local Stroke = Instance.new("UIStroke")
    Stroke.Color = Color3.fromRGB(50, 50, 56)
    Stroke.Thickness = 1
    Stroke.Parent = Box

    return Box
end

local function CreateToggle(Page, Text, Default, Callback)
    local Row = CreateRow(Page, 48)

    CreateRowLabel(Row, Text)

    local Button = Instance.new("TextButton")
    Button.AnchorPoint = Vector2.new(1, 0.5)
    Button.Position = UDim2.new(1, -9, 0.5, 0)
    Button.Size = UDim2.fromOffset(58, 28)
    Button.BackgroundColor3 = Color3.fromRGB(43, 43, 48)
    Button.BorderSizePixel = 0
    Button.Font = Enum.Font.GothamBold
    Button.TextSize = 9
    Button.AutoButtonColor = false
    Button.Parent = Row

    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(1, 0)
    Corner.Parent = Button

    local State = Default

    local function Refresh()
        if State then
            Button.BackgroundColor3 =
                Color3.fromRGB(190, 35, 45)

            Button.TextColor3 =
                Color3.fromRGB(255, 255, 255)

            Button.Text = "ON"
        else
            Button.BackgroundColor3 =
                Color3.fromRGB(43, 43, 48)

            Button.TextColor3 =
                Color3.fromRGB(150, 150, 155)

            Button.Text = "OFF"
        end
    end

    AddConnection(Button.Activated:Connect(function()
        State = not State

        Callback(State)

        Refresh()
    end))

    Refresh()

    return Button
end

local function CreateInfoRow(Page, Text, Value)
    local Row = CreateRow(Page, 46)

    CreateRowLabel(Row, Text)

    local ValueLabel = Instance.new("TextLabel")
    ValueLabel.AnchorPoint = Vector2.new(1, 0.5)
    ValueLabel.Position = UDim2.new(1, -12, 0.5, 0)
    ValueLabel.Size = UDim2.fromOffset(145, 25)
    ValueLabel.BackgroundTransparency = 1
    ValueLabel.Font = Enum.Font.GothamSemibold
    ValueLabel.Text = Value
    ValueLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    ValueLabel.TextSize = 10
    ValueLabel.TextXAlignment = Enum.TextXAlignment.Right
    ValueLabel.Parent = Row

    return ValueLabel
end

--//========================================================
--// AIM PAGE
--//========================================================

CreateSection(AimPage, "CAMERA")

local CameraModeRow = CreateRow(AimPage, 48)

CreateRowLabel(
    CameraModeRow,
    "Camera Mode"
)

local CameraModeButton = Instance.new("TextButton")
CameraModeButton.AnchorPoint = Vector2.new(1, 0.5)
CameraModeButton.Position = UDim2.new(1, -9, 0.5, 0)
CameraModeButton.Size = UDim2.fromOffset(115, 30)
CameraModeButton.BackgroundColor3 = Color3.fromRGB(12, 12, 15)
CameraModeButton.BorderSizePixel = 0
CameraModeButton.Font = Enum.Font.GothamMedium
CameraModeButton.Text = Config.CameraMode
CameraModeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
CameraModeButton.TextSize = 10
CameraModeButton.AutoButtonColor = false
CameraModeButton.Parent = CameraModeRow

local CameraCorner = Instance.new("UICorner")
CameraCorner.CornerRadius = UDim.new(0, 6)
CameraCorner.Parent = CameraModeButton

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

--// Separate prediction settings
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

        if LockedTarget
            and State
            and IsWhitelisted(LockedTarget) then

            Locked = false
            LockedTarget = nil
        end
    end
)

CreateSection(AimPage, "VERTICAL CORRECTION")

CreateToggle(
    AimPage,
    "Above Target Fix",
    Config.AboveTargetCorrection,
    function(State)
        Config.AboveTargetCorrection = State
    end
)

local AboveStrengthBox = CreateTextBox(
    AimPage,
    "Correction Strength",
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
SetLockButton.Size = UDim2.new(1, -4, 0, 44)
SetLockButton.BackgroundColor3 = Color3.fromRGB(190, 35, 45)
SetLockButton.BorderSizePixel = 0
SetLockButton.Font = Enum.Font.GothamBold
SetLockButton.Text = "SET LOCK BUTTON"
SetLockButton.TextColor3 = Color3.fromRGB(255, 255, 255)
SetLockButton.TextSize = 10
SetLockButton.AutoButtonColor = false
SetLockButton.Parent = AimPage

local SetLockCorner = Instance.new("UICorner")
SetLockCorner.CornerRadius = UDim.new(0, 8)
SetLockCorner.Parent = SetLockButton

local BindStatus = Instance.new("TextLabel")
BindStatus.Size = UDim2.new(1, -4, 0, 25)
BindStatus.BackgroundTransparency = 1
BindStatus.Font = Enum.Font.Gotham
BindStatus.Text = "Controller input only"
BindStatus.TextColor3 = Color3.fromRGB(125, 125, 132)
BindStatus.TextSize = 9
BindStatus.Parent = AimPage

--//========================================================
--// NUMBER VALIDATION
--//========================================================

local function GetNumber(Box, Default)
    local Number = tonumber(Box.Text)

    if Number == nil then
        Box.Text = tostring(Default)
        return Default
    end

    return Number
end

AddConnection(AimOffsetBox.FocusLost:Connect(function()
    Config.AimOffset = math.clamp(
        GetNumber(AimOffsetBox, Config.AimOffset),
        -100,
        100
    )

    AimOffsetBox.Text = tostring(Config.AimOffset)
end))

AddConnection(SmoothingBox.FocusLost:Connect(function()
    Config.Smoothing = math.max(
        0,
        GetNumber(SmoothingBox, Config.Smoothing)
    )

    SmoothingBox.Text = tostring(Config.Smoothing)
end))

AddConnection(PredictionXBox.FocusLost:Connect(function()
    Config.PredictionX =
        GetNumber(
            PredictionXBox,
            Config.PredictionX
        )

    PredictionXBox.Text =
        tostring(Config.PredictionX)
end))

AddConnection(PredictionYBox.FocusLost:Connect(function()
    Config.PredictionY =
        GetNumber(
            PredictionYBox,
            Config.PredictionY
        )

    PredictionYBox.Text =
        tostring(Config.PredictionY)
end))

AddConnection(AboveStrengthBox.FocusLost:Connect(function()
    Config.AboveTargetStrength =
        math.max(
            0,
            GetNumber(
                AboveStrengthBox,
                Config.AboveTargetStrength
            )
        )

    AboveStrengthBox.Text =
        tostring(Config.AboveTargetStrength)
end))

AddConnection(AboveMaxBox.FocusLost:Connect(function()
    Config.AboveTargetMaxCorrection =
        math.max(
            0,
            GetNumber(
                AboveMaxBox,
                Config.AboveTargetMaxCorrection
            )
        )

    AboveMaxBox.Text =
        tostring(Config.AboveTargetMaxCorrection)
end))

--//========================================================
--// ESP PAGE
--//========================================================

CreateSection(ESPPage, "ESP SETTINGS")

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

CreateInfoRow(
    ESPPage,
    "Font",
    "Gotham / 9"
)

CreateInfoRow(
    ESPPage,
    "Color",
    "Team Color"
)

--//========================================================
--// WHITELIST PAGE
--//========================================================

CreateSection(
    WhitelistPage,
    "PLAYER WHITELIST"
)

local WhitelistInfo = Instance.new("TextLabel")
WhitelistInfo.Size = UDim2.new(1, -4, 0, 32)
WhitelistInfo.BackgroundTransparency = 1
WhitelistInfo.Font = Enum.Font.Gotham
WhitelistInfo.Text = "Tap a player to toggle whitelist."
WhitelistInfo.TextColor3 = Color3.fromRGB(135, 135, 142)
WhitelistInfo.TextSize = 9
WhitelistInfo.TextXAlignment = Enum.TextXAlignment.Left
WhitelistInfo.Parent = WhitelistPage

local WhitelistEntries = {}

--//========================================================
--// WHITELIST ENTRY
--//========================================================

local function UpdateWhitelistEntry(Player)
    local Button = WhitelistEntries[Player]

    if not Button then
        return
    end

    if IsWhitelisted(Player) then
        Button.BackgroundColor3 =
            Color3.fromRGB(190, 35, 45)

        Button.TextColor3 =
            Color3.fromRGB(255, 255, 255)
    else
        Button.BackgroundColor3 =
            Color3.fromRGB(25, 25, 29)

        Button.TextColor3 =
            Color3.fromRGB(185, 185, 190)
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
    Button.Name = "Player_" .. tostring(Player.UserId)
    Button.Size = UDim2.new(1, -4, 0, 43)
    Button.BackgroundColor3 = Color3.fromRGB(25, 25, 29)
    Button.BorderSizePixel = 0
    Button.Font = Enum.Font.GothamMedium
    Button.Text =
        "  " ..
        Player.DisplayName ..
        "  @" ..
        Player.Name
    Button.TextColor3 = Color3.fromRGB(185, 185, 190)
    Button.TextSize = 10
    Button.TextXAlignment = Enum.TextXAlignment.Left
    Button.AutoButtonColor = false
    Button.Parent = WhitelistPage

    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 8)
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

        if LockedTarget == Player
            and Config.AimbotWhitelistSkip then

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
end))

--//========================================================
--// DRAGGING
--//========================================================

local Dragging = false
local DragStart = nil
local StartPosition = nil

AddConnection(TopBar.InputBegan:Connect(function(Input)
    if Input.UserInputType ==
        Enum.UserInputType.MouseButton1
        or Input.UserInputType ==
        Enum.UserInputType.Touch then

        Dragging = true

        DragStart = Input.Position
        StartPosition = Main.Position

        local EndConnection

        EndConnection = Input.Changed:Connect(function()
            if Input.UserInputState ==
                Enum.UserInputState.End then

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

    if Input.UserInputType ~=
        Enum.UserInputType.MouseMovement
        and Input.UserInputType ~=
        Enum.UserInputType.Touch then

        return
    end

    local Delta =
        Input.Position - DragStart

    Main.Position = UDim2.new(
        StartPosition.X.Scale,
        StartPosition.X.Offset + Delta.X,

        StartPosition.Y.Scale,
        StartPosition.Y.Offset + Delta.Y
    )
end))

--//========================================================
--// FLOATING REOPEN BUTTON
--//========================================================

local FloatingButton = Instance.new("TextButton")
FloatingButton.Name = "FloatingButton"
FloatingButton.AnchorPoint = Vector2.new(1, 0)
FloatingButton.Position = UDim2.new(1, -12, 0, 12)
FloatingButton.Size = UDim2.fromOffset(42, 42)
FloatingButton.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
FloatingButton.BorderSizePixel = 0
FloatingButton.Font = Enum.Font.GothamBold
FloatingButton.Text = "X"
FloatingButton.TextColor3 = Color3.fromRGB(235, 55, 65)
FloatingButton.TextSize = 15
FloatingButton.AutoButtonColor = false
FloatingButton.Visible = false
FloatingButton.Parent = ScreenGui

local FloatingCorner = Instance.new("UICorner")
FloatingCorner.CornerRadius = UDim.new(0, 10)
FloatingCorner.Parent = FloatingButton

local FloatingStroke = Instance.new("UIStroke")
FloatingStroke.Color = Color3.fromRGB(50, 50, 56)
FloatingStroke.Parent = FloatingButton

AddConnection(Close.Activated:Connect(function()
    Main.Visible = false
    FloatingButton.Visible = true
end))

AddConnection(FloatingButton.Activated:Connect(function()
    Main.Visible = true
    FloatingButton.Visible = false
end))

--//========================================================
--// RESPONSIVE MOBILE UI
--//========================================================

local function UpdateUI()
    local Viewport = Camera.ViewportSize

    local Width = Viewport.X
    local Height = Viewport.Y

    local WindowWidth
    local WindowHeight

    if Width <= 360 then
        WindowWidth = math.max(
            250,
            Width - 12
        )

        WindowHeight = math.min(
            455,
            Height - 16
        )

    elseif Width <= 600 then
        WindowWidth = math.min(
            320,
            Width - 16
        )

        WindowHeight = math.min(
            500,
            Height - 20
        )

    elseif Width <= 1000 then
        WindowWidth = 350
        WindowHeight = 520

    else
        WindowWidth = 380
        WindowHeight = 560
    end

    Main.Size =
        UDim2.fromOffset(
            WindowWidth,
            math.max(390, WindowHeight)
        )

    -- Make sure the tabs always stay inside the window.
    local TabWidth =
        math.max(
            65,
            math.floor(
                (WindowWidth - 28) / 3
            )
        )

    AimTab.Size =
        UDim2.fromOffset(
            TabWidth,
            30
        )

    ESPTab.Size =
        UDim2.fromOffset(
            TabWidth,
            30
        )

    WhitelistTab.Size =
        UDim2.fromOffset(
            TabWidth,
            30
        )
end

UpdateUI()

AddConnection(
    Camera:GetPropertyChangedSignal(
        "ViewportSize"
    ):Connect(UpdateUI)
)

--//========================================================
--// CHARACTER HELPERS
--//========================================================

local function GetCharacter(Player)
    if not Player then
        return nil
    end

    local Character = Player.Character

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

    return Character, Humanoid, Root
end

--//========================================================
--// TARGET VALIDATION
--//========================================================

local function IsValidTarget(Player)
    if not Player then
        return false
    end

    if Player == LocalPlayer then
        return false
    end

    if Config.AimbotWhitelistSkip
        and IsWhitelisted(Player) then

        return false
    end

    local Character, Humanoid, Root =
        GetCharacter(Player)

    if not Character
        or not Humanoid
        or not Root then

        return false
    end

    local LocalCharacter =
        LocalPlayer.Character

    if not LocalCharacter then
        return false
    end

    local LocalRoot =
        LocalCharacter:FindFirstChild(
            "HumanoidRootPart"
        )

    if not LocalRoot then
        return false
    end

    local Distance =
        (
            Root.Position -
            LocalRoot.Position
        ).Magnitude

    return Distance <= Config.MaxTargetDistance
end

--//========================================================
--// CURSOR TARGET
--//========================================================

local function FindClosestToCursor()
    local Center = Vector2.new(
        Camera.ViewportSize.X / 2,
        Camera.ViewportSize.Y / 2
    )

    local BestPlayer = nil
    local BestDistance = math.huge

    for _, Player in ipairs(
        Players:GetPlayers()
    ) do

        if IsValidTarget(Player) then
            local _, _, Root =
                GetCharacter(Player)

            if Root then
                local ScreenPosition, OnScreen =
                    Camera:WorldToViewportPoint(
                        Root.Position
                    )

                if OnScreen
                    and ScreenPosition.Z > 0 then

                    local ScreenDistance =
                        (
                            Vector2.new(
                                ScreenPosition.X,
                                ScreenPosition.Y
                            ) - Center
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

    return BestPlayer
end

--//========================================================
--// PHYSICAL TARGET
--//========================================================

local function FindClosestPhysical()
    local LocalCharacter =
        LocalPlayer.Character

    if not LocalCharacter then
        return nil
    end

    local LocalRoot =
        LocalCharacter:FindFirstChild(
            "HumanoidRootPart"
        )

    if not LocalRoot then
        return nil
    end

    local BestPlayer = nil
    local BestDistance = math.huge

    for _, Player in ipairs(
        Players:GetPlayers()
    ) do

        if IsValidTarget(Player) then
            local _, _, Root =
                GetCharacter(Player)

            if Root then
                local Distance =
                    (
                        Root.Position -
                        LocalRoot.Position
                    ).Magnitude

                if Distance <
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

local function FindTarget()
    if Config.StickyAim then
        return FindClosestToCursor()
    end

    return FindClosestPhysical()
end

--//========================================================
--// SEPARATE X/Y PREDICTION
--//========================================================

local function GetPredictedPosition(
    Position,
    Velocity
)
    local X =
        Position.X +
        (
            Velocity.X *
            Config.PredictionX
        )

    -- Inverted Y prediction
    local Y =
        Position.Y -
        (
            Velocity.Y *
            Config.PredictionY
        )

    -- Z intentionally has no prediction
    local Z = Position.Z

    return Vector3.new(
        X,
        Y,
        Z
    )
end

--//========================================================
--// ADAPTIVE THIRD-PERSON OFFSET
--//========================================================

local function GetAdaptiveOffset(Root)
    local LocalCharacter =
        LocalPlayer.Character

    if not LocalCharacter then
        return Config.AimOffset
    end

    local LocalRoot =
        LocalCharacter:FindFirstChild(
            "HumanoidRootPart"
        )

    if not LocalRoot then
        return Config.AimOffset
    end

    local Distance =
        (
            Root.Position -
            LocalRoot.Position
        ).Magnitude

    local Offset =
        Config.AimOffset *
        (
            Distance /
            Config.ReferenceDistance
        )

    return math.clamp(
        Offset,
        -100,
        100
    )
end

--//========================================================
--// AIM POSITION
--//========================================================

local function GetAimPosition(Player)
    local Character, Humanoid, Root =
        GetCharacter(Player)

    if not Character
        or not Humanoid
        or not Root then

        return nil
    end

    local Velocity =
        Root.AssemblyLinearVelocity

    -- First person = Head
    if Config.CameraMode ==
        "First Person" then

        local Head =
            Character:FindFirstChild(
                "Head"
            )

        if not Head then
            return nil
        end

        return GetPredictedPosition(
            Head.Position,
            Velocity
        )
    end

    -- Third person = Root
    local Predicted =
        GetPredictedPosition(
            Root.Position,
            Velocity
        )

    local AdaptiveOffset =
        GetAdaptiveOffset(Root)

    local AimPosition =
        Predicted -
        Vector3.new(
            0,
            AdaptiveOffset,
            0
        )

    -- Above-target correction
    if Config.AboveTargetCorrection then
        local CameraY =
            Camera.CFrame.Position.Y

        local TargetY =
            Predicted.Y

        local VerticalDifference =
            CameraY - TargetY

        if VerticalDifference > 0 then
            local Correction =
                VerticalDifference *
                Config.AboveTargetStrength

            Correction =
                math.clamp(
                    Correction,
                    0,
                    Config.AboveTargetMaxCorrection
                )

            AimPosition =
                AimPosition +
                Vector3.new(
                    0,
                    Correction,
                    0
                )
        end
    end

    return AimPosition
end

--//========================================================
--// LOCK
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

    local Target =
        FindTarget()

    if not Target then
        return
    end

    LockedTarget =
        Target

    Locked = true
end

--//========================================================
--// CONTROLLER BUTTONS
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

--//========================================================
--// SET LOCK BUTTON
--//========================================================

AddConnection(
    SetLockButton.Activated:Connect(function()
        WaitingForBind = true

        SetLockButton.Text =
            "PRESS CONTROLLER BUTTON"

        BindStatus.Text =
            "Press a supported controller input"
    end)
)

AddConnection(
    UserInputService.InputBegan:Connect(
        function(Input, GameProcessed)
            if GameProcessed then
                return
            end

            if Input.UserInputType ~=
                Enum.UserInputType.Gamepad1 then

                return
            end

            local KeyCode =
                Input.KeyCode

            if WaitingForBind then
                if IsSupportedButton(
                    KeyCode
                ) then

                    Config.LockButton =
                        KeyCode

                    LockButtonLabel.Text =
                        KeyCode.Name

                    WaitingForBind =
                        false

                    SetLockButton.Text =
                        "SET LOCK BUTTON"

                    BindStatus.Text =
                        "Bound to " ..
                        KeyCode.Name
                end

                return
            end

            if KeyCode ==
                Config.LockButton then

                Lock()
            end
        end
    )
)

--//========================================================
--// THUMBSTICK BINDING
--//========================================================

local StickPressed = {
    [Enum.KeyCode.Thumbstick1] = false,
    [Enum.KeyCode.Thumbstick2] = false,
}

AddConnection(
    UserInputService.InputChanged:Connect(
        function(Input)
            if not WaitingForBind then
                return
            end

            if Input.UserInputType ~=
                Enum.UserInputType.Gamepad1 then

                return
            end

            if Input.KeyCode ~=
                Enum.KeyCode.Thumbstick1
                and Input.KeyCode ~=
                Enum.KeyCode.Thumbstick2 then

                return
            end

            local Position =
                Input.Position

            local Magnitude =
                Vector2.new(
                    Position.X,
                    Position.Y
                ).Magnitude

            if Magnitude > 0.65 then
                if not StickPressed[
                    Input.KeyCode
                ] then

                    Config.LockButton =
                        Input.KeyCode

                    LockButtonLabel.Text =
                        Input.KeyCode.Name

                    WaitingForBind =
                        false

                    SetLockButton.Text =
                        "SET LOCK BUTTON"

                    BindStatus.Text =
                        "Bound to " ..
                        Input.KeyCode.Name

                    StickPressed[
                        Input.KeyCode
                    ] = true
                end
            else
                StickPressed[
                    Input.KeyCode
                ] = false
            end
        end
    )
)

--//========================================================
--// CAMERA RENDER LOCK
--//========================================================

local RenderName =
    "XenonCameraLock"

pcall(function()
    RunService:UnbindFromRenderStep(
        RenderName
    )
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

        if not IsValidTarget(
            LockedTarget
        ) then

            Unlock()
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
            Camera.CFrame.Position

        local Direction =
            AimPosition -
            CameraPosition

        if Direction.Magnitude <= 0.001 then
            return
        end

        local DesiredCFrame =
            CFrame.lookAt(
                CameraPosition,
                AimPosition
            )

        if Config.Smoothing <= 0 then
            Camera.CFrame =
                DesiredCFrame
        else
            local Alpha =
                math.clamp(
                    1 /
                    (
                        Config.Smoothing +
                        1
                    ),
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
--// ESP COLOR
--//========================================================

local function GetTeamColor(Player)
    if Player.Team then
        return Player.Team.TeamColor.Color
    end

    return Color3.fromRGB(
        255,
        255,
        255
    )
end

--//========================================================
--// ESP CLEANUP
--//========================================================

local function CleanupESP(Player)
    local Data =
        ESPObjects[Player]

    if not Data then
        return
    end

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

--//========================================================
--// ESP COLOR UPDATE
--//========================================================

local function ApplyESPColor(Player)
    local Data =
        ESPObjects[Player]

    if not Data then
        return
    end

    local Color =
        GetTeamColor(Player)

    if Data.NameLabel then
        Data.NameLabel.TextColor3 =
            Color
    end

    if Data.DistanceLabel then
        Data.DistanceLabel.TextColor3 =
            Color
    end

    if Data.Highlight then
        Data.Highlight.OutlineColor =
            Color
    end
end

--//========================================================
--// CREATE ESP
--//========================================================

local function CreateESP(
    Player,
    Character
)
    if Player == LocalPlayer then
        return
    end

    if not Config.ESPEnabled then
        return
    end

    if Config.ESPWhitelistCheck
        and IsWhitelisted(Player) then

        return
    end

    CleanupESP(Player)

    local Head =
        Character:FindFirstChild(
            "Head"
        )

    local Root =
        Character:FindFirstChild(
            "HumanoidRootPart"
        )

    if not Head or not Root then
        return
    end

    local Data = {}

    --// NAME
    if Config.ESPShowName then
        local Billboard =
            Instance.new(
                "BillboardGui"
            )

        Billboard.Name =
            "XenonName"

        Billboard.Adornee =
            Head

        Billboard.AlwaysOnTop =
            true

        Billboard.Size =
            UDim2.fromOffset(
                180,
                22
            )

        Billboard.StudsOffset =
            Vector3.new(
                0,
                2.7,
                0
            )

        Billboard.Parent =
            Head

        local Label =
            Instance.new(
                "TextLabel"
            )

        Label.BackgroundTransparency =
            1

        Label.Size =
            UDim2.fromScale(
                1,
                1
            )

        Label.Font =
            Enum.Font.Gotham

        Label.Text =
            Player.DisplayName

        Label.TextSize =
            9

        Label.TextStrokeTransparency =
            0.5

        Label.TextColor3 =
            Color3.fromRGB(
                255,
                255,
                255
            )

        Label.Parent =
            Billboard

        Data.NameBillboard =
            Billboard

        Data.NameLabel =
            Label
    end

    --// DISTANCE
    local DistanceBillboard =
        Instance.new(
            "BillboardGui"
        )

    DistanceBillboard.Name =
        "XenonDistance"

    DistanceBillboard.Adornee =
        Root

    DistanceBillboard.AlwaysOnTop =
        true

    DistanceBillboard.Size =
        UDim2.fromOffset(
            150,
            20
        )

    DistanceBillboard.StudsOffset =
        Vector3.new(
            0,
            -3,
            0
        )

    DistanceBillboard.Parent =
        Root

    local DistanceLabel =
        Instance.new(
            "TextLabel"
        )

    DistanceLabel.BackgroundTransparency =
        1

    DistanceLabel.Size =
        UDim2.fromScale(
            1,
            1
        )

    DistanceLabel.Font =
        Enum.Font.Gotham

    DistanceLabel.TextSize =
        9

    DistanceLabel.TextStrokeTransparency =
        0.5

    DistanceLabel.TextColor3 =
        Color3.fromRGB(
            255,
            255,
            255
        )

    DistanceLabel.Parent =
        DistanceBillboard

    Data.DistanceBillboard =
        DistanceBillboard

    Data.DistanceLabel =
        DistanceLabel

    --// OUTLINE
    if Config.ESPShowOutline then
        local Highlight =
            Instance.new(
                "Highlight"
            )

        Highlight.Name =
            "XenonHighlight"

        Highlight.Adornee =
            Character

        Highlight.DepthMode =
            Enum.HighlightDepthMode.AlwaysOnTop

        Highlight.FillTransparency =
            1

        Highlight.OutlineTransparency =
            0

        Highlight.Parent =
            Character

        Data.Highlight =
            Highlight
    end

    ESPObjects[Player] =
        Data

    ApplyESPColor(Player)
end

--//========================================================
--// ESP UPDATE
--//========================================================

local function UpdateESP(Player)
    local Data =
        ESPObjects[Player]

    if not Data then
        return
    end

    if not Config.ESPEnabled then
        CleanupESP(Player)
        return
    end

    if Config.ESPWhitelistCheck
        and IsWhitelisted(Player) then

        CleanupESP(Player)
        return
    end

    local Character,
        Humanoid,
        Root =
        GetCharacter(Player)

    if not Character
        or not Humanoid
        or not Root then

        CleanupESP(Player)
        return
    end

    local LocalCharacter =
        LocalPlayer.Character

    local LocalRoot =
        LocalCharacter
        and LocalCharacter:
        FindFirstChild(
            "HumanoidRootPart"
        )

    if LocalRoot
        and Data.DistanceLabel then

        local Distance =
            math.floor(
                (
                    Root.Position -
                    LocalRoot.Position
                ).Magnitude
            )

        Data.DistanceLabel.Text =
            tostring(Distance) ..
            " studs"
    end

    ApplyESPColor(Player)
end

--//========================================================
--// ESP CHARACTER TRACKING
--//========================================================

local function OnESPCharacter(
    Player,
    Character
)
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

        if Player.Character ~=
            Character then

            return
        end

        if Config.ESPEnabled then
            CreateESP(
                Player,
                Character
            )
        end
    end)
end

local function TrackESPPlayer(Player)
    if Player == LocalPlayer then
        return
    end

    if ESPCharacterConnections[
        Player
    ] then

        ESPCharacterConnections[
            Player
        ]:Disconnect()
    end

    local Connection =
        Player.CharacterAdded:
        Connect(function(Character)

            CleanupESP(Player)

            OnESPCharacter(
                Player,
                Character
            )
        end)

    ESPCharacterConnections[
        Player
    ] = Connection

    AddConnection(Connection)

    if Player.Character then
        OnESPCharacter(
            Player,
            Player.Character
        )
    end
end

for _, Player in ipairs(
    Players:GetPlayers()
) do
    TrackESPPlayer(Player)
end

AddConnection(
    Players.PlayerAdded:Connect(
        function(Player)
            TrackESPPlayer(Player)
        end
    )
)

AddConnection(
    Players.PlayerRemoving:Connect(
        function(Player)
            CleanupESP(Player)

            if ESPCharacterConnections[
                Player
            ] then

                ESPCharacterConnections[
                    Player
                ]:Disconnect()

                ESPCharacterConnections[
                    Player
                ] = nil
            end
        end
    )
)

--//========================================================
--// LOCAL RESPAWN
--//========================================================

AddConnection(
    LocalPlayer.CharacterAdded:
    Connect(function()
        Unlock()
    end)
)

--//========================================================
--// ESP REFRESH
--//========================================================

local function RefreshAllESP()
    for _, Player in ipairs(
        Players:GetPlayers()
    ) do

        if Player ~= LocalPlayer then
            CleanupESP(Player)

            if Config.ESPEnabled
                and not (
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

local LastESPEnabled =
    Config.ESPEnabled

local LastESPName =
    Config.ESPShowName

local LastESPOutline =
    Config.ESPShowOutline

local LastESPWhitelist =
    Config.ESPWhitelistCheck

AddConnection(
    RunService.Heartbeat:Connect(
        function()

            if LastESPEnabled ~=
                Config.ESPEnabled
                or LastESPName ~=
                Config.ESPShowName
                or LastESPOutline ~=
                Config.ESPShowOutline
                or LastESPWhitelist ~=
                Config.ESPWhitelistCheck then

                LastESPEnabled =
                    Config.ESPEnabled

                LastESPName =
                    Config.ESPShowName

                LastESPOutline =
                    Config.ESPShowOutline

                LastESPWhitelist =
                    Config.ESPWhitelistCheck

                RefreshAllESP()
            end
        end
    )
)

--//========================================================
--// ESP PERIODIC UPDATE
--//========================================================

local HeartbeatCounter = 0

AddConnection(
    RunService.Heartbeat:Connect(
        function()

            HeartbeatCounter += 1

            if HeartbeatCounter < 4 then
                return
            end

            HeartbeatCounter = 0

            for _, Player in ipairs(
                Players:GetPlayers()
            ) do

                if Player ~= LocalPlayer then
                    UpdateESP(Player)
                end
            end
        end
    )
)

--//========================================================
--// INITIAL TAB
--//========================================================

SwitchTab("AIM")

LockButtonLabel.Text =
    Config.LockButton.Name

--//========================================================
--// CLEANUP
--//========================================================

_G.XenonCleanup = function()
    Locked = false
    LockedTarget = nil

    pcall(function()
        RunService:UnbindFromRenderStep(
            RenderName
        )
    end)

    for Player in pairs(
        ESPObjects
    ) do

        CleanupESP(Player)
    end

    for Player, Connection in pairs(
        ESPCharacterConnections
    ) do

        pcall(function()
            Connection:Disconnect()
        end)

        ESPCharacterConnections[
            Player
        ] = nil
    end

    DisconnectAll()

    if ScreenGui then
        ScreenGui:Destroy()
    end
end

--//========================================================
--// DONE
--//========================================================

print(
    "Xenon Controller Camera Lock loaded."
)

print(
    "Lock Button:",
    Config.LockButton.Name
)

print(
    "Prediction X:",
    Config.PredictionX
)

print(
    "Prediction Y:",
    Config.PredictionY
)
