"""
Test builder.
Define a non-linear program with a complementarity constraint:

min f(x)
l <= x <= u
lb <= c(x) <= ub

with an array of integer "cvar" of the same size as c(x).
cvar[i] is > 0 if c_i(x) is involved in a complementarity constraint:
(lb_i = c_i(x) or c_i(x) = ub_i) OR x[cvar[i]] = 0.

Just updated ASL library
> update BinaryBuilder
to get ASL_jll ────────────────────── v0.1.1+2 (handle n_cc and cvar from ASL)

Note: should probably be tested with https://github.com/tmigot/MPCC.jl/blob/master/src/MPCCAmpl.jl

TODO: replace cons, jac and hess from AmplModel
"""
mutable struct AmplCCModel <: AbstractNLPModel
  meta  :: NLPModelMeta;     # Problem metadata.
  __asl :: Ptr{Nothing};        # Pointer to internal ASL structure. Do not touch.

  counters :: Counters       # Evaluation counters
  safe :: Bool               # Always evaluate the objective before the Hessian.

  n_cc :: Int64
  cvar :: Array

  function AmplCCModel(stub :: AbstractString; safe :: Bool=false)

    # check that stub or stub.nl exists
    fname = basename(stub)
    ext = occursin(".", fname) ? split(fname, '.')[2] : ""
    if ext == "nl"
      isfile(stub) || throw(AmplException("cannot find $(stub)"))
    else
      isfile("$(stub).nl") || throw(AmplException("cannot find $(stub).nl"))
    end

    asl = @asl_call(:asl_init, Ptr{Nothing}, (Ptr{UInt8},), stub)
    asl == C_NULL && error("Error allocating ASL structure")

    minimize = @asl_call(:asl_objtype, Int32, (Ptr{Nothing},), asl) == 0
    islp = @asl_call(:asl_islp, Int32, (Ptr{Nothing},), asl) != 0

    nlo = Int(@asl_call(:asl_nlo, Int32, (Ptr{Nothing},), asl))

    nvar = Int(@asl_call(:asl_nvar, Int32, (Ptr{Nothing},), asl))
    ncon = Int(@asl_call(:asl_ncon, Int32, (Ptr{Nothing},), asl))
    n_cc = Int(@asl_call(:asl_n_cc, Int32, (Ptr{Nothing},), asl))

    x0   = unsafe_wrap(Array, @asl_call(:asl_x0, Ptr{Cdouble}, (Ptr{Nothing},), asl), (nvar,), own=false)
    y0   = unsafe_wrap(Array, @asl_call(:asl_y0, Ptr{Cdouble}, (Ptr{Nothing},), asl), (ncon,), own=false)

    lvar = unsafe_wrap(Array, @asl_call(:asl_lvar, Ptr{Cdouble}, (Ptr{Nothing},), asl), (nvar,), own=false)
    uvar = unsafe_wrap(Array, @asl_call(:asl_uvar, Ptr{Cdouble}, (Ptr{Nothing},), asl), (nvar,), own=false)

    nzo = Int(@asl_call(:asl_nzo, Int32, (Ptr{Nothing},), asl))
    nbv = Int(@asl_call(:asl_nbv, Int32, (Ptr{Nothing},), asl))
    niv = Int(@asl_call(:asl_niv, Int32, (Ptr{Nothing},), asl))
    nlvb = Int(@asl_call(:asl_nlvb, Int32, (Ptr{Nothing},), asl))
    nlvo = Int(@asl_call(:asl_nlvo, Int32, (Ptr{Nothing},), asl))
    nlvc = Int(@asl_call(:asl_nlvc, Int32, (Ptr{Nothing},), asl))
    nlvbi = Int(@asl_call(:asl_nlvbi, Int32, (Ptr{Nothing},), asl))
    nlvci = Int(@asl_call(:asl_nlvci, Int32, (Ptr{Nothing},), asl))
    nlvoi = Int(@asl_call(:asl_nlvoi, Int32, (Ptr{Nothing},), asl))
    nwv = Int(@asl_call(:asl_nwv, Int32, (Ptr{Nothing},), asl))

    lcon = unsafe_wrap(Array, @asl_call(:asl_lcon, Ptr{Cdouble}, (Ptr{Nothing},), asl), (ncon,), own=false)
    ucon = unsafe_wrap(Array, @asl_call(:asl_ucon, Ptr{Cdouble}, (Ptr{Nothing},), asl), (ncon,), own=false)
    if n_cc>0
    #not sure what to do if nzlb!=0
    cvar = unsafe_wrap(Array, @asl_call(:asl_cvar, Ptr{Int32}, (Ptr{Nothing},), asl),(ncon,), own=false)
    @show n_cc cvar nvar ncon # nlcc ndcc nzlb
    else
    cvar = []
    end

    nlnet = Int(@asl_call(:asl_lnc, Int32, (Ptr{Nothing},), asl))
    nnnet = Int(@asl_call(:asl_nlnc, Int32, (Ptr{Nothing},), asl))
    nnln = Int(@asl_call(:asl_nlc,  Int32, (Ptr{Nothing},), asl)) - nnnet
    nlin = ncon - nnln - nnnet

    nln  = 1 : nnln
    nnet = nnln+1 : nnln+nnnet
    lnet = nnln+nnnet+1 : nnln+nnnet+nlnet
    lin  = nnln+nnnet+nlnet+1 : ncon

    nnzj = Int(@asl_call(:asl_nnzj, Int32, (Ptr{Nothing},), asl))
    nnzh = Int(@asl_call(:asl_nnzh, Int32, (Ptr{Nothing},), asl))

    meta = NLPModelMeta(nvar, x0=x0, lvar=lvar, uvar=uvar,
                        nlo=nlo, nnzo=nzo,
                        ncon=ncon, y0=y0, lcon=lcon, ucon=ucon,
                        nnzj=nnzj, nnzh=nnzh,
                        nbv=nbv, niv=niv,
                        nlvb=nlvb, nlvo=nlvo, nlvc=nlvc,
                        nlvbi=nlvbi, nlvci=nlvci, nlvoi=nlvoi, nwv=nwv,
                        lin=lin, nln=nln, nnet=nnet, lnet=lnet,
                        nlin=nlin, nnln=nnln, nlnet=nlnet,
                        minimize=minimize, islp=islp, name=stub)

    nlp = new(meta, asl, Counters(), safe, n_cc, cvar)

    finalizer(amplmodel_finalize, nlp)
    return nlp
  end

end
