local ADDON_NAME = ...

local isWrathClassic = (WOW_PROJECT_ID == WOW_PROJECT_WRATH_CLASSIC)
local isCataClassic = (WOW_PROJECT_ID == WOW_PROJECT_CATACLYSM_CLASSIC)
local isMoPClassic = (WOW_PROJECT_ID == WOW_PROJECT_MISTS_CLASSIC)
local isRelicClassic = (isWrathClassic or isCataClassic) -- Relics were removed in MoP
local isAnyClassic = (isWrathClassic or isCataClassic or isMoPClassic)

local db, g
local DBDefaults = { -- Default settings for new users
	setting = 2,
	inside = (isAnyClassic) and true or false,
	color = false,
	differenceColor = false,
	disableInspect = false,
	enchantsTable = { -- Slots you can enchant in current xpack (aka the only ones worthwhile of your time)
													--			Era		Wrath	MoP		Legion	SL		TWW		TLT
													--				BC		Cata	WoD		BfA		DF		MN
													-- ========|===|===|===|===|===|===|===|===|===|===|===|===|===|
		[1] = (isAnyClassic) and false or true,		-- Head													 x	
		[2] = false,								-- Neck							 x	 x						
		[3] = true,									-- Shoulder							 x					 x	
		[4] = false,								-- Shirt
													-- -------------------------------------------------------------
		[5] = true,									-- Chest	 x	 x	 x	 x	 x				 x	 x	 x	 x	
		[6] = false,								-- Waist													
		[7] = false,								-- Legs														
		[8] = true,									-- Feet		 x	 x	 x	 x	 x				 x	 x	 x	 x	
													-- -------------------------------------------------------------
		[9] = (isAnyClassic) and true or false,		-- Wrist	 x	 x	 x	 x	 x			 x	 x	 x	 x		
		[10] = (isAnyClassic) and true or false,	-- Hands	 x	 x	 x	 x	 x		 x	 x	 x				
		[11] = (isAnyClassic) and false or true,	-- Finger0						 x	 x	 x	 x	 x	 x	 x	
		[12] = (isAnyClassic) and false or true,	-- Finger1						 x	 x	 x	 x	 x	 x	 x	
													-- -------------------------------------------------------------
		[13] = false,								-- Trinket0													
		[14] = false,								-- Trinket1													
		[15] = (isAnyClassic) and true or false,	-- Back		 x	 x	 x	 x	 x	 x	 x		 x	 x	 x		
		[16] = true,								-- Mainhand	 x	 x	 x	 x	 x	 x	 x	 x	 x	 x	 x	 x	
		[17] = true,								-- Offhand	 x	 x	 x	 x	 x	 x	 x	 x	 x	 x	 x	 x	
													-- =============================================================
													-- https://warcraft.wiki.gg/wiki/Enchanting_formulas
	},
	debug = false
}

local function initDB(a, b) -- Check DB settings, Defaults-table, Settings-table
	if type(a) ~= "table" then return {} end
	if type(b) ~= "table" then b = {} end

	for k, v in pairs(a) do
		if type(b[k]) ~= type(v) then
			b[k] = v
		end
	end

	return b
end -- initDB
local function Debug(text, ...)
	if (not db) or (not db.debug) then return end

	if text then
		if text:match("%%[dfqsx%d%.]") then
			(DEBUG_CHAT_FRAME or (ChatFrame3:IsShown() and ChatFrame3 or ChatFrame4)):AddMessage("|cffff9999"..ADDON_NAME..":|r " .. format(text, ...))
		else
			(DEBUG_CHAT_FRAME or (ChatFrame3:IsShown() and ChatFrame3 or ChatFrame4)):AddMessage("|cffff9999"..ADDON_NAME..":|r " .. strjoin(" ", text, tostringall(...)))
		end
	end
end -- Debug
local function Print(text, ...)
	if text then
		if text:match("%%[dfqs%d%.]") then
			DEFAULT_CHAT_FRAME:AddMessage("|cffff9999".. ADDON_NAME ..":|r " .. format(text, ...))
		else
			DEFAULT_CHAT_FRAME:AddMessage("|cffff9999".. ADDON_NAME ..":|r " .. strjoin(" ", text, tostringall(...)))
		end
	end
end -- Print

