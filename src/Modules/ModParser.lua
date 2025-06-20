-- Path of Building
--
-- Module: Mod Parser for 3.0
-- Parser function for modifier names
--
local pairs = pairs
local ipairs = ipairs
local t_insert = table.insert
local band = bit.band
local bor = bit.bor
local bnot = bit.bnot
local m_huge = math.huge
local function firstToUpper(str)
	return (str:gsub("^%l", string.upper))
end

-- List of modifier forms
local formList = {
	["^([%+%-]?[%d%.]+)%% increased"] = "INC",
	["^([%+%-]?[%d%.]+)%% reduced"] = "RED",
	["^([%+%-]?[%d%.]+)%% more"] = "MORE",
	["^([%+%-]?[%d%.]+)%% less"] = "LESS",
	["^(%d+)%% faster"] = "INC",
	["^(%d+)%% slower"] = "RED",
	["^([%+%-]?[%d%.]+)%%?"] = "BASE",
	["^([%+%-][%d%.]+)%%? to"] = "BASE",
	["^([%+%-]?[%d%.]+)%%? of"] = "BASE",
	["^([%+%-][%d%.]+)%%? base"] = "BASE",
	["^([%+%-]?[%d%.]+)%%? additional"] = "BASE",
	["^you gain ([%d%.]+)"] = "GAIN",
	["^gains? ([%d%.]+)%% of"] = "GAIN",
	["^gain ([%d%.]+)"] = "GAIN",
	["^gain %+(%d+)%% to"] = "GAIN",
	["^you lose ([%d%.]+)"] = "LOSE",
	["^loses? ([%d%.]+)%% of"] = "LOSE",
	["^lose ([%d%.]+)"] = "LOSE",
	["^lose %+(%d+)%% to"] = "LOSE",
	["^(%d+)"] = "BASE",
	["^([%+%-]?%d+)%% chance"] = "CHANCE",
	["^([%+%-]?%d+)%% (%a+) chance"] = "CHANCE",
	["^([%+%-]?%d+)%% chance to gain "] = "FLAG",
	["^([%+%-]?%d+)%% additional chance"] = "CHANCE",
	["^you have "] = "FLAG",
	["^have "] = "FLAG",
	["^you are "] = "FLAG",
	["^are "] = "FLAG",
	["^gain "] = "FLAG",
	["^you gain "] = "FLAG",
}

