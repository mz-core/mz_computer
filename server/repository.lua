MZComputer = MZComputer or {}
local Repo = {}

function Repo.one(query, params)
    return MySQL.single.await(query, params or {})
end

function Repo.all(query, params)
    return MySQL.query.await(query, params or {}) or {}
end

function Repo.insert(query, params)
    return MySQL.insert.await(query, params or {})
end

function Repo.update(query, params)
    return MySQL.update.await(query, params or {}) or 0
end

function Repo.scalar(query, params)
    return MySQL.scalar.await(query, params or {})
end

function Repo.json(value)
    local ok, encoded = pcall(json.encode, value or {})
    return ok and encoded or '{}'
end

function Repo.decode(value, fallback)
    return MZComputer.Validation.safeJsonDecode(value, fallback)
end

MZComputer.Repo = Repo
