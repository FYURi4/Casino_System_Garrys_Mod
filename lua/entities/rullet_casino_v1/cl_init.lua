-- CLIENT

include('shared.lua')

local rouletteFrame, infoFrame
local isInputFocused = false
local currentBetAmount = 1
local minBetAmount = 1
local maxBetAmount = 1000
local selectedBet
local customCameraEnabled = false
local cameraPos, cameraAng
local currentChips = {}
local roundTimeLeft = 0
local isSpinning = false
local smoothTimer = {
    targetTime = 0,
    currentDisplay = 0,
    lastUpdate = 0
}
local CAMERA_OFFSET = Vector(6, -8.5, 58)
local CAMERA_ANGLE = Angle(180, 180, 0)
local WHEEL_OFFSET = Vector(5.96, 42.34, 43)
local cameraTransition = {
    active = false,
    startTime = 0,
    duration = 1.5,
    startPos = Vector(0,0,0),
    startAng = Angle(0,0,0),
    targetPos = Vector(0,0,0),
    targetAng = Angle(0,0,0)
}
local CHIP_VALUES = {
    [0] = 1,   
    [1] = 5,   
    [2] = 10,  
    [3] = 50,  
    [4] = 100,  
    [5] = 500,   
    [6] = 1000 
}
local CHIP_MODEL = "models/darkrpcasinoby3demc/fishka_casino.mdl"
local COLORS = {
    MAIN = Color(14, 137, 190),
    OUTLINE = Color(14, 117, 190),
    HOVER = Color(34, 157, 210),
    TEXT_WHITE = Color(255, 255, 255),
    TEXT_GRAY = Color(150, 150, 150),
    BG_DARK = Color(23, 24, 27),
    BG_DARKER = Color(13, 14, 15),
    ACCENT = Color(14, 122, 190),
    SEARCH_BG = Color(40, 42, 48, 0),
    SEARCH_OUTLINE = Color(62, 65, 74),
    SELECTED = Color(60, 50, 50)
}
local FONTS = {
    MAGNETO_MAX = "MagnetoLogoMax",
    MAGNETO_MIN = "MagnetoLogoMin",
    ARIAL_MAX = "ArialMax",
    ARIAL_MIN = "ArialMin"
}
local function InitializeFonts()
    surface.CreateFont(FONTS.MAGNETO_MAX, {
        font = "Magneto",
        size = 77,
        weight = 2000,
        antialias = true,
    })
    surface.CreateFont(FONTS.MAGNETO_MIN, {
        font = "Magneto",
        size = 51,
        weight = 2000,
        antialias = true,
        extended = true,
    })
    surface.CreateFont(FONTS.ARIAL_MAX, {
        font = "Arial",
        size = 39.42,
        weight = 2000,
        antialias = true,
    })
    surface.CreateFont(FONTS.ARIAL_MIN, {
        font = "Arial",
        size = 20.94,
        weight = 2000,
        antialias = true,
    })
end
local function StartCameraTransition(targetPos, keepAngle)
    if not IsValid(LocalPlayer()) then return end
    
    cameraTransition.startPos = cameraPos or LocalPlayer():EyePos()
    cameraTransition.startAng = cameraAng or LocalPlayer():EyeAngles()
    cameraTransition.targetPos = targetPos
    cameraTransition.targetAng = keepAngle and cameraTransition.startAng or CAMERA_ANGLE -- Сохраняем текущий угол
    cameraTransition.startTime = RealTime()
    cameraTransition.active = true
end
local function InitializeAllBets()
    ALL_BETS = {}
    for betName, _ in pairs(POSITION["OUTSIDE BETS"]) do
        table.insert(ALL_BETS, {
            name = betName,
            group = "OUTSIDE BETS",
            color = COLORS.BG_DARKER
        })
    end
    table.insert(ALL_BETS, {
        name = "0",
        group = "GREEN",
        color = Color(50, 200, 50)
    })
    for betName, _ in pairs(POSITION["BLACK"]) do
        table.insert(ALL_BETS, {
            name = betName,
            group = "BLACK",
            color = Color(50, 50, 50)
        })
    end
    for betName, _ in pairs(POSITION["RED"]) do
        table.insert(ALL_BETS, {
            name = betName,
            group = "RED",
            color = Color(200, 50, 50)
        })
    end
end

function ENT:Draw()
    self:DrawModel()
end

