local success, Library = pcall(function()
    return loadstring(game:HttpGet('https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/Library.lua'))()
end)
if not success or not Library then warn("Failed to load UI library") return end

local ThemeManager = loadstring(game:HttpGet('https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/addons/ThemeManager.lua'))()
local SaveManager   = loadstring(game:HttpGet('https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/addons/SaveManager.lua'))()


local Window = Library:CreateWindow({
    Title    = 'Reznov Hub v1.2',
    Center   = true,
    AutoShow = true,
})

local Services = {
    Players         = game:GetService("Players"),
    RunService      = game:GetService("RunService"),
    UIS             = game:GetService("UserInputService"),
    TeleportService = game:GetService("TeleportService"),
    Lighting        = game:GetService("Lighting"),
    HttpService     = game:GetService("HttpService"),
    VirtualUser     = game:GetService("VirtualUser"),
    CoreGui         = game:GetService("CoreGui"),
    StarterGui      = game:GetService("StarterGui"),
    TweenService    = game:GetService("TweenService"),
}

local plr    = Services.Players.LocalPlayer
local camera = workspace.CurrentCamera
local char   = plr.Character or plr.CharacterAdded:Wait()
local hrp, hum

local function updateChar()
    hrp = char:WaitForChild("HumanoidRootPart")
    hum = char:WaitForChild("Humanoid")
end
updateChar()
plr.CharacterAdded:Connect(function(c)
    char = c
    task.wait(0.1)
    updateChar()
end)

-- ─── Connection / Drawing Tracking ──────────────────────────────────────────
-- Each independent system has its own table so cleanups don't stomp each other.

local connections    = {}
local noclipConns    = {}
local hudConns       = {}
local nametagConns   = {}
local drawingObjects = {}   -- every Drawing.new tracked here for full removal

local function addConn(t, conn)
    table.insert(t, conn)
    return conn
end
local function gc(conn) return addConn(connections, conn) end

local function killTable(t)
    for _, c in ipairs(t) do pcall(function() c:Disconnect() end) end
    table.clear(t)
end

local function trackDrawing(d)
    table.insert(drawingObjects, d)
    return d
end

-- ─── Notify ─────────────────────────────────────────────────────────────────

local function Notify(cfg)
    pcall(function()
        Services.StarterGui:SetCore("SendNotification", {
            Title    = cfg.Title    or "Script",
            Text     = cfg.Text     or "",
            Duration = cfg.Duration or 2,
        })
    end)
end

-- ─── Config ─────────────────────────────────────────────────────────────────

local config = {
    flySpeed    = 75,
    noclipSpeed = 0.5,
    tpSpeed     = 2,
    walkSpeed   = 16,
    jumpPower   = 50,
    swimSpeed   = 16,
    gravity     = 196.2,
    hipHeight   = 2,

    aimbotFOV              = 200,
    aimbotSmoothing        = 5,
    aimbotPart             = "Head",
    aimbotVisibleOnly      = true,
    aimbotTeamCheck        = true,
    aimbotDeadCheck        = true,
    aimbotShowFOV          = true,
    aimbotPrediction       = false,
    aimbotPredictionAmount = 0.15,
    aimbotSticky           = false,
    aimbotSwitchDelay      = 0.5,

    espDistance   = 1000,
    espTeamCheck  = false,
    espBox        = false,
    espName       = false,
    espHealth     = false,
    espTracer     = false,
    espChams      = false,
    espNameMode   = "Both",   -- "Display", "Username", "Both"
    espBoxColor   = Color3.fromRGB(255, 50, 50),
    espNameColor  = Color3.fromRGB(255, 255, 255),
    espTracerColor = Color3.fromRGB(255, 50, 50),
    espChamsColor = Color3.fromRGB(255, 50, 50),
    espChamsAlpha = 0.6,

    fov      = 70,
    savedFOV = nil,     -- FIX: nil so first enable captures real game FOV

    platformSize         = 8,
    platformTransparency = 0.5,
    platformYOffset      = 0,

    spinSpeed   = 20,
    timeOfDay   = 14,

    atmosphereDensity = 0.395,
    atmosphereOffset  = 0,
    atmosphereColor   = Color3.fromRGB(199, 170, 140),
    atmosphereDecay   = Color3.fromRGB(106, 127, 189),
    atmosphereGlare   = 0,
    atmosphereHaze    = 0,

    crosshairSize      = 12,
    crosshairColor     = Color3.fromRGB(0, 255, 0),
    crosshairStyle     = "Cross",
    crosshairThickness = 2,
    crosshairGap       = 4,

    sessionStartTime = tick(),
    ignoreList    = {},
    friendList    = {},
    teamWhitelist = {},
}

-- ─── State ──────────────────────────────────────────────────────────────────

local state = {
    unloaded         = false,
    flying           = false,
    tpWalk           = false,
    infJump          = false,
    speedBypass      = false,
    noclipEnabled    = false,
    aimbotEnabled    = false,
    aimbotActive     = false,
    aimbotTarget     = nil,
    aimbotLastSwitch = 0,
    afkActive        = false,
    autoRejoin       = false,
    fovEnabled       = false,
    fullbrightEnabled = false,
    noFogEnabled     = false,
    timeOfDayEnabled = false,
    clickTPEnabled   = false,
    crosshairEnabled = false,
    coordsEnabled    = false,
    velocityEnabled  = false,
    fpsEnabled       = false,
    platformEnabled  = false,
    platformFixedY   = 0,
    spinEnabled      = false,
    spinConn         = nil,
    weatherActive    = nil,
    weatherFolder    = nil,
    hudEnabled       = false,
    gameInfoEnabled  = false,
    nametagsEnabled  = false,
}

-- ─── Locals ──────────────────────────────────────────────────────────────────

local ctrl     = {f=0, b=0, l=0, r=0}
local moveKeys = {w=false, a=false, s=false, d=false}
local bg, bv, flySpd = nil, nil, 0

local aimbotCircle      = nil
local crosshairGui      = nil
local crosshairDrawing  = nil   -- FIX: tracked separately for Drawing Circle cleanup
local coordsLabel       = nil
local velocityLabel     = nil
local fpsLabel          = nil
local platformPart      = nil
local hudGui            = nil
local hudFrame          = nil
local hudLabels         = {}
local gameInfoGui       = nil
local playerListGui     = nil
local chatSpyGui        = nil

local savedLighting   = {}
local savedSky        = nil
local savedAtmosphere = {}

-- ─── Helpers ─────────────────────────────────────────────────────────────────

local function getMoveVector()
    if not camera then return Vector3.zero end
    local d = Vector3.zero
    if moveKeys.w then d = d + camera.CFrame.LookVector  end
    if moveKeys.s then d = d - camera.CFrame.LookVector  end
    if moveKeys.a then d = d - camera.CFrame.RightVector end
    if moveKeys.d then d = d + camera.CFrame.RightVector end
    return d.Magnitude > 0 and d.Unit or Vector3.zero
end

local function isFriend(p)
    for _, uid in ipairs(config.friendList) do
        if p.UserId == uid then return true end
    end
    return false
end

local function isIgnored(p)
    for _, uid in ipairs(config.ignoreList) do
        if p.UserId == uid then return true end
    end
    return false
end

local function isTeamWhitelisted(team)
    if not team then return false end
    for _, name in ipairs(config.teamWhitelist) do
        if team.Name == name then return true end
    end
    return false
end

-- ─── Input ───────────────────────────────────────────────────────────────────

gc(Services.UIS.InputBegan:Connect(function(i, gp)
    if gp then return end
    local k = i.KeyCode.Name:lower()
    if k=="w" then ctrl.f=1 elseif k=="s" then ctrl.b=-1
    elseif k=="a" then ctrl.l=-1 elseif k=="d" then ctrl.r=1 end
end))
gc(Services.UIS.InputEnded:Connect(function(i)
    local k = i.KeyCode.Name:lower()
    if k=="w" then ctrl.f=0 elseif k=="s" then ctrl.b=0
    elseif k=="a" then ctrl.l=0 elseif k=="d" then ctrl.r=0 end
end))

-- ─── Fly ─────────────────────────────────────────────────────────────────────

local function FlyLoop()
    if not hrp then return end
    bg = Instance.new("BodyGyro")
    bg.P = 1e5; bg.MaxTorque = Vector3.new(1e9,1e9,1e9); bg.Parent = hrp
    bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(1e9,1e9,1e9); bv.Velocity = Vector3.zero; bv.Parent = hrp
    if hum then hum.PlatformStand = true end
    Notify({Title="Fly", Text="Enabled", Duration=1})
    while state.flying and not state.unloaded do
        task.wait()
        local mv = Vector3.zero
        if ctrl.f+ctrl.b~=0 or ctrl.l+ctrl.r~=0 then
            mv = (camera.CFrame.LookVector*(ctrl.f+ctrl.b))+(camera.CFrame.RightVector*(ctrl.r+ctrl.l))
            if mv.Magnitude>0 then mv=mv.Unit end
            flySpd = math.clamp(flySpd+2.5, 0, config.flySpeed)
        else
            flySpd = math.clamp(flySpd-2, 0, config.flySpeed)
        end
        if bv then pcall(function() bv.Velocity = mv*flySpd+Vector3.new(0,0.1,0) end) end
        if bg and hrp then pcall(function() bg.CFrame = CFrame.lookAt(hrp.Position, hrp.Position+camera.CFrame.LookVector) end) end
    end
    flySpd = 0
    if bg then pcall(function() bg:Destroy() end); bg=nil end
    if bv then pcall(function() bv:Destroy() end); bv=nil end
    if hum then pcall(function() hum.PlatformStand=false end) end
    Notify({Title="Fly", Text="Disabled", Duration=1})
end

-- ─── No-Clip ─────────────────────────────────────────────────────────────────

local function ToggleNoClip(enabled)
    state.noclipEnabled = enabled
    if enabled then
        Notify({Title="No-Clip", Text="Enabled", Duration=1})
        addConn(noclipConns, Services.RunService.Stepped:Connect(function()
            if not state.noclipEnabled or not char then return end
            for _, v in ipairs(char:GetDescendants()) do
                if v:IsA("BasePart") then v.CanCollide=false end
            end
        end))
        addConn(noclipConns, Services.RunService.Heartbeat:Connect(function()
            if not state.noclipEnabled or not hrp then return end
            local mv = getMoveVector()
            if mv.Magnitude>0 then hrp.CFrame = hrp.CFrame+(mv*config.noclipSpeed*50*0.016) end
        end))
        addConn(noclipConns, Services.UIS.InputBegan:Connect(function(i,g)
            if g or not i.KeyCode then return end
            local k=i.KeyCode.Name:lower(); if moveKeys[k]~=nil then moveKeys[k]=true end
        end))
        addConn(noclipConns, Services.UIS.InputEnded:Connect(function(i)
            if not i.KeyCode then return end
            local k=i.KeyCode.Name:lower(); if moveKeys[k]~=nil then moveKeys[k]=false end
        end))
    else
        killTable(noclipConns)
        if char then
            for _, v in ipairs(char:GetDescendants()) do
                if v:IsA("BasePart") then v.CanCollide=true end
            end
        end
        Notify({Title="No-Clip", Text="Disabled", Duration=1})
    end
