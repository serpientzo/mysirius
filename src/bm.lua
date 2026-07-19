local Players             = game:GetService("Players")
local UserInputService    = game:GetService("UserInputService")
local StarterGui          = game:GetService("StarterGui")
local GuiService          = game:GetService("GuiService")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")
local TweenService        = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

-- ===================== CONFIG =====================
local Config = {
    ScanInterval     = 0.05,
    TapOffsetX       = 0,
    TapOffsetY       = 0,

    MineTapDuration  = 0.02,   -- durasi tap saat timing-bar mining
    MineReactionMin  = 0.03,   -- reaction buffer sebelum marker masuk zone (dipakai kalau random OFF)
    MineTimeout      = 15,     -- batas waktu per minigame sebelum dianggap gagal/skip

    DragMoveSteps    = 8,
    DragMoveDelay    = 0.02,
    DragHoldAfter    = 0.05,

    OreLimit        = 100,
    OreLimitEnabled = false,

    BoulderReachRadius = 12,

	UseKeyboardTap      = false, -- Tambahkan baris ini
}

local ConfigMeta = {
    { key = "ScanInterval",    label = "Scan Interval",     min = 0.01, max = 0.5,  step = 0.01 },
    { key = "MineTapDuration", label = "Mine Tap Duration", min = 0.01, max = 0.3,  step = 0.01 },
    { key = "MineTimeout",     label = "Mine Timeout (s)",  min = 5,    max = 60,   step = 1    },
    { key = "TapOffsetX",      label = "Tap Offset X (px)", min = -200, max = 200,  step = 1    },
    { key = "TapOffsetY",      label = "Tap Offset Y (px)", min = -200, max = 200,  step = 1    },
    { key = "OreLimit",             label = "Ore Limit",          min = 1,     max = 1000,  step = 1    },
    { key = "BoulderReachRadius",   label = "Boulder Reach (studs)", min = 5,  max = 30,    step = 1    },
	{ key = "UseKeyboardTap", label = "Use Keyboard Tap (Space)", min = 0, max = 1, step = 1 }, -- Tambahkan baris ini

}

-- ===================== STATE =====================
local isRunning            = false
local isPaused             = false
local pauseStartTime       = 0
local selectedPickaxeName  = nil
local oreCount              = 0
local botStartTime         = 0
local activeTab            = "main"
local DebugLabel

-- local toolReadyPayload = nil
-- local boundPickaxe      = nil

-- STATE RANDOMIZE: Drag (PreMining)
local dragRandomEnabled = true
local DragMoveStepsMin  = 6
local DragMoveStepsMax  = 12
local DragMoveDelayMin  = 0.015
local DragMoveDelayMax  = 0.035
local DragHoldAfterMin  = 0.03
local DragHoldAfterMax  = 0.09
local DragJitterPixels  = 4

-- STATE RANDOMIZE: Mine Tap (timing bar)
local mineTapRandomEnabled = true
local MineTapDurationMin   = 0.008
local MineTapDurationMax   = 0.03
local MineReactionMin      = 0.02
local MineReactionMax      = 0.08

-- ===================== THEME =====================
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
if PlayerGui:FindFirstChild("Miner") then
    PlayerGui:FindFirstChild("Miner"):Destroy()
end

-- SCREEN GUI
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name           = "Miner"
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

local headerPadding = Instance.new("UIPadding", Header)
headerPadding.PaddingLeft   = UDim.new(0, 14)
headerPadding.PaddingRight  = UDim.new(0, 14)
headerPadding.PaddingTop    = UDim.new(0, 6)
headerPadding.PaddingBottom = UDim.new(0, 6)

local titleLabel = Instance.new("TextLabel", Header)
titleLabel.Size                 = UDim2.new(1, 0, 1, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text                 = "Miner"
titleLabel.TextColor3           = Theme.Text
titleLabel.TextSize             = 13
titleLabel.Font                 = Enum.Font.GothamBold
titleLabel.TextXAlignment       = Enum.TextXAlignment.Center
titleLabel.ZIndex               = 6
titleLabel.Parent               = Header

local minimizeBtn = Instance.new("TextButton", Header)
minimizeBtn.Size             = UDim2.new(0, 26, 0, 26)
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

-- TAB BAR (Main, Tracer, Config, Commands)
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
    btn.Size             = UDim2.new(1/4, -2, 1, 0) -- 4 tab
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

local mainTabBtn,     mainPage     = createTab("main",     "Main",     "", 1)
local tracerTabBtn,   tracerPage   = createTab("tracer",   "Tracer",   "", 2) -- Tambah tab tracer
local configTabBtn,   configPage   = createTab("config",   "Config",   "", 3)
local commandsTabBtn, commandsPage = createTab("commands", "Cmds",     "", 4)

mainTabBtn.MouseButton1Click:Connect(function()     switchTab("main")     end)
tracerTabBtn.MouseButton1Click:Connect(function()   switchTab("tracer")   end) -- Handler tracer
configTabBtn.MouseButton1Click:Connect(function()   switchTab("config")   end)
commandsTabBtn.MouseButton1Click:Connect(function()  switchTab("commands") end)

-- ===================== UI HELPERS =====================
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

-- Tambahkan helper untuk legend tracer
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

local function notify(t, msg)
    pcall(function() StarterGui:SetCore("SendNotification", {Title=t, Text=msg, Duration=3}) end)
end

-- ===================== MAIN TAB =====================
local o = 0

makeSectionLabel(mainPage, "STATUS", o) o+=1

local StatusValue  = makeStatRow(mainPage, "Status",      o) o+=1
local TimerValue   = makeStatRow(mainPage, "Runtime",     o) o+=1
local OreValue     = makeStatRow(mainPage, "Total Ore",   o) o+=1
local ActionValue  = makeStatRow(mainPage, "Action",      o) o+=1

StatusValue.Text = "Idle"
TimerValue.Text  = "00:00:00"
OreValue.Text     = "0"
ActionValue.Text = "-"

makeDivider(mainPage, o) o+=1

-- ============ PICKAXE DROPDOWN SELECTOR ============
makeSectionLabel(mainPage, "PICKAXE SELECTOR", o) o+=1

local pickaxeDropdownCard = makeCard(mainPage, o, 40) o+=1
local pickaxeDropdownPad = Instance.new("UIPadding", pickaxeDropdownCard)
pickaxeDropdownPad.PaddingLeft = UDim.new(0, 10)
pickaxeDropdownPad.PaddingRight = UDim.new(0, 10)

local pickaxeSelectedLabel = Instance.new("TextButton", pickaxeDropdownCard)
pickaxeSelectedLabel.Size = UDim2.new(1, -30, 1, 0)
pickaxeSelectedLabel.BackgroundTransparency = 1
pickaxeSelectedLabel.Text = "Pilih Pickaxe..."
pickaxeSelectedLabel.TextColor3 = Theme.SubText
pickaxeSelectedLabel.TextSize = 11
pickaxeSelectedLabel.Font = Enum.Font.GothamMedium
pickaxeSelectedLabel.TextXAlignment = Enum.TextXAlignment.Left
pickaxeSelectedLabel.AutoButtonColor = false

local pickaxeDropdownList = Instance.new("ScrollingFrame", mainPage)
pickaxeDropdownList.Name = "PickaxeDropdownList"
pickaxeDropdownList.Size = UDim2.new(1, 0, 0, 0)
pickaxeDropdownList.Position = UDim2.new(0, 0, 0, 0)
pickaxeDropdownList.BackgroundColor3 = Theme.Panel
pickaxeDropdownList.BorderSizePixel = 0
pickaxeDropdownList.ScrollBarThickness = 3
pickaxeDropdownList.ScrollBarImageColor3 = Theme.Border
pickaxeDropdownList.Visible = false
pickaxeDropdownList.ZIndex = 10
pickaxeDropdownList.LayoutOrder = o
o += 1
Instance.new("UICorner", pickaxeDropdownList).CornerRadius = UDim.new(0, 8)
local pickaxeListStroke = Instance.new("UIStroke", pickaxeDropdownList)
pickaxeListStroke.Color = Theme.Border
pickaxeListStroke.Thickness = 1

local pickaxeListLayout = Instance.new("UIListLayout", pickaxeDropdownList)
pickaxeListLayout.SortOrder = Enum.SortOrder.LayoutOrder
pickaxeListLayout.Padding = UDim.new(0, 2)

local pickaxeListPad = Instance.new("UIPadding", pickaxeDropdownList)
pickaxeListPad.PaddingLeft = UDim.new(0, 4)
pickaxeListPad.PaddingRight = UDim.new(0, 4)
pickaxeListPad.PaddingTop = UDim.new(0, 4)
pickaxeListPad.PaddingBottom = UDim.new(0, 4)

local isDropdownOpen = false
local dropdownItems = {}

-- ROD -> PICKAXE: scan pakai attribute IsPickaxe, bukan match nama string
local function scanPickaxes()
    local pickaxes, seen = {}, {}
    for _, c in ipairs({LocalPlayer.Backpack, LocalPlayer.Character}) do
        if c then
            for _, t in ipairs(c:GetChildren()) do
                if t:IsA("Tool") and t:GetAttribute("IsPickaxe") == true and not seen[t.Name] then
                    seen[t.Name] = true
                    table.insert(pickaxes, t.Name)
                end
            end
        end
    end
    return pickaxes
end

local function findPickaxe(name)
    for _, c in ipairs({LocalPlayer.Backpack, LocalPlayer.Character}) do
        if c and c:FindFirstChild(name) then return c:FindFirstChild(name) end
    end
end

local closeDropdown -- forward declare

local function renderDropdownList(pickaxeList)
    for _, item in ipairs(dropdownItems) do
        item:Destroy()
    end
    dropdownItems = {}

    if #pickaxeList == 0 then
        local emptyItem = Instance.new("TextButton", pickaxeDropdownList)
        emptyItem.Size = UDim2.new(1, 0, 0, 30)
        emptyItem.BackgroundColor3 = Theme.PanelAlt
        emptyItem.Text = "Tidak ada pickaxe"
        emptyItem.TextColor3 = Theme.SubText
        emptyItem.TextSize = 10
        emptyItem.Font = Enum.Font.Gotham
        emptyItem.AutoButtonColor = false
        emptyItem.BorderSizePixel = 0
        Instance.new("UICorner", emptyItem).CornerRadius = UDim.new(0, 6)
        table.insert(dropdownItems, emptyItem)
        return
    end

    for i, name in ipairs(pickaxeList) do
        local isSelected = (name == selectedPickaxeName)

        local item = Instance.new("TextButton", pickaxeDropdownList)
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
            selectedPickaxeName = name
            pickaxeSelectedLabel.Text = name
            pickaxeSelectedLabel.TextColor3 = Theme.Text
            pickaxeSelectedLabel.Font = Enum.Font.GothamBold
            DebugLabel.Text = "Pickaxe: " .. name
            closeDropdown()
            renderDropdownList(pickaxeList)
        end)

        item.MouseEnter:Connect(function()
            if name ~= selectedPickaxeName then
                TweenService:Create(item, TweenInfo.new(0.12), {BackgroundColor3 = Theme.Border}):Play()
            end
        end)
        item.MouseLeave:Connect(function()
            if name ~= selectedPickaxeName then
                TweenService:Create(item, TweenInfo.new(0.12), {BackgroundColor3 = Theme.PanelAlt}):Play()
            end
        end)

        table.insert(dropdownItems, item)
    end

    local totalHeight = #pickaxeList * 34 + 8
    pickaxeDropdownList.CanvasSize = UDim2.new(0, 0, 0, totalHeight)
