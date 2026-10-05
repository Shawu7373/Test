print("[Nicotine] Loading...")
if getgenv().Nicotine then pcall(getgenv().Nicotine) end
getgenv().Nicotine = function() end

local F3X_POS = Vector3.new(11, 3, -116)
local BTOOLS_POS = Vector3.new(30.8, 3.2, -62.3)

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local VirtualUser = game:GetService("VirtualUser")
local LP = Players.LocalPlayer
local PG = LP:WaitForChild("PlayerGui", 15)
if not PG then return end

for _, v in ipairs(PG:GetChildren()) do
    if v.Name == "Nicotine" then pcall(function() v:Destroy() end) end
end

local function notify(t, x, d)
    pcall(function()
        StarterGui:SetCore("SendNotification", {Title = t or "Nicotine", Text = x or "", Duration = d or 3})
    end)
end

local FOLDER = "Nicotine"
local FILE = FOLDER .. "/config.json"

local function loadCfg()
    if type(makefolder) == "function" and type(isfolder) == "function" and not isfolder(FOLDER) then
        pcall(makefolder, FOLDER)
    end
    if type(isfile) == "function" and type(readfile) == "function" and isfile(FILE) then
        local ok, c = pcall(readfile, FILE)
        if ok then
            local ok2, d = pcall(function() return HttpService:JSONDecode(c) end)
            if ok2 and type(d) == "table" then return d end
        end
    end
    return {}
end

local function saveCfg(t)
    if type(writefile) == "function" then
        local ok, e = pcall(function() return HttpService:JSONEncode(t) end)
        if ok then pcall(writefile, FILE, e) end
    end
end

local saved = loadCfg()

local S = {
    InfJump = saved.InfJump or false,
    ESP = saved.ESP or false,
    AntiKick = saved.AntiKick or false,
    AntiAFK = saved.AntiAFK or false,
    PlatformSize = saved.PlatformSize or 50,
    Conn = {}, ESPObjects = {}, PlacedParts = {},
    CanInfJump = true, IsGrabbing = false,
    AutoGrabKey = Enum.KeyCode.F
}

local function saveState()
    saveCfg({
        InfJump = S.InfJump, ESP = S.ESP, AntiKick = S.AntiKick,
        AntiAFK = S.AntiAFK, PlatformSize = S.PlatformSize
    })
end

local function getHum() local c = LP.Character; return c and c:FindFirstChildOfClass("Humanoid") end
local function getRoot() local c = LP.Character; return c and c:FindFirstChild("HumanoidRootPart") end
local function getBP() return LP:FindFirstChild("Backpack") end
local function trk(c) table.insert(S.Conn, c); return c end

local function applyAntiKick()
    pcall(function()
        local mt = getrawmetatable(game)
        local old = mt.__namecall
        setreadonly(mt, false)
        mt.__namecall = newcclosure(function(self, ...)
            if getnamecallmethod() == "Kick" and S.AntiKick then
                notify("Anti-Cheat", "Kick blocked", 3)
                return nil
            end
            return old(self, ...)
        end)
        setreadonly(mt, true)
    end)
end

trk(LP.Idled:Connect(function()
    if S.AntiAFK then
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
    end
end))

local TOOL_KW = {"building","f3x","btool","b tool","hammer","move","clone","destroy","import","wrench","lpi","resize","gear"}
local BT_KEYWORDS = {"btool", "b tool", "b-tool", "brick tool", "building tool", "b_tool"}

local function isF3XTool(o)
    if not o or not o:IsA("Tool") then return false end
    local n = o.Name:lower()
    for _, kw in ipairs(TOOL_KW) do if n:find(kw) then return true end end
    return false
end

local function isBtools(o)
    if not o or not o:IsA("Tool") then return false end
    local n = o.Name:lower()
    for _, kw in ipairs(BT_KEYWORDS) do if n:find(kw) then return true end end
    return false
end

local function hasF3X()
    local c = LP.Character
    if c then for _, o in ipairs(c:GetChildren()) do if isF3XTool(o) and not isBtools(o) then return o end end end
    local bp = getBP()
    if bp then for _, o in ipairs(bp:GetChildren()) do if isF3XTool(o) and not isBtools(o) then return o end end end