end

-- ─── TP Walk ─────────────────────────────────────────────────────────────────

local function TPWalkLoop()
    Notify({Title="TP Walk", Text="Enabled", Duration=1})
    while state.tpWalk and not state.unloaded do
        task.wait()
        -- FIX: nil-check hrp before accessing it
        if hrp and (ctrl.f+ctrl.b~=0 or ctrl.l+ctrl.r~=0) then
            local mv = (hrp.CFrame.LookVector*(ctrl.f+ctrl.b))+(hrp.CFrame.RightVector*(ctrl.r+ctrl.l))
            if mv.Magnitude>0 then hrp.CFrame = hrp.CFrame+mv.Unit*config.tpSpeed end
        end
    end
    Notify({Title="TP Walk", Text="Disabled", Duration=1})
end

-- ─── Infinite Jump ───────────────────────────────────────────────────────────

local function InfiniteJumpLoop()
    Notify({Title="Infinite Jump", Text="Enabled", Duration=1})
    local conn = gc(Services.UIS.JumpRequest:Connect(function()
        if state.infJump and hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end))
    while state.infJump and not state.unloaded do task.wait() end
    conn:Disconnect()
    Notify({Title="Infinite Jump", Text="Disabled", Duration=1})
end

-- ─── Speed Bypass ────────────────────────────────────────────────────────────

local function SpeedLoop()
    while state.speedBypass and not state.unloaded do
        task.wait()
        if not hum or not hrp then continue end
        hrp.AssemblyAngularVelocity = Vector3.zero
        hum.PlatformStand = false
        local st = hum:GetState()
        if st==Enum.HumanoidStateType.FallingDown or st==Enum.HumanoidStateType.Ragdoll or st==Enum.HumanoidStateType.Physics then
            hum:ChangeState(Enum.HumanoidStateType.Running)
        end
        local md = hum.MoveDirection
        if md.Magnitude>0 then
            -- FIX: use AssemblyLinearVelocity consistently, not deprecated .Velocity
            local velY = hrp.AssemblyLinearVelocity.Y
            hrp.AssemblyLinearVelocity = md.Unit*config.walkSpeed + Vector3.new(0,velY,0)
        else
            local v = hrp.AssemblyLinearVelocity
            hrp.AssemblyLinearVelocity = Vector3.new(v.X*0.35, v.Y, v.Z*0.35)
        end
    end
    if hrp then
        hrp.AssemblyLinearVelocity  = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
    end
end

-- ─── Teleport to Mouse ───────────────────────────────────────────────────────

local function TeleportToMouse()
    if not hrp or not camera then return end
    local mp  = Services.UIS:GetMouseLocation()
    local ray = camera:ScreenPointToRay(mp.X, mp.Y)
    local rp  = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Exclude
    rp.FilterDescendantsInstances = {char}
    rp.IgnoreWater = true
    local res = workspace:Raycast(ray.Origin, ray.Direction*5000, rp)
    local pos = res and res.Position or (ray.Origin+ray.Direction*100)
    pcall(function()
        hrp.CFrame = CFrame.new(pos+Vector3.new(0,3,0))
        hrp.AssemblyLinearVelocity = Vector3.zero
    end)
end

-- ─── Platform ────────────────────────────────────────────────────────────────

local function TogglePlatform(enabled)
    state.platformEnabled = enabled
    if enabled then
        if platformPart then platformPart:Destroy() end
        state.platformFixedY = hrp and (hrp.Position.Y-4) or 0
        platformPart = Instance.new("Part")
        platformPart.Size         = Vector3.new(config.platformSize, 0.5, config.platformSize)
        platformPart.Anchored     = true
        platformPart.Transparency = config.platformTransparency
        platformPart.Color        = Color3.fromRGB(0,170,255)
        platformPart.Material     = Enum.Material.Neon
        platformPart.CanCollide   = true
        platformPart.Parent       = workspace
        task.spawn(function()
            while state.platformEnabled and not state.unloaded do
                if hrp and platformPart then
                    platformPart.CFrame = CFrame.new(hrp.Position.X, state.platformFixedY+config.platformYOffset, hrp.Position.Z)
                end
                task.wait()
            end
        end)
    else
        if platformPart then platformPart:Destroy(); platformPart=nil end
    end
end

-- ─── Spin ────────────────────────────────────────────────────────────────────

local function ToggleSpin(enabled)
    state.spinEnabled = enabled
    -- FIX: always kill old conn before possibly making a new one
    if state.spinConn then
        pcall(function() state.spinConn:Disconnect() end)
        state.spinConn = nil
    end
    if enabled then
        state.spinConn = Services.RunService.RenderStepped:Connect(function(dt)
            if not state.spinEnabled or not hrp then return end
            hrp.CFrame = hrp.CFrame * CFrame.Angles(0, math.rad(config.spinSpeed*dt*60), 0)
        end)
    end
end

-- ─── Aimbot ──────────────────────────────────────────────────────────────────

local function CreateAimbotFOV()
    local c = trackDrawing(Drawing.new("Circle"))
    c.Thickness=2; c.NumSides=50; c.Radius=config.aimbotFOV
    c.Color=Color3.fromRGB(255,255,255); c.Visible=false; c.Filled=false; c.Transparency=1
    return c
end

local function IsVisible(tc)
    if not tc then return false end
    local tp = tc:FindFirstChild(config.aimbotPart)
    if not tp or not camera then return false end
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Exclude
    rp.FilterDescendantsInstances = {char, camera}
    rp.IgnoreWater = true
    local orig = camera.CFrame.Position
    local res  = workspace:Raycast(orig, (tp.Position-orig).Unit*1000, rp)
    return res and res.Instance and res.Instance:IsDescendantOf(tc)
end

local function GetAimbotTarget()
    local best, bestDist = nil, config.aimbotFOV
    for _, p in pairs(Services.Players:GetPlayers()) do
        if p==plr or not p.Character then continue end
        if isIgnored(p) then continue end
        if config.aimbotTeamCheck then
            if p.Team and plr.Team and p.Team==plr.Team then continue end
            if isTeamWhitelisted(p.Team) then continue end
        end
        local ph = p.Character:FindFirstChildOfClass("Humanoid")
        if config.aimbotDeadCheck and ph and ph.Health<=0 then continue end
        local pp = p.Character:FindFirstChild(config.aimbotPart)
        if not pp then continue end
        if config.aimbotVisibleOnly and not IsVisible(p.Character) then continue end
        local sp, onScreen = camera:WorldToViewportPoint(pp.Position)
        if not onScreen then continue end
        local d = (Vector2.new(sp.X,sp.Y)-Services.UIS:GetMouseLocation()).Magnitude
        if d<bestDist then bestDist=d; best=p end
    end
    return best
end

local function ToggleAimbot(enabled)
    state.aimbotEnabled = enabled
    if enabled then
        if not aimbotCircle then aimbotCircle = CreateAimbotFOV() end
        aimbotCircle.Visible = config.aimbotShowFOV
        -- activate immediately when enabled, no separate key press needed by default
        state.aimbotActive = true
        gc(Services.RunService.RenderStepped:Connect(function()
            if not state.aimbotEnabled then return end
            local mp = Services.UIS:GetMouseLocation()
            aimbotCircle.Position = mp
            aimbotCircle.Radius   = config.aimbotFOV
            aimbotCircle.Color    = state.aimbotTarget
                and Color3.fromRGB(255,50,50) or Color3.fromRGB(255,255,255)
            aimbotCircle.Visible  = config.aimbotShowFOV
            if not state.aimbotActive then return end
            local now = tick()

            if config.aimbotSticky and state.aimbotTarget and state.aimbotTarget.Character then
                local tp = state.aimbotTarget.Character:FindFirstChild(config.aimbotPart)
                if tp then
                    local tpos = camera:WorldToViewportPoint(tp.Position)
                    local dx = (tpos.X - mp.X) / config.aimbotSmoothing
                    local dy = (tpos.Y - mp.Y) / config.aimbotSmoothing
                    pcall(mousemoverel, dx, dy)
                    return
                end
            end

            local target = GetAimbotTarget()
            if target ~= state.aimbotTarget then
                if now - state.aimbotLastSwitch < config.aimbotSwitchDelay then
                    target = state.aimbotTarget
                else
                    state.aimbotTarget    = target
                    state.aimbotLastSwitch = now
                end
            end

            if target and target.Character then
                local tp = target.Character:FindFirstChild(config.aimbotPart)
                if tp then
                    local targetPos
                    if config.aimbotPrediction then
                        local root = target.Character:FindFirstChild("HumanoidRootPart")
                        targetPos = root
                            and camera:WorldToViewportPoint(tp.Position + root.AssemblyLinearVelocity * config.aimbotPredictionAmount)
                            or  camera:WorldToViewportPoint(tp.Position)
                    else
                        targetPos = camera:WorldToViewportPoint(tp.Position)
                    end
                    local dx = (targetPos.X - mp.X) / config.aimbotSmoothing
                    local dy = (targetPos.Y - mp.Y) / config.aimbotSmoothing
                    pcall(mousemoverel, dx, dy)
                end
            else
                state.aimbotTarget = nil
            end
        end))
        Notify({Title="Aimbot", Text="Enabled", Duration=2})
    else
        if aimbotCircle then aimbotCircle.Visible=false end
        state.aimbotActive = false
        state.aimbotTarget = nil
        Notify({Title="Aimbot", Text="Disabled", Duration=1})
    end
end

-- ─── ESP ─────────────────────────────────────────────────────────────────────
-- Fully self-contained Drawing-based ESP. No external dependency.

local espObjects  = {}   -- [player] = { box, nameLabel, healthBg, healthBar, tracer, chams={} }
local espRenderConn = nil

local function espGetName(p)
    local dn = p.DisplayName
    local un = p.Name
    local mode = config.espNameMode
    if mode == "Display"  then return dn end
    if mode == "Username" then return un end
    -- Both
    return dn ~= un and (dn .. "  [" .. un .. "]") or un
