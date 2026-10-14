return function(Mock,Library,test)
    function Mock.distributionHTTP(_,url)
        local path=url:match("/RetroBox/main/(.+)$"); assert(path,"Unexpected distribution origin")
        local filePath=path:match("^RetroBox%-UI%-v1%.1%.0/retrobox%-ui/(.+)$")
        if path=="dist/Loader.lua" or path=="dist/bootstrap/v2.lua" then filePath="Loader.lua"
        elseif path:match("^dist/channels/") or path:match("^dist/releases/.+/manifest%.json$") then
            local sourceFile=assert(io.open("RetroBox.lua","r")); local source=sourceFile:read("*a"); sourceFile:close()
            local channel=path:match("channels/([^/]+)/") or "pinned"
            return Mock.Services.HttpService:JSONEncode({SchemaVersion=1,Kind="RetroBox",Version=Library.Version,APIVersion=2,Build=Library.Build,Channel=channel,
                Artifact={Path="dist/releases/"..Library.Version.."/RetroBox.lua",SHA256=Library:SHA256(source),Bytes=#source}})
        elseif path:match("^dist/releases/.+/RetroBox%.lua$") then filePath="RetroBox.lua" end
        assert(filePath,"Unexpected distribution path: "..path)
        local file=assert(io.open(filePath,"r")); local source=file:read("*a"); file:close(); return source
    end
    test("permanent HTTP loader creates a complete library without executor files",function()
        local caps={readfile,writefile,makefolder,isfile,listfiles}; local oldHTTP,oldLoad=game.HttpGet,loadstring
        readfile=nil; writefile=nil; makefolder=nil; isfile=nil; listfiles=nil; loadstring=load
        local requests=0; game.HttpGet=function(...) requests=requests+1; return Mock.distributionHTTP(...) end
        local remote=dofile("Loader.lua"); assert(requests==2 and remote.Version=="2.0.0" and remote.Distribution.State=="Loaded")
        local window=remote:CreateWindow({Id="no-local-file",FileStorage=false})
        local section=window:CreateTab("Tab"):CreateSection("Section"); local calls=0
        section:AddToggle({Id="remote-toggle",Callback=function() calls=calls+1 end}):SetValue(true); Mock.pump(); assert(calls==1)
        window:Destroy(); Mock.pump(100); assert(Mock.Connections==0)
        readfile,writefile,makefolder,isfile,listfiles=table.unpack(caps,1,5); game.HttpGet=oldHTTP; loadstring=oldLoad
    end)
    test("permanent loader diagnoses missing capabilities and rejects wrong contents",function()
        local oldHTTP,oldLoad=game.HttpGet,loadstring; loadstring=load
        game.HttpGet=nil; local ok,err=pcall(dofile,"Loader.lua"); assert(not ok and tostring(err):find("HttpGet",1,true))
        game.HttpGet=Mock.distributionHTTP; loadstring=nil
        ok,err=pcall(dofile,"Loader.lua"); assert(not ok and tostring(err):find("loadstring",1,true))
        loadstring=load; game.HttpGet=function() return 'return {Version="1.8.0"}' end
        assert(not pcall(dofile,"Loader.lua")); game.HttpGet=oldHTTP; loadstring=oldLoad
    end)
end
