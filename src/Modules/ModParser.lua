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
	["^+?([%d%.]+)%% increased"] = "INC",
	["^(%d+)%% faster"] = "INC",
	["^(%d+)%% reduced"] = "RED",
	["^(%d+)%% slower"] = "RED",
	["^(%d+)%% more"] = "MORE",
	["^(%d+)%% less"] = "LESS",
	["^([%+%-][%d%.]+)%%?"] = "BASE",
	["^([%+%-][%d%.]+)%%? to"] = "BASE",
	["^([%+%-]?[%d%.]+)%%? of"] = "BASE",
	["^([%+%-][%d%.]+)%%? base"] = "BASE",
	["^([%+%-]?[%d%.]+)%%? additional"] = "BASE",
	["(%d+) additional hits?"] = "BASE",
	["^you gain ([%d%.]+)"] = "GAIN",
	["^gains? ([%d%.]+)%% of"] = "GAIN",
	["^gain ([%d%.]+)"] = "GAIN",
	["^gain %+(%d+)%% to"] = "GAIN",
	["^you lose ([%d%.]+)"] = "LOSE",
	["^loses? ([%d%.]+)%% of"] = "LOSE",
	["^lose ([%d%.]+)"] = "LOSE",
	["^lose %+(%d+)%% to"] = "LOSE",
	["^grants ([%d%.]+)"] = "GRANTS",    -- local
	["^removes? ([%d%.]+) ?o?f? ?y?o?u?r?"] = "REMOVES", -- local
	["^(%d+)"] = "BASE",
	["^([%+%-]?%d+)%% chance"] = "CHANCE",
	["^([%+%-]?%d+)%% chance to gain "] = "FLAG",
	["^([%+%-]?%d+)%% additional chance"] = "CHANCE",
	["costs? ([%+%-]?%d+)"] = "TOTALCOST",
	["skills cost ([%+%-]?%d+)"] = "BASECOST",
	["^([%d%.]+) (.+) regenerated per second"] = "REGENFLAT",
	["^([%d%.]+)%% (.+) regenerated per second"] = "REGENPERCENT",
	["^([%d%.]+)%% of (.+) regenerated per second"] = "REGENPERCENT",
	["^regenerate ([%d%.]+) (.-) per second"] = "REGENFLAT",
	["^regenerate ([%d%.]+)%% (.-) per second"] = "REGENPERCENT",
	["^regenerate ([%d%.]+)%% of (.-) per second"] = "REGENPERCENT",
	["^regenerate ([%d%.]+)%% of your (.-) per second"] = "REGENPERCENT",
	["^you regenerate ([%d%.]+)%% of (.-) per second"] = "REGENPERCENT",
	["^([%d%.]+) (.+) lost per second"] = "DEGENFLAT",
	["^([%d%.]+)%% (.+) lost per second"] = "DEGENPERCENT",
	["^([%d%.]+)%% of (.+) lost per second"] = "DEGENPERCENT",
	["^lose ([%d%.]+) (.-) per second"] = "DEGENFLAT",
	["^lose ([%d%.]+)%% (.-) per second"] = "DEGENPERCENT",
	["^lose ([%d%.]+)%% of (.-) per second"] = "DEGENPERCENT",
	["^lose ([%d%.]+)%% of your (.-) per second"] = "DEGENPERCENT",
	["^you lose ([%d%.]+)%% of (.-) per second"] = "DEGENPERCENT",
	["^([%d%.]+) (%a+) damage taken per second"] = "DEGEN",
	["^([%d%.]+) (%a+) damage per second"] = "DEGEN",
	["^%+([%d%.]+) damage"] = "DMG",
	["^%+([%d%.]+) (%a+) damage"] = "DMG",
	["^%+([%d%.]+) (%a+) (%a+) damage"] = "DMG",
	["^([%d%.]+)%% increased damage"] = "INCDMG",
	["^([%d%.]+)%% increased (%a+) damage"] = "INCDMG",
	["^([%d%.]+)%% increased (%a+) (%a+) damage"] = "INCDMG",
	["^you have "] = "FLAG",
	["^have "] = "FLAG",
	["^you are "] = "FLAG",
	["^are "] = "FLAG",
	["^gain "] = "FLAG",
	["^you gain "] = "FLAG",
	["is (%-?%d+)%%? "] = "OVERRIDE",
}