end

local function hasBtools()
    local c = LP.Character
    if c then for _, o in ipairs(c:GetChildren()) do if isBtools(o) then return o end end end
    local bp = getBP()
    if bp then for _, o in ipairs(bp:GetChildren()) do if isBtools(o) then return o end end end
end

local function equipF3X()
    local t = hasF3X(); if not t then return false end
    local h = getHum(); if h then pcall(function() h:EquipTool(t) end); return true end
end

local function equipBtools()
    local t = hasBtools(); if not t then return false end
    local h = getHum(); if h then pcall(function() h:EquipTool(t) end); return true end
end

local cache = {inv = nil, ev = nil, tool = nil, ts = 0}

local function findRemotes()
    local tool = hasF3X() or hasBtools()
    if not tool then return nil, nil end
    if cache.tool == tool and (tick() - cache.ts) < 30 then return cache.inv, cache.ev end

    local inv, ev = nil, nil
    for _, obj in ipairs(tool:GetDescendants()) do
        if obj:IsA("RemoteFunction") and not inv then inv = obj end
        if obj:IsA("RemoteEvent") and not ev then ev = obj end
    end
    if not inv and not ev and RS then
        for _, obj in ipairs(RS:GetDescendants()) do
            local n = obj.Name:lower()
            if (n:find("f3x") or n:find("btool") or n:find("build") or n:find("sync")) then
                if obj:IsA("RemoteFunction") and not inv then inv = obj end
                if obj:IsA("RemoteEvent") and not ev then ev = obj end
            end
        end
    end
    cache = {inv = inv, ev = ev, tool = tool, ts = tick()}
    return inv, ev
end

local function sendCmd(cmd, args)
    local inv, ev = findRemotes()
    if not inv and not ev then return false end
    local ok = pcall(function()
        if inv then inv:InvokeServer(cmd, args)
        else ev:FireServer(cmd, args) end
    end)
    return ok
end

local function testConn()
    local inv, ev = findRemotes()
    if not inv and not ev then return "Nu am gasit remote. Ia F3X intai." end
    local name = inv and ("RemoteFunction: " .. inv.Name) or ("RemoteEvent: " .. ev.Name)
    return "OK - " .. name
end

local function makePart(size, color, mat)
    local p = Instance.new("Part")
    p.Size = size; p.Anchored = true; p.CanCollide = true
    p.Material = mat or Enum.Material.SmoothPlastic
    p.Color = color or Color3.fromRGB(120,120,130)
    p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
    p.Parent = Workspace
    table.insert(S.PlacedParts, p)
    return p
end

local function clearPlatforms()
    local n = 0
    for _, p in ipairs(S.PlacedParts) do
        if p and p.Parent then pcall(function() p:Destroy() end); n = n + 1 end
    end
    S.PlacedParts = {}
    notify("Nicotine", "Sters " .. n .. " parti", 2)
end

local function platform(above, circle)
    local r = getRoot(); if not r then return end
    local s = S.PlatformSize or 50
    local pos = above and (r.Position + Vector3.new(0,12,0)) or (r.Position + Vector3.new(0,-4,0))
    local inv, ev = findRemotes()
    if inv or ev then
        equipF3X()
        sendCmd("New", {{
            Size = circle and Vector3.new(3,s,s) or Vector3.new(s,3,s),
            CFrame = circle and (CFrame.new(pos) * CFrame.Angles(0,0,math.rad(90))) or CFrame.new(pos),
            Color = circle and Color3.fromRGB(100,200,255) or Color3.fromRGB(255,200,0),
            Anchored = true, Material = "SmoothPlastic",
            Name = "NicotineP_" .. math.random(1000,9999)
        }})
        notify("Platform", "Spawnat!", 2)
    else
        if circle then
            local c = makePart(Vector3.new(3,s,s), Color3.fromRGB(100,200,255))
            c.Shape = Enum.PartType.Cylinder
            c.CFrame = CFrame.new(pos) * CFrame.Angles(0,0,math.rad(90))
        else
            makePart(Vector3.new(s,3,s), Color3.fromRGB(255,200,0)).Position = pos
        end
        notify("Platform", "Local. Ia F3X pt server!", 4)
    end