-- Map of modifier names
local modNameList = {
	-- Attributes
	["all attributes"] = Attributes,
	-- Life/mana
	["health"] = "Life",
	["health regen"] = "LifeRegen",
	["health regeneration"] = "LifeRegen",
	["maximum health"] = "Life",
	["mana"] = "Mana",
	["maximum mana"] = "Mana",
	["mana regeneration"] = "ManaRegen",
	["mana cost"] = "ManaCost",
	-- Primary defences
	["armour"] = "Armour",
	["armor"] = "Armour",
	["dodge rating"] = "Evasion",
	["ward"] = "Ward",
	-- Resistances
	["elemental resistance"] = "ElementalResist",
	["elemental resistances"] = "ElementalResist",
	["all resistances"] = { "ElementalResist", "PhysicalResist", "PoisonResist", "NecroticResist", "VoidResist" },
	-- Damage taken
	["damage taken"] = "DamageTaken",
	["damage over time taken"] = "DamageTakenOverTime",
	["elemental damage taken"] = "ElementalDamageTaken",
	["elemental damage taken over time"] = "ElementalDamageTakenOverTime",
	-- Other defences
	["block chance"] = "BlockChance",
	["health gained on block"] = "LifeOnBlock",
	["health gain on block"] = "LifeOnBlock",
	["mana gained on block"] = "ManaOnBlock",
	["mana gain on block"] = "ManaOnBlock",
	["ward gained on block"] = "WardOnBlock",
	["ward gain on block"] = "WardOnBlock",
	-- Stun/knockback modifiers
	["stun duration on you"] = "StunDuration",
	["stun duration"] = "EnemyStunDuration",
	["knockback distance"] = "EnemyKnockbackDistance",
	-- Auras/curses/buffs
	["buff effect"] = "BuffEffect",
	-- On hit/kill/leech effects
	["health gain on kill"] = "LifeOnKill",
	["health gain on hit"] = { "LifeOnHit", flags = ModFlag.Hit },
	-- Projectile modifiers
	["extra projectiles"] = "ProjectileCount",
	["projectiles"] = "ProjectileCount",
	["projectile speed"] = "ProjectileSpeed",
	-- Totem/trap/mine/brand modifiers
	["totem duration"] = "TotemDuration",
	-- Other skill modifiers
	["radius"] = "AreaOfEffect",
	["area"] = "AreaOfEffect",
	["area of effect"] = "AreaOfEffect",
	["duration"] = "Duration",
	["cooldown duration"] = "CooldownRecovery",
	["cooldown recovery"] = "CooldownRecovery",
	["cooldown recovery speed"] = "CooldownRecovery",
	["melee range"] = "MeleeWeaponRange",
	["to deal double damage"] = "DoubleDamageChance",
	-- Basic damage types
	["damage"] = "Damage",
	["elemental damage"] = {"FireDamage", "ColdDamage", "LightningDamage"},
	-- Other damage forms
	["melee damage"] = { "Damage", flags = ModFlag.Melee },
	["bow damage"] = { "Damage", flags = bor(ModFlag.Bow, ModFlag.Hit) },
	["throwing damage"] = { "Damage", flags = bor(ModFlag.Throwing, ModFlag.Hit) },
	["damage over time"] = { "Damage", flags = ModFlag.Dot },
	-- Crit/accuracy/speed modifiers
	["crit chance"] = "CritChance",
	["critical chance"] = "CritChance",
	["critical strike chance"] = "CritChance",
	["critical strike multiplier"] = "CritMultiplier",
	["critical multiplier"] = "CritMultiplier",
	["accuracy"] = "Accuracy",
	["minion accuracy"] = { "Accuracy", addToMinion = true },
	["attack speed"] = { "Speed", flags = ModFlag.Attack },
	["cast speed"] = { "Speed", flags = ModFlag.Cast },
	["attack and cast speed"] = "Speed",
	["freeze duration"] = "EnemyFreezeDuration",
	-- Misc modifiers
	["movespeed"] = "MovementSpeed",
	["movement speed"] = "MovementSpeed",
}

for i,stat in ipairs(LongAttributes) do
	modNameList[stat:lower()] = Attributes[i]
end

for skillId, skill in pairs(data.skills) do
	modNameList["to " .. skill.name:lower()] = {"ChanceToTriggerOnHit_"..skillId, flags = ModFlag.Hit}
	modNameList[skill.name:lower() .. " chance"] = {"ChanceToTriggerOnHit_"..skillId, flags = ModFlag.Hit}
	if skill.altName then
		modNameList[skill.altName:lower() .. " chance"] = {"ChanceToTriggerOnHit_"..skillId, flags = ModFlag.Hit}
	end
end

for _, damageType in ipairs(DamageTypes) do
	modNameList[damageType:lower() .. " penetration"] = damageType .. "Penetration"
	modNameList[damageType:lower() .. " damage"] = damageType .. "Damage"
	for _, damageSourceType in ipairs(DamageSourceTypes) do
		modNameList[damageSourceType:lower() .. " " .. damageType:lower() .. " damage"] = { damageType .. "Damage", flags = ModFlag[damageSourceType] }
	end
	modNameList[damageType:lower() .. " resistance"] = damageType .. "Resist"
	modNameList[damageType:lower() .. " damage taken"] = damageType .. "DamageTaken"
	modNameList[damageType:lower() .. " damage over time taken"] = damageType .. "DamageTakenOverTime"
	modNameList[damageType:lower() .. " damage over time"] = { damageType .. "Damage", flags = ModFlag.Dot + ModFlag[damageType] }
