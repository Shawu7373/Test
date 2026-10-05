print("[Nicotine] Loading...")

if getgenv().Nicotine then pcall(getgenv().Nicotine) end
getgenv().Nicotine = function() end

local F3X_POS = Vector3.new(11, 3, -116)
local BTOOLS_POS = Vector3.new(30.8, 3.2, -62.3)

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local Workspace         = game:GetService("Workspace")
local StarterGui        = game:GetService("StarterGui")
local HttpService       = game:GetService("HttpService")
local TeleportService   = game:GetService("TeleportService")
local UIS               = game:GetService("UserInputService")
local VirtualUser       = game:GetService("VirtualUser")
local RS                = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local LP                = Players.LocalPlayer
local PG                = LP:WaitForChild("PlayerGui", 15)
if not PG then warn("[Nicotine] PlayerGui missing"); return end

print("[Nicotine] Services OK")

for _, v in ipairs(PG:GetChildren()) do
    if v.Name == "Nicotine" or v.Name == "NicotineSelector" then
        pcall(function() v:Destroy() end)
    end
end

local function notify(t, x, d)
    local ok = pcall(function()
        StarterGui:SetCore("SendNotification", {Title = t or "Nicotine", Text = x or "", Duration = d or 3})
    end)
    if not ok then pcall(function()
        StarterGui:SetCore("ChatMakeSystemMessage", {Text = "[Nicotine] " .. tostring(t) .. ": " .. tostring(x)})
    end) end
end

local CONFIG_FOLDER = "Nicotine"
local CONFIG_FILE = CONFIG_FOLDER .. "/config.json"

local function ensureFolder()
    if type(makefolder) == "function" and type(isfolder) == "function" then
        if not isfolder(CONFIG_FOLDER) then pcall(function() makefolder(CONFIG_FOLDER) end) end
    end
end

local function loadConfig()
    ensureFolder()
    if type(isfile) == "function" and type(readfile) == "function" then
        local ok, exists = pcall(isfile, CONFIG_FILE)
        if ok and exists then
            local ok2, content = pcall(readfile, CONFIG_FILE)
            if ok2 then
                local ok3, decoded = pcall(function() return HttpService:JSONDecode(content) end)
                if ok3 and type(decoded) == "table" then return decoded end
            end
        end
    end
    return {}
end

local function saveConfig(t)
    ensureFolder()
    if type(writefile) == "function" then
        local ok, encoded = pcall(function() return HttpService:JSONEncode(t) end)
        if ok then pcall(writefile, CONFIG_FILE, encoded); return true end
    end
    return false
end

local saved = loadConfig()

local S = {
    InfJump = saved.InfJump or false,
    ESP = saved.ESP or false,
    AntiKick = saved.AntiKick or false,
    AntiAFK = saved.AntiAFK or false,
    PlatformSize = saved.PlatformSize or 50,
    Device = saved.Device or nil,
    Conn = {}, ESPObjects = {}, PlacedParts = {},
    CanInfJump = true, IsGrabbing = false,
    AutoGrabKey = Enum.KeyCode.F
}

local function saveCurrentState()
    saveConfig({
        InfJump = S.InfJump, ESP = S.ESP, AntiKick = S.AntiKick,
        AntiAFK = S.AntiAFK, PlatformSize = S.PlatformSize, Device = S.Device
    })
end

local function getChar() return LP.Character end
local function getHum() local c = getChar(); return c and c:FindFirstChildOfClass("Humanoid") end
local function getRoot() local c = getChar(); return c and c:FindFirstChild("HumanoidRootPart") end
local function getBP() return LP:FindFirstChild("Backpack") end
local function trk(c) table.insert(S.Conn, c); return c end

local buildPCUI
local buildMobileUI

local function applyAntiKick()
    pcall(function()
        local mt = getrawmetatable(game)
        local oldNamecall = mt.__namecall
        setreadonly(mt, false)
        mt.__namecall = newcclosure(function(self, ...)
            local method = getnamecallmethod()
            if method == "Kick" and S.AntiKick then
                notify("Anti-Cheat", "Kick attempt blocked!", 3)
                return nil
            end
            return oldNamecall(self, ...)
        end)
        setreadonly(mt, true)
    end)
end

local function setupAntiAFK()
    trk(LP.Idled:Connect(function()
        if S.AntiAFK then
            pcall(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new())
            end)
        end
    end))
end

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
    if c then
        for _, o in ipairs(c:GetChildren()) do
            if isF3XTool(o) and not isBtools(o) then return o end
        end
    end
    local bp = getBP()
    if bp then
        for _, o in ipairs(bp:GetChildren()) do
            if isF3XTool(o) and not isBtools(o) then return o end
        end
    end
    return nil
end

local function hasBtools()
    local c = LP.Character
    if c then
        for _, o in ipairs(c:GetChildren()) do
            if isBtools(o) then return o end
        end
    end
    local bp = getBP()
    if bp then
        for _, o in ipairs(bp:GetChildren()) do
            if isBtools(o) then return o end
        end
    end
    return nil
end

local function equipF3X()
    local t = hasF3X()
    if not t then return false end
    local h = getHum()
    if h then pcall(function() h:EquipTool(t) end); return true end
    return false
end

local function equipBtools()
    local t = hasBtools()
    if not t then return false end
    local h = getHum()
    if h then pcall(function() h:EquipTool(t) end); return true end
    return false
end

local _f3xCache = {inv = nil, ev = nil, tool = nil, found = false, ts = 0}

local function scoreRemoteName(n)
    n = n:lower()
    local score = 0
    if n:find("f3x") then score = score + 10 end
    if n:find("btool") then score = score + 8 end
    if n:find("build") then score = score + 6 end
    if n:find("sync") then score = score + 5 end
    if n:find("server") then score = score + 4 end
    if n:find("remote") then score = score + 3 end
    if n:find("event") then score = score + 2 end
    if n:find("invoke") then score = score + 2 end
    return score
end

local function findF3XRemotesDeep()
    local tool = hasF3X() or hasBtools()
    if not tool then return nil, nil end

    if _f3xCache.found and _f3xCache.tool == tool and (tick() - _f3xCache.ts) < 30 then
        return _f3xCache.inv, _f3xCache.ev
    end

    local bestInv, bestInvScore = nil, 0
    local bestEv, bestEvScore = nil, 0

    local function consider(obj, score)
        if obj:IsA("RemoteFunction") then
            if score > bestInvScore then bestInv = obj; bestInvScore = score end
        elseif obj:IsA("RemoteEvent") then
            if score > bestEvScore then bestEv = obj; bestEvScore = score end
        end
    end

    for _, obj in ipairs(tool:GetDescendants()) do
        if obj:IsA("RemoteFunction") or obj:IsA("RemoteEvent") then
            consider(obj, scoreRemoteName(obj.Name) + 2)
        end
    end

    if tool.Parent then
        for _, obj in ipairs(tool.Parent:GetDescendants()) do
            if obj:IsA("RemoteFunction") or obj:IsA("RemoteEvent") then
                consider(obj, scoreRemoteName(obj.Name))
            end
        end
    end

    for _, obj in ipairs(RS:GetDescendants()) do
        if obj:IsA("RemoteFunction") or obj:IsA("RemoteEvent") then
            consider(obj, scoreRemoteName(obj.Name))
        end
    end

    local ps = LP:FindFirstChild("PlayerScripts")
    if ps then
        for _, obj in ipairs(ps:GetDescendants()) do
            if obj:IsA("RemoteFunction") or obj:IsA("RemoteEvent") then
                consider(obj, scoreRemoteName(obj.Name))
            end
        end
    end

    if not bestInv and not bestEv then
        for _, obj in ipairs(tool:GetDescendants()) do
            if obj:IsA("RemoteFunction") then bestInv = obj; break end
            if obj:IsA("RemoteEvent") then bestEv = obj; break end
        end
        if not bestInv and not bestEv then
            for _, obj in ipairs(RS:GetDescendants()) do
                if obj:IsA("RemoteFunction") then bestInv = obj; break end
                if obj:IsA("RemoteEvent") then bestEv = obj; break end
            end
        end
    end

    _f3xCache = {inv = bestInv, ev = bestEv, tool = tool, found = (bestInv ~= nil or bestEv ~= nil), ts = tick()}
    return bestInv, bestEv