end

local function openDropdown()
    if isDropdownOpen then return end
    isDropdownOpen = true

    local absoluteY = pickaxeDropdownCard.AbsolutePosition.Y + pickaxeDropdownCard.AbsoluteSize.Y
    local guiY = absoluteY - Main.AbsolutePosition.Y

    local pickaxes = scanPickaxes()
    renderDropdownList(pickaxes)

    local maxHeight = math.min(180, #dropdownItems * 34 + 16)
    pickaxeDropdownList.Position = UDim2.new(0, 0, 0, guiY + 4)
    pickaxeDropdownList.Visible = true
    TweenService:Create(pickaxeDropdownList, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
        Size = UDim2.new(1, 0, 0, maxHeight)
    }):Play()
end

closeDropdown = function()
    if not isDropdownOpen then return end
    isDropdownOpen = false

    TweenService:Create(pickaxeDropdownList, TweenInfo.new(0.15, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
        Size = UDim2.new(1, 0, 0, 0)
    }):Play()

    task.delay(0.15, function()
        if not isDropdownOpen then
            pickaxeDropdownList.Visible = false
        end
    end)
end

pickaxeSelectedLabel.MouseButton1Click:Connect(function()
    if isDropdownOpen then
        closeDropdown()
    else
        openDropdown()
    end
end)

UserInputService.InputBegan:Connect(function(input)
    if not isDropdownOpen then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then
        local mousePos = UserInputService:GetMouseLocation()
        local dropPos = pickaxeDropdownList.AbsolutePosition
        local dropSize = pickaxeDropdownList.AbsoluteSize
        local cardPos = pickaxeDropdownCard.AbsolutePosition
        local cardSize = pickaxeDropdownCard.AbsoluteSize

        local inDropdown = mousePos.X >= dropPos.X and mousePos.X <= dropPos.X + dropSize.X
                       and mousePos.Y >= dropPos.Y and mousePos.Y <= dropPos.Y + dropSize.Y
        local inCard = mousePos.X >= cardPos.X and mousePos.X <= cardPos.X + cardSize.X
                   and mousePos.Y >= cardPos.Y and mousePos.Y <= cardPos.Y + cardSize.Y

        if not inDropdown and not inCard then
            closeDropdown()
        end
    end
end)

pickaxeSelectedLabel.Text = "Pilih Pickaxe..."

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
DebugLabel.Text                 = "Log: Siap. Pilih pickaxe & tekan START."
DebugLabel.TextColor3           = Theme.SubText
DebugLabel.TextSize             = 9
DebugLabel.Font                 = Enum.Font.Gotham
DebugLabel.TextXAlignment       = Enum.TextXAlignment.Left
DebugLabel.TextTruncate         = Enum.TextTruncate.AtEnd

-- ===================== HELPERS KARAKTER =====================
local function getHRP()
    local c = LocalPlayer.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end
local function getHumanoid()
    local c = LocalPlayer.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

-- ===================== TRACER TAB ===================== -- TAMBAHAN BARU
local tt = 0 -- Variable untuk layout order di tab tracer
makeSectionLabel(tracerPage, "BOULDER & ZONE INFO", tt) tt+=1

local TracerStatusValue = makeStatRow(tracerPage, "Status",        tt) tt+=1
local TracerCountValue  = makeStatRow(tracerPage, "Boulder/Zona Aktif",    tt) tt+=1
local TracerNearValue   = makeStatRow(tracerPage, "Terdekat", tt) tt+=1
local TracerDistValue   = makeStatRow(tracerPage, "Jarak",         tt) tt+=1

TracerStatusValue.Text = "Tidak aktif"
TracerCountValue.Text  = "0 / 0"
TracerNearValue.Text   = "-"
TracerDistValue.Text   = "-"

makeDivider(tracerPage, tt) tt+=1
makeSectionLabel(tracerPage, "TRACER CONTROL", tt) tt+=1