end

local function espIsTeammate(p)
    if not config.espTeamCheck then return false end
    return p.Team and plr.Team and p.Team == plr.Team
end

local function espMakeObjects(p)
    local box = trackDrawing(Drawing.new("Square"))
    box.Thickness = 1; box.Filled = false; box.Color = config.espBoxColor
    box.Visible = false

    local nameLabel = trackDrawing(Drawing.new("Text"))
    nameLabel.Size = 13; nameLabel.Center = true; nameLabel.Outline = true
    nameLabel.Color = config.espNameColor; nameLabel.Visible = false

    local hbBg = trackDrawing(Drawing.new("Square"))
    hbBg.Thickness = 1; hbBg.Filled = true
    hbBg.Color = Color3.fromRGB(0,0,0); hbBg.Visible = false

    local hbBar = trackDrawing(Drawing.new("Square"))
    hbBar.Thickness = 1; hbBar.Filled = true
    hbBar.Color = Color3.fromRGB(0,255,0); hbBar.Visible = false

    local tracer = trackDrawing(Drawing.new("Line"))
    tracer.Thickness = 1; tracer.Color = config.espTracerColor; tracer.Visible = false

    espObjects[p] = {
        box      = box,
        name     = nameLabel,
        hbBg     = hbBg,
        hbBar    = hbBar,
        tracer   = tracer,
        chams    = {},
    }
end

local function espRemoveObjects(p)
    local obj = espObjects[p]
    if not obj then return end
    pcall(function() obj.box:Remove()    end)
    pcall(function() obj.name:Remove()   end)
    pcall(function() obj.hbBg:Remove()   end)
    pcall(function() obj.hbBar:Remove()  end)
    pcall(function() obj.tracer:Remove() end)
    for _, c in ipairs(obj.chams) do pcall(function() c:Destroy() end) end
    espObjects[p] = nil
end

local function espApplyChams(p, enable)
    local obj = espObjects[p]
    if not obj then return end
    for _, c in ipairs(obj.chams) do pcall(function() c:Destroy() end) end
    obj.chams = {}
    if not enable or not p.Character then return end

    -- one Highlight on the character model — no per-part box spam
    local hl = Instance.new("Highlight")
    hl.Adornee         = p.Character
    hl.FillColor       = config.espChamsColor
    hl.FillTransparency = config.espChamsAlpha
    hl.OutlineColor    = config.espChamsColor
    hl.OutlineTransparency = 0
    hl.DepthMode       = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent          = Services.CoreGui
    table.insert(obj.chams, hl)
end

local function espUpdateChamsColor()
    for _, obj in pairs(espObjects) do
        for _, c in ipairs(obj.chams) do
            pcall(function()
                c.FillColor            = config.espChamsColor
                c.OutlineColor         = config.espChamsColor
                c.FillTransparency     = config.espChamsAlpha
            end)
        end
    end
end

local function espRebuildAll()
    -- called when a toggle changes; refreshes chams on/off and color-only changes
    for p, _ in pairs(espObjects) do
        espApplyChams(p, config.espChams)
    end
end

local function espStartRender()
    if espRenderConn then return end
    espRenderConn = gc(Services.RunService.RenderStepped:Connect(function()
        if state.unloaded then return end
        local vpSize = camera.ViewportSize

        for _, p in pairs(Services.Players:GetPlayers()) do
            if p == plr then continue end

            local obj = espObjects[p]
            if not obj then continue end

            local pchar  = p.Character
            local root   = pchar and pchar:FindFirstChild("HumanoidRootPart")
            local phum   = pchar and pchar:FindFirstChildOfClass("Humanoid")
            local anyOn  = config.espBox or config.espName or config.espHealth or config.espTracer or config.espChams

            if not root or not anyOn or espIsTeammate(p) or not pchar then
                obj.box.Visible    = false
                obj.name.Visible   = false
                obj.hbBg.Visible   = false
                obj.hbBar.Visible  = false
                obj.tracer.Visible = false
                continue
            end

            -- world-to-screen for root
            local rootSP, rootOnScreen = camera:WorldToViewportPoint(root.Position)
            if not rootOnScreen or rootSP.Z < 0 then
                obj.box.Visible    = false
                obj.name.Visible   = false
                obj.hbBg.Visible   = false
                obj.hbBar.Visible  = false
                obj.tracer.Visible = false
                continue
            end

            local dist = (root.Position - camera.CFrame.Position).Magnitude
            if dist > config.espDistance then
                obj.box.Visible    = false
                obj.name.Visible   = false
                obj.hbBg.Visible   = false
                obj.hbBar.Visible  = false
                obj.tracer.Visible = false
                continue
            end

            -- estimate box bounds using head and HRP
            local head = pchar:FindFirstChild("Head")
            local headSP = head and select(1, camera:WorldToViewportPoint(head.Position + Vector3.new(0, head.Size.Y/2, 0)))
                or Vector3.new(rootSP.X, rootSP.Y - 30, 0)
            local footSP = select(1, camera:WorldToViewportPoint(root.Position - Vector3.new(0, 3, 0)))

            local boxH = math.abs(headSP.Y - footSP.Y)
            local boxW = boxH * 0.5
            local boxX = rootSP.X - boxW/2
            local boxY = headSP.Y

            -- Box
            if config.espBox then
                obj.box.Size     = Vector2.new(boxW, boxH)
                obj.box.Position = Vector2.new(boxX, boxY)
                obj.box.Color    = config.espBoxColor
                obj.box.Visible  = true
            else
                obj.box.Visible = false
            end

            -- Name
            if config.espName then
                obj.name.Text     = espGetName(p)
                obj.name.Color    = config.espNameColor
                obj.name.Position = Vector2.new(rootSP.X, boxY - 16)
                obj.name.Visible  = true
            else
                obj.name.Visible = false
            end

            -- Health bar (left side of box)
            if config.espHealth and phum then
                local ratio  = math.clamp(phum.Health / math.max(phum.MaxHealth, 1), 0, 1)
                local barW   = 3
                local barX   = boxX - barW - 2
                local barH   = boxH * ratio
                obj.hbBg.Size     = Vector2.new(barW, boxH)
                hbBg.Position = Vector2.new(barX, boxY)
                hbBg.Visible  = true
                obj.hbBar.Size     = Vector2.new(barW, barH)
                obj.hbBar.Position = Vector2.new(barX, boxY + (boxH - barH))
                obj.hbBar.Color    = Color3.fromRGB(math.floor(255*(1-ratio)), math.floor(255*ratio), 0)
                obj.hbBar.Visible  = true
            else
                obj.hbBg.Visible  = false
                obj.hbBar.Visible = false
            end

            -- Tracer
            if config.espTracer then
                obj.tracer.From    = Vector2.new(vpSize.X/2, vpSize.Y)
                obj.tracer.To      = Vector2.new(rootSP.X, rootSP.Y)
                obj.tracer.Color   = config.espTracerColor
                obj.tracer.Visible = true
            else
                obj.tracer.Visible = false
            end
        end
    end))
end

local function espHookCharacter(p)
    gc(p.CharacterAdded:Connect(function()
        task.wait(0.5)
        if config.espChams then espApplyChams(p, true) end
    end))
end

local function espInit()
    for _, p in pairs(Services.Players:GetPlayers()) do
        if p ~= plr then
            espMakeObjects(p)
            espHookCharacter(p)
            if config.espChams then espApplyChams(p, true) end
        end
    end
    gc(Services.Players.PlayerAdded:Connect(function(p)
        espMakeObjects(p)
        espHookCharacter(p)
    end))
    gc(Services.Players.PlayerRemoving:Connect(function(p)
        espRemoveObjects(p)
    end))
    espStartRender()
end

-- Setters called by UI toggles
local function SetEsp(espType, enabled)
    config["esp"..espType] = enabled
    if espType == "Chams" then espRebuildAll() end
end

local function espDestroyAll()
    for p, _ in pairs(espObjects) do espRemoveObjects(p) end
    espObjects = {}
end

-- ─── Nametag Override ────────────────────────────────────────────────────────

local function ClearNametags()
    killTable(nametagConns)
    local folder = workspace:FindFirstChild("ReznovNametags")
    if folder then folder:Destroy() end
end

local nametagRoot = nil

local function BuildNametag(p)
    if not p or p==plr then return end
    local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
    if not root then return end

    -- remove stale tag if exists
    local old = root:FindFirstChild("ReznovTag")
    if old then old:Destroy() end

    local bill = Instance.new("BillboardGui")
    bill.Name        = "ReznovTag"
    bill.Size        = UDim2.new(0,160,0,20)
    bill.StudsOffset = Vector3.new(0,3.2,0)
    bill.AlwaysOnTop = true
    bill.Adornee     = root
    bill.MaxDistance = config.espDistance
    bill.Parent      = nametagRoot or root

    local lbl = Instance.new("TextLabel")
    lbl.Size                  = UDim2.new(1,0,1,0)
    lbl.BackgroundTransparency = 1
    lbl.TextStrokeTransparency = 0
    lbl.Font                  = Enum.Font.GothamBold
    lbl.TextSize              = 13
    lbl.Text = (p.DisplayName~=p.Name)
        and (p.DisplayName.."  ["..p.Name.."]")
        or p.Name
    lbl.Parent = bill

    local function updateColor()
        local h = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
        if not h then lbl.TextColor3=Color3.fromRGB(255,255,255) return end
        local r = math.clamp(h.Health/math.max(h.MaxHealth,1), 0, 1)
        lbl.TextColor3 = Color3.fromRGB(math.floor(255*(1-r)), math.floor(255*r), 0)
    end
    updateColor()

    local h = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
    if h then addConn(nametagConns, h.HealthChanged:Connect(updateColor)) end
end

local function ToggleNametags(enabled)
    state.nametagsEnabled = enabled
    ClearNametags()
    if not enabled then return end

    nametagRoot = Instance.new("Folder")
    nametagRoot.Name   = "ReznovNametags"
    nametagRoot.Parent = workspace

    for _, p in pairs(Services.Players:GetPlayers()) do
        pcall(function() BuildNametag(p) end)
    end

    addConn(nametagConns, Services.Players.PlayerAdded:Connect(function(p)
        addConn(nametagConns, p.CharacterAdded:Connect(function()
            task.wait(0.5)
            pcall(function() BuildNametag(p) end)
        end))
    end))

    addConn(nametagConns, plr.CharacterAdded:Connect(function()
        task.wait(0.5)
        for _, p in pairs(Services.Players:GetPlayers()) do
            pcall(function() BuildNametag(p) end)
        end
    end))
