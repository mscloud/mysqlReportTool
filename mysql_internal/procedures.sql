#============================#
#                            #
#         Procedures         #
#                            #
#============================#

#===============================================#
# 3.    Calculate statistical values            #
# 3.1.  Create table, if not created already    #
# 3.2.  Take a timestamp for current report     #
# 3.3.  Do the necessary calculations for each  #
#           item                                #
# 3.4.  Get the latest value from zabbix.history#
#===============================================#

USE reporter;
DELIMITER //

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
      CONSTRAINT `st_fk_2` FOREIGN KEY (`rtime`)              # `rtime` is a foreign key taken from `sum`.
            REFERENCES `sum` (`rtime`) ON DELETE CASCADE      # 
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8;                     # 

# 3.2.
    SELECT curtime = max(rtime) 
      FROM sum 
      GROUP BY rtime;

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


DELIMITER ;
