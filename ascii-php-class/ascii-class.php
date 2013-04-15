<?php

define('MIN_COL',50);
define('MAX_COL',254);
define('EXT','txt');

class AsciiImage
{
  var $dir;
  var $files;
  var $image;
  var $rgb;
  var $step;

  function AsciiImage($dir) {
        $this->dir=$dir;
        $this->rgb=$this->random_color();
  }

  function prepareImage() {
   if(!is_dir($this->dir)) { $this->send404(); die(''); }
   if ($handle = opendir($this->dir)) {
    while (false !== ($file = readdir($handle))) {
                if(is_file($this->dir.'/'.$file) AND ($this->getFileExtension($this->dir.'/'.$file) == '.'.EXT) AND $file != '.' AND $file != '..') {
                        $this->files[]=$file;
                }
    }
    closedir($handle);
        $this->image=$this->files[rand(0,sizeof($this->files)-1)];
   }
  }

  function printImage() {
   $lines = file($this->dir.'/'.$this->image);
   $this->step=ceil(MAX_COL/sizeof($lines));
   $step=$this->step;
    echo "<font size=\"-2\"><table align=\"center\" border=\"0\" cellpadding=\"0\" cellspacing=\"0\">\n";
        $rgb=$this->rgb;
        $lrgb=$rgb;
        foreach ($lines as $line_num => $line) {
                $hcol='';
                foreach ($rgb as $i => $col) {
                        $lcol = $lrgb[$i];
                        $hcol .= sprintf("%02X", $col);
                        if($lcol>$col) {
                                $rgb[$i]-=$step;
                        } else
                        if($lcol<$col) {
                                $rgb[$i]+=$step;
                        } else
                        if($lcol==$col) { $rgb[$i]+=$step; }

                        if($rgb[$i]>MAX_COL) {
                                $rgb[$i]=MAX_COL-$step;
                                $lrgb[$i]=MAX_COL;
                        } else
                        if($rgb[$i]<MIN_COL) {
                                $rgb[$i]=MIN_COL+$step;
                                $lrgb[$i]=MIN_COL;
                        }
                }
                echo "\t<tr><td><span style=\"color: #".$hcol.";\">" . str_replace("\r","",str_replace("\n", "", htmlspecialchars($line))) . "</span></td></tr>\n";
        }
        echo "</table></font>";
  }

  function send404() {
        header('Location: 404');
  }

  function getFileExtension($filename) {
    return substr($filename, strrpos($filename, '.'));
  }

  function random_color() {
    mt_srand((double)microtime()*1000000);
    $c = '';
        for ($i=0; $i<3; $i++) {
                $rgb[]=mt_rand(MIN_COL, MAX_COL);
        }
        return $rgb;
  }

}

?>

