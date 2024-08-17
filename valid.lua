--[[
  Copyright (c) 2024, Ben Wilber
  https://github.com/benwilber/lua-valid

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

      http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
]]
local _M = {}

-- Local reference optimizations for non-JIT'd Lua versions.
local type = type
local pairs = pairs
local ipairs = ipairs
local string_match = string.match
local string_lower = string.lower
local math_huge = math.huge

-- The default validation function that's called
-- when no custom function is provided.
local function defaultfunc(val)
    -- is_valid, val_or_err, badval_or_nil, path_or_nil
    return true, val, nil, nil
end

-- Helper that calls a custom validation function and
-- and ensures that meaningful values are returned.
local function callfunc(func, val)
    local is_valid, val_or_err, badval_or_nil, path_or_nil = func(val)

    -- checking for nil (not false)
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

    return is_valid, val_or_err, badval_or_nil, path_or_nil
end

-- Validates that a value string_matches a specific literal.
local function literal(lit, opts)
    opts = opts or {}
    local icase = opts.icase or false
    local func = opts.func or defaultfunc

    return function(val)
        if icase and type(lit) == "string" and type(val) == "string" then

            if string_lower(val) ~= string_lower(lit) then
                -- is_valid, val_or_err, badval_or_nil, path_or_nil
                return false, "literal", val, nil
            end

        elseif val ~= lit then
            -- is_valid, val_or_err, badval_or_nil, path_or_nil
            return false, "literal", val, nil
        end

        return callfunc(func, val)
    end
end
_M.literal = literal

-- Validates that a value is a number within an optional range.
local function number(opts)
    opts = opts or {}
    local min = opts.min or -math_huge
    local max = opts.max or math_huge
    local func = opts.func or defaultfunc

    return function(val)
        if type(val) ~= "number" then
            -- is_valid, val_or_err, badval_or_nil, path_or_nil
            return false, "number", val, nil
        end

        if val < min then
            -- is_valid, val_or_err, badval_or_nil, path_or_nil
            return false, "min", val, nil
        end

        if val > max then
            -- is_valid, val_or_err, badval_or_nil, path_or_nil
            return false, "max", val, nil
        end

        return callfunc(func, val)
    end
end
_M.number = number

-- Validates that a value is a string with optional length and pattern constraints.
-- (Don't shadow Lua's "string")
local function _string(opts)
    opts = opts or {}
    local minlen = opts.minlen or 0
    local maxlen = opts.maxlen or math_huge
    local pattern = opts.pattern
    local func = opts.func or defaultfunc

    return function(val)
        if type(val) ~= "string" then
            -- is_valid, val_or_err, badval_or_nil, path_or_nil
            return false, "string", val, nil
        end

        local len = #val

        if len < minlen then
            -- is_valid, val_or_err, badval_or_nil, path_or_nil
            return false, "minlen", val, nil
        end

        if len > maxlen then
            -- is_valid, val_or_err, badval_or_nil, path_or_nil
            return false, "maxlen", val, nil
        end

        if pattern and not string_match(val, pattern) then
            -- is_valid, val_or_err, badval_or_nil, path_or_nil
            return false, "pattern", val, nil
        end

        return callfunc(func, val)
    end
end
_M.string = _string

-- Validates that a value is a table, with optional constraints for arrays and maps.
-- (Don't shadow Lua's "table")
local function table_(opts)
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
            -- is_valid, val_or_err, badval_or_nil, path_or_nil
            return false, "table", val, nil
        end

        if array and #val == 0 and not empty then
            -- is_valid, val_or_err, badval_or_nil, path_or_nil
            return false, "empty", val, nil
        end

        -- checking for nil (not false)
        if map and next(val) == nil and not empty then
            -- is_valid, val_or_err, badval_or_nil, path_or_nil
            return false, "empty", val, nil
        end

        if required ~= "all" then

            -- specific required fields
            for _, key in ipairs(required) do

                -- checking for nil (not false)
                if val[key] == nil then
                    -- is_valid, val_or_err, badval_or_nil, path_or_nil
                    return false, "required", key, {key}
                end
            end
        end

        local is_valid
        local val_or_err
        local badval_or_nil
        local path_or_nil

        -- the value at key (or index) in the table.
        local v

        for key_or_idx, func_or_lit in pairs(tabledef) do
            if type(func_or_lit) ~= "function" then
                func_or_lit = literal(func_or_lit)
            end

            v = val[key_or_idx]

            -- checking for nil (not false)
            if v == nil and required == "all" then
                -- every field is required
                -- is_valid, val_or_err, badval_or_nil, path_or_nil
                return false, "required", key_or_idx, {key_or_idx}
            end

            -- we already validated the required fields
            -- checking for nil (not false)
            if v ~= nil then
                is_valid, val_or_err, badval_or_nil, path_or_nil = func_or_lit(v)

                if not is_valid then
                    -- is_valid, val_or_err, badval_or_nil, path_or_nil
                    return false, val_or_err, badval_or_nil, {key_or_idx, path_or_nil}
                end
            end
        end

        return callfunc(func, val)
    end
end
_M.table = table_

-- A shorthand for valid.table with opts.array set to true.
local function array(opts)
    return table_ {
        array = true,
        empty = opts.empty,
        required = opts.required,
        func = opts.func,
        table = opts.table
    }
end
_M.array = array

