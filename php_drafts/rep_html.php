<?php
// rep_html.php
    $html_head = <<<_END
    <!DOCTYPE html>
    <html>
        <head>
            <link href="styles/style.css" rel="stylesheet">
            <title>Report</title>
        </head>

        <body>
            <h1>Last Mile Optical Power Report</h1>
            <hr>
            <a href="?">Main</a>
            <a href="?p=rep">Reports</a>
            <a href="?p=upd">Get Fresh Data</a>
            <a href="?p=cfg">Edit Items</a>
            <br><hr>

_END;

    $html_tail = <<<_END
            <hr>
        </body>
    </html>
_END;
