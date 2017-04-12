# proc_out_stat.sql

#===============================================#
#       Print stats and warnings                #
#   0.  Get the latest report time              #
#   1.  Print warnings                          #
#   2.  Then show the whole stats table         #
#   3.  Then print out report summary           #
#===============================================#

USE reporter;
DELIMITER //

CREATE PROCEDURE out_stat()
BEGIN

# 0.
    DECLARE tstamp INT;
    SET tstamp = (SELECT rtime FROM sum ORDER BY rtime LIMIT 1);
    SELECT from_unixtime(tstamp) AS "Statistics generated at:", now() AS "Current time:";

# 1.
    SELECT "Monthly average change > 3 dbm" AS `Warnings`;
    SELECT 
            d.host, d.role, s.avlb30,
            s.avg30, s.avg3, s.avg1, s.dif1, s.avg3dif, s.dif30
        FROM def AS d, stat AS s
        WHERE d.itemid = s.itemid
        AND s.rtime = tstamp
        AND abs(s.dif30) > 3
        ORDER BY s.dif30 DESC;

    SELECT "Daily average change > 3 dbm" AS `Warnings`;
    SELECT 
            d.host, d.role, s.avlb3,
            s.avg30, s.avg3, s.avg1, s.dif1, s.avg3dif, s.dif30
        FROM def AS d, stat AS s
        WHERE d.itemid = s.itemid
        AND s.rtime = tstamp
        AND abs(s.dif1) > 3
        ORDER BY s.dif1 DESC;

    SELECT "Input too low" AS `Warnings`;
    SELECT 
            d.host, d.role, s.avlb3, 
            s.avg30, s.avg3, s.avg1, s.dif1, s.avg3dif, s.dif30
        FROM def AS d, stat AS s
        WHERE d.itemid = s.itemid
        AND s.rtime = tstamp
        AND s.avg1 < -21
        ORDER BY s.avg1 ASC;

    SELECT "Input too high" AS `Warnings`;
    SELECT 
            d.host, d.role, s.avlb3, 
            s.avg30, s.avg3, s.avg1, s.dif1, s.avg3dif, s.dif30
        FROM def AS d, stat AS s
        WHERE d.itemid = s.itemid
        AND s.rtime = tstamp
        AND s.avg1 > -4
        ORDER BY s.avg1 DESC;

# 2.
    SELECT "Complete table" AS `And also...`;
    SELECT 
            d.host, d.role, s.avlb30, s.avlb3, 
            s.avg30, s.avg3, s.avg1, s.dif1, s.avg3dif, s.dif30
        FROM def AS d, stat AS s
        WHERE d.itemid = s.itemid
        AND s.rtime = tstamp
        ORDER BY d.role;

# 3.
    SELECT "Report on report" AS `Self-giagnostics`;
    SELECT from_unixtime(rtime) as time, def, hist, stat
        FROM sum
        WHERE rtime = tstamp;

END//

DELIMITER ;
