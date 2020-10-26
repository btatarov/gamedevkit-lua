require('gamedevkit')

math.randomseed(1234) -- start with a known state

env.trace('(done) env.trace')

-- OOP tests
local BaseClass = class()
function BaseClass:init() self.var1 = 1; self.var2 = 2; self.var3 = 3 end
local ExtendedClass = class(BaseClass)
function ExtendedClass:init() self.var2 = -2 end
local ThirdExtendedClass = class(ExtendedClass)
function ThirdExtendedClass:init() self.var1 = -1 end
local AnotherBaseClass = class()
local SingletonClass1 = singleton(ExtendedClass)
local SingletonClass2 = singleton(ExtendedClass)
local obj1 = BaseClass()
local obj2 = ThirdExtendedClass()
local obj3 = SingletonClass1()
local obj4 = SingletonClass1()
local obj5 = SingletonClass2()

assert(obj2:instance_of(ThirdExtendedClass), 'error in class_obj:instance_of(class)')
assert(obj2:instance_of(ExtendedClass), 'error in class_obj:instance_of(super class)')
assert(obj2:instance_of(BaseClass), 'error in class_obj:instance_of(deeper class)')
assert(not obj2:instance_of(AnotherBaseClass), 'error in class_obj:instance_of(different class)')
env.trace('(done) class inheritance')
assert(obj1.var1 == 1 and obj1.var2 == 2 and obj1.var3 == 3 and obj2.var1 == -1 and obj2.var2 == -2 and obj2.var3 == 3, 'error in class.init'); env.trace('(done) class.init')
assert(obj3 == obj4, 'error in singleton single instance'); env.trace('(done) singleton single instance')
assert(obj4 ~= obj5, 'error in similar singletons instances'); env.trace('(done) similar singletons instances')
assert(obj3:instance_of(SingletonClass1), 'error in singleton_obj:instance_of(singleton class)')
assert(obj3:instance_of(ExtendedClass), 'error in singleton_obj:instance_of(super)')
assert(obj3:instance_of(BaseClass), 'error in singleton_obj:instance_of(super -> deeper)')
assert(not obj3:instance_of(AnotherBaseClass), 'error in singleton_obj:instance_of(different class)')
env.trace('(done) singleton inheritance')

-- table tests
local tbl1 = {'test1', 'test2', 'test3', {'test4', 'test5'}}
local tbl2
local tbl3 = {}
local tbl4 = {1, 2, 3, 4}
local tbl5 = {test1 = 1, test2 = 2}
local tbl6
local r1, r2

tbl2 = table.copy(tbl1)
for i = 1, 4 do
    assert(tbl1[i] == tbl2[i], 'error in table.copy')
end
env.trace('(done) table.copy')
table.deep_copy(tbl1, tbl3)
for i = 1, 3 do
    assert(tbl1[i] == tbl3[i], 'error in table.deep_copy')
end
assert(tbl1[4] ~= tbl3[4], 'error in table.deep_copy')
for i = 1, 2 do
    assert(tbl1[4][i] == tbl3[4][i], 'error in table.deep_copy')
