-- sv_init.lua

AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")


util.AddNetworkString("RoulettePlaceBet")
util.AddNetworkString("RouletteShowHUD")
util.AddNetworkString("RoulettePlayerSat")
util.AddNetworkString("RoulettePlayerLeft")
util.AddNetworkString("RouletteCameraUpdate")

-- Hooks for sitting/unsitting players
hook.Add("PlayerEnteredVehicle", "Roulette_PlayerSat", function(ply, veh)
    if not (IsValid(veh) and IsValid(ply)) then return end
    if veh:GetNWBool("IsRouletteChair", false) then
        local tableEnt = veh:GetNWEntity("RouletteTable")
        if IsValid(tableEnt) and tableEnt.PlayerSat then
            tableEnt:PlayerSat(ply, veh)
        end
    end
end)

hook.Add("PlayerLeaveVehicle", "Roulette_PlayerLeft", function(ply, veh)
    if not (IsValid(veh) and IsValid(ply)) then return end
    if veh:GetNWBool("IsRouletteChair", false) then
        local tableEnt = veh:GetNWEntity("RouletteTable")
        if IsValid(tableEnt) and tableEnt.PlayerLeft then
            tableEnt:PlayerLeft(ply)
        end
    end
end)


local CAMERA_OFFSET = Vector(6, -8.5, 58) -- Смещение камеры относительно стола
local CAMERA_ANGLE = Angle(90, 180, 0) -- Угол камеры (настроить по вкусу)
local ROUND_WAITING = 0

-- Constants
local CHAIR_OFFSETS = {
    { pos = Vector(50, 13, 6.5), ang = Angle(0, 0, 0), addAng = Angle(0, 90, 0) },  
    { pos = Vector(50, -24, 6.5), ang = Angle(0, 0, 0), addAng = Angle(0, 90, 0) },    
    { pos = Vector(50, -61, 6.5), ang = Angle(0, 0, 0), addAng = Angle(0, 90, 0) },    
    { pos = Vector(15, -100, 6.5), ang = Angle(0, 90, 0), addAng = Angle(0, 90, 0) }
}

local GMAN_OFFSET = Vector(-28, -35, -26)
local GMAN_ANGLE_OFFSET = Angle(0, 0, 0)
local WHEEL_OFFSET = Vector(5.96, 42.34, 26.75)
local BALL_OFFSET_Z = -1.5
local BALL_MODEL = "models/darkrpcasinoby3demc/play_sharik.mdl"

