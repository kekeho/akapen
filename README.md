# akapen

Tiny judge server. docker based.

Master: ![Master branch build status](https://travis-ci.org/kekeho/akapen.svg?branch=master)  Debelop: ![Develop branch build status](https://travis-ci.org/kekeho/akapen.svg?branch=develop)

## Overview

akapen is judge server for competitive programming.
Every judges run on secure docker container.

## Install

just type 4 commands.

```sh
git clone https://github.com/kekeho/akapen
cd akapen
docker-compose build  # build
```

## Boot

```sh
docker-compose up
```

then, boot all system include redis(port: 6379) and akapen.

## Judge

Throw task json like ↓ into redis `compile_queue` list.

```json:task.json
{
    "user": {
        "id": "abc1234"
    },
    "uuid": "e8411f06-c3db-436b-8d57-7af03c962b5f",
    "language": "python3",
    "code": "print(input())",
    "input": "abcdef",
    "assert": "abcdef\n",
    "memory": "1M",
    "time": "1000000000"
}
```

Judge results will appear on redis `results` list.

```json:result.json
{
    "user": {
        "id": "abc1234"
    },
    "uuid": "e8411f06-c3db-436b-8d57-7af03c962b5f",
    "language": "python3",
    "code": "print(input())",
    "input": "abcdef",
    "assertion": "abcdef\n",
    "memory": "1M",
    "time": "1000000000",
    "status": "AC",
    "output": "abcdef\n",
    "stderr": "",
    "exec_time": "432427451"
}
```

## Status

Now, just supported only `AC`, `WA`, `RE`, `TLE`, `Compiled`, `JSE`

|  status  |          detail       |
|  :----:  |          :----:       |
|    AC    |        Accepted       |
|    WA    |      Wrong Answer     |
|    RE    |     Runtime Error     |
|   TLE    |  Time Limit Exceeded  |
| Compiled | Memory Limit Exceeded |
|   JSE    |   Judge server Error  |

## Support language

Now, just supported only python3.

- python3
    version: 3.7.3
    dockerfile: [compile](worker/python3/compile/Dockerfile) | [run](worker/python3/run/Dockerfile)

## Details of the judge container

- CPU limit  
    1 judge container can use **single core**, **5%** of all (cpu-period=100000, cpu-quota=5000)
- Offline  
- PIDs limit  
    10 (anti fork-bomb)
- Time info  
    exec_time gets from docker inspect (StartedAt, FinishedAt)  
    In akapen, the unit of time is nanoseconds

## Test

```sh
docker-compose run judge nimble test
```
