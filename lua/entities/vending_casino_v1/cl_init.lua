include('shared.lua')

function ENT:Draw()
    self:DrawModel()
end

local lerpProgress = 0
local targetFOV = 75
local currentFOV = 75
local lastVehicle = NULL
local targetOffset = Vector(0, 0, 0)
local currentOffset = Vector(0, 0, 0)

local slotResult = nil
local resultTime = 0

net.Receive("Casino_SlotResult", function()
    slotResult = net.ReadTable()
    resultTime = CurTime() + 5 -- Показывать результат 5 секунд
end)

surface.CreateFont("CasinoFontBig", {
    font = "Roboto", 
    size = 25,
    weight = 400,
    antialias = true
})

hook.Add("CalcView", "CasinoMachineView", function(ply, pos, angles, fov)
    local seat = ply:GetVehicle()
    local shouldLerp = false
    
    -- Определяем, нужно ли делать плавный переход
    if IsValid(seat) then
        local ent = seat:GetParent()
        if IsValid(ent) and ent.CameraOffset then
            if lastVehicle ~= seat then
                -- Начинаем новый переход
                lerpProgress = 0
                targetOffset = ent.CameraOffset
                targetFOV = ent.CameraFOV or 60
                lastVehicle = seat
            end
            shouldLerp = true
        end
    elseif IsValid(lastVehicle) then
        -- Возвращаемся к обычной камере
        lerpProgress = 0
        targetOffset = Vector(0, 0, 0)
        targetFOV = 75
        lastVehicle = NULL
        shouldLerp = true
    end

    -- Плавное изменение параметров камеры
    if shouldLerp then
        lerpProgress = math.Clamp(lerpProgress + FrameTime() * 3, 0, 1)
        currentOffset = LerpVector(lerpProgress, currentOffset, targetOffset)
        currentFOV = Lerp(lerpProgress, currentFOV, targetFOV)
    else
        currentOffset = Vector(0, 0, 0)
        currentFOV = fov
    end

    -- Применяем изменения, если есть смещение
    if currentOffset ~= Vector(0, 0, 0) then
        local view = {
            origin = pos + angles:Forward() * currentOffset.x + 
                              angles:Right() * currentOffset.y + 
                              angles:Up() * currentOffset.z,
            angles = angles,
            fov = currentFOV,
            drawviewer = false
        }
        return view
    end
end)

-- Сброс при смерти игрока
hook.Add("PlayerDeath", "CasinoMachineResetView", function(ply)
    lerpProgress = 0
    currentOffset = Vector(0, 0, 0)
    currentFOV = 75
    lastVehicle = NULL
end)

local showControls = false

net.Receive("CasinoMachine_ShowUI", function()
    showControls = true
end)

net.Receive("CasinoMachine_HideUI", function()
    showControls = false
end)


local lastResults = nil
local resultDisplayTime = 0

net.Receive("CasinoMachine_SpinResult", function()
    local machine = net.ReadEntity()
    local results = net.ReadTable()
    
    if not IsValid(machine) or not IsValid(LocalPlayer():GetVehicle()) then return end
    
    lastResults = results
    resultDisplayTime = CurTime() + 5
end)


hook.Add("HUDPaint", "CasinoMachine_DrawUI", function()
    if showControls then
        local lines = {
            "slot machine management:",
            "spin:  whitespace",
            "bet +: left mouse",
            "bet -: right mouse",
            "bet max: r"
        }

        local font = "CasinoFontBig"
        surface.SetFont(font)
        local _, h = surface.GetTextSize("TEST")

        local x = 30
        local y = ScrH() / 2

        for i, line in ipairs(lines) do
            draw.SimpleText(line, font, x, y + (i - 1) * h, Color(255,255,255,150), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end
    end

    if not lastResults or CurTime() > resultDisplayTime then return end
    
    local alpha = 255
    if CurTime() > resultDisplayTime - 1 then
        alpha = 255 * (resultDisplayTime - CurTime())
    end
    
    local w, h = ScrW() / 2, ScrH() / 2
    
    draw.SimpleText("RESULT: " .. lastResults[1] .. " - " .. lastResults[2] .. " - " .. lastResults[3], "CasinoFontBig", w, h, Color(255, 255, 0, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)


