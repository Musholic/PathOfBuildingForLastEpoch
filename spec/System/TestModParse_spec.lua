describe("TestModParse", function()
    before_each(function()
        newBuild()
    end)

    teardown(function()
        -- newBuild() takes care of resetting everything in setup()
    end)

    it("health", function()
        build.configTab.input.customMods = "+92 Health\n\z
        20% increased Health"
        build.configTab:BuildModList()
        runCallback("OnFrame")
        assert.are.equals(240, build.calcsTab.calcsOutput.Life)

        build.configTab.input.customMods = "+892 Health\n\z
        20.5% increased Health"
        build.configTab:BuildModList()
        runCallback("OnFrame")
        assert.are.equals(1205, build.calcsTab.calcsOutput.Life)
    end)

    it("health regen", function()
        build.configTab.input.customMods = "100% Increased Health Regen"
        build.configTab:BuildModList()
        runCallback("OnFrame")
        assert.are.equals(12, math.floor(build.calcsTab.calcsOutput.LifeRegen))

        build.configTab.input.customMods = "200% Increased Health Regen\n\z50% Reduced Health Regeneration"
        build.configTab:BuildModList()
        runCallback("OnFrame")
        assert.are.equals(15, math.floor(build.calcsTab.calcsOutput.LifeRegen))
    end)

    it("attributes", function()
        build.configTab.input.customMods = "+2 to All Attributes"
        build.configTab:BuildModList()
        runCallback("OnFrame")
        assert.are.equals(4, build.calcsTab.calcsOutput.Str)
        assert.are.equals(2, build.calcsTab.calcsOutput.Dex)
        assert.are.equals(2, build.calcsTab.calcsOutput.Int)
        assert.are.equals(3, build.calcsTab.calcsOutput.Att)
        assert.are.equals(2, build.calcsTab.calcsOutput.Vit)
    end)

    it("damage types", function()
        build.configTab.input.customMods = "+10 damage\n+20 melee physical damage"
        build.configTab:BuildModList()
        runCallback("OnFrame")

        assert.are.equals(10, build.configTab.modList:Sum("BASE", nil, "PhysicalMin"))
        assert.are.equals(30, build.configTab.modList:Sum("BASE", { keywordFlags = KeywordFlag.Attack }, "PhysicalMin"))
    end)

end)