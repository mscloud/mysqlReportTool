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
    SET tstamp = (SELECT max(rtime) FROM sum);
    SELECT from_unixtime(tstamp) AS "Report generated at:", now() AS "Current values from Zabbix requested at:";

# 1.
    SELECT "avg1 - avg30 < -3 dbm" AS `Warnings`;
    SELECT 
            d.host, d.role, s.freq30, s.freq3, 
            s.avg30, s.avg3, s.avg1, s.dif1, s.avg3dif
        FROM def AS d, stat AS s
        WHERE d.itemid = s.itemid
        AND s.rtime = tstamp
        AND s.avg1 < s.avg30 - 3
        ORDER BY d.role;

    SELECT "Input too low" AS `Warnings`;
    SELECT 
            d.host, d.role, s.freq30, s.freq3, 
            s.avg30, s.avg3, s.avg1, s.dif1, s.avg3dif
        FROM def AS d, stat AS s
        WHERE d.itemid = s.itemid
        AND s.rtime = tstamp
        AND s.avg1 < -21
        ORDER BY s.avg1;

    SELECT "Input too high" AS `Warnings`;
    SELECT 
            d.host, d.role, s.freq30, s.freq3, 
            s.avg30, s.avg3, s.avg1, s.dif1, s.avg3dif
        FROM def AS d, stat AS s
        WHERE d.itemid = s.itemid
        AND s.rtime = tstamp
        AND s.avg1 > -4
        ORDER BY s.avg1;

# 2.
    SELECT "Complete table" AS `And also...`;
    SELECT 
            d.host, d.role, s.freq30, s.freq3, 
            s.avg30, s.avg3, s.avg1, s.dif1, s.avg3dif
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
