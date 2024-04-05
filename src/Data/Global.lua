-- Path of Building
--
-- Module: Global
-- Global constants
--

colorCodes = {
	NORMAL = "^xC8C8C8",
	MAGIC = "^x8888FF",
	RARE = "^xFFFF77",
	UNIQUE = "^xAF6025",
	RELIC = "^x60C060",
	GEM = "^x1AA29B",
	PROPHECY = "^xB54BFF",
	CURRENCY = "^xAA9E82",
	CRAFTED = "^xB8DAF1",
	CUSTOM = "^x5CF0BB",
	SOURCE = "^x88FFFF",
	UNSUPPORTED = "^xF05050",
	WARNING = "^xFF9922",
	TIP = "^x80A080",
	FIRE = "^xB97123",
	COLD = "^x3F6DB3",
	LIGHTNING = "^xADAA47",
	CHAOS = "^xD02090",
	POSITIVE = "^x33FF77",
	NEGATIVE = "^xDD0022",
	HIGHLIGHT ="^xFF0000",
	OFFENCE = "^xE07030",
	DEFENCE = "^x8080E0",
	SCION = "^xFFF0F0",
	MARAUDER = "^xE05030",
	RANGER = "^x70FF70",
	WITCH = "^x7070FF",
	DUELIST = "^xE0E070",
	TEMPLAR = "^xC040FF",
	SHADOW = "^x30C0D0",
	MAINHAND = "^x50FF50",
	MAINHANDBG = "^x071907",
	OFFHAND = "^xB7B7FF",
	OFFHANDBG = "^x070719",
	SHAPER = "^x55BBFF",
	ELDER = "^xAA77CC",
	FRACTURED = "^xA29160",
	ADJUDICATOR = "^xE9F831",
	BASILISK = "^x00CB3A",
	CRUSADER = "^x2946FC",
	EYRIE = "^xAAB7B8",
	CLEANSING = "^xF24141",
	TANGLE = "^x038C8C",
	CHILLBG = "^x151e26",
	FREEZEBG = "^x0c262b",
	SHOCKBG = "^x191732",
	SCORCHBG = "^x270b00",
	BRITTLEBG = "^x00122b",
	SAPBG = "^x261500",
	SCOURGE = "^xFF6E25",
	CRUCIBLE = "^xFFA500",
}
colorCodes.STRENGTH = colorCodes.MARAUDER
colorCodes.DEXTERITY = colorCodes.RANGER
colorCodes.INTELLIGENCE = colorCodes.WITCH

colorCodes.LIFE = colorCodes.MARAUDER
colorCodes.MANA = colorCodes.WITCH
colorCodes.ES = colorCodes.SOURCE
colorCodes.WARD = colorCodes.RARE
colorCodes.ARMOUR = colorCodes.NORMAL
colorCodes.EVASION = colorCodes.POSITIVE
colorCodes.RAGE = colorCodes.WARNING
colorCodes.PHYS = colorCodes.NORMAL

defaultColorCodes = copyTable(colorCodes)
function updateColorCode(code, color)
 	if colorCodes[code] then
		colorCodes[code] = color:gsub("^0", "^")
		if code == "HIGHLIGHT" then
			rgbColor = hexToRGB(color)
		end
	end
end

function hexToRGB(hex)
	hex = hex:gsub("0x", "") -- Remove "0x" prefix
	hex = hex:gsub("#","") -- Remove '#' if present
	if #hex ~= 6 then
		return nil
	end
	local r = (tonumber(hex:sub(1, 2), 16)) / 255
	local g = (tonumber(hex:sub(3, 4), 16)) / 255
	local b = (tonumber(hex:sub(5, 6), 16)) / 255
	return {r, g, b}
end

ModFlag = { }
-- Damage modes
ModFlag.Attack =	 0x00000001
ModFlag.Spell =		 0x00000002
ModFlag.Hit =		 0x00000004
ModFlag.Dot =		 0x00000008
ModFlag.Cast =		 0x00000010
-- Damage sources
ModFlag.Melee =		 0x00000100
ModFlag.Area =		 0x00000200
ModFlag.Projectile = 0x00000400
ModFlag.SourceMask = 0x00000600
ModFlag.Ailment =	 0x00000800
ModFlag.MeleeHit =	 0x00001000
ModFlag.Weapon =	 0x00002000
-- Weapon types
ModFlag.Axe =		 0x00010000
ModFlag.Bow =		 0x00020000
ModFlag.Claw =		 0x00040000
ModFlag.Dagger =	 0x00080000
ModFlag.Mace =		 0x00100000
ModFlag.Staff =		 0x00200000
ModFlag.Sword =		 0x00400000
ModFlag.Wand =		 0x00800000
ModFlag.Unarmed =	 0x01000000
ModFlag.Fishing =	 0x02000000
-- Weapon classes
ModFlag.WeaponMelee =0x04000000
ModFlag.WeaponRanged=0x08000000
ModFlag.Weapon1H =	 0x10000000
ModFlag.Weapon2H =	 0x20000000
ModFlag.WeaponMask = 0x2FFF0000