end

local function getF3XRemotes()
    return findF3XRemotesDeep()
end

local function sendF3XCommand(command, args)
    local inv, ev = getF3XRemotes()
    if not inv and not ev then return false end

    local formats = {
        function() return {command, args} end,
        function()
            if type(args) == "table" and #args == 1 and type(args[1]) == "table" then
                local d = {}
                d.Command = command
                for k, v in pairs(args[1]) do d[k] = v end
                return {{d}}
            end
            return {{Command = command, Args = args}}
        end,
        function() return {args} end,
        function()
            if type(args) == "table" and #args == 1 and type(args[1]) == "table" then
                local t = {command}
                for k, v in pairs(args[1]) do
                    table.insert(t, k)
                    table.insert(t, v)
                end
                return t
            end
            return {command}
        end,
    }

    for _, fmt in ipairs(formats) do
        local packed = fmt()
        local ok = pcall(function()
            if inv then inv:InvokeServer(table.unpack(packed))
            else ev:FireServer(table.unpack(packed)) end
        end)
        if ok then return true end
    end
    return false
end

local function testF3XConnection()
    local inv, ev = getF3XRemotes()
    if not inv and not ev then
        return false, "No remote found. Grab F3X first or equip the tool."
    end
    local name = inv and ("RemoteFunction: " .. inv.Name .. " @ " .. inv:GetFullName())
                      or ("RemoteEvent: " .. ev.Name .. " @ " .. ev:GetFullName())
    local tested = false
    for _, cmd in ipairs({"Get", "List", "Info", "Ping", "Sync"}) do
        if inv then
            local ok = pcall(function() inv:InvokeServer(cmd) end)
            if ok then tested = true; break end
        else
            local ok = pcall(function() ev:FireServer(cmd) end)
            if ok then tested = true; break end
        end
    end
    return true, name .. (tested and "\n✓ Remote responds to test calls" or "\n⚠ Remote found but didn't respond to probes")
end

local function makePart(size, color, transparency, material)
    local part = Instance.new("Part")
    part.Size = size; part.Anchored = true; part.CanCollide = true
    part.Material = material or Enum.Material.SmoothPlastic
    part.Color = color or Color3.fromRGB(120, 120, 130)
    part.Transparency = transparency or 0
    part.TopSurface = Enum.SurfaceType.Smooth; part.BottomSurface = Enum.SurfaceType.Smooth
    part.Parent = Workspace
    table.insert(S.PlacedParts, part)
    return part
end

local function makePartAt(pos, size, color, transparency, material)
    local p = makePart(size, color, transparency, material); p.Position = pos; return p
end

local function platformAtMe(above)
    local root = getRoot()
    if not root then notify("Platform", "No character", 2); return end
    local size = S.PlatformSize or 50
    local pos = above and (root.Position + Vector3.new(0, 12, 0)) or (root.Position + Vector3.new(0, -4, 0))
    local inv, ev = getF3XRemotes()
    if inv or ev then
        equipF3X()
        sendF3XCommand("New", {{
            Size = Vector3.new(size, 3, size), CFrame = CFrame.new(pos),
            Color = Color3.fromRGB(255, 200, 0), Anchored = true,
            Material = "SmoothPlastic", Name = "NicotinePlatform_" .. tostring(math.random(1000, 9999))
        }})
        notify("Platform", "Server-sided Square spawned!", 3)
    else
        local part = makePart(Vector3.new(size, 3, size), Color3.fromRGB(255, 200, 0), 0.15)
        part.Position = pos
        notify("Platform", "Local Square spawned. Grab F3X for server-sided!", 5)
    end
end

local function circlePlatformAtMe(above)
    local root = getRoot()
    if not root then notify("Platform", "No character", 2); return end
    local size = S.PlatformSize or 50
    local pos = above and (root.Position + Vector3.new(0, 12, 0)) or (root.Position + Vector3.new(0, -4, 0))
    local inv, ev = getF3XRemotes()
    if inv or ev then
        equipF3X()
        sendF3XCommand("New", {{
            Size = Vector3.new(3, size, size), CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)),
            Color = Color3.fromRGB(100, 200, 255), Anchored = true,
            Material = "SmoothPlastic", Shape = "Cylinder", Name = "NicotineCirclePlatform_" .. tostring(math.random(1000, 9999))
        }})
        notify("Platform", "Server-sided Circle spawned!", 3)
    else
        local cylinder = Instance.new("Part")
        cylinder.Shape = Enum.PartType.Cylinder
        cylinder.Size = Vector3.new(3, size, size)
        cylinder.Anchored = true; cylinder.CanCollide = true
        cylinder.Material = Enum.Material.SmoothPlastic
        cylinder.Color = Color3.fromRGB(100, 200, 255); cylinder.Transparency = 0.15
        cylinder.TopSurface = Enum.SurfaceType.Smooth; cylinder.BottomSurface = Enum.SurfaceType.Smooth
        cylinder.Parent = Workspace
        table.insert(S.PlacedParts, cylinder)
        cylinder.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90))
        notify("Platform", "Local Circle spawned. Grab F3X for server-sided!", 5)
    end
end

local function clearPlatforms()
    local n = 0
    for _, p in ipairs(S.PlacedParts) do
        if p and p.Parent then pcall(function() p:Destroy() end); n = n + 1 end
    end
    S.PlacedParts = {}
    notify("Platform", "Cleared " .. n .. " local parts", 3)
end

local function spawnHouse()
    local root = getRoot(); if not root then return end
    local base = root.Position + Vector3.new(0, 20, 0)
    local wall = Color3.fromRGB(220, 200, 160); local roof = Color3.fromRGB(180, 60, 60)
    local floor = Color3.fromRGB(120, 90, 60); local door = Color3.fromRGB(90, 60, 30)
    local win = Color3.fromRGB(150, 210, 255)
    makePartAt(base, Vector3.new(30, 1, 30), floor, 0)
    makePartAt(base + Vector3.new(0, 8, -15), Vector3.new(30, 16, 1), wall, 0)
    makePartAt(base + Vector3.new(-15, 8, 0), Vector3.new(1, 16, 30), wall, 0)
    makePartAt(base + Vector3.new(15, 8, 0), Vector3.new(1, 16, 30), wall, 0)
    makePartAt(base + Vector3.new(-9, 8, 15), Vector3.new(12, 16, 1), wall, 0)
    makePartAt(base + Vector3.new(9, 8, 15), Vector3.new(12, 16, 1), wall, 0)
    makePartAt(base + Vector3.new(0, 13, 15), Vector3.new(6, 6, 1), wall, 0)
    makePartAt(base + Vector3.new(0, 5, 15), Vector3.new(5, 10, 0.5), door, 0)
    makePartAt(base + Vector3.new(0, 10, -15), Vector3.new(8, 6, 0.5), win, 0.3)
    makePartAt(base + Vector3.new(-15, 10, 0), Vector3.new(0.5, 6, 8), win, 0.3)
    makePartAt(base + Vector3.new(15, 10, 0), Vector3.new(0.5, 6, 8), win, 0.3)
    makePartAt(base + Vector3.new(0, 17, 0), Vector3.new(32, 2, 32), roof, 0)
    makePartAt(base + Vector3.new(0, 20, 0), Vector3.new(24, 2, 24), roof, 0)
    notify("Builds", "House spawned", 2)
end

