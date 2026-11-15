--[[
	BRAINROT TYCOON - Configuração central
	Tudo que é ajustável (preços, renda, raridades, economia, Robux) fica aqui.

	Os itens dos 10 andares são GERADOS a partir da tabela Config.Floors abaixo:
	cada andar tem 2 esteiras (4 droppers + 2 multiplicadores cada), paredes,
	3 móveis, 6 brainrots, a escada para o próximo andar e 2 itens VIP (Robux).
	Os preços dos andares 2-10 saem de Config.Economy; o térreo tem preços fixos.

	Os modelos ficam em ServerStorage.TycoonTemplate.Items/<Id> e os botões em
	ServerStorage.TycoonTemplate.Buttons/<Id> (regerados pelo PlotBuilder).
]]

local Config = {}

-- Economia geral ------------------------------------------------------------
Config.StartingCash = 0
Config.DataStoreName = "BrainrotTycoon_v2"
Config.AutosaveInterval = 60
Config.MaxOresPerPlot = 260
Config.OreLifetime = 20
Config.ConveyorSpeed = 20
Config.AutoCollectInterval = 1
Config.MaxBrainrotBuff = 150           -- soma de TODOS os 60 brainrots = +150% (só no rebirth 10)
Config.MaxRebirths = 10
Config.FloorCount = 10
Config.DropperInterval = 2.5

Config.OfflineEarnings = {
	Enabled = true,
	Rate = 0.25, MaxSeconds = 2 * 60 * 60,          -- grátis: 25% por até 2h
	VipRate = 1, VipMaxSeconds = 12 * 60 * 60,      -- gamepass: 100% por até 12h
	MinSeconds = 60,
}

-- Curva de preços dos andares 2-10 (relativa ao 2º andar)
Config.Economy = {
	BasePrice = 230_000,        -- preço do 1º dropper do 2º andar
	BaseValue = 4_500,          -- valor do 1º dropper do 2º andar
	FloorPriceRatio = 42,   -- preço multiplica isso a cada andar
	FloorValueRatio = 20,   -- valor multiplica isso a cada andar
}

-- Rebirth -------------------------------------------------------------------
Config.Rebirth = {
	-- custo do 1º, 2º, ... 10º rebirth
	Costs = { 8800000000, 540000000000, 21000000000000, 690000000000000, 990000000000000, 29000000000000000, 38000000000000000, 1000000000000000000, 1300000000000000000, 34000000000000000000 },
	MultiplierPerRebirth = 0.5,        -- +50% de renda por rebirth (somado): R10 = x6
}
function Config.GetRebirthCost(rebirths: number): number
	return Config.Rebirth.Costs[rebirths + 1] or math.huge
end
function Config.GetMultiplier(rebirths: number): number
	return 1 + rebirths * Config.Rebirth.MultiplierPerRebirth
end

-- Níveis dos droppers (melhoria com dinheiro, zera no rebirth) ---------------
Config.DropperLevels = { ValuePerLevel = 0.5, CostGrowth = 3 }
function Config.GetMaxLevel(rebirths: number): number
	return 3 + math.floor(rebirths / 2)          -- R0: 3 ... R10: 8
end
function Config.GetLevelMultiplier(level: number): number
	return 1 + (level - 1) * Config.DropperLevels.ValuePerLevel
end
function Config.GetLevelCost(cfg, level: number): number      -- custo para ir de level -> level+1
	local base = (cfg.Price and cfg.Price > 0) and cfg.Price or 25
	return math.floor(base * Config.DropperLevels.CostGrowth ^ level)
end

-- Raridades -----------------------------------------------------------------
Config.Rarities = {
	Common       = { Order = 1, Color = Color3.fromRGB(190, 200, 210) },
	Rare         = { Order = 2, Color = Color3.fromRGB(70, 160, 255) },
	["Epic"]    = { Order = 3, Color = Color3.fromRGB(180, 90, 255) },
	["Legendary"] = { Order = 4, Color = Color3.fromRGB(255, 180, 40) },
	["Mythic"]   = { Order = 5, Color = Color3.fromRGB(255, 70, 120) },
	["Brainrot God"] = { Order = 6, Color = Color3.fromRGB(255, 255, 255), Rainbow = true },
}

-- Posições das esteiras --------------------------------------------------------
local BELT_ACCENTS = {
	A = {110, 220, 255}, B = {255, 110, 210}, C = {120, 255, 160}, D = {255, 200, 80},
	E = {190, 120, 255}, F = {255, 90, 90},   G = {90, 255, 230},  H = {255, 150, 60},
	I = {255, 120, 255}, J = {255, 240, 120}, K = {255, 215, 60},  L = {80, 220, 120},
	M = {120, 230, 90},  N = {255, 170, 70},  O = {150, 200, 255}, P = {200, 140, 255},
	Q = {240, 200, 120}, R = {255, 130, 90},  S = {255, 230, 150}, T = {255, 255, 255},
}
Config.Belts = {}
do
	local order = "ABCDEFGHIJKLMNOPQRST"
	for i = 1, #order do
		local id = order:sub(i, i)
		local c = BELT_ACCENTS[id]
		Config.Belts[id] = { Floor = math.ceil(i / 2), Z = (i % 2 == 1) and -20 or -50, Accent = Color3.fromRGB(c[1], c[2], c[3]), Index = i }
	end
end
Config.DropperSlotsX = { 46, 34, 22, 10 }
Config.UpgraderSlotsX = { -12, -32 }
Config.VipSlotX = { Dropper = -1, Upgrader = -42 }