-- Объявляем функции заранее
local RemoveCurrentChips, CreatePreviewChips

local function RemoveCurrentChips()
    for _, chip in pairs(currentChips) do
        if IsValid(chip.model) then
            chip.model:Remove()
        end
        timer.Remove("ChipGrow_".._)
    end
    currentChips = {}
end

local function CreatePreviewChips(betName, amount)
    local betData = nil
    for group, bets in pairs(POSITION) do
        if bets[betName] then
            betData = bets[betName]
            break
        end
    end
    if not betData then return end

    local chips = BreakIntoChips(amount)
    for i, chipValue in ipairs(chips) do
        local chip = {
            model = ClientsideModel(CHIP_MODEL, RENDERGROUP_OPAQUE),
            baseAngle = Angle(0, 0, 0),
            stackPos = i
        }
        
        chip.model:SetNoDraw(true)
        for texId, value in pairs(CHIP_VALUES) do
            if chipValue == value then
                chip.model:SetSkin(texId)
                break
            end
        end
        
        table.insert(currentChips, chip)
        chip.model:SetModelScale(0.1)
        chip.model:SetNoDraw(false)
        
        local scale = 0.1
        timer.Create("ChipGrow_"..#currentChips, 0.01, 15, function()
            if IsValid(chip.model) then
                scale = math.min(scale + 0.06, 1)
                chip.model:SetModelScale(scale)
            end
        end)
    end
end

local function DrawRoundedBoxExOutlined(radius, x, y, w, h, color, r1, r2, r3, r4, outlineWidth, outlineColor)
    draw.RoundedBoxEx(radius, x, y, w, h, outlineColor, r1, r2, r3, r4)
    
    local inset = outlineWidth
    draw.RoundedBoxEx(
        math.max(0, radius - inset), 
        x + inset, 
        y + inset, 
        w - inset * 2, 
        h - inset * 2, 
        color, 
        r1, r2, r3, r4
    )
end