local function spawnTower()
    local root = getRoot(); if not root then return end
    local pos = root.Position + Vector3.new(0, 30, 0)
    local stone = Color3.fromRGB(140, 140, 150); local top = Color3.fromRGB(200, 180, 100)
    for i = 0, 4 do
        local y = pos.Y + (i * 18)
        makePartAt(Vector3.new(pos.X, y, pos.Z), Vector3.new(20, 1, 20), stone, 0)
        makePartAt(Vector3.new(pos.X, y+8, pos.Z-10), Vector3.new(20, 16, 1), stone, 0)
        makePartAt(Vector3.new(pos.X, y+8, pos.Z+10), Vector3.new(20, 16, 1), stone, 0)
        makePartAt(Vector3.new(pos.X-10, y+8, pos.Z), Vector3.new(1, 16, 20), stone, 0)
        makePartAt(Vector3.new(pos.X+10, y+8, pos.Z), Vector3.new(1, 16, 20), stone, 0)
        makePartAt(Vector3.new(pos.X, y+16, pos.Z), Vector3.new(20, 1, 20), stone, 0)
    end
    makePartAt(Vector3.new(pos.X, pos.Y + 92, pos.Z), Vector3.new(24, 2, 24), top, 0)
    notify("Builds", "Tower spawned", 2)
end

local function spawnBridge()
    local root = getRoot(); if not root then return end
    local pos = root.Position + Vector3.new(0, 20, 0)
    local wood = Color3.fromRGB(140, 90, 50); local rail = Color3.fromRGB(100, 60, 30)
    makePartAt(pos, Vector3.new(60, 1, 10), wood, 0)
    makePartAt(pos + Vector3.new(0, 3, -5), Vector3.new(60, 5, 0.5), rail, 0)
    makePartAt(pos + Vector3.new(0, 3, 5), Vector3.new(60, 5, 0.5), rail, 0)
    for x = -25, 25, 25 do
        makePartAt(pos + Vector3.new(x, -15, -4), Vector3.new(3, 30, 3), wood, 0)
        makePartAt(pos + Vector3.new(x, -15, 4), Vector3.new(3, 30, 3), wood, 0)
    end
    notify("Builds", "Bridge spawned", 2)
end

local function spawnPyramid()
    local root = getRoot(); if not root then return end
    local base = root.Position + Vector3.new(0, 10, 0)
    local gold = Color3.fromRGB(230, 190, 80)
    for i = 0, 9 do
        local s = 40 - (i * 4); if s <= 0 then break end
        makePartAt(Vector3.new(base.X, base.Y + i * 3, base.Z), Vector3.new(s, 3, s), gold, 0)
    end
    notify("Builds", "Pyramid spawned", 2)
end

local function spawnWall()
    local root = getRoot(); if not root then return end
    local pos = root.Position + root.CFrame.LookVector * 20 + Vector3.new(0, 10, 0)
    local stone = Color3.fromRGB(160, 160, 170)
    local wall = makePartAt(pos, Vector3.new(40, 20, 2), stone, 0)
    wall.CFrame = CFrame.new(pos, pos + root.CFrame.LookVector)
    for x = -18, 18, 6 do
        local b = makePartAt(pos + Vector3.new(x, 12, 0), Vector3.new(3, 4, 2), stone, 0)
        b.CFrame = CFrame.new(b.Position, b.Position + root.CFrame.LookVector)
    end
    notify("Builds", "Wall spawned", 2)
end

local function spawnFountain()
    local root = getRoot(); if not root then return end
    local base = root.Position + Vector3.new(0, 5, 0)
    local stone = Color3.fromRGB(180, 180, 190); local water = Color3.fromRGB(100, 180, 255)
    local pool = makePart(Vector3.new(30, 4, 30), stone, 0)
    pool.Shape = Enum.PartType.Cylinder
    pool.CFrame = CFrame.new(base) * CFrame.Angles(0, 0, math.rad(90))
    local w = makePart(Vector3.new(29, 0.5, 29), water, 0.3)
    w.Shape = Enum.PartType.Cylinder
    w.CFrame = CFrame.new(base + Vector3.new(0, 2.5, 0)) * CFrame.Angles(0, 0, math.rad(90))
    makePartAt(base + Vector3.new(0, 15, 0), Vector3.new(4, 20, 4), stone, 0)
    local top = makePart(Vector3.new(15, 3, 15), stone, 0)
    top.Shape = Enum.PartType.Cylinder
    top.CFrame = CFrame.new(base + Vector3.new(0, 26, 0)) * CFrame.Angles(0, 0, math.rad(90))
    notify("Builds", "Fountain spawned", 2)
end

local function grabAndReturn()
    if S.IsGrabbing then return end
    S.IsGrabbing = true
    local root = getRoot()
    if not root then S.IsGrabbing = false; return end
    if hasF3X() then equipF3X(); S.IsGrabbing = false; return end
    local savedPos = root.CFrame
    pcall(function() root.CFrame = CFrame.new(F3X_POS) end)
    task.wait(1.2)
    pcall(function() root.CFrame = savedPos end)
    S.IsGrabbing = false
end

local function grabBtools()
    if S.IsGrabbing then return end
    S.IsGrabbing = true
    local root = getRoot()
    if not root then S.IsGrabbing = false; return end
    if hasBtools() then equipBtools(); S.IsGrabbing = false; return end
    local savedPos = root.CFrame
    pcall(function() root.CFrame = CFrame.new(BTOOLS_POS) end)
    task.wait(1.2)
    pcall(function() root.CFrame = savedPos end)
    S.IsGrabbing = false
end

local function collectGriefTargets()
    local list = {}
    for _, part in ipairs(Workspace:GetDescendants()) do
        if part:IsA("BasePart") then
            local isChar = part:FindFirstChildOfClass("Humanoid") ~= nil
            local isRoot = part.Name == "HumanoidRootPart"
            local isLocalChar = false
            if LP.Character then
                isLocalChar = part:IsDescendantOf(LP.Character)
            end
            if not isChar and not isRoot and not isLocalChar then
                table.insert(list, part)
            end
        end
    end
    return list
end

local function ensureF3XReady()
    if not hasF3X() and not hasBtools() then
        notify("Grief", "Grab F3X or Btools first!", 3)
        return false
    end
    equipF3X() or equipBtools()
    task.wait(0.2)
    local inv, ev = getF3XRemotes()
    if not inv and not ev then
        notify("Grief", "Could not find the build remote. Try 'Test Connection'.", 4)
        return false
    end
    return true
end

local function massDelete()
    if not ensureF3XReady() then return end
    notify("Grief", "Mass deleting...", 2)
    local targets = collectGriefTargets()
    local sent = 0
    for i, part in ipairs(targets) do
        if part and part.Parent then
            sendF3XCommand("Remove", {part})
            sent = sent + 1
        end
        if i % 15 == 0 then task.wait() end
    end
    notify("Grief", "Sent delete for " .. sent .. " parts", 3)
end

local function unanchorAll()
    if not ensureF3XReady() then return end
    notify("Grief", "Unanchoring...", 2)
    local targets = collectGriefTargets()
    local sent = 0
    for i, part in ipairs(targets) do
        if part and part.Parent and part.Anchored then
            sendF3XCommand("SyncAnchor", {{Part = part, Anchored = false}})
            sent = sent + 1
        end
        if i % 15 == 0 then task.wait() end
    end
    notify("Grief", "Unanchored " .. sent .. " parts", 3)
end

local function flingParts()
    if not ensureF3XReady() then return end
    notify("Grief", "Flinging...", 2)
    local targets = collectGriefTargets()
    local sent = 0
    for i, part in ipairs(targets) do
        if part and part.Parent then
            sendF3XCommand("SyncAnchor", {{Part = part, Anchored = false}})
            pcall(function()
                part.Velocity = Vector3.new(math.random(-400,400), math.random(150,600), math.random(-400,400))
            end)
            sent = sent + 1
        end
        if i % 15 == 0 then task.wait() end
    end
    notify("Grief", "Flung " .. sent .. " parts", 3)
end

local function voidAll()
    if not ensureF3XReady() then return end
    notify("Grief", "Voiding...", 2)
    local targets = collectGriefTargets()
    local sent = 0
    for i, part in ipairs(targets) do
        if part and part.Parent then
            local pos = part.Position
            sendF3XCommand("SyncMove", {{Part = part, CFrame = CFrame.new(pos.X, -5000, pos.Z)}})
            sent = sent + 1
        end
        if i % 15 == 0 then task.wait() end
    end
    notify("Grief", "Voided " .. sent .. " parts", 3)
