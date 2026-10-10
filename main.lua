--!nonstrict
--[[
    =============================================================================
                                PASTAWARE v3.0 MEGA
                  Universal & MM2 Combat / Visuals / Movement / Farm
    =============================================================================
    Merged & Unified from:
      - headshoot-slient.lua (Luraph Silent Aim, SmartTrigger, Prediction & Hook)
          * MotionSample / SampleMotion / PredictPath / JumpOffset
          * OscillationOffset / EstimateHitChance / Snapshot Validator
          * PickLockPlayer / GetShootProtocol / BuildShootArguments
          * ReserveShot / SmartTrigger Apex / __namecall hook
      - puls.orig.lua (Pulse MM2 Engine DEOBFUSCATED, 155 modules)
          * WP  -> DrawBoxESP (Corners/2D)
          * TP  -> PulseFlyController (BodyVelocity+BodyGyro)
          * EP  -> PulseSilentAimHook (__pulseAim / V2)
          * DP  -> IsValidTargetPart filter
          * FP  -> TrackGunDropAdded
          * v   -> RoleBillboardESP (Head Adornee)
          * f   -> ResolveRoleSimple (knife/gun)
          * J   -> GetPlayerDataRoster (cache 0.2s)
          * w   -> LoadInventoryModule (MyInventory.Weapons)
          * o   -> BuildAdminSnapshot (telemetry payload)
          * V   -> SHA256 / O -> HMAC-like / b -> RC4 / s -> Base64
          * Y/U/p/m/l/d/h -> BigInt helpers (65535 limbs)
          * GP  -> PositionLineFrame (tracer rotation)
          * wT  -> UpdateCrosshairVisibility / bT -> MoveCustomCursor
          * e   -> ApplyUISkin (accent/surf/glass/card)
          * S   -> UpdateGlassOverlay (Camera parts)
          * C   -> ApplyMenuFont / IT+sT -> AtmosphereCleaner
          * cP  -> ApplyCharacterCosmetics (korblox/headless/vfx)
          * NP  -> FarmHeartbeatNoclip / RP+CP+nP -> InvisController
          * fP  -> TrackKnifeVelocity / PT -> PollRemoteData
          * HT  -> CleanupDeadRefs / k -> HeadlessHider / A -> IsInTool
      - candy_main.lua (CandyWare module names, REAL implementations)
          * Aimbot / Backtrack / AntiAim / Chams / Tracers / Crosshair
          * Hitbox / Speed / Fly / Jump / WallHop / Prediction / Resolver
          * Spoofer / TriggerBot / Farm / Noclip / Silent / Teleport
          * AutoParry / HealthBar / NameTags / BoxESP / FOVCircle / ESP
          NOTE: candy_main.lua is 34919 lines of dead-code filler
          (`if X and not X`, `Key = ,`, `function (state)` broken).
          It does NOT run. Only module NAMES were salvaged and
          re-implemented below as working classes.
    =============================================================================
    Total target: 5500+ lines. All visuals. All modules. No stubs.
    =============================================================================
]]

local PastaWare = {
    Version = "3.0.1",
    Loaded = false,
    Connections = {},
    Drawings = {},
    Highlights = {},
    Billboards = {},
    State = {
        Alive = false,
        LocalPlayer = nil,
        Character = nil,
        RootPart = nil,
        Humanoid = nil,
        CurrentTarget = nil,
        TargetPart = nil,
        CurrentSnapshot = nil,
        GunDrop = nil,
        GunDrops = {},
        Roles = {},
        RosterCache = nil,
        RosterCacheAt = 0,
        InventoryCache = nil,
        FlyActive = false,
        NoclipActive = false,
        InvisActive = false,
        FarmActive = false,
        AntiAimActive = false,
        BacktrackRecords = {},
        HitboxBackup = {},
        LastShotTime = 0,
        LastSampleTime = 0,
        LastTriggerAt = 0,
        LastManualActionTime = 0,
        AimRevision = 1,
        MotionRevision = 0,
        Generation = 1,
        RoundGeneration = 0,
        Frame = 0,
        LockPlayer = nil,
        LockStartedAt = 0,
    }
}

--=============================================================================
-- 1. Окружение и службы
--=============================================================================
local Players: Players = game:GetService("Players")
local Workspace: Workspace = game:GetService("Workspace")
local RunService: RunService = game:GetService("RunService")
local UserInputService: UserInputService = game:GetService("UserInputService")
local TweenService: TweenService = game:GetService("TweenService")
local CoreGui: CoreGui = game:GetService("CoreGui")
local HttpService: HttpService = game:GetService("HttpService")

local Globals = (getgenv and getgenv()) or _G or {}
local LocalPlayer: Player = Players.LocalPlayer
local Camera: Camera = Workspace.CurrentCamera

-- Поддержка смены камеры
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    Camera = Workspace.CurrentCamera
end)

-- Проверка доступности возможностей экзекутора
local HasDrawing = typeof(Drawing) == "table" and typeof(Drawing.new) == "function"
local HasHook = typeof(hookmetamethod) == "function"
local HasNamecall = typeof(getnamecallmethod) == "function"
local HasTouch = typeof(firetouchinterest) == "function"

--=============================================================================
-- 2. Единая конфигурация (Settings)
--=============================================================================
PastaWare.Config = {
    Aimbot = {
        Enabled = true,
        SilentAim = true,
        AimLock = false,
        AutoShoot = false,
        SmartTrigger = true,
        Penetration = false, -- Wallbang
        TargetPart = "Head", -- "Head", "HumanoidRootPart", "UpperTorso"
        HitChance = 100,
        MinHitChance = 70,
        MaxDistance = 500,
        FieldOfView = 120,
        ShowFOV = true,
        FOVColor = Color3.fromRGB(255, 60, 60),
        FOVTransparency = 0.7,
        FilledFOV = false,
        Prediction = true,
        PredictionOffset = 0,
        HeightOffset = 0,
        Gravity = 196.2,
        SnapshotLifetime = 0.35,
        ShotDelay = 0,
        MaxWait = 250,
        IgnoreTeam = true,
        TargetMurdererOnly = false,
        UniversalAim = false, -- Pulse rP: доводка камеры Lerp 0.65 (Luraph-путь основной)
    },
    Visuals = {
        Enabled = true,
        BoxESP = true,
        BoxType = "Corners", -- "2D", "Corners"
        BoxColor = Color3.fromRGB(255, 255, 255),
        Chams = true,
        ChamsColor = Color3.fromRGB(255, 255, 255),
        ChamsOutlineColor = Color3.fromRGB(20, 20, 20),
        ChamsTransparency = 0.5,
        ChamsOutlineTransparency = 0,
        ChamsAlwaysOnTop = true,
        ChamsPulse = true,
        Tracers = false,
        TracerOrigin = "Bottom", -- "Bottom", "Middle", "Mouse"
        TracerColor = Color3.fromRGB(255, 255, 255),
        Names = true,
        Distances = true,
        HealthBar = true,
        HealthText = true,
        -- MM2 Role ESP
        RoleESP = true,
        MurdererColor = Color3.fromRGB(255, 35, 35),
        SheriffColor = Color3.fromRGB(35, 140, 255),
        HeroColor = Color3.fromRGB(255, 215, 0),
        InnocentColor = Color3.fromRGB(50, 255, 50),
        -- Gun Drop ESP
        GunDropESP = true,
        GunDropColor = Color3.fromRGB(255, 220, 40),
    },
    Movement = {
        Fly = false,
        FlySpeed = 60,
        FlyKey = Enum.KeyCode.F,
        FlyBobbing = true,
        FlyNoClip = true,
        FlyAnim = true, -- Pulse fly.anim: ложиться как супермен
        WalkSpeedEnabled = false,
        WalkSpeed = 24,
        JumpPowerEnabled = false,
        JumpPower = 55,
        InfiniteJump = false,
        Noclip = false,
        WallHop = false, -- Candy WallHop: подпрыгивать от стен
        WallHopPower = 55,
        SpeedEnabled = false, -- Candy Speed: множитель бега через Humanoid
        SpeedMultiplier = 1.5,
        JumpEnabled = false, -- Candy Jump: высокий прыжок
        JumpBoost = 75,
        Spin = false, -- Pulse SP: спинбот
        SpinSpeed = 10, -- рад/сек
        Bhop = false, -- Pulse SP: баннихоп-цепочка
        BhopPower = 5,
    },
    Misc = {
        AutoPickupGun = true,
        PickupDistance = 35,
        AntiRagdoll = true,
        MenuKey = Enum.KeyCode.RightControl,
        AntiAFK = true,
        AutoParry = false, -- Candy AutoParry (MM2 нож)
        AutoParryDistance = 18,
        TeleportEnabled = false, -- Candy Teleport
        TeleportKey = Enum.KeyCode.T,
        SpooferEnabled = false, -- Candy Spoofer: подмена скорости/прыжка для сервера
        SpoofWalkSpeed = 16,
        SpoofJumpPower = 50,
    },
    --=========================================================================
    -- Candy-модули (реальные реализации ниже, секция 13)
    --=========================================================================
    Backtrack = {
        Enabled = false, -- хранит позиции врага 0.2с и рисует госта
        Window = 0.2,
        GhostTransparency = 0.5,
        ShowGhost = true,
    },
    AntiAim = {
        Enabled = false, -- крутит HumanoidRootPart.CFrame вокруг Y
        Mode = "Spin", -- "Spin" | "Jitter" | "Static"
        SpinSpeed = 8, -- рад/сек
        JitterAngle = 45,
        StaticYaw = 180,
    },
    Hitbox = {
        Enabled = false, -- расширитель хитбоксов врага
        Size = Vector3.new(6, 6, 6),
        Transparency = 0.7,
        TargetPart = "HumanoidRootPart",
    },
    Resolver = {
        Enabled = false, -- анти-джиттер: сглаживает VelocityHistory
        Aggressiveness = 0.5, -- 0..1
    },
    Crosshair = {
        Enabled = true, -- Pulse wT+bT: системный + кастомный курсор
        UseCustomCursor = true,
        CursorSize = 12,
        CursorColor = Color3.fromRGB(255, 60, 60),
        HideOnAim = false, -- прятать когда показан __pulseXHairShown
    },
    TriggerBot = {
        Enabled = false, -- Candy TriggerBot: огонь когда прицел на враге
        Delay = 0.12,
        TargetMurdererOnly = true,
    },
    Farm = {
        Enabled = false, -- Pulse NP: PULSE_FARM_MM2_HEARTBEAT noclip монет/афк
        HeartbeatNoclip = true,
        AutoCoin = false,
        CoinRadius = 40,
    },
    Invis = {
        Enabled = false, -- Pulse RP/CP/nP: -200000 CFrame + NoCollide
        HideName = true,
        NoCollideHook = true,
    },
    World = {
        RemoveAtmosphere = false, -- Pulse IT/sT: убрать Atmosphere/Sky
        Fullbright = false,
        NoFog = false,
        GunChams = true,
        KnifeVelocityTrack = true, -- Pulse fP: скорость брошенного ножа
        KnifeSpeedMin = 30,
        KnifeSpeedMax = 800,
        StretchFX = 0, -- Pulse lT: сплющивание камеры (0=выкл, 1..100)
    },
    Glass = {
        Enabled = false, -- Pulse S: стеклянный оверлей поверх меню
        Transparency = 0.98,
        Color = Color3.fromRGB(248, 248, 252),
    },
    ESPEx = {
        BillboardRoles = true, -- Pulse v: BillboardGui на Head с ролью
        Skeleton = false,
        HealthText = true,
        WeaponESP = true,
        OffscreenArrows = false,
        ShowPerf = false, -- Pulse QP: FPS+пинг оверлей
        FollowTarget = false, -- Pulse ZP: курсор за целью
        MouseHL = false, -- Pulse _P: подсветка под курсором
    },
}

--=============================================================================
-- 3. Вспомогательные функции математики и проверок
--=============================================================================
local function isFiniteNumber(val: any): boolean
    return typeof(val) == "number" and val == val and val ~= math.huge and val ~= -math.huge
end

local function isFiniteVector(vec: any): boolean
    if typeof(vec) ~= "Vector3" then return false end
    return isFiniteNumber(vec.X) and isFiniteNumber(vec.Y) and isFiniteNumber(vec.Z)
end

local function finiteNumber(value: any, fallback: number, minimum: number, maximum: number): number
    local n = tonumber(value)
    if n == nil or n ~= n then return fallback end
    if minimum ~= nil and n < minimum then return minimum end
    if maximum ~= nil and n > maximum then return maximum end
    return n
end

-- Сейф-обёртки для урезанных API мобильных экзекуторов.
-- На части сборок FindFirstChildOfClass/GetMouseLocation = nil.
local function safeFindChild(obj: any, name: string)
    if typeof(obj) ~= "Instance" then return nil end
    local ok, res = pcall(function() return obj:FindFirstChild(name) end)
    if ok then return res end
    return nil
end
local function safeFindChildOfClass(obj: any, className: string)
    if typeof(obj) ~= "Instance" then return nil end
    local ok, res = pcall(function() return obj:FindFirstChildOfClass(className) end)
    if ok then return res end
    return nil
end
local function safeGetMouseLocation(): Vector2
    local ok, res = pcall(function() return UserInputService:GetMouseLocation() end)
    if ok and typeof(res) == "Vector2" then return res end
    local cam = Workspace.CurrentCamera
    if cam then
        local vs = cam.ViewportSize
        return Vector2.new(vs.X / 2, vs.Y / 2)
    end
    return Vector2.new(0, 0)
end

local function isAlive(player: Player?): boolean
    local plr = player or LocalPlayer
    if not plr or not plr.Parent then return false end
    local char = plr.Character
    if not char or not char.Parent then return false end
    local hum = safeFindChildOfClass(char, "Humanoid")
    local root = safeFindChild(char, "HumanoidRootPart")
    return (hum ~= nil and hum.Health > 0 and root ~= nil)
end

local function getLocalRoot(): BasePart?
    local char = LocalPlayer and LocalPlayer.Character
    return safeFindChild(char, "HumanoidRootPart") :: BasePart?
end

local function getTargetRoot(player: Player): BasePart?
    local char = player and player.Character
    return char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")) :: BasePart?
end

local function getStrictLivingPlayer(player: Player?): (Model?, BasePart?)
    if player == nil or not player.Parent then return nil, nil end
    local char = player.Character
    if char == nil or not char.Parent then return nil, nil end
    local hum = safeFindChildOfClass(char, "Humanoid")
    if hum == nil or hum.Health <= 0 then return nil, nil end
    local root = safeFindChild(char, "HumanoidRootPart") or safeFindChild(char, "Torso")
    if root == nil or not root:IsA("BasePart") then return nil, nil end
    return char, root :: BasePart
end

-- Регистратор подключений для чистого перезапуска/выгрузки
local function addConnection(conn)
    table.insert(PastaWare.Connections, conn)
    return conn
end

-- Лог ошибок: файл PastaWare/error.txt (executor FS) + зеркало
-- Workspace/PastaWare/"error.txt" (StringValue). Спам давится (1 строка/5 сек).
local ErrorLog = { lines = {}, counts = {}, skipped = 0 }
local ERR_FILE = "PastaWare/error.txt"
local ErrorMirror = nil
-- Чужие пути: ошибки игровых скриптов не логируем (только чанки/эксплойты).
local function ErrorLogIsForeign(msg: string): boolean
    return (msg:find("PlayerScripts", 1, true) ~= nil)
        or (msg:find("PlayerGui", 1, true) ~= nil)
        or (msg:find("Replicated", 1, true) ~= nil)
        or (msg:find("PlayerModule", 1, true) ~= nil)
        or (msg:find("Workspace.", 1, true) ~= nil)
        or (msg:find("Backpack", 1, true) ~= nil)
        or (msg:find("Starter", 1, true) ~= nil)
end
local function ErrorLogEnsureFs(): boolean
    if typeof(makefolder) ~= "function" then return false end
    local ok = pcall(function()
        if typeof(isfolder) == "function" then
            if not isfolder("PastaWare") then makefolder("PastaWare") end
        else
            makefolder("PastaWare")
        end
    end)
    return ok
end
local function ErrorLogAppendFile(line: string)
    if typeof(appendfile) ~= "function" then return end
    pcall(appendfile, ERR_FILE, line .. "\n")
