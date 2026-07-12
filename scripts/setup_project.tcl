set TCLPATH [file dirname [info script]]
puts $TCLPATH

# Source the shared project creation implementation
source $TCLPATH/common.tcl