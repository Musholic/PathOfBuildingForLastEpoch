-- Path of Building
--
-- Module: Tree Tab
-- Passive skill tree tab for the current build.
--
local ipairs = ipairs
local pairs = pairs
local next = next
local t_insert = table.insert
local t_remove = table.remove
local t_sort = table.sort
local t_concat = table.concat
local m_max = math.max
local m_min = math.min
local m_floor = math.floor
local m_abs = math.abs
local s_format = string.format
local s_gsub = string.gsub
local s_byte = string.byte
local dkjson = require "dkjson"

local TreeTabClass = newClass("TreeTab", "ControlHost", function(self, build)
	self.ControlHost()

	self.build = build
	self.isComparing = false;

	self.viewer = new("PassiveTreeView")

	self.specList = { }
	self.specList[1] = new("PassiveSpec", build, latestTreeVersion)
	self:SetActiveSpec(1)
	self:SetCompareSpec(1)

	self.anchorControls = new("Control", nil, 0, 0, 0, 20)

	-- Tree list dropdown
	self.controls.specSelect = new("DropDownControl", {"LEFT",self.anchorControls,"RIGHT"}, 0, 0, 190, 20, nil, function(index, value)
		if self.specList[index] then
			self.build.modFlag = true
			self:SetActiveSpec(index)
		else
			self:OpenSpecManagePopup()
		end
	end)
	self.controls.specSelect.maxDroppedWidth = 1000
	self.controls.specSelect.enableDroppedWidth = true
	self.controls.specSelect.enableChangeBoxWidth = true
	self.controls.specSelect.controls.scrollBar.enabled = true
	self.controls.specSelect.tooltipFunc = function(tooltip, mode, selIndex, selVal)
		tooltip:Clear()
		if mode ~= "OUT" then
			local spec = self.specList[selIndex]
			if spec then
				local used = spec:CountAllocNodes()
				tooltip:AddLine(16, "Class: "..spec.curClassName)
				tooltip:AddLine(16, "Points used: "..used)
				if selIndex ~= self.activeSpec then
					local calcFunc, calcBase = self.build.calcsTab:GetMiscCalculator()
					if calcFunc then
						local output = calcFunc({ spec = spec }, {})
						self.build:AddStatComparesToTooltip(tooltip, calcBase, output, "^7Switching to this tree will give you:")
					end
				end
				tooltip:AddLine(16, "Game Version: "..treeVersions[spec.treeVersion].display)
			end
		end
	end

	-- Compare checkbox
	self.controls.compareCheck = new("CheckBoxControl", { "LEFT", self.controls.specSelect, "RIGHT" }, 74, 0, 20, "Compare:", function(state)
		self.isComparing = state
		self:SetCompareSpec(self.activeCompareSpec)
		self.controls.compareSelect.shown = state
		if state then
			self.controls.reset:SetAnchor("LEFT", self.controls.compareSelect, "RIGHT", nil, nil, nil)
		else
			self.controls.reset:SetAnchor("LEFT", self.controls.compareCheck, "RIGHT", nil, nil, nil)
		end
	end)

	-- Compare tree dropdown
	self.controls.compareSelect = new("DropDownControl", { "LEFT", self.controls.compareCheck, "RIGHT" }, 8, 0, 190, 20, nil, function(index, value)
		if self.specList[index] then
			self:SetCompareSpec(index)
		end
	end)
	self.controls.compareSelect.shown = false
	self.controls.compareSelect.maxDroppedWidth = 1000
	self.controls.compareSelect.enableDroppedWidth = true
	self.controls.compareSelect.enableChangeBoxWidth = true
	self.controls.reset = new("ButtonControl", { "LEFT", self.controls.compareCheck, "RIGHT" }, 8, 0, 60, 20, "Reset", function()
		main:OpenConfirmPopup("Reset Tree", "Are you sure you want to reset your passive tree?", "Reset", function()
			self.build.spec:ResetNodes()
			self.build.spec:BuildAllDependsAndPaths()
			self.build.spec:AddUndoState()
			self.build.buildFlag = true
		end)
	end)

	-- Tree Version Dropdown
	self.treeVersions = { }
	for _, num in ipairs(treeVersionList) do
		t_insert(self.treeVersions, treeVersions[num].display)
	end
	self.controls.versionText = new("LabelControl", { "LEFT", self.controls.reset, "RIGHT" }, 8, 0, 0, 16, "Version:")
	self.controls.versionSelect = new("DropDownControl", { "LEFT", self.controls.versionText, "RIGHT" }, 8, 0, 100, 20, self.treeVersions, function(index, value)
		if value ~= self.build.spec.treeVersion then
			self:OpenVersionConvertPopup(value:gsub("[%(%)]", ""):gsub("[%.%s]", "_"), true)
		end
	end)
	self.controls.versionSelect.maxDroppedWidth = 1000
	self.controls.versionSelect.enableDroppedWidth = true
	self.controls.versionSelect.enableChangeBoxWidth = true
	self.controls.versionSelect.selIndex = #self.treeVersions

	-- Tree Search Textbox
	self.controls.treeSearch = new("EditControl", { "LEFT", self.controls.versionSelect, "RIGHT" }, 8, 0, main.portraitMode and 200 or 300, 20, "", "Search", "%c", 100, function(buf)
		self.viewer.searchStr = buf
		self.searchFlag = buf ~= self.viewer.searchStrSaved
	end, nil, nil, true)
	self.controls.treeSearch.tooltipText = "Uses Lua pattern matching for complex searches"

	self.tradeLeaguesList = { }

	-- Show Node Power Checkbox
	self.controls.treeHeatMap = new("CheckBoxControl", { "LEFT", self.controls.treeSearch, "RIGHT" }, 130, 0, 20, "Show Node Power:", function(state)
		self.viewer.showHeatMap = state
		self.controls.treeHeatMapStatSelect.shown = state

		if state == false then
			self.controls.powerReportList.shown = false 
		end
	end)

	-- Control for setting max node depth to limit calculation time of the heat map
	self.controls.nodePowerMaxDepthSelect = new("DropDownControl",
	{ "LEFT", self.controls.treeHeatMap, "RIGHT" }, 8, 0, 50, 20, { "All", 5, 10, 15 }, function(index, value)
		local oldMax = self.build.calcsTab.nodePowerMaxDepth

		if type(value) == "number" then
			self.build.calcsTab.nodePowerMaxDepth = value
		else
			self.build.calcsTab.nodePowerMaxDepth = nil
		end

		-- If the heat map is shown, tell it to recalculate
		-- if the new value is larger than the old
		if oldMax ~= value and self.viewer.showHeatMap then
			if oldMax ~= nil and (self.build.calcsTab.nodePowerMaxDepth == nil or self.build.calcsTab.nodePowerMaxDepth > oldMax) then
				self:SetPowerCalc(self.build.calcsTab.powerStat)
			end
		end
	end)
	self.controls.nodePowerMaxDepthSelect.tooltipText = "Limit of Node distance to search (lower = faster)"

	-- Control for selecting the power stat to sort by (Defense, DPS, etc)
	self.controls.treeHeatMapStatSelect = new("DropDownControl", { "LEFT", self.controls.nodePowerMaxDepthSelect, "RIGHT" }, 8, 0, 150, 20, nil, function(index, value)
		self:SetPowerCalc(value)
	end)
	self.controls.treeHeatMap.tooltipText = function()
		local offCol, defCol = main.nodePowerTheme:match("(%a+)/(%a+)")
		return "When enabled, an estimate of the offensive and defensive strength of\neach unallocated passive is calculated and displayed visually.\nOffensive power shows as "..offCol:lower()..", defensive power as "..defCol:lower().."."
	end

	self.powerStatList = { }
	for _, stat in ipairs(data.powerStatList) do
		if not stat.ignoreForNodes then
			t_insert(self.powerStatList, stat)
		end
	end

	-- Show/Hide Power Report Button
	self.controls.powerReport = new("ButtonControl", { "LEFT", self.controls.treeHeatMapStatSelect, "RIGHT" }, 8, 0, 150, 20,
		function() return self.controls.powerReportList.shown and "Hide Power Report" or "Show Power Report" end, function()
		self.controls.powerReportList.shown = not self.controls.powerReportList.shown
	end)

	-- Power Report List
	local yPos = self.controls.treeHeatMap.y == 0 and self.controls.specSelect.height + 4 or self.controls.specSelect.height * 2 + 8
	self.controls.powerReportList = new("PowerReportListControl", {"TOPLEFT", self.controls.specSelect, "BOTTOMLEFT"}, 0, yPos, 700, 220, function(selectedNode)
		-- this code is called by the list control when the user "selects" one of the passives in the list.
		-- we use this to set a flag which causes the next Draw() to recenter the passive tree on the desired node.
		if selectedNode.x then
			self.jumpToNode = true
			self.jumpToX = selectedNode.x
			self.jumpToY = selectedNode.y
		end
	end)
	self.controls.powerReportList.shown = false
	self.build.powerBuilderCallback = function()
		local powerStat = self.build.calcsTab.powerStat or data.powerStatList[1]
		local report = self:BuildPowerReportList(powerStat)
		self.controls.powerReportList:SetReport(powerStat, report)
	end

	self.controls.specConvertText = new("LabelControl", { "BOTTOMLEFT", self.controls.specSelect, "TOPLEFT" }, 0, -14, 0, 16, "^7This is an older tree version, which may not be fully compatible with the current game version.")
	self.controls.specConvertText.shown = function()
		return self.showConvert
	end
	local function getLatestTreeVersion()
		return latestTreeVersion .. (self.specList[self.activeSpec].treeVersion:match("^" .. latestTreeVersion .. "(.*)") or "")
	end
	local function buildConvertButtonLabel()
		return colorCodes.POSITIVE.."Convert to "..treeVersions[getLatestTreeVersion()].display
	end
	local function buildConvertAllButtonLabel()
		return colorCodes.POSITIVE.."Convert all trees to "..treeVersions[getLatestTreeVersion()].display
	end
	self.controls.specConvert = new("ButtonControl", { "LEFT", self.controls.specConvertText, "RIGHT" }, 8, 0, function() return DrawStringWidth(16, "VAR", buildConvertButtonLabel()) + 20 end, 20, buildConvertButtonLabel, function()
		self:ConvertToVersion(getLatestTreeVersion(), false, true)
	end)
	self.controls.specConvertAll = new("ButtonControl", { "LEFT", self.controls.specConvert, "RIGHT" }, 8, 0, function() return DrawStringWidth(16, "VAR", buildConvertAllButtonLabel()) + 20 end, 20, buildConvertAllButtonLabel, function()
		self:OpenVersionConvertAllPopup(getLatestTreeVersion())
	end)
	self.jumpToNode = false
	self.jumpToX = 0
	self.jumpToY = 0
end)

