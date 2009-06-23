-- 
-- ***** BEGIN LICENSE BLOCK *****
-- Zimbra Collaboration Suite Server
-- Copyright (C) 2008, 2009 Zimbra, Inc.
-- 
-- The contents of this file are subject to the Yahoo! Public License
-- Version 1.0 ("License"); you may not use this file except in
-- compliance with the License.  You may obtain a copy of the License at
-- http://www.zimbra.com/license.
-- 
-- Software distributed under the License is distributed on an "AS IS"
-- basis, WITHOUT WARRANTY OF ANY KIND, either express or implied.
-- ***** END LICENSE BLOCK *****
-- 

PRAGMA legacy_file_format = OFF;
PRAGMA encoding = "UTF-8";

-- -----------------------------------------------------------------------
-- volumes
-- -----------------------------------------------------------------------

-- list of known volumes
CREATE TABLE volume (
   id                     INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
   type                   TINYINT NOT NULL,   -- 1 = primary msg, 2 = secondary msg, 10 = index
   name                   VARCHAR(255) NOT NULL UNIQUE,
   path                   TEXT NOT NULL UNIQUE,
   file_bits              SMALLINT NOT NULL,
   file_group_bits        SMALLINT NOT NULL,
   mailbox_bits           SMALLINT NOT NULL,
   mailbox_group_bits     SMALLINT NOT NULL,
   compress_blobs         BOOLEAN NOT NULL,
   compression_threshold  BIGINT NOT NULL
);

-- This table has only one row.  It points to message and index volumes
-- to use for newly provisioned mailboxes.
CREATE TABLE current_volumes (
   message_volume_id            INTEGER NOT NULL,
   secondary_message_volume_id  INTEGER,
   index_volume_id              INTEGER NOT NULL,
   next_mailbox_id              INTEGER NOT NULL,

   CONSTRAINT fk_current_volumes_message_volume_id FOREIGN KEY (message_volume_id) REFERENCES volume(id),
   CONSTRAINT fk_current_volumes_secondary_message_volume_id FOREIGN KEY (secondary_message_volume_id) REFERENCES volume(id),
   CONSTRAINT fk_current_volumes_index_volume_id FOREIGN KEY (index_volume_id) REFERENCES volume(id)
);

-- CREATE TRIGGER fki_current_volumes_volume_id
-- BEFORE INSERT ON [current_volumes]
-- FOR EACH ROW BEGIN
--   SELECT RAISE(ROLLBACK, 'insert on table "current_volumes" violates foreign key constraint "fki_current_volumes_volume_id"')
--   WHERE (SELECT id FROM volume WHERE id = NEW.message_volume_id) IS NULL OR
--         (SELECT id FROM volume WHERE id = NEW.secondary_message_volume_id OR NEW.secondary_message_volume_id IS NULL) IS NULL OR
--         (SELECT id FROM volume WHERE id = NEW.index_volume_id) IS NULL;
-- END;

-- CREATE TRIGGER fku_current_volumes_volume_id
-- BEFORE UPDATE ON [current_volumes] 
-- FOR EACH ROW BEGIN
--     SELECT RAISE(ROLLBACK, 'update on table "current_volumes" violates foreign key constraint "fku_current_volumes_volume_id"')
--       WHERE (SELECT id FROM volume WHERE id = NEW.message_volume_id) IS NULL OR
--             (SELECT id FROM volume WHERE id = NEW.secondary_message_volume_id OR NEW.secondary_message_volume_id IS NULL) IS NULL OR
--             (SELECT id FROM volume WHERE id = NEW.index_volume_id) IS NULL;
-- END;

-- CREATE TRIGGER fkd_current_volumes_volume_id
-- BEFORE DELETE ON volume
-- FOR EACH ROW BEGIN
--   SELECT RAISE(ROLLBACK, 'delete on table "volume" violates foreign key constraint "fkd_current_volumes_volume_id"')
--   WHERE (SELECT message_volume_id FROM current_volumes WHERE message_volume_id = OLD.id) IS NOT NULL OR
--         (SELECT secondary_message_volume_id FROM current_volumes WHERE secondary_message_volume_id = OLD.id) IS NOT NULL OR
--         (SELECT index_volume_id FROM current_volumes WHERE index_volume_id = OLD.id) IS NOT NULL;
-- END;


-- -----------------------------------------------------------------------
-- mailbox info
-- -----------------------------------------------------------------------

CREATE TABLE mailbox (
   id                  BIGINT UNSIGNED NOT NULL PRIMARY KEY,
   account_id          VARCHAR(127) NOT NULL UNIQUE,  -- e.g. "d94e42c4-1636-11d9-b904-4dd689d02402"
   last_backup_at      INTEGER UNSIGNED,              -- last full backup time, UNIX-style timestamp
   comment             VARCHAR(255)                   -- usually the main email address originally associated with the mailbox
);

CREATE INDEX i_mailbox_last_backup_at ON mailbox(last_backup_at, id);

-- -----------------------------------------------------------------------
-- deleted accounts
-- -----------------------------------------------------------------------