-- Validates that a value is an array where each element string_matches a given definition.
local function arrayof(deffunc, opts)
    opts = opts or {}
    local empty = false
    local unique = false
    local minlen = opts.minlen or 0
    local maxlen = opts.maxlen or math_huge
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
            -- is_valid, val_or_err, badval_or_nil, path_or_nil
            return false, "table", val, nil
        end

        local len = #val

        if len == 0 and not empty then
            -- is_valid, val_or_err, badval_or_nil, path_or_nil
            return false, "empty", val, nil
        end

        if len < minlen then
            -- is_valid, val_or_err, badval_or_nil, path_or_nil
            return false, "minlen", val, nil
        end

        if len > maxlen then
            -- is_valid, val_or_err, badval_or_nil, path_or_nil
            return false, "maxlen", val, nil
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
                -- is_valid, val_or_err, badval_or_nil, path_or_nil
                return false, val_or_err, badval_or_nil, {i, path_or_nil}
            end

            is_valid, val_or_err, badval_or_nil, path_or_nil = callfunc(func, v)

            if not is_valid then
                -- is_valid, val_or_err, badval_or_nil, path_or_nil
                return false, val_or_err, badval_or_nil, {i, path_or_nil}
            end

            if unique then
                prev_i = set[v]

                -- checking for nil (not false)
                if prev_i ~= nil then
                    -- is_valid, val_or_err, badval_or_nil, path_or_nil
                    return false, "unique", v, {prev_i, i}
                else
                    set[v] = i
                end
            end
        end

        -- is_valid, val_or_err, badval_or_nil, path_or_nil
        return true, val, nil, nil
    end
end
_M.arrayof = arrayof

-- A shorthand for valid.table with opts.map set to true.
local function map(opts)
    return table_ {
        map = true,
        empty = opts.empty,
        required = opts.required,
        func = opts.func,
        table = opts.table
    }
end
_M.map = map

-- Validates maps with specific type definitions for both keys and values.
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
            -- is_valid, val_or_err, badval_or_nil, path_or_nil
            return false, "table", val, nil
        end

        -- checking for nil (not false)
        if next(val) == nil and not empty then
            -- is_valid, val_or_err, badval_or_nil, path_or_nil
            return false, "empty", val, nil
        end

        local is_valid
        local val_or_err
        local badval_or_nil
        local path_or_nil

        for k, v in pairs(val) do
            is_valid, val_or_err, badval_or_nil, path_or_nil = keydeffunc(k)

            if not is_valid then
                -- is_valid, val_or_err, badval_or_nil, path_or_nil
                return false, val_or_err, badval_or_nil, {k, path_or_nil}
            end

            is_valid, val_or_err, badval_or_nil, path_or_nil = keyfunc(k)

            if not is_valid then
                -- is_valid, val_or_err, badval_or_nil, path_or_nil
                return false, val_or_err, badval_or_nil, {k, path_or_nil}
            end

            is_valid, val_or_err, badval_or_nil, path_or_nil = valdeffunc(v)

            if not is_valid then
                -- is_valid, val_or_err, badval_or_nil, path_or_nil
                return false, val_or_err, badval_or_nil, {k, v, path_or_nil}
            end

            is_valid, val_or_err, badval_or_nil, path_or_nil = valfunc(v)

            if not is_valid then
                -- is_valid, val_or_err, badval_or_nil, path_or_nil
                return false, val_or_err, badval_or_nil, {k, v, path_or_nil}
            end
        end

        -- is_valid, val_or_err, badval_or_nil, path_or_nil
        return true, val, nil, nil
    end
end
_M.mapof = mapof

-- Validates that a value is a function.
local function func()
    return function(val)
        if type(val) ~= "function" then
            -- is_valid, val_or_err, badval_or_nil, path_or_nil
            return false, "func", val, nil
        end

        -- is_valid, val_or_err, badval_or_nil, path_or_nil
        return true, val, nil, nil
    end
end
_M.func = func

-- Validates that a value satisfies at least one of the given validation functions.
local function anyof(funcs_or_lits)
    return function(val)
        local is_valid
        local val_or_err
        local badval_or_nil
        local path_or_nil
        local errtabs = {}

        for _, func_or_lit in ipairs(funcs_or_lits) do
            if type(func_or_lit) ~= "function" then
                func_or_lit = literal(func_or_lit)
            end

            is_valid, val_or_err, badval_or_nil, path_or_nil = func_or_lit(val)

            if is_valid then
                -- is_valid, val_or_err, badval_or_nil, path_or_nil
                return true, val, nil, nil
            else
                errtabs[#errtabs + 1] = {val_or_err, badval_or_nil, path_or_nil}
            end
        end

        -- is_valid, val_or_err, badval_or_nil, path_or_nil
        return false, "any", val, errtabs
    end
end
_M.anyof = anyof

-- Validates that a value satisfies all of the given validation functions.
local function allof(funcs_or_lits)
    return function(val)
        local is_valid
        local val_or_err
        local badval_or_nil
        local path_or_nil
        local errtabs = {}

        for _, func_or_lit in ipairs(funcs_or_lits) do
            if type(func_or_lit) ~= "function" then
                func_or_lit = literal(func_or_lit)
            end

            is_valid, val_or_err, badval_or_nil, path_or_nil = func_or_lit(val)

            if not is_valid then
                errtabs[#errtabs + 1] = {val_or_err, badval_or_nil, path_or_nil}
            end
        end

        if #errtabs == 0 then
            -- is_valid, val_or_err, badval_or_nil, path_or_nil
            return true, val, nil, nil
        else
            -- is_valid, val_or_err, badval_or_nil, path_or_nil
            return false, "all", val, errtabs
        end
    end
end
_M.allof = allof

-- Validates that a value is a literal boolean either true or false.
local function boolean()
    return anyof {true, false}
end
_M.boolean = boolean

return _M
