-- MZ Computer - internal documents and OS notifications

CREATE TABLE IF NOT EXISTS mz_computer_documents (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  account_id BIGINT UNSIGNED NOT NULL,
  title VARCHAR(120) NOT NULL,
  content LONGTEXT NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  revision INT NOT NULL DEFAULT 1,
  PRIMARY KEY (id),
  KEY idx_mz_computer_documents_account (account_id, updated_at),
  CONSTRAINT fk_mz_computer_document_account FOREIGN KEY (account_id) REFERENCES mz_computer_accounts(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS mz_computer_notifications (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  account_id BIGINT UNSIGNED NOT NULL,
  title VARCHAR(100) NOT NULL,
  message VARCHAR(500) NOT NULL,
  type VARCHAR(24) NOT NULL DEFAULT 'info',
  icon VARCHAR(32) NOT NULL DEFAULT 'bell',
  data_json LONGTEXT DEFAULT NULL,
  is_read TINYINT(1) NOT NULL DEFAULT 0,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_mz_computer_notification_account (account_id, created_at),
  KEY idx_mz_computer_notification_unread (account_id, is_read),
  CONSTRAINT fk_mz_computer_notification_account FOREIGN KEY (account_id) REFERENCES mz_computer_accounts(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
