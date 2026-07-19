local Players             = game:GetService("Players")
local UserInputService    = game:GetService("UserInputService")
local StarterGui          = game:GetService("StarterGui")
local GuiService          = game:GetService("GuiService")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")
local TweenService        = game:GetService("TweenService")
local TextService = game:GetService("TextService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

-- Config
local Config = {
    ScanInterval     = 0.05,
    CastHoldTime     = 1.0,
    CastCooldown     = 0.5,
    CastX            = 0.5,
    CastY            = 0.5,
    CastTimeout      = 5,
    BarGreenR        = 113, BarGreenG = 228, BarGreenB = 143,
    BarRedR          = 238, BarRedG   = 121, BarRedB   = 117,
    ColorTolerance   = 20,
    TapHoldTime      = 0.2,
    FishTapDuration  = 0.01,
    ClickPerFish     = 1,
    ClickDelay       = 0.04,
    FishCooldown     = 0.05,
    HotspotRadius    = 15,
    TracerUpdateRate = 0.1,
	TapOffsetX = 0, 
    TapOffsetY = 0, 
    AutoJumpEnabled      = false,
    AutoJumpMinDelay     = 60.0,
    AutoJumpMaxDelay     = 300.0, 
    AutoJumpSpamEnabled  = true, 
    AutoJumpSpamMinDelay = 300.0, 
    AutoJumpSpamMaxDelay = 600.0,  

	FishLimit        = 100,  
    FishLimitEnabled = false, 
	
	HotspotPauseEnabled    = true,
    HotspotPauseRadius     = 60,
    HotspotDelayMinTime    = 3.0,
    HotspotDelayMaxTime    = 8.0,

	DragMoveSteps    = 8,      -- jumlah step gerakan biar smooth, bukan teleport
	DragMoveDelay    = 0.02,   -- delay antar step (detik)
	DragHoldAfter    = 0.05,   -- delay setelah nyampe target sebelum mouse up
	DragRecheckDelay = 0.05,   -- delay antar re-check posisi TargetFrame
	DragPosTolerance = 3,      -- kalau target pindah kurang dari ini (px), skip drag ulang
}

local ConfigMeta = {
    { key = "CastHoldTime",     label = "Cast Hold Time",     min = 0.1,  max = 3.0,  step = 0.1  },
    { key = "CastCooldown",     label = "Cast Cooldown",      min = 0.1,  max = 2.0,  step = 0.1  },
    { key = "CastTimeout",      label = "Cast Timeout",       min = 5,    max = 60,   step = 1    },
    { key = "CastX",            label = "Cast X (0-1)",       min = 0.0,  max = 1.0,  step = 0.05 },
    { key = "CastY",            label = "Cast Y (0-1)",       min = 0.0,  max = 1.0,  step = 0.05 },
    { key = "ScanInterval",     label = "Scan Interval",      min = 0.01, max = 0.5,  step = 0.01 },
    { key = "FishTapDuration",  label = "Fish Tap Duration",  min = 0.01, max = 0.3,  step = 0.01 },
    { key = "ClickPerFish",     label = "Click Per Fish",     min = 1,    max = 10,   step = 1    },
    { key = "ClickDelay",       label = "Click Delay",        min = 0.01, max = 0.2,  step = 0.01 },
    { key = "FishCooldown",     label = "Fish Cooldown",      min = 0.01, max = 0.5,  step = 0.01 },
    { key = "HotspotRadius",    label = "Hotspot Radius",     min = 5,    max = 100,  step = 5    },
    { key = "TracerUpdateRate", label = "Tracer Update Rate", min = 0.05, max = 1.0,  step = 0.05 },
    { key = "ColorTolerance",   label = "Color Tolerance",    min = 5,    max = 60,   step = 5    },
	{ key = "TapOffsetX", label = "Tap Offset X (px)", min = -200, max = 200, step = 1 },
    { key = "TapOffsetY", label = "Tap Offset Y (px)", min = -200, max = 200, step = 1 },
    { key = "AutoJumpMinDelay",     label = "Jump Min Delay (s)",   min = 60.0,  max = 300.0, step = 10.0 },
    { key = "AutoJumpMaxDelay",     label = "Jump Max Delay (s)",   min = 60.0,  max = 300.0, step = 10.0 },
    { key = "AutoJumpSpamMinDelay", label = "Spam Jump Min (s)",    min = 120.0, max = 600.0, step = 30.0 },
    { key = "AutoJumpSpamMaxDelay", label = "Spam Jump Max (s)",    min = 300.0, max = 900.0, step = 30.0 },
	{ key = "FishLimit",            label = "Fish Limit (ekor)",    min = 1,     max = 1000,   step = 1    },
	{ key = "HotspotPauseRadius", label = "Hotspot Pause Radius",   min = 5,  max = 100,  step = 5  },
	{ key = "HotspotDelayMinTime", label = "Hotspot Delay Min (s)",min = 0.5, max = 30,  step = 0.5 },
    { key = "HotspotDelayMaxTime", label = "Hotspot Delay Max (s)",min = 0.5, max = 30,  step = 0.5 },
}

-- STATE
local isRunning       = false
local isPaused        = false
local pauseStartTime  = 0
local selectedRodName = nil
local fishCount       = 0
local lastCastTime    = 0
local botStartTime    = 0
local clickedFish     = {}
local tracerEnabled   = false
local tracerThread    = nil
local HotspotTracers  = {}
local activeTab       = "main"

-- STATE TAMBAHAN 
local randomCastEnabled = true
local RandomCastMinTime = 0.8
local RandomCastMaxTime = 1.0 

local randomDelayEnabled = true
local RandomDelayMinTime = 1.8
local RandomDelayMaxTime = 2.1

local autoJumpThread = nil
local hotspotWatchThread = nil
local isHotspotPaused    = false  -- pause khusus dari hotspot watcher, bukan pause manual
local hotspotPendingSince = nil   -- tick() saat kondisi baru mulai berbeda, nil = tidak ada pending
local hotspotPendingTarget = nil  -- "pause" atau "resume", apa yang akan dieksekusi kalau delay selesai
local hotspotPendingDelay  = nil 
local DebugLabel 

-- ===================== MAP HOTSPOT DATA (HARDCODE) =====================
local HotspotMapData = {
    City = {
        Vector3.new(-833.8668212890625, 19.5, 5310.61376953125),
        Vector3.new(-626.8668212890625, 19.5, 4905.61376953125),
        Vector3.new(-856.3670043945312, 19.5, 5097.6142578125),
        Vector3.new(-629.8668212890625, 19.5, 4640.11376953125),
        Vector3.new(-508.3668212890625, 19.5, 5070.61376953125),
        Vector3.new(1082, 71.5, 5498),
        Vector3.new(260, 42, 5037.7021484375),
        Vector3.new(414.5, 44.05686950683594, 4964.2021484375),
        Vector3.new(156.5, 38.831214904785156, 4983.7021484375),
        Vector3.new(531.90966796875, 44, 4976),
    },
    Island = {
        -- belum ada data
    },
    Old = {
        -- belum ada data
    },
}

local MapToggleState = { City = false, Island = false, Old = false }
local MapHotspotTracers = {} -- tracer terpisah dari HotspotTracers, supaya tidak saling clear

-- THEME
local Theme = {
    Bg        = Color3.fromRGB(3, 5, 5),
    Panel     = Color3.fromRGB(27, 35, 39),
    PanelAlt  = Color3.fromRGB(32, 32, 38),
    Accent    = Color3.fromRGB(244, 186, 67),
    AccentHov = Color3.fromRGB(212, 145, 12),
    Danger    = Color3.fromRGB(239, 68, 68),
    Green     = Color3.fromRGB(34, 197, 94),
    Yellow    = Color3.fromRGB(234, 179, 8),
    Text      = Color3.fromRGB(240, 240, 248),
    SubText   = Color3.fromRGB(130, 130, 145),
    Border    = Color3.fromRGB(50, 50, 62),
    Header    = Color3.fromRGB(3, 5, 5),
    TabActive = Color3.fromRGB(244, 186, 67),
    TabInact  = Color3.fromRGB(26, 26, 31),
    InputBg   = Color3.fromRGB(20, 20, 26),
}

-- CLEANUP
if PlayerGui:FindFirstChild("Fisher") then
    PlayerGui:FindFirstChild("Fisher"):Destroy()
end

-- SCREEN GUI
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name           = "Fisher"
ScreenGui.ResetOnSpawn   = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent         = PlayerGui

-- MAIN FRAME
local Main = Instance.new("Frame")
Main.Name             = "Main"
Main.Size             = UDim2.new(0, 300, 0, 420)
Main.Position         = UDim2.new(0.5, -150, 0.5, -210)
Main.BackgroundColor3 = Theme.Bg
Main.BorderSizePixel  = 0
Main.ClipsDescendants = true
Main.Parent           = ScreenGui

local mainCorner = Instance.new("UICorner", Main)
mainCorner.CornerRadius = UDim.new(0, 12)

local mainStroke = Instance.new("UIStroke", Main)
mainStroke.Color     = Theme.Border
mainStroke.Thickness = 1

-- HEADER 
local Header = Instance.new("Frame")
Header.Name             = "Header"
Header.Size             = UDim2.new(1, 0, 0, 42)
Header.BackgroundColor3 = Theme.Header
Header.BorderSizePixel  = 0
Header.ZIndex           = 5
Header.Parent           = Main

local headerCorner = Instance.new("UICorner", Header)
headerCorner.CornerRadius = UDim.new(0, 12)

local headerFix = Instance.new("Frame", Header)
headerFix.Size             = UDim2.new(1, 0, 0.5, 0)
headerFix.Position         = UDim2.new(0, 0, 0.5, 0)
headerFix.BackgroundColor3 = Theme.Header
headerFix.BorderSizePixel  = 0
headerFix.ZIndex           = 4

-- === TAMBAHAN BARU: Padding Header ===
local headerPadding = Instance.new("UIPadding", Header)
headerPadding.PaddingLeft   = UDim.new(0, 14)  -- Jarak teks "Fisher" dari kiri
headerPadding.PaddingRight  = UDim.new(0, 14)  -- Jarak tombol Close dari kanan
headerPadding.PaddingTop    = UDim.new(0, 6)
headerPadding.PaddingBottom = UDim.new(0, 6)
-- ====================================

local titleLabel = Instance.new("TextLabel", Header)
titleLabel.Size                 = UDim2.new(1, 0, 1, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text                 = "Fisher"
titleLabel.TextColor3           = Theme.Text
titleLabel.TextSize             = 13
titleLabel.Font                 = Enum.Font.GothamBold
titleLabel.TextXAlignment       = Enum.TextXAlignment.Center
titleLabel.ZIndex               = 6
titleLabel.Parent               = Header

local minimizeBtn = Instance.new("TextButton", Header)
minimizeBtn.Size             = UDim2.new(0, 26, 0, 26)
-- UBAH POSISI: Beri jarak offset -56 (sebelumnya -58, karena padding kanan 14px)
minimizeBtn.Position         = UDim2.new(1, -56, 0.5, -13) 
minimizeBtn.BackgroundColor3 = Theme.PanelAlt
minimizeBtn.Text             = "−"
minimizeBtn.TextColor3       = Theme.SubText
minimizeBtn.TextSize         = 14
minimizeBtn.Font             = Enum.Font.GothamBold
minimizeBtn.BorderSizePixel  = 0
minimizeBtn.ZIndex           = 6
Instance.new("UICorner", minimizeBtn).CornerRadius = UDim.new(0, 6)

local closeBtn = Instance.new("TextButton", Header)
closeBtn.Size             = UDim2.new(0, 26, 0, 26)

closeBtn.Position         = UDim2.new(1, -28, 0.5, -13) 
closeBtn.BackgroundColor3 = Theme.Danger
closeBtn.Text             = "×"
closeBtn.TextColor3       = Theme.Text
closeBtn.TextSize         = 14
closeBtn.Font             = Enum.Font.GothamBold
closeBtn.BorderSizePixel  = 0
closeBtn.ZIndex           = 6
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)

-- TAB BAR
local TabBar = Instance.new("Frame", Main)
TabBar.Name             = "TabBar"
TabBar.Size             = UDim2.new(1, -16, 0, 32)
TabBar.Position         = UDim2.new(0, 8, 0, 48)
TabBar.BackgroundColor3 = Theme.Panel
TabBar.BorderSizePixel  = 0
TabBar.ZIndex           = 5
Instance.new("UICorner", TabBar).CornerRadius = UDim.new(0, 8)

local tabLayout = Instance.new("UIListLayout", TabBar)
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.SortOrder     = Enum.SortOrder.LayoutOrder
tabLayout.Padding       = UDim.new(0, 2)

local tabPad = Instance.new("UIPadding", TabBar)
tabPad.PaddingLeft  = UDim.new(0, 3)
tabPad.PaddingRight = UDim.new(0, 3)
tabPad.PaddingTop   = UDim.new(0, 3)
tabPad.PaddingBottom = UDim.new(0, 3)

-- CONTENT AREA
local ContentArea = Instance.new("Frame", Main)
ContentArea.Name             = "ContentArea"
ContentArea.Size             = UDim2.new(1, -16, 1, -92)
ContentArea.Position         = UDim2.new(0, 8, 0, 86)
ContentArea.BackgroundTransparency = 1
ContentArea.ClipsDescendants = true
ContentArea.ZIndex           = 2

-- TAB SYSTEM 
local tabs     = {}
local tabBtns  = {}
local tabPages = {}

local function createTab(id, label, icon, layoutOrder)

    local btn = Instance.new("TextButton", TabBar)
    btn.Size             = UDim2.new(0.25, -2, 1, 0)
    btn.BackgroundColor3 = Theme.TabInact
    btn.Text             = icon.." "..label
    btn.TextColor3       = Theme.SubText
    btn.TextSize         = 11
    btn.Font             = Enum.Font.GothamMedium
    btn.BorderSizePixel  = 0
    btn.ZIndex           = 6
    btn.LayoutOrder      = layoutOrder
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

    local page = Instance.new("ScrollingFrame", ContentArea)
    page.Name                  = id
    page.Size                  = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.BorderSizePixel       = 0
    page.ScrollBarThickness    = 2
    page.ScrollBarImageColor3  = Theme.Border
    page.CanvasSize            = UDim2.new(0, 0, 0, 0)
    page.AutomaticCanvasSize   = Enum.AutomaticSize.Y
    page.Visible               = false
    page.ZIndex                = 2

    local pageLayout = Instance.new("UIListLayout", page)
    pageLayout.SortOrder = Enum.SortOrder.LayoutOrder
    pageLayout.Padding   = UDim.new(0, 5)

    local pagePad = Instance.new("UIPadding", page)
    pagePad.PaddingBottom = UDim.new(0, 6)

    tabBtns[id]  = btn
    tabPages[id] = page
    table.insert(tabs, id)

    return btn, page
end

local function switchTab(id)
    activeTab = id
    for _, tid in ipairs(tabs) do
        local isActive = (tid == id)
        tabBtns[tid].BackgroundColor3 = isActive and Theme.TabActive or Theme.TabInact
        tabBtns[tid].TextColor3       = isActive and Theme.Text or Theme.SubText
        tabPages[tid].Visible         = isActive
    end
end

local mainTabBtn,   mainPage   = createTab("main",   "Main",   "", 1)
local tracerTabBtn, tracerPage = createTab("tracer", "Tracer", "", 2)
local configTabBtn, configPage = createTab("config", "Config", "", 3)
local commandsTabBtn, commandsPage = createTab("commands", "Cmds", "", 4)

mainTabBtn.MouseButton1Click:Connect(function()   switchTab("main")   end)
tracerTabBtn.MouseButton1Click:Connect(function() switchTab("tracer") end)
configTabBtn.MouseButton1Click:Connect(function() switchTab("config") end)
commandsTabBtn.MouseButton1Click:Connect(function() switchTab("commands") end)

-- UI HELPERS
local function makeDivider(parent, order)
    local d = Instance.new("Frame", parent)
    d.Size             = UDim2.new(1, 0, 0, 1)
    d.BackgroundColor3 = Theme.Border
    d.BorderSizePixel  = 0
    d.LayoutOrder      = order
    return d
end

local function makeCard(parent, order, height)
    local card = Instance.new("Frame", parent)
    card.Size             = UDim2.new(1, 0, 0, height or 40)
    card.BackgroundColor3 = Theme.Panel
    card.BorderSizePixel  = 0
    card.LayoutOrder      = order
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)
    return card