end

local function grabF3X()
    if S.IsGrabbing then return end
    S.IsGrabbing = true
    local r = getRoot()
    if not r then S.IsGrabbing = false; return end
    if hasF3X() then equipF3X(); S.IsGrabbing = false; return end
    local sv = r.CFrame
    pcall(function() r.CFrame = CFrame.new(F3X_POS) end)
    task.wait(1.2)
    pcall(function() r.CFrame = sv end)
    S.IsGrabbing = false
end

local function grabBtools()
    if S.IsGrabbing then return end
    S.IsGrabbing = true
    local r = getRoot()
    if not r then S.IsGrabbing = false; return end
    if hasBtools() then equipBtools(); S.IsGrabbing = false; return end
    local sv = r.CFrame
    pcall(function() r.CFrame = CFrame.new(BTOOLS_POS) end)
    task.wait(1.2)
    pcall(function() r.CFrame = sv end)
    S.IsGrabbing = false
end

local function collectTargets()
    local list = {}
    for _, p in ipairs(Workspace:GetDescendants()) do
        if p:IsA("BasePart") and not p:FindFirstChildOfClass("Humanoid") and p.Name ~= "HumanoidRootPart" then
            if not (LP.Character and p:IsDescendantOf(LP.Character)) then
                table.insert(list, p)
            end
        end
    end
    return list
end

local function ready()
    if not hasF3X() and not hasBtools() then
        notify("Grief", "Ia F3X sau Btools intai!", 3); return false
    end
    equipF3X() or equipBtools()
    task.wait(0.2)
    local inv, ev = findRemotes()
    if not inv and not ev then
        notify("Grief", "Nu gasesc remote-ul", 3); return false
    end
    return true
end

local function massDelete()
    if not ready() then return end
    local t = collectTargets(); local n = 0
    for i, p in ipairs(t) do
        if p and p.Parent then sendCmd("Remove", {p}); n = n + 1 end
        if i % 15 == 0 then task.wait() end
    end
    notify("Grief", "Sters " .. n .. " parti", 3)
end

local function unanchorAll()
    if not ready() then return end
    local t = collectTargets(); local n = 0
    for i, p in ipairs(t) do
        if p and p.Parent and p.Anchored then
            sendCmd("SyncAnchor", {{Part = p, Anchored = false}}); n = n + 1
        end
        if i % 15 == 0 then task.wait() end
    end
    notify("Grief", "Deancorat " .. n, 3)
end

local function flingParts()
    if not ready() then return end
    local t = collectTargets(); local n = 0
    for i, p in ipairs(t) do
        if p and p.Parent then
            sendCmd("SyncAnchor", {{Part = p, Anchored = false}})
            pcall(function() p.Velocity = Vector3.new(math.random(-400,400), math.random(150,600), math.random(-400,400)) end)
            n = n + 1
        end
        if i % 15 == 0 then task.wait() end
    end
    notify("Grief", "Aruncat " .. n, 3)
end

local function voidAll()
    if not ready() then return end
    local t = collectTargets(); local n = 0
    for i, p in ipairs(t) do
        if p and p.Parent then
            sendCmd("SyncMove", {{Part = p, CFrame = CFrame.new(p.Position.X, -5000, p.Position.Z)}})
            n = n + 1
        end
        if i % 15 == 0 then task.wait() end
    end
    notify("Grief", "Voided " .. n, 3)
end

local function antiF3X()
    local n = 0
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl ~= LP and pl.Character then
            for _, tool in ipairs(pl.Character:GetChildren()) do
                if isF3XTool(tool) then tool.Parent = nil; n = n + 1 end
            end
        end
    end
    notify("Grief", "Ascuns " .. n .. " tools", 3)
end

