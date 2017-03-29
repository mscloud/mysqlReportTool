# proc_master.sql

#===============================================#
#       Superprocedure                          #
#   0.  Initialize variables                    #
#   1.  Call open_sum()                         #
#   2.  Call pop_def()                          #
#   3.  Call pop_hist()                         #
#   4.  Call pop_stat()                         #
#   5.  Print summary                           #
#===============================================#

USE reporter;
DELIMITER //

CREATE PROCEDURE report_master()
BEGIN

    DECLARE curtime INT;
    DECLARE p_status VARCHAR;
    SET curtime = unix_timestamp(now());
    SET p_status = "unknown";

    CALL open_sum(curtime);

    SELECT "Updating items list..." AS status;
    CALL pop_def(curtime, p_status);
    UPDATE sum 
        SET def = p_status
        WHERE rtime = curtime;
    SET p_status = "unknown";

    SELECT "Updating values history..." AS status;
    CALL pop_hist(curtime, p_status);
    UPDATE sum 
        SET hist = p_status
        WHERE rtime = curtime;
    SET p_status = "unknown";

    SELECT "Calculating statistics..." AS status;
    CALL pop_stat(curtime, p_status);
    UPDATE sum 
        SET stat = p_status
        WHERE rtime = curtime;

SELECT * FROM sum WHERE rtime = curtime;
END//

DELIMITER ;
