DB = {}

MySQL.ready(function()
    MySQL.query.await([[
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
            PRIMARY KEY (`charidentifier`),
            INDEX `idx_identifier` (`identifier`),
            INDEX `idx_deleted` (`deleted_at`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `fks_character_slots` (
            `identifier` VARCHAR(60) NOT NULL,
            `extra_slots` INT(11) NOT NULL DEFAULT 0,
            `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`identifier`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `fks_tebex_redeemed` (
            `transaction` VARCHAR(80) NOT NULL,
            `identifier` VARCHAR(60) NOT NULL,
            `slots` INT(11) NOT NULL DEFAULT 0,
            `redeemed_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`transaction`),
            INDEX `idx_identifier` (`identifier`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])
    -- kit inicial escolhido (evita receber o kit duas vezes)
    MySQL.query.await("ALTER TABLE `fks_characters` ADD COLUMN IF NOT EXISTS `starter_kit` VARCHAR(40) NULL DEFAULT NULL")
    DB.Ready = true
end)

function DB.IsRedeemed(transaction)
    return MySQL.scalar.await("SELECT 1 FROM fks_tebex_redeemed WHERE `transaction` = ?", { transaction }) ~= nil
end

-- Devolve false se a transação já tinha sido usada (corrida entre dois pedidos)
function DB.Redeem(transaction, identifier, slots)
    local ok = pcall(MySQL.insert.await,
        "INSERT INTO fks_tebex_redeemed (`transaction`, identifier, slots) VALUES (?, ?, ?)",
        { transaction, identifier, slots })
    return ok
end

function DB.SetStarterKit(charId, kit)
    local affected = MySQL.update.await(
        "UPDATE fks_characters SET starter_kit = ? WHERE charidentifier = ? AND starter_kit IS NULL", { kit, charId })
    return (affected or 0) > 0
end

function DB.GetHeight(charId)
    return tonumber(MySQL.scalar.await("SELECT height FROM fks_characters WHERE charidentifier = ?", { charId }))
end

function DB.SetHeight(charId, identifier, height)
    MySQL.insert.await(
        "INSERT INTO fks_characters (charidentifier, identifier, height) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE height = VALUES(height)",
        { charId, identifier, height })
end

-- Dados de identidade de todas as personagens de um identificador
function DB.GetIdentities(identifier)
    local rows = MySQL.query.await(
        "SELECT charidentifier, DATE_FORMAT(birthdate, '%Y-%m-%d') AS birthdate, height, nationality, birthplace, biography, deleted_at IS NOT NULL AS deleted FROM fks_characters WHERE identifier = ?",
        { identifier }) or {}
    local map = {}
    for _, row in ipairs(rows) do
        row.deleted = row.deleted == 1 or row.deleted == true
        map[row.charidentifier] = row
    end
    return map
end

function DB.InsertIdentity(charId, identifier, identity)
    MySQL.insert.await(
        "INSERT INTO fks_characters (charidentifier, identifier, birthdate, height, nationality, birthplace, biography) VALUES (?, ?, ?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE birthdate = VALUES(birthdate), height = VALUES(height), nationality = VALUES(nationality), birthplace = VALUES(birthplace), biography = VALUES(biography), deleted_at = NULL, deleted_by = NULL",
        { charId, identifier, identity.birthdate, identity.height, identity.nationality, identity.birthplace, identity.biography })
end

function DB.SoftDelete(charId, identifier, deletedBy)
    -- Personagens antigas (criadas antes deste recurso) podem não ter linha ainda
    MySQL.insert.await(
        "INSERT INTO fks_characters (charidentifier, identifier, deleted_at, deleted_by) VALUES (?, ?, NOW(), ?) ON DUPLICATE KEY UPDATE deleted_at = NOW(), deleted_by = VALUES(deleted_by)",
        { charId, identifier, deletedBy })
end

function DB.HardDelete(charId)
    MySQL.query.await("DELETE FROM fks_characters WHERE charidentifier = ?", { charId })
end

function DB.Restore(charId)
    local affected = MySQL.update.await("UPDATE fks_characters SET deleted_at = NULL, deleted_by = NULL WHERE charidentifier = ? AND deleted_at IS NOT NULL", { charId })
    return (affected or 0) > 0
end

function DB.GetOwner(charId)
    return MySQL.scalar.await("SELECT identifier FROM fks_characters WHERE charidentifier = ?", { charId })
end

function DB.ListDeleted(identifier)
    return MySQL.query.await(
        "SELECT f.charidentifier, c.firstname, c.lastname, DATE_FORMAT(f.deleted_at, '%Y-%m-%d %H:%i') AS deleted_at FROM fks_characters f LEFT JOIN characters c ON c.charidentifier = f.charidentifier WHERE f.identifier = ? AND f.deleted_at IS NOT NULL",
        { identifier }) or {}
end

function DB.GetExtraSlots(identifier)
    return tonumber(MySQL.scalar.await("SELECT extra_slots FROM fks_character_slots WHERE identifier = ?", { identifier })) or 0
end

function DB.SetExtraSlots(identifier, amount)
    MySQL.insert.await(
        "INSERT INTO fks_character_slots (identifier, extra_slots) VALUES (?, ?) ON DUPLICATE KEY UPDATE extra_slots = VALUES(extra_slots)",
        { identifier, amount })
end
