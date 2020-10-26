-- gamedevkit-lua v0.1

-- Locals are faster
local type         = type
local select       = select
local pairs        = pairs
local ipairs       = ipairs
local tonumber     = tonumber
local tostring     = tostring
local unpack       = unpack or table.unpack
local setmetatable = setmetatable
local getmetatable = getmetatable
local os           = os
local error        = error
local assert       = assert
local require      = require
local pcall        = pcall
local xpcall       = xpcall
local _

-- Forward declarations
local class
local singleton
local table
local math
local string
local env
local mersenne_twister

-- Helper functions
local noop = function()
end

local identity = function(x)
    return x
end

local iscallable = function(x)
    if type(x) == 'function' then return true end
    local mt = getmetatable(x)
    return mt and mt.__call ~= nil
end

local getiter = function(x)
    if table.is_array(x) then
        return ipairs
    elseif type(x) == 'table' then
        return pairs
    end
    error('expected table', 3)
end

local iteratee = function(x)
    if x == nil then return identity end
    if iscallable(x) then return x end
    if type(x) == 'table' then
        return function(z)
            for k, v in pairs(x) do
                if z[k] ~= v then return false end
            end
            return true
        end
    end
    return function(z) return z[x] end
end

local absindex = function(len, i)
    return i < 0 and (len + i + 1) or i
end

local patternescape = function(str)
    return str:gsub('[%(%)%.%%%+%-%*%?%[%]%^%$]', '%%%1')
end

--------------------------------------------------------------------------------
-- @type class
--
-- This implements object-oriented style classes in Lua, including multiple
-- inheritance. This particular variation of class implementation copies the
-- base class functions into this class, which improves speed over other
-- implementations in return for slightly larger class tables. Please note that
-- the inherited class members are therefore cached and subsequent changes to a
-- superclass may not be reflected in your subclasses.
--------------------------------------------------------------------------------
class = {}
setmetatable(class, class)

--------------------------------------------------------------------------------
-- This allows you to define a class by calling 'class' as a function,
-- specifying the superclasses as a list.  For example:
-- mynewclass = class(superclass1, superclass2)
-- @param ... Base class list.
-- @return class
--------------------------------------------------------------------------------
function class:__call(...)
    local cls = table.copy(self)
    local bases = {...}
    for i = #bases, 1, -1 do
        table.copy(bases[i], cls)
    end
    cls.__class = cls
    cls.__super = bases[1]
    cls.__call = function(self, ...)
        return self:__new(...)
    end
    cls.__interface = {__index = cls}
    setmetatable(cls.__interface, cls.__interface)
    return setmetatable(cls, cls)
end

--------------------------------------------------------------------------------
-- Generic constructor function for classes.
-- Note that __new() will call init() if it is available in the class.
-- @return Instance
--------------------------------------------------------------------------------
function class:__new(...)
    local obj = self:__object_factory()
    local superClasses = {}
    local curSuper = obj.__super
    while curSuper do
        table.push(superClasses, curSuper)
        curSuper = curSuper.__super
    end
    for i = #superClasses, 1, -1 do
        if superClasses[i].init then
            superClasses[i].init(obj, ...)
        end
    end
    if obj.init then
        obj:init(...)
    end
    return obj
end

--------------------------------------------------------------------------------
-- Returns the new object.
-- @return object
--------------------------------------------------------------------------------
function class:__object_factory()
    local factory_class = self.__factory
    if factory_class then
        local obj = factory_class.new()
        obj:setInterface(self.__interface) -- TODO: fix
        return obj
    end
    return setmetatable({}, self.__interface)
end

--------------------------------------------------------------------------------
-- Check if the object is an instance of a certain class.
-- @return object
--------------------------------------------------------------------------------
function class:instance_of(cls)
    local curClass = self.__class
    local curSuper = self.__class
    while curClass do
        curSuper = curSuper.__super
        if curClass == cls then
            return true
        end
        curClass = curSuper
    end
    return false
end

--------------------------------------------------------------------------------
-- @type singleton
--
-- A class that is self-initialised when calling it for the first time.
-- Subsequent calls are made using its cached instance.
--------------------------------------------------------------------------------
singleton = {}
setmetatable(singleton, singleton)

singleton.__SINGLETON_CACHE = {}
singleton.__ERROR = 'Can\'t initialize or inherit a Singleton.'

function singleton:__call(...)
    local __instance
    local class = class(...)
    local class_factory = class.__call
    class.__call = function(self, ...)
        if not __instance then
            __instance = class_factory(self, ...)
            class.__instance_ref = __instance -- in case GC tries to collect it
            __instance.__call = function(...)
                if __instance.call then
                    __instance:call(...)
                end
                return __instance
            end
            __instance.init = function()
                error(singleton.__ERROR)
            end
            __instance.new = function()
                error(singleton.__ERROR)
            end
            self.init = function()
                error(singleton.__ERROR)
            end
            self.new = function()
                error(singleton.__ERROR)
            end
        end
        if __instance.call then
            __instance:call(...)
        end
        return __instance
    end
    -- in case GC tries to collect it
    table.insert(singleton.__SINGLETON_CACHE, class)
    return class
end

function singleton:new()
    error(singleton.__ERROR)
end

function singleton:init()
    error(singleton.__ERROR)
end

--------------------------------------------------------------------------------
-- @type table
--
-- The next group of functions extends the default lua table implementation
-- to include some additional useful methods.
--------------------------------------------------------------------------------
table = setmetatable({}, {__index = _G.table})

--------------------------------------------------------------------------------
-- Copy the table shallowly (i.e. do not create recursive copies of values)
-- @param src copy
-- @param dest (option)Destination
-- @return dest
--------------------------------------------------------------------------------
function table.copy(src, dest)
    dest = dest or {}
    for i, v in pairs(src) do
        dest[i] = v
    end
    return dest
end

--------------------------------------------------------------------------------
-- Copy the table deeply (i.e. create recursive copies of values)
-- @param src copy
-- @param dest (option)Destination
-- @return dest
--------------------------------------------------------------------------------
function table.deep_copy(src, dest)
    dest = dest or {}
    for k, v in pairs(src) do
        if type(v) == 'table' then
            dest[k] = table.deep_copy(v)
        else
            dest[k] = v
        end
    end
    return dest
end

--------------------------------------------------------------------------------
-- Returns true if the table is an array -- the value is assumed to be an array
-- if it is a table which contains a value at the index 1.
--------------------------------------------------------------------------------
function table.is_array(src)
    return type(src) == 'table' and src[1] ~= nil
end

--------------------------------------------------------------------------------
-- Returns the index/key found by searching for a matching value in the table.
-- @param src table
-- @param value Search value
-- @return the index/key if the value is found, or nil if not found.
--------------------------------------------------------------------------------
function table.find(src, value)
    local iter = getiter(src)
    for k, v in iter(src) do
        if v == value then
            return k
        end
    end
    return nil
end

