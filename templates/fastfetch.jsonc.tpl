// {{generated_note}}
{
  "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
  "logo": {
    "type": "data",
    "source": "$1      .-----.\n$1    .'   $2·$1   '.\n$1   /  $2o$1     $2·$1  \\\n$1  :      $2.$1      :\n$3───────────────────\n$4   ─────────────\n$5      ───────\n$5        ───",
    "color": { "1": "{{glow|ansi}}", "2": "{{glow_hi|ansi}}", "3": "{{glow|ansi}}", "4": "{{mute|ansi}}", "5": "{{line|ansi}}" },
    "padding": { "top": 4, "left": 2, "right": 4 }
  },
  "display": {
    "separator": "",
    "brightColor": false,
    "key": { "width": 14 },
    "color": { "keys": "{{mute|ansi}}", "output": "{{text|ansi}}", "separator": "{{line|ansi}}" },
    "percent": { "type": ["num"] },
    "size": { "binaryPrefix": "jedec", "ndigits": 1 }
  },
  "modules": [
      {
          "type": "title",
          "format": "{#1;{{text|ansi}}}{user-name}{#0;{{mute|ansi}}} on {#1;{{glow|ansi}}}{host-name}"
      },
      { "type": "custom", "format": "{#{{line|ansi}}}────────────────────────────────" },
      {
          "type": "os",
          "key": "{#{{glow|ansi}}}  {#{{mute|ansi}}}os",
          "format": "{pretty-name}"
      },
      {
          "type": "kernel",
          "key": "{#{{glow|ansi}}}  {#{{mute|ansi}}}kernel",
          "format": "{release}"
      },
      {
          "type": "uptime",
          "key": "{#{{glow|ansi}}}  {#{{mute|ansi}}}uptime"
      },
      {
          "type": "packages",
          "key": "{#{{glow|ansi}}}  {#{{mute|ansi}}}packages"
      },
      { "type": "custom", "format": "{#{{line|ansi}}}────────────────────────────────" },
      {
          "type": "wm",
          "key": "{#{{glow|ansi}}}  {#{{mute|ansi}}}wm",
          "format": "{pretty-name} {version}"
      },
      {
          "type": "shell",
          "key": "{#{{glow|ansi}}}  {#{{mute|ansi}}}shell",
          "format": "{pretty-name} {version}"
      },
      {
          "type": "terminal",
          "key": "{#{{glow|ansi}}}  {#{{mute|ansi}}}terminal",
          "format": "{pretty-name}"
      },
      {
          "type": "display",
          "key": "{#{{glow|ansi}}}󰍹  {#{{mute|ansi}}}display",
          "format": "{width}×{height} @ {refresh-rate} Hz"
      },
      { "type": "custom", "format": "{#{{line|ansi}}}────────────────────────────────" },
      {
          "type": "cpu",
          "key": "{#{{glow|ansi}}}  {#{{mute|ansi}}}cpu",
          "format": "{name}  {#{{mute|ansi}}}{cores-logical} threads",
          "temp": false
      },
      {
          "type": "gpu",
          "key": "{#{{glow|ansi}}}󰢮  {#{{mute|ansi}}}gpu",
          "format": "{name}",
          "hideType": "integrated"
      },
      {
          "type": "memory",
          "key": "{#{{glow|ansi}}}  {#{{mute|ansi}}}memory",
          "format": "{used} {#{{mute|ansi}}}of{#} {total}  {#{{mute|ansi}}}{percentage}"
      },
      {
          "type": "disk",
          "key": "{#{{glow|ansi}}}  {#{{mute|ansi}}}disk",
          "folders": "/",
          "format": "{size-used} {#{{mute|ansi}}}of{#} {size-total}  {#{{mute|ansi}}}{size-percentage}"
      },
      "break",
      {
          "type": "custom",
          "format": "{#{{glow_lo|ansi}}}● {#{{glow|ansi}}}● {#{{glow_hi|ansi}}}● {#{{text|ansi}}}● {#{{dim|ansi}}}● {#{{mute|ansi}}}● {#{{signal|ansi}}}● {#{{ansi_yellow|ansi}}}● {#{{ansi_green|ansi}}}● {#{{ansi_blue|ansi}}}● {#{{ansi_magenta|ansi}}}●"
      },
      "break"
  ]
}
