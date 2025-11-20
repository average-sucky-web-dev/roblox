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

local function FireEvent(identifier, who, ...)
	if who == "all" then
		rinterchange:FireAllClients(identifier, ...)
	elseif typeof(who) == "Instance" and who:IsA("Player") then
		rinterchange:FireClient(who, identifier, ...)
	else
		return "im going to bomb your house"
	end
end

rinterchange.OnServerEvent:Connect(function(plr, identifier, ...)
	if identifier and events[identifier] then
		for uuid, func in events[identifier] do
			if not debounces[uuid][plr] then
				debounces[uuid][plr] = {}
			end
			local debouncetbl = debounces[uuid]
			if not debouncetbl[plr] or time() - debouncetbl[plr] > debouncetbl.cd then
				debouncetbl[plr] = time()
				task.spawn(func, plr, ...)
			end
		end
	end
end)

local Event = {}
Event.__index = Event

function Event.new(identifier, debounce)
	local self = setmetatable({
		identifier = identifier, 
		debounce = debounce or 0,
		_uuid = HttpService:GenerateGUID(false),
	}, Event)
	self.OnServerEvent = {}
	function self.OnServerEvent:Connect(fn)
		if not debounces[self._parent._uuid] then
			debounces[self._parent._uuid] = {}
		end
		debounces[self._parent._uuid].cd = self._parent.debounce
		RegisterEventCallback(self._parent.identifier, self._parent._uuid, fn)
	end
	self.OnServerEvent._parent = self
	return self
end

function Event:Disconnect()
	debounces[self._parent._uuid] = nil
	RegisterEventCallback(self.identifier, self._uuid, nil)
end

function Event:FireClient(plr, ...)
	FireEvent(self.identifier, plr, ...)
end

function Event:FireAllClients(...)
	FireEvent(self.identifier, "all", ...)
end
-------------------------------------------------------------------------------------------
-- END EVENT BLOCK


-- FUNCTION BLOCK
-------------------------------------------------------------------------------------------
local function RegisterFunctionCallback(identifier, fn)
	functions[identifier] = fn
end

local function InvokeClient(identifier, who, ...)
	return finterchange:InvokeClient(who, identifier, ...)
end

finterchange.OnServerInvoke = function(plr, identifier, ...)
	if identifier and functions[identifier] and (not debounces[identifier][plr] or time() - debounces[identifier][plr] > debounces[identifier].cd) then
		debounces[identifier][plr] = time()
		return functions[identifier](plr, ...)
	end
end

local Function = {}
Function.__index = Function

function Function.new(identifier, debounce)
	local self = setmetatable({ identifier = identifier, debounce = debounce or 0}, Function)
	return self
end

function Function.__newindex(tbl, index, value)
	if typeof(value) == "function" and index == "OnServerInvoke" then
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
	rawset(self, "OnClientInvoke", nil)
end

function Function:InvokeClient(who, ...)
	return InvokeClient(self.identifier, who, ...)
end

-------------------------------------------------------------------------------------------
-- END FUNCTION BLOCK


return {
	['CreateEvent'] = function(identifier, debounce)
		return Event.new(identifier, debounce)
	end,
	['CreateFunction'] = function(identifier)
		return Function.new(identifier)
	end,
}
