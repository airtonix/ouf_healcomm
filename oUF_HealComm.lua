--==============================================================================
--
-- oUF_HealComm
--
-- Uses data from LibHealComm-3.0 to add incoming heal estimate bars onto units 
-- health bars.
--
-- * currently won't update the frame if max HP is unknown (ie, restricted to 
--   players/pets in your group that are in range), hides the bar for these
-- * can define frame.ignoreHealComm in layout to not have the bars appear on 
--   that frame
--
--=============================================================================

if not oUF then return end

local oUF_HealComm = {}

local healcomm = LibStub("LibHealComm-3.0")

local playerName = UnitName("player")
local playerIsCasting = false
local playerHeals = 0
local playerTarget = ""
oUF.debug=false
local layoutName = "HealComm"
local layoutPath = "Interface\\Addons\\oUF_"..layoutName
local mediaPath = layoutPath.."\\media\\"
local font, fontSize = mediaPath.."font.ttf", 11		-- The font and fontSize

function round(num, idp)
  if idp and idp>0 then
    local mult = 10^idp
    return math.floor(num * mult + 0.5) / mult
  end
  return math.floor(num + 0.5)
end

local  numberize = function(val)
	if(val >= 1e3) then
        return ("%.1fk"):format(val / 1e3)
	elseif (val >= 1e6) then
		return ("%.1fm"):format(val / 1e6)
	else
		return round(val,1)
	end
end

local function Hex(r, g, b)
	if type(r) == "table" then
		if r.r then r, g, b = r.r, r.g, r.b else r, g, b = unpack(r) end
	end
	return string.format("|cff%02x%02x%02x", r*255, g*255, b*255)
end


--set texture and color here
local color = {
    r = 0,
    g = 1,
    b = 0,
    a = .25,
}


--update a specific bar
local updateHealCommBar = function(frame, unit)
	if not unit or unit == nil then return end
    local curHP = UnitHealth(unit)
    local maxHP = UnitHealthMax(unit)
    local percHP = curHP / maxHP
	local parentBar = frame.hcbParent
    local incHeals = select(2, healcomm:UnitIncomingHealGet(unit, GetTime())) or 0

    --add player's own heals if casting on this unit
    if playerIsCasting then
        for i = 1, select("#", playerTarget) do
            local target = select(i, playerTarget)
            if target == unit then
                incHeals = incHeals + playerHeals
            end
        end
    end

    --hide if unknown max hp or no heals inc
    if maxHP == 100 or incHeals == 0 then
        frame.HealCommBar:Hide()
        return
    else
        frame.HealCommBar:Show()
    end
	
    percInc = incHeals / maxHP
    h = parentBar:GetHeight()
    w = parentBar:GetWidth()
    orient = parentBar:GetOrientation()
    
    fHcb = frame.HealCommBar
    fHcb:ClearAllPoints()
    fHcb:SetFrameStrata("DIALOG")
    
    if(orient=="VERTICAL")then
		fHcb:SetHeight(percInc * h)
		fHcb:SetWidth(w)
		fHcb:SetPoint("BOTTOM", parentBar, "BOTTOM", 0, h * percHP)
	else
		fHcb:SetWidth(percInc * w)
		fHcb:SetHeight(h)
		fHcb:SetPoint("LEFT", parentBar, "LEFT", w * percHP,0)
	end
	if(fHcb.Amount)then
		fHcb.Amount:SetText(numberize(incHeals))
	end

end

--used by library callbacks, arguments should be list of units to update
local updateHealCommBars = function(...)
	for i = 1, select("#", ...) do
		local unit = select(i, ...)

        --search current oUF frames for this unit
        for frame in pairs(oUF.units) do
            local name, server = UnitName(frame)
            if server then name = strjoin("-",name,server) end
            if name == unit and not oUF.units[frame].ignoreHealComm then
                updateHealCommBar(oUF.units[frame],unit)
            end
        end
	end
end