end

local function antiF3X()
    notify("Grief", "Hiding others' tools locally", 2)
    local count = 0
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LP then
            pcall(function()
                if player.Character then
                    for _, tool in ipairs(player.Character:GetChildren()) do
                        if isF3XTool(tool) then
                            tool.Parent = nil
                            count = count + 1
                        end
                    end
                end
            end)
        end
    end
    notify("Grief", "Hidden " .. count .. " tools", 2)
end

local function rejoinServer()
    saveCurrentState()
    notify("Nicotine", "Rejoining...", 2); task.wait(0.3)
    pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LP) end)
end

trk(UIS.JumpRequest:Connect(function()
    if not S.InfJump then return end
    local h = getHum(); if not h then return end
    local state = h:GetState()
    if state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Jumping then
        if S.CanInfJump then
            S.CanInfJump = false
            pcall(function() h:ChangeState(Enum.HumanoidStateType.Jumping) end)
            task.delay(0.15, function() S.CanInfJump = true end)
        end
    end
end))

local cleanESP = nil
local function makeESP(target, color)
    if not target or S.ESPObjects[target] then return end
    local root = target:FindFirstChild("HumanoidRootPart"); if not root then return end
    local hl = Instance.new("Highlight")
    hl.Name = "NicotineESP"; hl.Adornee = target
    hl.FillColor = color; hl.FillTransparency = 0.5
    hl.OutlineColor = Color3.fromRGB(255, 255, 255); hl.OutlineTransparency = 0
    hl.Parent = target
    local bb = Instance.new("BillboardGui")
    bb.Name = "NicotineESPLabel"; bb.Adornee = root
    bb.Size = UDim2.new(0, 200, 0, 40); bb.StudsOffset = Vector3.new(0, 3, 0)
    bb.AlwaysOnTop = true; bb.Parent = target
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 1, 0); lbl.BackgroundTransparency = 1
    lbl.TextColor3 = color; lbl.TextStrokeTransparency = 0; lbl.TextScaled = true
    lbl.Font = Enum.Font.GothamBold; lbl.Text = target.Name
    lbl.Parent = bb
    S.ESPObjects[target] = {hl = hl, bb = bb, lbl = lbl}
end

local function removeESP(target)
    if S.ESPObjects[target] then
        pcall(function() S.ESPObjects[target].hl:Destroy() end)
        pcall(function() S.ESPObjects[target].bb:Destroy() end)
        S.ESPObjects[target] = nil
    end
end

cleanESP = function()
    local snap = {}
    for t in pairs(S.ESPObjects) do table.insert(snap, t) end
    for _, t in ipairs(snap) do removeESP(t) end
    S.ESPObjects = {}
end

task.spawn(function()
    while getgenv().Nicotine do
        task.wait(0.5)
        for t in pairs(S.ESPObjects) do
            if not t or not t.Parent then removeESP(t) end
        end
        if S.ESP then
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LP and p.Character then
                    makeESP(p.Character, Color3.fromRGB(255, 100, 100))
                    local e = S.ESPObjects[p.Character]
                    if e and e.lbl then
                        local r = getRoot()
                        local tr = p.Character:FindFirstChild("HumanoidRootPart")
                        if r and tr then
                            e.lbl.Text = p.Name .. " | " .. math.floor((r.Position - tr.Position).Magnitude) .. "m"
                        end
                    end
                end
            end
        else
            for t in pairs(S.ESPObjects) do
                if t:IsA("Model") then removeESP(t) end
            end
        end
    end
end)

trk(UIS.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    if input.KeyCode == S.AutoGrabKey then task.spawn(function() pcall(grabAndReturn) end) end
    if input.KeyCode == Enum.KeyCode.H then
        S.ESP = not S.ESP
        if not S.ESP and cleanESP then cleanESP() end
        saveCurrentState()
    end
    if input.KeyCode == Enum.KeyCode.J then
        S.InfJump = not S.InfJump; saveCurrentState()
    end
end))

local function showDeviceSelector()
    local BG     = Color3.fromRGB(22, 22, 26)
    local HEAD   = Color3.fromRGB(26, 26, 30)
    local BORDER = Color3.fromRGB(44, 44, 50)
    local LINE   = Color3.fromRGB(40, 40, 46)
    local ROW    = Color3.fromRGB(30, 30, 36)
    local ROW_H  = Color3.fromRGB(38, 38, 46)
    local TEXT   = Color3.fromRGB(235, 235, 240)
    local SUB    = Color3.fromRGB(120, 120, 130)
    local ACCENT = Color3.fromRGB(130, 95, 200)

    local sg = Instance.new("ScreenGui")
    sg.Name = "NicotineSelector"
    sg.ResetOnSpawn = false
    sg.IgnoreGuiInset = true
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.Parent = PG

    local dim = Instance.new("Frame")
    dim.Size = UDim2.new(1, 0, 1, 0)
    dim.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    dim.BackgroundTransparency = 0.55
    dim.BorderSizePixel = 0
    dim.Parent = sg

    local win = Instance.new("Frame")
    win.Size = UDim2.new(0, 400, 0, 230)
    win.Position = UDim2.new(0.5, -200, 0.5, -115)
    win.BackgroundColor3 = BG
    win.BorderSizePixel = 0
    win.Active = true
    win.Draggable = true
    win.Parent = sg
    Instance.new("UICorner", win).CornerRadius = UDim.new(0, 8)
    local ws = Instance.new("UIStroke", win)
    ws.Color = BORDER
    ws.Thickness = 1

    local head = Instance.new("Frame")
    head.Size = UDim2.new(1, 0, 0, 44)
    head.BackgroundColor3 = HEAD
    head.BorderSizePixel = 0
    head.Parent = win
    Instance.new("UICorner", head).CornerRadius = UDim.new(0, 8)
    local headFix = Instance.new("Frame")
    headFix.Size = UDim2.new(1, 0, 0, 10)
    headFix.Position = UDim2.new(0, 0, 1, -10)
    headFix.BackgroundColor3 = HEAD
    headFix.BorderSizePixel = 0
    headFix.Parent = head
    local headLine = Instance.new("Frame")
    headLine.Size = UDim2.new(1, 0, 0, 1)
    headLine.Position = UDim2.new(0, 0, 1, -1)
    headLine.BackgroundColor3 = LINE
    headLine.BorderSizePixel = 0
    headLine.Parent = head

    local logo = Instance.new("Frame")
    logo.Size = UDim2.new(0, 18, 0, 18)
    logo.Position = UDim2.new(0, 14, 0.5, -9)
    logo.BackgroundColor3 = ACCENT
    logo.BorderSizePixel = 0
    logo.Parent = head
    Instance.new("UICorner", logo).CornerRadius = UDim.new(0, 4)

    local brand = Instance.new("TextLabel")
    brand.Size = UDim2.new(0, 200, 1, 0)
    brand.Position = UDim2.new(0, 38, 0, 0)
    brand.BackgroundTransparency = 1
    brand.Text = "Nicotine"
    brand.TextColor3 = TEXT
    brand.Font = Enum.Font.GothamBold
    brand.TextSize = 14
    brand.TextXAlignment = Enum.TextXAlignment.Left
    brand.Parent = head

    local ver = Instance.new("TextLabel")
    ver.Size = UDim2.new(0, 60, 1, 0)
    ver.Position = UDim2.new(1, -74, 0, 0)
    ver.BackgroundTransparency = 1
    ver.Text = "v4.1"
    ver.TextColor3 = SUB
    ver.Font = Enum.Font.Gotham
    ver.TextSize = 11
    ver.TextXAlignment = Enum.TextXAlignment.Right
    ver.Parent = head

    local secLbl = Instance.new("TextLabel")
    secLbl.Size = UDim2.new(1, -32, 0, 14)
    secLbl.Position = UDim2.new(0, 16, 0, 58)
    secLbl.BackgroundTransparency = 1
    secLbl.Text = "SELECT DEVICE"
    secLbl.TextColor3 = SUB
    secLbl.Font = Enum.Font.GothamBold
    secLbl.TextSize = 10
    secLbl.TextXAlignment = Enum.TextXAlignment.Left
    secLbl.Parent = win

    local choice = nil
    local destroyed = false

    local function pick(val)
        if destroyed then return end
        destroyed = true
        choice = val
        S.Device = val
        saveCurrentState()
        pcall(function() sg.Enabled = false end)
        pcall(function() sg.Parent = nil end)
        pcall(function() sg:Destroy() end)
    end

    local function makeRow(y, title, subtitle, val)
        local row = Instance.new("TextButton")
        row.Size = UDim2.new(1, -32, 0, 48)
        row.Position = UDim2.new(0, 16, 0, y)
        row.BackgroundColor3 = ROW
        row.BorderSizePixel = 0
        row.Text = ""
        row.AutoButtonColor = false
        row.Parent = win
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)

        local radio = Instance.new("Frame")
        radio.Size = UDim2.new(0, 16, 0, 16)
        radio.Position = UDim2.new(0, 14, 0.5, -8)
        radio.BackgroundTransparency = 1
        radio.BorderSizePixel = 0
        radio.Parent = row
        Instance.new("UICorner", radio).CornerRadius = UDim.new(1, 0)
        local rs = Instance.new("UIStroke", radio)
        rs.Color = SUB
        rs.Thickness = 1.5

        local dot = Instance.new("Frame")
        dot.Size = UDim2.new(0, 8, 0, 8)
        dot.Position = UDim2.new(0.5, -4, 0.5, -4)
        dot.BackgroundColor3 = ACCENT
        dot.BorderSizePixel = 0
        dot.Visible = false
        dot.Parent = radio
        Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -60, 0, 16)
        lbl.Position = UDim2.new(0, 42, 0, 8)
        lbl.BackgroundTransparency = 1
        lbl.Text = title
        lbl.TextColor3 = TEXT
        lbl.Font = Enum.Font.GothamSemibold
        lbl.TextSize = 13
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = row

        local subl = Instance.new("TextLabel")
        subl.Size = UDim2.new(1, -60, 0, 14)
        subl.Position = UDim2.new(0, 42, 0, 25)
        subl.BackgroundTransparency = 1
        subl.Text = subtitle
        subl.TextColor3 = SUB
        subl.Font = Enum.Font.Gotham
        subl.TextSize = 11
        subl.TextXAlignment = Enum.TextXAlignment.Left
        subl.Parent = row

        row.MouseEnter:Connect(function()
            if not destroyed then row.BackgroundColor3 = ROW_H end
        end)
        row.MouseLeave:Connect(function()
            if not destroyed then row.BackgroundColor3 = ROW end
        end)
        row.MouseButton1Click:Connect(function()
            dot.Visible = true
            rs.Color = ACCENT
            pick(val)
        end)
    end

    makeRow(80, "PC", "Keyboard & mouse", "pc")
    makeRow(134, "Mobile", "Phone & tablet", "mobile")

    local foot = Instance.new("TextLabel")
    foot.Size = UDim2.new(1, -32, 0, 14)
    foot.Position = UDim2.new(0, 16, 1, -24)
    foot.BackgroundTransparency = 1
    foot.Text = "You can change this later in Settings"
    foot.TextColor3 = SUB
    foot.Font = Enum.Font.Gotham
    foot.TextSize = 10
    foot.TextXAlignment = Enum.TextXAlignment.Left
    foot.Parent = win

    while not destroyed do task.wait(0.05) end
    return choice or "pc"