local function CreateRouletteBetSlider(parent)
    local scrollPanel = vgui.Create("DScrollPanel", parent)
    scrollPanel:SetSize(525, 522)
    scrollPanel:SetPos(18, 205)
    
    local scrollBar = scrollPanel:GetVBar()
    scrollBar:SetWide(8)
    scrollBar.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(40, 40, 40, 200))
    end
    scrollBar.btnGrip.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, self.Depressed and COLORS.ACCENT or self.Hovered and COLORS.HOVER or COLORS.MAIN)
    end
    
    local list = vgui.Create("DIconLayout", scrollPanel)
    list:SetSize(557, 522)
    list:Dock(FILL)
    list:SetSpaceY(5)

    local function CreateGroupHeader(text)
        local header = list:Add("DPanel")
        header:SetSize(557, 30)
        header.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, COLORS.BG_DARK)
            draw.SimpleText(
                text,
                FONTS.ARIAL_MIN,
                w/2, h/2,
                COLORS.TEXT_WHITE,
                TEXT_ALIGN_CENTER,
                TEXT_ALIGN_CENTER
            )
        end
    end

    local function CreateBetItem(name, color)
        local item = list:Add("DButton")
        item:SetSize(517, 40)
        item:SetText("")
        
        local isSelected = selectedBet == name
        
        item.Paint = function(self, w, h)
            local displayColor = isSelected and COLORS.SELECTED or color
            
            draw.RoundedBox(4, 0, 0, w, h, self:IsHovered() and Color(
                math.min(displayColor.r + 20, 255),
                math.min(displayColor.g + 20, 255),
                math.min(displayColor.b + 20, 255)
            ) or displayColor)
            
            draw.SimpleText(
                name,
                FONTS.ARIAL_MIN,
                20, h/2,
                COLORS.TEXT_WHITE,
                TEXT_ALIGN_LEFT,
                TEXT_ALIGN_CENTER
            )
            
            if self:IsHovered() then
                surface.SetDrawColor(COLORS.ACCENT)
                surface.DrawOutlinedRect(0, 0, w, h, 2)
            end
            
            if isSelected then
                surface.SetDrawColor(COLORS.SELECTED.r, COLORS.SELECTED.g, COLORS.SELECTED.b, 255)
                surface.DrawOutlinedRect(0, 0, w, h, 3)
            end
        end
        
        item.DoClick = function()
            local currentTime = SysTime()
            
            -- Проверяем двойное нажатие
            if lastClickedBet == name and (currentTime - lastClickTime) < 0.3 then
                selectedBet = nil -- Снимаем выделение
                lastClickTime = 0
                lastClickedBet = nil
                RemoveCurrentChips() -- Удаляем фишки
            else
                -- Если выбрана новая ставка, удаляем старые фишки
                if selectedBet ~= name then
                    RemoveCurrentChips()
                end
                
                selectedBet = name -- Выделяем ставку
                lastClickTime = currentTime
                lastClickedBet = name
                
                -- Создаем визуальные фишки для предпросмотра
                CreatePreviewChips(name, currentBetAmount)
            end
            
            betSlider.Update("") -- Обновляем список для перерисовки
        end
        
        return item
    end

    local function UpdateBetList(searchText)
        list:Clear()
        
        if searchText == "" then
            CreateGroupHeader("OUTSIDE BETS")
            local outsideBetsOrder = {
                "low (1to18)", "even", "on red", "on black", "odd", "high (10to36)",
                "1-12 (1st dozen)", "13-24 (2st dozen)", "25-36 (3rd dozen)",
                "1 line (2to1)", "2 line (2to1)", "3 line (2to1)"
            }
            for _, betName in ipairs(outsideBetsOrder) do
                CreateBetItem(betName, COLORS.BG_DARKER)
            end

            CreateGroupHeader("GREEN")
            CreateBetItem("0", Color(50, 200, 50))

            CreateGroupHeader("BLACK")
            local blackNumbers = {}
            for betName in pairs(POSITION["BLACK"]) do
                table.insert(blackNumbers, betName)
            end
            table.sort(blackNumbers, function(a, b) return tonumber(a) < tonumber(b) end)
            for _, betName in ipairs(blackNumbers) do
                CreateBetItem(betName, Color(50, 50, 50))
            end

            CreateGroupHeader("RED")
            local redNumbers = {}
            for betName in pairs(POSITION["RED"]) do
                table.insert(redNumbers, betName)
            end
            table.sort(redNumbers, function(a, b) return tonumber(a) < tonumber(b) end)
            for _, betName in ipairs(redNumbers) do
                CreateBetItem(betName, Color(200, 50, 50))
            end
        else
            searchText = searchText:lower()
            local foundAny = false
            
            for _, bet in ipairs(ALL_BETS) do
                if bet.name:lower():find(searchText, 1, true) then
                    CreateBetItem(bet.name, bet.color)
                    foundAny = true
                end
            end
            
            if not foundAny then
                local noResults = list:Add("DLabel")
                noResults:SetSize(557, 40)
                noResults:SetText("No bets found")
                noResults:SetFont(FONTS.ARIAL_MIN)
                noResults:SetTextColor(COLORS.TEXT_GRAY)
                noResults:SetContentAlignment(5)
            end
        end
    end

    UpdateBetList("")

    betSlider = {
        panel = scrollPanel,
        Update = UpdateBetList
    }

    return betSlider
end