KeywordFlag = { }
-- Skill keywords
KeywordFlag.Aura =		0x00000001
KeywordFlag.Curse =		0x00000002
KeywordFlag.Warcry =	0x00000004
KeywordFlag.Movement =	0x00000008
KeywordFlag.Physical =	0x00000010
KeywordFlag.Fire =		0x00000020
KeywordFlag.Cold =		0x00000040
KeywordFlag.Lightning =	0x00000080
KeywordFlag.Chaos =		0x00000100
KeywordFlag.Vaal =		0x00000200
KeywordFlag.Bow =		0x00000400
-- Skill types
KeywordFlag.Trap =		0x00001000
KeywordFlag.Mine =		0x00002000
KeywordFlag.Totem =		0x00004000
KeywordFlag.Minion =	0x00008000
KeywordFlag.Attack =	0x00010000
KeywordFlag.Spell =		0x00020000
KeywordFlag.Hit =		0x00040000
KeywordFlag.Ailment =	0x00080000
KeywordFlag.Brand =		0x00100000
-- Other effects
KeywordFlag.Poison =	0x00200000
KeywordFlag.Bleed =		0x00400000
KeywordFlag.Ignite =	0x00800000
-- Damage over Time types
KeywordFlag.PhysicalDot=0x01000000
KeywordFlag.LightningDot=0x02000000
KeywordFlag.ColdDot =	0x04000000
KeywordFlag.FireDot =	0x08000000
KeywordFlag.ChaosDot =	0x10000000
---The default behavior for KeywordFlags is to match *any* of the specified flags.
---Including the "MatchAll" flag when creating a mod will cause *all* flags to be matched rather than any.
KeywordFlag.MatchAll =	0x40000000

-- Helper function to compare KeywordFlags
local band = bit.band
local MatchAllMask = bit.bnot(KeywordFlag.MatchAll)
---@param keywordFlags number The KeywordFlags to be compared to.
---@param modKeywordFlags number The KeywordFlags stored in the mod.
---@return boolean Whether the KeywordFlags in the mod are satisfied.
function MatchKeywordFlags(keywordFlags, modKeywordFlags)
	local matchAll = band(modKeywordFlags, KeywordFlag.MatchAll) ~= 0
	modKeywordFlags = band(modKeywordFlags, MatchAllMask)
	keywordFlags = band(keywordFlags, MatchAllMask)
	if matchAll then
		return band(keywordFlags, modKeywordFlags) == modKeywordFlags
	end
	return modKeywordFlags == 0 or band(keywordFlags, modKeywordFlags) ~= 0
end

-- Active skill types
SkillType = {
	None = 0,
	Physical = 1,
	Lightning = 2,
	Cold = 4,
	Fire = 8,
	Void = 16,
	Necrotic = 32,
	Poison = 64,
	Elemental = 128,
	Spell = 256,
	Melee = 512,
	Throwing = 1024,
	Bow = 2048,
	DoT = 4096,
	Minion = 8192,
	Totem = 16384,
	PetResisted = 32768,
	Potion = 65536,
	Buff = 131072,
	Channelling = 262144,
	Transform = 524288,
	LowLife = 1048576,
	HighLife = 2097152,
	FullLife = 4194304,
	Hit = 8388608,
	Curse = 16777216,
	Ailment = 33554432,
	Crit_deprecated = 67108864,
	Kill_deprecated = 134217728,
	Die_deprecated = 268435456
}

GlobalCache = { 
	cachedData = { MAIN = {}, CALCS = {}, CALCULATOR = {}, CACHE = {}, },
	deleteGroup = { },
	excludeFullDpsList = { },
	noCache = nil,
	useFullDPS = false,
	numActiveSkillInFullDPS = 0,
}

