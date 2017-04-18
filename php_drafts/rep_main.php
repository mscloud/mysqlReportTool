<?php
// rep_main.php
    require_once 'rep_dbaccess.php';
    require_once 'rep_html.php';
    require_once 'rep_functions.php';

    echo $html_head;

    // code start

    $conn = new mysqli($hn, $un, $pw, $db);
    if ($conn->connect_error) die ($conn->connect_error);

	// $input = 'SHOW TABLES'; // phpaccess.one
	$input = 'INSERT INTO one (name, val) VALUES ("Light", "LED")';
	$input = 'SELECT * FROM one';

	my_input($conn, $input);

    // code end

    echo $html_tail;
?>
