local _M = {}

local function defaultfunc(val)
    return true, val
end

local function callfunc(func, val)
    local is_valid, val_or_err, badval_or_nil = func(val)

    if val_or_err == nil then
        if is_valid then
            val_or_err = val
            badval_or_nil = nil
        else
            val_or_err = "func"

            if badval_or_nil == nil then
                badval_or_nil = val
            end
        end
    end

    return is_valid, val_or_err, badval_or_nil
end

local function literal(lit, opts)
    opts = opts or {}
    local func = opts.func or defaultfunc

    return function(val)
        if val ~= lit then
            return false, "literal", val
        end

        return callfunc(func, val)
    end
end
_M.literal = literal

local function number(opts)
    opts = opts or {}
    local min = opts.min or -math.huge
    local max = opts.max or math.huge
    local func = opts.func or defaultfunc

    return function(val)
        if type(val) ~= "number" then
            return false, "number", val
        end

        if val < min then
            return false, "min", val
        end

        if val > max then
            return false, "max", val
        end

        return callfunc(func, val)
    end
end
_M.number = number

-- don't shadow lua's string
local function vstring(opts)
    opts = opts or {}
    local minlen = opts.minlen or 0
    local maxlen = opts.maxlen or math.huge
    local pattern = opts.pattern
    local func = opts.func or defaultfunc

    return function(val)
        if type(val) ~= "string" then
            return false, "string", val
        end

        local len = #val

        if len < minlen then
            return false, "minlen", val
        end

        if len > maxlen then
            return false, "maxlen", val
        end

        if pattern and not val:match(pattern) then
            return false, "pattern", val
        end

        return callfunc(func, val)
    end
end
_M.string = vstring

-- don't shadow lua's table
local function vtable(opts)
    opts = opts or {}
    local array = false
    local map = false
    local empty = false
    local required = opts.required or {}
    local func = opts.func or defaultfunc
    local tabledef = opts.table

    if opts.array then
        array = true
    end

    if opts.map then
        map = true
    end

    if opts.empty then
        empty = true
    end

    return function(val)
        if type(val) ~= "table" then
            return false, "table", val
        end

        if array and #val == 0 and not empty then
            return false, "empty", val
        end

        -- checking for nil (not false)
        if map and next(val) == nil and not empty then
            return false, "empty", val
        end

        if required ~= "all" then

            -- specific required fields
            for _, key in ipairs(required) do

                -- checking for nil (not false)
                if val[key] == nil then
                    return false, "required", key, {key}
                end
            end
        end

        local is_valid
        local val_or_err
        local badval_or_nil
        local path_or_nil
        local v

        for key_or_idx, func_or_lit in pairs(tabledef) do
            if type(func_or_lit) ~= "function" then
                func_or_lit = literal(func_or_lit)
            end

            v = val[key_or_idx]

            if v == nil and required == "all" then
                -- every field is required
                return false, "required", key_or_idx, {key_or_idx}
            end

            -- we already validated the required fields
            -- checking for nil (not false)
            if v ~= nil then
                is_valid, val_or_err, badval_or_nil, path_or_nil = func_or_lit(v)

                if not is_valid then
                    return false, val_or_err, badval_or_nil, {key_or_idx, path_or_nil}
                end
            end
        end

        return callfunc(func, val)
    end
end
_M.table = vtable

local function array(opts)
    return vtable {
        array = true,
        empty = opts.empty,
        required = opts.required,
        func = opts.func,
        table = opts.table
    }
end
_M.array = array

local function arrayof(deffunc, opts)
    opts = opts or {}
    local empty = false
    local unique = false
    local minlen = opts.minlen or 0
    local maxlen = opts.maxlen or math.huge
    local func = opts.func or defaultfunc

    if opts.empty then
        empty = true

        -- minlen doesnt matter if empty = true
        minlen = 0
    end

    if minlen == 0 and not empty then
        -- empty doesnt matter if minlen = 0
        empty = true
    end

    if opts.unique then
        unique = true
    end

    return function(val)
        if type(val) ~= "table" then
            return false, "table", val
        end

        local len = #val

        if len == 0 and not empty then
            return false, "empty", val
        end

        if len < minlen then
            return false, "minlen", val
        end

        if len > maxlen then
            return false, "maxlen", val
        end

        local is_valid
        local val_or_err
        local badval_or_nil
        local path_or_nil
        local set = {}
        local prev_i

        for i, v in ipairs(val) do
            is_valid, val_or_err, badval_or_nil, path_or_nil = deffunc(v)

            if not is_valid then
                return false, val_or_err, badval_or_nil, {i, path_or_nil}
            end

            is_valid, val_or_err, badval_or_nil, path_or_nil = callfunc(func, v)

            if not is_valid then
                return false, val_or_err, badval_or_nil, {i, path_or_nil}
            end

            if unique then
                prev_i = set[v]

                if prev_i ~= nil then
                    return false, "unique", v, {prev_i, i}
                else
                    set[v] = i
                end
            end
        end

        return true, val
    end
end
_M.arrayof = arrayof

local function map(opts)
    return vtable {
        map = true,
        empty = opts.empty,
        required = opts.required,
        func = opts.func,
        table = opts.table
    }
end
_M.map = map

local function mapof(deffuncs, opts)
    opts = opts or {}
    local empty = false
    local keydeffunc = deffuncs[1] or defaultfunc
    local valdeffunc = deffuncs[2] or defaultfunc
    local keyfunc = defaultfunc
    local valfunc = defaultfunc

    if type(opts.func) == "table" then
        keyfunc = opts.func[1] or defaultfunc
        valfunc = opts.func[2] or defaultfunc
    end

    if opts.empty then
        empty = true
    end

    return function(val)
        if type(val) ~= "table" then
            return false, "table", val
        end

        -- checking for nil (not false)
        if next(val) == nil and not empty then
            return false, "empty", val
        end

        local is_valid
        local val_or_err
        local badval_or_nil
        local path_or_nil

        for k, v in pairs(val) do
            is_valid, val_or_err, badval_or_nil, path_or_nil = keydeffunc(k)

            if not is_valid then
                return false, val_or_err, badval_or_nil, {k, path_or_nil}
            end

            is_valid, val_or_err, badval_or_nil, path_or_nil = keyfunc(k)

            if not is_valid then
                return false, val_or_err, badval_or_nil, {k, path_or_nil}
            end

            is_valid, val_or_err, badval_or_nil, path_or_nil = valdeffunc(v)

            if not is_valid then
                return false, val_or_err, badval_or_nil, {k, v, path_or_nil}
            end

            is_valid, val_or_err, badval_or_nil, path_or_nil = valfunc(v)

            if not is_valid then
                return false, val_or_err, badval_or_nil, {k, v, path_or_nil}
            end
        end

        return true, val
    end
end
_M.mapof = mapof

local function func()
    return function(val)
        if type(val) ~= "function" then
            return false, "func", val
        end

        return true, val
    end
end
_M.func = func

return _M
