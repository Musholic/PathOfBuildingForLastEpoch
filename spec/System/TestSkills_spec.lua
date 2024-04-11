describe("TestSkills #skills", function()
    before_each(function()
        newBuild()
    end)

	it("Test melee skill with basic weapon", function()
        build.itemsTab:CreateDisplayItemFromRaw([[ Rarity: RARE
        Forestry Axe
        Forestry Axe
        +8 Strength
        +23 Melee Damage
        +10 Melee Physical Damage]])
        build.itemsTab:AddDisplayItem()

        -- Use melee skill Lunge
        build.skillsTab:SelSkill(1, "lu25ng")
        runCallback("OnFrame")

        assert.are.equals(10, build.calcsTab.mainOutput.Str)
        assert.are.equals((2+10+23) * (1 + 0.04 * 10), build.calcsTab.mainOutput.TotalDPS)
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

        assert.are.equals((25+(10+30) * 1.25) * 4, build.calcsTab.mainOutput.TotalDPS)
    end)
end)