--------------------------------------------------------------------------------
-- Pushes all the given values to the end of the table and returns the pushed
-- values. Nil values are ignored.
--------------------------------------------------------------------------------
function table.push(src, ...)
    local n = select('#', ...)
    for i = 1, n do
        src[#src + 1] = select(i, ...)
    end
    return ...
end

--------------------------------------------------------------------------------
-- Adds an element to the table if and only if the value did not already exist.
-- @param srv table
-- @param value element
-- @return If it already exists, returns false. If not - returns true.
--------------------------------------------------------------------------------
function table.insert_if_absent(src, value)
    if table.find(src, value) ~= nil then
        return false
    end
    src[#src + 1] = value
    return true
end

--------------------------------------------------------------------------------
-- Removes the element from the table.
-- If the element existed, then returns its index value.
-- If the element did not previously exist, then return nil.
-- @param src table
-- @param val element
-- @return index
--------------------------------------------------------------------------------
function table.remove_element(src, val)
    local i = table.find(src, val)
    if i ~= nil then
        table.remove(src, i)
    end
    return i
end

--------------------------------------------------------------------------------
-- Nils all the values in the table, this renders it empty. Returns the table.
--------------------------------------------------------------------------------
function table.clear(src)
    local iter = getiter(src)
    for k in iter(src) do
        src[k] = nil
    end
    return src
end

--------------------------------------------------------------------------------
-- Copies all the fields from the source tables to the table and returns it
--  If a key exists in multiple tables the right-most table's value is used.
--------------------------------------------------------------------------------
function table.extend(src, ...)
    for i = 1, select('#', ...) do
      local x = select(i, ...)
      if x then
        for k, v in pairs(x) do
          src[k] = v
        end
      end
    end
    return src
end

-------------------------------------------------------------------------------
-- Returns a shuffled copy of the array.
-------------------------------------------------------------------------------
function table.shuffle(src)
    local rtn = {}
    for i = 1, #src do
        local r = math.random(i)
        if r ~= i then
            rtn[i] = rtn[r]
        end
        rtn[r] = src[i]
    end
    return rtn
end

-------------------------------------------------------------------------------
-- Returns a copy of the array with all its items sorted. If comp is a function
-- it will be used to compare the items when sorting. If comp is a string it
-- will be used as the key to sort the items by.
-------------------------------------------------------------------------------
function table.sorted(src, comp)
    local rtn = table.copy(src)
    if comp then
        if type(comp) == 'string' then
            table.sort(rtn, function(a, b) return a[comp] < b[comp] end)
        else
            table.sort(rtn, comp)
        end
    else
        table.sort(rtn)
    end
    return rtn
end

-------------------------------------------------------------------------------
-- Iterates the supplied iterator and returns an array filled with the values.
-------------------------------------------------------------------------------
function table.iterate(...)
    local t = {}
    for x in ... do
        t[#t + 1] = x
    end
    return t
end

-------------------------------------------------------------------------------
-- Iterates the table and calls the function fn on each value followed by the
-- supplied additional arguments; if fn is a string the method of that name is
-- called for each value. The function returns the table unmodified.
-------------------------------------------------------------------------------
function table.each(src, fn, ...)
    local iter = getiter(src)
    if type(fn) == 'string' then
        for _, v in iter(src) do v[fn](v, ...) end
    else
        for _, v in iter(src) do fn(v, ...) end
    end
    return src
end

-------------------------------------------------------------------------------
-- Applies a function to each value in the table and returns a new table with
-- the resulting values.
-------------------------------------------------------------------------------
function table.map(src, fn)
    fn = iteratee(fn)
    local iter = getiter(src)
    local rtn = {}
    for k, v in iter(src) do rtn[k] = fn(v) end
    return rtn
end

-------------------------------------------------------------------------------
-- Returns true if all the values in the table are true. If a function is
-- supplied, it is called on each value, true is returned if all of the calls
-- to the function return true.
-------------------------------------------------------------------------------
function table.all(src, fn)
    fn = iteratee(fn)
    local iter = getiter(src)
    for _, v in iter(src) do
        if not fn(v) then return false end
    end
    return true
end

-------------------------------------------------------------------------------
-- Returns true if any of the values in the table are true. If a function is
-- supplied it is called on each value, true is returned if any of the calls
-- to the function return true.
-------------------------------------------------------------------------------
function table.any(src, fn)
    fn = iteratee(fn)
    local iter = getiter(src)
    for _, v in iter(src) do
        if fn(v) then return true end
    end
    return false
end

-------------------------------------------------------------------------------
-- Applies a function on two arguments cumulative to the items of the array
-- from left to right, so as to reduce the array to a single value. If a first
-- value is specified, the accumulator is initialised to this, otherwise the
-- first value in the array is used.
-- If the array is empty and no first value is specified an error is raised.
-------------------------------------------------------------------------------
function table.reduce(src, fn, first)
    local started = first ~= nil
    local acc = first
    local iter = getiter(src)
    for _, v in iter(src) do
        if started then
            acc = fn(acc, v)
        else
            acc = v
            started = true
        end
    end
    assert(started, 'reduce of an empty table with no first value')
    return acc
end

-------------------------------------------------------------------------------
-- Returns a copy of the array with all the duplicate values removed.
-------------------------------------------------------------------------------
function table.unique(src)
    local rtn = {}
    for k in pairs(table.invert(src)) do
        rtn[#rtn + 1] = k
    end
    return rtn
end

-------------------------------------------------------------------------------
-- Calls a function on each value of the table. Returns a new table with only
-- the values where fn returned true. If retainkeys is true the table is not
-- treated as an array and retains its original keys.
-------------------------------------------------------------------------------
function table.filter(src, fn, retainkeys)
    fn = iteratee(fn)
    local iter = getiter(src)
    local rtn = {}
    if retainkeys then
        for k, v in iter(src) do
            if fn(v) then rtn[k] = v end
        end
    else
        for _, v in iter(src) do
            if fn(v) then rtn[#rtn + 1] = v end
        end
    end
    return rtn
end

-------------------------------------------------------------------------------
-- The opposite of table.filter(): Calls a function on each value of the table;
-- returns a new table with only the values where fn returned false. If
-- retainkeys is true the table is not treated as an array and retains its
--  original keys.
-------------------------------------------------------------------------------
function table.reject(t, fn, retainkeys)
    fn = iteratee(fn)
    local iter = getiter(t)
    local rtn = {}
    if retainkeys then
        for k, v in iter(t) do
            if not fn(v) then rtn[k] = v end
        end
    else
        for _, v in iter(t) do
            if not fn(v) then rtn[#rtn + 1] = v end
        end
    end
    return rtn
end

-------------------------------------------------------------------------------
-- Returns a new table with all the given tables merged together. If a key
-- exists in multiple tables the right-most table's value is used.
-------------------------------------------------------------------------------
function table.merge(...)
    local rtn = {}
    for i = 1, select('#', ...) do
        local t = select(i, ...)
        local iter = getiter(t)
        for k, v in iter(t) do
            rtn[k] = v
        end
    end
    return rtn
end

-------------------------------------------------------------------------------
-- Returns a new array consisting of all given arrays concatenated into one.
-------------------------------------------------------------------------------
function table.concat_all(...)
    local rtn = {}
    for i = 1, select('#', ...) do
        local t = select(i, ...)
        if t ~= nil then
            local iter = getiter(t)
            for _, v in iter(t) do
                rtn[#rtn + 1] = v
            end
      end
    end
    return rtn
end

-------------------------------------------------------------------------------
-- Returns the value and key of the value in the table which returns true when
-- a function is called on it. Returns nil if no such value exists.
-------------------------------------------------------------------------------
function table.match(src, fn)
    fn = iteratee(fn)
    local iter = getiter(src)
    for k, v in iter(src) do
        if fn(v) then return v, k end
    end
    return nil
end

-------------------------------------------------------------------------------
-- Counts the number of values in the table. If a function is supplied, it is
-- called on each value, the number of times it returns true is counted.
-------------------------------------------------------------------------------
function table.count(src, fn)
    local count = 0
    local iter = getiter(src)
    if fn then
        fn = iteratee(fn)
        for _, v in iter(src) do
            if fn(v) then count = count + 1 end
        end
    else
        if table.is_array(src) then
            return #src
        end
        for _ in iter(src) do
            count = count + 1
        end
    end
    return count
end

-------------------------------------------------------------------------------
-- Mimics the behaviour of Lua's string.sub, but operates on an array rather
-- than a string. Creates and returns a new array of the given slice.
-------------------------------------------------------------------------------
function table.slice(src, i, j)
    i = i and absindex(#src, i) or 1
    j = j and absindex(#src, j) or #src
    local rtn = {}
    for x = i < 1 and 1 or i, j > #src and #src or j do
        rtn[#rtn + 1] = src[x]
    end
    return rtn
end

-------------------------------------------------------------------------------
-- Returns the first element of an array or nil if the array is empty. If n is
-- specificed an array of the first n elements is returned.
-------------------------------------------------------------------------------
function table.first(src, n)
    if not n then
        return src[1]
    end
    return table.slice(src, 1, n)
end

-------------------------------------------------------------------------------
-- Returns the last element of an array or nil if the array is empty. If n is
-- specificed an array of the last n elements is returned.
-------------------------------------------------------------------------------
function table.last(src, n)
    if not n then
        return src[#src]
    end
    return table.slice(src, -n, -1)
end

-------------------------------------------------------------------------------
-- Returns a copy of the table where the keys have become the values and the
-- values the keys.
-------------------------------------------------------------------------------
function table.invert(src)
    local rtn = {}
    for k, v in pairs(src) do rtn[v] = k end
    return rtn
end

-------------------------------------------------------------------------------
-- Returns a copy of the table filtered to only contain values for the given
-- keys.
-------------------------------------------------------------------------------
function table.pick(src, ...)
    local rtn = {}
    for i = 1, select('#', ...) do
        local k = select(i, ...)
        rtn[k] = src[k]
    end
    return rtn
end

-------------------------------------------------------------------------------
-- Returns an array containing each key of the table.
-------------------------------------------------------------------------------
function table.keys(src)
    local rtn = {}
    local iter = getiter(src)
    for k in iter(src) do
        rtn[#rtn + 1] = k
    end
    return rtn
end

--------------------------------------------------------------------------------
-- Prints the table
--------------------------------------------------------------------------------
function table.print(src)
    local print_r_cache = {}
    local function sub_print_r(src, indent)
        if (print_r_cache[tostring(src)]) then
            print(indent .. '*' .. tostring(src))
        else
            print_r_cache[tostring(src)] = true
            if type(src) == 'table' then
                for pos, val in pairs(src) do
                    if type(val) == 'table' then
                        print(
                            indent .. '[' .. pos .. '] => ' .. tostring(src)
                            .. ' {'
                        )
                        sub_print_r(
                            val, indent .. string.rep(' ', string.len(pos) + 8)
                        )
                        print(
                            indent .. string.rep(' ', string.len(pos) + 6)
                            .. '}'
                        )
                    elseif type(val) == 'string' then
                        print(indent .. '[' .. pos .. '] => \'' .. val .. '\'')
                    else
                        print(indent .. '[' .. pos .. '] => ' .. tostring(val))
                    end
                end
            else
                print(indent .. tostring(src))
            end
        end
    end
    if type(src) == 'table' then
        print(tostring(src) .. ' {')
        sub_print_r(src, '  ')
        print('}')
    else
        sub_print_r(src, '  ')
    end
    print()
end

--------------------------------------------------------------------------------
-- @type math
--
-- This set of functions extends the native lua 'math' function set with
-- additional useful methods.
--------------------------------------------------------------------------------
math = setmetatable({}, {__index = _G.math})
math.atan2 = math.atan2 or math.atan

--------------------------------------------------------------------------------
-- Calculate the average of the values of the argument.
-- @param ... a variable number of arguments, all of which should be numbers
-- @return average
--------------------------------------------------------------------------------
function math.average(...)
    local total = 0
    local array = {...}
    for i, v in ipairs(array) do
        total = total + v
    end
    return total / #array
end

--------------------------------------------------------------------------------
-- Calculate the total values of the argument
-- @param ... a variable number of arguments, all of which should be numbers
-- @return total
--------------------------------------------------------------------------------
function math.sum(...)
    local total = 0
    local array = {...}
    for i, v in ipairs(array) do
        total = total + v
    end
    return total
end

--------------------------------------------------------------------------------
-- Returns the number x clamped between the numbers min and max
--------------------------------------------------------------------------------
function math.clamp(x, min, max)
    return x < min and min or (x > max and max or x)
end

--------------------------------------------------------------------------------
-- Removes the decimal part of a number.
--------------------------------------------------------------------------------
function math.whole(x)
    return x >= 0 and math.floor(x) or math.ceil(x)
end

--------------------------------------------------------------------------------
-- Rounds x to the nearest integer; rounds away from zero if we're midway
-- between two integers. If increment is set then the number is rounded to the
-- nearest increment.
--------------------------------------------------------------------------------
function math.round(x, increment)
    if increment then
        return math.round(x / increment) * increment
    end
    return x >= 0 and math.floor(x + .5) or math.ceil(x - .5)
end

--------------------------------------------------------------------------------
-- Returns 1 if x is 0 or above, returns -1 when x is negative.
--------------------------------------------------------------------------------
function math.sign(x)
    return x < 0 and -1 or 1
end

--------------------------------------------------------------------------------
-- Return the linearly interpolated number between a and b, amount should be in
-- the range of 0 - 1; if amount is outside of this range it is clamped.
--------------------------------------------------------------------------------
function math.lerp(a, b, amount)
    return a + (b - a) * math.clamp(amount, 0, 1)
end

--------------------------------------------------------------------------------
-- Similar to math.lerp() but uses cubic interpolation instead of linear
-- interpolation.
--------------------------------------------------------------------------------
function math.smooth(a, b, amount)
    local t = math.clamp(amount, 0, 1)
    local m = t * t * (3 - 2 * t)
    return a + (b - a) * m
end

--------------------------------------------------------------------------------
-- Ping-pongs the number x between 0 and 1.
--------------------------------------------------------------------------------
function math.pingpong(x)
    return 1 - math.abs(1 - x % 2)
end

--------------------------------------------------------------------------------
-- Calculate the distance.
-- @param x0 Start position.
-- @param y0 Start position.
-- @param x1 (option)End position (note: default value is 0)
-- @param y1 (option)End position (note: default value is 0)
-- @param squared (option)Don't square the result (note: default value is false)
-- @return distance
--------------------------------------------------------------------------------
function math.distance(x0, y0, x1, y1, squared)
    if not x1 then x1 = 0 end
    if not y1 then y1 = 0 end
    if not squared then squared = false end

    local dX = x1 - x0
    local dY = y1 - y0
    local dist = dX * dX + dY * dY
    return squared and dist or math.sqrt(dist)
end

--------------------------------------------------------------------------------
-- Returns the normal vector
-- @param x
-- @param y
-- @return x/d, y/d
--------------------------------------------------------------------------------
function math.normalize(x, y)
    local d = math.distance(x, y)
    return x/d, y/d
end

--------------------------------------------------------------------------------
-- Returns the angle between the two points.
--------------------------------------------------------------------------------
function math.angle(x1, y1, x2, y2)
    return math.atan2(y2 - y1, x2 - x1)
end

--------------------------------------------------------------------------------
-- Returns a vector, given an angle and magnitude.
--------------------------------------------------------------------------------
function math.vector(angle, magnitude)
    return math.cos(angle) * magnitude, math.sin(angle) * magnitude
end

--------------------------------------------------------------------------------
-- Override the random seeding function to use the mersenne twister
--------------------------------------------------------------------------------
function math.randomseed(...)
    local mt = mersenne_twister()
    mt:init_genrand(...)
end

--------------------------------------------------------------------------------
-- Override the random function to use the mersenne twister
--------------------------------------------------------------------------------
function math.random(a, b)
    local mt = mersenne_twister()
    if not a then
        return mt:genrand_real2()
    end
    if not b then
        return mt:genrand_int32() % a + 1
    end
    return a + mt:genrand_int32() % (b - a + 1)
end

--------------------------------------------------------------------------------
-- Returns a random number between a and b. If only a is supplied a number
-- between 0 and a is returned. If no arguments are supplied a random number
-- between 0 and 1 is returned.
--------------------------------------------------------------------------------
function math.random_number(a, b)
    if not a then
        a, b = 0, 1
    end
    if not b then
        b = 0
    end
    return a + math.random() * (b - a)
end

--------------------------------------------------------------------------------
-- Returns a random value from an array. If the array is empty an error is
-- raised.
--------------------------------------------------------------------------------
function math.random_choice(src)
    return src[math.random(#src)]
end

--------------------------------------------------------------------------------
-- Takes an argument table where the keys are the possible choices and the value
-- is the choice's weight. A weight should be 0 or above, the larger the number
-- the higher the probability of that choice being picked. If the table is
-- empty, a weight is below zero or all the weights are 0, an error is raised.
--------------------------------------------------------------------------------
function math.weighted_choice(src)
    local sum = 0
    for _, v in pairs(src) do
        assert(v >= 0, 'weight value less than zero')
        sum = sum + v
    end
    assert(sum ~= 0, 'all weights are zero')
    local rnd = math.random_number(sum)
    for k, v in pairs(src) do
        if rnd < v then return k end
        rnd = rnd - v
    end
end

--------------------------------------------------------------------------------
-- @type string
--
-- The next group of functions extends the default lua string implementation
-- to include some additional useful methods.
--------------------------------------------------------------------------------
string = setmetatable({}, {__index = _G.string})
string.gmatch = string.gmatch or string.gfind

--------------------------------------------------------------------------------
-- Returns an array of the words in the string str. If sep is provided it is
-- used as the delimiter, consecutive delimiters are not grouped together and
-- will delimit empty strings.
--------------------------------------------------------------------------------
function string.split(str, sep)
    if not sep then
        return table.iterate(str:gmatch('([%S]+)'))
    else
        assert(sep ~= '', 'empty separator')
        local psep = patternescape(sep)
        return table.iterate((str..sep):gmatch('(.-)(' .. psep .. ')'))
    end
end

--------------------------------------------------------------------------------
-- Trims the whitespace from the start and end of the string and returns the new
-- string. If a chars value is set the characters in chars are trimmed instead
-- of whitespace.
--------------------------------------------------------------------------------
function string.trim(str, chars)
    if not chars then
        return str:match('^[%s]*(.-)[%s]*$')
    end
    chars = patternescape(chars)
    return str:match('^[' .. chars .. ']*(.-)[' .. chars .. ']*$')
end

--------------------------------------------------------------------------------
-- Returns str wrapped to limit number of characters per line, by default limit
-- is 72. limit can also be a function which when passed a string, returns true
-- if it is too long for a single line.
--------------------------------------------------------------------------------
function string.wordwrap(str, limit)
    limit = limit or 72
    local check
    if type(limit) == 'number' then
        check = function(s) return #s >= limit end
    else
        check = limit
    end
    local rtn = {}
    local line = ''
    for word, spaces in str:gmatch('(%S+)(%s*)') do
        local s = line .. word
        if check(s) then
            table.insert(rtn, line .. '\n')
            line = word
        else
            line = s
        end
        for c in spaces:gmatch('.') do
            if c == '\n' then
                table.insert(rtn, line .. '\n')
                line = ''
            else
                line = line .. c
            end
        end
    end
    table.insert(rtn, line)
    return table.concat(rtn)
end

--------------------------------------------------------------------------------
-- Returns a formatted string. The values of keys in the table vars can be
-- inserted into the string by using the form '{key}' in str; numerical keys can
-- also be used.
--------------------------------------------------------------------------------
function string.formatted(str, vars)
    if not vars then return str end
    local f = function(x)
        return tostring(vars[x] or vars[tonumber(x)] or '{' .. x .. '}')
    end
    return (str:gsub('{(.-)}', f))
end

--------------------------------------------------------------------------------
-- Generates a random UUID string; version 4 as specified in RFC 4122.
--------------------------------------------------------------------------------
function string.uuid()
    local fn = function(x)
        local r = math.random(16) - 1
        r = (x == 'x') and (r + 1) or (r % 4) + 9
        return ('0123456789abcdef'):sub(r, r)
    end
    return (('xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'):gsub('[xy]', fn))
end

--------------------------------------------------------------------------------
-- Convert a large number into a readable string
--------------------------------------------------------------------------------
function string.natural_number(num, shorten_mil)
    local formatted = num
    if shorten_mil and num > 1000000 then
        formatted = string.format('%.1fM', num / 1000000)
    else
        while true do
            formatted, k = string.gsub(
                formatted, '^(-?%d+)(%d%d%d)', '%1,%2'
            )
            if (k==0) then
                break
            end
        end
    end
    return formatted
end

--------------------------------------------------------------------------------
-- Pluralize a string
--------------------------------------------------------------------------------
function string.pluralize(str, number, one, many)
    return string.format(
        str, number == 1 and one or many
    )
end

--------------------------------------------------------------------------------
-- Converts a string to a table containing each char.
--------------------------------------------------------------------------------
function string.as_table(str)
    local chunks = {}
    for i = 1, str:len() do
        table.insert(chunks, str:sub(i, i))
    end
    return chunks
end

--------------------------------------------------------------------------------
-- @type env
--
-- Other helpful functions
--------------------------------------------------------------------------------
env = {}
setmetatable(env, env)
env.huge_num = 2147483647 -- sizeof(signed long)

--------------------------------------------------------------------------------
-- Creates a wrapper function around the given function fn, automatically
-- inserting the arguments into fn which will persist every time the wrapper is
-- called. Any arguments which are passed to the returned function will be
-- inserted after the already existing arguments passed to fn.
--------------------------------------------------------------------------------
function env.wrap_fn(fn, ...)
    assert(iscallable(fn), 'expected a function as the first argument')
    local args = { ... }
    return function(...)
        local a = table.concat_all(args, { ... })
        return fn(unpack(a))
    end
end

--------------------------------------------------------------------------------
-- Returns a wrapper function to fn which takes the supplied arguments. The
-- wrapper function will call fn on the first call and do nothing on any
-- subsequent calls.
--------------------------------------------------------------------------------
function env.once(fn, ...)
    local f = env.wrap_fn(fn, ...)
    local done = false
    return function(...)
        if done then
            return
        end
        done = true
        return f(...)
    end
end

--------------------------------------------------------------------------------
-- Returns a wrapper function to fn where the results for any given set of
-- arguments are cached. env.memoize() is useful when used on functions with
-- slow-running computations.
--------------------------------------------------------------------------------
env.__memoize_fnkey = {}
env.__memoize_nil = {}
function env.memoize(fn)
    local cache = {}
    return function(...)
        local c = cache
        for i = 1, select('#', ...) do
            local a = select(i, ...) or env.__memoize_nil
            c[a] = c[a] or {}
            c = c[a]
        end
        c[env.__memoize_fnkey] = c[env.__memoize_fnkey] or {fn(...)}
        return unpack(c[env.__memoize_fnkey])
    end
end

--------------------------------------------------------------------------------
-- Creates a wrapper function which calls each supplied argument in the order
-- they were passed to env.combine(); nil arguments are ignored. The wrapper
-- function passes its own arguments to each of its wrapped functions when it is
-- called.
--------------------------------------------------------------------------------
function env.combine(...)
    local n = select('#', ...)
    if n == 0 then
        return noop
    end
    if n == 1 then
        local fn = select(1, ...)
        if not fn then
            return noop
        end
        assert(iscallable(fn), 'expected a function or nil')
        return fn
    end
    local funcs = {}
    for i = 1, n do
        local fn = select(i, ...)
        if fn ~= nil then
            assert(iscallable(fn), 'expected a function or nil')
            funcs[#funcs + 1] = fn
        end
    end
    return function(...)
        for _, f in ipairs(funcs) do
            f(...)
        end
    end
end

--------------------------------------------------------------------------------
-- Calls the given function with the provided arguments and returns its values.
-- If fn is nil then no action is performed and the function returns nil.
--------------------------------------------------------------------------------
function env.call(fn, ...)
    if fn then
        return fn(...)
    end
    return nil
end

--------------------------------------------------------------------------------
-- Inserts the arguments into function fn and calls it. Returns the time in
-- seconds the function fn took to execute followed by fn's returned values.
--------------------------------------------------------------------------------
function env.timed(fn, ...)
    local start = os.clock()
    local rtn = {fn(...)}
    return (os.clock() - start), unpack(rtn)
end

--------------------------------------------------------------------------------
-- Takes a string lambda and returns a function. str should be a list of
-- comma-separated parameters, followed by ->, followed by the expression which
-- will be evaluated and returned.
--------------------------------------------------------------------------------
env.__lambda_cache = {}
function env.lambda(str)
    if not env.__lambda_cache[str] then
        local args, body = str:match([[^([%w,_ ]-)%->(.-)$]])
        assert(args and body, 'bad string lambda')
        local s = 'return function(' .. args .. ')\nreturn ' .. body .. '\nend'
        env.__lambda_cache[str] = env.dostring(s)
    end
    return env.__lambda_cache[str]
end

--------------------------------------------------------------------------------
-- Serializes the argument x into a string which can be loaded again using
-- env.deserialize(). Only booleans, numbers, tables and strings can be
-- serialized. Circular references will result in an error; all nested tables
-- are serialized as unique tables.
--------------------------------------------------------------------------------
env.__serialize_map = {
    [ 'boolean' ] = tostring,
    [ 'nil'     ] = tostring,
    [ 'string'  ] = function(v) return string.format('%q', v) end,
    [ 'number'  ] = function(v)
        if      v ~=  v
            then return  '0/0'       --  nan
        elseif  v ==  1 / 0 then
            return  '1/0'            --  inf
        elseif  v == -1 / 0 then
            return '-1/0'            -- -inf
        end
        return tostring(v)
    end,
    [ 'table'   ] = function(t, stk)
        stk = stk or {}
        if stk[t] then error('circular reference') end
        local rtn = {}
        stk[t] = true
        for k, v in pairs(t) do
        rtn[#rtn + 1] = '[' .. env.__serialize(k, stk)
                .. ']=' .. env.__serialize(v, stk)
        end
        stk[t] = nil
        return '{' .. table.concat(rtn, ',') .. '}'
    end
}
setmetatable(env.__serialize_map, {
  __index = function(_, k) error('unsupported serialize type: ' .. k) end
})

env.__serialize = function(x, stk)
    return env.__serialize_map[type(x)](x, stk)
end

function env.serialize(x)
    return env.__serialize(x)
end

--------------------------------------------------------------------------------
-- Deserializes a string created by env.serialize() and returns the resulting
-- value. This function should not be run on an untrusted string.
--------------------------------------------------------------------------------
function env.deserialize(str)
  return env.dostring('return ' .. str)
end

--------------------------------------------------------------------------------
-- Executes the lua code inside the string.
--------------------------------------------------------------------------------
function env.dostring(str)
    return assert((loadstring or load)(str))()
end

--------------------------------------------------------------------------------
-- Prints the current filename and line number followed by each argument
-- separated by a space.
--------------------------------------------------------------------------------
function env.trace(...)
    local info = debug.getinfo(2, 'Sl')
    local t = { 'lua: ' .. info.short_src .. ':' .. info.currentline .. ':' }
    for i = 1, select('#', ...) do
        local x = select(i, ...)
        if type(x) == 'number' then
            x = string.format('%g', math.round(x, .01))
        end
        t[#t + 1] = tostring(x)
    end
    print(table.concat(t, ' '))
end

--------------------------------------------------------------------------------
-- Reloads an already loaded module in place, allowing you to immediately see
-- the effects of code changes without having to restart the program. modname
-- should be the same string used when loading the module with require(). In the
-- case of an error the global environment is restored and nil plus an error
-- message is returned.
--------------------------------------------------------------------------------
function env.hotswap(modname)
    local oldglobal = table.copy(_G)
    local updated = {}
    local function update(old, new)
        if updated[old] then
            return
        end
        updated[old] = true
        local oldmt, newmt = getmetatable(old), getmetatable(new)
        if oldmt and newmt then update(oldmt, newmt) end
        for k, v in pairs(new) do
            if type(v) == 'table' then
                update(old[k], v)
            else
                old[k] = v
            end
        end
    end
    local err = nil
    local function onerror(e)
        for k in pairs(_G) do
            _G[k] = oldglobal[k]
        end
        err = string.trim(e)
    end
    local ok, oldmod = pcall(require, modname)
    oldmod = ok and oldmod or nil
    xpcall(function()
        package.loaded[modname] = nil
        local newmod = require(modname)
        if type(oldmod) == 'table' then
            update(oldmod, newmod)
        end
        for k, v in pairs(oldglobal) do
            if v ~= _G[k] and type(v) == 'table' then
                update(v, _G[k])
                _G[k] = v
            end
        end
    end, onerror)
    package.loaded[modname] = oldmod
    if err then
        return nil, err
    end
    return oldmod
end

function env.get_lua_version()
    local version = {}
    local version_split = string.split(string.split(_VERSION)[2], '.')
    version.major = tonumber(version_split[1])
    version.minor = tonumber(version_split[2])
    return version
end

--------------------------------------------------------------------------------
-- Performs the same function as ipairs() but iterates in reverse; this allows
-- the removal of items from the table during iteration without any items being
-- skipped.
--------------------------------------------------------------------------------
local ripairs_iter = function(t, i)
    i = i - 1
    local v = t[i]
    if v ~= nil then
        return i, v
    end
end
  
local function ripairs(src)
    return ripairs_iter, src, (#src + 1)
end

--------------------------------------------------------------------------------
-- Takes color string and returns 4 values, one for each color channel (r, g, b
-- and a). By default the returned values are between 0 and 1; the values are
-- multiplied by the number mul if it is provided.
--------------------------------------------------------------------------------
local function color(str, mul)
    mul = mul or 1
    local r, g, b, a
    r, g, b = str:match('#(%x%x)(%x%x)(%x%x)')
    if r then
        r = tonumber(r, 16) / 0xff
        g = tonumber(g, 16) / 0xff
        b = tonumber(b, 16) / 0xff
        a = 1
    elseif str:match('rgba?%s*%([%d%s%.,]+%)') then
        local f = str:gmatch('[%d.]+')
        r = (f() or 0) / 0xff
        g = (f() or 0) / 0xff
        b = (f() or 0) / 0xff
        a = f() or 1
    else
        error(('bad color string "%s"'):format(str))
    end
    return r * mul, g * mul, b * mul, a * mul
end

--------------------------------------------------------------------------------
-- @type date
--
-- Date/time module
--------------------------------------------------------------------------------
local date = {}
setmetatable(date, date)

-- Variables/Constants
date.__FMTSTR       = '%x %X'
date.__HOURPERDAY   = 24
date.__MINPERHOUR   = 60
date.__MINPERDAY    = 1440  -- 24*60
date.__SECPERMIN    = 60
date.__SECPERHOUR   = 3600  -- 60*60
date.__SECPERDAY    = 86400 -- 24*60*60
date.__TICKSPERSEC  = 1000000
date.__TICKSPERDAY  = 86400000000
date.__TICKSPERHOUR = 3600000000
date.__TICKSPERMIN  = 60000000
date.__DAYNUM_MAX   =  365242500 -- Sat Jan 01 1000000 00:00:00
date.__DAYNUM_MIN   = -365242500 -- Mon Jan 01 1000000 BCE 00:00:00
date.__DAYNUM_DEF   = 0 -- Mon Jan 01 0001 00:00:00
date.__DATE_EPOCH   = nil -- to be set later

-- Date tables
date.__SL_WEEKDAYS = {
    [0]  = 'Sunday',
    [1]  = 'Monday',
    [2]  = 'Tuesday',
    [3]  = 'Wednesday',
    [4]  = 'Thursday',
    [5]  = 'Friday',
    [6]  = 'Saturday',
    [7]  = 'Sun',
    [8]  = 'Mon',
    [9]  = 'Tue',
    [10] = 'Wed',
    [11] = 'Thu',
    [12] = 'Fri',
    [13] = 'Sat',
}
date.__SL_MERIDIAN = {
    [-1] = 'AM',
    [1]  = 'PM',
}
date.__SL_MONTHS = {
    [00] = 'January',
    [01] = 'February',
    [02] = 'March',
    [03] = 'April',
    [04] = 'May',
    [05] = 'June',
    [06] = 'July',
    [07] = 'August',
    [08] = 'September',
    [09] = 'October',
    [10] = 'November',
    [11] = 'December',
    [12] = 'Jan',
    [13] = 'Feb',
    [14] = 'Mar',
    [15] = 'Apr',
    [16] = 'May',
    [17] = 'Jun',
    [18] = 'Jul',
    [19] = 'Aug',
    [20] = 'Sep',
    [21] = 'Oct',
    [22] = 'Nov',
    [23] = 'Dec',
}
date.__SL_TIMEZONE = {
  [000]   = 'utc',
  [0.2]   = 'gmt',
  [300]   = 'est',
  [240]   = 'edt',
  [360]   = 'cst',
  [300.2] = 'cdt',
  [420]   = 'mst',
  [360.2] = 'mdt',
  [480]   = 'pst',
  [420.2] = 'pdt',
}

-- Internal functions
-- returns the modulo n % d
function date.__fix(n)
    n = tonumber(n)
    return n and ((n > 0 and math.floor or math.ceil)(n))
end

function date.__mod(n, d)
    return n - d * math.floor(n / d)
end

-- is `str` in string list `tbl`, `ml` is the minimun len
function date.__inlist(str, tbl, ml, tn)
    local sl = string.len(str)
    if sl < (ml or 0) then
        return nil
    end
    str = string.lower(str)
    for k, v in pairs(tbl) do
        if str == string.lower(string.sub(v, 1, sl)) then
            if tn then
                tn[0] = k
            end
            return k
        end
    end
end

-- set the day fraction resolution
function date.__setticks(t)
    date.__TICKSPERSEC = t
    date.__TICKSPERDAY = date.__SECPERDAY * date.__TICKSPERSEC
    date.__TICKSPERHOUR= date.__SECPERHOUR * date.__TICKSPERSEC
    date.__TICKSPERMIN = date.__SECPERMIN * date.__TICKSPERSEC
end

-- is year y leap year?
function date.__isleapyear(y) -- y must be int!
    return (
        date.__mod(y, 4) == 0 and
        (date.__mod(y, 100) ~= 0 or date.__mod(y, 400) == 0)
    )
end

-- day since year 0
function date.__dayfromyear(y) -- y must be int!
    return (
        365 * y + math.floor(y / 4) - math.floor(y / 100) + math.floor(y / 400)
    )
end

-- day number from date, month is zero base
function date.__makedaynum(y, m, d)
    local mm = date.__mod(date.__mod(m, 12) + 10, 12)
    return (
        date.__dayfromyear(y + math.floor(m / 12) -
        math.floor(mm / 10)) +
        math.floor((mm * 306 + 5) / 10) + d - 307
    )
end

-- date from day number, month is zero base
function date.__breakdaynum(g)
    local g = g + 306
    local y = math.floor((10000 * g + 14780) / 3652425)
    local d = g - date.__dayfromyear(y)
    if d < 0 then
        y = y - 1
        d = g - date.__dayfromyear(y)
    end
    local mi = math.floor((100 * d + 52) / 3060)
    return
        (math.floor((mi + 2) / 12) + y),
        date.__mod(mi + 2, 12),
        (d - math.floor((mi * 306 + 5) / 10) + 1)
end

-- day fraction from time
function date.__makedayfrc(h, r, s, t)
    return ((h * 60 + r) * 60 + s) * date.__TICKSPERSEC + t
end

-- time from day fraction
function date.__breakdayfrc(df)
    return
        date.__mod(math.floor(df / date.__TICKSPERHOUR), date.__HOURPERDAY),
        date.__mod(math.floor(df / date.__TICKSPERMIN ), date.__MINPERHOUR),
        date.__mod(math.floor(df / date.__TICKSPERSEC ), date.__SECPERMIN),
        date.__mod(df, date.__TICKSPERSEC)
end

-- weekday sunday = 0, monday = 1 ...
function date.__weekday(dn)
    return date.__mod(dn + 1, 7)
end

-- yearday 0 based ...
function date.__yearday(dn)
   return dn - date.__dayfromyear((date.__breakdaynum(dn)) - 1)
end

-- parse v as a month
function date.__getmontharg(v)
    local m = tonumber(v)
    return (
        (m and date.__fix(m - 1)) or
        date.__inlist(tostring(v) or '', date.__SL_MONTHS, 2)
    )
end

-- get daynum of isoweek one of year y
function date.__isow1(y)
    local f = date.__makedaynum(y, 0, 4) -- get the date for the 4-Jan of year `y`
    local d = date.__weekday(f)
    d = d == 0 and 7 or d -- get the ISO day number, 1 == Monday, 7 == Sunday
    return f + (1 - d)
end
function date.__isowy(dn)
    local w1
    local y = (date.__breakdaynum(dn))
    if dn >= date.__makedaynum(y, 11, 29) then
        w1 = date.__isow1(y + 1)
        if dn < w1 then
            w1 = date.__isow1(y)
        else
            y = y + 1
        end
    else
        w1 = date.__isow1(y)
        if dn < w1 then
            w1 = date.__isow1(y-1)
            y = y - 1
        end
    end
    return math.floor((dn - w1) / 7) + 1, y
end
function date.__isoy(dn)
    local y = date.__breakdaynum(dn)
    return y + (
        (
            (dn >= date.__makedaynum(y, 11, 29)) and
            (dn >= date.__isow1(y + 1))
        ) and 1 or (dn < date.__isow1(y) and -1 or 0)
    )
end
function date.__makedaynum_isoywd(y, w, d)
    -- simplified: date.__isow1(y) + ((w-1)*7) + (d-1)
    return date.__isow1(y) + 7 * w + d - 8
end

-- shout invalid arg
function date.__date_error_arg()
    return error('invalid argument(s)', 0)
end

-- The date object
local dobj = {}
dobj.__index = dobj
dobj.__metatable = dobj

-- Create new date object
function dobj.__date_new(dn, df)
    return setmetatable({daynum=dn, dayfrc=df}, dobj)
end

-- Magic year table
dobj.__DATE_EPOCH = nil
dobj.__YEAR_TABLE = nil
function dobj.__getequivyear(y)
    assert(not dobj.__YEAR_TABLE)
    dobj.__YEAR_TABLE = {}
    local de = dobj.__DATE_EPOCH:copy()
    local dw, dy
    for _ = 0, 3000 do
        de:setyear(de:getyear() + 1, 1, 1)
        dy = de:getyear()
        dw = de:getweekday() * (date.__isleapyear(dy) and  -1 or 1)
        if not dobj.__YEAR_TABLE[dw] then
            dobj.__YEAR_TABLE[dw] = dy
        end
        if (
            dobj.__YEAR_TABLE[1] and dobj.__YEAR_TABLE[2] and
            dobj.__YEAR_TABLE[3] and dobj.__YEAR_TABLE[4] and
            dobj.__YEAR_TABLE[5] and dobj.__YEAR_TABLE[6] and
            dobj.__YEAR_TABLE[7] and dobj.__YEAR_TABLE[-1] and
            dobj.__YEAR_TABLE[-2] and dobj.__YEAR_TABLE[-3] and
            dobj.__YEAR_TABLE[-4] and dobj.__YEAR_TABLE[-5] and
            dobj.__YEAR_TABLE[-6] and dobj.__YEAR_TABLE[-7]
        ) then
            dobj.__getequivyear = function(y)
                return dobj.__YEAR_TABLE[
                    (date.__weekday(date.__makedaynum(y, 0, 1)) + 1) *
                    (date.__isleapyear(y) and  -1 or 1)
                ]
            end
            return dobj.__getequivyear(y)
        end
    end
end

-- TimeValue from date and time
function dobj.__totv(y, m, d, h, r, s)
    return (
        (date.__makedaynum(y, m, d) - date.__DATE_EPOCH) *
        date.__SECPERDAY  +
        ((h * 60 + r) * 60 + s)
    )
end

-- TimeValue from TimeTable
function dobj.__tmtotv(tm)
    return tm and dobj.__totv(
        tm.year, tm.month - 1, tm.day, tm.hour, tm.min, tm.sec
    )
end

-- Returns the bias in seconds of utc time daynum and dayfrc
function dobj.__getbiasutc2(self)
    local y,m,d = date.__breakdaynum(self.daynum)
    local h, r, s = date.__breakdayfrc(self.dayfrc)
     -- get the utc TimeValue of date and time
    local tvu = dobj.__totv(y, m, d, h, r, s)
     -- get the local TimeTable of tvu
    local tml = os.date('*t', tvu)
    -- failed try the magic
    if (not tml) or (tml.year > (y + 1) or tml.year < (y - 1)) then
        y = dobj.__getequivyear(y)
        tvu = dobj.__totv(y, m, d, h, r, s)
        tml = os.date('*t', tvu)
    end
    local tvl = dobj.__tmtotv(tml)
    if tvu and tvl then
        return tvu - tvl, tvu, tvl
    else
        return error('failed to get bias from utc time')
    end
end

-- Returns the bias in seconds of local time daynum and dayfrc
function dobj.__getbiasloc2(daynum, dayfrc)
    local tvu
    -- extract date and time
    local y,m,d = date.__breakdaynum(daynum)
    local h,r,s = date.__breakdayfrc(dayfrc)
    -- get equivalent TimeTable
    local tml = {year=y, month=m+1, day=d, hour=h, min=r, sec=s}
    -- get equivalent TimeValue
    local tvl = dobj.__tmtotv(tml)

    local function chkutc()
        tml.isdst = nil
        local tvug = os.time(tml)
        if tvug and (tvl == dobj.__tmtotv(os.date('*t', tvug))) then
            tvu = tvug
            return
        end
        tml.isdst = true
        local tvud = os.time(tml)
        if tvud and (tvl == dobj.__tmtotv(os.date('*t', tvud))) then
            tvu = tvud
            return
        end
        tvu = tvud or tvug
    end
    chkutc()
    if not tvu then
        tml.year = dobj.__getequivyear(y)
        tvl = dobj.__tmtotv(tml)
        chkutc()
    end
    return
        (
            ((tvu and tvl) and (tvu - tvl)) or
            error('failed to get bias from local time')
        ), tvu, tvl
end

-- The date parser
local strwalker = {} -- ^Lua regular expression is not as powerful as Perl$
strwalker.__index = strwalker
function strwalker.__newstrwalker(s)
    return setmetatable({s = s, i = 1, e = 1, c = string.len(s)}, strwalker)
end
function strwalker:aimchr()
    return '\n' .. self.s .. '\n' .. string.rep('.',self.e-1) .. '^'
end
function strwalker:finish()
    return self.i > self.c
end
function strwalker:back()
    self.i = self.e
    return self
end
function strwalker:restart()
    self.i, self.e = 1, 1
    return self
end
function strwalker:match(s)
    return (string.find(self.s, s, self.i))
end
function strwalker:__call(s, f)
    local is, ie
    is, ie, self[1], self[2], self[3], self[4], self[5] = string.find(
                                                        self.s, s, self.i)
    if is then
        self.e, self.i = self.i, 1+ie
        if f then
            f(unpack(self))
        end
        return self
    end
end

function strwalker.__date_parse(str)
    local y, m, d
    local h, r, s
    local z
    local w, u
    local j
    local e
    local x, c
    local dn, df
    local sw = strwalker.__newstrwalker( -- remove comment, trim leading space
        string.gsub(string.gsub(str, '(%b())', ''), '^(%s*)', '')
    )
    local function error_dup(q)
        error('duplicate value: ' .. (q or '') .. sw:aimchr())
    end
    local function error_syn(q)
        error('syntax error: ' .. (q or '') .. sw:aimchr())
    end
    local function error_inv(q)
      error('invalid date: ' .. (q or '') .. sw:aimchr())
    end
    local function sety(q)
        y = y and error_dup() or tonumber(q)
    end
    local function setm(q)
        m = (m or w or j) and error_dup(m or w or j) or tonumber(q)
    end
    local function setd(q)
        d = d and error_dup() or tonumber(q)
    end
    local function seth(q)
        h = h and error_dup() or tonumber(q)
    end
    local function setr(q)
        r = r and error_dup() or tonumber(q)
    end
    local function sets(q)
        s = s and error_dup() or tonumber(q)
    end
    local function adds(q)
        s = s + tonumber(q)
    end
    local function setj(q)
        j = (m or w or j) and error_dup() or tonumber(q)
    end
    local function setz(q)
        z = (z ~= 0 and z) and error_dup() or q
    end
    local function setzn(zs, zn)
        zn = tonumber(zn)
        setz(
            (
                (zn < 24) and
                (zn * 60) or (date.__mod(zn, 100) + math.floor(zn / 100) * 60)
            ) * ( zs == '+' and -1 or 1) 
        )
    end
    local function setzc(zs, zh, zm)
        setz( ((tonumber(zh) * 60) + tonumber(zm)) * ( zs == '+' and -1 or 1) )
    end

    if not (
        sw('^(%d%d%d%d)', sety) and
        (
            sw(
                '^(%-?)(%d%d)%1(%d%d)',
                function(_,a, b) setm(tonumber(a))
                    setd(tonumber(b))
                end
            ) or sw(
                '^(%-?)[Ww](%d%d)%1(%d?)',
                function(_, a, b)
                    w, u = tonumber(a), tonumber(b or 1)
                end
            ) or sw('^%-?(%d%d%d)',setj) or
            sw(
                '^%-?(%d%d)',
                function(a)
                    setm(a)
                    setd(1)
                end
            )
        ) and (
            (
                sw('^%s*[Tt]?(%d%d):?', seth) and
                sw('^(%d%d):?',setr) and
                sw('^(%d%d)',sets) and
                sw('^(%.%d+)',adds)
            ) or
            sw:finish() or
            (
                sw'^%s*$' or
                sw'^%s*[Zz]%s*$' or
                sw('^%s-([%+%-])(%d%d):?(%d%d)%s*$', setzc) or
                sw('^%s*([%+%-])(%d%d)%s*$',setzn)
            )
        ) 
    ) then
        sw:restart()
        y, m, d = nil, nil, nil
        h, r, s = nil, nil, nil
        z, w, u, j = nil, nil, nil, nil
        repeat
            if sw('^[tT:]?%s*(%d%d?):', seth) then
                _ = (
                    sw('^%s*(%d%d?)', setr) and
                    sw('^%s*:%s*(%d%d?)', sets) and
                    sw('^(%.%d+)', adds)
                )
            elseif sw('^(%d+)[/\\%s,-]?%s*') then
                x, c = tonumber(sw[1]), string.len(sw[1])
                if (x >= 70) or (m and d and (not y)) or (c > 3) then
                    sety( x + ((x >= 100 or c > 3)and 0 or 1900) )
                else
                    if m then
                        setd(x)
                    else
                        m = x
                    end
                end
            elseif sw('^(%a+)[/\\%s,-]?%s*') then
                x = sw[1]
                if date.__inlist(x, date.__SL_MONTHS, 2, sw) then
                    if m and (not d) and (not y) then d, m = m, false end
                    setm(date.__mod(sw[0], 12) + 1)
                elseif date.__inlist(x, date.__SL_TIMEZONE, 2, sw) then
                    c = date.__fix(sw[0]) -- ignore gmt and utc
                    if c ~= 0 then
                        setz(c, x)
                    end
                elseif not date.__inlist(x, date.__SL_WEEKDAYS, 2, sw) then
                    sw:back()
                    -- am pm bce ad ce bc
                    if (
                        sw('^([bB])%s*(%.?)%s*[Cc]%s*(%2)%s*[Ee]%s*(%2)%s*') or
                        sw('^([bB])%s*(%.?)%s*[Cc]%s*(%2)%s*')
                    ) then
                        e = e and error_dup() or -1
                    elseif (
                        sw('^([aA])%s*(%.?)%s*[Dd]%s*(%2)%s*') or
                        sw('^([cC])%s*(%.?)%s*[Ee]%s*(%2)%s*')
                    ) then
                        e = e and error_dup() or 1
                    elseif sw('^([PApa])%s*(%.?)%s*[Mm]?%s*(%2)%s*') then
                        -- there should be hour and it must be correct
                        x = string.lower(sw[1])
                        if (not h) or (h > 12) or (h < 0) then
                            return error_inv()
                        end
                        if x == 'a' and h == 12 then -- am
                            h = 0
                        end
                        if x == 'p' and h ~= 12 then -- pm
                            h = h + 12
                        end
                    else
                        error_syn() 
                    end
                end
            elseif not(
                sw('^([+-])(%d%d?):(%d%d)',setzc) or
                sw('^([+-])(%d+)',setzn) or
                sw('^[Zz]%s*$')
            ) then
                error_syn('?')
            end
            sw('^%s*')
        until sw:finish()
    end
    -- if date is given, it must be complete year, month & day
    if (
        (not y and not h) or
        ((m and not d) or (d and not m)) or
        ((m and w) or (m and j) or (j and w))
    ) then
        return error_inv('!')
    end
    -- fix month
    if m then
        m = m - 1
    end
    -- fix year if we are on BCE
    if e and e < 0 and y > 0 then
        y = 1 - y
    end
    --  create date object
    dn = (
        (y and (
            (w and date.__makedaynum_isoywd(y,w,u)) or
            (j and date.__makedaynum(y, 0, j)) or
            date.__makedaynum(y, m, d))
        ) or date.__DAYNUM_DEF
    )
    df = (
        date.__makedayfrc(h or 0, r or 0, s or 0, 0) +
        ((z or 0)*date.__TICKSPERMIN)
    )
    return dobj.__date_new(dn, df) -- no need to :normalize();
end

function strwalker.__date_fromtable(v)
    local y = date.__fix(v.year)
    local m = date.__getmontharg(v.month)
    local d = date.__fix(v.day)
    local h = tonumber(v.hour)
    local r = tonumber(v.min)
    local s = tonumber(v.sec)
    local t = tonumber(v.ticks)
    -- atleast there is time or complete date
    if (y or m or d) and (not(y and m and d)) then
        return error('incomplete table')
    end
    return (y or h or r or s or t) and
        dobj.__date_new(
              y and date.__makedaynum(y, m, d) or date.__DAYNUM_DEF,
              date.__makedayfrc(h or 0, r or 0, s or 0, t or 0)
        )
end

strwalker.__tmap = {
    ['number'] = function(v)
        return dobj.__DATE_EPOCH:copy():addseconds(v)
    end,
    ['string'] = function(v)
        return strwalker.__date_parse(v)
    end,
    ['boolean'] = function(v)
        return strwalker.__date_fromtable(os.date(v and '!*t' or '*t'))
    end,
    ['table'] = function(v)
        local ref = getmetatable(v) == dobj
        return ref and v or strwalker.__date_fromtable(v), ref
    end,
}

function strwalker.__date_getdobj(v)
    local o, r = (strwalker.__tmap[type(v)] or noop)(v)
    -- if r is true then o is a reference to a date obj
    return (o and o:normalize() or error('invalid date time value')), r
end

function strwalker.__date_from(arg1, arg2, arg3, arg4, arg5, arg6, arg7)
    local y = date.__fix(arg1)
    local m = date.__getmontharg(arg2)
    local d= date.__fix(arg3)
    local h = tonumber(arg4 or 0)
    local r = tonumber(arg5 or 0)
    local s = tonumber(arg6 or 0)
    local t = tonumber(arg7 or 0)
    if y and m and d and h and r and s and t then
        return 
            dobj.__date_new(date.__makedaynum(y, m, d),
            date.__makedayfrc(h, r, s, t)):normalize()
    else
        return date.__date_error_arg()
    end
end

-- Date object methods
function dobj:normalize()
    local dn, df = date.__fix(self.daynum), self.dayfrc
    self.daynum = dn + math.floor(df/date.__TICKSPERDAY)
    self.dayfrc = date.__mod(df, date.__TICKSPERDAY)
    return
        (dn >= date.__DAYNUM_MIN and dn <= date.__DAYNUM_MAX) and
        self or error('date beyond imposed limits:' .. self)
end

function dobj:getdate()
    local y, m, d = date.__breakdaynum(self.daynum)
    return y, m + 1, d
end

function dobj:gettime()
    return date.__breakdayfrc(self.dayfrc)
end

function dobj:getclockhour()
    local h = self:gethours()
    return h > 12 and date.__mod(h,12) or (h==0 and 12 or h)
end

function dobj:getyearday()
    return date.__yearday(self.daynum) + 1
end

function dobj:getweekday()
    -- in lua weekday is sunday = 1, monday = 2 ...
    return date.__weekday(self.daynum) + 1
end

function dobj:getyear()
    local r, _, _ = date.__breakdaynum(self.daynum)
    return r
end

function dobj:getmonth()
    local _, r, _ = date.__breakdaynum(self.daynum)
    -- in lua month is 1 base
    return r + 1
end

function dobj:getday()
    local _, _, r = date.__breakdaynum(self.daynum)
    return r
end

function dobj:gethours()
    return date.__mod(
        math.floor(self.dayfrc / date.__TICKSPERHOUR),
        date.__HOURPERDAY
    )
end

function dobj:getminutes()
    return date.__mod(
        math.floor(self.dayfrc / date.__TICKSPERMIN),
        date.__MINPERHOUR
    )
end

function dobj:getseconds()
    return date.__mod(
        math.floor(self.dayfrc / date.__TICKSPERSEC),
        date.__SECPERMIN
    )
end

function dobj:getfracsec()
    return (
        date.__mod(
            math.floor(self.dayfrc / date.__TICKSPERSEC ),
            date.__SECPERMIN
        ) + (date.__mod(
            self.dayfrc,
            date.__TICKSPERSEC) / date.__TICKSPERSEC
        )
     )
end

function dobj:getticks(u)
    local x = date.__mod(self.dayfrc, date.__TICKSPERSEC)
    return u and ((x * u) / date.__TICKSPERSEC) or x
end

function dobj:getweeknumber(wdb)
    local wd, yd = date.__weekday(self.daynum), date.__yearday(self.daynum)
    if wdb then
        wdb = tonumber(wdb)
        if wdb then
            wd = date.__mod(wd - (wdb - 1), 7)-- shift the week day base
        else
            return date.__date_error_arg()
        end
    end
    return (
        (yd < wd and 0) or
        (math.floor(yd / 7) + ((date.__mod(yd, 7) >= wd) and 1 or 0))
    )
end

function dobj:getisoweekday()
    -- sunday = 7, monday = 1 ...
    return date.__mod(date.__weekday(self.daynum) - 1, 7) + 1
end

function dobj:getisoweeknumber()
    return (date.__isowy(self.daynum))
end

function dobj:getisoyear()
    return date.__isoy(self.daynum)
end

function dobj:getisodate()
    local w, y = date.__isowy(self.daynum)
    return y, w, self:getisoweekday()
end

function dobj:setisoyear(y, w, d)
    local cy, cw, cd = self:getisodate()
    if y then
        cy = date.__fix(tonumber(y))
    end
    if w then
        cw = date.__fix(tonumber(w))
    end
    if d then
        cd = date.__fix(tonumber(d))
    end
    if cy and cw and cd then
        self.daynum = date.__makedaynum_isoywd(cy, cw, cd)
        return self:normalize()
    else
        return date.__date_error_arg()
    end
end

function dobj:setisoweekday(d)
    return self:setisoyear(nil, nil, d)
end

function dobj:setisoweeknumber(w,d)
    return self:setisoyear(nil, w, d)
end

function dobj:setyear(y, m, d)
    local cy, cm, cd = date.__breakdaynum(self.daynum)
    if y then
        cy = date.__fix(tonumber(y))
    end
    if m then
        cm = date.__getmontharg(m)
    end
    if d then
        cd = date.__fix(tonumber(d))
    end
    if cy and cm and cd then
        self.daynum = date.__makedaynum(cy, cm, cd)
        return self:normalize()
    else
        return date.__date_error_arg()
    end
end

function dobj:setmonth(m, d)
    return self:setyear(nil, m, d)
end

function dobj:setday(d)
    return self:setyear(nil, nil, d)
end

function dobj:sethours(h, m, s, t)
    local ch,cm,cs,ck = date.__breakdayfrc(self.dayfrc)
    ch = tonumber(h or ch)
    cm = tonumber(m or cm)
    cs = tonumber(s or cs)
    ck = tonumber(t or ck)
    if ch and cm and cs and ck then
        self.dayfrc = date.__makedayfrc(ch, cm, cs, ck)
        return self:normalize()
    else
        return date.__date_error_arg()
    end
end

function dobj:setminutes(m,s,t)
    return self:sethours(nil, m, s, t)
end
function dobj:setseconds(s, t)
    return self:sethours(nil, nil, s, t)
end
function dobj:setticks(t)
    return self:sethours(nil, nil, nil, t)
end

function dobj:spanticks()
    return (self.daynum * date.__TICKSPERDAY + self.dayfrc)
end

function dobj:spanseconds()
    return (self.daynum * date.__TICKSPERDAY + self.dayfrc) / date.__TICKSPERSEC
end

function dobj:spanminutes()
    return (self.daynum * date.__TICKSPERDAY + self.dayfrc) / date.__TICKSPERMIN
end

function dobj:spanhours()
    return (self.daynum * date.__TICKSPERDAY + self.dayfrc) /
                                                      date.__TICKSPERHOUR
end

function dobj:spandays()
    return (self.daynum * date.__TICKSPERDAY + self.dayfrc) / date.__TICKSPERDAY
end

function dobj:addyears(y, m, d)
    local cy, cm, cd = date.__breakdaynum(self.daynum)
    if y then
        y = date.__fix(tonumber(y))
    else
        y = 0
    end
    if m then
        m = date.__fix(tonumber(m))
    else
        m = 0
    end
    if d then
        d = date.__fix(tonumber(d))
    else
        d = 0
    end
    if y and m and d then
        self.daynum  = date.__makedaynum(cy + y, cm + m, cd + d)
        return self:normalize()
    else
        return date.__date_error_arg()
    end
end

function dobj:addmonths(m, d)
    return self:addyears(nil, m, d)
end

function dobj.__adddayfrc(self, n, pt, pd)
    n = tonumber(n)
    if n then
        local x = math.floor(n / pd)
        self.daynum = self.daynum + x
        self.dayfrc = self.dayfrc + (n - x * pd) * pt
        return self:normalize()
    else
        return date.__date_error_arg()
    end
end

function dobj:adddays(n)
    return dobj.__adddayfrc(self, n, date.__TICKSPERDAY, 1)
end

function dobj:addhours(n)
    return dobj.__adddayfrc(self, n, date.__TICKSPERHOUR, date.__HOURPERDAY)
end

function dobj:addminutes(n)
    return dobj.__adddayfrc(self, n, date.__TICKSPERMIN, date.__MINPERDAY)
end

function dobj:addseconds(n)
    return dobj.__adddayfrc(self, n, date.__TICKSPERSEC, date.__SECPERDAY)
end

function dobj:addticks(n)
    return dobj.__adddayfrc(self, n, 1, date.__TICKSPERDAY)
end

dobj.__tvspec = {
    -- Abbreviated weekday name (Sun)
    ['%a'] = function(self)
        return date.__SL_WEEKDAYS[date.__weekday(self.daynum) + 7]
    end,
    -- Full weekday name (Sunday)
    ['%A'] = function(self)
        return date.__SL_WEEKDAYS[date.__weekday(self.daynum)]
    end,
    -- Abbreviated month name (Dec)
    ['%b'] = function(self)
        return date.__SL_MONTHS[self:getmonth() - 1 + 12]
    end,
    -- Full month name (December)
    ['%B'] = function(self)
        return date.__SL_MONTHS[self:getmonth() - 1]
    end,
    -- Year/100 (19, 20, 30)
    ['%C'] = function(self)
        return string.format('%.2d', date.__fix(self:getyear() / 100))
    end,
    -- The day of the month as a number (range 1 - 31)
    ['%d'] = function(self)
        return string.format('%.2d', self:getday())
    end,
    -- year for ISO 8601 week, from 00 (79)
    ['%g'] = function(self)
        return string.format('%.2d', date.__mod(self:getisoyear(), 100))
    end,
    -- year for ISO 8601 week, from 0000 (1979)
    ['%G'] = function(self)
        return string.format('%.4d', self:getisoyear())
    end,
    -- same as %b
    ['%h'] = function(self)
        return self:fmt0('%b')
    end,
    -- hour of the 24-hour day, from 00 (06)
    ['%H'] = function(self)
        return string.format('%.2d', self:gethours())
    end,
    -- The  hour as a number using a 12-hour clock (01 - 12)
    ['%I'] = function(self)
        return string.format('%.2d', self:getclockhour())
    end,
    -- The day of the year as a number (001 - 366)
    ['%j'] = function(self)
        return string.format('%.3d', self:getyearday())
    end,
    -- Month of the year, from 01 to 12
    ['%m'] = function(self)
        return string.format('%.2d', self:getmonth())
    end,
    -- Minutes after the hour 55
    ['%M'] = function(self)
        return string.format('%.2d', self:getminutes())
    end,
    -- AM/PM indicator (AM)
    ['%p'] = function(self)
        return date.__SL_MERIDIAN[self:gethours() > 11 and 1 or -1]
    end,
    -- The second as a number (59, 20 , 01)
    ['%S'] = function(self)
        return string.format('%.2d', self:getseconds())
    end,
    -- ISO 8601 day of the week, to 7 for Sunday (7, 1)
    ['%u'] = function(self)
        return self:getisoweekday()
    end,
    -- Sunday week of the year, from 00 (48)
    ['%U'] = function(self)
        return string.format('%.2d', self:getweeknumber())
    end,
    -- ISO 8601 week of the year, from 01 (48)
    ['%V'] = function(self)
        return string.format('%.2d', self:getisoweeknumber())
    end,
    -- The day of the week as a decimal, Sunday being 0
    ['%w'] = function(self)
        return self:getweekday() - 1
    end,
    -- Monday week of the year, from 00 (48)
    ['%W'] = function(self)
        return string.format('%.2d', self:getweeknumber(2))
    end,
    -- The year as a number without a century (range 00 to 99)
    ['%y'] = function(self)
        return string.format('%.2d', date.__mod(self:getyear() ,100))
    end,
    -- Year with century (2000, 1914, 0325, 0001)
    ['%Y'] = function(self)
        return string.format('%.4d', self:getyear())
    end,
    -- Time zone offset, the date object is assumed local time (+1000, -0230)
    ['%z'] = function(self)
        local b = -self:getbias(); local x = math.abs(b)
        return string.format(
            '%s%.4d',
            b < 0 and '-' or '+',
            date.__fix(x / 60) * 100 + math.floor(date.__mod(x, 60))
        )
    end,
    -- Time zone name, the date object is assumed local time
    ['%Z'] = function(self)
        return self:gettzname()
    end,
    -- Misc --
    -- Year, if year is in BCE, prints the BCE Year representation,
    -- otherwise result is similar to '%Y' (1 BCE, 40 BCE)
    ['%\b'] = function(self)
        local x = self:getyear()
        return string.format(
            '%.4d%s',
            x > 0 and x or (-x + 1),
            x > 0 and '' or ' BCE'
        )
    end,
    -- Seconds including fraction (59.998, 01.123)
    ['%\f'] = function(self)
        local x = self:getfracsec()
        return string.format('%s%.9f', x >= 10 and '' or '0', x)
    end,
    -- percent character %
    ['%%'] = function(self)
        return '%'
    end,
    -- Group Spec --
    -- 12-hour time, from 01:00:00 AM (06:55:15 AM); same as '%I:%M:%S %p'
    ['%r'] = function(self)
        return self:fmt0('%I:%M:%S %p')
    end,
    -- hour:minute, from 01:00 (06:55); same as '%I:%M'
    ['%R'] = function(self)
        return self:fmt0('%I:%M')
    end,
    -- 24-hour time, from 00:00:00 (06:55:15); same as '%H:%M:%S'
    ['%T'] = function(self)
        return self:fmt0('%H:%M:%S')
    end,
    -- month/day/year from 01/01/00 (12/02/79); same as '%m/%d/%y'
    ['%D'] = function(self)
        return self:fmt0('%m/%d/%y')
    end,
    -- year-month-day (1979-12-02); same as '%Y-%m-%d'
    ['%F'] = function(self)
        return self:fmt0('%Y-%m-%d')
    end,
    -- The preferred date and time representation;  same as '%x %X'
    ['%c'] = function(self)
        return self:fmt0('%x %X')
    end,
    -- The preferred date representation, same as '%a %b %d %\b'
    ['%x'] = function(self)
        return self:fmt0('%a %b %d %\b')
    end,
    -- The preferred time representation, same as '%H:%M:%\f'
    ['%X'] = function(self)
        return self:fmt0('%H:%M:%\f')
    end,
    -- GroupSpec --
    -- Iso format, same as '%Y-%m-%dT%T'
    ['${iso}'] = function(self)
        return self:fmt0('%Y-%m-%dT%T')
    end,
    -- http format, same as '%a, %d %b %Y %T GMT'
    ['${http}'] = function(self)
        return self:fmt0('%a, %d %b %Y %T GMT')
    end,
    -- ctime format, same as '%a %b %d %T GMT %Y'
    ['${ctime}'] = function(self)
        return self:fmt0('%a %b %d %T GMT %Y')
    end,
    -- RFC850 format, same as '%A, %d-%b-%y %T GMT'
    ['${rfc850}'] = function(self)
        return self:fmt0('%A, %d-%b-%y %T GMT')
    end,
    -- RFC1123 format, same as '%a, %d %b %Y %T GMT'
    ['${rfc1123}'] = function(self)
        return self:fmt0('%a, %d %b %Y %T GMT')
    end,
    -- asctime format, same as '%a %b %d %T %Y'
    ['${asctime}'] = function(self)
        return self:fmt0('%a %b %d %T %Y')
    end,
}

function dobj:fmt0(str)
    return (string.gsub(
        str,
        '%%[%a%%\b\f]',
        function(x)
            local f = dobj.__tvspec[x]
            return (f and f(self)) or x
        end
    ))
end

function dobj:fmt(str)
    str = str or self.fmtstr or date.__FMTSTR
    return self:fmt0(
        (string.gmatch(str, '${%w+}')) and
        (string.gsub(
            str,
            '${%w+}',
            function(x)
                local f = dobj.__tvspec[x]
                return (f and f(self)) or x
            end
        )) or
        str
    )
end

function dobj.__lt(a, b)
    if (a.daynum == b.daynum) then
        return (a.dayfrc < b.dayfrc)
    else
        return (a.daynum < b.daynum)
    end
end

function dobj.__le(a, b)
    if (a.daynum == b.daynum) then
        return (a.dayfrc <= b.dayfrc)
    else
        return (a.daynum <= b.daynum)
    end
end

function dobj.__eq(a, b)
    return (a.daynum == b.daynum) and (a.dayfrc == b.dayfrc)
end

function dobj.__sub(a,b)
    local d1, d2 = strwalker.__date_getdobj(a), strwalker.__date_getdobj(b)
    local d0 = (
        d1 and
        d2 and
        dobj.__date_new(d1.daynum - d2.daynum, d1.dayfrc - d2.dayfrc)
    )
    return d0 and d0:normalize()
end

function dobj.__add(a,b)
    local d1, d2 = strwalker.__date_getdobj(a), strwalker.__date_getdobj(b)
    local d0 = (
        d1 and
        d2 and
        dobj.__date_new(d1.daynum + d2.daynum, d1.dayfrc + d2.dayfrc)
    )
    return d0 and d0:normalize()
end

function dobj.__concat(a, b)
    return tostring(a) .. tostring(b)
end

function dobj:__tostring()
    return self:fmt()
end

function dobj:copy()
    return dobj.__date_new(self.daynum, self.dayfrc)
end

-- Local date object methods
function dobj:tolocal()
    local dn, df = self.daynum, self.dayfrc
    local bias  = dobj.__getbiasutc2(self)
    if bias then
        self.daynum = dn
        self.dayfrc = df - bias * date.__TICKSPERSEC
        return self:normalize()
    else
        return nil
    end
end

function dobj:toutc()
    local dn, df = self.daynum, self.dayfrc
    local bias  = dobj.__getbiasloc2(dn, df)
    if bias then
        self.daynum = dn
        self.dayfrc = df + bias * date.__TICKSPERSEC
        return self:normalize()
    else
        return nil
    end
end

function dobj:getbias()
    return (dobj.__getbiasloc2(self.daynum, self.dayfrc)) / date.__SECPERMIN
end

function dobj:gettzname()
    local _, tvu, _ = dobj.__getbiasloc2(self.daynum, self.dayfrc)
    return tvu and os.date('%Z',tvu) or ''
end

function date.time(h, r, s, t)
    h = tonumber(h or 0)
    r = tonumber(r or 0)
    s = tonumber(s or 0)
    t = tonumber(t or 0)
    if h and r and s and t then
        return dobj.__date_new(date.__DAYNUM_DEF, date.__makedayfrc(h, r, s, t))
    else
        return date.__date_error_arg()
    end
end

function date:__call(arg1, ...)
    local arg_count = select('#', ...) + (arg1 == nil and 0 or 1)
    if arg_count  > 1 then
        return (strwalker.__date_from(arg1, ...))
    elseif arg_count == 0 then
        return (strwalker.__date_getdobj(false))
    else
        local o, r = strwalker.__date_getdobj(arg1)
        return r and o:copy() or o
    end
end

date.diff = dobj.__sub

function date.isleapyear(v)
    local y = date.__fix(v)
    if not y then
        y = strwalker.__date_getdobj(v)
        y = y and y:getyear()
    end
    return date.__isleapyear(y + 0)
end

function date.epoch()
    return dobj.__DATE_EPOCH:copy()
end

function date.isodate(y, w, d)
    return dobj.__date_new(
        date.__makedaynum_isoywd(y + 0, w and (w + 0) or 1, d and (d + 0) or 1),
        0
    )
end

-- Internal date functions
function date.fmt(str)
    if str then
        date.__FMTSTR = str
    end
    return date.__FMTSTR
end

function date.daynummin(n)
    date.__DAYNUM_MIN = (n and n < date.__DAYNUM_MAX) and n or date.__DAYNUM_MIN
    return (
        n and
        date.__DAYNUM_MIN or
        dobj.__date_new(date.__DAYNUM_MIN, 0):normalize()
    )
end

function date.daynummax(n)
    date.__DAYNUM_MAX = (n and n > date.__DAYNUM_MIN) and n or date.__DAYNUM_MAX
    return (
        n and
        date.__DAYNUM_MAX or 
        obj.__date_new(date.__DAYNUM_MAX, 0):normalize()
    )
end

function date.ticks(t)
    if t then
        date.__setticks(t)
    end
    return date.__TICKSPERSEC
end

local __tm = os.date('!*t', 0)
if __tm then
    dobj.__DATE_EPOCH = dobj.__date_new(
        date.__makedaynum(__tm.year, __tm.month - 1, __tm.day),
        date.__makedayfrc(__tm.hour, __tm.min, __tm.sec, 0)
    )
    -- the distance from our epoch to os epoch in daynum
    date.__DATE_EPOCH = dobj.__DATE_EPOCH and dobj.__DATE_EPOCH:spandays()
else -- error will be raise only if called!
    dobj.__DATE_EPOCH = setmetatable({}, {__index = function()
        error('failed to get the epoch date')
    end})
end

--[[
/* 
   A C-program for MT19937, with initialization improved 2002/1/26.
   Coded by Takuji Nishimura and Makoto Matsumoto.

   Before using, initialize the state by using init_genrand(seed)  
   or init_by_array(init_key, key_length).

   Copyright (C) 1997 - 2002, Makoto Matsumoto and Takuji Nishimura,
   All rights reserved.                          

   Redistribution and use in source and binary forms, with or without
   modification, are permitted provided that the following conditions
   are met:

     1. Redistributions of source code must retain the above copyright
        notice, this list of conditions and the following disclaimer.

     2. Redistributions in binary form must reproduce the above copyright
        notice, this list of conditions and the following disclaimer in the
        documentation and/or other materials provided with the distribution.

     3. The names of its contributors may not be used to endorse or promote 
        products derived from this software without specific prior written 
        permission.

   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
   "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
   LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
   A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT OWNER
   OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
   EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
   PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
   PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
   LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
   NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
   SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


   Any feedback is very welcome.
   http://www.math.sci.hiroshima-u.ac.jp/~m-mat/MT/emt.html
   email: m-mat @ math.sci.hiroshima-u.ac.jp (remove space)
*/
--]]
mersenne_twister = singleton()

mersenne_twister.__SAFEMUL32 = function(a, b)
    local alo = math.floor(a % 65536)
    local ahi = math.floor(a / 65536) % 65536
    local blo = math.floor(b % 65536)
    local bhi = math.floor(b / 65536) % 65536
    local lolo = alo * blo
    local lohi = alo * bhi
    local hilo = ahi * blo
    local llhh = lohi + hilo
    return math.floor((llhh * 65536 + lolo) % 4294967296)
end

mersenne_twister.__AND = function(a, b)
    local r, p = 0, 1
    for i = 0, 31 do
        local a1 = a % 2
        local b1 = b % 2
        if (a1 > 0) and (b1 > 0) then
            r = r + p
        end
        if a1 > 0 then
            a = a - 1
        end
        if b1 > 0 then
            b = b - 1
        end
        a = a / 2
        b = b / 2
        p = p * 2
    end
    return r
end

mersenne_twister.__OR = function(a, b)
    local r, p = 0, 1
    for i = 0, 31 do
        local a1 = a % 2
        local b1 = b % 2
        if (a1 > 0) or (b1 > 0) then
            r = r + p
        end
        if a1 > 0 then
            a = a - 1
        end
        if b1 > 0 then
            b = b - 1
        end
        a = a / 2
        b = b / 2
        p = p * 2
    end
    return r
end

mersenne_twister.__XOR = function(a, b)
    local r, p = 0, 1
    for i = 0, 31 do
        local a1 = a % 2
        local b1 = b % 2
        if a1 ~= b1 then
            r = r + p
        end
        if a1 > 0 then
            a = a - 1
        end
        if b1 > 0 then
            b = b - 1
        end
        a = a / 2
        b = b / 2
        p = p * 2
    end
    return r
end

mersenne_twister.__SHR1 = function(y)
    return math.floor(y / 2)
end

mersenne_twister.__SHR30 = function(y)
    return math.floor(y / 1073741824)
end

mersenne_twister.__SHR11 = function(y)
    return math.floor(y / 2048)
end

mersenne_twister.__SHL7 = function(y)
    return (y * 128)
end

mersenne_twister.__SHL15 = function(y)
    return (y * 32768)
end

mersenne_twister.__SHR18 = function(y)
    return math.floor(y / 262144)
end

mersenne_twister.__BIT0 = function(y)
    return (y % 2)
end

mersenne_twister.__N = 624
mersenne_twister.__M = 397

mersenne_twister.__MATRIX_A = 0x9908B0DF
mersenne_twister.__UPPER_MASK = 0x80000000
mersenne_twister.__LOWER_MASK = 0x7FFFFFFF

function mersenne_twister:init()
    self:reset()
end

function mersenne_twister:reset()
    self.mt = {}
    self.mti = self.__N + 1
end

--------------------------------------------------------------------------------
-- Seed the generator via a number
-- @param s number representing a 32-bit integer seed value
--------------------------------------------------------------------------------
function mersenne_twister:init_genrand(s)
    self.mt[0] = self.__AND(s, 0xFFFFFFFF)
    for i = 1, self.__N - 1 do
        self.mt[i] = self.__SAFEMUL32(
            1812433253,
            self.__XOR(self.mt[i - 1], self.__SHR30(self.mt[i - 1]))
        ) + i
        self.mt[i] = self.__AND(self.mt[i], 0xFFFFFFFF)
    end
    self.mti = self.__N
end

--------------------------------------------------------------------------------
-- Seed the generator via an array
-- @param init_key array of integer seeds
-- @param key_len number(option) use for the length of the array
--------------------------------------------------------------------------------
function mersenne_twister:init_by_array(init_key, key_len)
    self:init_genrand(19650218)
    if not key_len
        then key_len = #init_key
    end
    local i, j, k = 1, 0, (self.__N > key_len and self.__N) or key_len
    while k > 0 do
        self.mt[i] = self.__XOR(
            self.mt[i],
            self.__SAFEMUL32(
                self.__XOR(self.mt[i - 1], self.__SHR30(self.mt[i - 1])),
                1664525
            )
        ) + init_key[j + 1] + j
        self.mt[i] = self.__AND(self.mt[i], 0xFFFFFFFF)
        i, j = i + 1, j + 1
        if i >= self.__N then
            self.mt[0] = self.mt[self.__N - 1]
            i = 1
        end
        if j >= key_length then
            j = 0
        end
        k = k - 1
    end
    for k = self.__N-1, 1, -1 do
        self.mt[i] = self.__XOR(
            self.mt[i],
            self.__SAFEMUL32(
                self.__XOR(self.mt[i - 1], self.__SHR30(self.mt[i - 1])),
                1566083941
            )
        ) - i
        self.mt[i] = self.__AND(self.mt[i], 0xFFFFFFFF)
        i = i + 1
        if i >= self.__N then
            self.mt[0] = self.mt[self.__N-1]
            i = 1
        end
    end
    self.mt[0] = 0x80000000
end

--------------------------------------------------------------------------------
--- Generates a random integer in the [0,0xFFFFFFFF] interval
--- @return the generated number
--------------------------------------------------------------------------------
function mersenne_twister:genrand_int32()
    local y
    if self.mti >= self.__N then
        if self.mti == self.__N + 1 then
            self:init_genrand(5489)
        end
        for kk = 0, self.__N - self.__M - 1 do
            y = self.__OR(
                self.__AND(self.mt[kk], self.__UPPER_MASK),
                self.__AND(self.mt[kk + 1], self.__LOWER_MASK)
            )
            self.mt[kk] = self.__XOR(
                self.mt[kk + self.__M],
                self.__XOR(self.__SHR1(y), self.__BIT0(y) * self.__MATRIX_A)
            )
            kk=kk + 1
        end
        for kk = self.__N - self.__M, self.__N - 2 do
            y = self.__OR(
                self.__AND(self.mt[kk], self.__UPPER_MASK),
                self.__AND(self.mt[kk + 1], self.__LOWER_MASK)
            )
            self.mt[kk] = self.__XOR(
                self.mt[kk + (self.__M - self.__N)],
                self.__XOR(self.__SHR1(y), self.__BIT0(y) * self.__MATRIX_A)
            )
            kk=kk + 1
        end
        y = self.__OR(
            self.__AND(self.mt[self.__N - 1], self.__UPPER_MASK),
            self.__AND(self.mt[0], self.__LOWER_MASK)
        )
        self.mt[self.__N - 1] = self.__XOR(
            self.mt[self.__M - 1],
            self.__XOR(self.__SHR1(y), self.__BIT0(y) * self.__MATRIX_A)
        )
        self.mti = 0
    end
    y = self.mt[self.mti]
    self.mti = self.mti + 1
    y = self.__XOR(y, self.__SHR11(y))
    y = self.__XOR(y, self.__AND(self.__SHL7(y), 0x9D2C5680))
    y = self.__XOR(y, self.__AND(self.__SHL15(y), 0xEFC60000))
    y = self.__XOR(y, self.__SHR18(y))
    return y
end

--------------------------------------------------------------------------------
--- Generates a random integer in the [0,0x7FFFFFFF] interval
--- @return the generated number
--------------------------------------------------------------------------------
function mersenne_twister:genrand_int31()
    return math.floor(self:genrand_int32() / 2)
end

--------------------------------------------------------------------------------
--- Generates a random real number in the [0,1] interval
--- @return the generated number
--------------------------------------------------------------------------------
function mersenne_twister:genrand_real1()
    return self:genrand_int32() * (1.0/4294967295.0) -- divided by 2^32-1
end

--------------------------------------------------------------------------------
--- Generates a random real number in the [0,1) interval
--- @return the generated number
--------------------------------------------------------------------------------
function mersenne_twister:genrand_real2()
    return self:genrand_int32() * (1.0 / 4294967296.0) -- divided by 2^32
end

--------------------------------------------------------------------------------
--- Generates a random real number in the (0,1) interval
--- @return the generated number
--------------------------------------------------------------------------------
function mersenne_twister:genrand_real3()
    return (self:genrand_int32() + 0.5) * (1.0 / 4294967296.0) -- div by 2^32 
end

--------------------------------------------------------------------------------
--- Generates a random real number in the [0,1) interval with 53-bit resolution
--- @return the generated number
--------------------------------------------------------------------------------
function mersenne_twister:genrand_res53() 
    local a = math.floor(self:genrand_int32() / 32)
    local b = math.floor(self:genrand_int32() / 64)
        return (a * 67108864.0 + b) * (1.0 / 9007199254740992.0)
end

-- Update globals
_G.class     = class
_G.singleton = singleton
_G.table     = table
_G.math      = math
_G.string    = string
_G.env       = env
_G.color     = color
_G.ripairs   = ripairs
_G.date      = date
