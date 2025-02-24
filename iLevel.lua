local ADDON_NAME = ...
local _G = _G
local g, db -- Inspect Frame itemLevels / Settings on how much we show, where we anchor stuff and how we color it
local isWrathClassic = (_G.WOW_PROJECT_ID == _G.WOW_PROJECT_WRATH_CLASSIC)
local isCataClassic = (_G.WOW_PROJECT_ID == _G.WOW_PROJECT_CATACLYSM_CLASSIC)
local isSomeClassic = (isWrathClassic or isCataClassic)
local DBDefaults = { -- Default settings for new users
	setting = 2,
	inside = (isSomeClassic) and true or false,
	color = false,
	tooltips = false,
	differenceColor = false,
	disableInspect = false,
	enchantsTable = { -- Slots you can enchant in current xpack (aka the only ones worthwhile of your time)
		[1] = false, -- Head
		[2] = false, -- Neck
		[3] = false, -- Shoulder
		[4] = false, -- Shirt
		[5] = (isSomeClassic) and true or true, -- Chest
		[6] = false, -- Waist
		[7] = false, -- Legs
		[8] = (isSomeClassic) and true or true, -- Feet
		[9] = (isSomeClassic) and true or true, -- Wrist
		[10] = (isSomeClassic) and true or false, -- Hands
		[11] = (isSomeClassic) and true or true, -- Finger0
		[12] = (isSomeClassic) and true or true, -- Finger1
		[13] = false, -- Trinket0
		[14] = false, -- Trinket1
		[15] = (isSomeClassic) and true or true, -- Back
		[16] = (isSomeClassic) and true or true, -- Mainhand
		[17] = (isSomeClassic) and true or true, -- Offhand
	},
	debug = false
}
local f = CreateFrame("Frame", nil, _G.PaperDollFrame) -- iLevel number frame for Character
f:RegisterEvent("ADDON_LOADED")

MIN_PLAYER_LEVEL_FOR_ITEM_LEVEL_DISPLAY = 1 -- Enable itemlevel display for characters under level 90

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
local function Print(text, ...)
	if text then
		if text:match("%%[dfqs%d%.]") then
			DEFAULT_CHAT_FRAME:AddMessage("|cffff9999".. ADDON_NAME ..":|r " .. format(text, ...))
		else
			DEFAULT_CHAT_FRAME:AddMessage("|cffff9999".. ADDON_NAME ..":|r " .. strjoin(" ", text, tostringall(...)))
		end
	end
end -- Print