end

-- ─── Lighting ────────────────────────────────────────────────────────────────

-- FIX: FOV/time-of-day in single RenderStepped instead of separate ones
gc(Services.RunService.RenderStepped:Connect(function()
    if state.fovEnabled and camera then camera.FieldOfView = config.fov end
    if state.timeOfDayEnabled then Services.Lighting.ClockTime = config.timeOfDay end
end))

local function SetFOV(enabled, value)
    state.fovEnabled = enabled
    config.fov = value or 70
    if enabled then
        -- FIX: savedFOV only captured once (was always 70 before)
        if not config.savedFOV then config.savedFOV = camera.FieldOfView end
        camera.FieldOfView = config.fov
    else
        if config.savedFOV then camera.FieldOfView=config.savedFOV; config.savedFOV=nil end
    end
end

local function ToggleFullbright(enabled)
    state.fullbrightEnabled = enabled
    if enabled then
        savedLighting.Ambient           = Services.Lighting.Ambient
        savedLighting.Brightness        = Services.Lighting.Brightness
        savedLighting.ColorShift_Bottom = Services.Lighting.ColorShift_Bottom
        savedLighting.ColorShift_Top    = Services.Lighting.ColorShift_Top
        savedLighting.OutdoorAmbient    = Services.Lighting.OutdoorAmbient
        savedLighting.ClockTime         = Services.Lighting.ClockTime
        Services.Lighting.Ambient           = Color3.fromRGB(255,255,255)
        Services.Lighting.Brightness        = 2
        Services.Lighting.ColorShift_Bottom = Color3.fromRGB(255,255,255)
        Services.Lighting.ColorShift_Top    = Color3.fromRGB(255,255,255)
        Services.Lighting.OutdoorAmbient    = Color3.fromRGB(255,255,255)
        Services.Lighting.ClockTime         = 14
    else
        for k,v in pairs(savedLighting) do pcall(function() Services.Lighting[k]=v end) end
        savedLighting = {}
    end
end

local function ToggleNoFog(enabled)
    state.noFogEnabled = enabled
    Services.Lighting.FogEnd   = enabled and 1000000 or 100000
    Services.Lighting.FogStart = 0
end

local function ToggleTimeOfDay(enabled)
    state.timeOfDayEnabled = enabled
    if not enabled and next(savedLighting) then
        if savedLighting.ClockTime then
            Services.Lighting.ClockTime = savedLighting.ClockTime
        end
    end
end

-- ─── Atmosphere ──────────────────────────────────────────────────────────────

local function GetOrCreateAtmosphere()
    local a = Services.Lighting:FindFirstChildOfClass("Atmosphere")
    if not a then a=Instance.new("Atmosphere"); a.Parent=Services.Lighting end
    return a
end

local function SaveAtmosphere()
    -- FIX: guard so switching weather types doesn't overwrite the real saved state
    if next(savedAtmosphere) then return end
    local a = Services.Lighting:FindFirstChildOfClass("Atmosphere")
    if a then
        savedAtmosphere = {Density=a.Density,Offset=a.Offset,Color=a.Color,Decay=a.Decay,Glare=a.Glare,Haze=a.Haze}
    end
end

local function RestoreAtmosphere()
    local a = Services.Lighting:FindFirstChildOfClass("Atmosphere")
    if a and next(savedAtmosphere) then
        for k,v in pairs(savedAtmosphere) do pcall(function() a[k]=v end) end
    end
    savedAtmosphere = {}
end

local function ApplyAtmosphereConfig()
    local a = GetOrCreateAtmosphere()
    a.Density=config.atmosphereDensity; a.Offset=config.atmosphereOffset
    a.Color=config.atmosphereColor;     a.Decay=config.atmosphereDecay
    a.Glare=config.atmosphereGlare;     a.Haze=config.atmosphereHaze
end

-- ─── Skybox ──────────────────────────────────────────────────────────────────

local skyboxPresets = {
    Bluesky     = {Bk="rbxassetid://159723129",Dn="rbxassetid://159723121",Ft="rbxassetid://159723130",Lf="rbxassetid://159723134",Rt="rbxassetid://159723128",Up="rbxassetid://159723127"},
    ["Night Stars"] = {Bk="rbxassetid://9041725671",Dn="rbxassetid://9041725671",Ft="rbxassetid://9041725671",Lf="rbxassetid://9041725671",Rt="rbxassetid://9041725671",Up="rbxassetid://9041725671"},
    Sunset      = {Bk="rbxassetid://176938311",Dn="rbxassetid://176938302",Ft="rbxassetid://176938316",Lf="rbxassetid://176938319",Rt="rbxassetid://176938308",Up="rbxassetid://176938314"},
    Space       = {Bk="rbxassetid://25430709",Dn="rbxassetid://25430706",Ft="rbxassetid://25430702",Lf="rbxassetid://25430710",Rt="rbxassetid://25430703",Up="rbxassetid://25430707"},
}

local function ApplySkybox(name)
    if name=="Default" then
        local sky = Services.Lighting:FindFirstChildOfClass("Sky")
        if sky and savedSky then
            sky.SkyboxBk=savedSky.Bk; sky.SkyboxDn=savedSky.Dn; sky.SkyboxFt=savedSky.Ft
            sky.SkyboxLf=savedSky.Lf; sky.SkyboxRt=savedSky.Rt; sky.SkyboxUp=savedSky.Up
        end
        return
    end
    local preset = skyboxPresets[name]
    if not preset then return end
    local sky = Services.Lighting:FindFirstChildOfClass("Sky")
    if not sky then sky=Instance.new("Sky"); sky.Parent=Services.Lighting
    elseif not savedSky then
        savedSky={Bk=sky.SkyboxBk,Dn=sky.SkyboxDn,Ft=sky.SkyboxFt,Lf=sky.SkyboxLf,Rt=sky.SkyboxRt,Up=sky.SkyboxUp}
    end
    sky.SkyboxBk=preset.Bk; sky.SkyboxDn=preset.Dn; sky.SkyboxFt=preset.Ft
    sky.SkyboxLf=preset.Lf; sky.SkyboxRt=preset.Rt; sky.SkyboxUp=preset.Up
end

-- ─── Weather ─────────────────────────────────────────────────────────────────

local function ClearWeather()
    if state.weatherFolder then pcall(function() state.weatherFolder:Destroy() end); state.weatherFolder=nil end
    state.weatherActive = nil
end

local function CreateWeather(wtype)
    ClearWeather()
    state.weatherActive = wtype
    local folder = Instance.new("Folder"); folder.Name="ReznovWeather"; folder.Parent=workspace
    state.weatherFolder = folder

    if wtype=="Rain" or wtype=="Snow" then
        local e = Instance.new("Part")
        e.Size=Vector3.new(wtype=="Rain" and 200 or 150, 1, wtype=="Rain" and 200 or 150)
        e.Anchored=true; e.Transparency=1; e.CanCollide=false; e.CastShadow=false; e.Parent=folder
        local pe = Instance.new("ParticleEmitter")
        if wtype=="Rain" then
            pe.Rate=800; pe.Speed=NumberRange.new(60,80); pe.Lifetime=NumberRange.new(0.5,1.2)
            pe.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,0.05),NumberSequenceKeypoint.new(1,0.05)})
            pe.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0.3),NumberSequenceKeypoint.new(1,0.8)})
            pe.Color=ColorSequence.new(Color3.fromRGB(180,200,230))
            pe.RotSpeed=NumberRange.new(0); pe.Rotation=NumberRange.new(90,90); pe.SpreadAngle=Vector2.new(3,0)
        else
            pe.Rate=300; pe.Speed=NumberRange.new(5,15); pe.Lifetime=NumberRange.new(4,7)
            pe.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,0.12),NumberSequenceKeypoint.new(0.5,0.1),NumberSequenceKeypoint.new(1,0)})
            pe.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(0.9,0.1),NumberSequenceKeypoint.new(1,1)})
            pe.Color=ColorSequence.new(Color3.fromRGB(240,245,255))
            pe.RotSpeed=NumberRange.new(-20,20); pe.Rotation=NumberRange.new(0,360); pe.SpreadAngle=Vector2.new(15,15)
        end
        pe.LightInfluence=0.5; pe.Parent=e
        local height = wtype=="Rain" and 40 or 30
        task.spawn(function()
            while state.weatherActive==wtype and not state.unloaded do
                if hrp then e.CFrame=CFrame.new(hrp.Position+Vector3.new(0,height,0)) end
                task.wait()
            end
        end)
        SaveAtmosphere()
        local a = GetOrCreateAtmosphere()
        if wtype=="Rain" then a.Density=0.6; a.Haze=1.5; a.Color=Color3.fromRGB(150,160,180)
        else a.Density=0.45; a.Haze=2.5; a.Color=Color3.fromRGB(200,210,230) end
    elseif wtype=="Fog" then
        SaveAtmosphere()
        local a = GetOrCreateAtmosphere()
        a.Density=0.85; a.Haze=3.5; a.Color=Color3.fromRGB(180,185,190); a.Offset=0.25
        Services.Lighting.FogEnd=200; Services.Lighting.FogStart=0
    end
end

local function StopWeather()
    ClearWeather(); RestoreAtmosphere()
    Services.Lighting.FogEnd=100000; Services.Lighting.FogStart=0
end

-- ─── Crosshair ───────────────────────────────────────────────────────────────

local function BuildCrosshair()
    if crosshairGui then pcall(function() crosshairGui:Destroy() end); crosshairGui=nil end
    -- FIX: properly kill the Drawing circle before making a new one
    if crosshairDrawing then pcall(function() crosshairDrawing:Remove() end); crosshairDrawing=nil end

    local style = config.crosshairStyle
    local sz, col, thick, gap = config.crosshairSize, config.crosshairColor, config.crosshairThickness, config.crosshairGap

    if style=="Circle" then
        local c = trackDrawing(Drawing.new("Circle"))
        c.Radius=sz; c.Thickness=thick; c.Color=col; c.Filled=false; c.Transparency=1; c.NumSides=40
        c.Visible = state.crosshairEnabled
        crosshairDrawing = c
        gc(Services.RunService.RenderStepped:Connect(function()
            c.Visible  = state.crosshairEnabled
            c.Position = Services.UIS:GetMouseLocation()
        end))
        return
    end

    local gui = Instance.new("ScreenGui")
    gui.Name="ReznovCrosshair"; gui.ResetOnSpawn=false; gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling

    if style=="Dot" then
        local dot=Instance.new("Frame"); dot.Size=UDim2.new(0,thick*2,0,thick*2)
        dot.Position=UDim2.new(0.5,-thick,0.5,-thick); dot.BackgroundColor3=col; dot.BorderSizePixel=0; dot.Parent=gui

    elseif style=="Cross" then
        -- FIX: use four separate segments (two halves each axis) instead of one bar with an invisible overlay
        local half = sz
        local off  = math.floor(thick/2)
        local function seg(x,y,w,h)
            local f=Instance.new("Frame"); f.BackgroundColor3=col; f.BorderSizePixel=0
            f.Size=UDim2.new(0,w,0,h); f.Position=UDim2.new(0.5,x,0.5,y); f.Parent=gui
        end
        seg(-(half+gap), -off, half, thick)  -- left
        seg(gap,         -off, half, thick)  -- right
        seg(-off, -(half+gap), thick, half)  -- top
        seg(-off,  gap,        thick, half)  -- bottom
    end

    gui.Parent=Services.CoreGui; crosshairGui=gui
