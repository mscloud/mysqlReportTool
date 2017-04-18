<?php
//index.php

$libdir = 'php_drafts/';

require_once $libdir.'rep_dbaccess.php';
require_once $libdir.'rep_html.php';

echo $html_head;

// main part of code
require_once $libdir.'rep_main.php';

echo $html_tail;