end

local function addResizeHandle(parent, minW, minH, maxW, maxH)
    local grip = Instance.new("TextButton")
    grip.Size = UDim2.new(0, 18, 0, 18)
    grip.Position = UDim2.new(1, -20, 1, -20)
    grip.BackgroundTransparency = 1
    grip.Text = ""
    grip.AutoButtonColor = false
    grip.ZIndex = 20
    grip.Parent = parent

    local l1 = Instance.new("Frame")
    l1.Size = UDim2.new(0, 10, 0, 2)
    l1.Position = UDim2.new(1, -13, 1, -7)
    l1.BackgroundColor3 = Color3.fromRGB(120, 110, 150)
    l1.BorderSizePixel = 0
    l1.ZIndex = 20
    l1.Parent = parent

    local l2 = Instance.new("Frame")
    l2.Size = UDim2.new(0, 2, 0, 10)
    l2.Position = UDim2.new(1, -7, 1, -13)
    l2.BackgroundColor3 = Color3.fromRGB(120, 110, 150)
    l2.BorderSizePixel = 0
    l2.ZIndex = 20
    l2.Parent = parent

    local dragging = false
    local sx, sy, sw, sh

    grip.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            sx, sy = i.Position.X, i.Position.Y
            sw, sh = parent.AbsoluteSize.X, parent.AbsoluteSize.Y
            parent.Draggable = false
            l1.BackgroundColor3 = Color3.fromRGB(200, 180, 255)
            l2.BackgroundColor3 = Color3.fromRGB(200, 180, 255)
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if not dragging then return end
        if i.UserInputType ~= Enum.UserInputType.MouseMovement and i.UserInputType ~= Enum.UserInputType.Touch then return end
        local nw = math.clamp(sw + (i.Position.X - sx), minW, maxW)
        local nh = math.clamp(sh + (i.Position.Y - sy), minH, maxH)
        parent.Size = UDim2.new(0, nw, 0, nh)
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            if dragging then
                dragging = false
                parent.Draggable = true
                l1.BackgroundColor3 = Color3.fromRGB(120, 110, 150)
                l2.BackgroundColor3 = Color3.fromRGB(120, 110, 150)
            end
        end
    end)
end

