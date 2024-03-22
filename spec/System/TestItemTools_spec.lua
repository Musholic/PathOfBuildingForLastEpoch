local applyRangeTests = {
    [{ "+(10-20) Health", 0.5, 1.0 }] = "+15 Health",
    [{ "(5-14)% increased Health", 96 / 256, 0.38 }] = "3.13% increased Health",
}

describe("TestItemTools", function()
    for args, expected in pairs(applyRangeTests) do
        it(string.format("tests applyRange('%s', %.2f, %.2f)", unpack(args)), function()
            local result = itemLib.applyRange(unpack(args))
            assert.are.equals(expected, result)
        end)
    end
end)