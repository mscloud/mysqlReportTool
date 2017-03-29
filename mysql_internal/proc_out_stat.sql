# proc_out_stat.sql

#===============================================#
#       Print stats and warnings                #
#   0.  Get the latest report time              #
#   1.  Get the latest value from zabbix.history#
#   2.  First show abnormal items               #
#   3.  Then show the whole stats table         #
#   4.  Then print out report summary           #
#===============================================#

USE reporter;
DELIMITER //

CREATE PROCEDURE out_stat()
BEGIN

# 0.
    DECLARE curtime INT;
    SET curtime = (SELECT max(rtime) FROM sum);
    SELECT from_unixtime(curtime) AS "Report generated at:", now() AS "Current values from Zabbix requested at:";

# 1.
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

# 2.
    SELECT "Max - Min > 3 dbm" AS `Warnings`;
    SELECT d.host, d.role, s.avg, s.dev, s.count, 
            s.min, s.max, s.dif, s.cur
        FROM def AS d, stat AS s
        WHERE d.itemid = s.itemid
        AND s.rtime = curtime
        AND s.dif > 3
        ORDER BY s.dif;

    SELECT "Input too low" AS `Warnings`;
    SELECT d.host, d.role, s.avg, s.dev, s.count, 
            s.min, s.max, s.dif, s.cur
        FROM def AS d, stat AS s
        WHERE d.itemid = s.itemid
        AND s.rtime = curtime
        AND s.avg < -21
        ORDER BY s.avg;

    SELECT "Input too high" AS `Warnings`;
    SELECT d.host, d.role, s.avg, s.dev, s.count, 
            s.min, s.max, s.dif, s.cur
        FROM def AS d, stat AS s
        WHERE d.itemid = s.itemid
        AND s.rtime = curtime
        AND s.avg > -5
        ORDER BY s.avg;

# 3.
    SELECT "Complete table" AS `And also...`;
    SELECT d.host, d.role, s.avg, s.dev, s.count, 
            s.min, s.max, s.dif, s.cur
        FROM def AS d, stat AS s
        WHERE d.itemid = s.itemid
        AND s.rtime = curtime
        ORDER BY d.role;

# 4.
    SELECT "Report on report" AS `Self-giagnostics`;
    SELECT from_unixtime(rtime) as time, def, hist, stat
        FROM sum
        WHERE rtime = curtime;

END//

DELIMITER ;
