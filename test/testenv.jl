#!/usr/bin/env julia

using Revise
using TestEnv
using Pkg

Pkg.activate((@__DIR__)*"/..")

TestEnv.activate()

include("runtests.jl")


# vim: set sw=4 et sts=4 :
