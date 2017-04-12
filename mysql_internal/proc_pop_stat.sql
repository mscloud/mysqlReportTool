# proc_pop_stat.sql

#===============================================#
#       Calculate statistical values            #
#   1.  Create table, if not created already    #
#   2.  Do the necessary calculations for each  #
#           item                                #
#   3.  Delete old stats                        #
#   4.  Update p_status                         #
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
# t30 is a "current time minus 30 days" timestamp. Used for cleanup.
    DECLARE t1  INT;
    DECLARE t3  INT;
    DECLARE t30 INT;

# 0.
# Exit procedure on warning, update status variable
#
# If any warnings are encountered during the procedure, a variable is assigned 
# a special value, and the procedure is stopped. Then, report_master() procedure
# writes this value into a summary table.
    DECLARE EXIT HANDLER FOR SQLWARNING
    BEGIN
        SET p_status = "Warnings";
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
# `avlb30`: item availability, monthly average. counted as per cent ratio of
#           actual number of samples divided by maximum number of samples
#           possible (30 * 24 = 720).
# `avlb3`:  item availability, 3 days average. counted as per cent ratio of
#           actual number of samples divided by maximum number of samples
#           possible (3 * 24 = 72).
# `avg30`:  the most general average. Used as a reference point.
# `avg3`:   three days average.
# `avg1`:   one day average. Used as basic element for building other stats.
# `dif1`:   difference between last avg1 and previous avg1. abs(dif1) > 1 means
#           there is possible problem with a fiber.
# `avg3dif`:average of last 3 dif1 divided by 3. abs(avg3dif) > 1 is, probably, 
#           very bad.
# `dif30`:  difference between newest and oldest avg30. For items with low
#           availability.
    SET @debug_status = "cr table";

    CREATE TABLE IF NOT EXISTS `stat` (
        `itemid`  bigint(20) unsigned NOT NULL,
        `rtime`   int(11) NOT NULL,
        `avlb30`  decimal(5,2),
        `avlb3`   decimal(5,2),
        `avg30`   decimal(5,2),
        `avg3`    decimal(5,2),
        `avg1`    decimal(5,2),
        `dif1`    decimal(5,2),
        `avg3dif` decimal(5,2),
        `dif30`   decimal(5,2),
        PRIMARY KEY `stat_1` (`itemid`, `rtime`),
        CONSTRAINT `stat_fk_1` FOREIGN KEY (`itemid`)
            REFERENCES `def` (`itemid`) ON DELETE CASCADE,
        CONSTRAINT `stat_fk_2` FOREIGN KEY (`rtime`)
            REFERENCES `sum` (`rtime`) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8;

# 2.1.
# Some stats, like avlb30 and avg30, can be calculated in one operation.
# availability30 = count30 / (30 * 24) * 100% = count30/7.2 (per cent)
    SET @debug_status = "step 2.1";

    INSERT INTO stat (itemid, rtime, avlb30, avg30)
        SELECT h.itemid, curtime, 
                cast((count(h.val) / 7.2) AS decimal(5,2)), 
                cast(avg(h.val) AS decimal(5,2))
            FROM hist AS h
            GROUP BY itemid;

# 2.2.
# The stats avlb3 and avg3 have to be calculated using "now minus 3 days"
# timestamp. To avoid subqueries, a temporary table is created and then stats
# are copied to the main table.
# availability3 = count3 / (3 * 24) * 100% = count30/0.72 (per cent)
    SET @debug_status = "step 2.2";

    SET t3 = curtime - 259200; # 3 * 24 * 3600 = 259 200
    CREATE TEMPORARY TABLE `t_3dayspan` 
        SELECT 
                itemid, 
                cast((count(h.val) / 0.72) AS decimal(5,2)) as f3,
                cast(avg(h.val) AS decimal(5,2)) as a3
            FROM hist AS h
            WHERE htime > t3
            GROUP BY itemid;
    UPDATE stat AS s, t_3dayspan AS t
        SET s.avlb3 = t.f3, s.avg3 = t.a3
        WHERE s.itemid = t.itemid
        AND s.rtime = curtime;

# 2.3.
# avg1 have to be calculated using "now minus 1 day" timestamp. Quite similar
# to the previous block.
    SET t1 = curtime -  86400; # 24 * 3600 = 86 400
    SET @debug_status = "step 2.3";

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

# 2.4.
# Set t1 equal to "not later than 20 hours ago", i.e. 20 * 3600 = 72000
    SET t1 = curtime - 72000;

# Get latest timestamp that is older than 20 hours. If previous report was made
# not exactly 24 hours ago, we take report time that is relatively close.
# Fill yesterdays timestamp and avg1, and todays timestamp. Todays avg1 will be
# added further.
    SET @debug_status = "step 2.4";

    CREATE TEMPORARY TABLE `t_diff`
        SELECT
                itemid,
                max(rtime) AS ptime,
                avg1 AS avg1p,
                curtime AS ctime,
                NULL AS avg1c,
                min(rtime) AS mtime,
                NULL AS avg30c,
                NULL AS avg30m
            FROM stat
            WHERE rtime < t1
            GROUP BY itemid;

# Add todays avg1 and avg30.
    UPDATE t_diff AS t, stat AS s
        SET t.avg1c = s.avg1, t.avg30c = s.avg30
        WHERE t.itemid = s.itemid
        AND s.rtime = curtime;

# Add last months avg30.
    UPDATE t_diff AS t, stat AS s
        SET t.avg30m = s.avg30
        WHERE t.itemid = s.itemid
        AND t.mtime = s.rtime;

# Calculate dif1 as "todays avg" - "yesterdays avg".
    SET @debug_status = "dif1";

    UPDATE stat AS s, t_diff AS t
        SET s.dif1 = t.avg1c - t.avg1p
        WHERE t.itemid = s.itemid
        AND s.rtime = curtime;

# Calculate dif30 as "todays avg30" - "last months avg30"
    SET @debug_status = "dif30";

    UPDATE stat AS s, t_diff AS t
        SET s.dif30 = t.avg30c - t.avg30m
        WHERE t.itemid = s.itemid
        AND s.rtime = curtime;

# Calculate avg3dif. 
    SET @debug_status = "avg3dif";

    CREATE TEMPORARY TABLE `t_avgdif`
        SELECT itemid, avg(dif1) AS a
            FROM stat
            WHERE rtime >= t3
            GROUP BY itemid;
    UPDATE stat AS s, t_avgdif as t
        SET s.avg3dif = t.a
        WHERE s.itemid = t.itemid;

# Cleanup
    DROP TABLE t_3dayspan;
    DROP TABLE t_1dayspan;
    DROP TABLE t_diff;
    DROP TABLE t_avgdif;

# 3.
# Delete records that are older than 30 days.
    SET @debug_status = "Cleanup";

    SET t30 = curtime - 2592000; # 30 * 24 * 3600 = 2 592 000
    DELETE FROM stat
        WHERE rtime < t30;

# 4.
# If the procedure didn't stop abnormally, we update the status variable, which
# is then written into a summary table by report_master procedure.
    SET @debug_status = "OK";
    SET p_status = "OK";
END//

DELIMITER ;
