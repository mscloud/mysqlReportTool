# proc_pop_hist.sql

#===============================================#
#       Populate values table                   #
#   1.  Create table, if not created already    #
#   2.  Get values from zabbix                  #
#   3.  Remove values older than 30 days        #
#   4.  Update p_status                         #
#===============================================#

USE reporter;
DELIMITER //

CREATE PROCEDURE pop_hist(
    IN curtime INT, 
    INOUT p_status VARCHAR(8)
    )
BEGIN
    DECLARE EXIT HANDLER FOR SQLWARNING
    BEGIN
        SET p_status = "Fail";
    END;

# 1.
    CREATE TABLE IF NOT EXISTS `hist` (                           # The `hist` table stores actual zabbix values taken 
                                                                  # once per hour. It is a data source for `stat` table.
        `itemid` bigint(20) unsigned NOT NULL,                    # Primary key is `itemid`+`htime`.
        `htime` int(11) NOT NULL,                                 # 
        `val` decimal(8,4) NOT NULL,                              # Pay attention to convert input values to decimal!
        PRIMARY KEY `hi_1` (`itemid`,`htime`),                    # 
        CONSTRAINT `hi_fk_1` FOREIGN KEY (`itemid`)               # `itemid` is a foreign key taken from `def`.
            REFERENCES `def` (`itemid`) ON DELETE CASCADE         # 
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8;                         # 

# 2.
    INSERT IGNORE INTO reporter.hist (itemid, htime, val)         # IGNORE operator is to avoid duplicates.
        SELECT h.itemid, h.clock, cast(h.value AS decimal(8,4))   # This query takes values from zabbix.history 
                                                                  # (float values)
            FROM zabbix.history AS h, reporter.def AS d           # Don't forget to query zabbix.history_str 
                                                                  # for Medialinks!
            WHERE h.itemid = d.itemid                             # 
            AND d.role != 'skip'                                  # Some items need not to be processed
            AND minute(from_unixtime(h.clock)) = 0                # Values selected on a per hour basis
            AND h.clock > unix_timestamp(date_sub(now(),          # 
                    interval 30 day))                             # Not older than 30 days
            AND h.value > '-40.0'                                 # Drop LOS values which otherwise would spoil 
    ;                                                             # statistics ('-Inf.', '-41', '-128')

    INSERT IGNORE INTO reporter.hist (itemid, htime, val)         # IGNORE operator is to avoid duplicates.
        SELECT h.itemid, h.clock, cast(h.value AS decimal(8,4))   # This query takes values from 
                                                                  # zabbix.history_str (string values) and 
                                                                  # converts them to decimal type. Because 
                                                                  # Medialinks MIB is so special J
            FROM zabbix.history_str AS h, reporter.def AS d       # 
            WHERE h.itemid = d.itemid                             # 
            AND d.role != 'skip'                                  # Some items need not to be processed
            AND minute(from_unixtime(h.clock)) = 0                # Values selected on a per hour basis
            AND h.clock > unix_timestamp(date_sub(now(),          # 
                    interval 30 day))                             # Not older than 30 days
            AND h.value != '-Inf'                                 # Drop LOS values which otherwise would spoil 
            AND h.value != ''                                     # statistics ('-Inf', '', '-41', '-128')
    ;                                                             # 

# 3.
    DELETE FROM hist                                              # Delete lines older than 30 days.
        WHERE htime < unix_timestamp(date_sub(now(),              # 
                interval 30 day));                                #

# 4.
    SET p_status = "OK";
END//

DELIMITER ;
