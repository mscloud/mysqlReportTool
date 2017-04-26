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

function my_edit_items($conn, $posted) {
    echo  "<table><tr>"
        . "<th>ID</th>"
        . "<th>Host</th>"
        . "<th>Role</th>"
        . "<th>Edit</th>"
        . "</tr>";
    if ($posted['newrole']) {
        $statement = 
              "UPDATE def "
            . "SET role = \"".$posted['newrole']."\" "
            . "WHERE itemid = ".$posted['itemid'];
        if (!$conn->query($statement)) die ($conn->error);
    }
    
    $statement = 
        "SELECT itemid, host, role "
      . "FROM def "
      . "ORDER BY role";
    
    $result = $conn->query($statement);
    if (!$result) die ($conn->error);
        
    for ($j = 0; $j < $result->num_rows; ++$j) {
        $result->data_seek($j);
        $row = $result->fetch_array(MYSQLI_ASSOC);
        echo  "<tr>"
            . "<td>".$row['itemid']."</td>"
            . "<td>".$row['host']."</td>"
            . "<td>".$row['role']."</td>"
            . "<td>"
            . "<form action=\"?p=cfg\" method=\"post\">"
            . "<input type=\"text\" name=\"newrole\">"
            . "<input type=\"hidden\" name=\"itemid\" "
                . "value=\"".$row['itemid']."\">"
            . "<input type=\"submit\" value=\"Change role\">"
            . "</form>"
            . "</td>"
            . "</tr>";
    }
    echo  "<th colspan=3>Total: ".$result->num_rows." items</th>"
        . "<th></th>"
        . "</table>";
    $result->free();
}
