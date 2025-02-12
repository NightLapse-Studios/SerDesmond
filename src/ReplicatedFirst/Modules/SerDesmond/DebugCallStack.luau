--!strict

export type SerDesmondStack = { ErrorHandled: boolean, [number]: StackEntryDescriptor? }
export type StackEntryDescriptor = string | (() -> string)

local PROPAGATION_ERR_MSG = "Just Propagating"

local function new_stack(): SerDesmondStack
    return {
        ErrorHandled = false
    }
end

local function stack_desc(self: SerDesmondStack, caller_level: number)
    local desc = self[caller_level]
    if typeof(desc == "function") then
        desc = desc()
    end

    assert(typeof(desc) == "string")
    return desc
end

local function traceback(self: SerDesmondStack)
    local msg = "Internal traceback:\n"
    for i = #self, 1, -1 do
        local desc = stack_desc(self, i)
        msg ..= `{i}: {desc}\n`
    end

    return msg
end


local function track_stack<A..., R...>(self: SerDesmondStack, desc: StackEntryDescriptor, proc: (A...) -> (R...)): (A...) -> (R...)
    assert(proc ~= track_stack)
    

    return function(...)
        table.insert(self, desc)
        local stack_idx = #self
        
        local function err_handler(err: string)
            if stack_idx == #self then
                warn(err)
                warn(traceback(self))
            end

            return ""
        end

        local ret = { xpcall(proc, err_handler, ...) }
        
        local success = table.remove(ret, 1)
        if success == false then
            -- Propagate errors to the top so that stack traces do not change observable behavior
            error("Error in SerDesmond, see trace above")
        end
        
        assert(#self == stack_idx, "Corrupted stack (user not cleaning up its entry)")
        table.remove(self, stack_idx)

        return table.unpack(ret)
    end
end

return {
    new = new_stack,
    track_stack = track_stack,
    traceback = traceback
}