end

local function makeSectionLabel(parent, text, order)
    local lbl = Instance.new("TextLabel", parent)
    lbl.Size                 = UDim2.new(1, 0, 0, 18)
    lbl.BackgroundTransparency = 1
    lbl.Text                 = text
    lbl.TextColor3           = Theme.SubText
    lbl.TextSize             = 9
    lbl.Font                 = Enum.Font.GothamBold
    lbl.TextXAlignment       = Enum.TextXAlignment.Left
    lbl.LayoutOrder          = order
    local p = Instance.new("UIPadding", lbl)
    p.PaddingLeft = UDim.new(0, 2)
    return lbl
end

local function makeStatRow(parent, leftText, order)
    local card = makeCard(parent, order, 34)
    local pad  = Instance.new("UIPadding", card)
    pad.PaddingLeft  = UDim.new(0, 10)
    pad.PaddingRight = UDim.new(0, 10)

    local left = Instance.new("TextLabel", card)
    left.Size                 = UDim2.new(0.5, 0, 1, 0)
    left.BackgroundTransparency = 1
    left.Text                 = leftText
    left.TextColor3           = Theme.SubText
    left.TextSize             = 10
    left.Font                 = Enum.Font.Gotham
    left.TextXAlignment       = Enum.TextXAlignment.Left

    local right = Instance.new("TextLabel", card)
    right.Size                 = UDim2.new(0.5, 0, 1, 0)
    right.Position             = UDim2.new(0.5, 0, 0, 0)
    right.BackgroundTransparency = 1
    right.Text                 = "-"
    right.TextColor3           = Theme.Text
    right.TextSize             = 10
    right.Font                 = Enum.Font.GothamBold
    right.TextXAlignment       = Enum.TextXAlignment.Right

    return right
end

local function makeButton(parent, text, color, order, height)
    local btn = Instance.new("TextButton", parent)
    btn.Size             = UDim2.new(1, 0, 0, height or 34)
    btn.BackgroundColor3 = color or Theme.Panel
    btn.Text             = text
    btn.TextColor3       = Theme.Text
    btn.TextSize         = 13
    btn.Font             = Enum.Font.GothamMedium
    btn.AutoButtonColor  = false
    btn.BorderSizePixel  = 0
    btn.LayoutOrder      = order
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15), {
            BackgroundColor3 = color and Color3.new(
                math.min(color.R + 0.08, 1),
                math.min(color.G + 0.08, 1),
                math.min(color.B + 0.08, 1)
            ) or Theme.PanelAlt
        }):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15), {
            BackgroundColor3 = color or Theme.Panel
        }):Play()
    end)
    return btn
end

local function makeButtonRow(parent, order, items)
    local row = Instance.new("Frame", parent)
    row.Size                 = UDim2.new(1, 0, 0, 34)
    row.BackgroundTransparency = 1
    row.LayoutOrder          = order

    local rowLayout = Instance.new("UIListLayout", row)
    rowLayout.FillDirection = Enum.FillDirection.Horizontal
    rowLayout.Padding       = UDim.new(0, 5)
    rowLayout.SortOrder     = Enum.SortOrder.LayoutOrder

    local btns = {}
    local count = #items
    for i, item in ipairs(items) do
        local btn = Instance.new("TextButton", row)
        btn.Size             = UDim2.new(1/count, i < count and -math.ceil(5*(count-1)/count) or 0, 1, 0)
        btn.BackgroundColor3 = item.color or Theme.Panel
        btn.Text             = item.text
        btn.TextColor3       = Theme.Text
        btn.TextSize         = 12
        btn.Font             = Enum.Font.GothamMedium
        btn.AutoButtonColor  = false
        btn.BorderSizePixel  = 0
        btn.LayoutOrder      = i
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

        btn.MouseEnter:Connect(function()
            local c = item.color or Theme.Panel
            TweenService:Create(btn, TweenInfo.new(0.15), {
                BackgroundColor3 = Color3.new(
                    math.min(c.R + 0.08, 1),
                    math.min(c.G + 0.08, 1),
                    math.min(c.B + 0.08, 1))
            }):Play()
        end)
        btn.MouseLeave:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.15), {
                BackgroundColor3 = item.color or Theme.Panel
            }):Play()
        end)

        table.insert(btns, btn)
    end
    return btns
end

-- HELPERS UI
local function notify(t, msg)
    pcall(function() StarterGui:SetCore("SendNotification", {Title=t, Text=msg, Duration=3}) end)
end

-- MAIN TAB
local o = 0

makeSectionLabel(mainPage, "STATUS", o) o+=1

local StatusValue  = makeStatRow(mainPage, "Status",      o) o+=1
local TimerValue   = makeStatRow(mainPage, "Runtime",     o) o+=1
local FishValue    = makeStatRow(mainPage, "Total Fish",  o) o+=1
local ActionValue  = makeStatRow(mainPage, "Action",      o) o+=1

StatusValue.Text = "Idle"
TimerValue.Text  = "00:00:00"
FishValue.Text   = "0"
ActionValue.Text = "-"

makeDivider(mainPage, o) o+=1

-- ============ ROD DROPDOWN SELECTOR ============
makeSectionLabel(mainPage, "ROD SELECTOR", o) o+=1

local rodDropdownCard = makeCard(mainPage, o, 40) o+=1
local rodDropdownPad = Instance.new("UIPadding", rodDropdownCard)
rodDropdownPad.PaddingLeft = UDim.new(0, 10)
rodDropdownPad.PaddingRight = UDim.new(0, 10)

local rodSelectedLabel = Instance.new("TextButton", rodDropdownCard)
rodSelectedLabel.Size = UDim2.new(1, -30, 1, 0)
rodSelectedLabel.BackgroundTransparency = 1
rodSelectedLabel.Text = "Pilih Rod..."
rodSelectedLabel.TextColor3 = Theme.SubText
rodSelectedLabel.TextSize = 11
rodSelectedLabel.Font = Enum.Font.GothamMedium
rodSelectedLabel.TextXAlignment = Enum.TextXAlignment.Left
rodSelectedLabel.AutoButtonColor = false

local rodDropdownList = Instance.new("ScrollingFrame", mainPage)
rodDropdownList.Name = "RodDropdownList"
rodDropdownList.Size = UDim2.new(1, 0, 0, 0)
rodDropdownList.Position = UDim2.new(0, 0, 0, 0)
rodDropdownList.BackgroundColor3 = Theme.Panel
rodDropdownList.BorderSizePixel = 0
rodDropdownList.ScrollBarThickness = 3
rodDropdownList.ScrollBarImageColor3 = Theme.Border
rodDropdownList.Visible = false
rodDropdownList.ZIndex = 10
rodDropdownList.LayoutOrder = o
o += 1
Instance.new("UICorner", rodDropdownList).CornerRadius = UDim.new(0, 8)
local rodListStroke = Instance.new("UIStroke", rodDropdownList)
rodListStroke.Color = Theme.Border
rodListStroke.Thickness = 1

local rodListLayout = Instance.new("UIListLayout", rodDropdownList)
rodListLayout.SortOrder = Enum.SortOrder.LayoutOrder
rodListLayout.Padding = UDim.new(0, 2)

local rodListPad = Instance.new("UIPadding", rodDropdownList)
rodListPad.PaddingLeft = UDim.new(0, 4)
rodListPad.PaddingRight = UDim.new(0, 4)
rodListPad.PaddingTop = UDim.new(0, 4)
rodListPad.PaddingBottom = UDim.new(0, 4)

local isDropdownOpen = false
local dropdownItems = {}

