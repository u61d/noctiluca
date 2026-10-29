# {{generated_note}}
typeset -gA NOCT
NOCT[void]='{{void}}'
NOCT[ink]='{{ink}}'
NOCT[slate]='{{slate}}'
NOCT[line]='{{line}}'
NOCT[mute]='{{mute}}'
NOCT[dim]='{{dim}}'
NOCT[text]='{{text}}'
NOCT[glow]='{{glow}}'
NOCT[glow_hi]='{{glow_hi}}'
NOCT[glow_lo]='{{glow_lo}}'
NOCT[signal]='{{signal}}'
NOCT[red]='{{ansi_red}}'
NOCT[green]='{{ansi_green}}'
NOCT[yellow]='{{ansi_yellow}}'
NOCT[blue]='{{ansi_blue}}'
NOCT[magenta]='{{ansi_magenta}}'
NOCT[cyan]='{{ansi_cyan}}'
NOCT[menu]='{{glow_lo|ansi}}'
NOCT[menu_text]='{{glow_hi|ansi}}'

export LS_COLORS='di=1;{{glow|ansi}}:ln={{ansi_cyan|ansi}}:ex=1;{{text|ansi}}:so={{ansi_magenta|ansi}}:pi={{ansi_yellow|ansi}}:bd={{ansi_yellow|ansi}}:cd={{ansi_yellow|ansi}}:or={{signal|ansi}}:mi={{signal|ansi}}:*.tar={{ansi_red|ansi}}:*.zip={{ansi_red|ansi}}:*.gz={{ansi_red|ansi}}:*.zst={{ansi_red|ansi}}:*.png={{ansi_magenta|ansi}}:*.jpg={{ansi_magenta|ansi}}:*.webp={{ansi_magenta|ansi}}:*.mp4={{ansi_magenta|ansi}}:*.mp3={{ansi_magenta|ansi}}:*.md={{dim|ansi}}'
export EZA_COLORS="reset:${LS_COLORS}:da={{mute|ansi}}:sn={{dim|ansi}}:sb={{mute|ansi}}:uu={{dim|ansi}}:gu={{mute|ansi}}:ur={{glow|ansi}}:uw={{ansi_yellow|ansi}}:ux={{ansi_green|ansi}}:ue={{ansi_green|ansi}}:gr={{mute|ansi}}:gw={{mute|ansi}}:gx={{mute|ansi}}:tr={{mute|ansi}}:tw={{mute|ansi}}:tx={{mute|ansi}}:xx={{line|ansi}}:ga={{ansi_green|ansi}}:gm={{ansi_yellow|ansi}}:gd={{signal|ansi}}:gv={{ansi_blue|ansi}}:gt={{ansi_magenta|ansi}}:hd=4;{{dim|ansi}}"
