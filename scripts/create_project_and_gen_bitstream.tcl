set TCLPATH [file dirname [info script]]
puts $TCLPATH
source $TCLPATH/build_utils.tcl
source $TCLPATH/setup_project.tcl

# Thread count constants
set SYNTH_JOBS_WINDOWS 20
set SYNTH_JOBS_LINUX 20
set IMPL_JOBS_WINDOWS 4
set IMPL_JOBS_LINUX 4

# Detect if running on Linux, assign appropriate job counts
if {[string equal $tcl_platform(os) "Linux"]} {
    set SYNTH_JOBS $SYNTH_JOBS_LINUX
    set IMPL_JOBS $IMPL_JOBS_LINUX
    puts "Running on Linux - Synth jobs: $SYNTH_JOBS, Impl jobs: $IMPL_JOBS"
} else {
    set SYNTH_JOBS $SYNTH_JOBS_WINDOWS
    set IMPL_JOBS $IMPL_JOBS_WINDOWS
    puts "Running on Windows - Synth jobs: $SYNTH_JOBS, Impl jobs: $IMPL_JOBS"
}

# Launch synthesis on top level
reset_run synth_1
launch_runs synth_1 -jobs $SYNTH_JOBS
wait_on_run synth_1

# Launch implementation on top level
reset_run impl_1
set_property strategy Performance_Explore [get_runs impl_1]
launch_runs impl_1 -to_step write_bitstream -jobs $IMPL_JOBS
wait_on_run impl_1

# One-line report + checks
report_impl_results impl_1

write_hw_platform -fixed -force -include_bit -file ../$project_name.xsa
file copy -force $project_name.runs/impl_1/$project_name.bit ../$project_name.bit