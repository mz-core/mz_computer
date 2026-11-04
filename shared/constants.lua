MZComputer = MZComputer or {}

MZComputer.Const = {
    AccountStatus = { ACTIVE = 'active', LOCKED = 'locked', DISABLED = 'disabled' },
    SessionStatus = { VALID = 'valid', EXPIRED = 'expired', REVOKED = 'revoked' },
    DeviceStatus = { ACTIVE = 'active', DISABLED = 'disabled', LOST = 'lost', SEIZED = 'seized', RETIRED = 'retired' },
    DeviceType = { PERSONAL = 'personal', PUBLIC = 'public', BUSINESS = 'business', GOVERNMENT = 'government' },
    Visibility = { VISIBLE = 'visible', HIDDEN = 'hidden', DISABLED = 'disabled' },
    Error = {
        VALIDATION_FAILED = 'VALIDATION_FAILED',
        INTERNAL_ERROR = 'INTERNAL_ERROR',
        IDENTITY_UNAVAILABLE = 'IDENTITY_UNAVAILABLE',
        ACCOUNT_EXISTS = 'ACCOUNT_EXISTS',
        ACCOUNT_NOT_FOUND = 'ACCOUNT_NOT_FOUND',
        AUTH_INVALID_CREDENTIALS = 'AUTH_INVALID_CREDENTIALS',
        AUTH_RATE_LIMITED = 'AUTH_RATE_LIMITED',
        AUTH_ACCOUNT_LOCKED = 'AUTH_ACCOUNT_LOCKED',
        AUTH_ACCOUNT_DISABLED = 'AUTH_ACCOUNT_DISABLED',
        SESSION_INVALID = 'SESSION_INVALID',
        SESSION_EXPIRED = 'SESSION_EXPIRED',
        DEVICE_BUSY = 'DEVICE_BUSY',
        DEVICE_UNAVAILABLE = 'DEVICE_UNAVAILABLE',
        DEVICE_TOO_FAR = 'DEVICE_TOO_FAR',
        APP_FORBIDDEN = 'APP_FORBIDDEN',
        SITE_NOT_FOUND = 'SITE_NOT_FOUND',
        EXTERNAL_URL_BLOCKED = 'EXTERNAL_URL_BLOCKED',
        LIMIT_REACHED = 'LIMIT_REACHED',
        CONFLICT = 'CONFLICT'
    }
}
