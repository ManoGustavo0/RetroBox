-- Public update APIs. All network work is explicit or opted into by the hub.
do
    Library.APIVersion=2
    Library.Build="retrobox-"..Library.Version
    Library.MinimumVersion="2.0.0"
    Library.MaximumVersion="3.0.0" -- exclusive
    function Library:GetVersion() return self.Version end
    function Library:ParseVersion(value) return UpdateCore.ParseVersion(value) end
    function Library:CompareVersions(a,b) return UpdateCore.CompareVersions(a,b) end
    function Library:SHA256(bytes) return UpdateCore.SHA256(bytes) end
    function Library:CreateUpdater(options) return UpdateCore.New(options) end
    function Library:CheckForUpdates(options)
        if options or not self._distributionUpdater then
            local settings={}; for k,v in pairs(options or {}) do settings[k]=v end
            settings.Kind="RetroBox"; settings.Major=2; settings.APIVersion=2; settings.CurrentVersion=self.Version
            settings.MinVersion=settings.MinVersion or "2.0.0"; settings.MaxVersion=settings.MaxVersion or "3.0.0"
            self._distributionUpdater=UpdateCore.New(settings)
        end
        local _,reason=self._distributionUpdater:Check()
        return self._distributionUpdater:GetStatus(),reason
    end
    function Library:GetUpdateStatus()
        return self._distributionUpdater and self._distributionUpdater:GetStatus() or {State="Idle",CurrentVersion=self.Version,Channel="stable",Kind="RetroBox"}
    end
    function Library:LoadHub(options)
        assert(type(options)=="table" and options.Root,"LoadHub needs an explicit publisher Root")
        local settings={}; for k,v in pairs(options) do if k~="Settings" then settings[k]=v end end
        settings.Kind="Hub"; settings.Major=options.Major or 1; settings.LibraryVersion=self.Version; settings.LibraryAPIVersion=self.APIVersion
        local updater=UpdateCore.New(settings)
        local module,report=updater:Load()
        if not module then return nil,report end
        local ok,hub=pcall(module.Start,self,options.Settings or {})
        if not ok then return nil,"Hub initialization failed: "..tostring(hub) end
        if type(hub)~="table" or not hub.Window or type(hub.RunScript)~="function" then return nil,"Hub Start did not return a Script Hub" end
        hub.Version=module.Version; hub.CodeDistribution=report; hub._codeUpdater=updater
        return hub,report
    end
end
