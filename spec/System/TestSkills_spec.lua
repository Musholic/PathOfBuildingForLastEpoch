describe("TestSkills #skills", function()
    before_each(function()
        newBuild()
    end)

	it("Test melee skill with basic weapon (ignoring enemy damage reduction)", function()
        -- Ignore enemy damage reduction for calcsOutput
        build.calcsTab.input.misc_buffMode = "COMBAT"

        build.itemsTab:CreateDisplayItemFromRaw([[ Rarity: RARE
        Forestry Axe
        Forestry Axe
        +23 Melee Damage
        +10 Melee Physical Damage]])
        build.itemsTab:AddDisplayItem()

        -- Use melee skill Lunge
        build.skillsTab:SelSkill(1, "lu25ng")
        runCallback("OnFrame")

        assert.are.equals(35, build.calcsTab.calcsOutput.TotalDPS)
    end)
end)