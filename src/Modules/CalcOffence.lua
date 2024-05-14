-- Path of Building
--
-- Module: Calc Offence
-- Performs offence calculations.
--
local calcs = ...

local pairs = pairs
local ipairs = ipairs
local unpack = unpack
local t_insert = table.insert
local t_remove = table.remove
local m_abs = math.abs
local m_floor = math.floor
local m_ceil = math.ceil
local m_min = math.min
local m_max = math.max
local m_sqrt = math.sqrt
local m_pow = math.pow
local m_huge = math.huge
local bor = bit.bor
local band = bit.band
local bnot = bit.bnot
local s_format = string.format

local tempTable1 = { }
local tempTable2 = { }
local tempTable3 = { }

local isElemental = { Fire = true, Cold = true, Lightning = true }

-- List of all damage types, ordered according to the conversion sequence
local dmgTypeList = DamageTypes
local dmgTypeFlags = {}
for id,v in ipairs(dmgTypeList) do
	dmgTypeFlags[v] = bit.lshift(1,id)
end

-- Magic table for caching the modifier name sets used in calcDamage()
local damageStatsForTypes = setmetatable({ }, { __index = function(t, k)
	local modNames = { "Damage" }
	for type, flag in pairs(dmgTypeFlags) do
		if band(k, flag) ~= 0 then
			t_insert(modNames, type.."Damage")
		end
	end
	t[k] = modNames
	return modNames
end })

local globalOutput = nil
local globalBreakdown = nil

-- Calculate min/max damage for the given damage type
local function calcDamage(activeSkill, output, cfg, breakdown, damageType, typeFlags, convDst)
	local skillModList = activeSkill.skillModList

	typeFlags = bor(typeFlags, dmgTypeFlags[damageType])

	-- Calculate conversions
	local addDmg = 0
	local conversionTable = activeSkill.conversionTable
	for _, otherType in ipairs(dmgTypeList) do
		if otherType == damageType then
			-- Damage can only be converted from damage types that precede this one in the conversion sequence, so stop here
			break
		end
		local convMult = conversionTable[otherType][damageType]
		if convMult > 0 then
			-- Damage is being converted/gained from the other damage type
			local dmg = calcDamage(activeSkill, output, cfg, breakdown, otherType, typeFlags, damageType)
			addDmg = addDmg + dmg * convMult
		end
	end
	if addDmg ~= 0 then
		addDmg = round(addDmg)
	end

	local baseDmg = output[damageType.."DamageBase"]
	if baseDmg == 0 then
		-- No base damage for this type, don't need to calculate modifiers
		if breakdown and (addDmg ~= 0 or addMax ~= 0) then
			t_insert(breakdown.damageTypes, {
				source = damageType,
				convSrc = (addDmg ~= 0) and (addDmg .. ""),
				total = addDmg .. "",
				convDst = convDst and s_format("%d%% to %s", conversionTable[damageType][convDst] * 100, convDst),
			})
		end
		return addDmg
	end

	-- Combine modifiers
	local modNames = damageStatsForTypes[typeFlags]
	local inc = 1 + skillModList:Sum("INC", cfg, unpack(modNames)) / 100
	local more = skillModList:More(cfg, unpack(modNames))
	local genericMoreMinDamage = skillModList:More(cfg, "MinDamage")
	local moreMinDamage = skillModList:More(cfg, "Min"..damageType.."Damage")

	if breakdown then
		t_insert(breakdown.damageTypes, {
			source = damageType,
			base = baseDmg .. "",
			inc = (inc ~= 1 and "x "..inc),
			more = (more ~= 1 and "x "..more),
			convSrc = (addDmg ~= 0) and (addDmg .. ""),
			total = (round(baseDmg * inc * more) + addDmg) .. "",
			convDst = convDst and conversionTable[damageType][convDst] > 0 and s_format("%d%% to %s", conversionTable[damageType][convDst] * 100, convDst),
		})
	end

	return 	round(((baseDmg * inc * more) * genericMoreMinDamage + addDmg) * moreMinDamage)
end

---Calculates skill radius
---@param baseRadius number
---@param areaMod number
---@return number
local function calcRadius(baseRadius, areaMod)
	return m_floor(baseRadius * m_floor(100 * m_sqrt(areaMod)) / 100)
end

---Calculates the tertiary radius for Molten Strike, correctly handling the deadzone.
---@param baseRadius number
---@param deadzoneRadius number
---@param areaMod number
---@param speedMod number
local function calcMoltenStrikeTertiaryRadius(baseRadius, deadzoneRadius, areaMod, speedMod)
	-- For now, we assume that PoE only rounds at the end.
	local maxDistIgnoringSpeed = m_sqrt(baseRadius * baseRadius * areaMod - deadzoneRadius * deadzoneRadius * (areaMod - 1))
	local maxDist = m_floor((maxDistIgnoringSpeed - deadzoneRadius) * speedMod + deadzoneRadius)
	return maxDist
end

---Calculates modifiers needed to reach the next and previous radius breakpoints
---@param baseRadius number
---@param incArea number @Additive modifier
---@param moreArea number @Multiplicative modifier
---@return number, number, number, number @Next breakpoint: increased, more; Previous breakpoint: reduced, less
local function calcRadiusBreakpoints(baseRadius, incArea, moreArea)
	local radius = calcRadius(baseRadius, round(round(incArea * moreArea, 10), 2))
	local incAreaBreakpoint, redAreaBreakpoint, moreAreaBreakpoint, lessAreaBreakpoint
	if radius > 0 then
		incAreaBreakpoint = 0
		repeat
			incAreaBreakpoint = incAreaBreakpoint + 1
			local newRadius = calcRadius(baseRadius, round(round((incArea + incAreaBreakpoint / 100) * moreArea, 10), 2))
		until (newRadius > radius)
		redAreaBreakpoint = 0
		repeat
			redAreaBreakpoint = redAreaBreakpoint + 1
			local newRadius = calcRadius(baseRadius, round(round((incArea - redAreaBreakpoint / 100) * moreArea, 10), 2))
		until (newRadius < radius)
		moreAreaBreakpoint = 0
		repeat
			moreAreaBreakpoint = moreAreaBreakpoint + 1
			local newRadius = calcRadius(baseRadius, round(round(incArea * moreArea * (1 + moreAreaBreakpoint / 100), 10), 2))
		until (newRadius > radius)
		lessAreaBreakpoint = 0
		repeat
			lessAreaBreakpoint = lessAreaBreakpoint + 1
			local newRadius = calcRadius(baseRadius, round(round(incArea * moreArea * (1 - lessAreaBreakpoint / 100), 10), 2))
		until (newRadius < radius)
	end
	return incAreaBreakpoint, moreAreaBreakpoint, redAreaBreakpoint, lessAreaBreakpoint
end

---Computes and sets the breakdown for Molten Strike's tertiary radius.
---@param breakdown table
---@param deadzoneRadius number min ball landing distance (cannot be changed by any mods)
---@param baseRadius number default max landing distance with no aoe or proj. speed modifiers
---@param label string top level label to use for the breakdown
---@param incArea number current net increased area modifier
---@param moreArea number current product of all "more" and "less" area modifiers
---@param incSpd number current net increased projectile speed modifier
---@param moreSpd number current product of all "more" and "less" projectile speed modifiers
local function setMoltenStrikeTertiaryRadiusBreakdown(breakdown, deadzoneRadius, baseRadius, label, incArea, moreArea, incSpd, moreSpd)
	-- nil -> 1 (no multiplier)
	incArea = incArea or 1
	moreArea = moreArea or 1
	incSpd = incSpd or 1
	moreSpd = moreSpd or 1
	---Helper that calculates the tertiary radius with incremental modifiers to the 4 relevant pools.
	---This helps declutter the code below.
	local function calc(extraIncAoePct, extraMoreAoePct, extraIncSpdPct, extraMoreSpdPct)
		local areaMod = round(round((incArea + extraIncAoePct / 100) * moreArea * (1 + extraMoreAoePct / 100), 10), 2)
		local speedMod = round(round((incSpd + extraIncSpdPct / 100) * moreSpd * (1 + extraMoreSpdPct / 100), 10), 2)
		local dist = calcMoltenStrikeTertiaryRadius(baseRadius, deadzoneRadius, areaMod, speedMod)
		return dist, areaMod, speedMod
	end
	-- Current settings.
	local currentDist, currentAreaMod, currentSpeedMod = calc(0, 0, 0, 0)
	-- Create the detailed breakdown. This includes:
	--  * the complete formula as an algebraic expression (ignoring rounding),
	--  * the final value,
	--  * breakpoints on the 4 modifier pools (increased vs. more crossed with aoe and projectile speed), and
	--  * the input variables for the algebraic expression.
	local breakdownRadius = breakdown.AreaOfEffectRadiusTertiary or { }
	breakdown.AreaOfEffectRadiusTertiary = breakdownRadius
	t_insert(breakdownRadius, label)
	t_insert(breakdownRadius, " = (sqrt(R*R*a - r*r*(a-1)) - r) * s + r")
	t_insert(breakdownRadius, s_format(" = %d", currentDist))
	if currentDist > 0 then
		---Helper for finding one tertiary radius breakpoint value. This is a little slower than what
		---we do in the generic calcRadiusBreakpoints, but this approach requires a lot less code and
		---should be more maintainable given that we need to search for 8 different breakpoints.
		---@param sign number +1 (for increased and more breakpoints) or -1 (for reduced and less breakpoints)
		---@param argIdx number which argument to the calc function we're modifying
		local function findBreakpoint(sign, argIdx)
			local args = {0, 0, 0, 0} -- starter args for the calc function
			repeat
				args[argIdx] = args[argIdx] + sign -- increment or decrement the desired arg
				local newDist, _, _ = calc(unpack(args))
			until (newDist ~= currentDist) or (newDist == 0) -- stop once we've hit a new radius breakpoint
			return args[argIdx] * sign -- remove the sign since we want all positive numbers
		end
		t_insert(breakdownRadius, s_format("^8Next AoE breakpoint: %d%% increased or %d%% more", findBreakpoint(1, 1), findBreakpoint(1, 2)))
		t_insert(breakdownRadius, s_format("^8Next Proj. Speed breakpoint: %d%% increased or %d%% more", findBreakpoint(1, 3), findBreakpoint(1, 4)))
		t_insert(breakdownRadius, s_format("^8Previous AoE breakpoint: %d%% increased or %d%% more", findBreakpoint(-1, 1), findBreakpoint(-1, 2)))
		t_insert(breakdownRadius, s_format("^8Previous Proj. Speed breakpoint: %d%% increased or %d%% more", findBreakpoint(-1, 3), findBreakpoint(-1, 4)))
	end
	-- This is the input variable table.
	breakdownRadius.label = "Inputs"
	breakdownRadius.rowList = { }
	breakdownRadius.colList = {
		{ label = "Variable", key = "name" },
		{ label = "Value", key = "value"},
		{ label = "Description", key = "description" }
	}
	t_insert(breakdownRadius.rowList, { name = "r", value = s_format("%d", deadzoneRadius), description = "fixed deadzone radius" })
	t_insert(breakdownRadius.rowList, { name = "R", value = s_format("%d", baseRadius), description = "base outer radius" })
	t_insert(breakdownRadius.rowList, { name = "a", value = s_format("%.2f", currentAreaMod), description = "net AoE multiplier (scales area)" })
	t_insert(breakdownRadius.rowList, { name = "s", value = s_format("%.2f", currentSpeedMod), description = "net projectile speed multiplier (scales range)" })
	-- Trigger the inclusion of the radius display.
	breakdownRadius.radius = currentDist
end

function calcSkillCooldown(skillModList, skillCfg, skillData)
	local cooldownOverride = skillModList:Override(skillCfg, "CooldownRecovery")
	local addedCooldown = skillModList:Sum("BASE", skillCfg, "CooldownRecovery")
	local cooldown = cooldownOverride or ((skillData.cooldown or 0) + addedCooldown) / m_max(0, calcLib.mod(skillModList, skillCfg, "CooldownRecovery"))
	-- If a skill can store extra uses and has a cooldown, it doesn't round the cooldown value to server ticks
	local rounded = false
	if (skillData.storedUses and skillData.storedUses > 1) or (skillData.VaalStoredUses and skillData.VaalStoredUses > 1) or skillModList:Sum("BASE", skillCfg, "AdditionalCooldownUses") > 0 then
		return cooldown, rounded
	else
		return cooldown, rounded, addedCooldown
	end
end

local function calcWarcryCastTime(skillModList, skillCfg, actor)
	local baseSpeed = 1 / skillModList:Sum("BASE", skillCfg, "WarcryCastTime")
	local warcryCastTime = baseSpeed * calcLib.mod(skillModList, skillCfg, "WarcrySpeed") * calcs.actionSpeedMod(actor)
	warcryCastTime = 1 / warcryCastTime
	if skillModList:Flag(skillCfg, "InstantWarcry") then
		warcryCastTime = 0
	end
	return warcryCastTime
end

function calcSkillDuration(skillModList, skillCfg, skillData, env, enemyDB)
	local durationMod = calcLib.mod(skillModList, skillCfg, "Duration", "PrimaryDuration", "SkillAndDamagingAilmentDuration", skillData.mineDurationAppliesToSkill and "MineDuration" or nil)
	durationMod = m_max(durationMod, 0)
	local durationBase = (skillData.duration or 0) + skillModList:Sum("BASE", skillCfg, "Duration", "PrimaryDuration")
	local duration = durationBase * durationMod
	local debuffDurationMult = 1
	if env.mode_effective then
		debuffDurationMult = 1 / m_max(data.misc.BuffExpirationSlowCap, calcLib.mod(enemyDB, skillCfg, "BuffExpireFaster"))
	end
	if skillData.debuff then
		duration = duration * debuffDurationMult
	end
	return duration
end

