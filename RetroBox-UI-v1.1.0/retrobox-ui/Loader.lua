-- Optional diagnostic loader. Update URL if you move the published library.
local URL = "https://raw.githubusercontent.com/ManoGustavo0/RetroBox/main/RetroBox-UI-v1.1.0/retrobox-ui/RetroBox.lua"
local EXPECTED_VERSION = "1.9.0"
assert(type(loadstring) == "function", "[RetroBox] This executor does not expose loadstring")
local hasHTTP, httpGet = pcall(function() return game.HttpGet end)
assert(hasHTTP and type(httpGet) == "function", "[RetroBox] This executor does not expose game:HttpGet")
local downloaded, source = pcall(function() return game:HttpGet(URL) end)
assert(downloaded, "[RetroBox] Download failed. Check the raw GitHub URL: " .. tostring(source))
assert(type(source) == "string" and #source > 0, "[RetroBox] GitHub returned an empty source")
local chunk, compileError = loadstring(source, "RetroBox")
assert(chunk, "[RetroBox] Could not compile the raw source: " .. tostring(compileError))
local loaded, library = pcall(chunk)
assert(loaded, "[RetroBox] Could not initialize the library: " .. tostring(library))
assert(type(library) == "table" and type(library.CreateWindow) == "function", "[RetroBox] URL did not return a RetroBox library")
assert(library.Version == EXPECTED_VERSION and type(library.CreateScriptHub) == "function", "[RetroBox] Publish RetroBox " .. EXPECTED_VERSION .. " or use its confirmed commit in URL")
return library
