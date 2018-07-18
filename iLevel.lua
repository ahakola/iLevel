local ADDON_NAME = ...
local _G = getfenv(0)
local ChatFrame1, CreateFrame, tostring = _G.ChatFrame1, _G.CreateFrame, _G.tostring
local GetInventoryItemLink, GetItemGem, GetItemInfo = _G.GetInventoryItemLink, _G.GetItemGem, _G.GetItemInfo
local FONT_COLOR_CODE_CLOSE, NORMAL_FONT_COLOR_CODE = _G.FONT_COLOR_CODE_CLOSE, _G.NORMAL_FONT_COLOR_CODE
local ITEM_QUALITY_COLORS, LE_ITEM_QUALITY_ARTIFACT = _G.ITEM_QUALITY_COLORS, _G.LE_ITEM_QUALITY_ARTIFACT
local LE_ITEM_QUALITY_HEIRLOOM, IsAddOnLoaded, type = _G.LE_ITEM_QUALITY_HEIRLOOM, _G.IsAddOnLoaded, _G.type
local LE_ITEM_QUALITY_RARE, strtrim, tonumber, wipe = _G.LE_ITEM_QUALITY_RARE, _G.strtrim, _G.tonumber, _G.wipe
local floor, max, pairs, select, strmatch, strsplit = _G.floor, _G.max, _G.pairs, _G.select, _G.strmatch, _G.strsplit
local createCount = 0 -- How many string-sets we have created
local InspectUILoaded = false -- Is Blizzard_InspectUI loaded before iLevel?
local xo, yo = 8, 3 -- X-offset, Y-offset
local equipped = {} -- Table to store equipped items
local db -- Settings on how much we show, where we anchor stuff and how we color it
local DBDefaults = { -- Default settings for new users
	setting = 2,
	inside = false,
	color = false
}
local socketsTable = { -- These bonusIDs should be sockets
	-- /dump string.split(":", GetInventoryItemLink("player", i))
	-- /dump string.split(":", GetInventoryItemLink("target", 17))
	-- WoD Sockets
	[523] = true, -- Dungeon
	[563] = true, -- Normal Raid
	[564] = true, -- Heroic Raid
	[565] = true, -- Mythic Raid
	-- Prismatic Sockets in 7.0, how many are there?
	[1808] = true, -- From Heroic Dungeons and T19 Normal Raids
	[3458] = true, -- Legendary item with socket?
	--[[ Are these sockets?
	[3] = true,
	[497] = true,
	[572] = true,
	[3386] = true, -- From Vendor -- Not socket?
	[3459] = true, -- Legendary stuff, but no idea what this does
	]]--
}
local slotTable = { -- Slot names in right order
	"HeadSlot",
	"NeckSlot",
	"ShoulderSlot",
	"!Skip!", -- Shirt
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
local eventTable = { -- Listen to these events
	["ARTIFACT_UPDATE"] = true, -- Update Artifact Weapon
	["COMBAT_RATING_UPDATE"] = true, -- Enchanting or Gems added maybe?
	["ITEM_UPGRADE_MASTER_UPDATE"] = true, -- Item upgraded
	["PLAYER_DAMAGE_DONE_MODS"] = true, -- Enchanting or Gems added maybe?
	["PLAYER_EQUIPMENT_CHANGED"] = true, -- Something swapped or changed?
	["SOCKET_INFO_UPDATE"] = true, -- Relics or Gems added maybe?
	["ARTIFACT_RELIC_FORGE_UPDATE"] = true, -- Upgrade with Netherlight Crusible
	--["PLAYER_AVG_ITEM_LEVEL_UPDATE"] = true, -- Itemlevel changed?
}
local offhandArtifacts = { -- Artifacts that are Offhand items... Why would anyone think this was a good idea?
	[128289] = true, -- Protection Warrior, MH 128288
	[128866] = true, -- Protection Paladin, MH 128867
	[128943] = true, -- Demonology Warlock, MH 137246
}
local f = CreateFrame("Frame", nil, _G.PaperDollFrame) -- iLvl number frame
local g -- iLvl number for Inspect frame
f:RegisterEvent("ADDON_LOADED")

-- Tooltip and scanning by Phanx @ http://www.wowinterface.com/forums/showthread.php?p=271406
local S_ITEM_LEVEL = "^" .. gsub(ITEM_LEVEL, "%%d", "(%%d+)")
local S_UPGRADE_LEVEL = "^" .. gsub(ITEM_UPGRADE_TOOLTIP_FORMAT, "%%d", "(%%d+)")
local S_HEIRLOOM_LEVEL = "^" .. gsub(HEIRLOOM_UPGRADE_TOOLTIP_FORMAT, "%%d", "(%%d+)")

local scantip = CreateFrame("GameTooltip", "iLvlScanningTooltip", nil, "GameTooltipTemplate")
scantip:SetOwner(UIParent, "ANCHOR_NONE")

local function _getRealItemLevel(slotId, unit) -- Read the actual itemlevel from Tooltip
	local realItemLevel, currentUpgradeLevel, maxUpgradeLevel
	local hasItem = scantip:SetInventoryItem(unit, slotId)
	if not hasItem then return nil end -- With this we don't get ilvl for offhand if we equip 2h weapon

	for i = 2, scantip:NumLines() do -- Line 1 is always the name so you can skip it.
		local text = _G["iLvlScanningTooltipTextLeft"..i]:GetText()
		if text and text ~= "" then
			realItemLevel = realItemLevel or strmatch(text, S_ITEM_LEVEL)
			if not (currentUpgradeLevel or maxUpgradeLevel) then
				currentUpgradeLevel, maxUpgradeLevel = strmatch(text, S_UPGRADE_LEVEL)
				if not (currentUpgradeLevel or maxUpgradeLevel) then
					currentUpgradeLevel, maxUpgradeLevel = strmatch(text, S_HEIRLOOM_LEVEL)
				end
			end

			if realItemLevel and currentUpgradeLevel and maxUpgradeLevel then
				return realItemLevel, tonumber(currentUpgradeLevel), tonumber(maxUpgradeLevel)
			end
		end
	end

	return realItemLevel
end

local function _updateItems(unit, frame) -- Update the itemlevel strings on Frame
	local tmpItemLevel
	local itemCount, iLvlSum, raritySum = 0, 0, 0
	for i = 1, 17 do -- Only check changed player items or items without ilvl text, skip the shirt (4) and always update Inspects
		local itemLink = GetInventoryItemLink(unit, i)
		if i ~= 4 and ((frame == f and (equipped[i] ~= itemLink or frame[i]:GetText() == nil or itemLink == nil and frame[i]:GetText() ~= "")) or frame == g) then
			if frame == f then
				equipped[i] = itemLink
			end

			local realItemLevel, currentUpgradeLevel, maxUpgradeLevel = _getRealItemLevel(i, unit)
			local upgradeString, enchantString, gemString, colorString, colorCloseString = "", "", "", "", ""
			local _, itemID, enchantID, upgradeTypeID, numBonuses, affixes

			if itemLink then
				_, itemID, enchantID, _, _, _, _, _, _, _, _, upgradeTypeID, _, numBonuses, affixes = strsplit(":", itemLink, 15)
				itemID = tonumber(itemID); enchantID = tonumber(enchantID); numBonuses = tonumber(numBonuses); upgradeTypeID = tonumber(upgradeTypeID);
				local _, _, itemRarity = GetItemInfo(itemLink)
	
				if db.color and itemRarity then
					colorString = ITEM_QUALITY_COLORS[itemRarity].hex
					colorCloseString = FONT_COLOR_CODE_CLOSE
				end

				if frame == g then -- Calculation of average itemlevel when Inspecting
					itemCount = itemCount + 1
					iLvlSum = iLvlSum + tonumber(realItemLevel)
					raritySum = raritySum + (itemRarity == LE_ITEM_QUALITY_HEIRLOOM and LE_ITEM_QUALITY_RARE or (itemRarity or 0)) -- Downscale Heirlooms to Rare
				end

				if i == 16 and itemRarity == LE_ITEM_QUALITY_ARTIFACT then -- When inspecting dualwield Artifact, Offhand returns 750
					tmpItemLevel = tonumber(realItemLevel)
				elseif i == 17 and itemRarity == LE_ITEM_QUALITY_ARTIFACT then -- Fix Offhand itemlevel when calculating average
					if offhandArtifacts[itemID] then -- Offhand Artifact, fix Main Hand itemlevel calculations
						if frame == g then
							iLvlSum = iLvlSum - tmpItemLevel + tonumber(realItemLevel)
						end
						tmpItemLevel = tonumber(realItemLevel)
					elseif frame == g then -- Main Hand Artifact, fix Offhand itemlevel calculations
						iLvlSum = iLvlSum - tonumber(realItemLevel) + tmpItemLevel
					end
				end
			elseif i == 17 and tmpItemLevel then -- Math says 2 Handers counts for two itemslots with same itemlevel when trying to match GetAverageItemLevel()
				local _, _, itemRarity = GetItemInfo(GetInventoryItemLink(unit, 16)) -- Try to get Main Hand rarity
				itemCount = itemCount + 1
				iLvlSum = iLvlSum + tmpItemLevel
				raritySum = raritySum + (itemRarity == LE_ITEM_QUALITY_HEIRLOOM and LE_ITEM_QUALITY_RARE or (itemRarity or 0)) -- Downscale Heirlooms to Rare
			end

			if realItemLevel and db.setting >= 1 then
				if currentUpgradeLevel and maxUpgradeLevel and currentUpgradeLevel < maxUpgradeLevel then
					upgradeString = "|TInterface\\PetBattles\\BattleBar-AbilityBadge-Strong:0:0:0:0:32:32:2:30:2:30|t"
				end

				if db.setting == 2 then
					if i == 2 or i == 3 or i == 11 or i == 12 or i == 15 then
						-- Neck, Shoulders, Finger0, Finger1, Chest
						if enchantID and enchantID > 0 then
							enchantString = "|T136244:0:0:0:0:32:32:2:30:2:30|t"
						elseif itemLink then
							enchantString = "|T136244:0:0:0:0:32:32:2:30:2:30:221:0:0|t"
						end
					end

					if (i == 16 and (upgradeTypeID == 256 or upgradeTypeID == 16777472) and not offhandArtifacts[itemID]) or -- Main Hand, Artifact Weapon
					(i == 17 and (upgradeTypeID == 256 or upgradeTypeID == 16777472) and offhandArtifacts[itemID]) then -- Offhand Artifact
						for b = 1, 3 do
							local _, gemLink = GetItemGem(itemLink, b)
							if gemLink and gemLink ~= "" then
								local _, _, _, _, _, _, _, _, _, t = GetItemInfo(gemLink)
								if t and t > 0 then
									gemString = gemString.."|T"..t..":0:0:0:0:32:32:2:30:2:30|t"
								end
							else
								gemString = gemString.."|TInterface\\ItemSocketingFrame\\UI-EmptySocket-Red:0:0:0:0:32:32:2:30:2:30|t"
								equipped[i] = nil -- Might be just missing data from server, try to update next time
							end
						end							
					elseif numBonuses and numBonuses > 0 then
						for b = 1, numBonuses do
							local bonusID = select(b, strsplit(":", affixes))
							if socketsTable[tonumber(bonusID)] then
								local _, gemLink = GetItemGem(itemLink, 1)
								if gemLink and gemLink ~= "" then
									local _, _, _, _, _, _, _, _, _, t = GetItemInfo(gemLink)
									if t and t > 0 then
										gemString = gemString.."|T"..t..":0:0:0:0:32:32:2:30:2:30|t"
									end
								else
									gemString = gemString.."|TInterface\\ItemSocketingFrame\\UI-EmptySocket-Red:0:0:0:0:32:32:2:30:2:30|t"
									equipped[i] = nil -- Might be just missing data from server, try to update next time
								end
							end
						end
					end
				end
			end

			local finalString
			if not realItemLevel or realItemLevel == nil or realItemLevel == "" then
				finalString = ""
				equipped[i] = nil -- Might be just missing data from server, try to update next time
			elseif i == 17 and tmpItemLevel and tmpItemLevel > 0 and not offhandArtifacts[itemID] then -- Fix Offhand for two slot Artifacts
				finalString = tmpItemLevel
			else
				finalString = realItemLevel

				if db.setting >= 1 then
					if db.inside then -- Anchor inside
						finalString = upgradeString .. "\n" .. finalString
					elseif i <= 5 or i == 15 or i == 9 or i == 17 then -- Left side
						finalString = finalString .. upgradeString
					else -- Right Side
						finalString = upgradeString .. finalString
					end
				end

				if db.setting == 2 then
					if (i == 16 or i == 17) then
						finalString = strtrim(gemString .. "\n" .. strtrim(finalString))
					elseif i <= 5 or i == 15 or i == 9 then -- Left side
						if db.inside then
							finalString = strtrim(enchantString .. gemString .. finalString)
						else
							finalString = strtrim(finalString .. enchantString .. gemString)
						end
					else -- Right Side
						finalString = strtrim(gemString .. enchantString .. finalString)
					end
				end
			end

			if db.color then
				finalString = colorString .. finalString .. colorCloseString
			end

			frame[i]:SetText(finalString)

			if i == 17 and offhandArtifacts[itemID] then -- Fix Main Hand for Offhand Artifacts
				finalString = tmpItemLevel

				if db.color then
					finalString = colorString .. finalString .. colorCloseString
				end

				frame[16]:SetText(finalString)
			end

			if db.inside or (((i == 16 and not offhandArtifacts[itemID]) or (i == 17 and offhandArtifacts[itemID])) and gemString ~= "") then
				frame[i]:SetWidth(_G.CharacterMainHandSlot:GetWidth() + 2)
			else
				frame[i]:SetWidth(frame[i]:GetStringWidth())
			end
		end
	end

	if frame == g then -- Show Average Itemlevel of rarity of Inspect target
		frame["avg"]:SetFormattedText("%s%d%s", ITEM_QUALITY_COLORS[floor(raritySum / max(itemCount, 1))].hex, floor(iLvlSum / max(itemCount, 1)), FONT_COLOR_CODE_CLOSE)
	end
end

local function _returnPoints(number) -- Return anchoring points of string #
	if db.inside then -- Inside
		return "BOTTOM", "BOTTOM", 2, 3
	else
		if number <= 5 or number == 15 or number == 9 then -- Left side
			return "LEFT", "RIGHT", xo, 0
		elseif number <= 14 then -- Right side
			return "RIGHT", "LEFT", -xo, 0
		else -- Weapon slots
			return "BOTTOM", "TOP", 2, yo
		end
	end
end

local function _anchorStrings(frame) -- Anchor strings to right places
	local point
	if frame == f then
		point = "Character"
	else
		point = "Inspect"
	end

	for i = 1, 17 do
		if i ~= 4 then
			local parent = _G[point..slotTable[i]]
			local myPoint, parentPoint, x, y = _returnPoints(i)
			frame[i]:ClearAllPoints()
			frame[i]:SetPoint(myPoint, parent, parentPoint, x or 0, y or 0)
		end
	end
end

local function _createStrings(frame) -- Create itemlevel strings
	local function _createFancy(parent, point, isLeft) -- Create Extra Fancy stuff
		local r, g, b, aLeft, aRight = .9, .9, .9, (isLeft and 0 or .4), (isLeft and .4 or 0)
		local fancy = parent:CreateTexture(nil, "BORDER")
		fancy:SetPoint((isLeft and "RIGHT" or "LEFT"), point, "CENTER")
		fancy:SetSize(65, 35)
		fancy:SetColorTexture(1, 1, 1)
		fancy:SetGradientAlpha("Horizontal", r, g, b, aLeft, r, g, b, aRight)

		fancy.top = parent:CreateTexture(nil, "BORDER")
		fancy.top:SetPoint("BOTTOM", fancy, "TOP")
		fancy.top:SetSize(65, 2)
		fancy.top:SetColorTexture(0, 0, 0)
		fancy.top:SetGradientAlpha("Horizontal", 0, 0, 0, 2*aLeft, 0, 0, 0, 2*aRight)

		fancy.bottom = parent:CreateTexture(nil, "BORDER")
		fancy.bottom:SetPoint("TOP", fancy, "BOTTOM")
		fancy.bottom:SetSize(65, 2)
		fancy.bottom:SetColorTexture(0, 0, 0)
		fancy.bottom:SetGradientAlpha("Horizontal", 0, 0, 0, 2*aLeft, 0, 0, 0, 2*aRight)

		return fancy
	end

	if frame == f then
		frame:SetFrameLevel(_G.CharacterHeadSlot:GetFrameLevel())
	else
		frame:SetFrameLevel(_G.InspectHeadSlot:GetFrameLevel())
		frame["avg"] = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
		frame["avg"]:SetPoint("TOP", _G.InspectModelFrameControlFrame, "BOTTOM", 0, -yo)
		frame.fancyLeft = _createFancy(frame, frame["avg"], true)
		frame.fancyRight = _createFancy(frame, frame["avg"], false)
	end

	for i = 1, 17 do
		if i ~= 4 then
			frame[i] = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalOutline")
		end
	end

	_anchorStrings(frame)
	frame:Hide()
	createCount = createCount + 1
end

local function _initDB(a, b) -- Check DB settings, Defaults-table, Settings-table
	if type(a) ~= "table" then return {} end
	if type(b) ~= "table" then b = {} end

	for k, v in pairs(a) do
		if type(b[k]) ~= type(v) then
			b[k] = v
		end
	end

	return b
end

local function _createHooks(frame) -- Init String creation and create Hooks
	if frame == f then
		_createStrings(f)

		_G.PaperDollFrame:HookScript("OnShow", function(self)
			for event in pairs(eventTable) do
				f:RegisterEvent(event)
			end
			_updateItems("player", f)
			f:Show()
		end)

		_G.PaperDollFrame:HookScript("OnHide", function(self)
			for event in pairs(eventTable) do
				f:UnregisterEvent(event)
			end
			f:Hide()
		end)
	else
		g = CreateFrame("Frame", nil, _G.InspectPaperDollFrame) -- iLevel number frame for Inspect
		_createStrings(g)

		_G.InspectPaperDollFrame:HookScript("OnShow", function(self)
			g:SetFrameLevel(_G.InspectHeadSlot:GetFrameLevel())
			f:RegisterEvent("INSPECT_READY")
			_updateItems("target", g)
			g:Show()
		end)

		_G.InspectPaperDollFrame:HookScript("OnHide", function(self)
			f:UnregisterEvent("INSPECT_READY")
			g:Hide()
		end)
	end

	if createCount > 1 then
		_createStrings = nil
		_createHooks = nil
		createCount = nil
		InspectUILoaded = nil
	end
end

local function OnEvent(self, event, ...) -- Event handler
	if event == "ADDON_LOADED" then
		if (...) == ADDON_NAME then
			_G.iLevelSetting = _initDB(DBDefaults, _G.iLevelSetting)
			db = _G.iLevelSetting
			_initDB = nil
			self:RegisterEvent("PLAYER_LOGIN")

		elseif (...) == "Blizzard_InspectUI" then
			if _initDB then -- iLevel isn't loaded yet, but Blizzard_InspectUI is, mark Hooks for later creation
				InspectUILoaded = true

			else -- iLevel has been loaded earlier, create Hooks
				self:UnregisterEvent(event)
				_createHooks(g)
			end
		end

	elseif event == "PLAYER_LOGIN" then
		self:UnregisterEvent(event)
		_createHooks(f)

		if InspectUILoaded then -- Blizzard_InspectUI is loaded and Hooks should be ready to be created
			self:UnregisterEvent("ADDON_LOADED")
			_createHooks(g)
		end

	elseif eventTable[event] then
		if (...) == 16 or (...) == 17 or event == "ARTIFACT_UPDATE" or event == "ARTIFACT_RELIC_FORGE_UPDATE" then
			equipped[16] = nil
			equipped[17] = nil
		end
		_updateItems("player", f)

	elseif event == "INSPECT_READY" then
		_updateItems("target", g)
	end
end
f:SetScript("OnEvent", OnEvent)

SLASH_ILEVEL1 = "/ilevel"

SlashCmdList.ILEVEL = function(...)
	if (...) == "0" or (...) == "1" or (...) == "2" or (...) == "inside" or (...) == "color" then
		if (...) == "inside" then
			db.inside = not db.inside
			_anchorStrings(f)
			if g then
				_anchorStrings(g)
			end
		elseif (...) == "color" then
			db.color = not db.color
		else
			db.setting = tonumber((...))
		end
		wipe(equipped)
		_updateItems("player", f)
		if g and _G.InspectPaperDollFrame:IsShown() then
			_updateItems("target", g)
		end
	end
	ChatFrame1:AddMessage("|cffff9999"..ADDON_NAME..":|r " .. NORMAL_FONT_COLOR_CODE .. "/ilevel" .. FONT_COLOR_CODE_CLOSE .. " ( 0 | 1 | 2 | inside | color )\n " .. NORMAL_FONT_COLOR_CODE .. "0" .. FONT_COLOR_CODE_CLOSE .. " - Only show item levels.\n " .. NORMAL_FONT_COLOR_CODE .. "1" .. FONT_COLOR_CODE_CLOSE .. " - Show item levels and upgrades.\n " .. NORMAL_FONT_COLOR_CODE .. "2" .. FONT_COLOR_CODE_CLOSE .. " - Show item levels, upgrades and enchants and gems.\n " .. NORMAL_FONT_COLOR_CODE .. "inside" .. FONT_COLOR_CODE_CLOSE .. " - Change anchor point between INSIDE and OUTSIDE.\n " .. NORMAL_FONT_COLOR_CODE .. "color" .. FONT_COLOR_CODE_CLOSE .. " - Change coloring between RARITY and DEFAULT.")
	ChatFrame1:AddMessage("|cffff9999"..ADDON_NAME..":|r Current settings are: " .. NORMAL_FONT_COLOR_CODE .. tostring(db.setting) .. FONT_COLOR_CODE_CLOSE .. " / " .. NORMAL_FONT_COLOR_CODE .. (db.inside and "INSIDE" or "OUTSIDE") .. FONT_COLOR_CODE_CLOSE .. " / " .. NORMAL_FONT_COLOR_CODE .. (db.color and "RARITY" or "DEFAULT") .. FONT_COLOR_CODE_CLOSE)
end