-- Map of modifier names
local modNameList = {
	-- Attributes
	["strength"] = "Str",
	["dexterity"] = "Dex",
	["intelligence"] = "Int",
	["vitality"] = "Vit",
	["attunement"] = "Att",
	["omniscience"] = "Omni",
	["strength and dexterity"] = { "Str", "Dex", "StrDex" },
	["strength and intelligence"] = { "Str", "Int", "StrInt" },
	["dexterity and intelligence"] = { "Dex", "Int", "DexInt" },
	["attributes"] = { "Str", "Dex", "Int", "All" },
	["all attributes"] = { "Str", "Dex", "Int", "Vit", "Att", "All" },
	["devotion"] = "Devotion",
	-- Life/mana
	["life"] = "Life",
	["health"] = "Life",
	["health regen"] = "LifeRegen",
	["health regeneration"] = "LifeRegen",
	["maximum life"] = "Life",
	["life regeneration rate"] = "LifeRegen",
	["mana"] = "Mana",
	["maximum mana"] = "Mana",
	["mana regeneration"] = "ManaRegen",
	["mana regeneration rate"] = "ManaRegen",
	["mana cost"] = "ManaCost",
	["mana cost of"] = "ManaCost",
	["mana cost of skills"] = "ManaCost",
	["mana cost of attacks"] = { "ManaCost", tag = { type = "SkillType", skillType = SkillType.Attack } },
	["total cost"] = "Cost",
	["total mana cost"] = "ManaCost",
	["total mana cost of skills"] = "ManaCost",
	["life cost of skills"] = "LifeCost",
	["rage cost of skills"] = "RageCost",
	["cost of"] = "Cost",
	["cost of skills"] = "Cost",
	["mana reserved"] = "ManaReserved",
	["mana reservation"] = "ManaReserved",
	["mana reservation of skills"] = { "ManaReserved", tag = { type = "SkillType", skillType = SkillType.Aura } },
	["mana reservation efficiency of skills"] = "ManaReservationEfficiency",
	["life reservation efficiency of skills"] = "LifeReservationEfficiency",
	["reservation of skills"] = "Reserved",
	["mana reservation if cast as an aura"] = { "ManaReserved", tag = { type = "SkillType", skillType = SkillType.Aura } },
	["reservation if cast as an aura"] = { "Reserved", tag = { type = "SkillType", skillType = SkillType.Aura } },
	["reservation"] = { "Reserved" },
	["reservation efficiency"] = "ReservationEfficiency",
	["reservation efficiency of skills"] = "ReservationEfficiency",
	["mana reservation efficiency"] = "ManaReservationEfficiency",
	["life reservation efficiency"] = "LifeReservationEfficiency",
	-- Primary defences
	["maximum energy shield"] = "EnergyShield",
	["energy shield recharge rate"] = "EnergyShieldRecharge",
	["start of energy shield recharge"] = "EnergyShieldRechargeFaster",
	["restoration of ward"] = "WardRechargeFaster",
	["armour"] = "Armour",
	["armor"] = "Armour",
	["evasion"] = "Evasion",
	["evasion rating"] = "Evasion",
	["energy shield"] = "EnergyShield",
	["ward"] = "Ward",
	["armour and evasion"] = "ArmourAndEvasion",
	["armour and evasion rating"] = "ArmourAndEvasion",
	["evasion rating and armour"] = "ArmourAndEvasion",
	["armour and energy shield"] = "ArmourAndEnergyShield",
	["evasion rating and energy shield"] = "EvasionAndEnergyShield",
	["evasion and energy shield"] = "EvasionAndEnergyShield",
	["armour, evasion and energy shield"] = "Defences",
	["defences"] = "Defences",
	["to evade"] = "EvadeChance",
	["chance to evade"] = "EvadeChance",
	["to evade attacks"] = "EvadeChance",
	["to evade attack hits"] = "EvadeChance",
	["chance to evade attacks"] = "EvadeChance",
	["chance to evade attack hits"] = "EvadeChance",
	["chance to evade projectile attacks"] = "ProjectileEvadeChance",
	["chance to evade melee attacks"] = "MeleeEvadeChance",
	["evasion rating against melee attacks"] = "MeleeEvasion",
	["evasion rating against projectile attacks"] = "ProjectileEvasion",
	-- Resistances
	["physical damage reduction"] = "PhysicalDamageReduction",
	["physical damage reduction from hits"] = "PhysicalDamageReductionWhenHit",
	["fire resistance"] = "FireResist",
	["maximum fire resistance"] = "FireResistMax",
	["cold resistance"] = "ColdResist",
	["maximum cold resistance"] = "ColdResistMax",
	["lightning resistance"] = "LightningResist",
	["maximum lightning resistance"] = "LightningResistMax",
	["chaos resistance"] = "ChaosResist",
	["maximum chaos resistance"] = "ChaosResistMax",
	["fire and cold resistances"] = { "FireResist", "ColdResist" },
	["fire and lightning resistances"] = { "FireResist", "LightningResist" },
	["cold and lightning resistances"] = { "ColdResist", "LightningResist" },
	["elemental resistance"] = "ElementalResist",
	["elemental resistances"] = "ElementalResist",
	["all elemental resistances"] = "ElementalResist",
	["all resistances"] = { "ElementalResist", "ChaosResist" },
	["all maximum elemental resistances"] = "ElementalResistMax",
	["all maximum resistances"] = { "ElementalResistMax", "ChaosResistMax" },
	["all elemental resistances and maximum elemental resistances"] = { "ElementalResist", "ElementalResistMax" },
	["fire and chaos resistances"] = { "FireResist", "ChaosResist" },
	["cold and chaos resistances"] = { "ColdResist", "ChaosResist" },
	["lightning and chaos resistances"] = { "LightningResist", "ChaosResist" },
	-- Damage taken
	["damage taken"] = "DamageTaken",
	["damage taken when hit"] = "DamageTakenWhenHit",
	["damage taken from hits"] = "DamageTakenWhenHit",
	["damage over time taken"] = "DamageTakenOverTime",
	["damage taken from damage over time"] = "DamageTakenOverTime",
	["attack damage taken"] = "AttackDamageTaken",
	["spell damage taken"] = "SpellDamageTaken",
	["physical damage taken"] = "PhysicalDamageTaken",
	["physical damage from hits taken"] = "PhysicalDamageFromHitsTaken",
	["physical damage taken when hit"] = "PhysicalDamageTakenWhenHit",
	["physical damage taken from hits"] = "PhysicalDamageTakenWhenHit",
	["physical damage taken from attacks"] = "PhysicalDamageTakenFromAttacks",
	["physical damage taken from attack hits"] = "PhysicalDamageTakenFromAttacks",
	["physical damage taken over time"] = "PhysicalDamageTakenOverTime",
	["physical damage over time taken"] = "PhysicalDamageTakenOverTime",
	["physical damage over time damage taken"] = "PhysicalDamageTakenOverTime",
	["reflected physical damage taken"] = "PhysicalReflectedDamageTaken",
	["lightning damage taken"] = "LightningDamageTaken",
	["lightning damage from hits taken"] = "LightningDamageFromHitsTaken",
	["lightning damage taken when hit"] = "LightningDamageTakenWhenHit",
	["lightning damage taken from attacks"] = "LightningDamageTakenFromAttacks",
	["lightning damage taken from attack hits"] = "LightningDamageTakenFromAttacks",
	["lightning damage taken over time"] = "LightningDamageTakenOverTime",
	["cold damage taken"] = "ColdDamageTaken",
	["cold damage from hits taken"] = "ColdDamageFromHitsTaken",
	["cold damage taken when hit"] = "ColdDamageTakenWhenHit",
	["cold damage taken from hits"] = "ColdDamageTakenWhenHit",
	["cold damage taken from attacks"] = "ColdDamageTakenFromAttacks",
	["cold damage taken from attack hits"] = "ColdDamageTakenFromAttacks",
	["cold damage taken over time"] = "ColdDamageTakenOverTime",
	["fire damage taken"] = "FireDamageTaken",
	["fire damage from hits taken"] = "FireDamageFromHitsTaken",
	["fire damage taken when hit"] = "FireDamageTakenWhenHit",
	["fire damage taken from hits"] = "FireDamageTakenWhenHit",
	["fire damage taken from attacks"] = "FireDamageTakenFromAttacks",
	["fire damage taken from attack hits"] = "FireDamageTakenFromAttacks",
	["fire damage taken over time"] = "FireDamageTakenOverTime",
	["chaos damage taken"] = "ChaosDamageTaken",
	["chaos damage from hits taken"] = "ChaosDamageFromHitsTaken",
	["chaos damage taken when hit"] = "ChaosDamageTakenWhenHit",
	["chaos damage taken from hits"] = "ChaosDamageTakenWhenHit",
	["chaos damage taken from attacks"] = "ChaosDamageTakenFromAttacks",
	["chaos damage taken from attack hits"] = "ChaosDamageTakenFromAttacks",
	["chaos damage taken over time"] = "ChaosDamageTakenOverTime",
	["chaos damage over time taken"] = "ChaosDamageTakenOverTime",
	["elemental damage taken"] = "ElementalDamageTaken",
	["elemental damage from hits taken"] = "ElementalDamageFromHitsTaken",
	["elemental damage taken when hit"] = "ElementalDamageTakenWhenHit",
	["elemental damage taken from hits"] = "ElementalDamageTakenWhenHit",
	["elemental damage taken over time"] = "ElementalDamageTakenOverTime",
	["cold and lightning damage taken"] = { "ColdDamageTaken", "LightningDamageTaken" },
	["fire and lightning damage taken"] = { "FireDamageTaken", "LightningDamageTaken" },
	["fire and cold damage taken"] = { "FireDamageTaken", "ColdDamageTaken" },
	["physical and chaos damage taken"] = { "PhysicalDamageTaken", "ChaosDamageTaken" },
	["reflected elemental damage taken"] = "ElementalReflectedDamageTaken",
	-- Other defences
	["to dodge attacks"] = "AttackDodgeChance",
	["to dodge attack hits"] = "AttackDodgeChance",
	["to dodge spells"] = "SpellDodgeChance",
	["to dodge spell hits"] = "SpellDodgeChance",
	["to dodge spell damage"] = "SpellDodgeChance",
	["to dodge attacks and spells"] = { "AttackDodgeChance", "SpellDodgeChance" },
	["to dodge attacks and spell damage"] = { "AttackDodgeChance", "SpellDodgeChance" },
	["to dodge attack and spell hits"] = { "AttackDodgeChance", "SpellDodgeChance" },
	["to dodge attack or spell hits"] = { "AttackDodgeChance", "SpellDodgeChance" },
	["to suppress spell damage"] = { "SpellSuppressionChance" },
	["amount of suppressed spell damage prevented"] = { "SpellSuppressionEffect" },
	["to amount of suppressed spell damage prevented"] = { "SpellSuppressionEffect" },
	["to block"] = "BlockChance",
	["to block attacks"] = "BlockChance",
	["to block attack damage"] = "BlockChance",
	["block chance"] = "BlockChance",
	["block chance with staves"] = { "BlockChance", tag = { type = "Condition", var = "UsingStaff" } },
	["to block with staves"] = { "BlockChance", tag = { type = "Condition", var = "UsingStaff" } },
	["block chance against projectiles"] = "ProjectileBlockChance",
	["to block projectile attack damage"] = "ProjectileBlockChance",
	["to block projectile spell damage"] = "ProjectileSpellBlockChance",
	["spell block chance"] = "SpellBlockChance",
	["to block spells"] = "SpellBlockChance",
	["to block spell damage"] = "SpellBlockChance",
	["chance to block attacks and spells"] = { "BlockChance", "SpellBlockChance" },
	["chance to block attack and spell damage"] = { "BlockChance", "SpellBlockChance" },
	["to block attack and spell damage"] = { "BlockChance", "SpellBlockChance" },
	["maximum block chance"] = "BlockChanceMax",
	["maximum chance to block attack damage"] = "BlockChanceMax",
	["maximum chance to block spell damage"] = "SpellBlockChanceMax",
	["life gained when you block"] = "LifeOnBlock",
	["mana gained when you block"] = "ManaOnBlock",
	["energy shield when you block"] = "EnergyShieldOnBlock",
	["maximum chance to dodge spell hits"] = "SpellDodgeChanceMax",
	["to avoid physical damage from hits"] = "AvoidPhysicalDamageChance",
	["to avoid fire damage when hit"] = "AvoidFireDamageChance",
	["to avoid fire damage from hits"] = "AvoidFireDamageChance",
	["to avoid cold damage when hit"] = "AvoidColdDamageChance",
	["to avoid cold damage from hits"] = "AvoidColdDamageChance",
	["to avoid lightning damage when hit"] = "AvoidLightningDamageChance",
	["to avoid lightning damage from hits"] = "AvoidLightningDamageChance",
	["to avoid elemental damage when hit"] = { "AvoidFireDamageChance", "AvoidColdDamageChance", "AvoidLightningDamageChance" },
	["to avoid elemental damage from hits"] = { "AvoidFireDamageChance", "AvoidColdDamageChance", "AvoidLightningDamageChance" },
	["to avoid projectiles"] = "AvoidProjectilesChance",
	["to avoid being stunned"] = "AvoidStun",
	["to avoid interruption from stuns while casting"] = "AvoidInterruptStun",
	["to ignore stuns while casting"] = "AvoidInterruptStun",
	["to avoid being shocked"] = "AvoidShock",
	["to avoid being frozen"] = "AvoidFreeze",
	["to avoid being chilled"] = "AvoidChill",
	["to avoid being ignited"] = "AvoidIgnite",
	["to avoid non-damaging ailments on you"] = { "AvoidShock", "AvoidFreeze", "AvoidChill", "AvoidSap", "AvoidBrittle", "AvoidScorch" },
	["to avoid blind"] = "AvoidBlind",
	["to avoid elemental ailments"] = "AvoidElementalAilments",
	["to avoid elemental status ailments"] = "AvoidElementalAilments",
	["to avoid ailments"] = "AvoidAilments" ,
	["to avoid status ailments"] = "AvoidAilments",
	["to avoid bleeding"] = "AvoidBleed",
	["to avoid being poisoned"] = "AvoidPoison",
	["damage is taken from mana before life"] = "DamageTakenFromManaBeforeLife",
	["lightning damage is taken from mana before life"] = "LightningDamageTakenFromManaBeforeLife",
	["damage taken from mana before life"] = "DamageTakenFromManaBeforeLife",
	["effect of curses on you"] = "CurseEffectOnSelf",
	["effect of curses on them"] = "CurseEffectOnSelf",
	["effect of exposure on you"] = "ExposureEffectOnSelf",
	["effect of withered on you"] = "WitherEffectOnSelf",
	["life recovery rate"] = "LifeRecoveryRate",
	["mana recovery rate"] = "ManaRecoveryRate",
	["energy shield recovery rate"] = "EnergyShieldRecoveryRate",
	["energy shield regeneration rate"] = "EnergyShieldRegen",
	["recovery rate of life, mana and energy shield"] = { "LifeRecoveryRate", "ManaRecoveryRate", "EnergyShieldRecoveryRate" },
	["recovery rate of life and energy shield"] = { "LifeRecoveryRate", "EnergyShieldRecoveryRate" },
	["maximum life, mana and global energy shield"] = { "Life", "Mana", "EnergyShield", tag = { type = "Global" } },
	["non-chaos damage taken bypasses energy shield"] = { "PhysicalEnergyShieldBypass", "LightningEnergyShieldBypass", "ColdEnergyShieldBypass", "FireEnergyShieldBypass" },
	["damage taken recouped as life"] = "LifeRecoup",
	["physical damage taken recouped as life"] = "PhysicalLifeRecoup",
	["lightning damage taken recouped as life"] = "LightningLifeRecoup",
	["cold damage taken recouped as life"] = "ColdLifeRecoup",
	["fire damage taken recouped as life"] = "FireLifeRecoup",
	["chaos damage taken recouped as life"] = "ChaosLifeRecoup",
	["damage taken recouped as energy shield"] = "EnergyShieldRecoup",
	["damage taken recouped as mana"] = "ManaRecoup",
	["damage taken recouped as life, mana and energy shield"] = { "LifeRecoup", "EnergyShieldRecoup", "ManaRecoup" },
	-- Stun/knockback modifiers
	["stun recovery"] = "StunRecovery",
	["stun and block recovery"] = "StunRecovery",
	["block and stun recovery"] = "StunRecovery",
	["stun duration on you"] = "StunDuration",
	["stun threshold"] = "StunThreshold",
	["block recovery"] = "BlockRecovery",
	["enemy stun threshold"] = "EnemyStunThreshold",
	["stun duration on enemies"] = "EnemyStunDuration",
	["stun duration"] = "EnemyStunDuration",
	["to double stun duration"] = "DoubleEnemyStunDurationChance",
	["to knock enemies back on hit"] = "EnemyKnockbackChance",
	["knockback distance"] = "EnemyKnockbackDistance",
	-- Auras/curses/buffs
	["aura effect"] = "AuraEffect",
	["effect of non-curse auras you cast"] = { "AuraEffect", tagList = { { type = "SkillType", skillType = SkillType.Aura }, { type = "SkillType", skillType = SkillType.AppliesCurse, neg = true } } },
	["effect of non-curse auras from your skills"] = { "AuraEffect", tagList = { { type = "SkillType", skillType = SkillType.Aura }, { type = "SkillType", skillType = SkillType.AppliesCurse, neg = true } } },
	["effect of non-curse auras from your skills on your minions"] = { "AuraEffectOnSelf", tagList = { { type = "SkillType", skillType = SkillType.Aura }, { type = "SkillType", skillType = SkillType.AppliesCurse, neg = true } }, addToMinion = true },
	["effect of non-curse auras"] = { "AuraEffect", tag = { type = "SkillType", skillType = SkillType.AppliesCurse, neg = true } },
	["effect of your curses"] = "CurseEffect",
	["effect of auras on you"] = "AuraEffectOnSelf",
	["effect of auras on your minions"] = { "AuraEffectOnSelf", addToMinion = true },
	["effect of auras from mines"] = { "AuraEffect", keywordFlags = KeywordFlag.Mine },
	["effect of consecrated ground you create"] = "ConsecratedGroundEffect",
	["curse effect"] = "CurseEffect",
	["effect of curses applied by bane"] = { "CurseEffect", tag = { type = "Condition", var = "AppliedByBane" } },
	["effect of your marks"] = { "CurseEffect", tag = { type = "SkillType", skillType = SkillType.Mark } },
	["effect of arcane surge on you"] = "ArcaneSurgeEffect",
	["curse duration"] = { "Duration", keywordFlags = KeywordFlag.Curse },
	["hex duration"] = { "Duration", tag = { type = "SkillType", skillType = SkillType.Hex } },
	["radius of auras"] = { "AreaOfEffect", keywordFlags = KeywordFlag.Aura },
	["radius of curses"] = { "AreaOfEffect", keywordFlags = KeywordFlag.Curse },
	["buff effect"] = "BuffEffect",
	["effect of buffs on you"] = "BuffEffectOnSelf",
	["effect of buffs granted by your golems"] = { "BuffEffect", tag = { type = "SkillType", skillType = SkillType.Golem } },
	["effect of buffs granted by socketed golem skills"] = { "BuffEffect", addToSkill = { type = "SocketedIn", slotName = "{SlotName}", keyword = "golem" } },
	["effect of the buff granted by your stone golems"] = { "BuffEffect", tag = { type = "SkillName", skillName = "Summon Stone Golem", includeTransfigured = true } },
	["effect of the buff granted by your lightning golems"] = { "BuffEffect", tag = { type = "SkillName", skillName = "Summon Lightning Golem", includeTransfigured = true } },
	["effect of the buff granted by your ice golems"] = { "BuffEffect", tag = { type = "SkillName", skillName = "Summon Ice Golem", includeTransfigured = true } },
	["effect of the buff granted by your flame golems"] = { "BuffEffect", tag = { type = "SkillName", skillName = "Summon Flame Golem", includeTransfigured = true } },
	["effect of the buff granted by your chaos golems"] = { "BuffEffect", tag = { type = "SkillName", skillName = "Summon Chaos Golem", includeTransfigured = true } },
	["effect of the buff granted by your carrion golems"] = { "BuffEffect", tag = { type = "SkillName", skillName = "Summon Carrion Golem", includeTransfigured = true } },
	["effect of offering spells"] = { "BuffEffect", tag = { type = "SkillName", skillNameList = { "Bone Offering", "Flesh Offering", "Spirit Offering", "Blood Offering" } } },
	["effect of offerings"] = { "BuffEffect", tag = { type = "SkillName", skillNameList = { "Bone Offering", "Flesh Offering", "Spirit Offering", "Blood Offering" } } },
	["effect of heralds on you"] = { "BuffEffect", tag = { type = "SkillType", skillType = SkillType.Herald } },
	["effect of herald buffs on you"] = { "BuffEffect", tag = { type = "SkillType", skillType = SkillType.Herald } },
	["effect of buffs granted by your active ancestor totems"] = { "BuffEffect", tag = { type = "SkillName", skillNameList = { "Ancestral Warchief", "Ancestral Protector", "Earthbreaker" } } },
	["effect of buffs your ancestor totems grant "] = { "BuffEffect", tag = { type = "SkillName", skillNameList = { "Ancestral Warchief", "Ancestral Protector", "Earthbreaker" } } },
	["effect of shrine buffs on you"] = "ShrineBuffEffect",
	["effect of withered"] = "WitherEffect",
	["warcry effect"] = { "BuffEffect", keywordFlags = KeywordFlag.Warcry },
	["aspect of the avian buff effect"] = { "BuffEffect", tag = { type = "SkillName", skillName = "Aspect of the Avian" } },
	["maximum rage"] = "MaximumRage",
	["maximum fortification"] = "MaximumFortification",
	["fortification"] = "MinimumFortification",
	-- Charges
	["maximum power charge"] = "PowerChargesMax",
	["maximum power charges"] = "PowerChargesMax",
	["minimum power charge"] = "PowerChargesMin",
	["minimum power charges"] = "PowerChargesMin",
	["power charge duration"] = "PowerChargesDuration",
	["maximum frenzy charge"] = "FrenzyChargesMax",
	["maximum frenzy charges"] = "FrenzyChargesMax",
	["minimum frenzy charge"] = "FrenzyChargesMin",
	["minimum frenzy charges"] = "FrenzyChargesMin",
	["frenzy charge duration"] = "FrenzyChargesDuration",
	["maximum endurance charge"] = "EnduranceChargesMax",
	["maximum endurance charges"] = "EnduranceChargesMax",
	["minimum endurance charge"] = "EnduranceChargesMin",
	["minimum endurance charges"] = "EnduranceChargesMin",
	["minimum endurance, frenzy and power charges"] = { "PowerChargesMin", "FrenzyChargesMin", "EnduranceChargesMin" },
	["endurance charge duration"] = "EnduranceChargesDuration",
	["maximum frenzy charges and maximum power charges"] = { "FrenzyChargesMax", "PowerChargesMax" },
	["maximum power charges and maximum endurance charges"] = { "PowerChargesMax", "EnduranceChargesMax" },
	["maximum endurance, frenzy and power charges"] = { "EnduranceChargesMax", "PowerChargesMax", "FrenzyChargesMax" },
	["endurance, frenzy and power charge duration"] = { "PowerChargesDuration", "FrenzyChargesDuration", "EnduranceChargesDuration" },
	["maximum siphoning charge"] = "SiphoningChargesMax",
	["maximum siphoning charges"] = "SiphoningChargesMax",
	["maximum challenger charges"] = "ChallengerChargesMax",
	["maximum blitz charges"] = "BlitzChargesMax",
	["maximum number of crab barriers"] = "CrabBarriersMax",
	["maximum blood charges"] = "BloodChargesMax",
	["maximum spirit charges"] = "SpiritChargesMax",
	["charge duration"] = "ChargeDuration",
	-- On hit/kill/leech effects
	["life gained on kill"] = "LifeOnKill",
	["life per enemy killed"] = "LifeOnKill",
	["life on kill"] = "LifeOnKill",
	["life per enemy hit"] = { "LifeOnHit", flags = ModFlag.Hit },
	["life gained for each enemy hit"] = { "LifeOnHit", flags = ModFlag.Hit },
	["life for each enemy hit"] = { "LifeOnHit", flags = ModFlag.Hit },
	["mana gained on kill"] = "ManaOnKill",
	["mana per enemy killed"] = "ManaOnKill",
	["mana on kill"] = "ManaOnKill",
	["mana per enemy hit"] = { "ManaOnHit", flags = ModFlag.Hit },
	["mana gained for each enemy hit"] = { "ManaOnHit", flags = ModFlag.Hit },
	["mana for each enemy hit"] = { "ManaOnHit", flags = ModFlag.Hit },
	["energy shield gained on kill"] = "EnergyShieldOnKill",
	["energy shield per enemy killed"] = "EnergyShieldOnKill",
	["energy shield on kill"] = "EnergyShieldOnKill",
	["energy shield per enemy hit"] = { "EnergyShieldOnHit", flags = ModFlag.Hit },
	["energy shield gained for each enemy hit"] = { "EnergyShieldOnHit", flags = ModFlag.Hit },
	["energy shield for each enemy hit"] = { "EnergyShieldOnHit", flags = ModFlag.Hit },
	["life and mana gained for each enemy hit"] = { "LifeOnHit", "ManaOnHit", flags = ModFlag.Hit },
	["life and mana for each enemy hit"] = { "LifeOnHit", "ManaOnHit", flags = ModFlag.Hit },
	["damage as life"] = "DamageLifeLeech",
	["life leeched per second"] = "LifeLeechRate",
	["mana leeched per second"] = "ManaLeechRate",
	["total recovery per second from life leech"] = "LifeLeechRate",
	["recovery per second from life leech"] = "LifeLeechRate",
	["total recovery per second from energy shield leech"] = "EnergyShieldLeechRate",
	["recovery per second from energy shield leech"] = "EnergyShieldLeechRate",
	["total recovery per second from mana leech"] = "ManaLeechRate",
	["recovery per second from mana leech"] = "ManaLeechRate",
	["total recovery per second from life, mana, or energy shield leech"] = { "LifeLeechRate", "ManaLeechRate", "EnergyShieldLeechRate" },
	["maximum recovery per life leech"] = "MaxLifeLeechInstance",
	["maximum recovery per energy shield leech"] = "MaxEnergyShieldLeechInstance",
	["maximum recovery per mana leech"] = "MaxManaLeechInstance",
	["maximum total recovery per second from life leech"] = "MaxLifeLeechRate",
	["maximum total life recovery per second from leech"] = "MaxLifeLeechRate",
	["maximum total recovery per second from energy shield leech"] = "MaxEnergyShieldLeechRate",
	["maximum total energy shield recovery per second from leech"] = "MaxEnergyShieldLeechRate",
	["maximum total recovery per second from mana leech"] = "MaxManaLeechRate",
	["maximum total mana recovery per second from leech"] = "MaxManaLeechRate",
	["maximum total life, mana and energy shield recovery per second from leech"] = { "MaxLifeLeechRate", "MaxManaLeechRate", "MaxEnergyShieldLeechRate" },
	["life and mana leech is instant"] = { "InstantManaLeech", "InstantLifeLeech" },
	["life leech is instant"] = { "InstantLifeLeech" },
	["mana leech is instant"] = { "InstantManaLeech" },
	["energy shield leech is instant"] = { "InstantEnergyShieldLeech" },
	["leech is instant"] = { "InstantEnergyShieldLeech", "InstantManaLeech", "InstantLifeLeech" },
	["to impale enemies on hit"] = "ImpaleChance",
	["to impale on spell hit"] = { "ImpaleChance", flags = ModFlag.Spell },
	["impale effect"] = "ImpaleEffect",
	["effect of impales you inflict"] = "ImpaleEffect",
	["effects of impale inflicted"] = "ImpaleEffect", -- typo / old wording change
	["effect of impales inflicted"] = "ImpaleEffect",
	-- Projectile modifiers
	["projectile"] = "ProjectileCount",
	["projectiles"] = "ProjectileCount",
	["projectile speed"] = "ProjectileSpeed",
	["arrow speed"] = { "ProjectileSpeed", flags = ModFlag.Bow },
	-- Totem/trap/mine/brand modifiers
	["totem placement speed"] = "TotemPlacementSpeed",
	["totem life"] = "TotemLife",
	["totem duration"] = "TotemDuration",
	["maximum number of summoned totems"] = "ActiveTotemLimit",
	["maximum number of summoned totems."] = "ActiveTotemLimit", -- Mark plz
	["maximum number of summoned ballista totems"] = { "ActiveBallistaLimit", tag = { type = "SkillType", skillType = SkillType.TotemsAreBallistae } },
	["trap throwing speed"] = "TrapThrowingSpeed",
	["trap and mine throwing speed"] = { "TrapThrowingSpeed", "MineLayingSpeed" },
	["trap trigger area of effect"] = "TrapTriggerAreaOfEffect",
	["trap duration"] = "TrapDuration",
	["cooldown recovery speed for throwing traps"] = { "CooldownRecovery", keywordFlags = KeywordFlag.Trap },
	["cooldown recovery rate for throwing traps"] = { "CooldownRecovery", keywordFlags = KeywordFlag.Trap },
	["mine laying speed"] = "MineLayingSpeed",
	["mine throwing speed"] = "MineLayingSpeed",
	["mine detonation area of effect"] = "MineDetonationAreaOfEffect",
	["mine duration"] = "MineDuration",
	["activation frequency"] = "BrandActivationFrequency",
	["brand activation frequency"] = "BrandActivationFrequency",
	["brand attachment range"] = "BrandAttachmentRange",
	-- Minion modifiers
	["maximum number of skeletons"] = "ActiveSkeletonLimit",
	["maximum number of zombies"] = "ActiveZombieLimit",
	["maximum number of raised zombies"] = "ActiveZombieLimit",
	["number of zombies allowed"] = "ActiveZombieLimit",
	["maximum number of spectres"] = "ActiveSpectreLimit",
	["maximum number of golems"] = "ActiveGolemLimit",
	["maximum number of summoned golems"] = "ActiveGolemLimit",
	["maximum number of summoned raging spirits"] = "ActiveRagingSpiritLimit",
	["maximum number of raging spirits"] = "ActiveRagingSpiritLimit",
	["maximum number of summoned phantasms"] = "ActivePhantasmLimit",
	["maximum number of summoned holy relics"] = "ActiveHolyRelicLimit",
	["number of summoned arbalists"] = "ActiveArbalistLimit",
	["minion duration"] = { "Duration", tag = { type = "SkillType", skillType = SkillType.CreatesMinion } },
	["skeleton duration"] = { "Duration", tag = { type = "SkillName", skillName = "Summon Skeleton", includeTransfigured = true } },
	["sentinel of dominance duration"] = { "Duration", tag = { type = "SkillName", skillName = "Dominating Blow", includeTransfigured = true } },
	-- Other skill modifiers
	["radius"] = "AreaOfEffect",
	["radius of area skills"] = "AreaOfEffect",
	["area of effect radius"] = "AreaOfEffect",
	["area of effect"] = "AreaOfEffect",
	["area of effect of skills"] = "AreaOfEffect",
	["area of effect of area skills"] = "AreaOfEffect",
	["aspect of the spider area of effect"] = { "AreaOfEffect", tag = { type = "SkillName", skillName = "Aspect of the Spider" } },
	["firestorm explosion area of effect"] = { "AreaOfEffectSecondary", tag = { type = "SkillName", skillName = "Firestorm", includeTransfigured = true } },
	["duration"] = "Duration",
	["skill effect duration"] = "Duration",
	["chaos skill effect duration"] = { "Duration", keywordFlags = KeywordFlag.Chaos },
	["soul gain prevention duration"] = "SoulGainPreventionDuration",
	["aspect of the spider debuff duration"] = { "Duration", tag = { type = "SkillName", skillName = "Aspect of the Spider" } },
	["fire trap burning ground duration"] = { "Duration", tag = { type = "SkillName", skillName = "Fire Trap" } },
	["sentinel of absolution duration"] = { "SecondaryDuration", tag = { type = "SkillName", skillName = "Absolution", includeTransfigured = true } },
	["cooldown duration"] = "CooldownRecovery",
	["cooldown recovery"] = "CooldownRecovery",
	["cooldown recovery speed"] = "CooldownRecovery",
	["cooldown recovery rate"] = "CooldownRecovery",
	["cooldown use"] = "AdditionalCooldownUses",
	["cooldown uses"] = "AdditionalCooldownUses",
	["weapon range"] = "WeaponRange",
	["metres to weapon range"] = "WeaponRangeMetre",
	["metre to weapon range"] = "WeaponRangeMetre",
	["melee range"] = "MeleeWeaponRange",
	["melee weapon range"] = "MeleeWeaponRange",
	["melee weapon and unarmed range"] = { "MeleeWeaponRange", "UnarmedRange" },
	["melee weapon and unarmed attack range"] = { "MeleeWeaponRange", "UnarmedRange" },
	["melee strike range"] = { "MeleeWeaponRange", "UnarmedRange" },
	["metres to melee strike range"] = { "MeleeWeaponRangeMetre", "UnarmedRangeMetre" },
	["metre to melee strike range"] = { "MeleeWeaponRangeMetre", "UnarmedRangeMetre" },
	["to deal double damage"] = "DoubleDamageChance",
	["to deal triple damage"] = "TripleDamageChance",
	-- Buffs
	["onslaught effect"] = "OnslaughtEffect",
	["effect of onslaught on you"] = "OnslaughtEffect",
	["adrenaline duration"] = "AdrenalineDuration",
	["effect of tailwind on you"] = "TailwindEffectOnSelf",
	["elusive effect"] = "ElusiveEffect",
	["effect of elusive on you"] = "ElusiveEffect",
	["effect of infusion"] = "InfusionEffect",
	-- Basic damage types
	["damage"] = "Damage",
	["physical damage"] = "PhysicalDamage",
	["lightning damage"] = "LightningDamage",
	["cold damage"] = "ColdDamage",
	["fire damage"] = "FireDamage",
	["chaos damage"] = "ChaosDamage",
	["non-chaos damage"] = "NonChaosDamage",
	["elemental damage"] = {"FireDamage", "ColdDamage", "LightningDamage"},
	-- Other damage forms
	["attack damage"] = { "Damage", flags = ModFlag.Attack },
	["attack physical damage"] = { "PhysicalDamage", flags = ModFlag.Attack },
	["physical attack damage"] = { "PhysicalDamage", flags = ModFlag.Attack },
	["minimum physical attack damage"] = { "MinPhysicalDamage", tag = { type = "SkillType", skillType = SkillType.Attack } },
	["maximum physical attack damage"] = { "MaxPhysicalDamage", tag = { type = "SkillType", skillType = SkillType.Attack } },
	["physical weapon damage"] = { "PhysicalDamage", flags = ModFlag.Weapon },
	["physical damage with weapons"] = { "PhysicalDamage", flags = ModFlag.Weapon },
	["melee damage"] = { "Damage", flags = ModFlag.Melee },
	["physical melee damage"] = { "PhysicalDamage", flags = ModFlag.Melee },
	["melee physical damage"] = { "PhysicalDamage", flags = ModFlag.Melee },
	["bow damage"] = { "Damage", flags = bor(ModFlag.Bow, ModFlag.Hit) },
	["damage with arrow hits"] = { "Damage", flags = bor(ModFlag.Bow, ModFlag.Hit) },
	["wand damage"] = { "Damage", flags = bor(ModFlag.Wand, ModFlag.Hit) },
	["wand physical damage"] = { "PhysicalDamage", flags = bor(ModFlag.Wand, ModFlag.Hit) },
	["sword physical damage"] = { "PhysicalDamage", flags = bor(ModFlag.Sword, ModFlag.Hit) },
	["damage over time"] = { "Damage", flags = ModFlag.Dot },
	["physical damage over time"] = { "PhysicalDamage", keywordFlags = KeywordFlag.PhysicalDot },
	["cold damage over time"] = { "ColdDamage", keywordFlags = KeywordFlag.ColdDot },
	["chaos damage over time"] = { "ChaosDamage", keywordFlags = KeywordFlag.ChaosDot },
	["burning damage"] = { "FireDamage", keywordFlags = KeywordFlag.FireDot },
	["damage with ignite"] = { "Damage", keywordFlags = KeywordFlag.Ignite },
	["damage with ignites"] = { "Damage", keywordFlags = KeywordFlag.Ignite },
	["damage with ignites inflicted"] = { "Damage", keywordFlags = KeywordFlag.Ignite },
	["incinerate damage for each stage"] = { "Damage", tagList = { { type = "Multiplier", var = "IncinerateStage" }, { type = "SkillName", skillName = "Incinerate" } } },
	["physical damage over time multiplier"] = "PhysicalDotMultiplier",
	["fire damage over time multiplier"] = "FireDotMultiplier",
	["cold damage over time multiplier"] = "ColdDotMultiplier",
	["chaos damage over time multiplier"] = "ChaosDotMultiplier",
	["damage over time multiplier"] = "DotMultiplier",
	-- Crit/accuracy/speed modifiers
	["crit chance"] = "CritChance",
	["critical strike chance"] = "CritChance",
	["attack critical strike chance"] = { "CritChance", flags = ModFlag.Attack },
	["critical strike multiplier"] = "CritMultiplier",
	["critical multiplier"] = "CritMultiplier",
	["attack critical strike multiplier"] = { "CritMultiplier", flags = ModFlag.Attack },
	["accuracy"] = "Accuracy",
	["accuracy rating"] = "Accuracy",
	["minion accuracy rating"] = { "Accuracy", addToMinion = true },
	["attack speed"] = { "Speed", flags = ModFlag.Attack },
	["cast speed"] = { "Speed", flags = ModFlag.Cast },
	["warcry speed"] = { "WarcrySpeed", keywordFlags = KeywordFlag.Warcry },
	["attack and cast speed"] = "Speed",
	["dps"] = "DPS",
	["to sap enemies"] = "EnemySapChance",
	["effect of scorch"] = "EnemyScorchEffect",
	["effect of sap"] = "EnemySapEffect",
	["effect of brittle"] = "EnemyBrittleEffect",
	["effect of shock"] = "EnemyShockEffect",
	["effect of shock on you"] = "SelfShockEffect",
	["effect of shock you inflict"] = "EnemyShockEffect",
	["effect of shocks you inflict"] = "EnemyShockEffect",
	["effect of lightning ailments"] = { "EnemyShockEffect" , "EnemySapEffect" },
	["effect of chill"] = "EnemyChillEffect",
	["effect of chill and shock on you"] = { "SelfChillEffect", "SelfShockEffect" },
	["chill effect"] = "EnemyChillEffect",
	["effect of chill you inflict"] = "EnemyChillEffect",
	["effect of cold ailments"] = { "EnemyChillEffect" , "EnemyBrittleEffect" },
	["effect of chill on you"] = "SelfChillEffect",
	["effect of non-damaging ailments"] = { "EnemyShockEffect", "EnemyChillEffect", "EnemyFreezeEffect", "EnemyScorchEffect", "EnemyBrittleEffect", "EnemySapEffect" },
	["effect of non-damaging ailments you inflict"] = { "EnemyShockEffect", "EnemyChillEffect", "EnemyFreezeEffect", "EnemyScorchEffect", "EnemyBrittleEffect", "EnemySapEffect" },
	["shock duration"] = "EnemyShockDuration",
	["duration of shocks you inflict"] = "EnemyShockDuration",
	["shock duration on you"] = "SelfShockDuration",
	["duration of lightning ailments"] = { "EnemyShockDuration" , "EnemySapDuration" },
	["freeze duration"] = "EnemyFreezeDuration",
	["duration of freezes you inflict"] = "EnemyFreezeDuration",
	["freeze duration on you"] = "SelfFreezeDuration",
	["chill duration"] = "EnemyChillDuration",
	["duration of chills you inflict"] = "EnemyChillDuration",
	["chill duration on you"] = "SelfChillDuration",
	["duration of cold ailments"] = { "EnemyFreezeDuration" , "EnemyChillDuration", "EnemyBrittleDuration" },
	["ignite duration"] = "EnemyIgniteDuration",
	["duration of ignites you inflict"] = "EnemyIgniteDuration",
	["ignite duration on you"] = "SelfIgniteDuration",
	["duration of ignite on you"] = "SelfIgniteDuration",
	["duration of elemental ailments"] = "EnemyElementalAilmentDuration",
	["duration of elemental ailments on you"] = "SelfElementalAilmentDuration",
	["duration of elemental status ailments"] = "EnemyElementalAilmentDuration",
	["duration of ailments"] = "EnemyAilmentDuration",
	["duration of ailments on you"] = "SelfAilmentDuration",
	["elemental ailment duration on you"] = "SelfElementalAilmentDuration",
	["duration of ailments you inflict"] = "EnemyAilmentDuration",
	["duration of ailments inflicted"] = "EnemyAilmentDuration",
	["duration of ailments inflicted on you"] = "SelfAilmentDuration",
	["duration of damaging ailments on you"] = { "SelfIgniteDuration" , "SelfBleedDuration", "SelfPoisonDuration" },
	-- Other ailments
	["to poison"] = "PoisonChance",
	["to cause poison"] = "PoisonChance",
	["to poison on hit"] = "PoisonChance",
	["poison duration"] = { "EnemyPoisonDuration" },
	["poison duration on you"] = "SelfPoisonDuration",
	["duration of poisons on you"] = "SelfPoisonDuration",
	["duration of poisons you inflict"] = { "EnemyPoisonDuration" },
	["to cause bleeding"] = "BleedChance",
	["to cause bleeding on hit"] = "BleedChance",
	["to inflict bleeding"] = "BleedChance",
	["to inflict bleeding on hit"] = "BleedChance",
	["bleed duration"] = { "EnemyBleedDuration" },
	["bleeding duration"] = { "EnemyBleedDuration" },
	["bleed duration on you"] = "SelfBleedDuration",
	-- Misc modifiers
	["movement speed"] = "MovementSpeed",
	["attack, cast and movement speed"] = { "Speed", "MovementSpeed" },
	["action speed"] = "ActionSpeed",
	["light radius"] = "LightRadius",
	["rarity of items found"] = "LootRarity",
	["rarity of items dropped"] = "LootRarity",
	["quantity of items found"] = "LootQuantity",
	["item quantity"] = "LootQuantity",
	["strength requirement"] = "StrRequirement",
	["dexterity requirement"] = "DexRequirement",
	["intelligence requirement"] = "IntRequirement",
	["omni requirement"] = "OmniRequirement",
	["strength and intelligence requirement"] = { "StrRequirement", "IntRequirement" },
	["attribute requirements"] = { "StrRequirement", "DexRequirement", "IntRequirement" },
	["effect of socketed jewels"] = "SocketedJewelEffect",
	["effect of socketed abyss jewels"] = "SocketedJewelEffect",
	["to inflict fire exposure on hit"] = "FireExposureChance",
	["to apply fire exposure on hit"] = "FireExposureChance",
	["to inflict cold exposure on hit"] = "ColdExposureChance",
	["to apply cold exposure on hit"] = "ColdExposureChance",
	["to inflict lightning exposure on hit"] = "LightningExposureChance",
	["to apply lightning exposure on hit"] = "LightningExposureChance",
	-- Flask modifiers
	["effect"] = "FlaskEffect",
	["effect of flasks"] = "FlaskEffect",
	["amount recovered"] = "FlaskRecovery",
	["life recovered"] = "FlaskRecovery",
	["life recovery from flasks used"] = "FlaskLifeRecovery",
	["mana recovered"] = "FlaskRecovery",
	["life recovery from flasks"] = "FlaskLifeRecovery",
	["mana recovery from flasks"] = "FlaskManaRecovery",
	["life and mana recovery from flasks"] = { "FlaskLifeRecovery", "FlaskManaRecovery" },
	["flask effect duration"] = "FlaskDuration",
	["recovery speed"] = "FlaskRecoveryRate",
	["recovery rate"] = "FlaskRecoveryRate",
	["flask recovery rate"] = "FlaskRecoveryRate",
	["flask recovery speed"] = "FlaskRecoveryRate",
	["flask life recovery rate"] = "FlaskLifeRecoveryRate",
	["flask mana recovery rate"] = "FlaskManaRecoveryRate",
	["extra charges"] = "FlaskCharges",
	["maximum charges"] = "FlaskCharges",
	["charges used"] = "FlaskChargesUsed",
	["charges per use"] = "FlaskChargesUsed",
	["flask charges used"] = "FlaskChargesUsed",
	["flask charges gained"] = "FlaskChargesGained",
	["charge recovery"] = "FlaskChargeRecovery",
	["for flasks you use to not consume charges"] = "FlaskChanceNotConsumeCharges",
	["impales you inflict last"] = "ImpaleStacksMax",
	-- Buffs
	["adrenaline"] = "Condition:Adrenaline",
	["elusive"] = "Condition:CanBeElusive",
	["onslaught"] = "Condition:Onslaught",
	["rampage"] = "Condition:Rampage",
	["soul eater"] = "Condition:CanHaveSoulEater",
	["phasing"] = "Condition:Phasing",
	["arcane surge"] = "Condition:ArcaneSurge",
	["unholy might"] = "Condition:UnholyMight",
	["lesser brutal shrine buff"] = "Condition:LesserBrutalShrine",
	["lesser massive shrine buff"] = "Condition:LesserMassiveShrine",
	["diamond shrine buff"] = "Condition:DiamondShrine",
	["massive shrine buff"] = "Condition:MassiveShrine",
}