end

modNameList["penetration"] = "Penetration"

-- List of modifier flags
local modFlagList = {
	-- Skill types
	["elemental"] = { keywordFlags = bor(KeywordFlag.Fire, KeywordFlag.Cold, KeywordFlag.Lightning) },
	["spell"] = { flags = ModFlag.Spell },
	["melee"] = { flags = ModFlag.Melee },
	["on melee hit"] = { flags = bor(ModFlag.Melee, ModFlag.Hit) },
	["on hit"] = { flags = ModFlag.Hit },
	["minion skills"] = { tag = { type = "SkillType", skillType = SkillType.Minion } },
	["with elemental spells"] = { keywordFlags = bor(KeywordFlag.Lightning, KeywordFlag.Cold, KeywordFlag.Fire) },
	["minion"] = { addToMinion = true },
	-- Other
	["global"] = { tag = { type = "Global" } },
}

for _, damageType in ipairs(DamageTypes) do
	modFlagList["on " .. damageType:lower() .. " hit"] = { keywordFlags = KeywordFlag[damageType], flags = ModFlag.Hit }
	modFlagList["with " .. damageType:lower() .. " skills"] = { keywordFlags = KeywordFlag[damageType] }
end

-- List of modifier flags/tags that appear at the start of a line
local preFlagList = {
}

-- List of modifier tags
local modTagList = {
	[". this effect is doubled if you have (%d+) or more maximum mana."] = function(num) return { tag = { type = "StatThreshold", stat = "Mana", threshold = num, mult = 2 } } end,
	["for (%d+) seconds"] = { },
	[" on critical strike"] = { tag = { type = "Condition", var = "CriticalStrike" } },
	["from critical strikes"] = { tag = { type = "Condition", var = "CriticalStrike" } },
	-- Multipliers
	["per level"] = { tag = { type = "Multiplier", var = "Level" } },
	-- TODO: refactor all sword use
	-- Per stat
	["per (%d+) total attributes"] = function(num) return { tag = { type = "PerStat", statList = Attributes, div = num } } end,
	["per (%d+) maximum mana"] = function(num) return { tag = { type = "PerStat", stat = "Mana", div = num } } end,
	["per (%d+)%% block chance"] = function(num) return { tag = { type = "PerStat", stat = "BlockChance", div = num } } end,
	["per totem"] = { tag = { type = "PerStat", stat = "TotemsSummoned" } },
	-- Slot conditions
	["while dual wielding"] = { tag = { type = "Condition", var = "DualWielding" } },
	["while wielding a two handed melee weapon"] = { tagList = { { type = "Condition", var = "UsingTwoHandedWeapon" }, { type = "Condition", var = "UsingMeleeWeapon" } } },
	["while unarmed"] = { tag = { type = "Condition", var = "Unarmed" } },
	["while moving"] = { tag = { type = "Condition", var = "Moving" } },
	["while channelling"] = { tag = { type = "Condition", var = "Channelling" } },
	["while leeching"] = { tag = { type = "Condition", var = "Leeching" } },
	["while frozen"] = { tag = { type = "Condition", var = "Frozen" } },
	["while cursed"] = { tag = { type = "Condition", var = "Cursed" } },
	["if you[' ]h?a?ve dealt a critical strike recently"] = { tag = { type = "Condition", var = "CritRecently" } },
	["on kill"] = { tag = { type = "Condition", var = "KilledRecently" } },
	["on melee kill"] = { flags = ModFlag.WeaponMelee, tag = { type = "Condition", var = "KilledRecently" } },
	["when you kill an enemy"] = { tag = { type = "Condition", var = "KilledRecently" } },
	["if you[' ]h?a?ve stunned an enemy recently"] = { tag = { type = "Condition", var = "StunnedEnemyRecently" } },
	["if you[' ]h?a?ve been hit recently"] = { tag = { type = "Condition", var = "BeenHitRecently" } },
	["if you have ?n[o']t been hit recently"] = { tag = { type = "Condition", var = "BeenHitRecently", neg = true } },
	["when you summon a totem"] = { tag = { type = "Condition", var = "SummonedTotemRecently" } },
	-- Enemy status conditions
	["against poisoned enemies"] = { tag = { type = "ActorCondition", actor = "enemy", var = "Poisoned" } },
	["to poisoned enemies"] = { tag = { type = "ActorCondition", actor = "enemy", var = "Poisoned" } },
	["against blinded enemies"] = { tag = { type = "ActorCondition", actor = "enemy", var = "Blinded" } },
	["against ignited enemies"] = { tag = { type = "ActorCondition", actor = "enemy", var = "Ignited" } },
	["to ignited enemies"] = { tag = { type = "ActorCondition", actor = "enemy", var = "Ignited" } },
	["against shocked enemies"] = { tag = { type = "ActorCondition", actor = "enemy", var = "Shocked" } },
	["to shocked enemies"] = { tag = { type = "ActorCondition", actor = "enemy", var = "Shocked" } },
	["against frozen enemies"] = { tag = { type = "ActorCondition", actor = "enemy", var = "Frozen" } },
	["to frozen enemies"] = { tag = { type = "ActorCondition", actor = "enemy", var = "Frozen" } },
	["against chilled enemies"] = { tag = { type = "ActorCondition", actor = "enemy", var = "Chilled" } },
	["to chilled enemies"] = { tag = { type = "ActorCondition", actor = "enemy", var = "Chilled" } },
	["against chilled or frozen enemies"] = { tag = { type = "ActorCondition", actor = "enemy", varList = { "Chilled","Frozen" } } },
}

