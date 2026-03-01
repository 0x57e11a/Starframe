--@name Starframe | Wire Library
--@author The Starframe Team
--@class none

--[[

    The wire library is a modified version of the original wire library
    provided by Starfall, adapted to work within the Starframe ecosystem.

--]]

if CLIENT then return end

local inputs = {}
local outputs = {}

local starwire = {
    create = wire.create,
    delete = wire.delete,
    getInputs = wire.getInputs,
    getOutputs = wire.getOutputs,
    self = wire.self,

    ports = wire.ports,

    PORT_TYPE_ANGLE = wire.PORT_TYPE_ANGLE,
    PORT_TYPE_ARRAY = wire.PORT_TYPE_ARRAY,
    PORT_TYPE_ENTITY = wire.PORT_TYPE_ENTITY,
    PORT_TYPE_NUMBER = wire.PORT_TYPE_NUMBER,
    PORT_TYPE_STRING = wire.PORT_TYPE_STRING,
    PORT_TYPE_VECTOR = wire.PORT_TYPE_VECTOR,
    PORT_TYPE_VECTOR2 = wire.PORT_TYPE_VECTOR2,
    PORT_TYPE_VECTOR4 = wire.PORT_TYPE_VECTOR4,
    PORT_TYPE_WIRELINK = wire.PORT_TYPE_WIRELINK
}

local allowedInputTypes = {
	[wire.PORT_TYPE_ANGLE] = true,
	[wire.PORT_TYPE_ARRAY] = true,
	[wire.PORT_TYPE_ENTITY] = true,
	[wire.PORT_TYPE_NUMBER] = true,
	[wire.PORT_TYPE_STRING] = true,
	[wire.PORT_TYPE_VECTOR] = true,
	[wire.PORT_TYPE_VECTOR2] = true,
	[wire.PORT_TYPE_VECTOR4] = true,
	[wire.PORT_TYPE_WIRELINK] = true
}

local allowedOutputTypes = {
	[wire.PORT_TYPE_ANGLE] = true,
	[wire.PORT_TYPE_ARRAY] = true,
	[wire.PORT_TYPE_ENTITY] = true,
	[wire.PORT_TYPE_NUMBER] = true,
	[wire.PORT_TYPE_STRING] = true,
	[wire.PORT_TYPE_VECTOR] = true,
	[wire.PORT_TYPE_VECTOR2] = true,
	[wire.PORT_TYPE_VECTOR4] = true
}