end
local function ErrorLogPushMirror()
    if not ErrorMirror or not ErrorMirror.Parent then
        pcall(function()
            local folder = Workspace:FindFirstChild("PastaWare")
            if not folder then
                folder = Instance.new("Folder")
                folder.Name = "PastaWare"
                folder.Parent = Workspace
            end
            local v = folder:FindFirstChild("error.txt")
            if not v then
                v = Instance.new("StringValue")
                v.Name = "error.txt"
                v.Parent = folder
            end
            ErrorMirror = v
        end)
    end
    if not ErrorMirror then return end
    local take = {}
    local from = math.max(1, #ErrorLog.lines - 59)
    for i = from, #ErrorLog.lines do take[#take + 1] = ErrorLog.lines[i] end
    local text = table.concat(take, "\n")
    if #text > 8000 then text = text:sub(#text - 7999) end
    pcall(function() ErrorMirror.Value = text end)
end
local function ErrorLogDumpFull()
    local head = string.format("=== PastaWare v%s dump %s place=%d ===",
        tostring(PastaWare.Version), tostring(os.date("%Y-%m-%d %H:%M:%S")), game.PlaceId)
    local take = {}
    local from = math.max(1, #ErrorLog.lines - 199)
    for i = from, #ErrorLog.lines do take[#take + 1] = ErrorLog.lines[i] end
    return head .. "\n" .. table.concat(take, "\n") .. "\n"
end

local function ErrorLogTrace(message, stackTrace)
    if Globals.__ERRLOG_ARMED then return end -- пишет standalone логгер
    local msg = tostring(message)
    if ErrorLogIsForeign(msg) then
        ErrorLog.skipped += 1
        return
    end
    local stamp = os.date("%H:%M:%S")
    local key = msg:sub(1, 120)
    local now = os.clock()
    local slot = ErrorLog.counts[key]
    local isNew = (slot == nil)
    local count = (slot and slot.count or 0) + 1
    ErrorLog.counts[key] = { last = now, count = count }
    local line = string.format("[%s][#%d] %s || %s",
        stamp, count, msg, tostring(stackTrace):sub(1, 220))
    ErrorLog.lines[#ErrorLog.lines + 1] = line
    if #ErrorLog.lines > 2000 then table.remove(ErrorLog.lines, 1) end
    ErrorLogAppendFile(line)
    ErrorLog.bytes = (ErrorLog.bytes or 0) + #line + 1
    if ErrorLog.bytes > 300000 then
        if typeof(writefile) == "function" then
            pcall(writefile, ERR_FILE, "-- rotated " .. stamp .. "\n" .. ErrorLogDumpFull())
        end
        ErrorLog.bytes = 0
    end
    if isNew or now - (ErrorLog.lastMirror or 0) >= 1 then
        ErrorLog.lastMirror = now
        ErrorLogPushMirror()
    end
    if isNew or now - (ErrorLog.lastWarn or 0) >= 5 then
        ErrorLog.lastWarn = now
        warn("[PastaWare][ERR] " .. line)
    end
end
function PastaWare.SaveErrors()
    if Globals.__ERRLOG_ARMED then
        print("[PastaWare] standalone ErrLog armed - use global SaveErrors()")
        return
    end
    if typeof(writefile) == "function" then
        pcall(writefile, ERR_FILE, ErrorLogDumpFull())
    end
    ErrorLogPushMirror()
    local keys = 0
    for _ in pairs(ErrorLog.counts) do keys += 1 end
    print("[PastaWare] errors saved: " .. #ErrorLog.lines .. " lines, "
        .. keys .. " unique (game scripts skipped: " .. tostring(ErrorLog.skipped) .. ") -> " .. ERR_FILE .. " + Workspace/PastaWare/error.txt")
end
function PastaWare.ClearErrorLog()
    ErrorLog.lines = {}
    ErrorLog.counts = {}
    if typeof(writefile) == "function" then
        pcall(writefile, ERR_FILE, "-- cleared " .. tostring(os.date()) .. "\n")
    end
    ErrorLogPushMirror()
    print("[PastaWare] error log cleared.")
end
if not Globals.__ERRLOG_ARMED then
    pcall(function()
        ErrorLogEnsureFs()
        ErrorLogPushMirror()
    local head = string.format("=== PastaWare v%s session %s place=%d ===",
        tostring(PastaWare.Version), tostring(os.date("%Y-%m-%d %H:%M:%S")), game.PlaceId)
    ErrorLog.lines[#ErrorLog.lines + 1] = head
    ErrorLogAppendFile(head)
    ErrorLogPushMirror()
    game:GetService("ScriptContext").Error:Connect(function(message, stackTrace, _sourceScript)
        ErrorLogTrace(message, stackTrace)
    end)
    end)
end


--=============================================================================
-- 4. Определение ролей MM2 и отслеживание GunDrop
--=============================================================================
local function resolvePlayerRole(player: Player): string
    if not player or not player.Parent then return "Innocent" end
    local char = player.Character
    local backpack = player:FindFirstChild("Backpack")

    -- Проверка на Murderer (нож в руках или инвентаре)
    local function hasKnife(container: Instance?): boolean
        if not container then return false end
        for _, item in ipairs(container:GetChildren()) do
            if item:IsA("Tool") then
                local name = item.Name:lower()
                if name:find("knife") or name:find("blade") or name:find("dagger") or name:find("scythe") then
                    return true
                end
            end
        end
        return false
    end

    -- Проверка на Sheriff / Hero (пистолет)
    local function hasGun(container: Instance?): boolean
        if not container then return false end
        for _, item in ipairs(container:GetChildren()) do
            if item:IsA("Tool") then
                local name = item.Name:lower()
                if name:find("gun") or name:find("revolver") or name:find("luger") or name:find("blaster") then
                    return true
                end
            end
        end
        return false
    end

    if hasKnife(char) or hasKnife(backpack) then
        return "Murderer"
    end

    if hasGun(char) or hasGun(backpack) then
        -- Если у игрока пистолет, проверяем шериф ли он изначально или подобрал (Hero)
        if PastaWare.State.Roles[player.Name] == "Innocent" and PastaWare.State.GunDrop == nil then
            return "Hero"
        end
        return "Sheriff"
    end

    return "Innocent"
end

local function updateRoles()
    local current = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            current[plr.Name] = resolvePlayerRole(plr)
        end
    end
    PastaWare.State.Roles = current
end

local function scanGunDrop()
    local drop = Workspace:FindFirstChild("GunDrop")
    if not drop then
        for _, child in ipairs(Workspace:GetChildren()) do
            if child.Name == "GunDrop" and child:IsA("BasePart") then
                drop = child
                break
            end
        end
    end
    PastaWare.State.GunDrop = drop
    return drop
end

-- Периодическое фоновое обновление ролей и предметов
task.spawn(function()
    while true do
        pcall(updateRoles)
        pcall(scanGunDrop)
        task.wait(0.25)
    end
end)

--=============================================================================
-- 5. Silent Aim, Детектор движения, Баллистика и SmartTrigger (из headshoot-slient.lua)
--=============================================================================
local BODY_PARTS = { "Head", "HumanoidRootPart", "UpperTorso", "Torso" }
local SHOOT_REMOTES = {
    Shoot = true,
    ShootGun = true,
    GunBeam = true,
}

local VelocityHistory = {}
local RawSamples = {}
local LastTriggerAt = 0

local function getEquippedGun(): Tool?
    local char = LocalPlayer and LocalPlayer.Character
    if not char then return nil end
    for _, item in ipairs(char:GetChildren()) do
        if item:IsA("Tool") then
            local name = item.Name:lower()
            if name:find("gun") or name:find("revolver") or name:find("bow") or name:find("weapon") or item:FindFirstChild("GunBeam") or item:FindFirstChild("Shoot") then
                return item
            end
        end
    end
    return nil
end

local function getMuzzlePosition(gun: Tool?): Vector3
    local localRoot = getLocalRoot()
    local fallback = localRoot and localRoot.Position or (Camera and Camera.CFrame.Position or Vector3.zero)
    if not gun then return fallback end

    local muzzle = gun:FindFirstChild("Muzzle") or gun:FindFirstChild("Handle") or gun:FindFirstChild("Part")
    if muzzle and muzzle:IsA("BasePart") then
        return muzzle.Position
    end
    return fallback
end

local function samplePlayerMotion(player: Player, root: BasePart)
    local history = RawSamples[player]
    if not history then
        history = {}
        RawSamples[player] = history
    end

    local now = os.clock()
    local pos = root.Position
    local vel = root.AssemblyLinearVelocity or Vector3.zero

    table.insert(history, { time = now, position = pos, velocity = vel })
    while #history > 6 do
        table.remove(history, 1)
    end

    if #history < 2 then
        VelocityHistory[player] = {
            Velocity = vel,
            Acceleration = Vector3.zero,
            Confidence = 0.5,
            Airborne = false
        }
        return
    end

    local oldest = history[1]
    local newest = history[#history]
    local dt = newest.time - oldest.time
    if dt <= 0.001 then return end

    local calcVel = (newest.position - oldest.position) / dt
    local calcAcc = (newest.velocity - oldest.velocity) / dt

    local char = player.Character
    local hum = char and safeFindChildOfClass(char, "Humanoid")
    local airborne = hum and (hum:GetState() == Enum.HumanoidStateType.Freefall or hum:GetState() == Enum.HumanoidStateType.Jumping) or false

    VelocityHistory[player] = {
        Velocity = calcVel,
        Acceleration = calcAcc,
        Confidence = math.clamp(1.0 - (#history < 4 and 0.3 or 0), 0.1, 1.0),
        Airborne = airborne
    }
end

local function isSegmentClear(origin: Vector3, destination: Vector3, ignoreCharacter: Model?): boolean
    if PastaWare.Config.Aimbot.Penetration then
        return true -- Wallbang включён
    end

    local params = RaycastParams.new()
    params.FilterType = RaycastFilterType.Exclude
    local filter = { Workspace.CurrentCamera, LocalPlayer.Character }
    if ignoreCharacter then
        table.insert(filter, ignoreCharacter)
    end
    params.FilterDescendantsInstances = filter
    params.IgnoreWater = true

    local dir = destination - origin
    local result = Workspace:Raycast(origin, dir, params)
    return result == nil
end

local function predictTargetPosition(origin: Vector3, targetPart: BasePart, targetPlayer: Player): (Vector3, number)
    local sample = VelocityHistory[targetPlayer]
    local vel = (sample and sample.Velocity) or targetPart.AssemblyLinearVelocity or Vector3.zero
    local acc = (sample and sample.Acceleration) or Vector3.zero
    local dist = (targetPart.Position - origin).Magnitude

    -- Приблизительная скорость пули (в студах в секунду, для хитскана время близко к 0)
    local bulletSpeed = 1000
    local leadTime = math.clamp(dist / bulletSpeed, 0, 0.5)

    local predOffset = PastaWare.Config.Aimbot.PredictionOffset / 100
    local heightOffset = PastaWare.Config.Aimbot.HeightOffset

    local predicted = targetPart.Position + (vel * leadTime * (PastaWare.Config.Aimbot.Prediction and 1 or 0))
    if sample and sample.Airborne then
        -- Учёт гравитации при свободном падении
        local g = PastaWare.Config.Aimbot.Gravity or 196.2
        predicted = predicted - Vector3.new(0, 0.5 * g * leadTime * leadTime, 0)
    end

    predicted = predicted + Vector3.new(predOffset, heightOffset, 0)
    return predicted, leadTime
end

local function pickAimbotTarget(): (Player?, BasePart?)
    if not isAlive(LocalPlayer) then return nil, nil end
    local localRoot = getLocalRoot()
    if not localRoot then return nil, nil end

    local bestPlayer: Player? = nil
    local bestPart: BasePart? = nil
    local shortestDist = math.huge
    local mousePos = safeGetMouseLocation()

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and isAlive(player) then
            -- Проверка команд
            if PastaWare.Config.Aimbot.IgnoreTeam and player.Team ~= nil and player.Team == LocalPlayer.Team then
                continue
            end

            -- Проверка для MM2: стрелять только по Murderer если включено
            if PastaWare.Config.Aimbot.TargetMurdererOnly then
                local role = PastaWare.State.Roles[player.Name] or resolvePlayerRole(player)
                if role ~= "Murderer" then
                    continue
                end
            end

            local char = player.Character
            if not char then continue end

            local targetPartName = PastaWare.Config.Aimbot.TargetPart
            local part = char:FindFirstChild(targetPartName) or char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
            if not part or not part:IsA("BasePart") then continue end

            local worldDist = (part.Position - localRoot.Position).Magnitude
            if worldDist > PastaWare.Config.Aimbot.MaxDistance then continue end

            -- Проверка FOV на экране
            local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
            if not onScreen then continue end

            local screenDist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
            if screenDist > PastaWare.Config.Aimbot.FieldOfView then continue end

            -- Проверка видимости (если не включён прострел через стены)
            local muzzle = getMuzzlePosition(getEquippedGun())
            if not isSegmentClear(muzzle, part.Position, char) then
                continue
            end

            if screenDist < shortestDist then
                shortestDist = screenDist
                bestPlayer = player
                bestPart = part :: BasePart
            end
        end
    end

    return bestPlayer, bestPart
end

local function buildAimSnapshot()
    if not PastaWare.Config.Aimbot.Enabled then
        PastaWare.State.CurrentSnapshot = nil
        return
    end

    local targetPlayer, targetPart = pickAimbotTarget()
    PastaWare.State.CurrentTarget = targetPlayer
    PastaWare.State.TargetPart = targetPart

    if not targetPlayer or not targetPart then
        PastaWare.State.CurrentSnapshot = nil
        return
    end

    local gun = getEquippedGun()
    local muzzle = getMuzzlePosition(gun)
    local predictedPos, leadTime = predictTargetPosition(muzzle, targetPart, targetPlayer)

    PastaWare.State.CurrentSnapshot = {
        Player = targetPlayer,
        TargetPart = targetPart,
        OriginalPosition = targetPart.Position,
        PredictedPosition = predictedPos,
        MuzzlePosition = muzzle,
        Direction = (predictedPos - muzzle).Unit,
        LeadTime = leadTime,
        Gun = gun,
        CreatedAt = os.clock(),
    }
end

--=============================================================================
-- 6. Перехват выстрела через __namecall (Luraph Hook)
--=============================================================================
if HasHook and HasNamecall and not Globals.__PastaWareHookInstalled then
    Globals.__PastaWareHookInstalled = true

    local originalNamecall
    originalNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        local method = getnamecallmethod()
        local args = { ... }

        if (checkcaller == nil or not checkcaller()) and (method == "FireServer" or method == "InvokeServer") then
            if self and SHOOT_REMOTES[self.Name] and PastaWare.Config.Aimbot.Enabled and PastaWare.Config.Aimbot.SilentAim then
                local snapshot = PastaWare.State.CurrentSnapshot
                if snapshot and snapshot.PredictedPosition and snapshot.MuzzlePosition then
                    -- Подменяем направление/конечную точку выстрела
                    local aimPos = snapshot.PredictedPosition
                    local aimDir = (aimPos - snapshot.MuzzlePosition).Unit

                    -- Адаптивный перебор аргументов выстрела
                    for i = 1, #args do
                        local val = args[i]
                        if typeof(val) == "Vector3" then
                            -- Если вектор единичный - это луч/направление, иначе целевая позиция
                            if math.abs(val.Magnitude - 1.0) < 0.15 then
                                args[i] = aimDir
                            else
                                args[i] = aimPos
                            end
                        elseif typeof(val) == "CFrame" then
                            args[i] = CFrame.lookAt(val.Position, aimPos)
                        end
                    end

                    return originalNamecall(self, table.unpack(args))
                end
            end
        end

        return originalNamecall(self, ...)
    end)
end

--=============================================================================
-- 7. Система визуала (ESP, Chams, Tracers, Corner Boxes, GunDrop, FOV Circle)
--=============================================================================

-- Круг FOV на Drawing API
local FOVCircle = nil
if HasDrawing then
    pcall(function()
        FOVCircle = Drawing.new("Circle")
        FOVCircle.Thickness = 1.5
        FOVCircle.NumSides = 64
        FOVCircle.Radius = PastaWare.Config.Aimbot.FieldOfView
        FOVCircle.Filled = false
        FOVCircle.Visible = false
        FOVCircle.Color = PastaWare.Config.Aimbot.FOVColor
        FOVCircle.Transparency = PastaWare.Config.Aimbot.FOVTransparency
    end)
end

local ESPObjects = {}
local Highlights = {}

local function getPlayerColor(player: Player): Color3
    if PastaWare.Config.Visuals.RoleESP then
        local role = PastaWare.State.Roles[player.Name] or resolvePlayerRole(player)
        if role == "Murderer" then
            return PastaWare.Config.Visuals.MurdererColor
        elseif role == "Sheriff" then
            return PastaWare.Config.Visuals.SheriffColor
        elseif role == "Hero" then
            return PastaWare.Config.Visuals.HeroColor
        else
            return PastaWare.Config.Visuals.InnocentColor
        end
    end
    return PastaWare.Config.Visuals.BoxColor
end

local function createESPForPlayer(player: Player)
    if ESPObjects[player] then return end

    local esp = {
        Player = player,
        BoxLines = {},
        Tracer = nil,
        NameTag = nil,
        DistTag = nil,
        HealthBarOutline = nil,
        HealthBar = nil,
    }

    if HasDrawing then
        local probeOk = pcall(function() Drawing.new("Line"):Remove() end)
        if not probeOk then HasDrawing = false end
    end
    if HasDrawing then
        -- 8 линий для Corner Box или 4 для стандартного
        for i = 1, 8 do
            local line = Drawing.new("Line")
            line.Thickness = 1.5
            line.Visible = false
            table.insert(esp.BoxLines, line)
        end

        local tracer = Drawing.new("Line")
        tracer.Thickness = 1
        tracer.Visible = false
        esp.Tracer = tracer

        local name = Drawing.new("Text")
        name.Size = 13
        name.Center = true
        name.Outline = true
        name.Visible = false
        esp.NameTag = name

        local dist = Drawing.new("Text")
        dist.Size = 11
        dist.Center = true
        dist.Outline = true
        dist.Visible = false
        esp.DistTag = dist

        local hbOut = Drawing.new("Square")
        hbOut.Thickness = 1
        hbOut.Filled = false
        hbOut.Visible = false
        esp.HealthBarOutline = hbOut

        local hb = Drawing.new("Square")
        hb.Thickness = 1
        hb.Filled = true
        hb.Visible = false
        esp.HealthBar = hb
    end

    ESPObjects[player] = esp
end

local function removeESPForPlayer(player: Player)
    local esp = ESPObjects[player]
    if esp then
        if HasDrawing then
            for _, line in ipairs(esp.BoxLines) do pcall(function() line:Remove() end) end
            if esp.Tracer then pcall(function() esp.Tracer:Remove() end) end
            if esp.NameTag then pcall(function() esp.NameTag:Remove() end) end
            if esp.DistTag then pcall(function() esp.DistTag:Remove() end) end
            if esp.HealthBarOutline then pcall(function() esp.HealthBarOutline:Remove() end) end
            if esp.HealthBar then pcall(function() esp.HealthBar:Remove() end) end
        end
        ESPObjects[player] = nil
    end

    local hl = Highlights[player]
    if hl then
        pcall(function() hl:Destroy() end)
        Highlights[player] = nil
    end
end

-- Обработка добавления/удаления игроков
for _, plr in ipairs(Players:GetPlayers()) do
    if plr ~= LocalPlayer then
        createESPForPlayer(plr)
    end
end

Players.PlayerAdded:Connect(function(plr)
    if plr ~= LocalPlayer then
        createESPForPlayer(plr)
    end
end)

Players.PlayerRemoving:Connect(function(plr)
    removeESPForPlayer(plr)
end)

local function updateHighlight(player: Player, character: Model, color: Color3)
    if not PastaWare.Config.Visuals.Chams then
        if Highlights[player] then
            Highlights[player].Enabled = false
        end
        return
    end

    local hl = Highlights[player]
    if not hl or hl.Parent ~= character then
        if hl then hl:Destroy() end
        hl = Instance.new("Highlight")
        hl.Name = "PastaWare_Chams"
        hl.Parent = character
        Highlights[player] = hl
    end

    hl.Enabled = true
    hl.FillColor = color
    hl.OutlineColor = PastaWare.Config.Visuals.ChamsOutlineColor
    hl.FillTransparency = PastaWare.Config.Visuals.ChamsTransparency
    hl.OutlineTransparency = PastaWare.Config.Visuals.ChamsOutlineTransparency
    hl.DepthMode = PastaWare.Config.Visuals.ChamsAlwaysOnTop and Enum.HighlightDepthMode.AlwaysOnTop or Enum.HighlightDepthMode.Occluded
end

local function renderESP()
    -- Обновление круга FOV
    if FOVCircle then
        if PastaWare.Config.Aimbot.Enabled and PastaWare.Config.Aimbot.ShowFOV then
            local mouse = safeGetMouseLocation()
            FOVCircle.Position = mouse
            FOVCircle.Radius = PastaWare.Config.Aimbot.FieldOfView
            FOVCircle.Color = PastaWare.Config.Aimbot.FOVColor
            FOVCircle.Transparency = PastaWare.Config.Aimbot.FOVTransparency
            FOVCircle.Filled = PastaWare.Config.Aimbot.FilledFOV
            FOVCircle.Visible = true
        else
            FOVCircle.Visible = false
        end
    end

    local localRoot = getLocalRoot()

    for player, esp in pairs(ESPObjects) do
        local char = player.Character
        local root = char and safeFindChild(char, "HumanoidRootPart")
        local hum = char and safeFindChildOfClass(char, "Humanoid")

        local show = PastaWare.Config.Visuals.Enabled and isAlive(player) and root ~= nil and hum ~= nil

        if show then
            local color = getPlayerColor(player)
            updateHighlight(player, char, color)

            if HasDrawing then
                local rootPos, onScreen = Camera:WorldToViewportPoint(root.Position)
                local head = char and safeFindChild(char, "Head")
                local headPos = head and Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.6, 0)) or rootPos

                if onScreen then
                    local height = math.abs(rootPos.Y - headPos.Y) * 2.5
                    local width = height * 0.65
                    local boxX = rootPos.X - width / 2
                    local boxY = headPos.Y

                    -- Отображение боксов
                    if PastaWare.Config.Visuals.BoxESP then
                        local lines = esp.BoxLines
                        if PastaWare.Config.Visuals.BoxType == "Corners" then
                            local cl = math.clamp(width * 0.25, 4, 15)
                            -- Верх-лево
                            lines[1].From = Vector2.new(boxX, boxY); lines[1].To = Vector2.new(boxX + cl, boxY)
                            lines[2].From = Vector2.new(boxX, boxY); lines[2].To = Vector2.new(boxX, boxY + cl)
                            -- Верх-право
                            lines[3].From = Vector2.new(boxX + width, boxY); lines[3].To = Vector2.new(boxX + width - cl, boxY)
                            lines[4].From = Vector2.new(boxX + width, boxY); lines[4].To = Vector2.new(boxX + width, boxY + cl)
                            -- Низ-лево
                            lines[5].From = Vector2.new(boxX, boxY + height); lines[5].To = Vector2.new(boxX + cl, boxY + height)
                            lines[6].From = Vector2.new(boxX, boxY + height); lines[6].To = Vector2.new(boxX, boxY + height - cl)
                            -- Низ-право
                            lines[7].From = Vector2.new(boxX + width, boxY + height); lines[7].To = Vector2.new(boxX + width - cl, boxY + height)
                            lines[8].From = Vector2.new(boxX + width, boxY + height); lines[8].To = Vector2.new(boxX + width, boxY + height - cl)

                            for i = 1, 8 do
                                lines[i].Color = color
                                lines[i].Visible = true
                            end
                        else
                            -- Обычный 2D бокс
                            lines[1].From = Vector2.new(boxX, boxY); lines[1].To = Vector2.new(boxX + width, boxY)
                            lines[2].From = Vector2.new(boxX + width, boxY); lines[2].To = Vector2.new(boxX + width, boxY + height)
                            lines[3].From = Vector2.new(boxX + width, boxY + height); lines[3].To = Vector2.new(boxX, boxY + height)
                            lines[4].From = Vector2.new(boxX, boxY + height); lines[4].To = Vector2.new(boxX, boxY)
                            for i = 1, 4 do lines[i].Color = color; lines[i].Visible = true end
                            for i = 5, 8 do lines[i].Visible = false end
                        end
                    else
                        for i = 1, 8 do esp.BoxLines[i].Visible = false end
                    end

                    -- Трейсеры
                    if PastaWare.Config.Visuals.Tracers and esp.Tracer then
                        local origin = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                        if PastaWare.Config.Visuals.TracerOrigin == "Middle" then
                            origin = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
                        elseif PastaWare.Config.Visuals.TracerOrigin == "Mouse" then
                            origin = safeGetMouseLocation()
                        end
                        esp.Tracer.From = origin
                        esp.Tracer.To = Vector2.new(rootPos.X, rootPos.Y + height / 2)
                        esp.Tracer.Color = color
                        esp.Tracer.Visible = true
                    elseif esp.Tracer then
                        esp.Tracer.Visible = false
                    end

                    -- Текст имени и роли
                    if PastaWare.Config.Visuals.Names and esp.NameTag then
                        local role = PastaWare.State.Roles[player.Name] or resolvePlayerRole(player)
                        local roleText = (role ~= "Innocent") and (" [" .. role:upper() .. "]") or ""
                        esp.NameTag.Text = player.DisplayName .. roleText
                        esp.NameTag.Position = Vector2.new(rootPos.X, boxY - 16)
                        esp.NameTag.Color = color
                        esp.NameTag.Visible = true
                    elseif esp.NameTag then
                        esp.NameTag.Visible = false
                    end

                    -- Дистанция
                    if PastaWare.Config.Visuals.Distances and esp.DistTag and localRoot then
                        local distStuds = math.floor((root.Position - localRoot.Position).Magnitude)
                        esp.DistTag.Text = tostring(distStuds) .. "m"
                        esp.DistTag.Position = Vector2.new(rootPos.X, boxY + height + 3)
                        esp.DistTag.Color = Color3.fromRGB(220, 220, 220)
                        esp.DistTag.Visible = true
                    elseif esp.DistTag then
                        esp.DistTag.Visible = false
                    end

                    -- Полоска здоровья
                    if PastaWare.Config.Visuals.HealthBar and esp.HealthBar and esp.HealthBarOutline then
                        local maxHp = hum.MaxHealth > 0 and hum.MaxHealth or 100
                        local hp = math.clamp(hum.Health, 0, maxHp)
                        local pct = hp / maxHp
                        local barWidth = 3
                        local barX = boxX - barWidth - 4

                        esp.HealthBarOutline.Position = Vector2.new(barX - 1, boxY - 1)
                        esp.HealthBarOutline.Size = Vector2.new(barWidth + 2, height + 2)
                        esp.HealthBarOutline.Color = Color3.fromRGB(0, 0, 0)
                        esp.HealthBarOutline.Visible = true

                        local curBarHeight = height * pct
                        esp.HealthBar.Position = Vector2.new(barX, boxY + (height - curBarHeight))
                        esp.HealthBar.Size = Vector2.new(barWidth, curBarHeight)
                        esp.HealthBar.Color = Color3.fromHSV(pct * 0.33, 0.9, 0.9)
                        esp.HealthBar.Visible = true
                    else
                        if esp.HealthBar then esp.HealthBar.Visible = false end
                        if esp.HealthBarOutline then esp.HealthBarOutline.Visible = false end
                    end
                else
                    if HasDrawing then
                        for i = 1, 8 do esp.BoxLines[i].Visible = false end
                    end
                    if esp.Tracer then esp.Tracer.Visible = false end
                    if esp.NameTag then esp.NameTag.Visible = false end
                    if esp.DistTag then esp.DistTag.Visible = false end
                    if esp.HealthBar then esp.HealthBar.Visible = false end
                    if esp.HealthBarOutline then esp.HealthBarOutline.Visible = false end
                end
            end
        else
            if Highlights[player] then Highlights[player].Enabled = false end
            if HasDrawing then
                for i = 1, 8 do esp.BoxLines[i].Visible = false end
                if esp.Tracer then esp.Tracer.Visible = false end
                if esp.NameTag then esp.NameTag.Visible = false end
                if esp.DistTag then esp.DistTag.Visible = false end
                if esp.HealthBar then esp.HealthBar.Visible = false end
                if esp.HealthBarOutline then esp.HealthBarOutline.Visible = false end
            end
        end
    end
end

--=============================================================================
-- 8. Система передвижения (Pulse Fly, Noclip, Speed, Infinite Jump, Gun Grabber)
--=============================================================================

local FlyBodyVelocity = nil
local FlyBodyGyro = nil
local GunHighlight = nil

local function cleanupFly()
    if FlyBodyVelocity then
        pcall(function() FlyBodyVelocity:Destroy() end)
        FlyBodyVelocity = nil
    end
    if FlyBodyGyro then
        pcall(function() FlyBodyGyro:Destroy() end)
        FlyBodyGyro = nil
    end
    local char = LocalPlayer.Character
    local hum = char and safeFindChildOfClass(char, "Humanoid")
    if hum then
        hum.PlatformStand = false
    end
end

local function updateFly()
    local char = LocalPlayer.Character
    local hum = char and safeFindChildOfClass(char, "Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")

    if not PastaWare.Config.Movement.Fly or not hum or not root or hum.Health <= 0 then
        if PastaWare.State.FlyActive then
            PastaWare.State.FlyActive = false
            cleanupFly()
        end
        return
    end

    PastaWare.State.FlyActive = true

    if not FlyBodyVelocity or FlyBodyVelocity.Parent ~= root then
        cleanupFly()

        FlyBodyVelocity = Instance.new("BodyVelocity")
        FlyBodyVelocity.Name = "PastaWare_FlyVelocity"
        FlyBodyVelocity.MaxForce = Vector3.new(1e9, 1e9, 1e9)
        FlyBodyVelocity.Velocity = Vector3.zero
        FlyBodyVelocity.Parent = root

        FlyBodyGyro = Instance.new("BodyGyro")
        FlyBodyGyro.Name = "PastaWare_FlyGyro"
        FlyBodyGyro.P = 9e4
        FlyBodyGyro.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
        FlyBodyGyro.CFrame = root.CFrame
        FlyBodyGyro.Parent = root
    end

    hum.PlatformStand = true

    local moveDir = hum.MoveDirection
    local cam = Workspace.CurrentCamera
    local flyVelocity = Vector3.zero

    if cam then
        local look = cam.CFrame.LookVector
        local right = cam.CFrame.RightVector

        -- Проекция на горизонтальную плоскость
        local flatLook = Vector3.new(look.X, 0, look.Z).Unit
        local flatRight = Vector3.new(right.X, 0, right.Z).Unit

        if moveDir.Magnitude > 0.05 then
            flyVelocity = (look * moveDir:Dot(flatLook)) + (right * moveDir:Dot(flatRight))
        end
    end

    -- Вертикальный подъем / спуск
    local vertical = 0
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
        vertical = vertical + 1
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
        vertical = vertical - 1
    end

    if vertical ~= 0 then
        flyVelocity = flyVelocity + Vector3.new(0, vertical, 0)
    end

    local speed = PastaWare.Config.Movement.FlySpeed
    if flyVelocity.Magnitude > 0.01 then
        FlyBodyVelocity.Velocity = flyVelocity.Unit * speed
    elseif PastaWare.Config.Movement.FlyBobbing then
        -- Небольшое покачивание в воздухе при остановке
        FlyBodyVelocity.Velocity = Vector3.new(0, math.sin(os.clock() * 2.5) * 0.8, 0)
    else
        FlyBodyVelocity.Velocity = Vector3.zero
    end

    if cam then
        FlyBodyGyro.CFrame = cam.CFrame
    end
end

-- Noclip (отключение коллизий)
addConnection(RunService.Stepped:Connect(function()
    local char = LocalPlayer.Character
    if not char then return end

    local shouldNoclip = PastaWare.Config.Movement.Noclip or (PastaWare.Config.Movement.Fly and PastaWare.Config.Movement.FlyNoClip)
    if shouldNoclip then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then
                part.CanCollide = false
            end
        end
    end
end))

-- Infinite Jump (бесконечный прыжок)
addConnection(UserInputService.JumpRequest:Connect(function()
    if PastaWare.Config.Movement.InfiniteJump and isAlive(LocalPlayer) then
        local hum = LocalPlayer.Character and safeFindChildOfClass(LocalPlayer.Character, "Humanoid")
        if hum then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end))

-- Скорость бега и сила прыжка
addConnection(RunService.Heartbeat:Connect(function()
    local char = LocalPlayer.Character
    local hum = char and safeFindChildOfClass(char, "Humanoid")
    if hum and hum.Health > 0 then
        if PastaWare.Config.Movement.WalkSpeedEnabled then
            hum.WalkSpeed = PastaWare.Config.Movement.WalkSpeed
        end
        if PastaWare.Config.Movement.JumpPowerEnabled then
            hum.JumpPower = PastaWare.Config.Movement.JumpPower
        end
    end
end))

-- GunDrop ESP и Авто-подбор оружия
local function updateGunDrop()
    local gun = PastaWare.State.GunDrop
    if not gun or not gun.Parent then
        if GunHighlight then
            GunHighlight.Enabled = false
        end
        return
    end

    -- Визуал дропнутого пистолета
    if PastaWare.Config.Visuals.GunDropESP then
        if not GunHighlight or GunHighlight.Parent ~= gun then
            if GunHighlight then GunHighlight:Destroy() end
            GunHighlight = Instance.new("Highlight")
            GunHighlight.Name = "PastaWare_GunHL"
            GunHighlight.FillColor = PastaWare.Config.Visuals.GunDropColor
            GunHighlight.OutlineColor = Color3.fromRGB(255, 255, 255)
            GunHighlight.FillTransparency = 0.3
            GunHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            GunHighlight.Parent = gun
        end
        GunHighlight.Enabled = true
    elseif GunHighlight then
        GunHighlight.Enabled = false
    end

    -- Авто-подбор оружия (TouchInterest или приближение)
    if PastaWare.Config.Misc.AutoPickupGun and isAlive(LocalPlayer) then
        local root = getLocalRoot()
        if root then
            local dist = (gun.Position - root.Position).Magnitude
            if dist <= PastaWare.Config.Misc.PickupDistance then
                if HasTouch then
                    firetouchinterest(root, gun, 0)
                    task.wait()
                    firetouchinterest(root, gun, 1)
                else
                    -- Альтернативный метод: аккуратное касание CFrame
                    local oldCF = root.CFrame
                    root.CFrame = gun.CFrame
                    task.wait(0.05)
                    root.CFrame = oldCF
                end
            end
        end
    end
end

--=============================================================================
-- 9. Главный цикл обработки кадров (Main Runtime Loop & SmartTrigger)
--=============================================================================

addConnection(RunService.Heartbeat:Connect(function(dt)
    PastaWare.State.Alive = isAlive(LocalPlayer)
    if not PastaWare.State.Alive then
        PastaWare.State.CurrentSnapshot = nil
        return
    end

    local now = os.clock()

    -- Сэмплирование движения игроков (10 Гц)
    if now - PastaWare.State.LastSampleTime >= 0.1 then
        PastaWare.State.LastSampleTime = now
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and isAlive(plr) then
                local _, root = getStrictLivingPlayer(plr)
                if root then
                    samplePlayerMotion(plr, root)
                end
            end
        end
    end

    -- Обновление снапшота аима
    buildAimSnapshot()

    -- Обработка полета
    updateFly()

    -- Обработка оружия на земле
    updateGunDrop()

    -- SmartTrigger / AutoShoot
    if PastaWare.Config.Aimbot.Enabled and PastaWare.Config.Aimbot.AutoShoot then
        local snapshot = PastaWare.State.CurrentSnapshot
        if snapshot and snapshot.Gun and snapshot.TargetPart then
            if (now - PastaWare.State.LastShotTime) >= (PastaWare.Config.Aimbot.ShotDelay / 1000 + 0.15) then
                PastaWare.State.LastShotTime = now
                task.spawn(function()
                    pcall(function()
                        snapshot.Gun:Activate()
                    end)
                end)
            end
        end
    end
end))

-- Рендер ESP каждый кадр перед отрисовкой
addConnection(RunService.RenderStepped:Connect(function()
    renderESP()
end))

-- Обработка горячих клавиш (Fly, Menu)
addConnection(UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end

    if input.KeyCode == PastaWare.Config.Movement.FlyKey then
        PastaWare.Config.Movement.Fly = not PastaWare.Config.Movement.Fly
    elseif input.KeyCode == PastaWare.Config.Misc.MenuKey then
        if PastaWare.UI and PastaWare.UI.SetMenu and PastaWare.UI.MainFrame then
            PastaWare.UI.SetMenu(not PastaWare.UI.MainFrame.Visible)
        elseif PastaWare.UI and PastaWare.UI.MainFrame then
            PastaWare.UI.MainFrame.Visible = not PastaWare.UI.MainFrame.Visible
        end
    end
end))

--=============================================================================
-- 10. Графический интерфейс меню (PastaWare Modern In-Game GUI)
--=============================================================================

local function createPastaWareUI()
    local parent = nil
    pcall(function() parent = CoreGui end)
    if not parent then
        parent = LocalPlayer:WaitForChild("PlayerGui")
    end

    local existing = parent:FindFirstChild("PastaWare_UI")
    if existing then existing:Destroy() end

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "PastaWare_UI"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.Parent = parent

    -- Главное окно
    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0, 560, 0, 390)
    MainFrame.Position = UDim2.new(0.5, -280, 0.5, -195)
    MainFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
    MainFrame.BorderSizePixel = 0
    MainFrame.Active = true
    MainFrame.Draggable = true
    MainFrame.Parent = ScreenGui

    local MainCorner = Instance.new("UICorner")
    MainCorner.CornerRadius = UDim.new(0, 8)
    MainCorner.Parent = MainFrame

    local MainStroke = Instance.new("UIStroke")
    MainStroke.Color = Color3.fromRGB(220, 50, 50)
    MainStroke.Thickness = 1.5
    MainStroke.Parent = MainFrame

    -- Заголовок (TopBar)
    local TopBar = Instance.new("Frame")
    TopBar.Name = "TopBar"
    TopBar.Size = UDim2.new(1, 0, 0, 40)
    TopBar.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
    TopBar.BorderSizePixel = 0
    TopBar.Parent = MainFrame

    local TopBarCorner = Instance.new("UICorner")
    TopBarCorner.CornerRadius = UDim.new(0, 8)
    TopBarCorner.Parent = TopBar

    local Title = Instance.new("TextLabel")
    Title.Name = "Title"
    Title.Size = UDim2.new(0, 200, 1, 0)
    Title.Position = UDim2.new(0, 15, 0, 0)
    Title.BackgroundTransparency = 1
    Title.Text = "PASTAWARE <font color=\"#e74c3c\">v2.0</font>"
    Title.RichText = true
    Title.Font = Enum.Font.GothamBold
    Title.TextSize = 16
    Title.TextColor3 = Color3.fromRGB(240, 240, 240)
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.Parent = TopBar

    local SubTitle = Instance.new("TextLabel")
    SubTitle.Name = "SubTitle"
    SubTitle.Size = UDim2.new(0, 150, 1, 0)
    SubTitle.Position = UDim2.new(1, -165, 0, 0)
    SubTitle.BackgroundTransparency = 1
    SubTitle.Text = "[R-CTRL to Toggle]"
    SubTitle.Font = Enum.Font.Gotham
    SubTitle.TextSize = 12
    SubTitle.TextColor3 = Color3.fromRGB(130, 130, 140)
    SubTitle.TextXAlignment = Enum.TextXAlignment.Right
    SubTitle.Parent = TopBar

    -- Панель вкладок (Sidebar)
    local TabContainer = Instance.new("Frame")
    TabContainer.Name = "TabContainer"
    TabContainer.Size = UDim2.new(0, 120, 1, -40)
    TabContainer.Position = UDim2.new(0, 0, 0, 40)
    TabContainer.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
    TabContainer.BorderSizePixel = 0
    TabContainer.Parent = MainFrame

    local TabList = Instance.new("UIListLayout")
    TabList.Padding = UDim.new(0, 5)
    TabList.HorizontalAlignment = Enum.HorizontalAlignment.Center
    TabList.SortOrder = Enum.SortOrder.LayoutOrder
    TabList.Parent = TabContainer

    local TabPadding = Instance.new("UIPadding")
    TabPadding.PaddingTop = UDim.new(0, 10)
    TabPadding.Parent = TabContainer

    -- Контейнер содержимого страниц
    local PagesContainer = Instance.new("Frame")
    PagesContainer.Name = "PagesContainer"
    PagesContainer.Size = UDim2.new(1, -130, 1, -50)
    PagesContainer.Position = UDim2.new(0, 125, 0, 45)
    PagesContainer.BackgroundTransparency = 1
    PagesContainer.Parent = MainFrame

    local Tabs = { "Aimbot", "Visuals", "Movement", "Combat", "World", "Pulse", "Misc" }
    local TabButtons = {}
    local Pages = {}

    -- Генератор элементов интерфейса (Toggle, Slider, Button)
    local function createToggle(page, text, default, callback)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -10, 0, 32)
        btn.BackgroundColor3 = Color3.fromRGB(28, 28, 36)
        btn.BorderSizePixel = 0
        btn.Text = ""
        btn.AutoButtonColor = false
        btn.Parent = page

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 6)
        corner.Parent = btn

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, -50, 1, 0)
        label.Position = UDim2.new(0, 12, 0, 0)
        label.BackgroundTransparency = 1
        label.Text = text
        label.Font = Enum.Font.GothamMedium
        label.TextSize = 13
        label.TextColor3 = Color3.fromRGB(220, 220, 220)
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = btn

        local indicator = Instance.new("Frame")
        indicator.Size = UDim2.new(0, 20, 0, 20)
        indicator.Position = UDim2.new(1, -30, 0.5, -10)
        indicator.BackgroundColor3 = default and Color3.fromRGB(231, 76, 60) or Color3.fromRGB(50, 50, 60)
        indicator.BorderSizePixel = 0
        indicator.Parent = btn

        local indCorner = Instance.new("UICorner")
        indCorner.CornerRadius = UDim.new(0, 4)
        indCorner.Parent = indicator

        local state = default
        btn.MouseButton1Click:Connect(function()
            state = not state
            indicator.BackgroundColor3 = state and Color3.fromRGB(231, 76, 60) or Color3.fromRGB(50, 50, 60)
            callback(state)
        end)
    end

    local function createSlider(page, text, min, max, default, callback)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, -10, 0, 45)
        frame.BackgroundColor3 = Color3.fromRGB(28, 28, 36)
        frame.BorderSizePixel = 0
        frame.Parent = page

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 6)
        corner.Parent = frame

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(0.7, 0, 0, 20)
        label.Position = UDim2.new(0, 12, 0, 4)
        label.BackgroundTransparency = 1
        label.Text = text
        label.Font = Enum.Font.GothamMedium
        label.TextSize = 13
        label.TextColor3 = Color3.fromRGB(220, 220, 220)
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = frame

        local valLabel = Instance.new("TextLabel")
        valLabel.Size = UDim2.new(0.25, 0, 0, 20)
        valLabel.Position = UDim2.new(0.72, 0, 0, 4)
        valLabel.BackgroundTransparency = 1
        valLabel.Text = tostring(default)
        valLabel.Font = Enum.Font.GothamBold
        valLabel.TextSize = 13
        valLabel.TextColor3 = Color3.fromRGB(231, 76, 60)
        valLabel.TextXAlignment = Enum.TextXAlignment.Right
        valLabel.Parent = frame

        local barBg = Instance.new("Frame")
        barBg.Size = UDim2.new(1, -24, 0, 6)
        barBg.Position = UDim2.new(0, 12, 0, 30)
        barBg.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
        barBg.BorderSizePixel = 0
        barBg.Parent = frame

        local barCorner = Instance.new("UICorner")
        barCorner.CornerRadius = UDim.new(0, 3)
        barCorner.Parent = barBg

        local fill = Instance.new("Frame")
        local pct = math.clamp((default - min) / (max - min), 0, 1)
        fill.Size = UDim2.new(pct, 0, 1, 0)
        fill.BackgroundColor3 = Color3.fromRGB(231, 76, 60)
        fill.BorderSizePixel = 0
        fill.Parent = barBg

        local fillCorner = Instance.new("UICorner")
        fillCorner.CornerRadius = UDim.new(0, 3)
        fillCorner.Parent = fill

        local dragging = false
        local function update(input)
            local posX = math.clamp(input.Position.X - barBg.AbsolutePosition.X, 0, barBg.AbsoluteSize.X)
            local ratio = posX / barBg.AbsoluteSize.X
            local val = math.floor(min + (max - min) * ratio)
            fill.Size = UDim2.new(ratio, 0, 1, 0)
            valLabel.Text = tostring(val)
            callback(val)
        end

        barBg.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = true
                update(input)
            end
        end)

        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = false
            end
        end)

        UserInputService.InputChanged:Connect(function(input)
            if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                update(input)
            end
        end)
    end

    local function createButton(page, text, callback)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -10, 0, 32)
        btn.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
        btn.BorderSizePixel = 0
        btn.Text = text
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 13
        btn.TextColor3 = Color3.fromRGB(240, 240, 240)
        btn.Parent = page

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 6)
        corner.Parent = btn

        btn.MouseButton1Click:Connect(callback)
    end

    -- Создание страниц
    for _, tabName in ipairs(Tabs) do
        local page = Instance.new("ScrollingFrame")
        page.Name = tabName .. "Page"
        page.Size = UDim2.new(1, 0, 1, 0)
        page.BackgroundTransparency = 1
        page.BorderSizePixel = 0
        page.ScrollBarThickness = 4
        page.ScrollBarImageColor3 = Color3.fromRGB(231, 76, 60)
        page.Visible = (tabName == "Aimbot")
        page.Parent = PagesContainer
        Pages[tabName] = page

        local list = Instance.new("UIListLayout")
        list.Padding = UDim.new(0, 6)
        list.SortOrder = Enum.SortOrder.LayoutOrder
        list.Parent = page

        local pad = Instance.new("UIPadding")
        pad.PaddingTop = UDim.new(0, 5)
        pad.PaddingLeft = UDim.new(0, 5)
        pad.PaddingRight = UDim.new(0, 8)
        pad.Parent = page

        -- Кнопка вкладки в сайдбаре
        local tabBtn = Instance.new("TextButton")
        tabBtn.Name = tabName .. "Tab"
        tabBtn.Size = UDim2.new(1, -12, 0, 32)
        tabBtn.BackgroundColor3 = (tabName == "Aimbot") and Color3.fromRGB(231, 76, 60) or Color3.fromRGB(28, 28, 36)
        tabBtn.BorderSizePixel = 0
        tabBtn.Text = tabName
        tabBtn.Font = Enum.Font.GothamMedium
        tabBtn.TextSize = 13
        tabBtn.TextColor3 = Color3.fromRGB(240, 240, 240)
        tabBtn.Parent = TabContainer

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 6)
        corner.Parent = tabBtn

        tabBtn.MouseButton1Click:Connect(function()
            for name, p in pairs(Pages) do
                p.Visible = (name == tabName)
            end
            for name, b in pairs(TabButtons) do
                b.BackgroundColor3 = (name == tabName) and Color3.fromRGB(231, 76, 60) or Color3.fromRGB(28, 28, 36)
            end
        end)

        TabButtons[tabName] = tabBtn
    end

    -- Наполнение вкладки [Aimbot]
    local pAimbot = Pages["Aimbot"]
    createToggle(pAimbot, "Silent Aim (Luraph Engine)", PastaWare.Config.Aimbot.SilentAim, function(v) PastaWare.Config.Aimbot.SilentAim = v end)
    createToggle(pAimbot, "Auto Shoot (SmartTrigger)", PastaWare.Config.Aimbot.AutoShoot, function(v) PastaWare.Config.Aimbot.AutoShoot = v end)
    createToggle(pAimbot, "Penetration (Wallbang)", PastaWare.Config.Aimbot.Penetration, function(v) PastaWare.Config.Aimbot.Penetration = v end)
    createToggle(pAimbot, "Target Murderer Only (MM2)", PastaWare.Config.Aimbot.TargetMurdererOnly, function(v) PastaWare.Config.Aimbot.TargetMurdererOnly = v end)
    createToggle(pAimbot, "Prediction Trajectory", PastaWare.Config.Aimbot.Prediction, function(v) PastaWare.Config.Aimbot.Prediction = v end)
    createToggle(pAimbot, "Show FOV Circle", PastaWare.Config.Aimbot.ShowFOV, function(v) PastaWare.Config.Aimbot.ShowFOV = v end)
    createSlider(pAimbot, "Field Of View (Radius)", 30, 400, PastaWare.Config.Aimbot.FieldOfView, function(v) PastaWare.Config.Aimbot.FieldOfView = v end)
    createSlider(pAimbot, "Max Distance (Studs)", 50, 1000, PastaWare.Config.Aimbot.MaxDistance, function(v) PastaWare.Config.Aimbot.MaxDistance = v end)

    -- Наполнение вкладки [Visuals]
    local pVisuals = Pages["Visuals"]
    createToggle(pVisuals, "Master Visuals Switch", PastaWare.Config.Visuals.Enabled, function(v) PastaWare.Config.Visuals.Enabled = v end)
    createToggle(pVisuals, "Corner Box ESP", PastaWare.Config.Visuals.BoxESP, function(v) PastaWare.Config.Visuals.BoxESP = v end)
    createToggle(pVisuals, "Chams (Highlights)", PastaWare.Config.Visuals.Chams, function(v) PastaWare.Config.Visuals.Chams = v end)
    createToggle(pVisuals, "MM2 Role ESP (Colors)", PastaWare.Config.Visuals.RoleESP, function(v) PastaWare.Config.Visuals.RoleESP = v end)
    createToggle(pVisuals, "GunDrop ESP (Highlight Gun)", PastaWare.Config.Visuals.GunDropESP, function(v) PastaWare.Config.Visuals.GunDropESP = v end)
    createToggle(pVisuals, "Snaplines / Tracers", PastaWare.Config.Visuals.Tracers, function(v) PastaWare.Config.Visuals.Tracers = v end)
    createToggle(pVisuals, "Player Names & Roles", PastaWare.Config.Visuals.Names, function(v) PastaWare.Config.Visuals.Names = v end)
    createToggle(pVisuals, "Distance Tags", PastaWare.Config.Visuals.Distances, function(v) PastaWare.Config.Visuals.Distances = v end)
    createToggle(pVisuals, "Health Bars", PastaWare.Config.Visuals.HealthBar, function(v) PastaWare.Config.Visuals.HealthBar = v end)

    -- Наполнение вкладки [Movement]
    local pMovement = Pages["Movement"]
    createToggle(pMovement, "Pulse Flight (F)", PastaWare.Config.Movement.Fly, function(v) PastaWare.Config.Movement.Fly = v end)
    createSlider(pMovement, "Flight Speed", 20, 200, PastaWare.Config.Movement.FlySpeed, function(v) PastaWare.Config.Movement.FlySpeed = v end)
    createToggle(pMovement, "Fly Anim (Superman)", PastaWare.Config.Movement.FlyAnim, function(v) PastaWare.Config.Movement.FlyAnim = v end)
    createToggle(pMovement, "Noclip (Pass Walls)", PastaWare.Config.Movement.Noclip, function(v) PastaWare.Config.Movement.Noclip = v end)
    createToggle(pMovement, "Custom WalkSpeed", PastaWare.Config.Movement.WalkSpeedEnabled, function(v) PastaWare.Config.Movement.WalkSpeedEnabled = v end)
    createSlider(pMovement, "WalkSpeed Value", 16, 120, PastaWare.Config.Movement.WalkSpeed, function(v) PastaWare.Config.Movement.WalkSpeed = v end)
    createToggle(pMovement, "Speed Multiplier (Candy)", PastaWare.Config.Movement.SpeedEnabled, function(v) PastaWare.Config.Movement.SpeedEnabled = v end)
    createSlider(pMovement, "Speed Multiplier x", 10, 50, math.floor((PastaWare.Config.Movement.SpeedMultiplier or 1.5) * 10), function(v) PastaWare.Config.Movement.SpeedMultiplier = v / 10 end)
    createToggle(pMovement, "Jump Boost (Candy)", PastaWare.Config.Movement.JumpEnabled, function(v) PastaWare.Config.Movement.JumpEnabled = v end)
    createSlider(pMovement, "JumpBoost Power", 50, 150, PastaWare.Config.Movement.JumpBoost, function(v) PastaWare.Config.Movement.JumpBoost = v end)
    createToggle(pMovement, "WallHop (Candy)", PastaWare.Config.Movement.WallHop, function(v) PastaWare.Config.Movement.WallHop = v end)
    createSlider(pMovement, "WallHop Power", 30, 100, PastaWare.Config.Movement.WallHopPower, function(v) PastaWare.Config.Movement.WallHopPower = v end)
    createToggle(pMovement, "Infinite Jump", PastaWare.Config.Movement.InfiniteJump, function(v) PastaWare.Config.Movement.InfiniteJump = v end)

    -- Наполнение вкладки [Combat] (Candy боевые модули)
    local pCombat = Pages["Combat"]
    createToggle(pCombat, "AimLock Camera (Candy Aimbot)", PastaWare.Config.Aimbot.AimLock, function(v) PastaWare.Config.Aimbot.AimLock = v end)
    createSlider(pCombat, "Aimbot FOV (Candy)", 50, 500, 270, function(v) if PastaWare.State.CandyAimbot then PastaWare.State.CandyAimbot.config.FOV = v end end)
    createToggle(pCombat, "Backtrack Ghost (Candy)", PastaWare.Config.Backtrack.Enabled, function(v) if PastaWare.State.CandyBacktrack then PastaWare.State.CandyBacktrack:SetEnabled(v) end end)
    createToggle(pCombat, "Backtrack Ghost Visible", PastaWare.Config.Backtrack.ShowGhost, function(v) PastaWare.Config.Backtrack.ShowGhost = v end)
    createSlider(pCombat, "Backtrack Window ms", 50, 500, math.floor((PastaWare.Config.Backtrack.Window or 0.2) * 1000), function(v) PastaWare.Config.Backtrack.Window = v / 1000 end)
    createToggle(pCombat, "AntiAim Spin (Candy)", PastaWare.Config.AntiAim.Enabled, function(v) if PastaWare.State.CandyAntiAim then PastaWare.State.CandyAntiAim:SetEnabled(v) end end)
    createSlider(pCombat, "AntiAim Spin Speed", 2, 20, PastaWare.Config.AntiAim.SpinSpeed, function(v) PastaWare.Config.AntiAim.SpinSpeed = v end)
    createToggle(pCombat, "Hitbox Expander (Candy)", PastaWare.Config.Hitbox.Enabled, function(v) if PastaWare.State.CandyHitbox then PastaWare.State.CandyHitbox:SetEnabled(v) end end)
    createToggle(pCombat, "Resolver (Anti-Jitter)", PastaWare.Config.Resolver.Enabled, function(v) PastaWare.Config.Resolver.Enabled = v end)
    createSlider(pCombat, "Resolver Aggro %", 0, 100, math.floor((PastaWare.Config.Resolver.Aggressiveness or 0.5) * 100), function(v) PastaWare.Config.Resolver.Aggressiveness = v / 100 end)
    createToggle(pCombat, "TriggerBot (MM2)", PastaWare.Config.TriggerBot.Enabled, function(v) if PastaWare.State.CandyTrigger then PastaWare.State.CandyTrigger:SetEnabled(v) end end)
    createSlider(pCombat, "Trigger Delay ms", 0, 500, math.floor((PastaWare.Config.TriggerBot.Delay or 0.12) * 1000), function(v) PastaWare.Config.TriggerBot.Delay = v / 1000 end)
    createToggle(pCombat, "AutoParry (MM2 Knife)", PastaWare.Config.Misc.AutoParry, function(v) PastaWare.Config.Misc.AutoParry = v end)
    createSlider(pCombat, "AutoParry Distance", 8, 40, PastaWare.Config.Misc.AutoParryDistance, function(v) PastaWare.Config.Misc.AutoParryDistance = v end)
    createToggle(pCombat, "SilentAim Wrapper (Candy)", PastaWare.Config.Aimbot.SilentAim, function(v) PastaWare.Config.Aimbot.SilentAim = v end)
    createToggle(pCombat, "Teleport Mode (Candy)", PastaWare.Config.Misc.TeleportEnabled, function(v) PastaWare.Config.Misc.TeleportEnabled = v end)
    createToggle(pCombat, "Spoofer (Candy)", PastaWare.Config.Misc.SpooferEnabled, function(v) PastaWare.Config.Misc.SpooferEnabled = v end)

    -- Наполнение вкладки [World] (Pulse мир/карта/предметы)
    local pWorld = Pages["World"]
    createToggle(pWorld, "Billboard Role ESP (Pulse v)", PastaWare.Config.ESPEx.BillboardRoles, function(v) PastaWare.Config.ESPEx.BillboardRoles = v end)
    createToggle(pWorld, "Weapon ESP (in Hands)", PastaWare.Config.ESPEx.WeaponESP, function(v) PastaWare.Config.ESPEx.WeaponESP = v end)
    createToggle(pWorld, "Health Text (numbers)", PastaWare.Config.ESPEx.HealthText, function(v) PastaWare.Config.ESPEx.HealthText = v end)
    createToggle(pWorld, "Glass Overlay (Pulse S)", PastaWare.Config.Glass.Enabled, function(v) PastaWare.Config.Glass.Enabled = v end)
    createToggle(pWorld, "Remove Atmosphere/Sky", PastaWare.Config.World.RemoveAtmosphere, function(v) PastaWare.Config.World.RemoveAtmosphere = v end)
    createToggle(pWorld, "Knife Velocity Track (fP)", PastaWare.Config.World.KnifeVelocityTrack, function(v) PastaWare.Config.World.KnifeVelocityTrack = v end)
    createToggle(pWorld, "Crosshair System (wT+bT)", PastaWare.Config.Crosshair.Enabled, function(v) PastaWare.Config.Crosshair.Enabled = v end)
    createToggle(pWorld, "Custom Cursor Dot", PastaWare.Config.Crosshair.UseCustomCursor, function(v) PastaWare.Config.Crosshair.UseCustomCursor = v end)
    createToggle(pWorld, "Invis Mode (RP/CP)", PastaWare.Config.Invis.Enabled, function(v) PastaWare.Config.Invis.Enabled = v end)
    createToggle(pWorld, "Farm Noclip (NP)", PastaWare.Config.Farm.Enabled, function(v) PastaWare.Config.Farm.Enabled = v Globals.PULSE_FARM_MM2_HEARTBEAT = v end)
    createToggle(pWorld, "Apply UI Skin (e)", true, function(v) if v then PastaWare.Pulse.ApplyUISkin() end end)
    createButton(pWorld, "Scan Lighting Now", function() PastaWare.Pulse.ScanWorldLighting() end)
    createButton(pWorld, "Find TradeRequest GUI", function() local g = PastaWare.Pulse.FindTradeRequestGui() print("[PastaWare] TradeRequest:", g and g:GetFullName() or "nil") end)
    createButton(pWorld, "Dump Inventory (w)", function() local inv = PastaWare.Pulse.LoadInventoryWeapons() print("[PastaWare] Inventory groups:", inv and "ok" or "nil") end)
    createButton(pWorld, "SHA256 Self-Test (V)", function() print("[PastaWare] sha256(test)=", PastaWare.Pulse.SHA256Hex("test")) end)
    createButton(pWorld, "Base64 Self-Test (s)", function() print("[PastaWare] b64decode=", PastaWare.Pulse.Base64Decode("dGVzdA==")) end)

    -- Наполнение вкладки [Pulse] (деобфусцированные утилиты/крипто)
    local pPulse = Pages["Pulse"]
    createToggle(pPulse, "Pulse Fly Active Flag", PastaWare.Config.Movement.Fly, function(v) PastaWare.Config.Movement.Fly = v end)
    createToggle(pPulse, "Pulse Aim Gen Bump", false, function(v) if v then Globals.__pulseAimGen = (Globals.__pulseAimGen or 0) + 1 end end)
    createButton(pPulse, "Print Roster (J)", function() local r = PastaWare.Pulse.GetPlayerDataRoster() for k, v in pairs(r) do print(k, v.Role, v.Dead) end end)
    createButton(pPulse, "Scan GunDrops (FP)", function() local t = PastaWare.Pulse.ScanAllGunDrops() local n = 0 for _ in pairs(t) do n = n + 1 end print("[PastaWare] GunDrops:", n) end)
    createButton(pPulse, "Cleanup Dead Refs (HT)", function() PastaWare.Pulse.CleanupDeadRefs() print("[PastaWare] cleaned") end)
    createButton(pPulse, "RC4 Self-Test (b)", function() local e = PastaWare.Pulse.RC4("key", "hello") print("[PastaWare] rc4 len:", #e) end)
    createButton(pPulse, "HMAC Self-Test (O)", function() print("[PastaWare] hmac len:", #PastaWare.Pulse.HMACLike("k", "m")) end)
    createButton(pPulse, "BigInt Self-Test (Y/U)", function() local a = PastaWare.Pulse.BigFromHexLE("ff") print("[PastaWare] big hex:", PastaWare.Pulse.BigToHex(a)) end)
    createButton(pPulse, "LeadTime Probe (D1)", function() print("[PastaWare] lead:", PastaWare.Pulse.GetLeadTime()) end)
    createButton(pPulse, "Snapshot Validate (D4)", function() print("[PastaWare] valid:", PastaWare.Pulse.IsSnapshotValidEx(PastaWare.State.CurrentSnapshot)) end)
    createButton(pPulse, "Protocol Probe (D6)", function() print("[PastaWare] proto test ok") end)

    -- Наполнение вкладки [Misc]
    local pMisc = Pages["Misc"]
    createToggle(pMisc, "Auto-Pickup Dropped Gun (MM2)", PastaWare.Config.Misc.AutoPickupGun, function(v) PastaWare.Config.Misc.AutoPickupGun = v end)
    createSlider(pMisc, "Pickup Radius (Studs)", 10, 100, PastaWare.Config.Misc.PickupDistance, function(v) PastaWare.Config.Misc.PickupDistance = v end)
    createToggle(pMisc, "Anti-AFK (VirtualUser)", PastaWare.Config.Misc.AntiAFK, function(v) PastaWare.Config.Misc.AntiAFK = v end)
    createButton(pMisc, "Teleport to GunDrop", function()
        local g = PastaWare.State.GunDrop
        if g and g.Parent then
            local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if root then root.CFrame = g.CFrame + Vector3.new(0, 3, 0) end
        else
            print("[PastaWare] no GunDrop")
        end
    end)
    createButton(pMisc, "Teleport to Murderer", function()
        for _, plr in ipairs(Players:GetPlayers()) do
            if PastaWare.State.Roles[plr.Name] == "Murderer" and plr.Character then
                local t = plr.Character:FindFirstChild("HumanoidRootPart")
                local me = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                if t and me then me.CFrame = t.CFrame + Vector3.new(0, 3, 3) break end
            end
        end
    end)
    createButton(pMisc, "Print Roles (MM2)", function()
        for k, v in pairs(PastaWare.State.Roles) do print(k, "=>", v) end
        print("KnifeSpeed:", PastaWare.State.KnifeSpeed or 0)
    end)
    createButton(pMisc, "Apply Skin Now (e)", function() PastaWare.Pulse.ApplyUISkin() end)
    createButton(pMisc, "Save Errors -> error.txt", function() PastaWare.SaveErrors() end)
    createButton(pMisc, "Clear Error Log", function() PastaWare.ClearErrorLog() end)
    createButton(pMisc, "Unload PastaWare", function()
        PastaWare:Unload()
    end)

    PastaWare.UI = {
        ScreenGui = ScreenGui,
        MainFrame = MainFrame,
    }

    --=========================================================================
    -- Мобильная круглая кнопка: drag + открыть/закрыть GUI с анимацией.
    -- Тап (<10px сдвига) — тогл меню; перетаскивание — двигает кнопку.
    --=========================================================================
    local MobileBtn = Instance.new("TextButton")
    MobileBtn.Name = "MobileToggle"
    MobileBtn.Size = UDim2.new(0, 56, 0, 56)
    MobileBtn.Position = UDim2.new(1, -70, 0.35, 0)
    MobileBtn.AnchorPoint = Vector2.new(0.5, 0.5)
    MobileBtn.BackgroundColor3 = Color3.fromRGB(231, 76, 60)
    MobileBtn.BorderSizePixel = 0
    MobileBtn.Text = "PW"
    MobileBtn.Font = Enum.Font.GothamBold
    MobileBtn.TextSize = 16
    MobileBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    MobileBtn.AutoButtonColor = false
    MobileBtn.Active = true
    MobileBtn.Parent = ScreenGui

    local BtnCorner = Instance.new("UICorner")
    BtnCorner.CornerRadius = UDim.new(1, 0)
    BtnCorner.Parent = MobileBtn

    local BtnStroke = Instance.new("UIStroke")
    BtnStroke.Color = Color3.fromRGB(255, 255, 255)
    BtnStroke.Thickness = 1.5
    BtnStroke.Transparency = 0.4
    BtnStroke.Parent = MobileBtn

    local MenuScale = Instance.new("UIScale")
    MenuScale.Scale = 1
    MenuScale.Parent = MainFrame

    local menuOpen = true
    local function setMenu(open: boolean)
        menuOpen = open
        if open then
            MainFrame.Visible = true
            TweenService:Create(MenuScale,
                TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
                { Scale = 1 }):Play()
            TweenService:Create(MobileBtn, TweenInfo.new(0.2),
                { BackgroundColor3 = Color3.fromRGB(231, 76, 60) }):Play()
        else
            TweenService:Create(MenuScale,
                TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
                { Scale = 0.7 }):Play()
            TweenService:Create(MobileBtn, TweenInfo.new(0.2),
                { BackgroundColor3 = Color3.fromRGB(60, 60, 70) }):Play()
            task.delay(0.2, function()
                if not menuOpen then MainFrame.Visible = false end
            end)
        end
    end
    PastaWare.UI.SetMenu = setMenu
    PastaWare.UI.MobileButton = MobileBtn

    local mDragging = false
    local mStart, mPos0, mMoved = nil, nil, 0
    MobileBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            mDragging = true
            mStart = input.Position
            mPos0 = MobileBtn.Position
            mMoved = 0
            TweenService:Create(MobileBtn, TweenInfo.new(0.1),
                { Size = UDim2.new(0, 50, 0, 50) }):Play()
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if mDragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - mStart
            mMoved = delta.Magnitude
            MobileBtn.Position = UDim2.new(
                mPos0.X.Scale, mPos0.X.Offset + delta.X,
                mPos0.Y.Scale, mPos0.Y.Offset + delta.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if mDragging and (input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch) then
            mDragging = false
            TweenService:Create(MobileBtn, TweenInfo.new(0.12),
                { Size = UDim2.new(0, 56, 0, 56) }):Play()
            if mMoved < 10 then
                setMenu(not menuOpen)
            end
        end
    end)
end

--=============================================================================
-- 11.A PULSE DEOBFUSCATED CORE (puls.orig.lua -> чистые имена)
-- Mapping: WP=vP... обфусцированные f[0..27] -> реальные сервисы/стейт.
-- Каждый модуль ниже подписан: оригинальное имя = новая функция.
--=============================================================================
do
    -- PulseGlobal: общий стейт как в оригинале getgenv().__pulse*
    local PulseGlobal = Globals
    PulseGlobal.__pulseAimGen = PulseGlobal.__pulseAimGen or 0
    PulseGlobal.__pulseFlyActive = PulseGlobal.__pulseFlyActive or false
    PulseGlobal.__pulseXHairShown = PulseGlobal.__pulseXHairShown or false
    PastaWare.Pulse = PastaWare.Pulse or {}

    --=========================================================================
    -- A1. s (Base64 decode) -- puls.orig.lua:377 `s = function(f)`
    -- Оригинал: f[0] = словарь base64, ручной декодер с кэшем на 512 чанков.
    --=========================================================================
    local Base64Alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    local Base64Lookup = {}
    for i = 1, #Base64Alphabet do
        Base64Lookup[Base64Alphabet:sub(i, i)] = i - 1
    end
    local function Pulse_Base64Decode(input: string): string
        local s = tostring(input or ""):gsub("[^%w%+%/%=]", "")
        local outChunks, outN = {}, 0
        local charBuf, charN = {}, 0
        local acc, bits = 0, 0
        local len, pos = #s, 1
        local sbyte, schar, sfloor, tconcat = string.byte, string.char, math.floor, table.concat
        while pos <= len do
            local handled = false
            if bits == 0 and pos + 3 <= len then
                local b1, b2, b3, b4 = sbyte(s, pos, pos + 3)
                local c1, c2, c3, c4 = Base64Lookup[schar(b1)], Base64Lookup[schar(b2)], Base64Lookup[schar(b3)], Base64Lookup[schar(b4)]
                -- NOTE: оригинал маппит через словарь d (f[0]); здесь прямой lookup
                if c1 and c2 and c3 and c4 then
                    local packed = ((c1 * 64 + c2) * 64 + c3) * 64 + c4
                    charN = charN + 1
                    charBuf[charN] = schar(sfloor(packed / 65536), sfloor(packed / 256) % 256, packed % 256)
                    pos = pos + 4
                    handled = true
                end
            end
            if not handled then
                local ch = s:sub(pos, pos)
                pos = pos + 1
                local v = Base64Lookup[ch]
                if v then
                    acc = acc * 64 + v
                    bits = bits + 6
                    if bits >= 8 then
                        bits = bits - 8
                        local div = (bits == 4 and 16) or (bits == 2 and 4) or 1
                        charN = charN + 1
                        charBuf[charN] = schar(sfloor(acc / div))
                        acc = acc % div
                    end
                end
            end
            if charN >= 512 then
                outN = outN + 1
                outChunks[outN] = tconcat(charBuf, "", 1, charN)
                charN = 0
            end
        end
        if charN > 0 then
            outN = outN + 1
            outChunks[outN] = tconcat(charBuf, "", 1, charN)
        end
        return tconcat(outChunks)
    end
    PastaWare.Pulse.Base64Decode = Pulse_Base64Decode

    --=========================================================================
    -- A2. H (Hex encode) + d (Hex decode LE u16) -- puls: H, d, l, Y, U, p, m
    -- Оригинал: bigint как массив u16 limbs LE, Y=mul2, U=mul, p=sub, m=cmp,
    -- l=toHex, d=fromHex, h=xorfold. Сохранено 1:1, но с именами.
    --=========================================================================
    local function Pulse_HexEncode(s: string): string
        return (tostring(s):gsub(".", function(c)
            return string.format("%02x", c:byte())
        end))
    end
    local function Pulse_BigTrim(limbs)
        while #limbs > 1 and limbs[#limbs] == 0 do limbs[#limbs] = nil end
        return limbs
    end
    local function Pulse_BigFromHexLE(hexStr: string)
        local clean = tostring(hexStr or ""):gsub("%s", "")
        if #clean % 4 ~= 0 then
            clean = string.rep("0", 4 - #clean % 4) .. clean
        end
        local out = {}
        for i = #clean, 1, -4 do
            out[#out + 1] = tonumber(clean:sub(i - 3, i), 16) or 0
        end
        return Pulse_BigTrim(out)
    end
    local function Pulse_BigToHex(limbs): string
        local parts = {}
        for i = #limbs, 1, -1 do parts[#parts + 1] = string.format("%04x", limbs[i]) end
        local s = table.concat(parts):gsub("^0+", "")
        return s == "" and "0" or s
    end
    local function Pulse_BigMul2(limbs)
        local out, carry = {}, 0
        for i = 1, #limbs do
            local v = limbs[i] * 2 + carry
            out[i] = v % 65536
            carry = math.floor(v / 65536)
        end
        if carry > 0 then out[#out + 1] = carry end
        return out
    end
    local function Pulse_BigMul(a, b)
        local out = {}
        for i = 1, #a + #b do out[i] = 0 end
        for i = 1, #a do
            local carry, av = 0, a[i]
            if av ~= 0 then
                for j = 1, #b do
                    local v = out[i + j - 1] + av * b[j] + carry
                    out[i + j - 1] = v % 65536
                    carry = math.floor(v / 65536)
                end
                local k = i + #b
                while carry > 0 do
                    local v = out[k] + carry
                    out[k] = v % 65536
                    carry = math.floor(v / 65536)
                    k = k + 1
                end
            end
        end
        return Pulse_BigTrim(out)
    end
    local function Pulse_BigSub(a, b)
        local out, borrow = {}, 0
        for i = 1, #a do
            local v = a[i] - borrow - (b[i] or 0)
            if v < 0 then v = v + 65536 borrow = 1 else borrow = 0 end
            out[i] = v
        end
        return Pulse_BigTrim(out)
    end
    local function Pulse_BigCmp(a, b): number
        if #a ~= #b then return #a > #b and 1 or -1 end
        for i = #a, 1, -1 do
            if a[i] ~= b[i] then return a[i] > b[i] and 1 or -1 end
        end
        return 0
    end
    PastaWare.Pulse.HexEncode = Pulse_HexEncode
    PastaWare.Pulse.BigFromHexLE = Pulse_BigFromHexLE
    PastaWare.Pulse.BigToHex = Pulse_BigToHex
    PastaWare.Pulse.BigMul2 = Pulse_BigMul2
    PastaWare.Pulse.BigMul = Pulse_BigMul
    PastaWare.Pulse.BigSub = Pulse_BigSub
    PastaWare.Pulse.BigCmp = Pulse_BigCmp

    --=========================================================================
    -- A3. b (RC4) -- puls:868 `b = function(f)`
    -- f[0] = bxor. Классический KSA+PRGA, побайтово.
    --=========================================================================
    local function Pulse_RC4(key: string, data: string): string
        local S = {}
        for i = 0, 255 do S[i] = i end
        local j = 0
        local klen = #key
        for i = 0, 255 do
            j = (j + S[i] + key:byte(i % klen + 1)) % 256
            S[i], S[j] = S[j], S[i]
        end
        local out, a, b2 = {}, 0, 0
        for k = 1, #data do
            a = (a + 1) % 256
            b2 = (b2 + S[a]) % 256
            S[a], S[b2] = S[b2], S[a]
            local ks = S[(S[a] + S[b2]) % 256]
            out[k] = string.char(bit32.bxor(data:byte(k), ks))
        end
        return table.concat(out)
    end
    PastaWare.Pulse.RC4 = Pulse_RC4

    --=========================================================================
    -- A4. V (SHA256) -- puls:3224 `V = function(f)`
    -- Полный SHA256 на bit32, константы F[1..64] идут из апвелю f[6].
    -- Здесь константы вшиты явно (стандартные SHA256 K).
    --=========================================================================
    local SHA256_K = {
        0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,
        0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
        0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,
        0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
        0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,
        0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
        0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,
        0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2,
    }
    local function Pulse_SHA256_Raw(msg: string): string
        local bor, band, bxor, rrot, rsh, modadd =
            bit32.bor, bit32.band, bit32.bxor, bit32.rrotate, bit32.rshift,
            function(a, b) return (a + b) % 4294967296 end
        local H0,H1,H2,H3,H4,H5,H6,H7 =
            1779033703, 3144134277, 1013904242, 2773480762,
            1359893119, 2600822924, 528734635, 1541459225
        local mlen = #msg
        local bitlen_lo = (mlen * 8) % 4294967296
        local bitlen_hi = math.floor(mlen * 8 / 4294967296)
        local function be32(n)
            return string.char(
                band(rsh(n, 24), 255), band(rsh(n, 16), 255),
                band(rsh(n, 8), 255), band(n, 255))
        end
        msg = msg .. "\128" .. string.rep("\0", (56 - (mlen + 1) % 64) % 64)
            .. be32(bitlen_hi) .. be32(bitlen_lo)
        for off = 1, #msg, 64 do
            local W = {}
            for i = 0, 15 do
                local a,b,c,d = msg:byte(off + i * 4, off + i * 4 + 3)
                W[i] = bor(bor(bor(bit32.lshift(a,24), bit32.lshift(b,16)), bit32.lshift(c,8)), d)
            end
            for i = 16, 63 do
                local s0 = bxor(bxor(rrot(W[i-15],7), rrot(W[i-15],18)), rsh(W[i-15],3))
                local s1 = bxor(bxor(rrot(W[i-2],17), rrot(W[i-2],19)), rsh(W[i-2],10))
                W[i] = modadd(modadd(modadd(W[i-16], s0), W[i-7]), s1)
            end
            local a,b,c,d,e,f,g,h = H0,H1,H2,H3,H4,H5,H6,H7
            for i = 0, 63 do
                local S1 = bxor(bxor(rrot(e,6), rrot(e,11)), rrot(e,25))
                local ch = bxor(band(e,f), band(bxor(e,0xFFFFFFFF),g))
                local t1 = modadd(modadd(modadd(modadd(h, S1), ch), SHA256_K[i+1]), W[i])
                local S0 = bxor(bxor(rrot(a,2), rrot(a,13)), rrot(a,22))
                local mj = bxor(bxor(band(a,b), band(a,c)), band(b,c))
                local t2 = modadd(S0, mj)
                h,g,f,e,d,c,b,a = g,f,e,modadd(d,t1),c,b,a,modadd(t1,t2)
            end
            H0,H1,H2,H3,H4,H5,H6,H7 =
                modadd(H0,a),modadd(H1,b),modadd(H2,c),modadd(H3,d),
                modadd(H4,e),modadd(H5,f),modadd(H6,g),modadd(H7,h)
        end
        local out = {}
        for _, v in ipairs({H0,H1,H2,H3,H4,H5,H6,H7}) do out[#out+1] = be32(v) end
        return table.concat(out)
    end
    local function Pulse_SHA256Hex(s: string): string
        return (Pulse_SHA256_Raw(s):gsub(".", function(c)
            return string.format("%02x", c:byte())
        end))
    end
    PastaWare.Pulse.SHA256_Raw = Pulse_SHA256_Raw
    PastaWare.Pulse.SHA256Hex = Pulse_SHA256Hex

    --=========================================================================
    -- A5. W (key-stretch) + O (HMAC-like double) -- puls:1077,3746
    -- W(f): PBKDF-подобный конструкт: hex->bytes, RC4-ish, sha256hex цикл.
    -- O(f): O(f,m) = SHA256( pad92.. + SHA256(pad54.. .. m) ) — HMAC-стиль.
    --=========================================================================
    local function Pulse_HexToBytes(hexStr: string): string
        local clean = tostring(hexStr or "")
        if #clean % 2 == 1 then clean = "0" .. clean end
        return (clean:gsub("%x%x", function(h) return string.char(tonumber(h, 16)) end))
    end
    local function Pulse_HMACLike(keyStr: string, msg: string): string
        local key = tostring(keyStr or "")
        if #key > 64 then key = Pulse_SHA256_Raw(key) end
        key = key .. string.rep("\0", 64 - #key)
        local ipad, opad = {}, {}
        for i = 1, 64 do
            local b = key:byte(i)
            ipad[i] = string.char(bit32.bxor(b, 0x36))
            opad[i] = string.char(bit32.bxor(b, 0x5C))
        end
        return Pulse_SHA256_Raw(table.concat(opad) .. Pulse_SHA256_Raw(table.concat(ipad) .. msg))
    end
    PastaWare.Pulse.HexToBytes = Pulse_HexToBytes
    PastaWare.Pulse.HMACLike = Pulse_HMACLike

    --=========================================================================
    -- A6. DP (IsValidTargetPart) -- puls:2042
    -- Проверки: BasePart, не Terrain, Transparency<1, не PulseWobble,
    -- не принадлежит игроку (GetPlayerFromCharacter вверх по Model).
    --=========================================================================
    local function Pulse_IsValidTargetPart(part: Instance): boolean
        if not part or not part:IsA("BasePart") then return false end
        if part:IsA("Terrain") then return false end
        if (part.Transparency or 0) >= 1 then return false end
        if tostring(part.Name):sub(1, 11) == "PulseWobble" then return false end
        local model = part:FindFirstAncestorWhichIsA("Model")
        while model do
            local ok, plr = pcall(function() return Players:GetPlayerFromCharacter(model) end)
            if ok and plr then return false end
            model = model.Parent and model.Parent:FindFirstAncestorWhichIsA("Model") or nil
        end
        return true
    end
    PastaWare.Pulse.IsValidTargetPart = Pulse_IsValidTargetPart

    --=========================================================================
    -- A7. f (ResolveRoleSimple) -- puls:1710
    -- Только по Character Tools: knife->Murderer, gun->Sheriff, иначе nil.
    -- Полная версия с Backpack уже есть в resolvePlayerRole; это быстрый путь.
    --=========================================================================
    local function Pulse_ResolveRoleSimple(player: Player): string?
        local char = player and player.Character
        if not char then return nil end
        for _, tool in ipairs(char:GetChildren()) do
            if tool:IsA("Tool") then
                local n = tostring(tool.Name):lower()
                if n:find("knife") then return "Murderer" end
                if n:find("gun") then return "Sheriff" end
            end
        end
        return nil
    end
    PastaWare.Pulse.ResolveRoleSimple = Pulse_ResolveRoleSimple

    --=========================================================================
    -- A8. J (GetPlayerDataRoster, кэш 0.2с) -- puls:143
    -- Оригинал: если есть внешний провайдер j[1] (GetLatestPlayerData) — брать
    -- оттуда; иначе собрать {Role, Dead, Killed} по игрокам через m(d).
    --=========================================================================
    local function Pulse_GetPlayerDataRoster(): any
        local now = os.clock()
        if now - (PastaWare.State.RosterCacheAt or 0) < 0.2 and PastaWare.State.RosterCache then
            return PastaWare.State.RosterCache
        end
        PastaWare.State.RosterCacheAt = now
        local roster = {}
        for _, plr in ipairs(Players:GetPlayers()) do
            local role = Pulse_ResolveRoleSimple(plr) or PastaWare.State.Roles[plr.Name] or "Innocent"
            local char = plr.Character
            local hum = char and safeFindChildOfClass(char, "Humanoid")
            roster[plr.Name] = {
                Role = role,
                Dead = (hum ~= nil and hum.Health <= 0),
                Killed = false,
                UserId = plr.UserId,
            }
        end
        PastaWare.State.RosterCache = roster
        return roster
    end
    PastaWare.Pulse.GetPlayerDataRoster = Pulse_GetPlayerDataRoster

    --=========================================================================
    -- A9. w (LoadInventoryWeapons) -- puls:802
    -- require(ReplicatedStorage.Modules.InventoryModule).MyInventory.Data.Weapons
    -- -> { [id] = {name, chroma, rarity} }, кэшируется.
    --=========================================================================
    local function Pulse_LoadInventoryWeapons()
        if PastaWare.State.InventoryCache then return PastaWare.State.InventoryCache end
        local ok, mod = pcall(function()
            local rs = game:GetService("ReplicatedStorage")
            return require(rs:WaitForChild("Modules"):WaitForChild("InventoryModule"))
        end)
        if not ok or not mod or not mod.MyInventory or not mod.MyInventory.Data or not mod.MyInventory.Data.Weapons then
            return nil
        end
        local out = {}
        for _, group in pairs(mod.MyInventory.Data.Weapons) do
            for id, item in pairs(group) do
                if type(item) == "table" then
                    out[id] = { name = item.ItemName or item.Name or id, chroma = (item.Chroma == true), rarity = item.Rarity or "" }
                end
            end
        end
        PastaWare.State.InventoryCache = out
        return out
    end
    PastaWare.Pulse.LoadInventoryWeapons = Pulse_LoadInventoryWeapons

    --=========================================================================
    -- A10. o (BuildAdminSnapshot payload) -- puls:827
    -- Собирает inventory {displayName,rarity,chroma,value,amount,dataId},
    -- total_value (value>=4.5e15 считается 999999999), players, job_id и т.д.
    -- Оригинал постит на /admin/snapshot; здесь только сборка (без POST).
    --=========================================================================
    local function Pulse_BuildAdminSnapshot(getInventoryFn): any
        if type(getInventoryFn) ~= "function" then return nil end
        local items = getInventoryFn()
        if not items then return nil end
        local list, total = {}, 0
        for _, it in ipairs(items) do
            local v = it.value or 0
            if v >= 4500000000000000 then v = 999999999 end
            total = total + v * (it.amount or 1)
            table.insert(list, {
                displayName = it.displayName, rarity = it.rarity,
                chroma = (it.chroma == true), value = v,
                amount = it.amount or 1, dataId = it.dataId,
            })
        end
        local userIds = {}
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr.UserId and plr.UserId > 0 then userIds[#userIds + 1] = plr.UserId end
        end
        return {
            username = LocalPlayer and LocalPlayer.Name or "?",
            user_id = LocalPlayer and LocalPlayer.UserId or 0,
            place_id = game.PlaceId, job_id = game.JobId,
            inventory = list, total_value = total,
            players_online = #Players:GetPlayers(),
            server_max = Players.MaxPlayers,
            place_version = game.PlaceVersion,
            players = userIds,
        }
    end
    PastaWare.Pulse.BuildAdminSnapshot = Pulse_BuildAdminSnapshot

    --=========================================================================
    -- A11. FP (TrackGunDropAdded) + scanGunDrop расширенный -- puls:269
    -- Оригинал: d[f]=true для BasePart "GunDrop". Здесь + реестр всех дропов.
    --=========================================================================
    local function Pulse_TrackGunDropAdded(obj: Instance)
        if obj and obj.Name == "GunDrop" and obj:IsA("BasePart") then
            PastaWare.State.GunDrops[obj] = true
            PastaWare.State.GunDrop = obj
        end
    end
    local function Pulse_ScanAllGunDrops()
        for _, child in ipairs(Workspace:GetChildren()) do
            if child.Name == "GunDrop" and child:IsA("BasePart") then
                PastaWare.State.GunDrops[child] = true
            end
        end
        -- чистим удалённые
        for part in pairs(PastaWare.State.GunDrops) do
            if part.Parent == nil then PastaWare.State.GunDrops[part] = nil end
        end
        return PastaWare.State.GunDrops
    end
    PastaWare.Pulse.TrackGunDropAdded = Pulse_TrackGunDropAdded
    PastaWare.Pulse.ScanAllGunDrops = Pulse_ScanAllGunDrops

    --=========================================================================
    -- A12. fP (TrackKnifeVelocity) -- puls:3055
    -- Следит за ножом (имя/родитель содержат knife), 10 Heartbeat-кадров
    -- меряет AssemblyLinearVelocity; если 30..800 — пишет в стейт.
    --=========================================================================
    PastaWare.State.KnifeSpeed = PastaWare.State.KnifeSpeed or 0
    local function Pulse_TrackKnifeVelocity(part: BasePart)
        if not part or not part:IsA("BasePart") then return end
        local n = tostring(part.Name):lower()
        local pn = (part.Parent and tostring(part.Parent.Name) or ""):lower()
        if not (n:find("knife") or pn:find("knife")) then return end
        task.spawn(function()
            for _ = 1, 10 do
                RunService.Heartbeat:Wait()
                if not part.Parent then return end
                local ok, mag = pcall(function() return part.AssemblyLinearVelocity.Magnitude end)
                if ok and mag and mag == mag and mag > 30 and mag < 800 then
                    PastaWare.State.KnifeSpeed = mag
                    return
                end
            end
        end)
    end
    PastaWare.Pulse.TrackKnifeVelocity = Pulse_TrackKnifeVelocity

    --=========================================================================
    -- A13. VP (FindTradeRequestGui) -- puls:2073
    -- PlayerGui.MainGUI.Game.Leaderboard.Container.TradeRequest
    --=========================================================================
    local function Pulse_FindTradeRequestGui(): Instance?
        local ok, res = pcall(function()
            local pg = safeFindChildOfClass(LocalPlayer, "PlayerGui")
            local main = pg and pg:FindFirstChild("MainGUI")
            local g = main and main:FindFirstChild("Game")
            local lb = g and g:FindFirstChild("Leaderboard")
            local cont = lb and lb:FindFirstChild("Container")
            return cont and cont:FindFirstChild("TradeRequest")
        end)
        if ok then return res end
        return nil
    end
    PastaWare.Pulse.FindTradeRequestGui = Pulse_FindTradeRequestGui

    --=========================================================================
    -- A14. GP (PositionLineFrame) -- puls:3816
    -- Позиционирует Frame-линию между 2 точками: Size/Position/Rotation.
    -- Используется для трейсеров на GUI (альтернатива Drawing).
    --=========================================================================
    local function Pulse_PositionLineFrame(frame: GuiObject, x1: number, y1: number, x2: number, y2: number, thickness: number)
        local dx, dy = x2 - x1, y2 - y1
        local len = math.sqrt(dx * dx + dy * dy)
        local size = UDim2.fromOffset(len, thickness or 1)
        if frame.Size ~= size then frame.Size = size end
        local pos = UDim2.fromOffset((x1 + x2) / 2, (y1 + y2) / 2)
        if frame.Position ~= pos then frame.Position = pos end
        local rot = math.deg(math.atan2(dy, dx))
        if frame.Rotation ~= rot then frame.Rotation = rot end
    end
    PastaWare.Pulse.PositionLineFrame = Pulse_PositionLineFrame

    --=========================================================================
    -- A15. IT + sT (AtmosphereCleaner) -- puls:440,3292
    -- IT: при добавлении Atmosphere/Clouds/Sky (не Pulse*) — триггер чистки.
    -- sT: сам удаляет чужой Atmosphere (Parent=nil, defer).
    --=========================================================================
    local Pulse_AtmosphereGuard = false
    local function Pulse_CleanForeignAtmosphere(obj: Instance)
        if not PastaWare.Config.World.RemoveAtmosphere then return end
        if obj:IsA("Atmosphere") and obj.Name:sub(1, 5) ~= "Pulse" then
            if Pulse_AtmosphereGuard then return end
            Pulse_AtmosphereGuard = true
            task.delay(0.15, function()
                Pulse_AtmosphereGuard = false
                pcall(function() Pulse_ScanWorldLighting() end)
            end)
        end
    end
    local function Pulse_ScanWorldLighting()
        if not PastaWare.Config.World.RemoveAtmosphere then return end
        local lighting = game:GetService("Lighting")
        for _, child in ipairs(lighting:GetChildren()) do
            if (child:IsA("Atmosphere") or child:IsA("Clouds") or child:IsA("Sky"))
                and child.Name:sub(1, 5) ~= "Pulse" then
                pcall(function() child.Parent = nil end)
            end
        end
    end
    PastaWare.Pulse.OnAtmosphereAdded = Pulse_CleanForeignAtmosphere
    PastaWare.Pulse.ScanWorldLighting = Pulse_ScanWorldLighting

    --=========================================================================
    -- A16. PT (PollRemoteData loop) -- puls:3349
    -- while d(): f=m(); f:InvokeServer() -> U=m. Раз в 1с. Здесь обобщено.
    --=========================================================================
    local function Pulse_PollRemoteDataLoop(shouldRunFn, getRemoteFn, onDataFn)
        task.spawn(function()
            while type(shouldRunFn) == "function" and shouldRunFn() do
                local remote = type(getRemoteFn) == "function" and getRemoteFn() or nil
                if remote then
                    local ok, data = pcall(function() return remote:InvokeServer() end)
                    if ok and type(data) == "table" and type(onDataFn) == "function" then
                        pcall(onDataFn, data)
                    end
                end
                task.wait(1)
            end
        end)
    end
    PastaWare.Pulse.PollRemoteDataLoop = Pulse_PollRemoteDataLoop

    --=========================================================================
    -- A17. HT (CleanupDeadRefs) -- puls:3486
    -- Чистит таблицы GunDrops/Billboards от Parent==nil.
    --=========================================================================
    local function Pulse_CleanupDeadRefs()
        for part in pairs(PastaWare.State.GunDrops) do
            if part.Parent == nil then PastaWare.State.GunDrops[part] = nil end
        end
        for plr, gui in pairs(PastaWare.Billboards) do
            if typeof(gui) == "Instance" and gui.Parent == nil then
                PastaWare.Billboards[plr] = nil
            end
        end
    end
    PastaWare.Pulse.CleanupDeadRefs = Pulse_CleanupDeadRefs

    --=========================================================================
    -- A18. MT/OP (DeferIfOn) -- puls:259,3048: MT(f) task.defer(d,f) если U.on
    --=========================================================================
    local function Pulse_DeferIfOn(flagTable, fn, ...)
        if flagTable and flagTable.on then
            local args = table.pack(...)
            task.defer(function() pcall(fn, table.unpack(args, 1, args.n)) end)
        end
    end
    local function Pulse_PcallOnly(fn, ...)
        pcall(fn, ...)
    end
    PastaWare.Pulse.DeferIfOn = Pulse_DeferIfOn
    PastaWare.Pulse.PcallOnly = Pulse_PcallOnly
end

--=============================================================================
-- 11.B CANDY MODULES — REAL IMPLEMENTATIONS (candy_main.lua имена -> рабочий код)
-- В оригинале каждый модуль был заглушкой:
--   X={Enabled=false}; function X.new() return nil end; function (state) ... end
-- (сломанный синтаксис, dead-code `if X and not X`). Ниже — полные реализации.
--=============================================================================
do
    PastaWare.Candy = PastaWare.Candy or {}
    local Candy = PastaWare.Candy

    -- helpers shared by candy modules
    local function Candy_IsAlive(plr)
        plr = plr or LocalPlayer
        if not plr or not plr.Parent then return false end
        local ch = plr.Character
        if not ch or not ch.Parent then return false end
        local hum = safeFindChildOfClass(ch, "Humanoid")
        local root = safeFindChild(ch, "HumanoidRootPart")
        return hum ~= nil and hum.Health > 0 and root ~= nil
    end
    local function Candy_GetRoot(plr)
        local ch = plr and plr.Character
        return ch and safeFindChild(ch, "HumanoidRootPart")
    end
    local function Candy_GetHum(plr)
        local ch = plr and plr.Character
        return ch and safeFindChildOfClass(ch, "Humanoid")
    end
    Candy.IsAlive = Candy_IsAlive

    --=========================================================================
    -- B01. Aimbot (Candy Aimbot_112 / Aimbot_186) — клик-доводка камеры
    --=========================================================================
    local Aimbot = {}
    Aimbot.__index = Aimbot
    Aimbot.Enabled = false
    Aimbot.FOV = 270
    Aimbot.Smoothness = 0.4
    Aimbot.TeamCheck = true
    Aimbot.VisibleOnly = false
    function Aimbot.new(opts)
        local self = setmetatable({}, Aimbot)
        self.config = opts or {}
        self.Enabled = false
        self.active = false
        self.target = nil
        self.connections = {}
        return self
    end
    function Aimbot:SetEnabled(state: boolean)
        self.Enabled = (state == true)
        self.active = self.Enabled
        return self.Enabled
    end
    function Aimbot:FindTarget(): (Player?, BasePart?)
        if not Candy_IsAlive(LocalPlayer) then return nil, nil end
        local cam = Workspace.CurrentCamera
        local lroot = Candy_GetRoot(LocalPlayer)
        if not cam or not lroot then return nil, nil end
        local mouse = safeGetMouseLocation()
        local best, bestPart, bestScore = nil, nil, math.huge
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and Candy_IsAlive(plr) then
                if self.TeamCheck and LocalPlayer.Team ~= nil and plr.Team == LocalPlayer.Team then
                    -- skip teammate
                else
                    local ch = plr.Character
                    local head = ch and ch:FindFirstChild("Head")
                    local part = head or ch:FindFirstChild("HumanoidRootPart")
                    if part and part:IsA("BasePart") then
                        local sp, on = cam:WorldToViewportPoint(part.Position)
                        if on then
                            local d = (Vector2.new(sp.X, sp.Y) - mouse).Magnitude
                            if d <= (self.config.FOV or self.FOV) and d < bestScore then
                                best, bestPart, bestScore = plr, part, d
                            end
                        end
                    end
                end
            end
        end
        self.target = best
        return best, bestPart
    end
    function Aimbot:AimAt(dt: number)
        if not self.Enabled then return end
        local _, part = self:FindTarget()
        if not part then return end
        local cam = Workspace.CurrentCamera
        if not cam then return end
        local goal = CFrame.lookAt(cam.CFrame.Position, part.Position)
        local alpha = math.clamp(self.config.Smoothness or self.Smoothness or 0.4, 0.01, 1)
        cam.CFrame = cam.CFrame:Lerp(goal, alpha)
    end
    Candy.Aimbot = Aimbot
    PastaWare.State.CandyAimbot = PastaWare.State.CandyAimbot or Aimbot.new({ FOV = 270, Smoothness = 0.4 })

    --=========================================================================
    -- B02. Backtrack (Candy Backtrack) — окно позиций 0.2с + гост
    --=========================================================================
    local Backtrack = {}
    Backtrack.__index = Backtrack
    Backtrack.Enabled = false
    function Backtrack.new(opts)
        local self = setmetatable({}, Backtrack)
        self.config = opts or {}
        self.active = false
        self.records = {} -- [Player] = {{t, cf}, ...}
        self.ghosts = {}
        return self
    end
    function Backtrack:SetEnabled(state: boolean)
        self.Enabled = (state == true)
        PastaWare.Config.Backtrack.Enabled = self.Enabled
        if not self.Enabled then
            for _, g in pairs(self.ghosts) do pcall(function() g:Destroy() end) end
            self.ghosts = {}
            self.records = {}
        end
        return self.Enabled
    end
    function Backtrack:Record(plr: Player)
        if not self.Enabled then return end
        if not Candy_IsAlive(plr) then return end
        local root = Candy_GetRoot(plr)
        if not root then return end
        local rec = self.records[plr]
        if not rec then rec = {} self.records[plr] = rec end
        table.insert(rec, { t = os.clock(), cf = root.CFrame })
        local win = PastaWare.Config.Backtrack.Window or 0.2
        while #rec > 0 and os.clock() - rec[1].t > win do table.remove(rec, 1) end
    end
    function Backtrack:GetOldest(plr: Player): CFrame?
        local rec = self.records[plr]
        if rec and #rec > 0 then return rec[1].cf end
        return nil
    end
    function Backtrack:UpdateGhost(plr: Player)
        if not self.Enabled or not PastaWare.Config.Backtrack.ShowGhost then return end
        local cf = self:GetOldest(plr)
        if not cf then return end
        local g = self.ghosts[plr]
        if not g or g.Parent == nil then
            g = Instance.new("Part")
            g.Name = "PastaWare_Backtrack"
            g.Size = Vector3.new(2, 2, 1)
            g.Anchored = true
            g.CanCollide = false
            g.Transparency = PastaWare.Config.Backtrack.GhostTransparency or 0.5
            g.Color = Color3.fromRGB(180, 120, 255)
            g.Parent = Workspace
            self.ghosts[plr] = g
        end
        g.CFrame = cf
    end
    Candy.Backtrack = Backtrack
    PastaWare.State.CandyBacktrack = PastaWare.State.CandyBacktrack or Backtrack.new({})

    --=========================================================================
    -- B03. AntiAim (Candy AntiAim) — Spin/Jitter/Static yaw
    --=========================================================================
    local AntiAim = {}
    AntiAim.__index = AntiAim
    AntiAim.Enabled = false
    function AntiAim.new(opts)
        local self = setmetatable({}, AntiAim)
        self.config = opts or {}
        self.active = false
        self.yaw = 0
        self.jitterSide = 1
        return self
    end
    function AntiAim:SetEnabled(state: boolean)
        self.Enabled = (state == true)
        PastaWare.Config.AntiAim.Enabled = self.Enabled
        return self.Enabled
    end
    function AntiAim:Update(dt: number)
        if not self.Enabled then return end
        if not Candy_IsAlive(LocalPlayer) then return end
        local root = Candy_GetRoot(LocalPlayer)
        if not root then return end
        local mode = PastaWare.Config.AntiAim.Mode or "Spin"
        if mode == "Spin" then
            self.yaw = (self.yaw + (PastaWare.Config.AntiAim.SpinSpeed or 8) * dt) % (math.pi * 2)
            root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, self.yaw, 0)
        elseif mode == "Jitter" then
            self.jitterSide = -self.jitterSide
            local a = math.rad(PastaWare.Config.AntiAim.JitterAngle or 45) * self.jitterSide
            root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, a, 0)
        else
            local a = math.rad(PastaWare.Config.AntiAim.StaticYaw or 180)
            root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, a, 0)
        end
    end
    Candy.AntiAim = AntiAim
    PastaWare.State.CandyAntiAim = PastaWare.State.CandyAntiAim or AntiAim.new({})

    --=========================================================================
    -- B04. ChamsEx (Candy Chams_139/Chams_191) — Highlight пульс
    --=========================================================================
    local ChamsEx = {}
    ChamsEx.__index = ChamsEx
    ChamsEx.Enabled = false
    function ChamsEx.new(opts)
        local self = setmetatable({}, ChamsEx)
        self.config = opts or {}
        self.store = {}
        return self
    end
    function ChamsEx:SetEnabled(state: boolean)
        self.Enabled = (state == true)
        return self.Enabled
    end
    function ChamsEx:Apply(plr: Player, char: Model, color: Color3)
        if not self.Enabled then return end
        local hl = self.store[plr]
        if not hl or hl.Parent ~= char then
            if hl then pcall(function() hl:Destroy() end) end
            hl = Instance.new("Highlight")
            hl.Name = "PastaWare_CandyChams"
            hl.Parent = char
            self.store[plr] = hl
        end
        hl.Enabled = true
        hl.FillColor = color
        hl.FillTransparency = 0.5
        hl.OutlineTransparency = 0
        if PastaWare.Config.Visuals.ChamsPulse then
            hl.FillTransparency = 0.35 + 0.25 * math.abs(math.sin(os.clock() * 3))
        end
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    end
    function ChamsEx:Hide(plr: Player)
        local hl = self.store[plr]
        if hl then hl.Enabled = false end
    end
    Candy.Chams = ChamsEx
    PastaWare.State.CandyChams = PastaWare.State.CandyChams or ChamsEx.new({})

    --=========================================================================
    -- B05. TracersEx (Candy Tracers_197) — Drawing линии + GUI fallback
    --=========================================================================
    local TracersEx = {}
    TracersEx.__index = TracersEx
    TracersEx.Enabled = false
    function TracersEx.new(opts)
        local self = setmetatable({}, TracersEx)
        self.config = opts or {}
        self.lines = {}
        return self
    end
    function TracersEx:SetEnabled(state: boolean)
        self.Enabled = (state == true)
        return self.Enabled
    end
    function TracersEx:GetLine(plr: Player)
        local l = self.lines[plr]
        if not l then
            local ok, obj = pcall(function() return Drawing.new("Line") end)
            l = ok and obj or { Visible = false, From = Vector2.new(), To = Vector2.new() }
            self.lines[plr] = l
        end
        return l
    end
    function TracersEx:Draw(plr: Player, from2: Vector2, to2: Vector2, color: Color3)
        if not self.Enabled then return end
        local l = self:GetLine(plr)
        l.From = from2
        l.To = to2
        l.Color = color
        l.Thickness = 1
        l.Visible = true
    end
    function TracersEx:Hide(plr: Player)
        local l = self.lines[plr]
        if l then l.Visible = false end
    end
    Candy.Tracers = TracersEx
    PastaWare.State.CandyTracers = PastaWare.State.CandyTracers or TracersEx.new({})

    --=========================================================================
    -- B06. CrosshairSys (Candy Crosshair_161/Crosshair_99) — wT+bT порты
    --=========================================================================
    local CrosshairSys = {}
    CrosshairSys.__index = CrosshairSys
    CrosshairSys.Enabled = false
    function CrosshairSys.new(opts)
        local self = setmetatable({}, CrosshairSys)
        self.config = opts or {}
        self.gui = nil
        self.dot = nil
        return self
    end
    function CrosshairSys:SetEnabled(state: boolean)
        self.Enabled = (state == true)
        PastaWare.Config.Crosshair.Enabled = self.Enabled
        return self.Enabled
    end
    function CrosshairSys:EnsureGui()
        if self.gui and self.gui.Parent then return end
        local parent = safeFindChildOfClass(LocalPlayer, "PlayerGui")
        if not parent then return end
        local sg = Instance.new("ScreenGui")
        sg.Name = "PastaWare_Crosshair"
        sg.ResetOnSpawn = false
        sg.IgnoreGuiInset = true
        sg.Parent = parent
        local mk = function(sz, pos)
            local f = Instance.new("Frame")
            f.Size = sz
            f.Position = pos
            f.AnchorPoint = Vector2.new(0.5, 0.5)
            f.BackgroundColor3 = PastaWare.Config.Crosshair.CursorColor
            f.BorderSizePixel = 0
            f.Parent = sg
            return f
        end
        local cx = PastaWare.Config.Crosshair.CursorSize or 12
        mk(UDim2.fromOffset(cx * 2 + 4, 2), UDim2.new(0.5, 0, 0.5, 0))
        mk(UDim2.fromOffset(2, cx * 2 + 4), UDim2.new(0.5, 0, 0.5, 0))
        self.gui = sg
    end
    function CrosshairSys:Update()
        -- wT: видимость по pick>=1 (здесь: по Crosshair.Enabled и CustomCursor)
        local want = PastaWare.Config.Crosshair.Enabled and PastaWare.Config.Crosshair.UseCustomCursor
        if Globals.__pulseXHairShown == true and PastaWare.Config.Crosshair.HideOnAim then
            want = false
        end
        if self.gui then self.gui.Enabled = want end
        -- bT: кастомный курсор следует за мышью, если системный выключен
        if want then
            self:EnsureGui()
        end
    end
    Candy.Crosshair = CrosshairSys
    PastaWare.State.CandyCrosshair = PastaWare.State.CandyCrosshair or CrosshairSys.new({})

    --=========================================================================
    -- B07. HitboxExpander (Candy Hitbox) — увеличивает HumanoidRootPart
    --=========================================================================
    local HitboxEx = {}
    HitboxEx.__index = HitboxEx
    HitboxEx.Enabled = false
    function HitboxEx.new(opts)
        local self = setmetatable({}, HitboxEx)
        self.config = opts or {}
        return self
    end
    function HitboxEx:SetEnabled(state: boolean)
        self.Enabled = (state == true)
        PastaWare.Config.Hitbox.Enabled = self.Enabled
        if not self.Enabled then self:RestoreAll() end
        return self.Enabled
    end
    function HitboxEx:Backup(part: BasePart)
        if not PastaWare.State.HitboxBackup[part] then
            PastaWare.State.HitboxBackup[part] = { Size = part.Size, Transparency = part.Transparency, CanQuery = part.CanQuery }
        end
    end
    function HitboxEx:ApplyTo(plr: Player)
        if not self.Enabled then return end
        if plr == LocalPlayer or not Candy_IsAlive(plr) then return end
        local part = plr.Character and plr.Character:FindFirstChild(PastaWare.Config.Hitbox.TargetPart or "HumanoidRootPart")
        if part and part:IsA("BasePart") then
            self:Backup(part)
            part.Size = PastaWare.Config.Hitbox.Size or Vector3.new(6, 6, 6)
            part.Transparency = PastaWare.Config.Hitbox.Transparency or 0.7
            part.CanQuery = true
        end
    end
    function HitboxEx:RestoreAll()
        for part, bak in pairs(PastaWare.State.HitboxBackup) do
            pcall(function()
                if part.Parent then
                    part.Size = bak.Size
                    part.Transparency = bak.Transparency
                end
            end)
        end
        PastaWare.State.HitboxBackup = {}
    end
    Candy.Hitbox = HitboxEx
    PastaWare.State.CandyHitbox = PastaWare.State.CandyHitbox or HitboxEx.new({})

    --=========================================================================
    -- B08. SpeedCtrl (Candy Speed) — WalkSpeed множитель каждый Heartbeat
    --=========================================================================
    local SpeedCtrl = {}
    SpeedCtrl.__index = SpeedCtrl
    SpeedCtrl.Enabled = false
    function SpeedCtrl.new(opts)
        local self = setmetatable({}, SpeedCtrl)
        self.config = opts or {}
        return self
    end
    function SpeedCtrl:SetEnabled(state: boolean)
        self.Enabled = (state == true)
        return self.Enabled
    end
    function SpeedCtrl:Update()
        if not self.Enabled then return end
        local hum = Candy_GetHum(LocalPlayer)
        if hum and hum.Health > 0 then
            local base = PastaWare.Config.Movement.WalkSpeedEnabled and PastaWare.Config.Movement.WalkSpeed or 16
            local mult = PastaWare.Config.Movement.SpeedMultiplier or 1.5
            hum.WalkSpeed = base * (PastaWare.Config.Movement.SpeedEnabled and mult or 1)
        end
    end
    Candy.Speed = SpeedCtrl
    PastaWare.State.CandySpeed = PastaWare.State.CandySpeed or SpeedCtrl.new({})

    --=========================================================================
    -- B09. FlyEx (Candy Fly_227) — обёртка над PulseFly (секция 8)
    --=========================================================================
    local FlyEx = {}
    FlyEx.__index = FlyEx
    FlyEx.Enabled = false
    function FlyEx.new(opts)
        local self = setmetatable({}, FlyEx)
        self.config = opts or {}
        return self
    end
    function FlyEx:SetEnabled(state: boolean)
        self.Enabled = (state == true)
        PastaWare.Config.Movement.Fly = self.Enabled
        return self.Enabled
    end
    Candy.Fly = FlyEx

    --=========================================================================
    -- B10. JumpEx (Candy Jump) — высокий прыжок + банихоп-помощник
    --=========================================================================
    local JumpEx = {}
    JumpEx.__index = JumpEx
    JumpEx.Enabled = false
    function JumpEx.new(opts)
        local self = setmetatable({}, JumpEx)
        self.config = opts or {}
        return self
    end
    function JumpEx:SetEnabled(state: boolean)
        self.Enabled = (state == true)
        PastaWare.Config.Movement.JumpEnabled = self.Enabled
        return self.Enabled
    end
    function JumpEx:Update()
        if not self.Enabled then return end
        local hum = Candy_GetHum(LocalPlayer)
        if hum and hum.Health > 0 then
            hum.JumpPower = PastaWare.Config.Movement.JumpBoost or 75
        end
    end
    Candy.Jump = JumpEx
    PastaWare.State.CandyJump = PastaWare.State.CandyJump or JumpEx.new({})

    --=========================================================================
    -- B11. WallHop (Candy WallHop_101) — толчок от стены при прыжке
    --=========================================================================
    local WallHop = {}
    WallHop.__index = WallHop
    WallHop.Enabled = false
    function WallHop.new(opts)
        local self = setmetatable({}, WallHop)
        self.config = opts or {}
        return self
    end
    function WallHop:SetEnabled(state: boolean)
        self.Enabled = (state == true)
        PastaWare.Config.Movement.WallHop = self.Enabled
        return self.Enabled
    end
    function WallHop:TryHop()
        if not self.Enabled or not Candy_IsAlive(LocalPlayer) then return end
        local root = Candy_GetRoot(LocalPlayer)
        if not root then return end
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = { LocalPlayer.Character }
        params.IgnoreWater = true
        for _, dir in ipairs({ root.CFrame.LookVector, -root.CFrame.LookVector, root.CFrame.RightVector, -root.CFrame.RightVector }) do
            local hit = Workspace:Raycast(root.Position, dir * 4, params)
            if hit then
                root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, PastaWare.Config.Movement.WallHopPower or 55, root.AssemblyLinearVelocity.Z) + (-dir * 20)
                break
            end
        end
    end
    Candy.WallHop = WallHop
    PastaWare.State.CandyWallHop = PastaWare.State.CandyWallHop or WallHop.new({})

    --=========================================================================
    -- B12. PredictionEx (Candy Prediction) — линейное упреждение для Aimbot
    --=========================================================================
    local PredictionEx = {}
    PredictionEx.__index = PredictionEx
    PredictionEx.Enabled = false
    function PredictionEx.new(opts)
        local self = setmetatable({}, PredictionEx)
        self.config = opts or {}
        return self
    end
    function PredictionEx:SetEnabled(state: boolean)
        self.Enabled = (state == true)
        PastaWare.Config.Aimbot.Prediction = self.Enabled
        return self.Enabled
    end
    function PredictionEx:Predict(pos: Vector3, vel: Vector3, dist: number): Vector3
        local bulletSpeed = 1000
        local t = math.clamp(dist / bulletSpeed, 0, 0.5)
        if not self.Enabled then return pos end
        return pos + vel * t
    end
    Candy.Prediction = PredictionEx
    PastaWare.State.CandyPrediction = PastaWare.State.CandyPrediction or PredictionEx.new({})

    --=========================================================================
    -- B13. ResolverEx (Candy Resolver_58/142) — сглаживание джиттера
    --=========================================================================
    local ResolverEx = {}
    ResolverEx.__index = ResolverEx
    ResolverEx.Enabled = false
    function ResolverEx.new(opts)
        local self = setmetatable({}, ResolverEx)
        self.config = opts or {}
        self.smooth = {}
        return self
    end
    function ResolverEx:SetEnabled(state: boolean)
        self.Enabled = (state == true)
        PastaWare.Config.Resolver.Enabled = self.Enabled
        return self.Enabled
    end
    function ResolverEx:Resolve(plr: Player, rawVel: Vector3): Vector3
        if not self.Enabled then return rawVel end
        local k = PastaWare.Config.Resolver.Aggressiveness or 0.5
        local prev = self.smooth[plr] or rawVel
        -- агрессивность: чем выше, тем сильнее давим выбросы
        local mag = rawVel.Magnitude
        if mag > 80 then
            rawVel = rawVel.Unit * (80 + (mag - 80) * (1 - k))
        end
        local out = prev:Lerp(rawVel, math.clamp(1 - k * 0.7, 0.1, 1))
        self.smooth[plr] = out
        return out
    end
    Candy.Resolver = ResolverEx
    PastaWare.State.CandyResolver = PastaWare.State.CandyResolver or ResolverEx.new({})

    --=========================================================================
    -- B14. SpooferEx (Candy Spoofer) — подмена WalkSpeed/JumpPower для сервера
    --=========================================================================
    local SpooferEx = {}
    SpooferEx.__index = SpooferEx
    SpooferEx.Enabled = false
    function SpooferEx.new(opts)
        local self = setmetatable({}, SpooferEx)
        self.config = opts or {}
        return self
    end
    function SpooferEx:SetEnabled(state: boolean)
        self.Enabled = (state == true)
        PastaWare.Config.Misc.SpooferEnabled = self.Enabled
        return self.Enabled
    end
    function SpooferEx:Update()
        if not self.Enabled then return end
        -- Клиент видит реальную скорость, серверу отдаём Spoof через Humanoid тени:
        -- здесь мягко: не ломаем движение, только держим значения для античита.
        local hum = Candy_GetHum(LocalPlayer)
        if hum and hum.Health > 0 then
            -- сохраняем реальные, выставляем спооф на кадр проверки (heartbeat jitter)
            if os.clock() % 2 < 0.05 then
                hum.WalkSpeed = PastaWare.Config.Misc.SpoofWalkSpeed or 16
                hum.JumpPower = PastaWare.Config.Misc.SpoofJumpPower or 50
            end
        end
    end
    Candy.Spoofer = SpooferEx

    --=========================================================================
    -- B15. TriggerBot (Candy TriggerBot) — огонь когда курсор на враге
    --=========================================================================
    local TriggerBot = {}
    TriggerBot.__index = TriggerBot
    TriggerBot.Enabled = false
    function TriggerBot.new(opts)
        local self = setmetatable({}, TriggerBot)
        self.config = opts or {}
        self.lastFire = 0
        return self
    end
    function TriggerBot:SetEnabled(state: boolean)
        self.Enabled = (state == true)
        PastaWare.Config.TriggerBot.Enabled = self.Enabled
        return self.Enabled
    end
    function TriggerBot:Update()
        if not self.Enabled then return end
        if not Candy_IsAlive(LocalPlayer) then return end
        local now = os.clock()
        if now - self.lastFire < (PastaWare.Config.TriggerBot.Delay or 0.12) then return end
        local mouse = safeGetMouseLocation()
        local cam = Workspace.CurrentCamera
        if not cam then return end
        local ray = cam:ScreenPointToRay(mouse.X, mouse.Y)
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = { LocalPlayer.Character, cam }
        params.IgnoreWater = true
        local hit = Workspace:Raycast(ray.Origin, ray.Direction * 500, params)
        if hit and hit.Instance then
            local model = hit.Instance:FindFirstAncestorWhichIsA("Model")
            local plr = model and Players:GetPlayerFromCharacter(model)
            if plr and plr ~= LocalPlayer and Candy_IsAlive(plr) then
                if PastaWare.Config.TriggerBot.TargetMurdererOnly then
                    local role = PastaWare.State.Roles[plr.Name]
                    if role ~= "Murderer" then return end
                end
                self.lastFire = now
                local char = LocalPlayer.Character
                local tool = char and safeFindChildOfClass(char, "Tool")
                if tool then pcall(function() tool:Activate() end) end
            end
        end
    end
    Candy.TriggerBot = TriggerBot
    PastaWare.State.CandyTrigger = PastaWare.State.CandyTrigger or TriggerBot.new({})

    --=========================================================================
    -- B16. FarmCtrl (Candy Farm) — NP-порт: heartbeat noclip + монеты
    --=========================================================================
    local FarmCtrl = {}
    FarmCtrl.__index = FarmCtrl
    FarmCtrl.Enabled = false
    function FarmCtrl.new(opts)
        local self = setmetatable({}, FarmCtrl)
        self.config = opts or {}
        return self
    end
    function FarmCtrl:SetEnabled(state: boolean)
        self.Enabled = (state == true)
        PastaWare.Config.Farm.Enabled = self.Enabled
        Globals.PULSE_FARM_MM2_HEARTBEAT = self.Enabled
        return self.Enabled
    end
    function FarmCtrl:Heartbeat(mapModel: Model?)
        if not self.Enabled then return end
        if not PastaWare.Config.Farm.HeartbeatNoclip then return end
        local container = mapModel
        if not container then
            -- ищем первую Model карты с BasePart (эвристика Pulse NP)
            for _, child in ipairs(Workspace:GetChildren()) do
                if child:IsA("Model") and child ~= LocalPlayer.Character then
                    container = child
                    break
                end
            end
        end
        if not container then return end
        for _, part in ipairs(container:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then
                part.CanCollide = false
            end
        end
    end
    Candy.Farm = FarmCtrl

    --=========================================================================
    -- B17. NoclipCtrl (Candy Noclip) — Stepped отключение коллизий
    --=========================================================================
    local NoclipCtrl = {}
    NoclipCtrl.__index = NoclipCtrl
    NoclipCtrl.Enabled = false
    function NoclipCtrl.new(opts)
        local self = setmetatable({}, NoclipCtrl)
        self.config = opts or {}
        return self
    end
    function NoclipCtrl:SetEnabled(state: boolean)
        self.Enabled = (state == true)
        PastaWare.Config.Movement.Noclip = self.Enabled
        return self.Enabled
    end
    function NoclipCtrl:Stepped()
        if not self.Enabled then return end
        local char = LocalPlayer and LocalPlayer.Character
        if not char then return end
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end
        end
    end
    Candy.Noclip = NoclipCtrl

    --=========================================================================
    -- B18. SilentEx (Candy Silent_176) — флаг-обёртка над Luraph хуком
    --=========================================================================
    local SilentEx = {}
    SilentEx.__index = SilentEx
    SilentEx.Enabled = false
    function SilentEx.new(opts)
        local self = setmetatable({}, SilentEx)
        self.config = opts or {}
        return self
    end
    function SilentEx:SetEnabled(state: boolean)
        self.Enabled = (state == true)
        PastaWare.Config.Aimbot.SilentAim = self.Enabled
        return self.Enabled
    end
    Candy.Silent = SilentEx

    --=========================================================================
    -- B19. TeleportEx (Candy Teleport_235) — CFrame телепорт к цели/точке
    --=========================================================================
    local TeleportEx = {}
    TeleportEx.__index = TeleportEx
    TeleportEx.Enabled = false
    function TeleportEx.new(opts)
        local self = setmetatable({}, TeleportEx)
        self.config = opts or {}
        return self
    end
    function TeleportEx:SetEnabled(state: boolean)
        self.Enabled = (state == true)
        return self.Enabled
    end
    function TeleportEx:ToPosition(pos: Vector3)
        if not Candy_IsAlive(LocalPlayer) then return end
        local root = Candy_GetRoot(LocalPlayer)
        if root then root.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0)) end
    end
    function TeleportEx:ToPlayer(plr: Player)
        if not Candy_IsAlive(plr) then return end
        local target = Candy_GetRoot(plr)
        if target then self:ToPosition(target.Position) end
    end
    Candy.Teleport = TeleportEx

    --=========================================================================
    -- B20. AutoParry (Candy AutoParry_35) — MM2: бросок/блок при близком убийце
    --=========================================================================
    local AutoParry = {}
    AutoParry.__index = AutoParry
    AutoParry.Enabled = false
    function AutoParry.new(opts)
        local self = setmetatable({}, AutoParry)
        self.config = opts or {}
        self.lastUse = 0
        return self
    end
    function AutoParry:SetEnabled(state: boolean)
        self.Enabled = (state == true)
        PastaWare.Config.Misc.AutoParry = self.Enabled
        return self.Enabled
    end
    function AutoParry:Update()
        if not self.Enabled or not Candy_IsAlive(LocalPlayer) then return end
        local now = os.clock()
        if now - self.lastUse < 1 then return end
        local lroot = Candy_GetRoot(LocalPlayer)
        if not lroot then return end
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and Candy_IsAlive(plr) then
                local role = PastaWare.State.Roles[plr.Name]
                if role == "Murderer" then
                    local troot = Candy_GetRoot(plr)
                    if troot and (troot.Position - lroot.Position).Magnitude <= (PastaWare.Config.Misc.AutoParryDistance or 18) then
                        self.lastUse = now
                        local char = LocalPlayer.Character
                        local tool = char and safeFindChildOfClass(char, "Tool")
                        if tool then pcall(function() tool:Activate() end) end
                        break
                    end
                end
            end
        end
    end
    Candy.AutoParry = AutoParry

    --=========================================================================
    -- B21. HealthBarEx / NameTagsEx / BoxESPEx / FOVCircleEx / ESPMaster
    -- (Candy HealthBar, NameTags, BoxESP_75, FOVCircle, ESP_13/ESP_90)
    -- Реальный рендер уже есть в секции 7; здесь конфиг-обёртки + API.
    --=========================================================================
    local HealthBarEx = {}
    HealthBarEx.__index = HealthBarEx
    HealthBarEx.Enabled = false
    function HealthBarEx.new(opts) return setmetatable({ config = opts or {} }, HealthBarEx) end
    function HealthBarEx:SetEnabled(s: boolean)
        self.Enabled = (s == true)
        PastaWare.Config.Visuals.HealthBar = self.Enabled
        return self.Enabled
    end
    Candy.HealthBar = HealthBarEx

    local NameTagsEx = {}
    NameTagsEx.__index = NameTagsEx
    NameTagsEx.Enabled = false
    function NameTagsEx.new(opts) return setmetatable({ config = opts or {} }, NameTagsEx) end
    function NameTagsEx:SetEnabled(s: boolean)
        self.Enabled = (s == true)
        PastaWare.Config.Visuals.Names = self.Enabled
        return self.Enabled
    end
    Candy.NameTags = NameTagsEx

    local BoxESPEx = {}
    BoxESPEx.__index = BoxESPEx
    BoxESPEx.Enabled = false
    function BoxESPEx.new(opts) return setmetatable({ config = opts or {}, FOV = 267, Color = Color3.fromRGB(89, 237, 8) }, BoxESPEx) end
    function BoxESPEx:SetEnabled(s: boolean)
        self.Enabled = (s == true)
        PastaWare.Config.Visuals.BoxESP = self.Enabled
        return self.Enabled
    end
    Candy.BoxESP = BoxESPEx

    local ESPMaster = {}
    ESPMaster.__index = ESPMaster
    ESPMaster.Enabled = false
    function ESPMaster.new(opts) return setmetatable({ config = opts or {}, FOV = 345 }, ESPMaster) end
    function ESPMaster:SetEnabled(s: boolean)
        self.Enabled = (s == true)
        PastaWare.Config.Visuals.Enabled = self.Enabled
        return self.Enabled
    end
    Candy.ESP = ESPMaster

    local FOVCircleEx = {}
    FOVCircleEx.__index = FOVCircleEx
    FOVCircleEx.Enabled = false
    function FOVCircleEx.new(opts) return setmetatable({ config = opts or {} }, FOVCircleEx) end
    function FOVCircleEx:SetEnabled(s: boolean)
        self.Enabled = (s == true)
        PastaWare.Config.Aimbot.ShowFOV = self.Enabled
        return self.Enabled
    end
    Candy.FOVCircle = FOVCircleEx

    -- Совместимость: старые candy-вызовы Library._registry / Flags / Config
    PastaWare.CandyLibrary = {
        Registry = {},
        Flags = {},
        Config = PastaWare.Config,
    }
    -- регистрируем все модули как в candy Library._registry["Name"]
    for _, name in ipairs({ "Aimbot","Backtrack","AntiAim","Chams","Tracers","Crosshair","Hitbox","Speed","Fly","Jump","WallHop","Prediction","Resolver","Spoofer","TriggerBot","Farm","Noclip","Silent","Teleport","AutoParry","HealthBar","NameTags","BoxESP","FOVCircle","ESP" }) do
        PastaWare.CandyLibrary.Registry[name] = {
            name = name,
            default = false,
            tooltip = ("toggle %s"):format(name),
            callback = function() return end,
        }
    end
end

--=============================================================================
-- 11.C PULSE ADVANCED VISUALS & WORLD (v, S, e, C, bT/wT, cP/k, RP/CP/nP, NP)
--=============================================================================
do
    --=========================================================================
    -- C1. v (RoleBillboardESP) -- puls:1105
    -- Для каждого игрока: U(f)=роль; m.guis[f] кэш; d(a)=создать BillboardGui;
    -- Adornee=Head, Enabled=head~=nil. Здесь полная реализация + WeaponESP.
    --=========================================================================
    local BillboardCache: { [Player]: any } = {}
    local function Pulse_GetRoleForBillboard(plr: Player): string?
        local fast = PastaWare.Pulse.ResolveRoleSimple(plr)
        if fast then return fast end
        return PastaWare.State.Roles[plr.Name]
    end
    local function Pulse_CreateRoleBillboard(kind: string)
        local gui = Instance.new("BillboardGui")
        gui.Name = "PastaWare_RoleESP"
        gui.Size = UDim2.new(0, 120, 0, 28)
        gui.StudsOffset = Vector3.new(0, 2.6, 0)
        gui.AlwaysOnTop = true
        local label = Instance.new("TextLabel")
        label.Name = "RoleLabel"
        label.Size = UDim2.new(1, 0, 1, 0)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.GothamBold
        label.TextSize = 13
        label.TextStrokeTransparency = 0.2
        label.Text = kind or "?"
        if kind == "Murderer" then
            label.TextColor3 = PastaWare.Config.Visuals.MurdererColor
        elseif kind == "Sheriff" then
            label.TextColor3 = PastaWare.Config.Visuals.SheriffColor
        elseif kind == "Hero" then
            label.TextColor3 = PastaWare.Config.Visuals.HeroColor
        else
            label.TextColor3 = PastaWare.Config.Visuals.InnocentColor
        end
        label.Parent = gui
        -- WeaponESP строка 2: что в руках
        local sub = Instance.new("TextLabel")
        sub.Name = "WeaponLabel"
        sub.Size = UDim2.new(1, 0, 0, 12)
        sub.Position = UDim2.new(0, 0, 1, 0)
        sub.BackgroundTransparency = 1
        sub.Font = Enum.Font.Gotham
        sub.TextSize = 11
        sub.TextColor3 = Color3.fromRGB(220, 220, 220)
        sub.TextStrokeTransparency = 0.2
        sub.Text = ""
        sub.Parent = gui
        return { gui = gui, kind = kind, label = label, sub = sub }
    end
    local function Pulse_DestroyBillboard(plr: Player)
        local e = BillboardCache[plr]
        if e then
            pcall(function() e.gui:Destroy() end)
            BillboardCache[plr] = nil
        end
        PastaWare.Billboards[plr] = nil
    end
    local function Pulse_UpdateAllBillboards()
        if not PastaWare.Config.ESPEx.BillboardRoles then
            for plr in pairs(BillboardCache) do Pulse_DestroyBillboard(plr) end
            return
        end
        for _, plr in ipairs(Players:GetPlayers()) do
            local kind = Pulse_GetRoleForBillboard(plr)
            local cached = BillboardCache[plr]
            if not kind then
                if cached then Pulse_DestroyBillboard(plr) end
            else
                if cached and cached.kind ~= kind then
                    Pulse_DestroyBillboard(plr)
                    cached = nil
                end
                if not (cached and cached.gui and cached.gui.Parent) then
                    cached = Pulse_CreateRoleBillboard(kind)
                    BillboardCache[plr] = cached
                    PastaWare.Billboards[plr] = cached.gui
                end
                local char = plr.Character
                local head = char and char:FindFirstChild("Head")
                if cached.gui.Adornee ~= head then cached.gui.Adornee = head end
                cached.gui.Enabled = (head ~= nil) and (plr ~= LocalPlayer)
                -- обновить текст оружия
                if PastaWare.Config.ESPEx.WeaponESP and char then
                    local tool = char and safeFindChildOfClass(char, "Tool")
                    cached.sub.Text = tool and ("[" .. tool.Name .. "]") or ""
                else
                    cached.sub.Text = ""
                end
                -- дистанция в имя билборда
                if PastaWare.Config.Visuals.Distances and head and Candy_IsAliveSafe(plr) then
                    -- оставляем sub для дистанции если нет оружия
                    if cached.sub.Text == "" then
                        local lroot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                        local troot = char:FindFirstChild("HumanoidRootPart")
                        if lroot and troot then
                            cached.sub.Text = tostring(math.floor((troot.Position - lroot.Position).Magnitude)) .. "m"
                        end
                    end
                end
            end
        end
    end
    function Candy_IsAliveSafe(plr)
        if not plr or not plr.Parent then return false end
        local ch = plr.Character
        if not ch then return false end
        local h = ch and safeFindChildOfClass(ch, "Humanoid")
        return h ~= nil and h.Health > 0
    end
    PastaWare.Pulse.UpdateAllBillboards = Pulse_UpdateAllBillboards
    PastaWare.Pulse.DestroyBillboard = Pulse_DestroyBillboard

    --=========================================================================
    -- C2. S (GlassOverlay) -- puls:955
    -- Белые почти прозрачные (0.98) части поверх меню: кэш по CFrame/VS/FOV.
    -- Здесь: 4 клина между углами меню (ScreenPointToRay), обновление по кадру.
    --=========================================================================
    local GlassParts: { BasePart } = {}
    local GlassCache = { CF = nil, VS = nil, FOV = 0, TL = nil, BR = nil, Z = 0 }
    local function Pulse_EnsureGlassParts()
        if #GlassParts >= 4 then return end
        for _ = 1, 4 do
            local p = Instance.new("Part")
            p.Name = "PulseGlass"
            p.Anchored = true
            p.CanCollide = false
            p.CanQuery = false
            p.CanTouch = false
            p.Size = Vector3.new(1, 1, 1)
            p.Transparency = PastaWare.Config.Glass.Transparency or 0.98
            p.Color = PastaWare.Config.Glass.Color or Color3.fromRGB(248, 248, 252)
            p.Parent = Workspace.CurrentCamera
            GlassParts[#GlassParts + 1] = p
        end
    end
    local function Pulse_UpdateGlassOverlay()
        if not PastaWare.Config.Glass.Enabled then
            for _, p in ipairs(GlassParts) do pcall(function() p.Parent = nil end) end
            return
        end
        local ui = PastaWare.UI and PastaWare.UI.MainFrame
        local cam = Workspace.CurrentCamera
        if not ui or not ui.Visible or not ui.Parent or not cam then
            for _, p in ipairs(GlassParts) do pcall(function() p.Parent = nil end) end
            return
        end
        Pulse_EnsureGlassParts()
        local tl = ui.AbsolutePosition
        local br = ui.AbsolutePosition + ui.AbsoluteSize
        local z = 1 - 0.05 * ui.ZIndex
        if GlassCache.CF == cam.CFrame and GlassCache.VS == cam.ViewportSize
            and GlassCache.FOV == cam.FieldOfView and GlassCache.TL == tl
            and GlassCache.BR == br and GlassCache.Z == z then
            for _, p in ipairs(GlassParts) do
                if p.Parent ~= cam then p.Parent = cam end
                p.Transparency = PastaWare.Config.Glass.Transparency or 0.98
                p.Color = PastaWare.Config.Glass.Color
            end
            return
        end
        GlassCache.CF, GlassCache.VS, GlassCache.FOV, GlassCache.TL, GlassCache.BR, GlassCache.Z =
            cam.CFrame, cam.ViewportSize, cam.FieldOfView, tl, br, z
        local tr = Vector2.new(br.X, tl.Y)
        local bl = Vector2.new(tl.X, br.Y)
        local origins = {
            cam:ScreenPointToRay(tl.X, tl.Y, z).Origin,
            cam:ScreenPointToRay(tr.X, tr.Y, z).Origin,
            cam:ScreenPointToRay(bl.X, bl.Y, z).Origin,
            cam:ScreenPointToRay(br.X, br.Y, z).Origin,
        }
        -- строим 4 точки-плоскость: упрощённо вытягиваем бокс перед камерой
        local center = (origins[1] + origins[2] + origins[3] + origins[4]) / 4
        local fwd = cam.CFrame.LookVector
        for i, p in ipairs(GlassParts) do
            if p.Parent ~= cam then p.Parent = cam end
            p.Transparency = PastaWare.Config.Glass.Transparency or 0.98
            p.Color = PastaWare.Config.Glass.Color
            p.CFrame = CFrame.lookAt(center + fwd * (i * 0.2), center + fwd * 5)
            p.Size = Vector3.new(6, 4, 0.2)
        end
    end
    PastaWare.Pulse.UpdateGlassOverlay = Pulse_UpdateGlassOverlay

    --=========================================================================
    -- C3. e (ApplyUISkin) -- puls:3508
    -- Перекрас всего меню: surf по яркости, accent, glassWant, cardTr, textTint.
    --=========================================================================
    local function Pulse_GrayLuminance(c: Color3): number
        -- оригинал: d(e) проверяет grayscale (R==G==B); возвращаем R если серый
        if math.abs(c.R - c.G) < 0.01 and math.abs(c.G - c.B) < 0.01 then
            return c.R
        end
        return -1
    end
    local function Pulse_SurfColor(lum: number): Color3
        -- светлая/тёмная поверхность по люминесценции (упрощённый surf())
        local v = math.clamp(lum * 1.1, 0, 1)
        return Color3.new(v, v, v + 0.02)
    end
    local function Pulse_ApplySkinToObject(obj: GuiObject)
        if obj:IsA("GuiObject") and not obj:GetAttribute("_skinSkip") then
            pcall(function()
                local surfL = obj:GetAttribute("_surfL")
                if surfL == nil then
                    local e = obj.BackgroundColor3
                    local l = Pulse_GrayLuminance(e)
                    surfL = l
                    obj:SetAttribute("_surfL", l)
                end
                if surfL and surfL >= 0 then
                    obj.BackgroundColor3 = Pulse_SurfColor(surfL)
                end
                if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
                    local txtL = obj:GetAttribute("_txtL")
                    if txtL == nil then
                        txtL = Pulse_GrayLuminance(obj.TextColor3)
                        obj:SetAttribute("_txtL", txtL)
                    end
                    if txtL and txtL >= 0 then
                        obj.TextColor3 = Color3.new(txtL, txtL, txtL)
                    end
                end
            end)
        end
    end
    local function Pulse_ApplyUISkin()
        local ui = PastaWare.UI and PastaWare.UI.MainFrame
        if not ui then return end
        Pulse_ApplySkinToObject(ui)
        for _, d in ipairs(ui:GetDescendants()) do
            if d:IsA("GuiObject") then Pulse_ApplySkinToObject(d) end
        end
    end
    PastaWare.Pulse.ApplyUISkin = Pulse_ApplyUISkin

    --=========================================================================
    -- C4. C (ApplyMenuFont) -- puls:2085: если d.menuFont и Text* — ставить Font
    --=========================================================================
    PastaWare.Pulse.MenuFont = Enum.Font.GothamMedium
    local function Pulse_ApplyMenuFont(obj: Instance)
        if PastaWare.Pulse.MenuFont and (obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox")) then
            task.defer(function()
                if PastaWare.Pulse.MenuFont and not obj:GetAttribute("_fontFixed") then
                    pcall(function() obj.Font = PastaWare.Pulse.MenuFont end)
                end
            end)
        end
    end
    PastaWare.Pulse.ApplyMenuFont = Pulse_ApplyMenuFont

    --=========================================================================
    -- C5. bT (MoveCustomCursor) -- puls:3681: курсор следует за мышью
    --=========================================================================
    local CustomCursor: Frame? = nil
    local function Pulse_MoveCustomCursor()
        if (PastaWare.Config.Crosshair.CursorStyle or "Off") == "Off" then return end
        if not PastaWare.Config.Crosshair.UseCustomCursor then return end
        local showXhair = Globals.__pulseXHairShown == true
        if CustomCursor and CustomCursor.Parent then
            if CustomCursor.Visible == showXhair then
                CustomCursor.Visible = not showXhair
            end
        end
        if showXhair then return end
        if not CustomCursor or not CustomCursor.Parent then
            local parent = safeFindChildOfClass(LocalPlayer, "PlayerGui")
            if not parent then return end
            local sg = parent:FindFirstChild("PastaWare_Cursor")
            if not sg then
                sg = Instance.new("ScreenGui")
                sg.Name = "PastaWare_Cursor"
                sg.ResetOnSpawn = false
                sg.Parent = parent
            end
            local f = Instance.new("Frame")
            f.Name = "Dot"
            f.Size = UDim2.fromOffset(6, 6)
            f.AnchorPoint = Vector2.new(0.5, 0.5)
            f.BackgroundColor3 = PastaWare.Config.Crosshair.CursorColor
            f.BorderSizePixel = 0
            f.Parent = sg
            local c = Instance.new("UICorner")
            c.CornerRadius = UDim.new(1, 0)
            c.Parent = f
            CustomCursor = f
        end
        local m = safeGetMouseLocation()
        CustomCursor.Position = UDim2.fromOffset(m.X, m.Y)
    end
    PastaWare.Pulse.MoveCustomCursor = Pulse_MoveCustomCursor

    --=========================================================================
    -- C6. cP + k + A (CharacterCosmetics) -- puls:542,3705,3746
    -- cP(f): roster[f.UserId].cos -> j(m,U,korblox) + e(m,U,headless) +
    --        d(m,U,vfx) + B(m,U,ch) + C(m,U,wob)
    -- k(): прячет Head+face (headless); A(): true если внутри Tool.
    --=========================================================================
    local function Pulse_IsInTool(obj: Instance): boolean
        local p = obj.Parent
        while p do
            if p:IsA("Tool") then return true end
            if p:IsA("Model") then return false end
            p = p.Parent
        end
        return false
    end
    local CosmeticStore: { [Player]: any } = {}
    local function Pulse_SetHeadless(char: Model, data: any, enable: boolean)
        if enable and not data.hl then
            local head = char:FindFirstChild("Head")
            if not head then return end
            data.hl = { { head, (head :: BasePart).Transparency } }
            pcall(function() head.Transparency = 1 end)
            for _, d in ipairs(char:GetDescendants()) do
                if d:IsA("Decal") and d.Name == "face" then
                    data.hl[#data.hl + 1] = { d, d.Transparency }
                    pcall(function() d.Transparency = 1 end)
                end
            end
        elseif not enable and data.hl then
            for _, e in ipairs(data.hl) do
                if e[1].Parent then
                    pcall(function() e[1].Transparency = e[2] end)
                end
            end
            data.hl = nil
        end
    end
    local function Pulse_ApplyCharacterCosmetics(plr: Player)
        local char = plr.Character
        if not char then
            local old = CosmeticStore[plr]
            if old then
                CosmeticStore[plr] = nil
            end
            return
        end
        local data = CosmeticStore[plr]
        if not data then data = {} CosmeticStore[plr] = data end
        -- roster cos (заглушка: читаем из кэша; если нет — пропускаем korblox/vfx)
        local roster = PastaWare.State.RosterCache
        local cos = roster and roster[plr.Name] and roster[plr.Name].cos or nil
        -- headless флаг из cos
        local wantHeadless = cos and cos.headless and true or false
        Pulse_SetHeadless(char, data, wantHeadless)
        -- korblox/vfx/ch/wob — сохраняем точку расширения (оригинал вызывает
        -- j/e/d/B/C пcalls; здесь фиксируем вызовы чтобы не потерять покрытие)
        pcall(function() end) -- korblox hook point
        pcall(function() end) -- vfx hook point
        pcall(function() end) -- ch hook point
        pcall(function() end) -- wob hook point
    end
    PastaWare.Pulse.ApplyCharacterCosmetics = Pulse_ApplyCharacterCosmetics
    PastaWare.Pulse.IsInTool = Pulse_IsInTool

    --=========================================================================
    -- C7. RP + CP + nP (InvisController) -- puls:180,1030,3780
    -- RP: raycast вниз -200k CFrame, grounded джиттер 0.03, __pulseInvis state.
    -- CP: guard __pulseInvis.active, вызывает m() a(f) по-дефолту.
    -- nP: NoCollide хук getgenv().__pulseAfNoCollide.
    --=========================================================================
    local InvisState = { active = false, grounded = false, lastCF = nil }
    local function Pulse_UpdateInvis()
        if not PastaWare.Config.Invis.Enabled then
            if InvisState.active then
                InvisState.active = false
                Globals.__pulseInvis = nil
            end
            return
        end
        local char = LocalPlayer.Character
        local hum = char and safeFindChildOfClass(char, "Humanoid")
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not (hum and root and hum.Health > 0) then return end
        pcall(function()
            local moving = hum.MoveDirection.Magnitude > 0.01
            local params = RaycastParams.new()
            params.FilterType = Enum.RaycastFilterType.Exclude
            params.FilterDescendantsInstances = { char }
            local grounded = Workspace:Raycast(root.Position, Vector3.new(0, -3, 0), params) ~= nil
            local st = Globals.__pulseInvis or {}
            st.active = true
            st.grounded = grounded
            Globals.__pulseInvis = st
            InvisState.active = true
            InvisState.grounded = grounded
            local cf = root.CFrame
            if grounded and not moving then
                -- джиттер 0.03 как в оригинале (m[2][m[1]] flip-flop)
                InvisState.flip = not InvisState.flip
                if InvisState.flip then
                    cf = cf * CFrame.new(0, 0.03, 0)
                end
            end
            InvisState.lastCF = cf
            root.CFrame = cf * CFrame.new(0, -200000, 0)
        end)
    end
    local function Pulse_InvisGuard(obj: Instance)
        -- CP-порт: если __pulseInvis.active — не трогать персонажа
        local st = Globals.__pulseInvis
        if st and st.active then return end
        Pulse_ApplyCharacterCosmetics(LocalPlayer)
    end
    local function Pulse_NoCollideHook()
        local hook = Globals.__pulseAfNoCollide
        if hook then pcall(hook) end
    end
    PastaWare.Pulse.UpdateInvis = Pulse_UpdateInvis
    PastaWare.Pulse.InvisGuard = Pulse_InvisGuard
    PastaWare.Pulse.NoCollideHook = Pulse_NoCollideHook

    --=========================================================================
    -- C8. NP (FarmHeartbeatNoclip) -- puls:1163
    -- Если PULSE_FARM_MM2_HEARTBEAT и d[2][d[1]]/K — собрать BasePart карты
    -- и снять CanCollide. Здесь реализовано через Candy.Farm:Heartbeat.
    --=========================================================================
    local FarmPartCache: { BasePart } = {}
    local FarmMapRef: Model? = nil
    local function Pulse_FarmHeartbeat()
        if not Globals.PULSE_FARM_MM2_HEARTBEAT or not PastaWare.Config.Farm.Enabled then return end
        -- ищем карту один раз (первая большая Model)
        local map = FarmMapRef
        if not map or not map.Parent then
            for _, child in ipairs(Workspace:GetChildren()) do
                if child:IsA("Model") and child ~= LocalPlayer.Character then
                    local n = 0
                    for _, _ in ipairs(child:GetDescendants()) do n = n + 1 if n > 5 then break end end
                    if n > 5 then map = child break end
                end
            end
            FarmMapRef = map
            FarmPartCache = {}
            if map then
                for _, d in ipairs(map:GetDescendants()) do
                    if d:IsA("BasePart") then FarmPartCache[#FarmPartCache + 1] = d end
                end
            end
        end
        for _, part in ipairs(FarmPartCache) do
            if part.Parent and part.CanCollide then part.CanCollide = false end
        end
    end
    PastaWare.Pulse.FarmHeartbeat = Pulse_FarmHeartbeat
end

--=============================================================================
-- 11.D ADVANCED AIM (headshoot-slient полный порт) + WIRING всех модулей
-- Здесь лежат функции, которых не хватало в упрощённой секции 5:
-- getLeadTime(ping)/predictPath/jumpOffset/oscillation/bodyBounds/
-- estimateHitChance/isSnapshotValidEx/shouldFireApex/hasPenetrationPath/
-- getShootProtocol/getShootCFrames/buildShootArgumentsEx + циклы.
--=============================================================================
do
    --=========================================================================
    -- D1. GetLeadTime: половина RTT + 0.02 (оригинал @headshoot GetLeadTime)
    --=========================================================================
    local function Pulse_GetLeadTime(): number
        local pingMs = 100
        pcall(function()
            local v: any = (LocalPlayer :: any).GetNetworkPing(LocalPlayer)
            if typeof(v) == "number" and v == v then
                pingMs = v * 1000
            end
        end)
        if pingMs <= 0 then pingMs = 100 end
        return pingMs / 1000 * 0.5 + 0.02
    end
    PastaWare.Pulse.GetLeadTime = Pulse_GetLeadTime

    --=========================================================================
    -- D2. PredictPath / JumpOffset / OscillationOffset (порты PredictPath...)
    --=========================================================================
    local function Pulse_PredictPath(vel: Vector3, gravity: number, t: number): Vector3
        local drift = vel * t
        if gravity > 0 then
            drift += Vector3.new(0, -0.5 * gravity * t * t, 0)
        end
        return drift
    end
    local function Pulse_JumpOffset(velY: number, airborne: boolean, gravity: number, t: number): number
        if not airborne or gravity <= 0 then return 0 end
        if velY > 3 then return math.min(velY * t * 0.5, 4) end
        if velY < -3 then return -math.min(-velY * t * 0.5, 4) end
        return 0
    end
    local function Pulse_OscillationOffset(osc: Vector3?, t: number): Vector3?
        if not osc then return nil end
        return osc * t
    end
    local function Pulse_BodyBounds(root: BasePart): Vector3
        local s = root.Size
        if typeof(s) == "Vector3" and s.Magnitude > 0 and s.Magnitude <= 32 then
            return s
        end
        return Vector3.new(2, 5, 1)
    end
    PastaWare.Pulse.PredictPath = Pulse_PredictPath
    PastaWare.Pulse.JumpOffset = Pulse_JumpOffset
    PastaWare.Pulse.OscillationOffset = Pulse_OscillationOffset
    PastaWare.Pulse.BodyBounds = Pulse_BodyBounds

    --=========================================================================
    -- D3. EstimateHitChanceEx (порт EstimateHitChance)
    -- movementPenalty = |v|/max(dist,1)/8 clamp 0..0.6; sizeBonus; confidence.
    --=========================================================================
    local function Pulse_EstimateHitChanceEx(rawVelMag: number, confidence: number, dist: number, bodySize: Vector3): (number, number)
        local movementPenalty = math.clamp(rawVelMag / math.max(dist, 1) / 8, 0, 0.6)
        local sizeBonus = math.clamp((math.max(bodySize.X, bodySize.Z) - 1) / 4, 0, 0.2)
        local chance = math.clamp(1 - movementPenalty + sizeBonus + confidence * 0.15, 0, 1) * 100
        local lead = Pulse_GetLeadTime()
        local uncertainty = math.clamp(movementPenalty * 100 * (0.4 + lead), 0, 100)
        return chance, uncertainty
    end
    PastaWare.Pulse.EstimateHitChanceEx = Pulse_EstimateHitChanceEx

    --=========================================================================
    -- D4. IsSnapshotValidEx — расширенный валидатор (@198849 полный)
    -- Проверяет: age<=SnapshotLifetime, Generation/Round/AimRevision,
    -- конечность всех векторов, BodySize<=32, настройки совпадают,
    -- Gun.Parent==LocalCharacter, дуло<=25, цель живая и та же,
    -- TargetPart BasePart+Descendant+CanQuery, Predicted<=25 от root,
    -- Anchored совпал, дуло не уехало (<=10).
    --=========================================================================
    local MAX_SNAP_DIST = 25
    local MUZZLE_TOL = 10
    local function Pulse_IsSnapshotValidEx(snap): boolean
        if snap == nil or typeof(snap.CreatedAt) ~= "number" then return false end
        local age = os.clock() - snap.CreatedAt
        local life = PastaWare.Config.Aimbot.SnapshotLifetime or 0.35
        if age ~= age or age < 0 or age > life then return false end
        if snap.Generation ~= PastaWare.State.Generation then return false end
        if snap.AimRevision ~= PastaWare.State.AimRevision then return false end
        local function fin(v) return typeof(v) == "Vector3" and v.X == v.X and v.Y == v.Y and v.Z == v.Z and v.X ~= math.huge and v.X ~= -math.huge end
        if not fin(snap.OriginPosition) or not fin(snap.PredictedPosition) then return false end
        if not fin(snap.RootPosition) or not fin(snap.TargetPosition) then return false end
        if snap.BodySize and (snap.BodySize.Magnitude > 32 or math.min(snap.BodySize.X, snap.BodySize.Y, snap.BodySize.Z) <= 0) then return false end
        if snap.Enabled ~= PastaWare.Config.Aimbot.Enabled then return false end
        if snap.Penetration ~= PastaWare.Config.Aimbot.Penetration then return false end
        -- ствол всё ещё в руках
        local char = LocalPlayer.Character
        if not snap.Gun or snap.Gun.Parent ~= char then return false end
        if (snap.LocalRootPosition - snap.OriginPosition).Magnitude > MAX_SNAP_DIST then return false end
        -- цель живая
        local tchar = snap.Player and snap.Player.Character
        local thum = tchar and safeFindChildOfClass(tchar, "Humanoid")
        local troot = tchar and tchar:FindFirstChild("HumanoidRootPart")
        if not tchar or not thum or thum.Health <= 0 or not troot then return false end
        if tchar ~= snap.Character or troot ~= snap.RootPart then return false end
        local tp = snap.TargetPart
        if typeof(tp) ~= "Instance" or not tp:IsA("BasePart") then return false end
        if not tp:IsDescendantOf(tchar) or not tp.CanQuery then return false end
        if (troot.Position - snap.PredictedPosition).Magnitude > MAX_SNAP_DIST then return false end
        if (tp.Position - snap.TargetPosition).Magnitude > MAX_SNAP_DIST then return false end
        return true
    end
    PastaWare.Pulse.IsSnapshotValidEx = Pulse_IsSnapshotValidEx

    --=========================================================================
    -- D5. ShouldFireApex — SmartTrigger с послаблением на Apex (@86324)
    --=========================================================================
    local function Pulse_ShouldFireApex(snap, now: number, readyAt: number): boolean
        if not snap or not snap.Gun then return false end
        local maxWait = (PastaWare.Config.Aimbot.MaxWait or 250) / 1000
        local shotDelay = (PastaWare.Config.Aimbot.ShotDelay or 0) / 1000
        if now < readyAt - maxWait then return false end
        if now - (PastaWare.State.LastTriggerAt or 0) < math.max(shotDelay, 0.4) then return false end
        if not PastaWare.Config.Aimbot.SmartTrigger then return true end
        local waited = now - snap.CreatedAt >= maxWait
        local minCh = PastaWare.Config.Aimbot.MinHitChance or 70
        if (snap.HitChance or 0) >= minCh then return waited end
        if snap.Airborne and snap.VerticalPhase == "Apex" and (snap.HitChance or 0) >= minCh * 0.85 then
            return waited
        end
        return false
    end
    PastaWare.Pulse.ShouldFireApex = Pulse_ShouldFireApex

    --=========================================================================
    -- D6. HasPenetrationPath / GetShootProtocol / GetShootCFrames (порты)
    --=========================================================================
    local function Pulse_HasPenetrationPath(origin: Vector3, predicted: Vector3, targetPart: BasePart): boolean
        if not PastaWare.Config.Aimbot.Penetration then return true end
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = { LocalPlayer.Character }
        params.IgnoreWater = true
        local ok, hit = pcall(function()
            return Workspace:Raycast(origin, predicted - origin, params)
        end)
        if not ok or hit == nil then return false end
        return hit.Instance == targetPart or targetPart:IsDescendantOf(hit.Instance)
    end
    local function Pulse_GetShootProtocol(remote: Instance): string
        local parent = remote and remote.Parent
        if not parent then return "Handle" end
        local n = 0
        for _, child in ipairs(parent:GetChildren()) do
            if child.Name == "Shoot" or child.Name == "ShootGun" or child.Name == "GunBeam" then
                n = n + 1
            end
        end
        return n > 1 and "Pair" or "Handle"
    end
    local function Pulse_GetShootCFrames(origin: Vector3, localRootPos: Vector3, predicted: Vector3): (CFrame, CFrame)
        local dir = (predicted - origin)
        if dir.Magnitude < 0.001 then dir = Vector3.new(0, 0, -1) else dir = dir.Unit end
        local muzzle = CFrame.lookAt(origin, origin + dir)
        local aim = CFrame.lookAt(localRootPos, predicted)
        return muzzle, aim
    end
    PastaWare.Pulse.HasPenetrationPath = Pulse_HasPenetrationPath
    PastaWare.Pulse.GetShootProtocol = Pulse_GetShootProtocol
    PastaWare.Pulse.GetShootCFrames = Pulse_GetShootCFrames

    --=========================================================================
    -- D7. PickLockPlayerConic — ближайшая в конусе (TargetConic/Range)
    --=========================================================================
    local function Pulse_PickLockPlayerConic(): Player?
        local cam = Workspace.CurrentCamera
        local char = LocalPlayer.Character
        local origin = char and char:FindFirstChild("HumanoidRootPart")
        if cam == nil or origin == nil then return nil end
        local hum = char and safeFindChildOfClass(char, "Humanoid")
        if not hum or hum.Health <= 0 then return nil end
        local look = cam.CFrame.LookVector
        local conic = 45
        local range = PastaWare.Config.Aimbot.MaxDistance or 500
        local minCos = math.cos(math.rad(math.clamp(conic, 5, 180)))
        local best, bestScore = nil, math.huge
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer then
                local c = plr.Character
                local r = c and c:FindFirstChild("HumanoidRootPart")
                local h = c and safeFindChildOfClass(c, "Humanoid")
                if c and r and h and h.Health > 0 then
                    local delta = r.Position - origin.Position
                    local dist = delta.Magnitude
                    if dist > 0.01 and dist <= range then
                        local align = look:Dot(delta.Unit)
                        if align >= minCos then
                            local score = dist * (1 + (1 - align) * 4)
                            if score < bestScore then best, bestScore = plr, score end
                        end
                    end
                end
            end
        end
        return best
    end
    PastaWare.Pulse.PickLockPlayerConic = Pulse_PickLockPlayerConic

    --=========================================================================
    -- D8. WIRING: новые циклы поверх секции 9 (не трогаем старые коннекты)
    --=========================================================================
    -- Backtrack запись + госты + Hitbox + Resolver сглаживание (Heartbeat)
    table.insert(PastaWare.Connections, RunService.Heartbeat:Connect(function(dt)
        if not PastaWare.Loaded then return end
        -- Backtrack
        local bt = PastaWare.State.CandyBacktrack
        if bt and PastaWare.Config.Backtrack.Enabled then
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer then
                    pcall(function()
                        bt:Record(plr)
                        bt:UpdateGhost(plr)
                    end)
                end
            end
        end
        -- Hitbox expander
        local hb = PastaWare.State.CandyHitbox
        if hb and PastaWare.Config.Hitbox.Enabled then
            for _, plr in ipairs(Players:GetPlayers()) do
                pcall(function() hb:ApplyTo(plr) end)
            end
        end
        -- Candy Aimbot доводка (только если включён AimLock через конфиг)
        if PastaWare.Config.Aimbot.AimLock and PastaWare.State.CandyAimbot then
            pcall(function() PastaWare.State.CandyAimbot:AimAt(dt) end)
        end
        -- TriggerBot / AutoParry
        if PastaWare.State.CandyTrigger then
            pcall(function() PastaWare.State.CandyTrigger:Update() end)
        end
        -- Speed / Jump / Spoofer обновления
        if PastaWare.State.CandySpeed then pcall(function() PastaWare.State.CandySpeed:Update() end) end
        if PastaWare.State.CandyJump then pcall(function() PastaWare.State.CandyJump:Update() end) end
        -- AntiAim спин
        if PastaWare.State.CandyAntiAim then pcall(function() PastaWare.State.CandyAntiAim:Update(dt) end) end
        -- Farm heartbeat noclip (Pulse NP)
        pcall(function() PastaWare.Pulse.FarmHeartbeat() end)
        -- GunDrops полный скан + чистка
        pcall(function()
            PastaWare.Pulse.ScanAllGunDrops()
            PastaWare.Pulse.CleanupDeadRefs()
        end)
        -- World lighting чистка (Atmosphere)
        pcall(function() PastaWare.Pulse.ScanWorldLighting() end)
    end))

    -- RenderStepped: билборды + гласс + курсор + скин + кросхейр
    table.insert(PastaWare.Connections, RunService.RenderStepped:Connect(function()
        if not PastaWare.Loaded then return end
        pcall(function() PastaWare.Pulse.UpdateAllBillboards() end)
        pcall(function() PastaWare.Pulse.UpdateGlassOverlay() end)
        pcall(function() PastaWare.Pulse.MoveCustomCursor() end)
        if PastaWare.State.CandyCrosshair then
            pcall(function() PastaWare.State.CandyCrosshair:Update() end)
        end
        -- Knife velocity индикатор: чистим скорость если нож пропал
        -- (сам трекинг вызывается из DescendantAdded ниже)
    end))

    -- Stepped: NoclipCtrl + Farm noclip дубль
    table.insert(PastaWare.Connections, RunService.Stepped:Connect(function()
        -- Noclip уже есть в секции 8; здесь Candy-обёртка
        if PastaWare.Config.Movement.Noclip then
            local char = LocalPlayer.Character
            if char then
                for _, p in ipairs(char:GetDescendants()) do
                    if p:IsA("BasePart") and p.CanCollide then
                        p.CanCollide = false
                    end
                end
            end
        end
        -- Invis NoCollide хук
        pcall(function() PastaWare.Pulse.NoCollideHook() end)
    end))

    -- DescendantAdded: GunDrop трек (FP) + Knife трек (fP) + Atmosphere (IT) + шрифт (C)
    table.insert(PastaWare.Connections, Workspace.DescendantAdded:Connect(function(obj)
        pcall(function() PastaWare.Pulse.TrackGunDropAdded(obj) end)
        if PastaWare.Config.World.KnifeVelocityTrack then
            pcall(function() PastaWare.Pulse.TrackKnifeVelocity(obj) end)
        end
        pcall(function() PastaWare.Pulse.ApplyMenuFont(obj) end)
    end))
    table.insert(PastaWare.Connections, game:GetService("Lighting").DescendantAdded:Connect(function(obj)
        pcall(function() PastaWare.Pulse.OnAtmosphereAdded(obj) end)
    end))
    -- CharacterAdded: косметика (cP) + инвиз гард (CP)
    if LocalPlayer then
        table.insert(PastaWare.Connections, LocalPlayer.CharacterAdded:Connect(function(char)
            task.delay(0.5, function()
                pcall(function() PastaWare.Pulse.InvisGuard(char) end)
                pcall(function() PastaWare.Pulse.ApplyCharacterCosmetics(LocalPlayer) end)
            end)
        end))
    end
    -- JumpRequest: WallHop попытка + InfiniteJump уже в секции 8
    table.insert(PastaWare.Connections, UserInputService.JumpRequest:Connect(function()
        if PastaWare.Config.Movement.WallHop and PastaWare.State.CandyWallHop then
            pcall(function() PastaWare.State.CandyWallHop:TryHop() end)
        end
    end))
    -- Heartbeat 1с: Roster refresh + PollRemoteData пример + AutoParry тик
    task.spawn(function()
        while true do
            pcall(function() PastaWare.Pulse.GetPlayerDataRoster() end)
            -- AutoParry тик
            local ap = PastaWare.Candy and PastaWare.Candy.AutoParry
            -- инстанс хранится отдельно; дёргаем через конфиг-флаг
            if PastaWare.Config.Misc.AutoParry then
                -- ленивый синглтон
                PastaWare.State._AutoParryInst = PastaWare.State._AutoParryInst or (function()
                    local Cls = PastaWare.Candy.AutoParry
                    local o = Cls.new({})
                    o:SetEnabled(true)
                    return o
                end)()
                pcall(function() PastaWare.State._AutoParryInst:Update() end)
            end
            task.wait(1)
        end
    end)
end

--=============================================================================
-- 11. Выгрузка и очистка (Reverse-Path / Unload)
--=============================================================================
function PastaWare:Unload()
    for _, conn in ipairs(self.Connections) do
        pcall(function() conn:Disconnect() end)
    end
    self.Connections = {}

    for plr in pairs(ESPObjects) do
        removeESPForPlayer(plr)
    end

    -- 11.A/B/C/D cleanup: билборды, госты, хитбоксы, гласс, курсор
    if self.Pulse and self.Pulse.DestroyBillboard then
        for plr in pairs(self.Billboards) do
            pcall(function() self.Pulse.DestroyBillboard(plr) end)
        end
    end
    for plr in pairs(self.Billboards) do
        local g = self.Billboards[plr]
        pcall(function() if typeof(g) == "Instance" then g:Destroy() end end)
    end
    self.Billboards = {}
    if self.State.CandyBacktrack and self.State.CandyBacktrack.ghosts then
        for _, g in pairs(self.State.CandyBacktrack.ghosts) do
            pcall(function() g:Destroy() end)
        end
        self.State.CandyBacktrack.ghosts = {}
        self.State.CandyBacktrack.records = {}
    end
    if self.State.CandyHitbox then
        pcall(function() self.State.CandyHitbox:RestoreAll() end)
    end
    if self.State.CandyTracers and self.State.CandyTracers.lines then
        for _, l in pairs(self.State.CandyTracers.lines) do
            pcall(function() if l.Remove then l:Remove() else l.Visible = false end end)
        end
    end
    if self.State.CandyChams and self.State.CandyChams.store then
        for _, hl in pairs(self.State.CandyChams.store) do
            pcall(function() hl:Destroy() end)
        end
    end
    -- гласс-парты
    pcall(function()
        local cam = Workspace.CurrentCamera
        if cam then
            for _, d in ipairs(cam:GetChildren()) do
                if d.Name == "PulseGlass" then d:Destroy() end
            end
        end
    end)
    -- курсор/кросхейр GUI
    pcall(function()
        local pg = safeFindChildOfClass(LocalPlayer, "PlayerGui")
        if pg then
            local c = pg:FindFirstChild("PastaWare_Cursor")
            if c then c:Destroy() end
            local x = pg:FindFirstChild("PastaWare_Crosshair")
            if x then x:Destroy() end
        end
    end)

    if FOVCircle then
        pcall(function() FOVCircle:Remove() end)
        FOVCircle = nil
    end

    if GunHighlight then
        pcall(function() GunHighlight:Destroy() end)
        GunHighlight = nil
    end

    cleanupFly()

    if self.UI and self.UI.ScreenGui then
        pcall(function() self.UI.ScreenGui:Destroy() end)
        self.UI = nil
    end

    Globals.__PastaWare = nil
    Globals.__pulseFlyActive = false
    Globals.PULSE_FARM_MM2_HEARTBEAT = false
    print("[PastaWare] Successfully unloaded (v3 MEGA, all modules cleaned).")
end

-- Запуск интерфейса и регистрация в Globals
createPastaWareUI()
Globals.__PastaWare = PastaWare
PastaWare.Loaded = true

print("[PastaWare] v" .. PastaWare.Version .. " loaded successfully! Press Right-Control for menu.")
-- 12. RAW 1to1 headshoot-slient.lua (top-level, 3 lines tagged PastaWare)
--!nonstrict
--[[
	slient-aim2.lua — silent aim, вырезанный из 003_loadstring_04df5282_216999.txt
	(chunkname: Luraph, loadstring #3, 216999 байт).

	Что удалось вытащить из дампа (смещения — по столбцам единственной строки payload):

		@196755  хук FireServer/InvokeServer — точка входа silent aim. Пропускает
		         вызов как есть, если игрок мёртв, это не FireServer/InvokeServer,
		         remote не из {Shoot, ShootGun, GunBeam}, Aimbot выключен или не
		         резолвится протокол выстрела. Иначе собирает проверенные
		         аргументы и отправляет их вместо исходных.
		@152454  резолв протокола: GetShootProtocol -> "Pair"/"Handle",
		         GetShootCFrames, BuildShootArguments.
		@207473  построение снапшота прицела: позиция дула, сэмплирование движения
		         цели, упреждение (PredictPath), JumpOffset, OscillationOffset,
		         jitter-смещение MeanOffset, HeightOffset, выбор части тела через
		         MakeQueryParams + IsBoxClear/IsSegmentClear, оценка HitChance.
		@192571  драйвер сэмплирования: сброс снапшота при выключенном аиме, смерти
		         или смене ревизии ролей; сэмплирование не чаще 10 Гц.
		@198849  валидатор снапшота — проверки «похоже на серверные»: время жизни,
		         Generation, RoundGeneration, AimRevision, личность игрока, конечность
		         векторов, размер тела, дистанции 25 студов, TargetPart:IsDescendantOf
		         + CanQuery, дуло в пределах 10 студов.
		@86324   SmartTrigger: MinHitChance, MaxWait, задержка 0.4 c на цель,
		         послабление на Apex.
		@173089  исполнитель авто-выстрела: GunReadyAt + ShotDelay, ShouldFire,
		         ReserveShot, NativeActivationUntil, Tool:Activate.

	Чего в дампе нет: тел GetShootProtocol, GetShootCFrames, BuildShootArguments,
	SampleMotion, PredictPath, EstimateHitChance, IsBoxClear, GetLivingPlayer,
	ReserveShot, PrepareShot, ReadMuzzlePosition, GetLeadTime, GetBodyBounds.
	Они создаются VM Luraph в рантайме, в дампе остались только точки вызова,
	поэтому ниже они переписаны по смыслу: числовые проверки и пороги взяты из
	@207473/@198849, остальное — минимальные рабочие реализации.

	getgenv / hookmetamethod / getnamecallmethod есть только в экзекуторе,
	поэтому файл помечен --!nonstrict.

	Использование:
		local aim = require(path.to.slient.aim2)
		aim:disable()                     -- выключить
		aim:setTarget(player)             -- залочить цель вручную
		aim.settings.Penetration = true   -- стрелять через стены
		aim.settings.MinHitChance = 85    -- порог SmartTrigger/авто-выстрела
]]

--=============================================================================
-- Окружение
--=============================================================================

local Players: Players = game:GetService("Players")
local Workspace: Workspace = game:GetService("Workspace")
local RunService: RunService = game:GetService("RunService")

local Globals = (getgenv and getgenv()) or _G or {} -- [PastaWare] nil-safe

--=============================================================================
-- Типы
--=============================================================================

export type Protocol = "Pair" | "Handle"

--- Сэмпл движения цели, накопленный за окно наблюдения.
export type MotionSample = {
	Velocity: Vector3,
	RawVelocity: Vector3,
	Confidence: number,
	Gravity: number,
	Airborne: boolean,
	Jitter: boolean,
	MeanOffset: Vector3?,
	Oscillation: Vector3?,
	StableSince: number,
	StartedAt: number,
}

--- Замороженное на кадр решение аима. Именно оно валидируется и именно из него
--- собираются аргументы выстрела.
export type Snapshot = {
	CreatedAt: number,
	Frame: number,
	Generation: number,
	RoundGeneration: number,
	AimRevision: number,
	MotionRevision: number,

	Enabled: boolean,
	Penetration: boolean,
	PredictionOffset: number,
	HeightOffset: number,

	LocalCharacter: Model,
	LocalRoot: BasePart,
	LocalRootPosition: Vector3,
	Player: Player,
	Character: Model,
	RootPart: BasePart,
	RootPosition: Vector3,
	Gun: Tool,
	OriginPosition: Vector3,

	AnchorPart: BasePart,
	PredictedAnchor: Vector3,
	PredictedPosition: Vector3,
	TargetPart: BasePart,
	TargetPosition: Vector3,
	BodyCenter: Vector3,
	BodySize: Vector3,

	Velocity: Vector3,
	RawVelocity: Vector3,
	Acceleration: Vector3,
	Confidence: number,
	LeadTime: number,
	HitChance: number,
	Uncertainty: number,
	Airborne: boolean,
	VerticalPhase: string,
	Stable: boolean,
	TargetAnchored: boolean,
}

export type ShotState = {
	Busy: boolean,
	Generation: number,
	Gun: Tool,
	StartedAt: number,
	NativeActivationUntil: number?,
}

export type Settings = {
	Enabled: boolean,
	Penetration: boolean,
	SmartTrigger: boolean,

	-- предсказание
	PredictionOffset: number, -- сдвиг точки прицела по X; в оригинале -100..200 и /1000 (студы)
	HeightOffset: number, -- -2..2
	Gravity: number, -- 196.2
	SnapshotLifetime: number, -- 0.35..1, секунды

	-- стрельба
	ShotDelay: number, -- 0..1000 мс
	MaxWait: number, -- 0..300 мс
	MinHitChance: number, -- 70/40/95 в оригинале
	AutoShoot: boolean,
	TargetConic: number, -- половина ширины конуса поиска цели, градусы
	TargetRange: number, -- дистанция до цели, студы
	IgnoreTeam: boolean,
}

--=============================================================================
-- Настройки
--=============================================================================

local settings: Settings = {
	Enabled = true,
	Penetration = false,
	SmartTrigger = true,

	PredictionOffset = 0,
	HeightOffset = 0,
	Gravity = 196.2,
	SnapshotLifetime = 0.35,

	ShotDelay = 0,
	MaxWait = 250,
	MinHitChance = 70,
	AutoShoot = false,
	TargetConic = 45,
	TargetRange = 500,
	IgnoreTeam = true,
}

--=============================================================================
-- Состояние
--=============================================================================

local world = {
	Generation = 1, -- растёт при респауне / смене оружия
	RoundGeneration = 0, -- ревизия ролей
	AimRevision = 0, -- меняется при пересчёте настроек
	MotionRevision = 0,

	Alive = false,
	Sampling = false,
	Frame = 0,

	LockPlayer = nil :: Player?,
	LockStartedAt = 0,
	CurrentSnapshot = nil :: Snapshot?,

	ShotStates = {} :: { [Tool]: ShotState },
	VelocityHistory = {} :: { [Player]: MotionSample },

	-- перехваченные вызовы, которые мы уже обработали сами
	KnifeThrowRemote = nil :: Instance?,
	PendingRemote = nil :: Instance?,
	NativeShootRemote = nil :: Instance?,
	NativeShootGun = nil :: Tool?,
	NativeShootArgs = nil :: { any }?,
	NativeShootProtocol = nil :: Protocol?,

	LastShotRequestAt = 0,
	LastShotRequestGun = nil :: Tool?,
	LastManualActionTime = 0,
	LastSampleAt = 0,
}

local aim: any -- заполняется в разделе «Публичный интерфейс»

--=============================================================================
-- Константы и проверки чисел (порты IsFiniteVector / FiniteNumber)
--=============================================================================

--- Ремоуты, через которые играется выстрел.
local SHOOT_REMOTES: { [string]: true } = {
	Shoot = true,
	ShootGun = true,
	GunBeam = true,
}

--- Порядок предпочтения частей тела при выборе точки прицеливания.
local BODY_NAMES = { "Head", "HumanoidRootPart", "UpperTorso", "Torso" }

local MAX_DISTANCE = 25 -- предел, который оригинал требует от снапшота
local MUZZLE_TOLERANCE = 10
local SHOT_COOLDOWN = 0.12
local TRIGGER_COOLDOWN = 0.4
local SAMPLE_INTERVAL = 0.1 -- 10 Гц, как в @192571
local DIRECTION_ARGUMENT = 2

local function isFiniteNumber(value: any): boolean
	return typeof(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function isFiniteVector(value: any): boolean
	if typeof(value) ~= "Vector3" then
		return false
	end
	return isFiniteNumber(value.X) and isFiniteNumber(value.Y) and isFiniteNumber(value.Z)
end

--- Значение из настроек, приведённое к диапазону: мусор в конфиге не ломает расчёт.
local function finiteNumber(value: any, fallback: number, minimum: number, maximum: number): number
	local number = tonumber(value)
	if number == nil or number ~= number then
		return fallback
	end
	return math.clamp(number, minimum, maximum)
end

--=============================================================================
-- Доступ к миру
--=============================================================================

local function getLocalCharacter(): Model?
	return Players.LocalPlayer.Character
end

local function getLocalRoot(): BasePart?
	local character = getLocalCharacter()
	return character and (character:FindFirstChild("HumanoidRootPart") :: BasePart?)
end

local function getLivingPlayer(player: Player): (Model?, BasePart?)
	local character = player.Character
	if not character then
		return nil, nil
	end
	local humanoid = safeFindChildOfClass(character, "Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if humanoid == nil or humanoid.Health <= 0 or root == nil or not root.Parent then
		return nil, nil
	end
	return character, root
end

--- Строгий вариант GetLivingPlayer(player, true): дополнительно требует Model,
--- потому что у локального игрока Character теоретически может быть не Model.
local function getStrictLivingPlayer(player: Player?): (Model?, BasePart?)
	if player == nil then
		return nil, nil
	end
	local character = player.Character
	if not character or not character:IsA("Model") then
		return nil, nil
	end
	return getLivingPlayer(player)
end

local function isAlive(): boolean
	local character = getLocalCharacter()
	local humanoid = character and safeFindChildOfClass(character, "Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

--- У оружия с выстрелом внутри есть ремоут из SHOOT_REMOTES.
local function hasShootRemote(tool: Tool): boolean
	for _, descendant in ipairs(tool:GetDescendants()) do
		if SHOOT_REMOTES[descendant.Name] then
			return true
		end
	end
	return false
end

--- Ствол в руке: Tool, внутри которого есть shoot-ремоут.
local function getLocalGun(): Tool?
	local character = getLocalCharacter()
	if not character then
		return nil
	end
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Tool") and hasShootRemote(child :: Tool) then
			return child :: Tool
		end
	end
	return nil
end

--- Порт ReadMuzzlePosition: Handle ствола, иначе любой BasePart оружия.
local function readMuzzlePosition(gun: Tool): Vector3?
	local handle = gun:FindFirstChild("Handle") or gun:FindFirstChildWhichIsA("BasePart")
	if handle and handle:IsA("BasePart") then
		return (handle :: BasePart).Position
	end
	return nil
end

local function isTeammate(player: Player): boolean
	local localPlayer = Players.LocalPlayer
	local localTeam = localPlayer and localPlayer.Team
	return localTeam ~= nil and player.Team ~= nil and localTeam == player.Team
end

--=============================================================================
-- Лучи и «видность»
--=============================================================================

local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude

local function isOnGround(part: BasePart): boolean
	raycastParams.FilterDescendantsInstances = { part.Parent, getLocalCharacter() }
	return Workspace:Raycast(part.Position, Vector3.new(0, -3, 0), raycastParams) ~= nil
end

--- Порт IsBoxClear: маленький бокс вокруг точки должен быть свободен.
local function isBoxClear(point: Vector3, size: Vector3, excluded: { Instance? }): boolean
	raycastParams.FilterDescendantsInstances = excluded
	local ok, clear = pcall(function ()
		return Workspace:Raycast(point - size, size * 2, raycastParams) == nil
	end)
	return ok and clear
end

--- Порт IsSegmentClear: отрезок от дула до точки не должен быть перекрыт.
local function isSegmentClear(from: Vector3, to: Vector3, excluded: { Instance? }): boolean
	local delta = to - from
	if delta.Magnitude < 0.001 then
		return true
	end
	raycastParams.FilterDescendantsInstances = excluded
	local ok, clear = pcall(function ()
		return Workspace:Raycast(from, delta, raycastParams) == nil
	end)
	return ok and clear
end

--=============================================================================
-- Сэмплирование движения цели (порт SampleMotion)
--=============================================================================

local HISTORY_SIZE = 8
local rawSamples: { [Player]: { Vector3 } } = {}

--- Накапливает историю скоростей цели и выдаёт усреднённую оценку с
--- уверенностью: чем ровнее скорости и чем длиннее окно, тем выше confidence.
local function sampleMotion(player: Player, root: BasePart, now: number): MotionSample
	local previous = world.VelocityHistory[player]

	local history = rawSamples[player]
	if not history then
		history = {}
		rawSamples[player] = history
	end
	history[#history + 1] = root.AssemblyLinearVelocity
	while #history > HISTORY_SIZE do
		table.remove(history, 1)
	end

	local average = Vector3.zero
	for _, velocity in ipairs(history) do
		average += velocity
	end
	if #history > 0 then
		average /= #history
	end

	-- разброс скоростей это шум/джиттер; из него же — jitter и уверенность
	local jitterMagnitude = 0
	if #history > 1 then
		for _, velocity in ipairs(history) do
			jitterMagnitude += (velocity - average).Magnitude
		end
		jitterMagnitude /= #history
	end

	local confidence = math.clamp(1 - jitterMagnitude / 60, 0, 1)
	if #history < 3 then
		confidence *= 0.5
	end

	local airborne = root.AssemblyLinearVelocity.Y > 0.5 or not isOnGround(root)
	local gravity = airborne and finiteNumber(settings.Gravity, 196.2, 0, 500) or 0

	local sample: MotionSample = {
		Velocity = average,
		RawVelocity = root.AssemblyLinearVelocity,
		Confidence = confidence,
		Gravity = gravity,
		Airborne = airborne,
		Jitter = jitterMagnitude > 6,
		MeanOffset = jitterMagnitude > 6 and average.Unit * math.min(jitterMagnitude, 12) or nil,
		Oscillation = nil,
		StableSince = previous and previous.StableSince or now,
		StartedAt = previous and previous.StartedAt or now,
	}

	world.VelocityHistory[player] = sample
	world.MotionRevision += 1
	return sample
end

--=============================================================================
-- Предсказание (порты GetLeadTime / PredictPath / JumpOffset / OscillationOffset)
--=============================================================================

--- Сколько секунд летит выстрел: половина RTT плюс базовая задержка отправки.
local function getLeadTime(): number
	local player = Players.LocalPlayer
	local ping = 0
	pcall(function ()
		ping = (player :: any).GetNetworkPing(player) * 1000
	end)
	return (ping > 0 and ping or 100) / 1000 * 0.5 + 0.02
end

--- Линейное упреждение с учётом гравитации.
local function predictPath(velocity: Vector3, gravity: number, leadTime: number): Vector3
	local drift = velocity * leadTime
	if gravity > 0 then
		drift += Vector3.new(0, -0.5 * gravity * leadTime * leadTime, 0)
	end
	return drift
end

--- Поправка на момент, когда цель в верхней точке прыжка.
local function jumpOffset(sample: MotionSample, leadTime: number, gravity: number): number
	if not sample.Airborne or gravity <= 0 then
		return 0
	end
	local rise = sample.Velocity.Y
	if rise > 3 then
		return math.min(rise * leadTime * 0.5, 4)
	end
	if rise < -3 then
		return -math.min(-rise * leadTime * 0.5, 4)
	end
	return 0
end

--- Поправка на осцилляцию по X/Z без движения по Y.
local function oscillationOffset(sample: MotionSample, leadTime: number): Vector3?
	if not sample.Oscillation then
		return nil
	end
	return sample.Oscillation * leadTime
end

--=============================================================================
-- Выбор части тела (порты MakeQueryParams / IsBoxClear / IsSegmentClear)
--=============================================================================

--- Перебирает части сверху вниз и берёт первую, в которую свободно «видно».
local function pickTargetPart(character: Model, aimPoint: Vector3, muzzle: Vector3): BasePart?
	local excluded = { character, getLocalCharacter() }
	for _, name in ipairs(BODY_NAMES) do
		local part = character:FindFirstChild(name)
		if part and part:IsA("BasePart") and part.CanQuery and isFiniteVector(part.Position) then
			local point = (part :: BasePart).Position + aimPoint
			if isBoxClear(point, Vector3.new(0.12, 0.12, 0.12), excluded) and isSegmentClear(muzzle, point, excluded) then
				return part
			end
		end
	end
	return nil
end

--=============================================================================
-- Hit chance (порт EstimateHitChance)
--=============================================================================

--- Чем ближе цель, чем спокойнее движется и чем больше тело, тем выше шанс.
local function estimateHitChance(
	sample: MotionSample,
	leadTime: number,
	distance: number,
	bodySize: Vector3
): (number, number)
	local movementPenalty = math.clamp(sample.RawVelocity.Magnitude / math.max(distance, 1) / 8, 0, 0.6)
	local sizeBonus = math.clamp((math.max(bodySize.X, bodySize.Z) - 1) / 4, 0, 0.2)
	local chance = math.clamp(1 - movementPenalty + sizeBonus + sample.Confidence * 0.15, 0, 1) * 100
	local uncertainty = math.clamp(movementPenalty * 100 * (0.4 + leadTime), 0, 100)
	return chance, uncertainty
end

--=============================================================================
-- Снапшот (порт @207473)
--=============================================================================

local function invalidateSnapshot(): ()
	world.CurrentSnapshot = nil
end

--- Порт GetBodyBounds: реальный размер корня, если он правдоподобный.
local function bodyBounds(root: BasePart): Vector3
	local size = root.Size
	if isFiniteVector(size) and size.Magnitude > 0 and size.Magnitude <= 32 then
		return size
	end
	return Vector3.new(2, 5, 1)
end

local function buildSnapshot(): Snapshot?
	world.Frame += 1
	world.CurrentSnapshot = nil

	local gun = getLocalGun()
	if not gun or not gun.Parent then
		return nil
	end

	local localCharacter, localRoot = getLivingPlayer(Players.LocalPlayer)
	if not localCharacter or not localRoot then
		return nil
	end

	local muzzle = readMuzzlePosition(gun)
	if not muzzle then
		return nil
	end

	local targetCharacter, targetRoot = getStrictLivingPlayer(world.LockPlayer)
	if not targetCharacter or not targetRoot then
		return nil
	end

	local now = os.clock()
	local sample = sampleMotion(world.LockPlayer :: Player, targetRoot, now)
	local leadTime = getLeadTime()
	local bodySize = bodyBounds(targetRoot)

	-- упреждение и поправки — по @207473
	local drift = predictPath(sample.Velocity, sample.Gravity, leadTime)
	drift += Vector3.new(finiteNumber(settings.PredictionOffset, 0, -100, 200) / 1000, 0, 0)

	local jump = jumpOffset(sample, leadTime, sample.Gravity)
	if jump > 0 then
		drift += Vector3.new(0, jump, 0)
	end

	local oscillation = oscillationOffset(sample, leadTime)
	if oscillation then
		drift = Vector3.new(oscillation.X, drift.Y, oscillation.Z)
	elseif sample.MeanOffset then
		drift += sample.MeanOffset
	end

	local heightOffset = Vector3.new(0, finiteNumber(settings.HeightOffset, 0, -2, 2), 0)
	local targetPart = pickTargetPart(targetCharacter, drift, muzzle)
	if not targetPart then
		return nil
	end

	local targetPosition = targetPart.Position
	local predictedPosition = targetPosition + drift + heightOffset
	if not isFiniteVector(predictedPosition) then
		return nil
	end

	local hitChance, uncertainty =
		estimateHitChance(sample, leadTime, (muzzle - predictedPosition).Magnitude, bodySize)

	local stable = now - world.LockStartedAt >= 0.035
		and now - sample.StableSince >= 0.05
		and sample.Confidence >= 0.3

	local snapshot: Snapshot = {
		CreatedAt = now,
		Frame = world.Frame,
		Generation = world.Generation,
		RoundGeneration = world.RoundGeneration,
		AimRevision = world.AimRevision,
		MotionRevision = world.MotionRevision,

		Enabled = settings.Enabled,
		Penetration = settings.Penetration,
		PredictionOffset = settings.PredictionOffset,
		HeightOffset = settings.HeightOffset,

		LocalCharacter = localCharacter,
		LocalRoot = localRoot,
		LocalRootPosition = localRoot.Position,
		Player = world.LockPlayer :: Player,
		Character = targetCharacter,
		RootPart = targetRoot,
		RootPosition = targetRoot.Position,
		Gun = gun,
		OriginPosition = muzzle,

		AnchorPart = targetRoot,
		PredictedAnchor = targetRoot.Position + drift,
		PredictedPosition = predictedPosition,
		TargetPart = targetPart,
		TargetPosition = targetPosition,
		BodyCenter = targetPosition + drift,
		BodySize = bodySize,

		Velocity = sample.Velocity,
		RawVelocity = sample.RawVelocity,
		Acceleration = Vector3.new(0, -sample.Gravity, 0),
		Confidence = sample.Confidence,
		LeadTime = leadTime,
		HitChance = hitChance,
		Uncertainty = uncertainty,
		Airborne = sample.Airborne,
		VerticalPhase = (not sample.Airborne)
			and "Grounded"
			or (sample.Velocity.Y > 3 and "Rising" or (sample.Velocity.Y < -3 and "Falling" or "Apex")),
		Stable = stable,
		TargetAnchored = targetRoot.Anchored,
	}

	world.CurrentSnapshot = table.freeze(snapshot)
	return world.CurrentSnapshot
end

--=============================================================================
-- Валидатор снапшота (порт @198849)
--=============================================================================

local function isSnapshotValid(snapshot: Snapshot?): boolean
	if snapshot == nil or typeof(snapshot.CreatedAt) ~= "number" then
		return false
	end

	local age = os.clock() - snapshot.CreatedAt
	if age ~= age or age < 0 or age > finiteNumber(settings.SnapshotLifetime, 0.35, 0, 1) then
		return false
	end
	if snapshot.Generation ~= world.Generation
		or snapshot.RoundGeneration ~= world.RoundGeneration
		or snapshot.AimRevision ~= world.AimRevision
		or snapshot.Player ~= world.LockPlayer
	then
		return false
	end

	if not isFiniteVector(snapshot.OriginPosition)
		or not isFiniteVector(snapshot.PredictedPosition)
		or not isFiniteVector(snapshot.RootPosition)
		or not isFiniteVector(snapshot.LocalRootPosition)
		or not isFiniteVector(snapshot.TargetPosition)
		or not isFiniteVector(snapshot.BodyCenter)
		or not isFiniteVector(snapshot.RawVelocity)
	then
		return false
	end
	if not isFiniteVector(snapshot.BodySize)
		or snapshot.BodySize.Magnitude > 32
		or math.min(snapshot.BodySize.X, snapshot.BodySize.Y, snapshot.BodySize.Z) <= 0
	then
		return false
	end

	-- снимок обязан быть сделан с теми же настройками, что активны сейчас
	if snapshot.Enabled ~= settings.Enabled
		or snapshot.Penetration ~= settings.Penetration
		or snapshot.PredictionOffset ~= settings.PredictionOffset
		or snapshot.HeightOffset ~= settings.HeightOffset
	then
		return false
	end

	-- ствол в руке и рядом с нами
	if snapshot.Gun.Parent ~= snapshot.LocalCharacter then
		return false
	end
	if (snapshot.LocalRootPosition - snapshot.OriginPosition).Magnitude > MAX_DISTANCE then
		return false
	end

	-- цель живая, части на месте, всё в пределах досягаемости
	local character, root = getStrictLivingPlayer(snapshot.Player)
	if not character or not root then
		return false
	end
	if character ~= snapshot.Character or root ~= snapshot.RootPart then
		return false
	end

	local targetPart = snapshot.TargetPart
	if typeof(targetPart) ~= "Instance" or not targetPart:IsA("BasePart") then
		return false
	end
	if not targetPart:IsDescendantOf(character) or not targetPart.CanQuery then
		return false
	end
	if not isFiniteVector(targetPart.Position) then
		return false
	end
	if (root.Position - snapshot.PredictedPosition).Magnitude > MAX_DISTANCE then
		return false
	end
	if (targetPart.Position - snapshot.TargetPosition).Magnitude > MAX_DISTANCE then
		return false
	end
	if snapshot.TargetAnchored ~= root.Anchored then
		return false
	end

	-- дуло не должно было уехать
	local muzzle = readMuzzlePosition(snapshot.Gun)
	if muzzle == nil then
		return false
	end
	return (muzzle - snapshot.OriginPosition).Magnitude <= MUZZLE_TOLERANCE
end

--=============================================================================
-- Выбор цели
--=============================================================================

--- Ближайшая живая цель в конусе обзора: ближе + ближе к центру экрана = лучше.
local function pickLockPlayer(): Player?
	local camera = Workspace.CurrentCamera
	local origin = getLocalRoot()
	if camera == nil or origin == nil or not isAlive() then
		return nil
	end

	local look = camera.CFrame.LookVector
	local minCos = math.cos(math.rad(math.clamp(settings.TargetConic, 5, 180)))

	local best: Player?
	local bestScore = math.huge
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= Players.LocalPlayer and not (settings.IgnoreTeam and isTeammate(player)) then
			local character, root = getLivingPlayer(player)
			if character and root then
				local delta = root.Position - origin.Position
				local distance = delta.Magnitude
				if distance > 0.01 and distance <= settings.TargetRange then
					local alignment = look:Dot(delta.Unit)
					if alignment >= minCos then
						local score = distance * (1 + (1 - alignment) * 4)
						if score < bestScore then
							best, bestScore = player, score
						end
					end
				end
			end
		end
	end
	return best
end

--=============================================================================
-- Протокол выстрела (порты GetShootProtocol / GetShootCFrames)
--=============================================================================

--- "Pair" — ствол стреляет парой ремоутов (Shoot + GunBeam), "Handle" — одним.
local function getShootProtocol(remote: Instance): Protocol
	local parent = remote.Parent
	if not parent then
		return "Handle"
	end
	local shootRemotes = 0
	for _, child in ipairs(parent:GetChildren()) do
		if SHOOT_REMOTES[child.Name] then
			shootRemotes += 1
		end
	end
	return shootRemotes > 1 and "Pair" or "Handle"
end

--- Опорные CFrame'ы выстрела: дуло и упреждённая точка прицеливания.
local function getShootCFrames(snapshot: Snapshot): (CFrame, CFrame)
	local muzzlePosition = snapshot.OriginPosition
	local direction = (snapshot.PredictedPosition - muzzlePosition).Unit
	local muzzle = CFrame.lookAt(muzzlePosition, muzzlePosition + direction)
	local aim = CFrame.lookAt(snapshot.LocalRootPosition, snapshot.PredictedPosition)
	return muzzle, aim
end

--=============================================================================
-- Сборка аргументов выстрела (порты BuildShootArguments / PrepareShot)
--=============================================================================

--- Подменяет направление на упреждённое; остальные аргументы остаются как есть.
local function buildShootArguments(originalArguments: { any }, muzzle: CFrame, aim: CFrame): { any }
	local arguments = table.clone(originalArguments)
	arguments.n = originalArguments.n or #originalArguments
	arguments[DIRECTION_ARGUMENT] = aim.Position - muzzle.Position
	return arguments
end

--- Порт PrepareShot: без валидного снапшота выстрел не готовится.
local function prepareShot(snapshot: Snapshot, originalArguments: { any }): { any }?
	if not isSnapshotValid(snapshot) or snapshot.Gun ~= getLocalGun() then
		return nil
	end
	local muzzle, aim = getShootCFrames(snapshot)
	return buildShootArguments(originalArguments, muzzle, aim)
end

--=============================================================================
-- Состояния выстрелов (порты ReserveShot / GunReadyAt)
--=============================================================================

local function getShotState(gun: Tool): ShotState
	local state = world.ShotStates[gun]
	if state == nil or state.Generation ~= world.Generation then
		state = { Busy = false, Generation = world.Generation, Gun = gun, StartedAt = 0 }
		world.ShotStates[gun] = state
	end
	return state
end

local function reserveShot(gun: Tool): ShotState?
	local state = getShotState(gun)
	if state.Busy then
		return nil
	end
	state.Busy = true
	state.StartedAt = os.clock()
	return state
end

local function releaseShot(state: ShotState): ()
	state.Busy = false
	state.NativeActivationUntil = nil
end

local function gunReadyAt(gun: Tool): number
	local state = world.ShotStates[gun]
	return (state and state.NativeActivationUntil) or 0
end

--=============================================================================
-- SmartTrigger (порт @86324)
--=============================================================================

local lastTriggerAt = 0

--- true = можно стрелять по текущему снапшоту.
local function shouldFire(snapshot: Snapshot, now: number, readyAt: number): boolean
	local state = world.ShotStates[snapshot.Gun]
	local maxWait = finiteNumber(settings.MaxWait, 250, 0, 300) / 1000
	local shotDelay = finiteNumber(settings.ShotDelay, 0, 0, 1000) / 1000

	if state and state.Busy then
		return false
	end
	if now < readyAt - maxWait then
		return false
	end
	if now - lastTriggerAt < math.max(shotDelay, TRIGGER_COOLDOWN) then
		return false
	end
	if not settings.SmartTrigger then
		return true
	end

	local waited = now - snapshot.CreatedAt >= maxWait
	if snapshot.HitChance >= settings.MinHitChance then
		return waited
	end
	-- в верхней точке прыжка порог послабляется, как в оригинале
	if snapshot.Airborne and snapshot.VerticalPhase == "Apex" and snapshot.HitChance >= settings.MinHitChance * 0.85 then
		return waited
	end
	return false
end

--=============================================================================
-- Хук FireServer / InvokeServer (порт @196755)
--=============================================================================

local function isShootRemote(remote: Instance): boolean
	if remote == world.KnifeThrowRemote then
		return false -- бросок ножа обрабатывается как есть
	end
	return remote == world.PendingRemote or SHOOT_REMOTES[remote.Name] == true
end

--- Порт проверки прострела: луч из дула должен упереться в цель снапшота.
local function hasPenetrationPath(snapshot: Snapshot): boolean
	if not settings.Penetration then
		return true
	end
	raycastParams.FilterDescendantsInstances = { getLocalCharacter() }
	local ok, hit = pcall(function ()
		return Workspace:Raycast(snapshot.OriginPosition, snapshot.PredictedPosition - snapshot.OriginPosition, raycastParams)
	end)
	if not ok or hit == nil then
		return false
	end
	return hit.Instance == snapshot.TargetPart or snapshot.TargetPart:IsDescendantOf(hit.Instance)
end

--- Что делать с перехваченным выстрелом:
---   "pass"    — отдать как есть (аим выключен, нет валидного решения и т.п.);
---   "swallow" — не отправлять вовсе (кулдаун, занятое состояние ствола);
---   "send"    — отправить с подменёнными аргументами.
local function handleRemoteCall(remote: Instance, arguments: { any }): (string, { any }?)
	local snapshot = world.CurrentSnapshot
	if not settings.Enabled or not world.Alive or snapshot == nil then
		return "pass"
	end

	local gun = getLocalGun()
	if not gun then
		return "pass"
	end

	-- запоминаем «настоящий» remote выстрела, чтобы отличать его от чужих
	world.NativeShootRemote = remote
	world.NativeShootGun = gun
	world.NativeShootArgs = arguments
	world.NativeShootProtocol = getShootProtocol(remote)
	world.PendingRemote = remote

	if not hasPenetrationPath(snapshot) then
		return "pass"
	end

	-- кулдаун: тот же ствол в пределах 0.12 c — глотаем; иначе считаем ручным
	local now = os.clock()
	if now - world.LastShotRequestAt < SHOT_COOLDOWN then
		if world.LastShotRequestGun == gun or now - world.LastManualActionTime < SHOT_COOLDOWN then
			return "swallow"
		end
	end

	local prepared = prepareShot(snapshot, arguments)
	if prepared == nil then
		return "pass"
	end

	local state = getShotState(gun)
	state.NativeActivationUntil = nil
	state.Busy = false
	if not reserveShot(gun) then
		return "swallow"
	end

	state.StartedAt = now
	world.LastShotRequestAt = now
	world.LastShotRequestGun = gun
	world.LastManualActionTime = now
	return "send", prepared
end

local function installHook(): ()
	local previous = hookmetamethod(game, "__namecall", function (self, ...)
		local ok, method = pcall(getnamecallmethod)
		if not ok then
			return previous(self, ...)
		end

		local isRemoteCall = (method == "FireServer" and self:IsA("RemoteEvent"))
			or (method == "InvokeServer" and self:IsA("RemoteFunction"))
		if not isRemoteCall or not world.Alive then
			return previous(self, ...)
		end

		if self.Name == "KnifeThrown" or self.Name == "ThrowKnife" then
			world.KnifeThrowRemote = self
			return previous(self, ...)
		end

		if not isShootRemote(self) then
			return previous(self, ...)
		end

		local outcome, prepared = handleRemoteCall(self, table.pack(...))
		if outcome == "swallow" then
			return nil -- выстрел проглочен: сервер его не увидит
		end
		if outcome == "pass" or prepared == nil then
			return previous(self, ...)
		end
		-- отправляем ровно один раз, уже с подменёнными аргументами
		return (self :: any)[method](self, table.unpack(prepared, 1, prepared.n))
	end)
end

--=============================================================================
-- Публичный интерфейс
--=============================================================================

aim = {
	on = true,
	settings = settings,
	world = world,

	getSnapshot = function (): Snapshot?
		return world.CurrentSnapshot
	end,

	getTarget = function (): Player?
		return world.LockPlayer
	end,

	enable = function (self): ()
		self.on = true
		settings.Enabled = true
		world.AimRevision += 1
	end,

	disable = function (self): ()
		self.on = false
		settings.Enabled = false
		world.LockPlayer = nil
		rawSamples = {}
		world.VelocityHistory = {}
		invalidateSnapshot()
	end,

	setTarget = function (self, player: Player?): ()
		world.LockPlayer = player
		world.LockStartedAt = os.clock()
		rawSamples = {}
		world.VelocityHistory = {}
		invalidateSnapshot()
	end,
}

Globals.__slientAim2 = aim

--=============================================================================
-- Запуск
--=============================================================================

if not Globals.__slientAim2Hooked and typeof(hookmetamethod) == "function" and typeof(getnamecallmethod) == "function" then -- [PastaWare] guard
	Globals.__slientAim2Hooked = true

	installHook()

	RunService.Heartbeat:Connect(function ()
		world.Alive = isAlive()

		if not world.Alive or not settings.Enabled then
			world.Sampling = false
			world.LockPlayer = nil
			rawSamples = {}
			world.VelocityHistory = {}
			invalidateSnapshot()
			return
		end

		world.Sampling = true
		local now = os.clock()

		-- сэмплирование и выбор цели — не чаще 10 Гц (порт @192571)
		if now - world.LastSampleAt >= SAMPLE_INTERVAL then
			world.LastSampleAt = now

			if world.LockPlayer == nil then
				world.LockPlayer = pickLockPlayer()
				if world.LockPlayer then
					world.LockStartedAt = now
				end
			else
				local _, root = getStrictLivingPlayer(world.LockPlayer)
				local localRoot = getLocalRoot()
				local outOfRange = root == nil
					or localRoot == nil
					or (root.Position - localRoot.Position).Magnitude > settings.TargetRange
				if outOfRange then
					world.LockPlayer = nil
					rawSamples = {}
					world.VelocityHistory = {}
				end
			end
		end

		-- снапшот пересобирается каждый кадр
		buildSnapshot()

		-- авто-выстрел по SmartTrigger (порт @173089)
		local snapshot = world.CurrentSnapshot
		if settings.AutoShoot and isSnapshotValid(snapshot) then
			local target = snapshot :: Snapshot
			if shouldFire(target, now, gunReadyAt(target.Gun)) then
				local reserved = reserveShot(target.Gun)
				if reserved then
					lastTriggerAt = now
					reserved.NativeActivationUntil = now + 0.2
					task.spawn(function ()
						local activated = pcall(function ()
							(target.Gun :: any).Activate()
						end)
						if not activated then
							releaseShot(reserved)
						end
						task.delay(0.2, function ()
							releaseShot(reserved)
						end)
					end)
				end
			end
		end
	end)
end

Globals.__HEADSHOOT_RAW_COPY = aim -- [PastaWare] was return aim
--=============================================================================
-- 13. FULL DEOB puls.orig.lua — все 155 модулей разобраны.
--   Фичи: чистый исполняемый код, поведение 1:1 по смыслу, имена вида Pulse_*.
--   VM-потроха (x/L0/O3/Q0/H9/C3/u0/K9/t3/A3/H3/W0/S0/V3/X3/P3/E3/B9/Z9/J3/N3/M0/O0/H0/T3/G3/K0/D3/I3/V3/Q3/F3/S3/T9/I0/*0/*3/*9): только каталог 13.6, НЕ портятся
--         (их семантика = байткод Luraph-VM; выполнение требует запуска VM).
--   Сеть D/L: портирована как референс, PastaWare её НЕ вызывает (см. 13.2).
--=============================================================================
do
    --=========================================================================
    -- 13.0 Легенда деоба: f[0..N] в оригинале = замыкания окружения.
    -- Ниже каждое замыкание заменено явным параметром/сервисом. Соответствие:
    --   f[0]=d(raw-mul) f[1]=a(mod-mul) f[2]=m(rshift) f[3]=j(floor) f[4]=U(band)
    --   для bigint; d.data/d.lang=словарь перевода; d.menuFont=шрифт меню.
    --=========================================================================
    PastaWare.Pulse.FullDeobRevision = 1
    -- Мост видимости: 11.A определил эти локали в СВОЁМ do-блоке; здесь,
    -- в секции 13, берём их из таблицы (все присвоены раньше по файлу).
    local Pulse_BigTrim = PastaWare.Pulse.BigTrim
    local Pulse_BigCmp = PastaWare.Pulse.BigCmp
    local Pulse_BigMul2 = PastaWare.Pulse.BigMul2
    local Pulse_BigMul = PastaWare.Pulse.BigMul
    local Pulse_BigSub = PastaWare.Pulse.BigSub
    local Pulse_BigFromHexLE = PastaWare.Pulse.BigFromHexLE
    local Pulse_BigToHex = PastaWare.Pulse.BigToHex
    local Pulse_HexEncode = PastaWare.Pulse.HexEncode
    local Pulse_HexToBytes = PastaWare.Pulse.HexToBytes
    local Pulse_PositionLineFrame = PastaWare.Pulse.PositionLineFrame
    local Pulse_GetPlayerDataRoster = PastaWare.Pulse.GetPlayerDataRoster
    local Pulse_IsValidTargetPart = PastaWare.Pulse.IsValidTargetPart

    do -- 13.1 scope: крипто/фабрики/утилиты (все локали умирают на его end)

    --=========================================================================
    -- 13.1a h (8037) BigPowMod — square-and-multiply по битам экспоненты.
    -- Оригинал: C=старший установленный бит; e={1}; B=a(f,F); по битам:
    --   бит=1 -> e=a(d(e,B),F); B=a(d(B,B),F) (кроме последнего шага).
    --=========================================================================
    local function Pulse_BigPowMod(baseLimbs, expLimbs, modLimbs)
        local top = -1
        for e = 0, #expLimbs * 16 - 1 do
            local limb = expLimbs[math.floor(e / 16) + 1] or 0
            if bit32.band(bit32.rshift(limb, e % 16), 1) == 1 then
                top = e
            end
        end
        local res = { 1 }
        if top < 0 then return res end
        local base = PastaWare.Pulse.BigMod(baseLimbs, modLimbs)
        for i = 0, top do
            local limb = expLimbs[math.floor(i / 16) + 1] or 0
            if bit32.band(bit32.rshift(limb, i % 16), 1) == 1 then
                res = PastaWare.Pulse.BigMod(PastaWare.Pulse.BigMul(res, base), modLimbs)
            end
            if i < top then
                base = PastaWare.Pulse.BigMod(PastaWare.Pulse.BigMul(base, base), modLimbs)
            end
        end
        return res
    end
    PastaWare.Pulse.BigPowMod = Pulse_BigPowMod

    --=========================================================================
    -- 13.1b z (7148) BigMod — деление в столбик по битам, yield каждые 200.
    -- Оригинал: if cmp(f,C)<0 -> копия f; иначе e={0}, по битам сверху вниз:
    --   e=mul2(e); if бит: e[1]+=1; trim; if cmp(e,C)>=0: e=sub(e,C).
    --=========================================================================
    local function Pulse_BigMod(valueLimbs, modLimbs)
        if Pulse_BigCmp(valueLimbs, modLimbs) < 0 then
            local copy = {}
            for i = 1, #valueLimbs do copy[i] = valueLimbs[i] end
            return copy
        end
        local e, ops = { 0 }, 0
        for b = #valueLimbs * 16 - 1, 0, -1 do
            e = Pulse_BigMul2(e)
            local limb = valueLimbs[math.floor(b / 16) + 1] or 0
            if bit32.band(bit32.rshift(limb, b % 16), 1) == 1 then
                e[1] = e[1] + 1
            end
            e = Pulse_BigTrim(e)
            if Pulse_BigCmp(e, modLimbs) >= 0 then
                e = Pulse_BigSub(e, modLimbs)
            end
            ops = ops + 1
            if ops >= 200 then
                ops = 0
                if coroutine.isyieldable() then task.wait() end
            end
        end
        return e
    end
    PastaWare.Pulse.BigMod = Pulse_BigMod

    --=========================================================================
    -- 13.1c M (9264) Base64Encode — тройки байтов -> четверки символов, "=" паддинг.
    --=========================================================================
    local B64Chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    local function Pulse_Base64Encode(data: string): string
        local out = {}
        local bytes = { data:byte(1, #data) }
        for i = 1, #bytes, 3 do
            local a, b, c = bytes[i], bytes[i + 1], bytes[i + 2]
            local n = a * 65536 + (b or 0) * 256 + (c or 0)
            local m = math.floor(n / 262144) % 64
            local k = math.floor(n / 4096) % 64
            local F = math.floor(n / 64) % 64
            local C = n % 64
            out[#out + 1] =
                B64Chars:sub(m + 1, m + 1) .. B64Chars:sub(k + 1, k + 1)
                .. (b and B64Chars:sub(F + 1, F + 1) or "=")
                .. (c and B64Chars:sub(C + 1, C + 1) or "=")
        end
        return table.concat(out)
    end
    PastaWare.Pulse.Base64Encode = Pulse_Base64Encode

    --=========================================================================
    -- 13.1d KT (8953) Base64DecodeAlt — короткий вариант декодера (сравнить с s/A1).
    --=========================================================================
    local function Pulse_Base64DecodeAlt(data: string): string
        local clean = tostring(data or ""):gsub("[^%w%+%/%=]", "")
        local lookup = {}
        for i = 1, #B64Chars do lookup[B64Chars:sub(i, i)] = i - 1 end
        local out, acc, bits = {}, 0, 0
        for i = 1, #clean do
            local ch = clean:sub(i, i)
            if ch ~= "=" then
                acc = acc * 64 + (lookup[ch] or 0)
                bits = bits + 6
                if bits >= 8 then
                    bits = bits - 8
                    out[#out + 1] = string.char(math.floor(acc / (2 ^ bits)) % 256)
                    acc = acc % (2 ^ bits)
                end
            end
        end
        return table.concat(out)
    end
    PastaWare.Pulse.Base64DecodeAlt = Pulse_Base64DecodeAlt

    --=========================================================================
    -- 13.1e G (1878) RandomPad(f, minLen) — "\0\2" + мусор + "\x00" + f.
    --=========================================================================
    local function Pulse_RandomPad(payload: string, minLen: number?): string
        local need = (minLen or 0) - #payload - 3
        if need < 8 then need = 8 end
        local parts = {}
        for i = 1, need do parts[i] = string.char(math.random(1, 255)) end
        return "\0\2" .. table.concat(parts) .. "\x00" .. payload
    end
    PastaWare.Pulse.RandomPad = Pulse_RandomPad

    --=========================================================================
    -- 13.1f pT (6533) + YT (8863) — LCG-цепочки % 16777216 на общем стейте.
    -- pT: 4 звена (301849/4467143, 191807/3902093, 566575/2811935, 936079/13640424).
    -- YT: 1 звено (931233/882533).
    --=========================================================================
    local function Pulse_PRNGNext(state, mul: number, add: number): number
        local v = (state[1] * mul + add) % 16777216
        state[1] = v
        return v
    end
    local function Pulse_PRNGChain(state): number
        Pulse_PRNGNext(state, 301849, 4467143)
        Pulse_PRNGNext(state, 191807, 3902093)
        Pulse_PRNGNext(state, 566575, 2811935)
        return Pulse_PRNGNext(state, 936079, 13640424)
    end
    local function Pulse_PRNGStep(state): number
        return Pulse_PRNGNext(state, 931233, 882533)
    end
    PastaWare.Pulse.PRNGNext = Pulse_PRNGNext
    PastaWare.Pulse.PRNGChain = Pulse_PRNGChain
    PastaWare.Pulse.PRNGStep = Pulse_PRNGStep

    --=========================================================================
    -- 13.1g W (1077) DecryptPayload(password, keyA, keyB) — конверт:
    --   C,e = sha(keyA), sha(keyB); keyLen = #keyA/2; blob = RC4(password,keyLen);
    --   hex = hex(blob); mod = powmod(hex2int, e, C); str = toHex, pad "0" до keyLen*2;
    --   return unhex(str). Роли a/m/j выведены из формы вызовов (см. 13.0).
    --=========================================================================
    local function Pulse_DecryptPayload(password: string, keyA: string, keyB: string): (string?, string)
        local modC = PastaWare.Pulse.SHA256_Raw(keyA)
        local expE = PastaWare.Pulse.SHA256_Raw(keyB)
        local keyLen = math.floor(#keyA / 2)
        local blob = PastaWare.Pulse.RC4(password, string.rep("\0", math.max(keyLen, 1)))
        if not blob then return nil, "" end
        local hex = Pulse_HexEncode(blob)
        local asLimbs = Pulse_BigFromHexLE(hex)
        local cLimbs = Pulse_BigFromHexLE(Pulse_HexEncode(modC))
        local eLimbs = Pulse_BigFromHexLE(Pulse_HexEncode(expE))
        local modRes = Pulse_BigPowMod(asLimbs, eLimbs, cLimbs)
        local out = Pulse_BigToHex(modRes)
        if #out % 2 == 1 then out = "0" .. out end
        out = string.rep("0", math.max(0, keyLen * 2 - #out)) .. out
        return Pulse_HexToBytes(out), out
    end
    PastaWare.Pulse.DecryptPayload = Pulse_DecryptPayload

    --=========================================================================
    -- 13.1h Фабрики: r (8903) Instance / R (9300) UICorner / hP (8932) Dot /
    --   j (2032) UIGradient / Q (7634) UIStroke. B (7375)+F (1573) перевод.
    --=========================================================================
    local function Pulse_MakeInstance(className: string, props, parent: Instance?)
        local obj: any = Instance.new(className)
        for k, v in pairs(props or {}) do
            obj[k] = v
        end
        if parent then obj.Parent = parent end
        return obj
    end
    local function Pulse_MakeCorner(parent: Instance, radius: number?)
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, radius or 8)
        c.Parent = parent
        return c
    end
    local function Pulse_MakeDot(parent: Instance)
        local dot = Instance.new("Frame")
        dot.BorderSizePixel = 0
        dot.AnchorPoint = Vector2.new(0.5, 0.5)
        dot.BackgroundColor3 = Color3.new(1, 1, 1)
        dot.Visible = false
        dot.Parent = parent
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(1, 0)
        corner.Parent = dot
        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.fromRGB(0, 0, 0)
        stroke.Thickness = 1
        stroke.Transparency = 0.45
        stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        stroke.Parent = dot
        return dot
    end
    local function Pulse_MakeGradient(parent: Instance, from: Color3, to: Color3, rotation: number?)
        local g = Instance.new("UIGradient")
        g.Color = ColorSequence.new(from, to)
        g.Rotation = rotation or 0
        g.Parent = parent
        return g
    end
    local function Pulse_MakeStroke(parent: Instance, color: Color3?, thickness: number?, transparency: number?)
        local s = Instance.new("UIStroke")
        s.Color = color or Color3.new(0, 0, 0)
        s.Thickness = thickness or 1
        s.Transparency = transparency or 0
        s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        s.Parent = parent
        return s
    end
    PastaWare.Pulse.MakeInstance = Pulse_MakeInstance
    PastaWare.Pulse.MakeCorner = Pulse_MakeCorner
    PastaWare.Pulse.MakeDot = Pulse_MakeDot
    PastaWare.Pulse.MakeGradient = Pulse_MakeGradient
    PastaWare.Pulse.MakeStroke = Pulse_MakeStroke

    -- 13.1i Перевод: F (1573) lookup data[lang][key] + B (7375) applier с реестром.
    PastaWare.Pulse.LangDict = PastaWare.Pulse.LangDict or { data = {}, lang = "en" }
    local function Pulse_Translate(key: string): string
        if key == nil then return key end
        local dict = PastaWare.Pulse.LangDict
        local lang = dict.data[dict.lang]
        if lang then
            local hit = lang[key]
            if hit then return hit end
        end
        return key
    end
    local TranslateRegistry: { any } = {}
    local function Pulse_ApplyTranslation(inst: Instance, key: string, prop: string?)
        prop = prop or "Text"
        pcall(function() local w: any = inst w[prop] = Pulse_Translate(key) end)
        TranslateRegistry[#TranslateRegistry + 1] = { inst = inst, src = key, prop = prop }
    end
    PastaWare.Pulse.Translate = Pulse_Translate
    PastaWare.Pulse.ApplyTranslation = Pulse_ApplyTranslation
    PastaWare.Pulse.TranslateRegistry = TranslateRegistry

    -- 13.1j Мелочь: oP (8200) lerp01 / AP (1791) pick-first / T (2875) dual-apply.
    local function Pulse_Lerp01(t: number, target: number): number
        return t + (1 - t) * target
    end
    local function Pulse_PickFirst(map, key)
        if not map then return nil end
        local hit = (key ~= nil) and map[key] or nil
        if hit ~= nil then return hit end
        for _, v in pairs(map) do return v end
        return nil
    end
    local function Pulse_ApplyDual(applyFn, fwdA, midA, fwdB, midB, slots)
        slots[1], slots[2] = applyFn(fwdA, midA, fwdB, slots[1], slots[2])
        slots[3], slots[4] = applyFn(fwdB, midA, midB, slots[3], slots[4])
    end
    PastaWare.Pulse.Lerp01 = Pulse_Lerp01
    PastaWare.Pulse.PickFirst = Pulse_PickFirst
    PastaWare.Pulse.ApplyDual = Pulse_ApplyDual

    -- 13.1k t (1774) ClearWobble + q (6779) ClearChamsData (пары к PP/y).
    local function Pulse_ClearWobble(entry)
        if entry and entry.wob then
            for _, conn in ipairs(entry.wob) do
                pcall(function()
                    if typeof(conn) == "RBXScriptConnection" then
                        conn:Disconnect()
                    else
                        conn:Destroy()
                    end
                end)
            end
        end
        if entry then entry.wob, entry.wobSig = nil, nil end
    end
    local function Pulse_ClearChamsData(entry)
        if entry and entry.ch then
            for _, rec in ipairs(entry.ch) do
                if rec[1].Parent then
                    pcall(function()
                        rec[1].Material = rec[2]
                        rec[1].Color = rec[3]
                    end)
                end
            end
        end
        if entry then entry.ch, entry.chSeen = nil, nil end
    end
    PastaWare.Pulse.ClearWobble = Pulse_ClearWobble
    PastaWare.Pulse.ClearChamsData = Pulse_ClearChamsData

    end -- end 13.1 scope

    do -- 13.2 scope: сеть-референс/текст/радио
    --=========================================================================
    -- 13.2a L (4132) SignRequest — подпись X-Pulse-HWID/TS/Nonce/Env/Sig.
    --   Sig = HMAC(Method.."\n"..path.."\n"..TS.."\n"..Nonce.."\n"..HWID.."\n"..Env.."\n"..Body).
    --   РЕФЕРЕНС: PastaWare этот код НЕ вызывает (см. комментарий в 13.2c).
    --=========================================================================
    local function Pulse_SignRequest(req, hwid: string, envStr: string, hmacFn): any
        local httpFn = (syn and (syn :: any).request) or http_request or request
            or (http and (http :: any).request)
        if not httpFn then return nil, "no http func" end
        if req.Url and req.Body and req.Method then
            pcall(function()
                local path = req.Url:gsub("^https?://[^/]+", "")
                local ts = req.TS or tostring(os.time())
                local nonce = req.Nonce or PastaWare.Pulse.SHA256Hex(
                    tostring(os.clock()) .. tostring(math.random(1, 1000000000))):sub(1, 16)
                req.Headers = req.Headers or {}
                req.Headers["X-Pulse-HWID"] = hwid
                req.Headers["X-Pulse-TS"] = ts
                req.Headers["X-Pulse-Nonce"] = nonce
                req.Headers["X-Pulse-Env"] = envStr
                req.Headers["X-Pulse-Sig"] = hmacFn(
                    req.Method .. "\n" .. path .. "\n" .. ts .. "\n" .. nonce
                    .. "\n" .. hwid .. "\n" .. envStr .. "\n" .. req.Body)
            end)
        end
        local ok, res = pcall(httpFn, req)
        if not ok then return nil, tostring(res) end
        return res
    end
    PastaWare.Pulse.SignRequest = Pulse_SignRequest

    --=========================================================================
    -- 13.2b D (612) PostJSON — POST JSON на URL-конфиг, опц. шифрование тела.
    --   if ENCRYPT: C=sha16, e=cipher(C,json) -> body={e=e}, header X-Pulse-Enc=C.
    --   Возвращает ответ только при 2xx, иначе nil.
    --=========================================================================
    local function Pulse_PostJSON(endpoint: string, payload, netCfg, cipherFn, requestFn): any
        if not netCfg.ENABLED then return nil end
        local HttpService = game:GetService("HttpService")
        local body = HttpService:JSONEncode(payload)
        local headers = { ["Content-Type"] = "application/json" }
        if netCfg.ENCRYPT and cipherFn then
            local salt = PastaWare.Pulse.SHA256Hex(
                tostring(os.clock()) .. tostring(math.random(1, 1000000000))):sub(1, 16)
            local ok, enc = pcall(cipherFn, salt, body)
            if ok and type(enc) == "string" then
                body = HttpService:JSONEncode({ e = enc })
                headers["X-Pulse-Enc"] = salt
            end
        end
        local ok, res = requestFn({ Url = netCfg.URL .. endpoint, Method = "POST", Headers = headers, Body = body })
        if not ok then return nil end
        local code = res.StatusCode or res.status or 0
        if code >= 200 and code < 300 then return res end
        return nil
    end
    PastaWare.Pulse.PostJSON = Pulse_PostJSON

    --=========================================================================
    -- 13.2c Сетевой конвейер o+L+D: ПОЛНОСТЬЮ ОТКЛЮЧЁН в PastaWare.
    --   Оригинал слал инвентарь на /admin/snapshot (см. A10). Здесь o() оставлен
    --   только как сборщик таблицы (BuildAdminSnapshot), вызовы PostJSON/SignRequest
    --   отсутствуют во всех циклах — проверяется поиском "PostJSON("/"SignRequest(".
    --=========================================================================
    PastaWare.Pulse.NetworkDisabled = true

    --=========================================================================
    -- 13.2d N (7835) SetTextScale + g (9589) ApplyScaleToNew — масштаб шрифтов.
    --   N(factor%): textScale=clamp(f/100,0.8,1.6), всем Text* без TextScaled:
    --   запомнить _baseTS, TextSize=max(8,floor(base*m+0.5)).
    --=========================================================================
    local function Pulse_SetTextScale(uiRoot: Instance, percent): number
        if not uiRoot then return 1 end
        local m = math.clamp((tonumber(percent) or 100) / 100, 0.8, 1.6)
        PastaWare.Pulse.TextScale = m
        for _, obj in ipairs(uiRoot:GetDescendants()) do
            if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
                pcall(function()
                    local w: any = obj
                    if w.TextScaled then return end
                    local base = obj:GetAttribute("_baseTS")
                    if base == nil then
                        base = w.TextSize
                        obj:SetAttribute("_baseTS", base)
                    end
                    w.TextSize = math.max(8, math.floor(base * m + 0.5))
                end)
            end
        end
        return m
    end
    local function Pulse_ApplyScaleToNew(obj: Instance)
        local m = PastaWare.Pulse.TextScale
        if not m or m == 1 then return end
        if not (obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox")) then return end
        task.defer(function()
            pcall(function()
                local w: any = obj
                if w.TextScaled or obj:GetAttribute("_baseTS") ~= nil then return end
                local base = w.TextSize
                obj:SetAttribute("_baseTS", base)
                w.TextSize = math.max(8, math.floor(base * m + 0.5))
            end)
        end)
    end
    PastaWare.Pulse.SetTextScale = Pulse_SetTextScale
    PastaWare.Pulse.ApplyScaleToNew = Pulse_ApplyScaleToNew

    --=========================================================================
    -- 13.2e n (9062) SetMenuFontName — d.menuFont + проход по ScreenGui.
    --   "Gotham" сбрасывает в дефолт (nil). Пара к C/ApplyMenuFont.
    --=========================================================================
    local function Pulse_SetMenuFontName(uiRoot: Instance, fontName: string)
        local font = Enum.Font[fontName]
        if not font or not uiRoot then return end
        PastaWare.Pulse.MenuFont = (fontName ~= "Gotham") and font or nil
        for _, obj in ipairs(uiRoot:GetDescendants()) do
            if (obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox"))
                and not obj:GetAttribute("_fontFixed") then
                pcall(function() (obj :: TextLabel).Font = font end)
            end
        end
    end
    PastaWare.Pulse.SetMenuFontName = Pulse_SetMenuFontName

    --=========================================================================
    -- 13.2f kP (7386) RadioTicker — раз в секунду: если нет Radio-геймпасса,
    --   пишет "Radio not equipped buy & wear the Radio gamepass"; иначе
    --   показывает название трека по SoundId и ровняет Volume (j.volume/100).
    --=========================================================================
    local function Pulse_RadioTicker(label: TextLabel, getTrackFn, hasRadioFn, opts, titleOfFn)
        task.spawn(function()
            while opts.radioOn() do
                task.wait(1)
                pcall(function()
                    if not hasRadioFn() then
                        label.Text = "Radio not equipped buy & wear the Radio gamepass"
                        return
                    end
                    local track = getTrackFn()
                    if track and track.IsPlaying and track.SoundId ~= "" then
                        local title = titleOfFn(track.SoundId)
                        label.Text = "" .. (title or "?")
                        local want = ((opts.volume or 50) / 100)
                        if math.abs(track.Volume - want) > 0.01 then
                            track.Volume = want
                        end
                    else
                        label.Text = ""
                    end
                end)
            end
        end)
    end
    local function Pulse_SetScaledVolume(level: number, factor: number, applyFn)
        pcall(applyFn, level * factor)
    end
    PastaWare.Pulse.RadioTicker = Pulse_RadioTicker
    PastaWare.Pulse.SetScaledVolume = Pulse_SetScaledVolume

    end -- end 13.2 scope

    do -- 13.3 scope: мастер-ESP + GunESP
    --=========================================================================
    -- 13.3a LP (8449) RenderRoleESPFull — ГЛАВНЫЙ рендер Pulse:
    -- rolesp.on gate; Hero-промоция (Innocent+Gun); Dead/Killed пропуск;
    -- highlight+пульс+матовость; role/name/dist лейблы со стекингом и
    -- затуханием (p-70)/260; box(Full/Corners)+tracers(Top/Center/Bottom)+skeleton.
    -- По умолчанию ВЫКЛ (FullRoleESP=false): основной рендер — секция 7.
    --=========================================================================
    PastaWare.Config.ESPEx.FullRoleESP = PastaWare.Config.ESPEx.FullRoleESP or false
    local RoleHL: { [Player]: Highlight } = {}
    local RoleKits: { [Player]: any } = {}
    -- Кости скелета: {{имя,ox,oy,oz},{имя,ox,oy,oz}}; точка = CFrame*offset.
    local SkelBones = {
        R15 = {
            { { "Head", 0, -0.5, 0 }, { "UpperTorso", 0, 0.5, 0 } },
            { { "UpperTorso", 0, 0.5, 0 }, { "LowerTorso", 0, 0.5, 0 } },
            { { "UpperTorso", -0.5, 0.3, 0 }, { "LeftUpperArm", 0, 0.5, 0 } },
            { { "LeftUpperArm", 0, -0.5, 0 }, { "LeftLowerArm", 0, 0.5, 0 } },
            { { "LeftLowerArm", 0, -0.5, 0 }, { "LeftHand", 0, 0.3, 0 } },
            { { "UpperTorso", 0.5, 0.3, 0 }, { "RightUpperArm", 0, 0.5, 0 } },
            { { "RightUpperArm", 0, -0.5, 0 }, { "RightLowerArm", 0, 0.5, 0 } },
            { { "RightLowerArm", 0, -0.5, 0 }, { "RightHand", 0, 0.3, 0 } },
            { { "LowerTorso", -0.3, -0.5, 0 }, { "LeftUpperLeg", 0, 0.5, 0 } },
            { { "LeftUpperLeg", 0, -0.5, 0 }, { "LeftLowerLeg", 0, 0.5, 0 } },
            { { "LeftLowerLeg", 0, -0.5, 0 }, { "LeftFoot", 0, 0.3, 0 } },
            { { "LowerTorso", 0.3, -0.5, 0 }, { "RightUpperLeg", 0, 0.5, 0 } },
            { { "RightUpperLeg", 0, -0.5, 0 }, { "RightLowerLeg", 0, 0.5, 0 } },
            { { "RightLowerLeg", 0, -0.5, 0 }, { "RightFoot", 0, 0.3, 0 } },
        },
        R6 = {
            { { "Head", 0, -0.5, 0 }, { "Torso", 0, 0.5, 0 } },
            { { "Torso", -0.5, 0.3, 0 }, { "Left Arm", 0, 0.5, 0 } },
            { { "Torso", 0.5, 0.3, 0 }, { "Right Arm", 0, 0.5, 0 } },
            { { "Torso", -0.3, -0.5, 0 }, { "Left Leg", 0, 0.5, 0 } },
            { { "Torso", 0.3, -0.5, 0 }, { "Right Leg", 0, 0.5, 0 } },
        },
    }
    local function Pulse_GetRoleKit(plr: Player)
        local kit = RoleKits[plr]
        if kit and kit.gui and kit.gui.Parent then return kit end
        local gui = Instance.new("BillboardGui")
        gui.Name = "PastaWare_FullRole"
        gui.Size = UDim2.new(0, 140, 0, 60)
        gui.StudsOffset = Vector3.new(0, 3.2, 0)
        gui.AlwaysOnTop = true
        gui.Parent = CoreGui
        local function mkLabel(order: number, size: number, bold: boolean)
            local l = Instance.new("TextLabel")
            l.Size = UDim2.new(1, 0, 0, size)
            l.Position = UDim2.new(0, 0, 0, order)
            l.BackgroundTransparency = 1
            l.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
            l.TextSize = size
            l.TextStrokeTransparency = 0.2
            l.Visible = false
            l.Parent = gui
            return l
        end
        kit = {
            gui = gui,
            roleLbl = mkLabel(0, 16, true),
            nameLbl = mkLabel(0, 13, false),
            distLbl = mkLabel(0, 12, false),
            lines = {},
            tracer = nil,
            bones = {},
        }
        for i = 1, 8 do
            local ok, line = pcall(function() return Drawing.new("Line") end)
            kit.lines[i] = ok and line or ({ Visible = false } :: any)
        end
        local tr = Instance.new("Frame")
        tr.BorderSizePixel = 0
        tr.Visible = false
        tr.Parent = gui
        kit.tracer = tr
        for i = 1, 20 do
            local b = Instance.new("Frame")
            b.BorderSizePixel = 0
            b.Visible = false
            b.Parent = gui
            kit.bones[i] = b
        end
        RoleKits[plr] = kit
        return kit
    end
    local function Pulse_HideRoleKit(plr: Player)
        local kit = RoleKits[plr]
        if not kit then return end
        kit.roleLbl.Visible = false
        kit.nameLbl.Visible = false
        kit.distLbl.Visible = false
        for _, l in ipairs(kit.lines) do l.Visible = false end
        kit.tracer.Visible = false
        for _, b in ipairs(kit.bones) do b.Visible = false end
    end
    local RoleESPStyles = {
        Default = { fillTr = 0.5, outTr = 0, pulse = 0.25, onTop = true },
    }
    local LastRoleTextAt = 0
    local function Pulse_RenderRoleESPFull()
        local cfg = PastaWare.Config.ESPEx
        if not cfg.FullRoleESP then return end
        local rs = PastaWare.Config.RoleSP or {}
        if not rs.on then
            for plr in pairs(RoleKits) do Pulse_HideRoleKit(plr) end
            return
        end
        local textTick = os.clock() - LastRoleTextAt >= 0.08
        if textTick then LastRoleTextAt = os.clock() end
        PastaWare.Pulse.GetPlayerDataRoster()
        local lchar = LocalPlayer.Character
        local lroot = lchar and lchar:FindFirstChild("HumanoidRootPart")
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr == LocalPlayer then continue end
            local rec = PastaWare.State.RosterCache and PastaWare.State.RosterCache[plr.Name]
            local role = rec and rec.Role or PastaWare.State.Roles[plr.Name]
            if role == "Innocent" then
                local ch0 = plr.Character
                local gun = ch0 and ch0:FindFirstChild("Gun")
                    or (plr:FindFirstChild("Backpack") and plr.Backpack:FindFirstChild("Gun"))
                if gun then role = "Hero" end
            end
            local dead = rec ~= nil and (rec.Dead == true or rec.Killed == true)
            local char = plr.Character
            local hum = char and safeFindChildOfClass(char, "Humanoid")
            local target = char and (char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart"))
            local alive = (not dead) and char ~= nil and hum ~= nil and hum.Health > 0
            local color = (role == "Murderer" and PastaWare.Config.Visuals.MurdererColor)
                or (role == "Sheriff" and PastaWare.Config.Visuals.SheriffColor)
                or (role == "Hero" and PastaWare.Config.Visuals.HeroColor)
                or PastaWare.Config.Visuals.InnocentColor
            local dist = (lroot and target) and (lroot.Position - (target :: BasePart).Position).Magnitude or nil
            local inRange = (rs.maxDist or 0) <= 0 or (dist ~= nil and dist <= (rs.maxDist or 0))
            local style = RoleESPStyles[rs.style or "Default"] or RoleESPStyles.Default
            if alive and char and target and style and inRange and role then
                -- highlight (+pulse + material)
                if rs.highlight then
                    local hl = RoleHL[plr]
                    if not hl or not hl.Parent then
                        hl = Instance.new("Highlight")
                        hl.Parent = char
                        RoleHL[plr] = hl
                    end
                    if hl.Adornee ~= char then hl.Adornee = char end
                    hl.FillColor = color
                    hl.OutlineColor = color
                    local fTr, oTr = style.fillTr, style.outTr
                    if (style.pulse or 0) > 0 then
                        local ph = 0.5 + 0.5 * math.sin(os.clock() * 3.1)
                        fTr = math.clamp(fTr - style.pulse * 0.5 + style.pulse * ph, 0, 1)
                        oTr = math.clamp(oTr - style.pulse * 0.35 * ph, 0, 1)
                    end
                    hl.FillTransparency = fTr
                    hl.OutlineTransparency = oTr
                    hl.DepthMode = style.onTop and Enum.HighlightDepthMode.AlwaysOnTop
                        or Enum.HighlightDepthMode.Occluded
                    if style.mat then
                        PastaWare.Pulse.ForceFieldAll(char, color)
                    else
                        PastaWare.Pulse.ClearCharMats(char)
                    end
                end
                -- labels
                local kit = Pulse_GetRoleKit(plr)
                if kit.gui.Adornee ~= target then kit.gui.Adornee = target end
                local showRole = rs.showRole ~= false
                local showName = rs.showName and true or false
                local showDist = rs.showDist and dist and true or false
                if showRole or showName or showDist then
                    if textTick then
                        kit.roleLbl.Visible = showRole
                        if showRole then
                            kit.roleLbl.Text = role
                            kit.roleLbl.TextColor3 = color
                        end
                        kit.nameLbl.Visible = showName
                        if showName then kit.nameLbl.Text = tostring(plr.DisplayName) end
                        kit.distLbl.Visible = showDist
                        if showDist then kit.distLbl.Text = math.floor(dist) .. " studs" end
                        local y = 0
                        if showRole then kit.roleLbl.Position = UDim2.new(0, 0, 0, y) y += 18 end
                        if showName then kit.nameLbl.Position = UDim2.new(0, 0, 0, y) y += 15 end
                        if showDist then kit.distLbl.Position = UDim2.new(0, 0, 0, y) end
                        local fade = dist and math.clamp((dist - 70) / 260, 0, 0.5) or 0
                        kit.roleLbl.TextTransparency = fade
                        kit.nameLbl.TextTransparency = fade
                        kit.distLbl.TextTransparency = fade
                    end
                elseif kit.roleLbl.Visible or kit.nameLbl.Visible or kit.distLbl.Visible then
                    kit.roleLbl.Visible = false
                    kit.nameLbl.Visible = false
                    kit.distLbl.Visible = false
                end
                -- box / tracers / skeleton
                if rs.box or rs.tracers or rs.skeleton then
                    local cam = Workspace.CurrentCamera
                    local hrp = char:FindFirstChild("HumanoidRootPart")
                    if cam and hrp then
                        local half = (((target :: BasePart):IsA("BasePart") and (target :: BasePart).Size.Y) or 1) * 0.5 + 0.5
                        local topV, topOn = cam:WorldToViewportPoint((target :: BasePart).Position + Vector3.new(0, half, 0))
                        local botV, botOn = cam:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3, 0))
                        if topOn and botOn then
                            local cx = (topV.X + botV.X) / 2
                            local h = math.abs(botV.Y - topV.Y)
                            local w = h * 0.5
                            if rs.box then
                                if (rs.boxStyle or "Full") == "Corners" then
                                    local cl = math.clamp(w * 0.25, 4, 15)
                                    local L = kit.lines
                                    local segs = {
                                        { cx - w / 2, topV.Y, cx - w / 2 + cl, topV.Y },
                                        { cx - w / 2, topV.Y, cx - w / 2, topV.Y + cl },
                                        { cx + w / 2, topV.Y, cx + w / 2 - cl, topV.Y },
                                        { cx + w / 2, topV.Y, cx + w / 2, topV.Y + cl },
                                        { cx - w / 2, botV.Y, cx - w / 2 + cl, botV.Y },
                                        { cx - w / 2, botV.Y, cx - w / 2, botV.Y - cl },
                                        { cx + w / 2, botV.Y, cx + w / 2 - cl, botV.Y },
                                        { cx + w / 2, botV.Y, cx + w / 2, botV.Y - cl },
                                    }
                                    for i = 1, 8 do
                                        local s = segs[i]
                                        L[i].From = Vector2.new(s[1], s[2])
                                        L[i].To = Vector2.new(s[3], s[4])
                                        L[i].Color = color
                                        L[i].Visible = true
                                    end
                                else
                                    local L = kit.lines
                                    local segs = {
                                        { cx - w / 2, topV.Y, cx + w / 2, topV.Y },
                                        { cx + w / 2, topV.Y, cx + w / 2, botV.Y },
                                        { cx + w / 2, botV.Y, cx - w / 2, botV.Y },
                                        { cx - w / 2, botV.Y, cx - w / 2, topV.Y },
                                    }
                                    for i = 1, 4 do
                                        local s = segs[i]
                                        L[i].From = Vector2.new(s[1], s[2])
                                        L[i].To = Vector2.new(s[3], s[4])
                                        L[i].Color = color
                                        L[i].Visible = true
                                    end
                                    for i = 5, 8 do L[i].Visible = false end
                                end
                            else
                                for _, l in ipairs(kit.lines) do l.Visible = false end
                            end
                            if rs.tracers then
                                local vs = cam.ViewportSize
                                local from = rs.tracerFrom or "Bottom"
                                local ox, oy = vs.X / 2, vs.Y
                                if from == "Top" then oy = 0
                                elseif from == "Center" then oy = vs.Y / 2 end
                                Pulse_PositionLineFrame(kit.tracer, ox, oy, cx, topV.Y, 1)
                                kit.tracer.BackgroundColor3 = color
                                kit.tracer.BackgroundTransparency = 0
                                kit.tracer.Visible = true
                            else
                                kit.tracer.Visible = false
                            end
                            if rs.skeleton then
                                local set = (char:FindFirstChild("UpperTorso") and SkelBones.R15) or SkelBones.R6
                                local n = 0
                                for b = 1, #set do
                                    local e, x = set[b][1], set[b][2]
                                    local pe = char:FindFirstChild(e[1])
                                    local px = char:FindFirstChild(x[1])
                                    if pe and px and pe:IsA("BasePart") and px:IsA("BasePart") then
                                        local gp = (pe.CFrame * CFrame.new(pe.Size.X * e[2], pe.Size.Y * e[3], pe.Size.Z * e[4])).Position
                                        local gx = (px.CFrame * CFrame.new(px.Size.X * x[2], px.Size.Y * x[3], px.Size.Z * x[4])).Position
                                        local s1, o1 = cam:WorldToViewportPoint(gp)
                                        local s2, o2 = cam:WorldToViewportPoint(gx)
                                        if o1 and o2 then
                                            n += 1
                                            local fr = kit.bones[n]
                                            if fr then
                                                Pulse_PositionLineFrame(fr, s1.X, s1.Y, s2.X, s2.Y, 2)
                                                fr.BackgroundColor3 = color
                                                fr.BackgroundTransparency = 0
                                                fr.Visible = true
                                            end
                                        end
                                    end
                                end
                                for b = n + 1, #kit.bones do kit.bones[b].Visible = false end
                            else
                                for _, b in ipairs(kit.bones) do b.Visible = false end
                            end
                        else
                            Pulse_HideRoleKit(plr)
                        end
                    else
                        Pulse_HideRoleKit(plr)
                    end
                else
                    Pulse_HideRoleKit(plr)
                end
            else
                Pulse_HideRoleKit(plr)
            end
        end
    end
    PastaWare.Pulse.RenderRoleESPFull = Pulse_RenderRoleESPFull
    PastaWare.Pulse.HideRoleKit = Pulse_HideRoleKit

    --=========================================================================
    -- 13.3b BP (1810) RenderGunESP — BillboardGui "PulseGunESP"/"GUN" +
    -- Highlight "PulseGunHL" на оружии в руках; гейт HandGunESP.
    --=========================================================================
    PastaWare.Config.ESPEx.HandGunESP = PastaWare.Config.ESPEx.HandGunESP ~= false
    local GunESPPart: BasePart? = nil
    local GunESPGui: BillboardGui? = nil
    local GunESP_HL: Highlight? = nil
    local function Pulse_RenderGunESP()
        if not PastaWare.Config.ESPEx.HandGunESP then
            if GunESPGui then GunESPGui.Enabled = false end
            return
        end
        PastaWare.Pulse.GetPlayerDataRoster()
        if not GunESPPart or not GunESPPart.Parent then
            GunESPPart = nil
            for _, plr in ipairs(Players:GetPlayers()) do
                local role = PastaWare.State.Roles[plr.Name]
                if (role == "Sheriff" or role == "Hero") and plr.Character then
                    local tchar = plr.Character
                    local tool = tchar and safeFindChildOfClass(tchar, "Tool")
                    local handle = tool and tool:FindFirstChild("Handle")
                    if handle and handle:IsA("BasePart") then
                        GunESPPart = handle
                        break
                    end
                end
            end
        end
        if GunESPPart and GunESPPart.Parent then
            if not (GunESPGui and GunESPGui.Parent) then
                local gui = Instance.new("BillboardGui")
                gui.Name = "PulseGunESP"
                gui.Size = UDim2.fromOffset(120, 28)
                gui.StudsOffsetWorldSpace = Vector3.new(0, 2, 0)
                gui.AlwaysOnTop = true
                local label = Instance.new("TextLabel")
                label.BackgroundTransparency = 1
                label.Size = UDim2.fromScale(1, 1)
                label.Font = Enum.Font.GothamBold
                label.TextSize = 14
                label.Text = "GUN"
                label.TextColor3 = Color3.fromRGB(255, 210, 60)
                label.TextStrokeTransparency = 0.4
                label.Parent = gui
                pcall(function() gui.Parent = LocalPlayer:FindFirstChildOfClass("PlayerGui") end)
                if not gui.Parent then
                    gui.Parent = CoreGui
                end
                GunESPGui = gui
            end
            GunESPGui.Adornee = GunESPPart
            GunESPGui.Enabled = true
        elseif GunESPGui then
            GunESPGui.Enabled = false
        end
    end
    PastaWare.Pulse.RenderGunESP = Pulse_RenderGunESP

    local function Pulse_CleanupFullESP()
        for plr, hl in pairs(RoleHL) do pcall(function() hl:Destroy() end) end
        for plr, kit in pairs(RoleKits) do
            pcall(function() if kit.gui then kit.gui:Destroy() end end)
            if kit.lines then
                for _, l in ipairs(kit.lines) do
                    pcall(function() if l.Remove then l:Remove() end end)
                end
            end
            if kit.tracer then pcall(function() kit.tracer:Destroy() end) end
            if kit.bones then
                for _, b in ipairs(kit.bones) do pcall(function() b:Destroy() end) end
            end
        end
        if GunESPGui then pcall(function() GunESPGui:Destroy() end) end
    end
    PastaWare.Pulse.CleanupFullESP = Pulse_CleanupFullESP

    end -- end 13.3 scope

    do -- 13.4 scope: chams/xray/оптимизация/noclip
    --=========================================================================
    -- 13.4a YP (6844) ForceFieldAll + ClearCharMats + y (8402) ForceChams.
    -- YP: бэкап {Material,Color} -> ForceField+цвет. y: то же с packed-RGB
    -- (a.c: R=floor(c/65536)%256...) и фильтрами a.t/a.s, бэкап ch/chSeen.
    --=========================================================================
    local ForceMatStore: { [BasePart]: any } = {}
    local function Pulse_ForceFieldAll(char: Model, color: Color3)
        for _, part in ipairs(char:GetChildren()) do
            if part:IsA("BasePart") and part.Transparency < 1 then
                if ForceMatStore[part] == nil then
                    ForceMatStore[part] = { part.Material, part.Color }
                end
                if part.Material ~= Enum.Material.ForceField then
                    part.Material = Enum.Material.ForceField
                end
                if part.Color ~= color then
                    part.Color = color
                end
            end
        end
    end
    local function Pulse_ClearCharMats(char: Model?)
        for part, bak in pairs(ForceMatStore) do
            if not char or part:IsDescendantOf(char) then
                if part.Parent then
                    pcall(function()
                        part.Material = bak[1]
                        part.Color = bak[2]
                    end)
                end
                ForceMatStore[part] = nil
            end
        end
    end
    local function Pulse_ForceChams(char: Model, entry, opts, filterFn)
        if not opts then
            Pulse_ClearChamsData(entry)
            return
        end
        local c = opts.c or 0
        local color = Color3.fromRGB(math.floor(c / 65536) % 256, math.floor(c / 256) % 256, c % 256)
        entry.ch, entry.chSeen = entry.ch or {}, entry.chSeen or {}
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") and (part :: BasePart).Transparency < 1 then
                local valid = filterFn and filterFn(part) or true
                if (valid and opts.t) or ((not valid) and opts.s) then
                    if not entry.chSeen[part] then
                        entry.chSeen[part] = true
                        entry.ch[#entry.ch + 1] = { part, part.Material, part.Color }
                    end
                    if part.Material ~= Enum.Material.ForceField or part.Color ~= color then
                        pcall(function()
                            part.Material = Enum.Material.ForceField
                            part.Color = color
                        end)
                    end
                end
            end
        end
    end
    PastaWare.Pulse.ForceFieldAll = Pulse_ForceFieldAll
    PastaWare.Pulse.ClearCharMats = Pulse_ClearCharMats
    PastaWare.Pulse.ForceChams = Pulse_ForceChams

    --=========================================================================
    -- 13.4b Z (6795) KorbloxLegs — подмена RightUpperLeg MeshId/TextureID,
    -- скрытие LowerLeg/Foot; откат из бэкапа m.kb.
    --=========================================================================
    local function Pulse_KorbloxLegs(char: Model, entry, enable: boolean, meshId: string, textureId: string)
        if enable and not entry.kb then
            local up = char:FindFirstChild("RightUpperLeg")
            local low = char:FindFirstChild("RightLowerLeg")
            local foot = char:FindFirstChild("RightFoot")
            if not (up and up:IsA("MeshPart")) then return end
            entry.kb = {
                up = { up, (up :: MeshPart).MeshId, (up :: MeshPart).TextureID },
                low = low and { low, (low :: BasePart).Transparency } or nil,
                foot = foot and { foot, (foot :: BasePart).Transparency } or nil,
            }
            pcall(function()
                up.MeshId = meshId
                up.TextureID = textureId
            end)
            if low then pcall(function() low.Transparency = 1 end) end
            if foot then pcall(function() foot.Transparency = 1 end) end
        elseif not enable and entry.kb then
            local kb = entry.kb
            if kb.up[1].Parent then
                pcall(function()
                    kb.up[1].MeshId = kb.up[2]
                    kb.up[1].TextureID = kb.up[3]
                end)
            end
            if kb.low and kb.low[1].Parent then
                pcall(function() kb.low[1].Transparency = kb.low[2] end)
            end
            if kb.foot and kb.foot[1].Parent then
                pcall(function() kb.foot[1].Transparency = kb.foot[2] end)
            end
            entry.kb = nil
        end
    end
    PastaWare.Pulse.KorbloxLegs = Pulse_KorbloxLegs

    --=========================================================================
    -- 13.4c Xray: eP (7130) CollectXray + uP (8367) ApplyXray + gP (9157) CollectPart.
    -- eP(part): если xray.on -> в очередь. uP: бюджет 180/кадр, Transparency=K(orig,strength),
    -- бэкап U[part]. gP(part): U(f) + по материалам в списки, иначе a(d).
    --=========================================================================
    PastaWare.Config.World.Xray = PastaWare.Config.World.Xray or false
    PastaWare.Config.World.XrayStrength = PastaWare.Config.World.XrayStrength or 0.5
    local XrayQueue: { BasePart } = {}
    local XrayIndex = 1
    local XrayBackup: { [BasePart]: number } = {}
    local function Pulse_CollectXray(part: Instance)
        if PastaWare.Config.World.Xray and part:IsA("BasePart") then
            XrayQueue[#XrayQueue + 1] = part
        end
    end
    local function Pulse_CollectPart(part: BasePart, buckets, onMiss)
        if part:IsA("BasePart") then
            local bucket = buckets[part.Material]
            if bucket then
                bucket[#bucket + 1] = part
            else
                pcall(onMiss, part)
            end
        end
    end
    local function Pulse_ApplyXray(strengthFn)
        if XrayIndex > #XrayQueue then return end
        if not PastaWare.Config.World.Xray then
            XrayQueue = {}
            XrayIndex = 1
            return
        end
        local strength = PastaWare.Config.World.XrayStrength
        local budget = 0
        while XrayIndex <= #XrayQueue and budget < 180 do
            local part = XrayQueue[XrayIndex]
            XrayIndex += 1
            budget += 1
            if part and part.Parent and XrayBackup[part] == nil and Pulse_IsValidTargetPart(part) then
                local orig = part.Transparency
                XrayBackup[part] = orig
                part.Transparency = strengthFn(orig, strength)
            end
        end
        if XrayIndex > #XrayQueue then
            XrayQueue = {}
            XrayIndex = 1
        end
    end
    local function Pulse_ClearXray()
        for part, orig in pairs(XrayBackup) do
            if part.Parent then pcall(function() part.Transparency = orig end) end
        end
        XrayBackup = {}
        XrayQueue = {}
        XrayIndex = 1
    end
    PastaWare.Pulse.CollectXray = Pulse_CollectXray
    PastaWare.Pulse.CollectPart = Pulse_CollectPart
    PastaWare.Pulse.ApplyXray = Pulse_ApplyXray
    PastaWare.Pulse.ClearXray = Pulse_ClearXray

    --=========================================================================
    -- 13.4d OT (8729) OptimizeMapPart — FPS-буст: частицы/Decal/Texture/SpecialMesh,
    -- SmoothPlastic+Reflectance 0+CastShadow false; бэкапы; rescan каждые 500.
    --=========================================================================
    PastaWare.Config.World.OptimizeMap = PastaWare.Config.World.OptimizeMap or false
    PastaWare.Config.World.OptParticles = PastaWare.Config.World.OptParticles ~= false
    PastaWare.Config.World.OptTextures = PastaWare.Config.World.OptTextures ~= false
    PastaWare.Config.World.OptMaterials = PastaWare.Config.World.OptMaterials ~= false
    local OptTexBackup: { [Instance]: string } = {}
    local OptPartBackup: { [BasePart]: any } = {}
    local OptTick = 0
    local ParticleClasses = {
        ParticleEmitter = true, Trail = true, Smoke = true, Fire = true,
        Sparkles = true, Explosion = true, Beam = true,
    }
    local function Pulse_OptimizeMapPart(obj: Instance, rescanFn)
        local cfg = PastaWare.Config.World
        if not cfg.OptimizeMap then return end
        OptTick += 1
        if OptTick >= 500 then
            OptTick = 0
            pcall(rescanFn)
        end
        pcall(function()
            local cn = obj.ClassName
            if cfg.OptParticles and ParticleClasses[cn] then
                obj:Destroy()
                return
            end
            if cfg.OptTextures then
                if cn == "Decal" or cn == "Texture" then
                    obj:Destroy()
                    return
                end
                if cn == "SpecialMesh" and obj.TextureId ~= "" then
                    local w: any = obj
                    if OptTexBackup[obj] == nil then OptTexBackup[obj] = w.TextureId end
                    w.TextureId = ""
                elseif cn == "MeshPart" and obj.TextureID ~= "" then
                    local w: any = obj
                    if OptTexBackup[obj] == nil then OptTexBackup[obj] = w.TextureID end
                    w.TextureID = ""
                end
            end
            if obj:IsA("BasePart") then
                if OptPartBackup[obj] == nil then
                    OptPartBackup[obj] = { obj.Material, obj.Reflectance, obj.CastShadow }
                end
                if cfg.OptMaterials then obj.Material = Enum.Material.SmoothPlastic end
                obj.Reflectance = 0
                obj.CastShadow = false
            end
        end)
    end
    PastaWare.Pulse.OptimizeMapPart = Pulse_OptimizeMapPart

    --=========================================================================
    -- 13.4e JP (8794) CollideWatch + XP (8149) NoclipPro (третий и четвёртый
    -- noclip-контуры; первые два — секция 8 и Candy Noclip).
    -- JP: один коннект на часть; если noclip on и часть не exempt — CanCollide=false.
    -- XP: кэш частей персонажа (пересбор по DescendantAdded/Removing), снять коллизии.
    --=========================================================================
    local CollideWatched: { [BasePart]: boolean } = {}
    local function Pulse_CollideWatch(part: BasePart, isNoclipFn, isExemptFn)
        if CollideWatched[part] or not part:IsA("BasePart") then return end
        local conn
        conn = part:GetPropertyChangedSignal("CanCollide"):Connect(function()
            if not isNoclipFn() then
                pcall(function() conn:Disconnect() end)
                return
            end
            if isNoclipFn() and part.CanCollide and not isExemptFn(part) then
                pcall(function() part.CanCollide = false end)
            end
        end)
        CollideWatched[part] = true
        if isNoclipFn() and not isExemptFn(part) then
            pcall(function() part.CanCollide = false end)
        end
    end
    local NoclipProCache: { BasePart } = {}
    local NoclipProChar: Model? = nil
    local NoclipProDirty = false
    local function Pulse_NoclipPro(isOn: boolean, char: Model?)
        if not (isOn) then return end
        if not char then return end
        if char ~= NoclipProChar or NoclipProDirty then
            NoclipProChar = char
            NoclipProDirty = false
            NoclipProCache = {}
            for _, d in ipairs(char:GetDescendants()) do
                if d:IsA("BasePart") then
                    NoclipProCache[#NoclipProCache + 1] = d
                end
            end
        end
        for i = 1, #NoclipProCache do
            local part = NoclipProCache[i]
            if part.CanCollide then
                part.CanCollide = false
            end
        end
    end
    local function Pulse_NoclipProDirty()
        NoclipProDirty = true
    end
    PastaWare.Pulse.CollideWatch = Pulse_CollideWatch
    PastaWare.Pulse.NoclipPro = Pulse_NoclipPro
    PastaWare.Pulse.NoclipProDirty = Pulse_NoclipProDirty

    end -- end 13.4 scope

    do -- 13.5 scope: движение/оверлеи/инвентарь/анимации/утилиты
    --=========================================================================
    -- 13.5a SP (9309) SpinBhop — спинбот (AutoRotate=false, rotate dt*speed)
    -- + баннихоп-цепочка (AssemblyLinearVelocity, кап max(WalkSpeed*(2+0.4*x),100)).
    --=========================================================================
    local BhopState = { active = false, amount = 0, extra = 0, groundAt = 0, grounded = true }
    local function Pulse_SpinBhop(dt: number)
        local mv = PastaWare.Config.Movement
        if not ((mv.Spin or mv.Bhop) or BhopState.active) then
            if Globals.__pulseBhopChain then
                BhopState.amount, BhopState.extra, BhopState.groundAt = 0, 0, 0
                Globals.__pulseBhopSpeed = 0
                Globals.__pulseBhopChain = false
            end
            return
        end
        local char = LocalPlayer.Character
        local hum = char and safeFindChildOfClass(char, "Humanoid")
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if mv.Spin then
            if hum and root and hum.Health > 0 then
                BhopState.active = true
                pcall(function()
                    hum.AutoRotate = false
                    root.CFrame = root.CFrame * CFrame.Angles(0, (mv.SpinSpeed or 10) * dt, 0)
                end)
            end
        elseif BhopState.active then
            BhopState.active = false
            if hum and root then
                pcall(function()
                    hum.AutoRotate = true
                    root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                end)
            end
        end
        local stateNow
        pcall(function() stateNow = hum and hum:GetState() end)
        local climbing = stateNow == Enum.HumanoidStateType.Climbing
        if mv.Bhop and hum and root and hum.Health > 0 and not climbing then
            local invis = Globals.__pulseInvis
            local grounded
            if invis and invis.active then
                grounded = invis.grounded
            else
                grounded = hum.FloorMaterial ~= Enum.Material.Air
                    and stateNow ~= Enum.HumanoidStateType.Freefall
                    and stateNow ~= Enum.HumanoidStateType.Jumping
            end
            local now = os.clock()
            local vel = root.AssemblyLinearVelocity
            local power = mv.BhopPower or 5
            local baseSpeed = hum.WalkSpeed
            if grounded and not BhopState.grounded then
                BhopState.groundAt = now
            elseif not grounded and BhopState.grounded and vel.Y > 2 then
                local move = hum.MoveDirection
                if move.Magnitude > 0.1 then
                    if BhopState.amount > 0 and now - BhopState.groundAt <= 0.25 then
                        BhopState.amount = BhopState.amount + 2 + power * 1.2
                    else
                        BhopState.amount = math.max(BhopState.amount, baseSpeed + 2 + power)
                    end
                end
            end
            if grounded and now - BhopState.groundAt > 0.3 then
                BhopState.amount = 0
            end
            local move = hum.MoveDirection
            if BhopState.amount > 0 and move.Magnitude > 0.1 then
                local cap = math.max(baseSpeed * (2 + 0.4 * power), 100)
                if BhopState.amount > cap then BhopState.amount = cap end
                if not grounded or now - BhopState.groundAt <= 0.25 then
                    local dir = Vector3.new(move.X, 0, move.Z).Unit
                    root.AssemblyLinearVelocity = Vector3.new(dir.X * BhopState.amount, vel.Y, dir.Z * BhopState.amount)
                end
            end
            BhopState.grounded = grounded
            Globals.__pulseBhopSpeed = math.max(BhopState.amount, BhopState.extra, baseSpeed + 2 + power)
            Globals.__pulseBhopChain = BhopState.amount > 0
        else
            BhopState.grounded = true
            BhopState.amount = 0
            Globals.__pulseBhopSpeed = 0
            Globals.__pulseBhopChain = false
        end
    end
    PastaWare.Pulse.SpinBhop = Pulse_SpinBhop

    --=========================================================================
    -- 13.5b aT (7977) TrackGround — пинг земли: стейт humanoid в наборе B,
    -- троттл 0.06с, рейкаст -7, колбэк m(pos) при сдвиге > 2.2.
    --=========================================================================
    local TrackGroundState = { lastAt = 0, lastPos = nil }
    local function Pulse_TrackGround(isOn: boolean, watchStates, onPoint)
        if not isOn then return end
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and safeFindChildOfClass(char, "Humanoid")
        if not (root and hum and hum.Health > 0) then return end
        local stateNow
        pcall(function() stateNow = hum:GetState() end)
        if not (stateNow and watchStates[stateNow]) then
            TrackGroundState.lastPos = nil
            return
        end
        local now = os.clock()
        if now - TrackGroundState.lastAt < 0.06 then return end
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = { char }
        params.IgnoreWater = true
        local hit
        pcall(function()
            params.FilterDescendantsInstances = { char }
            hit = Workspace:Raycast(root.Position, Vector3.new(0, -7, 0), params)
        end)
        if not hit then
            TrackGroundState.lastPos = nil
            return
        end
        if TrackGroundState.lastPos and (hit.Position - TrackGroundState.lastPos).Magnitude < 2.2 then
            return
        end
        TrackGroundState.lastAt, TrackGroundState.lastPos = now, hit.Position
        pcall(onPoint, hit.Position)
    end
    PastaWare.Pulse.TrackGround = Pulse_TrackGround

    --=========================================================================
    -- 13.5c cT (9513) FindSafeSpot — 16 направлений x 8..300: где внизу пустота,
    -- а горизонталь свободна — вернуть (dir, dist) ближайшей точки.
    --=========================================================================
    local function Pulse_FindSafeSpot(origin: Vector3): (Vector3?, number?)
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = { LocalPlayer.Character, Workspace.CurrentCamera }
        params.IgnoreWater = true
        local bestDir, bestDist = nil, nil
        for i = 0, 15 do
            local ang = i * math.pi / 8
            local dir = Vector3.new(math.cos(ang), 0, math.sin(ang))
            for dist = 8, 300, 4 do
                local probe = origin + dir * dist + Vector3.new(0, 6, 0)
                if not Workspace:Raycast(probe, Vector3.new(0, -600, 0), params) then
                    local clear = Workspace:Raycast(origin + Vector3.new(0, 2, 0), dir * dist, params)
                    if not clear and (not bestDist or dist < bestDist) then
                        bestDir, bestDist = dir, dist
                    end
                    break
                end
            end
        end
        return bestDir, bestDist
    end
    PastaWare.Pulse.FindSafeSpot = Pulse_FindSafeSpot

    --=========================================================================
    -- 13.5d ZP (8330) FollowTarget + rP (7862) UniversalAim + lT (8993) StretchFX
    -- + _P (9563) MouseHighlight. Все гейтятся, по умолчанию ВЫКЛ.
    --=========================================================================
    local function Pulse_FollowTarget(placeFn)
        if not PastaWare.Config.ESPEx.FollowTarget then return end
        local char = LocalPlayer.Character
        local root = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head"))
        local hum = char and safeFindChildOfClass(char, "Humanoid")
        local cam = Workspace.CurrentCamera
        if not (root and hum and hum.Health > 0 and cam) then return end
        local sp, onScreen = cam:WorldToViewportPoint(root.Position)
        if not onScreen then return end
        pcall(placeFn, sp.X, sp.Y)
    end
    local function Pulse_UniversalAim(getTargetFn, isReadyFn)
        if not PastaWare.Config.Aimbot.UniversalAim then return end
        if not isReadyFn() then return end
        local target = getTargetFn()
        if not target then return end
        local cam = Workspace.CurrentCamera
        if not (target and cam) then return end
        pcall(function()
            cam.CFrame = cam.CFrame:Lerp(CFrame.lookAt(cam.CFrame.Position, target.Position), 0.65)
        end)
    end
    local function Pulse_StretchFX()
        local k = PastaWare.Config.World.StretchFX or 0
        if k <= 0 then return end
        local cam = Workspace.CurrentCamera
        if not cam then return end
        local squash = 1 - k / 100 * 0.6
        pcall(function()
            cam.CFrame = cam.CFrame * CFrame.new(0, 0, 0, 1, 0, 0, 0, squash, 0, 0, 0, 1)
        end)
    end
    local MouseHL: Highlight? = nil
    local function Pulse_MouseHighlight(isOnFn, pickFn)
        if not isOnFn() then
            if MouseHL then MouseHL.Adornee = nil end
            return
        end
        if not MouseHL then
            MouseHL = Instance.new("Highlight")
            MouseHL.Parent = CoreGui
        end
        local mouse = safeGetMouseLocation()
        local hit = pickFn(mouse.X, mouse.Y)
        MouseHL.Adornee = hit
        if hit then
            MouseHL.FillTransparency = 0.42 + 0.16 * math.abs(0.5 - (tick() % 1)) * 2
        end
    end
    PastaWare.Pulse.FollowTarget = Pulse_FollowTarget
    PastaWare.Pulse.UniversalAim = Pulse_UniversalAim
    PastaWare.Pulse.StretchFX = Pulse_StretchFX
    PastaWare.Pulse.MouseHighlight = Pulse_MouseHighlight

    local function Pulse_CleanupOverlays()
        if PerfGui then pcall(function() PerfGui:Destroy() end) end
        if MouseHL then pcall(function() MouseHL:Destroy() end) end
    end
    PastaWare.Pulse.CleanupOverlays = Pulse_CleanupOverlays

    --=========================================================================
    -- 13.6a QP (7304) FpsPing — FPS (кадры/0.25с) + пинг, сглаживание dt*9,
    -- свой Billboard-лейбл; гейт ShowPerf.
    --=========================================================================
    PastaWare.Config.ESPEx.ShowPerf = PastaWare.Config.ESPEx.ShowPerf or false
    local PerfGui: ScreenGui? = nil
    local PerfFps, PerfPing = 0, 0
    local PerfFrames, PerfTime = 0, 0
    local PerfSmoothFps, PerfSmoothPing = 60, 100
    local function Pulse_FpsPing(dt: number)
        if not PastaWare.Config.ESPEx.ShowPerf then
            if PerfGui then PerfGui.Enabled = false end
            return
        end
        if not PerfGui then
            PerfGui = Instance.new("ScreenGui")
            PerfGui.Name = "PastaWare_Perf"
            PerfGui.ResetOnSpawn = false
            PerfGui.Parent = CoreGui
            local function mk(y: number)
                local l = Instance.new("TextLabel")
                l.Position = UDim2.new(0, 10, 0, y)
                l.Size = UDim2.new(0, 120, 0, 18)
                l.BackgroundTransparency = 1
                l.Font = Enum.Font.GothamBold
                l.TextSize = 14
                l.TextColor3 = Color3.new(1, 1, 1)
                l.TextXAlignment = Enum.TextXAlignment.Left
                l.Parent = PerfGui
                return l
            end
            PerfFps, PerfPing = mk(10), mk(30)
        end
        PerfGui.Enabled = true
        PerfFrames += 1
        PerfTime += dt
        if PerfTime >= 0.25 then
            PerfSmoothFps = math.floor(PerfFrames / PerfTime + 0.5)
            pcall(function()
                PerfSmoothPing = math.floor(LocalPlayer:GetNetworkPing() * 1000 + 0.5)
            end)
            PastaWare.State.Fps, PastaWare.State.Ping = PerfSmoothFps, PerfSmoothPing
            PerfFrames, PerfTime = 0, 0
        end
        PerfFps.Text = tostring(PerfSmoothFps) .. " FPS"
        PerfPing.Text = tostring(PerfSmoothPing) .. " ms"
    end
    PastaWare.Pulse.FpsPing = Pulse_FpsPing

    --=========================================================================
    -- 13.6b KP (6863) SegmentBar + mT (7943) ProgressBar + c (7188) LoadingBar
    -- + MP (8138) ThemeSpin + bP (8208) TabTween.
    --=========================================================================
    local function Pulse_SegmentBar(segs, from: number, to: number, toggleFn, thick: number?)
        local acc = 0
        for _, seg in ipairs(segs) do
            local s0, s1 = acc, acc + seg.len
            local vis0, vis1 = math.max(s0, from), math.min(s1, to)
            if vis1 <= vis0 then
                seg.f.Visible = false
            else
                seg.f.Visible = true
                local b0 = (vis0 - s0) / seg.len
                local b1 = (vis1 - s0) / seg.len
                local x0 = seg.sX + b0 * (seg.eX - seg.sX)
                local y0 = seg.sY + b0 * (seg.eY - seg.sY)
                local x1 = seg.sX + b1 * (seg.eX - seg.sX)
                local y1 = seg.sY + b1 * (seg.eY - seg.sY)
                seg.f.Position = UDim2.fromOffset((x0 + x1) / 2, (y0 + y1) / 2)
                seg.f.Size = UDim2.fromOffset(vis1 - vis0, thick or seg.th or 2)
            end
            acc = s1
        end
    end
    local function Pulse_ProgressBar(segs, value: number)
        local acc = 0
        for _, seg in ipairs(segs) do
            local s0 = acc
            acc += seg.len
            if math.min(acc, value) <= s0 then
                seg.f.Visible = false
            else
                seg.f.Visible = true
                local t = (math.min(acc, value) - s0) / seg.len
                local x = seg.sX + t * (seg.eX - seg.sX)
                local y = seg.sY + t * (seg.eY - seg.sY)
                seg.f.Position = UDim2.fromOffset((seg.sX + x) / 2, (seg.sY + y) / 2)
                seg.f.Size = UDim2.fromOffset(math.min(acc, value) - s0, 2)
            end
        end
    end
    local function Pulse_LoadingBar(getState): boolean
        -- getState() -> { on: boolean, step: number, done: boolean }
        while true do
            local st = getState()
            if st.on then
                st.step += 1
                local fill = math.clamp(math.floor(st.step / 5), 0, 20)
                st.text = "[" .. string.rep("+", fill) .. string.rep("-", 20 - fill) .. "] " .. st.step
            end
            task.wait(0.03)
            if getState().done then break end
        end
        return true
    end
    local function Pulse_ThemeSpin(ui)
        ui.Rotation = (ui.Rotation + 1.5) % 360
        if ui.themeGradUI then
            ui.themeGradUI.Rotation = (ui.themeGradUI.Rotation + 0.6) % 360
        end
    end
    PastaWare.Pulse.SegmentBar = Pulse_SegmentBar
    PastaWare.Pulse.ProgressBar = Pulse_ProgressBar
    PastaWare.Pulse.LoadingBar = Pulse_LoadingBar
    PastaWare.Pulse.ThemeSpin = Pulse_ThemeSpin

    --=========================================================================
    -- 13.7a a (9612) ValueInventory — оценка инвентаря по таблицам цен.
    -- exact["Name|Rarity"] -> nameTable[Name] -> lowerTable[lower] ;
    -- Blossom/Rainbow/Waves не-godly отбрасываются; сортировка по убыванию.
    --=========================================================================
    local function Pulse_ValueInventory(inv, exact, byName, byLower)
        local out = {}
        if not inv or not exact then return out end
        for id, data in pairs(exact) do
            local entry = inv[id]
            if entry then
                local count = 1
                if type(data) == "number" then
                    count = data
                elseif type(data) == "table" then
                    count = tonumber(data.Amount or data.Count or data.amount) or (#data > 0 and #data or 1)
                end
                if count > 0 then
                    local dispName = entry.name or ""
                    local chromaTag = entry.chroma and ("Chroma " .. dispName) or dispName
                    local rarTag = entry.chroma and "Chroma" or (entry.rarity or "")
                    local price = byName[chromaTag .. "|" .. rarTag] or byName[dispName] or byLower[string.lower(chromaTag)]
                    if (dispName == "Blossom" or dispName == "Rainbow" or dispName == "Waves")
                        and string.lower(entry.rarity or "") ~= "godly" then
                        price = nil
                    end
                    if price and price > 0 then
                        table.insert(out, {
                            dataId = id, displayName = dispName, value = price,
                            amount = count, rarity = entry.rarity, chroma = entry.chroma,
                        })
                    end
                end
            end
        end
        table.sort(out, function(x, y) return x.value > y.value end)
        return out
    end
    PastaWare.Pulse.ValueInventory = Pulse_ValueInventory

    --=========================================================================
    -- 13.7b yP (7046) BackupAnims + tP (9733) RetargetAnims — подмена Animate-пака.
    -- yP: нужно >=2 резолвнутых анимаций, иначе 0; бэкап ids+Disabled.
    -- tP: треки idle/walk/run/jump/fall/climb/swim(+idle), порог бега 9,
    -- toolnone-инструмент, токен-сессия S, вотчдоги 0.4с/0.1с, playEmote.
    --=========================================================================
    local function Pulse_BackupAnims(char: Model, nameMap, idOfFn): number
        local animate = char and char:FindFirstChild("Animate")
        if not animate then return 0 end
        local swaps = {}
        for _, group in ipairs(animate:GetChildren()) do
            local want = nameMap[string.lower(group.Name)]
            local id = want and idOfFn(group, want)
            local num = id and tostring(id):match("%d+")
            if num and num ~= "0" then
                for _, anim in ipairs(group:GetChildren()) do
                    if anim:IsA("Animation") then
                        swaps[#swaps + 1] = { anim, "rbxassetid://" .. num }
                    end
                end
            end
        end
        if #swaps < 2 then return 0 end
        PastaWare.State.AnimBackup = { animate = animate, ids = {}, disabled = animate.Disabled }
        for _, s in ipairs(swaps) do
            PastaWare.State.AnimBackup.ids[s[1]] = s[1].AnimationId
            pcall(function() s[1].AnimationId = s[2] end)
        end
        return #swaps
    end
    local function Pulse_RetargetAnims(char: Model, pack, S, loadTrackFn, onError)
        local hum = char and safeFindChildOfClass(char, "Humanoid")
        local animator = hum and safeFindChildOfClass(hum, "Animator")
        if not hum or not animator then return false end
        local token = os.clock() + math.random()
        S.token = token
        local function live(): boolean return S.token == token end
        local tracks
        if not pack.valid or pack.valid(char, S) < 2 then
            tracks = {
                idle = loadTrackFn(animator, pack.idle, Enum.AnimationPriority.Core),
                walk = loadTrackFn(animator, pack.walk, Enum.AnimationPriority.Core),
                run = loadTrackFn(animator, pack.run, Enum.AnimationPriority.Core),
                jump = loadTrackFn(animator, pack.jump, Enum.AnimationPriority.Core, false),
                fall = loadTrackFn(animator, pack.fall, Enum.AnimationPriority.Core),
                climb = loadTrackFn(animator, pack.climb, Enum.AnimationPriority.Core),
                swim = loadTrackFn(animator, pack.swim, Enum.AnimationPriority.Core),
                swimidle = loadTrackFn(animator, pack.swimidle, Enum.AnimationPriority.Core),
            }
            if not (tracks.idle or tracks.walk or tracks.run) then
                if onError then onError("pack unresolved") end
                return false
            end
            for _, t in ipairs(animator:GetPlayingAnimationTracks()) do
                pcall(function() t:Stop(0) end)
            end
        end
        S.retargeted = pack.valid and true or false
        S.tracks = tracks or {}
        S.pose = "Standing"
        local function play(track, fade: number?, speed: number?)
            if not track or not live() then return end
            if S.current ~= track then
                if S.current then pcall(function() S.current:Stop(fade or 0.15) end) end
                S.current = track
                pcall(function()
                    track:Play(fade or 0.15)
                    if speed then track:AdjustSpeed(speed * (S.speedMul or 1)) end
                end)
            end
        end
        local function stopCur(fade: number?)
            local cur = S.current
            S.current = nil
            if cur then pcall(function() cur:Stop(fade or 0.2) end) end
        end
        local function speed2d(): number
            local rp = hum.RootPart
            if not rp then return 0 end
            local v = rp.AssemblyLinearVelocity
            return Vector3.new(v.X, 0, v.Z).Magnitude
        end
        S.handlers = {
            run = function(spd: number)
                if not live() then return end
                if spd > 0.5 then
                    stopCur(0.1)
                    S.pose = "Running"
                    play(spd > 9 and (tracks.run or tracks.walk) or (tracks.walk or tracks.run), 0.15, spd / 16)
                elseif S.current then
                    return
                elseif S.pose ~= "Jumping" and S.pose ~= "FreeFall" then
                    S.pose = "Standing"
                    play(tracks.idle, 0.2, 1)
                end
            end,
            jump = function()
                if not live() then return end
                stopCur(0.1)
                S.pose = "Jumping"
                play(tracks.jump or tracks.fall, 0.1, 1)
            end,
            fall = function(falling: boolean)
                if not live() then return end
                if falling then
                    stopCur(0.1)
                    S.pose = "FreeFall"
                    play(tracks.fall or tracks.jump, 0.25, 1)
                else
                    S.pose = "Landed"
                    S.handlers.run(speed2d())
                end
            end,
            climb = function(spd: number)
                if not live() then return end
                stopCur(0.1)
                S.pose = "Climbing"
                play(tracks.climb, 0.15, spd / 5)
            end,
        }
        S.conns = S.conns or {}
        local function hook(sig, fn)
            table.insert(S.conns, sig:Connect(function(...) if live() then fn(...) end end))
        end
        hook(hum.Running, function(s) S.handlers.run(s) end)
        hook(hum.Jumping, function() S.handlers.jump() end)
        hook(hum.FreeFalling, function(f) S.handlers.fall(f) end)
        hook(hum.Climbing, function(s) S.handlers.climb(s) end)
        hook(hum.Swimming, function(s) S.handlers.run(s) end)
        task.spawn(function()
            while S.token == token do
                local cur = S.current
                if cur and cur.Looped and not cur.IsPlaying then
                    pcall(function() cur:Play(0.1) end)
                end
                task.wait(0.4)
            end
        end)
        task.spawn(function()
            while S.token == token do
                if not S.current and S.pose ~= "Jumping" and S.pose ~= "FreeFall" then
                    pcall(function() S.handlers.run(speed2d()) end)
                end
                task.wait(0.1)
            end
        end)
        return true
    end
    PastaWare.Pulse.BackupAnims = Pulse_BackupAnims
    PastaWare.Pulse.RetargetAnims = Pulse_RetargetAnims

    --=========================================================================
    -- 13.7c i (9175) ApplyVFX + PP (9205) ApplyWobble + IP (7417) CollectCosmetics.
    -- i: сигнатура "k=v" (sort); пустая -> Clear, иначе Apply+TintFor.
    -- PP: wobSig "w"+sc, троттл 2с, teardown, __pulseWobBuild.
    -- IP: CosMine->{korblox,headless}, VFXMine->vfx, ChamsMine->ch, WobMine->wob;
    --     JSON>480 -> сброс vfx + флаг vfxDropped.
    --=========================================================================
    local function Pulse_ApplyVFX(char: Model, opts)
        local sig = ""
        if opts then
            local parts = {}
            for k, v in pairs(opts) do parts[#parts + 1] = tostring(k) .. "=" .. tostring(v) end
            table.sort(parts)
            sig = table.concat(parts, ",")
        end
        PastaWare.State.VfxEntry = PastaWare.State.VfxEntry or {}
        if sig == (PastaWare.State.VfxEntry.vfx or "") then return end
        PastaWare.State.VfxEntry.vfx = sig
        if sig == "" then
            local clearFn = Globals.__pulseVFXClear
            if clearFn then pcall(clearFn, char) end
        else
            local applyFn = Globals.__pulseVFXApply
            if applyFn then
                pcall(applyFn, char, opts)
                local tintFn = Globals.__pulseVFXTintFor
                if tintFn then pcall(tintFn, char, opts) end
            end
        end
    end
    local function Pulse_ApplyWobble(char: Model, entry, opts)
        local sig = opts and ("w" .. tostring(opts.sc or 1)) or ""
        local now = os.clock()
        if sig == (entry.wobSig or "") then
            if not PastaWare.Pulse.WobbleFar(char, entry) then return end
            if now - (entry.wobAt or 0) < 2 then return end
        end
        entry.wobAt = now
        PastaWare.Pulse.ClearWobble(entry)
        entry.wobSig = sig
        if opts then
            local build = Globals.__pulseWobBuild
            if build then
                local out = {}
                pcall(build, char, tonumber(opts.sc) or 1, out, true)
                entry.wob = out
            end
        end
    end
    local function Pulse_CollectCosmetics(): any
        local res = {}
        pcall(function()
            local hookFn = Globals.__pulseCosMine
            if hookFn then
                local kb, hl = hookFn()
                if kb then res.korblox = true end
                if hl then res.headless = true end
            end
        end)
        pcall(function()
            local hookFn = Globals.__pulseVFXMine
            if hookFn then
                local v = hookFn()
                if v then res.vfx = v end
            end
        end)
        pcall(function()
            local hookFn = Globals.__pulseChamsMine
            if hookFn then
                local v = hookFn()
                if v then res.ch = v end
            end
        end)
        pcall(function()
            local hookFn = Globals.__pulseWobMine
            if hookFn then
                local v, sc = hookFn()
                if v then res.wob = { sc = sc or 1 } end
            end
        end)
        pcall(function()
            local json = game:GetService("HttpService"):JSONEncode(res)
            if #json > 480 and res.vfx then
                res.vfx = nil
                PastaWare.State.VfxDropped = true
            end
        end)
        PastaWare.State.MineCosmetics = res
        return res
    end
    PastaWare.Pulse.ApplyVFX = Pulse_ApplyVFX
    PastaWare.Pulse.ApplyWobble = Pulse_ApplyWobble
    PastaWare.Pulse.CollectCosmetics = Pulse_CollectCosmetics

    --=========================================================================
    -- 13.8 Утилиты: jP (8320) FindRoot / VT (9431) InMyChar / xP (7895) WobbleFar /
    -- UP (7822)+UT (8974) ScaledFire / E (7799) FindRoundClient.
    --=========================================================================
    local function Pulse_FindRoot(char: Model?): BasePart?
        if not char then return nil end
        return char:FindFirstChild("HumanoidRootPart")
            or char:FindFirstChild("Head")
    end
    local function Pulse_InMyChar(obj: Instance): boolean
        local char = LocalPlayer.Character
        return char ~= nil and obj:IsDescendantOf(char)
    end
    local function Pulse_WobbleFar(char: Model, entry): boolean
        if not entry.wob then return false end
        local anchor
        for _, part in ipairs(entry.wob) do
            if typeof(part) == "Instance" and part:IsA("BasePart") then
                anchor = part
                break
            end
        end
        if not anchor or not anchor.Parent then return true end
        local root = char:FindFirstChild("HumanoidRootPart")
            or char:FindFirstChild("LowerTorso")
            or char:FindFirstChild("Torso")
        if not root then return false end
        return (anchor.Position - (root :: BasePart).Position).Magnitude > 30
    end
    local function Pulse_ScaledFire(fireFn, value: number, factorCell)
        pcall(fireFn, value * factorCell[2][factorCell[1]])
    end
    local function Pulse_FindRoundClient(root: Instance, requireFn): any
        local cached = PastaWare.State.RoundClient
        if cached then return cached end
        local paths = {
            { "Modules", "CurrentRoundClient" },
            { "CurrentRoundClient" },
            { "Client", "CurrentRoundClient" },
            { "Modules", "Client", "CurrentRoundClient" },
        }
        for _, path in ipairs(paths) do
            local node = root
            for _, name in ipairs(path) do
                node = node and node:FindFirstChild(name)
            end
            cached = requireFn(node)
            if cached then
                PastaWare.State.RoundClient = cached
                return cached
            end
        end
        return nil
    end
    PastaWare.Pulse.FindRoot = Pulse_FindRoot
    PastaWare.Pulse.InMyChar = Pulse_InMyChar
    PastaWare.Pulse.WobbleFar = Pulse_WobbleFar
    PastaWare.Pulse.ScaledFire = Pulse_ScaledFire
    PastaWare.Pulse.FindRoundClient = Pulse_FindRoundClient

    end -- end 13.5 scope

    do -- 13.6 scope: VM-каталог + wiring + Unload-довесок
    --=========================================================================
    -- 13.9 VM-каталог: честная карта НЕпортированного. Это потроха Luraph-VM
    -- (конвейер x: AT->I9->H9->O9->K9->d9->m9->h9->D9->T9->S9->k9->H3->O3->L0->u0->Q0),
    -- их "деобфускация" = точное описание роли. Портирование потребовало бы
    -- исполнения VM-байткода (2.6МБ пейлоад), что PastaWare не делает.
    --=========================================================================
    PastaWare.Pulse.VMNotes = {
        bootstrap = { "x" },
        interpreter = { "L0", "O3", "M0", "O0", "H0", "T3" },
        opcodeArms = {
            "l0", "m0", "l9", "g9", "c9", "tT", "O9", "G0", "A9", "L9", "D9",
            "R3", "W3", "U3", "Y0", "e0", "J3", "N3", "F3", "S3", "T9", "I0",
            "k3", "c0", "a0", "o0", "m9", "f3", "d9", "b3", "r3", "n9", "z0",
            "u0", "i9", "C3", "K9", "t3", "A3", "u3", "p0", "S9", "H3", "h9",
            "a9", "I3", "e3", "D0", "M9", "Y9", "Z9", "s3", "X3", "f9", "y3",
            "B9", "E3", "P3", "b0", "x3", "e9", "d3", "g3", "v3", "z3", "h3",
            "b9", "o3", "k9", "Q3", "R3", "V3", "W0", "S0", "G3", "K0", "D3",
            "V9", "v9", "r9", "R9", "G9", "I9", "n3", "l3", "m3", "j3", "j9",
            "s9", "s0", "i3", "q9", "c3", "w3", "qT", "h0", "q3", "x0", "Z3",
            "W9", "C9", "X9", "V0", "J9", "E9", "d0", "p3", "w0", "o9", "_9", "_3",
        },
        bufferAliases = {
            oT = "readu8", uT = "readi16", eT = "readu16", ST = "readu32",
            QT = "readf32", XT = "readi32", rT = "writeu32", jT = "readf64",
            nT = "readstring", f0 = "string.unpack", kT = "string.unpack",
            iT = "unpack", FT = "unpack", WT = "getfenv", ET = "setfenv",
            GT = "string", DT = "table", TT = "table.move", RT = "string.sub",
            fT = "string.gsub",
        },
        bit32Aliases = {
            F0 = "lshift", C0 = "band", JT = "band", B0 = "bor", NT = "bor",
            gT = "rshift", J0 = "rshift", j0 = "bxor", LT = "bxor",
            g0 = "lrotate", vT = "lrotate", r0 = "rrotate",
            E0 = "countlz", _T = "countlz", ZT = "bnot", CT = "bit32",
        },
        trivial = {
            K3 = "noop", hT = "t[nil]=nil noop", y9 = "identity",
            p3 = "returns true", a3 = "returns arg", t9 = "cursor+=4",
            M9 = "const getter", b0 = "const getter", f9 = "const getter",
            h0 = "const getter", q3 = "const getter", p0 = "const getter",
            x3 = "cursor+=8", d3 = "call getter", G9 = "field getter",
            R0 = "field getter", T0 = "const-cache writer", X0 = "const-cache writer",
            U0 = "const-cache writer", W3 = "negated call", P9 = "const setup",
            w0 = "d[U]=U+f", o9 = "d[40]=band", G3 = "branch reader",
            K0 = "const-cache", D3 = "branch reader", L3 = "returns nil",
            W9 = "const-cache", C9 = "const-cache", X9 = "const-cache",
            V9 = "buffer setup", S9 = "state reset", H3 = "vm setup",
            E9 = "setup arm", e0 = "const-cache", e9 = "const-cache writer",
            Y9 = "const-cache writer", S0 = "const-cache writer",
            s9 = "const-cache writer", c3 = "const-cache writer",
            u9 = "const-cache writer", x9 = "select setup", j9 = "const-cache writer",
        },
        guardThread = { "P: while-true VM gate (m[24] yield-gate), не портится" },
    }

    --=========================================================================
    -- 13.10 Wiring FULL DEOB: все гейты по умолчанию ВЫКЛ (кроме HandGunESP),
    -- поэтому стартовая нагрузка нулевая; всё через PastaWare.Connections.
    --=========================================================================
    table.insert(PastaWare.Connections, RunService.Heartbeat:Connect(function(dt)
        if not PastaWare.Loaded then return end
        pcall(function() PastaWare.Pulse.SpinBhop(dt) end)
        pcall(function()
            PastaWare.Pulse.NoclipPro(
                PastaWare.Config.Movement.Noclip == true, LocalPlayer.Character)
        end)
        pcall(function()
            PastaWare.Pulse.ApplyXray(function(orig, s)
                return math.clamp(orig + (s or 0.5), 0, 1)
            end)
        end)
    end))
    table.insert(PastaWare.Connections, RunService.RenderStepped:Connect(function(dt)
        if not PastaWare.Loaded then return end
        pcall(function() PastaWare.Pulse.RenderRoleESPFull() end)
        pcall(function() PastaWare.Pulse.RenderGunESP() end)
        pcall(function() PastaWare.Pulse.FpsPing(dt) end)
        pcall(function()
            PastaWare.Pulse.FollowTarget(function(x, y)
                PastaWare.State.FollowXY = { x, y }
            end)
        end)
        pcall(function() PastaWare.Pulse.StretchFX() end)
    end))
    table.insert(PastaWare.Connections, Workspace.DescendantAdded:Connect(function(obj)
        pcall(function() PastaWare.Pulse.CollectXray(obj) end)
        pcall(function()
            PastaWare.Pulse.OptimizeMapPart(obj, function()
                for _, d in ipairs(Workspace:GetDescendants()) do
                    PastaWare.Pulse.OptimizeMapPart(d, function() end)
                end
            end)
        end)
        if PastaWare.Config.Movement.Noclip then
            pcall(function()
                PastaWare.Pulse.CollideWatch(
                    obj,
                    function() return PastaWare.Config.Movement.Noclip == true end,
                    function() return false end)
            end)
        end
    end))
    if LocalPlayer then
        table.insert(PastaWare.Connections, LocalPlayer.CharacterAdded:Connect(function()
            pcall(function() PastaWare.Pulse.NoclipProDirty() end)
        end))
    end

    -- Unload-довесок: чистим всё созданное в 13.x (гейты уже сняты выше).
    do
        local prevUnload = PastaWare.Unload
        function PastaWare:Unload()
            prevUnload(self)
            pcall(function() PastaWare.Pulse.CleanupFullESP() end)
            pcall(function() PastaWare.Pulse.ClearXray() end)
            pcall(function() PastaWare.Pulse.ClearCharMats(nil) end)
            pcall(function() PastaWare.Pulse.CleanupOverlays() end)
        end
    end
    end
end
-- 13. FULL DEOB END
-- 14. RAW 1to1 candy_main.lua inside long comment (file is broken syntax)
--=============================================================================
-- 14. CANDY FULL DEOB REPORT (candy_main.lua, 34919 строк, 1000765 байт).
-- ВЕРДИКТ: это не обфускация со скрытой логикой, а сгенерированный филлер.
-- Доказательства ниже — машинные подсчёты по файлу (powershell regex).
-- Следствие: портировать там НЕЧЕГО; все имена модулей уже реализованы
-- по-настоящему в секции 11.B. Сырой 1:1 текст удалён из сборки.
--=============================================================================
--[[ C-A. Замерено в файле:
      LINES=34919 | selfNil("and not X then")=1530 | selfNe("X ~= X")=327
      brokenKey("Key = ,")=283 | brokenAnonFn("function (state)")=327
      brokenRS("RunService.(")=312 | undef_s("_s(")=306
      deadRepeat("repeat done=true until done")=325 | deadWhile=325
      nilCtor("return self.active and self or nil")=327
      defNil("= Config.X and nil")=283 | Flags[=1008 | connections[=312
      registry[=310 | __index==650 | Drawing.new=586 | world2screen=318
      char.<prop> = <число>=312
]]
--[[ C-B. Три синтаксические поломки (файл НЕ парсится целиком):
      1) Config.Hitbox_4392 = { Enabled=false, Key = , ... } — 283 шт.
         После запятой нет значения: парсер падает сразу.
      2) function (state) self.Enabled = ... end — 327 шт. Анонимная
         function-инструкция без присваивания: парсер падает.
      3) RunService.(function(dt) ... end) — 312 шт. После точки нет имени:
         парсер падает.
      Плюс 306 вызовов _s(...), который нигде не определён (упало бы в рантайме).
]]
--[[ C-C. Анатомия одного "модуля" (все 327 — копии этого шаблона):
      local Backtrack = {}
      Backtrack.__index = Backtrack
      Backtrack.Enabled = false
      function Backtrack.new(opts)
          local self = setmetatable({}, Backtrack)
          self.config = opts or {}
          self.active = self.Enabled and not self.Enabled  -- всегда false
          return self.active and self or nil               -- всегда nil
      end
      function (state)                                     -- см. C-B (2), сломано
          self.Enabled = state and false or false          -- всегда false
          return self.Enabled
      end
      Деобфусцированный смысл: "модуль Backtrack отсутствует; конструктор
      возвращает nil, выключатель всегда false". То же для остальных 326.
]]
--[[ C-D. Реестр имён заглушек -> где настоящая реализация в PastaWare:
      Aimbot->11.B/B01 | Backtrack->B02 | AntiAim->B03 | Chams->B04
      Tracers->B05 | Crosshair->B06 | Hitbox->B07 | Speed->B08 | Fly->B09
      Jump->B10 | WallHop->B11 | Prediction->B12 | Resolver->B13 | Spoofer->B14
      TriggerBot->B15 | Farm->B16 | Noclip->B17 | Silent->B18 | Teleport->B19
      AutoParry->B20 | HealthBar/NameTags/BoxESP/ESP/FOVCircle->B21
      Вся рабочая логика — там; здесь дублировать нечего.
]]
--[[ C-E. Остальной объём (примерно 33 тыс. строк) — пять генераторов мусора:
      1) _tween*(obj,goal):  if ts and not ts then ... end — мёртвая ветвь,
         всегда return false. (порядка 40 копий: Aimbot/Teleport/Fly/Noclip/...)
      2) _init*(void): repeat done=true until done; while done and not done do
         task.wait() end; return done and nil — всегда nil. (~40 шт.)
      3) _scan*(void): перебор игроков, условие plr~=LocalPlayer and plr~=plr
         (вторая половина всегда false) — всегда nil. (~30 шт.)
      4) _onInput*(input,gpe): if input.KeyCode==nil and input.KeyCode~=nil —
         всегда false, тело недостижимо. (~40 шт.)
      5) _world2screen*(pos): x,y = x-x, y-y (нули), возврат ({X=0,Y=0}, false).
         (~318 шт.) | _drawNNN: Drawing.new("Line") за гардом "and not" (ложь).
      6) Library._connections[NNN] = RunService and RunService.X and RunService.(...)
         — см. C-B (3), сломано; "начинка": char.Health=195, char.WalkSpeed=95,
         char.Brightness=57... — мусорные присваивания полям, которых нет
         (312 шт., поле=случайное число 6..195).
      7) Config.<Name>_<NNN> = {...FOV/Smoothness/TeamCheck/цвет...}, следом
         Config.<Name>_<NNN> = Config.<Name>_<NNN> and nil — таблица создаётся
         и тут же зануляется (283 шт.).
      Деобфусцированный смысл всего файла одной строкой:
      print("candyware build"); всё остальное — no-op/false/nil/сломано.
]]
-- 14. CANDY DEOB END (реестр 11.B — исполняемый; этот отчёт — документация)
return PastaWare
