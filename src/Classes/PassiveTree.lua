-- Path of Building
--
-- Class: Passive Tree
-- Passive skill tree class.
-- Responsible for downloading and loading the passive tree data and assets
-- Also pre-calculates and pre-parses most of the data need to use the passive tree, including the node modifiers
--
local pairs = pairs
local ipairs = ipairs
local t_insert = table.insert
local t_remove = table.remove
local m_min = math.min
local m_max = math.max
local m_pi = math.pi
local m_rad = math.rad
local m_sin = math.sin
local m_cos = math.cos
local m_tan = math.tan
local m_sqrt = math.sqrt

local classArt = {
    [0] = "centerscion",
    [1] = "centermarauder",
    [2] = "centerranger",
    [3] = "centerwitch",
    [4] = "centerduelist",
    [5] = "centertemplar",
    [6] = "centershadow"
}

-- These values are from the 3.6 tree; older trees are missing values for these constants
local legacySkillsPerOrbit = { 1, 6, 12, 12, 40 }
local legacyOrbitRadii = { 0, 82, 162, 335, 493 }

-- Retrieve the file at the given URL
local function getFile(URL)
    local page = ""
    local easy = common.curl.easy()
    easy:setopt_url(URL)
    easy:setopt_writefunction(function(data)
        page = page .. data
        return true
    end)
    easy:perform()
    easy:close()
    return #page > 0 and page
end

