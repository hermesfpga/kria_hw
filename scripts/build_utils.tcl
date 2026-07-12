# build_utils.tcl

proc report_impl_results {run_name} {

    set run [get_runs $run_name]

    set status       [get_property STATUS $run]
    set wns          [get_property STATS.WNS $run]
    set failed_nets  [get_property STATS.FAILED_NETS $run]

    set sep "*************************************************************************"

    puts $sep
    puts "Project Summary"
    puts ""
    puts [format "Run                 : %s" $run_name]
    puts [format "Status              : %s" $status]
    puts [format "Failing Nets        : %s" $failed_nets]
    puts [format "Worst Negative Slack: %s" $wns]
    puts $sep

    if {$wns < 0} {
        puts $sep
        puts ""
        puts "ERROR: Negative slack in implementation!"
        puts ""
        puts $sep
        return -code error "Negative slack in $run_name"
    }

    if {$status ne "write_bitstream Complete!"} {
        puts $sep
        puts ""
        puts "ERROR: implementation $run_name did not complete!"
        puts ""
        puts $sep
        return -code error "Implementation $run_name did not complete"
    }

    if {$failed_nets != 0} {
        puts $sep
        puts ""
        puts "ERROR: implementation $run_name has failing nets!"
        puts ""
        puts $sep
        return -code error "Implementation $run_name has failing nets"
    }
}