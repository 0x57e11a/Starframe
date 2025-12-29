--@name Starframe | Bootstrapper
--@author The Starframe Team
--@class none

--@includedir starframe/libraries
--@includedir starframe/modules

--[[

	**** Starfarme ****
	Starframe's bootstrapper, loads all libraries & modules.

	All libraries are loaded first and populate the environment used by modules.
	Modules are then loaded in separate protected environments as a way to isolate each module from each other.

--]]


-- The main mainframe table, containing mainframe-wide constants and functions.
mainframe = {
	name = "Starframe",				-- The name of the mainframe
	version = "0.1.0b",				-- The current version of the mainframe
	author = "The Starframe Team"	-- The author(s) of the mainframe
}


-- The bootstrapper table, containing functions for setting up the mainframe and loading all assets.
bootstrapper = {}

-- The environment metatable, base for all module environments.
local environment_mt = {
	__metatable = "Starframe Environment"
}

environment_mt.__index = environment_mt


-- Creates an isolated environment for a module to run in.
---@param modulePath string The path to the module.
---@return table The created environment.
function bootstrapper.createEnvironment(modulePath)
	assert(type(modulePath) == "string", 'Invalid type for "modulePath" parameter. (Expected string, got '..type(modulePath)..")")

	return setmetatable({
		MODULE_PATH = modulePath
	}, environment_mt)
end


-- Adds a value to the module's environment.
---@param key any The key by which the value will be accessible as.
---@param value any The value to add to the environment.
function bootstrapper.addToEnvironment(key, value)
	assert(key ~= nil, '"key" parameter cannot be nil.')
	environment_mt[key] = value
end


-- Provides a standard error-catching mechanism for libraries to use.
---@param errorTrace Error The stacktrack of the error that happened in module code.
---@retrun Error The stacktrace.
function bootstrapper.handleError(errorTrace)
	print(errorTrace) -- TODO: Make a less primitive error handler :3
	return errorTrace
end


-- Loading order table for library setup.
local libraryLoadOrder = {}

-- Root folders for both shared and local mainframe file locations.
local sharedRoot = "starframe"
local localRoot = string.gsub(starfall.getMainFileName(), "/[^/]+$", "", 1)


-- Sets the priority for a given library.
---@param path string The library's relative path from the mainframe's root.
---@param priority int The priority of the library, a higher number will make the library load sooner.
function bootstrapper.setLibraryPriority(path, priority)
	assert(type(path) == "string", 'Invalid type for "path" parameter. (Expected string, got '..type(path)..")")
	assert(type(priority) == "number", 'Invalid type for "priority" parameter. (Expected number, got '..type(prority)..")")

	-- If existing entry with path exists, update it.
	for _, existingEntry in pairs(libraryLoadOrder) do
		if existingEntry.path == path then
			existingEntry.priority = priority
			return
		end
	end

	-- Otherwise add new entry
	libraryLoadOrder[#libraryLoadOrder + 1] = {
		path = path,
		priority = priority
	}
end


-- Binds a script to a loading order table
-- Updates the matching loading order entry or creates it.
---@param path string The script's relative path.
---@param function script The script to bind
---@param table loadingOrder The loading order table to bind the script to.
---@param bool isFromShared Whether the script comes from shared or local.
local function bindScript(path, script, loadingOrder, isFromShared)
	local entry

	for i = 1, #loadingOrder do
		if loadingOrder[i].path == path then
			entry = loadingOrder[i]
		end
	end

	if entry == nil then
		loadingOrder[#loadingOrder + 1] = {
			path = path
		}

		entry = loadingOrder[#loadingOrder]
	end

	if isFromShared then
		entry.sharedScript = script
	else
		entry.localScript = script
	end
end


-- Loads all libraries in order.
-- Libraries are loaded by priority, higher priorities are loaded first.
-- Libraries with no set priority are loaded in a random order.
function bootstrapper.loadLibraries()
	local librariesToLoad = starfall.getScripts()

	-- Remove all files that are not libraries from the list
	for path, script in pairs(librariesToLoad) do
		local isSharedLibrary = string.find(path, sharedRoot.."/libraries/") ~= nil
		local isLocalLibrary = string.find(path, localRoot.."/libraries/") ~= nil

		if not (isLocalLibrary or isSharedLibrary) then
			librariesToLoad[path] = nil
			goto continueLibraryLoad
		end

		-- Normalise file paths
		local localPath
		if isSharedLibrary then
			localPath = utf8.sub(path, #(sharedRoot.."/libraries/") + 1)
		else
			localPath = utf8.sub(path, #(localRoot.."/libraries/") + 1)
		end

		-- Bind library to loading order
		bindScript(localPath, script, libraryLoadOrder, isSharedLibrary)

		::continueLibraryLoad::
	end

	-- Sort libraries by priority
	table.sort(libraryLoadOrder, function(a, b)
		if a.priority == nil then return false end
		if b.priority == nil then return true end

		return a.priority >= b.priority
	end)

	-- Load all libraries
	for i = 1, #libraryLoadOrder do
		local entry = libraryLoadOrder[i]

		-- Take libraries from local files in priority to shared files.
		local script = entry.localScript or entry.sharedScript
		script()
	end
end


local function resolveDependencies(dependencies)
	local visited = {} -- "visiting" | "visited"
	local result = {}

	local function visit(node)
		if visited[node] == "visiting" then
			error("Circular dependency detected at: "..node)
		end

		if visited[node] == "visited" then
			return
		end

		visited[node] = "visiting"

		for _, dependency in ipairs(dependencies[node] or {}) do
			visit(dependency)
		end

		visited[node] = "visited"
		table.insert(result, node)
	end

	for node in pairs(dependencies) do
		if not visited[node] then
			visit(node)
		end
	end

	return result
end


-- Loads all modules in order.
-- Modules are loaded by priority, higher priorities are loaded first.
-- Modules with no set priority are loaded in a random order.
function bootstrapper.loadModules()

	local modulesToLoad = {}

	-- Remove all files that are not modules from the list
	for path, script in pairs(starfall.getScripts()) do
		local isSharedModule = string.find(path, sharedRoot.."/modules/") ~= nil
		local isLocalModule = string.find(path, localRoot.."/modules/") ~= nil

		if not (isLocalModule or isSharedModule) then
			goto continueModuleLoad
		end


		-- Normalise file paths
		local localPath
		if isSharedModule then
			localPath = utf8.sub(path, #(sharedRoot.."/modules/") + 1)
		else
			localPath = utf8.sub(path, #(localRoot.."/modules/") + 1)
		end

		-- Take local script in priority to shared script
		if (isSharedModule and modulesToLoad[localPath] == nil) or not isSharedModule then
			modulesToLoad[localPath] = script
		end

		::continueModuleLoad::
	end

	local dependencies = {}

	-- Load all modules
	hook.run("premoduleload")
	-- INIT phase, modules need to return
	for path, script in pairs(modulesToLoad) do
		local environment = bootstrapper.createEnvironment(path)
		environment.INIT = true

		setfenv(script, environment)
		local success, moduleInfo = xpcall(script, bootstrapper.handleError)

		if type(moduleInfo) ~= "table" then
			error("Invalid module informations returned for module: "..path)
		end

		if success then
			dependencies[path] = moduleInfo.dependencies or {}
		end
	end

	local loadOrder = resolveDependencies(dependencies)
	for i = 1, #loadOrder do
		local path = loadOrder[i]

		-- Take modules from local files in priority to shared files.
		local script = modulesToLoad[path]
		local environment = bootstrapper.createEnvironment(path)

		setfenv(script, environment)
		script()
	end
	hook.run("postmoduleload")
end