function TreeTabClass:Draw(viewPort, inputEvents)
	self.anchorControls.x = viewPort.x + 4
	self.anchorControls.y = viewPort.y + viewPort.height - 24

	for id, event in ipairs(inputEvents) do
		if event.type == "KeyDown" then
			if event.key == "z" and IsKeyDown("CTRL") then
				self.build.spec:Undo()
				self.build.buildFlag = true
				inputEvents[id] = nil
			elseif event.key == "y" and IsKeyDown("CTRL") then
				self.build.spec:Redo()
				self.build.buildFlag = true
				inputEvents[id] = nil
			elseif event.key == "f" and IsKeyDown("CTRL") then
				self:SelectControl(self.controls.treeSearch)
			elseif event.key == "m" and IsKeyDown("CTRL") then
				self:OpenSpecManagePopup()
			end
		end
	end
	self:ProcessControlsInput(inputEvents, viewPort)

	-- Determine positions if one line of controls doesn't fit in the screen width
	local twoLineHeight = 24
	if viewPort.width >= 1336 + (self.isComparing and 198 or 0) + (self.viewer.showHeatMap and 316 or 0) then
		twoLineHeight = 0
		self.controls.treeSearch:SetAnchor("LEFT", self.controls.versionSelect, "RIGHT", 8, 0)
		self.controls.powerReportList:SetAnchor("TOPLEFT", self.controls.specSelect, "BOTTOMLEFT", 0, self.controls.specSelect.height + 4)
	else
		self.controls.treeSearch:SetAnchor("TOPLEFT", self.controls.specSelect, "BOTTOMLEFT", 0, 4)
		self.controls.powerReportList:SetAnchor("TOPLEFT", self.controls.treeSearch, "BOTTOMLEFT", 0, self.controls.treeHeatMap.y + self.controls.treeHeatMap.height + 4)
	end
	-- determine positions for convert line of controls
	local convertTwoLineHeight = 24
	local convertMaxWidth = 900
	if viewPort.width >= convertMaxWidth then
		convertTwoLineHeight = 0
		self.controls.specConvert:SetAnchor("LEFT", self.controls.specConvertText, "RIGHT", 8, 0)
		self.controls.specConvertText:SetAnchor("BOTTOMLEFT", self.controls.specSelect, "TOPLEFT", 0, -14)
	else
		self.controls.specConvert:SetAnchor("TOPLEFT", self.controls.specConvertText, "BOTTOMLEFT", 0, 4)
		self.controls.specConvertText:SetAnchor("BOTTOMLEFT", self.controls.specSelect, "TOPLEFT", 0, -38)
	end

	local bottomDrawerHeight = self.controls.powerReportList.shown and 194 or 0
	self.controls.specSelect.y = -bottomDrawerHeight - twoLineHeight

	local treeViewPort = { x = viewPort.x, y = viewPort.y, width = viewPort.width, height = viewPort.height - (self.showConvert and 64 + bottomDrawerHeight + twoLineHeight or 32 + bottomDrawerHeight + twoLineHeight)}
	if self.jumpToNode then
		self.viewer:Focus(self.jumpToX, self.jumpToY, treeViewPort, self.build)
		self.jumpToNode = false
	end
	self.viewer.compareSpec = self.isComparing and self.specList[self.activeCompareSpec] or nil
	self.viewer:Draw(self.build, treeViewPort, inputEvents)

	local newSpecList = self:GetSpecList()
	self.controls.compareSelect.selIndex = self.activeCompareSpec
	self.controls.compareSelect:SetList(newSpecList)
	t_insert(newSpecList, "Manage trees... (ctrl-m)")
	self.controls.specSelect.selIndex = self.activeSpec
	self.controls.specSelect:SetList(newSpecList)

	if not self.controls.treeSearch.hasFocus then
		self.controls.treeSearch:SetText(self.viewer.searchStr)
	end

	self.controls.treeHeatMap.state = self.viewer.showHeatMap
	self.controls.treeHeatMapStatSelect.shown = self.viewer.showHeatMap
	self.controls.treeHeatMapStatSelect.list = self.powerStatList
	self.controls.treeHeatMapStatSelect.selIndex = 1
	self.controls.treeHeatMapStatSelect:CheckDroppedWidth(true)
	if self.build.calcsTab.powerStat then
		self.controls.treeHeatMapStatSelect:SelByValue(self.build.calcsTab.powerStat.stat, "stat")
	end

	SetDrawLayer(1)

	SetDrawColor(0.05, 0.05, 0.05)
	DrawImage(nil, viewPort.x, viewPort.y + viewPort.height - (28 + bottomDrawerHeight + twoLineHeight), viewPort.width, 28 + bottomDrawerHeight + twoLineHeight)
	if self.showConvert then
		local height = viewPort.width < convertMaxWidth and (bottomDrawerHeight + twoLineHeight) or 0
		SetDrawColor(0.05, 0.05, 0.05)
		DrawImage(nil, viewPort.x, viewPort.y + viewPort.height - (60 + bottomDrawerHeight + twoLineHeight + convertTwoLineHeight), viewPort.width, 28 + height)
		SetDrawColor(0.85, 0.85, 0.85)
		DrawImage(nil, viewPort.x, viewPort.y + viewPort.height - (64 + bottomDrawerHeight + twoLineHeight + convertTwoLineHeight), viewPort.width, 4)
	end
	-- let white lines overwrite the black sections, regardless of showConvert
	SetDrawColor(0.85, 0.85, 0.85)
	DrawImage(nil, viewPort.x, viewPort.y + viewPort.height - (32 + bottomDrawerHeight + twoLineHeight), viewPort.width, 4)

	self:DrawControls(viewPort)