CREATE TABLE deleted_account (
   email       VARCHAR(255) NOT NULL PRIMARY KEY,
   account_id  VARCHAR(127) NOT NULL,
   mailbox_id  INTEGER UNSIGNED NOT NULL,
   deleted_at  INTEGER UNSIGNED NOT NULL      -- UNIX-style timestamp
);

-- -----------------------------------------------------------------------
-- etc.
-- -----------------------------------------------------------------------

-- table for global config params
CREATE TABLE config (
   name         VARCHAR(255) NOT NULL PRIMARY KEY,
   value        TEXT,
   description  TEXT,
   modified     TIMESTAMP DEFAULT (DATETIME('NOW'))
);

-- table for tracking database table maintenance
CREATE TABLE table_maintenance (
   database_name       VARCHAR(64) NOT NULL,
   table_name          VARCHAR(64) NOT NULL,
   maintenance_date    DATETIME NOT NULL,
   last_optimize_date  DATETIME,
   num_rows            INTEGER UNSIGNED NOT NULL,

   PRIMARY KEY (table_name, database_name)
);

CREATE TABLE service_status (
   server   VARCHAR(255) NOT NULL,
   service  VARCHAR(255) NOT NULL,
   time     DATETIME,
   status   BOOL,
  
   UNIQUE (server, service)
);

-- Tracks scheduled tasks
CREATE TABLE scheduled_task (
   class_name       VARCHAR(255) NOT NULL,
   name             VARCHAR(255) NOT NULL,
   mailbox_id       INTEGER UNSIGNED NOT NULL,
   exec_time        DATETIME,
   interval_millis  INTEGER UNSIGNED,
   metadata         MEDIUMTEXT,

   PRIMARY KEY (name, mailbox_id, class_name),
   CONSTRAINT fk_st_mailbox_id FOREIGN KEY (mailbox_id) REFERENCES mailbox(id) ON DELETE CASCADE
);

CREATE INDEX i_scheduled_task_mailbox_id ON scheduled_task(mailbox_id);

-- CREATE TRIGGER fki_scheduled_task_mailbox_id
-- BEFORE INSERT ON [scheduled_task]
-- FOR EACH ROW BEGIN
--   SELECT RAISE(ROLLBACK, 'insert on table "scheduled_task" violates foreign key constraint "fki_scheduled_task_mailbox_id"')
--   WHERE (SELECT id FROM mailbox WHERE id = NEW.mailbox_id) IS NULL;
-- END;

-- CREATE TRIGGER fku_scheduled_task_mailbox_id
-- BEFORE UPDATE OF mailbox_id ON [scheduled_task] 
-- FOR EACH ROW BEGIN
--     SELECT RAISE(ROLLBACK, 'update on table "scheduled_task" violates foreign key constraint "fku_scheduled_task_mailbox_id"')
--       WHERE (SELECT id FROM mailbox WHERE id = NEW.mailbox_id) IS NULL;
-- END;

CREATE TRIGGER fkdc_scheduled_task_mailbox_id
BEFORE DELETE ON mailbox
FOR EACH ROW BEGIN 
    DELETE FROM scheduled_task WHERE scheduled_task.mailbox_id = OLD.id;
END;

-- Mobile Devices
CREATE TABLE mobile_devices (
   mailbox_id          BIGINT UNSIGNED NOT NULL,
   device_id           VARCHAR(64) NOT NULL,
   device_type         VARCHAR(64) NOT NULL,
   user_agent          VARCHAR(64),
   protocol_version    VARCHAR(64),
   provisionable       BOOLEAN NOT NULL DEFAULT 0,
   status              TINYINT UNSIGNED NOT NULL DEFAULT 0,
   policy_key          INTEGER UNSIGNED,
   recovery_password   VARCHAR(64),
   first_req_received  INTEGER UNSIGNED NOT NULL,
   last_policy_update  INTEGER UNSIGNED,
   remote_wipe_req     INTEGER UNSIGNED,
   remote_wipe_ack     INTEGER UNSIGNED,

   PRIMARY KEY (mailbox_id, device_id),
   CONSTRAINT fk_mobile_mailbox_id FOREIGN KEY (mailbox_id) REFERENCES mailbox(id) ON DELETE CASCADE
);

-- CREATE TRIGGER fki_mobile_devices_mailbox_id
-- BEFORE INSERT ON [mobile_devices]
-- FOR EACH ROW BEGIN
--   SELECT RAISE(ROLLBACK, 'insert on table "mobile_devices" violates foreign key constraint "fki_mobile_devices_mailbox_id"')
--   WHERE (SELECT id FROM mailbox WHERE id = NEW.mailbox_id) IS NULL;
-- END;

-- CREATE TRIGGER fku_mobile_devices_mailbox_id
-- BEFORE UPDATE OF mailbox_id ON [mobile_devices] 
-- FOR EACH ROW BEGIN
--     SELECT RAISE(ROLLBACK, 'update on table "mobile_devices" violates foreign key constraint "fku_mobile_devices_mailbox_id"')
--       WHERE (SELECT id FROM mailbox WHERE id = NEW.mailbox_id) IS NULL;
-- END;

CREATE TRIGGER fkdc_mobile_devices_mailbox_id
BEFORE DELETE ON mailbox
FOR EACH ROW BEGIN 
    DELETE FROM mobile_devices WHERE mobile_devices.mailbox_id = OLD.id;
END;