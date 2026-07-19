# Compatibility entrypoint for the legacy 5-stage project.
set argv {legacy5}
source [file join [file dirname [file normalize [info script]]] create_project.tcl]
