# Package

version       = "0.1.0"
author        = "Hiroki.T"
description   = "Tiny judge server"
license       = "MIT"
srcDir        = "src"
bin           = @["akapen"]


# Dependencies

requires "nim >= 0.19.4"
requires "redis >= 0.3.0"


# tasks

task make, "build task":
    let build_command = "nim " & "c " & "--threads:on " & srcDir & '/' & bin[0] & " && mv " & srcDir & '/' & bin[0] & " ../" & bin[0]
    exec build_command