local function renderDropdownList(rodList)
    for _, item in ipairs(dropdownItems) do
        item:Destroy()
    end
    dropdownItems = {}

    if #rodList == 0 then
        local emptyItem = Instance.new("TextButton", rodDropdownList)
        emptyItem.Size = UDim2.new(1, 0, 0, 30)
        emptyItem.BackgroundColor3 = Theme.PanelAlt
        emptyItem.Text = "Tidak ada rod"
        emptyItem.TextColor3 = Theme.SubText
        emptyItem.TextSize = 10
        emptyItem.Font = Enum.Font.Gotham
        emptyItem.AutoButtonColor = false
        emptyItem.BorderSizePixel = 0
        Instance.new("UICorner", emptyItem).CornerRadius = UDim.new(0, 6)
        table.insert(dropdownItems, emptyItem)
        return
    end

    for i, name in ipairs(rodList) do
        local isSelected = (name == selectedRodName)

        local item = Instance.new("TextButton", rodDropdownList)
        item.Size = UDim2.new(1, 0, 0, 32)
        item.BackgroundColor3 = isSelected and Theme.Accent or Theme.PanelAlt
        item.Text = ""
        item.AutoButtonColor = false
        item.BorderSizePixel = 0
        item.LayoutOrder = i
        Instance.new("UICorner", item).CornerRadius = UDim.new(0, 6)

        local itemLabel = Instance.new("TextLabel", item)
        itemLabel.Size = UDim2.new(1, -8, 1, 0)
        itemLabel.Position = UDim2.new(0, 8, 0, 0)
        itemLabel.BackgroundTransparency = 1
        itemLabel.Text = name
        itemLabel.TextColor3 = isSelected and Theme.Text or Theme.SubText
        itemLabel.TextSize = 11
        itemLabel.Font = isSelected and Enum.Font.GothamBold or Enum.Font.Gotham
        itemLabel.TextXAlignment = Enum.TextXAlignment.Left

        item.MouseButton1Click:Connect(function()
            selectedRodName = name
            rodSelectedLabel.Text = name
            rodSelectedLabel.TextColor3 = Theme.Text
            rodSelectedLabel.Font = Enum.Font.GothamBold
            DebugLabel.Text = "Rod: " .. name
            closeDropdown()
            renderDropdownList(rodList)
        end)

        item.MouseEnter:Connect(function()
            if name ~= selectedRodName then
                TweenService:Create(item, TweenInfo.new(0.12), {BackgroundColor3 = Theme.Border}):Play()
            end
        end)
        item.MouseLeave:Connect(function()
            if name ~= selectedRodName then
                TweenService:Create(item, TweenInfo.new(0.12), {BackgroundColor3 = Theme.PanelAlt}):Play()
            end
        end)

        table.insert(dropdownItems, item)
    end

    local totalHeight = #rodList * 34 + 8
    rodDropdownList.CanvasSize = UDim2.new(0, 0, 0, totalHeight)
end

local function openDropdown()
    if isDropdownOpen then return end
    isDropdownOpen = true
    -- Hapus atau ubah teks ini jika ingin menunjukkan status terbuka, tapi sekarang fokusnya adalah scan otomatis
    -- rodArrow.Text = "^" -- GANTI BARIS INI ATAU HAPUS KOMENTAR
    local absoluteY = rodDropdownCard.AbsolutePosition.Y + rodDropdownCard.AbsoluteSize.Y
    local guiY = absoluteY - Main.AbsolutePosition.Y

    -- Lakukan scan otomatis saat membuka dropdown
    local rods = scanRods and scanRods() or {}
    renderDropdownList(rods) -- Gunakan hasil scan langsung

    local maxHeight = math.min(180, #dropdownItems * 34 + 16) -- Gunakan jumlah item hasil scan
    rodDropdownList.Position = UDim2.new(0, 0, 0, guiY + 4)
    rodDropdownList.Visible = true
    TweenService:Create(rodDropdownList, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
        Size = UDim2.new(1, 0, 0, maxHeight)
    }):Play()
end

local function closeDropdown()
    if not isDropdownOpen then return end
    isDropdownOpen = false
    rodArrow.Text = "v"

    TweenService:Create(rodDropdownList, TweenInfo.new(0.15, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
        Size = UDim2.new(1, 0, 0, 0)
    }):Play()

    task.delay(0.15, function()
        if not isDropdownOpen then
            rodDropdownList.Visible = false
        end
    end)
end

rodSelectedLabel.MouseButton1Click:Connect(function()
    if isDropdownOpen then
        closeDropdown()
    else
        -- Hapus bagian ini karena scan sekarang otomatis di openDropdown
        -- local rods = scanRods and scanRods() or {}
        -- renderDropdownList(rods)
        openDropdown() -- Panggil openDropdown, yang sekarang melakukan scan
    end
end)

UserInputService.InputBegan:Connect(function(input)
    if not isDropdownOpen then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then
        local mousePos = UserInputService:GetMouseLocation()
        local dropPos = rodDropdownList.AbsolutePosition
        local dropSize = rodDropdownList.AbsoluteSize
        local cardPos = rodDropdownCard.AbsolutePosition
        local cardSize = rodDropdownCard.AbsoluteSize

        local inDropdown = mousePos.X >= dropPos.X and mousePos.X <= dropPos.X + dropSize.X
                       and mousePos.Y >= dropPos.Y and mousePos.Y <= dropPos.Y + dropSize.Y
        local inCard = mousePos.X >= cardPos.X and mousePos.X <= cardPos.X + cardSize.X
                   and mousePos.Y >= cardPos.Y and mousePos.Y <= cardPos.Y + cardSize.Y

        if not inDropdown and not inCard then
            closeDropdown()
        end
    end
end)

-- Init kosong
rodSelectedLabel.Text = "Pilih Rod..."

makeDivider(mainPage, o) o+=1
makeSectionLabel(mainPage, "CONTROLS", o) o+=1

local ctrlBtns = makeButtonRow(mainPage, o, {
    { text = "START", color = Theme.Accent },
    { text = "Reset", color = Theme.PanelAlt },
}) o+=1
local StartBtn = ctrlBtns[1]
local ResetBtn = ctrlBtns[2]

local PauseBtn = makeButton(mainPage, "Pause", Theme.PanelAlt, o) o+=1

makeDivider(mainPage, o) o+=1

local DebugCard = makeCard(mainPage, o, 28) o+=1
local debugPad  = Instance.new("UIPadding", DebugCard)
debugPad.PaddingLeft = UDim.new(0, 8)
DebugLabel = Instance.new("TextLabel", DebugCard)
DebugLabel.Size                 = UDim2.new(1, -8, 1, 0)
DebugLabel.BackgroundTransparency = 1
DebugLabel.Text                 = "Log: Siap. Pilih rod & tekan START."
DebugLabel.TextColor3           = Theme.SubText
DebugLabel.TextSize             = 9
DebugLabel.Font                 = Enum.Font.Gotham
DebugLabel.TextXAlignment       = Enum.TextXAlignment.Left
DebugLabel.TextTruncate         = Enum.TextTruncate.AtEnd

-- TRACER TAB
local to = 0
makeSectionLabel(tracerPage, "HOTSPOT INFO", to) to+=1

local HotspotStatusValue = makeStatRow(tracerPage, "Status",        to) to+=1
local HotspotCountValue  = makeStatRow(tracerPage, "Zona Aktif",    to) to+=1
local HotspotNearValue   = makeStatRow(tracerPage, "Zona Terdekat", to) to+=1
local HotspotDistValue   = makeStatRow(tracerPage, "Jarak",         to) to+=1

HotspotStatusValue.Text = "Tidak ada"
HotspotCountValue.Text  = "0"
HotspotNearValue.Text   = "-"
HotspotDistValue.Text   = "-"

makeDivider(tracerPage, to) to+=1
makeSectionLabel(tracerPage, "TRACER CONTROL", to) to+=1

local TracerBtn = makeButton(tracerPage, "Hotspot Tracer: OFF", Theme.PanelAlt, to) to+=1

makeDivider(tracerPage, to) to+=1
makeSectionLabel(tracerPage, "MAP HOTSPOT (KOORDINAT TETAP)", to) to+=1

local mapToggleBtns = {}