local TracerBtn = makeButton(tracerPage, "Tracer: OFF", Theme.PanelAlt, tt) tt+=1

local FilterZoneBtn = makeButton(tracerPage, "Filter: Tampilkan Semua", Theme.PanelAlt, tt) tt+=1

makeDivider(tracerPage, tt) tt+=1
makeSectionLabel(tracerPage, "KETERANGAN WARNA", tt) tt+=1

makeLegendRow(tracerPage, Color3.fromRGB(255,255,255),  "Putih: Target terdekat",      tt) tt+=1
makeLegendRow(tracerPage, Color3.fromRGB(100, 180, 255), "Biru: Mining Zone aktif",      tt) tt+=1
makeLegendRow(tracerPage, Color3.fromRGB(255,220,50),   "Kuning: Jarak 16–50 studs",      tt) tt+=1
makeLegendRow(tracerPage, Color3.fromRGB(255,80,80),    "Merah: Jarak > 50 studs",       tt) tt+=1

-- ===================== TRACER LOGIC ===================== -- TAMBAHAN BARU
local tracerEnabled   = false -- State tracer
local tracerThread    = nil   -- Thread untuk loop tracer
local TracerObjects   = {}    -- Store drawing objects (digunakan seperti HotspotTracers di Fisher)
local showOnlyActiveZone = false -- Filter: hanya tampilkan boulder/zone yang mining zone-nya aktif

local function boulderHasActiveZone(model)
    for _, ore in ipairs(model:GetChildren()) do
        if ore.Name:match("^Ore_%d+$") then
            local mz = ore:FindFirstChild("MiningZone")
            if mz and mz.Enabled == true then
                return true
            end
        end
    end
    return false
end

local function getActiveBoulders()
    local active = {}
    local activeStones = workspace:FindFirstChild("Main") and workspace.Main:FindFirstChild("ActiveMiningStones")
    if not activeStones then
        return active
    end
    for _, model in ipairs(activeStones:GetChildren()) do
        -- Asumsikan objek aktif adalah Model
        if model:IsA("Model") then
            -- Ambil posisi pusat model
            local ok, center = pcall(function() return model:GetBoundingBox() end)
            if ok then
                table.insert(active, {
                    name = model.Name,
                    position = center.Position,
                    hasZone = boulderHasActiveZone(model)
                })
            end
        end
    end
    return active
end

-- Fungsi untuk mendapatkan mining zone aktif (path disesuaikan)
local function getActiveMiningZones()
    local active = {}
    local activeStones = workspace:FindFirstChild("Main") and workspace.Main:FindFirstChild("ActiveMiningStones")
    if not activeStones then
        return active
    end

    -- Fungsi rekursif untuk mencari MiningZone
    local function searchMiningZones(parent)
        for _, child in ipairs(parent:GetChildren()) do
            if child.Name == "MiningZone" and child:IsA("BasePart") then -- Sesuaikan tipe jika perlu (Model, Part, MeshPart, dll)
                -- Ambil posisi part tersebut
                table.insert(active, { name = "MZ_"..child.Parent.Name, position = child.Position }) -- Nama bisa diambil dari parent (Ore_XX) atau parent-nya lagi (MiningStone_XX)
            else
                -- Cari rekursif di dalam child
                searchMiningZones(child)
            end
        end
    end

    searchMiningZones(activeStones) -- Mulai pencarian dari root ActiveMiningStones
    return active
end

-- Fungsi untuk membersihkan tracer sebelumnya
local function clearTracers()
    for _, obj in ipairs(TracerObjects) do -- Gunakan nama variabel yang sama
        pcall(function() obj:Remove() end) -- Amankan pemanggilan Remove
    end
    TracerObjects = {} -- Kosongkan tabel
end

