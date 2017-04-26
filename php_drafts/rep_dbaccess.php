<?php
// rep_dbaccess.php
$hn = 'localhost';
$un = 'phpclient';
$pw = 'pI-IpcIient';
$db = 'reporter';

$conn = new mysqli($hn, $un, $pw, $db);
if ($conn->connect_error) 
    die ("MySQL connection error: $conn->connect_error");