local function createMapToggleRow(mapKey, order)
    local row = Instance.new("Frame", tracerPage)
    row.Size             = UDim2.new(1, 0, 0, 34)
    row.BackgroundColor3 = Theme.Panel
    row.BorderSizePixel  = 0
    row.LayoutOrder      = order
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)

    local pad = Instance.new("UIPadding", row)
    pad.PaddingLeft  = UDim.new(0, 10)
    pad.PaddingRight = UDim.new(0, 10)

    local pointCount = #HotspotMapData[mapKey]
    local lbl = Instance.new("TextLabel", row)
    lbl.Size                 = UDim2.new(1, -60, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text                 = string.format("Map %s (%d titik)", mapKey, pointCount)
    lbl.TextColor3           = Theme.Text
    lbl.TextSize             = 11
    lbl.Font                 = Enum.Font.GothamMedium
    lbl.TextXAlignment       = Enum.TextXAlignment.Left

    local btnToggle = Instance.new("TextButton", row)
    btnToggle.Size             = UDim2.new(0, 48, 0, 22)
    btnToggle.Position         = UDim2.new(1, -48, 0.5, -11)
    btnToggle.BackgroundColor3 = Theme.PanelAlt
    btnToggle.Text             = "OFF"
    btnToggle.TextColor3       = Theme.SubText
    btnToggle.TextSize         = 9
    btnToggle.Font             = Enum.Font.GothamBold
    btnToggle.AutoButtonColor  = false
    btnToggle.BorderSizePixel  = 0
    Instance.new("UICorner", btnToggle).CornerRadius = UDim.new(0, 11)

    btnToggle.MouseButton1Click:Connect(function()
        MapToggleState[mapKey] = not MapToggleState[mapKey]
        if MapToggleState[mapKey] then
            btnToggle.Text             = "ON"
            btnToggle.BackgroundColor3 = Theme.Green
            btnToggle.TextColor3       = Theme.Text
            DebugLabel.Text = string.format("Map %s tracer: ON", mapKey)
        else
            btnToggle.Text             = "OFF"
            btnToggle.BackgroundColor3 = Theme.PanelAlt
            btnToggle.TextColor3       = Theme.SubText
            DebugLabel.Text = string.format("Map %s tracer: OFF", mapKey)
        end
    end)

    mapToggleBtns[mapKey] = btnToggle
    return row
end

createMapToggleRow("City",   to) to+=1
createMapToggleRow("Island", to) to+=1
createMapToggleRow("Old",    to) to+=1

makeDivider(tracerPage, to) to+=1
makeSectionLabel(tracerPage, "KETERANGAN WARNA", to) to+=1

local function makeLegendRow(parent, color, text, order)
    local row = Instance.new("Frame", parent)
    row.Size                 = UDim2.new(1, 0, 0, 28)
    row.BackgroundColor3     = Theme.Panel
    row.BorderSizePixel      = 0
    row.LayoutOrder          = order
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)

    local pad = Instance.new("UIPadding", row)
    pad.PaddingLeft = UDim.new(0, 10)

    local dot = Instance.new("Frame", row)
    dot.Size             = UDim2.new(0, 8, 0, 8)
    dot.Position         = UDim2.new(0, 0, 0.5, -4)
    dot.BackgroundColor3 = color
    dot.BorderSizePixel  = 0
    Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

    local lbl = Instance.new("TextLabel", row)
    lbl.Size                 = UDim2.new(1, -20, 1, 0)
    lbl.Position             = UDim2.new(0, 16, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text                 = text
    lbl.TextColor3           = Theme.SubText
    lbl.TextSize             = 10
    lbl.Font                 = Enum.Font.Gotham
    lbl.TextXAlignment       = Enum.TextXAlignment.Left
end

makeLegendRow(tracerPage, Color3.fromRGB(255,255,255),  "Putih: Hotspot terdekat",      to) to+=1
makeLegendRow(tracerPage, Color3.fromRGB(50,255,100),   "Hijau:  Dalam radius bonus",     to) to+=1
makeLegendRow(tracerPage, Color3.fromRGB(255,220,50),   "Kuning: Jarak 16–50 studs",      to) to+=1
makeLegendRow(tracerPage, Color3.fromRGB(255,80,80),    "Merah: Jarak > 50 studs",       to) to+=1

-- CONFIG TAB 
local co = 0

makeSectionLabel(configPage, "PENGATURAN BOT", co) co+=1

-- CARD RANDOM CAST (di configPage)
local randomCard = Instance.new("Frame", configPage)
randomCard.Size             = UDim2.new(1, 0, 0, 96)
randomCard.BackgroundColor3 = Theme.Panel
randomCard.BorderSizePixel  = 0
randomCard.LayoutOrder      = co
co += 1
Instance.new("UICorner", randomCard).CornerRadius = UDim.new(0, 8)

local rcPad = Instance.new("UIPadding", randomCard)
rcPad.PaddingLeft   = UDim.new(0, 10)
rcPad.PaddingRight  = UDim.new(0, 10)
rcPad.PaddingTop    = UDim.new(0, 8)
rcPad.PaddingBottom = UDim.new(0, 8)

local rcTitle = Instance.new("TextLabel", randomCard)
rcTitle.Size                 = UDim2.new(0.65, 0, 0, 20)
rcTitle.Position             = UDim2.new(0, 0, 0, 0)
rcTitle.BackgroundTransparency = 1
rcTitle.Text                 = "Random Cast Hold"
rcTitle.TextColor3           = Theme.Text
rcTitle.TextSize             = 11
rcTitle.Font                 = Enum.Font.GothamMedium
rcTitle.TextXAlignment       = Enum.TextXAlignment.Left

local rcDesc = Instance.new("TextLabel", randomCard)
rcDesc.Size                 = UDim2.new(1, -60, 0, 14)
rcDesc.Position             = UDim2.new(0, 0, 0, 24)
rcDesc.BackgroundTransparency = 1
rcDesc.Text                 = string.format("Range: %.1f – %.1f detik", RandomCastMinTime, RandomCastMaxTime)
rcDesc.TextColor3           = Theme.SubText
rcDesc.TextSize             = 9
rcDesc.Font                 = Enum.Font.Gotham
rcDesc.TextXAlignment       = Enum.TextXAlignment.Left

local rcToggle = Instance.new("TextButton", randomCard)
rcToggle.Size             = UDim2.new(0, 52, 0, 24)
rcToggle.Position         = UDim2.new(1, -52, 0, 0)
rcToggle.BackgroundColor3 = randomCastEnabled and Theme.Green or Theme.PanelAlt
rcToggle.Text = randomCastEnabled and "ON" or "OFF"
rcToggle.TextColor3 = randomCastEnabled and Theme.Text or Theme.SubText
rcToggle.TextSize         = 10
rcToggle.Font             = Enum.Font.GothamBold
rcToggle.AutoButtonColor  = false
rcToggle.BorderSizePixel  = 0
Instance.new("UICorner", rcToggle).CornerRadius = UDim.new(0, 12)

-- HELPER buat input row (Min / Max)
local function makeRcInputRow(parentCard, descLabel, labelText, getValue, setValue, otherValue, isMin)
    local lbl = Instance.new("TextLabel", parentCard)
    lbl.Size                 = UDim2.new(0, 28, 0, 16)
    lbl.BackgroundTransparency = 1
    lbl.Text                 = labelText
    lbl.TextColor3           = Theme.SubText
    lbl.TextSize             = 9
    lbl.Font                 = Enum.Font.Gotham
    lbl.TextXAlignment       = Enum.TextXAlignment.Left

    local box = Instance.new("TextBox", parentCard)
    box.Size             = UDim2.new(0, 42, 0, 20)
    box.BackgroundColor3 = Theme.InputBg
    box.BorderSizePixel  = 0
    box.Text             = string.format("%.1f", getValue())
    box.TextColor3       = Theme.Accent
    box.TextSize         = 10
    box.Font             = Enum.Font.GothamBold
    box.TextXAlignment   = Enum.TextXAlignment.Center
    box.ClearTextOnFocus = false
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 5)
    local boxStroke = Instance.new("UIStroke", box)
    boxStroke.Color     = Theme.Border
    boxStroke.Thickness = 1

    local btnMinus = Instance.new("TextButton", parentCard)
    btnMinus.Size             = UDim2.new(0, 22, 0, 20)
    btnMinus.BackgroundColor3 = Theme.PanelAlt
    btnMinus.Text             = "−"
    btnMinus.TextColor3       = Theme.Text
    btnMinus.TextSize         = 12
    btnMinus.Font             = Enum.Font.GothamBold
    btnMinus.AutoButtonColor  = false
    btnMinus.BorderSizePixel  = 0
    Instance.new("UICorner", btnMinus).CornerRadius = UDim.new(0, 5)

    local btnPlus = Instance.new("TextButton", parentCard)
    btnPlus.Size             = UDim2.new(0, 22, 0, 20)
    btnPlus.BackgroundColor3 = Theme.Accent
    btnPlus.Text             = "+"
    btnPlus.TextColor3       = Theme.Text
    btnPlus.TextSize         = 12
    btnPlus.Font             = Enum.Font.GothamBold
    btnPlus.AutoButtonColor  = false
    btnPlus.BorderSizePixel  = 0
    Instance.new("UICorner", btnPlus).CornerRadius = UDim.new(0, 5)

    local function applyValue(raw)
        local num = tonumber(raw)
        if not num then
            box.Text = string.format("%.1f", getValue())
            return
        end
        num = math.round(num * 10) / 10
        if isMin then
            num = math.clamp(num, 0.1, otherValue() - 0.1)
            setValue(num)
        else
            num = math.clamp(num, otherValue() + 0.1, 5.0)
            setValue(num)
        end
        box.Text = string.format("%.1f", num)
        updateRcDesc(descLabel, isMin and num or getValue(), isMin and getValue() or num)
    end

    box.Focused:Connect(function()
        TweenService:Create(boxStroke, TweenInfo.new(0.12), {Color = Theme.Accent}):Play()
    end)
    box.FocusLost:Connect(function()
        TweenService:Create(boxStroke, TweenInfo.new(0.12), {Color = Theme.Border}):Play()
        applyValue(box.Text)
    end)

    btnMinus.MouseButton1Click:Connect(function()
        applyValue(string.format("%.1f", getValue() - 0.1))
    end)
    btnPlus.MouseButton1Click:Connect(function()
        applyValue(string.format("%.1f", getValue() + 0.1))
    end)

    btnMinus.MouseEnter:Connect(function()
        TweenService:Create(btnMinus, TweenInfo.new(0.12), {BackgroundColor3 = Theme.Border}):Play()
    end)
    btnMinus.MouseLeave:Connect(function()
        TweenService:Create(btnMinus, TweenInfo.new(0.12), {BackgroundColor3 = Theme.PanelAlt}):Play()
    end)
    btnPlus.MouseEnter:Connect(function()
        TweenService:Create(btnPlus, TweenInfo.new(0.12), {BackgroundColor3 = Theme.AccentHov}):Play()
    end)
    btnPlus.MouseLeave:Connect(function()
        TweenService:Create(btnPlus, TweenInfo.new(0.12), {BackgroundColor3 = Theme.Accent}):Play()
    end)

    return lbl, box, btnMinus, btnPlus
end

local ROW_Y = 56

local minLbl, minBox, minMinus, minPlus = makeRcInputRow(
	randomCard,
	rcDesc,
    "Min",
    function() return RandomCastMinTime end,
    function(v) RandomCastMinTime = v end,
    function() return RandomCastMaxTime end,
    true
)
minLbl.Position   = UDim2.new(0, 0,  0, ROW_Y)
minBox.Position   = UDim2.new(0, 30, 0, ROW_Y)
minMinus.Position = UDim2.new(0, 76, 0, ROW_Y)
minPlus.Position  = UDim2.new(0, 102, 0, ROW_Y)

local maxLbl, maxBox, maxMinus, maxPlus = makeRcInputRow(
	randomCard,
	rcDesc,
    "Max",
    function() return RandomCastMaxTime end,
    function(v) RandomCastMaxTime = v end,
    function() return RandomCastMinTime end,
    false
)
maxLbl.Position   = UDim2.new(0.5, 0,  0, ROW_Y)
maxBox.Position   = UDim2.new(0.5, 30, 0, ROW_Y)
maxMinus.Position = UDim2.new(0.5, 76, 0, ROW_Y)
maxPlus.Position  = UDim2.new(0.5, 102, 0, ROW_Y)

-- CARD RANDOM POST-CATCH DELAY
local delayCard = Instance.new("Frame", configPage)
delayCard.Size             = UDim2.new(1, 0, 0, 96)
delayCard.BackgroundColor3 = Theme.Panel
delayCard.BorderSizePixel  = 0
delayCard.LayoutOrder      = co
co += 1
Instance.new("UICorner", delayCard).CornerRadius = UDim.new(0, 8)

local dcPad = Instance.new("UIPadding", delayCard)
dcPad.PaddingLeft   = UDim.new(0, 10)
dcPad.PaddingRight  = UDim.new(0, 10)
dcPad.PaddingTop    = UDim.new(0, 8)
dcPad.PaddingBottom = UDim.new(0, 8)

local dcTitle = Instance.new("TextLabel", delayCard)
dcTitle.Size                 = UDim2.new(0.65, 0, 0, 20)
dcTitle.Position             = UDim2.new(0, 0, 0, 0)
dcTitle.BackgroundTransparency = 1
dcTitle.Text                 = "Random Post-Catch Delay"
dcTitle.TextColor3           = Theme.Text
dcTitle.TextSize             = 11
dcTitle.Font                 = Enum.Font.GothamMedium
dcTitle.TextXAlignment       = Enum.TextXAlignment.Left

local dcDesc = Instance.new("TextLabel", delayCard)
dcDesc.Size                 = UDim2.new(1, -60, 0, 14)
dcDesc.Position             = UDim2.new(0, 0, 0, 24)
dcDesc.BackgroundTransparency = 1
dcDesc.Text                 = string.format("Range: %.1f – %.1f detik", RandomDelayMinTime, RandomDelayMaxTime)
dcDesc.TextColor3           = Theme.SubText
dcDesc.TextSize             = 9
dcDesc.Font                 = Enum.Font.Gotham
dcDesc.TextXAlignment       = Enum.TextXAlignment.Left

local dcToggle = Instance.new("TextButton", delayCard)
dcToggle.Size             = UDim2.new(0, 52, 0, 24)
dcToggle.Position         = UDim2.new(1, -52, 0, 0)
dcToggle.BackgroundColor3 = randomDelayEnabled and Theme.Green or Theme.PanelAlt
dcToggle.Text = randomDelayEnabled and "ON" or "OFF"
dcToggle.TextColor3 = randomDelayEnabled and Theme.Text or Theme.SubText
dcToggle.TextSize         = 10
dcToggle.Font             = Enum.Font.GothamBold
dcToggle.AutoButtonColor  = false
dcToggle.BorderSizePixel  = 0
Instance.new("UICorner", dcToggle).CornerRadius = UDim.new(0, 12)

local dMinLbl, dMinBox, dMinMinus, dMinPlus = makeRcInputRow(
    delayCard,
	dcDesc,
    "Min",
    function() return RandomDelayMinTime end,
    function(v) RandomDelayMinTime = v end,
    function() return RandomDelayMaxTime end,
    true
)
dMinLbl.Position   = UDim2.new(0, 0,  0, ROW_Y)
dMinBox.Position   = UDim2.new(0, 30, 0, ROW_Y)
dMinMinus.Position = UDim2.new(0, 76, 0, ROW_Y)
dMinPlus.Position  = UDim2.new(0, 102, 0, ROW_Y)

local dMaxLbl, dMaxBox, dMaxMinus, dMaxPlus = makeRcInputRow(
    delayCard,
	dcDesc,
    "Max",
    function() return RandomDelayMaxTime end,
    function(v) RandomDelayMaxTime = v end,
    function() return RandomDelayMinTime end,
    false
)
dMaxLbl.Position   = UDim2.new(0.5, 0,  0, ROW_Y)
dMaxBox.Position   = UDim2.new(0.5, 30, 0, ROW_Y)
dMaxMinus.Position = UDim2.new(0.5, 76, 0, ROW_Y)
dMaxPlus.Position  = UDim2.new(0.5, 102, 0, ROW_Y)

-- LOGIKA TOGGLE
local function updateRcDesc(descLabel, minVal, maxVal)
    descLabel.Text = string.format("Range: %.1f – %.1f detik", minVal, maxVal)
end

local function setRandomCast(enabled)
    randomCastEnabled = enabled
    if enabled then
        rcToggle.Text             = "ON"
        rcToggle.BackgroundColor3 = Theme.Green
        rcToggle.TextColor3       = Theme.Text
    else
        rcToggle.Text             = "OFF"
        rcToggle.BackgroundColor3 = Theme.PanelAlt
        rcToggle.TextColor3       = Theme.SubText
    end
