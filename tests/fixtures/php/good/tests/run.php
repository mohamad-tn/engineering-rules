<?php
require __DIR__ . "/../src/add.php";
if (Demo\add(1, 2) !== 3) { fwrite(STDERR, "bad sum\n"); exit(1); }
echo "ok\n";