-- Andares -------------------------------------------------------------------
-- Droppers: {Id, Nome, Ícone, Forma do minério, {r,g,b}}; Multiplicadores: {Id, Nome, Ícone, {r,g,b}}
-- Brainrots: {Id, Nome, Ícone, Raridade, Buff %}
Config.Floors = {
	{ Name = "Ground Floor", Rebirth = 0,
		Belts = {
			{ Id = "A", Droppers = { {"DropperA1","Neuron Generator","🧠","Ball",{255,140,200}}, {"DropperA2","Meme Fryer","🍟","Block",{255,210,70}}, {"DropperA3","Cringe Printer","🖨️","Block",{120,230,90}}, {"DropperA4","Rizz Microwave","📡","Ball",{255,120,60}} },
				Upgraders = { {"UpgraderA1","Brainrotifier","⚡",{255,225,60}}, {"UpgraderA2","Turbo Brainrotifier","⚡",{255,160,40}} } },
			{ Id = "B", Conveyor = {"ConveyorB","Turbo Conveyor"}, Droppers = { {"DropperB1","Sigma Reactor","🗿","Ball",{90,220,255}}, {"DropperB2","Aura Distiller","✨","Ball",{190,110,255}}, {"DropperB3","Meme Collider","💥","Block",{255,70,110}}, {"DropperB4","Ohio Core","☢️","Ball",{255,230,60}} },
				Upgraders = { {"UpgraderB1","Aura Amplifier","🔆",{200,120,255}}, {"UpgraderB2","Ultra Brainrotifier","🌀",{110,220,255}} } },
		},
		Walls = {"F1Walls","Ground Floor Walls","🏠"},
		Furniture = { {"F1Sofa","Comfy Couch","🛋️"}, {"F1TV","Meme TV","📺"}, {"F1Plants","Brainrot Plants","🌿"} },
		Brainrots = { {"Bananito","Bananito Bandito","🍌","Common",1}, {"Pinguino","Pinguino Spaghettino","🐧","Common",1}, {"Frigorifero","Frigorifero Cantante","🧊","Rare",1},
			{"Biscottino","Biscottino Boxeador","🍪","Common",1}, {"Limoncello","Limone Lanciatore","🍋","Rare",1}, {"Ciambella","Ciambella Ciclone","🍩","Rare",1} },
		LateBrainrotRebirth = 1,
		Stairs = {"Stairs1","Stairs + 2nd Floor"},
	},
	{ Name = "2nd Floor", Rebirth = 0,
		Belts = {
			{ Id = "C", Conveyor = {"ConveyorC","2nd Floor Conveyor"}, Droppers = { {"DropperC1","Lore Blender","🥤","Ball",{120,255,170}}, {"DropperC2","Hype Oven","🔥","Block",{255,120,50}}, {"DropperC3","Vibe Antenna","📻","Ball",{110,170,255}}, {"DropperC4","Delulu Turbine","🌪️","Block",{255,150,230}} },
				Upgraders = { {"UpgraderC1","Lore Magnifier","🔍",{120,255,170}}, {"UpgraderC2","Hype-o-Matic","🎛️",{255,240,120}} } },
			{ Id = "D", Conveyor = {"ConveyorD","Golden Conveyor"}, Droppers = { {"DropperD1","Plot Twist Press","🎬","Block",{255,200,80}}, {"DropperD2","Chaos Cauldron","🧪","Ball",{150,255,90}}, {"DropperD3","Confetti Cannon","💨","Ball",{220,230,255}}, {"DropperD4","Main Character Generator","⭐","Block",{255,240,90}} },
				Upgraders = { {"UpgraderD1","Chaos Chamber","🌋",{255,120,60}}, {"UpgraderD2","Main Character Prism","💎",{120,230,255}} } },
		},
		Walls = {"F2Walls","2nd Floor Walls","🧱"},
		Furniture = { {"F2Bed","Gamer Bed","🛏️"}, {"F2Desk","Gamer Setup","🖥️"}, {"F2Arcade","Retro Arcade","👾"} },
		Brainrots = { {"Toastino","Toastino Tornado","🍞","Rare",1}, {"Mozzarello","Mozzarello Razzetto","🚀","Epic",1}, {"Ananasso","Ananasso Astronauta","🍍","Epic",1},
			{"Pizzetta","Pizzetta Pirata","🍕","Epic",1}, {"Gelatino","Gelatino Gelato","🍦","Epic",2}, {"Formaggio","Formaggio Fantasma","🧀","Legendary",2} },
		LateBrainrotRebirth = 1,
		Stairs = {"Stairs2","Stairs + 3rd Floor"},
	},
	{ Name = "3rd Floor", Rebirth = 0,
		Belts = {
			{ Id = "E", Conveyor = {"ConveyorE","Cosmic Conveyor"}, Droppers = { {"DropperE1","Infinite Aura Plant","💫","Ball",{200,140,255}}, {"DropperE2","Quantum Rizz Reactor","⚛️","Ball",{90,255,230}}, {"DropperE3","Golden Sigma Mine","🏆","Block",{255,205,60}}, {"DropperE4","Brainrot Satellite","🛰️","Ball",{255,255,255}} },
				Upgraders = { {"UpgraderE1","Quantum Accelerator","🔋",{90,255,230}}, {"UpgraderE2","Sigma Halo","😇",{255,240,140}} } },
			{ Id = "F", Conveyor = {"ConveyorF","Supreme Conveyor"}, Droppers = { {"DropperF1","Multiverse Portal","🚪","Ball",{255,80,120}}, {"DropperF2","Cosmic Forge","🌌","Block",{120,90,255}}, {"DropperF3","Brainrot Heart","💖","Ball",{255,120,200}}, {"DropperF4","Meme Supernova","🌟","Ball",{255,250,180}} },
				Upgraders = { {"UpgraderF1","Dimensional Rift","🕳️",{150,90,255}}, {"UpgraderF2","Supreme Core","👑",{255,220,90}} } },
		},
		Walls = {"F3Walls","3rd Floor Walls","🌇"},
		Furniture = { {"F3Jacuzzi","Soda Hot Tub","🛁"}, {"F3Throne","Golden Throne","👑"}, {"F3Disco","Disco Ball","💃"} },
		Brainrots = { {"Cocomero","Cocomero Colosso","🍉","Legendary",1}, {"Gattino","Gattino Galattico","🐱","Mythic",1}, {"Pomodoro","Il Supremo Pomodoro","🍅","Brainrot God",2},
			{"Melanzana","Melanzana Ninja","🍆","Legendary",2}, {"Avocado","Avocado Astrale","🥑","Mythic",2}, {"Ravioli","Ravioli Reale","🥟","Brainrot God",2} },
		LateBrainrotRebirth = 1,
		Stairs = {"Stairs3","Stairs + 4th Floor"},
	},
	{ Name = "Laboratory", Rebirth = 1,
		Belts = {
			{ Id = "G", Conveyor = {"ConveyorG","Lab Conveyor"}, Droppers = { {"DropperG1","Meme Centrifuge","🧲","Ball",{90,255,230}}, {"DropperG2","Brainrot Cloner","🧬","Block",{140,255,120}}, {"DropperG3","Aura Laser","🔦","Ball",{255,120,255}}, {"DropperG4","Legend Incubator","🥚","Ball",{255,245,210}} },
				Upgraders = { {"UpgraderG1","Quantum Purifier","🔬",{90,255,230}}, {"UpgraderG2","Reality Bender","🎭",{255,120,255}} } },
			{ Id = "H", Conveyor = {"ConveyorH","Plasma Conveyor"}, Droppers = { {"DropperH1","Sigma Plasma Reactor","🔮","Ball",{255,150,60}}, {"DropperH2","Particle Accelerator","🎇","Ball",{255,90,160}}, {"DropperH3","Ohio Factory","🏭","Block",{170,170,190}}, {"DropperH4","Brainrot Matrix","💾","Block",{110,255,140}} },
				Upgraders = { {"UpgraderH1","Sigma Synthesizer","🎹",{255,150,60}}, {"UpgraderH2","Plasma Crown","💠",{120,200,255}} } },
		},
		Walls = {"F4Walls","Lab Walls","🧱"},
		Furniture = { {"F4Tube","Giant Test Tube","🧪"}, {"F4Computer","Quantum Computer","💻"}, {"F4Jar","Brain in a Jar","🧠"} },
		Brainrots = { {"Broccolo","Broccolo Robotico","🥦","Epic",1}, {"Cocco","Cocco Coccodrillo","🥥","Legendary",2}, {"Funghetto","Funghetto Fulmine","🍄","Legendary",2},
			{"Peperone","Peperone Pazzo","🌶️","Mythic",2}, {"Uovo","Uovo Ufo","🛸","Mythic",2}, {"Panino","Panino Paradiso","🥪","Brainrot God",3} },
		Stairs = {"Stairs4","Stairs + 5th Floor"},
	},
	{ Name = "Celestial Penthouse", Rebirth = 2,
		Belts = {
			{ Id = "I", Conveyor = {"ConveyorI","Galactic Conveyor"}, Droppers = { {"DropperI1","Star Forge","🌠","Ball",{255,120,255}}, {"DropperI2","Galactic Press","🌍","Ball",{90,160,255}}, {"DropperI3","Infinity Fountain","🔱","Block",{80,255,200}}, {"DropperI4","Brainrot Sun","🌞","Ball",{255,220,60}} },
				Upgraders = { {"UpgraderI1","Stellar Lens","🔭",{255,120,255}}, {"UpgraderI2","Galactic Halo","🌟",{255,240,140}} } },
			{ Id = "J", Conveyor = {"ConveyorJ","Infinity Conveyor"}, Droppers = { {"DropperJ1","Meme Black Hole","⚫","Ball",{60,40,90}}, {"DropperJ2","Brainrot Big Bang","🎆","Ball",{255,160,80}}, {"DropperJ3","Sigma Nebula","🌈","Block",{200,140,255}}, {"DropperJ4","Supreme Cosmic Brain","🧿","Ball",{255,255,255}} },
				Upgraders = { {"UpgraderJ1","Singularity","🌀",{150,90,255}}, {"UpgraderJ2","Brainrot Supremacy","🏅",{255,220,90}} } },
		},
		Walls = {"F5Walls","Celestial Walls","🌌"},
		Furniture = { {"F5Telescope","Cosmic Telescope","🔭"}, {"F5Pool","Ball Pit","🎱"}, {"F5Portal","Brainrot Portal","🌀"} },
		Brainrots = { {"Carota","Carota Cometa","🥕","Legendary",2}, {"Fragola","Fragola Fenice","🍓","Mythic",2}, {"Mirtillo","Mirtillo Mago","🔵","Mythic",2},
			{"Cipolla","Cipolla Cosmica","🧅","Mythic",2}, {"Torta","Torta Titanica","🎂","Brainrot God",3}, {"Gnocco","Il Grande Gnocco","🥔","Brainrot God",3} },
		Stairs = {"Stairs5","Stairs + Casino"},
	},
	{ Name = "Brainrot Casino", Rebirth = 3,
		Belts = {
			{ Id = "K", Conveyor = {"ConveyorK","Casino Conveyor"}, Droppers = { {"DropperK1","Meme Slot Machine","🎰","Ball",{255,215,60}}, {"DropperK2","Rizz Roulette","🎡","Ball",{255,70,90}}, {"DropperK3","Sigma Deck","🃏","Block",{240,240,255}}, {"DropperK4","Lucky Die","🎲","Block",{255,110,200}} },
				Upgraders = { {"UpgraderK1","Double Jackpot","💰",{255,215,60}}, {"UpgraderK2","Big Luck Bonus","🎊",{255,90,200}} } },
			{ Id = "L", Conveyor = {"ConveyorL","Chip Conveyor"}, Droppers = { {"DropperL1","Cash Press","💵","Block",{110,230,120}}, {"DropperL2","Cursed Diamond","💎","Ball",{120,220,255}}, {"DropperL3","Golden Chip","🥇","Ball",{255,200,60}}, {"DropperL4","Casino Crown","👑","Ball",{255,240,120}} },
				Upgraders = { {"UpgraderL1","VIP Table","🎩",{80,220,120}}, {"UpgraderL2","Grand Prize","🏆",{255,220,90}} } },
		},
		Walls = {"F6Walls","Casino Walls","🎰"},
		Furniture = { {"F6Slot","Giant Slot Machine","🎰"}, {"F6Roulette","Wheel of Fortune","🎡"}, {"F6Poker","Poker Table","🃏"} },
		Brainrots = { {"Dadino","Dadino Dinamite","🎲","Rare",2}, {"Cartino","Cartino Coringa","🃏","Epic",2}, {"Slotto","Slotto Sorridente","🎰","Epic",3},
			{"Moneta","Moneta Matta","💰","Legendary",3}, {"Rouletta","Rouletta Rotante","🎡","Mythic",3}, {"Jackpottino","Jackpottino Supremo","👑","Brainrot God",3} },
		Stairs = {"Stairs6","Stairs + Tropical Jungle"},
	},
	{ Name = "Tropical Jungle", Rebirth = 5,
		Belts = {
			{ Id = "M", Conveyor = {"ConveyorM","Vine Conveyor"}, Droppers = { {"DropperM1","Aura Palm Tree","🌴","Ball",{140,90,50}}, {"DropperM2","Meme Volcano","🌋","Ball",{255,100,40}}, {"DropperM3","Sigma Waterfall","💧","Ball",{90,180,255}}, {"DropperM4","Carnivorous Flower","🌺","Block",{255,90,160}} },
				Upgraders = { {"UpgraderM1","Jungle Ritual","🔥",{255,140,50}}, {"UpgraderM2","Turbo Vine","🌿",{120,230,90}} } },
			{ Id = "N", Conveyor = {"ConveyorN","River Conveyor"}, Droppers = { {"DropperN1","Toucan Nest","🐦","Ball",{255,170,70}}, {"DropperN2","Rizz Beehive","🐝","Block",{255,220,50}}, {"DropperN3","Emerald Mine","💚","Block",{60,230,120}}, {"DropperN4","Ancestral Tree","🌳","Ball",{100,200,80}} },
				Upgraders = { {"UpgraderN1","Moonstone","🌙",{200,220,255}}, {"UpgraderN2","Jaguar Eye","🐆",{255,200,60}} } },
		},
		Walls = {"F7Walls","Bamboo Walls","🎋"},
		Furniture = { {"F7Palm","Giant Palm Tree","🌴"}, {"F7Falls","Indoor Waterfall","💦"}, {"F7Totem","Tiki Totem","🗿"} },
		Brainrots = { {"Mangolino","Mangolino Macaco","🥭","Epic",2}, {"Gorillone","Gorillone Gelatina","🦍","Legendary",3}, {"Pappagallo","Pappagallo Pizzaiolo","🦜","Legendary",3},
			{"Tucanello","Tucanello Tutti-Frutti","🐦","Mythic",3}, {"Serpentina","Serpentina Salsa","🐍","Mythic",3}, {"Leone","Re Leone Limone","🦁","Brainrot God",4} },
		Stairs = {"Stairs7","Stairs + Space Station"},
	},
	{ Name = "Space Station", Rebirth = 7,
		Belts = {
			{ Id = "O", Conveyor = {"ConveyorO","Orbital Conveyor"}, Droppers = { {"DropperO1","Stardust Collector","✨","Ball",{200,220,255}}, {"DropperO2","Asteroid Factory","☄️","Block",{160,140,130}}, {"DropperO3","Warp Drive","🚀","Ball",{120,180,255}}, {"DropperO4","Lunar Crystal","🌙","Block",{220,230,255}} },
				Upgraders = { {"UpgraderO1","Planetary Ring","💫",{150,200,255}}, {"UpgraderO2","Meteor Shower","🌠",{255,200,120}} } },
			{ Id = "P", Conveyor = {"ConveyorP","Anti-Gravity Conveyor"}, Droppers = { {"DropperP1","Brainrot Antimatter","🧪","Ball",{200,90,255}}, {"DropperP2","Orbital Laser","🔦","Ball",{255,80,80}}, {"DropperP3","Gravity Generator","🌀","Block",{120,90,255}}, {"DropperP4","Pulsar Core","💠","Ball",{90,240,255}} },
				Upgraders = { {"UpgraderP1","Cryo Chamber","❄️",{170,230,255}}, {"UpgraderP2","Star Portal","🌌",{200,140,255}} } },
		},
		Walls = {"F8Walls","Station Hull","🛰️"},
		Furniture = { {"F8Pod","Command Pod","🕹️"}, {"F8Robot","Robot Assistant","🤖"}, {"F8Holo","Galactic Hologram","🌍"} },
		Brainrots = { {"Lunetta","Lunetta Lunare","🌙","Legendary",3}, {"Robottino","Robottino Rizz","🤖","Legendary",3}, {"Marziano","Marziano Melone","👽","Mythic",3},
			{"Cometino","Cometino Caffè","☕","Mythic",3}, {"Satellino","Satellino Spaghetto","🛰️","Brainrot God",4}, {"Galassio","Galassio Gelato","🌌","Brainrot God",4} },
		Stairs = {"Stairs8","Stairs + Ancient Temple"},
	},
	{ Name = "Ancient Temple", Rebirth = 9,
		Belts = {
			{ Id = "Q", Conveyor = {"ConveyorQ","Pharaoh Conveyor"}, Droppers = { {"DropperQ1","Golden Altar","🏺","Block",{255,200,80}}, {"DropperQ2","Meme Pyramid","🔺","Block",{240,200,120}}, {"DropperQ3","Sigma Sphinx","🦁","Ball",{230,180,100}}, {"DropperQ4","Eternal Torch","🔥","Ball",{255,120,40}} },
				Upgraders = { {"UpgraderQ1","Sacred Eye","👁️",{90,200,255}}, {"UpgraderQ2","Ancient Scroll","📜",{240,220,170}} } },
			{ Id = "R", Conveyor = {"ConveyorR","Relic Conveyor"}, Droppers = { {"DropperR1","Holy Grail","🏆","Ball",{255,215,90}}, {"DropperR2","Lost Relic","💍","Ball",{120,255,200}}, {"DropperR3","Colossal Statue","🗽","Block",{120,220,190}}, {"DropperR4","Temple Heart","❤️","Ball",{255,60,80}} },
				Upgraders = { {"UpgraderR1","Ancestral Crystal","🔮",{200,120,255}}, {"UpgraderR2","Pharaoh Seal","👑",{255,210,70}} } },
		},
		Walls = {"F9Walls","Temple Walls","🏛️"},
		Furniture = { {"F9Pillars","Ancient Pillars","🏛️"}, {"F9Sarcophagus","Golden Sarcophagus","⚱️"}, {"F9Torches","Sacred Torches","🔥"} },
		Brainrots = { {"Mummietto","Mummietto Maccherone","🧟","Legendary",3}, {"Faraone","Faraone Finocchio","🌿","Mythic",3}, {"Sfingetta","Sfingetta Sorbetto","🍧","Mythic",4},
			{"Arancino","Anubino Arancino","🍊","Mythic",4}, {"Oracolo","Oracolo Olivetto","🔮","Brainrot God",4}, {"Pistacchio","Il Faraone Pistacchio","🥜","Brainrot God",4} },
		Stairs = {"Stairs9","Stairs + Supreme Throne"},
	},
	{ Name = "Supreme Throne", Rebirth = 10,
		Belts = {
			{ Id = "S", Conveyor = {"ConveyorS","Divine Conveyor"}, Droppers = { {"DropperS1","Cosmic Crown","👑","Ball",{255,220,90}}, {"DropperS2","Diamond Throne","💎","Block",{150,240,255}}, {"DropperS3","Primordial Fountain","⛲","Ball",{120,200,255}}, {"DropperS4","Absolute Brain","🧠","Ball",{255,150,210}} },
				Upgraders = { {"UpgraderS1","Supreme Blessing","😇",{255,245,180}}, {"UpgraderS2","Divine Aura","🌈",{255,140,220}} } },
			{ Id = "T", Conveyor = {"ConveyorT","Final Conveyor"}, Droppers = { {"DropperT1","Final Big Bang","💥","Ball",{255,160,60}}, {"DropperT2","Supreme Star","🌟","Ball",{255,250,200}}, {"DropperT3","Brainrot Singularity","🌀","Ball",{180,120,255}}, {"DropperT4","Meme Genesis","🎆","Ball",{255,255,255}} },
				Upgraders = { {"UpgraderT1","Absolute Supremacy","🏅",{255,215,80}}, {"UpgraderT2","End of Brainrot","🔱",{255,90,200}} } },
		},
		Walls = {"F10Walls","Throne Wall","🏰"},
		Furniture = { {"F10Heli","Golden Helipad","🚁"}, {"F10Statue","Supreme Brain Statue","🗿"}, {"F10Fireworks","Eternal Fireworks","🎆"} },
		Brainrots = { {"Dolcetto","Divino Dolcetto","🧁","Mythic",3}, {"Insalata","Imperatore Insalata","🥗","Brainrot God",4}, {"Ricotta","Regina Ricotta","👸","Brainrot God",4},
			{"Tiramisu","Titano Tiramisù","🍰","Brainrot God",4}, {"Cervellone","Il Cervellone Cosmico","🧠","Brainrot God",4}, {"Ultimo","L'Ultimo Brainrot","👑","Brainrot God",5} },
	},
}

