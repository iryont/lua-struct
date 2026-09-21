local struct = require "struct"

local function hex(str)
    return (str:gsub(".", function (c)
        return string.format("%02x", c:byte())
    end))
end

local function bin(str)
    return (str:gsub("%x%x", function (x)
        return string.char(tonumber(x, 16))
    end))
end

-- the call has to fail with a message which contains the given text
local function fails(text, fn, ...)
    local ok, err = pcall(fn, ...)
    assert.is_false(ok)
    assert.is_truthy(tostring(err):find(text, 1, true), tostring(err))
end

-- Lua 5.1 turns the literal -0.0 into 0, so it is made at run time
local negzero = -1 / math.huge

describe("struct test", function ()

    it("test ss", function ()
        local s1 = "test1"
        local s2 = "test2"
        local packed = struct.pack("<ss", s1, s2)
        local uns1, uns2 = struct.unpack("<ss", packed)
        assert.same(uns1, s1)
        assert.same(uns2, s2)
    end)

    it("test s", function ()
        local value = "test"
        local packed = struct.pack("<s", value)
        local unpacked = struct.unpack("<s", packed)
        assert.same(unpacked, value)
    end)

    it("test L", function ()
        local value = 12345678912345678
        local packed = struct.pack('<L', value)
        local unpacked = struct.unpack('<L', packed)
        assert.same(unpacked, value)
    end)

    it("test I", function ()
        local value = 123456789
        local packed = struct.pack('<I', value)
        local unpacked = struct.unpack('<I', packed)
        assert.same(unpacked, value)
    end)

    it("test h", function ()
        local value = -3200
        local packed = struct.pack('<h', value)
        local unpacked = struct.unpack('<h', packed)
        assert.same(unpacked, value)
    end)

    it("test B", function ()
        local value = 255
        local packed = struct.pack('<B', value)
        local unpacked = struct.unpack('<B', packed)
        assert.same(unpacked, value)
    end)

    it("test b", function ()
        local value = -1
        local packed = struct.pack('<b', value)
        local unpacked = struct.unpack('<b', packed)
        assert.same(unpacked, value)
    end)

    it("test f", function ()
        local value = 1.56789
        local packed = struct.pack('<f', value)
        local unpacked = struct.unpack('<f', packed)
        -- the closest float, which happens to be above the value
        assert.same(unpacked, 1.5678900480270386)
    end)

    it("test d", function ()
        local value = 1.56789
        local packed = struct.pack('<d', value)
        local unpacked = struct.unpack('<d', packed)
        assert.same(unpacked, value)
    end)

    it("test README example", function ()
        local packed = struct.pack('<LIhBsbfd', 123456789123456789, 123456789, -3200, 255, 'Test message', -1, 1.56789, 1.56789)
        local L, I, h, B, s, b, f, d, pos = struct.unpack('<LIhBsbfd', packed)
        assert.equal(123456789123456789, L)
        assert.equal(123456789, I)
        assert.equal(-3200, h)
        assert.equal(255, B)
        assert.equal('Test message', s)
        assert.equal(-1, b)
        assert.equal(1.5678900480270386, f)
        assert.equal(1.56789, d)
        assert.equal(#packed + 1, pos)
    end)

end)

describe("integers", function ()

    it("are little endian unless told otherwise", function ()
        assert.equal("78563412", hex(struct.pack("I", 0x12345678)))
        assert.equal("78563412", hex(struct.pack("<I", 0x12345678)))
        assert.equal("12345678", hex(struct.pack(">I", 0x12345678)))
        assert.equal(0x12345678, (struct.unpack("I", bin("78563412"))))
        assert.equal(0x12345678, (struct.unpack(">I", bin("12345678"))))
    end)

    it("can change the byte order inside of a format", function ()
        assert.equal("0001" .. "0100" .. "0001", hex(struct.pack(">H<H>H", 1, 1, 1)))
        local a, b, c = struct.unpack(">H<H>H", bin("000101000001"))
        assert.same({1, 1, 1}, {a, b, c})
    end)

    it("have the documented sizes", function ()
        for fmt, size in pairs{b = 1, B = 1, h = 2, H = 2, i = 4, I = 4, l = 8, L = 8, T = 8} do
            assert.equal(size, #struct.pack(fmt, 0))
            assert.equal(size, struct.size(fmt))
        end
    end)

    it("round trip at their limits", function ()
        local limits = {
            b = {-128, 127}, B = {0, 255},
            h = {-32768, 32767}, H = {0, 65535},
            i = {-2147483648, 2147483647}, I = {0, 4294967295},
            i3 = {-8388608, 8388607}, I3 = {0, 16777215},
            I5 = {0, 1099511627775}, i6 = {-140737488355328, 140737488355327},
            l = {-9007199254740992, 9007199254740992}, L = {0, 9007199254740992},
        }
        for fmt, values in pairs(limits) do
            for _, order in ipairs{"<", ">"} do
                for _, value in ipairs(values) do
                    local unpacked = struct.unpack(order .. fmt, struct.pack(order .. fmt, value))
                    assert.equal(value, unpacked)
                end
            end
        end
    end)

    it("use two's complement for negative numbers", function ()
        assert.equal("ff", hex(struct.pack("b", -1)))
        assert.equal("80f3", hex(struct.pack("<h", -3200)))
        assert.equal("f380", hex(struct.pack(">h", -3200)))
        assert.equal("feffffff", hex(struct.pack("<i", -2)))
        -- https://github.com/iryont/lua-struct/issues/3
        assert.equal("feffffffffffffff", hex(struct.pack("<l", -2)))
        assert.equal("fffffffffffffffe", hex(struct.pack(">l", -2)))
    end)

    it("unpack negative 8 byte numbers without losing the low bits", function ()
        -- the discussion of https://github.com/iryont/lua-struct/issues/3: these fit
        -- into a double, it was the detour over 2^64 while reading which broke them
        for _, value in ipairs{-1, -2, -255, -256, -3200, -123456789, -9007199254740992} do
            assert.equal(value, (struct.unpack("<l", struct.pack("<l", value))))
            assert.equal(value, (struct.unpack(">l", struct.pack(">l", value))))
        end
        for i = 0, 62 do
            assert.equal(2 ^ i, (struct.unpack("<l", struct.pack("<l", 2 ^ i))))
            assert.equal(-2 ^ i, (struct.unpack("<l", struct.pack("<l", -2 ^ i))))
        end
        assert.equal(-1, (struct.unpack("<l", bin("ffffffffffffffff"))))
        assert.equal(-2 ^ 63, (struct.unpack("<l", bin("0000000000000080"))))
    end)

    it("accept an explicit size", function ()
        assert.equal("fe", hex(struct.pack("<i1", -2)))
        assert.equal("feff", hex(struct.pack("<i2", -2)))
        assert.equal("feffff", hex(struct.pack("<i3", -2)))
        assert.equal("123456", hex(struct.pack(">I3", 0x123456)))
        assert.equal("feffffffffffffff", hex(struct.pack("<i8", -2)))
        assert.equal(-2, (struct.unpack("<i3", bin("feffff"))))
        assert.equal(0x123456, (struct.unpack(">I3", bin("123456"))))
        assert.equal(16777214, (struct.unpack("<I3", bin("feffff"))))
        assert.equal(7, struct.size("i3I4"))
        fails("integral size 0 is out of limits [1,8]", struct.pack, "i0", 1)
        fails("integral size 9 is out of limits [1,8]", struct.unpack, "I9", "123456789")
    end)

    it("wrap around instead of failing on overflow", function ()
        assert.equal("00", hex(struct.pack("B", 256)))
        assert.equal("ff", hex(struct.pack("B", -1)))
        assert.equal("ffffffff", hex(struct.pack("<i", 4294967295)))
        assert.equal("0000", hex(struct.pack("<H", 65536)))
    end)

    it("floor numbers with a fraction", function ()
        assert.equal("01000000", hex(struct.pack("<i", 1.5)))
        assert.equal("feffffff", hex(struct.pack("<i", -1.5)))
        assert.equal("ff", hex(struct.pack("B", 255.999)))
    end)

    it("accept strings which look like numbers", function ()
        assert.equal("0a00", hex(struct.pack("<h", "10")))
    end)

    it("reject values which are not integers at all", function ()
        fails("number has no integer representation", struct.pack, "i", math.huge)
        fails("number has no integer representation", struct.pack, "i", -math.huge)
        fails("number has no integer representation", struct.pack, "i", 0 / 0)
    end)

    it("are exact up to 2^53 everywhere, above that only approximated by doubles", function ()
        assert.equal("000000000000e0ff", hex(struct.pack("<l", -9007199254740992)))
        assert.equal(2 ^ 63, (struct.unpack("<L", bin("0000000000000080"))))
        assert.equal(2 ^ 64, (struct.unpack("<L", bin("ffffffffffffffff"))) + 0.0)
        assert.equal("0000000000000080", hex(struct.pack("<L", 2 ^ 63)))
    end)

    if math.type then
        it("are exact over the whole 64 bit range with Lua 5.3+", function ()
            assert.equal("ffffffffffffff7f", hex(struct.pack("<l", math.maxinteger)))
            assert.equal("0000000000000080", hex(struct.pack("<l", math.mininteger)))
            assert.equal("7fffffffffffffff", hex(struct.pack(">l", math.maxinteger)))
            assert.equal(math.maxinteger, (struct.unpack("<l", bin("ffffffffffffff7f"))))
            assert.equal(math.mininteger, (struct.unpack("<l", bin("0000000000000080"))))
            assert.equal(math.maxinteger, (struct.unpack("<L", bin("ffffffffffffff7f"))))

            local value = 9007199254740993 -- 2^53 + 1, not a double
            assert.equal(value, (struct.unpack("<l", struct.pack("<l", value))))
            assert.equal(-value, (struct.unpack(">l", struct.pack(">l", -value))))
        end)

        it("are returned as integers with Lua 5.3+", function ()
            for _, fmt in ipairs{"b", "B", "h", "H", "i", "I", "i3", "I7", "l", "L", "T"} do
                local value = struct.unpack(fmt, string.rep("\1", 8))
                assert.equal("integer", math.type(value))
            end
            -- does not fit into an integer, so it is a float like on Lua 5.1
            assert.equal("float", math.type((struct.unpack("<L", bin("00000000000000ff")))))
        end)
    end

end)

describe("floats", function ()

    it("are encoded as IEEE 754", function ()
        assert.equal("0000803f", hex(struct.pack("<f", 1)))
        assert.equal("c0200000", hex(struct.pack(">f", -2.5)))
        assert.equal("000000000000f03f", hex(struct.pack("<d", 1)))
        assert.equal("c004000000000000", hex(struct.pack(">d", -2.5)))
        assert.equal("9a9999999999b93f", hex(struct.pack("<d", 0.1)))
        assert.equal("679b1bd31316f93f", hex(struct.pack("<d", 1.56789)))
        assert.equal(-2.5, (struct.unpack(">f", bin("c0200000"))))
        assert.equal(0.1, (struct.unpack("<d", bin("9a9999999999b93f"))))
    end)

    it("round to the nearest float like C does", function ()
        assert.equal("cdcccc3d", hex(struct.pack("<f", 0.1)))
        assert.equal("9fb0c83f", hex(struct.pack("<f", 1.56789)))
        assert.equal(0.10000000149011612, (struct.unpack("<f", bin("cdcccc3d"))))
        -- ties go to the even mantissa
        assert.equal("0000804b", hex(struct.pack("<f", 16777217)))
        assert.equal("0200804b", hex(struct.pack("<f", 16777219)))
        -- rounding can carry over into the exponent
        assert.equal("00000040", hex(struct.pack("<f", 1.99999999)))
    end)

    it("round trip every double", function ()
        for _, value in ipairs{0, 1, -1, 0.1, 1 / 3, 1.56789, -24e-5, 123456.789, 2 ^ 53, 1e300, -1e-300,
                               1.7976931348623157e308, 2.2250738585072014e-308} do
            assert.equal(value, (struct.unpack("<d", struct.pack("<d", value))))
            assert.equal(value, (struct.unpack(">d", struct.pack(">d", value))))
        end
    end)

    it("handle infinity", function ()
        assert.equal("0000807f", hex(struct.pack("<f", math.huge)))
        assert.equal("000080ff", hex(struct.pack("<f", -math.huge)))
        assert.equal("000000000000f07f", hex(struct.pack("<d", math.huge)))
        assert.equal("000000000000f0ff", hex(struct.pack("<d", -math.huge)))
        assert.equal(math.huge, (struct.unpack("<f", bin("0000807f"))))
        assert.equal(-math.huge, (struct.unpack("<f", bin("000080ff"))))
        assert.equal(math.huge, (struct.unpack("<d", bin("000000000000f07f"))))
        assert.equal(-math.huge, (struct.unpack("<d", bin("000000000000f0ff"))))
    end)

    it("handle not a number", function ()
        assert.equal("0000c07f", hex(struct.pack("<f", 0 / 0)))
        assert.equal("000000000000f87f", hex(struct.pack("<d", 0 / 0)))
        for _, packed in ipairs{"0000c07f", "0000c0ff", "0100807f"} do
            local value = struct.unpack("<f", bin(packed))
            assert.is_true(value ~= value)
        end
        for _, packed in ipairs{"000000000000f87f", "000000000000f8ff", "010000000000f07f"} do
            local value = struct.unpack("<d", bin(packed))
            assert.is_true(value ~= value)
        end
    end)

    it("keep the sign of zero", function ()
        assert.equal("00000000", hex(struct.pack("<f", 0)))
        assert.equal("00000080", hex(struct.pack("<f", negzero)))
        assert.equal("0000000000000080", hex(struct.pack("<d", negzero)))
        assert.equal(math.huge, 1 / struct.unpack("<d", bin("0000000000000000")))
        assert.equal(-math.huge, 1 / struct.unpack("<d", bin("0000000000000080")))
        assert.equal(-math.huge, 1 / struct.unpack("<f", bin("00000080")))
    end)

    it("handle subnormal numbers", function ()
        assert.equal("0100000000000000", hex(struct.pack("<d", 5e-324)))
        assert.equal(5e-324, (struct.unpack("<d", bin("0100000000000000"))))
        assert.equal("c2160100", hex(struct.pack("<f", 1e-40)))
        assert.equal(9.99994610111476e-41, (struct.unpack("<f", bin("c2160100"))))
        assert.equal("01000000", hex(struct.pack("<f", 2 ^ -149)))
        assert.equal(2 ^ -149, (struct.unpack("<f", bin("01000000"))))
    end)

    it("turn doubles which are out of the float range into infinity or zero", function ()
        assert.equal("ffff7f7f", hex(struct.pack("<f", 3.4028234663852886e38)))
        assert.equal("0000807f", hex(struct.pack("<f", 1e39)))
        assert.equal("000080ff", hex(struct.pack("<f", -1e39)))
        assert.equal("00000000", hex(struct.pack("<f", 1e-46)))
        assert.equal("00000080", hex(struct.pack("<f", -1e-46)))
    end)

    it("accept integers and strings which look like numbers", function ()
        assert.equal("0000803f", hex(struct.pack("<f", "1")))
        assert.equal("0000000000000840", hex(struct.pack("<d", 3)))
    end)

    if math.type then
        it("are returned as floats with Lua 5.3+", function ()
            assert.equal("float", math.type((struct.unpack("<f", bin("0000803f")))))
            assert.equal("float", math.type((struct.unpack("<d", bin("000000000000f03f")))))
            assert.equal("float", math.type((struct.unpack("<d", bin("0000000000000000")))))
        end)
    end

end)

describe("strings", function ()

    it("s is zero terminated", function ()
        assert.equal("abc\0", struct.pack("s", "abc"))
        assert.equal("\0", struct.pack("s", ""))
        local a, b, pos = struct.unpack("ss", "abc\0\0")
        assert.same({"abc", "", 6}, {a, b, pos})
    end)

    it("s needs the terminator when unpacking", function ()
        fails("unfinished string in data", struct.unpack, "s", "abc")
        fails("unfinished string in data", struct.unpack, "ss", "abc\0def")
    end)

    it("c without a size is a single char", function ()
        -- https://github.com/iryont/lua-struct/issues/4
        assert.equal("a", struct.pack("c", "abc"))
        assert.equal("hhel\0", struct.pack("cc3b", "hello", "hello", 0))
        assert.same({"a", "b", 3}, {struct.unpack("cc", "abc")})
    end)

    it("cn takes exactly n chars", function ()
        assert.equal("abc", struct.pack("c3", "abcdef"))
        assert.equal("abcdef    ", struct.pack("c10", "abcdef"))
        assert.equal("abcdefghijkl", struct.pack("c12", "abcdefghijklmnop"))
        assert.same({"abc", "def", 7}, {struct.unpack("c3c3", "abcdef")})
        assert.same({"ab\0cd", 6}, {struct.unpack("c5", "ab\0cd")})
    end)

    it("cn only looks at the number right behind it", function ()
        fails("invalid format option '5'", struct.pack, "cb5", "abcdef", 1)
        assert.equal("a\1", struct.pack("cb", "abcdef", 1))
    end)

    it("c0 packs the whole string", function ()
        assert.equal("hello world", struct.pack("c0", "hello world"))
        assert.equal("", struct.pack("c0", ""))
        assert.equal("\5hello", struct.pack("Bc0", 5, "hello"))
    end)

    it("c0 takes its size from the previous value when unpacking", function ()
        local packed = struct.pack("<Hc0B", 5, "hello", 7)
        assert.same({"hello", 7, 9}, {struct.unpack("<Hc0B", packed)})
        assert.same({"", 2}, {struct.unpack("Bc0", "\0")})
        for _, fmt in ipairs{"B", "<l", ">i2", "<f", ">d"} do
            local value = string.rep("x", 200)
            assert.equal(value, (struct.unpack(fmt .. "c0", struct.pack(fmt .. "c0", #value, value))))
        end
    end)

    it("c0 refuses to unpack without a usable size", function ()
        fails("format 'c0' needs a previous size", struct.unpack, "c0", "abc")
        fails("format 'c0' needs a previous size", struct.unpack, "sc0", "abc\0abc")
        fails("invalid size for format 'c0'", struct.unpack, "bc0", "\255abc")
        fails("invalid size for format 'c0'", struct.unpack, "<fc0", struct.pack("<f", 1.5) .. "abc")
        fails("data string too short", struct.unpack, "Bc0", "\4abc")
    end)

    it("a huge size does not get around the check of the data length", function ()
        -- pos + size used to wrap around with the 64 bit integers of Lua 5.3+
        fails("data string too short", struct.unpack, "<lc0", bin("ffffffffffffff7f") .. "abc")
        fails("data string too short", struct.unpack, "<lc0B", bin("ffffffffffffff7f") .. "abc")
        fails("data string too short", struct.unpack, "c9223372036854775807", "abc", 2)
    end)

    it("c0 takes a size which is a string of digits", function ()
        assert.same({"abc", 6}, {struct.unpack("c2c0", "03abcdef")})
        assert.same({"abc", 6}, {struct.unpack("sc0", "3\0abcdef")})
    end)

    it("accept numbers in place of strings", function ()
        assert.equal("42\0", struct.pack("s", 42))
        assert.equal("42 ", struct.pack("c3", 42))
    end)

end)

describe("positions", function ()

    it("unpack returns the position where it stopped", function ()
        -- https://github.com/iryont/lua-struct/issues/5
        assert.same({1, 2, 3}, {struct.unpack("BB", "\1\2\3")})
        assert.same({1}, {struct.unpack("", "abc")})
        assert.same({4}, {struct.unpack("", "abc", 4)})
        assert.equal(3, select("#", struct.unpack("<HH", "\1\0\2\0")))
    end)

    it("unpack can start anywhere in the data", function ()
        assert.same({3, 4}, {struct.unpack("B", "\1\2\3", 3)})
        assert.same({0x0302, 4}, {struct.unpack("<H", "\1\2\3", 2)})
        assert.same({3, 4}, {struct.unpack("B", "\1\2\3", -1)})
        assert.same({0x0302, 4}, {struct.unpack("<H", "\1\2\3", -2)})
        assert.same({2, 3}, {struct.unpack("B", "\1\2\3", "2")})
    end)

    it("the returned position continues the reading", function ()
        local packed = struct.pack("<sIsI", "first", 1, "second", 2)
        local names, values, pos = {}, {}, 1
        while pos <= #packed do
            names[#names + 1], values[#values + 1], pos = struct.unpack("<sI", packed, pos)
        end
        assert.same({"first", "second"}, names)
        assert.same({1, 2}, values)
        assert.equal(#packed + 1, pos)
    end)

    it("unpack refuses positions outside of the data", function ()
        fails("initial position out of string", struct.unpack, "B", "abc", 0)
        fails("initial position out of string", struct.unpack, "B", "abc", 5)
        fails("initial position out of string", struct.unpack, "B", "abc", -4)
        fails("initial position out of string", struct.unpack, "B", "abc", 0.5)
        fails("initial position out of string", struct.unpack, "B", "abc", math.huge)
        fails("initial position out of string", struct.unpack, "B", "abc", 0 / 0)
        fails("number expected, got string", struct.unpack, "B", "abc", "x")
        fails("data string too short", struct.unpack, "B", "abc", 4)
    end)

end)

describe("padding and alignment", function ()

    it("x is a zero byte without a value", function ()
        assert.equal("\1\0\0\2", struct.pack("BxxB", 1, 2))
        assert.same({1, 2, 5}, {struct.unpack("BxxB", "\1\9\9\2")})
        fails("data string too short", struct.unpack, "Bx", "\1")
    end)

    it("spaces are ignored", function ()
        assert.equal(struct.pack("<HIs", 1, 2, "x"), struct.pack(" < H  I s ", 1, 2, "x"))
        assert.same({1, 2, 7}, {struct.unpack(" <H I ", struct.pack("<HI", 1, 2))})
        assert.equal("", struct.pack("   "))
    end)

    it("! aligns numbers to their size", function ()
        assert.equal("0200030000000500", hex(struct.pack("<!2 b i4 h", 2, 3, 5)))
        assert.equal("02000000030000000500", hex(struct.pack("<!4 b i h", 2, 3, 5)))
        assert.equal("01000000000000000000000000001440", hex(struct.pack("<!bd", 1, 5)))
        assert.same({2, 3, 5, 11}, {struct.unpack("<!4 b i h", bin("02000000030000000500"))})
        -- strings are never aligned
        assert.equal("\1abc", struct.pack("!4Bc3", 1, "abc"))
        assert.equal(12, struct.size("!4bibh"))
    end)

    it("! is relative to the start of the data when unpacking", function ()
        local packed = struct.pack("!8 x d", 12)
        assert.equal(16, #packed)
        assert.equal(12, (struct.unpack("!8 d", packed, 3)))
    end)

    it("! refuses what is not a power of 2", function ()
        fails("alignment 3 is not a power of 2", struct.pack, "!3i", 1)
        fails("format asks for alignment not power of 2", struct.pack, "!4i3", 1)
        assert.equal("\1\0\2\0\0", struct.pack("<!2Bi3", 1, 2))
    end)

end)

describe("size", function ()

    it("returns the size of a format", function ()
        assert.equal(0, struct.size(""))
        assert.equal(28, struct.size("<LIhBbfd"))
        assert.equal(28, #struct.pack("<LIhBbfd", 0, 0, 0, 0, 0, 0, 0))
        assert.equal(24, struct.size("<IIIIII"))
        assert.equal(13, struct.size(">c10 x H"))
        assert.equal(1, struct.size("c"))
    end)

    it("refuses formats without a fixed size", function ()
        fails("option 's' has no fixed size", struct.size, "Is")
        fails("option 'c0' has no fixed size", struct.size, "Ic0")
        fails("invalid format option 'q'", struct.size, "q")
    end)

end)

describe("errors", function ()

    it("name the invalid format option", function ()
        fails("bad argument #1 to 'pack' (invalid format option 'z')", struct.pack, "<Iz", 1)
        fails("bad argument #1 to 'unpack' (invalid format option '?')", struct.unpack, "?", "abc")
        fails("invalid format option '2'", struct.pack, "H2", 1)
    end)

    it("name the argument which is wrong", function ()
        fails("bad argument #2 to 'pack' (number expected, got no value)", struct.pack, "i")
        fails("bad argument #2 to 'pack' (number expected, got nil)", struct.pack, "ii", nil, 5)
        fails("bad argument #3 to 'pack' (number expected, got string)", struct.pack, "ii", 1, "abc")
        fails("bad argument #3 to 'pack' (number expected, got no value)", struct.pack, "<Bd", 1)
        fails("bad argument #2 to 'pack' (string expected, got no value)", struct.pack, "s")
        fails("bad argument #3 to 'pack' (string expected, got table)", struct.pack, "Bc3", 1, {})
        fails("bad argument #2 to 'pack' (string expected, got boolean)", struct.pack, "c0", true)
        fails("bad argument #1 to 'pack' (string expected, got nil)", struct.pack)
        fails("bad argument #1 to 'unpack' (string expected, got number)", struct.unpack, 1, "abc")
        fails("bad argument #2 to 'unpack' (string expected, got nil)", struct.unpack, "B")
        fails("bad argument #1 to 'size' (string expected, got nil)", struct.size)
    end)

    it("report data which is too short", function ()
        fails("bad argument #2 to 'unpack' (data string too short)", struct.unpack, "<I", "\1\2")
        fails("data string too short", struct.unpack, "B", "")
        fails("data string too short", struct.unpack, "<d", "\1\2")
        fails("data string too short", struct.unpack, "<f", "\1\2\3")
        fails("data string too short", struct.unpack, "c5", "ab")
        fails("data string too short", struct.unpack, "<HH", "\1\0\2")
    end)

    it("point at the caller", function ()
        local ok, err = pcall(function () struct.pack("i") end)
        assert.is_false(ok)
        assert.is_truthy(err:find("struct_spec", 1, true), err)
    end)

    it("extra arguments are ignored", function ()
        assert.equal("\1", struct.pack("B", 1, 2, 3))
    end)

end)

describe("without math.frexp and math.ldexp", function ()

    it("floats are packed and unpacked the same way", function ()
        -- both are missing from a Lua 5.3 or 5.4 built without LUA_COMPAT_MATHLIB
        local frexp, ldexp = math.frexp, math.ldexp
        math.frexp, math.ldexp = nil, nil
        package.loaded.struct = nil
        local ok, fallback = pcall(require, "struct")
        math.frexp, math.ldexp = frexp, ldexp
        package.loaded.struct = struct
        assert.is_true(ok)

        local values = {
            0, negzero, 1, -2.5, 0.1, 1 / 3, 1.56789, 123456.789, 16777217, 1.99999999, 2 ^ 53,
            2 ^ -149, 2 ^ -150, 2 ^ 127, 2 ^ -1022, 2 ^ -1074, 1e-40, 1e-46, 1e39, 1e300, -1e-300, 5e-324,
            3.4028234663852886e38, 1.7976931348623157e308, 2.2250738585072014e-308, math.huge, -math.huge
        }
        for _, value in ipairs(values) do
            for _, fmt in ipairs{"<f", ">f", "<d", ">d"} do
                local packed = struct.pack(fmt, value)
                assert.equal(hex(packed), hex(fallback.pack(fmt, value)))
                assert.equal((struct.unpack(fmt, packed)), (fallback.unpack(fmt, packed)))
            end
        end
    end)

end)