end
env.trace('(done) table.deep_copy')
assert(table.is_array(tbl4) and not table.is_array(tbl5), 'error in table.is_array'); env.trace('(done) table.is_array')
assert(table.find(tbl1, 'test3') == 3, 'error in table.find'); env.trace('(done) table.find')
table.push(tbl1, 'test6'); assert(tbl1[5] == 'test6', 'error in table.push'); env.trace('(done) table.push')
assert(not table.insert_if_absent(tbl1, 'test6') and #tbl1 == 5 and table.insert_if_absent(tbl1, 'test7') and #tbl1 == 6 and tbl1[6] == 'test7', 'error in table.insert_if_absent'); env.trace('(done) table.insert_if_absent')
assert(table.remove_element(tbl1, 'test7') == 6 and table.remove_element(tbl1, 'test7') == nil and #tbl1 == 5, 'error in table.remove_element'); env.trace('(done) table.remove_element')
assert(#table.clear(tbl3) == 0 and #tbl3 == 0, 'error in table.clear'); env.trace('(done) table.clear')
table.extend(tbl1, tbl4); assert(tbl1[1] == tbl4[1] and tbl1[2] == tbl4[2] and tbl1[3] == tbl4[3] and tbl1[4] == tbl4[4] and tbl1[5] == 'test6', 'error in table.extend'); env.trace('(done) table.extend')
tbl6 = table.shuffle(tbl1); assert(tbl6[1] == tbl1[3] and tbl6[2] == tbl1[5] and tbl6[3] == tbl1[1] and tbl6[4] == tbl1[2] and tbl6[5] == tbl1[4], 'error in table.shuffle'); env.trace('(done) table.shuffle')
tbl6 = table.sorted({4, 3, 1, 2}); assert(tbl6[1] == 1 and tbl6[2] == 2 and tbl6[3] == 3 and tbl6[4] == 4, 'error in table.sorted'); env.trace('(done) table.sorted')
tbl6 = table.sorted({4, 3, 1, 2}, function(a, b) return a > b end); assert(tbl6[1] == 4 and tbl6[2] == 3 and tbl6[3] == 2 and tbl6[4] == 1, 'error in table.sorted(custom cmp func)'); env.trace('(done) table.sorted(custom cmp func)')
tbl6 = table.iterate(string.gmatch('hello world', '%a+')); assert(tbl6[1] == 'hello' and tbl6[2] == 'world', 'error in table.iterate'); env.trace('(done) table.iterate')
table.clear(tbl6); table.each({1, 2, 3}, function(v, mul) table.push(tbl6, v * mul) end, 10); assert(tbl6[1] == 10 and tbl6[2] == 20 and tbl6[3] == 30, 'error in table.each'); env.trace('(done) table.each')
tbl6 = table.map({1, 2, 3}, function(v) return v * 20 end); assert(tbl6[1] == 20 and tbl6[2] == 40 and tbl6[3] == 60, 'error in table.map'); env.trace('(done) table.map')
assert(table.all({3, 6, 9}, function(v) return v % 3 == 0 end) and not table.all({3, 6, 9}, function(v) return v % 2 == 1 end), 'error in table.all'); env.trace('(done) table.all')
assert(table.any({3, 6, 9}, function(v) return v % 3 == 0 end) and table.any({3, 6, 9}, function(v) return v % 2 == 0 end), 'error in table.any'); env.trace('(done) table.any')
assert(table.reduce({1, 2, 3, 4}, function(a, b) return a + b end, 3) == 13, 'error in table.reduce'); env.trace('(done) table.reduce')
tbl6 = table.unique({2, 1, 2, 'cat', 'cat'}); assert(#tbl6 == 3 and tbl6[1] == 1 and tbl6[2] == 2 and tbl6[3] == 'cat', 'error in table.unique'); env.trace('(done) table.unique')
tbl6 = table.filter({1, 2, 3, 4}, function(v) return v % 2 == 0 end); assert(#tbl6 == 2 and tbl6[1] == 2 and tbl6[2] == 4, 'error in table.filter'); env.trace('(done) table.filter')
tbl6 = table.reject({1, 2, 3, 4}, function(v) return v % 2 == 0 end); assert(#tbl6 == 2 and tbl6[1] == 1 and tbl6[2] == 3, 'error in table.reject'); env.trace('(done) table.reject')
tbl6 = table.merge({a = 1, b = 2, c = 3}, {c = 8, d = 9}); assert(tbl6.a == 1 and tbl6.b == 2 and tbl6.c == 8 and tbl6.d == 9, 'error in table.merge'); env.trace('(done) table.merge')
tbl6 = table.concat_all({1, 2}, {3, 4}, {5, 6}); assert(tbl6[1] == 1 and tbl6[2] == 2 and tbl6[3] == 3 and tbl6[4] == 4 and tbl6[5] == 5 and tbl6[6] == 6, 'error in table.concat_all'); env.trace('(done) table.concat_all')
r1, r2 = table.match({3, 5, 8, 9}, function(v) return v % 4 == 0 end) assert(r1 == 8 and r2 == 3, 'error in table.match'); env.trace('(done) table.match')
assert(table.count({a = 2, b = 3, c = 4, d = 5}) == 4, 'error in table.count'); env.trace('(done) table.count')
assert(table.count({1, 2, 4, 6}, function(x) return x % 2 == 0 end) == 3, 'error in table.count(custom cmp func)'); env.trace('(done) table.count(custom cmp func)')
tbl6 = table.slice({'a', 'b', 'c', 'd', 'e'}, 2, 4); assert(#tbl6 == 3 and tbl6[1] == 'b' and tbl6[2] == 'c' and tbl6[3] == 'd', 'error in table.slice'); env.trace('(done) table.slice')
assert(table.first({'b', 'c', 'd'}) == 'b', 'error in table.first'); env.trace('(done) table.first')
assert(table.last({'b', 'c', 'd'}) == 'd', 'error in table.last'); env.trace('(done) table.last')
tbl6 = table.invert({a = 'x', b = 'y'}); assert(tbl6.x == 'a' and tbl6.y == 'b', 'error in table.invert'); env.trace('(done) table.invert')
tbl6 = table.pick({ a = 1, b = 2, c = 3 }, 'a', 'c'); assert(tbl6.a == 1 and tbl6.b == nil and tbl6.c == 3, 'error in table.pick'); env.trace('(done) table.pick')
tbl6 = table.sorted(table.keys({ a = 1, b = 2, c = 3 })); assert(#tbl6 == 3 and tbl6[1] == 'a' and tbl6[2] == 'b' and tbl6[3] == 'c', 'error in table.keys'); env.trace('(done) table.keys')

-- math tests
local r1, r2
assert(math.average(1, 2, 3, 4, 5, 6, 7) == 4, 'error in math.average'); env.trace('(done) math.average')
assert(math.sum(1, 2, 3, 4, 5, 6, 7) == 28, 'error in math.sum'); env.trace('(done) math.sum')
assert(math.clamp(5, 2, 4) == 4 and math.clamp(1, 2, 4) == 2, 'error in math.clamp'); env.trace('(done) math.clamp')
assert(math.whole(1.567) == 1 and math.whole(-1.567) == -1, 'error in math.whole'); env.trace('(done) math.whole')
assert(math.round(1.567) == 2 and math.round(1.567, .1) == 1.6 and math.round(-1.567, .01) == -1.57, 'error in math.round'); env.trace('(done) math.round')
assert(math.sign(5) == 1 and math.sign(-5) == -1, 'error in math.sign'); env.trace('(done) math.sign')
assert(math.lerp(100, 200, .6) == 160, 'error in math.lerp'); env.trace('(done) math.lerp')
assert(math.smooth(100, 200, .6) == 164.8, 'error in math.smooth'); env.trace('(done) math.smooth')
assert(math.pingpong(2) == 0 and math.pingpong(7) == 1, 'error in math.pingpong'); env.trace('(done) math.pingpong')
assert(math.floor(math.distance(1, 1, 7, 14)) == 14, 'error in math.distance'); env.trace('(done) math.distance')
assert(math.distance(1, 1, 4, 5, true) == 25, 'error in math.distance(squared)'); env.trace('(done) math.distance(squared)')
r1, r2 = math.normalize(6, 7); assert(math.round(r1, .01) == 0.65 and math.round(r2, .01) == 0.76, 'error in math.normalize'); env.trace('(done) math.normalize')
assert(math.deg(math.angle(0, 4, 4, 0)) == -45, 'error in math.angle'); env.trace('(done) math.angle')
r1, r2 = math.vector(math.angle(0, 4, 4, 0), 100); assert(math.round(r1, .1) == 70.7 and math.round(r2, .1) == -70.7, 'error in math.vector'); env.trace('(done) math.vector')

-- string tests
local tbl1
tbl1 = string.split(' hello   world '); assert(#tbl1 == 2 and tbl1[1] == 'hello' and tbl1[2] == 'world', 'error in string.split'); env.trace('(done) string.split')
tbl1 = string.split('hello|world', '|'); assert(#tbl1 == 2 and tbl1[1] == 'hello' and tbl1[2] == 'world', 'error in string.split(separator)'); env.trace('(done) string.split(separator)')
assert(string.trim('  hello   ') == 'hello', 'error in string.trim'); env.trace('(done) string.trim')
assert(string.wordwrap('Hello world. This is a short string.', 14) == 'Hello world. \nThis is a \nshort string.', 'error in string.wordwrap'); env.trace('(done) string.wordwrap')
assert(string.formatted('{b} hi {a}', {a = 'mark', b = 'Oh'}) == 'Oh hi mark' and string.formatted('Hello {1}!', {'world'}) == 'Hello world!', 'error in string.formatted'); env.trace('(done) string.formatted')
assert(string.uuid() == '489f179a-ebec-4ca6-a80c-509f6ef20bc5', 'error in string.uuid'); env.trace('(done) string.uuid')
assert(string.natural_number(123456) == '123,456', 'error in string.natural_number(integer)'); env.trace('(done) string.natural_number(integer)')
assert(string.natural_number(123456789.5) == '123,456,789.5', 'error in string.natural_number(float)'); env.trace('(done) string.natural_number(float)')
assert(string.natural_number(123456789, true) == '123.5M', 'error in string.natural_number(integer, shorten_millions)'); env.trace('(done) string.natural_number(integer, shorten_millions)')
assert(string.pluralize('single %s', 1, 'one', 'ones') == 'single one', 'error in string.pluralize(single)') env.trace('(done) string.pluralize(single)')
assert(string.pluralize('multiple %s', 5, 'one', 'ones') == 'multiple ones', 'error in string.pluralize(many)') env.trace('(done) string.pluralize(many)')
tbl1 = string.as_table('abc'); assert(#tbl1 == 3 and tbl1[1] == 'a' and tbl1[2] == 'b' and tbl1[3] == 'c', 'error in string.as_table'); env.trace('(done) string.as_table')

-- env tests
local fn1
local tbl1 = {}
local r1, r2
local f1
assert(env.wrap_fn(function(a, b) return a + b end, 5)(7) == 12, 'error in env.wrap_fn') env.trace('(done) env.wrap_fn')
fn1 = env.once(function(a) return a * 2 end, 5); assert(fn1() == 10 and fn1() == nil, 'error in env.once') env.trace('(done) env.once')
fn1 = env.memoize(function(n) return n < 2 and n or fn1(n-1) + fn1(n-2) end); assert(fn1(10) == 55, 'error in env.memoize') env.trace('(done) env.memoize')
env.combine(function(a, b) table.push(tbl1, a + b) end, function(a, b) table.push(tbl1, a * b) end)(3, 4); assert(#tbl1 == 2 and tbl1[1] == 7 and tbl1[2] == 12, 'error in env.combine') env.trace('(done) env.combine')
assert(env.call(function(a, b) return a + b end, 3, 4) == 7, 'error in env.call') env.trace('(done) env.call')
r1, r2 = env.timed(function(v) local t0 = os.clock(); while os.clock() - t0 <= 0.1 do end; return v end, 'hello'); assert(r1 >= 0.1 and r2 == 'hello', 'error in env.timed') env.trace('(done) env.timed')
assert(env.lambda('x,y -> 2*x+y')(10, 5) == 25, 'error in env.lambda') env.trace('(done) env.lambda')
assert(env.serialize({a = 'test', b = {1, 2, 3}, false}) == '{[1]=false,["a"]="test",["b"]={[1]=1,[2]=2,[3]=3}}', 'error in env.serialize') env.trace('(done) env.serialize')
tbl1 = env.deserialize('{1, 2, 3}'); assert(#tbl1 == 3 and tbl1[1] == 1 and tbl1[2] == 2 and tbl1[3] == 3, 'error in env.deserialize') env.trace('(done) env.deserialize')
local f1 = io.open('hotswap.lua', 'wb'); f1:write('hotswapped = 1'); f1:close(); require('hotswap'); r1 = hotswapped
local f1 = io.open('hotswap.lua', 'wb'); f1:write('hotswapped = 2'); f1:close(); env.hotswap('hotswap'); r2 = hotswapped
os.remove('hotswap.lua'); hotswapped = nil
assert(r1 == 1 and r2 == 2, 'error in env.hotswap') env.trace('(done) env.hotswap')

-- ripairs test
local tbl1 = {}
for i, v in ripairs({'a', 'b', 'c'}) do
    table.push(tbl1, {i, v})
end
assert(tbl1[1][1] == 3 and tbl1[1][2] == 'c' and tbl1[2][1] == 2 and tbl1[2][2] == 'b' and tbl1[3][1] == 1 and tbl1[3][2] == 'a', 'error in ripairs') env.trace('(done) ripairs')

-- color tests
local r, g, b, a
r, g, b, a = color('#ff0000'); assert(r == 1 and g == 0 and b == 0 and a == 1, 'error in color(#xxxxxx)') env.trace('(done) color(#xxxxxx)')
r, g, b, a = color('rgba(255, 0, 255, .5)'); assert(r == 1 and g == 0 and b == 1 and a == 0.5, 'error in color(rgba())') env.trace('(done) color(rgba())')
r, g, b, a = color('#00ffff', 255); assert(r == 0 and g == 255 and b == 255 and a == 255, 'error in color(#xxxxxx, mul)') env.trace('(done) color(#xxxxxx, mul)')
r, g, b, a = color('rgb(255, 0, 0)', 255); assert(r == 255 and g == 0 and b == 0 and a == 255, 'error in color(rgb(), mul)') env.trace('(done) color(rgb(), mul)')

-- date tests
local a, b, c, d, h, m, s, t, y
local expected_dates = {
    'Friday, October 13 2000',
    'Friday, April 13 2001',
    'Friday, July 13 2001',
    'Friday, September 13 2002',
    'Friday, December 13 2002',
    'Friday, June 13 2003',
    'Friday, February 13 2004',
    'Friday, August 13 2004',
    'Friday, May 13 2005',
    'Friday, January 13 2006',
    'Friday, October 13 2006',
    'Friday, April 13 2007',
    'Friday, July 13 2007',
    'Friday, June 13 2008',
    'Friday, February 13 2009',
    'Friday, March 13 2009',
    'Friday, November 13 2009',
    'Friday, August 13 2010',
}
local dates = {}
for i = 2000, 2010 do
    x = date(i, 1, 1)
    for j = 1, 12 do
        if x:setmonth(j, 13):getweekday() == 6 then
            table.push(dates, x:fmt('%A, %B %d %Y'))
        end
    end
end
for i = 1, #dates do
    assert(dates[i] == expected_dates[i], 'error in date(Y, m, d)')
end
env.trace('(done) date(Y, m, d)')
assert(date.diff('Jan 7 1563', date(1563, 1, 2)):spandays() == 5, 'error in date.diff'); env.trace('(done) date.diff')
assert(date.epoch() == date('jan 1 1970'), 'error in date.epoch'); env.trace('(done) date.epoch')
assert(date.isleapyear(date(1776, 1, 1)) and date.isleapyear(date(1776, 1, 1):getyear()) and date.isleapyear(1776), 'error in date.isleapyear'); env.trace('(done) date.isleapyear')
dates = {}
table.insert(dates, {date('Jul 27 2006 03:56:28 +2:00'), date(2006,07,27,1,56,28)})
table.insert(dates, {date('Jul 27 2006 -75 '), date(2006,07,27,1,15,0)})
table.insert(dates, {date('Jul 27 2006 -115'), date(2006,07,27,1,15,0)})
table.insert(dates, {date('Jul 27 2006 +10 '), date(2006,07,26,14,0,0)})
table.insert(dates, {date('Jul 27 2006 +2  '), date(2006,07,26,22,0,0)})
table.insert(dates, {date('Jul 27 2006 GMT'), date(2006,07,27,0,0,0)})
table.insert(dates, {date('Jul 27 2006 UTC'), date(2006,07,27,0,0,0)})
table.insert(dates, {date('Jul 27 2006 EST'), date(2006,07,27,5,0,0)})
table.insert(dates, {date('Jul 27 2006 EDT'), date(2006,07,27,4,0,0)})
table.insert(dates, {date('Jul 27 2006 CST'), date(2006,07,27,6,0,0)})
table.insert(dates, {date('Jul 27 2006 CDT'), date(2006,07,27,5,0,0)})
table.insert(dates, {date('Jul 27 2006 MST'), date(2006,07,27,7,0,0)})
table.insert(dates, {date('Jul 27 2006 MDT'), date(2006,07,27,6,0,0)})
table.insert(dates, {date('Jul 27 2006 PST'), date(2006,07,27,8,0,0)})
table.insert(dates, {date('Jul 27 2006 PDT'), date(2006,07,27,7,0,0)})
table.insert(dates, {date('02-03-04'), date(1904,02,03)})
table.insert(dates, {date('12/25/98'), date(1998,12,25)})
table.insert(dates, {date('Feb-03-04'), date(1904,02,03)})
table.insert(dates, {date('December 25 1998'), date(1998,12,25)})
table.insert(dates, {date('Feb 3 0003 BC'), date(-2,02,03)})
table.insert(dates, {date('December 25 0001 BC'), date(0,12,25)})
table.insert(dates, {date('2000-12-31'), date(2000,12,31)})
table.insert(dates, {date(' 20001231 '), date(2000,12,31)})
table.insert(dates, {date('1995-035'), date(1995,02,04)})
table.insert(dates, {date('1995035 '), date(1995,02,04)})
table.insert(dates, {date('1997-W01-1'), date(1996,12,30)})
table.insert(dates, {date('  1997W017'), date(1997,01,05)})
table.insert(dates, {date('1995-02-04 24:00:51.536'), date(1995,2,5,0,0,51.536)})
table.insert(dates, {date('1976-W01-1 12:12:12.123'), date(1975,12,29,12,12,12.123)})
table.insert(dates, {date('1995-035 23:59:59.99999'), date(1995,02,04,23,59,59.99999)})
table.insert(dates, {date('  19950205T000051.536  '), date(1995,2,5,0,0,51.536)})
table.insert(dates, {date('  1976W011T121212.123  '), date(1975,12,29,12,12,12.123)})
table.insert(dates, {date(' 1995035T235959.99999  '), date(1995,02,04,23,59,59.99999)})
table.insert(dates, {date('1976-W01-1 12:00Z     '), date(1975,12,29,12)})
table.insert(dates, {date('1976-W01-1 13:00+01:00'), date(1975,12,29,12)})
table.insert(dates, {date('1976-W01-1 0700-0500  '), date(1975,12,29,12)})
for i = 1, #dates do
    assert(dates[i][1] == dates[i][2], 'error in date(string) for: ' ..  dates[i][2])
end
env.trace('(done) date(str)')
a = date(1521, 5, 2)
b = a:copy():addseconds(0.001)
assert((a - b):spanseconds() == -0.001 and (a + b) == (b + a) and a == (b - date('00:00:00.001')) and b == (a + date('00:00:00.001')), 'error in date arithmetic calculations'); env.trace('(done) date arithmetic calculations')
b:addseconds(-0.01); assert((a >  b and b <  a) and (a >= b and b <= a) and (a ~= b and (not(a == b))), 'error in date boolean operations'); env.trace('(done) date boolean operations')
a = b:copy(); assert((a .. 565369) == (b .. 565369) and (a .. '????') == (b .. '????'), 'error in date concatenation'); env.trace('(done) date concatenation')
a = date(2000, 12, 30)
assert(date.diff(date(a):adddays(3), a):spandays() == 3, 'error in date:adddays'); env.trace('(done) date:adddays')
assert(date.diff(date(a):addhours(3), a):spanhours() == 3, 'error in date:addhours'); env.trace('(done) date:addhours')
assert(date.diff(date(a):addminutes(3), a):spanminutes() == 3, 'error in date:addminutes'); env.trace('(done) date:addminutes')
assert(date(2000,12,28):addmonths(3):getmonth() == 3, 'error in date:addmonths'); env.trace('(done) date:addmonths')
assert(date.diff(date(a):addseconds(3), a):spanseconds() == 3, 'error in date:addseconds'); env.trace('(done) date:addseconds')
assert(date.diff(date(a):addticks(3), a):spanticks() == 3, 'error in date:addticks'); env.trace('(done) date:addticks')
assert(date(2000,12,30):addyears(3):getyear() == 2003, 'error in date:addyears'); env.trace('(done) date:addyears')
d = date(1582,10,5); assert(d:fmt('%D') == d:fmt('%m/%d/%y') and d:fmt('%F') == d:fmt('%Y-%m-%d') and d:fmt('%h') == d:fmt('%b') and d:fmt('%r') == d:fmt('%I:%M:%S %p') and d:fmt('%T') == d:fmt('%H:%M:%S') and d:fmt('%a %A %b %B') == 'Tue Tuesday Oct October' and d:fmt('%C %d') == '15 05', d:fmt('%C %d'), 'error in date:fmt'); env.trace('(done) date:fmt')
assert(date('10:59:59 pm'):getclockhour() == 10, 'error in date:getclockhour'); env.trace('(done) date:getclockhour')
y, m, d = date(1970, 1, 1):getdate(); assert(y == 1970 and m == 1 and d == 1, 'error in date:getdate'); env.trace('(done) date:getdate')
assert(date(1966, 'sep', 6):getday() == 6, 'error in date:getday'); env.trace('(done) date:getday')
assert(date('Wed Apr 04 2181 11:51:06.996 UTC'):getfracsec() == 6.996, 'error in date:getfracsec'); env.trace('(done) date:getfracsec')
assert(date('Wed Apr 04 2181 11:51:06 UTC'):gethours() == 11, 'error in date:gethours'); env.trace('(done) date:gethours')
assert(date(1970, 1, 1):getisoweekday() == 4, 'error in date:getisoweekday'); env.trace('(done) date:getisoweekday')
assert(date(1975, 12, 29):getisoweeknumber() == 1, 'error in date:getisoweeknumber'); env.trace('(done) date:getisoweeknumber')
assert(date(1975, 12, 29):getisoyear() == 1976, 'error in date:getisoyear'); env.trace('(done) date:getisoyear')
assert(date('Wed Apr 04 2181 11:51:06 UTC'):getminutes() == 51, 'error in date:getminutes'); env.trace('(done) date:getminutes')
assert(date(1966, 'sep', 6):getmonth() == 9, 'error in date:getmonth'); env.trace('(done) date:getmonth')
assert(date('Wed Apr 04 2181 11:51:06.123 UTC'):getseconds() == 6, 'error in date:getseconds'); env.trace('(done) date:getseconds')
assert(date('Wed Apr 04 2181 11:51:06.123 UTC'):getticks() == 123000, 'error in date:getticks'); env.trace('(done) date:getticks')
h, m, s, t = date({hour=5, sec=.5, min=59}):gettime(); assert(t == 500000 and s == 0 and m == 59 and h == 5, 'error in date:gettime'); env.trace('(done) date:gettime')
assert(date(1970, 1, 1):getweekday() == 5, 'error in date:getweekday'); env.trace('(done) date:getweekday')
a = date('12/31/1972'); b, c = a:getweeknumber(), a:getweeknumber(2); assert(b == 53 and c == 52, 'error in date:getweeknumber'); env.trace('(done) date:getweeknumber')
assert(date(1965, 'jan', 0):getyear() == 1964, 'error in date:getyear'); env.trace('(done) date:getyear')
assert(date(2181, 1, 12):getyearday() == 12, 'error in date:getyearday'); env.trace('(done) date:getyearday')
assert(date(1966, 'july', 6):setday(1) == date('1966 july 1'), 'error in date:setday'); env.trace('(done) date:setday')
assert(date(1984, 12, 3, 4, 39, 54):sethours(1, 1, 1) == date('1984 DEc 3 1:1:1'), 'error in date:sethours'); env.trace('(done) date:sethours')
assert(date.isodate(1999, 52, 1):setisoweekday(7) == date(2000, 1, 02), 'error in date:setisoweekday'); env.trace('(done) date:setisoweekday')
assert(date(1999, 12, 27):setisoweeknumber(51, 7) == date(1999, 12, 26), 'error in date:setisoweeknumber'); env.trace('(done) date:setisoweeknumber')
d = date(1999, 12, 27):setisoyear(2000, 1); assert(d == date.isodate(2000, 1, 1) and d:getyear() == 2000 and d:getday() == 3, 'error in date:setisoyear'); env.trace('(done) date:setisoyear')
assert(date(1984, 12, 3, 4, 39, 54):setminutes(59, 59, 500) == date(1984, 12, 3, 4, 59, 59, 500), 'error in date:setminutes'); env.trace('(done) date:setminutes')
assert(date(1966, 'july', 6):setmonth(1) == date('6 jan 1966'), 'error in date:setmonth'); env.trace('(done) date:setmonth')
assert(date(1984, 12, 3, 4, 39, 54):setseconds(59, date.ticks()) == date(1984, 12, 3, 4, 40), 'error in date:setseconds'); env.trace('(done) date:setseconds')
assert(date(1984, 12, 3, 4, 39, 54):setticks(444) == date(1984, 12, 3, 4, 39, 54, 444), 'error in date:setticks'); env.trace('(done) date:setticks')
assert(date(1966, 'july', 6):setyear(2000) == date('jul 6 2000'), 'error in date:setyear'); env.trace('(done) date:setyear')
a = date(2181, 'aPr', 4, 6, 30, 30, 15000)
assert(date.diff(date(a):adddays(2), a):spandays() == (2), 'error in date:spandays'); env.trace('(done) date:spandays')
assert(date.diff(date(a):adddays(2), a):spanhours() == (2 * 24), 'error in date:spanhours'); env.trace('(done) date:spanhours')
assert(date.diff(date(a):adddays(2), a):spanminutes() == (2 * 24 * 60), 'error in date:spanminutes'); env.trace('(done) date:spanminutes')
assert(date.diff(date(a):adddays(2), a):spanseconds() == (2 * 24 * 60 * 60), 'error in date:spanseconds'); env.trace('(done) date:spanseconds')
assert(date.diff(date(a):adddays(2), a):spanticks() == (2 * 24 * 60 * 60 * 1000000), 'error in date:spanticks'); env.trace('(done) date:spanticks')

-- Mersenne Twister random tests
math.randomseed(1234) -- restore initial state
assert(math.random(env.huge_num) == 822569776, 'error in math.random(number)'); env.trace('(done) math.random in [1, number]')
math.randomseed(2345) -- change state
assert(tostring(math.random()) == '0.66064431145787', 'error in math.random')
assert(tostring(math.random()) == '0.20009499951266', 'error in math.random'); env.trace('(done) math.random in [0, 1)')
math.randomseed(2345) -- restore previous state
assert(tostring(math.random()) == '0.66064431145787', 'error in math.randomseed')
assert(math.round(math.random_number(), .01) == 0.20 and math.round(math.random_number(10), .01) == 5.86 and math.round(math.random_number(3, 8), .01) == 7.07, 'error in math.random_number'); env.trace('(done) math.random_number')
assert(math.random_choice({1, 2, 3, 4}) == 1, 'error in math.random_choice'); env.trace('(done) math.random_choice')
assert(math.weighted_choice({['dog'] = 8, ['cat'] = 5, ['frog'] = 3 }) == 'cat', 'error in math.weighted_choice'); env.trace('(done) math.weighted_choice')
math.randomseed(os.time()); env.trace('(done) math.randomseed')

env.trace('All tests done.')
