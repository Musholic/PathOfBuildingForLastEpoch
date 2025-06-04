describe("TestSkills #skills", function()
    before_each(function()
        newBuild()
    end)

    it("Test melee skill with cooldown and basic weapon", function()
        build.itemsTab:CreateDisplayItemFromRaw([[ Rarity: RARE
        Forestry Axe
        Forestry Axe
        +8 Strength
        +23 Melee Damage
        100% increased Critical Strike Chance
        +10 Melee Physical Damage]])
        build.itemsTab:AddDisplayItem()

        -- Use melee skill Lunge
        build.skillsTab:SelSkill(1, "lu25ng")
        runCallback("OnFrame")

        local castSpeed = 1 / build.calcsTab.mainEnv.player.mainSkill.activeEffect.grantedEffect.stats.cooldown
        assert.are.equals(10, build.calcsTab.mainOutput.Str)
        assert.are.equals((2 + 10 + 23) * (1 + 0.04 * 10) * 1.1 * castSpeed, build.calcsTab.mainOutput.TotalDPS)
    end)

    it("Test spell skill with basic weapon", function()
        build.itemsTab:CreateDisplayItemFromRaw([[ Rarity: RARE
        Forestry Axe
        Forestry Axe
        100% increased Fire Damage
        100% more Fire Damage
        +30 Spell Damage
        +10 Spell Fire Damage]])
        build.itemsTab:AddDisplayItem()

        -- Use fire skill Fireball with 25 base fire damage
        build.skillsTab:SelSkill(1, "fi9")

        runCallback("OnFrame")

        local castSpeed = 1 / build.calcsTab.mainEnv.player.mainSkill.activeEffect.grantedEffect.castTime
        assert.are.equals((25 + (10 + 30) * 1.25) * 4 * 1.05 * castSpeed, build.calcsTab.mainOutput.TotalDPS)
    end)

    it("Test dot spell skill with basic weapon", function()
        build.itemsTab:CreateDisplayItemFromRaw([[Rarity: RARE
        Brass Sceptre
        Brass Sceptre
        TODO: check if added damage count for dot spells
        +10 Spell Damage
        20% increased Spell Damage
        20% increased Damage Over Time]])
        build.itemsTab:AddDisplayItem()

        -- Use skill Wandering Spirits
        build.skillsTab:SelSkill(1, "ws54hm")

        runCallback("OnFrame")

        assert.are.equals(31.02, round(build.calcsTab.mainOutput.TotalDPS, 2))
    end)

    it("Test melee skill with weapon attack speed", function()
        build.itemsTab:CreateDisplayItemFromRaw([[ Rarity: RARE
        Forestry Axe
        Forestry Axe
        +8 Strength
        +48 Melee Damage]])
        build.itemsTab:AddDisplayItem()

        -- Use melee skill Rive
        build.skillsTab:SelSkill(1, "sndr1")
        runCallback("OnFrame")

        local castSpeed = 1 / build.calcsTab.mainEnv.player.mainSkill.activeEffect.grantedEffect.castTime
        assert.are.equals(round((2 + 48 * 1.25) * (1 + 0.04 * 10) * 1.05 * 0.92 * castSpeed, 4), round(build.calcsTab.mainOutput.TotalDPS, 4))
    end)
end)