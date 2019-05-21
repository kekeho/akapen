import osproc
import streams
import sequtils
import strutils
import cpuinfo
import random
import os
import json

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


proc nanosec_delta(started_at: string, finished_at: string): uint64 =
    ## docker times format
    var nano_times: array[2, uint64]
    for i, t in [started_at, finished_at]:
        let date: seq[string] = t.split("T")[0].split("-")
        let time: seq[string] = t.split("T")[1].split(":")
        let
            year: uint64 = date[0].parseUInt
            month: uint64 = date[1].parseUInt
            day: uint64 = date[2].parseUInt
            hours: uint64 = time[0].parseUInt
            minitues: uint64 = time[1].parseUInt
            seconds: float64 = time[2][0..^2].parseFloat
    
        nano_times[i] = cast[uint64]((seconds * 1.0e+9).toInt) + (minitues * 6e+10.toInt) + (hours * 3.6e+12.toInt) + (day * 8.64e+13.toInt) + (month * 2.628e+15.toInt) + (year * 31.536e+15.toInt)
    
    return nano_times[1] - nano_times[0]

    

proc docker_run*(mode: docker_run_mode, uuid: string,arguments: seq[string], standard_input: string = "", memory : string = "", nanosec: int = -1): array[4, string] =
    ## Run docker container with arguments and stdin
    var args: seq[string] = @["run"]
    if memory != "":
        args &= @["--memory="&memory]
    
    if mode == docker_run_mode.RUN:
        args &= @["--name=" & uuid]
        args &= @["--cpuset-cpus=" & rand_core().intToStr]  # Set single core (random)
        args &= @["--ulimit", "fsize=1000000:1000000"]  # file limit (1MB)
        args &= @["--pids-limit", "10"]  # Process limit (anti-forkbomb)
        args &= @["--cpu-period=100000", "--cpu-quota=5000"]  # CPU: 5%

    args &= arguments
    let p: osproc.Process = osproc.startProcess("docker", args=args, options = {poUsePath})

    # stdin
    if standard_input != "":
        p.inputStream.write(standard_input)
        p.inputStream.close()
    
    let exit_status: string = p.waitForExit().intToStr
    
    # stdout, stderr
    let output = p.outputStream.readAll()
    let err = p.errorStream.readAll()

    p.close()
    
    var exec_time: uint64 = 0
    if mode == docker_run_mode.RUN:
        # Container exec time (from docker inspect)
        let (inspect_str, status) = osproc.execCmdEx("docker inspect " & uuid)
        if status != 0:
            # Can"t get inpect info from docker engine
            return [output, "Can't get inspect info from docker engine", $status, $(-1)]
        let inspect: json.JsonNode = parseJson(inspect_str)[0]
        let start_time : string = inspect["State"]["StartedAt"].getStr
        let finish_time: string = inspect["State"]["FinishedAt"].getStr
        exec_time = nanosec_delta(start_time, finish_time)

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