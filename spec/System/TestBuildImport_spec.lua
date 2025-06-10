expose("BuildImport #buildImport", function()
    it("build import from LETools", function()
        newBuild()
        local jsonFile = io.open("../spec/System/letools_import.json", "r")
        local importCode = jsonFile:read("*a")
        jsonFile:close()
        build:Init(false, "Imported build", importCode)
        runCallback("OnFrame")
        assert.are.equals(774, build.calcsTab.calcsOutput.Life)
        -- TODO: Fix campaign bonus
        assert.are.equals(5, build.calcsTab.calcsOutput.Vit)
    end)

    -- TODO: update to last version
    it("build import from LETools, fireballDps calculation", function()
        newBuild()
        local jsonFile = io.open("../spec/System/letools_import_fireballDps.json", "r")
        local importCode = jsonFile:read("*a")
        jsonFile:close()
        build:Init(false, "Imported build", importCode)
        runCallback("OnFrame")

        --TODO: Blessing support
        assert.are.equals("Fireball", build.calcsTab.mainEnv.player.mainSkill.skillCfg.skillName)
        assert.are.equals(7739, round(build.calcsTab.mainOutput.FullDPS))
    end)

    it("build import from LETools, minionDps calculation", function()
        newBuild()
        local jsonFile = io.open("../spec/System/letools_import_minions.json", "r")
        local importCode = jsonFile:read("*a")
        jsonFile:close()
        build:Init(false, "Imported build", importCode)
        runCallback("OnFrame")

        assert.are.equals("Summon Wraith", build.calcsTab.mainEnv.player.mainSkill.skillCfg.skillName)
        assert.are.equals(743, round(build.calcsTab.mainOutput.FullDPS))
    end)
end)