end

local function setRandomDelay(enabled)
    randomDelayEnabled = enabled
    if enabled then
        dcToggle.Text             = "ON"
        dcToggle.BackgroundColor3 = Theme.Green
        dcToggle.TextColor3       = Theme.Text
    else
        dcToggle.Text             = "OFF"
        dcToggle.BackgroundColor3 = Theme.PanelAlt
        dcToggle.TextColor3       = Theme.SubText
    end
end

dcToggle.MouseButton1Click:Connect(function()
    setRandomDelay(not randomDelayEnabled)
end)

rcToggle.MouseButton1Click:Connect(function()
    setRandomCast(not randomCastEnabled)
end)

local configValueLabels = {}

-- UI TOGGLE AUTO JUMP & MOVE
local function createToggleCard(parent, title, descText, configEnabledKey, order)
    local card = Instance.new("Frame", parent)
    card.Size             = UDim2.new(1, 0, 0, 60)
    card.BackgroundColor3 = Theme.Panel
    card.BorderSizePixel  = 0
    card.LayoutOrder      = order
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)

    local pad = Instance.new("UIPadding", card)
    pad.PaddingLeft = UDim.new(0, 10); pad.PaddingRight = UDim.new(0, 10)
    pad.PaddingTop = UDim.new(0, 8); pad.PaddingBottom = UDim.new(0, 8)

    local lblTitle = Instance.new("TextLabel", card)
    lblTitle.Size = UDim2.new(0.7, 0, 0, 20)
    lblTitle.BackgroundTransparency = 1
    lblTitle.Text = title
    lblTitle.TextColor3 = Theme.Text
    lblTitle.TextSize = 12
    lblTitle.Font = Enum.Font.GothamMedium
    lblTitle.TextXAlignment = Enum.TextXAlignment.Left

    local lblDesc = Instance.new("TextLabel", card)
    lblDesc.Size = UDim2.new(1, 0, 0, 16)
    lblDesc.Position = UDim2.new(0, 0, 0, 22)
    lblDesc.BackgroundTransparency = 1
    lblDesc.Text = descText
    lblDesc.TextColor3 = Theme.SubText
    lblDesc.TextSize = 9
    lblDesc.Font = Enum.Font.Gotham
    lblDesc.TextXAlignment = Enum.TextXAlignment.Left

    local btnToggle = Instance.new("TextButton", card)
    btnToggle.Size = UDim2.new(0, 52, 0, 24)
    btnToggle.Position = UDim2.new(1, -52, 0, 0)
    btnToggle.BackgroundColor3 = Config[configEnabledKey] and Theme.Green or Theme.PanelAlt
    btnToggle.Text = Config[configEnabledKey] and "ON" or "OFF"
    btnToggle.TextColor3 = Theme.Text
    btnToggle.TextSize = 10
    btnToggle.Font = Enum.Font.GothamBold
    btnToggle.AutoButtonColor = false
    btnToggle.BorderSizePixel = 0
    Instance.new("UICorner", btnToggle).CornerRadius = UDim.new(0, 12)

    btnToggle.MouseButton1Click:Connect(function()
        Config[configEnabledKey] = not Config[configEnabledKey]
        if Config[configEnabledKey] then
            btnToggle.BackgroundColor3 = Theme.Green
            btnToggle.Text = "ON"
        else
            btnToggle.BackgroundColor3 = Theme.PanelAlt
            btnToggle.Text = "OFF"
        end
    end)
    
    btnToggle.MouseEnter:Connect(function()
        if Config[configEnabledKey] then
            TweenService:Create(btnToggle, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(22, 163, 74)}):Play()
        else
            TweenService:Create(btnToggle, TweenInfo.new(0.15), {BackgroundColor3 = Theme.Border}):Play()
        end
    end)

    btnToggle.MouseLeave:Connect(function()
        if Config[configEnabledKey] then
            TweenService:Create(btnToggle, TweenInfo.new(0.15), {BackgroundColor3 = Theme.Green}):Play()
        else
            TweenService:Create(btnToggle, TweenInfo.new(0.15), {BackgroundColor3 = Theme.PanelAlt}):Play()
        end
    end)

    return card
end

local toggleOrder = co
local ajCard = createToggleCard(configPage, "Auto Jump", "Lompat acak (1-5 mnt) + sesekali spam (5-10 mnt).", "AutoJumpEnabled", toggleOrder)
toggleOrder += 1
local flCard = createToggleCard(configPage, "Fish Limit", "Auto stop saat total ikan tercapai (atur di Fish Limit).", "FishLimitEnabled", toggleOrder)
co = toggleOrder + 1 
local hpCard = createToggleCard(configPage, "Hotspot Pause", "Auto pause jika semua hotspot > radius dari player.", "HotspotPauseEnabled", toggleOrder)
co = toggleOrder + 1

for _, meta in ipairs(ConfigMeta) do
    local card = Instance.new("Frame", configPage)
    card.Size             = UDim2.new(1, 0, 0, 52)
    card.BackgroundColor3 = Theme.Panel
    card.BorderSizePixel  = 0
    card.LayoutOrder      = co
    co += 1
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)

    local cpad = Instance.new("UIPadding", card)
    cpad.PaddingLeft  = UDim.new(0, 10)
    cpad.PaddingRight = UDim.new(0, 10)

    local nameLabel = Instance.new("TextLabel", card)
    nameLabel.Size                 = UDim2.new(0.55, 0, 0, 22)
    nameLabel.Position             = UDim2.new(0, 0, 0, 6)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text                 = meta.label
    nameLabel.TextColor3           = Theme.Text
    nameLabel.TextSize             = 11
    nameLabel.Font                 = Enum.Font.GothamMedium
    nameLabel.TextXAlignment       = Enum.TextXAlignment.Left

    local inputBox = Instance.new("TextBox", card)
    inputBox.Size                 = UDim2.new(0, 60, 0, 22)
    inputBox.Position             = UDim2.new(0.55, 0, 0, 6)
    inputBox.BackgroundColor3     = Theme.InputBg
    inputBox.BorderSizePixel      = 0
    inputBox.Text                 = tostring(Config[meta.key])
    inputBox.TextColor3           = Theme.Accent
    inputBox.TextSize             = 11
    inputBox.Font                 = Enum.Font.GothamBold
    inputBox.TextXAlignment       = Enum.TextXAlignment.Center
    inputBox.ClearTextOnFocus     = false
    inputBox.PlaceholderText      = tostring(Config[meta.key])
    inputBox.PlaceholderColor3    = Theme.SubText
    Instance.new("UICorner", inputBox).CornerRadius = UDim.new(0, 5)
    local inputStroke = Instance.new("UIStroke", inputBox)
    inputStroke.Color     = Theme.Border
    inputStroke.Thickness = 1

    local btnMinus = Instance.new("TextButton", card)
    btnMinus.Size             = UDim2.new(0, 28, 0, 20)
    btnMinus.Position         = UDim2.new(0, 0, 1, -26)
    btnMinus.BackgroundColor3 = Theme.PanelAlt
    btnMinus.Text             = "−"
    btnMinus.TextColor3       = Theme.Text
    btnMinus.TextSize         = 13
    btnMinus.Font             = Enum.Font.GothamBold
    btnMinus.AutoButtonColor  = false
    btnMinus.BorderSizePixel  = 0
    Instance.new("UICorner", btnMinus).CornerRadius = UDim.new(0, 5)

    local btnPlus = Instance.new("TextButton", card)
    btnPlus.Size             = UDim2.new(0, 28, 0, 20)
    btnPlus.Position         = UDim2.new(0, 34, 1, -26)
    btnPlus.BackgroundColor3 = Theme.Accent
    btnPlus.Text             = "+"
    btnPlus.TextColor3       = Theme.Text
    btnPlus.TextSize         = 13
    btnPlus.Font             = Enum.Font.GothamBold
    btnPlus.AutoButtonColor  = false
    btnPlus.BorderSizePixel  = 0
    Instance.new("UICorner", btnPlus).CornerRadius = UDim.new(0, 5)

    local btnReset = Instance.new("TextButton", card)
    btnReset.Size             = UDim2.new(0, 42, 0, 20)
    btnReset.Position         = UDim2.new(1, -42, 1, -26)
    btnReset.BackgroundColor3 = Theme.PanelAlt
    btnReset.Text             = "Reset"
    btnReset.TextColor3       = Theme.SubText
    btnReset.TextSize         = 9
    btnReset.Font             = Enum.Font.GothamMedium
    btnReset.AutoButtonColor  = false
    btnReset.BorderSizePixel  = 0
    Instance.new("UICorner", btnReset).CornerRadius = UDim.new(0, 5)

    local defaultVal = Config[meta.key]

    local function roundStep(val)
        local factor = 1 / meta.step
        return math.round(val * factor) / factor
    end

    local function formatVal(val)
        if meta.step < 1 then
            return string.format("%.2f", val)
        else
            return tostring(math.round(val))
        end
    end

    local function updateVal(newVal)
        newVal = math.clamp(roundStep(newVal), meta.min, meta.max)
        Config[meta.key] = newVal
        inputBox.Text = formatVal(newVal)
    end

    inputBox.Focused:Connect(function()
        TweenService:Create(inputStroke, TweenInfo.new(0.12), {Color = Theme.Accent}):Play()
    end)

    inputBox.FocusLost:Connect(function(enterPressed)
        TweenService:Create(inputStroke, TweenInfo.new(0.12), {Color = Theme.Border}):Play()
        local raw = tonumber(inputBox.Text)
        if raw then
            updateVal(raw)
        else
            inputBox.Text = formatVal(Config[meta.key])
        end
    end)

    btnMinus.MouseButton1Click:Connect(function() updateVal(Config[meta.key] - meta.step) end)
    btnPlus.MouseButton1Click:Connect(function()  updateVal(Config[meta.key] + meta.step) end)
    btnReset.MouseButton1Click:Connect(function() updateVal(defaultVal) end)

    btnMinus.MouseEnter:Connect(function()
        TweenService:Create(btnMinus, TweenInfo.new(0.12), {BackgroundColor3 = Theme.Border}):Play()
    end)
    btnMinus.MouseLeave:Connect(function()
        TweenService:Create(btnMinus, TweenInfo.new(0.12), {BackgroundColor3 = Theme.PanelAlt}):Play()
    end)

    btnPlus.MouseEnter:Connect(function()
        TweenService:Create(btnPlus, TweenInfo.new(0.12), {BackgroundColor3 = Theme.AccentHov}):Play()
    end)
    btnPlus.MouseLeave:Connect(function()
        TweenService:Create(btnPlus, TweenInfo.new(0.12), {BackgroundColor3 = Theme.Accent}):Play()
    end)

    configValueLabels[meta.key] = inputBox 
end

-- COMMANDS
local function triggerCommand(alias)
    local ok, err = pcall(function()
        local tcs = game:GetService("TextChatService")
        local channel = tcs.TextChannels:FindFirstChild("RBXGeneral")
        if not channel then
            -- fallback ke DefaultChatSystemChatEvents
            local remote = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
                and ReplicatedStorage.DefaultChatSystemChatEvents:FindFirstChild("SayMessageRequest")
            if remote then
                remote:FireServer(alias, "All")
                return
            end
            DebugLabel.Text = "Channel tidak ditemukan"
            return
        end
        channel:SendAsync(alias)
    end)
    if not ok then
        DebugLabel.Text = "Gagal: " .. tostring(err)
    end
end

local function leaveGame()
    print("Leave dijalankan")

    game:GetService("Players").LocalPlayer:Kick("Leaving")
end

-- COMMANDS TAB
local cmo = 0

makeSectionLabel(commandsPage, "COMMANDS", cmo) cmo+=1