local function updateTracers()
    -- Tambahkan pengecekan keamanan
    if not Drawing then
        print("Error: Drawing API tidak tersedia. Pastikan script adalah LocalScript.")
        return
    end

    clearTracers() -- Bersihkan sebelum menggambar baru
    local hrp = getHRP()
    if not hrp then return end

    local camera     = workspace.CurrentCamera
    local screenSize = camera.ViewportSize
    local fromPos    = Vector2.new(screenSize.X / 2, screenSize.Y * 0.9) -- Titik awal dari bawah tengah layar

    local activeBoulders = getActiveBoulders()
    local activeZones    = getActiveMiningZones()

    if showOnlyActiveZone then
        local filteredBoulders = {}
        for _, b in ipairs(activeBoulders) do
            if b.hasZone then
                table.insert(filteredBoulders, b)
            end
        end
        activeBoulders = filteredBoulders
        -- activeZones biarkan tetap tampil semua, karena zone yang muncul di getActiveMiningZones()
        -- memang representasi dari MiningZone part yang sedang aktif
    end

    local totalActive = #activeBoulders + #activeZones

    -- Update statistik GUI (pastikan elemen ini ada di tracerPage)
    if totalActive == 0 then
        -- Asumsikan elemen-elemen ini sudah didefinisikan di bagian TRACER TAB
        -- Misalnya: TracerStatusValue, TracerCountValue, TracerNearValue, TracerDistValue
        -- Pastikan nama-nama variabel ini sesuai dengan yang dibuat di UI HELPERS
        if TracerStatusValue then TracerStatusValue.Text = "Tidak aktif" end
        if TracerStatusValue then TracerStatusValue.TextColor3 = Theme.SubText end
        if TracerCountValue then TracerCountValue.Text = "0 / 0" end
        if TracerNearValue then TracerNearValue.Text = "-" end
        if TracerDistValue then TracerDistValue.Text = "-" end
    else
        if TracerStatusValue then TracerStatusValue.Text = "Aktif" end
        if TracerStatusValue then TracerStatusValue.TextColor3 = Theme.Yellow end
        if TracerCountValue then TracerCountValue.Text = string.format("%d / %d", #activeBoulders, #activeZones) end
    end

    -- Gabungkan semua posisi untuk mencari yang terdekat secara umum
    local allTargets = {}
    for _, boulder in ipairs(activeBoulders) do
        table.insert(allTargets, { type = "boulder", name = boulder.name, position = boulder.position })
    end
    for _, zone in ipairs(activeZones) do
        table.insert(allTargets, { type = "zone", name = zone.name, position = zone.position })
    end

    local closestTargetIndex = nil
    local closestTargetDist  = math.huge
    for i, target in ipairs(allTargets) do
        local dist = (hrp.Position - target.position).Magnitude
        if dist < closestTargetDist then
            closestTargetDist  = dist
            closestTargetIndex = i
        end
    end

    -- Gambar tracer untuk boulder
    for i, boulder in ipairs(activeBoulders) do
        local screenPos, onScreen = camera:WorldToViewportPoint(boulder.position)
        if screenPos.Z <= 0 then continue end -- Lewati jika di belakang kamera

        local toPos     = Vector2.new(screenPos.X, screenPos.Y)
        local dist      = math.floor((hrp.Position - boulder.position).Magnitude)
        local isClosest = (closestTargetIndex and allTargets[closestTargetIndex].type == "boulder" and allTargets[closestTargetIndex].name == boulder.name)

        local lineColor
        if isClosest then
            lineColor = Color3.fromRGB(255, 255, 255) -- Putih untuk terdekat (boulder atau zone)
        elseif dist <= 50 then
            lineColor = Color3.fromRGB(255, 220, 50) -- Kuning untuk < 50 studs
        else
            lineColor = Color3.fromRGB(255, 80, 80)  -- Merah untuk > 50 studs
        end

        local line           = Drawing.new("Line") -- Buat objek Drawing
        line.Visible         = true
        line.From            = fromPos
        line.To              = toPos
        line.Color           = lineColor
        line.Thickness       = isClosest and 2.5 or (onScreen and 1.5 or 1) -- Lebih tebal untuk terdekat
        line.Transparency    = onScreen and 1 or 0.5
        table.insert(TracerObjects, line) -- Simpan referensi ke tabel

        local labelText = isClosest
            and string.format("%s | %d studs [TERDEKAT]", boulder.name, dist)
            or  string.format("%s | %d studs", boulder.name, dist)

        local label           = Drawing.new("Text")
        label.Visible         = true
        label.Position        = Vector2.new(toPos.X + 6, toPos.Y - 8)
        label.Text            = labelText
        label.Size            = isClosest and 14 or 13
        label.Color           = lineColor
        label.Outline         = true
        label.OutlineColor    = Color3.fromRGB(0, 0, 0)
        label.Font            = Drawing.Fonts.UI
        table.insert(TracerObjects, label)

        local dot          = Drawing.new("Circle")
        dot.Visible        = true
        dot.Position       = toPos
        dot.Radius         = isClosest and 8 or 5
        dot.Color          = lineColor
        dot.Filled         = true
        dot.Thickness      = 1
        dot.Transparency   = 1
        table.insert(TracerObjects, dot)

        if isClosest then -- Lingkaran highlight untuk terdekat
            local ring        = Drawing.new("Circle")
            ring.Visible      = true
            ring.Position     = toPos
            ring.Radius       = 14
            ring.Color        = Color3.fromRGB(255, 255, 255)
            ring.Filled       = false
            ring.Thickness    = 1.5
            ring.Transparency = 0.6
            table.insert(TracerObjects, ring)
        end
    end

    -- Gambar tracer untuk zone aktif
    for _, zone in ipairs(activeZones) do
        local screenPos, onScreen = camera:WorldToViewportPoint(zone.position)
        if screenPos.Z <= 0 then continue end -- Lewati jika di belakang kamera

        local toPos     = Vector2.new(screenPos.X, screenPos.Y)
        local dist      = math.floor((hrp.Position - zone.position).Magnitude)
        local isClosest = (closestTargetIndex and allTargets[closestTargetIndex].type == "zone" and allTargets[closestTargetIndex].name == zone.name)

        -- Gunakan warna biru untuk zone aktif
        local lineColor = isClosest and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(100, 180, 255) -- Putih jika terdekat, biru jika tidak

        local line           = Drawing.new("Line")
        line.Visible         = true
        line.From            = fromPos
        line.To              = toPos
        line.Color           = lineColor
        line.Thickness       = isClosest and 2.5 or 2.0 -- Tebal lebih untuk zone, lebih tebal lagi untuk terdekat
        line.Transparency    = onScreen and 1 or 0.5
        table.insert(TracerObjects, line)

        local label           = Drawing.new("Text")
        label.Visible         = true
        label.Position        = Vector2.new(toPos.X + 6, toPos.Y - 8)
        label.Text            = string.format("%s | %d studs [ZONE%s]", zone.name, dist, isClosest and " TERDEKAT" or "")
        label.Size            = 12
        label.Color           = lineColor
        label.Outline         = true
        label.OutlineColor    = Color3.fromRGB(0, 0, 0)
        label.Font            = Drawing.Fonts.UI
        table.insert(TracerObjects, label)

        local dot          = Drawing.new("Circle")
        dot.Visible        = true
        dot.Position       = toPos
        dot.Radius         = isClosest and 8 or 6 -- Lebih besar jika terdekat
        dot.Color          = lineColor
        dot.Filled         = true
        dot.Thickness      = 1
        dot.Transparency   = 1
        table.insert(TracerObjects, dot)
    end

    -- Update label terdekat jika ada target terdekat
    if closestTargetIndex then
        local closest = allTargets[closestTargetIndex]
        if TracerNearValue then TracerNearValue.Text = closest.name end
        if TracerDistValue then TracerDistValue.Text = string.format("%.1f studs", closestTargetDist) end
        local distColor = closestTargetDist <= 50 and Theme.Yellow or Theme.Danger
        if TracerDistValue then TracerDistValue.TextColor3 = distColor end
    else
        -- Jika tidak ada target aktif, kosongkan label
        if TracerNearValue then TracerNearValue.Text = "-" end
        if TracerDistValue then TracerDistValue.Text = "-" end
        if TracerDistValue then TracerDistValue.TextColor3 = Theme.SubText end
    end
end

-- Fungsi untuk memulai loop tracer
local function startTracerLoop()
    tracerThread = task.spawn(function()
        while tracerEnabled do
            updateTracers()
            task.wait(0.1) -- Update setiap 100ms (atau sesuaikan dengan TracerUpdateRate jika ingin dinamis)
        end
        clearTracers() -- Bersihkan saat disable
        -- Reset GUI stats di sini juga jika perlu
        if TracerStatusValue then TracerStatusValue.Text = "Tidak aktif" end
        if TracerStatusValue then TracerStatusValue.TextColor3 = Theme.SubText end
        if TracerCountValue then TracerCountValue.Text = "0 / 0" end
        if TracerNearValue then TracerNearValue.Text = "-" end
        if TracerDistValue then TracerDistValue.Text = "-" end
    end)
end

-- Fungsi untuk menghentikan loop tracer
local function stopTracerLoop()
    tracerEnabled = false
    clearTracers()
    -- Reset GUI stats di sini juga
    if TracerStatusValue then TracerStatusValue.Text = "Tidak aktif" end
    if TracerStatusValue then TracerStatusValue.TextColor3 = Theme.SubText end
    if TracerCountValue then TracerCountValue.Text = "0 / 0" end
    if TracerNearValue then TracerNearValue.Text = "-" end
    if TracerDistValue then TracerDistValue.Text = "-" end
end

-- Handler untuk tombol Tracer (pastikan TracerBtn sudah didefinisikan)
-- Contoh handler (letakkan di akhir file setelah semua elemen UI dibuat):
-- TracerBtn.MouseButton1Click:Connect(function()
--     tracerEnabled = not tracerEnabled
--     if tracerEnabled then
--         TracerBtn.Text = "Tracer: ON"
--         TracerBtn.BackgroundColor3 = Theme.Green
--         startTracerLoop()
--         notify("Tracer", "Tracer aktif!")
--     else
--         TracerBtn.Text = "Tracer: OFF"
--         TracerBtn.BackgroundColor3 = Theme.PanelAlt
--         stopTracerLoop()
--         notify("Tracer", "Tracer dimatikan.")
--     end
-- end)


-- ===================== CONFIG TAB =====================
local co = 0

makeSectionLabel(configPage, "RANDOMIZE MINIGAME", co) co+=1

-- HELPER buat input row (Min / Max) -- sama seperti punya fish
local ROW_Y = 56

local function updateRcDescGeneric(descLabel, minVal, maxVal, unit, decimals)
    local fmt = "Range: %."..decimals.."f – %."..decimals.."f "..unit
    descLabel.Text = string.format(fmt, minVal, maxVal)
end

local function makeRcInputRow(parentCard, descLabel, labelText, getValue, setValue, otherValue, isMin, hardMin, hardMax, unit, decimals)
    unit = unit or "detik"
    decimals = decimals or 1

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
    box.Text             = string.format("%."..decimals.."f", getValue())
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

    local step =
    decimals == 0 and 1
    or decimals >= 3 and 0.005
    or 0.1

    local function applyValue(raw)
        local num = tonumber(raw)
        if not num then
            box.Text = string.format("%."..decimals.."f", getValue())
            return
        end
        local factor = 10 ^ decimals
        num = math.round(num * factor) / factor
        if isMin then
            num = math.clamp(num, hardMin, otherValue() - step)
            setValue(num)
        else
            num = math.clamp(num, otherValue() + step, hardMax)
            setValue(num)
        end
        box.Text = string.format("%."..decimals.."f", num)
        updateRcDescGeneric(descLabel, isMin and num or getValue(), isMin and getValue() or num, unit, decimals)
    end

    box.Focused:Connect(function()
        TweenService:Create(boxStroke, TweenInfo.new(0.12), {Color = Theme.Accent}):Play()
    end)
    box.FocusLost:Connect(function()
        TweenService:Create(boxStroke, TweenInfo.new(0.12), {Color = Theme.Border}):Play()
        applyValue(box.Text)
    end)

    btnMinus.MouseButton1Click:Connect(function()
        applyValue(string.format("%."..decimals.."f", getValue() - step))
    end)
    btnPlus.MouseButton1Click:Connect(function()
        applyValue(string.format("%."..decimals.."f", getValue() + step))
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

-- generic builder buat card randomize dua-value (Min/Max) + toggle ON/OFF
local function makeRandomCard(parent, order, title, getEnabled, setEnabled, minGetSet, maxGetSet, unit, decimals, hardMin, hardMax)
    local card = Instance.new("Frame", parent)
    card.Size             = UDim2.new(1, 0, 0, 96)
    card.BackgroundColor3 = Theme.Panel
    card.BorderSizePixel  = 0
    card.LayoutOrder      = order
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)

    local pad = Instance.new("UIPadding", card)
    pad.PaddingLeft   = UDim.new(0, 10)
    pad.PaddingRight  = UDim.new(0, 10)
    pad.PaddingTop    = UDim.new(0, 8)
    pad.PaddingBottom = UDim.new(0, 8)

    local titleLbl = Instance.new("TextLabel", card)
    titleLbl.Size                 = UDim2.new(0.65, 0, 0, 20)
    titleLbl.Position             = UDim2.new(0, 0, 0, 0)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text                 = title
    titleLbl.TextColor3           = Theme.Text
    titleLbl.TextSize             = 11
    titleLbl.Font                 = Enum.Font.GothamMedium
    titleLbl.TextXAlignment       = Enum.TextXAlignment.Left

    local descLbl = Instance.new("TextLabel", card)
    descLbl.Size                 = UDim2.new(1, -60, 0, 14)
    descLbl.Position             = UDim2.new(0, 0, 0, 24)
    descLbl.BackgroundTransparency = 1
    descLbl.Text                 = string.format("Range: %."..decimals.."f – %."..decimals.."f %s", minGetSet.get(), maxGetSet.get(), unit)
    descLbl.TextColor3           = Theme.SubText
    descLbl.TextSize             = 9
    descLbl.Font                 = Enum.Font.Gotham
    descLbl.TextXAlignment       = Enum.TextXAlignment.Left

    local toggleBtn = Instance.new("TextButton", card)
    toggleBtn.Size             = UDim2.new(0, 52, 0, 24)
    toggleBtn.Position         = UDim2.new(1, -52, 0, 0)
    toggleBtn.BackgroundColor3 = getEnabled() and Theme.Green or Theme.PanelAlt
    toggleBtn.Text = getEnabled() and "ON" or "OFF"
    toggleBtn.TextColor3 = getEnabled() and Theme.Text or Theme.SubText
    toggleBtn.TextSize         = 10
    toggleBtn.Font             = Enum.Font.GothamBold
    toggleBtn.AutoButtonColor  = false
    toggleBtn.BorderSizePixel  = 0
    Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 12)

    toggleBtn.MouseButton1Click:Connect(function()
        local newState = not getEnabled()
        setEnabled(newState)
        if newState then
            toggleBtn.Text = "ON"; toggleBtn.BackgroundColor3 = Theme.Green; toggleBtn.TextColor3 = Theme.Text
        else
            toggleBtn.Text = "OFF"; toggleBtn.BackgroundColor3 = Theme.PanelAlt; toggleBtn.TextColor3 = Theme.SubText
        end
    end)

    local minLbl, minBox, minMinus, minPlus = makeRcInputRow(
        card, descLbl, "Min", minGetSet.get, minGetSet.set, maxGetSet.get, true, hardMin, hardMax, unit, decimals
    )
    minLbl.Position   = UDim2.new(0, 0,  0, ROW_Y)
    minBox.Position   = UDim2.new(0, 30, 0, ROW_Y)
    minMinus.Position = UDim2.new(0, 76, 0, ROW_Y)
    minPlus.Position  = UDim2.new(0, 102, 0, ROW_Y)

    local maxLbl, maxBox, maxMinus, maxPlus = makeRcInputRow(
        card, descLbl, "Max", maxGetSet.get, maxGetSet.set, minGetSet.get, false, hardMin, hardMax, unit, decimals
    )
    maxLbl.Position   = UDim2.new(0.5, 0,  0, ROW_Y)
    maxBox.Position   = UDim2.new(0.5, 30, 0, ROW_Y)
    maxMinus.Position = UDim2.new(0.5, 76, 0, ROW_Y)
    maxPlus.Position  = UDim2.new(0.5, 102, 0, ROW_Y)

    return card