local cleanESP
local function makeESP(target, color)
    if not target or S.ESPObjects[target] then return end
    local r = target:FindFirstChild("HumanoidRootPart"); if not r then return end
    local hl = Instance.new("Highlight")
    hl.Adornee = target; hl.FillColor = color
    hl.FillTransparency = 0.5; hl.OutlineColor = Color3.fromRGB(255,255,255)
    hl.Parent = target
    local bb = Instance.new("BillboardGui")
    bb.Adornee = r; bb.Size = UDim2.new(0,200,0,40)
    bb.StudsOffset = Vector3.new(0,3,0); bb.AlwaysOnTop = true; bb.Parent = target
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1,0,1,0); l.BackgroundTransparency = 1
    l.TextColor3 = color; l.TextStrokeTransparency = 0; l.TextScaled = true
    l.Font = Enum.Font.GothamBold; l.Text = target.Name; l.Parent = bb
    S.ESPObjects[target] = {hl = hl, bb = bb, lbl = l}
end

local function removeESP(t)
    if S.ESPObjects[t] then
        pcall(function() S.ESPObjects[t].hl:Destroy() end)
        pcall(function() S.ESPObjects[t].bb:Destroy() end)
        S.ESPObjects[t] = nil
    end
end

cleanESP = function()
    local snap = {}
    for t in pairs(S.ESPObjects) do table.insert(snap, t) end
    for _, t in ipairs(snap) do removeESP(t) end
end

task.spawn(function()
    while getgenv().Nicotine do
        task.wait(0.5)
        for t in pairs(S.ESPObjects) do
            if not t.Parent then removeESP(t) end
        end
        if S.ESP then
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LP and p.Character then
                    makeESP(p.Character, Color3.fromRGB(255,100,100))
                    local e = S.ESPObjects[p.Character]
                    if e and e.lbl then
                        local r = getRoot()
                        local tr = p.Character:FindFirstChild("HumanoidRootPart")
                        if r and tr then e.lbl.Text = p.Name .. " | " .. math.floor((r.Position - tr.Position).Magnitude) .. "m" end
                    end
                end
            end
        end
    end
end)

trk(UIS.JumpRequest:Connect(function()
    if not S.InfJump then return end
    local h = getHum(); if not h then return end
    local st = h:GetState()
    if st == Enum.HumanoidStateType.Freefall or st == Enum.HumanoidStateType.Jumping then
        if S.CanInfJump then
            S.CanInfJump = false
            pcall(function() h:ChangeState(Enum.HumanoidStateType.Jumping) end)
            task.delay(0.15, function() S.CanInfJump = true end)
        end
    end
end))

trk(UIS.InputBegan:Connect(function(i, gp)
    if gp then return end
    if i.UserInputType ~= Enum.UserInputType.Keyboard then return end
    if i.KeyCode == S.AutoGrabKey then task.spawn(grabF3X) end
    if i.KeyCode == Enum.KeyCode.H then S.ESP = not S.ESP; if not S.ESP and cleanESP then cleanESP() end; saveState() end
    if i.KeyCode == Enum.KeyCode.J then S.InfJump = not S.InfJump; saveState() end
end))

-- UI
local ACCENT = Color3.fromRGB(140, 90, 230)
local BG = Color3.fromRGB(18, 18, 22)
local PANEL = Color3.fromRGB(26, 26, 32)
local CARD = Color3.fromRGB(34, 34, 42)
local HOVER = Color3.fromRGB(44, 44, 54)
local TEXT = Color3.fromRGB(235, 235, 240)
local SUB = Color3.fromRGB(140, 140, 155)
local RED = Color3.fromRGB(220, 80, 100)
local LINE = Color3.fromRGB(48, 48, 58)

local sg = Instance.new("ScreenGui")
sg.Name = "Nicotine"; sg.ResetOnSpawn = false; sg.IgnoreGuiInset = true
sg.Parent = PG

local scale = Instance.new("UIScale")
scale.Parent = sg
do
    local cam = workspace.CurrentCamera
    if cam then
        local vp = cam.ViewportSize
        local short = math.min(vp.X, vp.Y)
        scale.Scale = math.clamp(short / 620, 0.55, 1)
    end
