local struct = require "struct"

describe("struct test", function ()
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
        assert.is.truthy(unpacked < value)
    end)

    it("test d", function () 
        local value = 1.56789
        local packed = struct.pack('<d', value)
        local unpacked = struct.unpack('<d', packed)
        assert.same(unpacked, value)
    end)

end)