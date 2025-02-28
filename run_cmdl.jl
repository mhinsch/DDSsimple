include("run.jl")

const model, logf = prepare_model(ARGS) 


@time run_model(model, logf)


close(logf)

