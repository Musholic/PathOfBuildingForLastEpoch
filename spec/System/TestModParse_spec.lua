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
    end)
    
end)