end

-- CARD: Drag Move Steps (integer, pakai decimals=0)
local dragStepsCard = makeRandomCard(
    configPage, co, "Drag Move Steps",
    function() return dragRandomEnabled end,
    function(v) dragRandomEnabled = v end,
    { get = function() return DragMoveStepsMin end, set = function(v) DragMoveStepsMin = math.floor(v) end },
    { get = function() return DragMoveStepsMax end, set = function(v) DragMoveStepsMax = math.floor(v) end },
    "step", 0, 2, 30
) co += 1

-- CARD: Drag Move Delay
local dragDelayCard = makeRandomCard(
    configPage, co, "Drag Move Delay",
    function() return dragRandomEnabled end,
    function(v) dragRandomEnabled = v end,
    { get = function() return DragMoveDelayMin end, set = function(v) DragMoveDelayMin = v end },
    { get = function() return DragMoveDelayMax end, set = function(v) DragMoveDelayMax = v end },
    "detik", 3, 0.005, 0.2
) co += 1

-- CARD: Drag Hold After
local dragHoldCard = makeRandomCard(
    configPage, co, "Drag Hold After",
    function() return dragRandomEnabled end,
    function(v) dragRandomEnabled = v end,
    { get = function() return DragHoldAfterMin end, set = function(v) DragHoldAfterMin = v end },
    { get = function() return DragHoldAfterMax end, set = function(v) DragHoldAfterMax = v end },
    "detik", 3, 0.01, 0.3
) co += 1

-- CARD: Mine Tap Duration
local mineTapCard = makeRandomCard(
    configPage, co, "Mine Tap Duration",
    function() return mineTapRandomEnabled end,
    function(v) mineTapRandomEnabled = v end,
    { get = function() return MineTapDurationMin end, set = function(v) MineTapDurationMin = v end },
    { get = function() return MineTapDurationMax end, set = function(v) MineTapDurationMax = v end },
    "detik", 3, 0.005, 0.1
) co += 1

-- CARD: Mine Reaction Delay (buffer sebelum marker masuk zone)
local mineReactCard = makeRandomCard(
    configPage, co, "Mine Reaction Delay",
    function() return mineTapRandomEnabled end,
    function(v) mineTapRandomEnabled = v end,
    { get = function() return MineReactionMin end, set = function(v) MineReactionMin = v end },
    { get = function() return MineReactionMax end, set = function(v) MineReactionMax = v end },
    "detik", 3, 0, 0.3
) co += 1

makeDivider(configPage, co) co+=1
makeSectionLabel(configPage, "PENGATURAN BOT", co) co+=1

