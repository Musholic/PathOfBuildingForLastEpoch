-- Game versions
---Default target version for unknown builds and builds created before 3.0.0.
legacyTargetVersion = "3_18"
---Default target for new builds and target to convert legacy builds to.
liveTargetVersion = "3_18"

-- Skill tree versions
---Added for convenient indexing of skill tree versions.
---@type string[]
treeVersionList = { "3_18", }
--- Always points to the latest skill tree version.
latestTreeVersion = treeVersionList[#treeVersionList]
---Tree version where multiple skill trees per build were introduced to PoBC.
defaultTreeVersion = treeVersionList[2]
---Display, comparison and export data for all supported skill tree versions.
---@type table<string, {display: string, num: number, url: string}>
treeVersions = {
	["3_18"] = {
		display = "3.18",
		num = 3.18,
		url = "https://www.pathofexile.com/passive-skill-tree/3.18.0/",
	},
}