for i,stat in ipairs(LongAttributes) do
	modTagList["per " .. stat:lower()] = { tag = { type = "PerStat", stat = Attributes[i] } }
	modTagList["per player " .. stat:lower()] = { tag = { type = "PerStat", stat = Attributes[i], actor = "parent" } }
	modTagList["per (%d+) " .. stat:lower()] = function(num) return { tag = { type = "PerStat", stat = Attributes[i], div = num } } end
	modTagList["w?h?i[lf]e? you have at least (%d+) " .. stat:lower()] = function(num) return { tag = { type = "StatThreshold", stat = Attributes[i], threshold = num } } end
end
for _, weapon in ipairs(DamageSourceWeapons) do
	modTagList["with an? " .. weapon:lower()] = { tag = { type = "Condition", var = "Using" .. weapon } }
	modTagList["while wielding a " .. weapon:lower()] = { tag = { type = "Condition", var = "Using" .. weapon } }
	modTagList["per equipped " .. weapon:lower()] = { tag = { type = "Multiplier", var = weapon .. "Item" } }
	modTagList["per " .. weapon:lower()] = { tag = { type = "Multiplier", var = weapon .. "Item" } }
end

local mod = modLib.createMod
local function flag(name, ...)
	return mod(name, "FLAG", true, ...)
end

local explodeFunc = function(chance, amount, type, ...)
	local amountNumber = tonumber(amount) or (amount == "tenth" and 10) or (amount == "quarter" and 25)
	if not amountNumber then
		return
	end
	local amounts = {}
	amounts[type] = amountNumber
	return {
		mod("ExplodeMod", "LIST", { type = firstToUpper(type), chance = chance / 100, amount = amountNumber, keyOfScaledMod = "chance" }, ...),
		flag("CanExplode")
	}
end

-- List of special modifiers
local specialQuickFixModList = {
	["^([%+%-]?[%d%.]+%%) Damage"] = "%1 more Damage",
	["^([%+%-]?[%d%.]+%%) Cast Speed"] = "%1 increased Cast Speed",
	["^([%+%-]?[%d%.]+%%) Cooldown Recovery Speed"] = "%1 increased Cooldown Recovery Speed",
	["^([%+%-]?[%d%.]+%%) Duration"] = "%1 increased Duration",
}

