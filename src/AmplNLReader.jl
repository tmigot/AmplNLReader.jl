# A rudimentary AMPL interface in Julia.
# D. Orban, Vancouver, April 2014.
module AmplNLReader

using LinearAlgebra
using NLPModels
using SparseArrays

using Libdl
using ASL_jll

const libasl = joinpath(dirname(ASL_jll.libasl_path), "libasl." * dlext)

include("ampl_model.jl")

include("ampl_cc_model.jl")

# Import methods we override.
import Base.show, Base.print

# Methods associated to AmplModel instances.

function NLPModels.reset!(nlp :: Union{AmplModel,AmplCCModel})
  reset!(nlp.counters)
  return nlp
end

function write_sol(nlp :: Union{AmplModel,AmplCCModel}, msg :: String, x :: AbstractVector, y :: AbstractVector)
  @check_ampl_model
  length(x) == nlp.meta.nvar || error("x must have length $(nlp.meta.nvar)")
  length(y) == nlp.meta.ncon || error("y must have length $(nlp.meta.ncon)")

  @asl_call(:asl_write_sol, Nothing,
                    (Ptr{Nothing}, Ptr{UInt8}, Ptr{Cdouble}, Ptr{Cdouble}),
                     nlp.__asl,    msg,        x,            y)
end

function amplmodel_finalize(nlp :: Union{AmplModel,AmplCCModel})
  if nlp.__asl == C_NULL
    return
  end
  @asl_call(:asl_finalize, Nothing, (Ptr{Nothing},), nlp.__asl)
  nlp.__asl = C_NULL
end

# Displaying AmplModel instances.

function show(io :: IO, nlp :: Union{AmplModel,AmplCCModel})
  @check_ampl_model
  show(io, nlp.meta)
end

function print(io :: IO, nlp :: Union{AmplModel,AmplCCModel})
  @check_ampl_model
  print(io, nlp.meta)
end

end  # Module AmplNLReader
