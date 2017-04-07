# proc_master.sql

#===============================================#
#       Superprocedure                          #
#   0.  Declare variables                       #
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

# 0. 
# curtime is a timestamp in unix format that will be used throughout the report
# process.
# p_status is a variable into which all procedures write their status.
    DECLARE curtime INT;
    DECLARE p_status VARCHAR(8);
    SET curtime = unix_timestamp(now());

# 1.
# This procedure adds a new line to a summary table and records the timestamp.
    CALL open_sum(curtime);

# 2.
# Print status message.
# Reset the status variable.
# Call a procedure.
# Write status into a summary table.
#   Success:            OK
#   Warning:            Fail
#   Procedure stopped:  unknown
    SELECT now() AS time, "Updating items list..." AS status;
    SET p_status = "unknown";
    CALL pop_def(curtime, p_status);
    UPDATE sum 
        SET def = p_status
        WHERE rtime = curtime;

# 3.
# Exactly the same as previous block.
    SELECT now() AS time, "Updating values history..." AS status;
    SET p_status = "unknown";
    CALL pop_hist(curtime, p_status);
    UPDATE sum 
        SET hist = p_status
        WHERE rtime = curtime;

# 4.
# Exactly the same as two previous blocks.
    SELECT now() AS time, "Calculating statistics..." AS status;
    SET p_status = "unknown";
    CALL pop_stat(curtime, p_status);
    UPDATE sum 
        SET stat = p_status
        WHERE rtime = curtime;

# 5.
# Print the last line from the summary table.
SELECT * FROM sum WHERE rtime = curtime;
END//


# appendix.
-- CREATE EVENT daily_report
--     ON SCHEDULE EVERY 1 DAY
--     STARTS '2017-03-30 03:30:00' ENABLE
--     DO
--         BEGIN
--             CALL report_master();
--         END//

DELIMITER ;

# set global variable to enable scheduled events
-- SET GLOBAL event_scheduler = ON;