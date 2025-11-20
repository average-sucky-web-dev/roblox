-- httpservice
local HttpService = game.HttpService

-- Global tables
local events = {}
local functions = {}
local debounces = {}

-- the actual events. thats pretty important to have.
local interchange = game.ReplicatedStorage.Interchanges
local rinterchange = interchange.RemoteInterchange
local finterchange = interchange.FunctionInterchange

-- EVENT BLOCK
-------------------------------------------------------------------------------------------
local function RegisterEventCallback(identifier, uuid, fn)
	if not events[identifier] then
		events[identifier] = {}
	end
	events[identifier][uuid] = fn
end

local function FireEvent(identifier, ...)
	rinterchange:FireServer(identifier, ...)
end

rinterchange.OnClientEvent:Connect(function(identifier, ...)
	if identifier and events[identifier] then
		for _, func in events[identifier] do
			task.spawn(func, ...)
		end
	end
end)


local Event = {}
Event.__index = Event 

function Event.new(identifier)
	local self = setmetatable({
		identifier = identifier, 
		_uuid = HttpService:GenerateGUID(false)
	}, Event)
	self.OnClientEvent = {}
	function self.OnClientEvent:Connect(fn)
		RegisterEventCallback(self._parent.identifier, self._parent._uuid, fn)
	end
	self.OnClientEvent._parent = self
	return self
end

function Event:Disconnect()
	RegisterEventCallback(self.identifier, self._uuid, nil)
end

function Event:FireServer(...)
	FireEvent(self.identifier, ...)
end
-------------------------------------------------------------------------------------------
-- END EVENT BLOCK


-- FUNCTION BLOCK
-------------------------------------------------------------------------------------------
local function RegisterFunctionCallback(identifier, fn)
	functions[identifier] = fn
end

local function InvokeServer(identifier, ...)
	return finterchange:InvokeServer(identifier, ...)
end

finterchange.OnClientInvoke = function(identifier, ...)
	if identifier and functions[identifier] then
		return functions[identifier](...)
	end
end

local Function = {}
Function.__index = Function

function Function.new(identifier, debounce)
	local self = setmetatable({ identifier = identifier, debounce = debounce or 0}, Function)
	return self
end

function Function.__newindex(tbl, index, value)
	if typeof(value) == "function" and index == "OnClientInvoke" then
		if not debounces[tbl.identifier] then
			debounces[tbl.identifier] = {}
		end
		debounces[tbl.identifier].cd = tbl.debounce
		RegisterFunctionCallback(tbl.identifier, value)
	end
	rawset(tbl, index, value)
end

function Function:Disconnect()
	RegisterFunctionCallback(self.identifier, nil)
	rawset(self, "OnServerInvoke", nil)
end

function Function:InvokeServer(...)
	return InvokeServer(self.identifier, ...)
end
-------------------------------------------------------------------------------------------
-- END FUNCTION BLOCK


return {
	['CreateEvent'] = function(identifier)
		return Event.new(identifier)
	end,
	['CreateFunction'] = function(identifier, debounce)
		return Function.new(identifier)
	end,
}
