# gamedevkit-lua

A library that extends the default Lua scope, providing new and useful methods geared towards game development. lncludes modified versions of:
* [Flower Library v3.0.1](https://github.com/makotok/Hanappe/tree/V3.0.1/projects/flower-library) (`class` definition; `math` and `table` extensions)
* [Lume Library v2.3.0](https://github.com/rxi/lume/tree/v2.3.0)
* [Date Library v2.1.2](https://github.com/Tieske/date/blob/version_2.1.2)
* [mt19937ar-lua](https://github.com/davebollinger/mt19937ar-lua/tree/9e110f2d1c8a981c1d4ffccb93e25aef9e8b5f17) (Mersenne Twister RNG)

## Installation

The [gamedevkit.lua](gamedevkit.lua?raw=1) file should be put into an existing project and required by it:

```lua
require('gamedevkit')
```

## OOP Examples

#### Class Inheritance
```lua
-- Our Base Class
local BaseClass = class()

function BaseClass:init()
    self.var1 = 1
    self.var2 = 2
    self.var3 = 3
end

-- A Class that extends BaseClass
local ExtendedClass = class(BaseClass)

function ExtendedClass:init()
    self.var2 = -2
end

-- A Class that extends ExtendedClass
local ThirdExtendedClass = class(ExtendedClass)

function ThirdExtendedClass:init(custom_var)
    self.var3 = custom_var or -3
end

-- Create an object
local obj = ThirdExtendedClass(5)
print(obj.var1) -- Prints 1
print(obj.var2) -- Prints -2
print(obj.var3) -- Prints 5
```

#### Singleton classes
```lua
-- A Singleton Class that extends BaseClass
local SingletonClass = singleton(BaseClass)

local obj1 = SingletonClass()
local obj2 = SingletonClass()

print(obj3 == obj4) -- Prints true
```

## table methods

#### table.copy(src [, dest])
Shallow copy the table `src` and return the new table. If a table `dest` is provided, the values are copied into it.
```lua
local t1 = {'test1', 'test2', 'test3', {'test4', 'test5'}}
local t2 = table.copy(t1)
```

#### table.deep_copy(src [, dest])
Deep copy the table `src` and return the new table. If a table `dest` is provided, the values are copied into it.
```lua
local t1 = {'test1', 'test2', 'test3', {'test4', 'test5'}}
local t2 = table.deep_copy(t1)
```

#### table.is_array(src)
Returns `true` if  table `src` is an array -- the value is assumed to be an array if it is a table which contains a value at the index 1.

#### table.find(src, value)
Returns the index/key found by searching for a matching `value` in the table `src`. If the `value` is not found, returns `nil`.
```lua
table.find({'test1', 'test2', 'test3'}, 'test2') -- Returns 2
```

#### table.push(src, ...)
Pushes all the given values to the end of the table and returns the pushed values. `nil` values are ignored.
```lua
local t1 = {1, 2, 3}
table.push(t1, 4, 5, 6)  -- t1 becomes {1, 2, 3, 4, 5, 6}
```

#### table.insert_if_absent(src, value)
Adds an element to the table `src` if and only if the `value` did not already exist. If it already exists, returns `false`. If not - returns `true`.
```lua
local t1 = {1, 2, 3}
table.insert_if_absent(t1, 4)  -- t1 becomes {1, 2, 3, 4}
table.insert_if_absent(t1, 4)  -- t1 remains unchanged
```

#### table.remove_element(src, value)
Removes the element `value` from the table `src`. If the element existed, then returns its index value. Otherwise, returns `nil`.
```lua
local t1 = {1, 2, 3}
table.remove_element(t1, 3)  -- t1 becomes {1, 2}
```

#### table.clear(src)
Sets all the values in the table `src` to `nil`. Returns the empty table.
```lua
local t1 = {1, 2, 3}
table.clear(t1)  -- t1 becomes {} (empty table)
```

#### table.extend(src, ...)
Copies all the fields from the source tables to the table `src` and returns it. If a key exists in multiple tables, the right-most table's value is used.
```lua
local t1 = {a = 1, b = 2}
table.extend(t1, {b = 4, c = 6}) -- t1 becomes {a = 1, b = 4, c = 6}
```

#### table.shuffle(src)
Returns a shuffled copy of the table `src`.
```lua
local t1 = {1, 2, 3}
t2 = table.shuffle(t1)
```

#### table.sorted(src [, comp])
Returns a copy of the table `src` with all its items sorted. If `comp` is a `function`, it will be used to compare the items when sorting. If `comp` is a `string`, it will be used as the key to sort the items by.
```lua
table.sorted({ 1, 4, 3, 2, 5 }) -- Returns { 1, 2, 3, 4, 5 }
table.sorted({ {z=2}, {z=3}, {z=1} }, 'z') -- Returns { {z = 1}, {z = 2}, {z = 3} }
table.sorted({ 1, 3, 2 }, function(a, b) return a > b end) -- Returns { 3, 2, 1 }
```

#### table.iterate(...)
Iterates the supplied iterator and returns an array filled with the values.
```lua
local t1 = table.iterate(string.gmatch('hello world', '%a+')) -- t1 becomes {'hello', 'world'}
```

#### table.each(src, fn, ...)
Iterates the table `src` and calls the function `fn` on each value followed by the supplied additional arguments. If `fn` is a string, the method of that name is called for each value. The function returns the table unmodified.
```lua
table.each({1, 2, 3}, print) -- Prints '1', '2', '3' on separate lines
table.each({a, b, c}, 'move', 10, 20) -- Does x:move(10, 20) on each value
```

#### table.map(src, fn)
Applies the function `fn` to each value in the table `src` and returns a new table with the resulting values.
```lua
local t1 = table.map({1, 2, 3}, function(x) return x * 2 end) -- t1 becomes {2, 4, 6}
```

#### table.all(src [, fn])
Returns `true` if all the values in table `src` are `true`. If a function `fn` is supplied, it is called on each value, `true` is returned if all of the calls to `fn` return `true`.
```lua
table.all({1, 2, 1}, function(x) return x == 1 end) -- Returns false
```

#### table.any(src [, fn])
Returns `true` if any of the values in table `src` are `true`. If a function `fn` is supplied, it is called on each value, `true` is returned if any of the calls to `fn` return `true`.
```lua
table.any({1, 2, 1}, function(x) return x == 1 end) -- Returns true
```

#### table.reduce(src, fn [, first])
Applies the function `fn` on two arguments cumulative to the items of the table `src` from left to right, so as to reduce it to a single value. If a `first` value is specified, the accumulator is initialised to this, otherwise the first value of the table is used. If the table is empty and no `first` value is specified, an error is raised.
```lua
table.reduce({1, 2, 3}, function(a, b) return a + b end, 3) -- Returns 9
```

#### table.unique(src)
Returns a copy of the table `src` with all the duplicate values removed.
```lua
table.unique({2, 1, 2, 'cat', 'cat'}) -- Returns {1, 2, 'cat'}
```

#### table.filter(src, fn [, retainkeys])
Calls `fn` on each value of table `src`. Returns a new table with only the values where `fn` returned `true`. If `retainkeys` is `true`, the table is not treated as an array and retains its original keys.
```lua
table.filter({1, 2, 3, 4}, function(x) return x % 2 == 0 end) -- Returns {2, 4}
```

#### table.reject(src, fn [, retainkeys])
The opposite of `table.filter()`: Calls `fn` on each value of table `src`; returns a new table with only the values where `fn` returned `false`. If `retainkeys` is`true`, the table is not treated as an array and retains its original keys.
```lua
table.reject({1, 2, 3, 4}, function(x) return x % 2 == 0 end) -- Returns {1, 3}
```

#### table.merge(...)
Returns a new table with all the given tables merged together. If a key exists in multiple tables, the right-most table's value is used.
```lua
table.merge({a = 1, b = 2, c = 3}, {c = 8, d = 9}) -- Returns {a = 1, b = 2, c = 8, d = 9}
```

#### table.concat_all(...)
Returns a new table consisting of all the given tables concatenated into one.
```lua
table.concat_all({1, 2}, {3, 4}, {5, 6}) -- Returns {1, 2, 3, 4, 5, 6}
```

#### table.match(src, fn)
Returns the value and key of the value in table `src`, if it returns `true` when the function `fn` is called on it. Returns `nil` if no such value exists.
```lua
table.match({1, 5, 8, 7}, function(x) return x % 2 == 0 end) -- Returns 8, 3
```

#### table.count(src [, fn])
Counts the number of values in the table `src`. If a function `fn` is supplied, it is called on each value, and the number of times it returns `true` is counted.
```lua
table.count({a = 2, b = 3, c = 4, d = 5}) -- Returns 4
table.count({1, 2, 4, 6}, function(x) return x % 2 == 0 end) -- Returns 3
```

#### table.slice(src [, i [, j]])
Mimics the behaviour of Lua's `string.sub`, but operates on a table rather than a string. Creates and returns a new table of the given slice.
```lua
table.slice({'a', 'b', 'c', 'd', 'e'}, 2, 4) -- Returns {'b', 'c', 'd'}
```

#### table.first(src [, n])
Returns the first element of the table `src`, or `nil` if the table is empty. If `n` is specificed, a table of the first `n` elements is returned.
```lua
table.first({'a', 'b', 'c'}) -- Returns 'a'
```

#### table.last(src [, n])
Returns the last element of a the table `src`, or`nil` if the table is empty. If `n` is specificed, a table of the last `n` elements is returned.
```lua
table.last({'a', 'b', 'c'}) -- Returns 'c'
```

#### table.invert(src)
Returns a copy of the table `src` where the keys have become the values, and the values - the keys.
```lua
table.invert({a = 'x', b = 'y'}) -- returns {x = 'a', y = 'b'}
```

#### table.pick(src, ...)
Returns a copy of the table `src` filtered to only contain values for the given keys.
```lua
table.pick({a = 1, b = 2, c = 3}, 'a', 'c') -- Returns {a = 1, c = 3}
```

#### table.keys(src)
Returns a copy of the table `src` filtered to only contain values for the given keys.
```lua
table.keys({a = 1, b = 2, c = 3}) -- Returns {'a', 'b', 'c'}
```

#### table.print(src)
Prints the table `src` recursively.

## math methods

#### math.average(...)
Returns the average of the given values.
```lua
math.average(1, 2, 3, 4, 5, 6, 7) -- Returns 4
```

#### math.sum(...)
Returns the sum of the given values.
```lua
math.sum(1, 2, 3, 4, 5, 6, 7) -- Returns 28
```

#### math.clamp(x, min, max)
Returns the number `x` clamped between the numbers `min` and `max`.
```lua
math.clamp(5, 2, 4) -- Returns 4
```

#### math.whole(x)
Removes the decimal part of the number `x` and returns it.
```lua
math.whole(1.567) -- Returns 1
```

#### math.round(x [, increment])
Rounds the number `x` to the nearest integer; rounds away from zero if we're midway between two integers. If `increment` is set, then the number is rounded to the nearest increment.
```lua
math.round(2.3) -- Returns 2
math.round(123.4567, .1) -- Returns 123.5
```

#### math.sign(x)
Returns `1` if the number `x` is `0` or above, returns `-1` when `x` is negative.
```lua
math.sign(5) -- Returns 1
math.sign(-5) -- Returns -1
```

#### math.lerp(a, b, amount)
Returns the linearly interpolated number between `a` and `b`. `amount` should be in the range of [0, 1]; if `amount` is outside of this range, it is clamped.
```lua
math.lerp(100, 200, .6) -- Returns 160
```

#### math.smooth(a, b, amount)
Similar to `math.lerp()`, but uses cubic interpolation instead of linear interpolation.
```lua
math.smooth(100, 200, .6) -- Returns 164.8
```

#### math.pingpong(x)
Ping-pongs the number `x` between 0 and 1.
```lua
math.pingpong(2) -- Returns 0
math.pingpong(7) -- Returns 1
```

#### math.distance(x0, y0, x1, y1 [, squared])
Returns the distance between the two points. If `squared` is `true`, then the squared distance is returned -- this is faster to calculate and can still be used when comparing distances.
```lua
math.distance(1, 1, 7, 14) -- Returns 14.317821063276
math.distance(1, 1, 4, 5, true) -- Returns 25
```

#### math.normalize(x, y)
Returns the normal vector for a point.
```lua
math.normalize(6, 7) -- Returns 0.65079137345597, 0.7592566023653
```

#### math.angle(x0, y0, x1, y1)
Returns the angle between the two points.
```lua
math.deg(math.angle(0, 4, 4, 0)) -- Returns -45
```

#### math.vector(angle, magnitude)
Given an `angle` and `magnitude`, returns a vector.
```lua
math.vector(math.pi / 4, 100) -- Returns 70.710678118655, 70.710678118655
```

## math randomization methods

#### math.randomseed(...)
Mimics the behaviour of Lua's `math.randomseed`, but uses the implementation of the mersenne twister instead.

#### math.random(...)
Mimics the behaviour of Lua's `math.random`, but uses the implementation of the mersenne twister instead.

#### math.random_number([a [, b]])
 Returns a random number between `a` and `b`. If only `a` is supplied, a number between `0` and `a` is returned. If no arguments are supplied, a random number between `0` and `1` is returned.

#### math.random_choice(src)
Returns a random value from the table `src`. If the table is empty, an error is raised.
```lua
math.random_choice({true, false}) -- Returns either true or false
```

#### math.weighted_choice(src)
Takes the argument table `src` where the keys are the possible choices and the value is the choice's weight. A weight should be `0` or above, the larger the number - the higher the probability of that choice being picked. If the table is empty, a weight is below `0`, or all the weights are `0`, then an error is raised.
```lua
-- Returns either 'cat' or 'dog', with 'cat' being twice as likely to be chosen.
math.weightedchoice({ ['cat'] = 10, ['dog'] = 5, ['frog'] = 0 })
```

## string methods

#### string.split(str [, sep])
Returns an array of the words in the string `str`. If `sep` is provided, it is used as the delimiter, consecutive delimiters are not grouped together and will delimit empty strings.
```lua
string.split('One two three') -- Returns {'One', 'two', 'three'}
string.split('a,b,,c', ',') -- Returns {'a', 'b', '', 'c'}
```

#### string.trim(str [, chars])
Trims the whitespace from the start and end of the string `str` and returns the new string. If a `chars` value is set, the characters in `chars` are trimmed instead of whitespace.
```lua
string.trim('  Hello  ') -- Returns 'Hello'
```

#### string.wordwrap(str [, limit])
Returns `str` wrapped to `limit` number of characters per line, by default `limit` is `72`. `limit` can also be a function which when passed a string, returns `true` if it is too long for a single line.
```lua
-- Returns 'Hello world\nThis is a\nshort string.'
string.wordwrap('Hello world. This is a short string.', 14)
```

#### string.formatted(str [, vars])
Returns a formatted string. The values of keys in the table `vars` can be inserted into the string by using the form `'{key}'` in `str`; numerical keys can also be used.
```lua
string.formatted('{b} hi {a}', {a = 'mark', b = 'Oh'}) -- Returns 'Oh hi mark'
string.formatted('Hello {1}!', {'world'}) -- Returns 'Hello world!'
```

#### string.uuid()
Generates a random UUID string; version 4 as specified in [RFC 4122](http://www.ietf.org/rfc/rfc4122.txt).

#### string.natural_number(num [, shorten_mil])
Convert a large number into a human-readable string. If `shorten_mil` is `true`, it will convert the numbers above one million as shortened float numbers.
```lua
string.natural_number(123456) -- Returns '123,456'
string.natural_number(123456789.5) -- Returns '123,456,789.5'
string.natural_number(123456789, true) -- Returns '123.5M'
```

#### string.pluralize(str, number, one, many)
Returns a pluralized string using `string.format` based on the value of `number`.
```lua
string.pluralize('single %s', 1, 'one', 'ones') -- Returns 'single one'
string.pluralize('multiple %s', 5, 'one', 'ones') -- Returns 'multiple ones'
```

#### string.as_table(str)
Converts a string `str` to a table containing each chararacter.
```lua
sstring.as_table('abc') -- Returns {'a', 'b', 'c'}
```

## env methods

#### env.wrap_fn(fn, ...)
Creates a wrapper function around the function `fn`, automatically inserting the arguments into `fn` which will persist every time the wrapper is called. Any arguments which are passed to the returned function will be inserted after the already existing arguments passed to `fn`.
```lua
local f1 = env.wrap_fn(print, 'Hello')
local f2 = env.wrap_fn(function(a, b) return a + b end, 5)
f1('world') -- Prints 'Hello world'
f2(7) -- Returns 12
```

#### env.once(fn, ...)
Returns a wrapper function to `fn` which takes the supplied arguments. The wrapper function will call `fn` on the first call and do nothing on any subsequent calls.
```lua
local f1 = env.once(print, 'Hello')
f1() -- Prints 'Hello'
f1() -- Does nothing
```

#### env.memoize(fn)
Returns a wrapper function to `fn` where the results for any given set of arguments are cached. `env.memoize()` is useful when used on functions with slow-running computations.
```lua
fib = env.memoize(function(n) return n < 2 and n or fib(n - 1) + fib(n - 2) end)
fib(10) -- Returns 55
```

#### env.combine(...)
Creates a wrapper function which calls each supplied argument in the order they were passed to `env.combine()`; `nil` arguments are ignored. The wrapper function passes its own arguments to each of its wrapped functions when it is called.
```lua
local f = env.combine(function(a, b) print(a + b) end, function(a, b) print(a * b) end)
f(3, 4) -- Prints '7', then '12' on a new line
```

#### env.call(fn, ...)
Calls the given function `fn` with the provided arguments and returns its values. If `fn` is `nil`, then no action is performed and the function returns `nil`.
```lua
env.call(print, 'Hello world') -- Prints 'Hello world'
```

#### env.timed(fn, ...)
Inserts the arguments into function `fn` and calls it. Returns the time in seconds the function `fn` took to execute, followed by `fn`'s returned values.
```lua
env.timed(function(x) return x end, 'hello') -- Returns 0, 'hello'
```

#### env.lambda(str)
Takes a string lambda and returns a function. `str` should be a list of comma-separated parameters, followed by `->`, followed by the expression which will be evaluated and returned.
```lua
local f1 = env.lambda('x,y -> 2*x+y')
f1(10, 5) -- Returns 25
```

#### env.serialize(x)
Serializes the argument `x` into a string which can be loaded again using `env.deserialize()`. Only booleans, numbers, tables and strings can be serialized. Circular references will result in an error; all nested tables are serialized as unique tables.
```lua
env.serialize({a = 'test', b = {1, 2, 3}, false})
-- Returns '{[1]=false,["a"]="test",["b"]={[1]=1,[2]=2,[3]=3,},}'
```

#### env.deserialize(str)
Deserializes a string created by `env.serialize()` and returns the resulting value. This function should not be run on an untrusted string.
```lua
env.deserialize('{1, 2, 3}') -- Returns {1, 2, 3}
```

#### env.dostring(str)
Executes the lua code inside the `str`.
```lua
env.dostring('print("Hello!")') -- Prints 'Hello!'
```

#### env.trace(...)
Prints the current filename and line number followed by each argument separated by a space.
```lua
-- Assuming the file is called 'example.lua' and the next line is 12:
env.trace('hello', 1234) -- Prints 'example.lua:12: hello 1234'
```

#### env.hotswap(modname)
Reloads an already loaded module in place, allowing you to immediately see the effects of code changes without having to restart the program. `modname` should be the same string used when loading the module with require(). In the case of an error, the global environment is restored and `nil` plus an error message is returned.
```lua
env.hotswap('gamedevkit') -- Reloads the gamedevkit-lua module
assert(env.hotswap('inexistant_module')) -- Raises an error
```

## ripairs function
Performs the same function as `ipairs()` but iterates in reverse; this allows the removal of items from the table during iteration without any items being skipped.
```lua
-- Prints '3->c', '2->b', and '1->a' on separate lines
for i, v in ripairs({ 'a', 'b', 'c' }) do
    print(i .. '->' .. v)
end
```

## color function
Takes color string `str` and returns 4 values, one for each color channel (`r`, `g`, `b` and `a`). By default the returned values are between 0 and 1; the values are multiplied by the number `mul`, if it is provided.
```lua
color('#ff0000')               -- Returns 1, 0, 0, 1
color('rgba(255, 0, 255, .5)') -- Returns 1, 0, 1, .5
color('#00ffff', 256)          -- Returns 0, 256, 256, 256
color('rgb(255, 0, 0)', 256)   -- Returns 256, 0, 0, 256
```

## date module
Provides full implementation of the Date library by [Tieske](https://github.com/Tieske). For full list of examples, see [this page](http://tieske.github.io/date/).
```lua
local d1 = date('Jul 27 2006 03:56:28 +2:00')
local d2 = date(d1):adddays(3)
local date_diff = date.diff(d2, d1)
print(date_diff:spandays()) -- Prints 3
```