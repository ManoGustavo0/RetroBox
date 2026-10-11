-- Optional diagnostic loader. Replace SEU_USUARIO/repository/branch before use.
local URL = "https://raw.githubusercontent.com/SEU_USUARIO/retrobox-ui/main/RetroBox.lua"
assert(type(loadstring) == "function", "[RetroBox] This executor does not expose loadstring")
local downloaded, source = pcall(function() return game:HttpGet(URL) end)
assert(downloaded, "[RetroBox] Download failed. Check the raw GitHub URL: " .. tostring(source))
assert(type(source) == "string" and #source > 0, "[RetroBox] GitHub returned an empty source")
local chunk, compileError = loadstring(source, "RetroBox")
assert(chunk, "[RetroBox] Could not compile the raw source: " .. tostring(compileError))
local loaded, library = pcall(chunk)
assert(loaded, "[RetroBox] Could not initialize the library: " .. tostring(library))
assert(type(library) == "table" and type(library.CreateWindow) == "function", "[RetroBox] URL did not return a RetroBox library")
return library
