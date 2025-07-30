AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

-- Константы конфигурации
local WHEEL_OFFSET = Vector(5.96, 42.34, 26.75)
local BALL_MODEL = "models/darkrpcasinoby3demc/play_sharik.mdl"

-- Параметры скорости
local SUPPORT_SPEED = 100
local MAX_SPIN_SPEED = 500
local SPIN_DIRECTION = -1 -- -1 = вправо, 1 = влево

-- Параметры времени
local ACCELERATION_TIME = 6
local BALL_BRAKING_TIME = 7

-- Параметры шарика
local BALL_RADIUS = {
    R1 = 8.5,
    R2 = 9,
    R3 = 13.5
}

local BALL_HEIGHT = {
    H1 = -2.42,
    H2 = -1.5
}

-- Порядок номеров на колесе рулетки (обращенный для соответствия модели)
local ROULETTE_ORDER = {
    26, 3, 35, 12, 28, 7, 29, 18, 22, 9,
    31, 14, 20, 1, 33, 16, 24, 5, 10, 23,
    8, 30, 11, 36, 13, 27, 6, 34, 17, 25,
    2, 21, 4, 19, 15, 32, 0
}

local CELL_COUNT = #ROULETTE_ORDER
local CELL_ANGLE_STEP = 360 / CELL_COUNT

-- Фазы работы рулетки
local PHASES = {
    IDLE = "idle",
    ACCEL = "accel",
    SUPPORT = "support",
    BALL_SLOWING = "ball_slowing",
    DECEL = "decel"
}

function ENT:Initialize()
    self:SetupEntity()
    self:InitializeVariables()
    self:CreateComponents()
    
    self:DebugPrint("Roulette entity initialized")
end

