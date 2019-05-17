# This is just an example to get you started. A typical binary package
# uses this file as the main entry point of the application.

import redis
import os
import threadpool

proc run(task: string) {.thread.} =
    os.sleep(1000)
    echo task

proc main(): void =
    let redis_client: redis.Redis = redis.open()  # redis client

    # set pool size
    setMaxPoolSize(256)
    setMinPoolSize(256)

    while true:
        let task = redis_client.rPop("taskqueue")  # pop task (json)
        
        if task != redis.redisNil:
            threadpool.spawn run(task)
        else:
            # if queue is empty, sleep for performance
            os.sleep(1000)


when isMainModule:
    main()
