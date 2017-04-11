# proc_out_cur.sql

#===============================================#
#       Print latest values from zabbix         #
#   1.  Create a temporary table and fill it    #
#       with last values from zabbix.history    #
#       and zabbix.history_str                  #
#   2.  Print temporary table and drop it       #
#===============================================#

USE reporter;
DELIMITER //

CREATE PROCEDURE out_cur()
BEGIN

# 0.
    DECLARE t60 INT;
    SET t60 = unix_timestamp(now()) - 60;

# 1. 
    CREATE TEMPORARY TABLE t_cur
        SELECT 
                d.host, 
                d.role, 
                cast(h.value AS decimal(5,2)) AS val, 
                from_unixtime(h.clock) AS time,
                h.itemid
            FROM reporter.def AS d, zabbix.history as h
            WHERE d.itemid = h.itemid
            AND h.clock > t60
            AND d.role != 'skip'
            GROUP BY h.itemid
        UNION
        SELECT 
                d.host, 
                d.role, 
                cast(hs.value AS decimal(5,2)) AS val, 
                from_unixtime(hs.clock) AS time,
                h.itemid
            FROM reporter.def AS d, zabbix.history as hs
            WHERE d.itemid = hs.itemid
            AND hs.clock > t60
            AND d.role != 'skip'
            GROUP BY hs.itemid    
    ;

# 1.1. 
    UPDATE t_cur 
        SET val = NULL
        WHERE val = 0.00;

# 2. 
    SELECT host, role, time, val 
        FROM t_cur 
        GROUP BY itemid 
        ORDER BY role;

# 2.1. 
    DROP TABLE t_cur;

END//

DELIMITER ;