for skillId, skill in pairs(data.skills) do
	modNameList["to " .. skill.name:lower()] = {"ChanceToTriggerOnHit_"..skillId, flags = ModFlag.Hit}
	modNameList[skill.name:lower() .. " chance"] = {"ChanceToTriggerOnHit_"..skillId, flags = ModFlag.Hit}
end

for _, damageType in ipairs(DamageTypes) do
	modNameList[damageType:lower() .. " penetration"] = damageType .. "Penetration"
end

modNameList["penetration"] = "Penetration"

-- List of modifier flags
local modFlagList = {
	-- Weapon types
	["with axes"] = { flags = bor(ModFlag.Axe, ModFlag.Hit) },
	["to axe attacks"] = { flags = bor(ModFlag.Axe, ModFlag.Hit) },
	["with axe attacks"] = { flags = bor(ModFlag.Axe, ModFlag.Hit) },
	["with axes or swords"] = { flags = ModFlag.Hit, tag = { type = "ModFlagOr", modFlags = bor(ModFlag.Axe, ModFlag.Sword) } },
	["with bows"] = { flags = bor(ModFlag.Bow, ModFlag.Hit) },
	["to bow attacks"] = { flags = bor(ModFlag.Bow, ModFlag.Hit) },
	["with bow attacks"] = { flags = bor(ModFlag.Bow, ModFlag.Hit) },
	["with daggers"] = { flags = bor(ModFlag.Dagger, ModFlag.Hit) },
	["to dagger attacks"] = { flags = bor(ModFlag.Dagger, ModFlag.Hit) },
	["with dagger attacks"] = { flags = bor(ModFlag.Dagger, ModFlag.Hit) },
	["with maces"] = { flags = bor(ModFlag.Mace, ModFlag.Hit) },
	["to mace attacks"] = { flags = bor(ModFlag.Mace, ModFlag.Hit) },
	["with mace attacks"] = { flags = bor(ModFlag.Mace, ModFlag.Hit) },
	["with maces and sceptres"] = { flags = bor(ModFlag.Mace, ModFlag.Hit) },
	["with maces or sceptres"] = { flags = bor(ModFlag.Mace, ModFlag.Hit) },
	["with maces, sceptres or staves"] = { flags = ModFlag.Hit, tag = { type = "ModFlagOr", modFlags = bor(ModFlag.Mace, ModFlag.Staff) } },
	["to mace and sceptre attacks"] = { flags = bor(ModFlag.Mace, ModFlag.Hit) },
	["to mace or sceptre attacks"] = { flags = bor(ModFlag.Mace, ModFlag.Hit) },
	["with mace or sceptre attacks"] = { flags = bor(ModFlag.Mace, ModFlag.Hit) },
	["with staves"] = { flags = bor(ModFlag.Staff, ModFlag.Hit) },
	["to staff attacks"] = { flags = bor(ModFlag.Staff, ModFlag.Hit) },
	["with staff attacks"] = { flags = bor(ModFlag.Staff, ModFlag.Hit) },
	["with swords"] = { flags = bor(ModFlag.Sword, ModFlag.Hit) },
	["to sword attacks"] = { flags = bor(ModFlag.Sword, ModFlag.Hit) },
	["with sword attacks"] = { flags = bor(ModFlag.Sword, ModFlag.Hit) },
	["with wands"] = { flags = bor(ModFlag.Wand, ModFlag.Hit) },
	["to wand attacks"] = { flags = bor(ModFlag.Wand, ModFlag.Hit) },
	["with wand attacks"] = { flags = bor(ModFlag.Wand, ModFlag.Hit) },
	["unarmed"] = { flags = bor(ModFlag.Unarmed, ModFlag.Hit) },
	["unarmed melee"] = { flags = bor(ModFlag.Unarmed, ModFlag.Melee, ModFlag.Hit) },
	["with unarmed attacks"] = { flags = bor(ModFlag.Unarmed, ModFlag.Hit) },
	["with unarmed melee attacks"] = { flags = bor(ModFlag.Unarmed, ModFlag.Melee) },
	["to unarmed attacks"] = { flags = bor(ModFlag.Unarmed, ModFlag.Hit) },
	["to unarmed melee hits"] = { flags = bor(ModFlag.Unarmed, ModFlag.Melee, ModFlag.Hit) },
	["with one handed weapons"] = { flags = bor(ModFlag.Weapon1H, ModFlag.Hit) },
	["with one handed melee weapons"] = { flags = bor(ModFlag.Weapon1H, ModFlag.WeaponMelee, ModFlag.Hit) },
	["with two handed weapons"] = { flags = bor(ModFlag.Weapon2H, ModFlag.Hit) },
	["with two handed melee weapons"] = { flags = bor(ModFlag.Weapon2H, ModFlag.WeaponMelee, ModFlag.Hit) },
	["with ranged weapons"] = { flags = bor(ModFlag.WeaponRanged, ModFlag.Hit) },
	-- Skill types
	["elemental"] = { keywordFlags = bor(KeywordFlag.Fire, KeywordFlag.Cold, KeywordFlag.Lightning) },
	["spell"] = { flags = ModFlag.Spell },
	["for spells"] = { flags = ModFlag.Spell },
	["for spell damage"] = { flags = ModFlag.Spell },
	["with spell damage"] = { flags = ModFlag.Spell },
	["with spells"] = { keywordFlags = KeywordFlag.Spell },
	["with triggered spells"] = { keywordFlags = KeywordFlag.Spell, tag = { type = "SkillType", skillType = SkillType.Triggered } },
	["by spells"] = { keywordFlags = KeywordFlag.Spell },
	["by your spells"] = { keywordFlags = KeywordFlag.Spell },
	["with attacks"] = { keywordFlags = KeywordFlag.Attack },
	["by attacks"] = { keywordFlags = KeywordFlag.Attack },
	["by your attacks"] = { keywordFlags = KeywordFlag.Attack },
	["with attack skills"] = { keywordFlags = KeywordFlag.Attack },
	["for attacks"] = { flags = ModFlag.Attack },
	["for attack damage"] = { flags = ModFlag.Attack },
	["weapon"] = { flags = ModFlag.Weapon },
	["with weapons"] = { flags = ModFlag.Weapon },
	["melee"] = { flags = ModFlag.Melee },
	["with melee attacks"] = { flags = ModFlag.Melee },
	["with melee critical strikes"] = { flags = ModFlag.Melee, tag = { type = "Condition", var = "CriticalStrike" } },
	["with melee skills"] = { flags = ModFlag.Melee },
	["with bow skills"] = { keywordFlags = KeywordFlag.Bow },
	["on melee hit"] = { flags = bor(ModFlag.Melee, ModFlag.Hit) },
	["on hit"] = { flags = ModFlag.Hit },
	["with hits"] = { keywordFlags = KeywordFlag.Hit },
	["with hits against nearby enemies"] = { keywordFlags = KeywordFlag.Hit },
	["with hits and ailments"] = { keywordFlags = bor(KeywordFlag.Hit, KeywordFlag.Ailment) },
	["with ailments"] = { flags = ModFlag.Ailment },
	["with ailments from attack skills"] = { flags = ModFlag.Ailment, keywordFlags = KeywordFlag.Attack },
	["with poison"] = { keywordFlags = KeywordFlag.Poison },
	["with bleeding"] = { keywordFlags = KeywordFlag.Bleed },
	["for ailments"] = { flags = ModFlag.Ailment },
	["for poison"] = { keywordFlags = bor(KeywordFlag.Poison, KeywordFlag.MatchAll) },
	["for bleeding"] = { keywordFlags = KeywordFlag.Bleed },
	["for ignite"] = { keywordFlags = KeywordFlag.Ignite },
	["against damage over time"] = { flags = ModFlag.Dot },
	["area"] = { flags = ModFlag.Area },
	["mine"] = { keywordFlags = KeywordFlag.Mine },
	["with mines"] = { keywordFlags = KeywordFlag.Mine },
	["trap"] = { keywordFlags = KeywordFlag.Trap },
	["with traps"] = { keywordFlags = KeywordFlag.Trap },
	["for traps"] = { keywordFlags = KeywordFlag.Trap },
	["curse skills"] = { keywordFlags = KeywordFlag.Curse },
	["of curse skills"] = { keywordFlags = KeywordFlag.Curse },
	["with curse skills"] = { keywordFlags = KeywordFlag.Curse },
	["minion skills"] = { tag = { type = "SkillType", skillType = SkillType.Minion } },
	["of minion skills"] = { tag = { type = "SkillType", skillType = SkillType.Minion } },
	["for curses"] = { keywordFlags = KeywordFlag.Curse },
	["with movement skills"] = { keywordFlags = KeywordFlag.Movement },
	["of movement skills"] = { keywordFlags = KeywordFlag.Movement },
	["of movement skills used"] = { keywordFlags = KeywordFlag.Movement },
	["of travel skills"] = { tag = { type = "SkillType", skillType = SkillType.Travel } },
	["of banner skills"] = { tag = { type = "SkillType", skillType = SkillType.Banner } },
	["with lightning skills"] = { keywordFlags = KeywordFlag.Lightning },
	["with cold skills"] = { keywordFlags = KeywordFlag.Cold },
	["with fire skills"] = { keywordFlags = KeywordFlag.Fire },
	["with elemental spells"] = { keywordFlags = bor(KeywordFlag.Lightning, KeywordFlag.Cold, KeywordFlag.Fire) },
	["with chaos skills"] = { keywordFlags = KeywordFlag.Chaos },
	["with physical skills"] = { keywordFlags = KeywordFlag.Physical },
	["with channelling skills"] = { tag = { type = "SkillType", skillType = SkillType.Channel } },
	["channelling"] = { tag = { type = "SkillType", skillType = SkillType.Channel } },
	["channelling skills"] = { tag = { type = "SkillType", skillType = SkillType.Channel } },
	["non-channelling"] = { tag = { type = "SkillType", skillType = SkillType.Channel, neg = true } },
	["non-channelling skills"] = { tag = { type = "SkillType", skillType = SkillType.Channel, neg = true } },
	["with brand skills"] = { tag = { type = "SkillType", skillType = SkillType.Brand } },
	["for stance skills"] = { tag = { type = "SkillType", skillType = SkillType.Stance } },
	["of stance skills"] = { tag = { type = "SkillType", skillType = SkillType.Stance } },
	["mark skills"] = { tag = { type = "SkillType", skillType = SkillType.Mark } },
	["of mark skills"] = { tag = { type = "SkillType", skillType = SkillType.Mark } },
	["with skills that cost life"] = { tag = { type = "StatThreshold", stat = "LifeCost", threshold = 1 } },
	["minion"] = { addToMinion = true },
	["zombie"] = { addToMinion = true, addToMinionTag = { type = "SkillName", skillName = "Raise Zombie", includeTransfigured = true } },
	["raised zombie"] = { addToMinion = true, addToMinionTag = { type = "SkillName", skillName = "Raise Zombie", includeTransfigured = true } },
	["skeleton"] = { addToMinion = true, addToMinionTag = { type = "SkillName", skillName = "Summon Skeleton", includeTransfigured = true } },
	["spectre"] = { addToMinion = true, addToMinionTag = { type = "SkillName", skillName = "Raise Spectre", includeTransfigured = true } },
	["raised spectre"] = { addToMinion = true, addToMinionTag = { type = "SkillName", skillName = "Raise Spectre", includeTransfigured = true } },
	["golem"] = { addToMinion = true, addToMinionTag = { type = "SkillType", skillType = SkillType.Golem } },
	["chaos golem"] = { addToMinion = true, addToMinionTag = { type = "SkillName", skillName = "Summon Chaos Golem", includeTransfigured = true } },
	["flame golem"] = { addToMinion = true, addToMinionTag = { type = "SkillName", skillName = "Summon Flame Golem", includeTransfigured = true } },
	["increased flame golem"] = { addToMinion = true, addToMinionTag = { type = "SkillName", skillName = "Summon Flame Golem", includeTransfigured = true } },
	["ice golem"] = { addToMinion = true, addToMinionTag = { type = "SkillName", skillName = "Summon Ice Golem", includeTransfigured = true } },
	["lightning golem"] = { addToMinion = true, addToMinionTag = { type = "SkillName", skillName = "Summon Lightning Golem", includeTransfigured = true } },
	["stone golem"] = { addToMinion = true, addToMinionTag = { type = "SkillName", skillName = "Summon Stone Golem", includeTransfigured = true } },
	["animated guardian"] = { addToMinion = true, addToMinionTag = { type = "SkillName", skillName = "Animate Guardian", includeTransfigured = true } },
	-- Damage types
	["with physical damage"] = { tag = { type = "Condition", var = "PhysicalHasDamage" } },
	["with lightning damage"] = { tag = { type = "Condition", var = "LightningHasDamage" } },
	["with cold damage"] = { tag = { type = "Condition", var = "ColdHasDamage" } },
	["with fire damage"] = { tag = { type = "Condition", var = "FireHasDamage" } },
	["with chaos damage"] = { tag = { type = "Condition", var = "ChaosHasDamage" } },
	-- Other
	["global"] = { tag = { type = "Global" } },
	["from equipped shield"] = { tag = { type = "SlotName", slotName = "Weapon 2" } },
	["from equipped helmet"] = { tag = { type = "SlotName", slotName = "Helmet" } },
	["from equipped gloves and boots"] = { tag = { type = "SlotName", slotNameList = { "Gloves", "Boots" } } },
	["from equipped boots and gloves"] = { tag = { type = "SlotName", slotNameList = { "Gloves", "Boots" } } },
	["from equipped helmet and gloves"] = { tag = { type = "SlotName", slotNameList = { "Helmet", "Gloves" } } },
	["from equipped helmet and boots"] = { tag = { type = "SlotName", slotNameList = { "Helmet", "Boots" } } },
	["from your equipped body armour"] = { tag = { type = "SlotName", slotName = "Body Armour" } },
	["from equipped body armour"] = { tag = { type = "SlotName", slotName = "Body Armour" } },
	["from body armour"] = { tag = { type = "SlotName", slotName = "Body Armour" } },
	["from your body armour"] = { tag = { type = "SlotName", slotName = "Body Armour" } },
}

for _, damageType in ipairs(DamageTypes) do
	modFlagList["on " .. damageType:lower() .. " hit"] = { keywordFlags = KeywordFlag[damageType], flags = ModFlag.Hit }
end