-- Robux: Dropper e Multiplicador VIP de cada andar (permanentes, ficam após o rebirth)
-- ProductId = id do Developer Product criado no Creator Dashboard (0 = só teste no Studio)
Config.VipRobux = {
	Dropper   = { 29, 39, 49, 69, 89, 109, 129, 149, 179, 199 },
	Upgrader  = { 25, 35, 45, 59, 79, 99, 119, 139, 159, 189 },
	ValueMultiplier = 6,      -- dropper VIP vale 6x o melhor dropper do andar
	Interval = 2,
	Multiplier = 3,           -- multiplicador VIP: x3 na esteira da frente do andar
}
Config.VipProductIds = { Dropper = {3731914381,3731914498,3731914514,3731914529,3731914552,3731914571,3731914586,3731914602,3731914615,3731914636}, Upgrader = {3731914492,3731914506,3731914525,3731914538,3731914562,3731914575,3731914593,3731914608,3731914624,3731914641} }

-- Gamepasses (PassId = id do Game Pass criado no Creator Dashboard; 0 = só teste no Studio)
Config.GamePasses = {
	{ Id = "DoubleCash", Name = "2x Cash", Icon = "💰", Robux = 199, PassId = 2088790426,
		Description = "Doubles ALL dropper cash, forever." },
	{ Id = "AutoCollect", Name = "VIP Auto-Collector", Icon = "🤖", Robux = 99, PassId = 2088718500,
		Description = "Your vault empties by itself from the start, even after every rebirth." },
	{ Id = "OfflineVIP", Name = "VIP Offline Earnings", Icon = "🌙", Robux = 149, PassId = 2088340502,
		Description = "Earn 100% of your income while away (up to 12 hours)." },
	{ Id = "FastWalk", Name = "Turbo Sneakers", Icon = "👟", Robux = 79, PassId = 2087830491,
		Description = "Walk 75% faster across your whole base." },
}
-- Pacotes de dinheiro (Developer Products, consumíveis): dão X minutos da renda atual
Config.CashPacks = {
	{ Id = "Cash5m",  Name = "5 Minutes of Cash",  Icon = "⏱️", Minutes = 5,   Robux = 5,   ProductId = 3731923795 },
	{ Id = "Cash30m", Name = "30 Minutes of Cash", Icon = "⏰", Minutes = 30,  Robux = 30,  ProductId = 3731923889 },
	{ Id = "Cash1h",  Name = "1 Hour of Cash",     Icon = "💵", Minutes = 60,  Robux = 60,  ProductId = 3731923904 },
	{ Id = "Cash6h",  Name = "6 Hours of Cash",    Icon = "💰", Minutes = 360, Robux = 300, ProductId = 3731923912 },
	{ Id = "Cash12h", Name = "12 Hours of Cash",   Icon = "🤑", Minutes = 720, Robux = 600, ProductId = 3731923917 },
}
Config.CashPackMinIncome = 10      -- renda mínima usada no cálculo (jogador começando)
Config.CashPacksById = {}
for _, pack in ipairs(Config.CashPacks) do Config.CashPacksById[pack.Id] = pack end
function Config.GetCashPackAmount(pack, incomePerSecond: number?): number
	return math.floor(math.max(incomePerSecond or 0, Config.CashPackMinIncome) * pack.Minutes * 60)
