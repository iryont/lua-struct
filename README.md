### lua-struct
Implementation of binary packing/unpacking in pure lua

[![test](https://github.com/iryont/lua-struct/actions/workflows/test.yml/badge.svg)](https://github.com/iryont/lua-struct/actions/workflows/test.yml)

### what is it for?
You can use it to pack and unpack binary data in pure lua. The idea is very similar to PHP unpack and pack functions, and the format strings are those of the [struct](http://www.inf.puc-rio.br/~roberto/struct/) library by Roberto Ierusalimschy, so it can stand in for that library wherever a C module is not an option.

It is a single file without dependencies which works with Lua 5.1, 5.2, 5.3, 5.4, 5.5 and LuaJIT.

### LuaRocks
```luarocks install lua-struct```

Or just copy `src/struct.lua` into your project.

### how to use it?
```lua
local struct = require "struct"

local packed = struct.pack('<LIhBsbfd', 123456789123456789, 123456789, -3200, 255, 'Test message', -1, 1.56789, 1.56789)
local L, I, h, B, s, b, f, d = struct.unpack('<LIhBsbfd', packed)
print(L, I, h, B, s, b, f, d)

1.2345678912346e+17    123456789    -3200    255    Test message    -1    1.567890048027    1.56789
```

Lua 5.3 and newer print `123456789123456789` for the first value, as they have real 64 bit integers.

`unpack` also returns the position where it stopped reading, which is where the next read has to start. This is how you walk through data of unknown length:

```lua
-- a stream of records, each one is a length prefixed name followed by a position
local data = struct.pack('<Bc0 ff', 4, 'Lion', 1.5, -2.5) .. struct.pack('<Bc0 ff', 5, 'Zebra', 0.25, 8.5)

local pos = 1
while pos <= #data do
  local name, x, y
  name, x, y, pos = struct.unpack('<Bc0 ff', data, pos)
  print(name, x, y)
end

Lion     1.5     -2.5
Zebra    0.25    8.5
```

### functions
```
struct.pack(format, ...)            returns a string with the values packed according to the format.
struct.unpack(format, data [, pos]) returns the values unpacked from data, followed by the position of the first
                                    byte which was not read. Reading starts at pos (default is 1), a negative pos
                                    counts from the end of data.
struct.size(format)                 returns the size of a string packed with the format, which can not contain
                                    the variable sized "s" and "c0".
```

### byte order
You can use < or > at the beginning of the format string to specify the byte order. Default is little endian (<), but you can change it to big endian (>) as well. It is possible to dynamically change the byte order within the format string, so in general you can save types in different byte orders.

### available types
```
"b" a signed char.
"B" an unsigned char.
"h" a signed short (2 bytes).
"H" an unsigned short (2 bytes).
"i" a signed int (4 bytes).
"I" an unsigned int (4 bytes).
"in" a signed int with n bytes, n can be 1 to 8 ("i3" is a 24 bit integer).
"In" an unsigned int with n bytes.
"l" a signed long (8 bytes).
"L" an unsigned long (8 bytes).
"T" a size_t (8 bytes).
"f" a float (4 bytes).
"d" a double (8 bytes).
"s" a zero-terminated string.
"cn" a sequence of exactly n chars corresponding to a single Lua string, a missing n means 1. When packing, a longer string is cut and a shorter one is filled up with spaces.
"c0" like "cn", but for packing - the string length is taken, unpacking - the number value of the previous unpacked value which is not returned.
"x" a padding zero byte with no corresponding Lua value.
"!n" aligns every number which follows to the smaller of its size and n, which has to be a power of 2 (a missing n means 8). There is no alignment by default.
" " spaces are ignored, so they can be used to make a format readable.
```

Anything else in a format string is an error, just like missing or wrong arguments and data which is too short for the format.

### numbers
* Integers which do not fit are not an error, they wrap around like they do in C: `struct.pack('B', 256)` is the same as `struct.pack('B', 0)` and `struct.pack('B', -1)` the same as `struct.pack('B', 255)`. A fraction is dropped by rounding down.
* Lua 5.1, 5.2 and LuaJIT keep every number in a double. 8 byte integers are exact up to 2^53 there (negative ones too), beyond that you get the closest double. If you need all 64 bits, read them as two halves: `local low, high = struct.unpack('<II', data)`.
* Lua 5.3 and newer pack and unpack their 64 bit integers without any loss. An unsigned value of 2^63 or more does not fit into such an integer and is returned as a float.
* Floats and doubles are IEEE 754, including infinity, NaN, negative zero and subnormal numbers. A double is rounded to the nearest float exactly like a cast in C does it, so a value too large for a float becomes infinity.

### differences from the C library
* The default byte order is always little endian and the sizes never depend on the machine: "h" is 2, "i" is 4, "l", "L" and "T" are 8 bytes.
* "in" and "In" are limited to 8 bytes.
* "cn" fills up a string which is too short with spaces instead of raising an error.
* A number with a fraction is rounded down when it is packed as an integer (-1.5 becomes -2), the C library cuts the fraction off (-1).
* "!" raises an error for an integer whose size is not a power of 2 (like "!4 i3") instead of aligning it in some way.
* Every NaN is packed as the same quiet NaN, the sign and the payload are not kept.
* `unpack` accepts a negative start position.

### upgrading from 0.9
Version 1.0.0 fixes a number of bugs: negative numbers unpacked from "l" were wrong, floats were truncated instead of rounded, infinity, NaN and subnormal numbers were packed as garbage, integers above 2^53 lost their low bits with Lua 5.3+, "c" did not work without a number and the library did not load with Lua 5.5 at all. It is also faster, most of all for strings, long formats and LuaJIT.

Some of the changes can affect existing code:
* `unpack` returns one more value, the position where it stopped. This matters wherever all of the results are used: `{struct.unpack(...)}`, `print(struct.unpack(...))`, or `unpack` as the last argument of a call like `table.insert(list, struct.unpack(...))`. Put the call in parentheses to get just the first value.
* Characters which are not a format option raise an error, they used to be skipped silently. This includes a number behind anything but "i", "I", "c" and "!".
* "x", "!" and "T" used to be skipped as well. They do not raise an error, they now do what the list above says, so a format which had them in it produces different data.
* "c" without a number is a single char. It used to take its length from the next number anywhere later in the format ("ci4" was read as "c4").
* "i2" is now an integer of 2 bytes, the 2 used to be ignored.
* Data which is too short raises an error. "cn" used to return a shorter string and "s" without the terminating zero used to return the rest of the data.
* "s" and "cn" only take strings and numbers. Other values used to be packed the way `tostring` prints them.
* "f" packs the nearest float, which can differ in the last bit from the truncated one of the previous versions.

### tests
```
luarocks install busted
busted spec
```
