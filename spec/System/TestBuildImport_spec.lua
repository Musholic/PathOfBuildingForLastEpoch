expose("BuildImport #buildImport", function()
    it("build import from LETools", function()
        newBuild()
        local jsonFile = io.open("../spec/System/letools_import.json", "r")
        local importCode = jsonFile:read("*a")
        jsonFile:close()
        build:Init(false, "Imported build", importCode)
        runCallback("OnFrame")
        assert.are.equals(1251, build.calcsTab.calcsOutput.Life)
    end)

    it("build import from LETools, fireballDps calculation", function()
        newBuild()
        local jsonFile = io.open("../spec/System/letools_import_fireballDps.json", "r")
        local importCode = jsonFile:read("*a")
        jsonFile:close()
        build:Init(false, "Imported build", importCode)
        runCallback("OnFrame")

        --TODO: Ignite dps, Blessing support
        assert.are.equals("Fireball", build.calcsTab.mainEnv.player.mainSkill.skillCfg.skillName)
        assert.are.equals(4848, round(build.calcsTab.mainOutput.FullDPS))
    end)
end)
