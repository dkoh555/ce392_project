set_global_assignment -entity "AUDIO_PLL" -library "lib_AUDIO_PLL" -name IP_TOOL_NAME "altera_pll"
set_global_assignment -entity "AUDIO_PLL" -library "lib_AUDIO_PLL" -name IP_TOOL_VERSION "16.1"
set_global_assignment -entity "AUDIO_PLL" -library "lib_AUDIO_PLL" -name IP_TOOL_ENV "mwpim"
set_global_assignment -library "lib_AUDIO_PLL" -name SPD_FILE [file join $::quartus(sip_path) "AUDIO_PLL.spd"]

set_global_assignment -library "lib_AUDIO_PLL" -name MISC_FILE [file join $::quartus(sip_path) "AUDIO_PLL_sim/AUDIO_PLL.vo"]