local PassiveTreeClass = newClass("PassiveTree", function(self, treeVersion)
    self.treeVersion = treeVersion
    local versionNum = treeVersions[treeVersion].num

    MakeDir("TreeData")

    ConPrintf("Loading passive tree data for version '%s'...", treeVersions[treeVersion].display)
    local treeText
    local treeFile = io.open("TreeData/" .. treeVersion .. "/tree.lua", "r")
    if treeFile then
        treeText = treeFile:read("*a")
        treeFile:close()
    else
        ConPrintf("Downloading passive tree data...")
        local page
        local pageFile = io.open("TreeData/" .. treeVersion .. "/data.json", "r")
        if pageFile then
            page = pageFile:read("*a")
            pageFile:close()
        else
            page = getFile("https://www.pathofexile.com/passive-skill-tree")
        end
        local treeData = page:match("var passiveSkillTreeData = (%b{})")
        if treeData then
            treeText = "local tree=" .. jsonToLua(page:match("var passiveSkillTreeData = (%b{})"))
            treeText = treeText .. "return tree"
        else
            treeText = "return " .. jsonToLua(page)
        end
        treeFile = io.open("TreeData/" .. treeVersion .. "/tree.lua", "w")
        treeFile:write(treeText)
        treeFile:close()
    end
    for k, v in pairs(assert(loadstring(treeText))()) do
        self[k] = v
    end

    function table.merge(t1, t2)
        for k,v in ipairs(t2) do
            table.insert(t1, v)
        end

        return t1
    end

    -- Add json data from game files extracts
    self.nodes = {}
    self.classes = {}
    local minAbilityPosY = 0
    local maxAbilityPosY = 0
    for i = 0, 4 do
        local treeData = readJsonFile("TreeData/" .. treeVersion .. "/tree_" .. i .. ".json")
        for k,v in pairs(treeData["nodes"]) do
            self.nodes[k] = v
            if not k:match('^[A-Z]') then
                if v.y and maxAbilityPosY < v.y then
                    maxAbilityPosY = v.y
                end
                if v.y and minAbilityPosY > v.y then
                    minAbilityPosY = v.y
                end
                self.nodes[k].skillId = k:match("^[^-]+")
            end
        end
        for k,v in pairs(treeData["classes"]) do
            table.insert(self.classes, v)
        end
    end

    self.decAbilityPosY = (maxAbilityPosY - minAbilityPosY)

    local cdnRoot = ""

    self.size = m_min(self.max_x - self.min_x, self.max_y - self.min_y) * 1.1

    -- Migrate to old format
    for i = 0, 6 do
        self.classes[i] = self.classes[i + 1]
        self.classes[i + 1] = nil
    end

    -- Build maps of class name -> class table
    self.classNameMap = { }
    self.ascendNameMap = { }
    self.classNotables = { }

    for classId, class in pairs(self.classes) do
        -- Migrate to old format
        class.classes = class.ascendancies
        class.classes[0] = { name = "None" }
        self.classNameMap[class.name] = classId
        for ascendClassId, ascendClass in pairs(class.classes) do
            self.ascendNameMap[ascendClass.name] = {
                classId = classId,
                class = class,
                ascendClassId = ascendClassId,
                ascendClass = ascendClass
            }
        end
    end

    if self.alternate_ascendancies then
        self.secondaryAscendNameMap = { }
        local alternate_ascendancies_class = {
            ["name"] = "alternate_ascendancies",
            ["classes"] = self.alternate_ascendancies
        }
        for ascendClassId, ascendClass in pairs(self.alternate_ascendancies) do
            self.ascendNameMap[ascendClass.id] = {
                classId = "alternate_ascendancies",
                class = alternate_ascendancies_class,
                ascendClassId = ascendClassId,
                ascendClass = ascendClass
            }
            self.secondaryAscendNameMap[ascendClass.id] = self.ascendNameMap[ascendClass.id]
        end
    end

    self.skillsPerOrbit = self.constants.skillsPerOrbit or legacySkillsPerOrbit
    self.orbitRadii = self.constants.orbitRadii or legacyOrbitRadii
    self.orbitAnglesByOrbit = {}
    for orbit, skillsInOrbit in ipairs(self.skillsPerOrbit) do
        self.orbitAnglesByOrbit[orbit] = self:CalcOrbitAngles(skillsInOrbit)
    end

    ConPrintf("Loading passive tree assets...")
    for name, data in pairs(self.assets) do
        self:LoadImage(name .. ".png", cdnRoot .. (data[0.3835] or data[1]), data, not name:match("[OL][ri][bn][ie][tC]") and "ASYNC" or nil)--, not name:match("[OL][ri][bn][ie][tC]") and "MIPMAP" or nil)
    end

    -- Load sprite sheets and build sprite map
    self.spriteMap = { }
    local spriteSheets = { }
    for type, data in pairs(self.skillSprites) do
        local maxZoom = data[#data]
        maxZoom = data[0.3835] or data[1]
        local sheet = spriteSheets[maxZoom.filename]
        if not sheet then
            sheet = { }
            self:LoadImage(maxZoom.filename:gsub("%?%x+$", ""):gsub(".*/", "") or maxZoom.filename:gsub("%?%x+$", ""), maxZoom.filename or "https://web.poecdn.com" .. (self.imageRoot or "/image/") .. ("passive-skill/" or "build-gen/passive-skill-sprite/") .. maxZoom.filename, sheet, "CLAMP")--, "MIPMAP")
            spriteSheets[maxZoom.filename] = sheet
        end
        for name, coords in pairs(maxZoom.coords) do
            if not self.spriteMap[name] then
                self.spriteMap[name] = { }
            end
            self.spriteMap[name][type] = {
                handle = sheet.handle,
                width = coords.w,
                height = coords.h,
                [1] = coords.x / sheet.width,
                [2] = coords.y / sheet.height,
                [3] = (coords.x + coords.w) / sheet.width,
                [4] = (coords.y + coords.h) / sheet.height
            }
        end
    end

    local classArt = {
        [0] = "centerscion",
        [1] = "centermarauder",
        [2] = "centerranger",
        [3] = "centerwitch",
        [4] = "centerduelist",
        [5] = "centertemplar",
        [6] = "centershadow"
    }
    self.nodeOverlay = {
        Normal = {
            artWidth = 40,
            alloc = "PSSkillFrameActive",
            path = "PSSkillFrameHighlighted",
            unalloc = "PSSkillFrame",
            allocAscend = "AscendancyFrameSmallAllocated",
            pathAscend = "AscendancyFrameSmallCanAllocate",
            unallocAscend = "AscendancyFrameSmallNormal"
        },
        Notable = {
            artWidth = 58,
            alloc = "NotableFrameAllocated",
            path = "NotableFrameCanAllocate",
            unalloc = "NotableFrameUnallocated",
            allocAscend = "AscendancyFrameLargeAllocated",
            pathAscend = "AscendancyFrameLargeCanAllocate",
            unallocAscend = "AscendancyFrameLargeNormal",
            allocBlighted = "BlightedNotableFrameAllocated",
            pathBlighted = "BlightedNotableFrameCanAllocate",
            unallocBlighted = "BlightedNotableFrameUnallocated",
        },
        Keystone = {
            artWidth = 84,
            alloc = "KeystoneFrameAllocated",
            path = "KeystoneFrameCanAllocate",
            unalloc = "KeystoneFrameUnallocated"
        },
        Socket = {
            artWidth = 58,
            alloc = "JewelFrameAllocated",
            path = "JewelFrameCanAllocate",
            unalloc = "JewelFrameUnallocated",
            allocAlt = "JewelSocketAltActive",
            pathAlt = "JewelSocketAltCanAllocate",
            unallocAlt = "JewelSocketAltNormal",
        },
        Mastery = {
            artWidth = 65,
            alloc = "AscendancyFrameLargeAllocated",
            path = "AscendancyFrameLargeCanAllocate",
            unalloc = "AscendancyFrameLargeNormal"
        },
    }
    for type, data in pairs(self.nodeOverlay) do
        local size = data.artWidth * 1.33
        data.size = size
        data.rsq = size * size
    end

    -- Go away
    self.nodes.root = nil

    ConPrintf("Processing tree...")
    self.ascendancyMap = { }
    self.keystoneMap = { }
    self.notableMap = { }
    self.clusterNodeMap = { }
    self.sockets = { }
    self.masteryEffects = { }
    local nodeMap = { }
    for _, node in pairs(self.nodes) do
        node.alloc = 0
        -- Migration...
        -- To old format
        node.id = node.skill
        node.g = node.group
        node.o = node.orbit
        node.oidx = node.orbitIndex
        node.dn = node.name
        node.sd = node.stats
        node.passivePointsGranted = node.grantedPassivePoints or 0

        node.__index = node
        node.linkedId = { }
        nodeMap[node.id] = node

        -- Determine node type
        if node.classStartIndex then
            node.type = "ClassStart"
            local class = self.classes[node.classStartIndex]
            class.startNodeId = node.id
            node.startArt = classArt[node.classStartIndex]
        elseif node.isAscendancyStart then
            node.type = "AscendClassStart"
            local ascendClass = self.ascendNameMap[node.ascendancyName].ascendClass
            ascendClass.startNodeId = node.id
        elseif node.m or node.isMastery then
            node.type = "Mastery"
            if node.masteryEffects then
                for _, effect in pairs(node.masteryEffects) do
                    if not self.masteryEffects[effect.effect] then
                        self.masteryEffects[effect.effect] = { id = effect.effect, sd = effect.stats }
                        self:ProcessStats(self.masteryEffects[effect.effect])
                    else
                        -- Copy multiline stats from an earlier ProcessStats call
                        effect.stats = self.masteryEffects[effect.effect].sd
                    end
                end
            end
        elseif node.isJewelSocket then
            node.type = "Socket"
            self.sockets[node.id] = node
        elseif node.ks or node.isKeystone then
            node.type = "Keystone"
            self.keystoneMap[node.dn] = node
            self.keystoneMap[node.dn:lower()] = node
        elseif node["not"] or node.isNotable then
            node.type = "Notable"
            if not node.ascendancyName then
                -- Some nodes have duplicate names in the tree data for some reason, even though they're not on the tree
                -- Only add them if they're actually part of a group (i.e. in the tree)
                -- Add everything otherwise, because cluster jewel notables don't have a group
                if not self.notableMap[node.dn:lower()] then
                    self.notableMap[node.dn:lower()] = node
                elseif node.g then
                    self.notableMap[node.dn:lower()] = node
                end
            else
                self.ascendancyMap[node.dn:lower()] = node
                if not self.classNotables[self.ascendNameMap[node.ascendancyName].class.name] then
                    self.classNotables[self.ascendNameMap[node.ascendancyName].class.name] = { }
                end
                if self.ascendNameMap[node.ascendancyName].class.name ~= "Scion" then
                    t_insert(self.classNotables[self.ascendNameMap[node.ascendancyName].class.name], node.dn)
                end
            end
        else
            node.type = "Normal"
        end

        self:ProcessNode(node)
    end

    -- Pregenerate the polygons for the node connector lines
    self.connectors = { }
    for _, node in pairs(self.nodes) do
        for _, otherId in pairs(node.out or {}) do
            local other = nodeMap[otherId]
            t_insert(node.linkedId, otherId)
            if node.type ~= "ClassStart" and other.type ~= "ClassStart"
                    and node.type ~= "Mastery" and other.type ~= "Mastery"
                    and node.ascendancyName == other.ascendancyName
                    and not node.isProxy and not other.isProxy then
                local connectors = self:BuildConnector(node, other)
                t_insert(self.connectors, connectors[1])
                if connectors[2] then
                    t_insert(self.connectors, connectors[2])
                end
            end
        end
        for _, otherId in pairs(node["in"] or {}) do
            t_insert(node.linkedId, otherId)
        end
    end

    -- Precalculate the lists of nodes that are within each radius of each socket
    for nodeId, socket in pairs(self.sockets) do
        if socket.name == "Charm Socket" then
            socket.charmSocket = true
        else
            socket.nodesInRadius = { }
            socket.attributesInRadius = { }
            for radiusIndex, _ in ipairs(data.jewelRadius) do
                socket.nodesInRadius[radiusIndex] = { }
                socket.attributesInRadius[radiusIndex] = { }
            end

            local minX, maxX = socket.x - data.maxJewelRadius, socket.x + data.maxJewelRadius
            local minY, maxY = socket.y - data.maxJewelRadius, socket.y + data.maxJewelRadius

            for _, node in pairs(self.nodes) do
                if node.x and node.x >= minX and node.x <= maxX and node.y and node.y >= minY and node.y <= maxY
                        and node ~= socket and not node.isBlighted and node.group and not node.isProxy
                        and not node.group.isProxy and not node.isMastery then
                    local vX, vY = node.x - socket.x, node.y - socket.y
                    local distSquared = vX * vX + vY * vY
                    for radiusIndex, radiusInfo in ipairs(data.jewelRadius) do
                        if distSquared <= radiusInfo.outerSquared and radiusInfo.innerSquared <= distSquared then
                            socket.nodesInRadius[radiusIndex][node.id] = node
                        end
                    end
                end
            end
        end
    end

    for name, keystone in pairs(self.keystoneMap) do
        if not keystone.nodesInRadius then
            keystone.nodesInRadius = { }
            for radiusIndex, _ in ipairs(data.jewelRadius) do
                keystone.nodesInRadius[radiusIndex] = { }
            end

            if (keystone.x and keystone.y) then
                local minX, maxX = keystone.x - data.maxJewelRadius, keystone.x + data.maxJewelRadius
                local minY, maxY = keystone.y - data.maxJewelRadius, keystone.y + data.maxJewelRadius

                for _, node in pairs(self.nodes) do
                    if node.x and node.x >= minX and node.x <= maxX and node.y and node.y >= minY and node.y <= maxY
                            and node ~= keystone and not node.isBlighted and node.group and not node.isProxy
                            and not node.group.isProxy and not node.isMastery and not node.isSocket then
                        local vX, vY = node.x - keystone.x, node.y - keystone.y
                        local distSquared = vX * vX + vY * vY
                        for radiusIndex, radiusInfo in ipairs(data.jewelRadius) do
                            if distSquared <= radiusInfo.outerSquared and radiusInfo.innerSquared <= distSquared then
                                keystone.nodesInRadius[radiusIndex][node.id] = node
                            end
                        end
                    end
                end
            end
        end
    end

    for classId, class in pairs(self.classes) do
        local startNode = nodeMap[class.startNodeId]
        for _, nodeId in ipairs(startNode.linkedId) do
            local node = nodeMap[nodeId]
            if node.type == "Normal" then
                node.modList:NewMod("Condition:ConnectedTo" .. class.name .. "Start", "FLAG", true, "Tree:" .. nodeId)
            end
        end
    end