buildMobileUI = function()
    local Rayfield
    local srcs = {
        "https://sirius.menu/rayfield",
        "https://raw.githubusercontent.com/shlexware/Rayfield/main/source.lua",
        "https://raw.githubusercontent.com/Footagesus/Rayfield/main/source.lua",
        "https://raw.githubusercontent.com/luau-libraries/Rayfield/main/source.lua"
    }
    for i, u in ipairs(srcs) do
        local ok, res = pcall(function()
            local s = game:HttpGet(u)
            if not s or #s < 100 then error("empty") end
            return loadstring(s)()
        end)
        local lib = res
        if not (lib and type(lib) == "table" and lib.CreateWindow) then lib = getgenv().Rayfield end
        if not (lib and type(lib) == "table" and lib.CreateWindow) then lib = rawget(_G, "Rayfield") end
        if lib and type(lib) == "table" and lib.CreateWindow then Rayfield = lib; break end
    end
    if not Rayfield then notify("Nicotine", "Rayfield failed", 6); return nil end
    local RayfieldInstance = Rayfield

    local Window = Rayfield:CreateWindow({
        Name = "Nicotine", LoadingTitle = "Nicotine", LoadingSubtitle = "Mobile",
        KeySystem = false, ToggleUIKeybind = "K"
    })

    local MainTab = Window:CreateTab("Main", 4483362458)
    local GriefTab = Window:CreateTab("Grief", 4483362458)
    local PlatformTab = Window:CreateTab("Platform", 4483362458)
    local BuildsTab = Window:CreateTab("Builds", 4483362458)
    local CreditsTab = Window:CreateTab("Credits", 4483362458)

    MainTab:CreateSection("F3X / Btools")
    MainTab:CreateButton({Name = "Grab F3X & Return", Callback = function() task.spawn(function() pcall(grabAndReturn) end) end})
    MainTab:CreateButton({Name = "Grab Btools & Return", Callback = function() task.spawn(function() pcall(grabBtools) end) end})
    MainTab:CreateSection("Movement")
    MainTab:CreateToggle({Name = "Infinite Jump", CurrentValue = S.InfJump, Flag = "InfJumpToggle",
        Callback = function(v) S.InfJump = v; saveCurrentState() end})
    MainTab:CreateSection("Visual")
    MainTab:CreateToggle({Name = "Player ESP", CurrentValue = S.ESP, Flag = "ESPToggle",
        Callback = function(v) S.ESP = v; if not v and cleanESP then cleanESP() end; saveCurrentState() end})
    MainTab:CreateSection("Anti-Cheat")
    MainTab:CreateToggle({Name = "Anti-Kick", CurrentValue = S.AntiKick, Flag = "AntiKickToggle",
        Callback = function(v) S.AntiKick = v; saveCurrentState() end})
    MainTab:CreateToggle({Name = "Anti-AFK", CurrentValue = S.AntiAFK, Flag = "AntiAFKToggle",
        Callback = function(v) S.AntiAFK = v; saveCurrentState() end})
    MainTab:CreateSection("Server")
    MainTab:CreateButton({Name = "Rejoin Server", Callback = function() rejoinServer() end})

    GriefTab:CreateSection("Connection")
    GriefTab:CreateButton({Name = "Test F3X Connection", Callback = function()
        local ok, msg = testF3XConnection()
        notify("Grief Test", msg or "Unknown error", 6)
        print("[Nicotine] Test result: " .. tostring(msg))
    end})
    GriefTab:CreateSection("F3X Griefing")
    GriefTab:CreateButton({Name = "Delete Everything", Callback = function() task.spawn(massDelete) end})
    GriefTab:CreateButton({Name = "Unanchor All", Callback = function() task.spawn(unanchorAll) end})
    GriefTab:CreateButton({Name = "Fling Parts", Callback = function() task.spawn(flingParts) end})
    GriefTab:CreateButton({Name = "Void All", Callback = function() task.spawn(voidAll) end})
    GriefTab:CreateSection("Defense")
    GriefTab:CreateButton({Name = "Anti-F3X", Callback = function() antiF3X() end})

    PlatformTab:CreateSection("Size")
    PlatformTab:CreateSlider({Name = "Platform Size", Range = {10, 1000}, Increment = 25, Suffix = "studs",
        CurrentValue = S.PlatformSize, Flag = "PlatformSize",
        Callback = function(v) S.PlatformSize = v; saveCurrentState() end})
    PlatformTab:CreateSection("Square")
    PlatformTab:CreateButton({Name = "Square Below Me", Callback = function() platformAtMe(false) end})
    PlatformTab:CreateButton({Name = "Square Above Me", Callback = function() platformAtMe(true) end})
    PlatformTab:CreateSection("Circle")
    PlatformTab:CreateButton({Name = "Circle Below Me", Callback = function() circlePlatformAtMe(false) end})
    PlatformTab:CreateButton({Name = "Circle Above Me", Callback = function() circlePlatformAtMe(true) end})
    PlatformTab:CreateSection("Control")
    PlatformTab:CreateButton({Name = "Clear Local Platforms", Callback = function() clearPlatforms() end})

    BuildsTab:CreateSection("Builds")
    BuildsTab:CreateButton({Name = "Spawn House", Callback = function() spawnHouse() end})
    BuildsTab:CreateButton({Name = "Spawn Tower", Callback = function() spawnTower() end})
    BuildsTab:CreateButton({Name = "Spawn Bridge", Callback = function() spawnBridge() end})
    BuildsTab:CreateButton({Name = "Spawn Pyramid", Callback = function() spawnPyramid() end})
    BuildsTab:CreateButton({Name = "Spawn Wall", Callback = function() spawnWall() end})
    BuildsTab:CreateButton({Name = "Spawn Fountain", Callback = function() spawnFountain() end})
    BuildsTab:CreateButton({Name = "Clear All Builds", Callback = function() clearPlatforms() end})

    CreditsTab:CreateSection("Credits")
    CreditsTab:CreateParagraph({Title = "Creator", Content = "Shaw"})
    CreditsTab:CreateParagraph({Title = "Discord", Content = "Shaw6000"})
    CreditsTab:CreateSection("Settings")
    CreditsTab:CreateButton({Name = "Change Device (reloads UI)", Callback = function()
        S.Device = nil; saveCurrentState()
        notify("Nicotine", "Device reset. Re-execute to pick again.", 4)
        task.wait(1)
        pcall(function() RayfieldInstance:Destroy() end)
        task.spawn(function()
            local c = showDeviceSelector()
            if c == "mobile" then buildMobileUI()
            elseif c == "pc" then buildPCUI() end
        end)
    end})

    return Rayfield
end