end

local win = Instance.new("Frame")
win.Size = UDim2.new(0, 340, 0, 500)
win.Position = UDim2.new(0, 16, 0.5, -250)
win.BackgroundColor3 = BG; win.BorderSizePixel = 0
win.Active = true; win.Draggable = true; win.Parent = sg
Instance.new("UICorner", win).CornerRadius = UDim.new(0, 10)
local wst = Instance.new("UIStroke", win)
wst.Color = LINE; wst.Thickness = 1

local tb = Instance.new("Frame")
tb.Size = UDim2.new(1,0,0,38); tb.BackgroundColor3 = PANEL
tb.BorderSizePixel = 0; tb.Parent = win
Instance.new("UICorner", tb).CornerRadius = UDim.new(0, 10)
local tbf = Instance.new("Frame")
tbf.Size = UDim2.new(1,0,0,10); tbf.Position = UDim2.new(0,0,1,-10)
tbf.BackgroundColor3 = PANEL; tbf.BorderSizePixel = 0; tbf.Parent = tb

local t = Instance.new("TextLabel")
t.Size = UDim2.new(1,-60,1,0); t.Position = UDim2.new(0,14,0,0)
t.BackgroundTransparency = 1; t.Text = "Nicotine"
t.TextColor3 = TEXT; t.Font = Enum.Font.GothamBold; t.TextSize = 14
t.TextXAlignment = Enum.TextXAlignment.Left; t.Parent = tb

local close = Instance.new("TextButton")
close.Size = UDim2.new(0,24,0,24); close.Position = UDim2.new(1,-32,0,7)
close.BackgroundColor3 = RED; close.Text = "X"
close.TextColor3 = TEXT; close.Font = Enum.Font.GothamBold; close.TextSize = 11
close.BorderSizePixel = 0; close.Parent = tb
Instance.new("UICorner", close).CornerRadius = UDim.new(0, 5)
close.MouseButton1Click:Connect(function() sg:Destroy() end)

local nav = Instance.new("Frame")
nav.Size = UDim2.new(1,0,0,32); nav.Position = UDim2.new(0,0,0,38)
nav.BackgroundColor3 = PANEL; nav.BorderSizePixel = 0; nav.Parent = win
local nl = Instance.new("UIListLayout", nav)
nl.FillDirection = Enum.FillDirection.Horizontal
nl.Padding = UDim.new(0,2); nl.VerticalAlignment = Enum.VerticalAlignment.Center
nl.HorizontalAlignment = Enum.HorizontalAlignment.Center

local content = Instance.new("ScrollingFrame")
content.Size = UDim2.new(1,-12,1,-82); content.Position = UDim2.new(0,6,0,76)
content.BackgroundTransparency = 1; content.BorderSizePixel = 0
content.CanvasSize = UDim2.new(0,0,0,0); content.AutomaticCanvasSize = Enum.AutomaticSize.Y
content.ScrollBarThickness = 3; content.ScrollBarImageColor3 = ACCENT
content.Parent = win
local cl = Instance.new("UIListLayout", content)
cl.Padding = UDim.new(0,4); cl.SortOrder = Enum.SortOrder.LayoutOrder

local pages, tabBtns = {}, {}
local currentTab

local function switchTab(id)
    for n, p in pairs(pages) do p.Visible = (n == id) end
    for n, b in pairs(tabBtns) do
        b.BackgroundColor3 = (n == id) and ACCENT or CARD
        b.TextColor3 = (n == id) and Color3.fromRGB(255,255,255) or SUB
    end
    currentTab = id
end

local function makeTabBtn(id, label)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 62, 0, 24); b.BackgroundColor3 = CARD
    b.Text = label; b.TextColor3 = SUB
    b.Font = Enum.Font.GothamSemibold; b.TextSize = 11
    b.BorderSizePixel = 0; b.AutoButtonColor = false; b.Parent = nav
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
    b.MouseButton1Click:Connect(function() switchTab(id) end)
    tabBtns[id] = b
