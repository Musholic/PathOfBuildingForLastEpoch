describe("TestItemParse #itemParse", function()
    it("Creating unique", function()
        local item = new("Item", "", "UNIQUE")
        item.title = "Calamity"
        item.name = "Calamity"
        item.baseName = "Jewelled Circlet"
        item:BuildAndParseRaw()
        --print(item:BuildRaw())
        assert.are.equals("Calamity, Jewelled Circlet", item.name)
    end)

end)