local mainframeLoading = true
---Creates all wire inputs
local function buildInputs()
    if mainframeLoading then return end

    local names = {}
    local types = {}
    local descriptions = {}

    for _, inputList in pairs(inputs) do
    	for i = 1, #inputList.names do
    		names[#names + 1] = inputList.names[i]
    		types[#types + 1] = inputList.types[i]
    		descriptions[#descriptions + 1] = inputList.descriptions[i] or ""
    	end
    end

    wire.createInputs(names, types, descriptions)
end


---Creates all wire outputs
local function buildOutputs()
    if mainframeLoading then return end

    local names = {}
    local types = {}
    local descriptions = {}

    for _, outputList in pairs(outputs) do
    	for i = 1, #outputList.names do
    		names[#names + 1] = outputList.names[i]
    		types[#types + 1] = outputList.types[i]
    		descriptions[#descriptions + 1] = outputList.descriptions[i] or ""
    	end
    end

    wire.createOutputs(names, types, descriptions)
end


---Returns the number of inputs/outputs for a specific module or all
local function getIOCount(ioType, moduleId)
	local ioList = (ioType == "input" and inputs) or outputs

	if moduleId ~= nil then
		return (ioList[moduleId] and #ioList[moduleId].names) or 0
	else
		local count = 0
		for _, value in pairs(ioList) do
			count = count + #value.names
		end

		return count
	end
end


---Checks whether the current IO name, type and description is valid.
local function checkIO(index, ioType, name, type, desc)
	types.check(name, "string", "name #"..tostring(index), 3)
	types.check(type, "string", "type #"..tostring(index), 3)
	types.check(desc, "string?", "description #"..tostring(index), 3)

	if not string.find(name, "^[A-Z][%a%d%s]*$") then
		error("Invalid "..ioType.." name at index "..tostring(index).." (must be alphanumeric starting with upper-case)", 3)
	end

	local allowList = (ioType == "input" and allowedInputTypes) or allowedOutputTypes
	if not allowList[type:upper()] then
		error("Invalid/unsupported "..ioType.." type at index "..tostring(index)..": "..type, 3)
	end
end


---Checks all registered inputs/outputs for duplicate names
local function checkForDuplicateName(moduleId, ioType, name)
	local ioList = (ioType == "input" and inputs) or outputs
	local filteredIOList = table.except(ioList, ioList[moduleId])

	for otherModuleId, list in pairs(filteredIOList) do
		if table.contains(list.names, name) then
			local otherModulePath = base64.decode(otherModuleId)
			error("Duplicate "..ioType.." name '"..name.."' (registered in "..otherModulePath..")", 3)
		end
	end
end

---Replaces the standard wire library's createInput function
---@param names string[]
---@param inTypes string[]
---@param descriptions string[]?
---@see wire.createInputs
function starwire.createInputs(names, inTypes, descriptions)
    types.check(names, "table", "names", 2)
    types.check(inTypes, "table", "types", 2)
    types.check(descriptions, "table?", "descriptions", 2)

	if #names ~= #inTypes then
        error("Names and Types must have the same amount of values", 2)
    end

	---Set moduleId to 1 for library-handled IO
    local moduleId = bootstrapper.getCallingModuleId() or 1
	local moduleInputs = {
        names = {unpack(names)},
        types = {unpack(inTypes)},
        descriptions = {unpack(descriptions or {})}
    }

	--- Get total count - current inputs + expected inputs
	local expectedCount = getIOCount("input") - getIOCount("input", moduleId) + #moduleInputs.names
	if expectedCount > 64 then
		error("Expected input count is over the maximum of 64", 2)
	end

	for i = 1, #moduleInputs.names do
		local name = moduleInputs.names[i]
		local type = moduleInputs.types[i]
		local desc = moduleInputs.descriptions[i]

		checkForDuplicateName(moduleId, "input", name)
		checkIO(i, "input", name, type, desc)
	end

    inputs[moduleId] = moduleInputs
    buildInputs()
end


---Replaces the standard wire library's createOutput function
---@param names string[]
---@param outTypes string[]
---@param descriptions string[]?
---@see wire.createOutputs
function starwire.createOutputs(names, outTypes, descriptions)
	types.check(names, "table", "names", 2)
	types.check(outTypes, "table", "types", 2)
	types.check(descriptions, "table?", "descriptions", 2)

	---Set moduleId to 1 for external IO (library-handled)
	local moduleId = bootstrapper.getCallingModuleId() or 1
	local moduleOutputs = {
		names = {unpack(names)},
		types = {unpack(outTypes)},
		descriptions = {unpack(descriptions or {})}
	}

	if #names ~= #outTypes then
		error("Names and Types must have the same amount of values", 2)
	end

	--- Get total count - current outputs + expected outputs
	local expectedCount = getIOCount("output") - getIOCount("output", moduleId) + #moduleOutputs.names
	if expectedCount > 64 then
		error("Expected output count is over the maximum of 64", 2)
	end

	for i = 1, #moduleOutputs.names do
		local name = moduleOutputs.names[i]
		local type = moduleOutputs.types[i]
		local desc = moduleOutputs.descriptions[i]

		checkForDuplicateName(moduleId, "output", name)
		checkIO(i, "output", name, type, desc)
	end

	outputs[moduleId] = moduleOutputs
	buildInputs()
end


bootstrapper.addToEnvironment("wire", starwire)

-- Build all IO after all modules have loaded to avoid wire IO from being unliked on code load.
hook("postmoduleload", "starframe_wire_init", function()
    mainframeLoading = false
    buildInputs()
    buildOutputs()
end)