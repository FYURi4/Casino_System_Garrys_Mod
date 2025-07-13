  include('shared.lua')

local rouletteFrame = nil
local isInputFocused = false
local lastClickTime = 0
local currentBetAmount = 1
local minBetAmount = 1
local maxBetAmount = 1000
local betStep = 1
local ALL_BETS = {}
local betSlider = {}
local selectedBet = nil
local customCameraEnabled = false
local cameraPos, cameraAng
local lastClickedBet = nil

-- Chip values and model
local CHIP_VALUES = {
    [0] = 1,    -- Текстура 0 = фишка 1
    [1] = 5,     -- Текстура 1 = фишка 5
    [2] = 10,    -- Текстура 2 = фишка 10
    [3] = 50,    -- Текстура 3 = фишка 50
    [4] = 100,   -- Текстура 4 = фишка 100
    [5] = 500,   -- Текстура 5 = фишка 500
    [6] = 1000   -- Текстура 6 = фишка 1000
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
    SELECTED = Color(60, 50, 50) -- Золотистый цвет для выделения
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
            else
                selectedBet = name -- Выделяем ставку
                lastClickTime = currentTime
                lastClickedBet = name
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
                "low (1to18)", "even", "on red", "on black", "odd",
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
        local value = tonumber(numberEntry:GetText()) or currentBetAmount
        
        -- Проверяем, соответствует ли значение номиналу фишек
        local valid = false
        for _, chipValue in pairs(CHIP_VALUES) do
            if value == chipValue then
                valid = true
                break
            end
        end
        
        if not valid then
            -- Находим ближайшее допустимое значение
            local closest = 1
            local minDiff = math.huge
            for _, chipValue in pairs(CHIP_VALUES) do
                local diff = math.abs(value - chipValue)
                if diff < minDiff then
                    minDiff = diff
                    closest = chipValue
                end
            end
            
            value = closest
        end
        
        value = math.Clamp(math.floor(value), minBetAmount, maxBetAmount)
        currentBetAmount = value
        numberEntry:SetText(value)
    end
    
    numberEntry.OnEnter = function()
        numberEntry:OnLoseFocus()
    end
    
    numberEntry.OnValueChange = function(self, value)
        if value ~= "" then
            local num = tonumber(value)
            if num then
                -- Проверяем, соответствует ли значение номиналу фишек
                local valid = false
                for _, chipValue in pairs(CHIP_VALUES) do
                    if num == chipValue then
                        valid = true
                        break
                    end
                end
                
                if not valid then
                    -- Находим ближайшее допустимое значение
                    local closest = 1
                    local minDiff = math.huge
                    for _, chipValue in pairs(CHIP_VALUES) do
                        local diff = math.abs(num - chipValue)
                        if diff < minDiff then
                            minDiff = diff
                            closest = chipValue
                        end
                    end
                    
                    timer.Simple(0, function()
                        if IsValid(self) then
                            self:SetText(closest)
                            currentBetAmount = closest
                        end
                    end)
                else
                    currentBetAmount = num
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
        if IsValid(rouletteFrame) then
            rouletteFrame:Close()
        end
        if IsValid(infoFrame) then
            infoFrame:Close()
        end

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

            draw.SimpleText("END OF BETTING:",FONTS.ARIAL_MAX,27, 33.5,COLORS.TEXT_WHITE,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
            draw.SimpleText("0:00",FONTS.ARIAL_MAX, 160, 82,COLORS.TEXT_WHITE,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)

            draw.SimpleText("YOUR ACCOUNT:",FONTS.ARIAL_MAX,365, 33.5,COLORS.TEXT_WHITE,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
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
                -- Находим предыдущее допустимое значение
                local newValue = 1
                for i = #CHIP_VALUES, 1, -1 do
                    if CHIP_VALUES[i] < currentBetAmount then
                        newValue = CHIP_VALUES[i]
                        break
                    end
                end
                
                currentBetAmount = math.max(newValue, minBetAmount)
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
                -- Находим следующее допустимое значение
                local newValue = 1000
                for i = 1, #CHIP_VALUES do
                    if CHIP_VALUES[i] > currentBetAmount then
                        newValue = CHIP_VALUES[i]
                        break
                    end
                end
                
                currentBetAmount = math.min(newValue, maxBetAmount)
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
                
                -- Проверяем, достаточно ли у игрока денег
                local canAfford = LocalPlayer():canAfford(currentBetAmount)
                if not canAfford then
                    notification.AddLegacy("You don't have enough money!", NOTIFY_ERROR, 5)
                    return
                end
                
                -- Проверяем, что ставка соответствует номиналу фишек
                local validChip = false
                for _, chipValue in pairs(CHIP_VALUES) do
                    if currentBetAmount == chipValue then
                        validChip = true
                        break
                    end
                end
                
                if not validChip then
                    notification.AddLegacy("Bet amount must match chip value (1, 5, 10, 50, 100, 500, 1000)!", NOTIFY_ERROR, 5)
                    return
                end
                
                -- Запрашиваем подтверждение
                Derma_Query("Are you sure you want to bet " .. DarkRP.formatMoney(currentBetAmount) .. " on " .. selectedBet .. "?", 
                    "Confirm Bet",
                    "Yes", function()
                        -- Отправляем ставку на сервер
                        net.Start("RoulettePlaceBet")
                        net.WriteUInt(currentBetAmount, 32)
                        net.WriteString(selectedBet)
                        net.SendToServer()
                    end,
                    "No", function() end
                )
            end
        })

        rouletteFrame:SetKeyboardInputEnabled(false)
        infoFrame:SetKeyboardInputEnabled(false)
        gui.EnableScreenClicker(true)

        rouletteFrame.OnClose = function()
            if IsValid(infoFrame) then
                infoFrame:Close()
            end
            gui.EnableScreenClicker(false)
            rouletteFrame = nil
            infoFrame = nil
            isInputFocused = false
            selectedBet = nil
        end
        
        infoFrame.OnClose = function()
            if IsValid(rouletteFrame) then
                rouletteFrame:Close()
            end
        end
        
    elseif IsValid(rouletteFrame) then
        rouletteFrame:Close()
        if IsValid(infoFrame) then
            infoFrame:Close()
        end
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

-- Хук для управления камерой
hook.Add("CalcView", "RouletteCustomCamera", function(ply, pos, ang, fov)
    if customCameraEnabled and IsValid(ply) and ply:GetViewEntity() == ply then
        local view = {
            origin = cameraPos,
            angles = cameraAng,
            fov = fov,
            drawviewer = true -- Показывать модель игрока
        }
        return view
    end
end)

-- Хук для отключения камеры при смерти или других ситуациях
hook.Add("PlayerDeath", "RouletteCameraReset", function(ply)
    customCameraEnabled = false
end)
