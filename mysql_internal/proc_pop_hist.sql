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
# The `hist` table contains actual values for each item.
# Before filling the table with data, we check that the table does exist.
# 
# Description of columns.
# `itemid`: It is the fist part of the compound primary key for `hist`. 
# It is also a foreign key which references to `def` table.
# `htime`: A timestamp in unix format. It represents time at which measurement
# was taken by zabbix.
# `val`: value from zabbix.history translated to decimal type
    CREATE TABLE IF NOT EXISTS `hist` (
        `itemid` bigint(20) unsigned NOT NULL,
        `htime` int(11) NOT NULL,
        `val` decimal(8,4) NOT NULL,
        PRIMARY KEY `hi_1` (`itemid`,`htime`),
        INDEX `htime` (`htime`),
        CONSTRAINT `hi_fk_1` FOREIGN KEY (`itemid`)
            REFERENCES `def` (`itemid`) ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8;

# 2.
# In this block, zabbix history tables are processed and values for each item
# in `def` are collected. To reduce amount of data, only one in each hour is
# copied into `hist` table.
# 
# What should be noted is that two history tables are processed: zabbix.history
# for float values, and zabbix.history_str for values that are stored as string
# type (Medialinks is so special J).
# 
# General explanation for the block below.
# 1) items from `def` which are marked as 'skip', are ignored;
# 2) only values recorded at xx hours 00 minutes are inserted. this way,
# sampling frequency is reduced from 1/min in zabbix to 1/hr in the report
# generator;
# 3) special values that represent loss of signal ('-128' and '-41' for Evertz,
# '-40.0', '' and '-Inf' for Medialinks) are ignored;
# 4) only values within last 30 days (2,592,000 seconds) are processed;
# 5) zabbix.history and zabbix.history_str are processed consequently.
#
# IGNORE operator is used to avoid duplicate values when importing data from 
# zabbix history. 
    INSERT IGNORE INTO reporter.hist (itemid, htime, val)
        SELECT h.itemid, h.clock, cast(h.value AS decimal(8,4))
            FROM zabbix.history AS h, reporter.def AS d
            WHERE h.itemid = d.itemid
            AND d.role != 'skip'
            AND minute(from_unixtime(h.clock)) = 0
            AND h.clock > (curtime - 2592000)
            AND h.value > '-40.0';

    INSERT IGNORE INTO reporter.hist (itemid, htime, val)
        SELECT h.itemid, h.clock, cast(h.value AS decimal(8,4))
            FROM zabbix.history_str AS h, reporter.def AS d
            WHERE h.itemid = d.itemid
            AND d.role != 'skip'
            AND minute(from_unixtime(h.clock)) = 0
            AND h.clock > (curtime - 2592000)
            AND h.value NOT IN ('-Inf', '-40.000000', '') 

# 3.
# Remove values that are older than 30 days (2,592,000 seconds).
    DELETE FROM hist
        WHERE htime < (curtime - 2592000);

# 4.
# If the procedure didn't stop abnormally, we update the status variable, which
# is then written into a summary table by report_master procedure.
    SET p_status = "OK";
END//

DELIMITER ;
