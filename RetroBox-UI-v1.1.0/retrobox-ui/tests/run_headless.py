"""Run the logic suite using liblua 5.4. No Roblox renderer is emulated."""
import ctypes
import ctypes.util
from pathlib import Path
import os
import sys

root = Path(__file__).resolve().parents[1]
os.chdir(root)
library = ctypes.util.find_library("lua5.4")
if not library:
    sys.exit("Install Lua 5.4, or run: lua tests/headless.lua")
lua = ctypes.CDLL(library)
lua.luaL_newstate.restype = ctypes.c_void_p
lua.luaL_openlibs.argtypes = [ctypes.c_void_p]
lua.luaL_loadfilex.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_char_p]
lua.lua_pcallk.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_longlong, ctypes.c_void_p]
lua.lua_tolstring.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_void_p]
lua.lua_tolstring.restype = ctypes.c_char_p
lua.lua_close.argtypes = [ctypes.c_void_p]
state = lua.luaL_newstate()
lua.luaL_openlibs(state)
try:
    for source in sorted(root.rglob("*.lua")):
        status = lua.luaL_loadfilex(state, str(source).encode(), None)
        if status:
            sys.exit(lua.lua_tolstring(state, -1, None).decode())
    target = sys.argv[1] if len(sys.argv)>1 else "tests/headless.lua"
    status = lua.luaL_loadfilex(state, target.encode(), None)
    if not status:
        status = lua.lua_pcallk(state, 0, -1, 0, 0, None)
    if status:
        sys.exit(lua.lua_tolstring(state, -1, None).decode())
finally:
    lua.lua_close(state)