-- UI TOGGLE (Ore Limit)
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
-- Tambahkan ini sebelum kode OreLimit
local ukCard = createToggleCard(configPage, "Keyboard Tap", "Gunakan tombol spasi untuk tap timing-bar.", "UseKeyboardTap", toggleOrder)
toggleOrder += 1
-- Jangan lupa update nilai toggleOrder untuk olCard
local olCard = createToggleCard(configPage, "Ore Limit", "Auto stop saat total ore tercapai (atur di Ore Limit).", "OreLimitEnabled", toggleOrder)
co = toggleOrder + 1

local configValueLabels = {}

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

-- ===================== COMMANDS TAB =====================
local function triggerCommand(alias)
    local ok, err = pcall(function()
        local tcs = game:GetService("TextChatService")
        local channel = tcs.TextChannels:FindFirstChild("RBXGeneral")
        if not channel then
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

-- ===================== MINIMIZE =====================
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

-- ===================== DRAG WINDOW =====================
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

-- ===================== STATUS HELPERS =====================
local function setStatus(text, color)
    StatusValue.Text       = text
    StatusValue.TextColor3 = color or Theme.Text
end
local function setAction(text)  ActionValue.Text  = text  end
local function updateStats()    OreValue.Text     = tostring(oreCount) end
local function updateTimer()
    if not isRunning or botStartTime == 0 then return end
    local e = tick() - botStartTime
    TimerValue.Text = string.format("%02d:%02d:%02d",
        math.floor(e/3600), math.floor(e%3600/60), math.floor(e%60))
end

-- ===================== TAP / VIEWPORT HELPERS =====================
local function tapAt(x, y, holdTime)
    holdTime = holdTime or 0.05
    VirtualInputManager:SendMouseButtonEvent(math.floor(x), math.floor(y), 0, true,  game, 0)
    task.wait(holdTime)
    VirtualInputManager:SendMouseButtonEvent(math.floor(x), math.floor(y), 0, false, game, 0)
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

local function tapButton(btn, holdTime)
    -- Gunakan keyboard jika konfigurasi mengaktifkannya
    if Config.UseKeyboardTap then
        holdTime = holdTime or Config.MineTapDuration
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game) -- Tekan Spasi
        task.wait(holdTime)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game) -- Lepas Spasi
        return true -- Anggap berhasil karena tidak bisa dicek visibilitas btn
    else
        -- Fungsi mouse click tetap sama
        if not btn or not btn.Visible then return false end
        holdTime = holdTime or Config.MineTapDuration

        local px, py = guiToViewportPos(btn.AbsolutePosition, btn.AbsoluteSize)
        tapAt(px, py, holdTime)
        return true
    end
end

-- ===================== BOULDER / MINING TARGET =====================
local function findNearestBoulder()
    local hrp = getHRP()
    if not hrp then return nil end

    local main = workspace:FindFirstChild("Main")
    local activeStones = main and main:FindFirstChild("ActiveMiningStones")
    if not activeStones then return nil end

    local closest, closestDist = nil, math.huge
    for _, model in ipairs(activeStones:GetChildren()) do
        if model:IsA("Model") then
            local ok, center = pcall(function() return model:GetBoundingBox() end)
            if ok then
                local dist = (hrp.Position - center.Position).Magnitude
                if dist <= Config.BoulderReachRadius and dist < closestDist then
                    closest, closestDist = model, dist
                end
            end
        end
    end
    return closest
end

local function isMiningUIActive()
    return PlayerGui:FindFirstChild("MiningUI") ~= nil
end

-- ===================== PICKAXE EQUIP / EVENTS =====================
local function isPickaxeEquipped(name)
    local char = LocalPlayer.Character
    return char and char:FindFirstChild(name) ~= nil
end

-- local function bindPickaxeEvents(pickaxeTool)
--     if boundPickaxe == pickaxeTool then return end
--     boundPickaxe = pickaxeTool
--     local toolReady = pickaxeTool:FindFirstChild("ToolReady")
--     if toolReady then
--         toolReady.OnClientEvent:Connect(function(payload)
--             toolReadyPayload = payload
--         end)
--     end
-- end

local function equipPickaxeByName(name)
    if not name then
        return false
    end

    setAction("Equip: "..name)

    local hum = getHumanoid()
    if not hum then
        return false
    end

    if isPickaxeEquipped(name) then
        task.wait(0.2)
        return true
    end

    local tool = findPickaxe(name)

    if not tool then
        DebugLabel.Text = "Pickaxe tidak ditemukan: "..name
        return false
    end

    hum:EquipTool(tool)
    task.wait(0.4)

    return true
end

local function unequipPickaxe()
    setAction("Unequip pickaxe")
    local hum = getHumanoid()
    if hum then hum:UnequipTools(); task.wait(0.4) end
end

-- local function triggerMine(pickaxeTool)
--     local mineRemote = pickaxeTool:FindFirstChild("Mine")
--     if not mineRemote then
--         DebugLabel.Text = "Remote 'Mine' tidak ditemukan di tool"
--         return false
--     end
--     local ok, result = pcall(function()
--         return mineRemote:InvokeServer(toolReadyPayload)
--     end)
--     return ok and result
-- end

-- ===================== DRAG PHASE (PreMining) =====================
local function handleDragPhase(dragButton, targetFrame)
    if not dragButton or not targetFrame then
        DebugLabel.Text = "DragButton/TargetFrame tidak ditemukan!"
        return false
    end

    local dragPos = dragButton.AbsolutePosition
    local dragSize = dragButton.AbsoluteSize
    local targetPos = targetFrame.AbsolutePosition
    local targetSize = targetFrame.AbsoluteSize

    local startX, startY = guiToViewportPos(dragPos, dragSize)
    local endX, endY = guiToViewportPos(targetPos, targetSize)

    local steps = Config.DragMoveSteps or 8
    local jitter = 0
    if dragRandomEnabled then
        steps = math.random(DragMoveStepsMin, DragMoveStepsMax)
        jitter = DragJitterPixels or 4
    end

    VirtualInputManager:SendMouseButtonEvent(math.floor(startX), math.floor(startY), 0, true, game, 0)
    task.wait(0.02)

    for step = 1, steps do
        if not isRunning then break end
        local t = step / steps
        local curX = startX + (endX - startX) * t
        local curY = startY + (endY - startY) * t

        if jitter > 0 and step < steps then
            curX = curX + (math.random() * 2 - 1) * jitter
            curY = curY + (math.random() * 2 - 1) * jitter
        end

        local stepDelay = Config.DragMoveDelay or 0.02
        if dragRandomEnabled then
            stepDelay = DragMoveDelayMin + math.random() * (DragMoveDelayMax - DragMoveDelayMin)
        end

        VirtualInputManager:SendMouseMoveEvent(math.floor(curX), math.floor(curY), game)
        task.wait(stepDelay)
    end

    local finalHold = Config.DragHoldAfter or 0.05
    if dragRandomEnabled then
        finalHold = DragHoldAfterMin + math.random() * (DragHoldAfterMax - DragHoldAfterMin)
    end
    task.wait(finalHold)

    VirtualInputManager:SendMouseButtonEvent(math.floor(endX), math.floor(endY), 0, false, game, 0)
    return true
end