local maxSlots = (isSomeClassic) and 18 or 17
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
if (isSomeClassic) then slotTable[#slotTable + 1] = "RangedSlot" end

local anchorStrings, createStrings
do -- Create and Anchor strings based on settings
	local xo, yo = 8, 3 -- X-offset, Y-offset

	local function _returnPoints(slotId) -- Return anchoring points of string #, also because I'm lazy, I'm reusing this to return Tooltip achoring points as well
		if db.inside then -- Inside
			return "BOTTOM", "BOTTOM", 2, 3, "CENTER", "BOTTOM", "ANCHOR_CURSOR"
		else
			if slotId <= 5 or slotId == 15 or slotId == 9 then -- Left side
				return "LEFT", "RIGHT", xo, 0, "LEFT", "MIDDLE", "ANCHOR_RIGHT"
			elseif slotId <= 14 then -- Right side
				return "RIGHT", "LEFT", -xo, 0, "RIGHT", "MIDDLE", "ANCHOR_LEFT"
			else -- Weapon slots
				--return "BOTTOM", "TOP", 2, yo, "CENTER", "BOTTOM"
				return "BOTTOM", "TOP", 2, yo, "CENTER", "MIDDLE", "ANCHOR_TOP" -- Try to fix weapon strings sometimes looking bit weird
			end
		end
	end

	local function _createFancy(parent, point, isLeft) -- Create Extra Fancy stuff
		local r, g, b, aLeft, aRight = .9, .9, .9, (isLeft and 0 or .4), (isLeft and .4 or 0)
		local fancy = parent:CreateTexture(nil, "BORDER")
		fancy:SetPoint((isLeft and "RIGHT" or "LEFT"), point, "CENTER")
		fancy:SetSize(65, 35)
		fancy:SetColorTexture(1, 1, 1)
		fancy:SetGradient("Horizontal", CreateColor(r, g, b, aLeft), CreateColor(r, g, b, aRight))

		fancy.top = parent:CreateTexture(nil, "BORDER")
		fancy.top:SetPoint("BOTTOM", fancy, "TOP")
		fancy.top:SetSize(65, 2)
		fancy.top:SetColorTexture(0, 0, 0)
		fancy.top:SetGradient("Horizontal", CreateColor(0, 0, 0, 2*aLeft), CreateColor(0, 0, 0, 2*aRight))

		fancy.bottom = parent:CreateTexture(nil, "BORDER")
		fancy.bottom:SetPoint("TOP", fancy, "BOTTOM")
		fancy.bottom:SetSize(65, 2)
		fancy.bottom:SetColorTexture(0, 0, 0)
		fancy.bottom:SetGradient("Horizontal", CreateColor(0, 0, 0, 2*aLeft), CreateColor(0, 0, 0, 2*aRight))

		return fancy
	end

	function anchorStrings(frame) -- Anchor strings to right places
		local point
		if frame == f then
			point = "Character"
		else
			point = "Inspect"
		end

		for i = 1, maxSlots do -- Set Point and Justify
			if i ~= 4 then
				local parent = _G[ point..slotTable[i] ]
				local myPoint, parentPoint, x, y, justifyH, justifyV = _returnPoints(i)
				frame[i].string:ClearAllPoints()
				frame[i].string:SetPoint(myPoint, parent, parentPoint, x, y)
				frame[i].string:SetJustifyH(justifyH)
				frame[i].string:SetJustifyV(justifyV)
			end
		end
	end -- anchorStrings

	local function OnEnter(self) -- Enchant Tooltip OnEnter
		if (not db.tooltips) or (db.setting < 2) or (db.inside) then return end -- Tooltips ON, Setting 2 and Anchor OUTSIDE

		if self.currentEnchant ~= "" or self.currentSockets ~= "" then
			GameTooltip:SetOwner(self, select(-1, _returnPoints(self.slotId))) -- https://wow.gamepedia.com/API_GameTooltip_SetOwner
			if self.currentEnchant then
				GameTooltip:AddLine(self.currentEnchant, _G.GREEN_FONT_COLOR.r, _G.GREEN_FONT_COLOR.g, _G.GREEN_FONT_COLOR.b, true)
			end
			if self.currentSockets then
				GameTooltip:AddLine(self.currentSockets, 1, 1, 1, true)
			end
			GameTooltip:Show()
		end
	end
	local function OnLeave(self) -- Enchant Tooltip OnLeave
		GameTooltip:Hide()
	end

	function createStrings(frame) -- Create item level -strings
		if #frame > 0 then return end

		if frame == f then
			frame:SetFrameLevel(_G.CharacterHeadSlot:GetFrameLevel())
			if (isSomeClassic) then
				frame["avg"] = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
				frame["avg"]:SetPoint("BOTTOM", _G.CharacterModelScene, "BOTTOM", 0, 18*yo)
				frame.fancyLeft = _createFancy(frame, frame["avg"], true)
				frame.fancyRight = _createFancy(frame, frame["avg"], false)
			end
		else
			frame:SetFrameLevel(_G.InspectHeadSlot:GetFrameLevel())
			frame["avg"] = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
			if (isSomeClassic) then
				frame["avg"]:SetPoint("BOTTOM", _G.InspectModelFrame, "BOTTOM", 0, 3*yo)
			else
				frame["avg"]:SetPoint("TOP", _G.InspectModelFrameControlFrame, "BOTTOM", 0, -yo)
			end
			frame.fancyLeft = _createFancy(frame, frame["avg"], true)
			frame.fancyRight = _createFancy(frame, frame["avg"], false)
		end

		for i = 1, maxSlots do
			if i ~= 4 then
				frame[i] = CreateFrame("Frame", nil, frame)
				local s = frame[i]:CreateFontString(nil, "OVERLAY", "GameFontNormalOutline") -- Revert the previous fix, the smaller text size made it bit too hard to read the icons
				frame[i]:SetAllPoints(s) -- Fontstring anchoring hack by SDPhantom https://www.wowinterface.com/forums/showpost.php?p=280136&postcount=6
				frame[i].string = s; frame[i].slotId = i; frame[i].itemLevel = ""; frame[i].upgradeString = ""; frame[i].finalString = "%1$s"
				frame[i].enchantString = ""; frame[i].currentEnchant = ""; frame[i].socketString = ""; frame[i].currentSockets = ""
				frame[i]:SetScript("OnEnter", OnEnter); frame[i]:SetScript("OnLeave", OnLeave)
				frame[i]:EnableMouse(db.tooltips)
			end
		end

		anchorStrings(frame)
	end -- createStrings
end -- anchorStrings, createStrings

-- Upgrade scanning inspired by Phanx @ http://www.wowinterface.com/forums/showthread.php?p=271406
-- Socket scanning inspired by Phanx @ https://www.wowinterface.com/forums/showpost.php?p=319704&postcount=2
local TooltipScanItem
do -- Scan tooltip for sockets and upgrade levels
	-- Generate a unique name for the tooltip:
	local tooltipName = ADDON_NAME .. "ScanningTooltip" .. random(100000, 10000000)

	-- Create the hidden tooltip object:
	local tooltip = CreateFrame("GameTooltip", tooltipName, _G.UIParent, "GameTooltipTemplate")
	tooltip:SetOwner(_G.UIParent, "ANCHOR_NONE")

	-- Build a list of the tooltip's texture objects:
	local textures = {}
	for i = 1, 10 do
		textures[i] = _G[tooltipName .. "Texture" .. i]
	end

	-- Construct your search patterns based on the existing global strings:
	local S_ITEM_LEVEL = "^" .. gsub(ITEM_LEVEL, "%%d", "(%%d+)")
	local S_UPGRADE_LEVEL = "^" .. gsub(_G.ITEM_UPGRADE_TOOLTIP_FORMAT, "%%d", "(%%d+)")
	local S_HEIRLOOM_LEVEL = "^" .. gsub(_G.HEIRLOOM_UPGRADE_TOOLTIP_FORMAT, "%%d", "(%%d+)")
	local S_ENCHANTED_TOOLTIP_LINE =  "^" .. gsub(_G.ENCHANTED_TOOLTIP_LINE, "%%s", "(.+)") -- https://www.townlong-yak.com/framexml/8.3/GlobalStrings.lua#5500, https://wow.gamepedia.com/HOWTO:_Use_Pattern_Matching

	-- Expose the API:
	function TooltipScanItem(itemLink, isEnchanted, isGem, slotId)
		if not itemLink then return end

		-- Pass the item link to the tooltip:
		tooltip:SetHyperlink(itemLink)

		local n = {}
		for i = 1, 10 do -- Get all textures from Tooltip (Gems etc.)
			local tex = textures[i]:GetTexture() or textures[i]:GetTextureFileID()
			if tex and textures[i]:IsShown() then
				n[#n + 1] = tex
				if db.debug then
					Print("+", slotTable[slotId], "-", i, "/", #n, "-", tex, "|T" .. tex .. ":0:0:0:0:32:32:2:30:2:30|t")
				end
			end
		end

		local realItemLevel, currentUpgradeLevel, maxUpgradeLevel, currentEnchant
		for i = 2, tooltip:NumLines() do -- Line 1 is always the name so you can skip it.
			local text = _G[tooltipName .. "TextLeft" .. i]:GetText()
			if text and text ~= "" then
				if isGem then
					if strmatch(text, "+(%d+)") then -- +50 Crit etc. (Gems, Cogs and Punch Cards)
						return text
					elseif strmatch(text, _G.ITEM_SPELL_TRIGGER_ONEQUIP) then -- "Equip:" (Punch Cards)
						return strmatch(text, _G.ITEM_SPELL_TRIGGER_ONEQUIP .. " (.+)")
					end
				elseif strmatch(text, S_ITEM_LEVEL) then
					realItemLevel = strmatch(text, S_ITEM_LEVEL)
				elseif strmatch(text, S_UPGRADE_LEVEL) then
					currentUpgradeLevel, maxUpgradeLevel = strmatch(text, S_UPGRADE_LEVEL)
				elseif strmatch(text, S_HEIRLOOM_LEVEL) then
					currentUpgradeLevel, maxUpgradeLevel = strmatch(text, S_HEIRLOOM_LEVEL)
				elseif isEnchanted and strmatch(text, S_ENCHANTED_TOOLTIP_LINE) then
					currentEnchant = strmatch(text, S_ENCHANTED_TOOLTIP_LINE)
				end

				if realItemLevel and currentUpgradeLevel and ((not isEnchanted) or (isEnchanted and currentEnchant)) then
					return tonumber(realItemLevel), tonumber(currentUpgradeLevel), tonumber(maxUpgradeLevel), currentEnchant, n
				end
			end
		end

		return realItemLevel and tonumber(realItemLevel) or nil, currentUpgradeLevel and tonumber(currentUpgradeLevel) or nil, maxUpgradeLevel and tonumber(maxUpgradeLevel) or nil, currentEnchant, n
	end
end -- TooltipScanItem

local function getFinalString(slotId, itemQualityColor, isHex) -- Construct the itemLevel-string
	local finalString = "%1$s"
	local left = (slotId <= 5 or slotId == 15 or slotId == 9 or slotId == 17)

	if db.setting >= 1 then
		if db.inside then -- Inside
			finalString = (db.setting == 1) and "%2$s\n%1$s" or (left) and "%3$s%4$s%2$s\n%1$s" or "%2$s%4$s%3$s\n%1$s" -- 1: Either	2: Left			2: Right
		elseif (left) then -- Left
			finalString = (db.setting == 1) and "%1$s%2$s" or slotId == 17 and "%3$s%4$s\n%1$s%2$s" or "%1$s%2$s%3$s%4$s" -- 1: Left	2: slotId 17	2: Left
		else -- Right
			finalString = (db.setting == 1) and "%2$s%1$s" or slotId == 16 and "%3$s%4$s\n%2$s%1$s" or "%4$s%3$s%2$s%1$s" -- 1: Rightt	2: slotId 16	2: Right
		end
	end

	if db.color and itemQualityColor then
		finalString = (isHex and itemQualityColor or itemQualityColor.hex) .. finalString .. _G.FONT_COLOR_CODE_CLOSE
	end

	return finalString
end -- getFinalString

local updateSlot
do -- Update saved item data per slot and refresh text strings at the same time
	--[[
	local inspectOffhand -- Calculate the Average item level and rarity of inspect unit's gear
	local inspectLevels, inspectRarity = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }, { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }

	local function _updateAverageItemLevel() -- Update the Average Item Level text of Inspect Unit
		local raritySum, iLvlSum = 0, 0
		for i = 1, maxSlots do
			raritySum = raritySum + inspectRarity[i]
			iLvlSum = iLvlSum + inspectLevels[i]
		end

		local itemCount = #inspectLevels - 1 -- Remove shirt from calculatios
		if not inspectOffhand then -- Offhand empty, probably using 2H weapon without Titan's Grip (Fury Warrior passive allowing you to dual-wield 2H weapons), but this is just a guess
			itemCount = itemCount - 1
		end

		g["avg"]:SetFormattedText("%s%d%s", _G.ITEM_QUALITY_COLORS[math.floor(raritySum / math.max(itemCount, 1))].hex, math.floor(iLvlSum / math.max(itemCount, 1)), _G.FONT_COLOR_CODE_CLOSE)
	end -- _updateAverageItemLevel
	]]

	local updateLockPlayer, updateLockInspect = false, false
	function updateSlot(button) -- Slot was updated, check if we need to update the ilevel-text
		local slotId = button:GetID()
		local frame, unit
		if (button:GetParent():GetName() == "PaperDollItemsFrame") then
			frame, unit = f, "player"
		elseif (button:GetParent():GetName()) == "InspectPaperDollItemsFrame" then
			frame, unit = g, _G.InspectFrame.unit or "target"
		end

		if unit and slotId ~= 4 and slotId > 0 and slotId <= maxSlots then
			local link = GetInventoryItemLink(unit, slotId)
			if link then -- We have an item
				local item = Item:CreateFromItemLink(link)
				item:ContinueOnItemLoad(function() -- Information should be cached now
					local _, _, enchantId = strsplit(":", strmatch(link, "|H(.-)|h"))
					local itemQuality = item:GetItemQuality()
					local inventoryType = item:GetInventoryType()
					frame[slotId].itemQualityColor = item:GetItemQualityColor()

					local itemLevel, currentUpgradeLevel, maxUpgradeLevel, currentEnchant, sockets = TooltipScanItem(link, (enchantId and enchantId ~= ""), false, slotId)
					frame[slotId].itemLevel = itemLevel or item:GetCurrentItemLevel() or ""

					-- Upgrades
					frame[slotId].upgradeString = ""
					if currentUpgradeLevel and maxUpgradeLevel and currentUpgradeLevel < maxUpgradeLevel then
						frame[slotId].upgradeString = "|TInterface\\PetBattles\\BattleBar-AbilityBadge-Strong:0:0:0:0:32:32:2:30:2:30|t"
					end

					-- Enchant
					frame[slotId].enchantString, frame[slotId].currentEnchant = "", ""
					if enchantId and enchantId ~= "" then
						frame[slotId].enchantString = "|T136244:0:0:0:0:32:32:2:30:2:30|t"
						frame[slotId].currentEnchant = currentEnchant and ("|T136244:0:0:0:0:32:32:2:30:2:30|t " .. currentEnchant) or ""
					elseif db and db.enchantsTable and db.enchantsTable[slotId] then
						if (slotId ~= 17) or (slotId == 17 and (inventoryType ~= 14 and inventoryType ~= 23)) then -- Check if not an Offhand of Offhand item is a Weapon, https://www.townlong-yak.com/framexml/8.2.0/Blizzard_APIDocumentation/ItemDocumentation.lua#438
							frame[slotId].enchantString = "|T136244:0:0:0:0:32:32:2:30:2:30:221:0:0|t"
						end
					end

					-- Sockets
					frame[slotId].socketString, frame[slotId].currentSockets = "", ""
					for t = 1, #sockets do
						if sockets[t] then
							frame[slotId].socketString = frame[slotId].socketString .. "|T" .. sockets[t] .. ":0:0:0:0:32:32:2:30:2:30|t"
						end

						local gemName, gemLink = GetItemGem(link, t)
						if gemName then
							local gemStat = TooltipScanItem(gemLink, nil, true, slotId)
							if db.color then
								local _, _, colorHex = string.find(gemLink, "|cff(%x*)")
								frame[slotId].currentSockets = strtrim(frame[slotId].currentSockets .. (gemStat and ("\n|cff" .. colorHex .. "|T" .. sockets[t] .. ":0:0:0:0:32:32:2:30:2:30|t " .. gemStat .. "|r") or ""))
							else
								frame[slotId].currentSockets = strtrim(frame[slotId].currentSockets .. (gemStat and ("\n|T" .. sockets[t] .. ":0:0:0:0:32:32:2:30:2:30|t " .. gemStat) or ""))
							end
						end
					end

					-- Get the itemLevel-string
					frame[slotId].finalString = getFinalString(slotId, frame[slotId].itemQualityColor)

					-- Fill the itemLevel-string
					frame[slotId].string:SetFormattedText(frame[slotId].finalString, frame[slotId].itemLevel, frame[slotId].upgradeString, frame[slotId].enchantString, frame[slotId].socketString)
					-- New fix for the '...' in some of the strings in some cases
					local w = frame[slotId].string:GetStringWidth() + 5 --math.max(frame[slotId].string:GetWidth(), frame[slotId].string:GetParent():GetWidth() + 2)
					frame[slotId].string:SetWidth(w)
					
					if (unit == "player" and (not updateLockPlayer)) or (unit ~= "player" and (not updateLockInspect)) then
						if unit == "player" then
							updateLockPlayer = true
						else
							updateLockInspect = true
						end
						C_Timer.After(0, function() -- Fire on next frame instead of current frame
							local totalIlvl, totalQlvl = 0, 0
							local isOffhandEquipped = true
							for z = 1, maxSlots do
								if z ~= 4 then
									if (frame[z].itemLevel ~= "") then
										totalIlvl = totalIlvl + frame[z].itemLevel
										totalQlvl = totalQlvl + itemQuality
									elseif z == 17 then
										isOffhandEquipped = false
									end
								end
							end
							local itemCountFix = (isOffhandEquipped == true) and 1 or 2 -- Remove Shirt or Shirt+Offhand
							local finalAvgItemLevel = math.floor(totalIlvl / (maxSlots - itemCountFix))
							local finalAvgQualityLevel = math.floor(totalQlvl / (maxSlots - itemCountFix))
							if ((isSomeClassic) and unit == "player") or unit ~= "player" then
								frame["avg"]:SetFormattedText("%s%d%s", _G.ITEM_QUALITY_COLORS[finalAvgQualityLevel].hex, finalAvgItemLevel, _G.FONT_COLOR_CODE_CLOSE)
							end

							if db.differenceColor then
								for x = 1, maxSlots do
									if x ~= 4 then
										if (frame[x].itemLevel ~= "") then
											local iLevelGap = (finalAvgItemLevel - frame[x].itemLevel)
											local itemLevelColorCode = _G.GREEN_FONT_COLOR_CODE
											if iLevelGap >= 10 and iLevelGap < 20 then
												itemLevelColorCode = _G.ORANGE_FONT_COLOR_CODE
											elseif iLevelGap >= 20 then
												itemLevelColorCode = _G.RED_FONT_COLOR_CODE
											end
											frame[x].finalString = getFinalString(x, itemLevelColorCode, true)
											frame[x].string:SetFormattedText(frame[x].finalString, frame[x].itemLevel, frame[x].upgradeString, frame[x].enchantString, frame[x].socketString)
											local w = frame[x].string:GetStringWidth() + 5
											frame[x].string:SetWidth(w)
										end
									end
								end
							end
							if unit == "player" then
								updateLockPlayer = false
							else
								updateLockInspect = false
							end
						end)
					end
					--[[
					if unit ~= "player" then
						inspectLevels[slotId] = frame[slotId].itemLevel or 0
						inspectRarity[slotId] = (itemQuality == _G.LE_ITEM_QUALITY_HEIRLOOM and _G.LE_ITEM_QUALITY_RARE or (itemQuality or 0)) -- Downscale Heirlooms to Rare

						if slotId == 17 and frame[slotId].itemLevel then -- Check if we have Offhand equipped
							inspectOffhand = (frame[slotId].itemLevel > 0) and true or nil
						end
						_updateAverageItemLevel()
					end
					]]
				end)
			else -- No link, better reset stuff
				frame[slotId].string:SetFormattedText("")
				frame[slotId].itemLevel, frame[slotId].upgradeString = "", ""
				frame[slotId].enchantString, frame[slotId].currentEnchant = "", ""
				frame[slotId].socketString, frame[slotId].currentSockets = "", ""

				--[[
				if unit ~= "player" then
					inspectLevels[slotId] = 0
					inspectRarity[slotId] = 0

					if slotId == 17 then
						inspectOffhand = nil
					end
					_updateAverageItemLevel()
				end
				]]
			end
		end
	end -- updateSlot
end -- updateSlot

local lock -- Prevent multiple timers spawning
local function OnShow(self, force) -- Refresh text strings on frame Show or when called
	--print("OnShow", (self == f), (self == g), tostring(force))
	if (force) or (not lock) then -- Check if locked or forced call from SlashCmd
		lock = true
		C_Timer.After(0, function() -- Fire on next frame instead of current frame
			for slotId = 1, maxSlots do
				if slotId ~= 4 then
					if (force) then -- Calling from SlashCmd, settings might have changed, better reset links and get up to date finalString
						local frame = (self == f) and "Character" or "Inspect"
						updateSlot(_G[ frame..slotTable[slotId] ])
						--self[slotId].finalString = getFinalString(slotId, self[slotId].itemQualityColor)
					end

					if self[slotId].itemLevel ~= nil and self[slotId].itemLevel ~= "" then
						self[slotId].string:SetFormattedText(self[slotId].finalString, self[slotId].itemLevel, self[slotId].upgradeString, self[slotId].enchantString, self[slotId].socketString)
						local w = math.max(self[slotId].string:GetWidth(), self[slotId].string:GetParent():GetWidth() + 2)
						self[slotId].string:SetWidth(w)
					else
						self[slotId].string:SetFormattedText("")
					end
				end
			end
			lock = nil
		end)
	end
end -- OnShow

local function OnEvent(self, event, ...) -- Event handler
	if event == "ADDON_LOADED" then
		if (...) == ADDON_NAME then
			_G.iLevelSetting = initDB(DBDefaults, _G.iLevelSetting)
			db = _G.iLevelSetting

			self:RegisterEvent("PLAYER_LOGIN")
			--self:RegisterEvent("INSPECT_READY")
		elseif (...) == "Blizzard_InspectUI" then
			self:UnregisterEvent(event)

			if not db.disableInspect then
				g = CreateFrame("Frame", nil, _G.InspectPaperDollFrame) -- iLevel number frame for Inspect
				g:SetScript("OnShow", OnShow)
				createStrings(g)
				-- https://www.townlong-yak.com/framexml/8.2.0/Blizzard_InspectUI/InspectPaperDollFrame.lua#159
				hooksecurefunc("InspectPaperDollItemSlotButton_Update", updateSlot)
			end
		end
	elseif event == "PLAYER_LOGIN" then
		self:UnregisterEvent(event)

		f:SetScript("OnShow", OnShow)
		createStrings(f)
		-- https://www.townlong-yak.com/framexml/8.2.0/PaperDollFrame.lua#1610
		hooksecurefunc("PaperDollItemSlotButton_Update", updateSlot)
	--elseif event == "INSPECT_READY" then
	--	for slotId = 1, maxSlots do
	--		if slotId ~= 4 then
	--			updateSlot(_G["Inspect" .. slotTable[slotId]])
	--		end
	--	end
	end
end -- OnEvent
f:SetScript("OnEvent", OnEvent)

SLASH_ILEVEL1 = "/ilevel"
SlashCmdList.ILEVEL = function(...)
	local showHelp, showInfo = true, true
	if (...) == "0" or (...) == "1" or (...) == "2" or (...) == "inside" or (...) == "color" or (...) == "tooltip" or (...) == "difference" or (...) == "inspect" or (...) == "resetenchants" or (...) == "enchants" or strmatch((...), "enchants %d+") or (...) == "debug" then
		showHelp = false
		-- Save settings
		if (...) == "inside" then
			db.inside = not db.inside
		elseif (...) == "color" then
			db.color = not db.color
		elseif (...) == "tooltip" then
			db.tooltips = not db.tooltips
			for i = 1, maxSlots do
				if i ~= 4 then
					f[i]:EnableMouse(db.tooltips)
					if g then
						g[i]:EnableMouse(db.tooltips)
					end
				end
			end
		elseif (...) == "difference" then
			db.differenceColor = not db.differenceColor
		elseif (...) == "inspect" then
			db.disableInspect = not db.disableInspect
		elseif (...) == "resetenchants" then
			showInfo = false
			for i = 1, 17 do
				db.enchantsTable[i] = (DBDefaults.enchantsTable[i]) and true or false
			end
			Print("Show missing Enchants for slots has been reseted to defaults.")
		elseif (...) == "enchants" then
			showInfo = false
			Print("Show missing Enchants for slots:")
			for i = 1, 17 do
				if i ~= 4 then
					Print("  %s%d%s - %s%s%s (%s)",
						_G.NORMAL_FONT_COLOR_CODE, i, _G.FONT_COLOR_CODE_CLOSE,
						db.enchantsTable[i] and _G.GREEN_FONT_COLOR_CODE or _G.RED_FONT_COLOR_CODE, db.enchantsTable[i] and "True" or "False", _G.FONT_COLOR_CODE_CLOSE, _G[strupper(slotTable[i])])
				end
			end
		elseif strmatch((...), "enchants %d+") then
			showInfo = false
			local n = tonumber(strmatch((...), "enchants (%d+)"))
			if not n or n <= 0 or n > 17 or n == 4 then
				Print("Give number between %s1-3%s or %s5-17%s, you gave %s%s%s",
					_G.NORMAL_FONT_COLOR_CODE, _G.FONT_COLOR_CODE_CLOSE,
					_G.NORMAL_FONT_COLOR_CODE, _G.FONT_COLOR_CODE_CLOSE,
					_G.NORMAL_FONT_COLOR_CODE, tostring(n), _G.FONT_COLOR_CODE_CLOSE
				)
			else
				db.enchantsTable[n] = not db.enchantsTable[n]
				Print("Show missing Enchants for slot %s%d%s (%s) has been set to %s%s%s",
					_G.NORMAL_FONT_COLOR_CODE, n, _G.FONT_COLOR_CODE_CLOSE, _G[strupper(slotTable[n])],
					db.enchantsTable[n] and _G.GREEN_FONT_COLOR_CODE or _G.RED_FONT_COLOR_CODE, db.enchantsTable[n] and "True" or "False", _G.FONT_COLOR_CODE_CLOSE)
			end
		elseif (...) == "debug" then
			db.debug = not db.debug
			Print("Debug:", db.debug and _G.GREEN_FONT_COLOR:WrapTextInColorCode("ENABLED") or _G.RED_FONT_COLOR:WrapTextInColorCode("DISABLED"))
		else
			db.setting = tonumber((...))
		end

		-- Force changes
		OnShow(f, true)
		anchorStrings(f)
		if g then
			OnShow(g, true)
			anchorStrings(g)
		end
	end
	if showHelp then
		Print([=[%s ( 0 | 1 | 2 | inside | color | tooltip | difference | enchants [#] )
 %s - Only show item levels.
 %s - Show item levels and upgrades.
 %s - Show item levels, upgrades and enchants and gems.
 %s - Change anchor point between INSIDE and OUTSIDE.
 %s - Change coloring between RARITY and DEFAULT.
 %s - ENABLE/DISABLE show Enchant/Gem-tooltips.
   - Works only when setting is %s and anchor is set to %s.
 %s - ENABLE/DISABLE coloring based on itemlevel difference to averate item level.
 %s - ENABLE/DISABLE showing itemLevels on IspectFrame (Requires %s to take effect).
 %s - ENABLE/DISABLE show missing Enchants for slot #.
   - Ommit # to list slots and their current settings.
 %s - Reset 'Show missing Enchants' -settings to defaults.]=],
			_G.NORMAL_FONT_COLOR:WrapTextInColorCode(SLASH_ILEVEL1),
			_G.NORMAL_FONT_COLOR:WrapTextInColorCode("0"),
			_G.NORMAL_FONT_COLOR:WrapTextInColorCode("1"),
			_G.NORMAL_FONT_COLOR:WrapTextInColorCode("2"),
			_G.NORMAL_FONT_COLOR:WrapTextInColorCode("inside"),
			_G.NORMAL_FONT_COLOR:WrapTextInColorCode("color"),
			_G.NORMAL_FONT_COLOR:WrapTextInColorCode("tooltip"),
				_G.NORMAL_FONT_COLOR:WrapTextInColorCode("2"),
				_G.NORMAL_FONT_COLOR:WrapTextInColorCode("OUTSIDE"),
			_G.NORMAL_FONT_COLOR:WrapTextInColorCode("difference"),
			_G.NORMAL_FONT_COLOR:WrapTextInColorCode("inspect"),
				_G.NORMAL_FONT_COLOR:WrapTextInColorCode("/reloadui"),
			_G.NORMAL_FONT_COLOR:WrapTextInColorCode("enchants [#]"),
			_G.NORMAL_FONT_COLOR:WrapTextInColorCode("resetenchants")
		)
	end
	if showInfo then
		Print("Current settings: %s / %s / C: %s / TT: %s / I: %s",
			_G.NORMAL_FONT_COLOR:WrapTextInColorCode(tostring(db.setting)),
			_G.NORMAL_FONT_COLOR:WrapTextInColorCode(db.inside and "INSIDE" or "OUTSIDE"),
			_G.NORMAL_FONT_COLOR:WrapTextInColorCode(db.differenceColor and "DIFFERENCE" or (db.color and "RARITY" or "DEFAULT")),
			db.tooltips and _G.GREEN_FONT_COLOR:WrapTextInColorCode("ENABLED") or _G.RED_FONT_COLOR:WrapTextInColorCode("DISABLED"),
			db.disableInspect and _G.RED_FONT_COLOR:WrapTextInColorCode("DISABLED") or _G.GREEN_FONT_COLOR:WrapTextInColorCode("ENABLED")
			)
	end
end