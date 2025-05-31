-- Path of Building
--
-- Module: DataProcess
-- Process static data used by other modules
--

local t_insert = table.insert

local function processMod(grantedEffect, mod)
    mod.source = grantedEffect.modSource
    if type(mod.value) == "table" and mod.value.mod then
        mod.value.mod.source = "Skill:"..grantedEffect.id
    end
    for _, tag in ipairs(mod) do
        if tag.type == "GlobalEffect" then
            grantedEffect.hasGlobalEffect = true
            break
        end
    end
end

data.skillStatMapMeta = {
    __index = function(t, key)
        local map = data.skillStatMap[key]
        if map then
            map = copyTable(map)
            t[key] = map
            for _, mod in ipairs(map) do
                processMod(t._grantedEffect, mod)
            end
            return map
        end
    end
}

for skillId, grantedEffect in pairs(data.skills) do
    grantedEffect.id = skillId
    grantedEffect.modSource = "Skill:"..skillId
    -- Process base mods that are given as mod lines
    if grantedEffect.baseMods then
        local baseMods = grantedEffect.baseMods
        grantedEffect.baseMods = {}
        for i, mod in ipairs(baseMods) do
            local modList, extra = modLib.parseMod(mod)
            for _, mod in ipairs(modList) do
                t_insert(grantedEffect.baseMods, mod)
            end
        end
    end
    -- Add sources for skill mods, and check for global effects
    for _, list in pairs({grantedEffect.baseMods, grantedEffect.qualityMods, grantedEffect.levelMods}) do
        for _, mod in pairs(list) do
            if mod.name then
                processMod(grantedEffect, mod)
            else
                for _, mod in ipairs(mod) do
                    processMod(grantedEffect, mod)
                end
            end
        end
    end
    -- Install stat map metatable
    grantedEffect.statMap = grantedEffect.statMap or { }
    setmetatable(grantedEffect.statMap, data.skillStatMapMeta)
    grantedEffect.statMap._grantedEffect = grantedEffect
    for _, map in pairs(grantedEffect.statMap) do
        -- Some mods need different scalars for different stats, but the same value.  Putting them in a group allows this
        for _, modOrGroup in ipairs(map) do
            if modOrGroup.name then
                processMod(grantedEffect, modOrGroup)
            else
                for _, mod in ipairs(modOrGroup) do
                    processMod(grantedEffect, mod)
                end
            end
        end
    end
    --- Compute skill types
    grantedEffect.skillTypes = {}
    for name, type in pairs(SkillType) do
        if bit.band(grantedEffect.skillTypeTags, type) > 0 then
            grantedEffect.skillTypes[type] = true
        end
    end
end