end)

function PassiveTreeClass:ProcessStats(node, startIndex)
    startIndex = startIndex or 1
    if startIndex == 1 then
        node.modKey = ""
        node.mods = { }
        node.modList = new("ModList")
    end

    node.sd = {}
    if node.stats then
        for _, stat in ipairs(node.stats) do
            if node.alloc > 1 and stat:match("%d") then
                stat = stat:gsub("(%d[%d.]*)", function(valueStr)
                    value = tonumber(valueStr)
                    return tostring(value * node.alloc)
                end)
            end
            table.insert(node.sd, stat)
        end
    end
    if node.noScalingPointThreshold and node.alloc >= node.noScalingPointThreshold then
        for _,stat in ipairs(node.notScalingStats) do
            table.insert(node.sd, stat)
        end
    end

    if not node.sd then
        return
    end

    -- Parse node modifier lines
    local i = startIndex
    while node.sd[i] do
        if node.sd[i]:match("\n") then
            local line = node.sd[i]
            local il = i
            t_remove(node.sd, i)
            for line in line:gmatch("[^\n]+") do
                t_insert(node.sd, il, line)
                il = il + 1
            end
        end
        local line = node.sd[i]
        local list, extra = modLib.parseMod(line)
        if not list then
            -- Parser had no idea how to read this modifier
            node.unknown = true
        elseif extra then
            -- Parser recognised this as a modifier but couldn't understand all of it
            node.extra = true
        else
            for _, mod in ipairs(list) do
                node.modKey = node.modKey .. "[" .. modLib.formatMod(mod) .. "]"
            end
        end
        node.mods[i] = { list = list, extra = extra }
        i = i + 1
        while node.mods[i] do
            -- Skip any lines with dummy lists added by the line combining code
            i = i + 1
        end
    end

    -- Build unified list of modifiers from all recognised modifier lines
    for i = startIndex, #node.mods do
        local mod = node.mods[i]
        if mod.list and not mod.extra then
            for i, mod in ipairs(mod.list) do
                mod = modLib.setSource(mod, "Tree:" .. node.id)
                if node.skillId then
                    table.insert(mod, {type = "SkillId", skillId = node.skillId})
                end
                if node.alloc > 1 then
                    if type(mod.value) == "table" then
                        for _, mod in ipairs(mod.value) do
                            mod.value = mod.value
                        end
                    else
                        mod.value = mod.value
                    end
                end
                node.modList:AddMod(mod)
            end
        end
    end
    if node.type == "Keystone" then
        node.keystoneMod = modLib.createMod("Keystone", "LIST", node.dn, "Tree" .. node.id)
    end