end

local function ToggleCrosshair(enabled)
    state.crosshairEnabled = enabled
    if enabled then
        BuildCrosshair()
    else
        if crosshairGui then pcall(function() crosshairGui:Destroy() end); crosshairGui=nil end
        if crosshairDrawing then crosshairDrawing.Visible=false end
    end
end

-- ─── HUD Display Helpers ─────────────────────────────────────────────────────

local function makeLabel(name, w, h, x, y)
    local gui = Instance.new("ScreenGui"); gui.Name=name; gui.ResetOnSpawn=false
    local lbl = Instance.new("TextLabel")
    lbl.Size=UDim2.new(0,w,0,h); lbl.Position=UDim2.new(0,x,1,y)
    lbl.BackgroundColor3=Color3.fromRGB(0,0,0); lbl.BackgroundTransparency=0.5
    lbl.TextColor3=Color3.fromRGB(255,255,255); lbl.TextStrokeTransparency=0
    lbl.Font=Enum.Font.SourceSansBold; lbl.TextSize=14
    lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.Parent=gui; gui.Parent=Services.CoreGui
    return lbl
end

local function ToggleCoordinates(enabled)
    state.coordsEnabled = enabled
    if enabled then
        if not coordsLabel then coordsLabel=makeLabel("ReznovCoords",230,60,10,-70) end
        coordsLabel.Parent.Enabled=true
        task.spawn(function()
            while state.coordsEnabled and not state.unloaded do
                if hrp then
                    local p=hrp.Position
                    coordsLabel.Text=string.format("X: %.1f   Y: %.1f   Z: %.1f",p.X,p.Y,p.Z)
                end
                task.wait(0.1)
            end
        end)
    else
        if coordsLabel then coordsLabel.Parent.Enabled=false end
    end
end

local function ToggleVelocity(enabled)
    state.velocityEnabled = enabled
    if enabled then
        if not velocityLabel then velocityLabel=makeLabel("ReznovVelocity",165,40,250,-70) end
        velocityLabel.Parent.Enabled=true
        task.spawn(function()
            while state.velocityEnabled and not state.unloaded do
                if hrp then
                    local v=hrp.AssemblyLinearVelocity
                    velocityLabel.Text=string.format("Spd: %.1f\nYVel: %.1f",math.sqrt(v.X^2+v.Z^2),v.Y)
                end
                task.wait(0.05)
            end
        end)
    else
        if velocityLabel then velocityLabel.Parent.Enabled=false end
    end
end

local function ToggleFPSCounter(enabled)
    state.fpsEnabled = enabled
    if enabled then
        if not fpsLabel then
            local gui=Instance.new("ScreenGui"); gui.Name="ReznovFPS"; gui.ResetOnSpawn=false
            local l=Instance.new("TextLabel"); l.Size=UDim2.new(0,100,0,30); l.Position=UDim2.new(1,-110,0,10)
            l.BackgroundColor3=Color3.fromRGB(0,0,0); l.BackgroundTransparency=0.5
            l.TextColor3=Color3.fromRGB(0,255,0); l.TextStrokeTransparency=0
            l.Font=Enum.Font.SourceSansBold; l.TextSize=18; l.Text="FPS: 0"; l.Parent=gui; gui.Parent=Services.CoreGui
            fpsLabel=l
        end
        fpsLabel.Parent.Enabled=true
        task.spawn(function()
            local last,frames=tick(),0
            while state.fpsEnabled and not state.unloaded do
                frames=frames+1
                local now=tick()
                if now-last>=0.5 then
                    local fps=math.floor(frames/(now-last))
                    fpsLabel.Text="FPS: "..fps
                    fpsLabel.TextColor3=fps>=60 and Color3.fromRGB(0,255,0) or fps>=30 and Color3.fromRGB(255,255,0) or Color3.fromRGB(255,0,0)
                    frames,last=0,now
                end
                Services.RunService.RenderStepped:Wait()
            end
        end)
    else
        if fpsLabel then fpsLabel.Parent.Enabled=false end
    end
end

-- ─── Active Toggles HUD ──────────────────────────────────────────────────────
-- FIX: hash-based dirty check so labels only rebuild when state actually changes,
-- not every single RenderStepped frame (was creating/destroying instances at 60fps)

local hudHash = ""

local function GetHudHash()
    return table.concat({
        tostring(state.flying), tostring(state.noclipEnabled), tostring(state.speedBypass),
        tostring(state.infJump), tostring(state.tpWalk), tostring(state.aimbotEnabled),
        tostring(state.fullbrightEnabled), tostring(state.noFogEnabled), tostring(state.platformEnabled),
        tostring(state.spinEnabled), tostring(state.weatherActive or ""), tostring(state.timeOfDayEnabled),
        tostring(state.nametagsEnabled),
    }, "|")
end

local function RebuildHudLabels()
    if not hudFrame then return end
    for _, l in ipairs(hudLabels) do pcall(function() l:Destroy() end) end
    hudLabels = {}
    local list = {}
    if state.flying           then table.insert(list,"Fly") end
    if state.noclipEnabled    then table.insert(list,"No-Clip") end
    if state.speedBypass      then table.insert(list,"Speed") end
    if state.infJump          then table.insert(list,"Inf Jump") end
    if state.tpWalk           then table.insert(list,"TP Walk") end
    if state.aimbotEnabled    then table.insert(list,"Aimbot") end
    if state.fullbrightEnabled then table.insert(list,"Fullbright") end
    if state.noFogEnabled     then table.insert(list,"No Fog") end
    if state.platformEnabled  then table.insert(list,"Platform") end
    if state.spinEnabled      then table.insert(list,"Spin") end
    if state.weatherActive    then table.insert(list,state.weatherActive) end
    if state.timeOfDayEnabled then table.insert(list,"Time Lock") end
    if state.nametagsEnabled  then table.insert(list,"Nametags") end
    for i,name in ipairs(list) do
        local l=Instance.new("TextLabel"); l.Size=UDim2.new(1,0,0,18); l.Position=UDim2.new(0,0,0,(i-1)*20)
        l.BackgroundTransparency=1; l.TextColor3=Color3.fromRGB(0,220,120); l.TextStrokeTransparency=0.5
        l.Font=Enum.Font.SourceSansBold; l.TextSize=14; l.TextXAlignment=Enum.TextXAlignment.Right
        l.Text="[ "..name.." ]"; l.Parent=hudFrame; table.insert(hudLabels,l)
    end
end

local function ToggleHUD(enabled)
    state.hudEnabled = enabled
    killTable(hudConns)
    if enabled then
        if hudGui then pcall(function() hudGui:Destroy() end) end
        local gui=Instance.new("ScreenGui"); gui.Name="ReznovHUD"; gui.ResetOnSpawn=false; gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
        local frame=Instance.new("Frame"); frame.Size=UDim2.new(0,160,1,0); frame.Position=UDim2.new(1,-170,0,10)
        frame.BackgroundTransparency=1; frame.Parent=gui; hudFrame=frame; gui.Parent=Services.CoreGui; hudGui=gui
        RebuildHudLabels(); hudHash=GetHudHash()
        addConn(hudConns, Services.RunService.Heartbeat:Connect(function()
            if not state.hudEnabled then return end
            local h=GetHudHash(); if h~=hudHash then hudHash=h; RebuildHudLabels() end
        end))
    else
        if hudGui then pcall(function() hudGui:Destroy() end); hudGui=nil; hudFrame=nil end
    end
end

-- ─── Game Info Panel ─────────────────────────────────────────────────────────

local function ToggleGameInfo(enabled)
    state.gameInfoEnabled = enabled
    if not enabled then
        if gameInfoGui then pcall(function() gameInfoGui:Destroy() end); gameInfoGui=nil end
        return
    end

    local gui=Instance.new("ScreenGui"); gui.Name="ReznovGameInfo"; gui.ResetOnSpawn=false
    local frame=Instance.new("Frame"); frame.Size=UDim2.new(0,290,0,110)
    frame.Position=UDim2.new(0,10,0,10); frame.BackgroundColor3=Color3.fromRGB(15,15,15)
    frame.BackgroundTransparency=0.2; frame.BorderSizePixel=0
    local corner=Instance.new("UICorner"); corner.CornerRadius=UDim.new(0,6); corner.Parent=frame
    local lbl=Instance.new("TextLabel"); lbl.Size=UDim2.new(1,-10,1,-8); lbl.Position=UDim2.new(0,6,0,4)
    lbl.BackgroundTransparency=1; lbl.TextColor3=Color3.fromRGB(210,210,210); lbl.TextStrokeTransparency=0.6
    lbl.Font=Enum.Font.Code; lbl.TextSize=12; lbl.TextXAlignment=Enum.TextXAlignment.Left
    lbl.TextYAlignment=Enum.TextYAlignment.Top; lbl.RichText=true; lbl.Text="..."
    lbl.Parent=frame; frame.Parent=gui; gui.Parent=Services.CoreGui; gameInfoGui=gui

    local function refresh()
        local s = math.floor(tick()-config.sessionStartTime)
        lbl.Text = string.format(
            '<font color="rgb(100,200,255)">Server</font>\n'..
            'PlaceId: %d\n'..
            'JobId:  <font size="10">%s</font>\n'..
            'Players: %d / %d      Session: %02d:%02d',
            game.PlaceId,
            tostring(game.JobId):sub(1,26).."...",
            #Services.Players:GetPlayers(),
            Services.Players.MaxPlayers,
            math.floor(s/60), s%60
        )
    end
    refresh()
    gc(Services.RunService.Heartbeat:Connect(function()
        if state.gameInfoEnabled then refresh() end
    end))
