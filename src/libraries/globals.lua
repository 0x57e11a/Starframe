--@name Starframe | Global Library
--@author The Starframe Team
--@class none


--[[

	The globals library adds all builtin functions aswell as hooks and unchanged libraries.

--]]


-- Built-in functions
local builtin = {
	"Angle", "CRC", "Color", "IsValid", "Material", "Matrix", "Vector", "assert", "cpuAverage",
	"cpuMax", "cpuTime", "doAll", "dofile", "error", "getfenv", "getmetatable", "hint", "ipairs",
	"load", "localToWorld", "next", "pairs", "pcall", "print", "printColor", "printConsole",
	"rawequal", "rawget", "rawset", "require", "requireAll", "select", "setfenv", "setmetatable",
	"tonumber", "tostring", "type", "unpack", "worldToLocal", "xpcall", "CLIENT", "SERVER",
	"NOTIFY_GENERIC", "NOTIFY_ERROR", "NOTIFY_HINT"
}

for i = 1, #builtin do
	bootstrapper.addToEnvironment(builtin[i], _G[builtin[i]])
end


-- Untouched Libraries
local untouchedLibraries = {
	"base64", "bit", "Color", "console", "constraint", "coroutine", "effects", "emitter",
	"emoji", "ents", "faction", "fastlz", "files", "find", "globaltables", "holograms", "http",
	"hud", "input", "io", "json", "math", "mesh", "npc", "os", "permissions", "profiler",
	"propprotection", "props", "quaternion", "render", "rendertarget", "screen", "serverinfo",
	"spacebuild", "stargate", "starfall", "string", "system", "table", "time", "trace",
	"utf8", "util", "vgui", "von"
}

for i = 1, #untouchedLibraries do
	bootstrapper.addToEnvironment(untouchedLibraries[i], _G[untouchedLibraries[i]])
end

-- Hook rewrite and extensions
starhooks = {
	alteredHooks = {} -- The list of altered hooks behaviours.
}

-- Rewrite part
local starhooks_mt = {
	__metatable = "[MODIFIED] Library: hook"
}

starhooks_mt.__index = function(self, index)
	return starhooks_mt[index] or starhooks[index]
end

-- Replaces the original hooks.add function for modules.
function starhooks_mt.add(hookName, name, func)
	local addFunc = (starhooks.alteredHooks[hookName] or {}).addCallback

	if addFunc then
		addFunc(hookName, name, func)
		return
	end

	local function removeErroredHook(stacktrace)
		hook.remove(hookName, name)
		bootstrapper.handleError(stacktrace)
	end

	name = bootstrapper.getCallingModuleID()..tostring(name)

	hook.add(hookName, name, function(...)
		xpcall(func, removeErroredHook, ...)
	end)
end


function starhooks_mt.remove(hookName, name)
	local removeFunc = (starhooks.alteredHooks[hookName] or {}).removeCallback

	if removeFunc then
		removeFunc(hookName, name)
		return
	end

	name = bootstrapper.getCallingModuleID()..tostring(name)
	hook.remove(hookName, name)
end

function starhooks_mt.run(hookName, ...)
	local runFunc = (starhooks.alteredHooks[hookName] or {}).runCallback

	if runFunc then
		runFunc(hookName, ...)
		return
	end

	hook.run(hookName, ...)
end


function starhooks_mt.__call(self, hookName, name, func)
	if func ~= nil then
		starhooks_mt.add(hookName, name, func)
	else
		starhooks_mt.remove(hookName, name)
	end
end


-- Extension part

-- Allows libraries to alter the behaviour of a specific hook.
-- Calling the function with no callback will revert the hook to its original behaviour.
-- This function does not propagate changes to previously registered hooks.
---@param hookName string The hook which needs its behaviour modified.
---@param addCallback function? The function to run when hook.add is called.
---@param removeCallback function? The function to run when hook.remove is called.
---@param runCallback function? The function to run when the hook is ran (either by Starfall itself or by hook.run)
function starhooks.alterHookBehavior(hookName, addCallback, removeCallback, runCallback)
	types.check(hookName, "string", "hookName", 2)
	types.check(addCallback, "function?", "addCallback", 2)
	types.check(removeCallback, "function?", "removeCallback", 2)
	types.check(runCallback, "function?", "runCallback", 2)

	starhooks.alteredHooks[hookName] = {
		add = addCallback,
		run = runCallback,
		remove = removeCallback
	}
end

bootstrapper.addToEnvironment("hook", setmetatable({}, starhooks_mt))