-- ===================== MINING PHASE (timing bar, prediktif) =====================
local function handleMiningPhase(miningUIRoot, sweepSpeed)
    local miningHolder = miningUIRoot:FindFirstChild("MiningHolder")
    if not miningHolder then
        DebugLabel.Text = "MiningHolder tidak ditemukan di handleMiningPhase"
        return
    end
    local miningFrame = miningHolder:FindFirstChild("MiningFrame")
    if not miningFrame then return end
    local barContainer = miningFrame:FindFirstChild("BarContainer")
    if not barContainer then return end
    local bar = barContainer:FindFirstChild("Bar")
    local point = barContainer:FindFirstChild("Point")
    if not (bar and point) then return end

    local phaseStart = tick()
    local pollInterval = 0.01 -- polling tiap 10ms, jauh lebih presisi dari task.wait besar

    while isRunning and miningUIRoot.Parent and miningHolder.Visible do
        if tick() - phaseStart > (Config.MineTimeout or 15) then
            DebugLabel.Text = "Mining phase timeout"
            break -- Keluar dari loop
        end

        local markerPos = point.Position.X.Scale
        local barPos    = bar.Position.X.Scale
        local barWidth  = bar.Size.X.Scale
        local zoneMin   = barPos - barWidth / 2
        local zoneMax   = barPos + barWidth / 2

        -- *** PERBAIKAN LOGIKA ***
        -- Gunakan logika berbasis waktu dan prediksi seperti di Fisher
        -- atau cukup reaksi cepat saat masuk zone
        -- Pendekatan reaksi cepat masih valid dan mudah dipahami.
        if markerPos >= zoneMin and markerPos <= zoneMax then
            -- Marker sudah di dalam zone SEKARANG, tap langsung
            local reactionDelay = Config.MineReactionMin or 0.03
            if mineTapRandomEnabled then
                reactionDelay = MineReactionMin + math.random() * (MineReactionMax - MineReactionMin)
            end
            task.wait(reactionDelay)

            -- Re-cek posisi setelah delay kecil, karena marker terus bergerak
            -- Perbarui posisi sekarang
            local currentMarkerPos = point.Position.X.Scale
            if currentMarkerPos >= zoneMin and currentMarkerPos <= zoneMax then
                local tapDur = Config.MineTapDuration or 0.02
                if mineTapRandomEnabled then
                    tapDur = MineTapDurationMin + math.random() * (MineTapDurationMax - MineTapDurationMin)
                end
                tapButton(bar, tapDur)
                setStatus("Tap!", Theme.Green)

                task.wait(0.15) -- kasih waktu UI transisi ke round berikutnya / reposisi zone
            else
                -- Jika sudah keluar zone gara-gara delay, lanjut polling
                task.wait(pollInterval)
            end
        else
            -- Tidak di dalam zone, lanjut polling
            task.wait(pollInterval)
        end
    end
    -- Loop selesai karena UI hilang, timeout, atau isRunning = false
end

-- ===================== ORCHESTRATOR MINIGAME =====================
local function runMiningMinigame(miningUIRoot)
    local requiredHits = miningUIRoot:GetAttribute("RequiredHits")
    local sweepSpeed = miningUIRoot:GetAttribute("SweepSpeed")
    local rounds = miningUIRoot:GetAttribute("Rounds")

    if not (requiredHits and sweepSpeed and rounds) then
        DebugLabel.Text = "Config minigame tidak lengkap"
        return
    end

    local preMiningHolder = miningUIRoot:FindFirstChild("PreMiningHolder")
    local miningHolder = miningUIRoot:FindFirstChild("MiningHolder")
    if not (preMiningHolder and miningHolder) then
        DebugLabel.Text = "Struktur MiningUI tidak lengkap"
        return
    end

    local dragButton = preMiningHolder:FindFirstChild("DragButton")
    local targetFrame = preMiningHolder:FindFirstChild("TargetFrame")

    if not dragButton or not targetFrame then
        DebugLabel.Text = "DragButton atau TargetFrame tidak ditemukan di PreMiningHolder"
        return
    end

    for round = 1, rounds do
        if not isRunning then break end
        if not miningUIRoot.Parent then break end

        -- Tunggu PreMiningHolder muncul (jika belum, misalnya di round 2+)
        local waitStart = tick()
        while tick() - waitStart < 3 do
            if preMiningHolder.Visible then break end
            if not isRunning or not miningUIRoot.Parent then return end
            task.wait(0.03)
        end

        if not preMiningHolder.Visible then
            DebugLabel.Text = "PreMiningHolder tidak muncul sebelum round " .. round .. ", skip."
            continue
        end

        setStatus(string.format("Drag Round %d/%d", round, rounds), Theme.Accent)
        handleDragPhase(dragButton, targetFrame)

        -- *** PERUBAHAN UTAMA: Tunggu sampai MiningHolder VISIBLE, bukan PreMiningHolder invisible ***
        local miningStartWaitStart = tick()
        while not miningHolder.Visible do -- Tunggu sampai MiningHolder muncul
            if not isRunning or not miningUIRoot.Parent then
                DebugLabel.Text = "MiningUI tidak valid saat menunggu MiningHolder (Round " .. round .. ")."
                return -- Keluar dari runMiningMinigame
            end
            if tick() - miningStartWaitStart > 5 then -- Timeout tambahan untuk keamanan
                DebugLabel.Text = string.format("MiningHolder tidak muncul setelah drag round %d, timeout.", round)
                -- Coba drag lagi sekali sebagai fallback
                handleDragPhase(dragButton, targetFrame)
                miningStartWaitStart = tick() -- Reset timer
                -- Tunggu lagi
                while not miningHolder.Visible and tick() - miningStartWaitStart < 3 do
                    if not isRunning or not miningUIRoot.Parent then return end
                    task.wait(0.03)
                end
                if not miningHolder.Visible then
                    DebugLabel.Text = string.format("Retry drag gagal, lanjut round %d.", round + 1)
                    break -- Keluar dari loop tunggu miningHolder, lanjut ke round berikutnya
                else
                    DebugLabel.Text = "MiningHolder muncul setelah retry drag."
                end
            end
            task.wait(0.03) -- Cek ulang setiap 30ms
        end

        -- Jika MiningHolder muncul, lanjutkan ke handleMiningPhase
        if miningHolder.Visible then
            setStatus(string.format("Bar Round %d/%d", round, rounds), Theme.Accent)
            handleMiningPhase(miningUIRoot, sweepSpeed)
        else
            -- Jika tetap tidak muncul setelah timeout dan retry, lanjut ke round berikutnya
            continue
        end

        -- Tunggu sampai MiningHolder hilang sebelum lanjut ke round berikutnya
        local miningEndWaitStart = tick()
        while miningHolder.Visible do
            if not isRunning or not miningUIRoot.Parent then
                DebugLabel.Text = "MiningUI tidak valid saat menunggu selesai (Round " .. round .. ")."
                return
            end
            if tick() - miningEndWaitStart > 10 then -- Timeout jika mining phase terlalu lama
                DebugLabel.Text = string.format("MiningHolder masih visible setelah 10s (Round %d), skip.", round)
                break
            end
            task.wait(0.03)
        end

        task.wait(0.1) -- Delay kecil sebelum round berikutnya
    end

    -- *** PENGECEKAN JIKA MINING SELESAI SECARA NORMAL ***
    -- Kondisi utama untuk "ore selesai" adalah jika UI MiningUI benar-benar menghilang dari PlayerGui
    if not miningUIRoot.Parent then
        oreCount += 1
        updateStats()
        DebugLabel.Text = string.format("Ore ke-%d selesai", oreCount)
        notify("Mining Selesai!", string.format("Total: %d", oreCount))

        if Config.OreLimitEnabled and oreCount >= Config.OreLimit then
            notify("Ore Limit!", string.format("Target %d ore tercapai. Bot berhenti.", Config.OreLimit))
            DebugLabel.Text = string.format("LIMIT TERCAPAI: %d ore. Bot stop.", Config.OreLimit)
            setStatus("Limit Tercapai!", Theme.Yellow)
            isRunning  = false
            isPaused   = false
            PauseBtn.Text             = "Pause"
            PauseBtn.BackgroundColor3 = Theme.PanelAlt
            StartBtn.Text             = "START"
            StartBtn.BackgroundColor3 = Theme.Accent
            botStartTime    = 0
            TimerValue.Text = "00:00:00"
            stopAutoFeatures() -- Panggil stopAutoFeatures
            unequipPickaxe()
        end
    else
        -- Jika UI tidak menghilang, tapi loop round selesai (karena error, timeout, dll)
        DebugLabel.Text = "Minigame selesai (loop round selesai), tapi UI belum hilang."
    end
