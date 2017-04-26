<?php
// rep_main.php

// code start

$got    = filter_input_array(INPUT_GET,  ['p' => NULL], true);
$posted = filter_input_array(INPUT_POST, ['newrole' => NULL, 'itemid' => NULL], true);
$posted['newrole'] = preg_replace("/[^a-z0-9!?:_ ]/i", "_", $posted['newrole']);
print_r($got);
print_r($posted);
switch ($got['p']) {
    case 'cfg': 
        my_edit_items($conn, $posted);
        break;
    default: 
        echo "Invalid address";
        break;
}



// code end
