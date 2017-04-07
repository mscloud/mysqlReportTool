# proc_open_sum.sql

#===============================================#
#       Update summary table                    #
#   1.  Create table, if not created already    #
#   2.  Create new entry with current time      #
#   3.  Remove entries older than 12 months     #
#===============================================#

USE reporter;
DELIMITER //

CREATE PROCEDURE open_sum(IN curtime INT)
BEGIN

# 1.
# The `sum` table keeps results of execution of each subroutine.
# Before filling the table with data, we check that the table does exist.
# 
# Description of columns.
# `id`: auto-incremented numeric id for each report, the primary key.
# `rtime`: A timestamp in unix format. It represents time at which report was
# created.
# `def`: result of pop_def(...)
# `hist`: result of pop_hist(...)
# `stat`: result of pop_stat(...)
# these columns have 4 possible values:
#   'OK'        - procedure was called and finished successfully;
#   'Fail'      - procedure was called and exited by handler (warning);
#   'unknown'   - procedure was not called or finished abnormally(major);
#   'not set'   - update command was not executed (critical problem);
    CREATE TABLE IF NOT EXISTS `sum` (
        `id` int(11) NOT NULL AUTO_INCREMENT,
        `rtime` int(11) NOT NULL,
        `def` varchar(8) NOT NULL DEFAULT 'not set',
        `hist` varchar(8) NOT NULL DEFAULT 'not set',
        `stat` varchar(8) NOT NULL DEFAULT 'not set',
        PRIMARY KEY (`id`),
        KEY `rtime` (`rtime`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8;

# 2.
# Initialize new line. id is generated automatically, rtime is written, other
# columns have default values.
    INSERT INTO sum (rtime) 
        VALUE (curtime);

# 3.
# Cleanup. Records older than one year (365 days = 365*24*3600 = 31 536 000)
# are removed.
    DELETE FROM sum 
        WHERE rtime < (curtime - 31536000);

END//

DELIMITER ;
