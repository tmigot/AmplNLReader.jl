using Test
using NLPModels
using AmplNLReader
using LinearAlgebra
using Printf
using SparseArrays

"""
Just updated ASL library
> update BinaryBuilder
to get ASL_jll ────────────────────── v0.1.1+2
"""

path = dirname(@__FILE__)
cctest = Main.AmplNLReader.AmplCCModel(joinpath(path, "bard1.nl"))
@show cctest.meta.ncon
@show cctest.meta.nvar

amplmodel_finalize(cctest)