end

local function makePage(id)
    local p = Instance.new("Frame")
    p.Size = UDim2.new(1,0,0,0); p.BackgroundTransparency = 1
    p.Visible = false; p.Parent = content
    local pl = Instance.new("UIListLayout", p)
    pl.Padding = UDim.new(0,4); pl.SortOrder = Enum.SortOrder.LayoutOrder
    p.AutomaticSize = Enum.AutomaticSize.Y
    pages[id] = p
    return p
end

makeTabBtn("main", "Main")
makeTabBtn("grief", "Grief")
makeTabBtn("plat", "Platform")
makeTabBtn("build", "Builds")
makeTabBtn("cred", "Info")

local function section(parent, text)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1,0,0,18); l.BackgroundTransparency = 1
    l.Text = text; l.TextColor3 = SUB
    l.Font = Enum.Font.GothamBold; l.TextSize = 10
    l.TextXAlignment = Enum.TextXAlignment.Left; l.Parent = parent
end

local function btn(parent, text, cb, col)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1,0,0,32); b.BackgroundColor3 = CARD
    b.BorderSizePixel = 0; b.Text = "  " .. text; b.TextColor3 = TEXT
    b.TextXAlignment = Enum.TextXAlignment.Left
    b.Font = Enum.Font.GothamSemibold; b.TextSize = 12
    b.AutoButtonColor = false; b.Parent = parent
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    b.MouseButton1Click:Connect(function()
        b.BackgroundColor3 = col or ACCENT
        task.delay(0.12, function() b.BackgroundColor3 = CARD end)
        pcall(cb)
    end)
    b.MouseEnter:Connect(function() if b.BackgroundColor3 ~= col then b.BackgroundColor3 = HOVER end end)
    b.MouseLeave:Connect(function() b.BackgroundColor3 = CARD end)
end

local function toggle(parent, text, state, cb)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1,0,0,32); f.BackgroundColor3 = CARD
    f.BorderSizePixel = 0; f.Parent = parent
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 6)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1,-60,1,0); l.Position = UDim2.new(0,12,0,0)
    l.BackgroundTransparency = 1; l.Text = text; l.TextColor3 = TEXT
    l.Font = Enum.Font.GothamSemibold; l.TextSize = 12
    l.TextXAlignment = Enum.TextXAlignment.Left; l.Parent = f
    local tr = Instance.new("Frame")
    tr.Size = UDim2.new(0,36,0,18); tr.Position = UDim2.new(1,-46,0.5,-9)
    tr.BackgroundColor3 = state and ACCENT or Color3.fromRGB(60,60,72)
    tr.BorderSizePixel = 0; tr.Parent = f
    Instance.new("UICorner", tr).CornerRadius = UDim.new(1, 0)
    local k = Instance.new("Frame")
    k.Size = UDim2.new(0,14,0,14)
    k.Position = state and UDim2.new(1,-16,0.5,-7) or UDim2.new(0,2,0.5,-7)
    k.BackgroundColor3 = Color3.fromRGB(240,240,245); k.BorderSizePixel = 0
    k.Parent = tr
    Instance.new("UICorner", k).CornerRadius = UDim.new(1, 0)
    local s = state
    f.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            s = not s
            tr.BackgroundColor3 = s and ACCENT or Color3.fromRGB(60,60,72)
            k.Position = s and UDim2.new(1,-16,0.5,-7) or UDim2.new(0,2,0.5,-7)
            pcall(function() cb(s) end)
        end
    end)
end