end
function Config.FormatMinutes(minutes: number): string
	if minutes >= 60 then
		local h = minutes / 60
		return h .. (h == 1 and " hour" or " hours")
	end
	return minutes .. " min"
end

Config.GamePassesById = {}
for _, gp in ipairs(Config.GamePasses) do Config.GamePassesById[gp.Id] = gp end

-- Preços do térreo (fixos, introdução) e multiplicadores relativos dos outros andares
local FLOOR1 = {
	Conveyor = { nil, 7_000 },
	Droppers = { { 0, 75, 300, 1_000 }, { 10_000, 16_000, 26_000, 40_000 } },
	Values = { { 10, 25, 60, 140 }, { 400, 650, 1_000, 1_500 } },
	Upgraders = { { 2_000, 4_500 }, { 60_000, 90_000 } },
	Walls = 150, Furniture = { 1_500, 6_000, 20_000 },
	Brainrots = { 600, 3_000, 12_000, 25_000, 80_000, 200_000 }, Stairs = 120_000,
}
local REL = {
	Conveyor = { 0.78, 9.6 },
	Droppers = { { 1, 1.43, 2.1, 3.0 }, { 13, 18, 26, 37 } },
	Values = { { 1, 1.55, 2.2, 3.2 }, { 7.1, 10, 14, 19.6 } },
	Upgraders = { { 4.3, 6.5 }, { 52, 74 } },
	Walls = 1.1, Furniture = { 2.6, 7.8, 22 },
	Brainrots = { 1.74, 5.2, 17, 26, 52, 130 }, Stairs = 78,
}
local function nice(x)
	if x <= 0 then return 0 end
	local m = 10 ^ (math.floor(math.log10(x)) - 1)
	return math.floor(x / m + 0.5) * m
