describe("TestSkills #skills", function()
    before_each(function()
        newBuild()
    end)

	it("Test melee skill with basic weapon", function()
        build.itemsTab:CreateDisplayItemFromRaw([[ Rarity: RARE
        Forestry Axe
        Forestry Axe
        +23 Melee Damage
        +10 Melee Physical Damage]])
        build.itemsTab:AddDisplayItem()

        -- Use melee skill Lunge
        build.skillsTab:SelSkill(1, "lu25ng")
        runCallback("OnFrame")

        assert.are.equals(35, build.calcsTab.mainOutput.TotalDPS)
    end)

    it("Test spell skill with basic weapon #inTest", function()
        build.itemsTab:CreateDisplayItemFromRaw([[ Rarity: RARE
        Forestry Axe
        Forestry Axe
        100% increased Fire Damage
        100% more Fire Damage
        +23 Spell Damage
        +10 Spell Fire Damage]])
        build.itemsTab:AddDisplayItem()

        -- Use fire skill Fireball with 25 base fire damage
        build.skillsTab:SelSkill(1, "fi9")

        runCallback("OnFrame")

        assert.are.equals(232, build.calcsTab.mainOutput.TotalDPS)
    end)
end)