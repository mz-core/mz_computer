-- MZ Computer / MZ OS - base domain schema

CREATE TABLE IF NOT EXISTS mz_computer_accounts (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  username VARCHAR(32) NOT NULL,
  username_normalized VARCHAR(32) NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  password_algo VARCHAR(32) NOT NULL,
  password_version INT NOT NULL DEFAULT 1,
  status VARCHAR(16) NOT NULL DEFAULT 'active',
  failed_attempts INT NOT NULL DEFAULT 0,
  locked_until TIMESTAMP NULL DEFAULT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  revision INT NOT NULL DEFAULT 1,
  PRIMARY KEY (id),
  UNIQUE KEY uq_mz_computer_username (username_normalized),
  KEY idx_mz_computer_account_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS mz_computer_account_identities (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  account_id BIGINT UNSIGNED NOT NULL,
  citizen_id VARCHAR(64) NOT NULL,
  identity_type VARCHAR(32) NOT NULL DEFAULT 'primary',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_mz_computer_account_citizen (account_id, citizen_id),
  KEY idx_mz_computer_identity_citizen (citizen_id, identity_type),
  CONSTRAINT fk_mz_computer_identity_account FOREIGN KEY (account_id) REFERENCES mz_computer_accounts(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS mz_computer_devices (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  device_uid VARCHAR(64) NOT NULL,
  device_type VARCHAR(32) NOT NULL,
  skin_id VARCHAR(64) NOT NULL DEFAULT 'notebook_basic',
  ownership_type VARCHAR(32) NOT NULL,
  owner_ref VARCHAR(160) DEFAULT NULL,
  serial_number VARCHAR(64) DEFAULT NULL,
  status VARCHAR(16) NOT NULL DEFAULT 'active',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  metadata_json LONGTEXT DEFAULT NULL,
  revision INT NOT NULL DEFAULT 1,
  PRIMARY KEY (id),
  UNIQUE KEY uq_mz_computer_device_uid (device_uid),
  UNIQUE KEY uq_mz_computer_serial (serial_number),
  KEY idx_mz_computer_device_type (device_type),
  KEY idx_mz_computer_device_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS mz_computer_sessions (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  session_token VARCHAR(64) NOT NULL,
  account_id BIGINT UNSIGNED NOT NULL,
  device_id BIGINT UNSIGNED NOT NULL,
  citizen_id VARCHAR(64) NOT NULL,
  source INT DEFAULT NULL,
  status VARCHAR(16) NOT NULL DEFAULT 'valid',
  issued_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  expires_at TIMESTAMP NOT NULL,
  last_activity TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  revision INT NOT NULL DEFAULT 1,
  PRIMARY KEY (id),
  UNIQUE KEY uq_mz_computer_session_token (session_token),
  KEY idx_mz_computer_session_account (account_id, status),
  KEY idx_mz_computer_session_source (source, status),
  KEY idx_mz_computer_session_expiry (expires_at),
  CONSTRAINT fk_mz_computer_session_account FOREIGN KEY (account_id) REFERENCES mz_computer_accounts(id) ON DELETE CASCADE,
  CONSTRAINT fk_mz_computer_session_device FOREIGN KEY (device_id) REFERENCES mz_computer_devices(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS mz_computer_device_leases (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  device_id BIGINT UNSIGNED NOT NULL,
  session_id BIGINT UNSIGNED DEFAULT NULL,
  leased_by INT DEFAULT NULL,
  leased_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  expires_at TIMESTAMP NOT NULL,
  status VARCHAR(16) NOT NULL DEFAULT 'active',
  PRIMARY KEY (id),
  UNIQUE KEY uq_mz_computer_device_lease (device_id),
  KEY idx_mz_computer_lease_expiry (expires_at, status),
  CONSTRAINT fk_mz_computer_lease_device FOREIGN KEY (device_id) REFERENCES mz_computer_devices(id) ON DELETE CASCADE,
  CONSTRAINT fk_mz_computer_lease_session FOREIGN KEY (session_id) REFERENCES mz_computer_sessions(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS mz_computer_notes (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  account_id BIGINT UNSIGNED NOT NULL,
  title VARCHAR(120) NOT NULL,
  content LONGTEXT NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  revision INT NOT NULL DEFAULT 1,
  PRIMARY KEY (id),
  KEY idx_mz_computer_notes_account (account_id, updated_at),
  CONSTRAINT fk_mz_computer_note_account FOREIGN KEY (account_id) REFERENCES mz_computer_accounts(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS mz_computer_account_settings (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  account_id BIGINT UNSIGNED NOT NULL,
  settings_json LONGTEXT DEFAULT NULL,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  revision INT NOT NULL DEFAULT 1,
  PRIMARY KEY (id),
  UNIQUE KEY uq_mz_computer_settings_account (account_id),
  CONSTRAINT fk_mz_computer_settings_account FOREIGN KEY (account_id) REFERENCES mz_computer_accounts(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS mz_computer_audit_log (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  event_type VARCHAR(64) NOT NULL,
  account_id BIGINT UNSIGNED DEFAULT NULL,
  session_id BIGINT UNSIGNED DEFAULT NULL,
  device_id BIGINT UNSIGNED DEFAULT NULL,
  source INT DEFAULT NULL,
  description VARCHAR(255) DEFAULT NULL,
  metadata_json LONGTEXT DEFAULT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_mz_computer_audit_event (event_type, created_at),
  KEY idx_mz_computer_audit_account (account_id, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
