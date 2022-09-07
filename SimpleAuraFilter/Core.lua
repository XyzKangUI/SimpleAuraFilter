SimpleAuraFilter = LibStub("AceAddon-3.0"):NewAddon("SimpleAuraFilter", "AceConsole-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("SimpleAuraFilter")

S = SimpleAuraFilter

SimpleAuraFilter.debug = false

consolidatedBuffs = { };

function SimpleAuraFilter:OnInitialize()
    -- Called when the addon is loaded
   
end


function SimpleAuraFilter:OnEnable()
    -- Called when the addon is enabled
    self.db = LibStub("AceDB-3.0"):New("SimpleAuraFilterDB")
    if not self.db.profile.filters then self.db.profile.filters = {} end
	
	
	local options = {
		name = "SimpleAuraFilter",
		handler = SimpleAuraFilter,
		type = 'group',
		args = {
			menu = {
				type = 'execute',
				name = 'Buff Filter Menu',
				desc = 'Shows filter list',
				func = 'OpenMenu',
			},
			
--[[			toggle = {
				type = 'execute',
				name = 'Toggle Filter',
				desc = 'toggles buffs',
				func = 'ToggleAllBuffs',
			},--]]
		},
	}
	
	self.db.RegisterCallback( self, "OnNewProfile", "HandleProfileChanges" )
	self.db.RegisterCallback( self, "OnProfileReset", "HandleProfileChanges" )
	self.db.RegisterCallback( self, "OnProfileChanged", "HandleProfileChanges" )
	self.db.RegisterCallback( self, "OnProfileCopied", "HandleProfileChanges" )

	
	options.args.profile = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)
	LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable("Simple Aura Filter", options)
	LibStub("AceConfigDialog-3.0"):AddToBlizOptions("Simple Aura Filter")


	
	
	self.buffs = {}
    
	--Hooking the neccesary functions here
	

	BuffButton_OnClick = function (button) return SimpleAuraFilter:BuffButton_OnClick(button) end
	
	-- Repair damage done by overwriting
	ConsolidatedBuffs:HookScript("OnUpdate", ConsolidatedBuffs_OnUpdate)
	ConsolidatedBuffs:HookScript("OnEnter", ConsolidatedBuffs_OnEnter)

	
	-- Chat Command
	LibStub("AceConfig-3.0"):RegisterOptionsTable("SimpleAuraFilter", options, {"saf"})
end

function SimpleAuraFilter:HandleProfileChanges()
	local self = SimpleAuraFilter
	if not self.db.profile.filters then self.db.profile.filters = {} end
	BuffFrame_Update()
	BuffFrame_UpdateAllBuffAnchors()
end


-- ********* Hooks

function SimpleAuraFilter:BuffButton_OnClick(button)
	if IsShiftKeyDown() then
		name = UnitAura("player", button:GetID(), button.filter)
		if name then
			self.db.profile.filters[name] = 1
			BuffFrame_Update()
			BuffFrame_UpdateAllBuffAnchors()
		end
	else
		CancelUnitBuff(button.unit, button:GetID(), button.filter);
	end
end