--isShown = C_PaperDollInfo.IsRangedSlotShown()
local maxSlots = (isRelicClassic) and 18 or 17
local slotTable = { -- Slot names in right order
	"HeadSlot",
	"NeckSlot",
	"ShoulderSlot",
	"Shirt", -- Skip!
	"ChestSlot",
	"WaistSlot",
	"LegsSlot",
	"FeetSlot",
	"WristSlot",
	"HandsSlot",
	"Finger0Slot",
	"Finger1Slot",
	"Trinket0Slot",
	"Trinket1Slot",
	"BackSlot",
	"MainHandSlot",
	"SecondaryHandSlot"
}
if (isRelicClassic) then slotTable[#slotTable + 1] = "RangedSlot" end
local leftItemSlots = {
	[1] = true, --"HeadSlot",
	[2] = true, --"NeckSlot",
	[3] = true, --"ShoulderSlot",
	[5] = true, --"ChestSlot",
	[9] = true, --"WristSlot",
	[15] = true, --"BackSlot",
	[17] = true, --"SecondaryHandSlot"
	[18] = true, --"RangedSlot"
}
local bottomItemSlots = {
	[16] = true, --"MainHandSlot",
	[17] = true, --"SecondaryHandSlot"
	[18] = true, --"RangedSlot"
}

local f = CreateFrame("Frame", nil, PaperDollItemsFrame)
f.itemLevels = {}
f.qualities = {}
for slot = 1, maxSlots do
	f.itemLevels[slot] = 0
	f.qualities[slot] = 0
end
f.isOffhandEquipped = false
f.isWeaponArtifact = false
f.artifactWeaponLevel = 0
f.averageItemLevel = 0
f.averageQuality = Enum.ItemQuality.Poor

local function __poolRestterFunc(pool, fontString)
	fontString:ClearAllPoints()
	fontString:SetText("")
	fontString:Hide()
end

-- CreateFontStringPool(parent, layer, subLayer, fontStringTemplate, resetterFunc) - Constructs standard FontStrings.
f.pool = CreateFontStringPool(f, "OVERLAY", nil, "GameFontNormalOutline", __poolRestterFunc)

local __getString
do
	local xo, yo = 10, 8 -- X-offset, Y-offset
	local function __returnPoints(itemSlot)
		local slotId = itemSlot:GetID()

		local isLeft = leftItemSlots[slotId] and true or false -- itemSlot.IsLeftSide and true or false -- Doesn't exist on Inspect
		local isVertical = bottomItemSlots[slotId] and true or false -- itemSlot.verticalFlyout and true or false -- Doesn't exist on Inspect
		if db.inside then -- Inside
			--return "BOTTOM", "BOTTOM", 2, 2
			if isLeft then
				return "TOP", "TOP", xo, -2
			else
				return "TOP", "TOP", -xo, -2
			end
		elseif isVertical then -- Weapon
			return "BOTTOM", "TOP", 0, yo
		else
			if isLeft then -- Left
				return "LEFT", "RIGHT", xo, 0
			else -- Right
				return "RIGHT", "LEFT", -xo, 0
			end
		end
	end

	function __getString(itemSlot, poolParent)
		local textString
		local i = 1
		for activeText in poolParent.pool:EnumerateActive() do
			local point, relativeTo, relativePoint, offsetX, offsetY = activeText:GetPoint()

			if relativeTo == itemSlot then -- Found old one, reuse it
				textString = activeText
				textString:ClearAllPoints()
				Debug("  __getString (Reuse) ->", itemSlot:GetName(), i, "/", poolParent.pool:GetNumActive())
				break
			end
			i = i + 1
		end
		if not textString then -- Didn't find old string, need new one
			textString = poolParent.pool:Acquire()
			Debug("  __getString (New) ->", itemSlot:GetName(), i, "/", poolParent.pool:GetNumActive())
		end
		local myPoint, yourPoint, xOff, yOff = __returnPoints(itemSlot)
		textString:SetPoint(myPoint, itemSlot, yourPoint, xOff, yOff)

		return textString
	end
end -- __getString

--[[
for slot = 1, maxSlots do
	if slot ~= 4 then
		local itemSlot = _G["Character" .. slotTable[slot] ]
		local isLeft = itemSlot.IsLeftSide and true or false
		local isVertical = itemSlot.verticalFlyout and true or false
		local textString = f.pool:Acquire()
		--textString:SetText(slotTable[slot])
		textString:SetText(slot)
		if isVertical then -- Weapon
			textString:SetPoint("BOTTOM", itemSlot, "TOP", 0, yo)
		else
			if isLeft then -- Left
				textString:SetPoint("LEFT", itemSlot, "RIGHT", xo, 0)
			else -- Right
				textString:SetPoint("RIGHT", itemSlot, "LEFT", -xo, 0)
			end
		end
		textString:Show()
	end
end
local function __parseItemLink(link)
	local itemType, linkOptions = LinkUtil.ExtractLink(link)
	local itemId, enchantId, gemId1, gemId2, gemId3, gemId4, _, _, linkLevel, _, _, itemContext = strsplit(":", linkOptions)

	Debug("  __parseItemLink %s (%s) -> %s - E: %s G: %s", link, itemId, linkLevel,
		tonumber(enchantId) and GREEN_FONT_COLOR:WrapTextInColorCode("Yes") or RED_FONT_COLOR:WrapTextInColorCode("No"),
		(tonumber(gemId1) or tonumber(gemId2) or tonumber(gemId3) or tonumber(gemId4)) and GREEN_FONT_COLOR:WrapTextInColorCode("Yes") or RED_FONT_COLOR:WrapTextInColorCode("No")
	)
	return tonumber(itemId), tonumber(enchantId), tonumber(gemId1), tonumber(gemId2), tonumber(gemId3), tonumber(gemId4), tonumber(linkLevel)
end
]]

local __parseTooltip
do
	local ignoredKeys = {
		lines = true,
		leftColor = true,
		rightColor = true,
	}
	local indentation = 4
	local function _tableToString(tbl, depth) -- Convert a lua table into a lua syntactically correct string
		local d = depth or 1
		local result = "{\n"
		for k, v in pairs(tbl) do
			if type(v) ~= "function" and type(k) ~= "function" and (not ignoredKeys[k]) then
				-- Check the key type (ignore any numerical keys - assume its an array)
				if type(k) == "string" then
					result = result .. string.rep(" ", d * indentation) .. "[\"" .. k .. "\"] = "
				else
					result = result .. string.rep(" ", d * indentation) .. "[" .. k .. "] = "
				end

				-- Check the value type
				if type(v) == "table" then
					result = result .. _tableToString(v, d + 1)
				elseif type(v) == "string" then
					result = result .. "\"" .. v .. "\""
				else
					result = result .. tostring(v)
				end
				result = result .. ",\n"
			end
		end
		-- Remove leading commas from the result
		if result ~= "{" then
			result = result:sub(1, result:len()-1)
		end
		return result .. "\n" .. string.rep(" ", (d - 1) * indentation) .. "}"
	end

	local tooltipCache = {}
	function __parseTooltip(link, slotId)
		if tooltipCache[link] then -- Check cache
			local cacheData = tooltipCache[link]
			Debug("  __parseTooltip (Cache Hit) %s -> I: %d, U: %d / %d, E: %d, G: %s", link, cacheData[1], cacheData[2], cacheData[3], cacheData[4], cacheData[5])
			return cacheData[1], cacheData[2], cacheData[3], cacheData[4], cacheData[5]
		end

		local S_UPGRADE_LEVEL = "^" .. gsub(ITEM_UPGRADE_TOOLTIP_FORMAT, "%%d", "(%%d+)") -- "Upgrade Level: %d/%d"
		local S_HEIRLOOM_UPGRADE_TOOLTIP_FORMAT = "^" .. gsub(HEIRLOOM_UPGRADE_TOOLTIP_FORMAT, "%%d", "(%%d+)") -- "Heirloom Upgrade Level: %d/%d"

		local itemLevel, currentUpgradeLevel, maxUpgradeLevel = 0, 0, 0
		local gemInfo = ""

		-- Parse Tooltip
		--/tinspect C_TooltipInfo.GetHyperlink(GetInventoryItemLink("player", 1))
		local tooltipData = C_TooltipInfo.GetHyperlink(link)

		local offsetX = (leftItemSlots[slotId]) and 1 or 0
		local offsetY = -2
		for i, line in ipairs(tooltipData.lines) do
			-- GemSockets
			if line.type == Enum.TooltipDataLineType.GemSocket then -- 3
				if line.gemIcon then
					-- Example: 1995542 (gemItemID 153708)
					gemInfo = gemInfo .. format("|T%d:0:0:0:" .. offsetY .. ":32:32:2:30:2:30|t", line.gemIcon)

				else
					-- Example: "Prismatic" or "Meta"
					--[[
					SocketSlot Background Atlases:
						socket-blue-background
						socket-cogwheel-background
						socket-domination-background
						socket-hydraulic-background
						socket-meta-background
						socket-prismatic-background
						socket-punchcard-blue-background
						socket-punchcard-red-background
						socket-punchcard-yellow-background
						socket-red-background
						socket-yellow-background
					]]--
					--gemInfo = gemInfo .. CreateAtlasMarkup("socket-" .. strlower(line.socketType) .. "-background") -- Hope this works

					--[[
					Empty Socket Atlases:
						auctionhouse-icon-socket
						character-emptysocket
					]]--
					gemInfo = gemInfo .. CreateAtlasMarkup("character-emptysocket", 0, 0, offsetX, offsetY) -- Fallback choise

				end
				Debug("    - GemSocket:", line.gemIcon, line.socketType)

			-- AzeriteEssenceSlot
			--elseif line.type == Enum.TooltipDataLineType.AzeriteEssenceSlot then -- 4

			-- AzeriteEssencePower
			--elseif line.type == Enum.TooltipDataLineType.AzeriteEssencePower then -- 5

			-- GemSocketEnchantment
			--elseif line.type == Enum.TooltipDataLineType.GemSocketEnchantment then -- 30

			-- Itemlevel
			elseif line.type == Enum.TooltipDataLineType.ItemLevel then -- 31
				itemLevel = line.itemLevel
				Debug("    - itemlevel:", itemLevel)

			-- ItemUpgradeLevel
			elseif line.type == Enum.TooltipDataLineType.ItemUpgradeLevel then -- 32
				-- Example:
				--[[
					leftText: "Upgrade Level: Myth 6/6"
					maxLevel: 6
					currentLevel: 6
					trackStringID: 978
				]]--
				currentUpgradeLevel = line.currentLevel
				maxUpgradeLevel = line.maxLevel
				Debug("    - upgradeLevel: %s / %s (lineType)", currentUpgradeLevel, maxUpgradeLevel)

			-- ItemQuality
			--elseif line.type == Enum.TooltipDataLineType.ItemQuality then -- 35

			-- Debug for possibly interesting stuff
			else
				local interestingTypes = {
					[4] = true, -- AzeriteEssenceSlot
					[5] = true, -- AzeriteEssencePower
					[30] = true, -- GemSocketEnchantment
					[35] = true, -- ItemQuality
				}
				if interestingTypes[line.type] then
					Debug("\n%s\n====================\n%s\n====================\n%s",
						RED_FONT_COLOR:WrapTextInColorCode("!!! FOUND NEW STUFF"),
						_tableToString(line),
						RED_FONT_COLOR:WrapTextInColorCode("!!! FOUND NEW STUFF")
					)
					--assert(false, "Please report this in a new issue ticket either at Curseforge or Github:\n" .. link .. "\n" .. _tableToString(line))
				end

				-- Upgrade info
				if line.leftText then
					if strmatch(line.leftText, S_UPGRADE_LEVEL) then
						currentUpgradeLevel, maxUpgradeLevel = strmatch(line.leftText, S_UPGRADE_LEVEL)

						Debug("    - upgradeLevel: %s / %s", currentUpgradeLevel, maxUpgradeLevel)
					elseif strmatch(line.leftText, S_HEIRLOOM_UPGRADE_TOOLTIP_FORMAT) then
						currentUpgradeLevel, maxUpgradeLevel = strmatch(line.leftText, S_HEIRLOOM_UPGRADE_TOOLTIP_FORMAT)

						Debug("    - upgradeLevel: %s / %s (Heirloom)", currentUpgradeLevel, maxUpgradeLevel)
					end
				end
			end
		end

		-- Parse link for Enchant info
		local _, linkOptions = LinkUtil.ExtractLink(link)
		local _, enchantId = strsplit(":", linkOptions)

		-- Strings into numbers
		currentUpgradeLevel = tonumber(currentUpgradeLevel)
		maxUpgradeLevel = tonumber(maxUpgradeLevel)
		enchantId = tonumber(enchantId)

		Debug("  __parseTooltip %s -> I: %d, U: %d / %d, E: %d, G: %s", link, itemLevel, currentUpgradeLevel, maxUpgradeLevel, enchantId, gemInfo)
		tooltipCache[link] = { itemLevel, currentUpgradeLevel, maxUpgradeLevel, enchantId, gemInfo }
		return itemLevel, currentUpgradeLevel, maxUpgradeLevel, enchantId, gemInfo
	end
end -- __parseTooltip

local function __buildString(slotId, itemLevel, currentUpgradeLevel, maxUpgradeLevel, enchantId, gemInfo)
	--[[
		db.setting
		0 - Only show item levels.
		1 - Show item levels and upgrades.
		2 - Show item levels, upgrades and enchants and gems.
	]]--
	local finalString = tostring(itemLevel)
	local textUpgrade, textEnchant = "", ""

	if db.setting >= 1 then
		-- Upgrade
		--[[
		UpArrow Atlases:
			bags-greenarrow
			Garr_LevelUpgradeArrow
			house-reward-green-arrow-up
			LevelUp-Icon-Arrow
			loottoast-arrow-green
			plunderstorm-icon-upgrade
			poi-door-arrow-up (yellow, needs tinting)
		]]--
		if currentUpgradeLevel < maxUpgradeLevel then
			--textUpgrade = "|TInterface\\PetBattles\\BattleBar-AbilityBadge-Strong:0:0:0:0:32:32:2:30:2:30|t"
			--textUpgrade = CreateAtlasMarkup("poi-door-arrow-up")
			textUpgrade = CreateAtlasMarkup("poi-door-arrow-up", 0, 0, 0, 0, 0, 255, 0)
		end

		if leftItemSlots[slotId] then
			finalString = finalString .. textUpgrade
		else
			finalString = textUpgrade .. finalString
		end

		if db.setting == 2 then
			-- Enchant & Gems
			local offsetX = slotId >= 17 and 2 or (slotId == 16 and -4 or (leftItemSlots[slotId] and 1 or 0))
			local offsetY = (bottomItemSlots[slotId]) and -1 or -2
			if enchantId then
				--textEnchant = "|T136244:0:0:0:0:32:32:2:30:2:30|t"
				--textEnchant = CreateAtlasMarkup("Mobile-Enchanting")
				textEnchant = CreateAtlasMarkup("Mobile-Enchanting", 0, 0, offsetX, offsetY)
			elseif db.enchantsTable[slotId] then
				textEnchant = CreateAtlasMarkup("Mobile-Enchanting", 0, 0, offsetX, offsetY, 221, 0, 0)
			end

			if bottomItemSlots[slotId] and (not db.inside) then
				if slotId == 16 then
					finalString = gemInfo .. "\n" .. textEnchant .. finalString
				else
					finalString = gemInfo .. "\n" .. finalString .. textEnchant
				end
			else
				finalString = finalString .. "\n" .. strtrim(textEnchant .. gemInfo)
			end
		end
	end

	--return strtrim(finalString:gsub("\n\n", "\n"))
	return strtrim(finalString)
end -- __buildString

local __queueAverages
do
	local function __reColor(parentFrame)
		Debug("  __reColor:", parentFrame)
		local bigGap = 20
		local smallGap = 10

		if parentFrame % 2 == 1 then -- 1 or 3 == Player
			for activeText in f.pool:EnumerateActive() do
				local _, relativeTo = activeText:GetPoint()
				local slotId = relativeTo:GetID()

				local iLevelGap = (f.averageItemLevel - f.itemLevels[slotId])
				local slotText = activeText:GetText()
				if iLevelGap >= bigGap then
					slotText = slotText:gsub("|cnGREEN_FONT_COLOR:", "|cnRED_FONT_COLOR:")
					Debug("    - P: %s (%s) - %s (>= %d)", slotTable[slotId], slotId, RED_FONT_COLOR:WrapTextInColorCode(iLevelGap), bigGap)
				elseif iLevelGap >= smallGap then
					slotText = slotText:gsub("|cnGREEN_FONT_COLOR:", "|cnORANGE_FONT_COLOR:")
					Debug("    - P: %s (%s) - %s (>= %d)", slotTable[slotId], slotId, ORANGE_FONT_COLOR:WrapTextInColorCode(iLevelGap), smallGap)
				end
				activeText:SetText(slotText)
			end
		end
		if parentFrame >= 2 then -- 2 or 3 == Inspect
			for activeText in g.pool:EnumerateActive() do
				local _, relativeTo = activeText:GetPoint()
				local slotId = relativeTo:GetID()

				local iLevelGap = (g.averageItemLevel - g.itemLevels[slotId])
				local slotText = activeText:GetText()
				if iLevelGap >= bigGap then
					slotText = slotText:gsub("|cnGREEN_FONT_COLOR:", "|cnRED_FONT_COLOR:")
					Debug("    - I: %s (%s) - %s (>= %d)", slotTable[slotId], slotId, RED_FONT_COLOR:WrapTextInColorCode(iLevelGap), bigGap)
				elseif iLevelGap >= smallGap then
					slotText = slotText:gsub("|cnGREEN_FONT_COLOR:", "|cnORANGE_FONT_COLOR:")
					Debug("    - I: %s (%s) - %s (>= %d)", slotTable[slotId], slotId, ORANGE_FONT_COLOR:WrapTextInColorCode(iLevelGap), smallGap)
				end
				activeText:SetText(slotText)
			end
		end
	end

	local waitLock = 0
	local function __updateAverages() -- Calculate Averages
		--[[
		--------------------------------------------------------------------------------
		-> 3.3.3
		Nothing


		4.0.1 -> 4.2.0
		local avgItemLevel = GetAverageItemLevel();
		avgItemLevel = floor(avgItemLevel);


		4.3.0 -> 6.1.0
		local avgItemLevel, avgItemLevelEquipped = GetAverageItemLevel();
		avgItemLevel = floor(avgItemLevel);
		avgItemLevelEquipped = floor(avgItemLevelEquipped);


		6.2.0 -> 6.2.0
		local avgItemLevel, avgItemLevelEquipped, avgItemLevelPvP = GetAverageItemLevel();
		avgItemLevel = floor(avgItemLevel);
		avgItemLevelEquipped = floor(avgItemLevelEquipped);

		7.0.3 -> 7.3.5
		local avgItemLevel, avgItemLevelEquipped = GetAverageItemLevel();
		avgItemLevel = floor(avgItemLevel);
		avgItemLevelEquipped = floor(avgItemLevelEquipped);

		8.0.1 -> 9.0.1
		local avgItemLevel, avgItemLevelEquipped = GetAverageItemLevel();
		local minItemLevel = C_PaperDollInfo.GetMinItemLevel();

		local displayItemLevel = math.max(minItemLevel or 0, avgItemLevelEquipped);

		displayItemLevel = floor(displayItemLevel);
		avgItemLevel = floor(avgItemLevel);


		9.1.0 ->
		local avgItemLevel, avgItemLevelEquipped, avgItemLevelPvP = GetAverageItemLevel();
		local minItemLevel = C_PaperDollInfo.GetMinItemLevel();

		local displayItemLevel = math.max(minItemLevel or 0, avgItemLevelEquipped);

		displayItemLevel = floor(displayItemLevel);
		avgItemLevel = floor(avgItemLevel);
		--------------------------------------------------------------------------------
		local avgItemLevel = GetAverageItemLevel(); 4.0.1 ->
		local avgItemLevel, avgItemLevelEquipped = GetAverageItemLevel(); 4.3.0 ->
		local avgItemLevel, avgItemLevelEquipped, avgItemLevelPvP = GetAverageItemLevel(); 6.2.0, 9.1.0 ->

		local minItemLevel = C_PaperDollInfo.GetMinItemLevel(); 8.0.1 ->
		]]--
		Debug("__updateAverages:", waitLock)
		local playerISum, playerQSum, inspectISum, inspectQSum = 0, 0, 0, 0

		for i = 1, maxSlots do
			if waitLock % 2 == 1 then -- waitLock == 1 or 3
				playerISum = playerISum + f.itemLevels[i]
				playerQSum = playerQSum + f.qualities[i]
			end
			if waitLock >= 2 then -- waitLock == 2 or 3
				inspectISum = inspectISum + g.itemLevels[i]
				inspectQSum = inspectQSum + g.qualities[i]
			end
		end

		if waitLock % 2 == 1 then
			--local avgItemLevel, avgItemLevelEquipped = GetAverageItemLevel()
			local slotCount = maxSlots - 1 -- Remove Shirt
			if not f.isOffhandEquipped then
				slotCount = slotCount - 1 -- Remove Offhand
			end
			local playerAvgI = floor(playerISum / slotCount * 100 + .5) / 100
			local playerAvgQ = floor(playerQSum / slotCount + .5)
			f.averageItemLevel = playerAvgI
			f.averageQuality = playerAvgQ
			
			Debug("  - Average (Player): |cnIQ%d:%.2f|r (%d/%d)\n ", playerAvgQ, playerAvgI, slotCount, maxSlots)
		end

		if waitLock >= 2 then
			-- local equippedItemLevel = C_PaperDollInfo.GetInspectItemLevel(unit)
			local slotCount = maxSlots - 1 -- Remove Shirt
			if not g.isOffhandEquipped then
				slotCount = slotCount - 1 -- Remove Offhand
			end
			local inspectAvgI = floor(inspectISum / slotCount * 100 + .5) / 100
			local inspectAvgQ = floor(inspectQSum / slotCount + .5)
			g.averageItemLevel = inspectAvgI
			g.averageQuality = inspectAvgQ
			Debug("  - Average (Inspect): |cnIQ%d:%.2f|r (%d/%d)\n ", inspectAvgQ, inspectAvgI, slotCount, maxSlots)
		end

		if db.differenceColor then
			__reColor(waitLock)
		end
		waitLock = 0
	end

	function __queueAverages(num) -- Queue up only once per frame
		if waitLock < 3 and waitLock ~= num then -- This should allow queueing both Player (1) and Inspect (2) on the same frame
			waitLock = waitLock + num
			RunNextFrame(__updateAverages)
		end
	end
end -- __queueAverages

local updatePlayerSlot, updateInspectSlot
local itemCache = {}
local cacheHitCount, parseCount = 0, 0
do -- _updateSlot
	local function _updateSlot(itemSlot, observationSubject)
		local slotId = itemSlot:GetID()
		if slotId == 0 or slotId == 4 or slotId > maxSlots then
			return
		end

		local parentFrame = (observationSubject == "player") and f or g

		local slotItemLink = GetInventoryItemLink(observationSubject, slotId)

		if not itemCache[observationSubject] then
			itemCache[observationSubject] = {}
		end
		if itemCache[observationSubject][slotId] == slotItemLink then
			cacheHitCount = cacheHitCount + 1
			return
		end
		parseCount = parseCount + 1
		itemCache[observationSubject][slotId] = slotItemLink

		if (slotItemLink) then -- We have an item
			Debug("=== _updateSlot %d %s (%d/%d)", slotId, itemSlot:GetName(), parseCount, cacheHitCount)

			if slotId == 17 then
				parentFrame.isOffhandEquipped = true
				Debug("- isOffhandEquipped:", GREEN_FONT_COLOR:WrapTextInColorCode("YES!"))
			end

			--[[
			local slotItemQuality = GetInventoryItemQuality(observationSubject, slotId)
			Debug("--> Item: %s - Q: %s (%d)", slotItemLink, _G["ITEM_QUALITY" .. slotItemQuality .. "_DESC"], slotItemQuality)
			]]

			local item = Item:CreateFromItemLink(slotItemLink)
			if item:IsItemEmpty() then
				Print("ERROR", slotId)
				parseCount = parseCount - 1
				itemCache[observationSubject][slotId] = nil
				return
			end
			Debug("- Item:CreateFromItemLink - Quality:", item:GetItemQuality())

			-- Parse Tooltip
			local itemLevel, currentUpgradeLevel, maxUpgradeLevel, enchantId, gemInfo = __parseTooltip(slotItemLink, slotId)

			-- Artifact Weapon fix for dual wielded Artifact Weapons
			if slotId == 16 or slotId == 17 then
				if item:GetItemQuality() == Enum.ItemQuality.Artifact then
					parentFrame.isWeaponArtifact = true
					parentFrame.artifactWeaponLevel = math.max(itemLevel, parentFrame.artifactWeaponLevel)

					Debug("- Fixing Artifact Weapon item level: %d -> %d", itemLevel, parentFrame.artifactWeaponLevel)
					itemLevel = parentFrame.artifactWeaponLevel
				else
					parentFrame.isWeaponArtifact = false
					parentFrame.artifactWeaponLevel = 0
				end
			end

			-- Build FinalString
			local textItemLevel = __buildString(slotId, itemLevel, currentUpgradeLevel, maxUpgradeLevel, enchantId, gemInfo)

			-- Get FontString from the Pool
			local itemTextString = __getString(itemSlot, parentFrame)
			itemTextString:SetText(slotId)
			itemTextString:Show()

			-- Align text
			if bottomItemSlots[slotId] then
				itemTextString:SetJustifyH("CENTER")
			else
				if leftItemSlots[slotId] then
					itemTextString:SetJustifyH("LEFT")
				else
					itemTextString:SetJustifyH("RIGHT")
				end
			end

			-- Check Colors
			if (not db.color) then
				textItemLevel = format("%s", textItemLevel)
			else
				if (db.differenceColor) then
					textItemLevel = format("|cnGREEN_FONT_COLOR:%s|r", textItemLevel)
				else
					textItemLevel = format("|cnIQ%d:%s|r", item:GetItemQuality(), textItemLevel)
				end
			end

			-- Set text
			itemTextString:SetText(textItemLevel)
			itemTextString:SetWidth(itemSlot:GetWidth() * 1.5)
			--itemTextString:SetTextToFit(textItemLevel)

			--[[
			-- Check Width
			local fontstringWidth = itemTextString:GetWidth()
			local originalWidth, fixRounds = fontstringWidth, 0
			while itemTextString:IsTruncated() do
				fontstringWidth = fontstringWidth + 1
				fixRounds = fixRounds + 1
				itemTextString:SetWidth(fontstringWidth)
			end
			if fixRounds > 0 then
				Debug("- Width:", originalWidth, "->", fontstringWidth, "- Rounds:", fixRounds)
			end
			]]--

			-- Change Heirloom quality to Rare in the average calculations
			local itemQuality = item:GetItemQuality()
			if itemQuality == Enum.ItemQuality.Heirloom then
				itemQuality = Enum.ItemQuality.Rare -- 7 -> 3
			end

			-- Update Itemlevel and Quality for the slot
			parentFrame.itemLevels[slotId] = itemLevel
			parentFrame.qualities[slotId] = itemQuality

			Debug("=== DONE\n ")

		else -- Empty slot
			if slotId == 17 then
				parentFrame.isOffhandEquipped = false
				Debug("- isOffhandEquipped:", RED_FONT_COLOR:WrapTextInColorCode("NO!"))
			end

			-- Release FontString back to Pool
			local i = 1
			for activeText in parentFrame.pool:EnumerateActive() do
				local point, relativeTo, relativePoint, offsetX, offsetY = activeText:GetPoint()

				if relativeTo == itemSlot then
					parentFrame.pool:Release(activeText)
					Debug("- Releasing", itemSlot:GetName(), i, "/", parentFrame.pool:GetNumActive())
					break
				end
				i = i + 1
			end

			-- Update Itemlevel and Quality for the slot
			parentFrame.itemLevels[slotId] = 0
			parentFrame.qualities[slotId] = 0
		end

		-- Queue update to the Average values
		__queueAverages(observationSubject == "player" and 1 or 2)
	end

	function updatePlayerSlot(itemSlot)
		_updateSlot(itemSlot, "player")
	end

	function updateInspectSlot(itemSlot)
		local inspectUnit = InspectFrame.unit or "target"

		_updateSlot(itemSlot, inspectUnit)
	end
end -- _updateSlot

local function OnEvent(self, event, ...) -- Event handler
	if event == "ADDON_LOADED" then
		if (...) == ADDON_NAME then
			iLevelSetting = initDB(DBDefaults, iLevelSetting)
			db = iLevelSetting

			self:RegisterEvent("PLAYER_LOGIN")

		elseif (...) == "Blizzard_InspectUI" then
			self:UnregisterEvent(event)

			if (not db.disableInspect) then -- Setup 'g'
				--g = CreateFrame("Frame", nil, InspectPaperDollFrame) -- iLevel number frame for Inspect
				-- InspectPaperDollFrame was too low frameLevel and Fontstrings were hidden behind the slot buttons.
				-- With this parenting, we don't have to hardcode the frameLevel or raise the frameStrata.
				g = CreateFrame("Frame", nil, InspectPaperDollItemsFrame)
				g.itemLevels = {}
				g.qualities = {}
				for slot = 1, maxSlots do
					g.itemLevels[slot] = 0
					g.qualities[slot] = 0
				end
				g.isOffhandEquipped = false
				g.isWeaponArtifact = false
				g.artifactWeaponLevel = 0
				g.averageItemLevel = 0
				g.averageQuality = Enum.ItemQuality.Poor

				g.pool = CreateFontStringPool(g, "OVERLAY", nil, "GameFontNormalOutline", __poolRestterFunc)

				-- https://www.townlong-yak.com/framexml/67451/Blizzard_InspectUI/InspectPaperDollFrame.lua#161 // 12.0.5
				hooksecurefunc("InspectPaperDollItemSlotButton_Update", updateInspectSlot)
			end
		end

	elseif event == "PLAYER_LOGIN" then
		self:UnregisterEvent(event)

		-- https://www.townlong-yak.com/framexml/67451/Blizzard_UIPanels_Game/PaperDollFrame.lua#1693 // 12.0.5
		hooksecurefunc("PaperDollItemSlotButton_Update", updatePlayerSlot)

	end
end -- OnEvent
f:SetScript("OnEvent", OnEvent)
f:RegisterEvent("ADDON_LOADED")

SLASH_ILEVEL1 = "/ilevel"

local SlashHandlers = {
	["0"] = function()
		db.setting = 0
	end,
	["1"] = function()
		db.setting = 1
	end,
	["2"] = function()
		db.setting = 2
	end,
	["inside"] = function()
		db.inside = not db.inside
	end,
	["color"] = function()
		db.color = not db.color
	end,
	["colormode"] = function()
		db.differenceColor = not db.differenceColor
	end,
	["inspect"] = function()
		db.disableInspect = not db.disableInspect
	end,
	["resetenchants"] = function()
		for i = 1, 17 do
			db.enchantsTable[i] = (DBDefaults.enchantsTable[i]) and true or false
		end
		Print("Show missing Enchants for slots has been reseted to defaults.")
		return true
	end,
	["enchants"] = function(inputNumber)
		local slotId = tonumber(inputNumber)
		if not slotId then
			Print("Show missing Enchants for slots:")
			for i = 1, 17 do
				if i ~= 4 then
					Print("  %s - %s (%s)",
						NORMAL_FONT_COLOR:WrapTextInColorCode(i),
						db.enchantsTable[i] and GREEN_FONT_COLOR:WrapTextInColorCode("True") or RED_FONT_COLOR:WrapTextInColorCode("False"),
						_G[strupper(slotTable[i])]
					)
				end
			end
		else
			if slotId <= 0 or slotId > 17 or slotId == 4 then
				Print("Give number between %s or %s, you gave %s",
					NORMAL_FONT_COLOR:WrapTextInColorCode("1-3"),
					NORMAL_FONT_COLOR:WrapTextInColorCode("5-17"),
					NORMAL_FONT_COLOR:WrapTextInColorCode(tostring(slotId))
				)
			else
				db.enchantsTable[slotId] = not db.enchantsTable[slotId]
				Print("Show missing Enchants for slot %s (%s) has been set to %s",
					NORMAL_FONT_COLOR:WrapTextInColorCode(slotId),
					_G[strupper(slotTable[slotId])],
					db.enchantsTable[slotId] and GREEN_FONT_COLOR:WrapTextInColorCode("True") or RED_FONT_COLOR:WrapTextInColorCode("False")
				)
			end
		end
		return true
	end,
	["help"] = function()
		Print("%s ( 0 | 1 | 2 | inside | color | colormode | enchants [#] )", NORMAL_FONT_COLOR:WrapTextInColorCode(SLASH_ILEVEL1))
		Print("%s - Only show item levels.", NORMAL_FONT_COLOR:WrapTextInColorCode("0"))
		Print("%s - Show item levels and upgrades.", NORMAL_FONT_COLOR:WrapTextInColorCode("1"))
		Print("%s - Show item levels, upgrades and enchants and gems.", NORMAL_FONT_COLOR:WrapTextInColorCode("2"))
		Print("%s - Change anchor point between %s and %s.",
			NORMAL_FONT_COLOR:WrapTextInColorCode("inside"),
			NORMAL_FONT_COLOR:WrapTextInColorCode("INSIDE"),
			NORMAL_FONT_COLOR:WrapTextInColorCode("OUTSIDE")
		)
		Print("%s - %s/%s coloring.",
			NORMAL_FONT_COLOR:WrapTextInColorCode("color"),
			GREEN_FONT_COLOR:WrapTextInColorCode("ENABLE"),
			RED_FONT_COLOR:WrapTextInColorCode("DISABLE")
		)
		Print("%s - Change coloring based on item %s and itemlevel %s to averate item level.",
			NORMAL_FONT_COLOR:WrapTextInColorCode("colormode"),
			NORMAL_FONT_COLOR:WrapTextInColorCode("RARITY"),
			NORMAL_FONT_COLOR:WrapTextInColorCode("DIFFERENCE")
		)
		Print("%s - %s/%s showing itemLevels on InspectFrame (Requires %s to take effect).",
			NORMAL_FONT_COLOR:WrapTextInColorCode("inspect"),
			GREEN_FONT_COLOR:WrapTextInColorCode("ENABLE"),
			RED_FONT_COLOR:WrapTextInColorCode("DISABLE"),
			NORMAL_FONT_COLOR:WrapTextInColorCode("/reloadui")
		)
		Print([=[%s - %s/%s show missing Enchants for itemslot #.
- Ommit # to list itemslots and their current settings.]=],
			NORMAL_FONT_COLOR:WrapTextInColorCode("enchants [#]"),
			GREEN_FONT_COLOR:WrapTextInColorCode("ENABLE"),
			RED_FONT_COLOR:WrapTextInColorCode("DISABLE")
		)
		Print("%s - Reset %s -settings to defaults.",
			NORMAL_FONT_COLOR:WrapTextInColorCode("resetenchants"),
			NORMAL_FONT_COLOR:WrapTextInColorCode("Show missing Enchants")
		)
	end,
	["debug"] = function()
		db.debug = not db.debug
		Print("Debug:", db.debug and GREEN_FONT_COLOR:WrapTextInColorCode("ENABLED") or RED_FONT_COLOR:WrapTextInColorCode("DISABLED"))
	end
}

SlashCmdList.ILEVEL = function(text)
	local command, params = strsplit(" ", text, 2)

	if SlashHandlers[command] then
		local skipInfo = SlashHandlers[command](params)
		Debug("/Slash", command, params, skipInfo)

		if not skipInfo then
			Print("Current settings: %s / %s / C: %s / I: %s",
				NORMAL_FONT_COLOR:WrapTextInColorCode(tostring(db.setting)),
				NORMAL_FONT_COLOR:WrapTextInColorCode(db.inside and "INSIDE" or "OUTSIDE"),
				NORMAL_FONT_COLOR:WrapTextInColorCode(db.color and (db.differenceColor and "DIFFERENCE" or "RARITY") or "DEFAULT"),
				db.disableInspect and RED_FONT_COLOR:WrapTextInColorCode("DISABLED") or GREEN_FONT_COLOR:WrapTextInColorCode("ENABLED")
			)
		end

		-- Reset Cache so we get to update the itemSlots
		cacheHitCount = 0
		parseCount = 0
		wipe(itemCache)
		for slot = 1, maxSlots do
			local itemSlot = _G["Character" .. slotTable[slot] ]
			if itemSlot then
				PaperDollItemSlotButton_Update(itemSlot)
			end
		end
		if InspectPaperDollFrame then
			InspectPaperDollFrame_UpdateButtons()
		end
	else
		Print("Current settings: %s / %s / C: %s / I: %s",
			NORMAL_FONT_COLOR:WrapTextInColorCode(tostring(db.setting)),
			NORMAL_FONT_COLOR:WrapTextInColorCode(db.inside and "INSIDE" or "OUTSIDE"),
			NORMAL_FONT_COLOR:WrapTextInColorCode(db.color and (db.differenceColor and "DIFFERENCE" or "RARITY") or "DEFAULT"),
			db.disableInspect and RED_FONT_COLOR:WrapTextInColorCode("DISABLED") or GREEN_FONT_COLOR:WrapTextInColorCode("ENABLED")
		)
		Print("Use %s for help",
			NORMAL_FONT_COLOR:WrapTextInColorCode(SLASH_ILEVEL1 .. " help")
		)
	end
end
