-- Minimal engine double. Exercises library logic; does not render Roblox UI.
local Mock = { Connections=0, Queue={}, Time=0, Warnings={} }
math.atan2=math.atan -- Lua 5.4 equivalent of the Luau built-in used by chart segments.
os.clock=function() return Mock.Time end
function typeof(value)
    if type(value)=="table" and getmetatable(value) and getmetatable(value).__type then return getmetatable(value).__type end
    return type(value)
end
function table.find(t,value) for i,v in ipairs(t) do if v==value then return i end end end
function warn(message) table.insert(Mock.Warnings,tostring(message)) end
local function signal()
    local s={ listeners={} }
    function s:Connect(callback)
        local connection={ Connected=true,Callback=callback }
        Mock.Connections=Mock.Connections+1
        function connection:Disconnect(automatic)
            if not automatic then self._explicitDisconnected=true end
            if self.Connected then self.Connected=false; Mock.Connections=Mock.Connections-1 end
        end
        table.insert(self.listeners,connection)
        return connection
    end
    function s:Fire(...)
        local snapshot={table.unpack(self.listeners)}
        for _,c in ipairs(snapshot) do if c.Connected then c.Callback(...) end end
    end
    function s:FireDeferred(...)
        local snapshot,args={},table.pack(...)
        for _,c in ipairs(self.listeners) do if c.Connected then snapshot[#snapshot+1]=c end end
        task.defer(function()
            for _,c in ipairs(snapshot) do if not c._explicitDisconnected then c.Callback(table.unpack(args,1,args.n)) end end
        end)
    end
    function s:DisconnectAll(automatic) for _,c in ipairs(self.listeners) do c:Disconnect(automatic) end end
    return s
end
Mock.signal=signal
task={}
function task.spawn(fn,...) table.insert(Mock.Queue,{ Due=Mock.Time,Fn=fn,Args=table.pack(...) }) end
task.defer=task.spawn
function task.delay(seconds,fn,...) table.insert(Mock.Queue,{ Due=Mock.Time+seconds,Fn=fn,Args=table.pack(...) }) end
function task.wait(seconds)
    if Mock.YieldingTasks then local _,main=coroutine.running(); if not main then return coroutine.yield(seconds or .03) end end
    Mock.Time=Mock.Time+(seconds or .03)
end
function Mock.pump(advance)
    Mock.Time=Mock.Time+(advance or 0)
    local passes=0
    while true do
        local nextIndex,nextDue
        for index,item in ipairs(Mock.Queue) do
            if item.Due<=Mock.Time and (not nextDue or item.Due<nextDue) then nextIndex=index; nextDue=item.Due end
        end
        if not nextIndex then break end
        local item=table.remove(Mock.Queue,nextIndex)
        if Mock.YieldingTasks then
            item.Thread=item.Thread or coroutine.create(item.Fn)
            local ok,delay=coroutine.resume(item.Thread,table.unpack(item.Args,1,item.Args.n))
            assert(ok,delay)
            if coroutine.status(item.Thread)~="dead" then item.Due=Mock.Time+(delay or 0); item.Args=table.pack(); table.insert(Mock.Queue,item) end
        else item.Fn(table.unpack(item.Args,1,item.Args.n)) end
        passes=passes+1; assert(passes<10000,"Runaway task queue")
    end
end
Enum=setmetatable({},{ __index=function(container,enumName)
    local enum=setmetatable({ Name=enumName },{
        __index=function(e,name)
            local value=setmetatable({ Name=name,EnumType=e },{ __type="EnumItem" })
            rawset(e,name,value); return value
        end,
    })
    rawset(container,enumName,enum); return enum
end })
local vectorMT={ __type="Vector2" }
vectorMT.__add=function(a,b) return Vector2.new(a.X+b.X,a.Y+b.Y) end
vectorMT.__sub=function(a,b) return Vector2.new(a.X-b.X,a.Y-b.Y) end
vectorMT.__mul=function(a,b) if type(a)=="number" then return Vector2.new(a*b.X,a*b.Y) end; return Vector2.new(a.X*b,a.Y*b) end
vectorMT.__div=function(a,b) return Vector2.new(a.X/b,a.Y/b) end
Vector2={new=function(x,y) return setmetatable({X=x,Y=y},vectorMT) end}
UDim={new=function(scale,offset) return {Scale=scale,Offset=offset} end}
UDim2={}
function UDim2.new(xs,xo,ys,yo) return { X=UDim.new(xs or 0,xo or 0),Y=UDim.new(ys or 0,yo or 0) } end
function UDim2.fromOffset(x,y) return UDim2.new(0,x,0,y) end
function UDim2.fromScale(x,y) return UDim2.new(x,0,y,0) end
local colorMT={ __type="Color3" }
colorMT.__eq=function(a,b) return a.R==b.R and a.G==b.G and a.B==b.B end
colorMT.__index=colorMT
Color3={}
function Color3.new(r,g,b) return setmetatable({R=r,G=g,B=b},colorMT) end
function Color3.fromRGB(r,g,b) return Color3.new(r/255,g/255,b/255) end
function Color3.fromHSV(h,s,v)
    local i=math.floor(h*6); local f=h*6-i
    local p,q,t=v*(1-s),v*(1-f*s),v*(1-(1-f)*s)
    local choices={{v,t,p},{q,v,p},{p,v,t},{p,q,v},{t,p,v},{v,p,q}}
    return Color3.new(table.unpack(choices[i%6+1]))
end
function colorMT:ToHSV()
    local min,max=math.min(self.R,self.G,self.B),math.max(self.R,self.G,self.B)
    local delta=max-min; local h=0
    if delta~=0 then
        if max==self.R then h=((self.G-self.B)/delta)%6
        elseif max==self.G then h=(self.B-self.R)/delta+2 else h=(self.R-self.G)/delta+4 end
        h=h/6
    end
    return h,max==0 and 0 or delta/max,max
end
NumberSequence={new=function(value) return value end}
NumberSequenceKeypoint={new=function(time,value) return {Time=time,Value=value} end}
ColorSequence={new=function(value) return value end}
ColorSequenceKeypoint={new=NumberSequenceKeypoint.new}
TweenInfo={new=function(time) return {Time=time} end}

local instanceMethods={}
local instanceMT={ __type="Instance" }
local eventNames={Activated=true,InputBegan=true,InputChanged=true,InputEnded=true,Focused=true,FocusLost=true,Destroying=true,MouseEnter=true,MouseLeave=true,TouchLongPress=true}
function instanceMT.__index(self,key)
    if instanceMethods[key] then return instanceMethods[key] end
    if self._props[key]~=nil then return self._props[key] end
    if eventNames[key] then self._signals[key]=self._signals[key] or signal(); return self._signals[key] end
    if key=="AbsoluteSize" then
        if self.ClassName=="ScreenGui" or self.ClassName=="PlayerGui" then return Mock.Viewport end
        local size=self._props.Size or UDim2.fromOffset(100,100)
        local parent=self._props.Parent
        local ps=parent and parent.AbsoluteSize or Mock.Viewport
        return Vector2.new(size.X.Scale*ps.X+size.X.Offset,size.Y.Scale*ps.Y+size.Y.Offset)
    end
    if key=="AbsolutePosition" then return Vector2.new(0,0) end
    if key=="AbsoluteCanvasSize" then return self.AbsoluteSize end
    if key=="AbsoluteContentSize" then return Vector2.new(100,100) end
    if key=="Text" then return "" end
    if key=="ZIndex" then return 1 end
    if key=="Visible" then return true end
end
function instanceMT.__newindex(self,key,value)
    local old=self._props[key]
    if key=="Parent" and old~=value then
        assert(not value or not value._rejectGuiParent,"Mock parent denied GUI access")
        if old then local i=table.find(old._children,self); if i then table.remove(old._children,i) end end
        if value then table.insert(value._children,self) end
    end
    self._props[key]=value
    if old~=value and self._signals["property/"..key] then self._signals["property/"..key]:Fire() end
end
Instance={}
function Instance.new(class)
    return setmetatable({ClassName=class,_props={},_children={},_signals={},_attributes={}},instanceMT)
end
function instanceMethods:IsA(class)
    return self.ClassName==class or class=="Instance" or class=="GuiObject" and (
        self.ClassName=="Frame" or self.ClassName=="TextButton" or self.ClassName=="TextBox" or
        self.ClassName=="TextLabel" or self.ClassName=="ImageLabel" or self.ClassName=="ScrollingFrame")
end
function instanceMethods:GetChildren() return {table.unpack(self._children)} end
function instanceMethods:GetDescendants()
    local result={}
    for _,c in ipairs(self._children) do table.insert(result,c); for _,d in ipairs(c:GetDescendants()) do table.insert(result,d) end end
    return result
end
function instanceMethods:FindFirstChild(name) for _,c in ipairs(self._children) do if c.Name==name then return c end end end
function instanceMethods:WaitForChild(name) return assert(self:FindFirstChild(name),"Missing child: "..name) end
function instanceMethods:SetAttribute(name,value) self._attributes[name]=value end
function instanceMethods:GetAttribute(name) return self._attributes[name] end
function instanceMethods:GetPropertyChangedSignal(name)
    self._signals["property/"..name]=self._signals["property/"..name] or signal()
    return self._signals["property/"..name]
end
function instanceMethods:IsFocused() return Mock.Focused==self end
function instanceMethods:CaptureFocus() Mock.Focused=self; self.Focused:Fire() end
function instanceMethods:ReleaseFocus()
    if Mock.Focused==self then Mock.Focused=nil; self.FocusLost:Fire(false) end
end
function instanceMethods:Destroy()
    if self._destroying or self._destroyed then return end
    self._destroying=true
    -- Engine destruction disconnects signals but retains already queued calls;
    -- explicit Disconnect drops them. See Creator Hub deferred-events docs.
    if Mock.DeferDestroying then self.Destroying:FireDeferred() else self.Destroying:Fire() end
    for _,child in ipairs(self:GetChildren()) do child:Destroy() end
    for _,s in pairs(self._signals) do s:DisconnectAll(true) end
    self.Parent=nil; self._destroyed=true; self._destroying=false
end

local function quote(s)
    return '"'..s:gsub('[%z\1-\31\\"]',function(c)
        local map={['"']='\\"',['\\']='\\\\',['\n']='\\n',['\r']='\\r',['\t']='\\t'}
        return map[c] or string.format("\\u%04x",c:byte())
    end)..'"'
end
local function jsonEncode(value)
    if value==nil then return "null" end
    if type(value)=="string" then return quote(value) end
    if type(value)=="boolean" or type(value)=="number" then return tostring(value) end
    assert(type(value)=="table","Unsupported JSON value")
    local parts={}
    if #value>0 then
        for _,v in ipairs(value) do table.insert(parts,jsonEncode(v)) end
        return "["..table.concat(parts,",").."]"
    end
    for k,v in pairs(value) do table.insert(parts,quote(tostring(k))..":"..jsonEncode(v)) end
    table.sort(parts); return "{"..table.concat(parts,",").."}"
end
local function jsonDecode(text)
    local i=1
    local function space() local _,last=text:find("^%s*",i); i=(last or i-1)+1 end
    local parse
    local function str()
        assert(text:sub(i,i)=='"'); i=i+1; local result={}
        while i<=#text do
            local c=text:sub(i,i); i=i+1
            if c=='"' then return table.concat(result) end
            if c=='\\' then
                local e=text:sub(i,i); i=i+1
                local map={['"']='"',['\\']='\\',['/']='/',b='\b',f='\f',n='\n',r='\r',t='\t'}
                if e=='u' then local code=tonumber(text:sub(i,i+3),16); assert(code); i=i+4; c=utf8.char(code)
                else c=assert(map[e],"Invalid escape") end
            end
            table.insert(result,c)
        end
        error("Unterminated string")
    end
    parse=function()
        space(); local c=text:sub(i,i)
        if c=='"' then return str() end
        if c=='{' or c=='[' then
            local object=c=='{'; local ending=object and '}' or ']'; i=i+1; space(); local result={}
            if text:sub(i,i)==ending then i=i+1; return result end
            repeat
                space()
                if object then local key=str(); space(); assert(text:sub(i,i)==':'); i=i+1; result[key]=parse()
                else table.insert(result,parse()) end
                space(); local sep=text:sub(i,i); i=i+1
                if sep==ending then break end
                assert(sep==',',"Expected comma")
            until false
            return result
        end
        for token,value in pairs({["true"]=true,["false"]=false}) do
            if text:sub(i,i+#token-1)==token then i=i+#token; return value end
        end
        if text:sub(i,i+3)=="null" then i=i+4; return nil end
        local number=text:match("^-?%d+%.?%d*[eE]?[+-]?%d*",i)
        assert(number and #number>0,"Invalid JSON")
        i=i+#number; return assert(tonumber(number))
    end
    local value=parse(); space(); assert(i>#text,"Trailing input"); return value
end
Mock.Viewport=Vector2.new(1280,720)
local player=Instance.new("Player")
player.Name="TestUser"; player.DisplayName="Test Player"; player.UserId=42
local playerGui=Instance.new("PlayerGui"); playerGui.Name="PlayerGui"; playerGui.Parent=player
local services={
    Players={LocalPlayer=player,GetUserThumbnailAsync=function() return "rbxthumb://test-avatar",true end},
    UserInputService={InputBegan=signal(),InputChanged=signal(),InputEnded=signal(),WindowFocusReleased=signal(),
        GetMouseLocation=function() return Mock.MousePosition or Vector2.new(50,50) end,GetFocusedTextBox=function() return Mock.Focused end},
    RunService={Heartbeat=signal(),RenderStepped=signal(),IsClient=function() return true end},
    HttpService={JSONEncode=function(_,value) return jsonEncode(value) end,JSONDecode=function(_,value) return jsonDecode(value) end,
        GenerateGUID=function() return "test-"..tostring(math.random(1,1000000)) end},
    TweenService={Create=function(_,object,info,properties)
        local tween={Completed=signal(),PlaybackState=Enum.PlaybackState.Begin}
        function tween:Play()
            self.PlaybackState=Enum.PlaybackState.Playing
            local function complete()
                if self.PlaybackState~=Enum.PlaybackState.Playing then return end
                for k,v in pairs(properties) do object[k]=v end
                self.PlaybackState=Enum.PlaybackState.Completed; self.Completed:Fire(self.PlaybackState)
            end
            if Mock.AnimatedTweens then task.delay(info.Time,complete) else complete() end
        end
        function tween:Cancel() self.PlaybackState=Enum.PlaybackState.Cancelled; self.Completed:Fire(self.PlaybackState) end
        function tween:Destroy() self.Completed:DisconnectAll(); self.Destroyed=true end
        return tween
    end},
    TextService={GetTextSize=function(_,text,size,_,bounds)
        local lines=0
        for line in (text.."\n"):gmatch("(.-)\n") do lines=lines+math.max(1,math.ceil(#line*size*.6/bounds.X)) end
        return Vector2.new(bounds.X,lines*(size+2))
    end},
}
game={GetService=function(_,name) return assert(services[name],"Unknown service: "..name) end}
workspace={CurrentCamera={ViewportSize=Mock.Viewport}}
Mock.Services=services
return Mock