-- List of modifier flags/tags that appear at the start of a line
local preFlagList = {
	-- Weapon types
	["^axe attacks [hd][ae][va][el] "] = { flags = ModFlag.Axe },
	["^axe or sword attacks [hd][ae][va][el] "] = { tag = { type = "ModFlagOr", modFlags = bor(ModFlag.Axe, ModFlag.Sword) } },
	["^bow attacks [hd][ae][va][el] "] = { flags = ModFlag.Bow },
	["^claw attacks [hd][ae][va][el] "] = { flags = ModFlag.Claw },
	["^dagger attacks [hd][ae][va][el] "] = { flags = ModFlag.Dagger },
	["^mace or sceptre attacks [hd][ae][va][el] "] = { flags = ModFlag.Mace },
	["^mace, sceptre or staff attacks [hd][ae][va][el] "] = { tag = { type = "ModFlagOr", modFlags = bor(ModFlag.Mace, ModFlag.Staff) } },
	["^staff attacks [hd][ae][va][el] "] = { flags = ModFlag.Staff },
	["^sword attacks [hd][ae][va][el] "] = { flags = ModFlag.Sword },
	["^wand attacks [hd][ae][va][el] "] = { flags = ModFlag.Wand },
	["^unarmed attacks [hd][ae][va][el] "] = { flags = ModFlag.Unarmed },
	["^attacks with one handed weapons [hd][ae][va][el] "] = { flags = ModFlag.Weapon1H },
	["^attacks with two handed weapons [hd][ae][va][el] "] = { flags = ModFlag.Weapon2H },
	["^attacks with melee weapons [hd][ae][va][el] "] = { flags = ModFlag.WeaponMelee },
	["^attacks with one handed melee weapons [hd][ae][va][el] "] = { flags = bor(ModFlag.Weapon1H, ModFlag.WeaponMelee) },
	["^attacks with two handed melee weapons [hd][ae][va][el] "] = { flags = bor(ModFlag.Weapon2H, ModFlag.WeaponMelee) },
	["^attacks with ranged weapons [hd][ae][va][el] "] = { flags = ModFlag.WeaponRanged },
	-- Damage types
	["^attack damage "] = { flags = ModFlag.Attack },
	["^hits deal "] = { keywordFlags = KeywordFlag.Hit },
	["^deal "] = { },
	["^arrows deal "] = { flags = ModFlag.Bow },
	["^critical strikes deal "] = { tag = { type = "Condition", var = "CriticalStrike" } },
	["^poisons you inflict with critical strikes have "] = { keywordFlags = bor(KeywordFlag.Poison, KeywordFlag.MatchAll), tag = { type = "Condition", var = "CriticalStrike" } },
	-- Add to minion
	["^minions "] = { addToMinion = true },
	["^minions [hd][ae][va][el] "] = { addToMinion = true },
	["^while a unique enemy is in your presence, minions [hd][ae][va][el] "] = { addToMinion = true, playerTag = { type = "ActorCondition", actor = "enemy", var = "RareOrUnique" } },
	["^while a pinnacle atlas boss is in your presence, minions [hd][ae][va][el] "] = { addToMinion = true, playerTag = { type = "ActorCondition", actor = "enemy", var = "PinnacleBoss" } },
	["^minions leech "] = { addToMinion = true },
	["^minions' attacks deal "] = { addToMinion = true, flags = ModFlag.Attack },
	["^golems [hd][ae][va][el] "] = { addToMinion = true, addToMinionTag = { type = "SkillType", skillType = SkillType.Golem } },
	["^summoned golems [hd][ae][va][el] "] = { addToMinion = true, addToMinionTag = { type = "SkillType", skillType = SkillType.Golem } },
	["^golem skills have "] = { tag = { type = "SkillType", skillType = SkillType.Golem } },
	["^zombies [hd][ae][va][el] "] = { addToMinion = true, addToMinionTag = { type = "SkillName", skillName = "Raise Zombie", includeTransfigured = true } },
	["^raised zombies [hd][ae][va][el] "] = { addToMinion = true, addToMinionTag = { type = "SkillName", skillName = "Raise Zombie", includeTransfigured = true } },
	["^skeletons [hd][ae][va][el] "] = { addToMinion = true, addToMinionTag = { type = "SkillName", skillName = "Summon Skeleton", includeTransfigured = true } },
	["^raging spirits [hd][ae][va][el] "] = { addToMinion = true, addToMinionTag = { type = "SkillName", skillName = "Summon Raging Spirit", includeTransfigured = true } },
	["^summoned raging spirits [hd][ae][va][el] "] = { addToMinion = true, addToMinionTag = { type = "SkillName", skillName = "Summon Raging Spirit", includeTransfigured = true } },
	["^spectres [hd][ae][va][el] "] = { addToMinion = true, addToMinionTag = { type = "SkillName", skillName = "Raise Spectre", includeTransfigured = true } },
	["^chaos golems [hd][ae][va][el] "] = { addToMinion = true, addToMinionTag = { type = "SkillName", skillName = "Summon Chaos Golem", includeTransfigured = true } },
	["^summoned chaos golems [hd][ae][va][el] "] = { addToMinion = true, addToMinionTag = { type = "SkillName", skillName = "Summon Chaos Golem", includeTransfigured = true } },
	["^flame golems [hd][ae][va][el] "] = { addToMinion = true, addToMinionTag = { type = "SkillName", skillName = "Summon Flame Golem", includeTransfigured = true } },
	["^summoned flame golems [hd][ae][va][el] "] = { addToMinion = true, addToMinionTag = { type = "SkillName", skillName = "Summon Flame Golem", includeTransfigured = true } },
	["^ice golems [hd][ae][va][el] "] = { addToMinion = true, addToMinionTag = { type = "SkillName", skillName = "Summon Ice Golem", includeTransfigured = true } },
	["^summoned ice golems [hd][ae][va][el] "] = { addToMinion = true, addToMinionTag = { type = "SkillName", skillName = "Summon Ice Golem", includeTransfigured = true } },
	["^lightning golems [hd][ae][va][el] "] = { addToMinion = true, addToMinionTag = { type = "SkillName", skillName = "Summon Lightning Golem", includeTransfigured = true } },
	["^summoned lightning golems [hd][ae][va][el] "] = { addToMinion = true, addToMinionTag = { type = "SkillName", skillName = "Summon Lightning Golem", includeTransfigured = true } },
	["^stone golems [hd][ae][va][el] "] = { addToMinion = true, addToMinionTag = { type = "SkillName", skillName = "Summon Stone Golem", includeTransfigured = true } },
	["^summoned stone golems [hd][ae][va][el] "] = { addToMinion = true, addToMinionTag = { type = "SkillName", skillName = "Summon Stone Golem", includeTransfigured = true } },
	["^summoned carrion golems [hd][ae][va][el] "] = { addToMinion = true, addToMinionTag = { type = "SkillName", skillName = "Summon Carrion Golem", includeTransfigured = true } },
	["^summoned skitterbots [hd][ae][va][el] "] = { addToMinion = true, addToMinionTag = { type = "SkillName", skillName = "Summon Carrion Golem", includeTransfigured = true } },
	["^blink arrow and blink arrow clones [hd][ae][va][el] "] = { addToMinion = true, addToMinionTag = { type = "SkillName", skillName = "Blink Arrow", includeTransfigured = true } },
	["^mirror arrow and mirror arrow clones [hd][ae][va][el] "] = { addToMinion = true, addToMinionTag = { type = "SkillName", skillName = "Mirror Arrow", includeTransfigured = true } },
	["^animated weapons [hd][ae][va][el] "] = { addToMinion = true, addToMinionTag = { type = "SkillName", skillName = "Animate Weapon", includeTransfigured = true } },
	["^animated guardians? deals? "] = { addToMinion = true, addToMinionTag = { type = "SkillName", skillName = "Animate Guardian", includeTransfigured = true } },
	["^summoned holy relics [hd][ae][va][el] "] = { addToMinion = true, addToMinionTag = { type = "SkillName", skillName = "Summon Holy Relic" } },
	["^summoned reaper [dh][ea][as]l?s? "] = { addToMinion = true, addToMinionTag = { type = "SkillName", skillName = "Summon Reaper", includeTransfigured = true } },
	["^summoned arbalists [hgdf][aei][vair][eln] "] = { addToMinion = true, addToMinionTag = { type = "SkillName", skillName = "Summon Arbalists" } },
	["^summoned arbalists' attacks have "] = { addToMinion = true, addToMinionTag = { type = "SkillName", skillName = "Summon Arbalists" } },
	["^herald skills [hd][ae][va][el] "] = { tag = { type = "SkillType", skillType = SkillType.Herald } },
	["^agony crawler deals "] = { addToMinion = true, addToMinionTag = { type = "SkillName", skillName = "Herald of Agony" } },
	["^summoned agony crawler fires "] = { addToMinion = true, addToMinionTag = { type = "SkillName", skillName = "Herald of Agony" } },
	["^sentinels of purity deal "] = { addToMinion = true, addToMinionTag = { type = "SkillName", skillName = "Herald of Purity" } },
	["^summoned sentinels of absolution have "] = { addToMinion = true, addToMinionTag = { type = "SkillName", skillName = "Absolution", includeTransfigured = true } },
	["^summoned sentinels have "] = { addToMinion = true, addToMinionTag = { type = "SkillName", skillNameList = { "Herald of Purity", "Dominating Blow", "Absolution" }, includeTransfigured = true } },
	["^raised zombies' slam attack has "] = { addToMinion = true, tag = { type = "SkillId", skillId = "ZombieSlam" } },
	["^raised spectres, raised zombies, and summoned skeletons have "] = { addToMinion = true, addToMinionTag = { type = "SkillName", skillNameList = { "Raise Spectre", "Raise Zombie", "Summon Skeleton" }, includeTransfigured = true } },
	-- Local damage
	["^attacks with this weapon "] = { tagList = { { type = "Condition", var = "{Hand}Attack" }, { type = "SkillType", skillType = SkillType.Attack } } },
	["^attacks with this weapon [hd][ae][va][el] "] = { tagList = { { type = "Condition", var = "{Hand}Attack" }, { type = "SkillType", skillType = SkillType.Attack } } },
	["^hits with this weapon [hd][ae][va][el] "] = { flags = ModFlag.Hit, tagList = { { type = "Condition", var = "{Hand}Attack" }, { type = "SkillType", skillType = SkillType.Attack } } },
	-- Skill types
	["^attacks [hd][ae][va][el] "] = { flags = ModFlag.Attack },
	["^attack skills [hd][ae][va][el] "] = { keywordFlags = KeywordFlag.Attack },
	["^spells [hd][ae][va][el] a? ?"] = { flags = ModFlag.Spell },
	["^spell skills [hd][ae][va][el] "] = { keywordFlags = KeywordFlag.Spell },
	["^projectile attack skills [hd][ae][va][el] "] = { tag = { type = "SkillType", skillType = SkillType.RangedAttack } },
	["^projectiles from attacks [hd][ae][va][el] "] = { tag = { type = "SkillType", skillType = SkillType.RangedAttack } },
	["^arrows [hd][ae][va][el] "] = { keywordFlags = KeywordFlag.Bow },
	["^bow skills [hdf][aei][var][el] "] = { keywordFlags = KeywordFlag.Bow },
	["^projectiles [hdf][aei][var][el] "] = { flags = ModFlag.Projectile },
	["^melee attacks have "] = { flags = ModFlag.Melee },
	["^movement attack skills have "] = { flags = ModFlag.Attack, keywordFlags = KeywordFlag.Movement },
	["^travel skills have "] = { tag = { type = "SkillType", skillType = SkillType.Travel } },
	["^link skills have "] = { tag = { type = "SkillType", skillType = SkillType.Link } },
	["^lightning skills [hd][ae][va][el] a? ?"] = { keywordFlags = KeywordFlag.Lightning },
	["^lightning spells [hd][ae][va][el] a? ?"] = { keywordFlags = KeywordFlag.Lightning, flags = ModFlag.Spell },
	["^cold skills [hd][ae][va][el] a? ?"] = { keywordFlags = KeywordFlag.Cold },
	["^cold spells [hd][ae][va][el] a? ?"] = { keywordFlags = KeywordFlag.Cold, flags = ModFlag.Spell },
	["^fire skills [hd][ae][va][el] a? ?"] = { keywordFlags = KeywordFlag.Fire },
	["^fire spells [hd][ae][va][el] a? ?"] = { keywordFlags = KeywordFlag.Fire, flags = ModFlag.Spell },
	["^chaos skills [hd][ae][va][el] a? ?"] = { keywordFlags = KeywordFlag.Chaos },
	["^vaal skills [hd][ae][va][el] "] = { keywordFlags = KeywordFlag.Vaal },
	["^brand skills [hd][ae][va][el] "] = { keywordFlags = KeywordFlag.Brand },
	["^channelling skills [hd][ae][va][el] "] = { tag = { type = "SkillType", skillType = SkillType.Channel } },
	["^curse skills [hd][ae][va][el] "] = { keywordFlags = KeywordFlag.Curse },
	["^hex skills [hd][ae][va][el] "] = { tag = { type = "SkillType", skillType = SkillType.Hex } },
	["^mark skills [hd][ae][va][el] "] = { tag = { type = "SkillType", skillType = SkillType.Mark } },
	["^melee skills [hd][ae][va][el] "] = { tag = { type = "SkillType", skillType = SkillType.Melee } },
	["^guard skills [hd][ae][va][el] "] = { tag = { type = "SkillType", skillType = SkillType.Guard } },
	["^nova spells [hd][ae][va][el] "] = { tag = { type = "SkillType", skillType = SkillType.Nova } },
	["^area skills [hd][ae][va][el] "] = { tag = { type = "SkillType", skillType = SkillType.Area } },
	["^aura skills [hd][ae][va][el] "] = { tag = { type = "SkillType", skillType = SkillType.Aura } },
	["^prismatic skills [hd][ae][va][el] "] = { tag = { type = "SkillType", skillType = SkillType.RandomElement } },
	["^warcry skills have "] = { tag = { type = "SkillType", skillType = SkillType.Warcry } },
	["^non%-curse aura skills have "] = { tagList = { { type = "SkillType", skillType = SkillType.Aura }, { type = "SkillType", skillType = SkillType.AppliesCurse, neg = true } } },
	["^non%-channelling skills have "] = { tag = { type = "SkillType", skillType = SkillType.Channel, neg = true } },
	["^non%-vaal skills deal "] = { tag = { type = "SkillType", skillType = SkillType.Vaal, neg = true } },
	["^skills [hgdf][aei][vari][eln] "] = { },
	-- Slot specific
	["^left ring slot: "] = { tag = { type = "SlotNumber", num = 1 } },
	["^right ring slot: "] = { tag = { type = "SlotNumber", num = 2 } },
	["^socketed gems [hgd][ae][via][enl] "] = { addToSkill = { type = "SocketedIn", slotName = "{SlotName}" } },
	["^socketed skills [hgd][ae][via][enl] "] = { addToSkill = { type = "SocketedIn", slotName = "{SlotName}" } },
	["^socketed travel skills [hgd][ae][via][enl] "] = { addToSkill = { type = "SocketedIn", slotName = "{SlotName}", keyword = "travel" } },
	["^socketed warcry skills [hgd][ae][via][enl] "] = { addToSkill = { type = "SocketedIn", slotName = "{SlotName}", keyword = "warcry" } },
	["^socketed attacks [hgd][ae][via][enl] "] = { addToSkill = { type = "SocketedIn", slotName = "{SlotName}", keyword = "attack" } },
	["^socketed spells [hgd][ae][via][enl] "] = { addToSkill = { type = "SocketedIn", slotName = "{SlotName}", keyword = "spell" } },
	["^socketed curse gems [hgd][ae][via][enl] "] = { addToSkill = { type = "SocketedIn", slotName = "{SlotName}", keyword = "curse" } },
	["^socketed melee gems [hgd][ae][via][enl] "] = { addToSkill = { type = "SocketedIn", slotName = "{SlotName}", keyword = "melee" } },
	["^socketed golem gems [hgd][ae][via][enl] "] = { addToSkill = { type = "SocketedIn", slotName = "{SlotName}", keyword = "golem" } },
	["^socketed golem skills [hgd][ae][via][enl] "] = { addToSkill = { type = "SocketedIn", slotName = "{SlotName}", keyword = "golem" } },
	["^socketed golem skills have minions "] = { addToSkill = { type = "SocketedIn", slotName = "{SlotName}", keyword = "golem" } },
	["^socketed vaal skills [hgd][ae][via][enl] "] = { addToSkill = { type = "SocketedIn", slotName = "{SlotName}", keyword = "vaal" } },
	["^socketed projectile spells [hgdf][aei][viar][enl] "] = { addToSkill = { type = "SocketedIn", slotName = "{SlotName}" }, tagList = { { type = "SkillType", skillType= SkillType.Projectile }, { type = "SkillType", skillType = SkillType.Spell } } },
	-- Enemy modifiers
	["^enemies withered by you [th]a[vk]e "] = { tag = { type = "MultiplierThreshold", var = "WitheredStack", threshold = 1 }, applyToEnemy = true },
	["^enemies (%a+) by you take "] = function(cond)
		return { tag = { type = "Condition", var = cond:gsub("^%a", string.upper) }, applyToEnemy = true, modSuffix = "Taken" }
	end,
	["^enemies (%a+) by "] = function(cond)
		return { tag = { type = "Condition", var = cond:gsub("^%a", string.upper) }, applyToEnemy = true }
	end,
	["^enemies (%a+) by you have "] = function(cond)
		return { tag = { type = "Condition", var = cond:gsub("^%a", string.upper) }, applyToEnemy = true }
	end,
	["^while a pinnacle atlas boss is in your presence, enemies you've hit recently have "] = function(cond)
		return { playerTagList = { { type = "Condition", var = "HitRecently" }, { type = "ActorCondition", actor = "enemy", var = "RareOrUnique" } }, applyToEnemy = true }
	end,
	["^while a unique enemy is in your presence, enemies you've hit recently have "] = function(cond)
		return { playerTagList = { { type = "Condition", var = "HitRecently" }, { type = "ActorCondition", actor = "enemy", var = "PinnacleBoss" } }, applyToEnemy = true }
	end,
	["^enemies you've hit recently have "] = function(cond)
		return { playerTag = { type = "Condition", var = "HitRecently" }, applyToEnemy = true }
	end,
	["^hits against enemies (%a+) by you have "] = function(cond)
		return { tag = { type = "ActorCondition", actor = "enemy", var = cond:gsub("^%a", string.upper) } }
	end,
	["^enemies shocked or frozen by you take "] = { tag = { type = "Condition", varList = { "Shocked","Frozen" } }, applyToEnemy = true, modSuffix = "Taken" },
	["^enemies affected by your spider's webs [thd][ae][avk][el] "] = { tag = { type = "MultiplierThreshold", var = "Spider's WebStack", threshold = 1 }, applyToEnemy = true },
	["^enemies you curse take "] = { tag = { type = "Condition", var = "Cursed" }, applyToEnemy = true, modSuffix = "Taken" },
	["^enemies you curse "] = { tag = { type = "Condition", var = "Cursed" }, applyToEnemy = true },
	["^nearby enemies take "] = { modSuffix = "Taken", applyToEnemy = true },
	["^nearby enemies have "] = { applyToEnemy = true },
	["^nearby enemies deal "] = { applyToEnemy = true },
	["^nearby enemies'? "] = { applyToEnemy = true },
	["^nearby enemy monsters' "] = { applyToEnemy = true },
	["against you"] = { applyToEnemy = true, actorEnemy = true },
	["^hits against you "] = { applyToEnemy = true, flags = ModFlag.Hit },
	["^enemies near your totems deal "] = { applyToEnemy = true },
	-- Other
	["^your flasks grant "] = { },
	["^when hit, "] = { },
	["^you and allies [hgd][ae][via][enl] "] = { },
	["^auras from your skills grant "] = { addToAura = true },
	["^auras grant "] = { addToAura = true },
	["^you and nearby allies "] = { newAura = true },
	["^you and nearby allies [hgd][ae][via][enl] "] = { newAura = true },
	["^nearby allies [hgd][ae][via][enl] "] = { newAura = true, newAuraOnlyAllies = true },
	["^you and allies affected by auras from your skills [hgd][ae][via][enl] "] = { tag = { type = "Condition", var = "AffectedByAura" } },
	["^take "] = { modSuffix = "Taken" },
	["^marauder: "] = { tag = { type = "Condition", var = "ConnectedToMarauderStart" } },
	["^duelist: "] = { tag = { type = "Condition", var = "ConnectedToDuelistStart" } },
	["^ranger: "] = { tag = { type = "Condition", var = "ConnectedToRangerStart" } },
	["^shadow: "] = { tag = { type = "Condition", var = "ConnectedToShadowStart" } },
	["^witch: "] = { tag = { type = "Condition", var = "ConnectedToWitchStart" } },
	["^templar: "] = { tag = { type = "Condition", var = "ConnectedToTemplarStart" } },
	["^scion: "] = { tag = { type = "Condition", var = "ConnectedToScionStart" } },
	["^skills supported by spellslinger have "] = { tag = { type = "Condition", var = "SupportedBySpellslinger" } },
	["^skills that have dealt a critical strike in the past 8 seconds deal "] = { tag = { type = "Condition", var = "CritInPast8Sec" } },
	["^blink arrow and mirror arrow have "] = { tag = { type = "SkillName", skillNameList = { "Blink Arrow", "Mirror Arrow" }, includeTransfigured = true } },
	["attacks with energy blades "] = { flags = ModFlag.Attack, tag = { type = "Condition", var = "AffectedByEnergyBlade" } },
	["^for each nearby corpse, "] = { tag = { type = "Multiplier", var = "NearbyCorpse" } },
	["^enemies in your link beams have "] = { tag = { type = "Condition", var = "BetweenYouAndLinkedTarget" }, applyToEnemy = true },
	-- While in the presence of...
	["^while a unique enemy is in your presence, "] = { tag = { type = "ActorCondition", actor = "enemy", var = "RareOrUnique" } },
	["^while a pinnacle atlas boss is in your presence, "] = { tag = { type = "ActorCondition", actor = "enemy", var = "PinnacleBoss" } },
}

