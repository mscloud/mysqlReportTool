# proc_out_stat.sql

#===============================================#
#       Print stats and warnings                #
#   0.  Get the latest report time              #
#   1.  Get the latest value from zabbix.history#
#   2.  First show abnormal items               #
#   3.  Then show the whole stats table         #
#===============================================#

USE reporter;
DELIMITER //

CREATE PROCEDURE out_stat()
BEGIN

# 0.
    DECLARE curtime INT;
    SET curtime = (SELECT max(rtime) FROM sum);

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
    SELECT from_unixtime(curtime) AS "Report generated at:";
    SELECT d.host, d.role, s.avg, s.dev, s.count, 
            s.min, s.max, s.dif, s.cur
        FROM def AS d, stat AS s
        WHERE d.itemid = s.itemid
        AND s.rtime = curtime
        AND ...
        ORDER BY d.role;

# 3.
    SELECT d.host, d.role, s.avg, s.dev, s.count, 
            s.min, s.max, s.dif, s.cur
        FROM def AS d, stat AS s
        WHERE d.itemid = s.itemid
        AND s.rtime = curtime
        ORDER BY d.role;

END//

DELIMITER ;