function ENT:SetupEntity()
    self:SetModel("models/darkrpcasinoby3demc/table_rullet_casino.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:EnableMotion(false)
        phys:Wake()
    end
end

function ENT:InitializeVariables()
    -- Состояние рулетки
    self.Phase = PHASES.IDLE
    self.PhaseStartTime = CurTime()
    self.CurrentSpeed = 0
    self.WheelAngle = 0
    
    -- Состояние шарика
    self.Ball = {
        Speed = 0,
        HoldSpeed = 0,
        Radius = BALL_RADIUS.R1,
        Height = BALL_HEIGHT.H1,
        Angle = math.random(0, 359),
        FinalAngle = nil, -- Зафиксированный угол при остановке
        AttachedToWheel = true,
        LockedInCell = false,
        LockAngleOffset = 0
    }
    
    self.LastBallAngle = self.Ball.Angle
    
    -- Параметры рандомизации
    self.SpeedVariation = 1
    self.BrakingTime = BALL_BRAKING_TIME
    
    -- Результат
    self.CurrentResult = nil
    self.ResultLocked = false
    
    self:DebugPrint("=== INITIAL STATE ===")
    self:DebugPrint("Initial ball angle: " .. self.Ball.Angle)
    self:DebugPrint("Initial ball position number: " .. self:GetCellByAngle(self.Ball.Angle))
end

function ENT:CreateComponents()
    self:CreateWheel()
    self:CreateBall()
end

function ENT:CreateWheel()
    self.Wheel = ents.Create("prop_dynamic")
    if not IsValid(self.Wheel) then 
        ErrorNoHalt("[Roulette] Failed to create wheel entity\n")
        return 
    end

    local wheelPos = self:GetPos() + 
        self:GetForward() * WHEEL_OFFSET.x +
        self:GetRight() * WHEEL_OFFSET.y +
        self:GetUp() * WHEEL_OFFSET.z

    self.Wheel:SetModel("models/darkrpcasinoby3demc/table_rullet_casino_detail.mdl")
    self.Wheel:SetPos(wheelPos)
    self.Wheel:SetAngles(self:GetAngles())
    self.Wheel:Spawn()
    self.Wheel:SetParent(self)
    
    self:DeleteOnRemove(self.Wheel)
    self:DebugPrint("Wheel created successfully")
end

function ENT:CreateBall()
    if not IsValid(self.Wheel) then
        ErrorNoHalt("[Roulette] Cannot create ball: wheel is not valid\n")
        return
    end

    self.BallEntity = ents.Create("prop_dynamic")
    if not IsValid(self.BallEntity) then 
        ErrorNoHalt("[Roulette] Failed to create ball entity\n")
        return 
    end

    self.BallEntity:SetModel(BALL_MODEL)
    self.BallEntity:Spawn()
    self.BallEntity:SetParent(self.Wheel)
    self.BallEntity:SetMoveType(MOVETYPE_NONE)
    
    self:DeleteOnRemove(self.BallEntity)
    self:UpdateBallPosition()
    
    self:DebugPrint("Ball created successfully")
end

function ENT:UpdateBallPosition()
    if not IsValid(self.BallEntity) then return end

    -- Используем зафиксированный угол если шарик остановлен
    local angleToUse = self.Ball.LockedInCell and self.Ball.FinalAngle or self.Ball.Angle
    
    local correctedAngle = angleToUse + 180
    local localPos = Vector(
        math.cos(math.rad(correctedAngle)) * self.Ball.Radius,
        math.sin(math.rad(correctedAngle)) * self.Ball.Radius,
        self.Ball.Height
    )

    self.BallEntity:SetLocalPos(localPos)
end

function ENT:Think()
    if not self.PhaseStartTime then 
        self:NextThink(CurTime() + 0.1)
        return true 
    end
    
    local now = CurTime()
    local elapsed = now - self.PhaseStartTime

    self:ProcessPhase(now, elapsed)
    self:UpdateWheel()
    self:UpdateBall()
    self:UpdateBallPosition()

    self:NextThink(now + 0.01)
    return true
end

function ENT:ProcessPhase(now, elapsed)
    if self.Phase == PHASES.ACCEL then
        self:ProcessAcceleration(now, elapsed)
    elseif self.Phase == PHASES.SUPPORT then
        self:ProcessSupport(now, elapsed)
    elseif self.Phase == PHASES.BALL_SLOWING then
        self:ProcessBallSlowing(now, elapsed)
    elseif self.Phase == PHASES.DECEL then
        self:ProcessDeceleration(now, elapsed)
    end
end

function ENT:ProcessAcceleration(now, elapsed)
    local progress = math.min(elapsed / ACCELERATION_TIME, 1)
    self.CurrentSpeed = Lerp(progress, SUPPORT_SPEED, MAX_SPIN_SPEED)

    self.Ball.AttachedToWheel = true
    self.Ball.LockedInCell = false

    if progress >= 1 then
        self:SwitchToPhase(PHASES.SUPPORT, now)
        
        self.Ball.AttachedToWheel = false
        self.Ball.Radius = BALL_RADIUS.R3
        self.Ball.Height = BALL_HEIGHT.H2
        self.Ball.Speed = self.CurrentSpeed * self.SpeedVariation
        self.Ball.HoldSpeed = self.Ball.Speed
        
        self:DebugPrint("=== BALL RELEASED ===")
        self:DebugPrint("Ball speed: " .. self.Ball.Speed)
        self:DebugPrint("Ball at radius: " .. self.Ball.Radius)
    end
end

function ENT:ProcessSupport(now, elapsed)
    local progress = math.min(elapsed / ACCELERATION_TIME, 1)
    self.CurrentSpeed = Lerp(progress, MAX_SPIN_SPEED, SUPPORT_SPEED)
    self.Ball.Speed = self.Ball.HoldSpeed

    if progress >= 1 then
        self:SwitchToPhase(PHASES.BALL_SLOWING, now)
        self.BallSlowStartSpeed = self.Ball.Speed
        
        self:DebugPrint("=== BALL SLOWING PHASE ===")
        self:DebugPrint("Ball slow start speed: " .. self.BallSlowStartSpeed)
        self:DebugPrint("Expected braking time: " .. self.BrakingTime)
    end
end

function ENT:ProcessBallSlowing(now, elapsed)
    self.CurrentSpeed = SUPPORT_SPEED

    local progress = math.min(elapsed / self.BrakingTime, 1)
    self.Ball.Speed = Lerp(progress, self.BallSlowStartSpeed, 0)

    -- Плавное снижение шарика по радиусам
    self:UpdateBallRadius(progress)

    -- Проверяем остановку более точно
    if self.Ball.Speed <= 5 then -- Увеличиваем порог остановки
        self:StopBall(now)
    end
    
    -- Дебаг для отслеживания скорости
    if elapsed % 1 < 0.02 then -- Каждую секунду
        self:DebugPrint("Ball slowing - Speed: " .. math.Round(self.Ball.Speed, 1) .. 
                       ", Angle: " .. math.Round(self.Ball.Angle, 1))
    end
end

function ENT:UpdateBallRadius(progress)
    local radiusProgress = math.min(progress / 0.66, 1)
    
    if radiusProgress < 0.5 then
        local subProgress = radiusProgress * 2
        self.Ball.Radius = Lerp(subProgress, BALL_RADIUS.R3, BALL_RADIUS.R2)
        self.Ball.Height = Lerp(subProgress, BALL_HEIGHT.H2, BALL_HEIGHT.H1)
    else
        local subProgress = (radiusProgress - 0.5) * 2
        self.Ball.Radius = Lerp(subProgress, BALL_RADIUS.R2, BALL_RADIUS.R1)
        self.Ball.Height = BALL_HEIGHT.H1
    end
end

function ENT:StopBall(now)
    -- ПОЛНАЯ остановка шарика
    self.Ball.Speed = 0
    
    -- Фиксируем текущий угол шарика как ФИНАЛЬНЫЙ и НЕИЗМЕННЫЙ
    self.Ball.FinalAngle = self.Ball.Angle -- Сохраняем в отдельную переменную
    
    -- ВАЖНО: Сохраняем позицию для следующего запуска
    self.LastBallAngle = self.Ball.FinalAngle
    
    self:SwitchToPhase(PHASES.DECEL, now)
    
    self.Ball.LockedInCell = true
    self.Ball.LockAngleOffset = self.Ball.FinalAngle - self.WheelAngle
    
    -- Вычисляем окончательный результат ОТ ЗАФИКСИРОВАННОГО угла
    self.CurrentResult = self:GetCellByAngle(self.Ball.FinalAngle)
    self.ResultLocked = true
    
    self:DebugPrint("=== BALL STOPPED ===")
    self:DebugPrint("FINAL LOCKED ball angle: " .. math.Round(self.Ball.FinalAngle, 2))
    self:DebugPrint("Wheel angle at stop: " .. math.Round(self.WheelAngle, 2))
    self:DebugPrint("Lock offset: " .. math.Round(self.Ball.LockAngleOffset, 2))
    self:DebugPrint("CALCULATED WINNING NUMBER: " .. self.CurrentResult)
    self:DebugPrint("*** RESULT IS NOW LOCKED AND WILL NOT CHANGE ***")
    self:DebugPrint("*** POSITION SAVED FOR NEXT SPIN: " .. math.Round(self.LastBallAngle, 2) .. " ***")
end

function ENT:ProcessDeceleration(now, elapsed)
    local progress = math.min(elapsed / ACCELERATION_TIME, 1)
    self.CurrentSpeed = Lerp(progress, SUPPORT_SPEED, 0)
    
    -- Важно: НЕ изменяем угол шарика во время торможения колеса
    -- Шарик уже зафиксирован в ячейке

    if progress >= 1 then
        self:SwitchToPhase(PHASES.IDLE, now)
        
        self:DebugPrint("=== ROULETTE FULLY STOPPED ===")
        self:DebugPrint("FINAL RESULT: " .. (self.CurrentResult or "ERROR"))
        self:DebugPrint("Final wheel angle: " .. math.Round(self.WheelAngle, 2))
        
        -- Показываем только зафиксированный угол
        if self.Ball.FinalAngle then
            self:DebugPrint("Final ball angle (LOCKED): " .. math.Round(self.Ball.FinalAngle, 2))
            
            -- Финальная проверка ТОЛЬКО от зафиксированного угла
            local verificationResult = self:GetCellByAngle(self.Ball.FinalAngle)
            if verificationResult ~= self.CurrentResult then
                self:DebugPrint("ERROR: Result calculation mismatch!")
            else
                self:DebugPrint("SUCCESS: Result verified correctly")
            end
        end
    end
end

function ENT:UpdateWheel()
    if not IsValid(self.Wheel) then return end
    
    local angleDelta = self.CurrentSpeed * FrameTime() * SPIN_DIRECTION
    self.WheelAngle = (self.WheelAngle + angleDelta) % 360
    
    local angles = self:GetAngles()
    angles:RotateAroundAxis(self:GetUp(), self.WheelAngle)
    self.Wheel:SetAngles(angles)
end

function ENT:UpdateBall()
    if self.Ball.AttachedToWheel then
        self.Ball.Angle = self.WheelAngle
    elseif self.Ball.LockedInCell then
        -- ВАЖНО: Когда шарик заблокирован, его угол НЕ должен изменяться!
        -- Убираем любые обновления угла для заблокированного шарика
        -- self.Ball.Angle остается неизменным
        return
    else
        -- Шарик движется независимо от колеса только когда не заблокирован
        if self.Ball.Speed > 0 then
            local ballDelta = self.Ball.Speed * FrameTime() * SPIN_DIRECTION
            self.Ball.Angle = (self.Ball.Angle + ballDelta) % 360
        end
        -- Если скорость 0, то угол НЕ изменяется
    end
end

function ENT:GetCellByAngle(angle)
    -- Нормализация угла
    angle = angle % 360
    if angle < 0 then angle = angle + 360 end
    
    -- ВАЖНО: Возможно нужно добавить смещение для соответствия модели
    -- Попробуйте разные значения если результат не совпадает с визуальным:
    local ANGLE_OFFSET = 0 -- Попробуйте: 90, -90, 180, -180
    angle = (angle + ANGLE_OFFSET) % 360
    
    local index = math.floor(angle / CELL_ANGLE_STEP) + 1
    if index > CELL_COUNT then index = 1 end
    
    local cellNumber = ROULETTE_ORDER[index]
    
    -- Дебаг для калибровки
    self:DebugPrint("ANGLE CALCULATION:")
    self:DebugPrint("  Raw angle: " .. math.Round(angle - ANGLE_OFFSET, 2))
    self:DebugPrint("  With offset: " .. math.Round(angle, 2))
    self:DebugPrint("  Cell index: " .. index)
    self:DebugPrint("  Cell number: " .. cellNumber)
    
    return cellNumber
end

function ENT:SwitchToPhase(newPhase, time)
    self.Phase = newPhase
    self.PhaseStartTime = time or CurTime()
end

function ENT:Use(activator, caller)
    if self.Phase ~= PHASES.IDLE then 
        self:DebugPrint("Roulette is already running!")
        return 
    end

    self:StartRoulette(activator)
end

function ENT:StartRoulette(activator)
    -- Инициализация параметров запуска
    self:SwitchToPhase(PHASES.ACCEL)
    
    -- Сброс состояния шарика
    self.Ball.Radius = BALL_RADIUS.R1
    self.Ball.Height = BALL_HEIGHT.H1
    self.Ball.Speed = 0
    self.Ball.AttachedToWheel = true
    self.Ball.Angle = math.random(0, 359)
    self.LastBallAngle = self.Ball.Angle
    
    -- Рандомизация
    self.SpeedVariation = math.random(80, 120) / 100
    self.BrakingTime = BALL_BRAKING_TIME + math.random(-1, 2)
    
    -- Сброс результата
    self.ResultLocked = false
    self.CurrentResult = nil
    
    -- Дебаг информация
    local playerName = IsValid(activator) and activator:Nick() or "Unknown"
    
    self:DebugPrint("=== ROULETTE STARTED ===")
    self:DebugPrint("Started by: " .. playerName)
    self:DebugPrint("Starting ball angle: " .. self.Ball.Angle)
    self:DebugPrint("Starting position number: " .. self:GetCellByAngle(self.Ball.Angle))
    self:DebugPrint("Speed variation: " .. (self.SpeedVariation * 100) .. "%")
    self:DebugPrint("Braking time: " .. self.BrakingTime .. "s")
end

function ENT:DebugPrint(message)
    print("[Roulette] " .. tostring(message))
end

function ENT:OnRemove()
    if IsValid(self.Wheel) then
        self.Wheel:Remove()
    end
    if IsValid(self.BallEntity) then
        self.BallEntity:Remove()
    end
    
    self:DebugPrint("Roulette entity removed")
end
