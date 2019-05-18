# This is just an example to get you started. A typical binary package
# uses this file as the main entry point of the application.

import redis
import os
import threadpool
import osproc
import json
import strutils
import streams


proc run(task:string, redis_client:redis.Redis) {.thread.} =
    ## Running task and return result to redis
    var tasknode: json.JsonNode = json.parseJson(task)
    let
        lang: string = tasknode["language"].getStr
        input: string = tasknode["input"].getStr
        code: string = tasknode["code"].getStr

    var
        output: string
        err: string
        status: string

    let p: osproc.Process = osproc.startProcess("docker",
            args=["run", "-i", "akapen/$#" % [lang], code], 
            options={poUsePath}
        )
    p.inputStream.write(input)
    p.inputStream.close()

    if p.running:
        while true:
            if not p.running:
                break
    output = p.outputStream.readAll()
    err = p.errorStream.readAll()

    p.close()

    if err.len != 0:
        status = "RE"
    # elif output != tasknode["assert"].getStr:
        # status = "WA"
    else:
        status = "AC"
    
    tasknode["status"] = %* status
    tasknode["output"] = %* output
    tasknode["stderr"] = %* err
    let redis_result = redis_client.lPush("taskresults", tasknode.pretty)

proc main(): void =
    let redis_client: redis.Redis = redis.open()  # redis client

    # set pool size
    setMaxPoolSize(256)
    setMinPoolSize(256)

    while true:
        let task = redis_client.rPop("taskqueue")  # pop task (json)
        
        if task != redis.redisNil:
            # spawn new thread
            threadpool.spawn run(task, redis_client)
        else:
            # if queue is empty, sleep for performance
            os.sleep(1000)


when isMainModule:
    main()
