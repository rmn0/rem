<?php

function distance($map, $xx, $yy, $r, $visstarttile)
{
        $distance = 15;
        for($yy2 = $yy - 15; $yy2 <= $yy + 15; ++$yy2)
        for($xx2 = $xx - 15; $xx2 <= $xx + 15; ++$xx2)
        if (($xx2 != $xx || $yy2 != $yy)
        && $xx2 >= 0 && $xx2 < $map->width
        && $yy2 >= 0 && $yy2 < $map->height) {
                $v = $map->layers[5]->data[$yy2 * $map->width + $xx2];
                if(($v > $visstarttile) ^ $r) {
                       $d = (int)(sqrt( ($yy2 - $yy) * ($yy2 - $yy) + ($xx2 - $xx) * ($xx2 - $xx) )) - 1;
                       if($d < $distance) $distance = $d;
                }
        }

        return $distance;
}

$map = json_decode(file_get_contents($argv[1]));


$starttile = 0;
$visstarttile = 0;

  foreach($map->tilesets as $tileset) {
    if($tileset->name == "light") {
      $starttile = $tileset->firstgid;
    }
    if($tileset->name == "collision") {
      $visstarttile = $tileset->firstgid;
    }
  }


$img = unpack("C*", file_get_contents("assets/cloud.raw"));

for($yy = 0; $yy < $map->height; ++$yy)
for($xx = 0; $xx < $map->width; ++$xx) {
  $l = $map->layers[7]->data[$yy * $map->width + $xx];
  $v = $map->layers[9]->data[$yy * $map->width + $xx];

  $rgb = $img[$yy * 1024 + $xx + 1];

//if($l == 0) {
  $h = (int)(($rgb & 255) / 24);
  if($h < 0) $h = 0;
  if($h > 15) $h = 15;
  $map->layers[7]->data[$yy * $map->width + $xx] = $h + $starttile;
//}

//  if($l == 0) {
//    $d = distance($map, $xx, $yy, $v > $visstarttile, $visstarttile);
//    $map->layers[3]->data[$yy * $map->width + $xx] = $d + $starttile;
//  }
}

file_put_contents($argv[1], json_encode($map));
