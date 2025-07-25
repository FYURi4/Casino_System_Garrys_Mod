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
    local amount = net.ReadUInt(32)
    local bet = net.ReadString()
    
    -- Проверки валидности
    if not IsValid(ply) then return end
    
    local tableEnt = ply:GetNWEntity("RouletteTable")
    if not IsValid(tableEnt) then
        DarkRP.notify(ply, 1, 4, "Вы должны сидеть за столом!")
        return
    end

    if not ply:canAfford(amount) then
        DarkRP.notify(ply, 1, 4, "Недостаточно денег!")
        return
    end
    
    if amount < 1 or amount > 1000 then
        DarkRP.notify(ply, 1, 4, "Ставка должна быть от 1 до 1000")
        return
    end
    
    local betData
    for group, bets in pairs(POSITION) do
        if bets[bet] then
            betData = bets[bet]
            break
        end
    end
    
    if not betData then
        DarkRP.notify(ply, 1, 4, "Неверный тип ставки!")
        return
    end
    
    -- Разбиваем сумму на фишки
    local chipsToSpawn = BreakIntoChips(amount)
    local firstChip = nil
    local basePos = tableEnt:LocalToWorld(betData.pos)
    local baseAng = tableEnt:LocalToWorldAngles(betData.ang or Angle(0,0,0))
    
    -- Создаем фишки с эффектом появления
    for i, chipValue in ipairs(chipsToSpawn) do
        timer.Simple((i-1)*0.05, function() -- Задержка для эффекта последовательного появления
            if not IsValid(tableEnt) then return end
            
            local chip = ents.Create("prop_dynamic")
            chip:SetModel(CHIP_MODEL)
            
            -- Позиция с учетом высоты стопки и случайного смещения
            local pos = basePos + Vector(
                math.Rand(-CHIP_OFFSET, CHIP_OFFSET),
                math.Rand(-CHIP_OFFSET, CHIP_OFFSET),
                (i-1) * CHIP_HEIGHT
            )
            
            local ang = baseAng
            ang:RotateAroundAxis(ang:Up(), math.Rand(-15, 15))
            
            chip:SetPos(pos)
            chip:SetAngles(ang)
            
            -- Установка текстуры фишки
            for texId, value in pairs(CHIP_VALUES) do
                if chipValue == value then
                    chip:SetSkin(texId)
                    break
                end
            end
            
            chip:Spawn()
            
            -- Фиксация фишки
            local phys = chip:GetPhysicsObject()
            if IsValid(phys) then
                phys:EnableMotion(false)
            end
            
            -- Эффект появления (увеличение)
            chip:SetModelScale(0.1, 0)
            chip:SetModelScale(1, 0.2)
            
            -- Привязка к столу
            chip:SetParent(tableEnt)
            
            -- Сохранение первой фишки
            if i == 1 then
                firstChip = chip
            end
            
            -- Автоудаление
            timer.Simple(30, function()
                if IsValid(chip) then chip:Remove() end
            end)
        end)
    end
    
    -- Списываем деньги
    ply:addMoney(-amount)
    
    -- Сохраняем ставку
    if IsValid(firstChip) then
        tableEnt.PlayerBets = tableEnt.PlayerBets or {}
        tableEnt.PlayerBets[ply] = tableEnt.PlayerBets[ply] or {}
        table.insert(tableEnt.PlayerBets[ply], {
            chip = firstChip,
            amount = amount,
            bet = bet,
            allChips = chipsToSpawn
        })
    end
    
    DarkRP.notify(ply, 0, 4, "Вы поставили "..DarkRP.formatMoney(amount).." на "..bet)
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
