MZComputerClient = MZComputerClient or {
    open = false,
    device = nil,
    sessionToken = nil,
    prop = nil,
    camera = nil,
    terminals = {},
    closing = false
}

function MZComputerClient.resetSession()
    MZComputerClient.sessionToken = nil
end