end

-- ─── Player List ─────────────────────────────────────────────────────────────

local function OpenPlayerList()
    if playerListGui then
        pcall(function() playerListGui:Destroy() end); playerListGui=nil; return
    end
    local gui=Instance.new("ScreenGui"); gui.Name="ReznovPlayerList"; gui.ResetOnSpawn=false; gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
    local frame=Instance.new("Frame"); frame.Size=UDim2.new(0,220,0,300); frame.Position=UDim2.new(0.5,-110,0.5,-150)
    frame.BackgroundColor3=Color3.fromRGB(22,22,22); frame.BorderSizePixel=0
    local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,6); c.Parent=frame; frame.Parent=gui

    local title=Instance.new("TextLabel"); title.Size=UDim2.new(1,0,0,28); title.BackgroundColor3=Color3.fromRGB(32,32,32)
    title.BorderSizePixel=0; title.TextColor3=Color3.fromRGB(255,255,255); title.Font=Enum.Font.SourceSansBold
    title.TextSize=14; title.Text="Players"; title.Parent=frame

    local closeBtn=Instance.new("TextButton"); closeBtn.Size=UDim2.new(0,28,0,28); closeBtn.Position=UDim2.new(1,-28,0,0)
    closeBtn.BackgroundColor3=Color3.fromRGB(160,40,40); closeBtn.BorderSizePixel=0
    closeBtn.TextColor3=Color3.fromRGB(255,255,255); closeBtn.Font=Enum.Font.SourceSansBold
    closeBtn.TextSize=14; closeBtn.Text="X"; closeBtn.Parent=frame
    closeBtn.MouseButton1Click:Connect(function() pcall(function() gui:Destroy() end); playerListGui=nil end)

    local scroll=Instance.new("ScrollingFrame"); scroll.Size=UDim2.new(1,-10,1,-38); scroll.Position=UDim2.new(0,5,0,33)
    scroll.BackgroundTransparency=1; scroll.BorderSizePixel=0; scroll.ScrollBarThickness=6; scroll.Parent=frame
    local layout=Instance.new("UIListLayout"); layout.Padding=UDim.new(0,4); layout.Parent=scroll

    for _, p in pairs(Services.Players:GetPlayers()) do
        if p==plr then continue end
        local row=Instance.new("Frame"); row.Size=UDim2.new(1,0,0,30); row.BackgroundColor3=Color3.fromRGB(38,38,38); row.BorderSizePixel=0; row.Parent=scroll
        local nl=Instance.new("TextLabel"); nl.Size=UDim2.new(0.62,0,1,0); nl.BackgroundTransparency=1
        nl.TextColor3=Color3.fromRGB(210,210,210); nl.Font=Enum.Font.SourceSans; nl.TextSize=13
        nl.TextXAlignment=Enum.TextXAlignment.Left; nl.Text="  "..p.Name; nl.Parent=row
        local tp=Instance.new("TextButton"); tp.Size=UDim2.new(0,55,0,22); tp.Position=UDim2.new(1,-59,0.5,-11)
        tp.BackgroundColor3=Color3.fromRGB(0,120,200); tp.BorderSizePixel=0; tp.TextColor3=Color3.fromRGB(255,255,255)
        tp.Font=Enum.Font.SourceSansBold; tp.TextSize=12; tp.Text="TP"; tp.Parent=row
        tp.MouseButton1Click:Connect(function()
            local root=p.Character and p.Character:FindFirstChild("HumanoidRootPart")
            if root and hrp then
                hrp.CFrame=root.CFrame+Vector3.new(0,2,0); hrp.AssemblyLinearVelocity=Vector3.zero
                Notify({Title="TP", Text="->"..p.Name, Duration=2})
            end
        end)
    end
    scroll.CanvasSize=UDim2.new(0,0,0,layout.AbsoluteContentSize.Y+8)
    gui.Parent=Services.CoreGui; playerListGui=gui
end

-- ─── Chat Spy ────────────────────────────────────────────────────────────────

local function StartChatSpy()
    if chatSpyGui then return end
    local gui=Instance.new("ScreenGui"); gui.Name="ReznovChatSpy"; gui.ResetOnSpawn=false
    local frame=Instance.new("Frame"); frame.Size=UDim2.new(0,340,0,220); frame.Position=UDim2.new(0,10,0.5,-110)
    frame.BackgroundColor3=Color3.fromRGB(16,16,16); frame.BackgroundTransparency=0.15; frame.BorderSizePixel=0
    local title=Instance.new("TextLabel"); title.Size=UDim2.new(1,0,0,24); title.BackgroundColor3=Color3.fromRGB(28,28,28)
    title.BorderSizePixel=0; title.TextColor3=Color3.fromRGB(255,255,255); title.Font=Enum.Font.SourceSansBold; title.TextSize=13; title.Text="Chat Spy"; title.Parent=frame
    local scroll=Instance.new("ScrollingFrame"); scroll.Size=UDim2.new(1,-8,1,-32); scroll.Position=UDim2.new(0,4,0,28)
    scroll.BackgroundTransparency=1; scroll.BorderSizePixel=0; scroll.ScrollBarThickness=5; scroll.ScrollingDirection=Enum.ScrollingDirection.Y; scroll.Parent=frame
    local layout=Instance.new("UIListLayout"); layout.Padding=UDim.new(0,2); layout.Parent=scroll
    frame.Parent=gui; gui.Parent=Services.CoreGui; chatSpyGui=gui

    local function addMsg(sender, msg)
        local l=Instance.new("TextLabel"); l.Size=UDim2.new(1,-8,0,0); l.AutomaticSize=Enum.AutomaticSize.Y
        l.BackgroundTransparency=1; l.TextColor3=Color3.fromRGB(200,200,200); l.Font=Enum.Font.SourceSans
        l.TextSize=12; l.TextWrapped=true; l.TextXAlignment=Enum.TextXAlignment.Left; l.RichText=true
        l.Text=string.format('<font color="rgb(100,180,255)">%s</font>: %s',sender,msg); l.Parent=scroll
        scroll.CanvasSize=UDim2.new(0,0,0,layout.AbsoluteContentSize.Y+8)
        scroll.CanvasPosition=Vector2.new(0,math.max(0,layout.AbsoluteContentSize.Y-scroll.AbsoluteSize.Y+8))
    end

    for _, p in pairs(Services.Players:GetPlayers()) do
        gc(p.Chatted:Connect(function(m) addMsg(p.Name,m) end))
    end
    gc(Services.Players.PlayerAdded:Connect(function(p)
        gc(p.Chatted:Connect(function(m) addMsg(p.Name,m) end))
    end))
end

local function StopChatSpy()
    if chatSpyGui then pcall(function() chatSpyGui:Destroy() end); chatSpyGui=nil end
end

-- ─── Misc ────────────────────────────────────────────────────────────────────

local function ToggleClickTP(enabled)
    state.clickTPEnabled = enabled
    if enabled then
        gc(Services.UIS.InputBegan:Connect(function(i, gp)
            if gp then return end
            if i.UserInputType==Enum.UserInputType.MouseButton1 then
                if Services.UIS:IsKeyDown(Enum.KeyCode.LeftControl) or Services.UIS:IsKeyDown(Enum.KeyCode.RightControl) then
                    TeleportToMouse()
                end
            end
        end))
    end
end

local function ToggleAntiAFK(enabled)
    state.afkActive = enabled
    if enabled then
        gc(Services.RunService.Heartbeat:Connect(function()
            if not state.afkActive then return end
            Services.VirtualUser:CaptureController()
            Services.VirtualUser:ClickButton2(Vector2.new())
        end))
    end
end

local function ServerHop()
    local ok, data = pcall(function()
        return Services.HttpService:JSONDecode(game:HttpGetAsync('https://games.roblox.com/v1/games/'..game.PlaceId..'/servers/Public?sortOrder=Asc&limit=100'))
    end)
    if not ok or not data or not data.data then Notify({Title="Server Hop",Text="Failed",Duration=2}) return end
    for _, s in pairs(data.data) do
        if s.id~=game.JobId and s.playing<s.maxPlayers then
            Services.TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id); return
        end
    end
    Notify({Title="Server Hop", Text="No servers found", Duration=2})
end

local function RejoinSameServer()
    Services.TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId)
end

local function ToggleAutoRejoin(enabled)
    state.autoRejoin = enabled
    if enabled then
        pcall(function()
            gc(Services.CoreGui.RobloxPromptGui.promptOverlay.ChildAdded:Connect(function(child)
                if child.Name=="ErrorPrompt" then task.wait(1); Services.TeleportService:Teleport(game.PlaceId) end
            end))
        end)
    end
end

local function RemoveTextures()
    for _, o in ipairs(workspace:GetDescendants()) do
        if o:IsA("Texture") or o:IsA("Decal") then o.Transparency=1 end
    end
end

local function RemoveParticles()
    for _, o in ipairs(workspace:GetDescendants()) do
        if o:IsA("ParticleEmitter") or o:IsA("Trail") or o:IsA("Smoke") or o:IsA("Fire") or o:IsA("Sparkles") then
            o.Enabled=false
        end
    end
end

local function ApplyFPSBoost()
    settings().Rendering.QualityLevel=Enum.QualityLevel.Level01
    for _, v in pairs(workspace:GetDescendants()) do
        if v:IsA("Part") or v:IsA("MeshPart") or v:IsA("UnionOperation") then v.Material=Enum.Material.SmoothPlastic; v.Reflectance=0
        elseif v:IsA("Decal") or v:IsA("Texture") then v.Transparency=1
        elseif v:IsA("ParticleEmitter") or v:IsA("Trail") then v.Enabled=false end
    end
    Services.Lighting.GlobalShadows=false; Services.Lighting.FogEnd=9e9
end

-- ─── Unload ───────────────────────────────────────────────────────────────────
-- Kills every trace: connections, loops, Drawing objects, ScreenGuis,
-- workspace parts, lighting state. Nothing survives.

