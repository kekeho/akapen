# This is just an example to get you started. A typical binary package
# uses this file as the main entry point of the application.

import redis
import os
import threadpool
import json
import strutils
import utils


proc compile(task: string, redis_client: redis.Redis): void {.thread.} =
    # Generate binary from code.

    let PWD = os.getCurrentDir()

    # Parse json
    var
        tasknode: json.JsonNode = json.parseJson(task)
        lang: string
        code: string
        uuid: string
    try:
        lang = tasknode["language"].getStr
        code = tasknode["code"].getStr
        uuid = tasknode["uuid"].getStr
    except KeyError:
        tasknode["status"] = %* utils.status.JSE
        let redis_result = redis_client.lPush("results", tasknode.pretty)
        return

    # Compile code
    var
        output: string
        err: string
        status: utils.status

    let BINARY_CACHE_DIR = PWD & "/worker/" & lang & "/bin_cache"
    let args = @["-i", "-v", BINARY_CACHE_DIR & ":/bin_cache", "akapen/" & lang, "build", code, uuid]
    (output, err) = utils.docker_run(args)

    # Add run queue (or results when CE)
    tasknode["status"] = %* status
    tasknode["output"] = %* output
    tasknode["stderr"] = %* err
    if err.len > 0:
        status = utils.status.CE
    if status == utils.status.CE:
        let redis_result = redis_client.lPush("results", tasknode.pretty)
    else:
        let redis_result = redis_client.lPush("run_queue", tasknode.pretty)


proc run(task:string, redis_client:redis.Redis): void {.thread.} =
    ## Running task and return result to redis
    let PWD = os.getCurrentDir()

    # Parse json
    var
        tasknode: json.JsonNode = json.parseJson(task)
        lang: string
        input: string
        uuid: string
        assertion: string
    try:
        lang = tasknode["language"].getStr
        input = tasknode["input"].getStr
        uuid = tasknode["uuid"].getStr
        assertion = tasknode["assertion"].getStr
    except KeyError:
        tasknode["status"] = %* utils.status.JSE
        let redis_result = redis_client.lPush("results", tasknode.pretty)
        return

    # Run binary
    var
        output: string
        err: string
    let BINARY_CACHE_DIR = PWD & "/worker/" & lang & "/bin_cache"
    (output, err) = utils.docker_run(@["-i", "-v", BINARY_CACHE_DIR & ":/bin_cache", "akapen/$#" % [lang], "run", uuid], input)
    let status = utils.get_status(output, err, assertion)
    
    # Send result to redis
    tasknode["status"] = %* status
    tasknode["output"] = %* output
    tasknode["stderr"] = %* err
    let redis_result = redis_client.lPush("results", tasknode.pretty)


proc main(): void =
    let redis_client: redis.Redis = redis.open()  # redis client

    # set pool size
    setMaxPoolSize(256)
    setMinPoolSize(256)

    var
        compile_task: redis.RedisString = redis.redisNil
        run_task: redis.RedisString = redis.redisNil

    while true:
        let compile_task = redis_client.rPop("compile_queue")  # pop task (json)
        let run_task = redis_client.rPop("run_queue")

        # There is no task
        if compile_task == redis.redisNil and run_task == redis.redisNil:
            os.sleep(100)
            continue

        echo "compile_task:\n", compile_task
        echo "run_task:\n", run_task
        if compile_task != redis.redisNil:
            # spawn new compiling thread
            threadpool.spawn compile(compile_task, redis_client)
        
        if run_task != redis.redisNil:
            # spawn new running thread
            threadpool.spawn run(run_task, redis_client)



when isMainModule:
    main()
