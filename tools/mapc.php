<?php

function writeword($a) {
  echo chr($a);
  echo chr($a >> 8);
}

function writetilesetinfo($map, $name) {
  foreach($map->tilesets as $tileset) {
    if($tileset->name == $name) {
      writeword($tileset->columns);
      writeword($tileset->firstgid);
      return;
    }
  }

  error_log("tileset '" . $name . "' must be defined");
  exit(1);
}

$map = json_decode(file_get_contents($argv[1]));

echo "rrl";
echo chr(0);

writeword($map->width);
writeword($map->height);

$layercount = 0;
foreach($map->layers as $layer) {
  if($layer->type == "tilelayer") ++$layercount;
}

writeword($layercount);

// header padding
echo chr(0xff);
echo chr(0xff);

writetilesetinfo($map, "tileset");
writetilesetinfo($map, "light");
writetilesetinfo($map, "vis");
writetilesetinfo($map, "collision");


foreach($map->layers as $layer) {
  if($layer->type == "tilelayer")
  echo pack('i*', ...$layer->data);
}


// generate portal info

function makeportal(&$r, $a, $b, $w, $f) {
  $ii = ((int)($a->x / 256) + (int)($a->y / 256) * $w) * 16;
  $r[$ii + 0] = 0x80 | ($f == "hmirror" ? 2 : 0) | ($f == "vmirror" ? 4 : 0);
  $r[$ii + 2] = $a->x & 255;
  $r[$ii + 3] = ($a->x + $a->width) & 255;
  $r[$ii + 4] = $a->y & 255;
  $r[$ii + 5] = ($a->y + $a->height) & 255;
  $r[$ii + 6] = $f == "hmirror" ? 256 * $w - ($b->x + $b->width) - $a->x : $b->x - $a->x;
  $r[$ii + 7] = $f == "vmirror" ? 256 * $w - ($b->y + $b->height) - $a->y : $b->y - $a->y;
}

$portals = [];

$roomdata = [];

for($ii = 0; $ii < $map->width * $map->height / (32 * 32) * 16; ++$ii) $roomdata[$ii] = 0; 

foreach($map->layers as $layer) {
  if($layer->type == "objectgroup") {

    foreach($layer->objects as $object) {
      @list($type, $name, $point) = explode("_", $object->name);
      $ii = ((int)($object->x / 256) + (int)($object->y / 256) * (int)($map->width / 32)) * 16;

      switch($type) {
      case "key":
        $mirror = '';
        @list($key, $lock, $entry, $mirror) = explode("_", $object->type);
        $roomdata[$ii + 9] = (($mirror == "hmirror") ? 0x20 : 0) + (int)$key;
        $roomdata[$ii + 10] = (int)$lock;
        $roomdata[$ii + 11] = (($mirror == "nointeraction") ? 0x80 : 0) + (int)$entry + 1;
        $roomdata[$ii + 12] = $object->x & 255;
        $roomdata[$ii + 13] = $object->y & 255;
        break;
      case "portal":
        if (!isset($portals[$name])) {
         $portals[$name] = [];
        }
        $portals[$name][$point] = $object;
        break;
      case "barrier":
        if($object->width > $object->height) {
          $roomdata[$ii + 8] |= (($object->y & 255) < 128) ? 4 : 8;
        } else {
          $roomdata[$ii + 8] |= (($object->x & 255) < 128) ? 1 : 2;
        }
        break;
      }
    }
  }
}

foreach($portals as $key => $portal) {
  makeportal($roomdata, $portal["entry"], $portal["exit"], (int)($map->width / 32), $portal["entry"]->type);
}

echo pack('i*', ...$roomdata);


