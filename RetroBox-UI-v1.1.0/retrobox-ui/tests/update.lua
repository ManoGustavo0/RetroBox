return function(Mock,Library,test)
    local Core=dofile("src/UpdateCore.lua")
    local warningBase=#Mock.Warnings
    local service=Mock.Services.HttpService
    local function source(version,kind)
        if kind=="Hub" then return 'return {Version="'..version..'",Start=function(lib) return lib:CreateScriptHub({Id="loaded-hub",Version="'..version..'",FileStorage=false,ReducedMotion=true,Games={}}) end}' end
        return 'return {Version="'..version..'",APIVersion=2,CreateWindow=function() end,CreateScriptHub=function() end}'
    end
    local function manifest(version,bytes,kind,channel)
        return {SchemaVersion=1,Kind=kind or "RetroBox",Version=version,APIVersion=kind and 1 or 2,Build="test-"..version,Channel=channel or "stable",
            HubId=kind and "update-test" or nil,Library=kind and {MinVersion="2.0.0",MaxVersion="3.0.0",APIVersion=2} or nil,
            Artifact={Path="dist/releases/"..version.."/artifact.lua",SHA256=Core.SHA256(bytes),Bytes=#bytes}}
    end
    local function fixture(options)
        options=options or {}; local kind=options.Kind; local ver=options.ReleaseVersion or "2.0.0"; local bytes=source(ver,kind)
        local state={Manifest=manifest(ver,bytes,kind,options.Channel),Source=bytes,Requests={}}
        options.Fetch=function(url)
            state.Requests[#state.Requests+1]=url
            if state.Error then error(state.Error) end
            return url:sub(-5)==".json" and service:JSONEncode(state.Manifest) or state.Source
        end
        options.Service=service; options.ReleaseVersion=nil; options.MinVersion=options.MinVersion or "2.0.0"; options.MaxVersion=options.MaxVersion or "3.0.0"
        local updater=Core.New(options); return updater,state
    end
    local oldLoad=loadstring; loadstring=load
    test("semantic versions compare numeric releases and official prerelease precedence",function()
        assert(Core.CompareVersions("2.10.0","2.9.0")==1)
        assert(Core.CompareVersions("2.0.0+one","2.0.0+two")==0)
        local ordered={"2.0.0-alpha","2.0.0-alpha.1","2.0.0-alpha.beta","2.0.0-beta","2.0.0-beta.2","2.0.0-beta.11","2.0.0-rc.1","2.0.0"}
        for i=1,#ordered-1 do assert(Core.CompareVersions(ordered[i],ordered[i+1])==-1) end
        assert(Core.CompareVersions("2.0.0-999999999999999999999","2.0.0-1000000000000000000000")==-1)
        for _,bad in ipairs({"2.0","02.0.0","2.0.0-01","2.0.0-","2.0.0+","2.0.0-a..b","v2.0.0","2.0.0/bad"}) do assert(not pcall(Core.ParseVersion,bad)) end
    end)
    test("SHA256 matches independent standard vectors and binary padding boundaries",function()
        assert(Core.SHA256("")=="e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
        assert(Core.SHA256("abc")=="ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
        assert(Core.SHA256(("a"):rep(1000000))=="cdc76e5c9914fb9281a1c7e284d73e67f1809a48a497200e046d39ccc7112cd0")
        local file=assert(io.open("tests/fixtures/update-hashes.json","r")); local vectors=service:JSONDecode(file:read("*a")); file:close()
        for _,v in ipairs(vectors) do assert(Core.SHA256(("x"):rep(v.Length))==v.SHA256) end
    end)
    test("Stable Preview and Pinned resolve independent paths and exact versions",function()
        for _,channel in ipairs({"stable","preview","pinned"}) do
            local u,state=fixture({Channel=channel,Version=channel=="pinned" and "2.0.0" or nil})
            local lib,report=u:Load(); assert(lib.Version=="2.0.0" and report.Channel==channel and #state.Requests==2)
            assert(state.Requests[1]:find(channel=="pinned" and "dist/releases/2.0.0/manifest.json" or "dist/channels/"..channel.."/v2.json",1,true))
        end
    end)
    test("an unchanged loader receives a compatible new release then a channel rollback",function()
        local u,s=fixture({CurrentVersion="2.0.0"}); s.Source=source("2.1.0"); s.Manifest=manifest("2.1.0",s.Source)
        local lib=u:Load(); assert(lib.Version=="2.1.0")
        s.Source=source("2.0.1"); s.Manifest=manifest("2.0.1",s.Source)
        assert(u:Check().Version=="2.0.1" and u:GetStatus().State=="RollbackAvailable")
        lib=u:Load(); assert(lib.Version=="2.0.1")
    end)
    test("Preview accepts prereleases while Stable rejects them",function()
        local preview,s=fixture({Channel="preview",ReleaseVersion="2.1.0-rc.1"}); assert(preview:Load())
        s.Manifest.Channel="stable"; local stable=Core.New({Fetch=preview.Options.Fetch,MinVersion="2.0.0",MaxVersion="3.0.0"})
        assert(not stable:Load())
    end)
    test("wrong major API channel and semantic compatibility reject before compilation",function()
        for _,change in ipairs({function(m) m.Version="3.0.0" end,function(m) m.APIVersion=3 end,function(m) m.Channel="preview" end,function(m) m.Version="1.9.2" end,function(m) m.Version="2.0" end}) do
            local u,s=fixture({APIVersion=2}); change(s.Manifest); local value,err=u:Load(); assert(not value and err and #s.Requests==1)
        end
        local u=fixture({MinVersion="2.1.0"}); assert(not u:Load())
        u=fixture({MaxVersion="2.0.0"}); assert(not u:Load())
    end)
    test("Pinned refuses a different release even with valid content",function()
        local u,s=fixture({Channel="pinned",Version="2.0.0"}); s.Source=source("2.0.1"); s.Manifest=manifest("2.0.1",s.Source,nil,"pinned")
        assert(not u:Load() and #s.Requests==1)
    end)
    test("manifest and artifact corruption never execute the supplied bytes",function()
        local executed=0; local original=loadstring
        loadstring=function(...) executed=executed+1; return original(...) end
        for _,change in ipairs({function(s) s.Manifest.SchemaVersion=9 end,function(s) s.Manifest.Artifact.SHA256=("0"):rep(64) end,function(s) s.Manifest.Artifact.Bytes=1 end,function(s) s.Source=s.Source.." " end,function(s) s.Manifest.Artifact.Path="../foreign.lua" end,function(s) s.Manifest.Artifact.Path="https://foreign.test/code" end}) do
            local u,s=fixture(); change(s); assert(not u:Load())
        end
        assert(executed==0); loadstring=original
    end)
    test("empty malformed oversized and missing responses remain diagnostic",function()
        for _,bytes in ipairs({"","{broken",("x"):rep(65537),"null"}) do
            local u=Core.New({Fetch=function() return bytes end}); local lib,err=u:Load(); assert(not lib and err and u:GetStatus().State=="Failed")
        end
        local u,s=fixture(); s.Error="Network unavailable"; assert(not u:Load() and u:GetStatus().Error:find("Network unavailable",1,true))
        u,s=fixture(); local old=u.Options.Fetch; u.Options.Fetch=function(url) if url:sub(-5)~=".json" then error("404 artifact") end; return old(url) end
        assert(not u:Load() and u:GetStatus().Error:find("404 artifact",1,true))
    end)
    test("valid digests cannot hide compile init or self-reported version failures",function()
        for _,bytes in ipairs({"local",'error("init failure")','return {Version="2.0.1"}','return {Version="2.0.0",APIVersion=9}'}) do
            local u,s=fixture(); s.Source=bytes; s.Manifest=manifest("2.0.0",bytes); assert(not u:Load())
        end
    end)
    test("validated fallback reports the earlier version and rejects corrupted cache",function()
        local values={}; local cache={Get=function(_,k) return values[k] end,Set=function(_,k,v) values[k]=v end}
        local u,s=fixture({Cache=cache}); assert(u:Load()); s.Error="Offline"
        local lib,report=u:Load(); assert(lib.Version=="2.0.0" and report.State=="Fallback" and report.Fallback and report.Error:find("Offline",1,true))
        for _,entry in pairs(values) do entry.Source=entry.Source.."broken" end
        assert(not u:Load())
    end)
    test("cache separates configured origins and channels and fallback can be disabled",function()
        local values={}; local cache={Get=function(_,k) return values[k] end,Set=function(_,k,v) values[k]=v end}
        local a,s=fixture({Cache=cache,Root="https://updates.test/first"}); assert(a:Load())
        local b,t=fixture({Cache=cache,Root="https://updates.test/second"}); t.Error="Offline"; assert(not b:Load())
        s.Error="Offline"; a:SetChannel("preview"); assert(not a:Load())
        a:SetChannel("stable"); a.Options.Fallback=false; assert(not a:Load())
    end)
    test("session cache works without executor files and write errors are observable",function()
        local r,w,m=readfile,writefile,makefolder; readfile=nil; writefile=nil; makefolder=nil
        local u,s=fixture({Cache=true,Root="https://updates.test/session"}); assert(u:Load()); s.Error="Offline"; local _,status=u:Load(); assert(status.Cache=="session" and status.Fallback)
        readfile,writefile,makefolder=r,w,m
        local bad=fixture({Cache={Get=function() end,Set=function() error("Cache denied") end}}); assert(bad:Load()); assert(bad:GetStatus().CacheError:find("Cache denied",1,true))
    end)
    test("checks inspect metadata without downloading or replacing the active library",function()
        local u,s=fixture({CurrentVersion="2.0.0"}); local current=Library.Version
        assert(u:Check() and #s.Requests==1 and u:GetStatus().State=="UpToDate" and Library.Version==current)
        local snapshot=u:GetStatus(); snapshot.State="changed"; assert(u:GetStatus().State=="UpToDate")
    end)
    test("origins and artifacts require explicit HTTPS publishers without traversal",function()
        for _,root in ipairs({"http://updates.test/main","https://updates.test/a/../b","https://updates.test/a?x=1","https://updates.test/a%2fb"}) do assert(not pcall(Core.New,{Root=root})) end
        assert(not pcall(Core.New,{Kind="Hub",Major=1}))
        assert(not pcall(Core.New,{Channel="pinned"})); assert(not pcall(Core.New,{Channel="future"}))
    end)
    test("hub code versions stay independent and update only on a new load",function()
        local u,s=fixture({Kind="Hub",Root="https://updates.test/hub",Major=1,ReleaseVersion="1.1.0",MinVersion="1.0.0",MaxVersion="2.0.0",LibraryVersion=Library.Version,LibraryAPIVersion=2})
        local module=u:Load(); assert(module.Version=="1.1.0" and Library.Version=="2.0.0")
        local h=module.Start(Library); assert(h:GetVersion()=="1.1.0")
        s.Source=source("1.2.0","Hub"); s.Manifest=manifest("1.2.0",s.Source,"Hub")
        assert(u:Check().Version=="1.2.0" and h:GetVersion()=="1.1.0" and not h.Destroyed)
        local nextModule=u:Load(); assert(nextModule.Version=="1.2.0"); h.Window:Destroy(); Mock.pump(100); assert(Mock.Connections==0)
    end)
    test("hub code needs an authorized entry module and compatible RetroBox metadata",function()
        local u,s=fixture({Kind="Hub",Root="https://updates.test/hub",Major=1,ReleaseVersion="1.0.0",MinVersion="1.0.0",MaxVersion="2.0.0",LibraryVersion=Library.Version,LibraryAPIVersion=2})
        s.Manifest.Library.MinVersion="2.1.0"; assert(not u:Load())
        s.Manifest.Library=nil; assert(not u:Load())
        s.Manifest.Library={MinVersion="2.0.0",APIVersion=2}; s.Source='return {Version="1.0.0"}'; s.Manifest.Artifact.SHA256=Core.SHA256(s.Source); s.Manifest.Artifact.Bytes=#s.Source; assert(not u:Load())
    end)
    loadstring=oldLoad
    while #Mock.Warnings>warningBase do table.remove(Mock.Warnings) end
end