end
local function floorTable(f)
	if f == 1 then return FLOOR1 end
	local E = Config.Economy
	local B = E.BasePrice * E.FloorPriceRatio ^ (f - 2)
	local U = E.BaseValue * E.FloorValueRatio ^ (f - 2)
	local t = { Conveyor = {}, Droppers = { {}, {} }, Values = { {}, {} }, Upgraders = { {}, {} }, Furniture = {}, Brainrots = {} }
	for b = 1, 2 do
		t.Conveyor[b] = nice(REL.Conveyor[b] * B)
		for j = 1, 4 do
			t.Droppers[b][j] = nice(REL.Droppers[b][j] * B)
			t.Values[b][j] = nice(REL.Values[b][j] * U)
		end
		for j = 1, 2 do t.Upgraders[b][j] = nice(REL.Upgraders[b][j] * B) end
	end
	t.Walls = nice(REL.Walls * B)
	for j = 1, 3 do t.Furniture[j] = nice(REL.Furniture[j] * B) end
	for j = 1, 6 do t.Brainrots[j] = nice(REL.Brainrots[j] * B) end
	t.Stairs = nice(REL.Stairs * B)
	return t
end

-- Geração da lista de itens -------------------------------------------------
-- Type: Dropper | Upgrader | Conveyor | Brainrot | Decor | AutoCollector | Floor
Config.Items = {}
local function add(item)
	if item.Rebirth == 0 then item.Rebirth = nil end
	table.insert(Config.Items, item)
	return item
