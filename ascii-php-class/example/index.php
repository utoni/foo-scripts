<?php
function microtime_float()
{
    list($usec, $sec) = explode(" ", microtime());
    return ((float)$usec + (float)$sec);
}

$time_start=microtime_float();

require_once('../ascii.class.inc.php');
?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "DTD/xhtml1-strict.dtd">
<?php
  echo "<!-- you're welcome ".$_SERVER['REMOTE_ADDR']." -->\n";
  echo "<!-- ".htmlspecialchars($_SERVER['HTTP_USER_AGENT']) . " -->\n\n";
?>
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
<title>no content</title>
<link rel="Stylesheet" media="all" type="text/css" href="style.css">
</head>
<body bgcolor="black">

<div id="content_container">
<div id="content"><pre>
<?php
        $ascii = new AsciiImage("./ascii");
        $ascii->prepareImage();
        $ascii->printImage();
?>
</pre></div>
        <div id="footer_container">
                <div id="footer">
                        <?php
                                        $time_end=microtime_float();
                                        $time=round(($time_end-$time_start)*1000,2);
                                        $file=$ascii->dir."/".$ascii->image;
                                        echo $time." ms ";
                                        echo "&raquo; <a href=\"ascii/".basename($file)."\">".basename($ascii->image,'.'.EXT)."</a>\n";
                                ?>
                </div>
        </div>
</div>

</body>
</html>
<?php
        unset($ascii);
        echo "<!-- EoF -->\n";
?>