local function makeCommandCard(parent, title, desc, btnText, alias, order)
    local card = Instance.new("Frame", parent)
    card.Size             = UDim2.new(1, 0, 0, 62)
    card.BackgroundColor3 = Theme.Panel
    card.BorderSizePixel  = 0
    card.LayoutOrder      = order
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)

    local pad = Instance.new("UIPadding", card)
    pad.PaddingLeft   = UDim.new(0, 10)
    pad.PaddingRight  = UDim.new(0, 10)
    pad.PaddingTop    = UDim.new(0, 8)
    pad.PaddingBottom = UDim.new(0, 8)

    local lblTitle = Instance.new("TextLabel", card)
    lblTitle.Size                 = UDim2.new(0.65, 0, 0, 18)
    lblTitle.BackgroundTransparency = 1
    lblTitle.Text                 = title
    lblTitle.TextColor3           = Theme.Text
    lblTitle.TextSize             = 12
    lblTitle.Font                 = Enum.Font.GothamMedium
    lblTitle.TextXAlignment       = Enum.TextXAlignment.Left

    local lblDesc = Instance.new("TextLabel", card)
    lblDesc.Size                 = UDim2.new(1, 0, 0, 14)
    lblDesc.Position             = UDim2.new(0, 0, 0, 22)
    lblDesc.BackgroundTransparency = 1
    lblDesc.Text                 = desc
    lblDesc.TextColor3           = Theme.SubText
    lblDesc.TextSize             = 9
    lblDesc.Font                 = Enum.Font.Gotham
    lblDesc.TextXAlignment       = Enum.TextXAlignment.Left

    local btn = Instance.new("TextButton", card)
    btn.Size             = UDim2.new(0, 72, 0, 26)
    btn.Position         = UDim2.new(1, -72, 0, 0)
    btn.BackgroundColor3 = Theme.Accent
    btn.Text             = btnText
    btn.TextColor3       = Theme.Text
    btn.TextSize         = 11
    btn.Font             = Enum.Font.GothamBold
    btn.AutoButtonColor  = false
    btn.BorderSizePixel  = 0
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.12), {BackgroundColor3 = Theme.AccentHov}):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.12), {BackgroundColor3 = Theme.Accent}):Play()
    end)
    btn.MouseButton1Click:Connect(function()
        triggerCommand(alias)
        DebugLabel.Text = "Command: " .. alias
        notify("Command", alias .. " dikirim!")
    end)

    return card
end

makeCommandCard(commandsPage, "Refresh", "Reset avatar ke tampilan asli", "Refresh", "/refresh", cmo) cmo+=1
makeCommandCard(commandsPage, "Reset", "Reset posisi karakter", "Reset", "/reset", cmo) cmo+=1
makeCommandCard(commandsPage, "Rejoin", "Keluar dan masuk ulang ke server", "Rejoin", "/rejoin", cmo) cmo+=1

local Players = game:GetService("Players")

local leaveCard = Instance.new("Frame")
leaveCard.Size             = UDim2.new(1, 0, 0, 62)
leaveCard.BackgroundColor3 = Theme.Panel
leaveCard.BorderSizePixel  = 0
leaveCard.LayoutOrder      = cmo
leaveCard.Parent           = commandsPage
cmo += 1
Instance.new("UICorner", leaveCard).CornerRadius = UDim.new(0, 8)

local leavePad = Instance.new("UIPadding", leaveCard)
leavePad.PaddingLeft   = UDim.new(0, 10)
leavePad.PaddingRight  = UDim.new(0, 10)
leavePad.PaddingTop    = UDim.new(0, 8)
leavePad.PaddingBottom = UDim.new(0, 8)

local leaveTitle = Instance.new("TextLabel", leaveCard)
leaveTitle.Size                 = UDim2.new(0.65, 0, 0, 18)
leaveTitle.BackgroundTransparency = 1
leaveTitle.Text                 = "Leave Game"
leaveTitle.TextColor3           = Theme.Text
leaveTitle.TextSize             = 12
leaveTitle.Font                 = Enum.Font.GothamMedium
leaveTitle.TextXAlignment       = Enum.TextXAlignment.Left

local leaveDesc = Instance.new("TextLabel", leaveCard)
leaveDesc.Size                 = UDim2.new(1, 0, 0, 14)
leaveDesc.Position             = UDim2.new(0, 0, 0, 22)
leaveDesc.BackgroundTransparency = 1
leaveDesc.Text                 = "Keluar dari server."
leaveDesc.TextColor3           = Theme.SubText
leaveDesc.TextSize             = 9
leaveDesc.Font                 = Enum.Font.Gotham
leaveDesc.TextXAlignment       = Enum.TextXAlignment.Left

local leaveBtn = Instance.new("TextButton", leaveCard)
leaveBtn.Size             = UDim2.new(0, 72, 0, 26)
leaveBtn.Position         = UDim2.new(1, -72, 0, 0)
leaveBtn.BackgroundColor3 = Theme.Danger
leaveBtn.Text             = "Leave"
leaveBtn.TextColor3       = Theme.Text
leaveBtn.TextSize         = 11
leaveBtn.Font             = Enum.Font.GothamBold
leaveBtn.AutoButtonColor  = false
leaveBtn.BorderSizePixel  = 0
Instance.new("UICorner", leaveBtn).CornerRadius = UDim.new(0, 8)

leaveBtn.MouseEnter:Connect(function()
    TweenService:Create(leaveBtn, TweenInfo.new(0.12), {
        BackgroundColor3 = Color3.new(
            math.min(Theme.Danger.R + 0.08, 1),
            math.min(Theme.Danger.G + 0.08, 1),
            math.min(Theme.Danger.B + 0.08, 1))
    }):Play()
end)
leaveBtn.MouseLeave:Connect(function()
    TweenService:Create(leaveBtn, TweenInfo.new(0.12), {BackgroundColor3 = Theme.Danger}):Play()
end)
leaveBtn.MouseButton1Click:Connect(function()
    Players.LocalPlayer:Kick("Leaving...")
end)

-- MINIMIZE
local isMinimized     = false
local fullHeight      = 420
local minimizedHeight = 42
local isTweening      = false

minimizeBtn.MouseButton1Click:Connect(function()
    if isTweening then return end
    isMinimized = not isMinimized
    isTweening  = true
    minimizeBtn.Text = isMinimized and "+" or "−"

	headerFix.Visible = not isMinimized

    local targetH = isMinimized and minimizedHeight or fullHeight
    local tween   = TweenService:Create(
        Main,
        TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
        { Size = UDim2.new(0, 300, 0, targetH) }
    )
    tween:Play()
    tween.Completed:Connect(function()
        TabBar.Visible        = not isMinimized
        ContentArea.Visible   = not isMinimized
        isTweening = false
    end)

    if isMinimized then
        TabBar.Visible      = false
        ContentArea.Visible = false
    end
end)

-- DRAG
local dragging, dragStart, startPos = false, nil, nil

Header.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.Touch
    or inp.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = inp.Position
        startPos  = Main.Position
    end
end)
Header.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.Touch
    or inp.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)
UserInputService.InputChanged:Connect(function(inp)
    if not dragging then return end
    if inp.UserInputType ~= Enum.UserInputType.Touch
    and inp.UserInputType ~= Enum.UserInputType.MouseMovement then return end
    local d = inp.Position - dragStart
    Main.Position = UDim2.new(
        startPos.X.Scale, startPos.X.Offset + d.X,
        startPos.Y.Scale, startPos.Y.Offset + d.Y)
end)

local function setStatus(text, color)
    StatusValue.Text       = text
    StatusValue.TextColor3 = color or Theme.Text
end
local function setAction(text)  ActionValue.Text  = text  end
local function updateStats()    FishValue.Text    = tostring(fishCount) end
local function updateTimer()
    if not isRunning or botStartTime == 0 then return end
    local e = tick() - botStartTime
    TimerValue.Text = string.format("%02d:%02d:%02d",
        math.floor(e/3600), math.floor(e%3600/60), math.floor(e%60))
end

-- HELPERS KARAKTER
local function getHRP()
    local c = LocalPlayer.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end
local function getHumanoid()
    local c = LocalPlayer.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

-- TAP
local function tapAt(x, y, holdTime)
    holdTime = holdTime or 0.05
    VirtualInputManager:SendMouseButtonEvent(math.floor(x), math.floor(y), 0, true,  game, 0)
    task.wait(holdTime)
    VirtualInputManager:SendMouseButtonEvent(math.floor(x), math.floor(y), 0, false, game, 0)
end

local function tapButton(btn, holdTime)
    if not btn or not btn.Visible then return false end
    holdTime = holdTime or Config.FishTapDuration

    local camera   = workspace.CurrentCamera
    local viewport = camera.ViewportSize
    local inset    = GuiService:GetGuiInset()

    local guiAreaY = viewport.Y - inset.Y
    local scaleX   = viewport.X / ScreenGui.AbsoluteSize.X
    local scaleY   = guiAreaY   / ScreenGui.AbsoluteSize.Y

    local pos  = btn.AbsolutePosition
    local size = btn.AbsoluteSize

    local tapX = (pos.X + size.X / 2) * scaleX + Config.TapOffsetX
    local tapY = (pos.Y + size.Y / 2) * scaleY + inset.Y + Config.TapOffsetY

    tapAt(tapX, tapY, holdTime)
    return true
end

-- FISHING UI
local function getFishingUI()    return PlayerGui:FindFirstChild("FishingUI") end
local function getPreFishingHolder()
    local ui = getFishingUI()
    return ui and ui:FindFirstChild("PreFishingHolder")
end
local function isPreFishingActive()
    local h = getPreFishingHolder()
    return h ~= nil and h.Visible == true
end
local function getBar()
    local ui = getFishingUI();                                 if not ui then return nil end
    local fh = ui:FindFirstChild("FishingHolder");             if not fh then return nil end
    local ff = fh:FindFirstChild("FishingFrame"); if not ff or not ff.Visible then return nil end
    local bc = ff:FindFirstChild("BarContainer")
    return bc and bc:FindFirstChild("Bar")
end
local function isBarActive()
    local b = getBar(); return b ~= nil and b.Visible == true
end
local function colorMatch(col, r, g, b)
    local t = Config.ColorTolerance
    return math.abs(col.R*255-r)<=t
       and math.abs(col.G*255-g)<=t
       and math.abs(col.B*255-b)<=t
end
local function isBarGreen()
    local b = getBar()
    return b and colorMatch(b.BackgroundColor3, Config.BarGreenR, Config.BarGreenG, Config.BarGreenB)
end

-- ROD
function scanRods()
    local rods, seen = {}, {}
    for _, c in ipairs({LocalPlayer.Backpack, LocalPlayer.Character}) do
        if c then
            for _, t in ipairs(c:GetChildren()) do
                if t:IsA("Tool") and not seen[t.Name] and t.Name:lower():find("rod") then
                    seen[t.Name] = true; table.insert(rods, t.Name)
                end
            end
        end
    end
    return rods
end
local function findRod(name)
    for _, c in ipairs({LocalPlayer.Backpack, LocalPlayer.Character}) do
        if c and c:FindFirstChild(name) then return c:FindFirstChild(name) end
    end
end
local function isRodEquipped(name)
    local char = LocalPlayer.Character
    return char and char:FindFirstChild(name) ~= nil
end
local function equipRodByName(name)
    if not name then return false end
    setAction("Equip: "..name)
    local hum = getHumanoid(); if not hum then return false end
    if isRodEquipped(name) then task.wait(0.2); return true end
    local tool = findRod(name)
    if not tool then DebugLabel.Text = "Rod tidak ditemukan: "..name; return false end
    hum:EquipTool(tool); task.wait(0.4); return true
end
local function unequipRod()
    setAction("Unequip rod")
    local hum = getHumanoid()
    if hum then hum:UnequipTools(); task.wait(0.4) end
end

-- HOTSPOT DETECTION
local function getActiveHotspots()
    local active = {}
    local fishingZone = workspace:FindFirstChild("Main")
        and workspace.Main:FindFirstChild("FishingZone")
    if not fishingZone then
        DebugLabel.Text = "FishingZone tidak ditemukan!"
        return active
    end
    for _, part in ipairs(fishingZone:GetChildren()) do
        if not part:IsA("BasePart") then continue end
        local attachment = part:FindFirstChild("Attachment")
        if not attachment then continue end
        local flagNames = {"GroundFlag", "GroundFlasg"}
local isActive  = false

for _, flagName in ipairs(flagNames) do
    local flag = attachment:FindFirstChild(flagName)
    if flag and flag.Enabled then
        isActive = true
        break
    end
end
        if isActive then
            table.insert(active, { part=part, position=part.Position, name=part.Name })
        end
    end
    return active
end

local function isNearHotspot(radius)
    radius = radius or Config.HotspotRadius
    local hrp = getHRP()
    if not hrp then return false, nil end
    for _, hotspot in ipairs(getActiveHotspots()) do
        local dist = (hrp.Position - hotspot.position).Magnitude
        if dist <= radius then return true, hotspot end
    end
    return false, nil
