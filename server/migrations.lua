MZComputer = MZComputer or {}
local Migrations = {}

local function stripComments(sql)
    local lines = {}
    for line in sql:gmatch('[^\r\n]+') do
        if not line:match('^%s*%-%-') then lines[#lines + 1] = line end
    end
    return table.concat(lines, '\n')
end

local function splitStatements(sql)
    sql = stripComments(sql)
    local out, buffer, quote = {}, {}, nil
    local i = 1
    while i <= #sql do
        local ch = sql:sub(i, i)
        local nextCh = sql:sub(i + 1, i + 1)
        if quote then
            buffer[#buffer + 1] = ch
            if ch == quote then
                if nextCh == quote then
                    buffer[#buffer + 1] = nextCh
                    i = i + 1
                elseif sql:sub(i - 1, i - 1) ~= '\\' then
                    quote = nil
                end
            end
        else
            if ch == "'" or ch == '"' or ch == '`' then
                quote = ch
                buffer[#buffer + 1] = ch
            elseif ch == ';' then
                local statement = table.concat(buffer):gsub('^%s+', ''):gsub('%s+$', '')
                if statement ~= '' then out[#out + 1] = statement end
                buffer = {}
            else
                buffer[#buffer + 1] = ch
            end
        end
        i = i + 1
    end
    local tail = table.concat(buffer):gsub('^%s+', ''):gsub('%s+$', '')
    if tail ~= '' then out[#out + 1] = tail end
    return out
end

function Migrations.run()
    local tableName = Config.Database.migrationsTable
    MySQL.query.await(([=[
        CREATE TABLE IF NOT EXISTS `%s` (
            `migration` VARCHAR(128) NOT NULL,
            `applied_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`migration`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]=]):format(tableName))

    local appliedRows = MySQL.query.await(('SELECT `migration` FROM `%s`'):format(tableName)) or {}
    local applied = {}
    for _, row in ipairs(appliedRows) do applied[row.migration] = true end

    for _, path in ipairs(Config.Database.migrationFiles) do
        if not applied[path] then
            local sql = LoadResourceFile(GetCurrentResourceName(), path)
            if not sql then error(('Migration file not found: %s'):format(path)) end
            local statements = splitStatements(sql)
            print(('[mz_computer] Applying migration %s (%d statements)'):format(path, #statements))
            for _, statement in ipairs(statements) do MySQL.query.await(statement) end
            MySQL.insert.await(('INSERT INTO `%s` (`migration`) VALUES (?)'):format(tableName), { path })
        end
    end

    -- Runtime sessions and leases never survive a resource/server restart implicitly.
    MySQL.update.await("UPDATE mz_computer_sessions SET status='revoked', source=NULL WHERE status='valid'")
    MySQL.update.await("UPDATE mz_computer_device_leases SET status='expired' WHERE status='active'")
    return true
end

MZComputer.Migrations = Migrations