local function CreateSearchBox(parent, x, y, w, h, updateFunction)
    local searchEntry = vgui.Create("DTextEntry", parent)
    searchEntry:SetSize(w - 30 - 20, h - 6)
    searchEntry:SetPos(x + 30, y + 3)
    searchEntry:SetPlaceholderText("Search bets...")
    searchEntry:SetFont(FONTS.ARIAL_MIN)
    searchEntry:SetTextColor(COLORS.TEXT_WHITE)
    
    searchEntry.OnGetFocus = function()
        isInputFocused = true
        parent:SetKeyboardInputEnabled(true)
    end
    
    searchEntry.OnLoseFocus = function()
        isInputFocused = false
        parent:SetKeyboardInputEnabled(false)
    end
    
    searchEntry.Paint = function(self, w, h)
        draw.RoundedBox(0, 0, 0, w, h, COLORS.SEARCH_BG)
        self:DrawTextEntryText(COLORS.TEXT_WHITE, Color(30, 130, 200), COLORS.TEXT_WHITE)
        
        if self:GetText() == "" and not self:HasFocus() then
            draw.SimpleText(
                self:GetPlaceholderText(),
                FONTS.ARIAL_MIN,
                5, h/2,
                COLORS.TEXT_GRAY,
                TEXT_ALIGN_LEFT,
                TEXT_ALIGN_CENTER
            )
        end
    end

    local searchIcon = vgui.Create("DImage", parent)
    searchIcon:SetSize(16, 16)
    searchIcon:SetPos(x + 10, y + (h - 16)/2)
    searchIcon:SetImage("icon16/magnifier.png")
    searchIcon:SetImageColor(COLORS.TEXT_GRAY)

    local clearSearchBtn = vgui.Create("DButton", parent)
    clearSearchBtn:SetSize(16, 16)
    clearSearchBtn:SetPos(x + w - 16 - 5, y + (h - 16)/2)
    clearSearchBtn:SetText("X")
    clearSearchBtn:SetFont(FONTS.ARIAL_MIN)
    clearSearchBtn:SetTextColor(COLORS.TEXT_GRAY)
    clearSearchBtn:SetVisible(false)
    
    clearSearchBtn.Paint = function(self, w, h)
        if self:IsHovered() then
            draw.RoundedBox(8, 0, 0, w, h, Color(50, 50, 50, 100))
            self:SetTextColor(Color(200, 200, 200))
        else
            self:SetTextColor(COLORS.TEXT_GRAY)
        end
    end
    
    clearSearchBtn.DoClick = function()
        searchEntry:SetText("")
        searchEntry:OnValueChange("")
        clearSearchBtn:SetVisible(false)
        searchEntry:RequestFocus()
        updateFunction("")
    end

    searchEntry.OnValueChange = function(self, value)
        clearSearchBtn:SetVisible(value ~= "")
        updateFunction(value)
    end

    return searchEntry
end

local function CreateButton(parent, config)
    local btn = vgui.Create("DButton", parent)
    btn:SetSize(config.w or 100, config.h or 25)
    btn:SetPos(config.x or 0, config.y or 0)
    btn:SetText(config.text or "")
    btn:SetFont(config.font or FONTS.ARIAL_MIN)
    btn:SetTextColor(config.textColor or COLORS.TEXT_WHITE)
    
    btn.NormalColor = config.textColor or COLORS.TEXT_WHITE
    btn.PressedColor = config.pressedColor or COLORS.ACCENT
    
    if config.round then
        btn.Paint = function(self, w, h)
            draw.RoundedBox(8, 0, 0, w, h, config.outlineColor or COLORS.OUTLINE)
            draw.RoundedBox(8, 2, 2, w-4, h-4, self:IsHovered() and (config.hoverColor or COLORS.HOVER) or (config.bgColor or COLORS.MAIN))
        end
    else
        btn.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, self:IsHovered() and (config.hoverColor or config.bgColor) or config.bgColor)
        end
    end
    
    btn.OnMousePressed = function(self, mouseCode)
        if mouseCode == MOUSE_LEFT then
            self:SetTextColor(self.PressedColor)
        end
    end
    
    btn.OnMouseReleased = function(self, mouseCode)
        if mouseCode == MOUSE_LEFT then
            self:SetTextColor(self.NormalColor)
            if config.clickFunc then
                config.clickFunc(self)
            end
        end
    end
    
    if config.clickFunc then
        btn.DoClick = config.clickFunc
    end
    
    return btn
end

local function CreateNumberInput(parent, x, y, w, h)
    local numberEntry = vgui.Create("DTextEntry", parent)
    numberEntry:SetSize(w, h)
    numberEntry:SetPos(x, y)
    numberEntry:SetFont(FONTS.ARIAL_MAX)
    numberEntry:SetTextColor(COLORS.TEXT_WHITE)
    numberEntry:SetText(currentBetAmount)
    numberEntry:SetNumeric(true)
    numberEntry:SetDrawBackground(false)
    
    numberEntry.OnGetFocus = function()
        isInputFocused = true
        parent:SetKeyboardInputEnabled(true)
    end
    
    numberEntry.OnLoseFocus = function()
        isInputFocused = false
        parent:SetKeyboardInputEnabled(false)
        local value = tonumber(numberEntry:GetText()) or minBetAmount
        value = math.Clamp(math.floor(value), minBetAmount, maxBetAmount)
        currentBetAmount = value
        numberEntry:SetText(value)
        
        -- Обновляем фишки при изменении суммы
        if selectedBet then
            RemoveCurrentChips()
            CreatePreviewChips(selectedBet, currentBetAmount)
        end
    end
    
    numberEntry.OnEnter = function()
        numberEntry:OnLoseFocus()
    end
    
    numberEntry.OnValueChange = function(self, value)
        if value ~= "" then
            local num = tonumber(value)
            if num then
                currentBetAmount = math.Clamp(math.floor(num), minBetAmount, maxBetAmount)
                
                -- Обновляем фишки при изменении суммы
                if selectedBet then
                    RemoveCurrentChips()
                    CreatePreviewChips(selectedBet, currentBetAmount)
                end
            end
        end
    end
    
    numberEntry.Paint = function(self, w, h)
        draw.SimpleText(
            self:GetText(),
            FONTS.ARIAL_MAX,
            w/2, h/2,
            COLORS.TEXT_WHITE,
            TEXT_ALIGN_CENTER,
            TEXT_ALIGN_CENTER
        )
    end
    
    return numberEntry
