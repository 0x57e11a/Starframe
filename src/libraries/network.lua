--@name Starframe | Network Library
--@author The Starframe Team
--@class none

--[[

    The network library encapsulates network function calls for Starframe.

--]]

local starnet = {
    broadcast = net.broadcast,
    bytesLeft = net.bytesLeft,
    bytesWritten = net.bytesWritten,
    canSend = net.canSend,

    getDTVar = net.getDTVar,
    listenForAllDTVarChanges = net.listenForAllDTVarChanges,
    listenForDTVarChanges = net.listenForDTVarChanges,

    quotaMax = net.quotaMax,
    quotaUsed = net.quotaUsed,

    readAngle = net.readAngle,
    readBit = net.readBit,
    readBool = net.readBool,
    readData = net.readData,
    readDouble = net.readDouble,
    readEntity = net.readEntity,
    readFloat = net.readFloat,
    readInt = net.readInt,
    readMatrix = net.readMatrix,
    readNormal = net.readNormal,
    readString = net.readString,
    readTable = net.readTable,
    readType = net.readType,
    readUInt = net.readUInt,
    readVector = net.readVector,

    send = net.send,
    sendOmit = net.sendOmit,
    sendPAS = net.sendPAS,
    sendPVS = net.sendPVS,
    sendToServer = net.sendToServer,
    setDTVar = net.setDTVar,

    writeAngle = net.writeAngle,
    writeBit = net.writeBit,
    writeBool = net.writeBool,
    writeData = net.writeData,
    writeDouble = net.writeDouble,
    writeEntity = net.writeEntity,
    writeFloat = net.writeFloat,
    writeInt = net.writeInt,
    writeMatrix = net.writeMatrix,
    writeNormal = net.writeNormal,
    writeString = net.writeString,
    writeTable = net.writeTable,
    writeType = net.writeType,
    writeUInt = net.writeUInt,
}


---Replaces the default net.start() function for modules
---@see net.start
function starnet.start(ent, unreliable)
    types.check(ent, "Entity?", "ent", 2)
    types.check(unreliable, "boolean?", "unreliable", 2)

    local netId = bootstrapper.getCallingModuleId()
    if netId == nil then
        error("Libraries should use the default net library.", 2)
    end

    local messageStarted, reason = net.start(ent, unreliable)
    if not messageStarted then
        return false, reason
    end

    -- We write the netId of the current module to identify the source of the started message.
    net.writeString(netId)
    return true
end


---Stores all networking callbacks given their moduleId & name.
local starnetCallbacks = {}


local function onNetHookAdd(_, name, func)
    local moduleId = bootstrapper.getCallingModuleId()
    starnetCallbacks[moduleId] = starnetCallbacks[moduleId] or {}
    starnetCallbacks[moduleId][name] = func
end


local function onNetHookRemove(_, name)
    local moduleId = bootstrapper.getCallingModuleId()
    starnetCallbacks[moduleId] = starnetCallbacks[moduleId] or {}
    starnetCallbacks[moduleId][name] = nil
end


local function onNetHookRun(_, ...)
    local moduleId = bootstrapper.getCallingModuleId()

    local valuesToReturn = {}
    for name, callback in pairs(starnetCallbacks[moduleId] or {}) do
        local returnedValues = {callback(...)}

        for i = 1, #returnedValues do
            valuesToReturn[#valuesToReturn+1] = returnedValues[i]
        end
    end

    return unpack(valuesToReturn)
end


---This is the master net hook, it receives all net messages
---and redirects the message to the right net hook.
hook("net", "Master Net", function(_, player)
    local moduleId = net.readString() --We read the moduleId from the net message header.
    local callbacks = starnetCallbacks[moduleId] or {}

    for _, callback in pairs(callbacks) do
        xpcall(callback, bootstrapper.handleError, net.bytesLeft(), player)
    end
end)


starhooks.alterHookBehavior("net", onNetHookAdd, onNetHookRemove, onNetHookRun)
bootstrapper.addToEnvironment("net", starnet)