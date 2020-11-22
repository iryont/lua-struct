package = "lua-struct"
version = "0.9.2-1"

source = {
  url = "git://github.com/iryont/lua-struct.git",
  tag = "0.9.2-1",
}

description = {
  summary = "Implementation of binary packing/unpacking in pure lua",
  detailed = [[
    Implementation of binary packing/unpacking in pure lua
    You can use it to pack and unpack binary data in pure lua. The idea is very similar to PHP unpack and pack functions."
  ]],
  homepage = "https://github.com/iryont/lua-struct",
  license = "MIT/X11"
}

dependencies = {}

build = {
  type = 'none',
  install = {
    lua = {
      ['struct'] = 'src/struct.lua'
    }
  }
}
