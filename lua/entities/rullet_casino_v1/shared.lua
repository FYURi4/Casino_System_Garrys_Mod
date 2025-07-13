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

CHIP_HEIGHT = 0.3 -- Высота одной фишки
MAX_CHIP_STACK = 10 -- Максимальное количество фишек в стопке
CHIP_OFFSET_RANDOM = 0.1 -- Случайное смещение фишек в стопке

CHIP_VALUES = {
    [0] = 1,    -- Текстура 0 = фишка 1
    [1] = 5,     -- Текстура 1 = фишка 5
    [2] = 10,    -- Текстура 2 = фишка 10
    [3] = 50,    -- Текстура 3 = фишка 50
    [4] = 100,   -- Текстура 4 = фишка 100
    [5] = 500,   -- Текстура 5 = фишка 500
    [6] = 1000   -- Текстура 6 = фишка 1000
}

CHIP_MODEL = "models/darkrpcasinoby3demc/fishka_casino.mdl"

POSITION = {
    ["OUTSIDE BETS"] = {
        ["low (1to18)"] = {pos = Vector(12.8, 5, 17.8), ang = Angle(0, 90, 0)},
        ["even"] = {pos = Vector(30, -20, 30), ang = Angle(0, 0, 0)},
        ["on red"] = {pos = Vector(30, 0, 30), ang = Angle(0, 0, 0)},
        ["on black"] = {pos = Vector(30, 20, 30), ang = Angle(0, 0, 0)},
        ["odd"] = {pos = Vector(30, 40, 30), ang = Angle(0, 0, 0)},
        ["1-12 (1st dozen)"] = {pos = Vector(-20, -50, 30), ang = Angle(0, 0, 0)},
        ["13-24 (2st dozen)"] = {pos = Vector(-20, -25, 30), ang = Angle(0, 0, 0)},
        ["25-36 (3rd dozen)"] = {pos = Vector(-20, 0, 30), ang = Angle(0, 0, 0)},
        ["1 line (2to1)"] = {pos = Vector(0, 50, 30), ang = Angle(0, 0, 0)},
        ["2 line (2to1)"] = {pos = Vector(0, 25, 30), ang = Angle(0, 0, 0)},
        ["3 line (2to1)"] = {pos = Vector(0, 0, 30), ang = Angle(0, 0, 0)}
    },
    ["GREEN"] = {
        ["0"] = {pos = Vector(-40, 50, 30), ang = Angle(0, 0, 0)} 
    },
    ["BLACK"] = {
        ["1"] = {pos = Vector(-10, 40, 30), ang = Angle(0, 0, 0)},
        ["3"] = {pos = Vector(-10, 35, 30), ang = Angle(0, 0, 0)},
        ["5"] = {pos = Vector(-10, 30, 30), ang = Angle(0, 0, 0)},
        ["7"] = {pos = Vector(-10, 25, 30), ang = Angle(0, 0, 0)},
        ["9"] = {pos = Vector(-10, 20, 30), ang = Angle(0, 0, 0)},
        ["11"] = {pos = Vector(-10, 15, 30), ang = Angle(0, 0, 0)},
        ["13"] = {pos = Vector(-10, 10, 30), ang = Angle(0, 0, 0)},
        ["15"] = {pos = Vector(-10, 5, 30), ang = Angle(0, 0, 0)},
        ["17"] = {pos = Vector(-10, 0, 30), ang = Angle(0, 0, 0)},
        ["19"] = {pos = Vector(-10, -5, 30), ang = Angle(0, 0, 0)},
        ["21"] = {pos = Vector(-10, -10, 30), ang = Angle(0, 0, 0)},
        ["23"] = {pos = Vector(-10, -15, 30), ang = Angle(0, 0, 0)},
        ["25"] = {pos = Vector(-10, -20, 30), ang = Angle(0, 0, 0)},
        ["27"] = {pos = Vector(-10, -25, 30), ang = Angle(0, 0, 0)},
        ["29"] = {pos = Vector(-10, -30, 30), ang = Angle(0, 0, 0)},
        ["31"] = {pos = Vector(-10, -35, 30), ang = Angle(0, 0, 0)},
        ["33"] = {pos = Vector(-10, -40, 30), ang = Angle(0, 0, 0)},
        ["35"] = {pos = Vector(-10, -45, 30), ang = Angle(0, 0, 0)}
    },
    ["RED"] = {
        ["2"] = {pos = Vector(0, 40, 30), ang = Angle(0, 0, 0)},
        ["4"] = {pos = Vector(0, 35, 30), ang = Angle(0, 0, 0)},
        ["6"] = {pos = Vector(0, 30, 30), ang = Angle(0, 0, 0)},
        ["8"] = {pos = Vector(0, 25, 30), ang = Angle(0, 0, 0)},
        ["10"] = {pos = Vector(0, 20, 30), ang = Angle(0, 0, 0)},
        ["12"] = {pos = Vector(0, 15, 30), ang = Angle(0, 0, 0)},
        ["14"] = {pos = Vector(0, 10, 30), ang = Angle(0, 0, 0)},
        ["16"] = {pos = Vector(0, 5, 30), ang = Angle(0, 0, 0)},
        ["18"] = {pos = Vector(0, 0, 30), ang = Angle(0, 0, 0)},
        ["20"] = {pos = Vector(0, -5, 30), ang = Angle(0, 0, 0)},
        ["22"] = {pos = Vector(0, -10, 30), ang = Angle(0, 0, 0)},
        ["24"] = {pos = Vector(0, -15, 30), ang = Angle(0, 0, 0)},
        ["26"] = {pos = Vector(0, -20, 30), ang = Angle(0, 0, 0)},
        ["28"] = {pos = Vector(0, -25, 30), ang = Angle(0, 0, 0)},
        ["30"] = {pos = Vector(0, -30, 30), ang = Angle(0, 0, 0)},
        ["32"] = {pos = Vector(0, -35, 30), ang = Angle(0, 0, 0)},
        ["34"] = {pos = Vector(0, -40, 30), ang = Angle(0, 0, 0)},
        ["36"] = {pos = Vector(0, -45, 30), ang = Angle(0, 0, 0)}
    }
}