end
local function oreFor(beltIndex, j, shape, rgb)
	return { Shape = shape, Color = Color3.fromRGB(rgb[1], rgb[2], rgb[3]),
		Size = math.min(1.3 + 0.07 * (beltIndex - 1) + 0.06 * (j - 1), 2.9),
		Material = (beltIndex == 1 and j < 4) and "SmoothPlastic" or "Neon", Trail = beltIndex >= 2 }
end
for f, floor in ipairs(Config.Floors) do
	local T = floorTable(f)
	local R = floor.Rebirth
	local prevStairs = (f > 1) and Config.Floors[f - 1].Stairs[1] or nil
	local lastId
	for b, belt in ipairs(floor.Belts) do
		local beltIndex = Config.Belts[belt.Id].Index
		if belt.Conveyor then
			local req = (b == 1) and { prevStairs } or { lastId }
			add({ Id = belt.Conveyor[1], Name = belt.Conveyor[2], Icon = "🛤️", Type = "Conveyor", Belt = belt.Id, Floor = f,
				Price = T.Conveyor[b], Requires = req, Rebirth = R })
			lastId = belt.Conveyor[1]
		end
		for j, d in ipairs(belt.Droppers) do
			add({ Id = d[1], Name = d[2], Icon = d[3], Type = "Dropper", Belt = belt.Id, Slot = j, Floor = f,
				Price = T.Droppers[b][j], Value = T.Values[b][j], Interval = Config.DropperInterval,
				Ore = oreFor(beltIndex, j, d[4], d[5]), Requires = lastId and { lastId } or {}, Rebirth = R })
			lastId = d[1]
		end
		for j, u in ipairs(belt.Upgraders) do
			add({ Id = u[1], Name = u[2], Icon = u[3], Type = "Upgrader", Belt = belt.Id, Slot = j, Floor = f,
				Price = T.Upgraders[b][j], Multiplier = (j == 1) and 1.5 or 2, Tint = Color3.fromRGB(u[4][1], u[4][2], u[4][3]),
				Requires = { lastId }, Rebirth = R })
			lastId = u[1]
		end
	end
	local walls = floor.Walls
	add({ Id = walls[1], Name = walls[2], Icon = walls[3], Type = "Decor", Floor = f, Price = T.Walls,
		Requires = { prevStairs or "DropperA1" }, Rebirth = R })
	local prevB = walls[1]
	for j, br in ipairs(floor.Brainrots) do
		local reb = R
		if j >= 4 and floor.LateBrainrotRebirth then reb = math.max(R, floor.LateBrainrotRebirth) end
		add({ Id = br[1], Name = br[2], Icon = br[3], Type = "Brainrot", Rarity = br[4], Buff = br[5],
			Floor = f, Slot = j, Price = T.Brainrots[j], Requires = { prevB }, Rebirth = reb })
		prevB = br[1]
	end
	local prevF = walls[1]
	local stairsReq = { walls[1] }
	for j, fu in ipairs(floor.Furniture) do
		add({ Id = fu[1], Name = fu[2], Icon = fu[3], Type = "Decor", Floor = f, Price = T.Furniture[j],
			Requires = { prevF }, Rebirth = R })
		prevF = fu[1]
		table.insert(stairsReq, fu[1])
	end
	if floor.Stairs then
		add({ Id = floor.Stairs[1], Name = floor.Stairs[2], Icon = "🏢", Type = "Floor", Floor = f, Price = T.Stairs,
			Requires = stairsReq, Rebirth = Config.Floors[f + 1].Rebirth })
	end
	-- Itens VIP (Robux)
	local first = floor.Belts[1]
	local vipReq = first.Conveyor and first.Conveyor[1] or "DropperA1"
	local best = T.Values[2][4]
	add({ Id = "VipDropper" .. f, Name = "VIP Dropper — " .. floor.Name, Icon = "💎", Type = "Dropper", Belt = first.Id, Slot = "VIP",
		Floor = f, Price = 0, Robux = Config.VipRobux.Dropper[f], ProductId = Config.VipProductIds.Dropper[f],
		Value = nice(best * Config.VipRobux.ValueMultiplier), Interval = Config.VipRobux.Interval,
		Ore = { Shape = "Ball", Color = Color3.fromRGB(255, 215, 60), Size = 2.2, Material = "Neon", Trail = true },
		Requires = { vipReq }, Rebirth = R, Premium = true })
	add({ Id = "VipUpgrader" .. f, Name = "VIP Upgrader — " .. floor.Name, Icon = "💎", Type = "Upgrader", Belt = first.Id, Slot = "VIP",
		Floor = f, Price = 0, Robux = Config.VipRobux.Upgrader[f], ProductId = Config.VipProductIds.Upgrader[f],
		Multiplier = Config.VipRobux.Multiplier, Tint = Color3.fromRGB(255, 215, 60), Requires = { vipReq }, Rebirth = R, Premium = true })
	if f == 1 then
		add({ Id = "Lamps", Name = "Street Lamps", Icon = "💡", Type = "Decor", Floor = 1, Price = 2_500, Requires = { "F1Walls" } })
		add({ Id = "Fountain", Name = "Soda Fountain", Icon = "⛲", Type = "Decor", Floor = 1, Price = 25_000, Requires = { "Lamps" } })
		add({ Id = "AutoCollector", Name = "Auto-Collector", Icon = "🤖", Type = "AutoCollector", Floor = 1, Price = 50_000, Requires = { "DropperB1" } })
		add({ Id = "Statue", Name = "Brain Statue", Icon = "🏆", Type = "Decor", Floor = 1, Price = 250_000, Requires = { "Fountain" } })
	end
end

