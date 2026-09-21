package = "lua-struct"
version = "1.0.0-1"

source = {
  url = "git+https://github.com/iryont/lua-struct.git",
  tag = "1.0.0",
}

description = {
  summary = "Implementation of binary packing/unpacking in pure lua",
  detailed = [[
    Implementation of binary packing/unpacking in pure lua
    You can use it to pack and unpack binary data in pure lua. It follows the struct library of Roberto Ierusalimschy and works with Lua 5.1 up to 5.5 and LuaJIT.
  ]],
  homepage = "https://github.com/iryont/lua-struct",
  license = "MIT/X11"
}

dependencies = {
  "lua >= 5.1"
}

build = {
  type = 'none',
  install = {
    lua = {
      ['struct'] = 'src/struct.lua'
    }
  }
}