local function BuffFrame_UpdateAllBuffAnchors()
	local buff, previousBuff, aboveBuff, index;
	local numBuffs = 0;
	local numAuraRows = 0;
	local hidden = 0;	-- SAF
	local slack = BuffFrame.numEnchants
	if ( BuffFrame.numConsolidated > 0 ) then
		slack = slack + 1;	-- one icon for all consolidated buffs
	end
	
	for i = 1, BUFF_ACTUAL_DISPLAY do
		buff = _G["BuffButton"..i];
		if not buff:IsShown() then
			hidden = hidden + 1
			numBuffs = numBuffs + 1;
		else
			if ( buff.consolidated ) then	
				if ( buff.parent == BuffFrame ) then
					buff:SetParent(ConsolidatedBuffsContainer);
					buff.parent = ConsolidatedBuffsContainer;
				end
			else
				numBuffs = numBuffs + 1;
				index = numBuffs + slack - hidden;
				if ( buff.parent ~= BuffFrame ) then
					buff.count:SetFontObject(NumberFontNormal);
					buff:SetParent(BuffFrame);
					buff.parent = BuffFrame;
				end
				buff:ClearAllPoints();
				if ( (index > 1) and (mod(index, BUFFS_PER_ROW) == 1) ) then
					-- New row
					if ( index == BUFFS_PER_ROW+1 ) then
						buff:SetPoint("TOPRIGHT", ConsolidatedBuffs, "BOTTOMRIGHT", 0, -BUFF_ROW_SPACING);
					else
						buff:SetPoint("TOPRIGHT", aboveBuff, "BOTTOMRIGHT", 0, -BUFF_ROW_SPACING);
					end
					aboveBuff = buff;
				elseif ( index == 1 ) then
					numAuraRows = 1;
					buff:SetPoint("TOPRIGHT", BuffFrame, "TOPRIGHT", 0, 0);
					aboveBuff = buff;
				else
					if ( not previousBuff ) then
						if ( BuffFrame.numEnchants > 0 ) then
							buff:SetPoint("TOPRIGHT", "TemporaryEnchantFrame", "TOPLEFT", BUFF_HORIZ_SPACING, 0);
							aboveBuff = TemporaryEnchantFrame;
						else
							buff:SetPoint("TOPRIGHT", ConsolidatedBuffs, "TOPLEFT", BUFF_HORIZ_SPACING, 0);
						end
					else
						buff:SetPoint("RIGHT", previousBuff, "LEFT", BUFF_HORIZ_SPACING, 0);
					end
				end
				previousBuff = buff;
			end
		end
	end

	if ( ConsolidatedBuffsTooltip:IsShown() ) then
		ConsolidatedBuffs_UpdateAllAnchors();
	end

	-- check if we need to manage frames
	local bottomEdgeExtent = BUFF_FRAME_BASE_EXTENT;
	if ( DEBUFF_ACTUAL_DISPLAY > 0 ) then
		bottomEdgeExtent = bottomEdgeExtent + DebuffButton1.offsetY + BUFF_BUTTON_HEIGHT + ceil(DEBUFF_ACTUAL_DISPLAY / BUFFS_PER_ROW) * (BUFF_BUTTON_HEIGHT + BUFF_ROW_SPACING);
	else
		bottomEdgeExtent = bottomEdgeExtent + numAuraRows * (BUFF_BUTTON_HEIGHT + BUFF_ROW_SPACING);
	end
	if ( BuffFrame.bottomEdgeExtent ~= bottomEdgeExtent ) then
		BuffFrame.bottomEdgeExtent = bottomEdgeExtent;
		UIParent_ManageFramePositions();
	end
end
hooksecurefunc("BuffFrame_UpdateAllBuffAnchors", BuffFrame_UpdateAllBuffAnchors)

local function ConsolidatedBuffs_UpdateAllAnchors()
	local buff, previousBuff, aboveBuff;
	local numBuffs = 0;
	local hidden = 0;
	local index = 0;
	
	for _, buff in pairs(consolidatedBuffs) do
		numBuffs = numBuffs + 1
		if ( buff.parent == BuffFrame ) then
			buff:SetParent(ConsolidatedBuffsContainer);
			buff.parent = ConsolidatedBuffsContainer;
		end
		if not buff:IsShown() then
			hidden = hidden + 1
		else
			index = numBuffs - hidden
			buff:ClearAllPoints();
			if ( (index > 1) and (mod(index, CONSOLIDATED_BUFFS_PER_ROW) == 1) ) then
				-- new row
				buff:SetPoint("TOP", aboveBuff, "BOTTOM", 0, -BUFF_ROW_SPACING);
				aboveBuff = buff;
			elseif ( not previousBuff ) then
				buff:SetPoint("TOPLEFT", ConsolidatedBuffsContainer, "TOPLEFT", 0, 0);
				aboveBuff = buff;
			else
				buff:SetPoint("LEFT", previousBuff, "RIGHT", 7, 0);
			end
			previousBuff = buff;
		end
	end
	ConsolidatedBuffsTooltip:SetWidth(min(index * 24 + 18, 114));
	ConsolidatedBuffsTooltip:SetHeight(floor((index + 3) / 4 ) * CONSOLIDATED_BUFF_ROW_HEIGHT + 16);
end
hooksecurefunc("ConsolidatedBuffs_UpdateAllAnchors", ConsolidatedBuffs_UpdateAllAnchors)