-- ===== ARMAS (permanentes, ficam depois do rebirth) ===========================
-- Kind: Melee (golpe em área à frente) | Ranged (projétil)
local WEAPON_PRICES = { 270000000000, 540000000000, 8400000000000, 230000000000000, 280000000000000, 7300000000000000, 8400000000000000, 210000000000000000, 230000000000000000, 5700000000000000000, 140000000000000000000 }
Config.Weapons = {
	{ Id = "Chinelo", Name = "Nonna's Slipper", Icon = "👡", Rebirth = 1,
		Kind = "Melee", Damage = 15, Cooldown = 0.6, Range = 7, Knockback = 45, Color = Color3.fromRGB(80, 160, 255),
		Description = "A classic. One smack and the brainrot gets back in line." },
	{ Id = "Baguete", Name = "Battle Baguette", Icon = "🥖", Rebirth = 1,
		Kind = "Melee", Damage = 22, Cooldown = 0.75, Range = 9, Knockback = 60, Color = Color3.fromRGB(230, 170, 90),
		Description = "Crunchy outside, devastating inside." },
	{ Id = "Bazuca", Name = "Spaghetti Bazooka", Icon = "🍝", Rebirth = 2,
		Kind = "Ranged", Damage = 30, Cooldown = 1.1, Range = 140, Speed = 110, Knockback = 70, Splash = 7, Color = Color3.fromRGB(150, 70, 40),
		Description = "Fires exploding meatballs. Mamma mia!" },
	{ Id = "Varinha", Name = "Mozzarella Wand", Icon = "🧀", Rebirth = 3,
		Kind = "Ranged", Damage = 20, Cooldown = 0.35, Range = 160, Speed = 170, Knockback = 25, Color = Color3.fromRGB(255, 245, 200),
		Description = "Rapid bursts of melted cheese." },
	{ Id = "Martelo", Name = "Watermelon Hammer", Icon = "🍉", Rebirth = 4,
		Kind = "Melee", Damage = 45, Cooldown = 1.4, Range = 12, Knockback = 120, Splash = 12, Color = Color3.fromRGB(80, 200, 90),
		Description = "Area smash that sprays seeds everywhere." },
	{ Id = "Cetro", Name = "Supreme Tomato Scepter", Icon = "🍅", Rebirth = 5,
		Kind = "Ranged", Damage = 40, Cooldown = 0.8, Range = 200, Speed = 140, Knockback = 90, Splash = 10, Color = Color3.fromRGB(255, 60, 60),
		Description = "Exploding royal tomatoes. Kneel." },
	{ Id = "Pepino", Name = "Cucumber Katana", Icon = "🥒", Rebirth = 6,
		Kind = "Melee", Damage = 50, Cooldown = 0.5, Range = 10, Knockback = 70, Color = Color3.fromRGB(90, 200, 90),
		Description = "A refreshing ninja slice. Fast and sharp." },
	{ Id = "Pimenta", Name = "Pepper Blaster", Icon = "🌶️", Rebirth = 7,
		Kind = "Ranged", Damage = 35, Cooldown = 0.25, Range = 170, Speed = 190, Knockback = 30, Color = Color3.fromRGB(255, 70, 40),
		Description = "A machine gun of spicy peppers." },
	{ Id = "Ioio", Name = "Donut Yo-Yo", Icon = "🍩", Rebirth = 8,
		Kind = "Melee", Damage = 60, Cooldown = 0.9, Range = 14, Knockback = 110, Splash = 14, Color = Color3.fromRGB(255, 130, 200),
		Description = "Spins around and launches everyone away." },
	{ Id = "Arco", Name = "Banana Bow", Icon = "🍌", Rebirth = 9,
		Kind = "Ranged", Damage = 70, Cooldown = 0.9, Range = 240, Speed = 220, Knockback = 100, Splash = 8, Color = Color3.fromRGB(255, 225, 60),
		Description = "Banana arrows with bandit-level aim." },
	{ Id = "MarteloGnocco", Name = "Hammer of the Great Gnocco", Icon = "🔨", Rebirth = 10,
		Kind = "Melee", Damage = 100, Cooldown = 1.2, Range = 16, Knockback = 180, Splash = 18, Color = Color3.fromRGB(255, 215, 80),
		Description = "The supreme weapon. A pasta earthquake." },
}
for i, w in ipairs(Config.Weapons) do w.Price = WEAPON_PRICES[i] end

-- ===== SKINS (permanentes) ====================================================
local SKIN_PRICES = { 2900000000, 220000000000, 430000000000, 6700000000000, 180000000000000, 230000000000000, 5800000000000000, 6700000000000000, 170000000000000000, 190000000000000000, 4600000000000000000, 110000000000000000000 }
Config.Skins = {
	{ Id = "Cerebro", Name = "Walking Brain", Icon = "🧠", Rebirth = 0, Description = "A giant pink brain instead of a head." },
	{ Id = "Banana", Name = "Bananito Bandito", Icon = "🍌", Rebirth = 1, Description = "Banana costume with a bandit mask." },
	{ Id = "Pinguim", Name = "Pinguino Spaghettino", Icon = "🐧", Rebirth = 1, Description = "Penguin with spaghetti hair and a meatball." },
	{ Id = "Geladeira", Name = "Frigorifero Cantante", Icon = "🧊", Rebirth = 2, Description = "Singing fridge head with a microphone." },
	{ Id = "Foguete", Name = "Mozzarello Razzetto", Icon = "🚀", Rebirth = 3, Description = "Mozzarella with a fire-spitting jetpack." },
	{ Id = "Melancia", Name = "Cocomero Colosso", Icon = "🍉", Rebirth = 4, Description = "Buff watermelon body with a red headband." },
	{ Id = "Tomate", Name = "Il Supremo Pomodoro", Icon = "🍅", Rebirth = 5, Description = "Royal tomato with crown, halo and a rainbow aura." },
	{ Id = "Torradeira", Name = "Toastino Tornado", Icon = "🍞", Rebirth = 6, Description = "Toaster head with popping toast." },
	{ Id = "Gato", Name = "Gattino Galattico", Icon = "🐱", Rebirth = 7, Description = "Cat ears, galaxy eyes and a ring of stars." },
	{ Id = "Abacaxi", Name = "Ananasso Astronauta", Icon = "🍍", Rebirth = 8, Description = "Astronaut pineapple with a glass helmet." },
	{ Id = "Mumia", Name = "Mummietto Maccherone", Icon = "🧟", Rebirth = 9, Description = "A mummy wrapped in pasta from the ancient temple." },
	{ Id = "Gnocco", Name = "Il Grande Gnocco", Icon = "🥔", Rebirth = 10, Description = "The emperor of pasta: laurel crown and halo." },
}
for i, s in ipairs(Config.Skins) do s.Price = SKIN_PRICES[i] end
Config.WeaponsById, Config.SkinsById = {}, {}
for _, w in ipairs(Config.Weapons) do Config.WeaponsById[w.Id] = w end
for _, s in ipairs(Config.Skins) do Config.SkinsById[s.Id] = s end
Config.SafeZoneRadius = 45   -- praça central sem dano

