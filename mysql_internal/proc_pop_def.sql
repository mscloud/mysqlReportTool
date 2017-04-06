# proc_pop_def.sql

#===============================================#
#       Populate items table                    #
#   1.  Create table, if not created already    #
#   2.  Get items from zabbix                   #
#   3.  Remove items marked for deletion        #
#   4.  Update p_status                         #
#===============================================#

USE reporter;
DELIMITER //

CREATE PROCEDURE pop_def(
    IN curtime INT, 
    INOUT p_status VARCHAR(8)
    )
BEGIN

# 0.
# Exit procedure on warning, update status variable
#
# If any warnings are encountered during the procedure, a variable is assigned 
# a special value, and the procedure is stopped. Then, report_master() procedure
# writes this value into a summary table.
    DECLARE EXIT HANDLER FOR SQLWARNING
    BEGIN
        SET p_status = "Fail";
    END;

# 1.
# The `def` table contains definitions of items that must be analyzed.
# Before filling the table with data, we check that the table does exist.
# 
# Description of columns.
# `itemid`: Item ID taken from zabbix.items. It has BIGINT(20) type for 
# compatibility with zabbix. It is the primary key for `def` and a foreign key 
# for `history` and `stat` tables.
# `host`: Hostname taken from zabbix.hosts
# `name`: It was items.name initially, but changed to items.key_ because names 
# are the same for all slots.
# `role`: A handwritten description for an item. For unused items `role` = 'skip'.
# It is important that `role` has default value, which is used to check for new 
# found items.
# `itemid` is also a foreign key for stats and history tables.
    CREATE TABLE IF NOT EXISTS `def` (
        `itemid` bigint(20) unsigned NOT NULL,
        `host` varchar(32) NOT NULL DEFAULT 'undefined host',
        `name` varchar(64) DEFAULT NULL,
        `role` varchar(64) NOT NULL DEFAULT 'undefined role',
        PRIMARY KEY (`itemid`),
        KEY `role` (`role`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8;

# 2.
# In this block, zabbix.items table is checked for items that must be analyzed 
# further.
#
# It is decided that all, and only, items that represent received optical power,
# have "rx power" phrase in their names.
# Items that have "[#SNMPINDEX]" in their key are item prototypes and contain 
# no real data. Therefore, they are excluded.
# IGNORE operator is used to avoid duplicate items when importing data from 
# zabbix.items. 
    INSERT IGNORE INTO reporter.def (itemid, host, name)
        SELECT i.itemid, h.host, i.key_
            FROM zabbix.items AS i, zabbix.hosts AS h
            WHERE i.hostid = h.hostid
            AND i.name LIKE '%rx power%'
            AND i.key_ NOT LIKE '%#SNMPINDEX%'
    ;

# 3.
# Remove items that are no longer found in zabbix.items table
    DELETE reporter.def
        FROM reporter.def LEFT JOIN zabbix.items 
        USING (itemid) 
        WHERE zabbix.items.itemid IS NULL;

# 4.
# If the procedure didn't stop abnormally, we update the status variable, which
# is then written into a summary table by report_master procedure.
    SET p_status = "OK";
END//

DELIMITER ;