end

function TreeTabClass:GetSpecList()
	local newSpecList = { }
	for _, spec in ipairs(self.specList) do
		t_insert(newSpecList, (spec.treeVersion ~= latestTreeVersion and ("["..treeVersions[spec.treeVersion].display.."] ") or "")..(spec.title or "Default"))
	end
	return newSpecList
end

function TreeTabClass:Load(xml, dbFileName)
	self.specList = { }
	if xml.elem == "Spec" then
		-- Import single spec from old build
		self.specList[1] = new("PassiveSpec", self.build, defaultTreeVersion)
		self.specList[1]:Load(xml, dbFileName)
		self.activeSpec = 1
		self.build.spec = self.specList[1]
		return
	end
	for _, node in pairs(xml) do
		if type(node) == "table" then
			if node.elem == "Spec" then
				if node.attrib.treeVersion and not treeVersions[node.attrib.treeVersion] then
					main:OpenMessagePopup("Unknown Passive Tree Version", "The build you are trying to load uses an unrecognised version of the passive skill tree.\nYou may need to update the program before loading this build.")
					return true
				end
				local newSpec = new("PassiveSpec", self.build, node.attrib.treeVersion or defaultTreeVersion)
				newSpec:Load(node, dbFileName)
				t_insert(self.specList, newSpec)
			end
		end
	end
	if not self.specList[1] then
		self.specList[1] = new("PassiveSpec", self.build, latestTreeVersion)
	end
	self:SetActiveSpec(tonumber(xml.attrib.activeSpec) or 1)
