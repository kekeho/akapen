import osproc
import streams
import sequtils
import strutils
import cpuinfo
import random
import os
import times
from math import pow

type status* = enum
    CD = "Compiled"  # Waiting execute
    AC = "AC",  # Accepted
    WA = "WA",  # Wrong Answer
    TLE = "TLE",  # Time Limit Exceeded
    MLE = "MLE",  # Memory Limit Exceeded
    CE = "CE",  # Compillation Error
    RE = "RE", # Runtime Error
    OLE = "OLE", # Output Limit Error
    JSE = "JSE"  # Judge server error


type docker_run_mode* = enum
    # compile or run
    COMPILE = 0
    RUN = 1


proc rand_core(): int =
    randomize()
    return rand(0..cpuinfo.countProcessors()-1)


proc interval_to_nanosec(interval: times.TimeInterval): int64 =
    var nanosec: int64 = interval.nanoseconds
    nanosec += interval.microseconds * 10.0.pow(3.0).int
    nanosec += interval.milliseconds * 10.0.pow(6.0).int
    nanosec += interval.seconds * 10.0.pow(9.0).int
    nanosec += interval.minutes * 10.0.pow(9.0).int * 60
    nanosec += interval.hours * 10.0.pow(9.0).int * 3600
    nanosec += interval.days * 10.0.pow(9.0).int * 3600 * 24
    nanosec += interval.weeks * 10.0.pow(9.0).int * 3600 * 24 * 7
    nanosec += interval.months * 10.0.pow(9.0).int * 3600 * 24 * 7 * 31
    nanosec += interval.years * 10.0.pow(9.0).int * 3600 * 24 * 7 * 31 * 12
    return nanosec


proc docker_run*(mode: docker_run_mode, arguments: seq[string], standard_input: string = "", memory : string = "", nanosec: int = -1): array[4, string] =
    ## Run docker container with arguments and stdin
    var args: seq[string] = @["run"]
    if memory != "":
        args &= @["--memory="&memory]
    
    if mode == docker_run_mode.RUN:
        args &= @["--cpuset-cpus=" & rand_core().intToStr]  # Set single core (random)
        args &= @["--ulimit", "fsize=1000000:1000000"]  # file limit (1MB)
        args &= @["--pids-limit", "10"]  # Process limit (anti-forkbomb)
        args &= @["--cpu-period=100000", "--cpu-quota=5000"]  # CPU: 5%

    args &= arguments
    let p: osproc.Process = osproc.startProcess("docker", args=args, options = {poUsePath})
    let start_time: times.TimeInterval = getTime().toTimeInterval

    # stdin
    if standard_input != "":
        p.inputStream.write(standard_input)
        p.inputStream.close()
    
    let exit_status: string = p.waitForExit().intToStr
    let end_time: times.TimeInterval = getTime().toTimeInterval
    
    # stdout, stderr
    let output = p.outputStream.readAll()
    let err = p.errorStream.readAll()

    p.close()
    
    let exec_time: int64 = (end_time - start_time).interval_to_nanosec
    return [output, err, exit_status, $exec_time]


proc get_status*(standard_output: string, standard_error: string, assertion: string, time: int, exec_time: int): status = 
    if standard_error.len != 0:
        result = status.RE
    if exec_time > time:
        echo exec_time, " ", time
        result = status.TLE
    elif standard_output != assertion:
        result = status.WA
    else:
        result = status.AC