end

-- Common processing code for nodes (used for both real tree nodes and subgraph nodes)
function PassiveTreeClass:ProcessNode(node)
    -- Assign node artwork assets
    if node.type == "Mastery" and node.masteryEffects then
        node.masterySprites = { activeIcon = self.spriteMap[node.activeIcon], inactiveIcon = self.spriteMap[node.inactiveIcon], activeEffectImage = self.spriteMap[node.activeEffectImage] }
    else
        node.sprites = self.spriteMap[node.icon]
    end
    if not node.sprites then
        --error("missing sprite "..node.icon)
        node.sprites = self.spriteMap["Art/2DArt/SkillIcons/passives/MasteryBlank.png"]
    end
    node.overlay = self.nodeOverlay[node.type]
    if node.overlay then
        node.rsq = node.overlay.rsq
        node.size = node.overlay.size
    end

    -- Derive the true position of the node
    if node.group then
        node.angle = self.orbitAnglesByOrbit[node.o + 1][node.oidx + 1]
        local orbitRadius = self.orbitRadii[node.o + 1]
        node.x = node.group.x + m_sin(node.angle) * orbitRadius
        node.y = node.group.y - m_cos(node.angle) * orbitRadius
    end

    self:ProcessStats(node)
end

-- Checks if a given image is present and downloads it from the given URL if it isn't there
function PassiveTreeClass:LoadImage(imgName, url, data, ...)
    local imgFile = io.open("TreeData/" .. imgName, "r")
    if imgFile then
        imgFile:close()
    else
        imgFile = io.open("TreeData/" .. self.treeVersion .. "/" .. imgName, "r")
        if imgFile then
            imgFile:close()
            imgName = self.treeVersion .. "/" .. imgName
        elseif main.allowTreeDownload then
            -- Enable downloading with Ctrl+Shift+F5
            ConPrintf("Downloading '%s'...", imgName)
            local data = getFile(url)
            if data and not data:match("<!DOCTYPE html>") then
                imgFile = io.open("TreeData/" .. imgName, "wb")
                imgFile:write(data)
                imgFile:close()
            else
                ConPrintf("Failed to download: %s", url)
            end
        end
    end
    data.handle = NewImageHandle()
    data.handle:Load("TreeData/" .. imgName, ...)
    data.width, data.height = data.handle:ImageSize()
