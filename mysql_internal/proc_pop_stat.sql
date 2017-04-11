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

# 00.
# t1 is a "current time minus 1 day" timestamp. Used to calculate avg1.
# t3 is a "current time minus 3 days" timestamp. Used to calculate freq3, avg3.
    DECLARE t1 INT;
    DECLARE t3 INT;

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
# The `stat` table contains calculated statistical values for each item.
# Before filling the table with data, we check that the table does exist.
# 
# Description of columns.
# `itemid`: It is the fist part of the compound primary key for `hist`. 
# It is also a foreign key which references to `def` table.
# `rtime`: A timestamp in unix format. It represents time at which report was
# created.
# Stats fields:
# `freq3`:  amount of samples taken in 3 days, divided by 3. Used to see how
#           often item is generally available.
# `freq30`: amount of samples taken in 30 days, divided by 30. Same as previous.
# `avg1`:   one day average. Used as basic element for building other stats.
# `avg3`:   three days average.
# `avg30`:  the most general average. Used as a reference point.
# `dif1`:   difference between last avg1 and previous avg1. abs(dif1) > 1 means
#           there is possible problem with a fiber.
# `avg3dif`:average of last 3 dif1 divided by 3. abs(avg3dif) > 1 is, probably, 
#           very bad.
    CREATE TABLE IF NOT EXISTS `stat` (
        `itemid`  bigint(20) unsigned NOT NULL,
        `rtime`   int(11)      NOT NULL,
        `freq3`   decimal(5,2),
        `freq30`  decimal(5,2),
        `avg1`    decimal(5,2),
        `avg3`    decimal(5,2),
        `avg30`   decimal(5,2),
        `dif1`    decimal(5,2),
        `avg3dif` decimal(5,2),
        PRIMARY KEY `stat_1` (`itemid`, `rtime`),
        CONSTRAINT `stat_fk_1` FOREIGN KEY (`itemid`)
            REFERENCES `def` (`itemid`) ON DELETE CASCADE,
        CONSTRAINT `stat_fk_2` FOREIGN KEY (`rtime`)
            REFERENCES `sum` (`rtime`) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8;

# 2.1.
# Some stats, like freq30 and avg30, can be calculated in one operation.
    INSERT INTO stat (itemid, rtime, freq30, avg30)
        SELECT h.itemid, curtime, 
                cast((count(h.val) / 30) AS decimal(5,2)), 
                cast(avg(h.val) AS decimal(5,2))
            FROM hist AS h
            GROUP BY itemid;

# 2.2.
# The stats freq3 and avg3 have to be calculated using "now minus 3 days"
# timestamp. To avoid subqueries, a temporary table is created and then stats
# are copied to the main table.
    SET t3 = curtime - 259200; # 3 * 24 * 3600 = 259 200
    CREATE TEMPORARY TABLE `t_3dayspan` 
        SELECT 
                itemid, 
                cast((count(h.val) / 3) AS decimal(5,2)) as f3,
                cast(avg(h.val) AS decimal(5,2)) as a3
            FROM hist AS h
            WHERE htime > t3
            GROUP BY itemid;
    UPDATE stat AS s, t_3dayspan AS t
        SET s.freq3 = t.f3, s.avg3 = t.a3
        WHERE s.itemid = t.itemid
        AND s.rtime = curtime;
    DROP TABLE t_3dayspan;

# 2.3.
# avg1 have to be calculated using "now minus 1 day" timestamp. Quite similar
# to the previous block.
    SET t1 = curtime -  86400; # 24 * 3600 = 86 400
    CREATE TEMPORARY TABLE `t_1dayspan` 
        SELECT 
                itemid, 
                cast(avg(h.val) AS decimal(5,2)) as a1
            FROM hist AS h
            WHERE htime > t1
            GROUP BY itemid;
    UPDATE stat AS s, t_1dayspan AS t
        SET s.avg1 = t.a1
        WHERE s.itemid = t.itemid
        AND s.rtime = curtime;
    DROP TABLE t_1dayspan;

# 2.4.
# How do we get dif1 and avg3dif? #################################


# 3.
# If the procedure didn't stop abnormally, we update the status variable, which
# is then written into a summary table by report_master procedure.
    SET p_status = "OK";
END//

DELIMITER ;
