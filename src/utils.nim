import osproc
import streams
import sequtils

type status* = enum
    AC = "AC",  # Accepted
    WA = "WA",  # Wrong Answer
    TLE = "TLE",  # Time Limit Exceeded
    MLE = "MLE",  # Memory Limit Exceeded
    CE = "CE",  # Compillation Error
    RE = "RE", # Runtime Error
    OLE = "OLE", # Output Limit Error
    JSE = "JSE"  # Judge server error


proc docker_run*(arguments: seq[string], standard_input: string = ""): array[2, string] =
    ## Run docker container with arguments and stdin
    let p: osproc.Process = osproc.startProcess("docker", args = @["run"]&arguments, options = {poUsePath})
    
    # stdin
    if standard_input != "":
        p.inputStream.write(standard_input)
        p.inputStream.close()
    
    if p.running:
        while true:
            if not p.running:
                break
    
    # stdout, stderr
    let output = p.outputStream.readAll()
    let err = p.errorStream.readAll()

    p.close()

    return [output, err]


proc get_status*(standard_output: string, standard_error: string, assertion: string): status = 
    if standard_error.len != 0:
        result = status.RE
    elif standard_output != assertion:
        result = status.WA
    else:
        result = status.AC