local function hook(frame)
	if frame.ignoreHealComm then return end
	if not frame.hcbParent then 
		if frame.Health then
			frame.hcbParent = frame.Health
		else
			return 
		end
	end
	local parentBar = frame.hcbParent
    --create heal bar here and set initial values
	local hcb = CreateFrame"StatusBar"
    if(parentBar:GetOrientation() =="VERTICAL")then
		hcb:SetWidth(parentBar:GetWidth()) -- same height as health bar
		hcb:SetHeight(4) --no initial width
		hcb:SetStatusBarTexture(parentBar:GetStatusBarTexture():GetTexture())
		hcb:SetStatusBarColor(color.r, color.g, color.b, color.a)
		hcb:SetParent(frame)
		hcb:SetPoint("BOTTOMLEFT", parentBar, "TOPLEFT",0,0) --attach to immediate right of health bar to start
		hcb:Hide() --hide it for now
	else
		hcb:SetHeight(parentBar:GetHeight()) -- same height as health bar
		hcb:SetWidth(4) --no initial width
		hcb:SetStatusBarTexture(parentBar:GetStatusBarTexture():GetTexture())
		hcb:SetStatusBarColor(color.r, color.g, color.b, color.a)
		hcb:SetParent(frame)
		hcb:SetPoint("LEFT", parentBar, "RIGHT",0,0) --attach to immediate right of health bar to start
		hcb:Hide() --hide it for now
	end

	healthBarTextObj = parentBar.value or parentBar.text
	if(healthBarTextObj)then
		fontName, fontHeight, fontFlags = healthBarTextObj:GetFont()
	else
		fontName, fontHeight, fontFlags = font, fontSize, "outline"
	end
	
	hcb.Amount = hcb:CreateFontString(nil, "OVERLAY")
	hcb.Amount:SetFont(fontName, fontHeight, fontFlags)
	hcb.Amount:SetPoint('CENTER',hcb, 0, 0)
	hcb.Amount:SetTextColor(1,1,1,.5)
	hcb.Amount:SetJustifyH("CENTER")
	
	if(frame.FontObjects ~= nil) then 
		frame.FontObjects["incomingHeals"] = {
			name = "Incoming Heals",
			object = hcb.Amount
		}
	end
	
	frame.HealCommBar = hcb

	local o = frame.PostUpdateHealth
	frame.PostUpdateHealth = function(...)
		if o then o(...) end
        local name, server = UnitName(frame.unit)
        if server then name = strjoin("-",name,server) end
        updateHealCommBar(frame, name) --update the bar when unit's health is updated
	end
end

--hook into all existing frames
for i, frame in ipairs(oUF.objects) do hook(frame) end

--hook into new frames as they're created
oUF:RegisterInitCallback(hook)

--set up LibHealComm callbacks
function oUF_HealComm:HealComm_DirectHealStart(event, healerName, healSize, endTime, ...)
	if healerName == playerName then
		playerIsCasting = true
		playerTarget = ... 
		playerHeals = healSize
	end
    updateHealCommBars(...)
end

function oUF_HealComm:HealComm_DirectHealUpdate(event, healerName, healSize, endTime, ...)
    updateHealCommBars(...)
end

function oUF_HealComm:HealComm_DirectHealStop(event, healerName, healSize, succeeded, ...)
    if healerName == playerName then
        playerIsCasting = false
    end
    updateHealCommBars(...)
end

function oUF_HealComm:HealComm_HealModifierUpdate(event, unit, targetName, healModifier)
    updateHealCommBars(unit)
end

healcomm.RegisterCallback(oUF_HealComm, "HealComm_DirectHealStart")
healcomm.RegisterCallback(oUF_HealComm, "HealComm_DirectHealUpdate")
healcomm.RegisterCallback(oUF_HealComm, "HealComm_DirectHealStop")
healcomm.RegisterCallback(oUF_HealComm, "HealComm_HealModifierUpdate")
