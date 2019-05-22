import osproc
import streams
import sequtils
import strutils
import cpuinfo
import random
import os
import json
import oids
import unittest

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

    args &= @["--net", "none"]  # Offline

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
    elif exec_time > time:
        echo exec_time, " ", time
        result = status.TLE
    elif standard_output != assertion:
        result = status.WA
    else:
        result = status.AC


proc test*(): void =
    suite "utils test":
        echo "=== testing utils.nim ==="
        test "proc rand_core":
            # Random test
            let cpu_core_count = cpuinfo.countProcessors()
            echo "CPU cores: ", cpu_core_count
            for i in 0..30:
                # if cpu_core_count == 4, rand_core must within 0..3
                check(rand_core() < cpu_core_count)


        test "proc nanosec_delta":
            # Docker inspect format
            let start_time1 = "2019-05-21T17:46:42.666852086Z"
            let finished_time1 = "2019-05-21T17:46:43.666422086Z"
            check(nanosec_delta(start_time1, finished_time1) == 999570000)

            let start_time2 = "2019-05-21T17:46:42.666852086Z"
            let finished_time2 = "2019-05-21T18:57:43.666422086Z"
            check(nanosec_delta(start_time2, finished_time2) == cast[uint64](4260999570000))

        
        let uuid_python3 = oids.genOid()
        let exit_status_python3 = 198
        test "proc docker_run (Compile mode) in python3":
            let lang = "python3"
            let PWD = os.getCurrentDir()
            let BINARY_CACHE_DIR = PWD & "/worker/" & lang & "/bin_cache"
            let code = "print(input()); exit(" & $exit_status_python3 & ")"
            let args = @["-i", "-v", BINARY_CACHE_DIR & ":/bin_cache", "akapenjudge/" & lang & ":compile", code, $uuid_python3]
            var
                output: string
                err: string
                exit_status: string
                exec_time: string
            (output, err, exit_status, exec_time) = docker_run(docker_run_mode.COMPILE, $uuid_python3, args)

            check(output == "")
            check(err == "")
            check(exit_status == "0")
            check(exec_time == "0")
        

        test "proc docker_run (Run mode) in python3":
            let lang = "python3"
            let PWD = os.getCurrentDir()
            let BINARY_CACHE_DIR = PWD & "/worker/" & lang & "/bin_cache"
            let arg = @["-i", "-v", BINARY_CACHE_DIR & '/' & $uuid_python3 & ":/main.py:ro", "akapenjudge/" & lang & ":run"]
            let input = "Hello, python3"
            let memory = "10M"
            let time = 100000000
            var
                output: string
                err: string
                exit_status: string
                exec_time: string

            (output, err, exit_status, exec_time) = utils.docker_run(docker_run_mode.RUN, $uuid_python3, arg, input, memory, time)
            
            check(output == input & "\n")
            check(err == "")
            check(exit_status == $exit_status_python3)
        

        test "proc get_status":
            let re1: status = get_status("", "error", "", 100000, 1000)
            let re2: status =  get_status("abc", "error", "abc", 10000, 9999)
            let re3: status = get_status("abc", "error", "abc", 1000, 9999)
            let tle: status = get_status("ab", "", "", 1000, 9999)
            let wa: status = get_status("hello", "", "abc", 1000, 999)
            let ac: status = get_status("hello", "", "hello", 1000, 999)

            check(re1 == status.RE)
            check(re2 == status.RE)
            check(re3 == status.RE)
            check(tle == status.TLE)
            check(wa == status.WA)
            check(ac == status.AC)
        
        
        test "container offline check":
            let lang = "python3"
            let PWD = os.getCurrentDir()
            let BINARY_CACHE_DIR = PWD & "/worker/" & lang & "/bin_cache"
            # get globalip info (should fail)
            let code: string = "import urllib.request; html = urllib.request.urlopen('http://globalip.me').read(); print(html)"
            let arg = @["-i", "akapenjudge/" & lang & ":run", "python3", "-c", code]
            let input = ""
            let memory = "10M"
            let time = 100000000
            var
                output: string
                err: string
                exit_status: string
                exec_time: string

            (output, err, exit_status, exec_time) = utils.docker_run(docker_run_mode.RUN, $oids.genOid(), arg, input, memory, time)
            let error_string: string = "urllib.error.URLError: <urlopen error [Errno -3] Temporary failure in name resolution>"
            check(err.split("\n")[^2] == error_string)  # failure in name resolution
            check(exit_status == "1")
