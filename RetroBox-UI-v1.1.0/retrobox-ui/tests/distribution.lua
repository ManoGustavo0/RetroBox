return function(Mock,Library,test)
    test("the public HTTP loader creates a complete library without executor files",function()
        local caps={readfile,writefile,makefolder,isfile,listfiles}; local oldHTTP,oldLoad=game.HttpGet,loadstring
        readfile=nil; writefile=nil; makefolder=nil; isfile=nil; listfiles=nil; loadstring=load
        local file=assert(io.open("RetroBox.lua","r")); local source=file:read("*a"); file:close()
        local requests=0; game.HttpGet=function(_,url)
            assert(url:match("^https://raw%.githubusercontent%.com/ManoGustavo0/RetroBox/.+/RetroBox%-UI%-v1%.1%.0/retrobox%-ui/RetroBox%.lua$"))
            requests=requests+1; return source
        end
        local remote=dofile("Loader.lua"); assert(requests==1 and remote.Version=="1.9.0" and type(remote.CreateScriptHub)=="function")
        local window=remote:CreateWindow({Id="no-local-file",FileStorage=false})
        local tab=window:CreateTab("Tab"); local section=tab:CreateSection("Section"); local calls=0
        local toggle=section:AddToggle({Id="remote-toggle",Callback=function() calls=calls+1 end}); toggle:SetValue(true); Mock.pump(); assert(calls==1)
        window:Destroy(); Mock.pump(100); assert(Mock.Connections==0)
        readfile,writefile,makefolder,isfile,listfiles=table.unpack(caps,1,5); game.HttpGet=oldHTTP; loadstring=oldLoad
    end)
    test("remote loader rejects missing capabilities and old versions without local fallback",function()
        local oldHTTP,oldLoad=game.HttpGet,loadstring; loadstring=load
        game.HttpGet=nil; local ok,err=pcall(dofile,"Loader.lua"); assert(not ok and tostring(err):find("HttpGet",1,true))
        game.HttpGet=function() return 'return {Version="1.8.0",CreateWindow=function() end}' end
        assert(not pcall(dofile,"Loader.lua")); game.HttpGet=oldHTTP; loadstring=oldLoad
    end)
end