for _, damageType in ipairs(DamageTypes) do
	specialQuickFixModList[damageType .. " Shred Chance"] = "Shred " .. damageType .. " Resistance Chance"
end

local specialModList = {
	["no cooldown"] = { flag("NoCooldown") },
}

-- Modifiers that are recognised but unsupported
local unsupportedModList = {
}

-- Special lookups used for various modifier forms
local suffixTypes = {
	["as fire"] = "AsFire",
}
for _, damageType in ipairs(DamageTypes) do
	suffixTypes["converted to " .. damageType:lower()] = "ConvertTo" .. damageType
end
local function appendMod(inputTable, string)
	local table = { }
	for subLine, mods in pairs(inputTable) do
		if type(mods) == "string" then
			table[subLine] = mods..string
		else
			table[subLine] = { }
			for _, mod in ipairs(mods) do
				t_insert(table[subLine], mod..string)
			end
		end
	end
	return table
end
local flagTypes = {
	["frenzy"] = "Condition:Frenzy",
}

-- Build active skill name lookup
local skillNameList = {
}

for skillId, skill in pairs(data.skills) do
	skillNameList[skill.name:lower()] = { tag = { type = "SkillId", skillId = skillId } }
end

local preSkillNameList = { }

-- Scan a line for the earliest and longest match from the pattern list
-- If a match is found, returns the corresponding value from the pattern list, plus the remainder of the line and a table of captures
local function scan(line, patternList, plain)
	local bestIndex, bestEndIndex
	local bestPattern = ""
	local bestVal, bestStart, bestEnd, bestCaps
	local lineLower = line:lower()
	for pattern, patternVal in pairs(patternList) do
		local index, endIndex, cap1, cap2, cap3, cap4, cap5 = lineLower:find(pattern, 1, plain)
		if index and (not bestIndex or index < bestIndex or (index == bestIndex and (endIndex > bestEndIndex or (endIndex == bestEndIndex and #pattern > #bestPattern)))) then
			bestIndex = index
			bestEndIndex = endIndex
			bestPattern = pattern
			bestVal = patternVal
			bestStart = index
			bestEnd = endIndex
			bestCaps = { cap1, cap2, cap3, cap4, cap5 }
		end
	end
	if bestVal then
		return bestVal, line:sub(1, bestStart - 1) .. line:sub(bestEnd + 1, -1), bestCaps
	else
		return nil, line
	end
end

local function parseMod(line, order)
	-- Check if this is a special modifier
	local lineLower = line:lower()
	if unsupportedModList[lineLower] then
		return { }, line
	end
	local specialMod, specialLine, cap = scan(line, specialModList)
	if specialMod and #specialLine == 0 then
		if type(specialMod) == "function" then
			return specialMod(tonumber(cap[1]), unpack(cap))
		else
			return copyTable(specialMod)
		end
	end

	for pattern, replacement in pairs(specialQuickFixModList) do
		line = line:gsub(pattern, replacement)
	end

	-- Check for add-to-cluster-jewel special
	local addToCluster = line:match("^Added Small Passive Skills also grant: (.+)$")
	if addToCluster then
		return { mod("AddToClusterJewelNode", "LIST", addToCluster) }
	end

	line = line .. " "

	-- Check for a flag/tag specification at the start of the line
	local preFlag, preFlagCap
	preFlag, line, preFlagCap = scan(line, preFlagList)
	if type(preFlag) == "function" then
		preFlag = preFlag(unpack(preFlagCap))
	end

	-- Check for skill name at the start of the line
	local skillTag
	skillTag, line = scan(line, preSkillNameList)

	-- Scan for modifier form
	local modForm, formCap
	modForm, line, formCap = scan(line, formList)
	if not modForm then
		return nil, line
	end

	-- Check for tags (per-charge, conditionals)
	local modTag, modTag2, tagCap
	modTag, line, tagCap = scan(line, modTagList)
	if type(modTag) == "function" then
		if tagCap[1]:match("%d+") then
			modTag = modTag(tonumber(tagCap[1]), unpack(tagCap))
		else
			modTag = modTag(tagCap[1], unpack(tagCap))
		end
	end
	if modTag then
		modTag2, line, tagCap = scan(line, modTagList)
		if type(modTag2) == "function" then
			if tagCap[1]:match("%d+") then
				modTag2 = modTag2(tonumber(tagCap[1]), unpack(tagCap))
			else
				modTag2 = modTag2(tagCap[1], unpack(tagCap))
			end
		end
	end

	-- Scan for modifier name and skill name
	local modName
	if order == 2 and not skillTag then
		skillTag, line = scan(line, skillNameList)
	end
	if modForm == "FLAG" then
		formCap[1], line = scan(line, flagTypes, false)
		if not formCap[1] then
			return nil, line
		end
		modName, line = scan(line, modNameList, true)
	else
		modName, line = scan(line, modNameList, true)
	end
	if order == 1 and not skillTag then
		skillTag, line = scan(line, skillNameList)
	end

	-- Scan for flags
	local modFlag
	modFlag, line = scan(line, modFlagList, true)

	-- Find modifier value and type according to form
	local keywordFlags
	local modValue = tonumber(formCap[1]) or formCap[1]
	local modType = "BASE"
	local modSuffix
	local modExtraTags
	if modForm == "INC" then
		modType = "INC"
	elseif modForm == "RED" then
		modValue = -modValue
		modType = "INC"
	elseif modForm == "MORE" then
		modType = "MORE"
	elseif modForm == "LESS" then
		modValue = -modValue
		modType = "MORE"
	elseif modForm == "BASE" then
		modSuffix, line = scan(line, suffixTypes, true)
	elseif modForm == "GAIN" then
		modType = "BASE"
		modSuffix, line = scan(line, suffixTypes, true)
	elseif modForm == "LOSE" then
		modValue = -modValue
		modType = "BASE"
		modSuffix, line = scan(line, suffixTypes, true)
	elseif modForm == "GRANTS" then -- local
		modType = "BASE"
		modFlag = modFlag
		modExtraTags = { tag = { type = "Condition", var = "{Hand}Attack" } }
		modSuffix, line = scan(line, suffixTypes, true)
	elseif modForm == "REMOVES" then -- local
		modValue = -modValue
		modType = "BASE"
		modFlag = modFlag
		modExtraTags = { tag = { type = "Condition", var = "{Hand}Attack" } }
		modSuffix, line = scan(line, suffixTypes, true)
	elseif modForm == "CHANCE" then
		modFlag = {flags = 0, keywordFlags = 0}
		for i=2,#formCap do
			for _, damageSourceType in ipairs(DamageSourceTypes) do
				if formCap[i] == damageSourceType:lower() then
					modFlag.flags = ModFlag[damageSourceType]
				end
			end
		end
	elseif modForm == "FLAG" then
		modName = type(modValue) == "table" and modValue.name or modValue
		modType = type(modValue) == "table" and modValue.type or "FLAG"
		modValue = type(modValue) == "table" and modValue.value or true
	elseif modForm == "OVERRIDE" then
		modType = "OVERRIDE"
	end
	if not modName then
		return { }, line
	end

	-- Combine flags and tags
	local flags = 0
	local baseKeywordFlags = 0
	local tagList = { }
	local misc = { }
	for _, data in pairs({ modName, preFlag, modFlag, modTag, modTag2, skillTag, modExtraTags }) do
		if type(data) == "table" then
			flags = bor(flags, data.flags or 0)
			baseKeywordFlags = bor(baseKeywordFlags, data.keywordFlags or 0)
			if data.tag then
				t_insert(tagList, copyTable(data.tag))
			elseif data.tagList then
				for _, tag in ipairs(data.tagList) do
					t_insert(tagList, copyTable(tag))
				end
			end
			for k, v in pairs(data) do
				misc[k] = v
			end
		end
	end

	-- Generate modifier list
	local nameList = modName
	local modList = { }
	for i, name in ipairs(type(nameList) == "table" and nameList or { nameList }) do
		modList[i] = {
			name = name .. (modSuffix or misc.modSuffix or ""),
			type = modType,
			value = type(modValue) == "table" and modValue[i] or modValue,
			flags = flags,
			keywordFlags = bor(type(keywordFlags) == "table" and keywordFlags[i] or 0, baseKeywordFlags),
			unpack(tagList)
		}
	end
	if modList[1] then
		-- Special handling for various modifier types
		if misc.addToAura then
			-- Modifiers that add effects to your auras
			for i, effectMod in ipairs(modList) do
				modList[i] = mod("ExtraAuraEffect", "LIST", { mod = effectMod })
			end
		elseif misc.newAura then
			-- Modifiers that add extra auras
			for i, effectMod in ipairs(modList) do
				local tagList = { }
				for i, tag in ipairs(effectMod) do
					tagList[i] = tag
					effectMod[i] = nil
				end
				modList[i] = mod("ExtraAura", "LIST", { mod = effectMod, onlyAllies = misc.newAuraOnlyAllies }, unpack(tagList))
			end
		elseif misc.addToMinion then
			-- Minion modifiers
			for i, effectMod in ipairs(modList) do
				local tagList = { }
				if misc.playerTag then t_insert(tagList, misc.playerTag) end
				if misc.addToMinionTag then t_insert(tagList, misc.addToMinionTag) end
				if misc.playerTagList then
					for _, tag in ipairs(misc.playerTagList) do
						t_insert(tagList, tag)
					end
				end
				modList[i] = mod("MinionModifier", "LIST", { mod = effectMod }, unpack(tagList))
			end
		elseif misc.addToSkill then
			-- Skill enchants or socketed gem modifiers that add additional effects
			for i, effectMod in ipairs(modList) do
				modList[i] = mod("ExtraSkillMod", "LIST", { mod = effectMod }, misc.addToSkill)
			end
		elseif misc.applyToEnemy then
			for i, effectMod in ipairs(modList) do
				local tagList = { }
				if misc.playerTag then t_insert(tagList, misc.playerTag) end
				if misc.playerTagList then
					for _, tag in ipairs(misc.playerTagList) do
						t_insert(tagList, tag)
					end
				end
				local newMod = effectMod
				if effectMod[1] and type(effectMod) == "table" and misc.actorEnemy then
					newMod = copyTable(effectMod)
					newMod[1]["actor"] = "enemy"
				end
				modList[i] = mod("EnemyModifier", "LIST", { mod = newMod }, unpack(tagList))
			end
		end
	end
	return modList, line:match("%S") and line
end

local cache = { }
local unsupported = { }
local count = 0
--local foo = io.open("../unsupported.txt", "w")
--foo:close()
return function(line, isComb)
	if not cache[line] then
		local modList, extra = parseMod(line, 1)
		if modList and extra then
			-- TODO: No need currently, to be removed?
			-- modList, extra = parseMod(line, 2)
		end
		cache[line] = { modList, extra }
		if foo and not isComb and not cache[line][1] then
			local form = line:gsub("[%+%-]?%d+%.?%d*","{num}")
			if not unsupported[form] then
				unsupported[form] = true
				count = count + 1
				foo = io.open("../unsupported.txt", "a+")
				foo:write(count, ': ', form, (cache[line][2] and #cache[line][2] < #line and ('    {' .. cache[line][2]).. '}') or "", '\n')
				foo:close()
			end
		end
	end
	return unpack(copyTable(cache[line]))
end, cache
