local M = {}

--template
local template = nil
local templateVersion = -1

--helpers
local function ends_with(str, ending)
   return ending == "" or str:sub(-#ending) == ending
end

local json = require 'dkjson'  -- replace with your actual JSON library
local function readJsonFile(path)
    local file = io.open(path, "r")
    if not file then return nil end
    local content = file:read("*a")
    file:close()
    return content and json.decode(content) or nil
end

local function writeJsonFile(path, data, compact)
	local file = io.open(path, "w")
	if not file then return nil end
	local content = json.encode(data, { indent = not compact })
	file:write(content)
	file:close()
	return true
end



local function getAllVehicles()
  local vehicles = {}
  for _, v in ipairs(FS:findFiles('/vehicles', '*', 0, false, true)) do
    if v ~= '/vehicles/common' then
      table.insert(vehicles, string.match(v, '/vehicles/(.*)'))
    end
  end
  return vehicles
end

local function getBackfireJbeamPath(vehicleDir)
	local path = "/vehicles/" .. vehicleDir .. "/backfire/" .. vehicleDir .. "_backfire.jbeam"
	return path
end

local function loadExistingBackfireData(vehicleDir)
	return readJsonFile(getBackfireJbeamPath(vehicleDir))
end

local function makeAndSaveNewTemplate(vehicleDir, slotName)
	local templateCopy = deepcopy(template)
	
	--make main part
	local mainPart = {}
	templateCopy.slotType = slotName
	mainPart[vehicleDir .. "_backfire"] = templateCopy
	
	
	--save it
	local savePath = getBackfireJbeamPath(vehicleDir)
	writeJsonFile(savePath, mainPart, true)
end

--part helpers
local function findMainPart(vehicleJbeam) 
	if type(vehicleJbeam) ~= 'table' then return nil end
	
	for partKey, part in pairs(vehicleJbeam) do
		-- is it valid?
		if part.slotType == "main" then
			return partKey
		end
	end
	return nil
end

local function loadMainSlot(vehicleDir)
	--first check if a file exists named vehicleDir.jbeam
	local vehJbeamPath = "/vehicles/" .. vehicleDir .. "/" .. vehicleDir .. ".jbeam"
	local vehicleJbeam = nil
	
	if FS:fileExists(vehJbeamPath) then
		-- load it!
		vehicleJbeam = readJsonFile(vehJbeamPath)
		
		-- is it valid?
		local mainPartKey = findMainPart(vehicleJbeam)
		if mainPartKey ~= nil then
			return vehicleJbeam[mainPartKey]
		end
	end
	
	--if it wasn't valid, look through all files in this vehicle dir
	local files = FS:findFiles("/vehicles/" .. vehicleDir, "*.jbeam", -1, true, false)
	for _, file in ipairs(files) do
		-- load it!
		vehicleJbeam = readJsonFile(file)
		
		-- is it valid?
		local mainPartKey = findMainPart(vehicleJbeam)
		if mainPartKey ~= nil then
			return mainPartKey
		end
	end
	
	--if all else fails, return nil
	return nil
end

local function getSlotTypes(slotTable)
	local slotTypes = {}
	for i, slot in pairs(slotTable) do
		if i > 1 then
			local slotType = slot[1]
			table.insert(slotTypes, slotType)
		end
	end
	return slotTypes
end

--generation stuff
local function generate(vehicleDir)
	local existingData = loadExistingBackfireData(vehicleDir)
	if existingData ~= nil and existingData.version == templateVersion then
		log('D', 'GELua.backfireGenerator.onExtensionLoaded', vehicleDir .. " up to date")
		return
	else
		log('D', 'GELua.backfireGenerator.onExtensionLoaded', vehicleDir .. " NOT up to date, updating")
	end
	
	local mainSlotData = loadMainSlot(vehicleDir)
	if mainSlotData ~= nil and mainSlotData.slots ~= nil and type(mainSlotData.slots) == 'table' then
		for _,slotType in pairs(getSlotTypes(mainSlotData.slots)) do
			if ends_with(slotType, "_mod") then
				log('D', 'GELua.backfireGenerator.onExtensionLoaded', "found mod slot: " .. slotType)
				makeAndSaveNewTemplate(vehicleDir, slotType)
			end
		end
	end
	
end

local function generateAll()
	log('D', 'GELua.backfireGenerator.onExtensionLoaded', "running generateAll()")
	for _,veh in pairs(getAllVehicles()) do
		generate(veh)
	end
	log('D', 'GELua.backfireGenerator.onExtensionLoaded', "done")
end

local function loadTemplate()
	template = readJsonFile("/lua/ge/extensions/tommot/backfireGeneratorTemplates/template.json")
	if template ~= nil then
		templateVersion = template.version
	end
end

local function onExtensionLoaded()
	log('D', 'GELua.backfireGenerator.onExtensionLoaded', "Mods/TommoT Backfire Generator Loaded")
	if template == nil then loadTemplate() end
	if template == nil then 
		print("ERROR: Can't make Backfire mod. Template missing/invalid/failed to load!") 
		return
	end
	generateAll()
end

-- functions which should actually be exported
M.onExtensionLoaded = onExtensionLoaded
M.onModDeactivated = onExtensionLoaded
M.onModActivated = onExtensionLoaded
M.onExit = deleteTempFiles

return M