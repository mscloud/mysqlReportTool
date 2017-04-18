<?php
// rep_main.php


    // code start

    $conn = new mysqli($hn, $un, $pw, $db);
    if ($conn->connect_error) {
        die ($conn->connect_error);
    } else {
        echo 'connection is up</br>';
    }

    // code end


