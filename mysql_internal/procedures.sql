#============================#
#                            #
#         Procedures         #
#                            #
#============================#

#===============================================#
# 1.    Populate items table                    #
# 1.1.  Create table, if not created already    #
# 1.2.  Get items from zabbix                   #
# 1.3.  Remove items marked for deletion        #
#===============================================#

#===============================================#
# 2.    Populate values table                   #
# 2.1.  Create table, if not created already    #
# 2.2.  Get values from zabbix                  #
# 2.3.  Remove values older than 30 days        #
#===============================================#

#===============================================#
# 3.    Calculate statistical values            #
# 3.1.  Create table, if not created already    #
# 3.2.  Take a timestamp for current report     #
# 3.3.  Do the necessary calculations for each  #
#           item                                #
# 3.4.  Get the latest value from zabbix.history#
#===============================================#

#===============================================#
# 4.    Output to file                          #
# 4.1.  Warnings                                #
# 4.2.  Full table                              #
#===============================================#

#===============================================#
# 5.    Superprocedure                          #
# 5.1.  Call pop_def()                          #
# 5.1.1.Output status                           #
# 5.2.  Call pop_hist()                         #
# 5.2.1.Output status                           #
# 5.3.  Call pop_stat()                         #
# 5.3.1.Output status                           #
# 5.4.  Call out_stat()                         #
# 5.4.1.Output status                           #
#===============================================#

USE reporter;
DELIMITER //

# 1.
CREATE PROCEDURE pop_def();
BEGIN

# 1.1.
    CREATE TABLE IF NOT EXISTS `def` (                      # The `def` table contains definitions of items that 
                                                            # must be analyzed.
      `itemid` bigint(20) unsigned NOT NULL,                # Primary key is `itemid`. It has BIGINT(20) type for 
                                                            # compatibility with zabbix.
      `host` varchar(32) NOT NULL DEFAULT 'undefined host', # Hostname from zabbix
      `name` varchar(64) DEFAULT NULL,                      # It was items.name initially, but changed to items.key_ 
                                                            # because names are the same for all slots.
      `role` varchar(64) NOT NULL DEFAULT 'undefined role', # It will be a handwritten description for an item. Unused 
                                                            # items will have special itemrole value.
                                                            # Statistics will not be calculated for `role`='skip', and 
                                                            # entry will be deleted if `role`='remove'
      PRIMARY KEY (`itemid`),                               # `itemid` is also a foreign key for stats and history tables.
      KEY `role` (`role`)                                   # 
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8;                   # 

# 1.2.
    INSERT IGNORE INTO reporter.def (itemid, host, name)    # IGNORE operator is to avoid duplicates.
        SELECT i.itemid, h.host, i.key_                     # 
            FROM zabbix.items AS i, zabbix.hosts AS h       # 
            WHERE i.hostid = h.hostid                       # 
            AND i.name LIKE '%rx power%'                    # 
            AND i.key_ NOT LIKE '%#SNMPINDEX%'              # Keys that have '[#SNMPINDEX]' in index are 
    ;                                                       # templates. such keys are excluded.

#1.3
    DELETE FROM def                                         # Delete lines manually marked for removal.
        WHERE role  = 'remove';                             #
END//

# 2.
CREATE PROCEDURE pop_hist()
BEGIN

# 2.1.
    CREATE TABLE IF NOT EXISTS `hist` (                           # The `hist` table stores actual zabbix values taken 
                                                                  # once per hour. It is a data source for `stat` table.
      `itemid` bigint(20) unsigned NOT NULL,                      # Primary key is `itemid`+`htime`.
      `htime` int(11) NOT NULL,                                   # 
      `val` decimal(8,4) NOT NULL,                                # Pay attention to convert input values to decimal!
      PRIMARY KEY `hi_1` (`itemid`,`htime`),                      # 
      CONSTRAINT `hi_fk_1` FOREIGN KEY (`itemid`)                 # `itemid` is a foreign key taken from `def`.
            REFERENCES `def` (`itemid`) ON DELETE CASCADE         # 
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8;                         # 

# 2.2.
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
    ;                                                             # statistics ('-Inf.', '-41', '-128')

# 2.3.
    DELETE FROM hist                                              # Delete lines older than 30 days.
        WHERE htime < unix_timestamp(date_sub(now(),              # 
                interval 30 day));                                #
END//

# 3.
CREATE PROCEDURE pop_stat()
BEGIN
DECLARE curtime INT;

# 3.1.    
    CREATE TABLE IF NOT EXISTS `stat` (                       # The `stat` table contains calculated statistical values. 
                                                              # Some of them will be saved into the report file.
      `itemid` bigint(20) unsigned NOT NULL,                  # Primary key is `itemid`+`rtime`.
      `rtime` int(11) NOT NULL,                               # Report time. I want to be able to compare last report 
                                                              # with yestertay's, for example.
      `avg` decimal(5,2) DEFAULT NULL,                        # Mean value
      `dev` decimal(5,2) DEFAULT NULL,                        # Standard deviation. It's intended for seeing items 
                                                              # where value changes significantly.
      `count` smallint(6) NOT NULL DEFAULT '0',               # Number of valid values in a sample.
      `min` decimal(5,2) DEFAULT NULL,                        # Minimal value in a sample.
      `max` decimal(5,2) DEFAULT NULL,                        # Maximal value in a sample.
      `dif` decimal(5,2) DEFAULT NULL,                        # Difference between the maximal and minimal values 
                                                              # in a sample.
      `cur` decimal(5,2) DEFAULT NULL,                        # The latest value will be written here 
                                                              # (for manually generated reports)
      PRIMARY KEY `st_1` (`itemid`, `rtime`),                 # 
      CONSTRAINT `st_fk_1` FOREIGN KEY (`itemid`)             # `itemid` is a foreign key taken from `def`.
            REFERENCES `def` (`itemid`) ON DELETE CASCADE     # 
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8;                     # 

# 3.2.
    SET curtime = unix_timestamp(now());

# 3.3.
    INSERT IGNORE INTO stat 
          (itemid, rtime, 
          avg, dev, count, 
          min, max, dif)
      SELECT 
          h.itemid, curtime, 
          avg(h.val), std(h.val), count(h.val), 
          min(h.val), max(h.val), (max(h.val) - min(h.val))
        FROM hist as h
        GROUP BY itemid;

# 3.4.
    UPDATE reporter.stat AS s, zabbix.history AS z
      SET s.cur = cast(z.value as decimal(5,2))
      WHERE s.itemid = z.itemid
      AND s.rtime = curtime
      AND z.clock > unix_timestamp(now()) - 60;
    
    UPDATE reporter.stat AS s, zabbix.history_str AS z
      SET s.cur = cast(z.value as decimal(5,2))
      WHERE s.itemid = z.itemid
      AND s.rtime = curtime
      AND z.clock > unix_timestamp(now()) - 60;
END//

# 4.
CREATE PROCEDURE out_stat()
BEGIN
  ...
END//

# 5.
CREATE PROCEDURE report_lastmile()
BEGIN

# 5.1.
  SELECT "Updating items list..." AS status;
  CALL pop_def();
  SELECT "Done." AS status;

# 5.2.
  SELECT "Updating values history..." AS status;
  CALL pop_hist();
  SELECT "Done." AS status;

# 5.3.
  SELECT "Calculating statistics..." AS status;
  CALL pop_stat();
  SELECT "Done." AS status;

# 5.4.
  SELECT "Generating report file..." AS status;
  CALL out_stat();
  SELECT "Done." AS status;
END//

DELIMITER ;