end

net.Receive("RouletteShowHUD", function()
    local show = net.ReadBool()
    
    if show then
        
        if IsValid(rouletteFrame) then rouletteFrame:Close() end
        if IsValid(infoFrame) then infoFrame:Close() end

        -- Основной фрейм
        rouletteFrame = vgui.Create("DFrame")
        rouletteFrame:SetSize(558.08, 909.19)
        rouletteFrame:SetPos(30.46, 28)
        rouletteFrame:SetTitle("")
        rouletteFrame:SetVisible(true)
        rouletteFrame:SetDraggable(false)
        rouletteFrame:ShowCloseButton(false)
        rouletteFrame:MakePopup() 
        
        rouletteFrame.Paint = function(self, w, h)
            draw.RoundedBoxEx(8, 0, 0, 558.08, 108.41, COLORS.BG_DARK, true, true, false, false)
            draw.RoundedBoxEx(0, 0, 108.9, 558.08, 624, COLORS.BG_DARKER, false, false, false, false)
            draw.RoundedBoxEx(8, 0, 731.5, 558.08, 177.4, COLORS.BG_DARK, false, false, true, true)

            draw.SimpleTextOutlined(
                "Casino System", 
                FONTS.MAGNETO_MAX, 
                w/2, 
                40, 
                COLORS.TEXT_WHITE, 
                TEXT_ALIGN_CENTER, 
                TEXT_ALIGN_CENTER,
                4, 
                COLORS.ACCENT)
            
            draw.SimpleTextOutlined(
                "3DEMC", 
                FONTS.MAGNETO_MIN, 
                356, 
                55, 
                COLORS.TEXT_WHITE, 
                TEXT_ALIGN_LEFT, 
                TEXT_ALIGN_LEFT,
                4,
                COLORS.ACCENT)

            DrawRoundedBoxExOutlined(8, 20, 128, 522, 29.57, COLORS.BG_DARK, true, true, true, true, 3, COLORS.SEARCH_OUTLINE)
            DrawRoundedBoxExOutlined(8, 20, 170, 522, 29.57, COLORS.BG_DARK, true, true, true, true, 3, COLORS.SEARCH_OUTLINE)
            DrawRoundedBoxExOutlined(10, 98.56, 741.88, 365.9, 72.69, COLORS.BG_DARK, true, true, true, true, 3, COLORS.SEARCH_OUTLINE)
        end

        -- Второй информационный фрейм
        infoFrame = vgui.Create("DFrame")
        infoFrame:SetSize(673.56, 200)
        infoFrame:SetPos(30.46, 28 + 909.19 + 10) -- 10 пикселей отступа от основного фрейма
        infoFrame:SetTitle("")
        infoFrame:SetVisible(true)
        infoFrame:SetDraggable(false)
        infoFrame:ShowCloseButton(false)
        infoFrame:MakePopup()
        
        infoFrame.Paint = function(self, w, h)
            DrawRoundedBoxExOutlined(10, 0, 7, 337.56, 51.74, COLORS.BG_DARKER, true, false, false, false, 3, COLORS.SEARCH_OUTLINE)
            DrawRoundedBoxExOutlined(10, 0, 57, 337.56, 51.74, COLORS.BG_DARK, false, false, true, false, 3, COLORS.SEARCH_OUTLINE)
            DrawRoundedBoxExOutlined(10, 336, 7, 337.56, 51.74, COLORS.BG_DARKER, false, true, false, false, 3, COLORS.SEARCH_OUTLINE)
            DrawRoundedBoxExOutlined(10, 336, 57, 337.56, 51.74, COLORS.BG_DARK, false, false, false, true, 3, COLORS.SEARCH_OUTLINE)
        
            draw.SimpleText("END OF BETTING:", FONTS.ARIAL_MAX, 27, 33.5, COLORS.TEXT_WHITE, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            
            -- Отображаем таймер
            local displayTime = math.max(0, math.Round(roundTimeLeft))
            local minutes = math.floor(displayTime / 60)
            local seconds = displayTime % 60
            
            draw.SimpleText(
                string.format("%d:%02d", minutes, seconds), 
                FONTS.ARIAL_MAX, 
                160, 
                82, 
                COLORS.TEXT_WHITE, 
                TEXT_ALIGN_CENTER, 
                TEXT_ALIGN_CENTER
            )
            
            draw.SimpleText("YOUR ACCOUNT:", FONTS.ARIAL_MAX, 365, 33.5, COLORS.TEXT_WHITE, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            
            local money = LocalPlayer():getDarkRPVar("money") or 0
            local formattedMoney = DarkRP.formatMoney(money)
            draw.SimpleText(formattedMoney, FONTS.ARIAL_MAX, 505, 82, COLORS.TEXT_WHITE, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        InitializeFonts()
        InitializeAllBets()

        local buttonWidth = 533 / 3 - 10
        local buttonHeight = 25
        local buttonY = 129 + (29.57 - buttonHeight) / 2
        
        CreateButton(rouletteFrame, {
            x = 20 + 5, y = buttonY, w = buttonWidth, h = buttonHeight,
            text = "SETTINGS", font = FONTS.ARIAL_MIN,
            textColor = COLORS.TEXT_WHITE, bgColor = COLORS.SEARCH_BG,
            pressedColor = COLORS.ACCENT,
            clickFunc = function() print("Settings clicked") end
        })
        
        CreateButton(rouletteFrame, {
            x = 20 + 5 + buttonWidth + 5, y = buttonY, w = buttonWidth, h = buttonHeight,
            text = "HELP", font = FONTS.ARIAL_MIN,
            textColor = COLORS.TEXT_WHITE, bgColor = COLORS.SEARCH_BG,
            pressedColor = COLORS.ACCENT,
            clickFunc = function() print("Help clicked") end
        })
        
        CreateButton(rouletteFrame, {
            x = 20 + 5 + (buttonWidth + 5) * 2, y = buttonY, w = buttonWidth, h = buttonHeight,
            text = "HISTORY", font = FONTS.ARIAL_MIN,
            textColor = COLORS.TEXT_WHITE, bgColor = COLORS.SEARCH_BG,
            pressedColor = COLORS.ACCENT,
            clickFunc = function() print("History clicked") end
        })

        CreateRouletteBetSlider(rouletteFrame)
        CreateSearchBox(rouletteFrame, 20, 170, 522, 29.57, function(text)
            if betSlider and betSlider.Update then
                betSlider.Update(text)
            end
        end)

        local numberEntry = CreateNumberInput(rouletteFrame, 98.56, 741.88, 365.9, 72.69)

        CreateButton(rouletteFrame, {
            x = 13.55, y = 741.88, w = 72.69, h = 72.69,
            text = "-", font = FONTS.ARIAL_MAX,
            textColor = COLORS.TEXT_WHITE, bgColor = COLORS.MAIN,
            hoverColor = COLORS.HOVER, outlineColor = COLORS.OUTLINE,
            round = true,
            clickFunc = function()
                currentBetAmount = math.max(currentBetAmount - 1, minBetAmount)
                numberEntry:SetText(currentBetAmount)
                numberEntry:OnValueChange(currentBetAmount)
            end
        })
        
        CreateButton(rouletteFrame, {
            x = 476.77, y = 741.88, w = 72.69, h = 72.69,
            text = "+", font = FONTS.ARIAL_MAX,
            textColor = COLORS.TEXT_WHITE, bgColor = COLORS.MAIN,
            hoverColor = COLORS.HOVER, outlineColor = COLORS.OUTLINE,
            round = true,
            clickFunc = function()
                currentBetAmount = math.min(currentBetAmount + 1, maxBetAmount)
                numberEntry:SetText(currentBetAmount)
                numberEntry:OnValueChange(currentBetAmount)
            end
        })

        CreateButton(rouletteFrame, {
            x = 13.55, y = 826.88, w = 535.91, h = 70.22,
            text = "PLACE A BET", font = FONTS.ARIAL_MAX,
            textColor = COLORS.TEXT_WHITE, bgColor = COLORS.MAIN,
            hoverColor = COLORS.HOVER, outlineColor = COLORS.OUTLINE,
            round = true,
            clickFunc = function() 
                if not selectedBet then
                    notification.AddLegacy("Please select a bet first!", NOTIFY_ERROR, 5)
                    return
                end
                
                -- Проверка баланса
                if not LocalPlayer():canAfford(currentBetAmount) then
                    notification.AddLegacy("You don't have enough money!", NOTIFY_ERROR, 5)
                    return
                end
                
                -- Проверка минимальной/максимальной ставки
                if currentBetAmount < minBetAmount then
                    notification.AddLegacy("Minimum bet is "..minBetAmount.."!", NOTIFY_ERROR, 5)
                    return
                end
                
                if currentBetAmount > maxBetAmount then
                    notification.AddLegacy("Maximum bet is "..maxBetAmount.."!", NOTIFY_ERROR, 5)
                    return
                end
                
                local chips = BreakIntoChips(currentBetAmount)
                local betText = selectedBet.." ("
                for i, v in ipairs(chips) do
                    betText = betText..(i > 1 and " + " or "")..v
                end
                betText = betText..")"
        
                Derma_Query(
                    "Вы уверены, что хотите поставить "..DarkRP.formatMoney(currentBetAmount).." на "..betText.."?",
                    "Подтверждение ставки",
                    "Да", function()
                        -- Отправка ставки на сервер
                        net.Start("RoulettePlaceBet")
                            net.WriteUInt(currentBetAmount, 32)
                            net.WriteString(selectedBet)
                        net.SendToServer()
                    end,
                    "Нет", function() end
                )
            end
        })

        rouletteFrame:SetKeyboardInputEnabled(false)
        infoFrame:SetKeyboardInputEnabled(false)
        gui.EnableScreenClicker(true)

        rouletteFrame.OnClose = function()
            RemoveCurrentChips()
            gui.EnableScreenClicker(false)
            rouletteFrame = nil
            isInputFocused = false
            selectedBet = nil
            -- Не закрываем infoFrame здесь
        end
        
        infoFrame.OnClose = function()
            if IsValid(rouletteFrame) then
                rouletteFrame:Close()
            end
            infoFrame = nil
        end
        
    elseif IsValid(rouletteFrame) then
        rouletteFrame:Close()
        rouletteFrame = nil
    end
end)

net.Receive("RouletteUpdateTimer", function()
    smoothTimer.targetTime = net.ReadUInt(16)
    smoothTimer.lastUpdate = RealTime()
end)

net.Receive("RouletteStartSpin", function()
    local hideOnlyRoulette = net.ReadBool()
    
    if hideOnlyRoulette and IsValid(rouletteFrame) then
        rouletteFrame:Close()
    end
    
    isSpinning = true
    
    local tableEnt = LocalPlayer():GetNWEntity("RouletteTable")
    if IsValid(tableEnt) then
        local wheelPos = tableEnt:GetPos() + 
                        tableEnt:GetForward() * WHEEL_OFFSET.x + 
                        tableEnt:GetRight() * WHEEL_OFFSET.y + 
                        tableEnt:GetUp() * WHEEL_OFFSET.z
        
        -- Только смещение позиции, угол не меняется
        StartCameraTransition(wheelPos, true)
    end
end)

net.Receive("RouletteEndSpin", function()
    isSpinning = false
    
    local tableEnt = LocalPlayer():GetNWEntity("RouletteTable")
    if IsValid(tableEnt) then
        local targetPos = tableEnt:GetPos() + 
                         tableEnt:GetForward() * CAMERA_OFFSET.x + 
                         tableEnt:GetRight() * CAMERA_OFFSET.y + 
                         tableEnt:GetUp() * CAMERA_OFFSET.z
        
        -- Возврат к исходной позиции с сохранением угла
        StartCameraTransition(targetPos, true)
    end
end)


hook.Add("PlayerButtonDown", "RouletteCloseOnE", function(ply, button)
    if button == KEY_E and (IsValid(rouletteFrame) or IsValid(infoFrame)) and not isInputFocused then
        if IsValid(rouletteFrame) then
            rouletteFrame:Close()
        end
        if IsValid(infoFrame) then
            infoFrame:Close()
        end
    end
end)

hook.Add("DarkRPVarChanged", "UpdateRouletteBalance", function(ply, var, old, new)
    if ply == LocalPlayer() and var == "money" and IsValid(infoFrame) then
        infoFrame:InvalidateLayout() -- Это заставит фрейм перерисоваться
    end
end)

net.Receive("RouletteCameraUpdate", function()
    customCameraEnabled = net.ReadBool()
    if customCameraEnabled then
        cameraPos = net.ReadVector()
        cameraAng = net.ReadAngle()
    end
end)

-- Хук для отрисовки фишек
hook.Add("PostDrawOpaqueRenderables", "DrawRoulettePreviewChips", function()
    if not IsValid(LocalPlayer()) then return end
    
    for _, chip in pairs(currentChips) do
        if IsValid(chip.model) then
            local pos, ang
            
            -- Получаем позицию и угол из таблицы ставок
            if selectedBet then
                local betData
                for group, bets in pairs(POSITION) do
                    if bets[selectedBet] then
                        betData = bets[selectedBet]
                        break
                    end
                end
                
                if betData then
                    local tableEnt = LocalPlayer():GetNWEntity("RouletteTable")
                    if IsValid(tableEnt) then
                        pos = tableEnt:LocalToWorld(betData.pos)
                        ang = tableEnt:LocalToWorldAngles(betData.ang or Angle(0,0,0))
                        
                        -- Добавляем смещение по Z для стопки фишек
                        pos = pos + tableEnt:GetUp() * ((chip.stackPos-1) * CHIP_HEIGHT)
                        
                        -- Фиксированный угол (без вращения)
                        ang = ang + chip.baseAngle
                    end
                end
            end
            
            if pos and ang then
                chip.model:SetPos(pos)
                chip.model:SetAngles(ang)
                chip.model:DrawModel()
            end
        end
    end
end)

-- Хук для управления камерой
hook.Add("CalcView", "RouletteCustomCamera", function(ply, pos, ang, fov)
    if customCameraEnabled and IsValid(ply) and ply:GetViewEntity() == ply then
        local view = {
            origin = cameraPos,
            angles = cameraAng,
            fov = fov,
            drawviewer = true
        }
        
        if cameraTransition.active then
            local progress = math.Clamp((RealTime() - cameraTransition.startTime) / cameraTransition.duration, 0, 1)
            view.origin = LerpVector(progress, cameraTransition.startPos, cameraTransition.targetPos)
            view.angles = LerpAngle(progress, cameraTransition.startAng, cameraTransition.targetAng)
            
            if progress >= 1 then
                cameraTransition.active = false
                cameraPos = cameraTransition.targetPos
                cameraAng = cameraTransition.targetAng
            end
        end
        
        return view
    end
end)

-- Хук для отключения камеры при смерти или других ситуациях
hook.Add("PlayerDeath", "RouletteCameraReset", function(ply)
    customCameraEnabled = false
end)

hook.Add("Think", "UpdateRouletteTimer", function()
    if IsValid(infoFrame) then
        infoFrame:InvalidateLayout() -- Принудительное обновление
    end
end)

hook.Add("Think", "SmoothTimerUpdate", function()
    local now = RealTime()
    local delta = now - smoothTimer.lastUpdate
    
    if delta < 1 then
        local diff = smoothTimer.targetTime - smoothTimer.currentDisplay
        smoothTimer.currentDisplay = smoothTimer.currentDisplay + diff * FrameTime() * 5
    else
        smoothTimer.currentDisplay = smoothTimer.targetTime
    end
    
    roundTimeLeft = math.Round(smoothTimer.currentDisplay)
    
    -- Запускаем переход камеры, когда таймер достигает 0
    if roundTimeLeft <= 0 and not cameraTransition.active and not isSpinning then
        isSpinning = true
        
        local tableEnt = LocalPlayer():GetNWEntity("RouletteTable")
        if IsValid(tableEnt) then
            local wheelPos = tableEnt:GetPos() + tableEnt:GetForward() * WHEEL_OFFSET.x + 
                            tableEnt:GetRight() * WHEEL_OFFSET.y + 
                            tableEnt:GetUp() * (WHEEL_OFFSET.z + 10)
            
            local wheelAng = tableEnt:GetAngles()
            wheelAng:RotateAroundAxis(wheelAng:Right(), -30)
            
            StartCameraTransition(wheelPos, wheelAng)
        end
    end
end)