buildPCUI = function()
    local BG     = Color3.fromRGB(18, 18, 22)
    local PANEL  = Color3.fromRGB(26, 26, 32)
    local CARD   = Color3.fromRGB(34, 34, 42)
    local HOVER  = Color3.fromRGB(44, 44, 54)
    local ACCENT = Color3.fromRGB(140, 90, 230)
    local RED    = Color3.fromRGB(220, 80, 100)
    local TEXT   = Color3.fromRGB(235, 235, 240)
    local SUB    = Color3.fromRGB(140, 140, 155)
    local LINE   = Color3.fromRGB(48, 48, 58)

    local sg = Instance.new("ScreenGui")
    sg.Name = "Nicotine"; sg.ResetOnSpawn = false; sg.IgnoreGuiInset = true
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling; sg.Parent = PG

    local win = Instance.new("Frame")
    win.Size = UDim2.new(0, 620, 0, 460)
    win.Position = UDim2.new(0.5, -310, 0.5, -230)
    win.BackgroundColor3 = BG; win.BorderSizePixel = 0
    win.Active = true; win.Draggable = true; win.Parent = sg
    Instance.new("UICorner", win).CornerRadius = UDim.new(0, 10)
    local ws = Instance.new("UIStroke", win)
    ws.Color = LINE; ws.Thickness = 1

    local tb = Instance.new("Frame")
    tb.Size = UDim2.new(1, 0, 0, 40); tb.BackgroundColor3 = PANEL
    tb.BorderSizePixel = 0; tb.Parent = win
    Instance.new("UICorner", tb).CornerRadius = UDim.new(0, 10)
    local tbf = Instance.new("Frame")
    tbf.Size = UDim2.new(1, 0, 0, 12); tbf.Position = UDim2.new(0, 0, 1, -12)
    tbf.BackgroundColor3 = PANEL; tbf.BorderSizePixel = 0; tbf.Parent = tb

    local t = Instance.new("TextLabel")
    t.Size = UDim2.new(0, 200, 1, 0); t.Position = UDim2.new(0, 16, 0, 0)
    t.BackgroundTransparency = 1; t.Text = "Nicotine"
    t.TextColor3 = TEXT; t.Font = Enum.Font.GothamBold; t.TextSize = 14
    t.TextXAlignment = Enum.TextXAlignment.Left; t.Parent = tb

    local close = Instance.new("TextButton")
    close.Size = UDim2.new(0, 28, 0, 28); close.Position = UDim2.new(1, -38, 0, 6)
    close.BackgroundColor3 = Color3.fromRGB(180, 60, 80); close.Text = "✕"
    close.TextColor3 = TEXT; close.Font = Enum.Font.GothamBold
    close.TextSize = 12; close.BorderSizePixel = 0; close.AutoButtonColor = false
    close.Parent = tb
    Instance.new("UICorner", close).CornerRadius = UDim.new(0, 6)

    local mini = Instance.new("TextButton")
    mini.Size = UDim2.new(0, 28, 0, 28); mini.Position = UDim2.new(1, -72, 0, 6)
    mini.BackgroundColor3 = Color3.fromRGB(60, 60, 72); mini.Text = "–"
    mini.TextColor3 = TEXT; mini.Font = Enum.Font.GothamBold
    mini.TextSize = 14; mini.BorderSizePixel = 0; mini.AutoButtonColor = false
    mini.Parent = tb
    Instance.new("UICorner", mini).CornerRadius = UDim.new(0, 6)
    mini.MouseButton1Click:Connect(function() win.Visible = false end)

    local side = Instance.new("Frame")
    side.Size = UDim2.new(0, 130, 1, -56); side.Position = UDim2.new(0, 8, 0, 48)
    side.BackgroundColor3 = PANEL; side.BorderSizePixel = 0; side.Parent = win
    Instance.new("UICorner", side).CornerRadius = UDim.new(0, 8)
    local sl = Instance.new("UIListLayout", side)
    sl.Padding = UDim.new(0, 3); sl.SortOrder = Enum.SortOrder.LayoutOrder
    local sp = Instance.new("UIPadding", side)
    sp.PaddingTop = UDim.new(0, 6); sp.PaddingLeft = UDim.new(0, 6)
    sp.PaddingRight = UDim.new(0, 6); sp.PaddingBottom = UDim.new(0, 6)

    local content = Instance.new("ScrollingFrame")
    content.Size = UDim2.new(1, -154, 1, -64); content.Position = UDim2.new(0, 146, 0, 48)
    content.BackgroundTransparency = 1; content.BorderSizePixel = 0
    content.CanvasSize = UDim2.new(0, 0, 0, 0)
    content.ScrollBarThickness = 3
    content.ScrollBarImageColor3 = ACCENT
    content.Parent = win
    local cl = Instance.new("UIListLayout", content)
    cl.Padding = UDim.new(0, 4); cl.SortOrder = Enum.SortOrder.LayoutOrder
    local cp = Instance.new("UIPadding", content)
    cp.PaddingTop = UDim.new(0, 2); cp.PaddingBottom = UDim.new(0, 10)

    local pages, tabs = {}, {}
    local currentTab = nil

    local function show(name)
        for n, p in pairs(pages) do p.Visible = (n == name) end
        for n, b in pairs(tabs) do
            b.BackgroundColor3 = (n == name) and HOVER or PANEL
            b.TextColor3 = (n == name) and TEXT or SUB
        end
    end

    local function tab(name)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, 0, 0, 30)
        b.BackgroundColor3 = PANEL; b.BorderSizePixel = 0
        b.Text = "  " .. name; b.TextColor3 = SUB
        b.TextXAlignment = Enum.TextXAlignment.Left
        b.Font = Enum.Font.GothamSemibold; b.TextSize = 12
        b.AutoButtonColor = false; b.Parent = side
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
        tabs[name] = b

        b.MouseEnter:Connect(function()
            if currentTab ~= name then b.BackgroundColor3 = Color3.fromRGB(38, 38, 46) end
        end)
        b.MouseLeave:Connect(function()
            if currentTab ~= name then b.BackgroundColor3 = PANEL end
        end)
        b.MouseButton1Click:Connect(function()
            currentTab = name; show(name)
        end)

        local p = Instance.new("Frame")
        p.Size = UDim2.new(1, 0, 0, 0); p.BackgroundTransparency = 1
        p.Visible = false; p.Parent = content
        local pl = Instance.new("UIListLayout", p)
        pl.Padding = UDim.new(0, 4); pl.SortOrder = Enum.SortOrder.LayoutOrder
        p.AutomaticSize = Enum.AutomaticSize.Y
        pages[name] = p
        return p
    end

    local function label(parent, text)
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1, 0, 0, 18); l.BackgroundTransparency = 1
        l.Text = text; l.TextColor3 = SUB
        l.Font = Enum.Font.GothamBold; l.TextSize = 10
        l.TextXAlignment = Enum.TextXAlignment.Left; l.Parent = parent
    end

    local function btn(parent, text, cb, accent)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, 0, 0, 30); b.BackgroundColor3 = CARD
        b.BorderSizePixel = 0; b.Text = "  " .. text; b.TextColor3 = TEXT
        b.TextXAlignment = Enum.TextXAlignment.Left
        b.Font = Enum.Font.GothamSemibold; b.TextSize = 12
        b.AutoButtonColor = false; b.Parent = parent
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)

        b.MouseEnter:Connect(function() b.BackgroundColor3 = HOVER end)
        b.MouseLeave:Connect(function() b.BackgroundColor3 = CARD end)
        b.MouseButton1Click:Connect(function()
            b.BackgroundColor3 = accent or ACCENT
            task.delay(0.12, function() b.BackgroundColor3 = CARD end)
            pcall(cb)
        end)
        return b
    end

    local function toggle(parent, text, state, cb)
        local f = Instance.new("Frame")
        f.Size = UDim2.new(1, 0, 0, 30); f.BackgroundColor3 = CARD
        f.BorderSizePixel = 0; f.Parent = parent
        Instance.new("UICorner", f).CornerRadius = UDim.new(0, 6)

        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1, -60, 1, 0); l.Position = UDim2.new(0, 12, 0, 0)
        l.BackgroundTransparency = 1; l.Text = text; l.TextColor3 = TEXT
        l.Font = Enum.Font.GothamSemibold; l.TextSize = 12
        l.TextXAlignment = Enum.TextXAlignment.Left; l.Parent = f

        local tr = Instance.new("Frame")
        tr.Size = UDim2.new(0, 36, 0, 18); tr.Position = UDim2.new(1, -46, 0.5, -9)
        tr.BackgroundColor3 = state and ACCENT or Color3.fromRGB(60, 60, 72)
        tr.BorderSizePixel = 0; tr.Parent = f
        Instance.new("UICorner", tr).CornerRadius = UDim.new(1, 0)

        local k = Instance.new("Frame")
        k.Size = UDim2.new(0, 14, 0, 14)
        k.Position = state and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)
        k.BackgroundColor3 = Color3.fromRGB(240, 240, 245)
        k.BorderSizePixel = 0; k.Parent = tr
        Instance.new("UICorner", k).CornerRadius = UDim.new(1, 0)

        local s = state
        f.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 then
                s = not s
                tr.BackgroundColor3 = s and ACCENT or Color3.fromRGB(60, 60, 72)
                k.Position = s and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)
                pcall(function() cb(s) end)
            end
        end)
    end

    local function slider(parent, text, minV, maxV, initial, cb)
        local f = Instance.new("Frame")
        f.Size = UDim2.new(1, 0, 0, 50); f.BackgroundColor3 = CARD
        f.BorderSizePixel = 0; f.Parent = parent
        Instance.new("UICorner", f).CornerRadius = UDim.new(0, 6)

        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1, -100, 0, 18); l.Position = UDim2.new(0, 12, 0, 6)
        l.BackgroundTransparency = 1; l.Text = text; l.TextColor3 = TEXT
        l.Font = Enum.Font.GothamSemibold; l.TextSize = 12
        l.TextXAlignment = Enum.TextXAlignment.Left; l.Parent = f

        local v = Instance.new("TextLabel")
        v.Size = UDim2.new(0, 70, 0, 18); v.Position = UDim2.new(1, -82, 0, 6)
        v.BackgroundTransparency = 1; v.Text = tostring(initial)
        v.TextColor3 = ACCENT; v.Font = Enum.Font.GothamBold; v.TextSize = 12
        v.TextXAlignment = Enum.TextXAlignment.Right; v.Parent = f

        local tr = Instance.new("Frame")
        tr.Size = UDim2.new(1, -24, 0, 6); tr.Position = UDim2.new(0, 12, 0, 32)
        tr.BackgroundColor3 = Color3.fromRGB(52, 52, 62); tr.BorderSizePixel = 0
        tr.Parent = f
        Instance.new("UICorner", tr).CornerRadius = UDim.new(1, 0)

        local fill = Instance.new("Frame")
        fill.Size = UDim2.new((initial - minV) / (maxV - minV), 0, 1, 0)
        fill.BackgroundColor3 = ACCENT; fill.BorderSizePixel = 0; fill.Parent = tr
        Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

        local k = Instance.new("Frame")
        k.Size = UDim2.new(0, 14, 0, 14)
        k.Position = UDim2.new((initial - minV) / (maxV - minV), -7, 0.5, -7)
        k.BackgroundColor3 = Color3.fromRGB(240, 240, 245); k.BorderSizePixel = 0
        k.Parent = tr
        Instance.new("UICorner", k).CornerRadius = UDim.new(1, 0)

        local drag = false
        local function set(x)
            local r = math.clamp((x - tr.AbsolutePosition.X) / tr.AbsoluteSize.X, 0, 1)
            local val = math.floor(minV + r * (maxV - minV))
            val = math.floor(val / 25) * 25
            local r2 = (val - minV) / (maxV - minV)
            fill.Size = UDim2.new(r2, 0, 1, 0)
            k.Position = UDim2.new(r2, -7, 0.5, -7)
            v.Text = tostring(val)
            pcall(function() cb(val) end)
        end
        tr.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 then drag = true; set(i.Position.X) end
        end)
        UIS.InputChanged:Connect(function(i)
            if drag and i.UserInputType == Enum.UserInputType.MouseMovement then set(i.Position.X) end
        end)
        UIS.InputEnded:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 then drag = false end
        end)
    end

    local function para(parent, title, text)
        local f = Instance.new("Frame")
        f.Size = UDim2.new(1, 0, 0, 0); f.AutomaticSize = Enum.AutomaticSize.Y
        f.BackgroundColor3 = PANEL; f.BorderSizePixel = 0; f.Parent = parent
        Instance.new("UICorner", f).CornerRadius = UDim.new(0, 6)
        local p = Instance.new("UIPadding", f)
        p.PaddingTop = UDim.new(0, 8); p.PaddingBottom = UDim.new(0, 8)
        p.PaddingLeft = UDim.new(0, 12); p.PaddingRight = UDim.new(0, 12)
        local l = Instance.new("UIListLayout", f)
        l.Padding = UDim.new(0, 3); l.SortOrder = Enum.SortOrder.LayoutOrder

        local t = Instance.new("TextLabel")
        t.Size = UDim2.new(1, 0, 0, 14); t.BackgroundTransparency = 1
        t.Text = title; t.TextColor3 = ACCENT
        t.Font = Enum.Font.GothamBold; t.TextSize = 10
        t.TextXAlignment = Enum.TextXAlignment.Left; t.Parent = f

        local c = Instance.new("TextLabel")
        c.Size = UDim2.new(1, 0, 0, 0); c.AutomaticSize = Enum.AutomaticSize.Y
        c.BackgroundTransparency = 1; c.Text = text; c.TextColor3 = SUB
        c.Font = Enum.Font.Gotham; c.TextSize = 11; c.TextWrapped = true
        c.TextXAlignment = Enum.TextXAlignment.Left
        c.TextYAlignment = Enum.TextYAlignment.Top; c.Parent = f
    end

    local Main = tab("Main")
    local Grief = tab("Grief")
    local Plat = tab("Platform")
    local Build = tab("Builds")
    local Cred = tab("Credits")

    label(Main, "F3X / BTOOLS")
    btn(Main, "Grab F3X & Return", function() task.spawn(function() pcall(grabAndReturn) end) end)
    btn(Main, "Grab Btools & Return", function() task.spawn(function() pcall(grabBtools) end) end)

    label(Main, "MOVEMENT")
    toggle(Main, "Infinite Jump", S.InfJump, function(v) S.InfJump = v; saveCurrentState() end)

    label(Main, "VISUAL")
    toggle(Main, "Player ESP", S.ESP, function(v)
        S.ESP = v; if not v and cleanESP then cleanESP() end; saveCurrentState()
    end)

    label(Main, "ANTI-CHEAT")
    toggle(Main, "Anti-Kick", S.AntiKick, function(v) S.AntiKick = v; saveCurrentState() end)
    toggle(Main, "Anti-AFK", S.AntiAFK, function(v) S.AntiAFK = v; saveCurrentState() end)

    label(Main, "SERVER")
    btn(Main, "Rejoin Server", function() rejoinServer() end)

    label(Grief, "CONNECTION")
    btn(Grief, "Test F3X Connection", function()
        local ok, msg = testF3XConnection()
        notify("Grief Test", msg or "Unknown error", 6)
        print("[Nicotine] Test result: " .. tostring(msg))
    end)

    label(Grief, "F3X GRIEFING")
    btn(Grief, "Delete Everything", function() task.spawn(massDelete) end, RED)
    btn(Grief, "Unanchor All", function() task.spawn(unanchorAll) end, RED)
    btn(Grief, "Fling Parts", function() task.spawn(flingParts) end, RED)
    btn(Grief, "Void All", function() task.spawn(voidAll) end, RED)

    label(Grief, "DEFENSE")
    btn(Grief, "Anti-F3X (hide others)", function() antiF3X() end)
    para(Grief, "Warning", "These will lag or crash the server. Use at your own risk.")

    label(Plat, "SIZE")
    slider(Plat, "Platform Size", 10, 1000, S.PlatformSize, function(v) S.PlatformSize = v; saveCurrentState() end)

    label(Plat, "SQUARE")
    btn(Plat, "Square Below Me", function() platformAtMe(false) end)
    btn(Plat, "Square Above Me", function() platformAtMe(true) end)

    label(Plat, "CIRCLE")
    btn(Plat, "Circle Below Me", function() circlePlatformAtMe(false) end)
    btn(Plat, "Circle Above Me", function() circlePlatformAtMe(true) end)

    label(Plat, "CONTROL")
    btn(Plat, "Clear Local Platforms", function() clearPlatforms() end)

    label(Build, "SPAWN BUILDS")
    btn(Build, "House", function() spawnHouse() end)
    btn(Build, "Tower", function() spawnTower() end)
    btn(Build, "Bridge", function() spawnBridge() end)
    btn(Build, "Pyramid", function() spawnPyramid() end)
    btn(Build, "Wall", function() spawnWall() end)
    btn(Build, "Fountain", function() spawnFountain() end)

    label(Build, "CONTROL")
    btn(Build, "Clear All Local", function() clearPlatforms() end)

    label(Cred, "CREDITS")
    para(Cred, "Creator", "Shaw")
    para(Cred, "Discord", "Shaw6000")

    label(Cred, "SETTINGS")
    btn(Cred, "Change Device (reloads UI)", function()
        S.Device = nil; saveCurrentState()
        notify("Nicotine", "Device reset. Pick again in the prompt.", 3)
        task.wait(0.4)
        sg:Destroy()
        task.spawn(function()
            local c = showDeviceSelector()
            if c == "mobile" then buildMobileUI()
            elseif c == "pc" then buildPCUI() end
        end)
    end)

    local function updateCanvas()
        content.CanvasSize = UDim2.new(0, 0, 0, cl.AbsoluteContentSize.Y + 20)
    end
    cl:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvas)

    currentTab = "Main"
    show("Main")

    local visible = true
    trk(UIS.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.KeyCode == Enum.KeyCode.K then
            if win and win.Parent then
                visible = not visible
                win.Visible = visible
            end
        end
    end))

    mini.MouseButton1Click:Connect(function()
        visible = false
        if win and win.Parent then win.Visible = false end
    end)

    close.MouseButton1Click:Connect(function()
        pcall(function() sg:Destroy() end)
    end)

    addResizeHandle(win, 400, 300, 1200, 800)

    return {Destroy = function() pcall(function() sg:Destroy() end) end}
end

task.spawn(function()
    local choice = S.Device
    if not choice or (choice ~= "mobile" and choice ~= "pc") then
        choice = showDeviceSelector()
    end
    if choice == "mobile" then
        local success = buildMobileUI()
        if success then notify("Nicotine", "Loaded (Mobile UI)", 4)
        else notify("Nicotine", "Failed to load Mobile UI", 4) end
    elseif choice == "pc" then
        buildPCUI()
        notify("Nicotine", "Loaded (PC UI) • Press K", 4)
    end
end)

getgenv().Nicotine = function()
    S.InfJump = false; S.ESP = false; S.AntiKick = false
    S.AntiAFK = false
    if cleanESP then cleanESP() end
    clearPlatforms()
    for _, c in ipairs(S.Conn) do pcall(function() c:Disconnect() end) end
    S.Conn = {}
    for _, v in ipairs(PG:GetChildren()) do
        if v.Name == "Nicotine" or v.Name == "NicotineSelector" then
            pcall(function() v:Destroy() end)
        end
    end
    notify("Nicotine", "Unloaded.", 2)
end

applyAntiKick()
setupAntiAFK()
saveCurrentState()
print("[Nicotine] Done")
