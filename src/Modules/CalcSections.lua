-- Path of Building
--
-- Module: Calc Sections
-- List of sections for the Calcs tab
--

-- format {width, id, group, color, subsection:{default hidden, label, data:{}}}
return {
{ 3, "HitDamage", 1, colorCodes.OFFENCE, {{ defaultCollapsed = false, label = "Skill Damage", data = {
	extra = "{output:DisplayDamage}",
	colWidth = 95,
	generateTableByValues(
			{{ format = "All Types:", }},
			DamageTypesColored, function (_,damageType)
				return { format = damageType .. ":" }
			end),
	generateTableByValues(
			{ label = "Added", flag = "notAilment",
			  { format = "{0:mod:1}", { modName = "Damage", modType = "BASE", cfg = "skill" }, },
			},
			DamageTypes, function (_,damageType)
				return { format = "{0:mod:1,2}",
						 { label = "Player modifiers", modName = damageType .. "Damage", modType = "BASE", cfg = "skill" },
						 { label = "Enemy modifiers", modName = "Self" .. damageType .. "Damage", modType = "BASE", enemy = true, cfg = "skill" }, }
			end),
	-- Skill Hit Damage
	generateTableByValues(
			{ label = "Total Increased",
			  { format = "{0:mod:1}%", { modName = "Damage", modType = "INC", cfg = "skill" }, },
			},
			DamageTypes, function (_,damageType)
				return { format = "{0:mod:1}%", { modName = damageType .. "Damage", modType = "INC", cfg = "skill" }, }
			end),
	generateTableByValues(
			{ label = "Total More",
			  { format = "{0:mod:1}%", { modName = "Damage", modType = "MORE", cfg = "skill" }, },
			},
			DamageTypes, function (_,damageType)
				return { format = "{0:mod:1}%", { modName = damageType .. "Damage", modType = "MORE", cfg = "skill" }, }
			end),
	generateTableByValues(
			{ label = "Effective DPS Mod", flag = "effective",
			  { },
			},
			DamageTypes, function (_,damageType)
				return { format = "x {3:output:" .. damageType .. "EffMult}",
						 { breakdown = damageType .. "EffMult" },
						 { label = "Player modifiers", modName = { damageType .. "Penetration", "Ignore" .. damageType .. "Resistance" }, cfg = "skill" },
						 { label = "Enemy modifiers", modName = { "DamageTaken", damageType .. "DamageTaken", damageType .. "Resist" }, enemy = true, cfg = "skill" },
				}
			end),
	generateTableByValues(
			{ label = "Skill Hit Damage", textSize = 12,
			  {  },
			},
			DamageTypes, function (_,damageType)
				return { format = "{1:output:" .. damageType .. "Damage}",
						 { breakdown = damageType },
				}
			end),
	{ label = "Skill Average Hit", { format = "{1:output:AverageHit}", { breakdown = "AverageHit" }, }, },
	{ label = "Skill PvP Average Hit", flag = "notAttackPvP", { format = "{1:output:PvpAverageHit}", { breakdown = "PvpAverageHit" },
		{ label = "Tvalue Override (ms)", modName = "MultiplierPvpTvalueOverride" },
		{ label = "PvP Multiplier", cfg = "skill", modName = "PvpDamageMultiplier" },
	}, },
	{ label = "Chance to Hit", haveOutput = "enemyHasSpellBlock", { format = "{0:output:HitChance}%",
		{ breakdown = "HitChance" },
		{ label = "Enemy Block", modName = { "BlockChance" }, enemy = true },
		{ label = "Block Chance Reduction", cfg = "skill", modName = { "reduceEnemyBlock" } },
	}, },
	{ label = "Average Damage", haveOutput = "enemyHasSpellBlock", { format = "{1:output:AverageDamage}",
		{ breakdown = "AverageDamage" },
	}, },
	{ label = "Chance to Explode", haveOutput = "ExplodeChance", { format = "{0:output:ExplodeChance}%" }, },
	{ label = "Average Damage", haveOutput = "ExplodeChance", { format = "{1:output:AverageDamage}",
		{ breakdown = "AverageDamage" },
	}, },
	{ label = "PvP Average Dmg", flag = "attackPvP", { format = "{1:output:PvpAverageDamage}",
		{ breakdown = "MainHand.PvpAverageDamage" },
		{ breakdown = "OffHand.PvpAverageDamage" },
		{ breakdown = "PvpAverageDamage" },
		{ label = "Tvalue Override (ms)", modName = "MultiplierPvpTvalueOverride" },
		{ label = "PvP Multiplier", cfg = "skill", modName = "PvpDamageMultiplier" },
	}, },
	{ label = "Skill Stacks", flag = "dot", { format = "{2:output:MaxStacks}", { breakdown = "MaxStacks" }, }, },
	{ label = "Skill DPS", flag = "notAverage", notFlag = "triggered", { format = "{1:output:TotalDPS}", { breakdown = "TotalDPS" }, { label = "DPS Multiplier", modName = "DPS" }, }, },
	{ label = "Skill PvP DPS", flag = "notAveragePvP", { format = "{1:output:PvpTotalDPS}", { breakdown = "PvpTotalDPS" },
		{ label = "Tvalue Override (ms)", modName = "MultiplierPvpTvalueOverride" },
		{ label = "PvP Multiplier", cfg = "skill", modName = "PvpDamageMultiplier" },
		{ label = "DPS Multiplier", modName = "DPS" },
	}, },
	{ label = "Skill DPS", flag = "triggered", { format = "{1:output:TotalDPS}", { breakdown = "TotalDPS" }, { label = "DPS Multiplier", modName = "DPS" }, }, },
} }
} },
{ 1, "Speed", 1, colorCodes.OFFENCE, {{ defaultCollapsed = false, label = "Attack/Cast Rate", data = {
	extra = "{2:output:Speed}/s",
	{ label = "Inc. Att. Speed", flag = "attack", notFlag = "triggered", { format = "{0:mod:1}%", { modName = "Speed", modType = "INC", cfg = "skill", }, }, },
	{ label = "More Att. Speed", flag = "attack", notFlag = "triggered", { format = "{0:mod:1}%", { modName = "Speed", modType = "MORE", cfg = "skill", }, }, },
	{ label = "Att. per second", flag = "attack", notFlag = "triggered", { format = "{2:output:Speed}", { breakdown = "Speed" }, }, },
	{ label = "Attacks per second", flag = "bothWeaponAttack", notFlag = "triggered", { format = "{2:output:Speed}", { breakdown = "Speed" }, }, },
	{ label = "Attack time", flag = "attack", notFlag = "triggered", { format = "{2:output:Time}s", { breakdown = "MainHand.Time" }, }, },
	{ label = "Inc. Cast Speed", flag = "spell", notFlag = "triggered", { format = "{0:mod:1}%", { modName = "Speed", modType = "INC", cfg = "skill", }, }, },
	{ label = "More Cast Speed", flag = "spell", notFlag = "triggered", { format = "{0:mod:1}%", { modName = "Speed", modType = "MORE", cfg = "skill", }, }, },
	{ label = "Casts per second", flag = "spell", notFlag = "triggered", { format = "{2:output:Speed}", { breakdown = "Speed" }, }, },
	{ label = "Cast Time", flag = "addsCastTime", { format = "{2:output:addsCastTime}", { breakdown = "AddedCastTime" }, }, },
	{ label = "Trigger Chance", haveOutput = "TriggerChance", { format = "{2:output:TriggerChance}%", { breakdown = "TriggerChance" }, {modName = "ChanceToTriggerOnHit_{skillId}", modType = "BASE", cfg = "triggerSource" } }, },
	{ label = "Trigger Rate Cap", flag = "triggered", notFlagList = {"focused", "hasOverride"}, { format = "{2:output:TriggerRateCap}", { breakdown = "TriggerRateCap" } }, },
	{ label = "Trigger Rate Cap", flagList = {"triggered", "hasOverride"}, notFlag = "focused", { format = "{2:output:TriggerRateCap}", { breakdown = "TriggerRateCap" }, { modName = "CooldownRecovery", modType = "OVERRIDE", cfg = "skill", }, }, },
	{ label = "Trigger Rate Cap", flagList = {"triggered", "focused"}, { format = "{2:output:TriggerRateCap}", { breakdown = "TriggerRateCap" }, { modName = "FocusCooldownRecovery", modType = "INC", cfg = "skill", }, }, },
	{ label = "Eff. Source Rate", flag = "triggered", notFlag = "focused", notFlag = "globalTrigger", { format = "{2:output:EffectiveSourceRate}", { breakdown = "EffectiveSourceRate" } }, },
	{ label = "Skill Trigger Rate", flag = "triggered", notFlag = "focused", { format = "{2:output:SkillTriggerRate}", { breakdown = "SkillTriggerRate" }, { breakdown = "SimData" }, }, },
	{ label = "Skill Trigger Rate", flagList = {"triggered", "focused"}, { format = "{2:output:SkillTriggerRate}", { breakdown = "SkillTriggerRate" }, { breakdown = "SimData" }, { modName = "FocusCooldownRecovery", modType = "INC", cfg = "skill", }, }, },
	{ label = "Cast time", flag = "spell", notFlag = "triggered", { format = "{2:output:Time}s", }, },
	{ label = "Hit Rate", haveOutput = "HitSpeed", { format = "{2:output:HitSpeed}", { breakdown = "HitSpeed" } }, },
} }
} },
{ 1, "Crit", 1, colorCodes.OFFENCE, {{ defaultCollapsed = false, label = "Crits", data = {
	extra = "{2:output:CritChance}% x{2:output:CritMultiplier}",
	flag = "hit",
	-- Skill
	{ label = "Inc. Crit Chance", { format = "{0:mod:1,2}%",
		{ label = "Player modifiers", modName = "CritChance", modType = "INC", cfg = "skill" },
		{ label = "Enemy modifiers", modName = "SelfCritChance", modType = "INC", enemy = true },
	}, },
	{ label = "Crit Chance", { format = "{2:output:CritChance}%",
		{ breakdown = "CritChance" },
		{ label = "Player modifiers", modName = {"CritChance", "SpellSkillsCannotDealCriticalStrikesExceptOnFinalRepeat", "SpellSkillsAlwaysDealCriticalStrikesOnFinalRepeat"}, cfg = "skill" },
		{ label = "Enemy modifiers", modName = "SelfCritChance", enemy = true },
	}, },
	{ label = "Crit Multiplier", { format = "x {2:output:CritMultiplier}",
		{ breakdown = "CritMultiplier" },
		{ label = "Player modifiers", modName = "CritMultiplier", cfg = "skill" },
		{ label = "Enemy modifiers", modName = "SelfCritMultiplier", enemy = true },
	}, },
	{ label = "Crit Effect Mod", { format = "x {3:output:CritEffect}", { breakdown = "CritEffect" }, }, },
} }
} },
{ 1, "SkillTypeStats", 1, colorCodes.OFFENCE, {{ defaultCollapsed = false, label = "Skill type-specific Stats", data = {
	{ label = "Mana Cost", color = colorCodes.MANA, haveOutput = "ManaHasCost", { format = "{0:output:ManaCost}", { breakdown = "ManaCost" }, { modName = { "ManaCost", "Cost" }, cfg = "skill" }, }, },
	{ label = "Mana % Cost", color = colorCodes.MANA, haveOutput = "ManaPercentHasCost", { format = "{0:output:ManaPercentCost}", { breakdown = "ManaPercentCost" }, { modName = { "ManaCost", "Cost" }, cfg = "skill" }, }, },
	{ label = "Mana per second", color = colorCodes.MANA, haveOutput = "ManaPerSecondHasCost", { format = "{2:output:ManaPerSecondCost}", { breakdown = "ManaPerSecondCost" }, { modName = { "ManaCost", "Cost" }, cfg = "skill" }, }, },
	{ label = "Mana % per second", color = colorCodes.MANA, haveOutput = "ManaPercentPerSecondHasCost", { format = "{2:output:ManaPercentPerSecondCost}", { breakdown = "ManaPercentPerSecondCost" }, { modName = { "ManaCost", "Cost" }, cfg = "skill" }, }, },
	{ label = "Active Minion Limit", haveOutput = "ActiveMinionLimit", { format = "{0:output:ActiveMinionLimit}" } },
	{ label = "Quantity Multiplier", haveOutput = "QuantityMultiplier", { format = "{0:output:QuantityMultiplier}",
	    { breakdown = "QuantityMultiplier" },
	    { modName = { "QuantityMultiplier" }, cfg = "skill" },
	}, },
	{ label = "Skill Cooldown", haveOutput = "Cooldown", { format = "{3:output:Cooldown}s",
		{ breakdown = "Cooldown" },
		{ modName = "CooldownRecovery", cfg = "skill" },
	}, },
	{ label = "Stored Uses", haveOutput = "StoredUses", { format = "{output:StoredUses}",
	{ breakdown = "StoredUses" },
	{ modName = "AdditionalCooldownUses", cfg = "skill" },
}, },
	{ label = "Duration Mod", flag = "duration", { format = "x {4:output:DurationMod}",
		{ breakdown = "DurationMod" },
		{ breakdown = "SecondaryDurationMod" },
		{ breakdown = "TertiaryDurationMod" },
		{ modName = { "Duration", "PrimaryDuration", "SecondaryDuration", "TertiaryDuration", "SkillAndDamagingAilmentDuration" }, cfg = "skill" },
	}, },
	{ label = "Skill Duration", flag = "duration", haveOutput = "Duration", { format = "{3:output:Duration}s", { breakdown = "Duration" }, }, },
	{ label = "Uptime", haveOutput = "DurationUptime", { format = "{2:output:DurationUptime}%", { breakdown = "DurationUptime" }, }, },
	{ label = "Repeat Count", haveOutput = "RepeatCount", { format = "{output:Repeats}", { modName = { "RepeatCount" }, cfg = "skill" }, }, },
	{ label = "Projectile Count", flag = "projectile", { format = "{output:ProjectileCount}", { modName = { "NoAdditionalProjectiles" , "ProjectileCount" }, cfg = "skill" }, }, },
	{ label = "Pierce Count", haveOutput = "PierceCount", { format = "{output:PierceCountString}", { modName = { "CannotPierce", "PierceCount", "PierceAllTargets" }, cfg = "skill" }, }, },
	{ label = "Fork Count", haveOutput = "ForkCountMax", { format = "{output:ForkCountString}", { modName = { "CannotFork", "ForkCountMax" }, cfg = "skill" }, }, },
	{ label = "Max Chain Count", haveOutput = "ChainMax", { format = "{output:ChainMaxString}", { modName = { "CannotChain", "ChainCountMax", "NoAdditionalChains" }, cfg = "skill" }, }, },
	{ label = "Split Count", haveOutput = "SplitCountString", { format = "{output:SplitCountString}",
		{ label = "Player modifiers", modName = { "CannotSplit", "SplitCount", "AdditionalProjectilesAddSplitsInstead", "AdditionalChainsAddSplitsInstead" }, cfg = "skill" },
		{ label = "Enemy modifiers", modName = { "SelfSplitCount" }, enemy = true, cfg = "skill" },
	}, },
	{ label = "Proj. Speed Mod", flag = "projectile", { format = "x {2:output:ProjectileSpeedMod}",
		{ breakdown = "ProjectileSpeedMod" },
		{ modName = "ProjectileSpeed", cfg = "skill" },
	}, },
	{ label = "Self hit Damage", haveOutput = "SelfHitDamage", { format = "{0:output:SelfHitDamage}", { breakdown = "SelfHitDamage" } } },
	{ label = "Bounces Count", flag = "bounce", { format = "{output:BounceCount}", { modName = { "BounceCount", "ProjectileCount" }, cfg = "skill" }, }, },
	{ label = "Aura Effect Mod", haveOutput = "AuraEffectMod", { format = "x {2:output:AuraEffectMod}",
		{ breakdown = "AuraEffectMod" },
		{ modName = { "AuraEffect", "SkillAuraEffectOnSelf" }, cfg = "skill" },
	}, },
	{ label = "Curse Effect Mod", haveOutput = "CurseEffectMod", { format = "x {2:output:CurseEffectMod}",
		{ breakdown = "CurseEffectMod" },
		{ modName = "CurseEffect", cfg = "skill" },
	}, },
	{ label = "Area of Effect Mod", haveOutput = "AreaOfEffectMod", { format = "x {2:output:AreaOfEffectMod}",
		{ breakdown = "AreaOfEffectMod" },
		{ modName = "AreaOfEffect", cfg = "skill" },
	}, },
	{ label = "Radius", haveOutput = "AreaOfEffectRadius", { format = "{1:output:AreaOfEffectRadiusMetres}m", { breakdown = "AreaOfEffectRadius" }, }, },
	{ label = "Weapon Range", haveOutput = "WeaponRange", { format = "{1:output:WeaponRangeMetre}m", { breakdown = "WeaponRange" }, }, },
	{ label = "Trap Cooldown", haveOutput = "TrapCooldown", { format = "{3:output:TrapCooldown}s",
		{ breakdown = "TrapCooldown" },
		{ modName = "CooldownRecovery", cfg = "skill" },
	}, },
	{ label = "Avg. Active Traps", haveOutput = "AverageActiveTraps", { format = "{2:output:AverageActiveTraps}", { breakdown = "AverageActiveTraps" }, }, },
	{ label = "DPS Multiplier", haveOutput = "SkillDPSMultiplier", { format = "{3:output:SkillDPSMultiplier}", { breakdown = "SkillDPSMultiplier" }, }, },
	{ label = "Trap Trigg. Radius", flag = "trap", { format = "{1:output:TrapTriggerRadiusMetre}m",
		{ breakdown = "TrapTriggerRadius" },
		{ label = "Area of Effect modifiers", modName = "TrapTriggerAreaOfEffect", cfg = "skill" },
	}, },
	{ label = "Active Trap Limit", flag = "trap", { format = "{0:output:ActiveTrapLimit}", { modName = "ActiveTrapLimit", cfg = "skill" }, }, },
	{ label = "Trap Throw Rate", flag = "trap", { format = "{2:output:TrapThrowingSpeed}",
		{ breakdown = "TrapThrowingSpeed" },
		{ modName = "TrapThrowingSpeed", cfg = "skill" },
	}, },
	{ label = "Trap Throw Time", flag = "trap", { format = "{2:output:TrapThrowingTime}s", { breakdown = "TrapThrowingTime" }, }, },
	{ label = "Totem Place Time", flag = "totem", notFlag = "triggered", { format = "{2:output:TotemPlacementTime}s",
		{ breakdown = "TotemPlacementTime" },
		{ modName = "TotemPlacementSpeed", cfg = "skill" },
	}, },
	{ label = "Active Totem Limit", flag = "totem", notFlag = "triggered", { format = "{0:output:ActiveTotemLimit}",
		{ breakdown = "ActiveTotemLimit" },
		{ modName = { "ActiveTotemLimit", "ActiveBallistaLimit" }, cfg = "skill" },
	}, },
	{ label = "Totem Duration Mod", flagList = {"duration", "totem"}, { format = "x {4:output:TotemDurationMod}",
		{ breakdown = "TotemDurationMod" },
		{ modName = { "Duration", "PrimaryDuration", "TotemDuration" }, cfg = "skill" },
	}, },
	{ label = "Totem Duration", flagList = {"duration", "totem"}, { format = "x {4:output:TotemDuration}",
		{ breakdown = "TotemDuration" },
	}, },
	{ label = "Totem Life Mod", flag = "totem", notFlag = "triggered", { format = "x {2:output:TotemLifeMod}",
		{ breakdown = "TotemLifeMod" },
		{ modName = "TotemLife", cfg = "skill" },
	}, },
	{ label = "Totem Life", flag = "totem", notFlag = "triggered", { format = "{0:output:TotemLife}", { breakdown = "TotemLife" }, }, },
	{ label = "Totem Block Chance", haveOutput = "TotemBlockChance", { format = "{0:output:TotemBlockChance}%",
		{ breakdown = "TotemBlockChance" },
		{ modName = "TotemBlockChance", cfg = "skill" },
	}, },
	{ label = "Totem Armour", haveOutput = "TotemArmour", { format = "{0:output:TotemArmour}",
		{ breakdown = "TotemArmour" },
		{ modName = "TotemArmour", cfg = "skill" },
	}, },
	{ label = "Burst Damage", haveOutput = "ShowBurst", { format = "{1:output:AverageBurstDamage}", { breakdown = "AverageBurstDamage" }, }, },
} }
} },
{ 1, "LeechGain", 1, colorCodes.OFFENCE, {{ defaultCollapsed = false, label = "Leech & Gain on Hit", data = {
	{ label = "Life Leech Cap", flag = "leechLife", { format = "{1:output:MaxLifeLeechRate}",
		{ breakdown = "MaxLifeLeechRate" },
		{ modName = "MaxLifeLeechRate" },
	}, },
	{ label = "Life Leech Rate", flag = "leechLife", notFlag = "showAverage", { format = "{1:output:LifeLeechRate}",
		{ breakdown = "LifeLeech" },
		{ label = "Player modifiers", notFlagList = { "totem", "attack" }, modName = { "DamageLeech", "DamageLifeLeech", "PhysicalDamageLifeLeech", "LightningDamageLifeLeech", "ColdDamageLifeLeech", "FireDamageLifeLeech", "ChaosDamageLifeLeech", "ElementalDamageLifeLeech" }, modType = "BASE", cfg = "skill" },
		{ label = "Main Hand", notFlag = "totem", flag = "weapon1Attack", modName = { "DamageLeech", "DamageLifeLeech", "PhysicalDamageLifeLeech", "LightningDamageLifeLeech", "ColdDamageLifeLeech", "FireDamageLifeLeech", "ChaosDamageLifeLeech", "ElementalDamageLifeLeech" }, modType = "BASE", cfg = "weapon1" },
		{ label = "Off Hand", notFlag = "totem", flag = "weapon2Attack", modName = { "DamageLeech", "DamageLifeLeech", "PhysicalDamageLifeLeech", "LightningDamageLifeLeech", "ColdDamageLifeLeech", "FireDamageLifeLeech", "ChaosDamageLifeLeech", "ElementalDamageLifeLeech" }, modType = "BASE", cfg = "weapon2" },
		{ label = "Totem modifiers", flag = "totem", modName = { "DamageLifeLeechToPlayer" }, modType = "BASE", cfg = "skill" },
		{ label = "Enemy modifiers", modName = { "SelfDamageLifeLeech" }, modType = "BASE", enemy = true },
	}, },
	{ label = "Life Leech per Hit", flagList = { "leechLife", "showAverage" }, { format = "{1:output:LifeLeechPerHit}",
		{ breakdown = "LifeLeech" },
		{ label = "Player modifiers", notFlagList = { "totem", "attack" }, modName = { "DamageLeech", "DamageLifeLeech", "PhysicalDamageLifeLeech", "LightningDamageLifeLeech", "ColdDamageLifeLeech", "FireDamageLifeLeech", "ChaosDamageLifeLeech", "ElementalDamageLifeLeech" }, modType = "BASE", cfg = "skill" },
		{ label = "Main Hand", notFlag = "totem", flag = "weapon1Attack", modName = { "DamageLeech", "DamageLifeLeech", "PhysicalDamageLifeLeech", "LightningDamageLifeLeech", "ColdDamageLifeLeech", "FireDamageLifeLeech", "ChaosDamageLifeLeech", "ElementalDamageLifeLeech" }, modType = "BASE", cfg = "weapon1" },
		{ label = "Off Hand", notFlag = "totem", flag = "weapon2Attack", modName = { "DamageLeech", "DamageLifeLeech", "PhysicalDamageLifeLeech", "LightningDamageLifeLeech", "ColdDamageLifeLeech", "FireDamageLifeLeech", "ChaosDamageLifeLeech", "ElementalDamageLifeLeech" }, modType = "BASE", cfg = "weapon2" },
		{ label = "Totem modifiers", flag = "totem", modName = { "DamageLifeLeechToPlayer" }, modType = "BASE", cfg = "skill" },
		{ label = "Enemy modifiers", modName = { "SelfDamageLifeLeech" }, modType = "BASE", enemy = true },
	}, },
	{ label = "Life Gain Rate", notFlag = "showAverage", haveOutput = "LifeOnHitRate", { format = "{1:output:LifeOnHitRate}",
		{ label = "Player modifiers", notFlag = "attack", modName = "LifeOnHit", modType = "BASE", cfg = "skill" },
		{ label = "Main Hand", flag = "weapon1Attack", modName = "LifeOnHit", modType = "BASE", cfg = "weapon1" },
		{ label = "Off Hand", flag = "weapon2Attack", modName = "LifeOnHit", modType = "BASE", cfg = "weapon2" },
		{ label = "Enemy modifiers", modName = { "SelfLifeOnHit" }, modType = "BASE", cfg = "skill", enemy = true },
	}, },
	{ label = "Life Gain per Hit", flag = "showAverage", haveOutput = "LifeOnHit", { format = "{1:output:LifeOnHit}",
		{ label = "Player modifiers", notFlag = "attack", modName = "LifeOnHit", modType = "BASE", cfg = "skill" },
		{ label = "Main Hand", flag = "weapon1Attack", modName = "LifeOnHit", modType = "BASE", cfg = "weapon1" },
		{ label = "Off Hand", flag = "weapon2Attack", modName = "LifeOnHit", modType = "BASE", cfg = "weapon2" },
		{ label = "Enemy modifiers", modName = { "SelfLifeOnHit" }, modType = "BASE", cfg = "skill", enemy = true },
	}, },
	{ label = "Life Gain on Kill", haveOutput = "LifeOnKill", { format = "{1:output:LifeOnKill}",
		{modName = "LifeOnKill"},
	}, },
	{ label = "Mana Leech Cap", flag = "leechMana", { format = "{1:output:MaxManaLeechRate}",
		{ breakdown = "MaxManaLeechRate" },
		{ modName = "MaxManaLeechRate" },
	}, },
	{ label = "Mana Leech Rate", flag = "leechMana", notFlag = "showAverage", { format = "{1:output:ManaLeechRate}",
		{ breakdown = "ManaLeech" },
		{ label = "Player modifiers", notFlag = "attack", modName = { "DamageLeech", "DamageManaLeech", "PhysicalDamageManaLeech", "LightningDamageManaLeech", "ColdDamageManaLeech", "FireDamageManaLeech", "ChaosDamageManaLeech", "ElementalDamageManaLeech" }, modType = "BASE", cfg = "skill" },
		{ label = "Main Hand", flag = "weapon1Attack", modName = { "DamageLeech", "DamageManaLeech", "PhysicalDamageManaLeech", "LightningDamageManaLeech", "ColdDamageManaLeech", "FireDamageManaLeech", "ChaosDamageManaLeech", "ElementalDamageManaLeech" }, modType = "BASE", cfg = "weapon1" },
		{ label = "Off Hand", flag = "weapon2Attack", modName = { "DamageLeech", "DamageManaLeech", "PhysicalDamageManaLeech", "LightningDamageManaLeech", "ColdDamageManaLeech", "FireDamageManaLeech", "ChaosDamageManaLeech", "ElementalDamageManaLeech" }, modType = "BASE", cfg = "weapon2" },
		{ label = "Enemy modifiers", modName = { "SelfDamageManaLeech" }, modType = "BASE", cfg = "skill", enemy = true },
	}, },
	{ label = "Mana Leech per Hit", flagList = { "leechMana", "showAverage" }, { format = "{1:output:ManaLeechPerHit}",
		{ breakdown = "ManaLeech" },
		{ label = "Player modifiers", notFlag = "attack", modName = { "DamageLeech", "DamageManaLeech", "PhysicalDamageManaLeech", "LightningDamageManaLeech", "ColdDamageManaLeech", "FireDamageManaLeech", "ChaosDamageManaLeech", "ElementalDamageManaLeech" }, modType = "BASE", cfg = "skill" },
		{ label = "Main Hand", flag = "weapon1Attack", modName = { "DamageLeech", "DamageManaLeech", "PhysicalDamageManaLeech", "LightningDamageManaLeech", "ColdDamageManaLeech", "FireDamageManaLeech", "ChaosDamageManaLeech", "ElementalDamageManaLeech" }, modType = "BASE", cfg = "weapon1" },
		{ label = "Off Hand", flag = "weapon2Attack", modName = { "DamageLeech", "DamageManaLeech", "PhysicalDamageManaLeech", "LightningDamageManaLeech", "ColdDamageManaLeech", "FireDamageManaLeech", "ChaosDamageManaLeech", "ElementalDamageManaLeech" }, modType = "BASE", cfg = "weapon2" },
		{ label = "Enemy modifiers", modName = { "SelfDamageManaLeech" }, modType = "BASE", enemy = true },
	}, },
	{ label = "Mana Gain Rate", notFlag = "showAverage", haveOutput = "ManaOnHitRate", { format = "{1:output:ManaOnHitRate}",
		{ label = "Player modifiers", notFlag = "attack", modName = "ManaOnHit", modType = "BASE", cfg = "skill" },
		{ label = "Main Hand", flag = "weapon1Attack", modName = "ManaOnHit", modType = "BASE", cfg = "weapon1" },
		{ label = "Off Hand", flag = "weapon2Attack", modName = "ManaOnHit", modType = "BASE", cfg = "weapon2" },
		{ label = "Enemy modifiers", modName = { "SelfManaOnHit" }, modType = "BASE", cfg = "skill", enemy = true },
	}, },
	{ label = "Mana Gain per Hit", flag = "showAverage", haveOutput = "ManaOnHit", { format = "{1:output:ManaOnHit}",
		{ label = "Player modifiers", notFlag = "attack", modName = "ManaOnHit", modType = "BASE", cfg = "skill" },
		{ label = "Main Hand", flag = "weapon1Attack", modName = "ManaOnHit", modType = "BASE", cfg = "weapon1" },
		{ label = "Off Hand", flag = "weapon2Attack", modName = "ManaOnHit", modType = "BASE", cfg = "weapon2" },
		{ label = "Enemy modifiers", modName = { "SelfManaOnHit" }, modType = "BASE", cfg = "skill", enemy = true },
	}, },
	{ label = "Mana Gain on Kill", haveOutput = "ManaOnKill", { format = "{1:output:ManaOnKill}",
		{modName = "ManaOnKill"},
	}, },
} }
} },
{ 1, "MiscEffects", 1, colorCodes.OFFENCE, {{ defaultCollapsed = false, label = "Other Effects", data = {
	{ label = "Stun Threshold", flag = "hit", notFlag = "attack", { format = "x {2:output:EnemyStunThresholdMod}", { modName = "EnemyStunThreshold", cfg = "skill" }, }, },
	{ label = "Stun Duration", flag = "hit", notFlag = "attack", { format = "{2:output:EnemyStunDuration}s",
		{ breakdown = "EnemyStunDuration" },
		{ label = "Player modifiers", modName = { "EnemyStunDuration", "EnemyStunDurationOnCrit", "DoubleEnemyStunDurationChance" }, cfg = "skill" },
		{ label = "Enemy modifiers", modName = { "StunRecovery", "SelfDoubleStunDurationChance" }, enemy = true },
	}, },
	{ label = "Knockback Chance", haveOutput = "KnockbackChance", { format = "{0:output:KnockbackChance}%",
		{ label = "Player modifiers", modName = "EnemyKnockbackChance", cfg = "skill" },
		{ label = "Enemy modifiers", modName = "SelfKnockbackChance", enemy = true },
	}, },
	{ label = "Knockback Dist.", haveOutput = "KnockbackChance", { format = "{0:output:KnockbackDistance}",
		{ breakdown = "KnockbackDistance" },
		{ modName = "EnemyKnockbackDistance", cfg = "skill" },
	}, },
} }
} },
-- attributes/resists
{ 1, "Attributes", 2, colorCodes.NORMAL, {{ defaultCollapsed = false, label = "Attributes", data = generateTableByValues({},
		Attributes, function(i, stat)
			return { label = LongAttributes[i], { format = "{0:output:" .. stat .. "}", { breakdown = stat }, { modName = stat }, }, }
		end),
}
} },
-- primary defenses
{ 1, "Life", 2, colorCodes.LIFE, {{ defaultCollapsed = false, label = "Health", data = {
	extra = "{0:output:LifeUnreserved}/{0:output:Life}",
	{ label = "Base from Gear", { format = "{0:mod:1}", { modName = "Life", modType = "BASE", modSource = "Item" }, }, },
	{ label = "Inc. from Tree", { format = "{0:mod:1}%", { modName = "Life", modType = "INC", modSource = "Tree" }, }, },
	{ label = "Total Base", { format = "{0:mod:1}", { modName = "Life", modType = "BASE" }, }, },
	{ label = "Total Increased", { format = "{0:mod:1}%", { modName = "Life", modType = "INC", }, }, },
	{ label = "Total More", { format = "{0:mod:1}%", { modName = "Life", modType = "MORE", }, }, },
	{ label = "Total", { format = "{0:output:Life}", { breakdown = "Life" }, }, },
	{ label = "Total Recoverable", haveOutput = "CappingLife", { format = "{0:output:LifeRecoverable}", { breakdown = "LifeUnreserved" }, }, },
	{ label = "Recovery", { format = "{1:output:LifeRegenRecovery} ({1:output:LifeRegenPercent}%)",
		{ breakdown = "LifeRegenRecovery" },
		{ label = "Sources", modName = { "LifeRegen", "LifeRegenPercent", "LifeDegen", "LifeDegenPercent", "LifeRecovery" }, modType = "BASE" },
		{ label = "Increased Life Regeneration Rate", modName = { "LifeRegen" }, modType = "INC" },
		{ label = "More Life Regeneration Rate", modName = { "LifeRegen" }, modType = "MORE" },
		{ label = "Recovery modifiers", modName = "LifeRecoveryRate" },
	}, },
} }
} },
{ 1, "Mana", 2, colorCodes.MANA, {{ defaultCollapsed = false, label = "Mana", data = {
	extra = "{0:output:ManaUnreserved}/{0:output:Mana}",
	notFlag = "minionSkill",
	{ label = "Base from Gear", { format = "{0:mod:1}", { modName = "Mana", modType = "BASE", modSource = "Item" }, }, },
	{ label = "Inc. from Tree", { format = "{0:mod:1}%", { modName = "Mana", modType = "INC", modSource = "Tree" }, }, },
	{ label = "Total Base", { format = "{0:mod:1}", { modName = "Mana", modType = "BASE" }, }, },
	{ label = "Total Increased", { format = "{0:mod:1}%", { modName = "Mana", modType = "INC" }, }, },
	{ label = "Total", { format = "{0:output:Mana}", { breakdown = "Mana" }, }, },
	{ label = "Recovery", { format = "{1:output:ManaRegenRecovery} ({1:output:ManaRegenPercent}%)",
		{ breakdown = "ManaRegenRecovery" },
		{ label = "Sources", modName = { "ManaRegen", "ManaRegenPercent", "ManaDegen", "ManaDegenPercent", "ManaRecovery" }, modType = "BASE" },
		{ label = "Increased Mana Regeneration Rate", modName = { "ManaRegen" }, modType = "INC" },
		{ label = "More Mana Regeneration Rate", modName = { "ManaRegen" }, modType = "MORE" },
		{ label = "Recovery modifiers", modName = "ManaRecoveryRate" },
	}, },
} }
} },
{ 1, "Ward", 2, colorCodes.WARD, {{ defaultCollapsed = false, label = "Ward", data = {
	extra = "{0:output:Ward}",
	{ label = "Base from Armours", { format = "{0:output:Gear:Ward}", { breakdown = "Ward", gearOnly = true }, }, },
	{ label = "Global Base", { format = "{0:mod:1}", { modName = "Ward", modType = "BASE" }, }, },
	{ label = "Inc. from Tree", { format = "{0:mod:1}%", { modName = "Ward", modType = "INC", modSource = "Tree" }, }, },
	{ label = "Total Increased", { format = "{0:mod:1}%", { modName = { "Ward", "Defences" }, modType = "INC" }, }, },
	{ label = "Total More", { format = "{0:mod:1}%", { modName = { "Ward", "Defences" }, modType = "MORE" }, }, },
	{ label = "Total", { format = "{0:output:Ward}", { breakdown = "Ward" }, }, },
} }
} },
-- secondary defenses
{ 1, "Resist", 3, colorCodes.DEFENCE, {{ defaultCollapsed = false, label = "Resists", data = generateTableByValues({},

		DamageTypes, function (i,damageType)
			return { label = DamageTypesColored[i] .. " Resist", { format = "{0:output:" .. damageType .. "Resist}% (+{0:output:FireResistOverCap}%)",
												   { breakdown = "FireResist" },
												   { modName = { "FireResistMax", "FireResist" }, } } }
		end),
}
} },
{ 1, "Armour", 3, colorCodes.ARMOUR, {{ defaultCollapsed = false, label = "Armor", data = {
	extra = "{0:output:Armour}",
	{ label = "Base from Armours", { format = "{0:output:Gear:Armour}", { breakdown = "Armour", gearOnly = true }, }, },
	{ label = "Global Base", { format = "{0:mod:1}", { modName = { "Armour", "ArmourAndEvasion" }, modType = "BASE" }, }, },
	{ label = "Inc. from Tree", { format = "{0:mod:1}%", { modName = { "Armour", "ArmourAndEvasion" }, modType = "INC", modSource = "Tree", }, }, },
	{ label = "Total Increased", { format = "{0:mod:1}%", { modName = { "Armour", "ArmourAndEvasion", "Defences" }, modType = "INC" }, }, },
	{ label = "Total More", { format = "{0:mod:1}%", { modName = { "Armour", "ArmourAndEvasion", "Defences" }, modType = "MORE" }, }, },
	{ label = "Total", { format = "{0:output:Armour}", { breakdown = "Armour" }, }, },
	{ label = "Armour Defense", haveOutput = "RawArmourDefense", { format = "{0:output:RawArmourDefense}%", { modName = "ArmourDefense" }, }, },
	{ label = "Phys. Dmg. Reduct", { format = "{0:output:PhysicalDamageReduction}%",
		{ breakdown = "PhysicalDamageReduction" },
		{ modName = { "PhysicalDamageReduction", "PhysicalDamageReductionWhenHit", "ArmourDoesNotApplyToPhysicalDamageTaken", "DamageReductionMax" } },
	}, },
} }
} },
{ 1, "DamageAvoidance", 3, colorCodes.DEFENCE, { { defaultCollapsed = false, label = "Block", data = {
	extra = "{0:output:BlockChance}%/{0:output:SpellBlockChance}%",
	{ label = "Block Chance", { format = "{0:output:BlockChance}% (+{0:output:BlockChanceOverCap}%)",
		{ breakdown = "BlockChance" },
		{ modName = "BlockChance" },
	}, },
	{ label = "Taken From Block", haveOutput = "ShowBlockEffect", { format = "{0:output:DamageTakenOnBlock}%",
		{ breakdown = "BlockEffect" },
		{ modName = { "BlockEffect" }, },
	}, },
	{ label = "Life on Block", haveOutput = "LifeOnBlock", { format = "{0:output:LifeOnBlock}", { modName = "LifeOnBlock" }, }, },
	{ label = "Mana on Block", haveOutput = "ManaOnBlock", { format = "{0:output:ManaOnBlock}", { modName = "ManaOnBlock" }, }, },
} }, { defaultCollapsed = false, label = "Dodge", data = {
	{ label = "Dodge Chance", { format = "{0:output:AttackDodgeChance}% (+{0:output:AttackDodgeChanceOverCap}%)",
		{ breakdown = "AttackDodgeChance" },
		{ modName = "AttackDodgeChance" },
	}, },
} },
} },
-- misc defense
{ 1, "MiscDefences", 3, colorCodes.DEFENCE, {{ defaultCollapsed = false, label = "Other Defences", data = {
	{ label = "Movement Speed", { format = "x {2:output:EffectiveMovementSpeedMod}", { breakdown = "EffectiveMovementSpeedMod" }, { modName = { "MovementSpeed", "MovementSpeedEqualHighestLinkedPlayers" } }, }, },
} },
} },
-- damage taken
{ 3, "DamageTaken", 1, colorCodes.DEFENCE, {{ defaultCollapsed = false, label = "Damage Taken", data = {
	colWidth = 95,
	generateTableByValues(
			{ { format = "Total:" }},
			DamageTypesColored, function (_,damageType)
			    return { format = damageType .. ":" }
			end
	),
	generateTableByValues(
			{ label = "Enemy Damage",
			  { format = "{2:output:totalEnemyDamage}",
				{ breakdown = "totalEnemyDamage" },
				{ label = "Enemy modifiers", modName = {"Damage", "CritChance", "CritMultiplier"}, enemy = true },
			  }},
			DamageTypes, function (_,damageType)
			    return { format = "{2:output:" .. damageType .. "EnemyDamage}",
    			  { breakdown = damageType .. "EnemyDamage" },
    			  { label = "Enemy modifiers", modName = {"Damage", damageType .. "Damage", "CritChance", "CritMultiplier"}, enemy = true },
    			}
			end
	),
	generateTableByValues(
			{ label = "Taken As",
			  { format = "{2:output:totalTakenDamage}",
				{ breakdown = "totalTakenDamage" },
			  }},
			DamageTypes, function (_,damageType)
			    return { format = "{2:output:" .. damageType .. "TakenDamage}",
    			  { breakdown = damageType .. "TakenDamage" },
    			}
			end
	),
} }, { defaultCollapsed = false, label = "Damaging Hits", data = {
	colWidth = 95,
	generateTableByValues(
			{ label = "Hit taken Mult.",
			  { format = "" }},
			DamageTypes, function (_,damageType)
    			return {
    				format = "x {3:output:" .. damageType .. "TakenHitMult}",
    				{ breakdown = damageType .. "TakenHitMult" },
    				{ modName = { "DamageTaken", "DamageTakenWhenHit", "AttackDamageTaken", "SpellDamageTaken", damageType .. "DamageTaken", damageType .. "DamageTakenWhenHit" } }
    			}
			end
	),
	generateTableByValues(
			{ label = "Hit taken",
			  { format = "{2:output:totalTakenHit}",
				{ breakdown = "totalTakenHit" },
			  }},
			DamageTypes, function (_,damageType)
    			return {
    				format = "{2:output:" .. damageType .. "TakenHit}",
    				{ breakdown = damageType .. "TakenHit" },
    			}
			end
	),
	{ label = "Hits before death",{ format = "{2:output:NumberOfDamagingHits}", },
	}
}, }, { defaultCollapsed = false, label = "Effective \"Health\" Pool", data = {
	extra = "{0:output:TotalEHP}",
	{ label = "Unmitigated %", { format = "{0:output:ConfiguredDamageChance}%",
		{ breakdown = "ConfiguredDamageChance" },
		{ label = "Enemy modifiers", modName = { "CannotBeSuppressed", "CannotBeBlocked", "reduceEnemyBlock" }, enemy = true },
	}, },
	{ label = "Mitigated hits", { format = "{2:output:NumberOfMitigatedDamagingHits}", }, },
	{ label = "Enemy miss chance", { format = "{0:output:ConfiguredNotHitChance}%",
		{ breakdown = "ConfiguredNotHitChance" },
		{ label = "Enemy modifiers", modName = { "CannotBeEvaded", "CannotBeDodged", "reduceEnemyDodge" }, enemy = true },
	}, },
	{ label = "Hits before death", { format = "{2:output:TotalNumberOfHits}", { breakdown = "TotalNumberOfHits" }}, },
	{ label = "Effective Hit Pool",{ format = "{0:output:TotalEHP}", { breakdown = "TotalEHP" }, },},
	{ label = "Time before death",{ format = "{2:output:EHPsurvivalTime}s",
		{ breakdown = "EHPsurvivalTime" },
		{ label = "Enemy modifiers", modName = { "TemporalChainsActionSpeed", "ActionSpeed", "Speed", "MinimumActionSpeed" }, enemy = true },
	},}
}, }, { defaultCollapsed = false, label = "Maximum Hit Taken", data = {
	colWidth = 108,
	generateTableByValues({},
	    DamageTypesColored, function (_,damageType)
			return { format = damageType .. ":" }
		end
	),
	generateTableByValues({ label = "Maximum Hit Taken"},
        DamageTypes, function (_,damageType)
            return { format = "{0:output:" .. damageType .. "MaximumHitTaken}",
    			{ breakdown = damageType .. "MaximumHitTaken" },
    		}
		end
	)
} }, { defaultCollapsed = false, label = "Dots and Degens", data = {
	colWidth = 108,
	generateTableByValues({},
    	DamageTypesColored, function (_,damageType)
			return { format = damageType .. ":" }
		end
	),
	generateTableByValues({ label = "DoT taken"},
    	DamageTypes, function (_,damageType)
    		return { format = "x {2:output:" .. damageType .. "TakenDotMult}",
    			{ breakdown = damageType .. "TakenDotMult" },
    			{ modName = { "DamageTaken", "DamageTakenOverTime", damageType .. "DamageTaken", damageType .. "DamageTakenOverTime" } },
    		}
		end
	),
	generateTableByValues({ label = "Total Pool"},
    	DamageTypes, function (_,damageType)
		return { format = "{0:output:" .. damageType .. "TotalPool}",
			{ breakdown = damageType .. "TotalPool" },
		}
		end
	),
	generateTableByValues({ label = "Effective DoT Pool"},
    	DamageTypes, function (_,damageType)
    		return { format = "{0:output:" .. damageType .. "DotEHP}",
    			{ breakdown = damageType .. "DotEHP" },
    		}
		end
	),
	generateTableByValues({ label = "Degens", haveOutput = "TotalDegen"},
    	DamageTypes, function (_,damageType)
    		return { format = "{0:output:" .. damageType .. "Degen}",
    			{ breakdown = damageType .. "Degen" },
    			{ modName = damageType .. "Degen", }
    		}
		end
	),
	{ label = "Total Net Recovery", haveOutput = "TotalNetRegen", { format = "{1:output:TotalNetRegen}",
		{ breakdown = "TotalNetRegen" },
	}, },
	{ label = "Net Life Recovery", color = colorCodes.LIFE, haveOutput = "NetLifeRegen", { format = "{1:output:NetLifeRegen}", { breakdown = "NetLifeRegen" }, }, },
	{ label = "Net Mana Recovery", color = colorCodes.MANA, haveOutput = "NetManaRegen", { format = "{1:output:NetManaRegen}", { breakdown = "NetManaRegen" }, }, },
} },
} },
}