local function slider(parent, text, minV, maxV, initial, cb)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1,0,0,52); f.BackgroundColor3 = CARD
    f.BorderSizePixel = 0; f.Parent = parent
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 6)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1,-100,0,18); l.Position = UDim2.new(0,12,0,6)
    l.BackgroundTransparency = 1; l.Text = text; l.TextColor3 = TEXT
    l.Font = Enum.Font.GothamSemibold; l.TextSize = 12
    l.TextXAlignment = Enum.TextXAlignment.Left; l.Parent = f
    local v = Instance.new("TextLabel")
    v.Size = UDim2.new(0,70,0,18); v.Position = UDim2.new(1,-82,0,6)
    v.BackgroundTransparency = 1; v.Text = tostring(initial)
    v.TextColor3 = ACCENT; v.Font = Enum.Font.GothamBold; v.TextSize = 12
    v.TextXAlignment = Enum.TextXAlignment.Right; v.Parent = f
    local tr = Instance.new("Frame")
    tr.Size = UDim2.new(1,-24,0,6); tr.Position = UDim2.new(0,12,0,34)
    tr.BackgroundColor3 = Color3.fromRGB(52,52,62); tr.BorderSizePixel = 0
    tr.Parent = f
    Instance.new("UICorner", tr).CornerRadius = UDim.new(1, 0)
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((initial-minV)/(maxV-minV),0,1,0)
    fill.BackgroundColor3 = ACCENT; fill.BorderSizePixel = 0; fill.Parent = tr
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
    local k = Instance.new("Frame")
    k.Size = UDim2.new(0,14,0,14)
    k.Position = UDim2.new((initial-minV)/(maxV-minV),-7,0.5,-7)
    k.BackgroundColor3 = Color3.fromRGB(240,240,245); k.BorderSizePixel = 0
    k.Parent = tr
    Instance.new("UICorner", k).CornerRadius = UDim.new(1, 0)
    local drag = false
    local function set(x)
        local r = math.clamp((x - tr.AbsolutePosition.X) / tr.AbsoluteSize.X, 0, 1)
        local val = math.floor(minV + r * (maxV - minV))
        val = math.floor(val / 25) * 25
        local r2 = (val - minV) / (maxV - minV)
        fill.Size = UDim2.new(r2,0,1,0)
        k.Position = UDim2.new(r2,-7,0.5,-7)
        v.Text = tostring(val)
        pcall(function() cb(val) end)
    end
    tr.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            drag = true; set(i.Position.X)
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if drag and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            set(i.Position.X)
        end
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            drag = false
        end
    end)
end

local Main = makePage("main")
local Grief = makePage("grief")
local Plat = makePage("plat")
local Build = makePage("build")
local Cred = makePage("cred")

section(Main, "F3X / BTOOLS")
btn(Main, "Grab F3X", function() task.spawn(grabF3X) end)
btn(Main, "Grab Btools", function() task.spawn(grabBtools) end)

section(Main, "MOVEMENT")
toggle(Main, "Infinite Jump", S.InfJump, function(v) S.InfJump = v; saveState() end)

section(Main, "VISUAL")
toggle(Main, "Player ESP", S.ESP, function(v) S.ESP = v; if not v and cleanESP then cleanESP() end; saveState() end)

section(Main, "ANTI-CHEAT")
toggle(Main, "Anti-Kick", S.AntiKick, function(v) S.AntiKick = v; saveState() end)
toggle(Main, "Anti-AFK", S.AntiAFK, function(v) S.AntiAFK = v; saveState() end)

section(Grief, "TEST")
btn(Grief, "Test Connection", function()
    notify("Test", testConn(), 6)
end)

section(Grief, "GRIEF")
btn(Grief, "Delete Everything", function() task.spawn(massDelete) end, RED)
btn(Grief, "Unanchor All", function() task.spawn(unanchorAll) end, RED)
btn(Grief, "Fling Parts", function() task.spawn(flingParts) end, RED)
btn(Grief, "Void All", function() task.spawn(voidAll) end, RED)

section(Grief, "DEFENSE")
btn(Grief, "Anti-F3X", function() antiF3X() end)

section(Plat, "SIZE")
slider(Plat, "Size", 10, 1000, S.PlatformSize, function(v) S.PlatformSize = v; saveState() end)

section(Plat, "SQUARE")
btn(Plat, "Below", function() platform(false, false) end)
btn(Plat, "Above", function() platform(true, false) end)

section(Plat, "CIRCLE")
btn(Plat, "Below", function() platform(false, true) end)
btn(Plat, "Above", function() platform(true, true) end)

