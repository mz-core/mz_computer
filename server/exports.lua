exports('RegisterApp', function(descriptor)
    return MZComputer.Apps.register(descriptor, GetInvokingResource())
end)

exports('UnregisterApp', function(appId)
    return MZComputer.Apps.unregister(appId, GetInvokingResource())
end)

exports('RegisterSite', function(descriptor)
    return MZComputer.Sites.register(descriptor, GetInvokingResource())
end)

exports('UnregisterSite', function(siteId)
    return MZComputer.Sites.unregister(siteId, GetInvokingResource())
end)

exports('PushNotification', function(accountId, notification)
    return MZComputer.Notifications.push(accountId, notification)
end)

exports('GetSessionContext', function(source)
    return MZComputer.Sessions.public(MZComputer.Sessions.getBySource(source))
end)

exports('HasComputerPermission', function(source, permission)
    return MZComputer.Permissions.has(source, permission, MZComputer.Devices.context(source))
end)

exports('OpenComputer', function(source, options)
    options = type(options) == 'table' and options or {}
    local physicalKey = MZComputer.Validation.string(options.physicalKey, 1, 160)
    if not physicalKey then
        local identity = MZComputer.Identity.resolve(source)
        if not identity then return false, 'identity_unavailable' end
        physicalKey = ('resource:%s:citizen:%s'):format(GetInvokingResource() or 'unknown', identity.citizenid)
    end
    local device, err = MZComputer.Devices.getOrCreatePersonal(source, physicalKey)
    if not device then return false, err end
    return MZComputer.Devices.authorizePersonalUse(source, device)
end)

exports('OpenApp', function(source, appId)
    if not MZComputer.Sessions.getBySource(source) then return false, 'no_session' end
    if not MZComputer.Apps.canOpen(source, appId) then return false, MZComputer.Const.Error.APP_FORBIDDEN end
    TriggerClientEvent('mz_computer:client:openApp', source, appId)
    return true
end)