end

-- HOTSPOT TRACER
local function clearTracers()
    for _, obj in ipairs(HotspotTracers) do
        pcall(function() obj:Remove() end)
    end
    HotspotTracers = {}
end

local function clearMapHotspotTracers()
    for _, obj in ipairs(MapHotspotTracers) do
        pcall(function() obj:Remove() end)
    end
    MapHotspotTracers = {}
end

local function updateMapHotspotTracers()
    clearMapHotspotTracers()

    -- skip kalau tidak ada map yang di-toggle
    local anyActive = MapToggleState.City or MapToggleState.Island or MapToggleState.Old
    if not anyActive then return end

    local camera = workspace.CurrentCamera
    local hrp    = getHRP()
    if not hrp then return end

    local fromPos = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y * 0.9)

    -- warna berbeda per map biar gampang dibedain
    local mapColors = {
        City   = Color3.fromRGB(100, 180, 255),
        Island = Color3.fromRGB(120, 255, 150),
        Old    = Color3.fromRGB(255, 160, 80),
    }

    for mapKey, isOn in pairs(MapToggleState) do
        if not isOn then continue end

        for _, point in ipairs(HotspotMapData[mapKey]) do
            -- request stream-in supaya part di lokasi itu coba ke-load
            pcall(function()
                workspace:RequestStreamAroundAsync(point, 1)
            end)

            local screenPos, onScreen = camera:WorldToViewportPoint(point)
            if screenPos.Z <= 0 then continue end

            local toPos = Vector2.new(screenPos.X, screenPos.Y)
            local dist  = math.floor((hrp.Position - point).Magnitude)
            local color = mapColors[mapKey]

            local line        = Drawing.new("Line")
            line.Visible       = true
            line.From          = fromPos
            line.To            = toPos
            line.Color         = color
            line.Thickness     = onScreen and 1.5 or 1
            line.Transparency  = onScreen and 1 or 0.4
            table.insert(MapHotspotTracers, line)

            local label        = Drawing.new("Text")
            label.Visible      = true
            label.Position     = Vector2.new(toPos.X + 6, toPos.Y - 8)
            label.Text         = string.format("[%s] %d studs", mapKey, dist)
            label.Size         = 12
            label.Color        = color
            label.Outline      = true
            label.OutlineColor = Color3.fromRGB(0, 0, 0)
            label.Font         = Drawing.Fonts.UI
            table.insert(MapHotspotTracers, label)

            local dot      = Drawing.new("Circle")
            dot.Visible    = true
            dot.Position   = toPos
            dot.Radius     = 5
            dot.Color      = color
            dot.Filled     = true
            dot.Thickness  = 1
            dot.Transparency = 1
            table.insert(MapHotspotTracers, dot)
        end
    end
end

