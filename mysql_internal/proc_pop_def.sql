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
    INOUT p_status VARCHAR
    )
BEGIN
    DECLARE EXIT HANDLER FOR SQLWARNING
    BEGIN
        SET p_status = "Fail";
    END;
# 1.
    CREATE TABLE IF NOT EXISTS `def` (                      # The `def` table contains definitions of items that 
                                                            # must be analyzed.
        `itemid` bigint(20) unsigned NOT NULL,              # Primary key is `itemid`. It has BIGINT(20) type for 
                                                            # compatibility with zabbix.
        `host` varchar(32) NOT NULL DEFAULT 'undefined host', # Hostname from zabbix
        `name` varchar(64) DEFAULT NULL,                    # It was items.name initially, but changed to items.key_ 
                                                            # because names are the same for all slots.
        `role` varchar(64) NOT NULL DEFAULT 'undefined role', # It will be a handwritten description for an item. Unused 
                                                            # items will have special itemrole value.
                                                            # Statistics will not be calculated for `role`='skip', and 
                                                            # entry will be deleted if `role`='remove'
        PRIMARY KEY (`itemid`),                             # `itemid` is also a foreign key for stats and history tables.
        KEY `role` (`role`)                                 # 
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8;               # 

# 2.
    INSERT IGNORE INTO reporter.def (itemid, host, name)    # IGNORE operator is to avoid duplicates.
        SELECT i.itemid, h.host, i.key_                     # 
            FROM zabbix.items AS i, zabbix.hosts AS h       # 
            WHERE i.hostid = h.hostid                       # 
            AND i.name LIKE '%rx power%'                    # 
            AND i.key_ NOT LIKE '%#SNMPINDEX%'              # Keys that have '[#SNMPINDEX]' in index are 
    ;                                                       # templates. such keys are excluded.

# 3.
    DELETE FROM def                                         # Delete lines manually marked for removal.
        WHERE role  = 'remove';                             #

# 4.
    SET p_status = "OK";
END//

DELIMITER ;
