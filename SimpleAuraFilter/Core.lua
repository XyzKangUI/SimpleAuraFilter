local SimpleAuraFilter = LibStub("AceAddon-3.0"):NewAddon("SimpleAuraFilter", "AceConsole-3.0")

local GetSpellInfo = GetSpellInfo
local AceGUI = LibStub("AceGUI-3.0")

function SimpleAuraFilter:OnInitialize()
    -- Called when the addon is loaded
end

function SimpleAuraFilter:OnEnable()
    -- Called when the addon is enabled
    self.db = LibStub("AceDB-3.0"):New("SimpleAuraFilterDB")
    if not self.db.profile.filters then
        self.db.profile.filters = {}
    end

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
            custom = {
                type = 'execute',
                name = 'Buff Filter Insert Menu',
                desc = 'Insert spellname or spellId to hide',
                func = 'InsertBuffs',
            },
        },
    }

    self.db.RegisterCallback(self, "OnNewProfile", "HandleProfileChanges")
    self.db.RegisterCallback(self, "OnProfileReset", "HandleProfileChanges")
    self.db.RegisterCallback(self, "OnProfileChanged", "HandleProfileChanges")
    self.db.RegisterCallback(self, "OnProfileCopied", "HandleProfileChanges")

    options.args.profile = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)
    LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable("Simple Aura Filter", options)
    LibStub("AceConfigDialog-3.0"):AddToBlizOptions("Simple Aura Filter")

    self.buffs = {}

    -- Chat Command
    LibStub("AceConfig-3.0"):RegisterOptionsTable("SimpleAuraFilter", options, { "saf" })
end

function SimpleAuraFilter:HandleProfileChanges()
    local self = SimpleAuraFilter
    if not self.db.profile.filters then
        self.db.profile.filters = {}
    end
end


-- ********* Hooks

local function IsBadBuff(buttonName, index, filter)
    local unit = PlayerFrame.unit
    local name, _, count, _, duration = UnitAura(unit, index, filter);

    local buffName = buttonName .. index
    local buff = _G[buffName]

    if name then
        if SimpleAuraFilter.db.profile.filters[name] then
            buff.bad = true
            buff:SetAlpha(0.01)
            buff.duration:SetAlpha(0.01)
            buff.count:SetAlpha(0.01)
        else
            buff.bad = false
		buff:SetAlpha(1)
		buff.duration:SetAlpha(1)
		buff.count:SetAlpha(1)
        end
    end
    return 1
end

hooksecurefunc("AuraButton_Update", IsBadBuff)

local function New_BuffFrame_UpdateAllBuffAnchors()
    local buff, previousBuff, aboveBuff, index;
    local numBuffs = 0;
    local numAuraRows = 0;
    local slack = BuffFrame.numEnchants
    if (BuffFrame.numConsolidated > 0) then
        slack = slack + 1;    -- one icon for all consolidated buffs
    end

    for i = 1, BUFF_ACTUAL_DISPLAY do
        buff = _G["BuffButton" .. i];

        if buff:GetAlpha() < 1 then
            buff:SetPoint("TOPRIGHT", ConsolidatedBuffs, "TOPLEFT", 0, 100);
        else
            if (buff.consolidated) then
                if (buff.parent == BuffFrame) then
                    buff:SetParent(ConsolidatedBuffsContainer);
                    buff.parent = ConsolidatedBuffsContainer;
                end
            else
                numBuffs = numBuffs + 1;
                index = numBuffs + slack;
                if (buff.parent ~= BuffFrame) then
                    buff.count:SetFontObject(NumberFontNormal);
                    buff:SetParent(BuffFrame);
                    buff.parent = BuffFrame;
                end
                buff:ClearAllPoints();
                if ((index > 1) and (mod(index, BUFFS_PER_ROW) == 1)) then
                    -- New row
                    if (index == BUFFS_PER_ROW + 1) then
                        buff:SetPoint("TOPRIGHT", ConsolidatedBuffs, "BOTTOMRIGHT", 0, -BUFF_ROW_SPACING);
                    else
                        buff:SetPoint("TOPRIGHT", aboveBuff, "BOTTOMRIGHT", 0, -BUFF_ROW_SPACING);
                    end
                    aboveBuff = buff;
                elseif (index == 1) then
                    numAuraRows = 1;
                    buff:SetPoint("TOPRIGHT", BuffFrame, "TOPRIGHT", 0, 0);
                    aboveBuff = buff;
                else
                    if (numBuffs == 1) then
                        if (BuffFrame.numEnchants > 0) then
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
end
hooksecurefunc("BuffFrame_UpdateAllBuffAnchors", New_BuffFrame_UpdateAllBuffAnchors)

function SimpleAuraFilter:OpenMenu()
    local d = AceGUI:Create("Frame")
    d:SetTitle("Filters")
    d:SetWidth(400)
    d:SetHeight(225)
    d:SetCallback("OnClose", function(widget)
        AceGUI:Release(widget)
    end)
    d:SetLayout("Fill")
    local s = AceGUI:Create("ScrollFrame")
    d:AddChild(s)

    for name, _ in pairs(self.db.profile.filters) do
        local temp = AceGUI:Create("Button")
        temp:SetText(name)
        temp:SetCallback("OnClick", function(self, event)
            SimpleAuraFilter.db.profile.filters[name] = nil
            d:Hide()
            SimpleAuraFilter:OpenMenu()
        end)
        s:AddChild(temp)
    end
    d:Show()
end

function SimpleAuraFilter:InsertBuffs()
    local spellname, spellid

    local d = AceGUI:Create("Frame")
    d:SetTitle("Hide buffs by name or spellID")
    d:SetWidth(400)
    d:SetHeight(225)
    d:SetCallback("OnClose", function(widget)
        AceGUI:Release(widget)
    end)
    d:SetLayout("Flow")

    local editbox = AceGUI:Create("EditBox")
    editbox:SetLabel("Insert spell name:")
    editbox:SetWidth(200)
    editbox:SetCallback("OnEnterPressed", function(widget, event, text)
        spellname = text
    end)
    d:AddChild(editbox)

    local seditbox = AceGUI:Create("EditBox")
    seditbox:SetLabel("Insert spell ID:")
    seditbox:SetWidth(200)
    seditbox:SetCallback("OnEnterPressed", function(widget, event, text)
        spellid = GetSpellInfo(text)
    end)
    d:AddChild(seditbox)

    local button = AceGUI:Create("Button")
    button:SetText("Hide it!")
    button:SetWidth(200)
    button:SetCallback("OnClick", function()
        if spellname then
            self.db.profile.filters[spellname] = spellname
        end
        if spellid then
            self.db.profile.filters[spellid] = spellid
        end
    end)
    d:AddChild(button)
end