local function AuraButton_Update(buttonName, index, filter)
	local unit = PlayerFrame.unit;
	local name, texture, count, debuffType, duration, expirationTime, _, _, _, spellId, _, _, _, _, timeMod, shouldConsolidate = UnitAura(unit, index, filter);
	local buffName = buttonName..index;
	local buff = _G[buffName];

	if ( not name ) then
		-- No buff so hide it if it exists
		if ( buff ) then
			buff:Hide();
			buff.duration:Hide();
		end
		return nil;
	else
		local helpful = (filter == "HELPFUL" or filter == "HELPFUL");

		-- If button doesn't exist make it
		if ( not buff ) then
			if ( helpful ) then
				buff = CreateFrame("Button", buffName, BuffFrame, "BuffButtonTemplate");
			else
				buff = CreateFrame("Button", buffName, BuffFrame, "DebuffButtonTemplate");
			end
			buff.parent = BuffFrame;
		end
		-- Setup Buff
		buff:SetID(index);
		buff.unit = unit;
		buff.filter = filter;
		buff:SetAlpha(1.0);
		buff.exitTime = nil;
		buff.consolidated = nil;
		buff:Show();
		-- Set filter-specific attributes
		if ( not helpful ) then
			-- Anchor Debuffs
			DebuffButton_UpdateAnchors(buttonName, index);

			-- Set color of debuff border based on dispel class.
			local debuffSlot = _G[buffName.."Border"];
			if ( debuffSlot ) then
				local color;
				if ( debuffType ) then
					color = DebuffTypeColor[debuffType];
					if ( ENABLE_COLORBLIND_MODE == "1" ) then
						buff.symbol:Show();
						buff.symbol:SetText(DebuffTypeSymbol[debuffType] or "");
					else
						buff.symbol:Hide();
					end
				else
					buff.symbol:Hide();
					color = DebuffTypeColor["none"];
				end
				debuffSlot:SetVertexColor(color.r, color.g, color.b);
			end
		end

		if ( duration > 0 and expirationTime ) then
			if ( SHOW_BUFF_DURATIONS == "1" ) then
				buff.duration:Show();
			else
				buff.duration:Hide();
			end

			local timeLeft = (expirationTime - GetTime());
			if(timeMod > 0) then
				buff.timeMod = timeMod;
				timeLeft = timeLeft / timeMod;
			end

			if ( not buff.timeLeft ) then
				buff.timeLeft = timeLeft
				buff:SetScript("OnUpdate", AuraButton_OnUpdate);
			else
				buff.timeLeft = timeLeft
			end

			buff.expirationTime = expirationTime;
		else
			buff.duration:Hide();
			if ( buff.timeLeft ) then
				buff:SetScript("OnUpdate", nil);
			end
			buff.timeLeft = nil;
		end

		-- Set Texture
		local icon = _G[buffName.."Icon"];
		icon:SetTexture(texture);

		-- Set the number of applications of an aura
		if ( count > 1 ) then
			buff.count:SetText(count);
			buff.count:Show();
		else
			buff.count:Hide();
		end

		-- Refresh tooltip
		if ( GameTooltip:IsOwned(buff) ) then
			GameTooltip:SetUnitAura(PlayerFrame.unit, index, filter);
		end

		if ( GetCVarBool("consolidateBuffs") and shouldConsolidate ) then
			if ( buff.timeLeft and duration > 30 ) then
				buff.exitTime = expirationTime - max(10, duration / 10);
			end
			buff.expirationTime = expirationTime;			
			buff.consolidated = true;
			table.insert(consolidatedBuffs, buff);
		end
		-- this one is SAF code
		if SimpleAuraFilter:IsBadBuff(name) then
			buff.bad = true;
			buff:Hide();
			buff.duration:Hide();
			buff.count:Hide();
		else
			buff.bad = false;
		end
	end
	return 1;
end
hooksecurefunc("AuraButton_Update", AuraButton_Update)
		
function SimpleAuraFilter:IsBadBuff(name)
	if not self.db.profile.filters then return false end
	return self.db.profile.filters[name]
end


function SimpleAuraFilter:AllBuffs()
	return self.allbuffs
end

function SimpleAuraFilter:ToggleAllBuffs()
	self.allbuffs = not self.allbuffs
	if self.allbuffs then self:Print("Filter off") else self:Print("Filter on") end
	BuffFrame_Update()
	BuffFrame_UpdateAllBuffAnchors()
end


function SimpleAuraFilter:OpenMenu()
	local d = LibStub("AceGUI-3.0"):Create("Frame")
	d:SetTitle("Filters")
	d:SetWidth(400)
	d:SetHeight(225)
	d:SetLayout("Fill")
	local s = LibStub("AceGUI-3.0"):Create("ScrollFrame")
	d:AddChild(s)
	
	for name,_ in pairs(self.db.profile.filters) do
		local temp = LibStub("AceGUI-3.0"):Create("Button")				
		temp:SetText(name)
		temp:SetCallback("OnClick", function (self, event)
						SimpleAuraFilter.db.profile.filters[name] = nil
						d:Hide()
						BuffFrame_Update()		
						BuffFrame_UpdateAllBuffAnchors()
						ConsolidatedBuffs_UpdateAllAnchors()
						SimpleAuraFilter:OpenMenu()
						end)
		s:AddChild(temp)
	end
    d:Show()
end


-- ********* Helpers

function SimpleAuraFilter:Debug(...)
    if self.debug then self:Print(...) end
end