local function Unload()
    state.unloaded = true

    -- stop all loops by setting flags false first so spawned loops exit cleanly
    state.flying=false; state.tpWalk=false; state.infJump=false; state.speedBypass=false
    state.noclipEnabled=false; state.aimbotEnabled=false; state.aimbotActive=false
    state.afkActive=false; state.fpsEnabled=false; state.coordsEnabled=false
    state.velocityEnabled=false; state.crosshairEnabled=false; state.hudEnabled=false
    state.weatherActive=nil; state.spinEnabled=false; state.nametagsEnabled=false
    state.gameInfoEnabled=false; state.timeOfDayEnabled=false

    -- disconnect everything
    killTable(connections)
    killTable(noclipConns)
    killTable(hudConns)
    killTable(nametagConns)

    if state.spinConn then pcall(function() state.spinConn:Disconnect() end); state.spinConn=nil end

    -- FIX: restore lighting BEFORE state booleans are zeroed (was broken before — checked already-false flags)
    if next(savedLighting)~=nil then ToggleFullbright(false) end
    if config.savedFOV then camera.FieldOfView=config.savedFOV; config.savedFOV=nil end
    if state.noFogEnabled then ToggleNoFog(false) end
    if savedSky then ApplySkybox("Default") end
    ClearWeather(); RestoreAtmosphere()
    Services.Lighting.FogEnd=100000; Services.Lighting.FogStart=0

    -- destroy fly physics
    if bg then pcall(function() bg:Destroy() end); bg=nil end
    if bv then pcall(function() bv:Destroy() end); bv=nil end
    pcall(function() if hum then hum.PlatformStand=false; hum.WalkSpeed=16 end end)

    -- destroy workspace parts
    if platformPart then pcall(function() platformPart:Destroy() end); platformPart=nil end
    ClearNametags()

    -- destroy IY ESP
    espDestroyAll()

    -- remove all Drawing objects (aimbotCircle, crosshairDrawing, any others)
    for _, d in ipairs(drawingObjects) do pcall(function() d:Remove() end) end
    table.clear(drawingObjects)
    aimbotCircle=nil; crosshairDrawing=nil

    -- destroy every ScreenGui we created
    local guis = {
        crosshairGui,
        coordsLabel   and coordsLabel.Parent,
        velocityLabel and velocityLabel.Parent,
        fpsLabel      and fpsLabel.Parent,
        hudGui,
        gameInfoGui,
        playerListGui,
        chatSpyGui,
    }
    for _, g in ipairs(guis) do
        if g then pcall(function() g:Destroy() end) end
    end
    crosshairGui=nil; coordsLabel=nil; velocityLabel=nil; fpsLabel=nil
    hudGui=nil; hudFrame=nil; gameInfoGui=nil; playerListGui=nil; chatSpyGui=nil

    Notify({Title="Reznov Hub", Text="Unloaded", Duration=2})
    task.wait(0.05)
    if Library then pcall(function() Library:Unload() end) end
end

espInit()

-- ─── UI ──────────────────────────────────────────────────────────────────────

local Tabs = {
    Player   = Window:AddTab('Player'),
    Combat   = Window:AddTab('Combat'),
    ESP      = Window:AddTab('ESP'),
    Visual   = Window:AddTab('Visual'),
    Misc     = Window:AddTab('Misc'),
    Settings = Window:AddTab('Settings'),
}

-- Player Tab
local PM = Tabs.Player:AddLeftGroupbox('Movement')
PM:AddToggle('NoClip',      {Text='No-Clip',       Default=false, Callback=function(v) ToggleNoClip(v) end})
PM:AddSlider('NoClipSpd',   {Text='No-Clip Speed', Min=0.1,Max=2,    Default=0.5,  Rounding=1, Callback=function(v) config.noclipSpeed=v end})
PM:AddToggle('Fly',         {Text='Fly',           Default=false, Callback=function(v) state.flying=v if v then task.spawn(FlyLoop) end end})
PM:AddSlider('FlySpd',      {Text='Fly Speed',     Min=25, Max=1500, Default=75,   Rounding=0, Callback=function(v) config.flySpeed=v end})
PM:AddToggle('TPWalk',      {Text='TP Walk',       Default=false, Callback=function(v) state.tpWalk=v if v then task.spawn(TPWalkLoop) end end})
PM:AddSlider('TPSpd',       {Text='TP Walk Speed', Min=0.5,Max=10,   Default=2,    Rounding=1, Callback=function(v) config.tpSpeed=v end})
PM:AddToggle('SpeedBypass', {Text='Speed Bypass',  Default=false, Callback=function(v) state.speedBypass=v if v then task.spawn(SpeedLoop) end end})
PM:AddSlider('WalkSpd',     {Text='Walk Speed',    Min=16, Max=500,  Default=16,   Rounding=0, Callback=function(v) config.walkSpeed=v end})
PM:AddToggle('InfJump',     {Text='Infinite Jump', Default=false, Callback=function(v) state.infJump=v if v then task.spawn(InfiniteJumpLoop) end end})

local PC = Tabs.Player:AddRightGroupbox('Character Mods')
PC:AddSlider('JumpPow', {Text='Jump Power', Min=50,  Max=500, Default=50,    Rounding=0, Callback=function(v) config.jumpPower=v if hum then hum.JumpPower=v end end})
PC:AddSlider('Gravity',  {Text='Gravity',   Min=0,   Max=400, Default=196.2, Rounding=1, Callback=function(v) config.gravity=v workspace.Gravity=v end})
PC:AddSlider('HipHgt',   {Text='Hip Height',Min=0,   Max=20,  Default=2,     Rounding=1, Callback=function(v) config.hipHeight=v if hum then hum.HipHeight=v end end})
PC:AddSlider('SwimSpd',  {Text='Swim Speed',Min=16,  Max=300, Default=16,    Rounding=0, Callback=function(v) config.swimSpeed=v end})

local PK = Tabs.Player:AddLeftGroupbox('Keybinds')
PK:AddLabel('Fly Key'):AddKeyPicker('FlyKey',   {Default='None',NoDefault=true,Mode='Toggle',Text='Fly',Callback=function() state.flying=not state.flying if state.flying then task.spawn(FlyLoop) end end})
PK:AddLabel('No-Clip Key'):AddKeyPicker('NCKey',{Default='None',NoDefault=true,Mode='Toggle',Text='No-Clip',Callback=function() ToggleNoClip(not state.noclipEnabled) end})
PK:AddLabel('TP Mouse'):AddKeyPicker('TPKey',   {Default='None',NoDefault=true,SyncToggleState=false,Text='TP Mouse',Callback=function() TeleportToMouse() end})

-- Combat Tab
local AB = Tabs.Combat:AddLeftGroupbox('Aimbot')
AB:AddToggle('Aimbot',      {Text='Enable Aimbot', Default=false, Callback=function(v) ToggleAimbot(v) end})
AB:AddLabel('Pause Key'):AddKeyPicker('AimbotKey',{Default='None',NoDefault=true,Mode='Toggle',Text='Pause Aim',Callback=function()
    state.aimbotActive = not state.aimbotActive
    Notify({Title="Aimbot", Text=state.aimbotActive and "Resumed" or "Paused", Duration=1})
end})
AB:AddToggle('AimbotFOVShow',{Text='Show FOV Circle',Default=true, Callback=function(v) config.aimbotShowFOV=v if aimbotCircle then aimbotCircle.Visible=v and state.aimbotEnabled end end})
AB:AddSlider('AimbotFOV',    {Text='FOV',      Min=50,  Max=500, Default=200,  Rounding=0, Callback=function(v) config.aimbotFOV=v end})
AB:AddSlider('AimbotSmooth', {Text='Smoothing',Min=1,   Max=20,  Default=5,    Rounding=1, Callback=function(v) config.aimbotSmoothing=v end})
AB:AddDropdown('AimbotPart', {Values={'Head','Torso','HumanoidRootPart','UpperTorso','LowerTorso'},Default=1,Multi=false,Text='Target Part',Callback=function(v) config.aimbotPart=v end})

local AS = Tabs.Combat:AddRightGroupbox('Aimbot Settings')
AS:AddToggle('AimbotVis',   {Text='Visible Check',  Default=true,  Callback=function(v) config.aimbotVisibleOnly=v end})
AS:AddToggle('AimbotTeam',  {Text='Team Check',     Default=true,  Callback=function(v) config.aimbotTeamCheck=v end})
AS:AddToggle('AimbotDead',  {Text='Alive Check',    Default=true,  Callback=function(v) config.aimbotDeadCheck=v end})
AS:AddToggle('AimbotPred',  {Text='Prediction',     Default=false, Callback=function(v) config.aimbotPrediction=v end})
AS:AddSlider('AimbotPredAmt',{Text='Pred Amount',   Min=0.01,Max=0.5,Default=0.15,Rounding=2,Callback=function(v) config.aimbotPredictionAmount=v end})
AS:AddToggle('AimbotSticky',{Text='Sticky Target',  Default=false, Callback=function(v) config.aimbotSticky=v end})
AS:AddSlider('AimbotDelay', {Text='Switch Delay (s)',Min=0,Max=2,  Default=0.5, Rounding=1, Callback=function(v) config.aimbotSwitchDelay=v end})

local TW = Tabs.Combat:AddLeftGroupbox('Team Whitelist')
TW:AddInput('AddTeam',{Default='',Numeric=false,Finished=true,Text='Add Team',Placeholder='Team Name',Callback=function(v)
    if v~='' then table.insert(config.teamWhitelist,v); Notify({Title="Whitelist",Text="Added: "..v,Duration=2}) end
end})
TW:AddButton('Clear Whitelist',function() config.teamWhitelist={}; Notify({Title="Whitelist",Text="Cleared",Duration=2}) end)

-- ESP Tab
local ET = Tabs.ESP:AddLeftGroupbox('ESP Types')
ET:AddToggle('BoxESP',    {Text='Box',             Default=false, Callback=function(v) SetEsp("Box",v) end})
ET:AddToggle('NameESP',   {Text='Name',            Default=false, Callback=function(v) SetEsp("Name",v) end})
ET:AddToggle('HealthESP', {Text='Health Bar',      Default=false, Callback=function(v) SetEsp("Health",v) end})
ET:AddToggle('TracerESP', {Text='Tracers',         Default=false, Callback=function(v) SetEsp("Tracer",v) end})
ET:AddToggle('ChamsESP',  {Text='Chams',           Default=false, Callback=function(v) SetEsp("Chams",v) end})
ET:AddToggle('Nametags',  {Text='Nametag Override',Default=false, Callback=function(v) ToggleNametags(v) end})

