import osproc
import streams
import sequtils
import strutils
import cpuinfo
import random

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


proc docker_run*(mode: docker_run_mode, arguments: seq[string], standard_input: string = "", memory : string = ""): array[3, string] =
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
    
    # stdin
    if standard_input != "":
        p.inputStream.write(standard_input)
        p.inputStream.close()
    
    let exit_status: string = p.waitForExit().intToStr
    
    # stdout, stderr
    let output = p.outputStream.readAll()
    let err = p.errorStream.readAll()

    p.close()

    return [output, err, exit_status]


proc get_status*(standard_output: string, standard_error: string, assertion: string): status = 
    if standard_error.len != 0:
        result = status.RE
    elif standard_output != assertion:
        result = status.WA
    else:
        result = status.AC