end

-- Generate the quad used to render the line between the two given nodes
function PassiveTreeClass:BuildConnector(node1, node2)
    local connector = {
        ascendancyName = node1.ascendancyName,
        nodeId1 = node1.id,
        nodeId2 = node2.id,
        c = { } -- This array will contain the quad's data: 1-8 are the vertex coordinates, 9-16 are the texture coordinates
        -- Only the texture coords are filled in at this time; the vertex coords need to be converted from tree-space to screen-space first
        -- This will occur when the tree is being drawn; .vert will map line state (Normal/Intermediate/Active) to the correct tree-space coordinates
    }
    -- Generate a straight line
    connector.type = "LineConnector"
    local art = self.assets.LineConnectorNormal
    local vX, vY = node2.x - node1.x, node2.y - node1.y
    local dist = m_sqrt(vX * vX + vY * vY)
    local scale = art.height * 1.33 / dist
    local nX, nY = vX * scale, vY * scale
    local endS = dist / (art.width * 1.33)
    connector[1], connector[2] = node1.x - nY, node1.y + nX
    connector[3], connector[4] = node1.x + nY, node1.y - nX
    connector[5], connector[6] = node2.x + nY, node2.y - nX
    connector[7], connector[8] = node2.x - nY, node2.y + nX
    connector.c[9], connector.c[10] = 0, 1
    connector.c[11], connector.c[12] = 0, 0
    connector.c[13], connector.c[14] = endS, 0
    connector.c[15], connector.c[16] = endS, 1
    connector.vert = { Normal = connector, Intermediate = connector, Active = connector }
    return { connector }
