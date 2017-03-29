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
    INSERT INTO sum (rtime) 
        VALUE (curtime);

# 3.
    DELETE FROM sum 
        WHERE rtime < (curtime - 31536000);   # 365*24*3600 = 31 536 000

END//

DELIMITER ;
