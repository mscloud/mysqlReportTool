<?php
// rep_functions.php

function my_input($conn, $input) {

	$result = $conn->query($input);
	if (!$result) die ($conn->error);

	$rows = $result->num_rows;
	for ($i = 0; $i < $rows; $i++) {
		$result->data_seek($i);
		$row = $result->fetch_array(MYSQLI_ASSOC);
		print_r($row);
		echo '<br>';
	}
	
	$result->close(); // Close object after its usage.

}

?>