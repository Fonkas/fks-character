-- As tabelas são criadas automaticamente no arranque do recurso.
-- Este ficheiro existe para instalação manual / referência.

CREATE TABLE IF NOT EXISTS `fks_characters` (
    `charidentifier` INT(11) NOT NULL,
    `identifier` VARCHAR(60) NOT NULL,
    `birthdate` DATE NULL DEFAULT NULL,
    `height` SMALLINT(5) UNSIGNED NULL DEFAULT NULL,
    `nationality` VARCHAR(60) NULL DEFAULT NULL,
    `birthplace` VARCHAR(60) NULL DEFAULT NULL,
    `biography` TEXT NULL DEFAULT NULL,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `deleted_at` DATETIME NULL DEFAULT NULL,
    `deleted_by` VARCHAR(60) NULL DEFAULT NULL,
    `starter_kit` VARCHAR(40) NULL DEFAULT NULL,
    PRIMARY KEY (`charidentifier`),
    INDEX `idx_identifier` (`identifier`),
    INDEX `idx_deleted` (`deleted_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `fks_character_slots` (
    `identifier` VARCHAR(60) NOT NULL,
    `extra_slots` INT(11) NOT NULL DEFAULT 0,
    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `fks_tebex_redeemed` (
    `transaction` VARCHAR(80) NOT NULL,
    `identifier` VARCHAR(60) NOT NULL,
    `slots` INT(11) NOT NULL DEFAULT 0,
    `redeemed_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`transaction`),
    INDEX `idx_identifier` (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