-- Bordões dos brainrots (balões de fala aleatórios na base) -------------
Config.Catchphrases = {
	Bananito    = { "Bananito bandito, rubato tutto! 💰", "Shhh... nobody saw anything 🤫", "Banana is life, stealing is art" },
	Pinguino    = { "Spaghetti al ghiaccio! 🍝", "Mamma mia, it's cold!", "Who wants a meatball? 🐧" },
	Frigorifero = { "🎵 La la la FRIDGEEEE 🎵", "Close the door, the heat's getting in!", "3-octave high note, trust me" },
	Toastino    = { "TOAST TOAST TORNADOOO 🌪️", "Buttered bread is my fuel", "I'm spinning and I can't stop" },
	Mozzarello  = { "Liftoff in 3, 2, cheese! 🚀", "Orbital mozzarella, baby", "Next stop: the parmesan Moon" },
	Ananasso    = { "Houston, we have a pineapple 🍍", "Zero gravity, full flavor", "Pineapple on pizza? Yes. Fight me." },
	Cocomero    = { "SWOLE WATERMELON 💪", "Today is seed day", "No pain, no juice!" },
	Gattino     = { "Meow... from across the galaxy 🌌", "I knocked a planet off the table", "I'm the cat who saw the end of the universe" },
	Pomodoro    = { "KNEEL BEFORE THE TOMATO 🍅👑", "I am the supreme sauce", "Ketchup? How dare you." },
	Biscottino  = { "One, two, CRUNCH! 🥊", "Dunk me in milk and I get stronger", "Steel cookie, baby" },
	Limoncello  = { "Lemon throw in 3, 2... 🍋", "Sour? Me? Never", "Victory lemonade!" },
	Ciambella   = { "SPIN SPIN DONUUUT 🍩", "I'm dizzy from spinning", "Sprinkles are my shield" },
	Pizzetta    = { "Arrr! Where's the pepperoni treasure? 🏴‍☠️", "Pineapple overboard!", "Captain's slice" },
	Gelatino    = { "Stay cool, bro 😎🍦", "I melt hearts and in the sun", "Premium cone" },
	Formaggio   = { "Boooo... I'm the cheese from beyond 👻", "I have holes in my soul", "I haunt pizzerias" },
	Melanzana   = { "Silence... I'm invisible 🥷", "Purple shadow strike", "Eggplant isn't a veggie, it's a lifestyle" },
	Avocado     = { "My pit is a galaxy 🌌", "Toast? Only the fancy kind", "Astral avocado, nice to meet you" },
	Ravioli     = { "HIS MAJESTY RAVIOLI 👑", "Stuffed with power", "Bow to the white sauce" },
	Broccolo    = { "BEEP BOOP, VITAMINS 🤖", "Green system online", "Eat your veggies, humans" },
	Cocco       = { "Coconut outside, croc inside 🐊", "Coconut water? That's my blood", "SNAP SNAP" },
	Funghetto   = { "ZAP! Mushroom shock ⚡", "I grow in the dark and shine on stage", "Shimeji lightning" },
	Peperone    = { "WHY IS IT SO HOT 🔥🔥", "Too spicy to ignore", "Pepper in the eye? Refreshing" },
	Uovo        = { "Abducting your toast 🛸", "White outside, alien yolk", "I came from another henhouse" },
	Panino      = { "Heavenly filling 😇🥪", "Angel bread, divine ham", "Blessed bite" },
	Carota      = { "Carrot at light speed ☄️", "I leave an orange trail in the sky", "Onward, always crunchy" },
	Fragola     = { "Reborn from the juice! 🔥🍓", "Strawberry-flavored phoenix", "Sweet and legendary" },
	Mirtillo    = { "Abracadabra, blueberry! 🧙", "Purple vitamin spell", "Raspberry wand? Amateur stuff" },
	Cipolla     = { "I have layers... cosmic ones 🧅", "If you cry, it means I'm strong", "Onion of the multiverse" },
	Torta       = { "HAPPY BIRTHDAY TO ME 🎂", "I'm made of 100 layers", "Eternal birthday" },
	Gnocco      = { "THE GREAT GNOCCO HAS ARRIVED 👑🥔", "Emperor of pasta", "Potato? Show respect, I'm gnocchi" },
	Dadino      = { "Rolled a 7... again 🎲", "Luck is my best friend" },
	Cartino     = { "Joker up my sleeve, always 🃏", "Bluff? I never bluff... maybe" },
	Slotto      = { "TRIPLE BRAINROT! 🎰", "Pull the lever, go on!" },
	Moneta      = { "Heads or tails? Both! 💰", "I'm worth more than you" },
	Rouletta    = { "Spin, spin, spin 🎡", "Red or black? Pink!" },
	Jackpottino = { "JACKPOOOOT 👑💰", "The casino is mine" },
	Mangolino   = { "Ooh ooh ah ah 🥭", "Ripe mango is power" },
	Gorillone   = { "Gorilla jelly 🦍", "I beat my chest and wobble all over" },
	Pappagallo  = { "Pizza! Pizza! Pizza! 🦜", "I repeat every brainrot" },
	Tucanello   = { "Colorful beak, colorful life 🐦", "Flying tutti-frutti" },
	Serpentina  = { "Sssssspicy salsa 🐍", "I dance with no legs" },
	Leone       = { "I AM THE KING OF THE JUNGLE 🦁🍋", "Sour roar" },
	Lunetta     = { "Full moon, full pockets 🌙", "Gravity? Never heard of it" },
	Robottino   = { "BEEP. RIZZ. LOADED 🤖", "Charm system 100%" },
	Marziano    = { "Take me to your melon 👽", "I came from Mars for the memes" },
	Cometino    = { "Space coffee, infinite energy ☕", "Espresso at light speed" },
	Satellino   = { "Broadcasting spaghetti 🛰️", "Strong signal, strong sauce" },
	Galassio    = { "Galaxy ice cream 🌌🍦", "I only melt in black holes" },
	Mummietto   = { "Wrapped in pasta since 3000 BC 🧟", "Uuuuhh... pasta" },
	Faraone     = { "Kneel before the fennel 🌿", "Vegetarian pharaoh" },
	Sfingetta   = { "Answer my riddle 🍧", "What's icy and wise? Me" },
	Arancino    = { "Guardian of the sacred arancino 🍊", "Orange is the color of power" },
	Oracolo     = { "I foresee... more brainrot 🔮", "The future has olives" },
	Pistacchio  = { "THE PISTACHIO PHARAOH 🥜👑", "Green is the color of royalty" },
	Dolcetto    = { "Divine sweetie 🧁", "Heavenly sprinkles" },
	Insalata    = { "Emperor of salad 🥗", "Green leaves, clear orders" },
	Ricotta     = { "The queen has arrived 👸", "Royal ricotta, creamy and supreme" },
	Tiramisu    = { "Pick me up, I'm a titan 🍰", "Coffee, cocoa and power" },
	Cervellone  = { "I THINK, THEREFORE I BRAINROT 🧠", "A brain the size of the universe" },
	Ultimo      = { "I AM THE LAST BRAINROT 👑", "After me, only the void" },
}

-- Índice por Id
Config.ItemsById = {}
for index, item in ipairs(Config.Items) do
	item.Order = index
	Config.ItemsById[item.Id] = item
end

return Config
