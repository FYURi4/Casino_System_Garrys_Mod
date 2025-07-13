AddCSLuaFile('cl_init.lua')
AddCSLuaFile('shared.lua')
include('shared.lua')

util.AddNetworkString("CasinoMachine_ShowUI")
util.AddNetworkString("CasinoMachine_HideUI")
util.AddNetworkString("CasinoMachine_SpinResult")

function ENT:Initialize()
    -- Основные настройки стула
    self:SetModel("models/darkrpcasinoby3demc/chair_co.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)

    -- Фиксируем физику
    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:EnableMotion(false)
    end

    -- Создаем сиденье
    self.Seat = ents.Create("prop_vehicle_prisoner_pod")
    self.Seat:SetModel("models/nova/airboat_seat.mdl")
    self.Seat:SetKeyValue("vehiclescript", "scripts/vehicles/prisoner_pod.txt")
    
    -- Позиционирование сиденья
    local seatPos = self:GetPos() + 
                   self:GetUp() * -2 + 
                   self:GetForward() * -5
    
    self.Seat:SetPos(seatPos)
    self.Seat:SetAngles(self:GetAngles() + Angle(0, -90, 0))
    self.Seat:SetParent(self)
    self.Seat:SetColor(Color(0, 0, 0, 0))
    self.Seat:SetRenderMode(RENDERMODE_TRANSALPHA)
    self.Seat:Spawn()
    self.Seat:SetNoDraw(true)
    self.Seat:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
    
    self:DeleteOnRemove(self.Seat)

    -- Создаем стол
    self.table = ents.Create("prop_dynamic")
    self.table:SetSolid(SOLID_VPHYSICS)
    self.table:SetModel("models/darkrpcasinoby3demc/Vending_Casino_Table.mdl")
    self.table:SetPos(self:GetPos())
    self.table:SetAngles(self:GetAngles())
    self.table:Spawn()
    self.table:SetParent(self)
    self.table:SetLocalPos(Vector(0, 0, -32))
    self.table:SetLocalAngles(Angle(0, 180, 0))

    -- Создаем автомат
    self.machine = ents.Create("prop_dynamic")
    self.machine:SetSolid(SOLID_VPHYSICS)
    self.machine:SetModel("models/darkrpcasinoby3demc/Vending_Casino_V1.mdl")
    self.machine:SetParent(self.table)
    self.machine:SetLocalPos(Vector(0, 0, 0))
    self.machine:SetLocalAngles(Angle(0, 0, 0))
    self.machine:Spawn()

    -- Создаем барабаны
    self.reels = {}
    local positionReelsY = -4.7

    for i = 1, 3 do
        self.reels[i] = ents.Create("prop_dynamic")
        self.reels[i]:SetModel("models/darkrpcasinoby3demc/baraban_group.mdl")
        self.reels[i]:SetParent(self.machine)
        self.reels[i]:SetLocalPos(Vector(-33.3, positionReelsY, 56.1))
        self.reels[i]:SetLocalAngles(Angle(0, 0, 0))
        self.reels[i]:Spawn()
        positionReelsY = positionReelsY + 4.68
    end

    -- Создаем кнопки
    self.buttons = {}
    self.buttonPressedState = {}
    self.buttonPressTime = {}
    self.buttonAnimating = {}

    local buttonData = {
        {name = "btn1", model = "models/darkrpcasinoby3demc/btn_1.mdl", pos = Vector(-27.655, -5.77, 51.99), pressedPos = Vector(-27.655, -5.77, 51.89)},
        {name = "bet2", model = "models/darkrpcasinoby3demc/btn_2.mdl", pos = Vector(-27.655, -3.671, 51.99), pressedPos = Vector(-27.655, -3.671, 51.89)},
        {name = "maxbet", model = "models/darkrpcasinoby3demc/btn_3.mdl", pos = Vector(-27.655, -0.685, 51.99), pressedPos = Vector(-27.655, -0.685, 51.89)},
        {name = "spin", model = "models/darkrpcasinoby3demc/btn_4.mdl", pos = Vector(-27.655, 5.88, 51.99), pressedPos = Vector(-27.655, 5.88, 51.89)}
    }

    for _, btn in ipairs(buttonData) do
        self.buttons[btn.name] = ents.Create("prop_dynamic")
        self.buttons[btn.name]:SetModel(btn.model)
        self.buttons[btn.name]:SetMoveType(MOVETYPE_NONE)
        self.buttons[btn.name]:SetSolid(SOLID_NONE)
        self.buttons[btn.name]:SetParent(self.machine)
        self.buttons[btn.name]:SetLocalPos(btn.pos)
        self.buttons[btn.name]:SetLocalAngles(Angle(0, 0, 0))
        self.buttons[btn.name]:Spawn()
        
        self.buttons[btn.name].normalPos = btn.pos
        self.buttons[btn.name].pressedPos = btn.pressedPos
        self.buttonPressedState[btn.name] = false
        self.buttonPressTime[btn.name] = 0
        self.buttonAnimating[btn.name] = false
    end

    -- Инициализация состояния барабанов
    self.isSpinning = false
    self.spinStartTime = 0
    self.spinDuration = 8 -- Общая длительность вращения в секундах
    self.reelStopDelays = {0.5, 1.0, 1.5} -- Задержки между остановками барабанов
    self.reelsStopped = {false, false, false}
    self.currentAngles = {0, 0, 0}
    self.targetAngles = {0, 0, 0}
    self.spinDirection = 1 -- -1 для вращения вперед, 1 для вращения назад
    
    -- Звуки
    self.spinSounds = {
        "rullet.wav",
        "rullet2.wav",
        "rullet3.wav",
        "rullet4.wav"
    }
    self.stopSounds = {
        "ambient/machines/catapult_throw.wav",
        "ambient/machines/catapult_throw.wav",
        "ambient/machines/catapult_throw.wav"
    }
    self.buttonSound = "buttons/button24.wav"
    self.spinSoundEntity = nil
    self.lastSpinTime = 0
end

function ENT:Think()
    -- Обработка вращения барабанов
    if self.isSpinning then
        local elapsed = CurTime() - self.spinStartTime
        
        for i = 1, 3 do
            if not self.reelsStopped[i] and elapsed >= self.reelStopDelays[i] then
                self.reelsStopped[i] = true
                self.reels[i]:SetLocalAngles(Angle(self.targetAngles[i], 0, 0))
                self:EmitSound(self.stopSounds[i], 75, 100, 0.5)
            end
        end
        
        for i = 1, 3 do
            if not self.reelsStopped[i] then
                local progress = elapsed / self.reelStopDelays[i]
                local easeProgress = math.sin(progress * math.pi / 2)
                local startAngle = self.currentAngles[i]
                local endAngle = self.targetAngles[i] + 360 * 10 * self.spinDirection
                local currentAngle = Lerp(easeProgress, startAngle, endAngle)
                self.reels[i]:SetLocalAngles(Angle(currentAngle, 0, 0))
            end
        end
        
        if self.reelsStopped[1] and self.reelsStopped[2] and self.reelsStopped[3] then
            self.isSpinning = false
            if IsValid(self.spinSoundEntity) then
                self.spinSoundEntity:Stop()
                self.spinSoundEntity = nil
            end
            
            -- Отправляем результат на клиент
            if IsValid(self.Seat:GetDriver()) then
                self:SendSpinResult(self.Seat:GetDriver())
            end
        end
    end
    
    -- Обработка анимации кнопок
    for btnName, btn in pairs(self.buttons) do
        if self.buttonAnimating[btnName] then
            local pressTime = CurTime() - self.buttonPressTime[btnName]
            local animDuration = 0.2 -- Длительность анимации в секундах
            
            if pressTime < animDuration then
                -- Анимация нажатия
                local progress = pressTime / animDuration
                local easedProgress = progress * progress -- Квадратичное easing
                local newPos = LerpVector(easedProgress, btn.normalPos, btn.pressedPos)
                btn:SetLocalPos(newPos)
            elseif pressTime < animDuration * 2 then
                -- Анимация отпускания
                local progress = (pressTime - animDuration) / animDuration
                local easedProgress = progress * progress
                local newPos = LerpVector(easedProgress, btn.pressedPos, btn.normalPos)
                btn:SetLocalPos(newPos)
            else
                -- Анимация завершена
                btn:SetLocalPos(btn.normalPos)
                self.buttonAnimating[btnName] = false
                self.buttonPressedState[btnName] = false
            end
        end

        if self.lastDriver and (not IsValid(self.Seat:GetDriver()) or self.Seat:GetDriver() ~= self.lastDriver) then
            -- Игрок вышел
            net.Start("CasinoMachine_HideUI")
            net.Send(self.lastDriver)
            self.lastDriver = nil
        end
        
        if IsValid(self.Seat:GetDriver()) then
            self.lastDriver = self.Seat:GetDriver()
        end
    end
    
    -- Обработка ввода игрока
    if IsValid(self.Seat:GetDriver()) and self.Seat:GetDriver():IsPlayer() then
        local ply = self.Seat:GetDriver()
        
        -- Обработка нажатия пробела (кнопка spin)
        if ply:KeyPressed(IN_JUMP) and CurTime() > self.lastSpinTime + 0.5 then -- Защита от спама
            self:AnimateButton("spin")
            self:StartSpin()
            self.lastSpinTime = CurTime()
        end
    end
    
    self:NextThink(CurTime())
    return true
end

function ENT:SendSpinResult(ply)
    if not IsValid(ply) then return end
    
    -- Преобразуем углы в символы (0-4)
    local results = {}
    for i = 1, 3 do
        local angle = self.targetAngles[i] % 360
        if angle < 70 then
            results[i] = 0 -- 7
        elseif angle < 142 then
            results[i] = 1 -- Вишня
        elseif angle < 215 then
            results[i] = 2 -- BAR BAR
        elseif angle < 288 then
            results[i] = 3 -- Колокол
        else
            results[i] = 4 -- Арбуз
        end
    end
    
    net.Start("CasinoMachine_SpinResult")
        net.WriteEntity(self) -- Отправляем сам автомат
        net.WriteTable(results) -- Отправляем таблицу с результатами
    net.Send(ply)
    
    -- Здесь можно добавить логику определения выигрыша
    local winAmount = self:CalculateWin(results)
    if winAmount > 0 then
        -- Даем игроку выигрыш (ваша реализация)
    end
end

function ENT:AnimateButton(btnName)
    if self.buttons[btnName] and not self.buttonAnimating[btnName] then
        self.buttonAnimating[btnName] = true
        self.buttonPressTime[btnName] = CurTime()
        self.buttonPressedState[btnName] = true
        self:EmitSound(self.buttonSound, 60, 100, 0.5)
    end
end

function ENT:StartSpin()
    if not self.isSpinning then
        self.isSpinning = true
        self.spinStartTime = CurTime()
        self.reelsStopped = {false, false, false}
        
        local symbolAngles = {
            0,    -- Позиция 1 -- 7
            70,   -- Позиция 2 -- Вишня
            142,  -- Позиция 3 -- BAR BAR
            215,  -- Позиция 4 -- Колокол
            288   -- Позиция 5 -- Арбуз
        }
        
        for i = 1, 3 do
            self.currentAngles[i] = self.reels[i]:GetLocalAngles().x
            self.targetAngles[i] = symbolAngles[math.random(1, #symbolAngles)]
        end
        
        if IsValid(self.spinSoundEntity) then
            self.spinSoundEntity:Stop()
            self.spinSoundEntity = nil
        end
        
        local randomSound = self.spinSounds[math.random(1, #self.spinSounds)]
        self.spinSoundEntity = CreateSound(self, randomSound)
        self.spinSoundEntity:Play()
        self.spinSoundEntity:ChangeVolume(0.7, 0)
    end
end

function ENT:CalculateWin(results)
    -- Проверка на три одинаковых символа
    if results[1] == results[2] and results[2] == results[3] then
        -- Возвращаем разный выигрыш в зависимости от символа
        if results[1] == 0 then     -- 7
            return 1000
        elseif results[1] == 1 then  -- Вишня
            return 500
        elseif results[1] == 2 then -- BAR BAR
            return 750
        elseif results[1] == 3 then -- Колокол
            return 250
        elseif results[1] == 4 then -- Арбуз
            return 100
        end
    end
    
    -- Проверка на два одинаковых символа (например, первые два)
    if results[1] == results[2] then
        if results[1] == 0 then     -- 7
            return 100
        elseif results[1] == 1 then  -- Вишня
            return 50
        -- и т.д.
        end
    end
    
    -- Если нет выигрышных комбинаций
    return 0
end

function ENT:OnRemove()
    if IsValid(self.spinSoundEntity) then
        self.spinSoundEntity:Stop()
        self.spinSoundEntity = nil
    end
end

function ENT:Use(activator, caller)
    if IsValid(activator) and activator:IsPlayer() then
        if not IsValid(self.Seat:GetDriver()) then
            activator:EnterVehicle(self.Seat)

            -- Показать интерфейс
            net.Start("CasinoMachine_ShowUI")
            net.Send(activator)
        else
            if activator == self.Seat:GetDriver() then
                activator:ExitVehicle()

                -- Скрыть интерфейс
                net.Start("CasinoMachine_HideUI")
                net.Send(activator)
            end
        end
    end
end