-- List of modifier tags
local modTagList = {
	[". this effect is doubled if you have (%d+) or more maximum mana."] = function(num) return { tag = { type = "StatThreshold", stat = "Mana", threshold = num, mult = 2 } } end,
	["on enemies"] = { },
	["while active"] = { },
	["for (%d+) seconds"] = { },
	["when you hit a unique enemy"] = { tag = { type = "ActorCondition", actor = "enemy", var = "RareOrUnique" } },
	[" on critical strike"] = { tag = { type = "Condition", var = "CriticalStrike" } },
	["from critical strikes"] = { tag = { type = "Condition", var = "CriticalStrike" } },
	["with critical strikes"] = { tag = { type = "Condition", var = "CriticalStrike" } },
	["while affected by auras you cast"] = { tag = { type = "Condition", var = "AffectedByAura" } },
	["for you and nearby allies"] = { newAura = true },
	-- Multipliers
	["per power charge"] = { tag = { type = "Multiplier", var = "PowerCharge" } },
	["per frenzy charge"] = { tag = { type = "Multiplier", var = "FrenzyCharge" } },
	["per endurance charge"] = { tag = { type = "Multiplier", var = "EnduranceCharge" } },
	["per siphoning charge"] = { tag = { type = "Multiplier", var = "SiphoningCharge" } },
	["per spirit charge"] = { tag = { type = "Multiplier", var = "SpiritCharge" } },
	["per challenger charge"] = { tag = { type = "Multiplier", var = "ChallengerCharge" } },
	["per gale force"] = { tag = { type = "Multiplier", var = "GaleForce" } },
	["per intensity"] = { tag = { type = "Multiplier", var = "Intensity" } },
	["per brand"] = { tag = { type = "Multiplier", var = "ActiveBrand" } },
	["per brand, up to a maximum of (%d+)%%"] = function(num) return { tag = { type = "Multiplier", var = "ActiveBrand", limit = tonumber(num), limitTotal = true } } end,
	["per blitz charge"] = { tag = { type = "Multiplier", var = "BlitzCharge" } },
	["per ghost shroud"] = { tag = { type = "Multiplier", var = "GhostShroud" } },
	["per crab barrier"] = { tag = { type = "Multiplier", var = "CrabBarrier" } },
	["per rage"] = { tag = { type = "Multiplier", var = "Rage" } },
	["per rage while you are not losing rage"] = { tag = { type = "Multiplier", var = "Rage" } },
	["per (%d+) rage"] = function(num) return { tag = { type = "Multiplier", var = "Rage", div = num } } end,
	["per level"] = { tag = { type = "Multiplier", var = "Level" } },
	["per (%d+) player levels"] = function(num) return { tag = { type = "Multiplier", var = "Level", div = num } } end,
	["per defiance"] = { tag = { type = "Multiplier", var = "Defiance" } },
	["per (%d+)%% (%a+) effect on enemy"] = function(num, _, effectName) return { tag = { type = "Multiplier", var = firstToUpper(effectName) .. "Effect", div = num, actor = "enemy" } } end,
	["for each equipped normal item"] = { tag = { type = "Multiplier", var = "NormalItem" } },
	["for each normal item equipped"] = { tag = { type = "Multiplier", var = "NormalItem" } },
	["for each normal item you have equipped"] = { tag = { type = "Multiplier", var = "NormalItem" } },
	["for each equipped magic item"] = { tag = { type = "Multiplier", var = "MagicItem" } },
	["for each magic item equipped"] = { tag = { type = "Multiplier", var = "MagicItem" } },
	["for each magic item you have equipped"] = { tag = { type = "Multiplier", var = "MagicItem" } },
	["for each equipped rare item"] = { tag = { type = "Multiplier", var = "RareItem" } },
	["for each rare item equipped"] = { tag = { type = "Multiplier", var = "RareItem" } },
	["for each rare item you have equipped"] = { tag = { type = "Multiplier", var = "RareItem" } },
	["for each equipped unique item"] = { tag = { type = "Multiplier", var = "UniqueItem" } },
	["for each unique item equipped"] = { tag = { type = "Multiplier", var = "UniqueItem" } },
	["for each unique item you have equipped"] = { tag = { type = "Multiplier", var = "UniqueItem" } },
	["per elder item equipped"] = { tag = { type = "Multiplier", var = "ElderItem" } },
	["per shaper item equipped"] = { tag = { type = "Multiplier", var = "ShaperItem" } },
	["per elder or shaper item equipped"] = { tag = { type = "Multiplier", var = "ShaperOrElderItem" } },
	["for each corrupted item equipped"] = { tag = { type = "Multiplier", var = "CorruptedItem" } },
	["for each equipped corrupted item"] = { tag = { type = "Multiplier", var = "CorruptedItem" } },
	["for each uncorrupted item equipped"] = { tag = { type = "Multiplier", var = "NonCorruptedItem" } },
	["per equipped claw"] = { tag = { type = "Multiplier", var = "ClawItem" } },
	["per equipped dagger"] = { tag = { type = "Multiplier", var = "DaggerItem" } },
	["per equipped axe"] = { tag = { type = "Multiplier", var = "AxeItem" } },
	["per equipped ring"] = { tag = { type = "Multiplier", var = "RingItem" } },
	["per equipped flask"] = { tag = { type = "Multiplier", var = "FlaskItem" } },
	["per equipped sword"] = { tag = { type = "Multiplier", var = "SwordItem" } },
	["per equipped jewel"] = { tag = { type = "Multiplier", var = "JewelItem" } },
	["per equipped mace"] = { tag = { type = "Multiplier", var = "MaceItem" } },
	["per equipped sceptre"] = { tag = { type = "Multiplier", var = "SceptreItem" } },
	["per equipped wand"] = { tag = { type = "Multiplier", var = "WandItem" } },
	["per claw"] = { tag = { type = "Multiplier", var = "ClawItem" } },
	["per dagger"] = { tag = { type = "Multiplier", var = "DaggerItem" } },
	["per axe"] = { tag = { type = "Multiplier", var = "AxeItem" } },
	["per ring"] = { tag = { type = "Multiplier", var = "RingItem" } },
	["per flask"] = { tag = { type = "Multiplier", var = "FlaskItem" } },
	["per sword"] = { tag = { type = "Multiplier", var = "SwordItem" } },
	["per jewel"] = { tag = { type = "Multiplier", var = "JewelItem" } },
	["per mace"] = { tag = { type = "Multiplier", var = "MaceItem" } },
	["per sceptre"] = { tag = { type = "Multiplier", var = "SceptreItem" } },
	["per wand"] = { tag = { type = "Multiplier", var = "WandItem" } },
	["per abyssa?l? jewel affecting you"] = { tag = { type = "Multiplier", var = "AbyssJewel" } },
	["for each herald b?u?f?f?s?k?i?l?l? ?affecting you"] = { tag = { type = "Multiplier", var = "Herald" } },
	["for each of your aura or herald skills affecting you"] = { tag = { type = "Multiplier", varList = { "Herald", "AuraAffectingSelf" } } },
	["for each type of abyssa?l? jewel affecting you"] = { tag = { type = "Multiplier", var = "AbyssJewelType" } },
	["per (.+) eye jewel affecting you, up to a maximum of %+?(%d+)%%"] = function(type, _, num) return { tag = { type = "Multiplier", var = (type:gsub("^%l", string.upper)) .. "EyeJewel", limit = tonumber(num), limitTotal = true } } end,
	["per sextant affecting the area"] = { tag = { type = "Multiplier", var = "Sextant" } },
	["per buff on you"] = { tag = { type = "Multiplier", var = "BuffOnSelf" } },
	["per hit suppressed recently"] = { tag = { type = "Multiplier", var = "HitsSuppressedRecently" } },
	["per curse on enemy"] = { tag = { type = "Multiplier", var = "CurseOnEnemy" } },
	["for each curse on enemy"] = { tag = { type = "Multiplier", var = "CurseOnEnemy" } },
	["for each curse on the enemy"] = { tag = { type = "Multiplier", var = "CurseOnEnemy" } },
	["per curse on you"] = { tag = { type = "Multiplier", var = "CurseOnSelf" } },
	["per poison on you"] = { tag = { type = "Multiplier", var = "PoisonStack" } },
	["for each poison on you"] = { tag = { type = "Multiplier", var = "PoisonStack" } },
	["for each poison on you up to a maximum of (%d+)%%"] = function(num) return { tag = { type = "Multiplier", var = "PoisonStack", limit = tonumber(num), limitTotal = true } } end,
	["per poison on you, up to (%d+) per second"] = function(num) return { tag = { type = "Multiplier", var = "PoisonStack", limit = tonumber(num), limitTotal = true } } end,
	["for each poison you have inflicted recently"] = { tag = { type = "Multiplier", var = "PoisonAppliedRecently" } },
	["per withered debuff on enemy"] = { tag = { type = "Multiplier", var = "WitheredStack", actor = "enemy", limit = 15 } },
	["for each poison you have inflicted recently, up to a maximum of (%d+)%%"] = function(num) return { tag = { type = "Multiplier", var = "PoisonAppliedRecently", globalLimit = tonumber(num), globalLimitKey = "NoxiousStrike" } } end,
	["for each time you have shocked a non%-shocked enemy recently, up to a maximum of (%d+)%%"] = function(num) return { tag = { type = "Multiplier", var = "ShockedNonShockedEnemyRecently", limit = tonumber(num), limitTotal = true } } end,
	["for each shocked enemy you've killed recently"] = { tag = { type = "Multiplier", var = "ShockedEnemyKilledRecently" } },
	["per enemy killed recently, up to (%d+)%%"] = function(num) return { tag = { type = "Multiplier", var = "EnemyKilledRecently", limit = tonumber(num), limitTotal = true } } end,
	["per (%d+) rampage kills"] = function(num) return { tag = { type = "Multiplier", var = "Rampage", div = num, limit = 1000 / num, limitTotal = true } } end,
	["per minion, up to (%d+)%%"] = function(num) return { tag = { type = "Multiplier", var = "SummonedMinion", limit = tonumber(num), limitTotal = true } } end,
	["for each enemy you or your minions have killed recently, up to (%d+)%%"] = function(num) return { tag = { type = "Multiplier", varList = { "EnemyKilledRecently","EnemyKilledByMinionsRecently" }, limit = tonumber(num), limitTotal = true } } end,
	["for each enemy you or your minions have killed recently, up to (%d+)%% per second"] = function(num) return { tag = { type = "Multiplier", varList = { "EnemyKilledRecently","EnemyKilledByMinionsRecently" }, limit = tonumber(num), limitTotal = true } } end,
	["for each (%d+) total mana y?o?u? ?h?a?v?e? ?spent recently"] = function(num) return { tag = { type = "Multiplier", var = "ManaSpentRecently", div = num } } end,
	["for each (%d+) total mana you have spent recently, up to (%d+)%%"] = function(num, _, limit) return { tag = { type = "Multiplier", var = "ManaSpentRecently", div = num, limit = tonumber(limit), limitTotal = true } } end,
	["per (%d+) mana spent recently, up to (%d+)%%"] = function(num, _, limit) return { tag = { type = "Multiplier", var = "ManaSpentRecently", div = num, limit = tonumber(limit), limitTotal = true } } end,
	["for each time you've blocked in the past 10 seconds"] = { tag = { type = "Multiplier", var =  "BlockedPast10Sec" } },
	["per enemy killed by you or your totems recently"] = { tag = { type = "Multiplier", varList = { "EnemyKilledRecently","EnemyKilledByTotemsRecently" } } },
	["per nearby enemy, up to %+?(%d+)%%"] = function(num) return { tag = { type = "Multiplier", var = "NearbyEnemies", limit = num, limitTotal = true } } end,
	["per enemy in close range"] = { tagList = { { type = "Condition", var = "AtCloseRange" }, { type = "Multiplier", var = "NearbyEnemies" } } },
	["to you and allies"] = { },
	["per red socket"] = { tag = { type = "Multiplier", var = "RedSocketIn{SlotName}" } },
	["per green socket on main hand weapon"] = { tag = { type = "Multiplier", var = "GreenSocketInWeapon 1" } },
	["per green socket on"] = { tag = { type = "Multiplier", var = "GreenSocketInWeapon 1" } },
	["per red socket on main hand weapon"] = { tag = { type = "Multiplier", var = "RedSocketInWeapon 1" } },
	["per green socket"] = { tag = { type = "Multiplier", var = "GreenSocketIn{SlotName}" } },
	["per blue socket"] = { tag = { type = "Multiplier", var = "BlueSocketIn{SlotName}" } },
	["per white socket"] = { tag = { type = "Multiplier", var = "WhiteSocketIn{SlotName}" } },
	["for each empty red socket on any equipped item"] = { tag = { type = "Multiplier", var = "EmptyRedSocketsInAnySlot" } },
	["for each empty green socket on any equipped item"] = { tag = { type = "Multiplier", var = "EmptyGreenSocketsInAnySlot" } },
	["for each empty blue socket on any equipped item"] = { tag = { type = "Multiplier", var = "EmptyBlueSocketsInAnySlot" } },
	["for each empty white socket on any equipped item"] = { tag = { type = "Multiplier", var = "EmptyWhiteSocketsInAnySlot" } },
	["per socketed gem"] = { tag = { type = "Multiplier", var = "SocketedGemsIn{SlotName}"}},
	["for each impale on enemy"] = { tag = { type = "Multiplier", var = "ImpaleStacks", actor = "enemy" } },
	["per impale on enemy"] = { tag = { type = "Multiplier", var = "ImpaleStacks", actor = "enemy" } },
	["per animated weapon"] = { tag = { type = "Multiplier", var = "AnimatedWeapon", actor = "parent" } },
	["per grasping vine"] = { tag =  { type = "Multiplier", var = "GraspingVinesCount" } },
	["per fragile regrowth"] = { tag =  { type = "Multiplier", var = "FragileRegrowthCount" } },
	["per bark"] = { tag =  { type = "Multiplier", var = "BarkskinStacks" } },
	["per bark below maximum"] = { tag =  { type = "Multiplier", var = "MissingBarkskinStacks" } },
	["per allocated mastery passive skill"] = { tag = { type = "Multiplier", var = "AllocatedMastery" } },
	["per allocated notable passive skill"] = { tag = { type = "Multiplier", var = "AllocatedNotable" } },
	["for each different type of mastery you have allocated"] = { tag = { type = "Multiplier", var = "AllocatedMasteryType" } },
	["per grand spectrum"] = { tag = { type = "Multiplier", var = "GrandSpectrum" } },
	["per second you've been stationary, up to a maximum of (%d+)%%"] = function(num) return { tag = { type = "Multiplier", var = "StationarySeconds", limit = tonumber(num), limitTotal = true } } end,
	-- Per stat
	["per (%d+)%% of maximum mana they reserve"] = function(num) return { tag = { type = "PerStat", stat = "ManaReservedPercent", div = num } } end,
	["per (%d+) strength"] = function(num) return { tag = { type = "PerStat", stat = "Str", div = num } } end,
	["per (%d+) dexterity"] = function(num) return { tag = { type = "PerStat", stat = "Dex", div = num } } end,
	["per (%d+) intelligence"] = function(num) return { tag = { type = "PerStat", stat = "Int", div = num } } end,
	["per (%d+) omniscience"] = function(num) return { tag = { type = "PerStat", stat = "Omni", div = num } } end,
	["per (%d+) total attributes"] = function(num) return { tag = { type = "PerStat", statList = { "Str", "Dex", "Int" }, div = num } } end,
	["per (%d+) of your lowest attribute"] = function(num) return { tag = { type = "PerStat", stat = "LowestAttribute", div = num } } end,
	["per (%d+) reserved life"] = function(num) return { tag = { type = "PerStat", stat = "LifeReserved", div = num } } end,
	["per (%d+) unreserved maximum mana"] = function(num) return { tag = { type = "PerStat", stat = "ManaUnreserved", div = num } } end,
	["per (%d+) unreserved maximum mana, up to (%d+)%%"] = function(num, _, limit) return { tag = { type = "PerStat", stat = "ManaUnreserved", div = num, limit = tonumber(limit), limitTotal = true } } end,
	["per (%d+) armour"] = function(num) return { tag = { type = "PerStat", stat = "Armour", div = num } } end,
	["per (%d+) evasion rating"] = function(num) return { tag = { type = "PerStat", stat = "Evasion", div = num } } end,
	["per (%d+) evasion rating, up to (%d+)%%"] = function(num, _, limit) return { tag = { type = "PerStat", stat = "Evasion", div = num, limit = tonumber(limit), limitTotal = true } } end,
	["per (%d+) maximum energy shield"] = function(num) return { tag = { type = "PerStat", stat = "EnergyShield", div = num } } end,
	["per (%d+) maximum life"] = function(num) return { tag = { type = "PerStat", stat = "Life", div = num } } end,
	["per (%d+) of maximum life or maximum mana, whichever is lower"] = function(num) return { tag = { type = "PerStat", stat = "LowestOfMaximumLifeAndMaximumMana", div = num } } end,
	["per (%d+) player maximum life"] = function(num) return { tag = { type = "PerStat", stat = "Life", div = num, actor = "parent" } } end,
	["per (%d+) maximum mana"] = function(num) return { tag = { type = "PerStat", stat = "Mana", div = num } } end,
	["per (%d+) maximum mana, up to (%d+)%%"] = function(num, _, limit) return { tag = { type = "PerStat", stat = "Mana", div = num, limit = tonumber(limit), limitTotal = true } } end,
	["per (%d+) maximum mana, up to a maximum of (%d+)%%"] = function(num, _, limit) return { tag = { type = "PerStat", stat = "Mana", div = num, limit = tonumber(limit), limitTotal = true } } end,
	["per (%d+) accuracy rating"] = function(num) return { tag = { type = "PerStat", stat = "Accuracy", div = num } } end,
	["per (%d+)%% block chance"] = function(num) return { tag = { type = "PerStat", stat = "BlockChance", div = num } } end,
	["per (%d+)%% chance to block on equipped shield"] = function(num) return { tag = { type = "PerStat", stat = "ShieldBlockChance", div = num } } end,
	["per (%d+)%% chance to block attack damage"] = function(num) return { tag = { type = "PerStat", stat = "BlockChance", div = num } } end,
	["per (%d+)%% chance to block spell damage"] = function(num) return { tag = { type = "PerStat", stat = "SpellBlockChance", div = num } } end,
	["per (%d+) of the lowest of armour and evasion rating"] = function(num) return { tag = { type = "PerStat", stat = "LowestOfArmourAndEvasion", div = num } } end,
	["per (%d+) maximum energy shield on equipped helmet"] = function(num) return { tag = { type = "PerStat", stat = "EnergyShieldOnHelmet", div = num } } end,
	["per (%d+) maximum energy shield on helmet"] = function(num) return { tag = { type = "PerStat", stat = "EnergyShieldOnHelmet", div = num } } end,
	["per (%d+) evasion rating on body armour"] = function(num) return { tag = { type = "PerStat", stat = "EvasionOnBody Armour", div = num } } end,
	["per (%d+) evasion rating on equipped body armour"] = function(num) return { tag = { type = "PerStat", stat = "EvasionOnBody Armour", div = num } } end,
	["per (%d+) armour on equipped shield"] = function(num) return { tag = { type = "PerStat", stat = "ArmourOnWeapon 2", div = num } } end,
	["per (%d+) armour or evasion rating on shield"] = function(num) return { tag = { type = "PerStat", statList = { "ArmourOnWeapon 2", "EvasionOnWeapon 2" }, div = num } } end,
	["per (%d+) armour or evasion rating on equipped shield"] = function(num) return { tag = { type = "PerStat", statList = { "ArmourOnWeapon 2", "EvasionOnWeapon 2" }, div = num } } end,
	["per (%d+) evasion rating on equipped shield"] = function(num) return { tag = { type = "PerStat", stat = "EvasionOnWeapon 2", div = num } } end,
	["per (%d+) maximum energy shield on equipped shield"] = function(num) return { tag = { type = "PerStat", stat = "EnergyShieldOnWeapon 2", div = num } } end,
	["per (%d+) maximum energy shield on shield"] = function(num) return { tag = { type = "PerStat", stat = "EnergyShieldOnWeapon 2", div = num } } end,
	["per (%d+) evasion on equipped boots"] = function(num) return { tag = { type = "PerStat", stat = "EvasionOnBoots", div = num } } end,
	["per (%d+) evasion on boots"] = function(num) return { tag = { type = "PerStat", stat = "EvasionOnBoots", div = num } } end,
	["per (%d+) armour on equipped gloves"] = function(num) return { tag = { type = "PerStat", stat = "ArmourOnGloves", div = num } } end,
	["per (%d+) armour on gloves"] = function(num) return { tag = { type = "PerStat", stat = "ArmourOnGloves", div = num } } end,
	["per (%d+)%% chaos resistance"] = function(num) return { tag = { type = "PerStat", stat = "ChaosResist", div = num } } end,
	["per (%d+)%% cold resistance above 75%%"] = function(num) return { tag  = { type = "PerStat", stat = "ColdResistOver75", div = num } } end,
	["per (%d+)%% lightning resistance above 75%%"] = function(num) return { tag  = { type = "PerStat", stat = "LightningResistOver75", div = num } } end,
	["per (%d+) devotion"] = function(num) return { tag = { type = "PerStat", stat = "Devotion", actor = "parent", div = num } } end,
	["per (%d+)%% missing fire resistance, up to a maximum of (%d+)%%"] = function(num, _, limit) return { tag = { type = "PerStat", stat = "MissingFireResist", div = num, globalLimit = tonumber(limit), globalLimitKey = "ReplicaNebulisFire" } } end,
	["per (%d+)%% missing cold resistance, up to a maximum of (%d+)%%"] = function(num, _, limit) return { tag = { type = "PerStat", stat = "MissingColdResist", div = num, globalLimit = tonumber(limit), globalLimitKey = "ReplicaNebulisCold" } } end,
	["per endurance, frenzy or power charge"] = { tag = { type = "PerStat", stat = "TotalCharges" } },
	["per fortification"] = { tag = { type = "PerStat", stat = "FortificationStacks" } },
	["per totem"] = { tag = { type = "PerStat", stat = "TotemsSummoned" } },
	["per summoned totem"] = { tag = { type = "PerStat", stat = "TotemsSummoned" } },
	["for each summoned totem"] =  { tag = { type = "PerStat", stat = "TotemsSummoned" } },
	["for each time they have chained"] = { tag = { type = "PerStat", stat = "Chain" } },
	["for each time it has chained"] = { tag = { type = "PerStat", stat = "Chain" } },
	["for each summoned golem"] = { tag = { type = "PerStat", stat = "ActiveGolemLimit" } },
	["for each golem you have summoned"] = { tag = { type = "PerStat", stat = "ActiveGolemLimit" } },
	["per summoned golem"] = { tag = { type = "PerStat", stat = "ActiveGolemLimit" } },
	["per summoned sentinel of purity"] = { tag = { type = "PerStat", stat = "ActiveSentinelOfPurityLimit" } },
	["per summoned skeleton"] = { tag = { type = "PerStat", stat = "ActiveSkeletonLimit" } },
	["per skeleton you own"] = { tag = { type = "PerStat", stat = "ActiveSkeletonLimit", actor = "parent" } },
	["per summoned raging spirit"] = { tag = { type = "PerStat", stat = "ActiveRagingSpiritLimit" } },
	["for each raised zombie"] = { tag = { type = "PerStat", stat = "ActiveZombieLimit" } },
	["per zombie you own"] = { tag = { type = "PerStat", stat = "ActiveZombieLimit", actor = "parent" } },
	["per raised zombie"] = { tag = { type = "PerStat", stat = "ActiveZombieLimit" } },
	["per raised spectre"] = { tag = { type = "PerStat", stat = "ActiveSpectreLimit" } },
	["per spectre you own"] = { tag = { type = "PerStat", stat = "ActiveSpectreLimit", actor = "parent" } },
	["for each remaining chain"] = { tag = { type = "PerStat", stat = "ChainRemaining" } },
	["for each enemy pierced"] = { tag = { type = "PerStat", stat = "PiercedCount" } },
	["for each time they've pierced"] = { tag = { type = "PerStat", stat = "PiercedCount" } },
	-- Stat conditions
	["with (%d+) or more strength"] = function(num) return { tag = { type = "StatThreshold", stat = "Str", threshold = num } } end,
	["with at least (%d+) strength"] = function(num) return { tag = { type = "StatThreshold", stat = "Str", threshold = num } } end,
	["w?h?i[lf]e? you have at least (%d+) strength"] = function(num) return { tag = { type = "StatThreshold", stat = "Str", threshold = num } } end,
	["w?h?i[lf]e? you have at least (%d+) dexterity"] = function(num) return { tag = { type = "StatThreshold", stat = "Dex", threshold = num } } end,
	["w?h?i[lf]e? you have at least (%d+) intelligence"] = function(num) return { tag = { type = "StatThreshold", stat = "Int", threshold = num } } end,
	["w?h?i[lf]e? strength is below (%d+)"] = function(num) return { tag = { type = "StatThreshold", stat = "Str", threshold = num - 1, upper = true } } end,
	["w?h?i[lf]e? dexterity is below (%d+)"] = function(num) return { tag = { type = "StatThreshold", stat = "Dex", threshold = num - 1, upper = true } } end,
	["w?h?i[lf]e? intelligence is below (%d+)"] = function(num) return { tag = { type = "StatThreshold", stat = "Int", threshold = num - 1, upper = true } } end,
	["at least (%d+) intelligence"] = function(num) return { tag = { type = "StatThreshold", stat = "Int", threshold = num } } end,
	["if dexterity is higher than intelligence"] = { tag = { type = "Condition", var = "DexHigherThanInt" } },
	["if strength is higher than intelligence"] = { tag = { type = "Condition", var = "StrHigherThanInt" } },
	["w?h?i[lf]e? you have at least (%d+) maximum energy shield"] = function(num) return { tag = { type = "StatThreshold", stat = "EnergyShield", threshold = num } } end,
	["against targets they pierce"] = { tag = { type = "StatThreshold", stat = "PierceCount", threshold = 1 } },
	["against pierced targets"] = { tag = { type = "StatThreshold", stat = "PierceCount", threshold = 1 } },
	["to targets they pierce"] = { tag = { type = "StatThreshold", stat = "PierceCount", threshold = 1 } },
	["w?h?i[lf]e? you have at least (%d+) devotion"] = function(num) return { tag = { type = "StatThreshold", stat = "Devotion", threshold = num } } end,
	["while you have at least (%d+) rage"] = function(num) return { tag = { type = "MultiplierThreshold", var = "Rage", threshold = num } } end,
	["while affected by a unique abyss jewel"] = { tag = { type = "MultiplierThreshold", var = "UniqueAbyssJewels", threshold = 1 } },
	["while affected by a rare abyss jewel"] = { tag = { type = "MultiplierThreshold", var = "RareAbyssJewels", threshold = 1 } },
	["while affected by a magic abyss jewel"] =  { tag = { type = "MultiplierThreshold", var = "MagicAbyssJewels", threshold = 1 } },
	["while affected by a normal abyss jewel"] = { tag = { type = "MultiplierThreshold", var = "NormalAbyssJewels", threshold = 1 } },
	-- Slot conditions
	["when in main hand"] = { tag = { type = "SlotNumber", num = 1 } },
	["when in off hand"] = { tag = { type = "SlotNumber", num = 2 } },
	["in main hand"] = { tag = { type = "InSlot", num = 1 } },
	["in off hand"] = { tag = { type = "InSlot", num = 2 } },
	["w?i?t?h? main hand"] = { tagList = { { type = "Condition", var = "MainHandAttack" }, { type = "SkillType", skillType = SkillType.Attack } } },
	["w?i?t?h? off hand"] = { tagList = { { type = "Condition", var = "OffHandAttack" }, { type = "SkillType", skillType = SkillType.Attack } } },
	["[fi]?[rn]?[of]?[ml]?[ i]?[hc]?[it]?[te]?[sd]? ? with this weapon"] = { tagList = { { type = "Condition", var = "{Hand}Attack" }, { type = "SkillType", skillType = SkillType.Attack } } },
	["if your other ring is a shaper item"] = { tag = { type = "ItemCondition", itemSlot = "Ring {OtherSlotNum}", shaperCond = true} },
	["if your other ring is an elder item"] = { tag = { type = "ItemCondition", itemSlot = "Ring {OtherSlotNum}", elderCond = true}},
	["if you have a (%a+) (%a+) in (%a+) slot"] = function(_, rarity, item, slot) return { tag = { type = "Condition", var = rarity:gsub("^%l", string.upper).."ItemIn"..item:gsub("^%l", string.upper).." "..(slot == "right" and 2 or slot == "left" and 1) } } end,
	["of skills supported by spellslinger"] = { tag = { type = "Condition", var = "SupportedBySpellslinger" } },
	-- Equipment conditions
	["while holding a (%w+)"] = function (_, gear) return {
		tag = { type = "Condition", varList = { "Using"..firstToUpper(gear) } }
	} end,
	["while holding a (%w+) or (%w+)"] = function (_, g1, g2) return {
		tag = { type = "Condition", varList = { "Using"..firstToUpper(g1), "Using"..firstToUpper(g2) } }
	} end,
	["while your off hand is empty"] = { tag = { type = "Condition", var = "OffHandIsEmpty" } },
	["with shields"] = { tag = { type = "Condition", var = "UsingShield" } },
	["while dual wielding"] = { tag = { type = "Condition", var = "DualWielding" } },
	["while dual wielding claws"] = { tag = { type = "Condition", var = "DualWieldingClaws" } },
	["while dual wielding or holding a shield"] = { tag = { type = "Condition", varList = { "DualWielding", "UsingShield" } } },
	["while wielding an axe"] = { tag = { type = "Condition", var = "UsingAxe" } },
	["while wielding an axe or sword"] = { tag = { type = "Condition", varList = { "UsingAxe", "UsingSword" } } },
	["while wielding a bow"] = { tag = { type = "Condition", var = "UsingBow" } },
	["while wielding a claw"] = { tag = { type = "Condition", var = "UsingClaw" } },
	["while wielding a dagger"] = { tag = { type = "Condition", var = "UsingDagger" } },
	["while wielding a claw or dagger"] = { tag = { type = "Condition", varList = { "UsingClaw", "UsingDagger" } } },
	["while wielding a mace"] = { tag = { type = "Condition", var = "UsingMace" } },
	["while wielding a mace or sceptre"] = { tag = { type = "Condition", var = "UsingMace" } },
	["while wielding a mace, sceptre or staff"] = { tag = { type = "Condition", varList = { "UsingMace", "UsingStaff" } } },
	["while wielding a staff"] = { tag = { type = "Condition", var = "UsingStaff" } },
	["while wielding a sword"] = { tag = { type = "Condition", var = "UsingSword" } },
	["while wielding a melee weapon"] = { tag = { type = "Condition", var = "UsingMeleeWeapon" } },
	["while wielding a one handed weapon"] = { tag = { type = "Condition", var = "UsingOneHandedWeapon" } },
	["while wielding a two handed weapon"] = { tag = { type = "Condition", var = "UsingTwoHandedWeapon" } },
	["while wielding a two handed melee weapon"] = { tagList = { { type = "Condition", var = "UsingTwoHandedWeapon" }, { type = "Condition", var = "UsingMeleeWeapon" } } },
	["while wielding a wand"] = { tag = { type = "Condition", var = "UsingWand" } },
	["while wielding two different weapon types"] = { tag = { type = "Condition", var = "WieldingDifferentWeaponTypes" } },
	["while unarmed"] = { tag = { type = "Condition", var = "Unarmed" } },
	["while you are unencumbered"] = { tag = { type = "Condition", var = "Unencumbered" } },
	["equipped bow"] = { tag = { type = "Condition", var = "UsingBow" } },
	["if equipped ([%a%s]+) has an ([%a%s]+) modifier"] = function (_, itemSlotName, conditionSubstring) return { tag = { type = "ItemCondition", searchCond = conditionSubstring, itemSlot = itemSlotName } } end,
	["if both equipped ([%a%s]+) have a?n? ?([%a%s]+) modifiers?"] = function (_, itemSlotName, conditionSubstring) return { tag = { type = "ItemCondition", searchCond = conditionSubstring, itemSlot = itemSlotName:sub(1, #itemSlotName - 1), bothSlots = true } } end,
	["if there are no ([%a%s]+) modifiers on equipped ([%a%s]+)"] = function (_, conditionSubstring, itemSlotName) return { tag = { type = "ItemCondition", searchCond = conditionSubstring, itemSlot = itemSlotName, neg = true } } end,
	["if there are no (%a+) modifiers on other equipped items"] = function(_, conditionSubstring) return {tag = { type = "ItemCondition", searchCond = conditionSubstring, itemSlot = "{SlotName}", allSlots = true, excludeSelf = true, neg = true }} end,
	["if corrupted"] = {tag = { type = "ItemCondition", itemSlot = "{SlotName}", corruptedCond = true}},
	["with a normal item equipped"] = { tag = { type = "MultiplierThreshold", var = "NormalItem", threshold = 1 } },
	["with a magic item equipped"] = { tag = { type = "MultiplierThreshold", var = "MagicItem", threshold = 1 } },
	["with a rare item equipped"] = { tag = { type = "MultiplierThreshold", var = "RareItem", threshold = 1 } },
	["with a unique item equipped"] = { tag = { type = "MultiplierThreshold", var = "UniqueItem", threshold = 1 } },
	["if you wear no corrupted items"] = { tag = { type = "MultiplierThreshold", var = "CorruptedItem", threshold = 0, upper = true } },
	["if no worn items are corrupted"] = { tag = { type = "MultiplierThreshold", var = "CorruptedItem", threshold = 0, upper = true } },
	["if no equipped items are corrupted"] = { tag = { type = "MultiplierThreshold", var = "CorruptedItem", threshold = 0, upper = true } },
	["if all worn items are corrupted"] = { tag = { type = "MultiplierThreshold", var = "NonCorruptedItem", threshold = 0, upper = true } },
	["if all equipped items are corrupted"] = { tag = { type = "MultiplierThreshold", var = "NonCorruptedItem", threshold = 0, upper = true } },
	["if equipped shield has at least (%d+)%% chance to block"] = function(num) return { tag = { type = "StatThreshold", stat = "ShieldBlockChance", threshold = num } } end,
	["if you have (%d+) primordial items socketed or equipped"] = function(num) return { tag = { type = "MultiplierThreshold", var = "PrimordialItem", threshold = num } } end,
	["if equipped helmet, body armour, gloves, and boots all have armour"] = { tagList = {
		{ type = "StatThreshold", stat = "ArmourOnHelmet", threshold = 1},
		{ type = "StatThreshold", stat = "ArmourOnBody Armour", threshold = 1},
		{ type = "StatThreshold", stat = "ArmourOnGloves", threshold = 1},
		{ type = "StatThreshold", stat = "ArmourOnBoots", threshold = 1} } },
	["if equipped helmet, body armour, gloves, and boots all have evasion rating"] = { tagList = {
		{ type = "StatThreshold", stat = "EvasionOnHelmet", threshold = 1},
		{ type = "StatThreshold", stat = "EvasionOnBody Armour", threshold = 1},
		{ type = "StatThreshold", stat = "EvasionOnGloves", threshold = 1},
		{ type = "StatThreshold", stat = "EvasionOnBoots", threshold = 1} } },
	-- Player status conditions
	["wh[ie][ln]e? on low life"] = { tag = { type = "Condition", var = "LowLife" } },
	["on reaching low life"] = { tag = { type = "Condition", var = "LowLife" } },
	["wh[ie][ln]e? not on low life"] = { tag = { type = "Condition", var = "LowLife", neg = true } },
	["wh[ie][ln]e? on low mana"] = { tag = { type = "Condition", var = "LowMana" } },
	["wh[ie][ln]e? not on low mana"] = { tag = { type = "Condition", var = "LowMana", neg = true } },
	["wh[ie][ln]e? on full life"] = { tag = { type = "Condition", var = "FullLife" } },
	["wh[ie][ln]e? not on full life"] = { tag = { type = "Condition", var = "FullLife", neg = true } },
	["wh[ie][ln]e? no life is reserved"] = { tag = { type = "StatThreshold", stat = "LifeReserved", threshold = 0, upper = true } },
	["wh[ie][ln]e? no mana is reserved"] = { tag = { type = "StatThreshold", stat = "ManaReserved", threshold = 0, upper = true } },
	["wh[ie][ln]e? on full energy shield"] = { tag = { type = "Condition", var = "FullEnergyShield" } },
	["wh[ie][ln]e? not on full energy shield"] = { tag = { type = "Condition", var = "FullEnergyShield", neg = true } },
	["wh[ie][ln]e? you have energy shield"] = { tag = { type = "Condition", var = "HaveEnergyShield" } },
	["wh[ie][ln]e? you have no energy shield"] = { tag = { type = "Condition", var = "HaveEnergyShield", neg = true } },
	["if you have energy shield"] = { tag = { type = "Condition", var = "HaveEnergyShield" } },
	["while stationary"] = { tag = { type = "Condition", var = "Stationary" } },
	["while you are stationary"] = { tag = { type = "ActorCondition", actor = "player", var = "Stationary" }},
	["while moving"] = { tag = { type = "Condition", var = "Moving" } },
	["while channelling"] = { tag = { type = "Condition", var = "Channelling" } },
	["while channelling snipe"] = { tag = { type = "Condition", var = "Channelling" } },
	["after channelling for (%d+) seconds?"] = function(num) return { tag = { type = "MultiplierThreshold", var = "ChannellingTime", threshold = num } } end,
	["if you've been channelling for at least (%d+) seconds?"] = function(num) return { tag = { type = "MultiplierThreshold", var = "ChannellingTime", threshold = num } } end,
	["if you've inflicted exposure recently"] = { tag = { type = "Condition", var = "AppliedExposureRecently" } },
	["while you have no power charges"] = { tag = { type = "StatThreshold", stat = "PowerCharges", threshold = 0, upper = true } },
	["while you have no frenzy charges"] = { tag = { type = "StatThreshold", stat = "FrenzyCharges", threshold = 0, upper = true } },
	["while you have no endurance charges"] = { tag = { type = "StatThreshold", stat = "EnduranceCharges", threshold = 0, upper = true } },
	["while you have a power charge"] = { tag = { type = "StatThreshold", stat = "PowerCharges", threshold = 1 } },
	["while you have a frenzy charge"] = { tag = { type = "StatThreshold", stat = "FrenzyCharges", threshold = 1 } },
	["while you have an endurance charge"] = { tag = { type = "StatThreshold", stat = "EnduranceCharges", threshold = 1 } },
	["while at maximum power charges"] = { tag = { type = "StatThreshold", stat = "PowerCharges", thresholdStat = "PowerChargesMax" } },
	["while at maximum frenzy charges"] = { tag = { type = "StatThreshold", stat = "FrenzyCharges", thresholdStat = "FrenzyChargesMax" } },
	["while on full frenzy charges"] = { tag = { type = "StatThreshold", stat = "FrenzyCharges", thresholdStat = "FrenzyChargesMax" } },
	["while at maximum endurance charges"] = { tag = { type = "StatThreshold", stat = "EnduranceCharges", thresholdStat = "EnduranceChargesMax" } },
	["while at maximum fortification"] = { tag = { type = "Condition", var = "HaveMaximumFortification" } },
	["while you have at least (%d+) crab barriers"] = function(num) return { tag = { type = "StatThreshold", stat = "CrabBarriers", threshold = num } } end,
	["while you have at least (%d+) fortification"] = function(num) return { tag = { type = "StatThreshold", stat = "FortificationStacks", threshold = num } } end,
	["while you have at least (%d+) total endurance, frenzy and power charges"] = function(num) return { tag = { type = "MultiplierThreshold", var = "TotalCharges", threshold = num } } end,
	["while you have a totem"] = { tag = { type = "Condition", var = "HaveTotem" } },
	["while you have at least one nearby ally"] = { tag = { type = "MultiplierThreshold", var = "NearbyAlly", threshold = 1 } },
	["while you have fortify"] = { tag = { type = "Condition", var = "Fortified" } },
	["while you have phasing"] = { tag = { type = "Condition", var = "Phasing" } },
	["if you[' ]h?a?ve suppressed spell damage recently"] = { tag = { type = "Condition", var = "SuppressedRecently" } },
	["while you have elusive"] = { tag = { type = "Condition", var = "Elusive" } },
	["while physical aegis is depleted"] = { tag = { type = "Condition", var = "PhysicalAegisDepleted" } },
	["during onslaught"] = { tag = { type = "Condition", var = "Onslaught" } },
	["while you have onslaught"] = { tag = { type = "Condition", var = "Onslaught" } },
	["while phasing"] = { tag = { type = "Condition", var = "Phasing" } },
	["while you have tailwind"] = { tag = { type = "Condition", var = "Tailwind" } },
	["while elusive"] = { tag = { type = "Condition", var = "Elusive" } },
	["gain elusive"] = { tag = { type = "Condition", varList = { "CanBeElusive", "Elusive" } } },
	["while you have arcane surge"] = { tag = { type = "Condition", var = "AffectedByArcaneSurge" } },
	["while you have cat's stealth"] = { tag = { type = "Condition", var = "AffectedByCat'sStealth" } },
	["while you have cat's agility"] = { tag = { type = "Condition", var = "AffectedByCat'sAgility" } },
	["while you have avian's might"] = { tag = { type = "Condition", var = "AffectedByAvian'sMight" } },
	["while you have avian's flight"] = { tag = { type = "Condition", var = "AffectedByAvian'sFlight" } },
	["while affected by aspect of the cat"] = { tag = { type = "Condition", varList = { "AffectedByCat'sStealth", "AffectedByCat'sAgility" } } },
	["while affected by a non%-vaal guard skill"] = { tag = { type = "Condition", var =  "AffectedByNonVaalGuardSkill" } },
	["if a non%-vaal guard buff was lost recently"] = { tag = { type = "Condition", var = "LostNonVaalBuffRecently" } },
	["while affected by a guard skill buff"] = { tag = { type = "Condition", var = "AffectedByGuardSkill" } },
	["while affected by a herald"] = { tag = { type = "Condition", var = "AffectedByHerald" } },
	["while fortified"] = { tag = { type = "Condition", var = "Fortified" } },
	["while in blood stance"] = { tag = { type = "Condition", var = "BloodStance" } },
	["while in sand stance"] = { tag = { type = "Condition", var = "SandStance" } },
	["while you have a bestial minion"] = { tag = { type = "Condition", var = "HaveBestialMinion" } },
	["while you have infusion"] = { tag = { type = "Condition", var = "InfusionActive" } },
	["while focus?sed"] = { tag = { type = "Condition", var = "Focused" } },
	["while leeching"] = { tag = { type = "Condition", var = "Leeching" } },
	["while leeching energy shield"] = { tag = { type = "Condition", var = "LeechingEnergyShield" } },
	["while leeching mana"] = { tag = { type = "Condition", var = "LeechingMana" } },
	["while using a flask"] = { tag = { type = "Condition", var = "UsingFlask" } },
	["during effect"] = { tag = { type = "Condition", var = "UsingFlask" } },
	["during flask effect"] = { tag = { type = "Condition", var = "UsingFlask" } },
	["during any flask effect"] = { tag = { type = "Condition", var = "UsingFlask" } },
	["while under no flask effects"] = { tag = { type = "Condition", var = "UsingFlask", neg = true } },
	["during effect of any mana flask"] = { tag = { type = "Condition", var = "UsingManaFlask" } },
	["during effect of any life flask"] = { tag = { type = "Condition", var = "UsingLifeFlask" } },
	["if you've used a life flask in the past 10 seconds"] = { tag = { type = "Condition", var = "UsingLifeFlask" } },
	["if you've used a mana flask in the past 10 seconds"] = { tag = { type = "Condition", var = "UsingManaFlask" } },
	["during effect of any life or mana flask"] = { tag = { type = "Condition", varList = { "UsingManaFlask", "UsingLifeFlask" } } },
	["while on consecrated ground"] = { tag = { type = "Condition", var = "OnConsecratedGround" } },
	["while on caustic ground"] = { tag = { type = "Condition", var = "OnCausticGround" } },
	["when you create consecrated ground"] = { },
	["on burning ground"] = { tag = { type = "Condition", var = "OnBurningGround" } },
	["while on burning ground"] = { tag = { type = "Condition", var = "OnBurningGround" } },
	["on chilled ground"] = { tag = { type = "Condition", var = "OnChilledGround" } },
	["on shocked ground"] = { tag = { type = "Condition", var = "OnShockedGround" } },
	["while in a caustic cloud"] = { tag = { type = "Condition", var = "OnCausticCloud" } },
	["while blinded"] = { tagList = { { type = "Condition", var = "Blinded" }, { type = "Condition", var = "CannotBeBlinded", neg = true } } },
	["while burning"] = { tag = { type = "Condition", var = "Burning" } },
	["while ignited"] = { tag = { type = "Condition", var = "Ignited" } },
	["while you are ignited"] = { tag = { type = "Condition", var = "Ignited" } },
	["while chilled"] = { tag = { type = "Condition", var = "Chilled" } },
	["while you are chilled"] = { tag = { type = "Condition", var = "Chilled" } },
	["while frozen"] = { tag = { type = "Condition", var = "Frozen" } },
	["while shocked"] = { tag = { type = "Condition", var = "Shocked" } },
	["while you are shocked"] = { tag = { type = "Condition", var = "Shocked" } },
	["while you are bleeding"] = { tag = { type = "Condition", var = "Bleeding" } },
	["while not ignited, frozen or shocked"] = { tag = { type = "Condition", varList = { "Ignited", "Frozen", "Shocked" }, neg = true } },
	["while bleeding"] = { tag = { type = "Condition", var = "Bleeding" } },
	["while poisoned"] = { tag = { type = "Condition", var = "Poisoned" } },
	["while you are poisoned"] = { tag = { type = "Condition", var = "Poisoned" } },
	["while cursed"] = { tag = { type = "Condition", var = "Cursed" } },
	["while not cursed"] = { tag = { type = "Condition", var = "Cursed", neg = true } },
	["while there is only one nearby enemy"] = { tagList = { { type = "Multiplier", var = "NearbyEnemies", limit = 1 }, { type = "Condition", var = "OnlyOneNearbyEnemy" } } },
	["while t?h?e?r?e? ?i?s? ?a rare or unique enemy i?s? ?nearby"] = { tag = { type = "ActorCondition", actor = "enemy", varList = { "NearbyRareOrUniqueEnemy", "RareOrUnique" } } },
	["if you[' ]h?a?ve hit recently"] = { tag = { type = "Condition", var = "HitRecently" } },
	["if you[' ]h?a?ve hit an enemy recently"] = { tag = { type = "Condition", var = "HitRecently" } },
	["if you[' ]h?a?ve hit with your main hand weapon recently"] = { tag = { type = "Condition", var = "HitRecentlyWithWeapon" } },
	["if you[' ]h?a?ve hit with your off hand weapon recently"] = { tagList = { { type = "Condition", var = "HitRecentlyWithWeapon" }, { type = "Condition", var = "DualWielding" } } },
	["if you[' ]h?a?ve hit a cursed enemy recently"] = { tagList = { { type = "Condition", var = "HitRecently" }, { type = "ActorCondition", actor = "enemy", var = "Cursed" } } },
	["when you or your totems hit an enemy with a spell"] = { tag = { type = "Condition", varList = { "HitSpellRecently","TotemsHitSpellRecently" } }, },
	["on hit with spells"] = { tag = { type = "Condition", var = "HitSpellRecently" } },
	["if you[' ]h?a?ve crit recently"] = { tag = { type = "Condition", var = "CritRecently" } },
	["if you[' ]h?a?ve dealt a critical strike recently"] = { tag = { type = "Condition", var = "CritRecently" } },
	["when you deal a critical strike"] = { tag = { type = "Condition", var = "CritRecently" } },
	["if you[' ]h?a?ve dealt a critical strike with this weapon recently"] = { tag = { type = "Condition", var = "CritRecently" } }, -- Replica Kongor's
	["if you[' ]h?a?ve crit in the past 8 seconds"] = { tag = { type = "Condition", var = "CritInPast8Sec" } },
	["if you[' ]h?a?ve dealt a crit in the past 8 seconds"] = { tag = { type = "Condition", var = "CritInPast8Sec" } },
	["if you[' ]h?a?ve dealt a critical strike in the past 8 seconds"] = { tag = { type = "Condition", var = "CritInPast8Sec" } },
	["if you haven't crit recently"] = { tag = { type = "Condition", var = "CritRecently", neg = true } },
	["if you haven't dealt a critical strike recently"] = { tag = { type = "Condition", var = "CritRecently", neg = true } },
	["if you[' ]h?a?ve dealt a non%-critical strike recently"] = { tag = { type = "Condition", var = "NonCritRecently" } },
	["if your skills have dealt a critical strike recently"] = { tag = { type = "Condition", var = "SkillCritRecently" } },
	["if you dealt a critical strike with a herald skill recently"] = { tag = { type = "Condition", var = "CritWithHeraldSkillRecently" } },
	["if you[' ]h?a?ve dealt a critical strike with a two handed melee weapon recently"] = { flags = bor(ModFlag.Weapon2H, ModFlag.WeaponMelee), tag = { type = "Condition", var = "CritRecently" } },
	["if you[' ]h?a?ve killed recently"] = { tag = { type = "Condition", var = "KilledRecently" } },
	["on killing taunted enemies"] = { tag = { type = "Condition", var = "KilledTauntedEnemyRecently" } },
	["on kill"] = { tag = { type = "Condition", var = "KilledRecently" } },
	["on melee kill"] = { flags = ModFlag.WeaponMelee, tag = { type = "Condition", var = "KilledRecently" } },
	["when you kill an enemy"] = { tag = { type = "Condition", var = "KilledRecently" } },
	["if you[' ]h?a?ve killed an enemy recently"] = { tag = { type = "Condition", var = "KilledRecently" } },
	["if you[' ]h?a?ve killed at least (%d) enemies recently"] = function(num) return { tag = { type = "MultiplierThreshold", var = "EnemyKilledRecently", threshold = num } } end,
	["if you haven't killed recently"] = { tag = { type = "Condition", var = "KilledRecently", neg = true } },
	["if you or your totems have killed recently"] = { tag = { type = "Condition", varList = { "KilledRecently","TotemsKilledRecently" } } },
	["if you[' ]h?a?ve thrown a trap or mine recently"] = { tag = { type = "Condition", var = "TrapOrMineThrownRecently" } },
	["on throwing a trap"] = { tag = { type = "Condition", var = "TrapOrMineThrownRecently" } },
	["if you[' ]h?a?ve killed a maimed enemy recently"] = { tagList = { { type = "Condition", var = "KilledRecently" }, { type = "ActorCondition", actor = "enemy", var = "Maimed" } } },
	["if you[' ]h?a?ve killed a cursed enemy recently"] = { tagList = { { type = "Condition", var = "KilledRecently" }, { type = "ActorCondition", actor = "enemy", var = "Cursed" } } },
	["if you[' ]h?a?ve killed a bleeding enemy recently"] = { tagList = { { type = "Condition", var = "KilledRecently" }, { type = "ActorCondition", actor = "enemy", var = "Bleeding" } } },
	["if you[' ]h?a?ve killed an enemy affected by your damage over time recently"] = { tag = { type = "Condition", var = "KilledAffectedByDotRecently" } },
	["if you[' ]h?a?ve frozen an enemy recently"] = { tag = { type = "Condition", var = "FrozenEnemyRecently" } },
	["if you[' ]h?a?ve chilled an enemy recently"] = { tag = { type = "Condition", var = "ChilledEnemyRecently" } },
	["if you[' ]h?a?ve ignited an enemy recently"] = { tag = { type = "Condition", var = "IgnitedEnemyRecently" } },
	["if you[' ]h?a?ve shocked an enemy recently"] = { tag = { type = "Condition", var = "ShockedEnemyRecently" } },
	["if you[' ]h?a?ve stunned an enemy recently"] = { tag = { type = "Condition", var = "StunnedEnemyRecently" } },
	["if you[' ]h?a?ve stunned an enemy with a two handed melee weapon recently"] = { flags = bor(ModFlag.Weapon2H, ModFlag.WeaponMelee), tag = { type = "Condition", var = "StunnedEnemyRecently" } },
	["if you[' ]h?a?ve been hit recently"] = { tag = { type = "Condition", var = "BeenHitRecently" } },
	["if you[' ]h?a?ve been hit by an attack recently"] = { tag = { type = "Condition", var = "BeenHitByAttackRecently" } },
	["if you were hit recently"] = { tag = { type = "Condition", var = "BeenHitRecently" } },
	["if you were damaged by a hit recently"] = { tag = { type = "Condition", var = "BeenHitRecently" } },
	["if you[' ]h?a?ve taken a critical strike recently"] = { tag = { type = "Condition", var = "BeenCritRecently" } },
	["if you[' ]h?a?ve taken a savage hit recently"] = { tag = { type = "Condition", var = "BeenSavageHitRecently" } },
	["if you have ?n[o']t been hit recently"] = { tag = { type = "Condition", var = "BeenHitRecently", neg = true } },
	["if you have ?n[o']t been hit by an attack recently"] = { tag = { type = "Condition", var = "BeenHitByAttackRecently", neg = true } },
	["if you[' ]h?a?ve taken no damage from hits recently"] = { tag = { type = "Condition", var = "BeenHitRecently", neg = true } },
	["if you[' ]h?a?ve taken fire damage from a hit recently"] = { tag = { type = "Condition", var = "HitByFireDamageRecently" } },
	["if you[' ]h?a?ve taken fire damage from an enemy hit recently"] = { tag = { type = "Condition", var = "TakenFireDamageFromEnemyHitRecently" } },
	["if you[' ]h?a?ve taken spell damage recently"] = { tag = { type = "Condition", var = "HitBySpellDamageRecently" } },
	["if you haven't taken damage recently"] = { tag = { type = "Condition", var = "BeenHitRecently", neg = true } },
	["if you[' ]h?a?ve blocked recently"] = { tag = { type = "Condition", var = "BlockedRecently" } },
	["if you haven't blocked recently"] = { tag = { type = "Condition", var = "BlockedRecently", neg = true } },
	["if you[' ]h?a?ve blocked an attack recently"] = { tag = { type = "Condition", var = "BlockedAttackRecently" } },
	["if you[' ]h?a?ve blocked attack damage recently"] = { tag = { type = "Condition", var = "BlockedAttackRecently" } },
	["if you[' ]h?a?ve blocked a spell recently"] = { tag = { type = "Condition", var = "BlockedSpellRecently" } },
	["if you[' ]h?a?ve blocked spell damage recently"] = { tag = { type = "Condition", var = "BlockedSpellRecently" } },
	["if you[' ]h?a?ve blocked damage from a unique enemy in the past 10 seconds"] = { tag = { type = "Condition", var = "BlockedHitFromUniqueEnemyInPast10Sec" } },
	["if you[' ]h?a?ve attacked recently"] = { tag = { type = "Condition", var = "AttackedRecently" } },
	["if you[' ]h?a?ve cast a spell recently"] = { tag = { type = "Condition", var = "CastSpellRecently" } },
	["if you[' ]h?a?ve been stunned while casting recently"] = { tag = { type = "Condition", var = "StunnedWhileCastingRecently" } },
	["if you[' ]h?a?ve consumed a corpse recently"] = { tag = { type = "Condition", var = "ConsumedCorpseRecently" } },
	["if you[' ]h?a?ve cursed an enemy recently"] = { tag = { type = "Condition", var = "CursedEnemyRecently" } },
	["if you[' ]h?a?ve cast a mark spell recently"] = { tag = { type = "Condition", var = "CastMarkRecently" } },
	["if you have ?n[o']t consumed a corpse recently"] = { tag = { type = "Condition", var = "ConsumedCorpseRecently", neg = true } },
	["for each corpse consumed recently"] = { tag = { type = "Multiplier", var = "CorpseConsumedRecently" } },
	["if you[' ]h?a?ve taunted an enemy recently"] = { tag = { type = "Condition", var = "TauntedEnemyRecently" } },
	["if you[' ]h?a?ve used a skill recently"] = { tag = { type = "Condition", var = "UsedSkillRecently" } },
	["if you[' ]h?a?ve used a travel skill recently"] = { tag = { type = "Condition", var = "UsedTravelSkillRecently" } },
	["for each skill you've used recently, up to (%d+)%%"] = function(num) return { tag = { type = "Multiplier", var = "SkillUsedRecently", limit = num, limitTotal = true } } end,
	["for each different non%-instant spell you[' ]h?a?ve cast recently"] = { tag = { type = "Multiplier", var = "NonInstantSpellCastRecently" } },
	["if you[' ]h?a?ve used a warcry recently"] = { tag = { type = "Condition", var = "UsedWarcryRecently" } },
	["when you warcry"] = { tag = { type = "Condition", var = "UsedWarcryRecently" } },
	["if you[' ]h?a?ve warcried recently"] = { tag = { type = "Condition", var = "UsedWarcryRecently" } },
	["for each time you[' ]h?a?ve warcried recently"] = { tag = { type = "Multiplier", var = "WarcryUsedRecently" } },
	["when you warcry"] = { tag = { type = "Condition", var = "UsedWarcryRecently" } },
	["if you[' ]h?a?ve warcried in the past 8 seconds"] = { tag = { type = "Condition", var = "UsedWarcryInPast8Seconds" } },
	["for each second you've been affected by a warcry buff, up to a maximum of (%d+)%%"] = function(num) return { tag = { type = "Multiplier", var = "AffectedByWarcryBuffDuration", limit = num, limitTotal = true } } end,
	["for each of your mines detonated recently, up to (%d+)%%"] = function(num) return { tag = { type = "Multiplier", var = "MineDetonatedRecently", limit = num, limitTotal = true } } end,
	["for each mine detonated recently, up to (%d+)%%"] = function(num) return { tag = { type = "Multiplier", var = "MineDetonatedRecently", limit = num, limitTotal = true } } end,
	["for each mine detonated recently, up to (%d+)%% per second"] = function(num) return { tag = { type = "Multiplier", var = "MineDetonatedRecently", limit = num, limitTotal = true } } end,
	["for each of your traps triggered recently, up to (%d+)%%"] = function(num) return { tag = { type = "Multiplier", var = "TrapTriggeredRecently", limit = num, limitTotal = true } } end,
	["for each trap triggered recently, up to (%d+)%%"] = function(num) return { tag = { type = "Multiplier", var = "TrapTriggeredRecently", limit = num, limitTotal = true } } end,
	["for each trap triggered recently, up to (%d+)%% per second"] = function(num) return { tag = { type = "Multiplier", var = "TrapTriggeredRecently", limit = num, limitTotal = true } } end,
	["if you[' ]h?a?ve used a fire skill recently"] = { tag = { type = "Condition", var = "UsedFireSkillRecently" } },
	["if you[' ]h?a?ve used a cold skill recently"] = { tag = { type = "Condition", var = "UsedColdSkillRecently" } },
	["if you[' ]h?a?ve used a fire skill in the past 10 seconds"] = { tag = { type = "Condition", var = "UsedFireSkillInPast10Sec" } },
	["if you[' ]h?a?ve used a cold skill in the past 10 seconds"] = { tag = { type = "Condition", var = "UsedColdSkillInPast10Sec" } },
	["if you[' ]h?a?ve used a lightning skill in the past 10 seconds"] = { tag = { type = "Condition", var = "UsedLightningSkillInPast10Sec" } },
	["if you[' ]h?a?ve summoned a totem recently"] = { tag = { type = "Condition", var = "SummonedTotemRecently" } },
	["when you summon a totem"] = { tag = { type = "Condition", var = "SummonedTotemRecently" } },
	["if you summoned a golem in the past 8 seconds"] = { tag = { type = "Condition", var = "SummonedGolemInPast8Sec" } },
	["if you haven't summoned a totem in the past 2 seconds"] = { tag = { type = "Condition", var = "NoSummonedTotemsInPastTwoSeconds" }  },
	["if you[' ]h?a?ve used a minion skill recently"] = { tag = { type = "Condition", var = "UsedMinionSkillRecently" } },
	["if you[' ]h?a?ve used a movement skill recently"] = { tag = { type = "Condition", var = "UsedMovementSkillRecently" } },
	["if you haven't cast dash recently"] = { tag = { type = "Condition", var = "CastDashRecently", neg = true } },
	["if you[' ]h?a?ve cast dash recently"] = { tag = { type = "Condition", var = "CastDashRecently" } },
	["if you[' ]h?a?ve used a vaal skill recently"] = { tag = { type = "Condition", var = "UsedVaalSkillRecently" } },
	["if you[' ]h?a?ve used a socketed vaal skill recently"] = { tag = { type = "Condition", var = "UsedVaalSkillRecently" } },
	["when you use a vaal skill"] = { tag = { type = "Condition", var = "UsedVaalSkillRecently" } },
	["if you haven't used a brand skill recently"] = { tag = { type = "Condition", var = "UsedBrandRecently", neg = true } },
	["if you[' ]h?a?ve used a brand skill recently"] = { tag = { type = "Condition", var = "UsedBrandRecently" } },
	["if you[' ]h?a?ve spent (%d+) total mana recently"] = function(num) return { tag = { type = "MultiplierThreshold", var = "ManaSpentRecently", threshold = num } } end,
	["if you[' ]h?a?ve spent life recently"] = { tag = { type = "MultiplierThreshold", var = "LifeSpentRecently", threshold = 1 } },
	["for %d+ seconds after spending a total of (%d+) mana"] = function(num) return { tag = { type = "MultiplierThreshold", var = "ManaSpentRecently", threshold = num } } end,
	["if you've impaled an enemy recently"] = { tag = { type = "Condition", var = "ImpaledRecently" } },
	["if you've changed stance recently"] = { tag = { type = "Condition", var = "ChangedStanceRecently" } },
	["if you've gained a power charge recently"] = { tag = { type = "Condition", var = "GainedPowerChargeRecently" } },
	["if you haven't gained a power charge recently"] = { tag = { type = "Condition", var = "GainedPowerChargeRecently", neg = true } },
	["if you haven't gained a frenzy charge recently"] = { tag = { type = "Condition", var = "GainedFrenzyChargeRecently", neg = true } },
	["if you've stopped taking damage over time recently"] = { tag = { type = "Condition", var = "StoppedTakingDamageOverTimeRecently" } },
	["during soul gain prevention"] = { tag = { type = "Condition", var = "SoulGainPrevention" } },
	["if you detonated mines recently"] = { tag = { type = "Condition", var = "DetonatedMinesRecently" } },
	["if you detonated a mine recently"] = { tag = { type = "Condition", var = "DetonatedMinesRecently" } },
	["if you[' ]h?a?ve detonated a mine recently"] = { tag = { type = "Condition", var = "DetonatedMinesRecently" } },
	["when your mine is detonated targeting an enemy"] = { tag = { type = "Condition", var = "DetonatedMinesRecently" } },
	["when your trap is triggered by an enemy"] = { tag = { type = "Condition", var = "TriggeredTrapsRecently" } },
	["if energy shield recharge has started recently"] = { tag = { type = "Condition", var = "EnergyShieldRechargeRecently" } },
	["if energy shield recharge has started in the past 2 seconds"] = { tag = { type = "Condition", var = "EnergyShieldRechargePastTwoSec" } },
	["when cast on frostbolt"] = { tag = { type = "Condition", var = "CastOnFrostbolt" } },
	["branded enemy's"] = { tag = { type = "MultiplierThreshold", var = "BrandsAttachedToEnemy", threshold = 1 } },
	["to enemies they're attached to"] = { tag = { type = "MultiplierThreshold", var = "BrandsAttachedToEnemy", threshold = 1 } },
	["for each hit you've taken recently up to a maximum of (%d+)%%"] = function(num) return { tag = { type = "Multiplier", var = "BeenHitRecently", limit = num, limitTotal = true } } end,
	["for each nearby enemy, up to (%d+)%%"] = function(num) return { tag = { type = "Multiplier", var = "NearbyEnemies", limit = num, limitTotal = true } } end,
	["while you have iron reflexes"] = { tag = { type = "Condition", var = "HaveIronReflexes" } },
	["while you do not have iron reflexes"] = { tag = { type = "Condition", var = "HaveIronReflexes", neg = true } },
	["while you have elemental overload"] = { tag = { type = "Condition", var = "HaveElementalOverload" } },
	["while you do not have elemental overload"] = { tag = { type = "Condition", var = "HaveElementalOverload", neg = true } },
	["while you have resolute technique"] = { tag = { type = "Condition", var = "HaveResoluteTechnique" } },
	["while you do not have resolute technique"] = { tag = { type = "Condition", var = "HaveResoluteTechnique", neg = true } },
	["while you have avatar of fire"] = { tag = { type = "Condition", var = "HaveAvatarOfFire" } },
	["while you do not have avatar of fire"] = { tag = { type = "Condition", var = "HaveAvatarOfFire", neg = true } },
	["if you have a summoned golem"] = { tag = { type = "Condition", varList = { "HavePhysicalGolem", "HaveLightningGolem", "HaveColdGolem", "HaveFireGolem", "HaveChaosGolem", "HaveCarrionGolem" } } },
	["while you have a summoned golem"] = { tag = { type = "Condition", varList = { "HavePhysicalGolem", "HaveLightningGolem", "HaveColdGolem", "HaveFireGolem", "HaveChaosGolem", "HaveCarrionGolem" } } },
	["if a minion has died recently"] = { tag = { type = "Condition", var = "MinionsDiedRecently" } },
	["if a minion has been killed recently"] = { tag = { type = "Condition", var = "MinionsDiedRecently" } },
	["while you have sacrificial zeal"] = { tag = { type = "Condition", var = "SacrificialZeal" } },
	["while sane"] = { tag = { type = "Condition", var = "Insane", neg = true } },
	["while insane"] = { tag = { type = "Condition", var = "Insane" } },
	["while you have defiance"] = { tag = { type = "MultiplierThreshold", var = "Defiance", threshold = 1 } },
	["while affected by glorious madness"] = { tag = { type = "Condition", var = "AffectedByGloriousMadness" } },
	["if you have reserved life and mana"] = { tagList = {
		{ type = "StatThreshold", stat = "LifeReserved", threshold = 1},
		{ type = "StatThreshold", stat = "ManaReserved", threshold = 1} } },
	["if you've shattered an enemy recently"] = { tag = { type = "Condition", var = "ShatteredEnemyRecently" } },
	-- Enemy status conditions
	["at close range"] = { tag = { type = "Condition", var = "AtCloseRange" } },
	["against rare and unique enemies"] = { tag = { type = "ActorCondition", actor = "enemy", var = "RareOrUnique" } },
	["by s?l?a?i?n? rare [ao][nr]d? unique enemies"] = { tag = { type = "ActorCondition", actor = "enemy", var = "RareOrUnique" } },
	["against unique enemies"] = { tag = { type = "ActorCondition", actor = "enemy", var = "RareOrUnique" } },
	["against enemies on full life"] = { tag = { type = "ActorCondition", actor = "enemy", var = "FullLife" } },
	["against enemies that are on full life"] = { tag = { type = "ActorCondition", actor = "enemy", var = "FullLife" } },
	["against enemies on low life"] = { tag = { type = "ActorCondition", actor = "enemy", var = "LowLife" } },
	["against enemies that are on low life"] = { tag = { type = "ActorCondition", actor = "enemy", var = "LowLife" } },
	["to enemies which have energy shield"] = { tag = { type = "ActorCondition", actor = "enemy", var = "HaveEnergyShield" } },
	["against cursed enemies"] = { tag = { type = "ActorCondition", actor = "enemy", var = "Cursed" } },
	["against stunned enemies"] = { tag = { type = "ActorCondition", actor = "enemy", var = "Stunned" } },
	["on cursed enemies"] = { tag = { type = "ActorCondition", actor = "enemy", var = "Cursed" } },
	["of cursed enemies'"] = { tag = { type = "ActorCondition", actor = "enemy", var = "Cursed" } },
	["when hitting cursed enemies"] = { tag = { type = "ActorCondition", actor = "enemy", var = "Cursed" }, keywordFlags = KeywordFlag.Hit },
	["from cursed enemies"] = { tag = { type = "ActorCondition", actor = "enemy", var = "Cursed" } },
	["against marked enemy"] = { tag = { type = "ActorCondition", actor = "enemy", var = "Marked" } },
	["when hitting marked enemy"] = { tag = { type = "ActorCondition", actor = "enemy", var = "Marked" }, keywordFlags = KeywordFlag.Hit },
	["from marked enemy"] = { tag = { type = "ActorCondition", actor = "enemy", var = "Marked" } },
	["against taunted enemies"] = { tag = { type = "ActorCondition", actor = "enemy", var = "Taunted" } },
	["against bleeding enemies"] = { tag = { type = "ActorCondition", actor = "enemy", var = "Bleeding" } },
	["you inflict on bleeding enemies"] = { tag = { type = "ActorCondition", actor = "enemy", var = "Bleeding" } },
	["to bleeding enemies"] = { tag = { type = "ActorCondition", actor = "enemy", var = "Bleeding" } },
	["from bleeding enemies"] = { tag = { type = "ActorCondition", actor = "enemy", var = "Bleeding" } },
	["against poisoned enemies"] = { tag = { type = "ActorCondition", actor = "enemy", var = "Poisoned" } },
	["you inflict on poisoned enemies"] = { tag = { type = "ActorCondition", actor = "enemy", var = "Poisoned" } },
	["to poisoned enemies"] = { tag = { type = "ActorCondition", actor = "enemy", var = "Poisoned" } },
	["against enemies affected by (%d+) or more poisons"] = function(num) return { tag = { type = "MultiplierThreshold", actor = "enemy", var = "PoisonStack", threshold = num } } end,
	["against enemies affected by at least (%d+) poisons"] = function(num) return { tag = { type = "MultiplierThreshold", actor = "enemy", var = "PoisonStack", threshold = num } } end,
	["against hindered enemies"] = { tag = { type = "ActorCondition", actor = "enemy", var = "Hindered" } },
	["against maimed enemies"] = { tag = { type = "ActorCondition", actor = "enemy", var = "Maimed" } },
	["you inflict on maimed enemies"] = { tag = { type = "ActorCondition", actor = "enemy", var = "Maimed" } },
	["against blinded enemies"] = { tag = { type = "ActorCondition", actor = "enemy", var = "Blinded" } },
	["from blinded enemies"] = { tag = { type = "ActorCondition", actor = "enemy", var = "Blinded" } },
	["against burning enemies"] = { tag = { type = "ActorCondition", actor = "enemy", var = "Burning" } },
	["against ignited enemies"] = { tag = { type = "ActorCondition", actor = "enemy", var = "Ignited" } },
	["to ignited enemies"] = { tag = { type = "ActorCondition", actor = "enemy", var = "Ignited" } },
	["against shocked enemies"] = { tag = { type = "ActorCondition", actor = "enemy", var = "Shocked" } },
	["you inflict on shocked enemies"] = { tag = { type = "ActorCondition", actor = "enemy", var = "Shocked" } },
	["to shocked enemies"] = { tag = { type = "ActorCondition", actor = "enemy", var = "Shocked" } },
	["inflicted on shocked enemies"] = { tag = { type = "ActorCondition", actor = "enemy", var = "Shocked" } },
	["enemies which are shocked"] = { tag = { type = "ActorCondition", actor = "enemy", var = "Shocked" } },
	["against frozen enemies"] = { tag = { type = "ActorCondition", actor = "enemy", var = "Frozen" } },
	["to frozen enemies"] = { tag = { type = "ActorCondition", actor = "enemy", var = "Frozen" } },
	["against chilled enemies"] = { tag = { type = "ActorCondition", actor = "enemy", var = "Chilled" } },
	["you inflict on chilled enemies"] = { tag = { type = "ActorCondition", actor = "enemy", var = "Chilled" } },
	["to chilled enemies"] = { tag = { type = "ActorCondition", actor = "enemy", var = "Chilled" } },
	["inflicted on chilled enemies"] = { tag = { type = "ActorCondition", actor = "enemy", var = "Chilled" } },
	["enemies which are chilled"] = { tag = { type = "ActorCondition", actor = "enemy", var = "Chilled" } },
	["against chilled or frozen enemies"] = { tag = { type = "ActorCondition", actor = "enemy", varList = { "Chilled","Frozen" } } },
	["against frozen, shocked or ignited enemies"] = { tag = { type = "ActorCondition", actor = "enemy", varList = { "Frozen","Shocked","Ignited" } } },
	["against enemies affected by elemental ailments"] = { tag = { type = "ActorCondition", actor = "enemy", varList = { "Frozen","Chilled","Shocked","Ignited","Scorched","Brittle","Sapped" } } },
	["against enemies affected by ailments"] = { tag = { type = "ActorCondition", actor = "enemy", varList = { "Frozen","Chilled","Shocked","Ignited","Scorched","Brittle","Sapped","Poisoned","Bleeding" } } },
	["against enemies that are affected by elemental ailments"] = { tag = { type = "ActorCondition", actor = "enemy", varList = { "Frozen","Chilled","Shocked","Ignited","Scorched","Brittle","Sapped" } } },
	["against enemies that are affected by no elemental ailments"] = { tagList = { { type = "ActorCondition", actor = "enemy", varList = { "Frozen","Chilled","Shocked","Ignited","Scorched","Brittle","Sapped" }, neg = true }, { type = "Condition", var = "Effective" } } },
	["against enemies affected by (%d+) spider's webs"] = function(num) return { tag = { type = "MultiplierThreshold", actor = "enemy", var = "Spider's WebStack", threshold = num } } end,
	["against enemies on consecrated ground"] = { tag = { type = "ActorCondition", actor = "enemy", var = "OnConsecratedGround" } },
	["if (%d+)%% of curse duration expired"] = function(num) return { tag = { type = "MultiplierThreshold", actor = "enemy", var = "CurseExpired", threshold = num } } end,
	["against enemies with (%w+) exposure"] = function(element) return { tag = { type = "ActorCondition", actor = "enemy", var = "Has"..(firstToUpper(element).."Exposure") } } end,
	-- Enemy multipliers
	["per freeze, shock [ao][nr]d? ignite on enemy"] = { tag = { type = "Multiplier", var = "FreezeShockIgniteOnEnemy" } },
	["per poison affecting enemy"] = { tag = { type = "Multiplier", actor = "enemy", var = "PoisonStack" } },
	["per poison affecting enemy, up to %+([%d%.]+)%%"] = function(num) return { tag = { type = "Multiplier", actor = "enemy", var = "PoisonStack", limit = num, limitTotal = true } } end,
	["for each spider's web on the enemy"] = { tag = { type = "Multiplier", actor = "enemy", var = "Spider's WebStack" } },
}

for i,stat in ipairs(LongAttributes) do
	modTagList["per " .. stat:lower()] = { tag = { type = "PerStat", stat = Attributes[i] } }
end
for _, weapon in ipairs({ "Wand", "Bow", "Axe", "Sceptre", "Staff" }) do
	modTagList["with an? " .. weapon:lower()] = { tag = { type = "Condition", var = "Using" .. weapon } }
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
	["^%+([%d%.]+%%) Damage"] = "%1 more Damage",
	["^%+([%d%.]+%%) Cast Speed"] = "%1 increased Cast Speed",
	["^%+([%d%.]+%%) Cooldown Recovery Speed"] = "%1 increased Cooldown Recovery Speed",
}

local specialModList = {
	["no cooldown"] = { flag("NoCooldown") },
}

-- Modifiers that are recognised but unsupported
local unsupportedModList = {
}

-- Special lookups used for various modifier forms
local suffixTypes = {
	["as extra lightning damage"] = "GainAsLightning",
	["added as lightning damage"] = "GainAsLightning",
	["gained as extra lightning damage"] = "GainAsLightning",
	["as extra cold damage"] = "GainAsCold",
	["added as cold damage"] = "GainAsCold",
	["gained as extra cold damage"] = "GainAsCold",
	["as extra fire damage"] = "GainAsFire",
	["added as fire damage"] = "GainAsFire",
	["gained as extra fire damage"] = "GainAsFire",
	["as extra chaos damage"] = "GainAsChaos",
	["added as chaos damage"] = "GainAsChaos",
	["gained as extra chaos damage"] = "GainAsChaos",
	["converted to lightning"] = "ConvertToLightning",
	["converted to lightning damage"] = "ConvertToLightning",
	["converted to cold damage"] = "ConvertToCold",
	["converted to fire damage"] = "ConvertToFire",
	["converted to fire"] = "ConvertToFire",
	["converted to chaos damage"] = "ConvertToChaos",
	["added as energy shield"] = "GainAsEnergyShield",
	["as extra maximum energy shield"] = "GainAsEnergyShield",
	["converted to energy shield"] = "ConvertToEnergyShield",
	["as extra armour"] = "GainAsArmour",
	["as physical damage"] = "AsPhysical",
	["as lightning damage"] = "AsLightning",
	["as cold damage"] = "AsCold",
	["as fire damage"] = "AsFire",
	["as fire"] = "AsFire",
	["as chaos damage"] = "AsChaos",
	["leeched as life and mana"] = "Leech",
	["leeched as life"] = "LifeLeech",
	["is leeched as life"] = "LifeLeech",
	["leeched as mana"] = "ManaLeech",
	["is leeched as mana"] = "ManaLeech",
	["leeched as energy shield"] = "EnergyShieldLeech",
	["is leeched as energy shield"] = "EnergyShieldLeech",
}
local dmgTypes = {
	["physical"] = "Physical",
	["lightning"] = "Lightning",
	["cold"] = "Cold",
	["fire"] = "Fire",
	["chaos"] = "Chaos",
}
local resourceTypes = {
	["life"] = "Life",
	["mana"] = "Mana",
	["energy shield"] = "EnergyShield",
	["life and mana"] = { "Life", "Mana" },
	["life and energy shield"] = { "Life", "EnergyShield" },
	["life, mana and energy shield"] = { "Life", "Mana", "EnergyShield" },
	["life, energy shield and mana"] = { "Life", "Mana", "EnergyShield" },
	["mana and life"] = { "Life", "Mana" },
	["mana and energy shield"] = { "Mana", "EnergyShield" },
	["mana, life and energy shield"] = { "Life", "Mana", "EnergyShield" },
	["mana, energy shield and life"] = { "Life", "Mana", "EnergyShield" },
	["energy shield and life"] = { "Life", "EnergyShield" },
	["energy shield and mana"] = { "Mana", "EnergyShield" },
	["energy shield, life and mana"] = { "Life", "Mana", "EnergyShield" },
	["energy shield, mana and life"] = { "Life", "Mana", "EnergyShield" },
	["rage"] = "Rage",
}
do
	local maximumResourceTypes = { }
	for resource, values in pairs(resourceTypes) do
		maximumResourceTypes["maximum "..resource] = values
	end
	for resource, values in pairs(maximumResourceTypes) do
		resourceTypes[resource] = values
	end
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
local regenTypes = appendMod(resourceTypes, "Regen")
local degenTypes = appendMod(resourceTypes, "Degen")
local costTypes = appendMod(resourceTypes, "Cost")
local baseCostTypes = appendMod(resourceTypes, "CostNoMult")
local flagTypes = {
	["phasing"] = "Condition:Phasing",
	["onslaught"] = "Condition:Onslaught",
	["rampage"] = "Condition:Rampage",
	["soul eater"] = "Condition:CanHaveSoulEater",
	["adrenaline"] = "Condition:Adrenaline",
	["elusive"] = "Condition:CanBeElusive",
	["arcane surge"] = "Condition:ArcaneSurge",
	["fortify"] = "Condition:Fortified",
	["fortified"] = "Condition:Fortified",
	["unholy might"] = "Condition:UnholyMight",
	["lesser brutal shrine buff"] = "Condition:LesserBrutalShrine",
	["lesser massive shrine buff"] = "Condition:LesserMassiveShrine",
	["tailwind"] = "Condition:Tailwind",
	["intimidated"] = "Condition:Intimidated",
	["crushed"] = "Condition:Crushed",
	["chilled"] = "Condition:Chilled",
	["blinded"] = "Condition:Blinded",
	["no life regeneration"] = "NoLifeRegen",
	["hexproof"] = { name = "CurseEffectOnSelf", value = -100, type = "MORE" },
	["hindered,? with (%d+)%% reduced movement speed"] = "Condition:Hindered",
	["unnerved"] = "Condition:Unnerved",
	["malediction"] = "HasMalediction",
}

-- Build active skill name lookup
local skillNameList = {
}

for skillId, skill in pairs(data.skills) do
	skillNameList[skill.name:lower()] = { tag = { type = "SkillId", skillId = skillId } }
end

local preSkillNameList = { }

-- Radius jewels that modify the jewel itself based on nearby allocated nodes
local function getPerStat(dst, modType, flags, stat, factor)
	return function(node, out, data)
		if node then
			data[stat] = (data[stat] or 0) + out:Sum("BASE", nil, stat)
		elseif data[stat] ~= 0 then
			out:NewMod(dst, modType, math.floor((data[stat] or 0) * factor), data.modSource, flags)
		end
	end
end

-- Radius jewels with bonuses conditional upon attributes of nearby nodes
local function getThreshold(attrib, name, modType, value, ...)
	local baseMod = mod(name, modType, value, "", ...)
	return function(node, out, data)
		if node then
			if type(attrib) == "table" then
				for _, att in ipairs(attrib) do
					local nodeVal = out:Sum("BASE", nil, att)
					data[att] = (data[att] or 0) + nodeVal
					data.total = (data.total or 0) + nodeVal
				end
			else
				local nodeVal = out:Sum("BASE", nil, attrib)
				data[attrib] = (data[attrib] or 0) + nodeVal
				data.total = (data.total or 0) + nodeVal
			end
		elseif (data.total or 0) >= 40 then
			local mod = copyTable(baseMod)
			mod.source = data.modSource
			if type(value) == "table" and value.mod then
				value.mod.source = data.modSource
			end
			out:AddMod(mod)
		end
	end
end

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
	if modForm == "BASECOST" then
		modName, line = scan(line, baseCostTypes, true)
		if not modName then
			return { }, line
		end
		local _
		_, line = scan(line, modNameList, true)
	elseif modForm == "TOTALCOST" then
		modName, line = scan(line, costTypes, true)
		if not modName then
			return { }, line
		end
		local _
		_, line = scan(line, modNameList, true)
	elseif modForm == "FLAG" then
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
	elseif modForm == "REGENPERCENT" then
		modName = regenTypes[formCap[2]]
		modSuffix = "Percent"
	elseif modForm == "REGENFLAT" then
		modName = regenTypes[formCap[2]]
	elseif modForm == "DEGENPERCENT" then
		modValue = modValue
		modName = degenTypes[formCap[2]]
		modSuffix = "Percent"
	elseif modForm == "DEGENFLAT" then
		modValue = modValue
		modName = degenTypes[formCap[2]]
	elseif modForm == "DEGEN" then
		local damageType = dmgTypes[formCap[2]]
		if not damageType then
			return { }, line
		end
		modName = damageType .. "Degen"
		modSuffix = ""
	elseif modForm == "DMG" or modForm == "INCDMG" then
		local damageTypes = DamageTypes
		modFlag = {flags = 0, keywordFlags = 0}
		for i=2,#formCap do
			for _,v in ipairs(DamageSourceTypes) do
				if formCap[i] == v:lower() then
					modFlag.flags = ModFlag[v]
				end
			end
			for _,v in ipairs(DamageTypes) do
				if formCap[i] == v:lower() then
					damageTypes = {v}
				end
			end
			if formCap[i] == "minion" then
				modFlag.addToMinion = true
			end
		end
		if modForm == "INCDMG" then
			modType = "INC"
		end
		modName = {}
		keywordFlags = {}
		if modForm == "DMG" then
			for _,damageType in ipairs(damageTypes) do
				-- If the damage type is specific, then it is applied regardless of the type of the skill
					if #damageTypes > 1 then
						table.insert(keywordFlags, KeywordFlag[damageType])
					end
					table.insert(modName,damageType.."Min")
					if #damageTypes > 1 then
						table.insert(keywordFlags, KeywordFlag[damageType])
					end
					table.insert(modName,damageType.."Max")
			end
		else
			if #damageTypes == 1 then
				table.insert(modName,damageTypes[1].."Damage")
			else
				-- Increase damage for all damage types
				table.insert(modName,"Damage")
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
			modList, extra = parseMod(line, 2)
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
