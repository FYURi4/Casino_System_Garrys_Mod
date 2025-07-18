ENT.Base = "base_gmodentity"

ENT.Type = "anim"

ENT.Category = "3DEMC_ENT"

ENT.Spawnable = true

ENT.AdminSpawnable = true

ENT.ClassName = "Rullet_Machines"

ENT.PrintName = "Rullet_Machines"

ENT.Author = "FURA"

ENT.Contact = "Discord: fyurl4, Furushka: FurichF"

ENT.Purpose = ""

ENT.Instructions = ""

CHIP_HEIGHT = 0.15
MAX_CHIP_STACK = 10 
CHIP_OFFSET = 0.05

ROUND_WAITING = 0
ROUND_BETTING = 1
ROUND_SPINNING = 2
BETTING_TIME = 20 
SPIN_TIME = 10

CHIP_VALUES = {
    [0] = 1,   
    [1] = 5,   
    [2] = 10,  
    [3] = 50,    
    [4] = 100,  
    [5] = 500,   
    [6] = 1000   
}

CHIP_MODEL = "models/darkrpcasinoby3demc/fishka_casino.mdl"

POSITION = {
    ["OUTSIDE BETS"] = {
        ["low (1to18)"] = {pos = Vector(17.7, 0, 17.8), ang = Angle(0, 90, 0)},
        ["even"] = {pos = Vector(17.7, 9.5, 17.8), ang = Angle(0, 90, 0)},
        ["on red"] = {pos = Vector(17.7, 19.4, 17.8), ang = Angle(0, 90, 0)},
        ["on black"] = {pos = Vector(17.7, 29, 17.8), ang = Angle(0, 90, 0)},
        ["odd"] = {pos = Vector(17.7, 38.7, 17.8), ang = Angle(0, 90, 0)},
        ["high (10to36)"] = {pos = Vector(17.7, 48.45, 17.8), ang = Angle(0, 90, 0)},
        --//                                                                     //--
        ["1-12 (1st dozen)"] = {pos = Vector(12.8, 4.8, 17.8), ang = Angle(0, 90, 0)},
        ["13-24 (2st dozen)"] = {pos = Vector(12.8, 24.2, 17.8), ang = Angle(0, 90, 0)},
        ["25-36 (3rd dozen)"] = {pos = Vector(12.8, 43.5, 17.8), ang = Angle(0, 90, 0)},
        --//                                                                     //--
        ["1 line (2to1)"] = {pos = Vector(-5.4, 55.6, 17.8), ang = Angle(0, 90, 0)},
        ["2 line (2to1)"] = {pos = Vector(1, 55.6, 17.8), ang = Angle(0, 90, 0)},
        ["3 line (2to1)"] = {pos = Vector(7.3, 55.6, 17.8), ang = Angle(0, 90, 0)}
    },
    ["GREEN"] = {
        ["0"] = {pos = Vector(1, -7.15, 17.8), ang = Angle(0, 90, 0)} 
    },
    ["BLACK"] = {
        ["1"] = {pos = Vector(7.3, -2.3, 17.8), ang = Angle(0, 90, 0)},
        ["3"] = {pos = Vector(-5.4, -2.3, 17.8), ang = Angle(0, 90, 0)},
        ["5"] = {pos = Vector(1, 2.47, 17.8), ang = Angle(0, 90, 0)},
        ["7"] = {pos = Vector(7.3, 7.25, 17.8), ang = Angle(0, 90, 0)},
        ["9"] = {pos = Vector(-5.4, 7.25, 17.8), ang = Angle(0, 90, 0)},
        ["11"] = {pos = Vector(1, 12.1, 17.8), ang = Angle(0, 90, 0)},
        ["13"] = {pos = Vector(7.3, 17, 17.8), ang = Angle(0, 90, 0)},
        ["15"] = {pos = Vector(-5.4, 17, 17.8), ang = Angle(0, 90, 0)},
        ["17"] = {pos = Vector(1, 21.78, 17.8), ang = Angle(0, 90, 0)},
        ["19"] = {pos = Vector(7.3, 26.6, 17.8), ang = Angle(0, 90, 0)},
        ["21"] = {pos = Vector(-5.4, 26.6, 17.8), ang = Angle(0, 90, 0)},
        ["23"] = {pos = Vector(1, 31.5, 17.8), ang = Angle(0, 90, 0)},
        ["25"] = {pos = Vector(7.3, 36.3, 17.8), ang = Angle(0, 90, 0)},
        ["27"] = {pos = Vector(-5.4, 36.3, 17.8), ang = Angle(0, 90, 0)},
        ["29"] = {pos = Vector(1, 41.2, 17.8), ang = Angle(0, 90, 0)},
        ["31"] = {pos = Vector(7.3, 45.95, 17.8), ang = Angle(0, 90, 0)},
        ["33"] = {pos = Vector(-5.4, 45.95, 17.8), ang = Angle(0, 90, 0)},
        ["35"] = {pos = Vector(1, 50.85, 17.8), ang = Angle(0, 90, 0)}
    },
    ["RED"] = {
        ["2"] = {pos = Vector(1, -2.3, 17.8), ang = Angle(0, 90, 0)},
        ["4"] = {pos = Vector(7.3, 2.47, 17.8), ang = Angle(0, 90, 0)},
        ["6"] = {pos = Vector(-5.4, 2.47, 17.8), ang = Angle(0, 90, 0)},
        ["8"] = {pos = Vector(1, 7.25, 17.8), ang = Angle(0, 90, 0)},
        ["10"] = {pos = Vector(7.3, 12.1, 17.8), ang = Angle(0, 90, 0)},
        ["12"] = {pos = Vector(-5.4, 12.1, 17.8), ang = Angle(0, 90, 0)},
        ["14"] = {pos = Vector(1, 17, 17.8), ang = Angle(0, 90, 0)},
        ["16"] = {pos = Vector(7.3, 21.78, 17.8), ang = Angle(0, 90, 0)},
        ["18"] = {pos = Vector(-5.4, 21.7, 17.8), ang = Angle(0, 90, 0)},
        ["20"] = {pos = Vector(1, 26.6, 17.8), ang = Angle(0, 90, 0)},
        ["22"] = {pos = Vector(7.3, 31.5, 17.8), ang = Angle(0, 90, 0)},
        ["24"] = {pos = Vector(-5.4, 31.5, 17.8), ang = Angle(0, 90, 0)},
        ["26"] = {pos = Vector(1, 36.3, 17.8), ang = Angle(0, 90, 0)},
        ["28"] = {pos = Vector(7.3, 41.2, 17.8), ang = Angle(0, 90, 0)},
        ["30"] = {pos = Vector(-5.4, 41.2, 17.8), ang = Angle(0, 90, 0)},
        ["32"] = {pos = Vector(1, 45.95, 17.8), ang = Angle(0, 90, 0)},
        ["34"] = {pos = Vector(7.3, 50.85, 17.8), ang = Angle(0, 90, 0)},
        ["36"] = {pos = Vector(-5.4, 50.85, 17.8), ang = Angle(0, 90, 0)}
    }
}

local chipValues = {1000, 500, 100, 50, 10, 5, 1}
function BreakIntoChips(amount)
    local chips = {}
    for _, value in ipairs(chipValues) do
        while amount >= value do
            table.insert(chips, value)
            amount = amount - value
        end
    end
    return chips
end 