function ENT:Initialize()
    self:SetModel("models/darkrpcasinoby3demc/table_rullet_casino.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then phys:EnableMotion(false) end

    self.RoundState = ROUND_WAITING
    self.BettingEndTime = 0
    self.Players = {}

    self:CreateChairs()
    self:CreateGMan()
    self:CreateWheel()
    self:CreateBall()
end

function ENT:CreateChairs()
    self.Chairs = {}
    for i, offset in ipairs(CHAIR_OFFSETS) do
        local chairPos = self:GetPos() + self:GetForward() * offset.pos.x + self:GetRight() * offset.pos.y + self:GetUp() * offset.pos.z
        local seat = ents.Create("prop_vehicle_prisoner_pod")
        seat:SetModel("models/nova/airboat_seat.mdl")
        seat:SetKeyValue("vehiclescript", "")
        seat:SetPos(chairPos)
        seat:SetAngles(self:GetAngles() + offset.ang + offset.addAng)
        seat:Spawn()
        seat:SetParent(self)

        seat:SetNoDraw(true)
        seat:SetColor(Color(0, 0, 0, 0))
        seat:SetRenderMode(RENDERMODE_TRANSALPHA)
        seat:SetCollisionGroup(COLLISION_GROUP_WEAPON)
        seat:SetNWEntity("RouletteTable", self)
        seat:SetNWBool("IsRouletteChair", true)

        local chair = ents.Create("prop_dynamic")
        chair:SetModel("models/darkrpcasinoby3demc/chair_co.mdl")
        chair:SetPos(chairPos)
        chair:SetAngles(self:GetAngles() + offset.ang)
        chair:SetParent(seat)
        chair:Spawn()
        chair:DrawShadow(false)

        self.Chairs[i] = seat
        self:DeleteOnRemove(seat)
        self:DeleteOnRemove(chair)
    end
end

function ENT:CreateGMan()
    -- GMan
    self.GMan = ents.Create("npc_gman")
    if IsValid(self.GMan) then
        local localOffset = GMAN_OFFSET
        local worldPos = self:GetPos()
            + self:GetForward() * localOffset.x
            + self:GetRight() * localOffset.y
            + self:GetUp() * localOffset.z

        self.GMan:SetModel("models/gman.mdl")
        self.GMan:SetPos(worldPos)
        self.GMan:SetAngles(self:GetAngles())
        self.GMan:Spawn()
        self.GMan:Activate()

        -- Установка состояния NPC
        self.GMan:SetNPCState(NPC_STATE_SCRIPT)
        self.GMan:SetSolid(SOLID_NONE)
        self.GMan:SetMoveType(MOVETYPE_NONE) -- NPC теперь "заморожен"
        self.GMan:SetHealth(99999)
        self.GMan:SetMaxHealth(99999)
        self.GMan:SetSchedule(SCHED_IDLE_STAND)
        self.GMan:AddRelationship("player D_LI 99")
        self.GMan:CapabilitiesAdd(CAP_ANIMATEDFACE + CAP_TURN_HEAD)

        -- Принудительно задать анимацию
        self.GMan:ResetSequence(self.GMan:LookupSequence("lineidle01"))

        -- Родитель — стол
        self.GMan:SetParent(self)

    
        self:DeleteOnRemove(self.GMan)
    end
end

function ENT:CreateWheel()
    self.Wheel = ents.Create("prop_dynamic")
    if not IsValid(self.Wheel) then return end

    local wheelPos = self:GetPos() + self:GetForward() * WHEEL_OFFSET.x + self:GetRight() * WHEEL_OFFSET.y + self:GetUp() * WHEEL_OFFSET.z
    self.Wheel:SetModel("models/darkrpcasinoby3demc/table_rullet_casino_detail.mdl")
    self.Wheel:SetPos(wheelPos)
    self.Wheel:SetAngles(self:GetAngles())
    self.Wheel:SetParent(self)
    self.Wheel:Spawn()

    local wheelPhys = self.Wheel:GetPhysicsObject()
    if IsValid(wheelPhys) then wheelPhys:EnableMotion(false) end

    self:DeleteOnRemove(self.Wheel)
end

function ENT:CreateBall()
    self.Ball = ents.Create("prop_dynamic")
    if not IsValid(self.Ball) or not IsValid(self.Wheel) then return end

    self.Ball:SetModel(BALL_MODEL)
    self.Ball:SetPos(self.Wheel:GetPos() + self.Wheel:GetUp() * BALL_OFFSET_Z)
    self.Ball:SetAngles(self:GetAngles())
    self.Ball:SetParent(self.Wheel)
    self.Ball:Spawn()

    local ballPhys = self.Ball:GetPhysicsObject()
    if IsValid(ballPhys) then ballPhys:EnableMotion(false) end

    self:DeleteOnRemove(self.Ball)
end

function ENT:PlayerSat(ply, chair)
    if not (IsValid(ply) and ply:IsPlayer()) then return end
    
    self.Players[ply] = {
        chair = chair,
        cameraPos = self:GetPos() + self:GetForward() * CAMERA_OFFSET.x + 
                   self:GetRight() * CAMERA_OFFSET.y + 
                   self:GetUp() * CAMERA_OFFSET.z,
        cameraAng = self:GetAngles() + CAMERA_ANGLE
    }
    
    ply:SetNWEntity("RouletteChair", chair)
    ply:SetNWEntity("RouletteTable", self)
    
    -- Отправляем данные о камере клиенту
    net.Start("RouletteCameraUpdate")
        net.WriteBool(true) -- Включить камеру
        net.WriteVector(self.Players[ply].cameraPos)
        net.WriteAngle(self.Players[ply].cameraAng)
    net.Send(ply)
    
    net.Start("RouletteShowHUD") 
        net.WriteBool(true) 
    net.Send(ply)
    
    net.Start("RoulettePlayerSat") 
        net.WriteEntity(self) 
    net.Send(ply)
end


function ENT:PlayerLeft(ply)
    if not (IsValid(ply) and ply:IsPlayer()) then return end
    
    if self.Players[ply] then
        -- Отправляем команду отключить кастомную камеру
        net.Start("RouletteCameraUpdate")
            net.WriteBool(false) -- Выключить камеру
        net.Send(ply)
        
        self.Players[ply] = nil
    end
    
    ply:SetNWEntity("RouletteChair", NULL)
    ply:SetNWEntity("RouletteTable", NULL)
    
    net.Start("RouletteShowHUD") 
        net.WriteBool(false) 
    net.Send(ply)
    
    net.Start("RoulettePlayerLeft") 
        net.WriteEntity(self) 
    net.Send(ply)
end

net.Receive("RoulettePlaceBet", function(len, ply)
    -- Получаем данные о ставке от клиента
    local amount = net.ReadUInt(32)
    local bet = net.ReadString()
    
    -- Проверяем, что игрок может сделать ставку
    if not IsValid(ply) then return end
    
    -- Проверяем, что игрок сидит за столом
    local tableEnt = ply:GetNWEntity("RouletteTable")
    if not IsValid(tableEnt) then
        DarkRP.notify(ply, 1, 4, "Вы должны сидеть за столом, чтобы сделать ставку!")
        return
    end

    -- Проверяем наличие денег
    if not ply:canAfford(amount) then
        DarkRP.notify(ply, 1, 4, "У вас недостаточно денег!")
        return
    end
    
    -- Проверяем, что ставка соответствует номиналу фишек
    local validChip = false
    for _, chipValue in pairs(CHIP_VALUES) do
        if amount == chipValue then
            validChip = true
            break
        end
    end
    
    if not validChip then
        DarkRP.notify(ply, 1, 4, "Ставка должна соответствовать номиналу фишек (1, 5, 10, 50, 100, 500, 1000)!")
        return
    end
    
    -- Ищем данные о позиции ставки
    local betData
    for group, bets in pairs(POSITION) do
        if bets[bet] then
            betData = bets[bet]
            break
        end
    end
    
    if not betData then
        DarkRP.notify(ply, 1, 4, "Неверная ставка!")
        return
    end
    
    -- Создаем фишку
    local chip = ents.Create("prop_physics")
    chip:SetModel(CHIP_MODEL)
    
    -- Рассчитываем позицию и угол фишки
    local worldPos = tableEnt:LocalToWorld(betData.pos)
    local worldAng = tableEnt:LocalToWorldAngles(betData.ang or Angle(0, 0, 0))
    
    -- Добавляем случайный поворот для ставок на числа
    if not POSITION["OUTSIDE BETS"][bet] and not POSITION["GREEN"][bet] then
        worldAng:RotateAroundAxis(worldAng:Up(), math.random(-20, 20))
        worldAng:RotateAroundAxis(worldAng:Forward(), math.random(-5, 5))
    end
    
    -- Устанавливаем позицию и угол
    chip:SetPos(worldPos)
    chip:SetAngles(worldAng)
    
    -- Устанавливаем номинал фишки (текстуру)
    for texId, chipValue in pairs(CHIP_VALUES) do
        if amount == chipValue then
            chip:SetSkin(texId)
            break
        end
    end
    
    -- Спавним фишку
    chip:Spawn()
    
    -- Фиксируем физику фишки
    local phys = chip:GetPhysicsObject()
    if IsValid(phys) then
        phys:EnableMotion(false)
        phys:Sleep()
    end
    
    -- Привязываем фишку к столу
    chip:SetParent(tableEnt)
    
    -- Сохраняем информацию о ставке
    chip:SetNWString("BetType", bet)
    chip:SetNWInt("BetAmount", amount)
    chip:SetNWEntity("BetOwner", ply)
    
    -- Списываем деньги с игрока
    ply:addMoney(-amount)
    
    -- Удаляем фишку через 30 секунд (или после окончания раунда)
    timer.Simple(30, function()
        if IsValid(chip) then
            chip:Remove()
        end
    end)
    
    -- Логируем ставку
    DarkRP.notify(ply, 0, 4, string.format("Вы поставили %s на %s", DarkRP.formatMoney(amount), bet))
    
    -- Отправляем уведомление другим игрокам за столом
    for otherPlayer, _ in pairs(tableEnt.Players or {}) do
        if IsValid(otherPlayer) and otherPlayer ~= ply then
            DarkRP.notify(otherPlayer, 3, 4, string.format("%s поставил %s на %s", ply:Nick(), DarkRP.formatMoney(amount), bet))
        end
    end
    
    -- Сохраняем информацию о ставке в таблице
    tableEnt.PlayerBets = tableEnt.PlayerBets or {}
    tableEnt.PlayerBets[ply] = tableEnt.PlayerBets[ply] or {}
    table.insert(tableEnt.PlayerBets[ply], {
        chip = chip,
        amount = amount,
        bet = bet
    })
end)

function ENT:OnRemove()
    for ply, _ in pairs(self.Players) do
        if IsValid(ply) and IsValid(ply.RouletteCamera) then
            ply:SetViewEntity(NULL)
            ply.RouletteCamera:Remove()
            ply.RouletteCamera = nil
        end
    end
end
