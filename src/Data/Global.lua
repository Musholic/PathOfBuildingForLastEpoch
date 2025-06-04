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
	PHYSICAL = "^xFCDFC0",
	FIRE = "^xEC4D29",
	COLD = "^x17BBEA",
	LIGHTNING = "^x286AFF",
	VOID = "^x7E1BC5",
	POISON = "^x1DA546",
	NECROTIC = "^x2DBF9C",
	CHAOS = "^x2dbf9c",
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

DamageTypes = {
	"Physical",
	"Lightning",
	"Cold",
	"Fire",
	"Void",
	"Necrotic",
	"Poison"
}

Attributes = {"Str","Dex","Int","Vit","Att"}
LongAttributes = {"Strength","Dexterity","Intelligence","Vitality","Attunement"}

DamageTypesColored = {
	colorCodes.PHYSICAL.."Physical",
	colorCodes.LIGHTNING .. "Lightning",
	colorCodes.COLD .. "Cold",
	colorCodes.FIRE.."Fire",
	colorCodes.VOID.."Void",
	colorCodes.NECROTIC.."Necrotic",
	colorCodes.POISON.."Poison"
}

DamageSourceTypes = { "Spell", "Melee", "Throwing", "Bow", "Dot"}

-- Active skill types
SkillType = {
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
	Dot = 4096,
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
}

SkillType.Attack = SkillType.Melee + SkillType.Throwing + SkillType.Bow
SkillType.Cast = SkillType.Spell

-- TODO: Not supported yet
SkillType.Unsupported = SkillType.Ailment * 2
SkillType.Wand = SkillType.Unsupported
SkillType.Sword = SkillType.Unsupported
SkillType.Axe = SkillType.Unsupported
SkillType.Dagger = SkillType.Unsupported
SkillType.Mace = SkillType.Unsupported
SkillType.Staff = SkillType.Unsupported
SkillType.Unarmed = SkillType.Unsupported
SkillType.Weapon = SkillType.Unsupported
SkillType.Weapon1H = SkillType.Unsupported
SkillType.Weapon2H = SkillType.Unsupported
SkillType.WeaponRanged = SkillType.Unsupported
SkillType.WeaponMelee = SkillType.Unsupported
SkillType.WeaponMask = SkillType.Unsupported
SkillType.Ignite = SkillType.Unsupported
SkillType.Area = SkillType.Unsupported
SkillType.Projectile = SkillType.Unsupported

for _, damageType in ipairs(DamageTypes) do
	SkillType[damageType .. "Dot"] = SkillType.Unsupported
end

ModFlag = SkillType

KeywordFlag = copyTable(SkillType)

---The default behavior for KeywordFlags is to match *any* of the specified flags.
---Including the "MatchAll" flag when creating a mod will cause *all* flags to be matched rather than any.
KeywordFlag.MatchAll = SkillType.Unsupported * 2

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

GlobalCache = {
	cachedData = { MAIN = {}, CALCS = {}, CALCULATOR = {}, CACHE = {}, },
	deleteGroup = { },
	excludeFullDpsList = { },
	useFullDPS = false,
	numActiveSkillInFullDPS = 0
}

