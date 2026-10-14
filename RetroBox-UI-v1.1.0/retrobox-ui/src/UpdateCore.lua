-- RetroBox update protocol v1. Embedded into the standalone library and loader.
-- HTTPS origin is the publisher trust boundary. SHA-256 detects damaged bytes;
-- it is not a signature and does not protect a compromised publishing account.
local Core={ProtocolVersion=1,OfficialRoot="https://raw.githubusercontent.com/ManoGustavo0/RetroBox/main"}
local Client={}; Client.__index=Client
local function clone(value)
    if type(value)~="table" then return value end
    local out={}; for k,v in pairs(value) do out[k]=clone(v) end; return out
end
local function integer(n) return type(n)=="number" and n==n and n>=0 and n%1==0 and n<=9007199254740991 end
local function bounded(value,maximum,name)
    assert(type(value)=="string" and #value>0 and #value<=maximum,name.." must be bounded text"); return value
end
function Core.ParseVersion(value)
    bounded(value,128,"Version")
    local base,build=value:match("^(.-)%+(.+)$"); base=base or value
    if build then
        assert(not build:find("[^%w%.%-]") and not build:find("%.%.") and build:sub(1,1)~="." and build:sub(-1)~=".","Invalid semantic version build")
    end
    local numeric,pre=base:match("^(%d+%.%d+%.%d+)%-(.+)$"); numeric=numeric or base
    local a,b,c=numeric:match("^(%d+)%.(%d+)%.(%d+)$"); assert(a,"Expected MAJOR.MINOR.PATCH")
    local parts={a,b,c}; for _,part in ipairs(parts) do assert((#part==1 or part:sub(1,1)~="0") and integer(tonumber(part)),"Invalid semantic version number") end
    local prerelease={}
    if pre then
        assert(not pre:find("[^%w%.%-]") and not pre:find("%.%.") and pre:sub(1,1)~="." and pre:sub(-1)~=".","Invalid prerelease")
        for part in pre:gmatch("[^%.]+") do
            assert(not part:match("^%d+$") or #part==1 or part:sub(1,1)~="0","Prerelease numbers cannot have leading zeroes")
            prerelease[#prerelease+1]=part
        end
    end
    return {Major=tonumber(a),Minor=tonumber(b),Patch=tonumber(c),Prerelease=prerelease,Build=build,Text=value}
end
function Core.CompareVersions(a,b)
    a=Core.ParseVersion(a); b=Core.ParseVersion(b)
    for _,k in ipairs({"Major","Minor","Patch"}) do if a[k]~=b[k] then return a[k]<b[k] and -1 or 1 end end
    if #a.Prerelease==0 and #b.Prerelease==0 then return 0 end
    if #a.Prerelease==0 then return 1 elseif #b.Prerelease==0 then return -1 end
    for i=1,math.max(#a.Prerelease,#b.Prerelease) do
        local x,y=a.Prerelease[i],b.Prerelease[i]
        if x==nil then return -1 elseif y==nil then return 1 elseif x~=y then
            local xn,yn=x:match("^%d+$"),y:match("^%d+$")
            if xn and yn then
                if #x~=#y then return #x<#y and -1 or 1 end
                return x<y and -1 or 1
            elseif xn then return -1 elseif yn then return 1 end
            return x<y and -1 or 1
        end
    end
    return 0
end
function Core.SHA256(source)
    assert(type(source)=="string","SHA256 needs bytes")
    assert(type(bit32)=="table" and type(bit32.bxor)=="function","SHA-256 needs the Luau bit32 library")
    local band,bxor,bnot,rshift,ror=bit32.band,bit32.bxor,bit32.bnot,bit32.rshift,bit32.rrotate
    local constants={
        0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,
        0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
        0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,
        0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
        0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,
        0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
        0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,
        0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2,
    }
    local h={0x6a09e667,0xbb67ae85,0x3c6ef372,0xa54ff53a,0x510e527f,0x9b05688c,0x1f83d9ab,0x5be0cd19}
    local function word(n) return string.char(rshift(n,24),band(rshift(n,16),255),band(rshift(n,8),255),band(n,255)) end
    local bits=#source*8
    local padded=source.."\128"..string.rep("\0",(55-#source)%64)..word(math.floor(bits/4294967296))..word(bits%4294967296)
    for offset=1,#padded,64 do
        local w={}
        for i=0,15 do local a,b,c,d=padded:byte(offset+i*4,offset+i*4+3); w[i+1]=a*16777216+b*65536+c*256+d end
        for i=17,64 do
            local x,y=w[i-15],w[i-2]
            local s0=bxor(ror(x,7),ror(x,18),rshift(x,3)); local s1=bxor(ror(y,17),ror(y,19),rshift(y,10))
            w[i]=(w[i-16]+s0+w[i-7]+s1)%4294967296
        end
        local a,b,c,d,e,f,g,j=table.unpack(h)
        for i=1,64 do
            local s1=bxor(ror(e,6),ror(e,11),ror(e,25)); local ch=bxor(band(e,f),band(bnot(e),g))
            local t1=(j+s1+ch+constants[i]+w[i])%4294967296
            local s0=bxor(ror(a,2),ror(a,13),ror(a,22)); local maj=bxor(band(a,b),band(a,c),band(b,c))
            local t2=(s0+maj)%4294967296
            j,g,f,e,d,c,b,a=g,f,e,(d+t1)%4294967296,c,b,a,(t1+t2)%4294967296
        end
        local v={a,b,c,d,e,f,g,j}; for i=1,8 do h[i]=(h[i]+v[i])%4294967296 end
    end
    local out={}; for i=1,8 do out[i]=string.format("%08x",h[i]) end; return table.concat(out)
end
local function path(value)
    bounded(value,512,"Artifact path")
    assert(not value:find("[^%w_%.%/%-]") and value:sub(1,1)~="/" and value:sub(-1)~="/" and not value:find("//",1,true),"Only origin-relative paths are allowed")
    for segment in value:gmatch("[^/]+") do assert(segment~="." and segment~="..","Path traversal is forbidden") end
    return value
end
local function channel(value)
    assert(value=="stable" or value=="preview" or value=="pinned","Channel must be stable, preview or pinned"); return value
end
local function json(service,bytes,limit)
    assert(type(bytes)=="string" and #bytes>0 and #bytes<=limit,"Response is empty or exceeds its size limit")
    local value=service:JSONDecode(bytes); assert(type(value)=="table","Expected a JSON record"); return value
end
local function validate(client,m)
    local o=client.Options
    assert(type(m)=="table" and m.SchemaVersion==1 and m.Kind==o.Kind,"Unsupported distribution manifest")
    local version=Core.ParseVersion(m.Version)
    assert(version.Major==o.Major,"Incompatible release major")
    assert(o.Channel~="stable" or #version.Prerelease==0,"Stable cannot resolve a prerelease")
    assert(o.Channel=="pinned" or m.Channel==o.Channel,"Manifest belongs to a different channel")
    assert(o.Channel~="pinned" or m.Version==o.Version,"Pinned manifest does not match the requested version")
    assert(integer(m.APIVersion) and (not o.APIVersion or m.APIVersion==o.APIVersion),"Incompatible API version")
    if o.MinVersion then assert(Core.CompareVersions(m.Version,o.MinVersion)>=0,"Release is below MinVersion") end
    if o.MaxVersion then assert(Core.CompareVersions(m.Version,o.MaxVersion)<0,"Release is at or above exclusive MaxVersion") end
    if o.HubId then assert(m.HubId==o.HubId,"Manifest belongs to a different hub") end
    bounded(m.Build,128,"Build")
    local a=m.Artifact; assert(type(a)=="table","Artifact metadata is missing"); path(a.Path)
    assert(type(a.SHA256)=="string" and #a.SHA256==64 and a.SHA256:match("^[0-9a-f]+$"),"Invalid SHA-256 digest")
    assert(integer(a.Bytes) and a.Bytes>0 and a.Bytes<=o.MaxArtifactBytes,"Invalid artifact length")
    assert(o.Kind=="RetroBox" or type(m.Library)=="table","Hub manifest needs RetroBox compatibility metadata")
    if m.Library then
        assert(type(m.Library)=="table" and type(o.LibraryVersion)=="string","Library compatibility cannot be determined")
        assert(type(m.Library.MinVersion)=="string" and integer(m.Library.APIVersion),"Hub manifest needs a minimum RetroBox version and API")
        if m.Library.MinVersion then assert(Core.CompareVersions(o.LibraryVersion,m.Library.MinVersion)>=0,"Hub needs a newer RetroBox") end
        if m.Library.MaxVersion then assert(Core.CompareVersions(o.LibraryVersion,m.Library.MaxVersion)<0,"Hub does not support this RetroBox") end
        if m.Library.APIVersion then assert(m.Library.APIVersion==o.LibraryAPIVersion,"Hub needs a different RetroBox API") end
    end
    return clone(m)
end
function Core.New(options)
    options=options or {}; assert(type(options)=="table","Updater options must be a table")
    local o={}; for k,v in pairs(options) do o[k]=v end
    o.Channel=channel(o.Channel or "stable"); o.Kind=o.Kind or "RetroBox"; o.Major=o.Major or 2
    o.APIVersion=o.APIVersion or (o.Kind=="RetroBox" and 2 or 1)
    assert(o.Kind=="RetroBox" or o.Kind=="Hub" or o.Kind=="HubCatalog","Unsupported update kind")
    assert(integer(o.Major) and o.Major>0,"Major must be a positive integer")
    if o.Kind~="RetroBox" then assert(o.Root,"Hub updates need an explicit publisher Root") end
    o.Root=bounded(o.Root or Core.OfficialRoot,1024,"Root"):gsub("/+$","")
    assert(o.Root:match("^https://[%w%.%-]+/[A-Za-z0-9_%.%/%-]+$") and not o.Root:find("/%.%./") and not o.Root:find("/%.%./?$"),"Root must be an explicit HTTPS origin and path without traversal")
    if o.Version then Core.ParseVersion(o.Version) end
    assert(o.Channel~="pinned" or o.Version,"Pinned needs Version")
    if o.CurrentVersion then Core.ParseVersion(o.CurrentVersion) end
    if o.MinVersion then Core.ParseVersion(o.MinVersion) end; if o.MaxVersion then Core.ParseVersion(o.MaxVersion) end
    assert(o.APIVersion==nil or integer(o.APIVersion),"APIVersion must be an integer")
    if o.ManifestPath then path(o.ManifestPath) end
    o.MaxArtifactBytes=o.MaxArtifactBytes or (o.Kind=="HubCatalog" and 524288 or 2097152)
    assert(integer(o.MaxArtifactBytes) and o.MaxArtifactBytes>=1 and o.MaxArtifactBytes<=8388608,"MaxArtifactBytes must be 1–8388608")
    o.Service=o.Service or game:GetService("HttpService")
    o.Fetch=o.Fetch or function(url)
        local ok,fn=pcall(function() return game.HttpGet end); assert(ok and type(fn)=="function","Environment does not provide HttpGet")
        return fn(game,url,true)
    end
    assert(type(o.Fetch)=="function","Fetch must be a developer function")
    assert(o.Cache==nil or o.Cache==false or o.Cache==true or type(o.Cache)=="table","Cache must be boolean or an adapter")
    if type(o.Cache)=="table" then assert(type(o.Cache.Get)=="function" and type(o.Cache.Set)=="function","Cache needs Get and Set") end
    local self=setmetatable({Options=o,Report={State="Idle",Channel=o.Channel,CurrentVersion=o.CurrentVersion,Kind=o.Kind,Root=o.Root}},Client)
    return self
end
function Client:GetStatus() return clone(self.Report) end
function Client:SetChannel(value,version)
    assert(not self._busy,"Cannot change channel during an update operation")
    value=channel(value); if version then Core.ParseVersion(version) end
    assert(value~="pinned" or version or self.Options.Version,"Pinned needs Version")
    self.Options.Channel=value; if version then self.Options.Version=version end
    self._manifest=nil; self.Report={State="Idle",Channel=value,CurrentVersion=self.Options.CurrentVersion,Kind=self.Options.Kind,Root=self.Options.Root}
    return self
end
function Client:_manifestPath()
    if self.Options.ManifestPath then return self.Options.ManifestPath end
    if self.Options.Channel=="pinned" then return "dist/releases/"..self.Options.Version.."/manifest.json" end
    return "dist/channels/"..self.Options.Channel.."/v"..self.Options.Major..".json"
end
function Client:Check()
    if self._busy then return nil,"Update operation is already running" end
    self._busy=true; self.Report.State="Checking"; self.Report.LastCheck=os.time(); self.Report.Error=nil
    self.Report.Compatible=nil; self.Report.AvailableVersion=nil; self.Report.Build=nil
    local ok,result=pcall(function() return validate(self,json(self.Options.Service,self.Options.Fetch(self.Options.Root.."/"..self:_manifestPath()),65536)) end)
    self._busy=false
    if not ok then self.Report.State="Failed"; self.Report.Error=tostring(result); return nil,self.Report.Error end
    self._manifest=result; self.Report.AvailableVersion=result.Version; self.Report.Build=result.Build; self.Report.Compatible=true
    local current=self.Options.CurrentVersion
    local comparison=current and Core.CompareVersions(result.Version,current) or 1
    self.Report.State=comparison==0 and "UpToDate" or comparison<0 and "RollbackAvailable" or "Available"
    return clone(result)
end
function Client:_cacheKey()
    local o=self.Options
    return Core.SHA256(o.Root.."|"..self:_manifestPath().."|"..o.Kind.."|"..tostring(o.HubId or ""))
end
function Client:_cache(get,value)
    local o=self.Options; if not o.Cache then return nil end
    local key=self:_cacheKey()
    if type(o.Cache)=="table" then if get then return o.Cache:Get(key) else return o.Cache:Set(key,value) end end
    local env=_G; if type(getgenv)=="function" then local ok,v=pcall(getgenv); if ok and type(v)=="table" then env=v end end
    env.__RetroBoxUpdateCache=env.__RetroBoxUpdateCache or {}; local memory=env.__RetroBoxUpdateCache
    self.Report.Cache="session"
    local fileMode=type(readfile)=="function" and type(writefile)=="function" and type(makefolder)=="function"
    if fileMode then
        local folder=path(o.CacheFolder or "RetroBox/Updates"); local filename=folder.."/"..key..".json"
        self.Report.Cache="file"
        if get then
            if memory[key] then return clone(memory[key]) end
            local ok,bytes=pcall(readfile,filename)
            if ok then return json(o.Service,bytes,o.MaxArtifactBytes*3+65536) end
        else
            local accumulated=""; for segment in folder:gmatch("[^/]+") do accumulated=accumulated=="" and segment or accumulated.."/"..segment; pcall(makefolder,accumulated) end
            writefile(filename,o.Service:JSONEncode(value)); memory[key]=clone(value)
        end
    elseif get then return clone(memory[key]) else memory[key]=clone(value) end
end
function Client:_verified(m,bytes,mode)
    m=validate(self,m)
    assert(type(bytes)=="string" and #bytes==m.Artifact.Bytes and #bytes<=self.Options.MaxArtifactBytes,"Artifact length differs from the manifest")
    assert(Core.SHA256(bytes)==m.Artifact.SHA256,"Artifact SHA-256 does not match")
    if mode=="json" then
        assert(m.Kind=="HubCatalog","Only catalogs can be loaded as JSON")
        local value=json(self.Options.Service,bytes,self.Options.MaxArtifactBytes)
        assert(value.SchemaVersion==1 and value.Kind=="HubCatalog" and value.Version==m.Version and value.HubId==m.HubId,"Catalog does not match its manifest")
        if self.Options.ValidateData then assert(self.Options.ValidateData(value,m)==true,"Catalog validation failed") end
        return value,m
    end
    assert(type(loadstring)=="function","Environment does not provide loadstring")
    local chunk,reason=loadstring(bytes,"@RetroBox-"..m.Kind.."-"..m.Version); assert(chunk,"Artifact compilation failed: "..tostring(reason))
    local value=chunk()
    assert(type(value)=="table" and value.Version==m.Version,"Artifact reports a different version")
    if m.Kind=="RetroBox" then assert(type(value.CreateWindow)=="function" and type(value.CreateScriptHub)=="function" and value.APIVersion==m.APIVersion,"Artifact does not implement the declared RetroBox API")
    elseif m.Kind=="Hub" then assert(type(value.Start)=="function","Hub module must return Version and Start")
    else error("A catalog must be loaded as data") end
    return value,m
end
function Client:Load(mode)
    assert(mode==nil or mode=="json","Load mode must be json or omitted")
    local m,checkError=self:Check(); if self._busy then return nil,checkError end
    self._busy=true
    local ok,value,verified,bytes=pcall(function()
        assert(m,checkError); local source=self.Options.Fetch(self.Options.Root.."/"..m.Artifact.Path)
        local item,manifest=self:_verified(m,source,mode); return item,manifest,source
    end)
    if ok then
        self.Report.State="Loaded"; self.Report.CurrentVersion=verified.Version; self.Report.AvailableVersion=verified.Version; self.Report.Fallback=false; self.Report.Error=nil
        self.Options.CurrentVersion=verified.Version
        local saved,reason=pcall(self._cache,self,false,{Manifest=verified,Source=bytes,Root=self.Options.Root})
        if not saved then self.Report.CacheError=tostring(reason) end
        self._busy=false; return value,self:GetStatus()
    end
    local liveError=tostring(value)
    if self.Options.Cache and self.Options.Fallback~=false then
        local recovered,item,manifest=pcall(function()
            local cached=self:_cache(true); assert(type(cached)=="table" and cached.Root==self.Options.Root,"No validated cache for this origin")
            return self:_verified(cached.Manifest,cached.Source,mode)
        end)
        if recovered then
            self.Report.State="Fallback"; self.Report.CurrentVersion=manifest.Version; self.Report.Fallback=true; self.Report.Error=liveError
            self.Options.CurrentVersion=manifest.Version; self._busy=false
            warn("[RetroBox] Using validated cached "..self.Options.Kind.." "..manifest.Version..": "..liveError)
            return item,self:GetStatus()
        end
        self.Report.CacheError=tostring(item)
    end
    self.Report.State="Failed"; self.Report.Error=liveError; self._busy=false; return nil,liveError
end
Core.Client=Client
return Core
