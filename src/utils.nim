import osproc
import streams
import sequtils


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
    