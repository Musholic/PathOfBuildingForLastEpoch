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
        build.buildFlag = true
        runCallback("OnFrame")
        assert.are.equals(242, build.calcsTab.calcsOutput.Life)

        build.configTab.input.customMods = "+892 Health\n\z
        20.5% increased Health"
        build.configTab:BuildModList()
        build.buildFlag = true
        runCallback("OnFrame")
        assert.are.equals(1207, build.calcsTab.calcsOutput.Life)
    end)

    it("health regen", function()
        build.configTab.input.customMods = "100% Increased Health Regen"
        build.configTab:BuildModList()
        build.buildFlag = true
        runCallback("OnFrame")
        assert.are.equals(12, math.floor(build.calcsTab.calcsOutput.LifeRegen))

        build.configTab.input.customMods = "200% Increased Health Regen\n\z50% Reduced Health Regeneration"
        build.configTab:BuildModList()
        build.buildFlag = true
        runCallback("OnFrame")
        assert.are.equals(15, math.floor(build.calcsTab.calcsOutput.LifeRegen))
    end)

    it("cooldown recovery", function()
        build.configTab.input.customMods = "-17% Cooldown Recovery Speed"
        build.configTab:BuildModList()
        runCallback("OnFrame")
        assert.are.equals(0, build.configTab.modList:Sum("BASE", nil, "CooldownRecovery"))
        assert.are.equals(-17, build.configTab.modList:Sum("INC", nil, "CooldownRecovery"))
    end)

    it("duration", function()
        build.configTab.input.customMods = "+81% Duration"
        build.configTab:BuildModList()
        runCallback("OnFrame")
        assert.are.equals(0, build.configTab.modList:Sum("BASE", nil, "Duration"))
        assert.are.equals(81, build.configTab.modList:Sum("INC", nil, "Duration"))
    end)

    it("attributes", function()
        build.configTab.input.customMods = "+2 to All Attributes"
        build.configTab:BuildModList()
        build.buildFlag = true
        runCallback("OnFrame")

        assert.are.equals(4, build.calcsTab.calcsOutput.Str)
        assert.are.equals(2, build.calcsTab.calcsOutput.Dex)
        assert.are.equals(2, build.calcsTab.calcsOutput.Int)
        assert.are.equals(3, build.calcsTab.calcsOutput.Att)
        assert.are.equals(2, build.calcsTab.calcsOutput.Vit)
    end)

    it("damage types", function()
        build.configTab.input.customMods = "+10 damage\n+20 melee physical damage\n+25 spell fire damage"
        build.configTab:BuildModList()
        runCallback("OnFrame")

        assert.are.equals(10, build.configTab.modList:Sum("BASE", { keywordFlags = KeywordFlag.Physical }, "Damage"))
        assert.are.equals(10, build.configTab.modList:Sum("BASE", { keywordFlags = KeywordFlag.Physical }, "Damage"))
        assert.are.equals(20, build.configTab.modList:Sum("BASE", { flags = ModFlag.Melee }, "PhysicalDamage"))
        assert.are.equals(0, build.configTab.modList:Sum("BASE", nil, "PhysicalDamage"))
        assert.are.equals(0, build.configTab.modList:Sum("BASE", { keywordFlags = KeywordFlag.Fire }, "FireDamage"))
        assert.are.equals(25, build.configTab.modList:Sum("BASE", { keywordFlags = KeywordFlag.Fire, flags = KeywordFlag.Spell }, "FireDamage"))
    end)

    it("increased damage", function()
        build.configTab.input.customMods = "50% increased melee void damage"
        build.configTab:BuildModList()
        runCallback("OnFrame")

        assert.are.equals(50, build.configTab.modList:Sum("INC", { keywordFlags = KeywordFlag.Void, flags = ModFlag.Melee }, "VoidDamage"))
    end)

    it("passive node more damage", function()
        build.configTab.input.customMods = "+10.5% Damage"
        build.configTab:BuildModList()
        runCallback("OnFrame")

        assert.are.equals(10.5, build.configTab.modList:Sum("MORE", nil, "Damage"))
    end)

    it("effect doubled", function()
        build.configTab.input.customMods = "+40% Increased fire damage. This effect is doubled if you have 300 or more maximum mana."
        build.configTab:BuildModList()
        runCallback("OnFrame")
        build.skillsTab:SelSkill(1, "fi9")
        runCallback("OnFrame")

        assert.are.equals(51, build.calcsTab.calcsOutput.Mana)
        assert.are.equals(40, build.calcsTab.mainEnv.player.mainSkill.skillModList:Sum("INC", nil, "FireDamage"))

        build.configTab.input.customMods = "+900 maximum mana\n\z+40% Increased fire damage. This effect is doubled if you have 300 or more maximum mana."
        build.configTab:BuildModList()
        build.buildFlag = true
        runCallback("OnFrame")

        assert.are.equals(951, build.calcsTab.calcsOutput.Mana)
        assert.are.equals(80, build.calcsTab.mainEnv.player.mainSkill.skillModList:Sum("INC", nil, "FireDamage"))
    end)

    it("elemental cast speed", function()
        build.configTab.input.customMods = "+10% increased elemental cast speed"
        build.configTab:BuildModList()
        runCallback("OnFrame")

        assert.are.equals(10, build.configTab.modList:Sum("INC", {keywordFlags = KeywordFlag.Fire, flags = ModFlag.Cast}, "Speed"))
    end)

    it("shred chance", function()
        build.configTab.input.customMods = "+10% Void Shred Chance"
        build.configTab:BuildModList()
        runCallback("OnFrame")

        assert.are.equals(10, build.configTab.modList:Sum("BASE", {flags = ModFlag.Hit}, "ChanceToTriggerOnHit_Ailment_VoidResistanceShred"))
    end)

    it("melee chance", function()
        build.configTab.input.customMods = "+10% Melee Chance to Ignite on Hit"
        build.configTab:BuildModList()
        runCallback("OnFrame")

        assert.are.equals(0, build.configTab.modList:Sum("BASE", {flags = bit.bor(ModFlag.Hit)}, "ChanceToTriggerOnHit_Ailment_Ignite"))
        assert.are.equals(10, build.configTab.modList:Sum("BASE", {flags = bit.bor(ModFlag.Hit, ModFlag.Melee)}, "ChanceToTriggerOnHit_Ailment_Ignite"))
    end)
end)