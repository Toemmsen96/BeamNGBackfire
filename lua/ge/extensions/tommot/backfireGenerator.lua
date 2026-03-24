local M = {}

--template
local template = nil
local templateVersion = -1

--helpers
local function isEmptyOrWhitespace(str)
    return str == nil or str:match("^%s*$") ~= nil
end

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

local function readJsonFileSafe(path)
	if isEmptyOrWhitespace(path) then
		log('E', 'readJsonFileSafe', "path is empty")
		return nil
	end
	if not FS:fileExists(path) then
		log('E', 'readJsonFileSafe', "file does not exist: " .. path)
		return nil
	end

	local content = readFile(path)
	if not content then
		log('E', 'readJsonFileSafe', "failed to read file: " .. path)
		return nil
	end

	local ok, data = pcall(json.decode, content)
	if not ok then
		log('E', 'readJsonFileSafe', "JSON decode error in " .. path .. ": " .. tostring(data))
		return nil
	end
	if type(data) ~= 'table' then
		log('E', 'readJsonFileSafe', "decoded JSON is not a table: " .. path)
		return nil
	end
	return data
end

local function writeJsonFile(path, data, nice)
    return jsonWriteFile(path, data, nice)
end

local function writeFileAtomic(finalPath, data, compact)
	local tempPath = finalPath .. ".tmp"

	-- Validate payload by roundtripping a temp file first.
	local tempWriteOk = writeJsonFile(tempPath, data, compact)
	if not tempWriteOk then
		log('E', 'writeFileAtomic', "failed to write temp file: " .. tempPath)
		return false
	end

	local tempValidate = readJsonFileSafe(tempPath)
	if tempValidate == nil then
		log('E', 'writeFileAtomic', "temp validation failed: " .. tempPath)
		FS:removeFile(tempPath)
		return false
	end

	local finalWriteOk = writeJsonFile(finalPath, data, compact)
	if not finalWriteOk then
		log('E', 'writeFileAtomic', "failed to write final file: " .. finalPath)
		FS:removeFile(tempPath)
		return false
	end

	local finalValidate = readJsonFileSafe(finalPath)
	if finalValidate == nil then
		log('E', 'writeFileAtomic', "final validation failed: " .. finalPath)
		FS:removeFile(tempPath)
		return false
	end

	FS:removeFile(tempPath)
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
	local path = "/mods/unpacked/generatedBackfire/vehicles/" .. vehicleDir .. "/backfire/" .. vehicleDir .. "_backfire.jbeam"
	return path
end

local function loadExistingBackfireData(vehicleDir)
	local path = getBackfireJbeamPath(vehicleDir)
	if not FS:fileExists(path) then
		return nil
	end
	return readJsonFileSafe(path)
end

local function makeAndSaveNewTemplate(vehicleDir, slotName)
	local templateCopy = deepcopy(template)
	if templateCopy == nil then
		log('E', 'makeAndSaveNewTemplate', "template copy failed for vehicle: " .. tostring(vehicleDir))
		return
	end
	
	--make main part
	local mainPart = {}
	templateCopy.slotType = slotName
	mainPart[vehicleDir .. "_backfire"] = templateCopy
	
	
	--save it
	local savePath = getBackfireJbeamPath(vehicleDir)
	FS:directoryCreate("/mods/unpacked/generatedBackfire/vehicles/" .. vehicleDir .. "/backfire/", true)
	local writeOk = writeFileAtomic(savePath, mainPart, true)
	if not writeOk then
		log('E', 'makeAndSaveNewTemplate', "failed to save template: " .. savePath)
		return
	end
	if not FS:fileExists(savePath) then
		log('E', 'makeAndSaveNewTemplate', "write reported success but file is missing: " .. savePath)
		return
	end
end

local function findTemplateVersion(modslotJbeam)
	if type(modslotJbeam) ~= 'table' then return nil end
	for _, part in pairs(modslotJbeam) do
		if type(part) == 'table' and part.version ~= nil then
			return part.version
		end
	end
	return nil
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
		vehicleJbeam = readJsonFileSafe(vehJbeamPath)
		
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
		vehicleJbeam = readJsonFileSafe(file)
		
		-- is it valid?
		local mainPartKey = findMainPart(vehicleJbeam)
		if mainPartKey ~= nil then
			return vehicleJbeam[mainPartKey]
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

local function getModSlot(mainSlotData)
	if mainSlotData ~= nil and mainSlotData.slots ~= nil and type(mainSlotData.slots) == 'table' then
		for _, slotType in pairs(getSlotTypes(mainSlotData.slots)) do
			if ends_with(slotType, "_mod") then
				return slotType
			end
		end
	end

	if mainSlotData ~= nil and mainSlotData.slots2 ~= nil and type(mainSlotData.slots2) == 'table' then
		for _, slotType in pairs(getSlotTypes(mainSlotData.slots2)) do
			if ends_with(slotType, "_mod") then
				return slotType
			end
		end
	end

	return nil
end

--generation stuff
local function generate(vehicleDir)
	local existingData = loadExistingBackfireData(vehicleDir)
	local existingVersion = findTemplateVersion(existingData)
	if existingVersion ~= nil and existingVersion == templateVersion then
		log('D', 'generate', vehicleDir .. " up to date")
		return
	else
		log('D', 'generate', vehicleDir .. " NOT up to date, updating (existingVersion=" .. tostring(existingVersion) .. ", templateVersion=" .. tostring(templateVersion) .. ")")
	end
	
	local mainSlotData = loadMainSlot(vehicleDir)
	local slotType = getModSlot(mainSlotData)
	if slotType ~= nil then
		log('D', 'generate', "found mod slot: " .. slotType)
		makeAndSaveNewTemplate(vehicleDir, slotType)
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
	template = readJsonFileSafe("/modslotgenerator/Afterfire.json")
	if template ~= nil then
		templateVersion = template.version
		if templateVersion == nil then
			templateVersion = 1.0
			template.version = templateVersion
		end
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
	-- only delete transient temp files, keep generated jbeams for next startup
	local files = FS:findFiles("/mods/unpacked/generatedBackfire", "*.tmp", -1, true, false)
	for _, file in ipairs(files) do
		FS:removeFile(file)
	end
end

-- functions which should actually be exported
M.onExtensionLoaded = onExtensionLoaded
M.onModDeactivated = deleteTempFiles
M.onModActivated = onExtensionLoaded
M.onExit = deleteTempFiles

return M