local ES = Tabs.ESP:AddRightGroupbox('ESP Settings')
ES:AddSlider('ESPDist', {Text='Distance', Min=100, Max=5000, Default=1000, Rounding=0, Callback=function(v)
    config.espDistance = v
end})
ES:AddToggle('ESPTeam', {Text='Team Check', Default=false, Callback=function(v)
    config.espTeamCheck = v
end})
ES:AddDropdown('ESPNameMode', {
    Text   = 'Name Display',
    Values = {'Both', 'Display', 'Username'},
    Default = 1,
    Multi  = false,
    Callback = function(v) config.espNameMode = v end,
})
ES:AddLabel('Box Color'):AddColorPicker('ESPBoxColor', {Default=Color3.fromRGB(255,50,50), Callback=function(v)
    config.espBoxColor = v
end})
ES:AddLabel('Name Color'):AddColorPicker('ESPNameColor', {Default=Color3.fromRGB(255,255,255), Callback=function(v)
    config.espNameColor = v
end})
ES:AddLabel('Tracer Color'):AddColorPicker('ESPTracerColor', {Default=Color3.fromRGB(255,50,50), Callback=function(v)
    config.espTracerColor = v
end})
ES:AddLabel('Chams Color'):AddColorPicker('ESPChamsColor', {Default=Color3.fromRGB(255,50,50), Callback=function(v)
    config.espChamsColor = v
    espUpdateChamsColor()
end})
ES:AddSlider('ESPChamsAlpha', {Text='Chams Opacity', Min=0, Max=1, Default=0.6, Rounding=2, Callback=function(v)
    config.espChamsAlpha = v
    espUpdateChamsColor()
end})

-- Visual Tab
local VL = Tabs.Visual:AddLeftGroupbox('Lighting')
VL:AddToggle('Fullbright',  {Text='Fullbright',        Default=false, Callback=function(v) ToggleFullbright(v) end})
VL:AddToggle('NoFog',       {Text='No Fog',            Default=false, Callback=function(v) ToggleNoFog(v) end})
VL:AddToggle('FOVChanger',  {Text='FOV Changer',       Default=false, Callback=function(v) SetFOV(v,config.fov) end})
VL:AddSlider('FOVValue',    {Text='FOV',               Min=1,Max=120, Default=70, Rounding=0, Callback=function(v) config.fov=v if state.fovEnabled then camera.FieldOfView=v end end})
VL:AddToggle('TimeOfDay',   {Text='Lock Time of Day',  Default=false, Callback=function(v) ToggleTimeOfDay(v) end})
VL:AddSlider('TimeSlider',  {Text='Time (0 - 24)',     Min=0,Max=24,  Default=14, Rounding=1, Callback=function(v)
    config.timeOfDay=v; if state.timeOfDayEnabled then Services.Lighting.ClockTime=v end
end})

local VA = Tabs.Visual:AddRightGroupbox('Atmosphere')
VA:AddSlider('AtmoDensity',{Text='Density',Min=0,  Max=1,  Default=0.395,Rounding=3,Callback=function(v) config.atmosphereDensity=v ApplyAtmosphereConfig() end})
VA:AddSlider('AtmoHaze',   {Text='Haze',   Min=0,  Max=10, Default=0,    Rounding=1,Callback=function(v) config.atmosphereHaze=v    ApplyAtmosphereConfig() end})
VA:AddSlider('AtmoGlare',  {Text='Glare',  Min=0,  Max=1,  Default=0,    Rounding=2,Callback=function(v) config.atmosphereGlare=v   ApplyAtmosphereConfig() end})
VA:AddLabel('Color'):AddColorPicker('AtmoColor',{Default=Color3.fromRGB(199,170,140),Callback=function(v) config.atmosphereColor=v ApplyAtmosphereConfig() end})
VA:AddLabel('Decay'):AddColorPicker('AtmoDecay',{Default=Color3.fromRGB(106,127,189),Callback=function(v) config.atmosphereDecay=v ApplyAtmosphereConfig() end})

local VW = Tabs.Visual:AddLeftGroupbox('Weather')
VW:AddButton('Rain',function() if state.weatherActive=="Rain" then StopWeather() else CreateWeather("Rain") end end)
VW:AddButton('Snow',function() if state.weatherActive=="Snow" then StopWeather() else CreateWeather("Snow") end end)
VW:AddButton('Fog', function() if state.weatherActive=="Fog"  then StopWeather() else CreateWeather("Fog")  end end)
VW:AddButton('Clear Weather', function() StopWeather() end)

local VSB = Tabs.Visual:AddRightGroupbox('Skybox')
VSB:AddDropdown('SkyboxPreset',{Values={'Default','Bluesky','Night Stars','Sunset','Space'},Default=1,Multi=false,Text='Skybox Preset',Callback=function(v) ApplySkybox(v) end})

local VUI = Tabs.Visual:AddLeftGroupbox('UI Elements')
VUI:AddToggle('FPSCounter',  {Text='FPS Counter',         Default=false, Callback=function(v) ToggleFPSCounter(v) end})
VUI:AddToggle('Coordinates', {Text='Coordinates',         Default=false, Callback=function(v) ToggleCoordinates(v) end})
VUI:AddToggle('Velocity',    {Text='Velocity Display',    Default=false, Callback=function(v) ToggleVelocity(v) end})
VUI:AddToggle('HUDToggle',   {Text='Active Toggles HUD',  Default=false, Callback=function(v) ToggleHUD(v) end})
VUI:AddToggle('GameInfo',    {Text='Game Info Panel',      Default=false, Callback=function(v) ToggleGameInfo(v) end})

local VC = Tabs.Visual:AddRightGroupbox('Crosshair')
VC:AddToggle('Crosshair',     {Text='Enable',    Default=false, Callback=function(v) ToggleCrosshair(v) end})
VC:AddDropdown('CrossStyle',  {Values={'Cross','Dot','Circle'},Default=1,Multi=false,Text='Style',Callback=function(v)
    config.crosshairStyle=v; if state.crosshairEnabled then BuildCrosshair() end
end})
VC:AddSlider('CrossSize',  {Text='Size',     Min=4, Max=40,Default=12,Rounding=0,Callback=function(v) config.crosshairSize=v      if state.crosshairEnabled then BuildCrosshair() end end})
VC:AddSlider('CrossThick', {Text='Thickness',Min=1, Max=6, Default=2, Rounding=0,Callback=function(v) config.crosshairThickness=v if state.crosshairEnabled then BuildCrosshair() end end})
VC:AddSlider('CrossGap',   {Text='Gap',      Min=0, Max=12,Default=4, Rounding=0,Callback=function(v) config.crosshairGap=v       if state.crosshairEnabled then BuildCrosshair() end end})
VC:AddLabel('Color'):AddColorPicker('CrossColor',{Default=Color3.fromRGB(0,255,0),Callback=function(v) config.crosshairColor=v if state.crosshairEnabled then BuildCrosshair() end end})

local VWo = Tabs.Visual:AddLeftGroupbox('World')
VWo:AddButton('Remove Textures',  function() RemoveTextures()  Notify({Title="World",Text="Textures removed", Duration=2}) end)
VWo:AddButton('Remove Particles', function() RemoveParticles() Notify({Title="World",Text="Particles removed",Duration=2}) end)
VWo:AddButton('FPS Boost',        function() ApplyFPSBoost()   Notify({Title="World",Text="FPS boost applied",Duration=2}) end)

-- Misc Tab
local MU = Tabs.Misc:AddLeftGroupbox('Utilities')
MU:AddToggle('AntiAFK',    {Text='Anti-AFK',            Default=false, Callback=function(v) ToggleAntiAFK(v) end})
MU:AddToggle('AutoRejoin', {Text='Auto Rejoin on Kick', Default=false, Callback=function(v) ToggleAutoRejoin(v) end})
MU:AddButton('Server Hop',        function() ServerHop() end)
MU:AddButton('Rejoin Same Server',function() RejoinSameServer() end)
MU:AddToggle('ClickTP', {Text='Click TP (Ctrl+Click)', Default=false, Callback=function(v) ToggleClickTP(v) end})
MU:AddButton('Copy Coords', function()
    if hrp then
        local p=hrp.Position; local s=string.format("%.2f, %.2f, %.2f",p.X,p.Y,p.Z)
        pcall(function() setclipboard(s) end); Notify({Title="Clipboard",Text=s,Duration=3})
    end
end)
MU:AddButton('Player List', function() OpenPlayerList() end)
MU:AddToggle('ChatSpy', {Text='Chat Spy', Default=false, Callback=function(v)
    if v then StartChatSpy() else StopChatSpy() end
end})

local MF = Tabs.Misc:AddRightGroupbox('Fun')
MF:AddToggle('Platform',  {Text='Platform', Default=false, Callback=function(v) TogglePlatform(v) end})
MF:AddSlider('PlatSize',  {Text='Platform Size', Min=4,  Max=20, Default=8,  Rounding=0, Callback=function(v) config.platformSize=v if platformPart then platformPart.Size=Vector3.new(v,0.5,v) end end})
MF:AddSlider('PlatOffset',{Text='Y Offset',      Min=-10,Max=10, Default=0,  Rounding=1, Callback=function(v) config.platformYOffset=v end})
MF:AddToggle('Spin',      {Text='Spin Bot',       Default=false, Callback=function(v) ToggleSpin(v) end})
MF:AddSlider('SpinSpd',   {Text='Spin Speed',     Min=1,  Max=100,Default=20, Rounding=0, Callback=function(v) config.spinSpeed=v end})

-- Settings Tab
local FS = Tabs.Settings:AddLeftGroupbox('Friends & Ignore')
FS:AddInput('AddFriend',{Default='',Numeric=true,Finished=true,Text='Add Friend (UserID)',Placeholder='UserID',Callback=function(v)
    local uid=tonumber(v); if uid then table.insert(config.friendList,uid); Notify({Title="Friends",Text="Added "..uid,Duration=2}) end
end})
FS:AddButton('Clear Friends',function() config.friendList={}; Notify({Title="Friends",Text="Cleared",Duration=2}) end)
FS:AddInput('AddIgnore',{Default='',Numeric=true,Finished=true,Text='Add Ignore (UserID)',Placeholder='UserID',Callback=function(v)
    local uid=tonumber(v); if uid then table.insert(config.ignoreList,uid); Notify({Title="Ignore",Text="Added "..uid,Duration=2}) end
end})
FS:AddButton('Clear Ignore',function() config.ignoreList={}; Notify({Title="Ignore",Text="Cleared",Duration=2}) end)

local SS = Tabs.Settings:AddRightGroupbox('Script')
SS:AddButton('Unload Script', function() Unload() end)

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:SetFolder('ReznovHub')
SaveManager:BuildConfigSection(Tabs.Settings)
ThemeManager:ApplyToTab(Tabs.Settings)

Library:OnUnload(function() Unload() end)

Notify({Title="Reznov Hub", Text="v1.2 loaded", Duration=3})
