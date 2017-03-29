# proc_pop_stat.sql

#===============================================#
#       Calculate statistical values            #
#   1.  Create table, if not created already    #
#   2.  Do the necessary calculations for each  #
#           item                                #
#   3.  Update p_status                         #
#===============================================#

USE reporter;
DELIMITER //

CREATE PROCEDURE pop_stat(
    IN curtime INT, 
    INOUT p_status VARCHAR(8)
    )
BEGIN
    DECLARE EXIT HANDLER FOR SQLWARNING
    BEGIN
        SET p_status = "Fail";
    END;

# 1.    
    CREATE TABLE IF NOT EXISTS `stat` (                         # The `stat` table contains calculated statistical values. 
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
            REFERENCES `def` (`itemid`) ON DELETE CASCADE,      # 
        CONSTRAINT `st_fk_2` FOREIGN KEY (`rtime`)              # `rtime` is a foreign key taken from `sum`.
            REFERENCES `sum` (`rtime`) ON DELETE CASCADE        # 
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8;                   # 

# 2.
    INSERT INTO stat 
            (itemid, rtime, 
            avg, dev, count, 
            min, max, dif)
        SELECT 
                h.itemid, 
                curtime, 
                cast(avg(h.val) as decimal(5,2)), 
                cast(std(h.val) as decimal(5,2)), 
                count(h.val), 
                cast(min(h.val) as decimal(5,2)), 
                cast(max(h.val) as decimal(5,2)), 
                cast((max(h.val) - min(h.val)) as decimal(5,2)), 
            FROM hist as h
            GROUP BY itemid;

# 3.
    SET p_status = "OK";
END//

DELIMITER ;
