--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
-- file:    air-screen-keeper.lua
-- brief:
-- author:  Leonid Krashenko <leonid.krashenko@gmail.com>
--
-- Copyright (C) 2014.
-- Licensed under the terms of the GNU GPL, v2.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
function widget:GetInfo()
	return {
		name = "Air Screen Keeper",
		desc = "Notifies player if an air-screen is under attack from the ground.",
		author = "jetbird",
		date = "Apr 26, 2015",
		license = "GNU GPL, v2",
		layer = 0,
		enabled = true --  loaded by default?
	}
end


local glColor = gl.Color
local glDepthTest = gl.DepthTest
local glBeginEnd = gl.BeginEnd
local glLineWidth = gl.LineWidth
local glShape = gl.Shape
local glDrawGroundCircle = gl.DrawGroundCircle
local GetUnitDefID = Spring.GetUnitDefID
local spGetAllUnits = Spring.GetAllUnits
local spGetSpectatingState = Spring.GetSpectatingState
local spGetMyPlayerID = Spring.GetMyPlayerID
local spGetPlayerInfo = Spring.GetPlayerInfo
local spGetMyTeamID = Spring.GetMyTeamID
local spGetTeamUnits = Spring.GetTeamUnits
local spGetUnitDefID = Spring.GetUnitDefID
local spGiveOrderToUnitMap = Spring.GiveOrderToUnitMap
local spGetGroundInfo = Spring.GetGroundInfo
local spGetGroundHeight = Spring.GetGroundHeight
local spMarkerAddPoint = Spring.MarkerAddPoint
local spGetUnitsInCylinder = Spring.GetUnitsInCylinder
local spGetCommandQueue = Spring.GetCommandQueue
local echo = Spring.Echo

local units = {} -- player's units
local airscreen = {}
local armSpyUDId = UnitDefNames["armspy"].id
local coreSpyUDId = UnitDefNames["corspy"].id
local targets = {}
local spyTimeToBlast = {}
local lastMarkTime = 0
local MARK_DELAY = 3


--[[
function widget:DrawWorldPreUnit()
	glLineWidth(3.0)
	glDepthTest(true)
	glColor(1, 0, 0, .2)
	for id, v in pairs(units) do
		local posx,posy,posz = Spring.GetUnitPosition(id)
		gl.Color(0.5, 0.5, 0.5, 0.5);
		gl.DrawGroundCircle(posx, posy, posz, v, 25)
	end

	glDepthTest(false)
end
--]]
--

local function UnitHasPatrolOrder(unitID)
	local queue=spGetCommandQueue(unitID,2)
	for i,cmd in ipairs(queue) do
		if cmd.id==CMD.PATROL then
			return true
		end
	end
	return false
end


--[[
function widget:DrawScreenEffects()
    for id, v in pairs(units) do
        local x,y=Spring.WorldToScreenCoords(Spring.GetUnitPosition(id))
		local status = 'none';
		
		if airscreen[id] then
			status = 'airscreen'
		end

		
        gl.Text("status: "..status,x,y,16,"od")
    end
end
--]]


local function dispatchUnit(unitID, unitDefID)
	local udef = UnitDefs[unitDefID]
	
	if udef.isAirUnit then
		units[unitID] = true
	end

	--[[
	--local ud = UnitDefs[unitDefID]
	if unitDefID == armSpyUDId or unitDefID == coreSpyUDId then
		local udef = UnitDefs[unitDefID]
		local selfdBlastId = WeaponDefNames[string.lower(udef["selfDExplosion"])].id
		local selfdBlastRadius = WeaponDefs[selfdBlastId]["damageAreaOfEffect"]
		units[unitID] = selfdBlastRadius
		spyTimeToBlast[unitID] = 0
		--echo ("spy detected "..selfdBlastRadius)
	end
	--]]
end

function updateAirScreenUnits()
	for id, v in pairs(units) do
		if UnitHasPatrolOrder(id) then
			airscreen[id] = true
		end
	end
end

function widget:GameFrame(frameNum)
	if (frameNum % 128 ) == 0 then
		updateAirScreenUnits()
	end
end

function widget:Update(dt)
	lastMarkTime = lastMarkTime - dt
end

function notify(unitID)
	if (lastMarkTime < 0) then
		lastMarkTime = MARK_DELAY
		
		local msg = "AA"
		local x, y, z = Spring.GetUnitPosition(unitID)
		spMarkerAddPoint(x, y, z, msg, true)
	end
end

--
function widget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
	if airscreen[unitID] then
		if attackerID then
			notify(attackerID)
		else
			notify(unitID)
		end
	end
end
--]]

function widget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
	if airscreen[unitID] then
		if attackerID then
			notify(attackerID)
		else
			notify(unitID)
		end
		airscreen[unitID] = nil
	end
	units[unitID] = nil
end

function widget:UnitCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions)
	local udef = UnitDefs[unitDefID]
	--if teamID ~= 0 then echo ("team ID "..teamID) end
	if cmdID == CMD.PATROL and udef.isAirUnit then
		--echo ("new Airscreen unit!")
		airscreen[unitID] = true
	else
		airscreen[unitID] = nil
	end

end

function widget:UnitFinished(unitID, unitDefID, unitTeam)
	if (unitTeam ~= spGetMyTeamID()) then
		return
	end
	dispatchUnit(unitID, unitDefID)
end

function widget:UnitTaken(unitID, unitDefID, unitTeam, newTeam)
	widget:UnitDestroyed(unitID, unitDefID)
end


function widget:UnitGiven(unitID, unitDefID, unitTeam, oldTeam)
	widget:UnitFinished(unitID, unitDefID, unitTeam)
end


function widget:Initialize()
																																						
	local playerID = spGetMyPlayerID()
	local _, _, spec, _, _, _, _, _ = spGetPlayerInfo(playerID)
	if spec == true then
		echo ("<Air screen keeper> Spectator mode. Widget removed")
		widgetHandler:RemoveWidget(self)
	end

	local allunits = spGetTeamUnits(spGetMyTeamID())
	for _, uid in ipairs(allunits) do
		dispatchUnit(uid, spGetUnitDefID(uid))
	end
end