end

-- ===================== PAUSE =====================
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
        unequipPickaxe() -- Unequip saat pause
        notify("Pause", "Bot dijeda.")
    else
        botStartTime              = botStartTime + (tick() - pauseStartTime)
        pauseStartTime            = 0
        PauseBtn.Text             = "Pause"
        PauseBtn.BackgroundColor3 = Theme.PanelAlt
        setStatus("Running", Theme.Accent)
        DebugLabel.Text           = "Bot dilanjutkan..."
        equipPickaxeByName(selectedPickaxeName) -- Equip kembali saat resume
        notify("Resume", "Bot dilanjutkan!")
    end
end)

-- ===================== AUTO FEATURES (kosong untuk sekarang, bisa ditambah nanti) =====================
local autoFeaturesThread = nil

local function startAutoFeatures()
    -- Contoh jika nanti ditambah fitur auto-jump, dll.
    -- autoFeaturesThread = task.spawn(function()
    --     while isRunning do
    --         if not isPaused and Config.AutoFeatureEnabled then
    --             -- Logika auto feature
    --         end
    --         task.wait(1) -- Atau interval yang sesuai
    --     end
    -- end)
end

local function stopAutoFeatures()
    -- if autoFeaturesThread then
    --     task.cancel(autoFeaturesThread)
    --     autoFeaturesThread = nil
    -- end
end

-- ===================== MAIN LOOP =====================
local function miningLoop()
    updateStats()
    setStatus("Running", Theme.Accent)
    DebugLabel.Text = "Bot dimulai..."

    -- Coba equip pickaxe awal (opsional, bisa dihapus jika ingin selalu cek di loop)
    --[[
    local equipped = false
    local pickaxeTool = nil
    for attempt = 1, 3 do
        if equipPickaxeByName(selectedPickaxeName) then
            pickaxeTool = findPickaxe(selectedPickaxeName)
            equipped = true
            break
        end
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
    --]]

    while isRunning do
        if isPaused then
            setStatus("Paused", Theme.SubText)
            waitWhilePaused()
            if not isRunning then break end
            setStatus("Running", Theme.Accent)
            equipPickaxeByName(selectedPickaxeName) -- Equip kembali saat resume dari pause manual
        end

        updateTimer()

        if isMiningUIActive() then
            task.wait(Config.ScanInterval)
            continue
        end

        setAction("Cari boulder...")
        local boulder = findNearestBoulder()

        if boulder then
            -- Periksa dan lengkapi pickaxe jika belum
            if not isPickaxeEquipped(selectedPickaxeName) then
                setAction("Re-equip pickaxe...")
                local reEquipped = false
                for attempt = 1, 3 do -- Coba beberapa kali jika gagal
                    if equipPickaxeByName(selectedPickaxeName) then
                        reEquipped = true
                        break
                    end
                    DebugLabel.Text = "Re-equip gagal, coba "..attempt.."/3"
                    task.wait(0.5)
                end
                if not reEquipped then
                    DebugLabel.Text = "Gagal re-equip pickaxe, skip boulder."
                    task.wait(Config.ScanInterval) -- Tunggu sejenak sebelum mencari boulder lain
                    continue -- Lanjut ke iterasi loop berikutnya untuk mencari boulder baru
                end
            end

            setAction("Mining: "..boulder.Name)

            -- Simulasi klik kiri seperti pemain
            VirtualInputManager:SendMouseButtonEvent(
                0,
                0,
                0,
                true,
                game,
                0
            )

            task.wait(0.05)

            VirtualInputManager:SendMouseButtonEvent(
                0,
                0,
                0,
                false,
                game,
                0
            )

            -- Tunggu UI mining muncul
            local miningUIRoot = nil
            local waitStart = tick()

            while tick() - waitStart < 5 do
                miningUIRoot = PlayerGui:FindFirstChild("MiningUI")

                if miningUIRoot then
                    break
                end

                task.wait(0.05)
            end

            if miningUIRoot then
                runMiningMinigame(miningUIRoot)
            else
                DebugLabel.Text = "MiningUI tidak muncul, timeout"
                -- Opsional: Bisa tambahkan logika untuk menunggu sejenak atau langsung lanjut mencari
                -- agar tidak spam klik ke boulder yang sama jika UI gagal muncul.
            end
        else
            setAction("Tidak ada boulder terjangkau")
            task.wait(0.5)
        end

        task.wait(Config.ScanInterval)
    end

    setStatus("Stopped", Theme.SubText)
    setAction("-")
    unequipPickaxe()
end

-- ===================== START / STOP =====================
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
        
        stopAutoFeatures() -- Hentikan thread-thread auto features saat stop
    else
        if not selectedPickaxeName then notify("Error", "Pilih pickaxe dulu!"); return end
        isRunning    = true
        botStartTime = tick()
        StartBtn.Text             = "STOP"
        StartBtn.BackgroundColor3 = Theme.Danger
        
        startAutoFeatures() -- Mulai thread-thread auto features saat start
        
        task.spawn(miningLoop) -- Spawn miningLoop dalam thread baru
    end
end)

ResetBtn.MouseButton1Click:Connect(function()
    oreCount = 0; updateStats()
    botStartTime    = isRunning and tick() or 0
    TimerValue.Text = "00:00:00"
    DebugLabel.Text = "Stats direset"
    notify("Reset", "Counter dan timer direset!")
end)

-- ===================== CLOSE =====================
closeBtn.MouseButton1Click:Connect(function()
    isRunning = false
    stopTracerLoop() -- Tambahkan ini untuk memastikan tracer mati saat close
    ScreenGui:Destroy()
end)

-- ===================== TRACER BUTTON HANDLER ===================== -- TAMBAHAN AKHIR
-- Pastikan variabel-variabel ini didefinisikan sebelumnya di scope global fungsi ini
-- Misalnya: tracerEnabled, TracerBtn, startTracerLoop, stopTracerLoop, notify, Theme
TracerBtn.MouseButton1Click:Connect(function()
    tracerEnabled = not tracerEnabled
    if tracerEnabled then
        TracerBtn.Text             = "Tracer: ON"
        TracerBtn.BackgroundColor3 = Theme.Green
        startTracerLoop() -- Panggil fungsi untuk memulai loop
        notify("Tracer", "Tracer aktif!")
    else
        TracerBtn.Text             = "Tracer: OFF"
        TracerBtn.BackgroundColor3 = Theme.PanelAlt
        stopTracerLoop() -- Panggil fungsi untuk menghentikan loop dan membersihkan
        notify("Tracer", "Tracer dimatikan.")
    end
end)

FilterZoneBtn.MouseButton1Click:Connect(function()
    showOnlyActiveZone = not showOnlyActiveZone
    if showOnlyActiveZone then
        FilterZoneBtn.Text             = "Filter: Zone Aktif Saja"
        FilterZoneBtn.BackgroundColor3 = Theme.Accent
        notify("Filter", "Hanya tampilkan boulder dengan zone aktif.")
    else
        FilterZoneBtn.Text             = "Filter: Tampilkan Semua"
        FilterZoneBtn.BackgroundColor3 = Theme.PanelAlt
        notify("Filter", "Tampilkan semua boulder & zone.")
    end
end)
-- =================================================================

-- ===================== INIT =====================
switchTab("main")
notify("Auto Mining", "UI loaded! Pilih pickaxe lalu tap START.")
DebugLabel.Text = "Siap. Pilih pickaxe & tekan START."