end

function TreeTabClass:PostLoad()
	for _, spec in ipairs(self.specList) do
		spec:PostLoad()
	end
end

function TreeTabClass:Save(xml)
	xml.attrib = {
		activeSpec = tostring(self.activeSpec)
	}
	for specId, spec in ipairs(self.specList) do
		local child = {
			elem = "Spec"
		}
		spec:Save(child)
		t_insert(xml, child)
	end
end

function TreeTabClass:SetActiveSpec(specId)
	local prevSpec = self.build.spec
	self.activeSpec = m_min(specId, #self.specList)
	local curSpec = self.specList[self.activeSpec]
	data.setJewelRadiiGlobally(curSpec.treeVersion)
	self.build.spec = curSpec
	self.build.buildFlag = true
	self.build.spec:SetWindowTitleWithBuildClass()
	for _, slot in pairs(self.build.itemsTab.slots) do
		if slot.nodeId then
			if prevSpec then
				-- Update the previous spec's jewel for this slot
				prevSpec.jewels[slot.nodeId] = slot.selItemId
			end
			if curSpec.jewels[slot.nodeId] then
				-- Socket the jewel for the new spec
				slot.selItemId = curSpec.jewels[slot.nodeId]
			else
				-- Unsocket the old jewel from the previous spec
				slot.selItemId = 0
			end
		end
	end
	self.showConvert = not curSpec.treeVersion:match("^" .. latestTreeVersion)
	if self.build.itemsTab.itemOrderList[1] then
		-- Update item slots if items have been loaded already
		self.build.itemsTab:PopulateSlots()
	end
	-- Update the passive tree dropdown control in itemsTab
	self.build.itemsTab.controls.specSelect.selIndex = specId
	-- Update Version dropdown to active spec's
	if self.controls.versionSelect then
		self.controls.versionSelect:SelByValue(curSpec.treeVersion:gsub("%_", "."):gsub(".ruthless", " (ruthless)"))
	end
end

function TreeTabClass:SetCompareSpec(specId)
	self.activeCompareSpec = m_min(specId, #self.specList)
	local curSpec = self.specList[self.activeCompareSpec]

	self.compareSpec = curSpec
end

function TreeTabClass:ConvertToVersion(version, remove, success, ignoreRuthlessCheck)
	if not ignoreRuthlessCheck and self.build.spec.treeVersion:match("ruthless") and not version:match("ruthless") then
		if isValueInTable(treeVersionList, version.."_ruthless") then
			version = version.."_ruthless"
		end
	end
	local newSpec = new("PassiveSpec", self.build, version)
	newSpec.title = self.build.spec.title
	newSpec.jewels = copyTable(self.build.spec.jewels)
	newSpec:RestoreUndoState(self.build.spec:CreateUndoState(), version)
	newSpec:BuildClusterJewelGraphs()
	t_insert(self.specList, self.activeSpec + 1, newSpec)
	if remove then
		t_remove(self.specList, self.activeSpec)
		-- activeSpec + 1 is shifted down one on remove, otherwise we would set the spec below it if it exists
		self:SetActiveSpec(self.activeSpec)
	else
		self:SetActiveSpec(self.activeSpec + 1)
	end
	self.modFlag = true
	if success then
		main:OpenMessagePopup("Tree Converted", "The tree has been converted to "..treeVersions[version].display..".\nNote that some or all of the passives may have been de-allocated due to changes in the tree.\n\nYou can switch back to the old tree using the tree selector at the bottom left.")
	end
end

function TreeTabClass:ConvertAllToVersion(version)
	local currActiveSpec = self.activeSpec
	local specVersionList = { }
	for _, spec in ipairs(self.specList) do
		t_insert(specVersionList, spec.treeVersion)
	end
	for index, specVersion in ipairs(specVersionList) do
		if specVersion ~= version then
			self:SetActiveSpec(index)
			self:ConvertToVersion(version, true, false)
		end
	end
	self:SetActiveSpec(currActiveSpec)
end

function TreeTabClass:OpenSpecManagePopup()
	local importTree =
		new("ButtonControl", nil, -99, 259, 90, 20, "Import Tree", function()
			self:OpenImportPopup()
		end)
	local exportTree =
		new("ButtonControl", { "LEFT", importTree, "RIGHT" }, 8, 0, 90, 20, "Export Tree", function()
			self:OpenExportPopup()
		end)

	main:OpenPopup(370, 290, "Manage Passive Trees", {
		new("PassiveSpecListControl", nil, 0, 50, 350, 200, self),
		importTree,
		exportTree,
		new("ButtonControl", {"LEFT", exportTree, "RIGHT"}, 8, 0, 90, 20, "Done", function()
			main:ClosePopup()
		end),
	})
end

function TreeTabClass:OpenVersionConvertPopup(version, ignoreRuthlessCheck)
	local controls = { }
	controls.warningLabel = new("LabelControl", nil, 0, 20, 0, 16, "^7Warning: some or all of the passives may be de-allocated due to changes in the tree.\n\n" ..
		"Convert will replace your current tree.\nCopy + Convert will backup your current tree.\n")
	controls.convert = new("ButtonControl", nil, -125, 105, 100, 20, "Convert", function()
		self:ConvertToVersion(version, true, false, ignoreRuthlessCheck)
		main:ClosePopup()
	end)
	controls.convertCopy = new("ButtonControl", nil, 0, 105, 125, 20, "Copy + Convert", function()
		self:ConvertToVersion(version, false, false, ignoreRuthlessCheck)
		main:ClosePopup()
	end)
	controls.cancel = new("ButtonControl", nil, 125, 105, 100, 20, "Cancel", function()
		main:ClosePopup()
	end)
	main:OpenPopup(570, 140, "Convert to Version "..treeVersions[version].display, controls, "convert", "edit")
end

function TreeTabClass:OpenVersionConvertAllPopup(version)
	local controls = { }
	controls.warningLabel = new("LabelControl", nil, 0, 20, 0, 16, "^7Warning: some or all of the passives may be de-allocated due to changes in the tree.\n\n" ..
		"Convert will replace all trees that are not Version "..treeVersions[version].display..".\nThis action cannot be undone.\n")
	controls.convert = new("ButtonControl", nil, -58, 105, 100, 20, "Convert", function()
		self:ConvertAllToVersion(version)
		main:ClosePopup()
	end)
	controls.cancel = new("ButtonControl", nil, 58, 105, 100, 20, "Cancel", function()
		main:ClosePopup()
	end)
	main:OpenPopup(570, 140, "Convert all to Version "..treeVersions[version].display, controls, "convert", "edit")
end

function TreeTabClass:OpenImportPopup()
	local versionLookup = "tree/([0-9]+)%.([0-9]+)%.([0-9]+)/"
	local controls = { }
	local function decodePoePlannerTreeLink(treeLink)
		-- treeVersion is not known at this point. We need to decode the URL to get it.
		local tmpSpec = new("PassiveSpec", self.build, latestTreeVersion)
		local newTreeVersion_or_errMsg = tmpSpec:DecodePoePlannerURL(treeLink, true)
		-- Check for an error message
		if string.find(newTreeVersion_or_errMsg, "Invalid") then
			controls.msg.label = "^1"..newTreeVersion_or_errMsg
			return
		end

		-- 20230908. We always create a new Spec()
		local newSpec = new("PassiveSpec", self.build, newTreeVersion_or_errMsg)
		newSpec.title = controls.name.buf
		newSpec:DecodePoePlannerURL(treeLink, false)  --DecodePoePlannerURL was used above and URL proven correct.
		t_insert(self.specList, newSpec)
		-- trigger all the things that go with changing a spec
		self:SetActiveSpec(#self.specList)
		self.modFlag = true
		self.build.spec:AddUndoState()
		self.build.buildFlag = true
		main:ClosePopup()
	end

	local function decodeTreeLink(treeLink, newTreeVersion)
		-- newTreeVersion is passed in as an output of validateTreeVersion(). It will always be a valid tree version text string
		-- 20230908. We always create a new Spec()
		local newSpec = new("PassiveSpec", self.build, newTreeVersion)
		newSpec.title = controls.name.buf
		local errMsg = newSpec:DecodeURL(treeLink)
		if errMsg then
			controls.msg.label = "^1"..errMsg.."^7"
		else
			t_insert(self.specList, newSpec)
			-- trigger all the things that go with changing a spec
			self:SetActiveSpec(#self.specList)
			self.modFlag = true
			self.build.spec:AddUndoState()
			self.build.buildFlag = true
			main:ClosePopup()
		end
	end
	local function validateTreeVersion(isRuthless, major, minor)
		-- Take the Major and Minor version numbers and confirm it is a valid tree version. The point release is also passed in but it is not used
		-- Return: the passed in tree version as text or latestTreeVersion
		if major and minor then
			--need leading 0 here
			local newTreeVersionNum = tonumber(string.format("%d.%02d", major, minor))
			if newTreeVersionNum >= treeVersions[defaultTreeVersion].num and newTreeVersionNum <= treeVersions[latestTreeVersion].num then
				-- no leading 0 here
				return string.format("%s_%s", major, minor) .. (isRuthless and "_ruthless" or "")
			else
				print(string.format("Version '%d_%02d' is out of bounds", major, minor))
			end
		end
		return latestTreeVersion .. (isRuthless and "_ruthless" or "")
	end

	controls.nameLabel = new("LabelControl", nil, -180, 20, 0, 16, "Enter name for this passive tree:")
	controls.name = new("EditControl", nil, 100, 20, 350, 18, "", nil, nil, nil, function(buf)
		controls.msg.label = ""
		controls.import.enabled = buf:match("%S") and controls.edit.buf:match("%S")
	end)
	controls.editLabel = new("LabelControl", nil, -150, 45, 0, 16, "Enter passive tree link:")
	controls.edit = new("EditControl", nil, 100, 45, 350, 18, "", nil, nil, nil, function(buf)
		controls.msg.label = ""
		controls.import.enabled = buf:match("%S") and controls.name.buf:match("%S")
	end)
	controls.msg = new("LabelControl", nil, 0, 65, 0, 16, "")
	controls.import = new("ButtonControl", nil, -45, 85, 80, 20, "Import", function()
		local treeLink = controls.edit.buf
		if #treeLink == 0 then
			return
		end
		-- EG: http://poeurl.com/dABz
		if treeLink:match("poeurl%.com/") then
			controls.import.enabled = false
			controls.msg.label = "Resolving PoEURL link..."
			local id = LaunchSubScript([[
				local treeLink = ...
				local curl = require("lcurl.safe")
				local easy = curl.easy()
				easy:setopt_url(treeLink)
				easy:setopt_writefunction(function(data)
					return true
				end)
				easy:perform()
				local redirect = easy:getinfo(curl.INFO_REDIRECT_URL)
				easy:close()
				if not redirect or redirect:match("poeurl%.com/") then
					return nil, "Failed to resolve PoEURL link"
				end
				return redirect
			]], "", "", treeLink)
			if id then
				launch:RegisterSubScript(id, function(treeLink, errMsg)
					if errMsg then
						controls.msg.label = "^1"..errMsg.."^7"
						controls.import.enabled = true
						return
					else
						decodeTreeLink(treeLink, validateTreeVersion(treeLink:match("tree/ruthless"), treeLink:match(versionLookup)))
					end
				end)
			end
		elseif treeLink:match("poeplanner.com/") then
			decodePoePlannerTreeLink(treeLink:gsub("/%?v=.+#","/"))
		elseif treeLink:match("poeskilltree.com/") then
			local oldStyleVersionLookup = "/%?v=([0-9]+)%.([0-9]+)%.([0-9]+)%-?r?u?t?h?l?e?s?s?#"
			-- Strip the version from the tree : https://poeskilltree.com/?v=3.6.0#AAAABAMAABEtfIOFMo6-ksHfsOvu -> https://poeskilltree.com/AAAABAMAABEtfIOFMo6-ksHfsOvu
			decodeTreeLink(treeLink:gsub("/%?v=.+#","/"), validateTreeVersion(treeLink:match("-ruthless#"), treeLink:match(oldStyleVersionLookup)))
		else
			-- EG: https://www.pathofexile.com/passive-skill-tree/3.15.0/AAAABgMADI6-HwKSwQQHLJwtH9-wTLNfKoP3ES3r5AAA
			-- EG: https://www.pathofexile.com/fullscreen-passive-skill-tree/3.15.0/AAAABgMADAQHES0fAiycLR9Ms18qg_eOvpLB37Dr5AAA
			-- EG: https://www.pathofexile.com/passive-skill-tree/ruthless/AAAABgAAAAAA (Ruthless doesn't have versions)
			decodeTreeLink(treeLink, validateTreeVersion(treeLink:match("tree/ruthless"), treeLink:match(versionLookup)))
		end
	end)
	controls.import.enabled = false
	controls.cancel = new("ButtonControl", nil, 45, 85, 80, 20, "Cancel", function()
		main:ClosePopup()
	end)
	main:OpenPopup(580, 115, "Import Tree", controls, "import", "name")
end

function TreeTabClass:OpenExportPopup()
	local treeLink = self.build.spec:EncodeURL(treeVersions[self.build.spec.treeVersion].url)
	local popup
	local controls = { }
	controls.label = new("LabelControl", nil, 0, 20, 0, 16, "Passive tree link:")
	controls.edit = new("EditControl", nil, 0, 40, 350, 18, treeLink, nil, "%Z")
	controls.shrink = new("ButtonControl", nil, -90, 70, 140, 20, "Shrink with PoEURL", function()
		controls.shrink.enabled = false
		controls.shrink.label = "Shrinking..."
		launch:DownloadPage("http://poeurl.com/shrink.php?url="..treeLink, function(response, errMsg)
			controls.shrink.label = "Done"
			if errMsg or not response.body:match("%S") then
				main:OpenMessagePopup("PoEURL Shortener", "Failed to get PoEURL link. Try again later.")
			else
				treeLink = "http://poeurl.com/"..response.body
				controls.edit:SetText(treeLink)
				popup:SelectControl(controls.edit)
			end
		end)
	end)
	controls.copy = new("ButtonControl", nil, 30, 70, 80, 20, "Copy", function()
		Copy(treeLink)
	end)
	controls.done = new("ButtonControl", nil, 120, 70, 80, 20, "Done", function()
		main:ClosePopup()
	end)
	popup = main:OpenPopup(380, 100, "Export Tree", controls, "done", "edit")
end

function TreeTabClass:ModifyNodePopup(selectedNode)
	local controls = { }
	local modGroups = { }
	local function buildMods(selectedNode)
		wipeTable(modGroups)
		local treeNodes = self.build.spec.tree.nodes
		local numLinkedNodes = selectedNode.linkedId and #selectedNode.linkedId or 0
		local nodeName = treeNodes[selectedNode.id].dn
		local nodeValue = treeNodes[selectedNode.id].sd[1]
		for id, node in pairs(self.build.spec.tree.tattoo.nodes) do
			if (nodeName:match(node.targetType:gsub("^Small ", "")) or (node.targetValue ~= "" and nodeValue:match(node.targetValue)) or
					(node.targetType == "Small Attribute" and (nodeName == "Intelligence" or nodeName == "Strength" or nodeName == "Dexterity"))
					or (node.targetType == "Keystone" and treeNodes[selectedNode.id].type == node.targetType))
					and node.MinimumConnected <= numLinkedNodes then
				local combine = false
				for id, desc in pairs(node.stats) do
					combine = (id:match("^local_display.*") and #node.stats == (#node.sd - 1)) or combine
					if combine then break end
				end
				local descriptionsAndReminders = copyTable(node.sd)
				if combine then
					t_remove(descriptionsAndReminders, 1)
					t_remove(descriptionsAndReminders, 1)
					t_insert(descriptionsAndReminders, 1, node.sd[1] .. " " .. node.sd[2])
				end
				local descriptionsAndReminders = combine and { [1] = table.concat(node.sd, " ") } or copyTable(node.sd)
				if node.reminderText then
					t_insert(descriptionsAndReminders, node.reminderText[1])
				end
				t_insert(modGroups, {
				label = node.dn .. "                                                " .. table.concat(node.sd, ","),
				descriptions = descriptionsAndReminders,
				id = id,
				})
			end
		end
		table.sort(modGroups, function(a, b) return a.label < b.label end)
		end
	local function addModifier(selectedNode)
		local newTattooNode = self.build.spec.tree.tattoo.nodes[modGroups[controls.modSelect.selIndex].id]
		newTattooNode.id = selectedNode.id
		self.build.spec.hashOverrides[selectedNode.id] = newTattooNode
		self.build.spec:ReplaceNode(selectedNode, newTattooNode)
		self.build.spec:BuildAllDependsAndPaths()
	end

	local function constructUI(modGroup)
		local totalHeight = 43
		local maxWidth = 375
		local i = 1
		while controls[i] do
			controls[i] = nil
			i = i + 1
		end

		local wrapTable = {}
		for idx, desc in ipairs(modGroup.descriptions) do
			for _, wrappedDesc in ipairs(main:WrapString(desc, 16, maxWidth)) do
				t_insert(wrapTable, wrappedDesc)
			end
		end
		for idx, desc in ipairs(wrapTable) do
			controls[idx] = new("LabelControl", {"TOPLEFT", controls[idx-1] or controls.modSelect,"TOPLEFT"}, 0, 20, 600, 16, "^7"..desc)
			totalHeight = totalHeight + 20
		end
		main.popups[1].height = totalHeight + 30
		controls.save.y = totalHeight
		controls.reset.y = totalHeight
		controls.close.y = totalHeight
	end

	buildMods(selectedNode)
	controls.modSelectLabel = new("LabelControl", {"TOPRIGHT",nil,"TOPLEFT"}, 150, 25, 0, 16, "^7Modifier:")
	controls.modSelect = new("DropDownControl", {"TOPLEFT",nil,"TOPLEFT"}, 155, 25, 250, 18, modGroups, function(idx) constructUI(modGroups[idx]) end)
	controls.modSelect.tooltipFunc = function(tooltip, mode, index, value)
		tooltip:Clear()
		if mode ~= "OUT" and value then
			for _, line in ipairs(value.descriptions) do
				tooltip:AddLine(16, "^7"..line)
			end
		end
	end
	controls.save = new("ButtonControl", nil, -90, 75, 80, 20, "Add", function()
		addModifier(selectedNode)
		self.modFlag = true
		self.build.buildFlag = true
		main:ClosePopup()
	end)
	controls.reset = new("ButtonControl", nil, 0, 75, 80, 20, "Reset Node", function()
		self.build.spec.tree.nodes[selectedNode.id].isTattoo = false
		self.build.spec.hashOverrides[selectedNode.id] = nil
		self.build.spec:ReplaceNode(selectedNode, self.build.spec.tree.nodes[selectedNode.id])
		self.build.spec:BuildAllDependsAndPaths()
		self.modFlag = true
		self.build.buildFlag = true
		main:ClosePopup()
	end)
	controls.close = new("ButtonControl", nil, 90, 75, 80, 20, "Cancel", function()
		main:ClosePopup()
	end)
	main:OpenPopup(600, 105, "Replace Modifier of Node", controls, "save")
	constructUI(modGroups[1])
end

function TreeTabClass:SetPowerCalc(powerStat)
	self.viewer.showHeatMap = true
	self.build.buildFlag = true
	self.build.calcsTab.powerBuildFlag = true
	self.build.calcsTab.powerStat = powerStat
	self.controls.powerReportList:SetReport(powerStat, nil)
end

function TreeTabClass:BuildPowerReportList(currentStat)
	local report = {}

	if not (currentStat and currentStat.stat) then
		return report
	end

	-- locate formatting information for the type of heat map being used.
	-- maybe a better place to find this? At the moment, it is the only place
	-- in the code that has this information in a tidy place.
	local displayStat = nil

	for index, ds in ipairs(self.build.displayStats) do
		if ds.stat == currentStat.stat then
			displayStat = ds
			break
		end
	end

	-- not every heat map has an associated "stat" in the displayStats table
	-- this is due to not every stat being displayed in the sidebar, I believe.
	-- But, we do want to use the formatting knowledge stored in that table rather than duplicating it here.
	-- If no corresponding stat is found, just default to a generic stat display (>0=good, one digit of precision).
	if not displayStat then
		displayStat = {
			fmt = ".1f"
		}
	end

	-- search all nodes, ignoring ascendancies, sockets, etc.
	for nodeId, node in pairs(self.build.spec.visibleNodes) do
		local isAlloc = node.alloc > 0 or self.build.calcsTab.mainEnv.grantedPassives[nodeId]
		if (node.type == "Normal" or node.type == "Keystone" or node.type == "Notable") and not node.ascendancyName then
			local pathDist
			if isAlloc then
				pathDist = #(node.depends or { }) == 0 and 1 or #node.depends
			else
				pathDist = #(node.path or { }) == 0 and 1 or #node.path
			end
			local nodePower = (node.power.singleStat or 0) * ((displayStat.pc or displayStat.mod) and 100 or 1)
			local pathPower = (node.power.pathPower or 0) / pathDist * ((displayStat.pc or displayStat.mod) and 100 or 1)
			local nodePowerStr = s_format("%"..displayStat.fmt, nodePower)
			local pathPowerStr = s_format("%"..displayStat.fmt, pathPower)

			nodePowerStr = formatNumSep(nodePowerStr)
			pathPowerStr = formatNumSep(pathPowerStr)

			if (nodePower > 0 and not displayStat.lowerIsBetter) or (nodePower < 0 and displayStat.lowerIsBetter) then
				nodePowerStr = colorCodes.POSITIVE .. nodePowerStr
			elseif (nodePower < 0 and not displayStat.lowerIsBetter) or (nodePower > 0 and displayStat.lowerIsBetter) then
				nodePowerStr = colorCodes.NEGATIVE .. nodePowerStr
			end
			if (pathPower > 0 and not displayStat.lowerIsBetter) or (pathPower < 0 and displayStat.lowerIsBetter) then
				pathPowerStr = colorCodes.POSITIVE .. pathPowerStr
			elseif (pathPower < 0 and not displayStat.lowerIsBetter) or (pathPower > 0 and displayStat.lowerIsBetter) then
				pathPowerStr = colorCodes.NEGATIVE .. pathPowerStr
			end

			t_insert(report, {
				name = node.dn,
				power = nodePower,
				powerStr = nodePowerStr,
				pathPower = pathPower,
				pathPowerStr = pathPowerStr,
				allocated = isAlloc,
				id = node.id,
				x = node.x,
				y = node.y,
				type = node.type,
				pathDist = pathDist
			})
		end
	end

	-- sort it
	if displayStat.lowerIsBetter then
		t_sort(report, function (a,b)
			return a.power < b.power
		end)
	else
		t_sort(report, function (a,b)
			return a.power > b.power
		end)
	end

	return report
end

