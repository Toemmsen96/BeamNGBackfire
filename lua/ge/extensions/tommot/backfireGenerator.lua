local M = {}

--template
local template = nil
local templateVersion = -1

--helpers
local function ends_with(str, ending)
   return ending == "" or str:sub(-#ending) == ending
end

local function readJsonFile(path)
    if isEmptyOrWhitespace(path) then
        log('E', 'readJsonFile', "path is empty")
        return nil
    end
    return jsonReadFile(path)
end

local function writeJsonFile(path, data, nice)
    return jsonWriteFile(path, data, nice)
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
	local path = "/mods/unpacked/generatedBackfire/vehicles/" .. vehicleDir .. "/backfire/" .. vehicleDir .. "_backfire.jbeam"
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
		log('D', 'generate', vehicleDir .. " up to date")
		return
	else
		log('D', 'generate', vehicleDir .. " NOT up to date, updating")
	end
	
	local mainSlotData = loadMainSlot(vehicleDir)
	if mainSlotData ~= nil and mainSlotData.slots ~= nil and type(mainSlotData.slots) == 'table' then
		for _,slotType in pairs(getSlotTypes(mainSlotData.slots)) do
			if ends_with(slotType, "_mod") then
				log('D', 'generate', "found mod slot: " .. slotType)
				makeAndSaveNewTemplate(vehicleDir, slotType)
			end
		end
	end
	-- if not, try slots2 because this is the newer slot type
	if mainSlotData ~= nil and mainSlotData.slots2 ~= nil and type(mainSlotData.slots2) == 'table' then
		for _,slotType in pairs(getSlotTypes(mainSlotData.slots2)) do
			if ends_with(slotType, "_mod") then
				log('D', 'generate', "found mod slot: " .. slotType)
				makeAndSaveNewTemplate(vehicleDir, slotType)
			end
		end
	end
	
end

local function generateAll()
	log('D', 'generateAll', "running generateAll()")
	for _,veh in pairs(getAllVehicles()) do
		generate(veh)
	end
	log('D', 'generateAll', "done")
end

local function loadTemplate()
	template = readJsonFile("/modslotgenerator/Afterfire.json")
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

local function deleteTempFiles()
	--delete all files in /mods/unpacked/generatedBackfire
	local files = FS:findFiles("/mods/unpacked/generatedBackfire", "*", -1, true, false)
	for _, file in ipairs(files) do
		FS:removeFile(file)
	end
	--TODO delete the folder itself
end

-- functions which should actually be exported
M.onExtensionLoaded = onExtensionLoaded
M.onModDeactivated = onExtensionLoaded
M.onModActivated = onExtensionLoaded
M.onExit = deleteTempFiles

return M