section(Plat, "CONTROL")
btn(Plat, "Clear Local", function() clearPlatforms() end)

section(Build, "SPAWN")
btn(Build, "House", function()
    local r = getRoot(); if not r then return end
    local base = r.Position + Vector3.new(0,20,0)
    local wall = Color3.fromRGB(220,200,160); local roof = Color3.fromRGB(180,60,60)
    makePart(Vector3.new(30,1,30), Color3.fromRGB(120,90,60)).Position = base
    makePart(Vector3.new(30,16,1), wall).Position = base + Vector3.new(0,8,-15)
    makePart(Vector3.new(1,16,30), wall).Position = base + Vector3.new(-15,8,0)
    makePart(Vector3.new(1,16,30), wall).Position = base + Vector3.new(15,8,0)
    makePart(Vector3.new(12,16,1), wall).Position = base + Vector3.new(-9,8,15)
    makePart(Vector3.new(12,16,1), wall).Position = base + Vector3.new(9,8,15)
    makePart(Vector3.new(6,6,1), wall).Position = base + Vector3.new(0,13,15)
    makePart(Vector3.new(32,2,32), roof).Position = base + Vector3.new(0,17,0)
    makePart(Vector3.new(24,2,24), roof).Position = base + Vector3.new(0,20,0)
    notify("Build", "House!", 2)
end)
btn(Build, "Tower", function()
    local r = getRoot(); if not r then return end
    local pos = r.Position + Vector3.new(0,30,0)
    local st = Color3.fromRGB(140,140,150)
    for i=0,4 do
        local y = pos.Y + i*18
        makePart(Vector3.new(20,1,20), st).Position = Vector3.new(pos.X,y,pos.Z)
        makePart(Vector3.new(20,16,1), st).Position = Vector3.new(pos.X,y+8,pos.Z-10)
        makePart(Vector3.new(20,16,1), st).Position = Vector3.new(pos.X,y+8,pos.Z+10)
        makePart(Vector3.new(1,16,20), st).Position = Vector3.new(pos.X-10,y+8,pos.Z)
        makePart(Vector3.new(1,16,20), st).Position = Vector3.new(pos.X+10,y+8,pos.Z)
        makePart(Vector3.new(20,1,20), st).Position = Vector3.new(pos.X,y+16,pos.Z)
    end
    notify("Build", "Tower!", 2)
end)
btn(Build, "Pyramid", function()
    local r = getRoot(); if not r then return end
    local base = r.Position + Vector3.new(0,10,0)
    for i=0,9 do
        local s = 40 - i*4; if s <= 0 then break end
        makePart(Vector3.new(s,3,s), Color3.fromRGB(230,190,80)).Position = Vector3.new(base.X,base.Y+i*3,base.Z)
    end
    notify("Build", "Pyramid!", 2)
end)

section(Build, "CONTROL")
btn(Build, "Clear All", function() clearPlatforms() end)

section(Cred, "CREDITS")
local p1 = Instance.new("TextLabel")
p1.Size = UDim2.new(1,0,0,60); p1.BackgroundTransparency = 1
p1.Text = "Creator: Shaw\nDiscord: Shaw6000\nKeybinds: F/H/J"
p1.TextColor3 = SUB; p1.Font = Enum.Font.Gotham; p1.TextSize = 11
p1.TextXAlignment = Enum.TextXAlignment.Left
p1.TextYAlignment = Enum.TextYAlignment.Top; p1.Parent = Cred

switchTab("main")

getgenv().Nicotine = function()
    S.InfJump = false; S.ESP = false; S.AntiKick = false; S.AntiAFK = false
    if cleanESP then cleanESP() end
    clearPlatforms()
    for _, c in ipairs(S.Conn) do pcall(function() c:Disconnect() end) end
    S.Conn = {}
    for _, v in ipairs(PG:GetChildren()) do
        if v.Name == "Nicotine" then pcall(function() v:Destroy() end) end
    end
    notify("Nicotine", "Unloaded.", 2)
end

applyAntiKick()
saveState()
notify("Nicotine", "Loaded!", 3)
