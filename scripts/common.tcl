# create_project_impl.tcl
# Implements the actual project creation logic
# Called by both create_project.tcl and create_project_and_gen_bitstream.tcl

set project_name "kria_zynq"

# ensure vivado folder exists (ignored in git)
if {![file exists "$TCLPATH/../vivado"]} {
    puts "Creating vivado directory"
    file mkdir "$TCLPATH/../vivado"
}

cd $TCLPATH/../vivado/

# Create vivado project
create_project $project_name ./$project_name -part xck26-sfvc784-2LV-c
set_property target_language VHDL [current_project]
set_property -name "enable_vhdl_2008" -value "1" -objects [current_project]
set_property source_mgmt_mode All [current_project]
set_property target_simulator Questa [current_project]
set_property -name {questa.compile.vhdl_syntax} -value {2008} -objects [get_filesets sim_1]

cd ./$project_name

# Import user repository
set_property ip_repo_paths ../../ip [current_project]
update_ip_catalog

# Add source HDL
foreach source_hdl [glob ../../src/hdl/*.vhd] {
    puts $source_hdl
    add_files -norecurse $source_hdl
    set_property file_type {VHDL 2008} [get_files $source_hdl]
}

# Set old VHDL for sources intended to be used in block design
#set_property file_type VHDL [get_files  ../../src/hdl/example.vhd]

# Generate block design
source ../../src/bd/zynq.tcl
close_bd_design [get_bd_designs zynq]
make_wrapper -files [get_files $project_name.srcs/sources_1/bd/zynq/zynq.bd] -top
add_files -norecurse $project_name.gen/sources_1/bd/zynq/hdl/zynq_wrapper.vhd

# Add constraints
add_files -fileset constrs_1 -norecurse ../../src/const/pinout.xdc
set_property used_in_synthesis false [get_files ../../src/const/pinout.xdc]

add_files -fileset constrs_1 -norecurse ../../src/const/timing.xdc
set_property used_in_synthesis false [get_files ../../src/const/timing.xdc]
set_property target_constrs_file ../../src/const/timing.xdc [current_fileset -constrset]

update_compile_order -fileset sources_1
