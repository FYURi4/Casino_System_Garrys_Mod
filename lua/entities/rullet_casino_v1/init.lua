AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

-- Константы вращения и шарика
local WHEEL_OFFSET = Vector(5.96, 42.34, 26.75)
local BALL_MODEL = "models/darkrpcasinoby3demc/play_sharik.mdl"

local supportSpeed = 100
local maxSpinSpeed = 500
local rulletSpinSide = -1 -- -1 - right, 1 - Left (The side of the roulette wheel affects the side of the ball's rotation.)
local accelerationAndDecelerationRullet = 6 -- seconds

local sharikSpeed = 1200 

local sharikR1 = 8.5
local sharikR2 = 9
local sharikR3 = 13.5

local sharikBacklash = 0.05 -- the ball's backlash when it rolls along the 3rd radius
local sharikH1 = -2.42
local sharikH2 = -1.5
local sharikStatus = "cell" -- ctll, r1, r2, r3, slowing down
local ballBraking = 7

local CELL_MAGNET_STRENGTH = 0.3  -- Сила "притяжения" к ячейке (0 = нет, 1 = мгновенное залипание)
local CELL_SLOWDOWN_FACTOR = 0.95
local roulette_order = {
    0, 32, 15, 19, 4, 21, 2, 25, 17, 34,
    6, 27, 13, 36, 11, 30, 8, 23, 10, 5,
    24, 16, 33, 1, 20, 14, 31, 9, 22, 18,
    29, 7, 28, 12, 35, 3, 26
}
local cellCount = #roulette_order
local cellAngleStep = 360 / cellCount

function ENT:GetCellByAngle(angle)
    angle = angle % 360
    local index = math.floor(angle / cellAngleStep) + 1
    if index > cellCount then index = 1 end
    return roulette_order[index]
end

function ENT:Initialize()
    self:SetModel("models/darkrpcasinoby3demc/table_rullet_casino.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:EnableMotion(false)
    end

    self:CreateWheel()
    self:CreateBall()

    self.RouletteSpinSpeed = rulletSpeed
    self.RouletteSpinning = false
    self.RouletteAngle = 0
    self.RouletteSpinPhase = "idle"
    self.RouletteSpinStartTime = 0
    self.RouletteCurrentSpeed = 0
    self.BallSpeed = 0
    self.BallHoldSpeed = 0
    self.BallRadius = sharikR1
    self.BallHeight = sharikH1
    self.BallAttachedToWheel = true
    self.BallLockedInCell = false
    self.BallLockAngleOffset = 0

    -- Начальный угол шарика (будет обновляться при остановке)
    self.BallAngle = 180
    self.LastBallAngle = 180 -- Сохраняем последний угол шарика
end 

function ENT:CreateWheel()
    self.Wheel = ents.Create("prop_dynamic")
    if not IsValid(self.Wheel) then return end

    local pos = self:GetPos() + self:GetForward() * WHEEL_OFFSET.x +
                self:GetRight() * WHEEL_OFFSET.y +
                self:GetUp() * WHEEL_OFFSET.z

    self.Wheel:SetModel("models/darkrpcasinoby3demc/table_rullet_casino_detail.mdl")
    self.Wheel:SetPos(pos)
    self.Wheel:SetAngles(self:GetAngles())
    self.Wheel:SetParent(self)
    self.Wheel:Spawn()

    self:DeleteOnRemove(self.Wheel)
end

function ENT:CreateBall()
    self.Ball = ents.Create("prop_dynamic")
    if not IsValid(self.Ball) then return end

    self.Ball:SetModel(BALL_MODEL)
    self.Ball:SetAngles(Angle(0, 0, 0))
    self.Ball:SetMoveType(MOVETYPE_NONE)
    self.Ball:SetParent(nil)
    self.Ball:Spawn()
    self:DeleteOnRemove(self.Ball)
end

function ENT:Think()
    local now = CurTime()
    local elapsed = now - self.RouletteSpinStartTime
    local accelTime = accelerationAndDecelerationRullet

    -- === ФАЗЫ ВРАЩЕНИЯ РУЛЕТКИ ===
    if self.RouletteSpinPhase == "accel" then
        local t = math.min(elapsed / accelTime, 1)
        self.RouletteCurrentSpeed = Lerp(t, supportSpeed, maxSpinSpeed)

        self.BallAttachedToWheel = true
        self.BallLockedInCell = false

        if t >= 1 then
            self.RouletteSpinPhase = "support"
            self.RouletteSpinStartTime = now
            self.BallAttachedToWheel = false
            self.BallRadius = sharikR3
            self.BallHeight = sharikH2
            self.BallSpeed = self.RouletteCurrentSpeed
            self.BallHoldSpeed = self.BallSpeed
        end

    elseif self.RouletteSpinPhase == "support" then
        local t = math.min(elapsed / accelTime, 1)
        self.RouletteCurrentSpeed = Lerp(t, maxSpinSpeed, supportSpeed)
        self.BallSpeed = self.BallHoldSpeed

        if t >= 1 then
            self.RouletteSpinPhase = "ball_slowing"
            self.RouletteSpinStartTime = now
            self.BallSlowStartSpeed = self.BallSpeed
        end

        elseif self.RouletteSpinPhase == "ball_slowing" then
            self.RouletteCurrentSpeed = supportSpeed

            local t = math.min((now - self.RouletteSpinStartTime) / ballBraking, 1)
            self.BallSpeed = Lerp(t, self.BallSlowStartSpeed, 0)

            -- Плавное снижение шарика по радиусам
            local radiusProgress = math.min(t / 0.66, 1) -- 66% времени на снижение
            if radiusProgress < 0.5 then
                -- Переход от R3 к R2
                local subProgress = radiusProgress * 2
                self.BallRadius = Lerp(subProgress, sharikR3, sharikR2)
                self.BallHeight = Lerp(subProgress, sharikH2, sharikH1)
            else
                -- Переход от R2 к R1
                local subProgress = (radiusProgress - 0.5) * 2
                self.BallRadius = Lerp(subProgress, sharikR2, sharikR1)
                self.BallHeight = sharikH1
            end

            if self.BallSpeed <= 1 then
                self.BallSpeed = 0
                self.RouletteSpinPhase = "decel"
                self.RouletteSpinStartTime = now
                self.BallLockedInCell = true
                self.BallLockAngleOffset = self.BallAngle - self.RouletteAngle
                
                -- Сохраняем последний угол шарика
                self.LastBallAngle = self.BallAngle
            end

    elseif self.RouletteSpinPhase == "decel" then
        local t = math.min(elapsed / accelerationAndDecelerationRullet, 1)
        self.RouletteCurrentSpeed = Lerp(t, supportSpeed, 0)

        if self.BallSpeed <= 1 and not self.ResultLocked then
            self.BallSpeed = 0
            self.BallLockedInCell = true
            self.BallLockAngleOffset = self.BallAngle - self.RouletteAngle
            local ballCellNumber = self:GetCellByAngle(self.BallAngle)
            self.CurrentResult = ballCellNumber
            self.ResultLocked = true
            print("Ball stopped in cell: ", ballCellNumber)
        end

        if t >= 1 then
            self.RouletteSpinPhase = "idle"
        end

    elseif self.RouletteSpinPhase == "idle" then
        self.RouletteCurrentSpeed = 0
    end

    -- Вращение барабана
    local angleDelta = self.RouletteCurrentSpeed * FrameTime() * rulletSpinSide
    self.RouletteAngle = (self.RouletteAngle + angleDelta) % 360
    local ang = self:GetAngles()
    ang:RotateAroundAxis(self:GetUp(), self.RouletteAngle)
    self.Wheel:SetAngles(Angle(ang.p, ang.y, ang.r))

    -- Вращение шарика
    if IsValid(self.Ball) then
        if self.BallAttachedToWheel then
            self.BallAngle = self.RouletteAngle
        elseif self.BallLockedInCell then
            self.BallAngle = self.RouletteAngle + (self.BallLockAngleOffset or 0)
        else
            self.BallAngle = (self.BallAngle + self.BallSpeed * FrameTime() * rulletSpinSide) % 360
        end

        local basePos = self:GetPos() +
            self:GetForward() * WHEEL_OFFSET.x +
            self:GetRight() * WHEEL_OFFSET.y +
            self:GetUp() * WHEEL_OFFSET.z

        local correctedBallAngle = self.BallAngle + 180
        local localBallPos = Vector(
            math.cos(math.rad(correctedBallAngle)) * self.BallRadius,
            math.sin(math.rad(correctedBallAngle)) * self.BallRadius,
            self.BallHeight
        )

        local rotatedBallPos = LocalToWorld(localBallPos, Angle(0, 0, 0), basePos, self:GetAngles())
        self.Ball:SetPos(rotatedBallPos)
    end

    self:NextThink(now)
    return true
end 


function ENT:Use(activator, caller)
    if self.RouletteSpinPhase == "idle" then
        self.RouletteSpinPhase = "accel"
        self.RouletteSpinStartTime = CurTime()
        self.BallRadius = sharikR1
        self.BallHeight = sharikH1
        self.BallSpeed = 0
        self.BallAttachedToWheel = true
        
        -- Устанавливаем начальный угол шарика из сохраненного значения
        self.BallAngle = self.LastBallAngle
        self.ResultLocked = false
    end
end


function ENT:OnRemove()

end