local function updateHotspotTracers()
    clearTracers()
    local hrp = getHRP()
    if not hrp then return end

    local camera     = workspace.CurrentCamera
    local screenSize = camera.ViewportSize
    local fromPos    = Vector2.new(screenSize.X / 2, screenSize.Y * 0.9)
    local activeHotspots = getActiveHotspots()

    if #activeHotspots == 0 then
        HotspotStatusValue.Text       = "Tidak ada"
        HotspotStatusValue.TextColor3 = Theme.SubText
        HotspotCountValue.Text        = "0"
        HotspotNearValue.Text         = "-"
        HotspotDistValue.Text         = "-"
    else
        HotspotStatusValue.Text       = "Aktif"
        HotspotStatusValue.TextColor3 = Theme.Yellow
        HotspotCountValue.Text        = tostring(#activeHotspots).." zona"
    end

    local closestIndex = nil
    local closestDist  = math.huge
    for i, hotspot in ipairs(activeHotspots) do
        local dist = (hrp.Position - hotspot.position).Magnitude
        if dist < closestDist then
            closestDist  = dist
            closestIndex = i
        end
    end

    if closestIndex then
        local closest = activeHotspots[closestIndex]
        HotspotNearValue.Text  = closest.name
        HotspotDistValue.Text  = string.format("%.1f studs", closestDist)
        local distColor = closestDist <= Config.HotspotRadius and Theme.Green
                       or closestDist <= 50                   and Theme.Yellow
                       or Theme.Danger
        HotspotDistValue.TextColor3 = distColor
    end

    for i, hotspot in ipairs(activeHotspots) do
        local screenPos, onScreen = camera:WorldToViewportPoint(hotspot.position)
        if screenPos.Z <= 0 then continue end

        local toPos     = Vector2.new(screenPos.X, screenPos.Y)
        local dist      = math.floor((hrp.Position - hotspot.position).Magnitude)
        local isClosest = (i == closestIndex)

        local lineColor
        if isClosest then
            lineColor = Color3.fromRGB(255, 255, 255)
        elseif dist <= Config.HotspotRadius then
            lineColor = Color3.fromRGB(50, 255, 100)
        elseif dist <= 50 then
            lineColor = Color3.fromRGB(255, 220, 50)
        else
            lineColor = Color3.fromRGB(255, 80, 80)
        end

        local line           = Drawing.new("Line")
        line.Visible         = true
        line.From            = fromPos
        line.To              = toPos
        line.Color           = lineColor
        line.Thickness       = isClosest and 2.5 or (onScreen and 1.5 or 1)
        line.Transparency    = onScreen and 1 or 0.5
        table.insert(HotspotTracers, line)

        local labelText = isClosest
            and string.format("%s | %d studs [TERDEKAT]", hotspot.name, dist)
            or  string.format("%s | %d studs", hotspot.name, dist)

        local label           = Drawing.new("Text")
        label.Visible         = true
        label.Position        = Vector2.new(toPos.X + 6, toPos.Y - 8)
        label.Text            = labelText
        label.Size            = isClosest and 14 or 13
        label.Color           = lineColor
        label.Outline         = true
        label.OutlineColor    = Color3.fromRGB(0, 0, 0)
        label.Font            = Drawing.Fonts.UI
        table.insert(HotspotTracers, label)

        local dot          = Drawing.new("Circle")
        dot.Visible        = true
        dot.Position       = toPos
        dot.Radius         = isClosest and 8 or 5
        dot.Color          = lineColor
        dot.Filled         = true
        dot.Thickness      = 1
        dot.Transparency   = 1
        table.insert(HotspotTracers, dot)

        if isClosest then
            local ring        = Drawing.new("Circle")
            ring.Visible      = true
            ring.Position     = toPos
            ring.Radius       = 14
            ring.Color        = Color3.fromRGB(255, 255, 255)
            ring.Filled       = false
            ring.Thickness    = 1.5
            ring.Transparency = 0.6
            table.insert(HotspotTracers, ring)
        end
    end
end

local function startTracerLoop()
    tracerThread = task.spawn(function()
        while tracerEnabled do
            updateHotspotTracers()
            updateMapHotspotTracers()
            task.wait(Config.TracerUpdateRate)
        end
        clearTracers()
        clearMapHotspotTracers()
        HotspotStatusValue.Text       = "Tidak ada"
        HotspotStatusValue.TextColor3 = Theme.SubText
        HotspotCountValue.Text        = "0"
        HotspotNearValue.Text         = "-"
        HotspotDistValue.Text         = "-"
    end)
end

local function stopTracerLoop()
    tracerEnabled = false
    clearTracers()
    clearMapHotspotTracers()
    HotspotStatusValue.Text       = "Tidak ada"
    HotspotStatusValue.TextColor3 = Theme.SubText
    HotspotCountValue.Text        = "0"
    HotspotNearValue.Text         = "-"
    HotspotDistValue.Text         = "-"
end

TracerBtn.MouseButton1Click:Connect(function()
    tracerEnabled = not tracerEnabled
    if tracerEnabled then
        TracerBtn.Text             = "Hotspot Tracer: ON"
        TracerBtn.BackgroundColor3 = Theme.Green
        startTracerLoop()
        notify("Tracer", "Hotspot tracer aktif!")
    else
        TracerBtn.Text             = "Hotspot Tracer: OFF"
        TracerBtn.BackgroundColor3 = Theme.PanelAlt
        stopTracerLoop()
        notify("Tracer", "Hotspot tracer dimatikan.")
    end
end)

-- CAST
local function castRod()
    setAction("Casting...")
    local cam      = workspace.CurrentCamera
    local viewport = cam and cam.ViewportSize or Vector2.new(1080, 1920)
    local inset    = GuiService:GetGuiInset()

    local holdTime
    if randomCastEnabled then
        holdTime = RandomCastMinTime + math.random() * (RandomCastMaxTime - RandomCastMinTime)
        holdTime = math.round(holdTime * 100) / 100
        DebugLabel.Text = string.format("Cast acak: %.2fs", holdTime)
    else
        holdTime = Config.CastHoldTime
    end

    tapAt(
        math.floor(viewport.X * Config.CastX),  
        math.floor(viewport.Y * Config.CastY), 
        holdTime)
    task.wait(Config.CastCooldown)
    lastCastTime = tick()
    setAction("Menunggu gigitan...")
end

local function guiToViewportPos(absPosition, absSize, offsetX, offsetY)
    local camera   = workspace.CurrentCamera
    local viewport = camera.ViewportSize
    local inset    = GuiService:GetGuiInset()

    local guiAreaY = viewport.Y - inset.Y
    local scaleX   = viewport.X / ScreenGui.AbsoluteSize.X
    local scaleY   = guiAreaY   / ScreenGui.AbsoluteSize.Y

    local centerX = absPosition.X + absSize.X / 2
    local centerY = absPosition.Y + absSize.Y / 2

    local px = centerX * scaleX + (offsetX or Config.TapOffsetX)
    local py = centerY * scaleY + inset.Y + (offsetY or Config.TapOffsetY)

    return px, py
end

-- FISH PHASE (DRAG VERSION)
local function handleFishPhase()
    setStatus("Fish Phase!", Theme.Accent)
    local holder = getPreFishingHolder()
    if not holder then DebugLabel.Text = "PreFishingHolder not found!"; return end

    local dragButton = holder:FindFirstChild("DragButton")
    local targetFrame = holder:FindFirstChild("TargetFrame")

    if not dragButton or not targetFrame then
        DebugLabel.Text = "DragButton/TargetFrame tidak ditemukan!"
        return
    end

    local moveSteps    = Config.DragMoveSteps or 8
    local moveDelay    = Config.DragMoveDelay or 0.02
    local holdAfter    = Config.DragHoldAfter or 0.05
    local recheckDelay = Config.DragRecheckDelay or 0.05
    local posTolerance = Config.DragPosTolerance or 3

    local lastTargetPos = nil

    while isRunning and isPreFishingActive() do
        if not dragButton.Visible or not targetFrame.Visible then
            task.wait(recheckDelay)
            continue
        end

        local targetPos = targetFrame.AbsolutePosition
        local targetSize = targetFrame.AbsoluteSize

        -- skip kalau target belum pindah signifikan dari posisi terakhir
        local moved = true
        if lastTargetPos then
            local dx = math.abs(targetPos.X - lastTargetPos.X)
            local dy = math.abs(targetPos.Y - lastTargetPos.Y)
            moved = (dx > posTolerance or dy > posTolerance)
        end

        if moved then
            setStatus("Dragging...", Theme.Accent)
            DebugLabel.Text = "Drag ke target baru"

            local dragPos = dragButton.AbsolutePosition
            local dragSize = dragButton.AbsoluteSize

            local startX, startY = guiToViewportPos(dragPos, dragSize)
            local endX, endY = guiToViewportPos(targetPos, targetSize)

            -- MOUSE DOWN di posisi DragButton
            VirtualInputManager:SendMouseButtonEvent(math.floor(startX), math.floor(startY), 0, true, game, 0)
            task.wait(0.02)

            -- GERAK BERTAHAP menuju TargetFrame
            for step = 1, moveSteps do
                if not isRunning or not isPreFishingActive() then break end
                local t = step / moveSteps
                local curX = startX + (endX - startX) * t
                local curY = startY + (endY - startY) * t
                VirtualInputManager:SendMouseMoveEvent(math.floor(curX), math.floor(curY), game)
                task.wait(moveDelay)
            end

            task.wait(holdAfter)

            -- MOUSE UP di posisi TargetFrame
            VirtualInputManager:SendMouseButtonEvent(math.floor(endX), math.floor(endY), 0, false, game, 0)

            lastTargetPos = targetPos
        end

        task.wait(recheckDelay)
    end
end

-- BAR PHASE
local function handleBarPhase()
    setStatus("Bar Phase...", Theme.Accent)
    local barStart = tick()
    local didTap   = false

    while isRunning and isBarActive() do
        if tick() - barStart > 12 then break end
        if isBarGreen() then
            setStatus("HIJAU - TAP!", Theme.Green)
            local bar = getBar()
            if bar then tapButton(bar, Config.FishTapDuration); didTap = true end
            task.wait(0.04)
        else
            setStatus("MERAH - TAHAN", Theme.Danger)
            task.wait(0.04)
        end
    end

    if not isBarActive() then
        if didTap then
            fishCount += 1
            updateStats()
            local nearHS, hsData = isNearHotspot()
            if nearHS then
                setStatus("Ikan +1 (+Hotspot!)", Theme.Green)
                DebugLabel.Text = string.format("Ikan ke-%d | Hotspot: %s", fishCount, hsData.name)
                notify("Ikan Tertangkap!", string.format("Total: %d | Hotspot: %s", fishCount, hsData.name))
            else
                setStatus("Ikan +1", Theme.Green)
                DebugLabel.Text = string.format("Ikan ke-%d | Total: %d", fishCount, fishCount)
                notify("Ikan Tertangkap!", string.format("Total: %d", fishCount))
            end

            -- Cek fish limit setelah ikan bertambah
            if Config.FishLimitEnabled and fishCount >= Config.FishLimit then
                notify("Fish Limit!", string.format("Target %d ikan tercapai. Bot berhenti.", Config.FishLimit))
                DebugLabel.Text = string.format("LIMIT TERCAPAI: %d ikan. Bot stop.", Config.FishLimit)
                setStatus("Limit Tercapai!", Theme.Yellow)
                isRunning  = false
                isPaused   = false
                PauseBtn.Text             = "Pause"
                PauseBtn.BackgroundColor3 = Theme.PanelAlt
                StartBtn.Text             = "START"
                StartBtn.BackgroundColor3 = Theme.Accent
                botStartTime    = 0
                TimerValue.Text = "00:00:00"
                stopAutoFeatures()
                unequipRod()
            end
        else
            setStatus("Bar gagal", Theme.Danger)
            DebugLabel.Text = "Bar phase gagal"
        end
    end
end

-- PAUSE
local function waitWhilePaused()
    while isPaused and isRunning do task.wait(0.1) end
end

PauseBtn.MouseButton1Click:Connect(function()
    if not isRunning then notify("Info", "Bot belum jalan!"); return end
    isPaused = not isPaused
    if isPaused then
        pauseStartTime            = tick()
        PauseBtn.Text             = "Resume"
        PauseBtn.BackgroundColor3 = Theme.Green
        setStatus("Paused", Theme.SubText)
        DebugLabel.Text           = "Bot dijeda..."
        unequipRod()
        notify("Pause", "Bot dijeda.")
    else
        botStartTime              = botStartTime + (tick() - pauseStartTime)
        pauseStartTime            = 0
        PauseBtn.Text             = "Pause"
        PauseBtn.BackgroundColor3 = Theme.PanelAlt
        setStatus("Running", Theme.Accent)
        DebugLabel.Text           = "Bot dilanjutkan..."
        notify("Resume", "Bot dilanjutkan!")
    end
end)

-- AUTO MOVEMENT & JUMP HELPERS 
local function startAutoFeatures()
	-- Hotspot Watcher Thread (dengan delay anti-flicker)
    hotspotWatchThread = task.spawn(function()
        while isRunning do
            task.wait(1) -- cek tiap 1 detik, lebih responsif untuk delay tracking
            if not Config.HotspotPauseEnabled then
                hotspotPendingSince = nil -- reset kalau fitur dimatikan di tengah jalan
                continue
            end
            if isPaused and not isHotspotPaused then continue end -- lagi pause manual, skip

            local hrp = getHRP()
            if not hrp then continue end

            local hotspots = getActiveHotspots()
            local closestDist = math.huge
            for _, hs in ipairs(hotspots) do
                local dist = (hrp.Position - hs.position).Magnitude
                if dist < closestDist then
                    closestDist = dist
                end
            end

            local isTooFar = closestDist > Config.HotspotPauseRadius
            local desiredTarget = nil

            if isTooFar and not isHotspotPaused then
                desiredTarget = "pause"
            elseif not isTooFar and isHotspotPaused then
                desiredTarget = "resume"
            end

            if desiredTarget == nil then
                -- kondisi sudah sesuai state saat ini, batalkan pending kalau ada
                if hotspotPendingSince then
                    DebugLabel.Text = "Hotspot: kondisi normal lagi, pending dibatalkan."
                end
                hotspotPendingSince  = nil
                hotspotPendingTarget = nil
                hotspotPendingDelay  = nil

            elseif hotspotPendingTarget ~= desiredTarget then
                -- target baru, mulai hitung delay dari awal
                hotspotPendingSince  = tick()
                hotspotPendingTarget = desiredTarget
                hotspotPendingDelay  = Config.HotspotDelayMinTime
                    + math.random() * (Config.HotspotDelayMaxTime - Config.HotspotDelayMinTime)
                DebugLabel.Text = string.format("Hotspot: %s pending dalam %.1fs (jarak %.0f)",
                    desiredTarget, hotspotPendingDelay, closestDist)

            else
                -- target sama dengan pending sebelumnya, cek apakah delay sudah lewat
                local elapsed = tick() - hotspotPendingSince
                if elapsed >= hotspotPendingDelay then
                    -- eksekusi trigger
                    if desiredTarget == "pause" then
                        isHotspotPaused = true
                        isPaused        = true
                        pauseStartTime  = tick()
                        PauseBtn.Text             = "Resume"
                        PauseBtn.BackgroundColor3 = Theme.Green
                        setStatus("Hotspot Jauh!", Theme.Yellow)
                        DebugLabel.Text = string.format("Hotspot pause dieksekusi: %.0f studs", closestDist)
                        unequipRod()
                        notify("Hotspot", string.format("Hotspot terlalu jauh (%.0f studs). Bot dijeda.", closestDist))

                    elseif desiredTarget == "resume" then
                        isHotspotPaused           = false
                        botStartTime              = botStartTime + (tick() - pauseStartTime)
                        pauseStartTime            = 0
                        isPaused                  = false
                        PauseBtn.Text             = "Pause"
                        PauseBtn.BackgroundColor3 = Theme.PanelAlt
                        setStatus("Running", Theme.Accent)
                        DebugLabel.Text = string.format("Hotspot resume dieksekusi: %.0f studs", closestDist)
                        notify("Hotspot", string.format("Hotspot dekat lagi (%.0f studs). Bot lanjut.", closestDist))
                    end

                    -- reset pending state setelah eksekusi
                    hotspotPendingSince  = nil
                    hotspotPendingTarget = nil
                    hotspotPendingDelay  = nil
                end
                -- kalau belum lewat delay, ya tunggu saja, tidak ngapa-ngapain
            end
        end
    end)

    autoJumpThread = task.spawn(function()
        while isRunning do
            if not isPaused and Config.AutoJumpEnabled then
                local roll = math.random(1, 10)
                
                if roll == 1 and Config.AutoJumpSpamEnabled then
                    local waitTime = Config.AutoJumpSpamMinDelay + math.random(0, Config.AutoJumpSpamMaxDelay - Config.AutoJumpSpamMinDelay)
                    task.wait(waitTime)
                    
                    if isRunning and not isPaused and Config.AutoJumpEnabled then
                        local spamCount = math.random(3, 6) 
                        for i = 1, spamCount do
                            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
                            task.wait(0.08) 
                            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
                            task.wait(0.15) 
                        end
                    end
                else
                    local waitTime = Config.AutoJumpMinDelay + math.random(0, Config.AutoJumpMaxDelay - Config.AutoJumpMinDelay)
                    task.wait(waitTime)
                    
                    if isRunning and not isPaused and Config.AutoJumpEnabled then
                        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
                        task.wait(0.05)
                        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
                    end
                end
            else
                task.wait(1)
            end
        end
    end)
end

local function stopAutoFeatures()
    if hotspotWatchThread then
        task.cancel(hotspotWatchThread)
        hotspotWatchThread = nil
    end
    if autoJumpThread then
        task.cancel(autoJumpThread)
        autoJumpThread = nil
    end
    -- reset semua state hotspot pause saat bot di-stop
    isHotspotPaused      = false
    hotspotPendingSince  = nil
    hotspotPendingTarget = nil
    hotspotPendingDelay  = nil
    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
end

-- MAIN LOOP
local function mainLoop()
    updateStats()
    setStatus("Running", Theme.Accent)
    DebugLabel.Text = "Bot dimulai..."

    local equipped = false
    for attempt = 1, 3 do
        if equipRodByName(selectedRodName) then equipped = true; break end
        DebugLabel.Text = "Equip gagal, coba "..attempt.."/3"
        task.wait(0.5)
    end
    if not equipped then
        setStatus("Equip gagal!", Theme.Danger)
        isRunning = false
        StartBtn.Text             = "START"
        StartBtn.BackgroundColor3 = Theme.Accent
        return
    end

    castRod()
    local hasCast = true

    while isRunning do
        if isPaused then
            setStatus("Paused", Theme.SubText)
            waitWhilePaused()
            if not isRunning then break end
            setStatus("Running", Theme.Accent)
            equipRodByName(selectedRodName)
            castRod()
            hasCast = true
        end

        updateTimer()

        if isPreFishingActive() then
            handleFishPhase(); hasCast = true
        elseif isBarActive() then
			handleBarPhase(); hasCast = false
			local postCatchDelay
			if randomDelayEnabled then
				postCatchDelay = RandomDelayMinTime + math.random() * (RandomDelayMaxTime - RandomDelayMinTime)
				postCatchDelay = math.round(postCatchDelay * 100) / 100
				DebugLabel.Text = string.format("Delay acak: %.2fs", postCatchDelay)
			else
				postCatchDelay = 0.5
			end
			task.wait(postCatchDelay)
        else
            if not hasCast then
                setStatus("Idle - Cast...", Theme.SubText)
                if not isRodEquipped(selectedRodName) then equipRodByName(selectedRodName) end
                castRod(); hasCast = true
            elseif tick() - lastCastTime >= Config.CastTimeout then
                setStatus("Timeout - Retry", Theme.Danger)
                DebugLabel.Text = "Cast timeout, ulang..."
                hasCast = false
            end
        end

        task.wait(Config.ScanInterval)
    end

    setStatus("Stopped", Theme.SubText)
    setAction("-")
    unequipRod()
end

-- START / STOP
StartBtn.MouseButton1Click:Connect(function()
    if isRunning then
        isRunning  = false
        isPaused   = false
        PauseBtn.Text             = "Pause"
        PauseBtn.BackgroundColor3 = Theme.PanelAlt
        StartBtn.Text             = "START"
        StartBtn.BackgroundColor3 = Theme.Accent
        setStatus("Stopped", Theme.SubText)
        botStartTime    = 0
        TimerValue.Text = "00:00:00"
        
        stopAutoFeatures()
    else
        if not selectedRodName then notify("Error", "Pilih rod dulu!"); return end
        isRunning    = true
        botStartTime = tick()
        StartBtn.Text             = "STOP"
        StartBtn.BackgroundColor3 = Theme.Danger
        
        startAutoFeatures()
        
        task.spawn(mainLoop)
    end
end)

ResetBtn.MouseButton1Click:Connect(function()
    fishCount = 0; updateStats()
    botStartTime    = isRunning and tick() or 0
    TimerValue.Text = "00:00:00"
    DebugLabel.Text = "Stats direset"
    notify("Reset", "Counter dan timer direset!")
end)

-- CLOSE
closeBtn.MouseButton1Click:Connect(function()
    isRunning = false
    stopTracerLoop()
    ScreenGui:Destroy()
end)

--  INIT
switchTab("main")
notify("Auto Fish", "UI loaded! Pilih rod lalu tap START.")
DebugLabel.Text = "Siap. Pilih rod & tekan START."