end

function PassiveTreeClass:BuildArc(arcAngle, node1, connector, isMirroredArc)
    connector.type = "Orbit" .. node1.o
    -- This is an arc texture mapped onto a kite-shaped quad
    -- Calculate how much the arc needs to be clipped by
    -- Both ends of the arc will be clipped by this amount, so 90 degree arc angle = no clipping and 30 degree arc angle = 75 degrees of clipping
    -- The clipping is accomplished by effectively moving the bottom left and top right corners of the arc texture towards the top left corner
    -- The arc texture only shows 90 degrees of an arc, but some arcs must go for more than 90 degrees
    -- Fortunately there's nowhere on the tree where we can't just show the middle 90 degrees and rely on the node artwork to cover the gaps :)
    local clipAngle = m_pi / 4 - arcAngle / 2
    local p = 1 - m_max(m_tan(clipAngle), 0)
    local angle = node1.angle - clipAngle
    if isMirroredArc then
        -- The center of the mirrored angle should be positioned at 75% of the way between nodes.
        angle = angle + arcAngle
    end
    connector.vert = { }
    for _, state in pairs({ "Normal", "Intermediate", "Active" }) do
        -- The different line states have differently-sized artwork, so the vertex coords must be calculated separately for each one
        local art = self.assets[connector.type .. state]
        local size = art.width * 2 * 1.33
        local oX, oY = size * m_sqrt(2) * m_sin(angle + m_pi / 4), size * m_sqrt(2) * -m_cos(angle + m_pi / 4)
        local cX, cY = node1.group.x + oX, node1.group.y + oY
        local vert = { }
        vert[1], vert[2] = node1.group.x, node1.group.y
        vert[3], vert[4] = cX + (size * m_sin(angle) - oX) * p, cY + (size * -m_cos(angle) - oY) * p
        vert[5], vert[6] = cX, cY
        vert[7], vert[8] = cX + (size * m_cos(angle) - oX) * p, cY + (size * m_sin(angle) - oY) * p
        if (isMirroredArc) then
            -- Flip the quad's non-origin, non-center vertexes when drawing a mirrored arc so that the arc actually mirrored
            -- This is required to prevent the connection of the 2 arcs appear to have a 'seam'
            local temp1, temp2 = vert[3], vert[4]
            vert[3], vert[4] = vert[7], vert[8]
            vert[7], vert[8] = temp1, temp2
        end
        connector.vert[state] = vert
    end
    connector.c[9], connector.c[10] = 1, 1
    connector.c[11], connector.c[12] = 0, p
    connector.c[13], connector.c[14] = 0, 0
    connector.c[15], connector.c[16] = p, 0
end

function PassiveTreeClass:CalcOrbitAngles(nodesInOrbit)
    local orbitAngles = {}

    if nodesInOrbit == 16 then
        -- Every 30 and 45 degrees, per https://github.com/grindinggear/skilltree-export/blob/3.17.0/README.md
        orbitAngles = { 0, 30, 45, 60, 90, 120, 135, 150, 180, 210, 225, 240, 270, 300, 315, 330 }
    elseif nodesInOrbit == 40 then
        -- Every 10 and 45 degrees
        orbitAngles = { 0, 10, 20, 30, 40, 45, 50, 60, 70, 80, 90, 100, 110, 120, 130, 135, 140, 150, 160, 170, 180, 190, 200, 210, 220, 225, 230, 240, 250, 260, 270, 280, 290, 300, 310, 315, 320, 330, 340, 350 }
    else
        -- Uniformly spaced
        for i = 0, nodesInOrbit do
            orbitAngles[i + 1] = 360 * i / nodesInOrbit
        end
    end

    for i, degrees in ipairs(orbitAngles) do
        orbitAngles[i] = m_rad(degrees)
    end

    return orbitAngles
end