-- Performs all offensive calculations
function calcs.offence(env, actor, activeSkill)
	local modDB = actor.modDB
	local enemyDB = actor.enemy.modDB
	local output = actor.output
	local breakdown = actor.breakdown

	local skillModList = activeSkill.skillModList
	local skillData = activeSkill.skillData
	local skillFlags = activeSkill.skillFlags
	local skillCfg = activeSkill.skillCfg
	if skillData.showAverage then
		skillFlags.showAverage = true
	else
		skillFlags.notAverage = true
	end

	if skillFlags.disable then
		-- Skill is disabled
		output.CombinedDPS = 0
		return
	end

	local function calcAreaOfEffect(skillModList, skillCfg, skillData, skillFlags, output, breakdown)
		local incArea, moreArea = calcLib.mods(skillModList, skillCfg, "AreaOfEffect", "AreaOfEffectPrimary")
		output.AreaOfEffectMod = round(round(incArea * moreArea, 10), 2)
		if skillData.radiusIsWeaponRange then
			local range = 0
			if skillFlags.weapon1Attack then
				range = m_max(range, actor.weaponRange1)
			end
			if skillFlags.weapon2Attack then
				range = m_max(range, actor.weaponRange2)
			end
			skillData.radius = range + 2
		end
		if skillData.radius then
			skillFlags.area = true
			local baseRadius = skillData.radius + (skillData.radiusExtra or 0) + skillModList:Sum("BASE", skillCfg, "AreaOfEffect")
			output.AreaOfEffectRadius = calcRadius(baseRadius, output.AreaOfEffectMod)
			output.AreaOfEffectRadiusMetres = output.AreaOfEffectRadius / 10
			if breakdown then
				local incAreaBreakpoint, moreAreaBreakpoint, redAreaBreakpoint, lessAreaBreakpoint = calcRadiusBreakpoints(baseRadius, incArea, moreArea)
				breakdown.AreaOfEffectRadius = breakdown.area(baseRadius, output.AreaOfEffectMod, output.AreaOfEffectRadius, incAreaBreakpoint, moreAreaBreakpoint, redAreaBreakpoint, lessAreaBreakpoint, skillData.radiusLabel)
			end
			if skillData.radiusSecondary then
				local incAreaSecondary, moreAreaSecondary = calcLib.mods(skillModList, skillCfg, "AreaOfEffect", "AreaOfEffectSecondary")
				output.AreaOfEffectModSecondary = round(round(incAreaSecondary * moreAreaSecondary, 10), 2)
				baseRadius = skillData.radiusSecondary + (skillData.radiusExtra or 0)
				output.AreaOfEffectRadiusSecondary = calcRadius(baseRadius, output.AreaOfEffectModSecondary)
				output.AreaOfEffectRadiusSecondaryMetres = output.AreaOfEffectRadiusSecondary / 10
				if breakdown then
					local incAreaBreakpointSecondary, moreAreaBreakpointSecondary, redAreaBreakpointSecondary, lessAreaBreakpointSecondary
					if not skillData.projectileSpeedAppliesToMSAreaOfEffect then
						incAreaBreakpointSecondary, moreAreaBreakpointSecondary, redAreaBreakpointSecondary, lessAreaBreakpointSecondary = calcRadiusBreakpoints(baseRadius, incAreaSecondary, moreAreaSecondary)
					end
					breakdown.AreaOfEffectRadiusSecondary = breakdown.area(baseRadius, output.AreaOfEffectModSecondary, output.AreaOfEffectRadiusSecondary, incAreaBreakpointSecondary, moreAreaBreakpointSecondary, redAreaBreakpointSecondary, lessAreaBreakpointSecondary, skillData.radiusSecondaryLabel)
				end
			end
			if skillData.radiusTertiary then
				local incAreaTertiary, moreAreaTertiary = calcLib.mods(skillModList, skillCfg, "AreaOfEffect", "AreaOfEffectTertiary")
				output.AreaOfEffectModTertiary = round(round(incAreaTertiary * moreAreaTertiary, 10), 2)
				baseRadius = skillData.radiusTertiary + (skillData.radiusExtra or 0)
				if skillData.projectileSpeedAppliesToMSAreaOfEffect then
					local incSpeedTertiary, moreSpeedTertiary = calcLib.mods(skillModList, skillCfg, "ProjectileSpeed")
					output.SpeedModTertiary = round(round(incSpeedTertiary * moreSpeedTertiary, 10), 2)
					output.AreaOfEffectRadiusTertiary = calcMoltenStrikeTertiaryRadius(baseRadius, skillData.radiusSecondary, output.AreaOfEffectModTertiary, output.SpeedModTertiary)
					output.AreaOfEffectRadiusMetres = output.AreaOfEffectRadius / 10
					if breakdown then
						setMoltenStrikeTertiaryRadiusBreakdown(
							breakdown, skillData.radiusSecondary, baseRadius, skillData.radiusTertiaryLabel,
							incAreaTertiary, moreAreaTertiary, incSpeedTertiary, moreSpeedTertiary
						)
					end
				else
					output.AreaOfEffectRadiusTertiary = calcRadius(baseRadius, output.AreaOfEffectModTertiary)
					output.AreaOfEffectRadiusTertiaryMetres = output.AreaOfEffectRadiusTertiary / 10
					if breakdown then
						local incAreaBreakpointTertiary, moreAreaBreakpointTertiary, redAreaBreakpointTertiary, lessAreaBreakpointTertiary = calcRadiusBreakpoints(baseRadius, incAreaTertiary, moreAreaTertiary)
						breakdown.AreaOfEffectRadiusTertiary = breakdown.area(baseRadius, output.AreaOfEffectModTertiary, output.AreaOfEffectRadiusTertiary, incAreaBreakpointTertiary, moreAreaBreakpointTertiary, redAreaBreakpointTertiary, lessAreaBreakpointTertiary, skillData.radiusTertiaryLabel)
					end
				end
			end
		end
		if breakdown then
			breakdown.AreaOfEffectMod = { }
			if output.AreaOfEffectMod ~= 1 then
				breakdown.multiChain(breakdown.AreaOfEffectMod, {
					{ "%.2f ^8(increased/reduced)", 1 + skillModList:Sum("INC", skillCfg, "AreaOfEffect") / 100 },
					{ "%.2f ^8(more/less)", skillModList:More(skillCfg, "AreaOfEffect") },
					total = s_format("= %.2f", output.AreaOfEffectMod),
				})
			end
		end
	end

	local function calcResistForType(damageType, cfg)
		local resist = enemyDB:Override(cfg, damageType.."Resist")
		local maxResist = enemyDB:Flag(nil, "DoNotChangeMaxResFromConfig") and data.misc.EnemyMaxResist or m_min(m_max(env.configInput["enemy"..damageType.."Resist"] or data.misc.EnemyMaxResist, data.misc.EnemyMaxResist), data.misc.MaxResistCap)
		if not resist then
			if env.modDB:Flag(nil, "Enemy"..damageType.."ResistEqualToYours") then
				resist = env.player.output[damageType.."Resist"]
			elseif env.partyMembers.modDB:Flag(nil, "Enemy"..damageType.."ResistEqualToYours") then
				resist = env.partyMembers.output[damageType.."Resist"]
			else
				resist = enemyDB:Sum("BASE", cfg, damageType.."Resist", isElemental[damageType] and "ElementalResist" or nil) * m_max(calcLib.mod(enemyDB, cfg, damageType.."Resist", isElemental[damageType] and "ElementalResist" or nil), 0)
			end
		end
		return m_max(m_min(resist, maxResist), data.misc.ResistFloor)
	end

	local function runSkillFunc(name)
		local func = activeSkill.activeEffect.grantedEffect[name]
		if func then
			func(activeSkill, output, breakdown)
		end
	end

	runSkillFunc("initialFunc")

	skillCfg.skillCond["SkillIsTriggered"] = skillData.triggered
	if skillCfg.skillCond["SkillIsTriggered"] then
		skillFlags.triggered = true
	end
	skillCfg.skillCond["SkillIsFocused"] = skillData.chanceToTriggerOnFocus
	if skillCfg.skillCond["SkillIsFocused"] then
		skillFlags.focused = true
	end

	-- Update skill data
	for _, value in ipairs(skillModList:List(skillCfg, "SkillData")) do
		if value.merge == "MAX" then
			skillData[value.key] = m_max(value.value, skillData[value.key] or 0)
		else
			skillData[value.key] = value.value
		end
	end

	-- Add addition stat bonuses
	if skillModList:Flag(nil, "IronGrip") then
		skillModList:NewMod("PhysicalDamage", "INC", actor.strDmgBonus or 0, "Strength", bor(ModFlag.Attack, ModFlag.Projectile))
	end
	if skillModList:Flag(nil, "IronWill") then
		skillModList:NewMod("Damage", "INC", actor.strDmgBonus or 0, "Strength", ModFlag.Spell)
	end

	if skillModList:Flag(nil, "TransfigurationOfBody") then
		skillModList:NewMod("Damage", "INC", m_floor(skillModList:Sum("INC", nil, "Life") * data.misc.Transfiguration), "Transfiguration of Body", ModFlag.Attack)
	end
	if skillModList:Flag(nil, "TransfigurationOfMind") then
		skillModList:NewMod("Damage", "INC", m_floor(skillModList:Sum("INC", nil, "Mana") * data.misc.Transfiguration), "Transfiguration of Mind")
	end
	if skillModList:Flag(nil, "TransfigurationOfSoul") then
		skillModList:NewMod("Damage", "INC", m_floor(skillModList:Sum("INC", nil, "EnergyShield") * data.misc.Transfiguration), "Transfiguration of Soul", ModFlag.Spell)
	end

	if modDB:Flag(nil, "Elusive") and skillModList:Flag(nil, "SupportedByNightblade") then
		local elusiveEffect = output.ElusiveEffectMod / 100
		local nightbladeMulti = skillModList:Sum("BASE", nil, "NightbladeElusiveCritMultiplier")
		skillModList:NewMod("CritMultiplier", "BASE", m_floor(nightbladeMulti * elusiveEffect), "Nightblade")
	end

	-- set other limits
	output.ActiveTrapLimit = skillModList:Sum("BASE", skillCfg, "ActiveTrapLimit")
	output.ActiveMineLimit = skillModList:Sum("BASE", skillCfg, "ActiveMineLimit")

	-- set flask scaling
	output.LifeFlaskRecovery = env.itemModDB.multipliers["LifeFlaskRecovery"]

	if modDB.conditions["AffectedByEnergyBlade"] then
		local dmgMod = calcLib.mod(skillModList, skillCfg, "EnergyBladeDamage")
		local speedMod = calcLib.mod(skillModList, skillCfg, "EnergyBladeAttackSpeed")
		for slotName, weaponData in pairs({ ["Weapon 1"] = "weaponData1", ["Weapon 2"] = "weaponData2" }) do
			if actor.itemList[slotName] and actor.itemList[slotName].weaponData and actor.itemList[slotName].weaponData[1] and actor[weaponData].name and data.itemBases[actor[weaponData].name] then
				local weaponBaseData = data.itemBases[actor[weaponData].name].weapon
				actor[weaponData].CritChance = weaponBaseData.CritChanceBase
				actor[weaponData].AttackRate = weaponBaseData.AttackRateBase * speedMod
				actor[weaponData].Range = weaponBaseData.Range
				for _, damageType in ipairs(dmgTypeList) do
					actor[weaponData][damageType.."Min"] = (weaponBaseData[damageType.."Min"] or 0) + m_floor(skillModList:Sum("BASE", skillCfg, "EnergyBladeMin"..damageType) * dmgMod)
					actor[weaponData][damageType.."Max"] = (weaponBaseData[damageType.."Max"] or 0) + m_floor(skillModList:Sum("BASE", skillCfg, "EnergyBladeMax"..damageType) * dmgMod)
				end
			end
		end
	end

	-- account for Battlemage
	-- Note: we check conditions of Main Hand weapon using actor.itemList as actor.weaponData1 is populated with unarmed values when no weapon slotted.
	if skillModList:Flag(nil, "Battlemage") and actor.itemList["Weapon 1"] and actor.itemList["Weapon 1"].weaponData and actor.itemList["Weapon 1"].weaponData[1] then

		local multiplier = (skillModList:Max(skillCfg, "MainHandWeaponDamageAppliesToSpells") or 100) / 100
		for _, damageType in ipairs(dmgTypeList) do
			skillModList:NewMod(damageType.."Min", "BASE", m_floor((actor.weaponData1[damageType.."Min"] or 0) * multiplier), "Battlemage", ModFlag.Spell)
			skillModList:NewMod(damageType.."Max", "BASE", m_floor((actor.weaponData1[damageType.."Max"] or 0) * multiplier), "Battlemage", ModFlag.Spell)
		end
	end
	local weapon1info = env.data.weaponTypeInfo[actor.weaponData1.type]
	local weapon2info = env.data.weaponTypeInfo[actor.weaponData2.type]
	-- -- account for Spellblade
	-- Note: we check conditions of Main Hand weapon using actor.itemList as actor.weaponData1 is populated with unarmed values when no weapon slotted.
	local spellbladeMulti = skillModList:Max(skillCfg, "OneHandWeaponDamageAppliesToSpells")
	if spellbladeMulti and actor.itemList["Weapon 1"] and actor.itemList["Weapon 1"].weaponData and actor.itemList["Weapon 1"].weaponData[1] and weapon1info.melee and weapon1info.oneHand then
		local multiplier = spellbladeMulti / 100 * (weapon2info and 0.6 or 1)
		for _, damageType in ipairs(dmgTypeList) do
			skillModList:NewMod(damageType.."Min", "BASE", m_floor((actor.weaponData1[damageType.."Min"] or 0) * multiplier), "Spellblade Main Hand", ModFlag.Spell)
			skillModList:NewMod(damageType.."Max", "BASE", m_floor((actor.weaponData1[damageType.."Max"] or 0) * multiplier), "Spellblade Main Hand", ModFlag.Spell)
		end
		if weapon2info then
			for _, damageType in ipairs(dmgTypeList) do
				skillModList:NewMod(damageType.."Min", "BASE", m_floor((actor.weaponData2[damageType.."Min"] or 0) * multiplier), "Spellblade Off Hand", ModFlag.Spell)
				skillModList:NewMod(damageType.."Max", "BASE", m_floor((actor.weaponData2[damageType.."Max"] or 0) * multiplier), "Spellblade Off Hand", ModFlag.Spell)
			end
		end
	end
	if skillModList:Flag(nil, "MinionDamageAppliesToPlayer") or skillModList:Flag(skillCfg, "MinionDamageAppliesToPlayer") then
		-- Minion Damage conversion from Spiritual Aid and The Scourge
		local multiplier = (skillModList:Max(skillCfg, "ImprovedMinionDamageAppliesToPlayer") or 100) / 100
		for _, value in ipairs(skillModList:List(skillCfg, "MinionModifier")) do
			if value.mod.name == "Damage" and value.mod.type == "INC" then
				local mod = value.mod
				local modifiers = calcLib.getConvertedModTags(mod, multiplier, true)
				skillModList:NewMod("Damage", "INC", mod.value * multiplier, mod.source, mod.flags, mod.keywordFlags, unpack(modifiers))
			end
		end
	end
	if skillModList:Flag(nil, "MinionAttackSpeedAppliesToPlayer") then
		-- Minion Damage conversion from Spiritual Command
		local multiplier = (skillModList:Max(skillCfg, "ImprovedMinionAttackSpeedAppliesToPlayer") or 100) / 100
		-- Minion Attack Speed conversion from Spiritual Command
		for _, value in ipairs(skillModList:List(skillCfg, "MinionModifier")) do
			if value.mod.name == "Speed" and value.mod.type == "INC" and (value.mod.flags == 0 or band(value.mod.flags, ModFlag.Attack) ~= 0) then
				local modifiers = calcLib.getConvertedModTags(value.mod, multiplier, true)
				skillModList:NewMod("Speed", "INC", value.mod.value * multiplier, value.mod.source, ModFlag.Attack, value.mod.keywordFlags, unpack(modifiers))
			end
		end
	end
	if skillModList:Flag(nil, "SpellDamageAppliesToAttacks") then
		-- Spell Damage conversion from Crown of Eyes, Kinetic Bolt, and the Wandslinger notable
		local multiplier = (skillModList:Max(skillCfg, "ImprovedSpellDamageAppliesToAttacks") or 100) / 100
		for i, value in ipairs(skillModList:Tabulate("INC", { flags = ModFlag.Spell }, "Damage")) do
			local mod = value.mod
			if band(mod.flags, ModFlag.Spell) ~= 0 then
				local modifiers = calcLib.getConvertedModTags(mod, multiplier)
				skillModList:NewMod("Damage", "INC", mod.value * multiplier, mod.source, bor(band(mod.flags, bnot(ModFlag.Spell)), ModFlag.Attack), mod.keywordFlags, unpack(modifiers))
				if mod.source == "Strength" then -- Prevent double-dipping from converted strength's damage bonus
					skillModList:ReplaceMod("PhysicalDamage", "INC", 0, "Strength", ModFlag.Melee)
				end
			end
		end
	end
	if skillModList:Flag(nil, "CastSpeedAppliesToAttacks") then
		-- Get all increases for this; assumption is that multiple sources would not stack, so find the max
		local multiplier = (skillModList:Max(skillCfg, "ImprovedCastSpeedAppliesToAttacks") or 100) / 100
		for i, value in ipairs(skillModList:Tabulate("INC", { flags = ModFlag.Cast }, "Speed")) do
			local mod = value.mod
			-- Add a new mod for all mods that are cast only
			-- Replace this with a single mod for the sum?
			if band(mod.flags, ModFlag.Cast) ~= 0 then
				local modifiers = calcLib.getConvertedModTags(mod, multiplier)
				skillModList:NewMod("Speed", "INC", mod.value * multiplier, mod.source, bor(band(mod.flags, bnot(ModFlag.Cast)), ModFlag.Attack), mod.keywordFlags, unpack(modifiers))
			end
		end
	end
	if skillModList:Flag(nil, "ProjectileSpeedAppliesToBowDamage") then
		-- Bow mastery projectile speed to damage with bows conversion
		for i, value in ipairs(skillModList:Tabulate("INC", { }, "ProjectileSpeed")) do
			local mod = value.mod
			skillModList:NewMod("Damage", mod.type, mod.value, mod.source, bor(ModFlag.Bow, ModFlag.Hit), mod.keywordFlags, unpack(mod))
		end
	end
	if skillModList:Flag(nil, "ClawDamageAppliesToUnarmed") then
		-- Claw Damage conversion from Rigwald's Curse
		for i, value in ipairs(skillModList:Tabulate("INC", { flags = bor(ModFlag.Claw, ModFlag.Hit), keywordFlags = KeywordFlag.Hit }, "Damage")) do
			local mod = value.mod
			if band(mod.flags, ModFlag.Claw) ~= 0 then
				skillModList:NewMod("Damage", mod.type, mod.value, mod.source, bor(band(mod.flags, bnot(ModFlag.Claw)), ModFlag.Unarmed, ModFlag.Melee), mod.keywordFlags, unpack(mod))
			end
		end
	end
	if skillModList:Flag(nil, "ClawAttackSpeedAppliesToUnarmed") then
		-- Claw Attack Speed conversion from Rigwald's Curse
		for i, value in ipairs(skillModList:Tabulate("INC", { flags = bor(ModFlag.Claw, ModFlag.Attack, ModFlag.Hit) }, "Speed")) do
			local mod = value.mod
			if band(mod.flags, ModFlag.Claw) ~= 0 and band(mod.flags, ModFlag.Attack) ~= 0 then
				skillModList:NewMod("Speed", mod.type, mod.value, mod.source, bor(band(mod.flags, bnot(ModFlag.Claw)), ModFlag.Unarmed), mod.keywordFlags, unpack(mod))
			end
		end
	end
	if skillModList:Flag(nil, "ClawCritChanceAppliesToUnarmed") then
		-- Claw Crit Chance conversion from Rigwald's Curse
		for i, value in ipairs(skillModList:Tabulate("INC", { flags = bor(ModFlag.Claw, ModFlag.Hit) }, "CritChance")) do
			local mod = value.mod
			if band(mod.flags, ModFlag.Claw) ~= 0 then
				skillModList:NewMod("CritChance", mod.type, mod.value, mod.source, bor(band(mod.flags, bnot(ModFlag.Claw)), ModFlag.Unarmed), mod.keywordFlags, unpack(mod))
			end
		end
	end
	if skillModList:Flag(nil, "ClawCritChanceAppliesToMinions") then
		-- Claw Crit Chance conversion from Law of the Wilds
		for i, value in ipairs(skillModList:Tabulate("INC", { flags = bor(ModFlag.Claw, ModFlag.Hit) }, "CritChance")) do
			local mod = value.mod
			if band(mod.flags, ModFlag.Claw) ~= 0 then
				env.minion.modDB:NewMod("CritChance", mod.type, mod.value, mod.source)
			end
		end
	end
	if skillModList:Flag(nil, "ClawCritMultiplierAppliesToMinions") then
		-- Claw Crit Multi conversion from Law of the Wilds
		for i, value in ipairs(skillModList:Tabulate("BASE", { flags = bor(ModFlag.Claw, ModFlag.Hit) }, "CritMultiplier")) do
			local mod = value.mod
			if band(mod.flags, ModFlag.Claw) ~= 0 then
				env.minion.modDB:NewMod("CritMultiplier", mod.type, mod.value, mod.source)
			end
		end
	end
	if skillModList:Flag(nil, "CritChanceIncreasedByUncappedLightningRes") then
		for i, value in ipairs(modDB:Tabulate("FLAG", nil, "CritChanceIncreasedByUncappedLightningRes")) do
			local mod = value.mod
			skillModList:NewMod("CritChance", "INC", output.LightningResistTotal, mod.source)
			break
		end
	end
	if skillModList:Flag(nil, "CritChanceIncreasedByLightningRes") then
		for i, value in ipairs(modDB:Tabulate("FLAG", nil, "CritChanceIncreasedByLightningRes")) do
			local mod = value.mod
			skillModList:NewMod("CritChance", "INC", output.LightningResist, mod.source)
			break
		end
	end
	if skillModList:Flag(nil, "CritChanceIncreasedByOvercappedLightningRes") then
		for i, value in ipairs(modDB:Tabulate("FLAG", nil, "CritChanceIncreasedByOvercappedLightningRes")) do
			local mod = value.mod
			skillModList:NewMod("CritChance", "INC", output.LightningResistOverCap, mod.source)
			break
		end
	end
	if skillModList:Flag(nil, "CritChanceIncreasedBySpellSuppressChance") then
		for i, value in ipairs(modDB:Tabulate("FLAG", nil, "CritChanceIncreasedBySpellSuppressChance")) do
			local mod = value.mod
			skillModList:NewMod("CritChance", "INC", output.SpellSuppressionChance, mod.source)
			break
		end

	end
	if skillModList:Flag(nil, "LightRadiusAppliesToAccuracy") then
		-- Light Radius conversion from Corona Solaris
		for i, value in ipairs(skillModList:Tabulate("INC",  { }, "LightRadius")) do
			local mod = value.mod
			skillModList:NewMod("Accuracy", "INC", mod.value, mod.source, mod.flags, mod.keywordFlags, unpack(mod))
		end
	end
	if skillModList:Flag(nil, "LightRadiusAppliesToAreaOfEffect") then
		-- Light Radius conversion from Wreath of Phrecia
		for i, value in ipairs(skillModList:Tabulate("INC",  { }, "LightRadius")) do
			local mod = value.mod
			skillModList:NewMod("AreaOfEffect", "INC", math.floor(mod.value / 2), mod.source, mod.flags, mod.keywordFlags, unpack(mod))
		end
	end
	if skillModList:Flag(nil, "LightRadiusAppliesToDamage") then
		-- Light Radius conversion from Wreath of Phrecia
		for i, value in ipairs(skillModList:Tabulate("INC",  { }, "LightRadius")) do
			local mod = value.mod
			skillModList:NewMod("Damage", "INC", mod.value, mod.source, mod.flags, mod.keywordFlags, unpack(mod))
		end
	end
	if skillModList:Flag(nil, "CastSpeedAppliesToTrapThrowingSpeed") then
		-- Cast Speed conversion from Slavedriver's Hand
		for i, value in ipairs(skillModList:Tabulate("INC", { flags = ModFlag.Cast }, "Speed")) do
			local mod = value.mod
			if (mod.flags == 0 or band(mod.flags, ModFlag.Cast) ~= 0) then
				skillModList:NewMod("TrapThrowingSpeed", "INC", mod.value, mod.source, band(mod.flags, bnot(ModFlag.Cast), bnot(ModFlag.Attack)), mod.keywordFlags, unpack(mod))
			end
		end
	end
	if skillData.arrowSpeedAppliesToAreaOfEffect then
		-- Arrow Speed conversion for Galvanic Arrow
		for i, value in ipairs(skillModList:Tabulate("INC", { flags = ModFlag.Bow }, "ProjectileSpeed")) do
			local mod = value.mod
			skillModList:NewMod("AreaOfEffect", "INC", mod.value, mod.source, mod.flags, mod.keywordFlags, unpack(mod))
		end
	end
	if skillModList:Flag(nil, "SequentialProjectiles") and not skillModList:Flag(nil, "OneShotProj") and not skillModList:Flag(nil,"NoAdditionalProjectiles") and not skillModList:Flag(nil, "TriggeredBySnipe") then
		-- Applies DPS multiplier based on projectile count
		skillData.dpsMultiplier = skillModList:Sum("BASE", skillCfg, "ProjectileCount")
	end
	output.Repeats = 1 + (skillModList:Sum("BASE", skillCfg, "RepeatCount") or 0)
	if output.Repeats > 1 then
		output.RepeatCount = output.Repeats
		-- handle all the multipliers from Repeats
		if env.configInput.repeatMode ~= "NONE" then
			for i, value in ipairs(skillModList:Tabulate("INC", skillCfg, "RepeatFinalAreaOfEffect")) do
				local mod = value.mod
				local modValue = mod.value
				if env.configInput.repeatMode == "AVERAGE" then
					modValue = modValue / output.Repeats
				end
				skillModList:NewMod("AreaOfEffect", "INC", modValue, mod.source, mod.flags, mod.keywordFlags, unpack(mod))
			end
			for i, value in ipairs(skillModList:Tabulate("INC", skillCfg, "RepeatPerRepeatAreaOfEffect")) do
				local mod = value.mod
				local modValue = mod.value * (output.Repeats - 1)
				if env.configInput.repeatMode == "AVERAGE" then
					modValue = modValue / 2
				end
				skillModList:NewMod("AreaOfEffect", "INC", modValue, mod.source, mod.flags, mod.keywordFlags, unpack(mod))
			end
			for i, value in ipairs(skillModList:Tabulate("BASE", skillCfg, "RepeatFinalDoubleDamageChance")) do
				local mod = value.mod
				local modValue = mod.value
				if env.configInput.repeatMode == "AVERAGE" then
					modValue = modValue / output.Repeats
				end
				skillModList:NewMod("DoubleDamageChance", "BASE", modValue, mod.source, mod.flags, mod.keywordFlags, unpack(mod))
			end
			local DamageFinalMoreValueTotal = 1
			local DamageMoreValueTotal = 0
			for i, value in ipairs(skillModList:Tabulate("MORE", skillCfg, "RepeatFinalDamage")) do
				local mod = value.mod
				local modValue = mod.value
				DamageFinalMoreValueTotal = DamageFinalMoreValueTotal * (1 + modValue / 100)
				DamageMoreValueTotal = DamageMoreValueTotal + modValue
				if env.configInput.repeatMode == "AVERAGE" and not skillModList:Flag(nil, "OnlyFinalRepeat") then
					modValue = modValue / output.Repeats
				end
				skillModList:NewMod("Damage", "MORE", modValue, mod.source, mod.flags, mod.keywordFlags, unpack(mod))
			end
			for i, value in ipairs(skillModList:Tabulate("MORE", skillCfg, "RepeatPerRepeatDamage")) do
				local mod = value.mod
				local modValue = mod.value * (output.Repeats - 1)
				if env.configInput.repeatMode == "AVERAGE" then
					if DamageFinalMoreValueTotal ~= 1 then
						-- sum from 0 to num Repeats the damage each one does, multiplied by the other repeat multipliers,
						-- divide the total by the average other repeat multipliers and divide by number of repeats
						-- eg greater echo with 20Q div echo is (100 + 130 + 160 + 190*1.6)/1.15/4 - 100 = 50.87% more damage
						modValue = ((100 + mod.value * (output.Repeats - 2) / 2) * (output.Repeats - 1) + (100 + mod.value * (output.Repeats - 1)) * DamageFinalMoreValueTotal) / (output.Repeats + DamageMoreValueTotal / 100) - 100
					else
						modValue = modValue / 2
					end
				end
				skillModList:NewMod("Damage", "MORE", modValue, mod.source, mod.flags, mod.keywordFlags, unpack(mod))
			end

			local lastMod = nil
			DamageFinalMoreValueTotal = DamageMoreValueTotal
			for _, repeatCount in ipairs({{2, "One"}, {3, "Two"}, {4, "Three"}}) do
				if repeatCount[1] > output.Repeats then
					break
				elseif env.configInput.repeatMode == "AVERAGE" then
					for i, value in ipairs(skillModList:Tabulate("MORE", skillCfg, "Repeat"..repeatCount[2].."Damage")) do
						DamageMoreValueTotal = DamageMoreValueTotal + value.mod.value
						lastMod = value.mod
					end
				elseif repeatCount[1] == output.Repeats then
					for i, value in ipairs(skillModList:Tabulate("MORE", skillCfg, "Repeat"..repeatCount[2].."Damage")) do
						skillModList:NewMod("Damage", "MORE", value.mod.value, value.mod.source, value.mod.flags, value.mod.keywordFlags, unpack(value.mod))
					end
				end
			end
			if env.configInput.repeatMode == "AVERAGE" then
				if lastMod then
					skillModList:NewMod("Damage", "MORE", (DamageMoreValueTotal / output.Repeats + 100) / (1 + DamageFinalMoreValueTotal / output.Repeats / 100) - 100, lastMod.source, lastMod.flags, lastMod.keywordFlags, unpack(lastMod))
				end
			end
			if skillModList:Flag(nil, "FinalRepeatSumsDamage") then
				for i, value in ipairs(skillModList:Tabulate("FLAG", skillCfg, "FinalRepeatSumsDamage")) do
					skillModList:NewMod("Damage", "MORE", (100 * output.Repeats + DamageFinalMoreValueTotal) / (1 + DamageFinalMoreValueTotal / 100) - 100, value.mod.source, value.mod.flags, value.mod.keywordFlags, unpack(value.mod))
				end
			end
		end
	end
	if skillData.gainPercentBaseWandDamage then
		local mult = skillData.gainPercentBaseWandDamage / 100
		if actor.weaponData1.type == "Wand" and actor.weaponData2.type == "Wand" then
			for _, damageType in ipairs(dmgTypeList) do
				skillModList:NewMod(damageType.."Min", "BASE", ((actor.weaponData1[damageType.."Min"] or 0) + (actor.weaponData2[damageType.."Min"] or 0)) / 2 * mult, "Spellslinger")
				skillModList:NewMod(damageType.."Max", "BASE", ((actor.weaponData1[damageType.."Max"] or 0) + (actor.weaponData2[damageType.."Max"] or 0)) / 2 * mult, "Spellslinger")
			end
		elseif actor.weaponData1.type == "Wand" then
			for _, damageType in ipairs(dmgTypeList) do
				skillModList:NewMod(damageType.."Min", "BASE", (actor.weaponData1[damageType.."Min"] or 0) * mult, "Spellslinger")
				skillModList:NewMod(damageType.."Max", "BASE", (actor.weaponData1[damageType.."Max"] or 0) * mult, "Spellslinger")
			end
		elseif actor.weaponData2.type == "Wand" then
			for _, damageType in ipairs(dmgTypeList) do
				skillModList:NewMod(damageType.."Min", "BASE", (actor.weaponData2[damageType.."Min"] or 0) * mult, "Spellslinger")
				skillModList:NewMod(damageType.."Max", "BASE", (actor.weaponData2[damageType.."Max"] or 0) * mult, "Spellslinger")
			end
		end
	end
	if skillData.gainPercentBaseDaggerDamage then
		local mult = skillData.gainPercentBaseDaggerDamage / 100
		if actor.weaponData1.type == "Dagger" and actor.weaponData2.type == "Dagger" then
			for _, damageType in ipairs(dmgTypeList) do
				skillModList:NewMod(damageType.."Min", "BASE", ((actor.weaponData1[damageType.."Min"] or 0) + (actor.weaponData2[damageType.."Min"] or 0)) / 2 * mult, "Blade Blast of Dagger Detonation")
				skillModList:NewMod(damageType.."Max", "BASE", ((actor.weaponData1[damageType.."Max"] or 0) + (actor.weaponData2[damageType.."Max"] or 0)) / 2 * mult, "Blade Blast of Dagger Detonation")
			end
		elseif actor.weaponData1.type == "Dagger" then
			for _, damageType in ipairs(dmgTypeList) do
				skillModList:NewMod(damageType.."Min", "BASE", (actor.weaponData1[damageType.."Min"] or 0) * mult, "Blade Blast of Dagger Detonation")
				skillModList:NewMod(damageType.."Max", "BASE", (actor.weaponData1[damageType.."Max"] or 0) * mult, "Blade Blast of Dagger Detonation")
			end
		elseif actor.weaponData2.type == "Dagger" then
			for _, damageType in ipairs(dmgTypeList) do
				skillModList:NewMod(damageType.."Min", "BASE", (actor.weaponData2[damageType.."Min"] or 0) * mult, "Blade Blast of Dagger Detonation")
				skillModList:NewMod(damageType.."Max", "BASE", (actor.weaponData2[damageType.."Max"] or 0) * mult, "Blade Blast of Dagger Detonation")
			end
		end
	end
	if skillModList:Sum("BASE", nil, "CritMultiplierAppliesToDegen") > 0 then
		for i, value in ipairs(skillModList:Tabulate("BASE", skillCfg, "CritMultiplier")) do
			local mod = value.mod
			if mod.source ~= "Base" then -- The global base Crit Multi doesn't apply to ailments with Perfect Agony
				skillModList:NewMod("DotMultiplier", "BASE", m_floor(mod.value / 2), mod.source, ModFlag.Ailment, { type = "Condition", var = "CriticalStrike" }, unpack(mod))
			end
		end
	end
	if skillModList:Flag(nil, "HasSeals") and activeSkill.skillTypes[SkillType.CanRapidFire] and not skillModList:Flag(nil, "NoRepeatBonuses") then
		-- Applies DPS multiplier based on seals count
		output.SealCooldown = skillModList:Sum("BASE", skillCfg, "SealGainFrequency") / calcLib.mod(skillModList, skillCfg, "SealGainFrequency")
		output.SealMax = skillModList:Sum("BASE", skillCfg, "SealCount")
		output.AverageBurstHits = output.SealMax
		output.TimeMaxSeals = output.SealCooldown * output.SealMax

		if not skillData.hitTimeOverride then
			if skillModList:Flag(nil, "UseMaxUnleash") then
				for i, value in ipairs(skillModList:Tabulate("INC",  { }, "MaxSealCrit")) do
					local mod = value.mod
					skillModList:NewMod("CritChance", "INC", mod.value, mod.source, mod.flags, mod.keywordFlags, unpack(mod))
				end
				env.player.mainSkill.skillData.dpsMultiplier = (1 + output.SealMax * calcLib.mod(skillModList, skillCfg, "SealRepeatPenalty"))
				env.player.mainSkill.skillData.hitTimeOverride = m_max(output.TimeMaxSeals, (1 / activeSkill.activeEffect.grantedEffect.castTime * 1.1 * calcLib.mod(skillModList, skillCfg, "Speed") * output.ActionSpeedMod))
			else
				env.player.mainSkill.skillData.dpsMultiplier = 1 + 1 / output.SealCooldown / (1 / activeSkill.activeEffect.grantedEffect.castTime * 1.1 * calcLib.mod(skillModList, skillCfg, "Speed") * output.ActionSpeedMod) * calcLib.mod(skillModList, skillCfg, "SealRepeatPenalty")
			end
		end

		if breakdown then
			breakdown.SealGainTime = { }
			breakdown.multiChain(breakdown.SealGainTime, {
				label = "Gain frequency:",
				base = { "%.2fs ^8(base gain frequency)", skillModList:Sum("BASE", skillCfg, "SealGainFrequency") },
				{ "%.2f ^8(increased/reduced gain frequency)", 1 + skillModList:Sum("INC", skillCfg, "SealGainFrequency") / 100 },
				{ "%.2f ^8(action speed modifier)",  output.ActionSpeedMod },
				total = s_format("= %.2fs ^8per Seal", output.SealCooldown),
			})
		end
	end
	if skillModList:Sum("BASE", skillCfg, "PhysicalDamageGainAsRandom", "PhysicalDamageConvertToRandom", "PhysicalDamageGainAsColdOrLightning") > 0 then
		skillFlags.randomPhys = true
		local physMode = env.configInput.physMode or "AVERAGE"
		for i, value in ipairs(skillModList:Tabulate("BASE", skillCfg, "PhysicalDamageGainAsRandom")) do
			local mod = value.mod
			local effVal = mod.value / 3
			if physMode == "AVERAGE" then
				skillModList:NewMod("PhysicalDamageGainAsFire", "BASE", effVal, mod.source, mod.flags, mod.keywordFlags, unpack(mod))
				skillModList:NewMod("PhysicalDamageGainAsCold", "BASE", effVal, mod.source, mod.flags, mod.keywordFlags, unpack(mod))
				skillModList:NewMod("PhysicalDamageGainAsLightning", "BASE", effVal, mod.source, mod.flags, mod.keywordFlags, unpack(mod))
			elseif physMode == "FIRE" then
				skillModList:NewMod("PhysicalDamageGainAsFire", "BASE", mod.value, mod.source, mod.flags, mod.keywordFlags, unpack(mod))
			elseif physMode == "COLD" then
				skillModList:NewMod("PhysicalDamageGainAsCold", "BASE", mod.value, mod.source, mod.flags, mod.keywordFlags, unpack(mod))
			elseif physMode == "LIGHTNING" then
				skillModList:NewMod("PhysicalDamageGainAsLightning", "BASE", mod.value, mod.source, mod.flags, mod.keywordFlags, unpack(mod))
			end
		end
		for i, value in ipairs(skillModList:Tabulate("BASE", skillCfg, "PhysicalDamageConvertToRandom")) do
			local mod = value.mod
			local effVal = mod.value / 3
			if physMode == "AVERAGE" then
				skillModList:NewMod("PhysicalDamageConvertToFire", "BASE", effVal, mod.source, mod.flags, mod.keywordFlags, unpack(mod))
				skillModList:NewMod("PhysicalDamageConvertToCold", "BASE", effVal, mod.source, mod.flags, mod.keywordFlags, unpack(mod))
				skillModList:NewMod("PhysicalDamageConvertToLightning", "BASE", effVal, mod.source, mod.flags, mod.keywordFlags, unpack(mod))
			elseif physMode == "FIRE" then
				skillModList:NewMod("PhysicalDamageConvertToFire", "BASE", mod.value, mod.source, mod.flags, mod.keywordFlags, unpack(mod))
			elseif physMode == "COLD" then
				skillModList:NewMod("PhysicalDamageConvertToCold", "BASE", mod.value, mod.source, mod.flags, mod.keywordFlags, unpack(mod))
			elseif physMode == "LIGHTNING" then
				skillModList:NewMod("PhysicalDamageConvertToLightning", "BASE", mod.value, mod.source, mod.flags, mod.keywordFlags, unpack(mod))
			end
		end
		for i, value in ipairs(skillModList:Tabulate("BASE", skillCfg, "PhysicalDamageGainAsColdOrLightning")) do
			local mod = value.mod
			local effVal = mod.value / 2
			if physMode == "AVERAGE" or physMode == "FIRE" then
				skillModList:NewMod("PhysicalDamageGainAsCold", "BASE", effVal, mod.source, mod.flags, mod.keywordFlags, unpack(mod))
				skillModList:NewMod("PhysicalDamageGainAsLightning", "BASE", effVal, mod.source, mod.flags, mod.keywordFlags, unpack(mod))
			elseif physMode == "COLD" then
				skillModList:NewMod("PhysicalDamageGainAsCold", "BASE", mod.value, mod.source, mod.flags, mod.keywordFlags, unpack(mod))
			elseif physMode == "LIGHTNING" then
				skillModList:NewMod("PhysicalDamageGainAsLightning", "BASE", mod.value, mod.source, mod.flags, mod.keywordFlags, unpack(mod))
			end
		end
	end
	-- momentum stacks
	if skillModList:Flag(nil, "SupportedByMomentum") then
		local maxMomentumStacks = skillModList:Sum("BASE", skillCfg, "MomentumStacksMax")
		local extraMomentumStacks = skillModList:Sum("BASE", skillCfg, "MomentumStacksExtra")
		if maxMomentumStacks > 0 then
			if not modDB:HasMod("BASE", nil, "Multiplier:MomentumStacks") then
				modDB:NewMod("Multiplier:MomentumStacks", "BASE", m_min((maxMomentumStacks + extraMomentumStacks) / 2, maxMomentumStacks), "Config", { type = "Condition", var = "Combat" })
			elseif modDB:Sum("BASE", nil, "Multiplier:MomentumStacks") > maxMomentumStacks then
				modDB:ReplaceMod("Multiplier:MomentumStacks", "BASE", maxMomentumStacks, "Config", { type = "Condition", var = "Combat" })
			end
		elseif modDB:HasMod("BASE", nil, "Multiplier:MomentumStacks") then
			modDB:ReplaceMod("Multiplier:MomentumStacks", "BASE", 0, "Config")
		end
	end

	local isAttack = skillFlags.attack

	runSkillFunc("preSkillTypeFunc")

	-- Calculate skill type stats
	if skillFlags.minion then
		if activeSkill.minion and activeSkill.minion.minionData.limit then
			output.ActiveMinionLimit = m_floor(env.modDB:Override(nil, activeSkill.minion.minionData.limit) or calcLib.val(skillModList, activeSkill.minion.minionData.limit, skillCfg))
		end
		output.SummonedMinionsPerCast = m_floor(calcLib.val(skillModList, "MinionPerCastCount", skillCfg))
		if output.SummonedMinionsPerCast == 0 then
			output.SummonedMinionsPerCast = 1
		end
	end
	if skillFlags.chaining then
		if skillModList:Flag(skillCfg, "CannotChain") or skillModList:Flag(skillCfg, "NoAdditionalChains")then
			output.ChainMaxString = "Cannot chain"
		else
			output.ChainMax = skillModList:Sum("BASE", skillCfg, "ChainCountMax", not skillFlags.projectile and "BeamChainCountMax" or nil)
			output.ChainMaxString = output.ChainMax
			output.Chain = m_min(output.ChainMax, skillModList:Sum("BASE", skillCfg, "ChainCount"))
			output.ChainRemaining = m_max(0, output.ChainMax - output.Chain)
		end
	end
	if skillFlags.projectile then
		if skillModList:Flag(nil, "PointBlank") then
			skillModList:NewMod("Damage", "MORE", 30, "Point Blank", bor(ModFlag.Attack, ModFlag.Projectile), { type = "DistanceRamp", ramp = {{10,1},{35,0},{120,-1}} })
		end
		if skillModList:Flag(nil, "FarShot") then
			skillModList:NewMod("Damage", "MORE", 100, "Far Shot", bor(ModFlag.Attack, ModFlag.Projectile), { type = "DistanceRamp", ramp = {{10, -0.2}, {25, 0}, {70, 0.6}} })
		end
		if skillModList:Flag(skillCfg, "NoAdditionalProjectiles") then
			output.ProjectileCount = 1
		else
			local projBase = skillModList:Sum("BASE", skillCfg, "ProjectileCount")
			local projMore = skillModList:More(skillCfg, "ProjectileCount")
			output.ProjectileCount = m_floor(projBase * projMore)
		end
		if skillModList:Flag(skillCfg, "AdditionalProjectilesAddBouncesInstead") then
			local projBase = skillModList:Sum("BASE", skillCfg, "ProjectileCount") + skillModList:Sum("BASE", skillCfg, "BounceCount") - 1
			local projMore = skillModList:More(skillCfg, "ProjectileCount")
			output.BounceCount = m_floor(projBase * projMore)
		end
		if skillModList:Flag(skillCfg, "CannotSplit") or activeSkill.skillTypes[SkillType.ProjectileNumber] then
			if breakdown then
				local SplitCount = skillModList:Sum("BASE", skillCfg, "SplitCount") + enemyDB:Sum("BASE", skillCfg, "SelfSplitCount")
				if SplitCount > 0 then
					output.SplitCountString = "Cannot split"
				end
			end
		else
			output.SplitCount = skillModList:Sum("BASE", skillCfg, "SplitCount") + enemyDB:Sum("BASE", skillCfg, "SelfSplitCount")
			if skillModList:Flag(skillCfg, "AdditionalProjectilesAddSplitsInstead") then
				output.SplitCount = output.SplitCount + m_floor((skillModList:Sum("BASE", skillCfg, "ProjectileCount") - 1) * skillModList:More(skillCfg, "ProjectileCount"))
			end
			if skillModList:Flag(skillCfg, "AdditionalChainsAddSplitsInstead") then
				output.SplitCount = output.SplitCount + skillModList:Sum("BASE", skillCfg, "ChainCountMax")
			end
			output.SplitCountString = output.SplitCount
		end
		if skillModList:Flag(skillCfg, "CannotFork") then
			output.ForkCountString = "Cannot fork"
		elseif skillModList:Flag(skillCfg, "ForkOnce") then
			skillFlags.forking = true
			if skillModList:Flag(skillCfg, "ForkTwice") then
				output.ForkCountMax = m_min(skillModList:Sum("BASE", skillCfg, "ForkCountMax"), 2)
			else
				output.ForkCountMax = m_min(skillModList:Sum("BASE", skillCfg, "ForkCountMax"), 1)
			end
			output.ForkedCount = m_min(output.ForkCountMax, skillModList:Sum("BASE", skillCfg, "ForkedCount"))
			output.ForkCountString = output.ForkCountMax
			output.ForkRemaining = m_max(0, output.ForkCountMax - output.ForkedCount)
		else
			output.ForkCountString = "0"
		end
		if skillModList:Flag(skillCfg, "CannotPierce") then
			output.PierceCount = 0
			output.PierceCountString = "Cannot pierce"
		else
			if skillModList:Flag(skillCfg, "PierceAllTargets") or enemyDB:Flag(nil, "AlwaysPierceSelf") then
				output.PierceCount = 100
				output.PierceCountString = "All targets"
			else
				output.PierceCount = skillModList:Sum("BASE", skillCfg, "PierceCount")
				output.PierceCountString = output.PierceCount
			end
			if output.PierceCount > 0 then
				skillFlags.piercing = true
			end
			output.PiercedCount = m_min(output.PierceCount, skillModList:Sum("BASE", skillCfg, "PiercedCount"))
		end
		output.ProjectileSpeedMod = calcLib.mod(skillModList, skillCfg, "ProjectileSpeed")
		if breakdown then
			breakdown.ProjectileSpeedMod = breakdown.mod(skillModList, skillCfg, "ProjectileSpeed")
		end
	end
	if skillFlags.melee then
		if skillFlags.weapon1Attack then
			actor.weaponRange1 = (actor.weaponData1.range and actor.weaponData1.range + skillModList:Sum("BASE", activeSkill.weapon1Cfg, "MeleeWeaponRange") + 10 * skillModList:Sum("BASE", activeSkill.weapon1Cfg, "MeleeWeaponRangeMetre")) or (6 + skillModList:Sum("BASE", skillCfg, "UnarmedRange") + 10 * skillModList:Sum("BASE", skillCfg, "UnarmedRangeMetre"))
		end
		if skillFlags.weapon2Attack then
			actor.weaponRange2 = (actor.weaponData2.range and actor.weaponData2.range + skillModList:Sum("BASE", activeSkill.weapon2Cfg, "MeleeWeaponRange") + 10 * skillModList:Sum("BASE", activeSkill.weapon2Cfg, "MeleeWeaponRangeMetre")) or (6 + skillModList:Sum("BASE", skillCfg, "UnarmedRange") + 10 * skillModList:Sum("BASE", skillCfg, "UnarmedRangeMetre"))
		end
		if activeSkill.skillTypes[SkillType.MeleeSingleTarget] then
			local range = 100
			if skillFlags.weapon1Attack then
				range = m_min(range, actor.weaponRange1)
			end
			if skillFlags.weapon2Attack then
				range = m_min(range, actor.weaponRange2)
			end
			output.WeaponRange = range + 2
			output.WeaponRangeMetre = output.WeaponRange / 10
			if breakdown then
				breakdown.WeaponRange = {
					radius = output.WeaponRange
				}
			end
		end
	end
	if skillFlags.area or skillData.radius or (skillFlags.mine and activeSkill.skillTypes[SkillType.Aura]) then
		calcAreaOfEffect(skillModList, skillCfg, skillData, skillFlags, output, breakdown)
	end
	if activeSkill.skillTypes[SkillType.Aura] then
		output.AuraEffectMod = calcLib.mod(skillModList, skillCfg, "AuraEffect", not skillData.auraCannotAffectSelf and "SkillAuraEffectOnSelf" or nil)
		if breakdown then
			breakdown.AuraEffectMod = breakdown.mod(skillModList, skillCfg, "AuraEffect", not skillData.auraCannotAffectSelf and "SkillAuraEffectOnSelf" or nil)
		end
	end
	if activeSkill.skillTypes[SkillType.HasReservation] and not activeSkill.skillTypes[SkillType.ReservationBecomesCost] then
		for _, pool in ipairs({"Life", "Mana"}) do
			output[pool .. "ReservedMod"] = 0
			if calcLib.mod(skillModList, skillCfg, "SupportManaMultiplier") > 0 and calcLib.mod(skillModList, skillCfg, pool .. "Reserved", "Reserved") > 0 then
				output[pool .. "ReservedMod"] = calcLib.mod(skillModList, skillCfg, pool .. "Reserved", "Reserved") * floor(calcLib.mod(skillModList, skillCfg, "SupportManaMultiplier"), 4) / m_max(0, calcLib.mod(skillModList, skillCfg, pool .. "ReservationEfficiency", "ReservationEfficiency"))
			end
			if breakdown then
				local inc = skillModList:Sum("INC", skillCfg, pool .. "Reserved", "Reserved", "SupportManaMultiplier")
				local more = skillModList:More(skillCfg, pool .. "Reserved", "Reserved", "SupportManaMultiplier")
				if inc ~= 0 and more ~= 1 then
					breakdown[pool .. "ReservedMod"] = {
						s_format("%.2f ^8(increased/reduced)", 1 + inc/100),
						s_format("x %.2f ^8(more/less)", more),
						s_format("/ %.2f ^8(reservation efficiency)", calcLib.mod(skillModList, skillCfg, pool .. "ReservationEfficiency", "ReservationEfficiency")),
						s_format("= %.2f", output[pool .. "ReservedMod"]),
					}
				end
			end
		end
	end
	if activeSkill.skillTypes[SkillType.Hex] or activeSkill.skillTypes[SkillType.Mark] then
		output.CurseEffectMod = calcLib.mod(skillModList, skillCfg, "CurseEffect")
		if breakdown then
			breakdown.CurseEffectMod = breakdown.mod(skillModList, skillCfg, "CurseEffect")
		end
	end
	if activeSkill.skillTypes[SkillType.Link] then
		output.LinkEffectMod = calcLib.mod(skillModList, skillCfg, "LinkEffect", "BuffEffect")
		if breakdown then
			breakdown.LinkEffectMod = breakdown.mod(skillModList, skillCfg, "LinkEffect", "BuffEffect")
		end
	end
	if (skillFlags.trap or skillFlags.mine) and not (skillData.trapCooldown or skillData.cooldown) then
		skillFlags.notAverage = true
		skillFlags.showAverage = false
		skillData.showAverage = false
	end
	if skillFlags.trap then
		local baseSpeed = 1 / skillModList:Sum("BASE", skillCfg, "TrapThrowingTime")
		local timeMod = calcLib.mod(skillModList, skillCfg, "SkillTrapThrowingTime")
		if timeMod > 0 then
			baseSpeed = baseSpeed * (1 / timeMod)
		end
		output.TrapThrowingSpeed = baseSpeed * calcLib.mod(skillModList, skillCfg, "TrapThrowingSpeed") * output.ActionSpeedMod
		output.TrapThrowingTime = 1 / output.TrapThrowingSpeed
		skillData.timeOverride = output.TrapThrowingTime
		if breakdown then
			breakdown.TrapThrowingSpeed = { }
			breakdown.multiChain(breakdown.TrapThrowingSpeed, {
				label = "Throwing rate:",
				base = { "%.2f ^8(base throwing rate)", baseSpeed },
				{ "%.2f ^8(increased/reduced throwing speed)", 1 + skillModList:Sum("INC", skillCfg, "TrapThrowingSpeed") / 100 },
				{ "%.2f ^8(more/less throwing speed)", skillModList:More(skillCfg, "TrapThrowingSpeed") },
				{ "%.2f ^8(action speed modifier)",  output.ActionSpeedMod },
				total = s_format("= %.2f ^8per second", output.TrapThrowingSpeed),
			})
		end
		if breakdown and timeMod > 0 then
			breakdown.TrapThrowingTime = { }
			breakdown.multiChain(breakdown.TrapThrowingTime, {
				label = "Throwing time:",
				base = { "%.2f ^8(base throwing time)", 1 / (output.TrapThrowingSpeed * timeMod) },
				{ "%.2f ^8(total modifier)", timeMod },
				total = s_format("= %.2f ^8seconds per throw", output.TrapThrowingTime),
			})
		end

		local baseCooldown = skillData.trapCooldown or skillData.cooldown
		if baseCooldown then
			output.TrapCooldown = baseCooldown / calcLib.mod(skillModList, skillCfg, "CooldownRecovery")
			if breakdown then
				breakdown.TrapCooldown = {
					s_format("%.2fs ^8(base)", skillData.trapCooldown or skillData.cooldown or 4),
					s_format("/ %.2f ^8(increased/reduced cooldown recovery)", 1 + skillModList:Sum("INC", skillCfg, "CooldownRecovery") / 100),
					s_format("= %.3fs", output.TrapCooldown)
				}
			end
		end
		local incArea, moreArea = calcLib.mods(skillModList, skillCfg, "TrapTriggerAreaOfEffect")
		local areaMod = round(round(incArea * moreArea, 10), 2)
		output.TrapTriggerRadius = calcRadius(data.misc.TrapTriggerRadiusBase, areaMod)
		output.TrapTriggerRadiusMetre = output.TrapTriggerRadius / 10
		if breakdown then
			local incAreaBreakpoint, moreAreaBreakpoint, redAreaBreakpoint, lessAreaBreakpoint = calcRadiusBreakpoints(data.misc.TrapTriggerRadiusBase, incArea, moreArea)
			breakdown.TrapTriggerRadius = breakdown.area(data.misc.TrapTriggerRadiusBase, areaMod, output.TrapTriggerRadius, incAreaBreakpoint, moreAreaBreakpoint, redAreaBreakpoint, lessAreaBreakpoint)
		end
	elseif skillData.cooldown or skillModList:Sum("BASE", skillCfg, "CooldownRecovery") ~= 0 then
		local cooldown, rounded, addedCooldown = calcSkillCooldown(skillModList, skillCfg, skillData)
		output.Cooldown = cooldown
		if breakdown then
			breakdown.Cooldown = {
				s_format("%.2fs ^8(base)", skillData.cooldown or 0 + addedCooldown),
				s_format("/ %.2f ^8(increased/reduced cooldown recovery)", 1 + skillModList:Sum("INC", skillCfg, "CooldownRecovery") / 100),
			}
			t_insert(breakdown.Cooldown, s_format("= %.3fs", output.Cooldown))
		end
	end
	if skillData.storedUses then
		local baseUses = skillData.storedUses
		local additionalUses = skillModList:Sum("BASE", skillCfg, "AdditionalCooldownUses")
		output.StoredUses = baseUses + additionalUses
		if breakdown then
			breakdown.StoredUses = { s_format("%d ^8(skill use%s)", baseUses, baseUses == 1 and "" or "s" ) }
			if additionalUses ~= 0 then
				t_insert(breakdown.StoredUses, s_format("+ %d ^8(additional use%s)", additionalUses, additionalUses == 1 and "" or "s"))
				t_insert(breakdown.StoredUses, s_format("= %d ^8(total use%s)", output.StoredUses, output.StoredUses == 1 and "" or "s"))
			end
		end
	end
	if skillFlags.mine then
		local baseSpeed = 1 / skillModList:Sum("BASE", skillCfg, "MineLayingTime")
		local timeMod = calcLib.mod(skillModList, skillCfg, "SkillMineThrowingTime")
		if timeMod > 0 then
			baseSpeed = baseSpeed * (1 / timeMod)
		end
		output.MineLayingSpeed = baseSpeed * calcLib.mod(skillModList, skillCfg, "MineLayingSpeed") * output.ActionSpeedMod
		output.MineLayingTime = 1 / output.MineLayingSpeed
		skillData.timeOverride = output.MineLayingTime
		if breakdown then
			breakdown.MineLayingTime = { }
			breakdown.multiChain(breakdown.MineLayingTime, {
				label = "Throwing rate:",
				base = { "%.2f ^8(base throwing rate)", baseSpeed },
				{ "%.2f ^8(increased/reduced throwing speed)", 1 + skillModList:Sum("INC", skillCfg, "MineLayingSpeed") / 100 },
				{ "%.2f ^8(more/less throwing speed)", skillModList:More(skillCfg, "MineLayingSpeed") },
				{ "%.2f ^8(action speed modifier)",  output.ActionSpeedMod },
				total = s_format("= %.2f ^8per second", output.MineLayingSpeed),
			})
		end
		if breakdown and timeMod > 0 then
			breakdown.MineThrowingTime = { }
			breakdown.multiChain(breakdown.MineThrowingTime, {
			label = "Throwing time:",
				base = { "%.2f ^8(base throwing time)", 1 / (output.MineLayingSpeed * timeMod) },
				{ "%.2f ^8(total modifier)", timeMod },
				total = s_format("= %.2f ^8seconds per throw", output.MineLayingTime),
			})
		end

		local incArea, moreArea = calcLib.mods(skillModList, skillCfg, "MineDetonationAreaOfEffect")
		local areaMod = round(round(incArea * moreArea, 10), 2)
		output.MineDetonationRadius = calcRadius(data.misc.MineDetonationRadiusBase, areaMod)
		output.MineDetonationRadiusMetre = output.MineDetonationRadius / 10
		if breakdown then
			local incAreaBreakpoint, moreAreaBreakpoint, redAreaBreakpoint, lessAreaBreakpoint = calcRadiusBreakpoints(data.misc.MineDetonationRadiusBase, incArea, moreArea)
			breakdown.MineDetonationRadius = breakdown.area(data.misc.MineDetonationRadiusBase, areaMod, output.MineDetonationRadius, incAreaBreakpoint, moreAreaBreakpoint, redAreaBreakpoint, lessAreaBreakpoint)
		end
		if activeSkill.skillTypes[SkillType.Aura] then
			output.MineAuraRadius = calcRadius(data.misc.MineAuraRadiusBase, output.AreaOfEffectMod)
			output.MineAuraRadiusMetre = output.MineAuraRadius / 10
			if breakdown then
				local incArea, moreArea = calcLib.mods(skillModList, skillCfg, "AreaOfEffect")
				local incAreaBreakpoint, moreAreaBreakpoint, redAreaBreakpoint, lessAreaBreakpoint = calcRadiusBreakpoints(data.misc.MineAuraRadiusBase, incArea, moreArea)
				breakdown.MineAuraRadius = breakdown.area(data.misc.MineAuraRadiusBase, output.AreaOfEffectMod, output.MineAuraRadius, incAreaBreakpoint, moreAreaBreakpoint, redAreaBreakpoint, lessAreaBreakpoint)
			end
		end
	end
	if skillFlags.totem then
		if skillFlags.ballista then
			baseSpeed = 1 / skillModList:Sum("BASE", skillCfg, "BallistaPlacementTime")
		else
			baseSpeed = 1 / skillModList:Sum("BASE", skillCfg, "TotemPlacementTime")
		end
		output.TotemPlacementSpeed = baseSpeed * calcLib.mod(skillModList, skillCfg, "TotemPlacementSpeed") * output.ActionSpeedMod
		output.TotemPlacementTime = 1 / output.TotemPlacementSpeed
		if breakdown then
			breakdown.TotemPlacementTime = { }
			breakdown.multiChain(breakdown.TotemPlacementTime, {
				label = "Placement speed:",
				base = { "%.2f ^8(base placement speed)", baseSpeed },
				{ "%.2f ^8(increased/reduced placement speed)", 1 + skillModList:Sum("INC", skillCfg, "TotemPlacementSpeed") / 100 },
				{ "%.2f ^8(more/less placement speed)", skillModList:More(skillCfg, "TotemPlacementSpeed") },
				{ "%.2f ^8(action speed modifier)",  output.ActionSpeedMod },
				total = s_format("= %.2f ^8per second", output.TotemPlacementSpeed),
			})
		end
		output.ActiveTotemLimit = skillModList:Sum("BASE", skillCfg, "ActiveTotemLimit", "ActiveBallistaLimit")
		output.TotemsSummoned = env.modDB:Override(nil, "TotemsSummoned") or output.ActiveTotemLimit
		if breakdown then
			breakdown.ActiveTotemLimit = {
				"Totems Summoned: "..output.TotemsSummoned..(env.configInput.TotemsSummoned and " ^8(overridden from the Configuration tab)" or " ^8(can be overridden in the Configuration tab)"),
			}
		end
		output.TotemLifeMod = calcLib.mod(skillModList, skillCfg, "TotemLife")
		output.TotemLife = round(m_floor(env.data.monsterAllyLifeTable[skillData.totemLevel] * env.data.totemLifeMult[activeSkill.skillTotemId]) * output.TotemLifeMod)
		output.TotemEnergyShield = skillModList:Sum("BASE", skillCfg, "TotemEnergyShield")
		output.TotemBlockChance = skillModList:Sum("BASE", skillCfg, "TotemBlockChance")
		output.TotemArmour = skillModList:Sum("BASE", skillCfg, "TotemArmour")
		if breakdown then
			breakdown.TotemLifeMod = breakdown.mod(skillModList, skillCfg, "TotemLife")
			breakdown.TotemLife = {
				"Totem level: "..skillData.totemLevel,
				env.data.monsterAllyLifeTable[skillData.totemLevel].." ^8(base life for a level "..skillData.totemLevel.." monster)",
				"x "..env.data.totemLifeMult[activeSkill.skillTotemId].." ^8(life multiplier for this totem type)",
				"x "..output.TotemLifeMod.." ^8(totem life modifier)",
				"= "..output.TotemLife,
			}
			breakdown.TotemEnergyShield = breakdown.mod(skillModList, skillCfg, "TotemEnergyShield")
			breakdown.TotemBlockChance = breakdown.mod(skillModList, skillCfg, "TotemBlockChance")
			breakdown.TotemArmour = breakdown.mod(skillModList, skillCfg, "TotemArmour")
		end
	end
	if skillFlags.brand then
		output.BrandAttachmentRange = data.misc.BrandAttachmentRangeBase * calcLib.mod(skillModList, skillCfg, "BrandAttachmentRange")
		output.BrandAttachmentRangeMetre = output.BrandAttachmentRange / 10
		output.ActiveBrandLimit = skillModList:Sum("BASE", skillCfg, "ActiveBrandLimit")
		if breakdown then
			breakdown.BrandAttachmentRange = { radius = output.BrandAttachmentRange }
		end
	end

	if skillFlags.warcry then
		output.WarcryCastTime = calcWarcryCastTime(skillModList, skillCfg, actor)
	end

	if skillFlags.corpse then
		output.CorpseLevel = skillModList:Sum("BASE", skillCfg, "CorpseLevel")
		output.BaseCorpseLife = env.data.monsterLifeTable[output.CorpseLevel or 1] * (env.data.monsterVarietyLifeMult[skillData.corpseMonsterVariety] or 1) * (env.data.mapLevelLifeMult[env.enemyLevel] or 1)
		output.CorpseLifeInc = 1 + (skillModList:Sum("INC", skillCfg, "CorpseLife") or 0) / 100
		output.CorpseLife = output.BaseCorpseLife * output.CorpseLifeInc
		if breakdown then
			breakdown.CorpseLife = {
				s_format("%d ^8(base life of a level %d monster)", env.data.monsterLifeTable[output.CorpseLevel or 1], output.CorpseLevel or "n/a"),
				s_format("x %.2f ^8(%s variety multiplier)", env.data.monsterVarietyLifeMult[skillData.corpseMonsterVariety] or 1, skillData.corpseMonsterVariety),
				s_format("x %.2f ^8(map level %d monster life multiplier from config)", env.data.mapLevelLifeMult[env.enemyLevel] or 1, env.enemyLevel),
				s_format(" = %d ^8(base corpse life)", output.BaseCorpseLife),
				s_format(""),
				s_format("x %.2f ^8(corpse maximum life increases)", output.CorpseLifeInc),
				s_format(" = %d", output.CorpseLife),
			}
		end
	end

	-- Skill duration
	local debuffDurationMult = 1
	if env.mode_effective then
		debuffDurationMult = 1 / m_max(data.misc.BuffExpirationSlowCap, calcLib.mod(enemyDB, skillCfg, "BuffExpireFaster"))
	end
	do
		output.DurationMod = calcLib.mod(skillModList, skillCfg, "Duration", "PrimaryDuration", "SkillAndDamagingAilmentDuration", skillData.mineDurationAppliesToSkill and "MineDuration" or nil)
		output.DurationMod = m_max(output.DurationMod, 0)
		if breakdown then
			breakdown.DurationMod = breakdown.mod(skillModList, skillCfg, "Duration", "PrimaryDuration", "SkillAndDamagingAilmentDuration", skillData.mineDurationAppliesToSkill and "MineDuration" or nil)
			if breakdown.DurationMod and skillData.durationSecondary then
				t_insert(breakdown.DurationMod, 1, "Primary duration:")
			end
		end
		local durationBase = (skillData.duration or 0) + skillModList:Sum("BASE", skillCfg, "Duration", "PrimaryDuration")
		if durationBase > 0 and not (activeSkill.minion and skillModList:Flag(skillCfg, activeSkill.minion.type.."PermanentDuration")) then
			output.Duration = durationBase * output.DurationMod
			if skillData.debuff then
				output.Duration = output.Duration * debuffDurationMult
			end
			if breakdown and output.Duration ~= durationBase then
				breakdown.Duration = {
					s_format("%.2fs ^8(base)", durationBase),
				}
				if output.DurationMod ~= 1 then
					t_insert(breakdown.Duration, s_format("x %.4f ^8(duration modifier)", output.DurationMod))
				end
				if skillData.debuff and debuffDurationMult ~= 1 then
					t_insert(breakdown.Duration, s_format("/ %.3f ^8(debuff expires slower/faster)", 1 / debuffDurationMult))
				end
				t_insert(breakdown.Duration, s_format("= %.3fs", output.Duration))
			end
		end
		durationBase = (skillData.durationSecondary or 0) + skillModList:Sum("BASE", skillCfg, "Duration", "SecondaryDuration")
		if durationBase > 0 then
			local durationMod = calcLib.mod(skillModList, skillCfg, "Duration", "SecondaryDuration", "SkillAndDamagingAilmentDuration", skillData.mineDurationAppliesToSkill and "MineDuration" or nil)
			durationMod = m_max(durationMod, 0)
			output.DurationSecondary = durationBase * durationMod
			if skillData.debuffSecondary then
				output.DurationSecondary = output.DurationSecondary * debuffDurationMult
			end
			if breakdown and output.DurationSecondary ~= durationBase then
				breakdown.SecondaryDurationMod = breakdown.mod(skillModList, skillCfg, "Duration", "SecondaryDuration", "SkillAndDamagingAilmentDuration", skillData.mineDurationAppliesToSkill and "MineDuration" or nil)
				if breakdown.SecondaryDurationMod then
					t_insert(breakdown.SecondaryDurationMod, 1, "Secondary duration:")
				end
				breakdown.DurationSecondary = {
					s_format("%.2fs ^8(base)", durationBase),
				}
				if output.DurationMod ~= 1 then
					t_insert(breakdown.DurationSecondary, s_format("x %.4f ^8(duration modifier)", durationMod))
				end
				if skillData.debuffSecondary and debuffDurationMult ~= 1 then
					t_insert(breakdown.DurationSecondary, s_format("/ %.3f ^8(debuff expires slower/faster)", 1 / debuffDurationMult))
				end
				t_insert(breakdown.DurationSecondary, s_format("= %.3fs", output.DurationSecondary))
			end
		end
		durationBase = (skillData.durationTertiary or 0) + skillModList:Sum("BASE", skillCfg, "Duration", "TertiaryDuration")
		if durationBase > 0 then
			local durationMod = calcLib.mod(skillModList, skillCfg, "Duration", "TertiaryDuration", "SkillAndDamagingAilmentDuration", skillData.mineDurationAppliesToSkill and "MineDuration" or nil)
			durationMod = m_max(durationMod, 0)
			output.DurationTertiary = durationBase * durationMod
			if skillData.debuffTertiary then
				output.DurationTertiary = output.DurationTertiary * debuffDurationMult
			end
			if breakdown and output.DurationTertiary ~= durationBase then
				breakdown.TertiaryDurationMod = breakdown.mod(skillModList, skillCfg, "Duration", "TertiaryDuration", "SkillAndDamagingAilmentDuration", skillData.mineDurationAppliesToSkill and "MineDuration" or nil)
				if breakdown.TertiaryDurationMod then
					t_insert(breakdown.TertiaryDurationMod, 1, "Tertiary duration:")
				end
				breakdown.DurationTertiary = {
					s_format("%.2fs ^8(base)", durationBase),
				}
				if output.DurationMod ~= 1 then
					t_insert(breakdown.DurationTertiary, s_format("x %.4f ^8(duration modifier)", durationMod))
				end
				if skillData.debuffTertiary and debuffDurationMult ~= 1 then
					t_insert(breakdown.DurationTertiary, s_format("/ %.3f ^8(debuff expires slower/faster)", 1 / debuffDurationMult))
				end
				t_insert(breakdown.DurationTertiary, s_format("= %.3fs", output.DurationTertiary))
			end
		end
		durationBase = (skillData.auraDuration or 0)
		if durationBase > 0 then
			local durationMod = calcLib.mod(skillModList, skillCfg, "Duration", "SkillAndDamagingAilmentDuration")
			durationMod = m_max(durationMod, 0)
			output.AuraDuration = durationBase * durationMod
			if breakdown and output.AuraDuration ~= durationBase then
				breakdown.AuraDuration = {
					s_format("%.2fs ^8(base)", durationBase),
					s_format("x %.4f ^8(duration modifier)", durationMod),
					s_format("= %.3fs", output.AuraDuration),
				}
			end
		end
		durationBase = (skillData.reserveDuration or 0)
		if durationBase > 0 then
			local durationMod = calcLib.mod(skillModList, skillCfg, "Duration", "SkillAndDamagingAilmentDuration")
			durationMod = m_max(durationMod, 0)
			output.ReserveDuration = durationBase * durationMod
			if breakdown and output.ReserveDuration ~= durationBase then
				breakdown.ReserveDuration = {
					s_format("%.2fs ^8(base)", durationBase),
					s_format("x %.4f ^8(duration modifier)", durationMod),
					s_format("= %.3fs", output.ReserveDuration),
				}
			end
		end
		output.TotemDurationMod = calcLib.mod(skillModList, skillCfg, "TotemDuration")
		output.TotemDurationMod = m_max(output.TotemDurationMod, 0)
		local TotemDurationBase = skillModList:Sum("BASE", skillCfg, "TotemDuration")
		output.TotemDuration = TotemDurationBase * output.TotemDurationMod
		if breakdown then
			breakdown.TotemDurationMod = breakdown.mod(skillModList, skillCfg, "TotemDuration")
			breakdown.TotemDuration = {
				s_format("%.2fs ^8(base)", TotemDurationBase),
			}
			if output.TotemDurationMod ~= 1 then
				t_insert(breakdown.TotemDuration, s_format("x %.4f ^8(duration modifier)", output.TotemDurationMod))
			end
			t_insert(breakdown.TotemDuration, s_format("= %.3fs", output.TotemDuration))
		end
	end

	-- Skill uptime
	do
		if not activeSkill.skillTypes[SkillType.Vaal] then -- exclude vaal skills as we currently don't support soul generation or gain prevention.
			local cooldown = output.Cooldown or 0
			for _, durationType in pairs({ "Duration", "DurationSecondary", "DurationTertiary", "AuraDuration", "reserveDuration" }) do
				local duration = output[durationType] or 0
				if (duration ~= 0 and cooldown ~= 0) then
					local uptime = 1
					if skillModList:Flag(skillCfg, "NoCooldownRecoveryInDuration") then
						uptime = duration / (cooldown + duration)
					else
						uptime = duration / (cooldown)
					end
					uptime = m_min(uptime, 1)
					output[durationType.."Uptime"] = uptime * 100
					if breakdown then
						if skillModList:Flag(skillCfg, "NoCooldownRecoveryInDuration") then
							breakdown[durationType.."Uptime"] = {
								s_format("%.2fs / (%.2fs + %.2fs)", duration, cooldown, duration),
								s_format("= %d%%", output[durationType.."Uptime"])
							}
						else
							breakdown[durationType.."Uptime"] = {
								s_format("%.2fs / %.2fs", duration, cooldown),
								s_format("= %d%%", output[durationType.."Uptime"])
							}
						end
					end
				end
			end
		end
	end

	-- Calculate costs (may be slightly off due to rounding differences)
	local costs = {
		["Mana"] = { type = "Mana", upfront = true, percent = false, text = "mana", baseCost = 0, totalCost = 0, baseCostNoMult = 0, finalBaseCost = 0 },
		["Life"] = { type = "Life", upfront = true, percent = false, text = "life", baseCost = 0, totalCost = 0, baseCostNoMult = 0, finalBaseCost = 0 },
		["ES"] = { type = "ES", upfront = true, percent = false, text = "ES", baseCost = 0, totalCost = 0, baseCostNoMult = 0, finalBaseCost = 0 },
		["Soul"] = { type = "Soul", upfront = true, percent = false, unaffectedByGenericCostMults = true, text = "soul", baseCost = 0, totalCost = 0, baseCostNoMult = 0, finalBaseCost = 0 },
		["Rage"] = { type = "Rage", upfront = true, percent = false, text = "rage", baseCost = 0, totalCost = 0, baseCostNoMult = 0, finalBaseCost = 0 },
		["ManaPercent"] = { type = "Mana", upfront = true, percent = true, text = "mana", baseCost = 0, totalCost = 0, baseCostNoMult = 0, finalBaseCost = 0 },
		["LifePercent"] = { type = "Life", upfront = true, percent = true, text = "life", baseCost = 0, totalCost = 0, baseCostNoMult = 0, finalBaseCost = 0 },
		["ManaPerMinute"] = { type = "Mana", upfront = false, percent = false, text = "mana/s", baseCost = 0, totalCost = 0, baseCostNoMult = 0, finalBaseCost = 0 },
		["LifePerMinute"] = { type = "Life", upfront = false, percent = false, text = "life/s", baseCost = 0, totalCost = 0, baseCostNoMult = 0, finalBaseCost = 0 },
		["ManaPercentPerMinute"] = { type = "Mana", upfront = false, percent = true, text = "mana/s", baseCost = 0, totalCost = 0, baseCostNoMult = 0, finalBaseCost = 0 },
		["LifePercentPerMinute"] = { type = "Life", upfront = false, percent = true, text = "life/s", baseCost = 0, totalCost = 0, baseCostNoMult = 0, finalBaseCost = 0 },
		["ESPerMinute"] = { type = "ES", upfront = false, percent = false, text = "ES/s", baseCost = 0, totalCost = 0, baseCostNoMult = 0, finalBaseCost = 0 },
		["ESPercentPerMinute"] = { type = "ES", upfront = false, percent = true, text = "ES/s", baseCost = 0, totalCost = 0, baseCostNoMult = 0, finalBaseCost = 0 },
	}

	if not skillModList:Flag(skillCfg, "HasNoCost") then
		--Support cost multipliers are calculated first and rounded down after 4 digits
		local mult = floor(skillModList:More(skillCfg, "SupportManaMultiplier"), 4)
		-- First pass to calculate base costs. Used for cost conversion (e.g. Petrified Blood)
		local additionalLifeCost = skillModList:Sum("BASE", skillCfg, "ManaCostAsLifeCost") / 100 -- Extra cost (e.g. Petrified Blood) calculations
		local additionalESCost = skillModList:Sum("BASE", skillCfg, "ManaCostAsEnergyShieldCost") / 100 -- Extra cost (e.g. Replica Covenant) calculations
		local hybridLifeCost = skillModList:Sum("BASE", skillCfg, "HybridManaAndLifeCost_Life") / 100 -- Life/Mana mastery
		for resource, val in pairs(costs) do
			local skillCost = activeSkill.activeEffect.grantedEffect.stats.cost and activeSkill.activeEffect.grantedEffect.stats.cost[resource] or nil
			local baseCost = round(skillCost and skillCost / data.costs[resource].Divisor or 0, 2)
			local baseCostNoMult = skillModList:Sum("BASE", skillCfg, resource.."CostNoMult") or 0 -- Flat cost from gem e.g. Divine Blessing
			local divineBlessingCorrection = 0
			if val.upfront then
				baseCost = baseCost + skillModList:Sum("BASE", skillCfg, resource.."CostBase") -- Rage Cost
				val.totalCost = skillModList:Sum("BASE", skillCfg, resource.."Cost", "Cost")
				if resource == "Mana" and activeSkill.skillTypes[SkillType.ReservationBecomesCost] and val.percent == false then --Divine Blessing / Totem auras
					local reservedFlat = activeSkill.skillData[val.text.."ReservationFlat"] or activeSkill.activeEffect.grantedEffectLevel[val.text.."ReservationFlat"] or 0
					baseCost = baseCost + reservedFlat
					local reservedPercent = activeSkill.skillData[val.text.."ReservationPercent"] or activeSkill.activeEffect.grantedEffectLevel[val.text.."ReservationPercent"] or 0
					baseCost = baseCost + m_floor((output[resource] or 0) * reservedPercent / 100)
					--Divine Blessing / Totem aura skills that have a percent reservation, round instead of floor the value. This corrects the final result if it would round up
					divineBlessingCorrection = round((output[resource] or 0) * reservedPercent / 100 * mult) - m_floor((output[resource] or 0) * reservedPercent / 100 * mult)
				end
				if resource == "Mana" and skillData.baseManaCostIsAtLeastPercentUnreservedMana then -- Archmage
					baseCost = m_max(baseCost, m_max(m_floor((output.ManaUnreserved or 0) * skillData.baseManaCostIsAtLeastPercentUnreservedMana / 100)), 1)
				end
			end
			val.baseCost = val.baseCost + baseCost
			val.baseCostNoMult = val.baseCostNoMult + baseCostNoMult
			val.finalBaseCost = (m_floor(val.baseCost * mult) + val.baseCostNoMult) + divineBlessingCorrection
			if val.type == "Life" then
				local manaType = resource:gsub("Life", "Mana")
				if skillModList:Flag(skillCfg, "CostLifeInsteadOfMana") then -- Blood Magic / Lifetap
					val.baseCost = val.baseCost + costs[manaType].baseCost
					val.baseCostNoMult = val.baseCostNoMult + costs[manaType].baseCostNoMult
					val.finalBaseCost = val.finalBaseCost + costs[manaType].finalBaseCost
					costs[manaType].baseCost = 0
					costs[manaType].baseCostNoMult = 0
					costs[manaType].finalBaseCost = 0
				elseif additionalLifeCost > 0 or hybridLifeCost > 0 then
					val.baseCost = costs[manaType].baseCost
					val.finalBaseCost = val.finalBaseCost + round(costs[manaType].finalBaseCost * (hybridLifeCost + additionalLifeCost))
				end
			elseif val.type == "ES" then
				local manaType = resource:gsub("ES", "Mana")
			  	if additionalESCost > 0 then
			  		val.baseCost = costs[manaType].baseCost
			  		val.finalBaseCost = val.finalBaseCost + round(costs[manaType].finalBaseCost * additionalESCost)
				end
			elseif val.type == "Rage" then
				if skillModList:Flag(skillCfg, "CostRageInsteadOfSouls") then -- Hateforge
					val.baseCost = val.baseCost + costs.Soul.baseCost
					val.baseCostNoMult = val.baseCostNoMult + costs.Soul.baseCostNoMult
					val.finalBaseCost = val.finalBaseCost + costs.Soul.finalBaseCost
					costs.Soul.baseCost = 0
					costs.Soul.baseCostNoMult = 0
					costs.Soul.finalBaseCost = 0
				end
			end
		end
		for resource, val in pairs(costs) do
			local resource = val.upfront and resource or resource:gsub("Minute", "Second")
			local hasCost = val.baseCost > 0 or val.totalCost > 0 or val.baseCostNoMult > 0 or val.finalBaseCost > 0
			output[resource.."HasCost"] = hasCost
			local costName = resource.."Cost"
			local moreType = 1
			local moreCost = 1
			local inc = 0
			if not val.unaffectedByGenericCostMults then
				output[costName] = val.finalBaseCost
				moreType = skillModList:More(skillCfg, val.type.."Cost")
				moreCost = skillModList:More(skillCfg, "Cost")
				inc = skillModList:Sum("INC", skillCfg, val.type.."Cost", "Cost")
				if inc < 0 then
					output[costName] = m_max(0, m_ceil((1 + inc / 100) * output[costName]))
				else
					output[costName] = m_max(0, m_floor((1 + inc / 100) * output[costName]))
				end
				if moreType < 1 then
					output[costName] = m_max(0, m_ceil(moreType * output[costName]))
				else
					output[costName] = m_max(0, m_floor(moreType * output[costName]))
				end
				if moreCost < 1 then
					output[costName] = m_max(0, m_ceil(moreCost * output[costName]))
				else
					output[costName] = m_max(0, m_floor(moreCost * output[costName]))
				end
				output[costName] = m_max(0, output[costName] + val.totalCost)
				if val.type == "Mana" and hybridLifeCost > 0 then -- Life/Mana Mastery
					output[costName] = m_max(0, m_floor((1 - hybridLifeCost) * output[costName]))
				end
			else
				moreType = skillModList:More(skillCfg, val.type.."Cost")
				inc = skillModList:Sum("INC", skillCfg, val.type.."Cost")
				output[costName] = m_floor(val.baseCost + val.baseCostNoMult)
				output[costName] = m_max(0, (1 + inc / 100) * output[costName])
				output[costName] = m_max(0, moreType * output[costName])
				output[costName] = m_max(0, output[costName] + val.totalCost)
			end
			if breakdown and hasCost then
				breakdown[costName] = {
					s_format("%.2f"..(val.percent and "%%" or "").." ^8(base "..val.text.." cost)", val.baseCost)
				}
				if mult ~= 1 then
					t_insert(breakdown[costName], s_format("x %.4f ^8(cost multiplier)", mult))
				end
				if val.baseCostNoMult ~= 0 then
					t_insert(breakdown[costName], s_format("+ %d ^8(additional "..val.text.." cost)", val.baseCostNoMult))
				end
				if val.type == "Life" and (hybridLifeCost + additionalLifeCost) ~= 0 and not skillModList:Flag(skillCfg, "CostLifeInsteadOfMana") then
					t_insert(breakdown[costName], s_format("* %.2f ^8(mana cost conversion)", hybridLifeCost + additionalLifeCost))
				end
				if val.type == "ES" and additionalESCost ~= 0 and not skillModList:Flag(skillCfg, "CostLifeInsteadOfMana") then
					t_insert(breakdown[costName], s_format("* %.2f ^8(mana cost conversion)", additionalESCost))
				end
				if inc ~= 0 then
					t_insert(breakdown[costName], s_format("x %.2f ^8(increased/reduced "..val.text.." cost)", 1 + inc/100))
				end
				if moreCost ~= 1 then
					t_insert(breakdown[costName], s_format("x %.2f ^8(more/less cost)", moreCost))
				end
				if moreType ~= 1 then
					t_insert(breakdown[costName], s_format("x %.2f ^8(more/less "..val.text.." cost)", moreType))
				end
				if val.totalCost ~= 0 then
					t_insert(breakdown[costName], s_format("%+d ^8(total "..val.text.." cost)", val.totalCost))
				end
				if val.type == "Mana" and hybridLifeCost > 0 then
					t_insert(breakdown[costName], s_format("x %.2f ^8(%d%% paid for with life)", (1-hybridLifeCost), hybridLifeCost*100))
				end
				t_insert(breakdown[costName], s_format("= %"..(val.upfront and "d" or ".2f")..(val.percent and "%%" or ""), output[costName]))
			end
		end
	end

	-- account for Sacrificial Zeal
	-- Note: Sacrificial Zeal grants Added Spell Physical Damage equal to 25% of the Skill's Mana Cost, and causes you to take Physical Damage over Time, for 4 seconds
	if skillModList:Flag(nil, "Condition:SacrificialZeal") and output.ManaHasCost then
		local multiplier = 0.25
		skillModList:NewMod("PhysicalMin", "BASE", m_floor(output.ManaCost * multiplier), "Sacrificial Zeal", ModFlag.Spell)
		skillModList:NewMod("PhysicalMax", "BASE", m_floor(output.ManaCost * multiplier), "Sacrificial Zeal", ModFlag.Spell)
	end

	runSkillFunc("preDamageFunc")

	-- Handle corpse and enemy explosions
	local monsterLife = skillData.corpseLife or (env.enemyLevel and data.monsterLifeTable[env.enemyLevel] or 100)
	if skillData.explodeCorpse and (skillData.corpseLife or env.enemyLevel) then
		local damageType = skillData.corpseExplosionDamageType or "Fire"
		skillData[damageType.."BonusMin"] = monsterLife * ( skillData.corpseExplosionLifeMultiplier or skillData.selfFireExplosionLifeMultiplier )
		skillData[damageType.."BonusMax"] = monsterLife * ( skillData.corpseExplosionLifeMultiplier or skillData.selfFireExplosionLifeMultiplier )
	end
	if skillFlags.monsterExplode then
		for _, damageType in pairs(dmgTypeList) do
			local percentage = skillData[damageType.."EffectiveExplodePercentage"]
			local base = (percentage or 0) * monsterLife / 100
			skillData[damageType.."Min"] = base
			skillData[damageType.."Max"] = base
		end
	end

	-- Cache global damage disabling flags
	local canDeal = { }
	for _, damageType in pairs(dmgTypeList) do
		canDeal[damageType] = not skillModList:Flag(skillCfg, "DealNo"..damageType)
	end

	-- Calculate damage conversion percentages
	activeSkill.conversionTable = wipeTable(activeSkill.conversionTable)
	for damageTypeIndex = 1, #dmgTypeList - 1 do
		local damageType = dmgTypeList[damageTypeIndex]
		local globalConv = wipeTable(tempTable1)
		local skillConv = wipeTable(tempTable2)
		local add = wipeTable(tempTable3)
		local globalTotal, skillTotal = 0, 0
		for otherTypeIndex = damageTypeIndex + 1, #dmgTypeList do
			-- For all possible destination types, check for global and skill conversions
			otherType = dmgTypeList[otherTypeIndex]
			globalConv[otherType] = m_max(skillModList:Sum("BASE", skillCfg, damageType.."DamageConvertTo"..otherType, isElemental[damageType] and "ElementalDamageConvertTo"..otherType or nil, damageType ~= "Chaos" and "NonChaosDamageConvertTo"..otherType or nil), 0)
			globalTotal = globalTotal + globalConv[otherType]
			skillConv[otherType] = m_max(skillModList:Sum("BASE", skillCfg, "Skill"..damageType.."DamageConvertTo"..otherType), 0)
			skillTotal = skillTotal + skillConv[otherType]
			add[otherType] = m_max(skillModList:Sum("BASE", skillCfg, damageType.."DamageGainAs"..otherType, isElemental[damageType] and "ElementalDamageGainAs"..otherType or nil, damageType ~= "Chaos" and "NonChaosDamageGainAs"..otherType or nil), 0)
		end
		if skillTotal > 100 then
			-- Skill conversion exceeds 100%, scale it down and remove non-skill conversions
			local factor = 100 / skillTotal
			for type, val in pairs(skillConv) do
				-- Over-conversion is fixed in 3.0, so I finally get to uncomment this line!
				skillConv[type] = val * factor
			end
			for type, val in pairs(globalConv) do
				globalConv[type] = 0
			end
		elseif globalTotal + skillTotal > 100 then
			-- Conversion exceeds 100%, scale down non-skill conversions
			local factor = (100 - skillTotal) / globalTotal
			for type, val in pairs(globalConv) do
				globalConv[type] = val * factor
			end
			globalTotal = globalTotal * factor
		end
		local dmgTable = { }
		for type, val in pairs(globalConv) do
			dmgTable[type] = (globalConv[type] + skillConv[type] + add[type]) / 100
		end
		dmgTable.mult = 1 - m_min((globalTotal + skillTotal) / 100, 1)
		activeSkill.conversionTable[damageType] = dmgTable
	end
	activeSkill.conversionTable[dmgTypeList[#dmgTypeList]] = { mult = 1 }

	-- Configure damage passes
	local passList = { }
	t_insert(passList, {
		label = "Skill",
		source = skillData,
		cfg = skillCfg,
		output = output,
		breakdown = breakdown,
	})

	local storedMainHandAccuracy = nil
	local storedMainHandAccuracyVsEnemy = nil
	local storedSustainedTraumaBreakdown = { }
	-- Calculate how often you hit (speed, accuracy, block, etc)
	for _, pass in ipairs(passList) do
		globalOutput, globalBreakdown = output, breakdown
		local source, output, cfg, breakdown = pass.source, pass.output, pass.cfg, pass.breakdown

		if skillData.averageBurstHits then
			output.AverageBurstHits = skillData.averageBurstHits
		elseif output.Repeats and output.Repeats > 1 then
			output.AverageBurstHits = output.Repeats
		end

		-- Calculate hit chance
		local base = skillModList:Sum("BASE", cfg, "Accuracy")
		local baseVsEnemy = skillModList:Sum("BASE", cfg, "Accuracy", "AccuracyVsEnemy")
		local inc = skillModList:Sum("INC", cfg, "Accuracy")
		local incVsEnemy = skillModList:Sum("INC", cfg, "Accuracy", "AccuracyVsEnemy")
		local more = skillModList:More("MORE", cfg, "Accuracy")
		local moreVsEnemy = skillModList:More("MORE", cfg, "Accuracy", "AccuracyVsEnemy")

		output.Accuracy = m_max(0, m_floor(base * (1 + inc / 100) * more))
		local accuracyVsEnemy = m_max(0, m_floor(baseVsEnemy * (1 + incVsEnemy / 100) * moreVsEnemy))
		if breakdown then
			breakdown.Accuracy = { }
			breakdown.multiChain(breakdown.Accuracy, {
				base = { "%g ^8(base)", base },
				{ "%.2f ^8(increased/reduced)", 1 + inc / 100 },
				{ "%.2f ^8(more/less)", more },
				total = s_format("= %g", output.Accuracy)
			})
			if output.Accuracy ~= accuracyVsEnemy then
				t_insert(breakdown.Accuracy, s_format(""))
				breakdown.multiChain(breakdown.Accuracy, {
					label = "Effective Accuracy vs Enemy",
					base = { "%g ^8(base)", baseVsEnemy },
					{ "%.2f ^8(increased/reduced)", 1 + incVsEnemy / 100 },
					{ "%.2f ^8(more/less)", moreVsEnemy },
					total = s_format("= %g", accuracyVsEnemy)
				})
			end
		end
		if skillModList:Flag(nil, "Condition:OffHandAccuracyIsMainHandAccuracy") and pass.label == "Main Hand" then
			storedMainHandAccuracy = output.Accuracy
			storedMainHandAccuracyVsEnemy = accuracyVsEnemy
		elseif skillModList:Flag(nil, "Condition:OffHandAccuracyIsMainHandAccuracy") and pass.label == "Off Hand" and storedMainHandAccuracy then
			output.Accuracy = storedMainHandAccuracy
			accuracyVsEnemy = storedMainHandAccuracyVsEnemy
			if breakdown then
				breakdown.Accuracy = {
					"Using Main Hand Accuracy due to Mastery: "..output.Accuracy,
				}
			end
		end
		-- A hit cannot miss in Last Epoch
		output.AccuracyHitChance = 100
		--enemy block chance
		output.enemyBlockChance = m_max(m_min((enemyDB:Sum("BASE", cfg, "BlockChance") or 0), 100) - skillModList:Sum("BASE", cfg, "reduceEnemyBlock"), 0)
		if enemyDB:Flag(nil, "CannotBlockAttacks") and isAttack then
			output.enemyBlockChance = 0
		end

		output.HitChance = output.AccuracyHitChance * (1 - output.enemyBlockChance / 100)
		if output.enemyBlockChance > 0 and not isAttack then
			globalOutput.enemyHasSpellBlock = true
		end
		if breakdown and output.enemyBlockChance > 0 then
			if output.AccuracyHitChance < 100 then
				breakdown.HitChance = {
					"Accuracy Hit Chance: "..output.AccuracyHitChance.."%",
					"Enemy Block Chance: "..output.enemyBlockChance.."%",
					"Approximate hit chance: "..output.HitChance.."%",
				}
			else
				breakdown.HitChance = {
					"Enemy Block Chance: "..output.enemyBlockChance.."%",
					"Approximate hit chance: "..output.HitChance.."%",
				}
			end
		end

		-- Check Precise Technique Keystone condition per pass as MH/OH might have different values
		local condName = pass.label:gsub(" ", "") .. "AccRatingHigherThanMaxLife"
		skillModList.conditions[condName] = output.Accuracy > env.player.output.Life

		-- Calculate attack/cast speed
		if activeSkill.activeEffect.grantedEffect.castTime == 0 and not skillData.castTimeOverride and not skillData.triggered then
			output.Time = 0
			output.Speed = 0
		elseif skillData.timeOverride then
			output.Time = skillData.timeOverride
			output.Speed = 1 / output.Time
		elseif skillData.fixedCastTime then
			output.Time = activeSkill.activeEffect.grantedEffect.castTime
			output.Speed = 1 / output.Time
		elseif skillData.triggerTime and skillData.triggered then
			local activeSkillsLinked = skillModList:Sum("BASE", cfg, "ActiveSkillsLinkedToTrigger")
			if activeSkillsLinked > 0 then
				output.Time = skillData.triggerTime / (1 + skillModList:Sum("INC", cfg, "CooldownRecovery") / 100) * activeSkillsLinked
			else
				output.Time = skillData.triggerTime / (1 + skillModList:Sum("INC", cfg, "CooldownRecovery") / 100)
			end
			output.TriggerTime = output.Time
			output.Speed = 1 / output.Time
		elseif skillData.triggerRate and skillData.triggered then
			output.Time = 1 / skillData.triggerRate
			output.TriggerTime = output.Time
			output.Speed = skillData.triggerRate
			skillData.showAverage = false
		else
			local baseTime = skillData.castTimeOverride or activeSkill.activeEffect.grantedEffect.castTime or 1
			local more = skillModList:More(cfg, "Speed")
			output.Repeats = globalOutput.Repeats or 1
			local inc = skillModList:Sum("INC", cfg, "Speed")
			local attackRate = nil
			output.Speed = 1 / baseTime * round((1 + inc/100) * more, 2)
			if isAttack then
				attackRate = env.player.weaponData1.AttackRate
				output.Speed = output.Speed * attackRate
			end
			output.CastRate = output.Speed
			if skillFlags.selfCast then
				-- Self-cast skill; apply action speed
				output.Speed = output.Speed * globalOutput.ActionSpeedMod
				output.CastRate = output.Speed
			end
			if skillFlags.totem then
				-- Totem skill. Apply action speed
				local totemActionSpeed = 1 + (modDB:Sum("INC", nil, "TotemActionSpeed") / 100)
				output.TotemActionSpeed = totemActionSpeed
				output.Speed = output.Speed * totemActionSpeed
				output.CastRate = output.Speed
			end
			if globalOutput.Cooldown then
				output.Cooldown = globalOutput.Cooldown
				output.Speed = m_min(output.Speed, 1 / output.Cooldown * output.Repeats)
			end
			if output.Cooldown and skillFlags.selfCast then
				skillFlags.notAverage = true
				skillFlags.showAverage = false
				skillData.showAverage = false
			end
			if output.Speed == 0 then
				output.Time = 0
			else
				output.Time = 1 / output.Speed
			end
			if breakdown then
				breakdown.Speed = { }
				breakdown.multiChain(breakdown.Speed, {
					base = { "%.2f ^8(base)", 1 / baseTime },
					{ "%.2f ^8weapon attack rate", attackRate },
					{ "%.2f ^8(increased/reduced)", 1 + inc/100 },
					{ "%.2f ^8(more/less)", more },
					{ "%.2f ^8(action speed modifier)", (skillFlags.totem and output.TotemActionSpeed) or (skillFlags.selfCast and globalOutput.ActionSpeedMod) or 1 },
					total = s_format("= %.2f ^8casts per second", output.CastRate)
				})
				if output.Cooldown and (1 / output.Cooldown) < output.CastRate then
					t_insert(breakdown.Speed, s_format("\n"))
					t_insert(breakdown.Speed, s_format("1 / %.2f ^8(skill cooldown)", output.Cooldown))
					if output.Repeats > 1 then
						t_insert(breakdown.Speed, s_format("x %d ^8(repeat count)", output.Repeats))
					end
					t_insert(breakdown.Speed, s_format("= %.2f ^8(casts per second)", output.Repeats / output.Cooldown))
					t_insert(breakdown.Speed, s_format("\n"))
					t_insert(breakdown.Speed, s_format("= %.2f ^8(lower of cast rates)", output.Speed))
				end
			end
			if breakdown and calcLib.mod(skillModList, skillCfg, "SkillAttackTime") > 0 then
				breakdown.Time = { }
				breakdown.multiChain(breakdown.Time, {
					base = { "%.2f ^8(base)", 1 / (output.Speed * calcLib.mod(skillModList, skillCfg, "SkillAttackTime") ) },
					{ "%.2f ^8(total modifier)", calcLib.mod(skillModList, skillCfg, "SkillAttackTime")  },
					total = s_format("= %.2f ^8seconds per attack", output.Time)
				})
			end
		end
		if skillData.hitTimeOverride and not skillData.triggeredOnDeath then
			output.HitTime = skillData.hitTimeOverride
			output.HitSpeed = 1 / output.HitTime
			--Brands always have hitTimeOverride
			if skillFlags.brand and not skillModList:Flag(nil, "UnlimitedBrandDuration") then
				output.BrandTicks = m_floor(output.Duration * output.HitSpeed)
			end
		elseif skillData.hitTimeMultiplier and output.Time and not skillData.triggeredOnDeath then
			output.HitTime = output.Time * skillData.hitTimeMultiplier
			if output.Cooldown and skillData.triggered then
				output.HitSpeed = 1 / (m_max(output.HitTime, output.Cooldown))
			elseif output.Cooldown then
				output.HitSpeed = 1 / (output.HitTime + output.Cooldown)
			else
				output.HitSpeed = 1 / output.HitTime
			end
		end
	end
	-- Other Misc DPS multipliers (like custom source)
	skillData.dpsMultiplier = ( skillData.dpsMultiplier or 1 ) * ( 1 + skillModList:Sum("INC", skillCfg, "DPS") / 100 ) * skillModList:More(skillCfg, "DPS")
	if env.configInput.repeatMode == "FINAL" or skillModList:Flag(nil, "OnlyFinalRepeat") then
		skillData.dpsMultiplier = skillData.dpsMultiplier / (output.Repeats or 1)
	end
	if skillModList:Flag(nil, "TriggeredBySnipe") then
		skillFlags.channelRelease = true
	end
	if breakdown then
		breakdown.SustainableTrauma = storedSustainedTraumaBreakdown
	end
	output.SustainableTrauma = skillModList:Flag(nil, "HasTrauma") and skillModList:Sum("BASE", skillCfg, "Multiplier:SustainableTraumaStacks")
	--Mantra of Flames buff count
	modDB.multipliers["BuffOnSelf"] = (modDB.multipliers["BuffOnSelf"] or 0) + skillModList:Sum("BASE", cfg, "Multiplier:TraumaStacks")
	modDB.multipliers["BuffOnSelf"] = (modDB.multipliers["BuffOnSelf"] or 0) + skillModList:Sum("BASE", cfg, "Multiplier:VoltaxicWaitingStages")
	if breakdown then
		if skillData.hitTimeOverride and not skillData.triggeredOnDeath then
			breakdown.HitSpeed = { }
			t_insert(breakdown.HitSpeed, s_format("1 / %.2f ^8(hit time override)", output.HitTime))
			t_insert(breakdown.HitSpeed, s_format("= %.2f", output.HitSpeed))
		elseif skillData.hitTimeMultiplier and output.Time and not skillData.triggeredOnDeath then
			breakdown.HitTime = { }
			if m_floor(skillData.hitTimeMultiplier) ~= skillData.hitTimeMultiplier then
				t_insert(breakdown.HitTime, s_format(colorCodes.CUSTOM.."NOTE: First stage has a %.2fx channel time multiplier", skillData.hitTimeMultiplier - m_floor(skillData.hitTimeMultiplier)))
			end
			if isAttack then
				t_insert(breakdown.HitTime, s_format("%.2f ^8(attack time)", output.Time))
			else
				t_insert(breakdown.HitTime, s_format("%.2f ^8(cast time)", output.Time))
			end
			t_insert(breakdown.HitTime, s_format("x %.2f ^8(channel time multiplier)", skillData.hitTimeMultiplier))
			t_insert(breakdown.HitTime, s_format("= %.2f", output.HitTime))
			breakdown.HitSpeed = { }
			if output.Cooldown and skillData.triggered then
				t_insert(breakdown.HitSpeed, s_format("1 / min(%.2f, %.2f) ^8min(hit time, cooldown)", output.HitTime, output.Cooldown))
			elseif output.Cooldown then
				t_insert(breakdown.HitSpeed, s_format("1 / (%.2f + %.2f) ^8(hit time + cooldown)", output.HitTime, output.Cooldown))
			else
				t_insert(breakdown.HitSpeed, s_format("1 / %.2f ^8(hit time)", output.HitTime))
			end
			t_insert(breakdown.HitSpeed, s_format("= %.2f", output.HitSpeed))
		end
	end

	-- Grab quantity multiplier
	local quantityMultiplier = m_max(activeSkill.skillModList:Sum("BASE", activeSkill.skillCfg, "QuantityMultiplier"), 1)
	if quantityMultiplier > 1 then
		output.QuantityMultiplier = quantityMultiplier
	end

	--Calculate damage (exerts, crits, ruthless, DPS, etc)
	for _, pass in ipairs(passList) do
		globalOutput, globalBreakdown = output, breakdown
		local source, output, cfg, breakdown = pass.source, pass.output, pass.cfg, pass.breakdown

		-- Exerted Attack members
		local exertedDoubleDamage = env.modDB:Sum("BASE", cfg, "ExertDoubleDamageChance")
		globalOutput.OffensiveWarcryEffect = 1
		globalOutput.MaxOffensiveWarcryEffect = 1
		globalOutput.TheoreticalOffensiveWarcryEffect = 1
		globalOutput.TheoreticalMaxOffensiveWarcryEffect = 1
		globalOutput.RallyingHitEffect = 1
		globalOutput.AilmentWarcryEffect = 1

		if env.mode_buffs then
			-- Iterative over all the active skills to account for exerted attacks provided by warcries
			if (activeSkill.activeEffect.grantedEffect.name == "Vaal Ground Slam" or not activeSkill.skillTypes[SkillType.Vaal]) and not activeSkill.skillTypes[SkillType.Triggered] and not activeSkill.skillTypes[SkillType.Channel] and not activeSkill.skillTypes[SkillType.OtherThingUsesSkill] and not activeSkill.skillModList:Flag(cfg, "SupportedByMultistrike") then
				for index, value in ipairs(actor.activeSkillList) do
					if value.activeEffect.grantedEffect.name == "Ancestral Cry" and activeSkill.skillTypes[SkillType.MeleeSingleTarget] and not globalOutput.AncestralCryCalculated then
						globalOutput.AncestralCryDuration = calcSkillDuration(value.skillModList, value.skillCfg, value.skillData, env, enemyDB)
						globalOutput.AncestralCryCooldown = calcSkillCooldown(value.skillModList, value.skillCfg, value.skillData)
						output.GlobalWarcryCooldown = env.modDB:Sum("BASE", nil, "GlobalWarcryCooldown")
						output.GlobalWarcryCount = env.modDB:Sum("BASE", nil, "GlobalWarcryCount")
						if modDB:Flag(nil, "WarcryShareCooldown") then
							globalOutput.AncestralCryCooldown = globalOutput.AncestralCryCooldown + (output.GlobalWarcryCooldown - globalOutput.AncestralCryCooldown) / output.GlobalWarcryCount
						end
						globalOutput.AncestralCryCastTime = calcWarcryCastTime(value.skillModList, value.skillCfg, actor)
						globalOutput.AncestralExertsCount = env.modDB:Sum("BASE", nil, "NumAncestralExerts") or 0
						local baseUptimeRatio = m_min((globalOutput.AncestralExertsCount / output.Speed) / (globalOutput.AncestralCryCooldown + globalOutput.AncestralCryCastTime), 1) * 100
						local storedUses = value.skillData.storedUses + value.skillModList:Sum("BASE", value.skillCfg, "AdditionalCooldownUses")
						globalOutput.AncestralUpTimeRatio = m_min(100, baseUptimeRatio * storedUses)
						if globalBreakdown then
							globalBreakdown.AncestralUpTimeRatio = { }
							t_insert(globalBreakdown.AncestralUpTimeRatio, s_format("(%d ^8(number of exerts)", globalOutput.AncestralExertsCount))
							t_insert(globalBreakdown.AncestralUpTimeRatio, s_format("/ %.2f) ^8(attacks per second)", output.Speed))
							if globalOutput.AncestralCryCastTime > 0 then
								t_insert(globalBreakdown.AncestralUpTimeRatio, s_format("/ (%.2f ^8(warcry cooldown)", globalOutput.AncestralCryCooldown))
								t_insert(globalBreakdown.AncestralUpTimeRatio, s_format("+ %.2f) ^8(warcry casttime)", globalOutput.AncestralCryCastTime))
							else
								t_insert(globalBreakdown.AncestralUpTimeRatio, s_format("/ %.2f ^8(average warcry cooldown)", globalOutput.AncestralCryCooldown))
							end
							t_insert(globalBreakdown.AncestralUpTimeRatio, s_format("= %d%%", globalOutput.AncestralUpTimeRatio))
						end
						globalOutput.AncestralCryCalculated = true
					elseif value.activeEffect.grantedEffect.name == "Infernal Cry" and not globalOutput.InfernalCryCalculated then
						globalOutput.InfernalCryDuration = calcSkillDuration(value.skillModList, value.skillCfg, value.skillData, env, enemyDB)
						globalOutput.InfernalCryCooldown = calcSkillCooldown(value.skillModList, value.skillCfg, value.skillData)
						output.GlobalWarcryCooldown = env.modDB:Sum("BASE", nil, "GlobalWarcryCooldown")
						output.GlobalWarcryCount = env.modDB:Sum("BASE", nil, "GlobalWarcryCount")
						if modDB:Flag(nil, "WarcryShareCooldown") then
							globalOutput.InfernalCryCooldown = globalOutput.InfernalCryCooldown + (output.GlobalWarcryCooldown - globalOutput.InfernalCryCooldown) / output.GlobalWarcryCount
						end
						globalOutput.InfernalCryCastTime = calcWarcryCastTime(value.skillModList, value.skillCfg, actor)
						if activeSkill.skillTypes[SkillType.Melee] then
							globalOutput.InfernalExertsCount = env.modDB:Sum("BASE", nil, "NumInfernalExerts") or 0
							local baseUptimeRatio = m_min((globalOutput.InfernalExertsCount / output.Speed) / (globalOutput.InfernalCryCooldown + globalOutput.InfernalCryCastTime), 1) * 100
							local storedUses = value.skillData.storedUses + value.skillModList:Sum("BASE", value.skillCfg, "AdditionalCooldownUses")
							globalOutput.InfernalUpTimeRatio = m_min(100, baseUptimeRatio * storedUses)
							if globalBreakdown then
								globalBreakdown.InfernalUpTimeRatio = { }
								t_insert(globalBreakdown.InfernalUpTimeRatio, s_format("(%d ^8(number of exerts)", globalOutput.InfernalExertsCount))
								t_insert(globalBreakdown.InfernalUpTimeRatio, s_format("/ %.2f) ^8(attacks per second)", output.Speed))
								if globalOutput.InfernalCryCastTime > 0 then
									t_insert(globalBreakdown.InfernalUpTimeRatio, s_format("/ (%.2f ^8(warcry cooldown)", globalOutput.InfernalCryCooldown))
									t_insert(globalBreakdown.InfernalUpTimeRatio, s_format("+ %.2f) ^8(warcry casttime)", globalOutput.InfernalCryCastTime))
								else
									t_insert(globalBreakdown.InfernalUpTimeRatio, s_format("/ %.2f ^8(average warcry cooldown)", globalOutput.InfernalCryCooldown))
								end
								t_insert(globalBreakdown.InfernalUpTimeRatio, s_format("= %d%%", globalOutput.InfernalUpTimeRatio))
							end
						end
						globalOutput.InfernalCryCalculated = true
					elseif value.activeEffect.grantedEffect.name == "Intimidating Cry" and activeSkill.skillTypes[SkillType.Melee] and not globalOutput.IntimidatingCryCalculated then
						globalOutput.CreateWarcryOffensiveCalcSection = true
						globalOutput.IntimidatingCryDuration = calcSkillDuration(value.skillModList, value.skillCfg, value.skillData, env, enemyDB)
						globalOutput.IntimidatingCryCooldown = calcSkillCooldown(value.skillModList, value.skillCfg, value.skillData)
						output.GlobalWarcryCooldown = env.modDB:Sum("BASE", nil, "GlobalWarcryCooldown")
						output.GlobalWarcryCount = env.modDB:Sum("BASE", nil, "GlobalWarcryCount")
						if modDB:Flag(nil, "WarcryShareCooldown") then
							globalOutput.IntimidatingCryCooldown = globalOutput.IntimidatingCryCooldown + (output.GlobalWarcryCooldown - globalOutput.IntimidatingCryCooldown) / output.GlobalWarcryCount
						end
						globalOutput.IntimidatingCryCastTime = calcWarcryCastTime(value.skillModList, value.skillCfg, actor)
						globalOutput.IntimidatingExertsCount = env.modDB:Sum("BASE", nil, "NumIntimidatingExerts") or 0
						local baseUptimeRatio = m_min((globalOutput.IntimidatingExertsCount / output.Speed) / (globalOutput.IntimidatingCryCooldown + globalOutput.IntimidatingCryCastTime), 1) * 100
						local storedUses = value.skillData.storedUses + value.skillModList:Sum("BASE", value.skillCfg, "AdditionalCooldownUses")
						globalOutput.IntimidatingUpTimeRatio = m_min(100, baseUptimeRatio * storedUses)
						if globalBreakdown then
							globalBreakdown.IntimidatingUpTimeRatio = { }
							t_insert(globalBreakdown.IntimidatingUpTimeRatio, s_format("(%d ^8(number of exerts)", globalOutput.IntimidatingExertsCount))
							t_insert(globalBreakdown.IntimidatingUpTimeRatio, s_format("/ %.2f) ^8(attacks per second)", output.Speed))
							if 	globalOutput.IntimidatingCryCastTime > 0 then
								t_insert(globalBreakdown.IntimidatingUpTimeRatio, s_format("/ (%.2f ^8(warcry cooldown)", globalOutput.IntimidatingCryCooldown))
								t_insert(globalBreakdown.IntimidatingUpTimeRatio, s_format("+ %.2f) ^8(warcry casttime)", globalOutput.IntimidatingCryCastTime))
							else
								t_insert(globalBreakdown.IntimidatingUpTimeRatio, s_format("/ %.2f ^8(average warcry cooldown)", globalOutput.IntimidatingCryCooldown))
							end
							t_insert(globalBreakdown.IntimidatingUpTimeRatio, s_format("= %d%%", globalOutput.IntimidatingUpTimeRatio))
						end
						local ddChance = m_min(skillModList:Sum("BASE", cfg, "DoubleDamageChance") + (env.mode_effective and enemyDB:Sum("BASE", cfg, "SelfDoubleDamageChance") or 0) + exertedDoubleDamage, 100)
						globalOutput.IntimidatingAvgDmg = 2 * (1 - ddChance / 100) -- 1
						if globalBreakdown then
							globalBreakdown.IntimidatingAvgDmg = {
								"Average Intimidating Cry Damage:",
								s_format("%.2f%% ^8(base double damage increase to hit 100%%)", (1 - ddChance / 100) * 100 ),
								s_format("x %d ^8(double damage multiplier)", 2),
								s_format("= %.2f", globalOutput.IntimidatingAvgDmg),
							}
						end
						globalOutput.IntimidatingHitEffect = 1 + globalOutput.IntimidatingAvgDmg * globalOutput.IntimidatingUpTimeRatio / 100
						globalOutput.IntimidatingMaxHitEffect = 1 + globalOutput.IntimidatingAvgDmg
						if globalBreakdown then
							globalBreakdown.IntimidatingHitEffect = {
								s_format("1 + (%.2f ^8(average exerted damage)", globalOutput.IntimidatingAvgDmg),
								s_format("x %.2f) ^8(uptime %%)", globalOutput.IntimidatingUpTimeRatio / 100),
								s_format("= %.2f", globalOutput.IntimidatingHitEffect),
							}
						end

						globalOutput.TheoreticalOffensiveWarcryEffect = globalOutput.TheoreticalOffensiveWarcryEffect * globalOutput.IntimidatingHitEffect
						globalOutput.TheoreticalMaxOffensiveWarcryEffect = globalOutput.TheoreticalMaxOffensiveWarcryEffect * globalOutput.IntimidatingMaxHitEffect
						globalOutput.IntimidatingCryCalculated = true
					elseif value.activeEffect.grantedEffect.name == "Rallying Cry" and activeSkill.skillTypes[SkillType.Melee] and not globalOutput.RallyingCryCalculated then
						globalOutput.CreateWarcryOffensiveCalcSection = true
						globalOutput.RallyingCryDuration = calcSkillDuration(value.skillModList, value.skillCfg, value.skillData, env, enemyDB)
						globalOutput.RallyingCryCooldown = calcSkillCooldown(value.skillModList, value.skillCfg, value.skillData)
						output.GlobalWarcryCooldown = env.modDB:Sum("BASE", nil, "GlobalWarcryCooldown")
						output.GlobalWarcryCount = env.modDB:Sum("BASE", nil, "GlobalWarcryCount")
						if modDB:Flag(nil, "WarcryShareCooldown") then
							globalOutput.RallyingCryCooldown = globalOutput.RallyingCryCooldown + (output.GlobalWarcryCooldown - globalOutput.RallyingCryCooldown) / output.GlobalWarcryCount
						end
						globalOutput.RallyingCryCastTime = calcWarcryCastTime(value.skillModList, value.skillCfg, actor)
						globalOutput.RallyingExertsCount = env.modDB:Sum("BASE", nil, "NumRallyingExerts") or 0
						local baseUptimeRatio = m_min((globalOutput.RallyingExertsCount / output.Speed) / (globalOutput.RallyingCryCooldown + globalOutput.RallyingCryCastTime), 1) * 100
						local storedUses = value.skillData.storedUses + value.skillModList:Sum("BASE", value.skillCfg, "AdditionalCooldownUses")
						globalOutput.RallyingUpTimeRatio = m_min(100, baseUptimeRatio * storedUses)
						if globalBreakdown then
							globalBreakdown.RallyingUpTimeRatio = { }
							t_insert(globalBreakdown.RallyingUpTimeRatio, s_format("(%d ^8(number of exerts)", globalOutput.RallyingExertsCount))
							t_insert(globalBreakdown.RallyingUpTimeRatio, s_format("/ %.2f) ^8(attacks per second)", output.Speed))
							if 	globalOutput.RallyingCryCastTime > 0 then
								t_insert(globalBreakdown.RallyingUpTimeRatio, s_format("/ (%.2f ^8(warcry cooldown)", globalOutput.RallyingCryCooldown))
								t_insert(globalBreakdown.RallyingUpTimeRatio, s_format("+ %.2f) ^8(warcry casttime)", globalOutput.RallyingCryCastTime))
							else
								t_insert(globalBreakdown.RallyingUpTimeRatio, s_format("/ %.2f ^8(average warcry cooldown)", globalOutput.RallyingCryCooldown))
							end
							t_insert(globalBreakdown.RallyingUpTimeRatio, s_format("= %d%%", globalOutput.RallyingUpTimeRatio))
						end
						globalOutput.RallyingAvgDmg = m_min(env.modDB:Sum("BASE", cfg, "Multiplier:NearbyAlly"), 5) * (env.modDB:Sum("BASE", nil, "RallyingExertMoreDamagePerAlly") / 100)
						if globalBreakdown then
							globalBreakdown.RallyingAvgDmg = {
								"Average Rallying Cry Damage:",
								s_format("%.2f ^8(average damage multiplier per ally)", env.modDB:Sum("BASE", nil, "RallyingExertMoreDamagePerAlly") / 100),
								s_format("x %d ^8(number of nearby allies (max=5))", m_min(env.modDB:Sum("BASE", cfg, "Multiplier:NearbyAlly"), 5)),
								s_format("= %.2f", globalOutput.RallyingAvgDmg),
							}
						end
						globalOutput.RallyingHitEffect = 1 + globalOutput.RallyingAvgDmg * globalOutput.RallyingUpTimeRatio / 100
						globalOutput.RallyingMaxHitEffect = 1 + globalOutput.RallyingAvgDmg
						if globalBreakdown then
							globalBreakdown.RallyingHitEffect = {
								s_format("1 + (%.2f ^8(average exerted damage)", globalOutput.RallyingAvgDmg),
								s_format("x %.2f) ^8(uptime %%)", globalOutput.RallyingUpTimeRatio / 100),
								s_format("= %.2f", globalOutput.RallyingHitEffect),
							}
						end
						globalOutput.OffensiveWarcryEffect = globalOutput.OffensiveWarcryEffect * globalOutput.RallyingHitEffect
						globalOutput.MaxOffensiveWarcryEffect = globalOutput.MaxOffensiveWarcryEffect * globalOutput.RallyingMaxHitEffect
						globalOutput.TheoreticalOffensiveWarcryEffect = globalOutput.TheoreticalOffensiveWarcryEffect * globalOutput.RallyingHitEffect
						globalOutput.TheoreticalMaxOffensiveWarcryEffect = globalOutput.TheoreticalMaxOffensiveWarcryEffect * globalOutput.RallyingMaxHitEffect
						globalOutput.RallyingCryCalculated = true

					elseif value.activeEffect.grantedEffect.name == "Seismic Cry" and activeSkill.skillTypes[SkillType.Slam] and not globalOutput.SeismicCryCalculated then
						globalOutput.CreateWarcryOffensiveCalcSection = true
						globalOutput.SeismicCryDuration = calcSkillDuration(value.skillModList, value.skillCfg, value.skillData, env, enemyDB)
						globalOutput.SeismicCryCooldown = calcSkillCooldown(value.skillModList, value.skillCfg, value.skillData)
						output.GlobalWarcryCooldown = env.modDB:Sum("BASE", nil, "GlobalWarcryCooldown")
						output.GlobalWarcryCount = env.modDB:Sum("BASE", nil, "GlobalWarcryCount")
						if modDB:Flag(nil, "WarcryShareCooldown") then
							globalOutput.SeismicCryCooldown = globalOutput.SeismicCryCooldown + (output.GlobalWarcryCooldown - globalOutput.SeismicCryCooldown) / output.GlobalWarcryCount
						end
						globalOutput.SeismicCryCastTime = calcWarcryCastTime(value.skillModList, value.skillCfg, actor)
						globalOutput.SeismicExertsCount = env.modDB:Sum("BASE", nil, "NumSeismicExerts") or 0
						local baseUptimeRatio = m_min((globalOutput.SeismicExertsCount / output.Speed) / (globalOutput.SeismicCryCooldown + globalOutput.SeismicCryCastTime), 1) * 100
						local storedUses = value.skillData.storedUses + value.skillModList:Sum("BASE", value.skillCfg, "AdditionalCooldownUses")
						globalOutput.SeismicUpTimeRatio = m_min(100, baseUptimeRatio * storedUses)
						if globalBreakdown then
							globalBreakdown.SeismicUpTimeRatio = { }
							t_insert(globalBreakdown.SeismicUpTimeRatio, s_format("(%d ^8(number of exerts)", globalOutput.SeismicExertsCount))
							t_insert(globalBreakdown.SeismicUpTimeRatio, s_format("/ %.2f) ^8(attacks per second)", output.Speed))
							if 	globalOutput.SeismicCryCastTime > 0 then
								t_insert(globalBreakdown.SeismicUpTimeRatio, s_format("/ (%.2f ^8(warcry cooldown)", globalOutput.SeismicCryCooldown))
								t_insert(globalBreakdown.SeismicUpTimeRatio, s_format("+ %.2f) ^8(warcry casttime)", globalOutput.SeismicCryCastTime))
							else
								t_insert(globalBreakdown.SeismicUpTimeRatio, s_format("/ %.2f ^8(average warcry cooldown)", globalOutput.SeismicCryCooldown))
							end
							t_insert(globalBreakdown.SeismicUpTimeRatio, s_format("= %d%%", globalOutput.SeismicUpTimeRatio))
						end
						-- calculate the stacking AoE modifier of Seismic slams
						local SeismicAoEPerExert = env.modDB:Sum("BASE", cfg, "SeismicIncAoEPerExert") / 100
						local AoEImpact = 0
						local MaxSingleAoEImpact = 0
						for i = 1, globalOutput.SeismicExertsCount do
							AoEImpact = AoEImpact + (i * SeismicAoEPerExert)
							MaxSingleAoEImpact = MaxSingleAoEImpact + SeismicAoEPerExert
						end
						local AvgAoEImpact = AoEImpact / globalOutput.SeismicExertsCount

						-- account for AoE increase
						if activeSkill.skillModList:Flag(nil, "Condition:WarcryMaxHit") then
							skillModList:NewMod("AreaOfEffect", "INC", MaxSingleAoEImpact * 100, "Max Seismic Exert AoE")
						else
							skillModList:NewMod("AreaOfEffect", "INC", m_floor(AvgAoEImpact * globalOutput.SeismicUpTimeRatio), "Avg Seismic Exert AoE")
						end
						calcAreaOfEffect(skillModList, skillCfg, skillData, skillFlags, globalOutput, globalBreakdown)
						globalOutput.SeismicCryCalculated = true
					elseif value.activeEffect.grantedEffect.name == "Battlemage's Cry" and not globalOutput.BattleMageCryCalculated then
						globalOutput.BattleMageCryDuration = calcSkillDuration(value.skillModList, value.skillCfg, value.skillData, env, enemyDB)
						globalOutput.BattleMageCryCooldown = calcSkillCooldown(value.skillModList, value.skillCfg, value.skillData)
						output.GlobalWarcryCooldown = env.modDB:Sum("BASE", nil, "GlobalWarcryCooldown")
						output.GlobalWarcryCount = env.modDB:Sum("BASE", nil, "GlobalWarcryCount")
						if modDB:Flag(nil, "WarcryShareCooldown") then
							globalOutput.BattleMageCryCooldown = globalOutput.BattleMageCryCooldown + (output.GlobalWarcryCooldown - globalOutput.BattleMageCryCooldown) / output.GlobalWarcryCount
						end
						globalOutput.BattleMageCryCastTime = calcWarcryCastTime(value.skillModList, value.skillCfg, actor)
						if activeSkill.skillTypes[SkillType.Melee] then
							globalOutput.BattleCryExertsCount = env.modDB:Sum("BASE", nil, "NumBattlemageExerts") or 0
							local baseUptimeRatio = m_min((globalOutput.BattleCryExertsCount / output.Speed) / (globalOutput.BattleMageCryCooldown + globalOutput.BattleMageCryCastTime), 1) * 100
							local storedUses = value.skillData.storedUses + value.skillModList:Sum("BASE", value.skillCfg, "AdditionalCooldownUses")
							globalOutput.BattlemageUpTimeRatio = m_min(100, baseUptimeRatio * storedUses)
							if globalBreakdown then
								globalBreakdown.BattlemageUpTimeRatio = { }
								t_insert(globalBreakdown.BattlemageUpTimeRatio, s_format("(%d ^8(number of exerts)", globalOutput.BattleCryExertsCount))
								t_insert(globalBreakdown.BattlemageUpTimeRatio, s_format("/ %.2f) ^8(attacks per second)", output.Speed))
								if globalOutput.BattleMageCryCastTime > 0 then
									t_insert(globalBreakdown.BattlemageUpTimeRatio, s_format("/ (%.2f ^8(warcry cooldown)", globalOutput.BattleMageCryCooldown))
									t_insert(globalBreakdown.BattlemageUpTimeRatio, s_format("+ %.2f) ^8(warcry casttime)", globalOutput.BattleMageCryCastTime))
								else
									t_insert(globalBreakdown.BattlemageUpTimeRatio, s_format("/ %.2f ^8(average warcry cooldown)", globalOutput.BattleMageCryCooldown))
								end
								t_insert(globalBreakdown.BattlemageUpTimeRatio, s_format("= %d%%", globalOutput.BattlemageUpTimeRatio))
							end
						end
						globalOutput.BattleMageCryCalculated = true
					end
				end

				if activeSkill.skillModList:Flag(nil, "Condition:WarcryMaxHit") then
					globalOutput.AilmentWarcryEffect = globalOutput.MaxOffensiveWarcryEffect
					skillData.showAverage = true
					skillFlags.showAverage = true
					skillFlags.notAverage = false
				else
					globalOutput.AilmentWarcryEffect = globalOutput.OffensiveWarcryEffect
				end

				-- Calculate Exerted Attack Uptime
				-- There are various strategies a player could use to maximize either warcry effect stacking or staggering
				-- 1) they don't pay attention and therefore we calculated exerted attack uptime as just the maximum uptime of any enabled warcries that exert attacks
				local warcryList = {"AncestralUpTimeRatio", "InfernalUpTimeRatio", "IntimidatingUpTimeRatio", "RallyingUpTimeRatio", "SeismicUpTimeRatio", "BattlemageUpTimeRatio"}
				for _, cryTimeRatio in ipairs(warcryList) do
					globalOutput.ExertedAttackUptimeRatio = m_max(globalOutput.ExertedAttackUptimeRatio or 0, globalOutput[cryTimeRatio] or 0)
				end
				if globalBreakdown then
					globalBreakdown.ExertedAttackUptimeRatio = { }
					t_insert(globalBreakdown.ExertedAttackUptimeRatio, s_format("Maximum of:"))
					for _, cryTimeRatio in ipairs(warcryList) do
						if globalOutput[cryTimeRatio] then
							t_insert(globalBreakdown.ExertedAttackUptimeRatio, s_format("%d%% ^8(%s Cry Uptime)", globalOutput[cryTimeRatio] or 0, cryTimeRatio:match("(.+)Up.*")))
						end
					end
					t_insert(globalBreakdown.ExertedAttackUptimeRatio, s_format("= %d%%", globalOutput.ExertedAttackUptimeRatio))
				end
				if globalOutput.ExertedAttackUptimeRatio > 0 then
					local incExertedAttacks = skillModList:Sum("INC", cfg, "ExertIncrease")
					local moreExertedAttacks = skillModList:Sum("MORE", cfg, "ExertIncrease")
					local moreExertedAttackDamage = skillModList:Sum("MORE", cfg, "ExertAttackIncrease")
					if activeSkill.skillModList:Flag(nil, "Condition:WarcryMaxHit") then
						skillModList:NewMod("Damage", "INC", incExertedAttacks, "Exerted Attacks")
						skillModList:NewMod("Damage", "MORE", moreExertedAttacks, "Exerted Attacks")
						skillModList:NewMod("Damage", "MORE", moreExertedAttackDamage, "Exerted Attack Damage", ModFlag.Attack)
					else
						skillModList:NewMod("Damage", "INC", incExertedAttacks * globalOutput.ExertedAttackUptimeRatio / 100, "Uptime Scaled Exerted Attacks")
						skillModList:NewMod("Damage", "MORE", moreExertedAttacks * globalOutput.ExertedAttackUptimeRatio / 100, "Uptime Scaled Exerted Attacks")
						skillModList:NewMod("Damage", "MORE", moreExertedAttackDamage * globalOutput.ExertedAttackUptimeRatio / 100, "Uptime Scaled Exerted Attack Damage", ModFlag.Attack)
					end
					globalOutput.ExertedAttackAvgDmg = calcLib.mod(skillModList, skillCfg, "ExertIncrease")
					globalOutput.ExertedAttackAvgDmg = globalOutput.ExertedAttackAvgDmg * calcLib.mod(skillModList, skillCfg, "ExertAttackIncrease")
					globalOutput.ExertedAttackHitEffect = globalOutput.ExertedAttackAvgDmg * globalOutput.ExertedAttackUptimeRatio / 100
					globalOutput.ExertedAttackMaxHitEffect = globalOutput.ExertedAttackAvgDmg
					if globalBreakdown then
						globalBreakdown.ExertedAttackHitEffect = {
							s_format("(%.2f ^8(average exerted damage)", globalOutput.ExertedAttackAvgDmg),
							s_format("x %.2f) ^8(uptime %%)", globalOutput.ExertedAttackUptimeRatio / 100),
							s_format("= %.2f", globalOutput.ExertedAttackHitEffect),
						}
					end
				end
			end
		end

		output.RuthlessBlowHitEffect = 1
		output.RuthlessBlowAilmentEffect = 1
		output.FistOfWarHitEffect = 1
		output.FistOfWarAilmentEffect = 1
		if env.mode_combat then
			local ruthlessEffect = env.configInput.ruthlessSupportMode or "AVERAGE"
			-- Calculate Ruthless Blow chance/multipliers + Fist of War multipliers
			output.RuthlessBlowMaxCount = skillModList:Sum("BASE", cfg, "RuthlessBlowMaxCount")
			if output.RuthlessBlowMaxCount > 0 and ( not skillCfg.skillCond["usedByMirage"] or (skillData.mirageUses or 0) > output.RuthlessBlowMaxCount ) then
				if ruthlessEffect == "AVERAGE" then
					output.RuthlessBlowChance = round(100 / output.RuthlessBlowMaxCount)
				elseif ruthlessEffect == "MAX" then
					output.RuthlessBlowChance = 100
					skillData.dpsMultiplier = skillData.dpsMultiplier / (output.RuthlessBlowMaxCount or 1)
				end
			else
				output.RuthlessBlowChance = 0
			end
			output.RuthlessBlowHitMultiplier = 1 + skillModList:Sum("BASE", cfg, "RuthlessBlowHitMultiplier") / 100
			output.RuthlessBlowAilmentMultiplier = 1 + skillModList:Sum("BASE", cfg, "RuthlessBlowAilmentMultiplier") / 100
			output.RuthlessBlowHitEffect = 1 - output.RuthlessBlowChance / 100 + output.RuthlessBlowChance / 100 * output.RuthlessBlowHitMultiplier
			output.RuthlessBlowAilmentEffect = 1 - output.RuthlessBlowChance / 100 + output.RuthlessBlowChance / 100 * output.RuthlessBlowAilmentMultiplier

			globalOutput.FistOfWarCooldown = skillModList:Sum("BASE", cfg, "FistOfWarCooldown") or 0
			-- If Fist of War & Active Skill is a Slam Skill & NOT a Vaal Skill & NOT used by mirage or other
			if globalOutput.FistOfWarCooldown ~= 0 and activeSkill.skillTypes[SkillType.Slam] and not activeSkill.skillTypes[SkillType.Vaal] and not activeSkill.skillTypes[SkillType.OtherThingUsesSkill] then
				globalOutput.FistOfWarHitMultiplier = skillModList:Sum("BASE", nil, "FistOfWarHitMultiplier") / 100
				globalOutput.FistOfWarAilmentMultiplier = skillModList:Sum("BASE", nil, "FistOfWarAilmentMultiplier") / 100
				globalOutput.FistOfWarUptimeRatio = m_min( (1 / output.Speed) / globalOutput.FistOfWarCooldown, 1) * 100
				if globalBreakdown then
					globalBreakdown.FistOfWarUptimeRatio = {
						s_format("min( (1 / %.2f) ^8(second per attack)", output.Speed),
						s_format("/ %.2f, 1) ^8(fist of war cooldown)", globalOutput.FistOfWarCooldown),
						s_format("= %d%%", globalOutput.FistOfWarUptimeRatio),
					}
				end
				globalOutput.AvgFistOfWarHit = globalOutput.FistOfWarHitMultiplier
				globalOutput.AvgFistOfWarHitEffect = 1 + globalOutput.FistOfWarHitMultiplier * (globalOutput.FistOfWarUptimeRatio / 100)
				if globalBreakdown then
					globalBreakdown.AvgFistOfWarHitEffect = {
						s_format("1 + (%.2f ^8(fist of war hit multiplier)", globalOutput.FistOfWarHitMultiplier),
						s_format("x %.2f) ^8(fist of war uptime ratio)", globalOutput.FistOfWarUptimeRatio / 100),
						s_format("= %.2f", globalOutput.AvgFistOfWarHitEffect),
					}
				end
				globalOutput.AvgFistOfWarAilmentEffect = 1 + globalOutput.FistOfWarAilmentMultiplier * (globalOutput.FistOfWarUptimeRatio / 100)
				globalOutput.MaxFistOfWarHitEffect = 1 + globalOutput.FistOfWarHitMultiplier
				globalOutput.MaxFistOfWarAilmentEffect = 1 + globalOutput.FistOfWarAilmentMultiplier
				if activeSkill.skillModList:Flag(nil, "Condition:WarcryMaxHit") then
					output.FistOfWarHitEffect = globalOutput.MaxFistOfWarHitEffect
					output.FistOfWarAilmentEffect = globalOutput.MaxFistOfWarAilmentEffect
				else
					output.FistOfWarHitEffect = globalOutput.AvgFistOfWarHitEffect
					output.FistOfWarAilmentEffect = globalOutput.AvgFistOfWarAilmentEffect
				end
				globalOutput.TheoreticalOffensiveWarcryEffect = globalOutput.TheoreticalOffensiveWarcryEffect * globalOutput.AvgFistOfWarHitEffect
				globalOutput.TheoreticalMaxOffensiveWarcryEffect = globalOutput.TheoreticalMaxOffensiveWarcryEffect * globalOutput.MaxFistOfWarHitEffect
			else
				output.FistOfWarHitEffect = 1
				output.FistOfWarAilmentEffect = 1
			end
		end

		-- Calculate maximum sustainable fuses and explosion rate for Explosive Arrow
		-- Does not take into account mines or traps
		if activeSkill.activeEffect.grantedEffect.name == "Explosive Arrow" then
			activeSkill.activeEffect.grantedEffect.explosiveArrowFunc(activeSkill, output, globalOutput, globalBreakdown, env)
		end

		-- Calculate crit chance, crit multiplier, and their combined effect
		if skillModList:Flag(cfg, "NeverCrit") then
			output.PreEffectiveCritChance = 0
			output.CritChance = 0
			output.CritMultiplier = 0
			output.BonusCritDotMultiplier = 0
			output.CritEffect = 1
		elseif skillModList:Flag(cfg, "SpellSkillsCannotDealCriticalStrikesExceptOnFinalRepeat") then
			if (output.Repeats or 1) == 1 then
				output.PreEffectiveCritChance = 0
				output.CritChance = 0
				output.CritMultiplier = 0
				output.BonusCritDotMultiplier = 0
				output.CritEffect = 1
			elseif skillModList:Flag(cfg, "SpellSkillsAlwaysDealCriticalStrikesOnFinalRepeat") then
				if env.configInput.repeatMode == "None" then
					output.PreEffectiveCritChance = 0
					output.CritChance = 0
				elseif env.configInput.repeatMode == "AVERAGE" then
					output.PreEffectiveCritChance = 100 / output.Repeats
					output.CritChance = 100 / output.Repeats
					if breakdown then
						breakdown.CritChance = {
							s_format("100%%"),
							s_format("/ %d ^8(number of repeats)", output.Repeats),
							s_format("= %.2f%% average critical strike chance", output.CritChance)
						}
					end
				else
					output.PreEffectiveCritChance = 100
					output.CritChance = 100
				end
			--else -- this shouldn't ever be a case but leaving this here if someone wants to implement it
			end
		else
			local critOverride = skillModList:Override(cfg, "CritChance")
			-- destructive link
			if skillModList:Flag(cfg, "MainHandCritIsEqualToParent") then
				critOverride = actor.parent.output.MainHand and actor.parent.output.MainHand.CritChance or actor.parent.weaponData1.CritChance
			elseif skillModList:Flag(cfg, "MainHandCritIsEqualToPartyMember") then
				critOverride = actor.partyMembers.output.MainHand and actor.partyMembers.output.MainHand.CritChance or (actor.partyMembers.weaponData1 and actor.partyMembers.weaponData1.CritChance or 0)
			end
			local baseCrit = critOverride or source.CritChance or 0

			local baseCritFromMainHand = skillModList:Flag(cfg, "BaseCritFromMainHand")
			local baseCritFromParentMainHand = skillModList:Flag(cfg, "AttackCritIsEqualToParentMainHand")
			if baseCritFromMainHand then
				baseCrit = actor.weaponData1.CritChance
			elseif baseCritFromParentMainHand then
				baseCrit = actor.parent.weaponData1 and actor.parent.weaponData1.CritChance or baseCrit
			end

			if critOverride == 100 then
				output.PreEffectiveCritChance = 100
				output.CritChance = 100
			else
				local base = 0
				local inc = 0
				local more = 1
				if not critOverride then
					base = skillModList:Sum("BASE", cfg, "CritChance") + (env.mode_effective and enemyDB:Sum("BASE", nil, "SelfCritChance") or 0)
					inc = skillModList:Sum("INC", cfg, "CritChance") + (env.mode_effective and enemyDB:Sum("INC", nil, "SelfCritChance") or 0)
					more = skillModList:More(cfg, "CritChance")
				end
				output.CritChance = (baseCrit + base) * (1 + inc / 100) * more
				local preCapCritChance = output.CritChance
				output.CritChance = m_min(output.CritChance, skillModList:Override(nil, "CritChanceCap") or skillModList:Sum("BASE", cfg, "CritChanceCap"))
				if (baseCrit + base) > 0 then
					output.CritChance = m_max(output.CritChance, 0)
				end
				output.PreEffectiveCritChance = output.CritChance
				local preLuckyCritChance = output.CritChance
				if env.mode_effective and skillModList:Flag(cfg, "CritChanceLucky") then
					output.CritChance = (1 - (1 - output.CritChance / 100) ^ 2) * 100
				end
				local preHitCheckCritChance = output.CritChance
				if env.mode_effective then
					output.CritChance = output.CritChance * output.AccuracyHitChance / 100
				end
				if breakdown and output.CritChance ~= baseCrit then
					breakdown.CritChance = { }
					local baseCritFromMainHandStr = baseCritFromMainHand and " from main weapon" or baseCritFromParentMainHand and " from parent main weapon" or ""
					if base ~= 0 then
						t_insert(breakdown.CritChance, s_format("(%g + %g) ^8(base%s)", baseCrit, base, baseCritFromMainHandStr))
					else
						t_insert(breakdown.CritChance, s_format("%g ^8(base%s)", baseCrit + base, baseCritFromMainHandStr))
					end
					if inc ~= 0 then
						t_insert(breakdown.CritChance, s_format("x %.2f", 1 + inc/100).." ^8(increased/reduced)")
					end
					if more ~= 1 then
						t_insert(breakdown.CritChance, s_format("x %.2f", more).." ^8(more/less)")
					end
					t_insert(breakdown.CritChance, s_format("= %.2f%% ^8(crit chance)", output.PreEffectiveCritChance))
					if preCapCritChance > 100 then
						local overCap = preCapCritChance - 100
						t_insert(breakdown.CritChance, s_format("Crit is overcapped by %.2f%% (%d%% increased Critical Strike Chance)", overCap, overCap / more / (baseCrit + base) * 100))
					end
					if env.mode_effective and skillModList:Flag(cfg, "CritChanceLucky") then
						t_insert(breakdown.CritChance, "Crit Chance is Lucky:")
						t_insert(breakdown.CritChance, s_format("1 - (1 - %.4f) x (1 - %.4f)", preLuckyCritChance / 100, preLuckyCritChance / 100))
						t_insert(breakdown.CritChance, s_format("= %.2f%%", preHitCheckCritChance))
					end
					if env.mode_effective and output.AccuracyHitChance < 100 then
						t_insert(breakdown.CritChance, "Crit confirmation roll:")
						t_insert(breakdown.CritChance, s_format("%.2f%%", preHitCheckCritChance))
						t_insert(breakdown.CritChance, s_format("x %.2f ^8(chance to hit)", output.AccuracyHitChance / 100))
						t_insert(breakdown.CritChance, s_format("= %.2f%%", output.CritChance))
					end
				end
			end
		end
		if not output.CritEffect then
			if skillModList:Flag(cfg, "NoCritMultiplier") then
				output.CritMultiplier = 1
			else
				local extraDamage = skillModList:Sum("BASE", cfg, "CritMultiplier") / 100
				local multiOverride = skillModList:Override(skillCfg, "CritMultiplier")
				if multiOverride then
					extraDamage = (multiOverride - 100) / 100
				end
				if env.mode_effective then
					local enemyInc = 1 + enemyDB:Sum("INC", nil, "SelfCritMultiplier") / 100
					extraDamage = extraDamage + enemyDB:Sum("BASE", nil, "SelfCritMultiplier") / 100
					extraDamage = round(extraDamage * enemyInc, 2)
					if breakdown and enemyInc ~= 1 then
						breakdown.CritMultiplier = {
							s_format("%d%% ^8(additional extra damage)", (enemyDB:Sum("BASE", nil, "SelfCritMultiplier") + skillModList:Sum("BASE", cfg, "CritMultiplier")) / 100),
							s_format("x %.2f ^8(increased/reduced extra crit damage taken by enemy)", enemyInc),
							s_format("= %d%% ^8(extra crit damage)", extraDamage * 100),
						}
					end
				end
				output.CritMultiplier = 1 + m_max(0, extraDamage)
			end
			local critChancePercentage = output.CritChance / 100
			output.CritEffect = 1 - critChancePercentage + critChancePercentage * output.CritMultiplier
			output.BonusCritDotMultiplier = (skillModList:Sum("BASE", cfg, "CritMultiplier") - 50) * skillModList:Sum("BASE", cfg, "CritMultiplierAppliesToDegen") / 10000
			if breakdown and output.CritEffect ~= 1 then
				breakdown.CritEffect = {
					s_format("(1 - %.4f) ^8(portion of damage from non-crits)", critChancePercentage),
					s_format("+ [ (%.4f x %g) ^8(portion of damage from crits)", critChancePercentage, output.CritMultiplier),
					s_format("= %.3f", output.CritEffect),
				}
			end
		end

		output.ScaledDamageEffect = 1

		-- Calculate chance and multiplier for dealing triple damage on Normal and Crit
		output.TripleDamageChanceOnCrit = m_min(skillModList:Sum("BASE", cfg, "TripleDamageChanceOnCrit"), 100)
		output.TripleDamageChance = m_min(skillModList:Sum("BASE", cfg, "TripleDamageChance") or 0 + (env.mode_effective and enemyDB:Sum("BASE", cfg, "SelfTripleDamageChance") or 0) + (output.TripleDamageChanceOnCrit * output.CritChance / 100), 100)
		output.TripleDamageEffect = 2 * output.TripleDamageChance / 100

		-- Calculate chance and multiplier for dealing double damage on Normal and Crit
		output.DoubleDamageChanceOnCrit = m_min(skillModList:Sum("BASE", cfg, "DoubleDamageChanceOnCrit"), 100)
		output.DoubleDamageChance = m_min(skillModList:Sum("BASE", cfg, "DoubleDamageChance") + (env.mode_effective and enemyDB:Sum("BASE", cfg, "SelfDoubleDamageChance") or 0) + (output.DoubleDamageChanceOnCrit * output.CritChance / 100), 100)
		if globalOutput.IntimidatingUpTimeRatio and activeSkill.skillModList:Flag(nil, "Condition:WarcryMaxHit") then
			output.DoubleDamageChance = 100
		elseif globalOutput.IntimidatingUpTimeRatio then
			output.DoubleDamageChance = m_min(output.DoubleDamageChance + globalOutput.IntimidatingUpTimeRatio, 100)
		end
		-- Triple Damage overrides Double Damage. If you have both, it's the same as just having Triple
		-- We need to subtract the probability of both happening in favor of Triple Damage
		if output.TripleDamageChance > 0 then
			output.DoubleDamageChance = m_max(output.DoubleDamageChance - output.TripleDamageChance * output.DoubleDamageChance / 100, 0)
		end
		output.DoubleDamageEffect = output.DoubleDamageChance / 100
		output.ScaledDamageEffect = output.ScaledDamageEffect * (1 + output.DoubleDamageEffect + output.TripleDamageEffect)

		local hitRate = output.HitChance / 100 * (globalOutput.HitSpeed or globalOutput.Speed) * skillData.dpsMultiplier

		-- Calculate culling DPS
		local criticalCull = skillModList:Max(cfg, "CriticalCullPercent") or 0
		if criticalCull > 0 then
			criticalCull = m_min(criticalCull, criticalCull * (1 - (1 - output.CritChance / 100) ^ hitRate))
		end
		local regularCull = skillModList:Max(cfg, "CullPercent") or 0
		local maxCullPercent = m_max(criticalCull, regularCull)
		globalOutput.CullPercent = maxCullPercent
		globalOutput.CullMultiplier = 100 / (100 - globalOutput.CullPercent)

		--Calculate reservation DPS
		globalOutput.ReservationDpsMultiplier = 100 / (100 - enemyDB:Sum("BASE", nil, "LifeReservationPercent"))

		-- Calculate base hit damage
		for _, damageType in ipairs(dmgTypeList) do
			local damageTypeMod = damageType.."Damage"
			local baseMultiplier = activeSkill.activeEffect.grantedEffect.stats.baseMultiplier or skillData.baseMultiplier or 1
			local damageEffectiveness = activeSkill.activeEffect.grantedEffect.stats.damageEffectiveness or skillData.damageEffectiveness or 1
			local typeAddedDmg = skillModList:Sum("BASE", cfg, damageTypeMod) + enemyDB:Sum("BASE", cfg, "Self".. damageTypeMod)
			local allAddedDmg = source[damageTypeMod] and skillModList:Sum("BASE", cfg, "Damage") or 0
			local addedDmg = typeAddedDmg + allAddedDmg
			local addedMult = calcLib.mod(skillModList, cfg, "Added"..damageType.."Damage", "AddedDamage")
			local baseDmg = ((source[damageTypeMod] or 0) + (source[damageType.."BonusMin"] or 0)) * baseMultiplier + addedDmg * damageEffectiveness * addedMult
			output[damageTypeMod .."Base"] = baseDmg
			if breakdown then
				breakdown[damageType] = { damageTypes = { } }
				if baseDmg ~= 0 and baseMax ~= 0 then
					t_insert(breakdown[damageType], "Base damage:")
					local plus = ""
					if (source[damageTypeMod] or 0) ~= 0 then
						t_insert(breakdown[damageType], s_format("%d ^8(base damage from %s)", source[damageTypeMod], source.type and "weapon" or "skill"))
						if baseMultiplier ~= 1 then
							t_insert(breakdown[damageType], s_format("x %.2f ^8(base damage multiplier)", baseMultiplier))
						end
						plus = "+ "
					end
					if addedDmg ~= 0 or addedMax ~= 0 then
						t_insert(breakdown[damageType], s_format("%s(%d + %d) ^8(added damage, including all types)", plus, typeAddedDmg, allAddedDmg))
						if damageEffectiveness ~= 1 then
							t_insert(breakdown[damageType], s_format("x %.2f ^8(damage effectiveness)", damageEffectiveness))
						end
						if addedMult ~= 1 then
							t_insert(breakdown[damageType], s_format("x %.2f ^8(added damage multiplier)", addedMult))
						end
					end
					t_insert(breakdown[damageType], s_format("= %.1f", baseDmg))
				end
			end
		end

		-- Calculate hit damage for each damage type
		local totalHitAvg = 0
		local totalCritAvg = 0
		local ghostReaver = skillModList:Flag(nil, "GhostReaver")
		output.LifeLeech = 0
		output.LifeLeechInstant = 0
		output.EnergyShieldLeech = 0
		output.EnergyShieldLeechInstant = 0
		output.ManaLeech = 0
		output.ManaLeechInstant = 0
		output.impaleStoredHitAvg = 0
		for pass = 1, 2 do
			-- Pass 1 is critical strike damage, pass 2 is non-critical strike
			cfg.skillCond["CriticalStrike"] = (pass == 1)
			local lifeLeechTotal = 0
			local energyShieldLeechTotal = 0
			local manaLeechTotal = 0
			local noLifeLeech = skillModList:Flag(cfg, "CannotLeechLife") or enemyDB:Flag(nil, "CannotLeechLifeFromSelf") or skillModList:Flag(cfg, "CannotGainLife")
			local noEnergyShieldLeech = skillModList:Flag(cfg, "CannotLeechEnergyShield") or enemyDB:Flag(nil, "CannotLeechEnergyShieldFromSelf") or skillModList:Flag(cfg, "CannotGainEnergyShield")
			local noManaLeech = skillModList:Flag(cfg, "CannotLeechMana") or enemyDB:Flag(nil, "CannotLeechManaFromSelf") or skillModList:Flag(cfg, "CannotGainMana")
			for _, damageType in ipairs(dmgTypeList) do
				local damageTypeHitAvg = 0
				if skillFlags.hit and canDeal[damageType] then
					damageTypeHitAvg = calcDamage(activeSkill, output, cfg, pass == 2 and breakdown and breakdown[damageType], damageType, 0)
					local convMult = activeSkill.conversionTable[damageType].mult
					if pass == 2 and breakdown then
						t_insert(breakdown[damageType], "Hit damage:")
						t_insert(breakdown[damageType], s_format("%d ^8(total damage)", damageTypeHitAvg))
						if convMult ~= 1 then
							t_insert(breakdown[damageType], s_format("x %g ^8(%g%% converted to other damage types)", convMult, (1-convMult)*100))
						end
						if output.DoubleDamageEffect ~= 0 then
							if output.TripleDamageEffect ~= 0 then
								t_insert(breakdown[damageType], s_format("x %.2f ^8(1 + %.2f + %.2f multiplier from %.1f%% chance to deal double damage and %d%% chance to deal triple damage)", 1 + output.DoubleDamageEffect + output.TripleDamageEffect, output.DoubleDamageEffect, output.TripleDamageEffect, output.DoubleDamageChance, output.TripleDamageChance))
							else
								t_insert(breakdown[damageType], s_format("x %.2f ^8(multiplier from %d%% chance to deal double damage)", 1 + output.DoubleDamageEffect, output.DoubleDamageChance))
							end
						elseif output.TripleDamageEffect ~= 0 then
							t_insert(breakdown[damageType], s_format("x %.2f ^8(multiplier from %d%% chance to deal triple damage)", 1 + output.TripleDamageEffect, output.TripleDamageChance))
						end
						if output.RuthlessBlowHitEffect ~= 1 then
							t_insert(breakdown[damageType], s_format("x %.2f ^8(ruthless blow effect modifier)", output.RuthlessBlowHitEffect))
						end
						if output.FistOfWarHitEffect ~= 1 then
							t_insert(breakdown[damageType], s_format("x %.2f ^8(fist of war effect modifier)", output.FistOfWarHitEffect))
						end
						if globalOutput.OffensiveWarcryEffect ~= 1  and not activeSkill.skillModList:Flag(nil, "Condition:WarcryMaxHit") then
							t_insert(breakdown[damageType], s_format("x %.2f ^8(aggregated warcry exerted effect modifier)", globalOutput.OffensiveWarcryEffect))
						end
						if globalOutput.MaxOffensiveWarcryEffect ~= 1 and activeSkill.skillModList:Flag(nil, "Condition:WarcryMaxHit") then
							t_insert(breakdown[damageType], s_format("x %.2f ^8(aggregated max warcry exerted effect modifier)", globalOutput.MaxOffensiveWarcryEffect))
						end
					end
					if activeSkill.skillModList:Flag(nil, "Condition:WarcryMaxHit") then
						output.allMult = convMult * output.ScaledDamageEffect * output.RuthlessBlowHitEffect * output.FistOfWarHitEffect * globalOutput.MaxOffensiveWarcryEffect
					else
						output.allMult = convMult * output.ScaledDamageEffect * output.RuthlessBlowHitEffect * output.FistOfWarHitEffect * globalOutput.OffensiveWarcryEffect
					end
					local allMult = output.allMult
					if pass == 1 then
						-- Apply crit multiplier
						allMult = allMult * output.CritMultiplier
					end
					damageTypeHitAvg = damageTypeHitAvg * allMult
					if (damageTypeHitAvg ~= 0) and env.mode_effective then
						-- Apply enemy resistances and damage taken modifiers
						local resist = 0
						local pen = 0
						local sourceRes = damageType
						local takenInc = enemyDB:Sum("INC", cfg, "DamageTaken", damageType.."DamageTaken")
						local takenMore = enemyDB:More(cfg, "DamageTaken", damageType.."DamageTaken")
						-- Check if player is supposed to ignore a damage type, or if it's ignored on enemy side
						local useThisResist = function(damageType)
							return not skillModList:Flag(cfg, "Ignore"..damageType.."Resistance", isElemental[damageType] and "IgnoreElementalResistances" or nil) and not enemyDB:Flag(nil, "SelfIgnore"..damageType.."Resistance")
						end
						if damageType == "Physical" then
							local enemyArmour = m_max(calcLib.val(enemyDB, "Armour"), 0)
							local armourReduction = calcs.armourReductionF(enemyArmour, damageTypeHitAvg * skillModList:More(cfg, "CalcArmourAsThoughDealing"))
							if skillModList:Flag(cfg, "IgnoreEnemyPhysicalDamageReduction") then
								resist = 0
							else
								resist = m_min(m_max(0, enemyDB:Sum("BASE", nil, "PhysicalDamageReduction") + skillModList:Sum("BASE", cfg, "EnemyPhysicalDamageReduction") + armourReduction), data.misc.DamageReductionCap)
								resist = resist > 0 and resist * (1 - (skillModList:Sum("BASE", nil, "PartialIgnoreEnemyPhysicalDamageReduction") / 100)) or resist
							end
						else
							resist = calcResistForType(damageType, cfg)
							pen = skillModList:Sum("BASE", cfg, damageType.."Penetration", "Penetration")
							takenInc = takenInc + enemyDB:Sum("INC", cfg, "ElementalDamageTaken")
						end
						local invertChance = m_max(m_min(skillModList:Sum("CHANCE", cfg, "HitsInvertEleResChance"), 1), 0)
						if isElemental[damageType] and invertChance > 0 then
							-- resist = (1 - invertChance) * resist + invertChance * (-1 * resist)
							resist = resist - 2 * invertChance * resist
						end
						sourceRes = env.modDB:Flag(nil, "Enemy"..sourceRes.."ResistEqualToYours") and "Your "..sourceRes.." Resistance" or (env.partyMembers.modDB:Flag(nil, "Enemy"..sourceRes.."ResistEqualToYours") and "Party Member "..sourceRes.." Resistance" or sourceRes)
						if skillFlags.projectile then
							takenInc = takenInc + enemyDB:Sum("INC", nil, "ProjectileDamageTaken")
						end
						if skillFlags.projectile and skillFlags.attack then
							takenInc = takenInc + enemyDB:Sum("INC", nil, "ProjectileAttackDamageTaken")
						end
						if skillFlags.trap or skillFlags.mine then
							takenInc = takenInc + enemyDB:Sum("INC", nil, "TrapMineDamageTaken")
						end
						local effMult = (1 + takenInc / 100) * takenMore
						local useRes = useThisResist(damageType)
						if skillModList:Flag(cfg, isElemental[damageType] and "CannotElePenIgnore" or nil) then
							effMult = effMult * (1 - resist / 100)
						elseif useRes then
							effMult = effMult * (1 - (resist - pen) / 100)
						end
						damageTypeHitAvg = damageTypeHitAvg * effMult
						if env.mode == "CALCS" then
							output[damageType.."EffMult"] = effMult
						end
						if pass == 2 and breakdown and (effMult ~= 1 or sourceRes ~= damageType) and skillModList:Flag(cfg, isElemental[damageType] and "CannotElePenIgnore" or nil) then
							t_insert(breakdown[damageType], s_format("x %.3f ^8(effective DPS modifier)", effMult))
							breakdown[damageType.."EffMult"] = breakdown.effMult(damageType, resist, 0, takenInc, effMult, takenMore, sourceRes, useRes, invertChance)
						elseif pass == 2 and breakdown and (effMult ~= 1 or sourceRes ~= damageType) then
							t_insert(breakdown[damageType], s_format("x %.3f ^8(effective DPS modifier)", effMult))
							breakdown[damageType.."EffMult"] = breakdown.effMult(damageType, resist, pen, takenInc, effMult, takenMore, sourceRes, useRes, invertChance)
						end
					end
					if pass == 2 and breakdown then
						t_insert(breakdown[damageType], s_format("= %d", damageTypeHitAvg))
					end

					-- Beginning of Leech Calculation for this DamageType
					local lifeLeech = 0
					local energyShieldLeech = 0
					local manaLeech = 0
					if skillFlags.mine or skillFlags.trap or skillFlags.totem then
						lifeLeech = skillModList:Sum("BASE", cfg, "DamageLifeLeechToPlayer")
					else
						if skillModList:Flag(nil, "LifeLeechBasedOnChaosDamage") then
								if damageType == "Chaos" then
									lifeLeech = skillModList:Sum("BASE", cfg, "DamageLeech", "DamageLifeLeech", "PhysicalDamageLifeLeech", "LightningDamageLifeLeech", "ColdDamageLifeLeech", "FireDamageLifeLeech", "ChaosDamageLifeLeech", "ElementalDamageLifeLeech") + enemyDB:Sum("BASE", cfg, "SelfDamageLifeLeech") / 100
								end
							else
								lifeLeech = skillModList:Sum("BASE", cfg, "DamageLeech", "DamageLifeLeech", damageType.."DamageLifeLeech", isElemental[damageType] and "ElementalDamageLifeLeech" or nil) + enemyDB:Sum("BASE", cfg, "SelfDamageLifeLeech") / 100
							end
						energyShieldLeech = skillModList:Sum("BASE", cfg, "DamageEnergyShieldLeech", damageType.."DamageEnergyShieldLeech", isElemental[damageType] and "ElementalDamageEnergyShieldLeech" or nil) + enemyDB:Sum("BASE", cfg, "SelfDamageEnergyShieldLeech") / 100
						manaLeech = skillModList:Sum("BASE", cfg, "DamageLeech", "DamageManaLeech", damageType.."DamageManaLeech", isElemental[damageType] and "ElementalDamageManaLeech" or nil) + enemyDB:Sum("BASE", cfg, "SelfDamageManaLeech") / 100
					end

					if ghostReaver and not noLifeLeech then
						energyShieldLeech = energyShieldLeech + lifeLeech
						lifeLeech = 0
					end

					if lifeLeech > 0 and not noLifeLeech then
						lifeLeechTotal = lifeLeechTotal + damageTypeHitAvg * lifeLeech / 100
					end
					if manaLeech > 0 and not noManaLeech then
						manaLeechTotal = manaLeechTotal + damageTypeHitAvg * manaLeech / 100
					end
					if energyShieldLeech > 0 and not noEnergyShieldLeech  then
						energyShieldLeechTotal = energyShieldLeechTotal + damageTypeHitAvg * energyShieldLeech / 100
					end
				else
					if breakdown then
						breakdown[damageType] = {
							"You can't deal "..damageType.." damage"
						}
					end
				end
				if pass == 1 then
					output[damageType.."CritAverage"] = damageTypeHitAvg
					totalCritAvg = totalCritAvg + damageTypeHitAvg
				else
					if env.mode == "CALCS" then
						output[damageType.."Damage"] = damageTypeHitAvg
					end
					output[damageType.."HitAverage"] = damageTypeHitAvg
					totalHitAvg = totalHitAvg + damageTypeHitAvg
				end
			end
			if skillData.lifeLeechPerUse then
				lifeLeechTotal = lifeLeechTotal + skillData.lifeLeechPerUse
			end
			if skillData.manaLeechPerUse then
				manaLeechTotal = manaLeechTotal + skillData.manaLeechPerUse
			end

			-- leech caps per instance
			lifeLeechTotal = m_min(lifeLeechTotal, globalOutput.MaxLifeLeechInstance)
			energyShieldLeechTotal = m_min(energyShieldLeechTotal, globalOutput.MaxEnergyShieldLeechInstance)
			manaLeechTotal = m_min(manaLeechTotal, globalOutput.MaxManaLeechInstance)

			local portion = (pass == 1) and (output.CritChance / 100) or (1 - output.CritChance / 100)
			output.LifeLeech = output.LifeLeech + lifeLeechTotal * portion
			output.EnergyShieldLeech = output.EnergyShieldLeech + energyShieldLeechTotal * portion
			output.ManaLeech = output.ManaLeech + manaLeechTotal * portion
		end
		output.TotalAvg = totalHitAvg

		if skillModList:Flag(skillCfg, "ElementalEquilibrium") and not env.configInput.EEIgnoreHitDamage and (output.FireHitAverage + output.ColdHitAverage + output.LightningHitAverage > 0) then
			-- Update enemy hit-by-damage-type conditions
			enemyDB.conditions.HitByFireDamage = output.FireHitAverage > 0
			enemyDB.conditions.HitByColdDamage = output.ColdHitAverage > 0
			enemyDB.conditions.HitByLightningDamage = output.LightningHitAverage > 0
		end

		local highestType = "Physical"

		-- For each damage type, calculate percentage of total damage. Also tracks the highest damage type and outputs a Condition:TypeIsHighestDamageType flag for whichever the highest type is
		for _, damageType in ipairs(dmgTypeList) do
			if output[damageType.."HitAverage"] > 0 then
				local portion = output[damageType.."HitAverage"] / totalHitAvg * 100
				skillModList:NewMod("Condition:"..damageType.."HasDamage", "FLAG", true, "Config")
				if output[damageType.."HitAverage"] > output[highestType.."HitAverage"] then
					highestType = damageType
				end
				if breakdown then
					t_insert(breakdown[damageType], s_format("Portion of total damage: %d%%", portion))
				end
			end
		end
		if not skillModList:Flag(nil, "IsHighestDamageTypeOVERRIDE") then
			skillModList:NewMod("Condition:"..highestType.."IsHighestDamageType", "FLAG", true, "Config")
		end

		-- Calculate leech
		local function getLeechInstances(amount, total)
			if total == 0 then
				return 0, 0
			end
			local duration = amount / total / data.misc.LeechRateBase
			return duration, duration * hitRate
		end

		--Instant Leech
		output.LifeLeechInstantProportion = m_max(m_min(skillModList:Sum("BASE", cfg, "InstantLifeLeech") or 0, 100), 0) / 100
		if output.LifeLeechInstantProportion > 0 then
			output.LifeLeechInstant = output.LifeLeech * output.LifeLeechInstantProportion
			output.LifeLeech = output.LifeLeech * (1 - output.LifeLeechInstantProportion)
		end
		output.EnergyShieldLeechInstantProportion = m_max(m_min(skillModList:Sum("BASE", cfg, "InstantEnergyShieldLeech") or 0, 100), 0) / 100
		if output.EnergyShieldLeechInstantProportion > 0 then
			output.EnergyShieldLeechInstant = output.EnergyShieldLeech * output.EnergyShieldLeechInstantProportion
			output.EnergyShieldLeech = output.EnergyShieldLeech * (1 - output.EnergyShieldLeechInstantProportion)
		end
		output.ManaLeechInstantProportion = m_max(m_min(skillModList:Sum("BASE", cfg, "InstantManaLeech") or 0, 100), 0) / 100
		if output.ManaLeechInstantProportion > 0 then
			output.ManaLeechInstant = output.ManaLeech * output.ManaLeechInstantProportion
			output.ManaLeech = output.ManaLeech * (1 - output.ManaLeechInstantProportion)
		end

		output.LifeLeechDuration, output.LifeLeechInstances = getLeechInstances(output.LifeLeech, globalOutput.Life)
		output.LifeLeechInstantRate = output.LifeLeechInstant * hitRate
		output.EnergyShieldLeechDuration, output.EnergyShieldLeechInstances = getLeechInstances(output.EnergyShieldLeech, globalOutput.EnergyShield)
		output.EnergyShieldLeechInstantRate = output.EnergyShieldLeechInstant * hitRate
		output.ManaLeechDuration, output.ManaLeechInstances = getLeechInstances(output.ManaLeech, globalOutput.Mana)
		output.ManaLeechInstantRate = output.ManaLeechInstant * hitRate

		-- Calculate gain on hit
		if skillFlags.mine or skillFlags.trap or skillFlags.totem then
			output.LifeOnHit = 0
			output.EnergyShieldOnHit = 0
			output.ManaOnHit = 0
		else
			output.LifeOnHit = not skillModList:Flag(cfg, "CannotGainLife") and (skillModList:Sum("BASE", cfg, "LifeOnHit") + enemyDB:Sum("BASE", cfg, "SelfLifeOnHit")) or 0
			output.EnergyShieldOnHit = not skillModList:Flag(cfg, "CannotGainEnergyShield") and (skillModList:Sum("BASE", cfg, "EnergyShieldOnHit") + enemyDB:Sum("BASE", cfg, "SelfEnergyShieldOnHit")) or 0
			output.ManaOnHit = not skillModList:Flag(cfg, "CannotGainMana") and (skillModList:Sum("BASE", cfg, "ManaOnHit") + enemyDB:Sum("BASE", cfg, "SelfManaOnHit")) or 0
		end
		output.LifeOnHitRate = output.LifeOnHit * hitRate
		output.EnergyShieldOnHitRate = output.EnergyShieldOnHit * hitRate
		output.ManaOnHitRate = output.ManaOnHit * hitRate

		-- Calculate gain on kill
		if skillFlags.mine or skillFlags.trap or skillFlags.totem then
			output.LifeOnKill = 0
			output.EnergyShieldOnKill = 0
			output.ManaOnKill = 0
		else
			output.LifeOnKill = not skillModList:Flag(cfg, "CannotGainLife") and (m_floor(skillModList:Sum("BASE", cfg, "LifeOnKill"))) or 0
			output.EnergyShieldOnKill = not skillModList:Flag(cfg, "CannotGainEnergyShield") and (m_floor(skillModList:Sum("BASE", cfg, "EnergyShieldOnKill"))) or 0
			output.ManaOnKill = not skillModList:Flag(cfg, "CannotGainMana") and (m_floor(skillModList:Sum("BASE", cfg, "ManaOnKill"))) or 0
		end

		-- Enemy Regeneration Rate
		output.EnemyLifeRegen = enemyDB:Sum("INC", cfg, "LifeRegen")
		output.EnemyManaRegen = enemyDB:Sum("INC", cfg, "ManaRegen")
		output.EnemyEnergyShieldRegen = enemyDB:Sum("INC", cfg, "EnergyShieldRegen")

		-- Calculate average damage and final DPS
		output.AverageHit = totalHitAvg * (1 - output.CritChance / 100) + totalCritAvg * output.CritChance / 100
		if skillFlags.monsterExplode then
			output.AverageHitToMonsterLifePercentage = output.AverageHit / monsterLife * 100
			if skillData.hitChanceIsExplodeChance then
				output.HitChance = output.ExplodeChance
			end
		end
		output.AverageDamage = output.AverageHit * output.HitChance / 100
		globalOutput.AverageBurstHits = output.AverageBurstHits or 1
		local repeatPenalty = skillModList:Flag(nil, "HasSeals") and activeSkill.skillTypes[SkillType.CanRapidFire]  and not skillModList:Flag(nil, "NoRepeatBonuses") and calcLib.mod(skillModList, skillCfg, "SealRepeatPenalty") or 1
		globalOutput.AverageBurstDamage = output.AverageDamage + output.AverageDamage * (globalOutput.AverageBurstHits - 1) * repeatPenalty or 0
		globalOutput.ShowBurst = globalOutput.AverageBurstHits > 1
		output.TotalDPS = output.AverageDamage * (globalOutput.HitSpeed or globalOutput.Speed) * skillData.dpsMultiplier * quantityMultiplier
		if breakdown then
			if output.CritEffect ~= 1 then
				breakdown.AverageHit = { }
				t_insert(breakdown.AverageHit, s_format("%.1f x (1 - %.4f) ^8(damage from non-crits)", totalHitAvg, output.CritChance / 100))
				t_insert(breakdown.AverageHit, s_format("+ %.1f x %.4f ^8(damage from crits)", totalCritAvg, output.CritChance / 100))
				t_insert(breakdown.AverageHit, s_format("= %.1f", output.AverageHit))
			end
			if output.HitChance < 100 then
				breakdown.AverageDamage = { }
				t_insert(breakdown.AverageDamage, s_format("%s:", pass.label))
				t_insert(breakdown.AverageDamage, s_format("%.1f ^8(average hit)", output.AverageHit))
				t_insert(breakdown.AverageDamage, s_format("x %.2f ^8(chance to hit)", output.HitChance / 100))
				t_insert(breakdown.AverageDamage, s_format("= %.1f", output.AverageDamage))
			end
		end
		if globalBreakdown and globalOutput.AverageBurstDamage > 0 then
			globalBreakdown.AverageBurstDamage = { }
			t_insert(globalBreakdown.AverageBurstDamage, s_format("%.1f ^8(average hit)", output.AverageHit))
			if output.HitChance < 100 then
				t_insert(globalBreakdown.AverageBurstDamage, s_format("x %.2f ^8(chance to hit)", output.HitChance / 100))
			end
			if repeatPenalty < 1 then
				t_insert(globalBreakdown.AverageBurstDamage, s_format("x %.2f ^8(number of repeats)", globalOutput.AverageBurstHits - 1))
				t_insert(globalBreakdown.AverageBurstDamage, s_format("x %.2f ^8(repeat penalty)", repeatPenalty))
				t_insert(globalBreakdown.AverageBurstDamage, s_format("= %.1f ^8(repeat damage total)", globalOutput.AverageBurstDamage - output.AverageDamage))
				t_insert(globalBreakdown.AverageBurstDamage, "")
				t_insert(globalBreakdown.AverageBurstDamage, s_format("+ %.1f ^8(first hit)", output.AverageHit))
				if output.HitChance < 100 then
					t_insert(globalBreakdown.AverageBurstDamage, s_format("x %.2f ^8(chance to hit)", output.HitChance / 100))
				end
			else
				t_insert(globalBreakdown.AverageBurstDamage, s_format("x %.2f ^8(number of hits)", globalOutput.AverageBurstHits))
			end
			t_insert(globalBreakdown.AverageBurstDamage, s_format("= %.1f ^8(total burst damage)", globalOutput.AverageBurstDamage))
		end


		-- Calculate PvP values

		--setup flags
		skillFlags.isPvP = false
		skillFlags.notAttackPvP = false
		skillFlags.attackPvP = false
		skillFlags.weapon1AttackPvP = false
		skillFlags.weapon2AttackPvP = false
		skillFlags.notAveragePvP = false

		if env.configInput.PvpScaling then
			skillFlags.isPvP = true
			skillFlags.attackPvP = skillFlags.attack
			skillFlags.notAttackPvP = not skillFlags.attack
			skillFlags.weapon1AttackPvP = skillFlags.weapon1Attack
			skillFlags.weapon2AttackPvP = skillFlags.weapon2Attack
			skillFlags.notAveragePvP = skillFlags.notAverage
			local PvpTvalue = env.configInput.multiplierPvpTvalueOverride or nil
			if PvpTvalue then
				PvpTvalue = PvpTvalue / 1000
			else
				if skillData.cooldown then
					PvpTvalue = skillData.cooldown
				elseif skillFlags.mine then
					PvpTvalue = (output.MineLayingTime or 1) / globalOutput.ActionSpeedMod
				elseif skillFlags.trap then
					PvpTvalue = (output.TrapThrowingTime or 1) / globalOutput.ActionSpeedMod
				else
					PvpTvalue = 1/((globalOutput.HitSpeed or globalOutput.Speed)/globalOutput.ActionSpeedMod) * skillModList:More(cfg, "PvpTvalueMultiplier")
				end
				if PvpTvalue > 2147483647 then
					PvpTvalue = 1
				end
			end
			local PvpMultiplier = skillModList:More(cfg, "PvpDamageMultiplier")

			local PvpNonElemental1 = data.misc.PvpNonElemental1
			local PvpNonElemental2 = data.misc.PvpNonElemental2
			local PvpElemental1 = data.misc.PvpElemental1
			local PvpElemental2 = data.misc.PvpElemental2

			local percentageNonElemental = ((output["PhysicalHitAverage"] + output["ChaosHitAverage"]) / totalHitAvg)
			local percentageElemental = 1 - percentageNonElemental
			local portionNonElemental = (output.AverageHit / PvpTvalue / PvpNonElemental2 ) ^ PvpNonElemental1 * PvpTvalue * PvpNonElemental2 * percentageNonElemental
			local portionElemental = (output.AverageHit / PvpTvalue / PvpElemental2 ) ^ PvpElemental1 * PvpTvalue * PvpElemental2 * percentageElemental
			output.PvpAverageHit = (portionNonElemental + portionElemental) * PvpMultiplier
			output.PvpAverageDamage = output.PvpAverageHit * output.HitChance / 100
			output.PvpTotalDPS = output.PvpAverageDamage * (globalOutput.HitSpeed or globalOutput.Speed) * skillData.dpsMultiplier

			-- fix for these being nan
			if output.PvpAverageHit ~= output.PvpAverageHit then
				output.PvpAverageHit = 0
			end
			if output.PvpAverageDamage ~= output.PvpAverageDamage then
				output.PvpAverageDamage = 0
			end
			if output.PvpTotalDPS ~= output.PvpTotalDPS then
				output.PvpTotalDPS = 0
			end

			if breakdown then
				breakdown.PvpAverageHit = { }
				local percentBoth = (percentageNonElemental > 0) and (percentageElemental > 0)
				t_insert(breakdown.PvpAverageHit, s_format("Pvp Formula is (D/(T*M))^E*T*%s, where D is the damage, T is the time taken,", percentBoth and "M*P" or "M" ))
				t_insert(breakdown.PvpAverageHit, s_format(" M is the multiplier%s", percentBoth and ", E is the exponent and P is the percentage of that type (ele or non ele)" or " and E is the exponent" ))
				if percentBoth then
					t_insert(breakdown.PvpAverageHit, s_format("(M= %.1f for ele and %.1f for non-ele)(E= %.2f for ele and %.2f for non-ele)", PvpElemental2, PvpNonElemental2, PvpElemental1, PvpNonElemental1))
					t_insert(breakdown.PvpAverageHit, s_format("(%.1f / (%.2f * %.1f)) ^ %.2f * %.2f * %.1f * %.2f = %.1f", output.AverageHit, PvpTvalue,  PvpNonElemental2, PvpNonElemental1, PvpTvalue, PvpNonElemental2, percentageNonElemental, portionNonElemental))
					t_insert(breakdown.PvpAverageHit, s_format("(%.1f / (%.2f * %.1f)) ^ %.2f * %.2f * %.1f * %.2f = %.1f", output.AverageHit, PvpTvalue,  PvpElemental2, PvpElemental1, PvpTvalue, PvpElemental2, percentageElemental, portionElemental))
					t_insert(breakdown.PvpAverageHit, s_format("(portionNonElemental + portionElemental)%s", PvpMultiplier ~= 1 and " * PvP multiplier" or " "))
					if PvpMultiplier ~= 1 then
						t_insert(breakdown.PvpAverageHit, s_format("(%.1f + %.1f) * %g", portionNonElemental, portionElemental, PvpMultiplier))
					else
						t_insert(breakdown.PvpAverageHit, s_format("%.1f + %.1f", portionNonElemental, portionElemental))
					end
				elseif percentageElemental <= 0 then
					t_insert(breakdown.PvpAverageHit, s_format("(M= %.1f for non-ele)(E= %.2f for non-ele)", PvpNonElemental2, PvpNonElemental1))
					t_insert(breakdown.PvpAverageHit, s_format("(%.1f / (%.2f * %.1f)) ^ %.2f * %.2f * %.1f = %.1f", output.AverageHit, PvpTvalue,  PvpNonElemental2, PvpNonElemental1, PvpTvalue, PvpNonElemental2, portionNonElemental))
					if PvpMultiplier ~= 1 then
						t_insert(breakdown.PvpAverageHit, s_format("%.1f * %g ^8(portionNonElemental * PvP multiplier)", portionNonElemental, PvpMultiplier))
					end
				elseif percentageNonElemental <= 0 then
					t_insert(breakdown.PvpAverageHit, s_format("(M= %.1f for ele)(E= %.2f for ele)", PvpElemental2, PvpElemental1))
					t_insert(breakdown.PvpAverageHit, s_format("(%.1f / (%.2f * %.1f)) ^ %.2f * %.2f * %.1f = %.1f", output.AverageHit, PvpTvalue,  PvpElemental2, PvpElemental1, PvpTvalue, PvpElemental2, portionElemental))
					if PvpMultiplier ~= 1 then
						t_insert(breakdown.PvpAverageHit, s_format("%.1f * %g ^8(portionElemental * PvP multiplier)", portionElemental, PvpMultiplier))
					end
				end
				t_insert(breakdown.PvpAverageHit, s_format("= %.1f", output.PvpAverageHit))
				if isAttack then
					breakdown.PvpAverageDamage = { }
					t_insert(breakdown.PvpAverageDamage, s_format("%s:", pass.label))
					t_insert(breakdown.PvpAverageDamage, s_format("%.1f ^8(average pvp hit)", output.PvpAverageHit))
					t_insert(breakdown.PvpAverageDamage, s_format("x %.2f ^8(chance to hit)", output.HitChance / 100))
					t_insert(breakdown.PvpAverageDamage, s_format("= %.1f", output.PvpAverageDamage))
				end
			end
		end
	end

	if env.mode == "CALCS" then
		if skillData.showAverage then
			output.DisplayDamage = formatNumSep(s_format("%.1f", output.AverageDamage)) .. " average damage"
		else
			output.DisplayDamage = formatNumSep(s_format("%.1f", output.TotalDPS)) .. " DPS"
		end
	end
	if breakdown then
		if isAttack then
			breakdown.TotalDPS = {
				s_format("%.1f ^8(average damage)", output.AverageDamage),
				output.HitSpeed and s_format("x %.2f ^8(hit rate)", output.HitSpeed) or s_format("x %.2f ^8(attack rate)", output.Speed),
			}
		elseif skillData.triggered then
			breakdown.TotalDPS = {
				s_format("%.1f ^8(average damage)", output.AverageDamage),
				output.HitSpeed and s_format("x %.2f ^8(hit rate)", output.HitSpeed) or s_format("x %.2f ^8(trigger rate)", output.Speed),
			}
		else
			breakdown.TotalDPS = {
				s_format("%.1f ^8(average hit)", output.AverageDamage),
				output.HitSpeed and s_format("x %.2f ^8(hit rate)", output.HitSpeed) or s_format("x %.2f ^8(cast rate)", output.Speed),
			}
		end
		if skillData.dpsMultiplier ~= 1 then
			t_insert(breakdown.TotalDPS, s_format("x %g ^8(DPS multiplier for this skill)", skillData.dpsMultiplier))
		end
		if quantityMultiplier > 1 then
			t_insert(breakdown.TotalDPS, s_format("x %g ^8(quantity multiplier for this skill)", quantityMultiplier))
		end
		t_insert(breakdown.TotalDPS, s_format("= %.1f", output.TotalDPS))
		if skillFlags.isPvP then
			local rateType = "cast"
			if isAttack then
				rateType = "attack"
			elseif skillData.triggered then
				rateType = "trigger"
			end
			breakdown.PvpTotalDPS = {
				s_format("%.1f ^8(average pvp hit)", output.PvpAverageDamage),
				output.HitSpeed and s_format("x %.2f ^8(hit rate)", output.HitSpeed) or s_format("x %.2f ^8(%s rate)", output.Speed, rateType),
			}
			if skillData.dpsMultiplier ~= 1 then
				t_insert(breakdown.PvpTotalDPS, s_format("x %g ^8(DPS multiplier for this skill)", skillData.dpsMultiplier))
			end
			if quantityMultiplier > 1 then
				t_insert(breakdown.PvpTotalDPS, s_format("x %g ^8(quantity multiplier for this skill)", quantityMultiplier))
			end
			t_insert(breakdown.PvpTotalDPS, s_format("= %.1f", output.PvpTotalDPS))
		end
	end

	if skillFlags.minion then
		skillData.summonSpeed = output.SummonedMinionsPerCast * (output.HitSpeed or output.Speed) * skillData.dpsMultiplier
	end

	-- Calculate leech rates
	output.LifeLeechInstanceRate = output.Life * data.misc.LeechRateBase * calcLib.mod(skillModList, skillCfg, "LifeLeechRate")
	output.LifeLeechRate = output.LifeLeechInstances * output.LifeLeechInstanceRate
	output.LifeLeechPerHit = output.LifeLeechInstanceRate
	output.EnergyShieldLeechInstanceRate = output.EnergyShield * data.misc.LeechRateBase * calcLib.mod(skillModList, skillCfg, "EnergyShieldLeechRate")
	output.EnergyShieldLeechRate = output.EnergyShieldLeechInstances * output.EnergyShieldLeechInstanceRate
	output.EnergyShieldLeechPerHit = output.EnergyShieldLeechInstanceRate
	output.ManaLeechInstanceRate = output.Mana * data.misc.LeechRateBase * calcLib.mod(skillModList, skillCfg, "ManaLeechRate")
	output.ManaLeechRate = output.ManaLeechInstances * output.ManaLeechInstanceRate
	output.ManaLeechPerHit = output.ManaLeechInstanceRate
	-- On full life, Immortal Ambition treats life leech as energy shield leech
	if skillModList:Flag(nil, "ImmortalAmbition") then
		output.EnergyShieldLeechRate = output.EnergyShieldLeechRate + output.LifeLeechRate
		output.EnergyShieldLeechPerHit = output.EnergyShieldLeechPerHit  + output.LifeLeechPerHit
		-- Clears output.LifeLeechRate to disable leechLife flag
		output.LifeLeechRate = 0
		output.LifeLeechPerHit = 0
	end
	output.LifeLeechRate = output.LifeLeechInstantRate + m_min(output.LifeLeechRate, output.MaxLifeLeechRate) * output.LifeRecoveryRateMod
	output.LifeLeechPerHit = output.LifeLeechInstant + m_min(output.LifeLeechPerHit, output.MaxLifeLeechRate) * output.LifeLeechDuration * output.LifeRecoveryRateMod
	output.EnergyShieldLeechRate = output.EnergyShieldLeechInstantRate + m_min(output.EnergyShieldLeechRate, output.MaxEnergyShieldLeechRate) * output.EnergyShieldRecoveryRateMod
	output.EnergyShieldLeechPerHit = output.EnergyShieldLeechInstant + m_min(output.EnergyShieldLeechPerHit, output.MaxEnergyShieldLeechRate) * output.EnergyShieldLeechDuration * output.EnergyShieldRecoveryRateMod
	output.ManaLeechRate = output.ManaLeechInstantRate + m_min(output.ManaLeechRate, output.MaxManaLeechRate) * output.ManaRecoveryRateMod
	output.ManaLeechPerHit = output.ManaLeechInstant + m_min(output.ManaLeechPerHit, output.MaxManaLeechRate) * output.ManaLeechDuration * output.ManaRecoveryRateMod
	skillFlags.leechLife = output.LifeLeechRate > 0
	skillFlags.leechES = output.EnergyShieldLeechRate > 0
	skillFlags.leechMana = output.ManaLeechRate > 0
	if skillData.showAverage then
		output.LifeLeechGainPerHit = output.LifeLeechPerHit + output.LifeOnHit
		output.EnergyShieldLeechGainPerHit = output.EnergyShieldLeechPerHit + output.EnergyShieldOnHit
		output.ManaLeechGainPerHit = output.ManaLeechPerHit + output.ManaOnHit
	else
		output.LifeLeechGainRate = output.LifeLeechRate + output.LifeOnHitRate
		output.EnergyShieldLeechGainRate = output.EnergyShieldLeechRate + output.EnergyShieldOnHitRate
		output.ManaLeechGainRate = output.ManaLeechRate + output.ManaOnHitRate
	end
	if breakdown then
		local hitRate = output.HitChance / 100 * (globalOutput.HitSpeed or globalOutput.Speed) * skillData.dpsMultiplier
		if skillFlags.leechLife then
			breakdown.LifeLeech = breakdown.leech(output.LifeLeechInstant, output.LifeLeechInstantRate, output.LifeLeechInstances, output.Life, "LifeLeechRate", output.MaxLifeLeechRate, output.LifeLeechDuration, output.LifeLeechInstantProportion, hitRate)
		end
		if skillFlags.leechES then
			breakdown.EnergyShieldLeech = breakdown.leech(output.EnergyShieldLeechInstant, output.EnergyShieldLeechInstantRate, output.EnergyShieldLeechInstances, output.EnergyShield, "EnergyShieldLeechRate", output.MaxEnergyShieldLeechRate, output.EnergyShieldLeechDuration, output.EnergyShieldLeechInstantProportion, hitRate)
		end
		if skillFlags.leechMana then
			breakdown.ManaLeech = breakdown.leech(output.ManaLeechInstant, output.ManaLeechInstantRate, output.ManaLeechInstances, output.Mana, "ManaLeechRate", output.MaxManaLeechRate, output.ManaLeechDuration, output.ManaLeechInstantProportion, hitRate)
		end
	end

	skillFlags.impale = false

	-- Calculate skill DOT components
	local dotCfg = {
		skillName = skillCfg.skillName,
		skillPart = skillCfg.skillPart,
		skillTypes = skillCfg.skillTypes,
		slotName = skillCfg.slotName,
		skillGrantedEffect = skillCfg.skillGrantedEffect,
		flags = bor(ModFlag.Dot, skillCfg.flags),
		keywordFlags = band(skillCfg.keywordFlags, bnot(KeywordFlag.Hit)),
		groupSource = skillCfg.groupSource
	}
	if bor(dotCfg.flags, ModFlag.Area) == dotCfg.flags and not skillData.dotIsArea then
		dotCfg.flags = band(dotCfg.flags, bnot(ModFlag.Area))
	end
	if bor(dotCfg.flags, ModFlag.Projectile) == dotCfg.flags and not skillData.dotIsProjectile then
		dotCfg.flags = band(dotCfg.flags, bnot(ModFlag.Projectile))
	end
	if bor(dotCfg.flags, ModFlag.Spell) == dotCfg.flags and not skillData.dotIsSpell then
		dotCfg.flags = band(dotCfg.flags, bnot(ModFlag.Spell))
	end
	if bor(dotCfg.flags, ModFlag.Attack) == dotCfg.flags and not skillData.dotIsAttack then
		dotCfg.flags = band(dotCfg.flags, bnot(ModFlag.Attack))
	end
	if bor(dotCfg.flags, ModFlag.Hit) == dotCfg.flags and not skillData.dotIsHit then
		dotCfg.flags = band(dotCfg.flags, bnot(ModFlag.Hit))
	end

	-- spell_damage_modifiers_apply_to_skill_dot does not apply to enemy damage taken
	local dotTakenCfg = copyTable(dotCfg, true)
	if (skillData.dotIsSpell) then
		dotTakenCfg.flags = band(dotTakenCfg.flags, bnot(ModFlag.Spell))
	end

	activeSkill.dotCfg = dotCfg
	output.TotalDotInstance = 0

	runSkillFunc("preDotFunc")

	for _, damageType in ipairs(dmgTypeList) do
		local dotTypeCfg = copyTable(dotCfg, true)
		dotTypeCfg.keywordFlags = bor(dotTypeCfg.keywordFlags, KeywordFlag[damageType.."Dot"])
		activeSkill["dot"..damageType.."Cfg"] = dotTypeCfg
		local baseVal
		if canDeal[damageType] then
			baseVal = skillData[damageType.."Dot"] or 0
		else
			baseVal = 0
		end
		if baseVal > 0 or (output[damageType.."Dot"] or 0) > 0 then
			if skillData.duration then
				-- Base damage is applied over the given base duration
				baseVal = baseVal / skillData.duration
			end
			skillFlags.dot = true
			local effMult = 1
			if env.mode_effective then
				local resist = 0
				local takenInc = enemyDB:Sum("INC", dotTakenCfg, "DamageTaken", "DamageTakenOverTime", damageType.."DamageTaken", damageType.."DamageTakenOverTime") + (isElemental[damageType] and enemyDB:Sum("INC", dotTakenCfg, "ElementalDamageTaken") or 0)
				local takenMore = enemyDB:More(dotTakenCfg, "DamageTaken", "DamageTakenOverTime", damageType.."DamageTaken", damageType.."DamageTakenOverTime") * (isElemental[damageType] and enemyDB:More(dotTakenCfg, "ElementalDamageTaken") or 1)
				local pen = skillModList:Sum("BASE", dotCfg, damageType.."Penetration", "Penetration")
				if damageType == "Physical" then
					resist = m_max(0, m_min(enemyDB:Sum("BASE", nil, "PhysicalDamageReduction"), data.misc.DamageReductionCap))
				else
					resist = calcResistForType(damageType, dotTypeCfg)
				end
				effMult = (1 - (resist - pen) / 100) * (1 + takenInc / 100) * takenMore
				output[damageType.."DotEffMult"] = effMult
				if breakdown and effMult ~= 1 then
					local sourceRes = env.modDB:Flag(nil, "Enemy"..damageType.."ResistEqualToYours") and "Your "..damageType.." Resistance" or (env.partyMembers.modDB:Flag(nil, "Enemy"..damageType.."ResistEqualToYours") and "Party Member "..damageType.." Resistance" or damageType)
					breakdown[damageType.."DotEffMult"] = breakdown.effMult(damageType, resist, pen, takenInc, effMult, takenMore, sourceRes, true)
				end
			end
			local inc = skillModList:Sum("INC", dotTypeCfg, "Damage", damageType.."Damage", isElemental[damageType] and "ElementalDamage" or nil)
			local more = skillModList:More(dotTypeCfg, "Damage", damageType.."Damage", isElemental[damageType] and "ElementalDamage" or nil)
			local mult = skillModList:Sum("BASE", dotTypeCfg, "DotMultiplier", damageType.."DotMultiplier")
			local aura = activeSkill.skillTypes[SkillType.Aura] and not activeSkill.skillTypes[SkillType.RemoteMined] and calcLib.mod(skillModList, dotTypeCfg, "AuraEffect")
			local total = baseVal * (1 + inc/100) * more * (1 + mult/100) * (aura or 1) * effMult
			if output[damageType.."Dot"] == 0 or output[damageType.."Dot"] == nil then
				output[damageType.."Dot"] = total
				output.TotalDotInstance = m_min(output.TotalDotInstance + total, data.misc.DotDpsCap)
			else
				output.TotalDotInstance = m_min(output.TotalDotInstance + total + (output[damageType.."Dot"] or 0), data.misc.DotDpsCap)
			end
			if breakdown then
				breakdown[damageType.."Dot"] = { }
				breakdown.dot(breakdown[damageType.."Dot"], baseVal, inc, more, mult, nil, aura, effMult, total)
			end
		end
	end
	if skillModList:Flag(nil, "DotCanStack") then
		skillFlags.DotCanStack = true
		local speed = output.Speed
		output.TotalDot = output.TotalDotInstance * speed * output.Duration * skillData.dpsMultiplier * quantityMultiplier
		output.TotalDotCalcSection = output.TotalDot
		output.MaxStacks = round(speed * output.Duration * quantityMultiplier, 2)
		if breakdown then
			breakdown.MaxStacks = {
				s_format("%.2f ^8(hits per second)", speed),
				s_format("x %.2f ^8(skill duration)", output.Duration),
			}
			breakdown.TotalDot = {
				s_format("%.1f ^8(Damage per Instance)", output.TotalDotInstance),
				s_format("x %.2f ^8(max stacks)", output.MaxStacks),
			}
			if skillData.dpsMultiplier ~= 1 then
				t_insert(breakdown.TotalDot, s_format("x %g ^8(DPS multiplier for this skill)", skillData.dpsMultiplier))
			end
			if quantityMultiplier > 1 then
				t_insert(breakdown.TotalDot, s_format("x %g ^8(quantity multiplier for this skill)", quantityMultiplier))
			end
			t_insert(breakdown.TotalDot, s_format("= %.1f", output.TotalDot))
		end
	elseif skillModList:Flag(nil, "dotIsBurningGround") then
		output.TotalDot = 0
		output.TotalDotCalcSection = output.TotalDotInstance
		if not output.BurningGroundDPS or output.BurningGroundDPS < output.TotalDotInstance then
			output.BurningGroundDPS = m_max(output.BurningGroundDPS or 0, output.TotalDotInstance)
			output.BurningGroundFromIgnite = false
		end
	elseif skillModList:Flag(nil, "dotIsCausticGround") then
		output.TotalDot = 0
		output.TotalDotCalcSection = output.TotalDotInstance
		if not output.CausticGroundDPS or output.CausticGroundDPS < output.TotalDotInstance then
			output.CausticGroundDPS = m_max(output.CausticGroundDPS or 0, output.TotalDotInstance)
			output.CausticGroundFromPoison = false
		end
	elseif skillModList:Flag(nil, "dotIsCorruptingBlood") then
		output.TotalDot = 0
		output.TotalDotCalcSection = output.TotalDotInstance
		if not output.CorruptingBloodDPS or output.CorruptingBloodDPS < output.TotalDotInstance then
			output.CorruptingBloodDPS = m_max(output.CorruptingBloodDPS or 0, output.TotalDotInstance)
		end
	else
		if skillModList:Flag(nil, "DotCanStackAsTotems") and skillFlags.totem then
			skillFlags.DotCanStack = true
		end
		output.TotalDot = output.TotalDotInstance
		output.TotalDotCalcSection = output.TotalDotInstance
	end

	--Calculates and displays cost per second for skills that don't already have one (link skills)
	for resource, val in pairs(costs) do
		local EB = env.modDB:Flag(nil, "EnergyShieldProtectsMana")
		if(val.upfront and output[resource.."HasCost"] and output[resource.."Cost"] > 0 and not (output[resource.."PerSecondHasCost"] and not (EB and skillModList:Sum("BASE", skillCfg, "ManaCostAsEnergyShieldCost"))) and (output.Speed > 0 or output.Cooldown)) then
			local usedResource = resource

			if EB and resource == "Mana" then
				usedResource = "ES"
			end

			local repeats = output.Repeats or 1
			local useSpeed = 1
			local timeType
			if skillFlags.trap or skillFlags.mine then
				local preSpeed = output.TrapThrowingSpeed or output.MineLayingSpeed
				local cooldown = output.TrapCooldown or output.Cooldown
				useSpeed = (cooldown and cooldown > 0 and 1 / cooldown or preSpeed) / repeats
				timeType = skillFlags.trap and "trap throwing" or "mine laying"
			elseif skillFlags.totem then
				useSpeed = (output.Cooldown and output.Cooldown > 0 and (output.TotemPlacementSpeed > 0 and output.TotemPlacementSpeed or 1 / output.Cooldown) or output.TotemPlacementSpeed) / repeats
				timeType = "totem placement"
			elseif skillModList:Flag(nil, "HasSeals") and skillModList:Flag(nil, "UseMaxUnleash") then
				useSpeed = env.player.mainSkill.skillData.hitTimeOverride / repeats
				timeType = "full unleash"
			else
				useSpeed = (output.Cooldown and output.Cooldown > 0 and (output.Speed > 0 and output.Speed or 1 / output.Cooldown) or output.Speed) / repeats
				timeType = skillData.triggered and "trigger" or (skillFlags.totem and "totem placement" or skillFlags.attack and "attack" or "cast")
			end

			output[usedResource.."PerSecondHasCost"] = true
			output[usedResource.."PerSecondCost"] = (output[usedResource.."PerSecondCost"] or 0)+ output[resource.."Cost"] * useSpeed

			if breakdown then
				breakdown[usedResource.."PerSecondCost"] = copyTable(breakdown[resource.."Cost"])
				t_remove(breakdown[usedResource.."PerSecondCost"])
				t_insert(breakdown[usedResource.."PerSecondCost"], s_format("x %.2f ^8("..timeType.." speed)", useSpeed))
				t_insert(breakdown[usedResource.."PerSecondCost"], s_format("= %.2f per second", output[usedResource.."PerSecondCost"]))
			end
		end
	end

	-- Self hit dmg calcs
	do
		-- Based on code from FR and BS found in act_*.txt
		local function applyDmgTakenConversion(sourceType, baseDmg)
			local damageBreakdown = {}
			local totalDamageTaken = 0
			local totalTakenAs = activeSkill.skillModList:Sum("BASE", nil, "PhysicalDamageTakenAsLightning","PhysicalDamageTakenAsCold","PhysicalDamageTakenAsFire","PhysicalDamageTakenAsChaos") / 100
			for _, damageType in ipairs(dmgTypeList) do
				local damageTakenAs = 1

				if damageType ~= sourceType then
					damageTakenAs = (activeSkill.skillModList:Sum("BASE", nil, sourceType.."DamageTakenAs"..damageType) or 0) / 100
				else
					damageTakenAs = math.max(1 - totalTakenAs, 0)
				end

				if damageTakenAs ~= 0 then
					if(totalTakenAs > 1) then
						damageTakenAs = damageTakenAs / totalTakenAs
					end
					local damage = baseDmg * damageTakenAs

					local baseTakenInc = activeSkill.skillModList:Sum("INC", nil, "DamageTaken", damageType.."DamageTaken", "DamageTakenWhenHit", damageType.."DamageTakenWhenHit")
					local baseTakenMore = activeSkill.skillModList:More(nil, "DamageTaken", damageType.."DamageTaken","DamageTakenWhenHit", damageType.."DamageTakenWhenHit")
					if (damageType == "Lightning" or damageType == "Cold" or damageType == "Fire") then
						baseTakenInc = baseTakenInc + activeSkill.skillModList:Sum("INC", nil, "ElementalDamageTaken", "ElementalDamageTakenWhenHit")
						baseTakenMore = baseTakenMore * activeSkill.skillModList:More(nil, "ElementalDamageTaken", "ElementalDamageTakenWhenHit")
					end
					local damageTakenMods = math.max((1 + baseTakenInc / 100) * baseTakenMore, 0)
					local reduction = activeSkill.skillModList:Flag(nil, "SelfIgnore".."Base"..damageType.."DamageReduction") and 0 or output["Base"..damageType.."DamageReductionWhenHit"] or output["Base"..damageType.."DamageReduction"]
					local resist = activeSkill.skillModList:Flag(nil, "SelfIgnore"..damageType.."Resistance") and 0 or output[damageType.."ResistWhenHit"] or output[damageType.."Resist"]
					local armourReduct = 0
					local resMult = 1 - resist / 100
					local reductMult = 1

					local percentOfArmourApplies = math.min((not activeSkill.skillModList:Flag(nil, "ArmourDoesNotApplyTo"..damageType.."DamageTaken") and activeSkill.skillModList:Sum("BASE", nil, "ArmourAppliesTo"..damageType.."DamageTaken") or 0), 100)
					if percentOfArmourApplies > 0 then
						local effArmour = (output.Armour * percentOfArmourApplies / 100) * (1 + output.ArmourDefense)
						local effDamage = damage * resMult
						armourReduct = round(effArmour ~= 0 and damage * resMult ~= 0 and (effArmour / (effArmour + effDamage * 5) * 100) or 0)
						armourReduct = math.min(output.DamageReductionMax, armourReduct)
					end
					reductMult = (1 - math.max(math.min(output.DamageReductionMax, armourReduct + reduction), 0) / 100) * damageTakenMods
					local combinedMult = resMult * reductMult
					local finalDamage = damage * combinedMult
					totalDamageTaken = totalDamageTaken + finalDamage

					if breakdown then
						t_insert(damageBreakdown, damageType.." Damage Taken")
						if damageTakenAs ~= 1 then
							t_insert(damageBreakdown, s_format("^8=^7 %d^8 (Base Damage)^7 * %.2f^8 (Damage taken as %s)", baseDmg, damageTakenAs, damageType))
						end
						if combinedMult ~= 1 then
							t_insert(damageBreakdown, s_format("^8=^7 %d^8 (%s Damage)^7 * %.4f^8 (Damage taken multi)", damage, damageType, combinedMult))
						end
						t_insert(damageBreakdown, s_format("^8=^7 %d^8 (%s Damage taken)", finalDamage, damageType))
						t_insert(damageBreakdown, s_format(""))
					end
				end
			end
			return damageBreakdown, totalDamageTaken
		end

		-- Handler functions for self hit sources
		local nameToHandler = {
			["Heartbound Loop"] = function(activeSkill, output, breakdown)
				local dmgType, dmgVal
				for _, value in ipairs(activeSkill.skillModList:List(nil, "HeartboundLoopSelfDamage")) do -- Combines dmg taken from both ring accounting for catalysts
					dmgVal = (dmgVal or 0) + value.baseDamage
					dmgType = string.gsub(" "..value.damageType, "%W%l", string.upper):sub(2) -- This assumes both rings deal the same damage type
				end
				if activeSkill.activeEffect.grantedEffect.name == "Summon Skeletons" and dmgType and dmgVal then
					local dmgBreakdown, totalDmgTaken = applyDmgTakenConversion(dmgType, dmgVal)
					t_insert(dmgBreakdown, 1, s_format("Heartbound Loop base damage: %d", dmgVal))
					t_insert(dmgBreakdown, 2, s_format(""))
					t_insert(dmgBreakdown, s_format("Total Heartbound Loop damage taken per cast/attack: %.2f * %d ^8(minions per cast)^7 = %.2f",totalDmgTaken, output.SummonedMinionsPerCast, totalDmgTaken * output.SummonedMinionsPerCast))
					return dmgBreakdown, totalDmgTaken * output.SummonedMinionsPerCast
				end
			end,
			["Eye of Innocence"] = function(activeSkill, output, breakdown)
				local dmgType, dmgVal
				for _, value in ipairs(activeSkill.skillModList:List(nil, "EyeOfInnocenceSelfDamage")) do
					dmgVal = value.baseDamage
					dmgType = string.gsub(" "..value.damageType, "%W%l", string.upper):sub(2)
					break -- Only one mod of this kind is expected here
				end
				if activeSkill.skillFlags.ignite and dmgType and dmgVal then
					local dmgBreakdown, totalDmgTaken = applyDmgTakenConversion(dmgType, dmgVal)
					t_insert(dmgBreakdown, 1, s_format("Eye of Innocence base damage: %d", dmgVal))
					t_insert(dmgBreakdown, 2, s_format(""))
					t_insert(dmgBreakdown, s_format("Total Eye of Innocence damage taken per cast/attack: %.2f ", totalDmgTaken))
					return dmgBreakdown, totalDmgTaken
				end
			end,
			["Scold's Bridle"] = function(activeSkill, output, breakdown)
				local dmgType, dmgMult
				for _, value in ipairs(activeSkill.skillModList:List(nil, "ScoldsBridleSelfDamage")) do
					dmgMult = value.dmgMult
					dmgType = string.gsub(" "..value.damageType, "%W%l", string.upper):sub(2)
					break -- Only one mod of this kind is expected here
				end
				if output.ManaHasCost and dmgType and dmgMult then
					local dmgBreakdown, totalDmgTaken = applyDmgTakenConversion(dmgType, (output.ManaCost or 0) * dmgMult/100)
					t_insert(dmgBreakdown, 1, s_format("Scold's Bridle base damage: %d ^8(Mana Cost)^7 * %d%% = %.2f", (output.ManaCost or 0), dmgMult, (output.ManaCost or 0) * dmgMult/100))
					t_insert(dmgBreakdown, 2, s_format(""))
					t_insert(dmgBreakdown, s_format("Total Scold's Bridle damage taken per cast/attack: %.2f ", totalDmgTaken))
					return dmgBreakdown, totalDmgTaken
				end
			end,
			["Trauma"] = function(activeSkill, output, breakdown)
				local dmgType = "Physical"
				local currentTraumaStacks =  math.max(activeSkill.skillModList:Sum("BASE", nil, "Multiplier:TraumaStacks"), 1)
				local damagePerTrauma = activeSkill.skillModList:Sum("BASE", nil, "TraumaSelfDamageTakenLife")
				local dmgVal = activeSkill.baseSkillModList:Flag(nil, "HasTrauma") and damagePerTrauma * currentTraumaStacks
				if dmgType and dmgVal then
					local dmgBreakdown, totalDmgTaken = applyDmgTakenConversion(dmgType, dmgVal)
					t_insert(dmgBreakdown, 1, s_format("%d ^8(base %s damage)^7 * %.2f ^8(%s trauma)^7 = %.2f %s damage", damagePerTrauma, dmgType, currentTraumaStacks, activeSkill.skillModList:Sum("BASE", skillCfg, "Multiplier:SustainableTraumaStacks") == currentTraumaStacks and "sustainable" or "current", dmgVal, dmgType))
					t_insert(dmgBreakdown, 2, s_format(""))
					t_insert(dmgBreakdown, s_format("Total Trauma damage taken per cast/attack: %.2f ", totalDmgTaken))
					return dmgBreakdown, totalDmgTaken
				end
			end,
		}

		for _, sourceFunc in pairs(nameToHandler) do
			local selfHitBreakdown, dmgTaken = sourceFunc(activeSkill, output, breakdown)
			if dmgTaken then
				output.SelfHitDamage = (output.SelfHitDamage or 0) + dmgTaken
			end
			if breakdown and selfHitBreakdown then
				breakdown.SelfHitDamage = breakdown.SelfHitDamage or {}
				for _, line in ipairs(selfHitBreakdown) do
					t_insert(breakdown.SelfHitDamage, line)
				end
				t_insert(breakdown.SelfHitDamage, "")
			end
		end

		-- Special handling for self hit skills
		-- These need to be handled higher up in this file using runFuncs for correct DPS calcs
		for selfHitSkill, displayName in pairs({["FRDamageTaken"] = "Forbidden Rite"}) do
			if output[selfHitSkill] then
				output.SelfHitDamage = (output.SelfHitDamage or 0) + output[selfHitSkill]
			end
			if breakdown and breakdown[selfHitSkill] then
				breakdown.SelfHitDamage = breakdown.SelfHitDamage or {}
				for _, line in ipairs(breakdown[selfHitSkill]) do
					t_insert(breakdown.SelfHitDamage, line)
				end
				t_insert(breakdown.SelfHitDamage, "")
			end
		end

		if breakdown and breakdown.SelfHitDamage then
			breakdown.SelfHitDamage[#breakdown.SelfHitDamage] = nil -- Remove new line at the end
		end
	end

	-- Calculate combined DPS estimate, including DoTs
	local baseDPS = output[(skillData.showAverage and "AverageDamage") or "TotalDPS"]
	output.CombinedDPS = baseDPS
	output.CombinedAvg = baseDPS
	if skillFlags.dot then
		output.WithDotDPS = baseDPS + (output.TotalDot or 0)
	end
	if quantityMultiplier > 1 and output.TotalPoisonDPS then
		output.TotalPoisonDPS = m_min(output.TotalPoisonDPS * quantityMultiplier, data.misc.DotDpsCap)
	end
	if skillData.showAverage then
		output.CombinedAvg = output.CombinedAvg + (output.TotalPoisonAverageDamage or 0)
		output.WithPoisonDPS = baseDPS + (output.TotalPoisonAverageDamage or 0)
	else
		output.WithPoisonDPS = baseDPS + (output.TotalPoisonDPS or 0)
	end
	if skillFlags.ignite then
		if skillFlags.igniteCanStack then
			if skillData.showAverage then
				output.CombinedAvg = output.CombinedDPS + output.IgniteDamage
			else
				output.WithIgniteDPS = baseDPS + output.TotalIgniteDPS
			end
		elseif skillData.showAverage then
			output.WithIgniteDPS = baseDPS + output.IgniteDamage
			output.CombinedAvg = output.CombinedAvg + output.IgniteDamage
		else
			output.WithIgniteDPS = baseDPS + output.IgniteDPS
		end
	else
		output.WithIgniteDPS = baseDPS
	end
	if skillFlags.monsterExplode then
		output.CombinedAvgToMonsterLife = output.CombinedAvg / monsterLife * 100
	end
	if skillFlags.bleed then
		if skillData.showAverage then
			output.WithBleedDPS = baseDPS + output.BleedDamage
			output.CombinedAvg = output.CombinedAvg + output.BleedDamage
		else
			output.WithBleedDPS = baseDPS + output.BleedDPS
		end
	else
		output.WithBleedDPS = baseDPS
	end
	local TotalDotDPS = (output.TotalDot or 0) + (output.TotalPoisonDPS or 0) + (output.CausticGroundDPS or 0) + (output.TotalIgniteDPS or output.IgniteDPS or 0) + (output.BurningGroundDPS  or 0) + (output.BleedDPS or 0) + (output.CorruptingBloodDPS or 0) + (output.DecayDPS or 0)
	output.TotalDotDPS = m_min(TotalDotDPS, data.misc.DotDpsCap)
	if output.TotalDotDPS ~= TotalDotDPS then
		output.showTotalDotDPS = true
	end
	if not skillData.showAverage then
		output.CombinedDPS = output.CombinedDPS + output.TotalDotDPS
	end
	if skillFlags.impale then
		if skillFlags.attack then
			output.ImpaleHit = ((output.MainHand.PhysicalHitAverage or output.OffHand.PhysicalHitAverage) + (output.OffHand.PhysicalHitAverage or output.MainHand.PhysicalHitAverage)) / 2 * (1-output.CritChance/100) + ((output.MainHand.PhysicalCritAverage or output.OffHand.PhysicalCritAverage) + (output.OffHand.PhysicalCritAverage or output.MainHand.PhysicalCritAverage)) / 2 * (output.CritChance/100)
			if skillData.doubleHitsWhenDualWielding and skillFlags.bothWeaponAttack then
				output.ImpaleHit = output.ImpaleHit * 2
			end
		else
			output.ImpaleHit = output.PhysicalHitAverage * (1-output.CritChance/100) + output.PhysicalCritAverage * (output.CritChance/100)
		end
		output.ImpaleDPS = output.ImpaleHit * ((output.ImpaleModifier or 1) - 1) * output.HitChance / 100 * skillData.dpsMultiplier
		if skillData.showAverage then
			output.WithImpaleDPS = output.AverageDamage + output.ImpaleDPS
			output.CombinedAvg = output.CombinedAvg + output.ImpaleDPS
		else
			skillFlags.notAverage = true
			output.ImpaleDPS = output.ImpaleDPS * (output.HitSpeed or output.Speed)
			output.WithImpaleDPS = output.TotalDPS + output.ImpaleDPS
		end
		if quantityMultiplier > 1 then
			output.ImpaleDPS = output.ImpaleDPS * quantityMultiplier
		end
		output.CombinedDPS = output.CombinedDPS + output.ImpaleDPS
		if breakdown then
			breakdown.ImpaleDPS = {}
			t_insert(breakdown.ImpaleDPS, s_format("%.2f ^8(average physical hit)", output.ImpaleHit))
			t_insert(breakdown.ImpaleDPS, s_format("x %.2f ^8(chance to hit)", output.HitChance / 100))
			if skillFlags.notAverage then
				t_insert(breakdown.ImpaleDPS, output.HitSpeed and s_format("x %.2f ^8(hit rate)", output.HitSpeed) or s_format("x %.2f ^8(%s rate)", output.Speed, skillFlags.attack and "attack" or "cast"))
			end
			t_insert(breakdown.ImpaleDPS, s_format("x %.2f ^8(impale damage multiplier)", ((output.ImpaleModifier or 1) - 1)))
			if skillData.dpsMultiplier ~= 1 then
				t_insert(breakdown.ImpaleDPS, s_format("x %g ^8(dps multiplier for this skill)", skillData.dpsMultiplier))
			end
			if quantityMultiplier > 1 then
				t_insert(breakdown.ImpaleDPS, s_format("x %g ^8(quantity multiplier for this skill)", quantityMultiplier))
			end
			t_insert(breakdown.ImpaleDPS, s_format("= %.1f", output.ImpaleDPS))
		end
	end

	local bestCull = 1
	if activeSkill.mirage and activeSkill.mirage.output and activeSkill.mirage.output.TotalDPS then
		local mirageCount = activeSkill.mirage.count or 1
		output.MirageDPS = activeSkill.mirage.output.TotalDPS * mirageCount
		output.CombinedDPS = output.CombinedDPS + activeSkill.mirage.output.TotalDPS * mirageCount

		if activeSkill.mirage.output.IgniteDPS and activeSkill.mirage.output.IgniteDPS > (output.IgniteDPS or 0) then
			output.MirageDPS = output.MirageDPS + activeSkill.mirage.output.IgniteDPS
			output.IgniteDPS = 0
		end
		if activeSkill.mirage.output.BleedDPS and activeSkill.mirage.output.BleedDPS > (output.BleedDPS or 0) then
			output.MirageDPS = output.MirageDPS + activeSkill.mirage.output.BleedDPS
			output.BleedDPS = 0
		end

		if activeSkill.mirage.output.PoisonDPS then
			output.MirageDPS = output.MirageDPS + activeSkill.mirage.output.PoisonDPS * mirageCount
			output.CombinedDPS = output.CombinedDPS + activeSkill.mirage.output.PoisonDPS * mirageCount
		end
		if activeSkill.mirage.output.ImpaleDPS then
			output.MirageDPS = output.MirageDPS + activeSkill.mirage.output.ImpaleDPS * mirageCount
			output.CombinedDPS = output.CombinedDPS + activeSkill.mirage.output.ImpaleDPS * mirageCount
		end
		if activeSkill.mirage.output.DecayDPS then
			output.MirageDPS = output.MirageDPS + activeSkill.mirage.output.DecayDPS
			output.CombinedDPS = output.CombinedDPS + activeSkill.mirage.output.DecayDPS
		end
		if activeSkill.mirage.output.TotalDot and (skillFlags.DotCanStack or not output.TotalDot or output.TotalDot == 0) then
			output.MirageDPS = output.MirageDPS + activeSkill.mirage.output.TotalDot * (skillFlags.DotCanStack and mirageCount or 1)
			output.CombinedDPS = output.CombinedDPS + activeSkill.mirage.output.TotalDot * (skillFlags.DotCanStack and mirageCount or 1)
		end
		if activeSkill.mirage.output.CullMultiplier > 1 then
			bestCull = activeSkill.mirage.output.CullMultiplier
		end
	end

	bestCull = m_max(bestCull, output.CullMultiplier)
	output.CullingDPS = output.CombinedDPS * (bestCull - 1)
	output.ReservationDPS = output.CombinedDPS * (output.ReservationDpsMultiplier - 1)
	output.CombinedDPS = output.CombinedDPS * bestCull * output.ReservationDpsMultiplier
end
