include("run.jl")
include("analysis_runs.jl")


using Base.Threads
using DataFrames

using Jeeps


function run_once(pars)
    Random.seed!(pars.seed)    
    model = setup(pars)

	for t in 1:model.pars.t_max
		println(t)
		step_until!(model, t) # run internal scheduler up to the next time step
	end

    observe(Data, model.world, model.pars.t_max, model.pars)
end


function run_nth(parspace, n; save_pars=false)
    p = nth_point(parspace, n)
    if p == nothing
        error("no such point")
    end
    pars = apply_values!(Pars(), p)
    if save_pars
        save_parameters_to_file("pars.$n.yaml", pars)
    end
    run_once(pars), p
end


function run_all_by_seed(parspace, verbose = false)
    df = create_dataframe!(Data, DataFrame())
    df.seed = Int[]
    for seed in 1:10
        for parpoint in points_in_space(parspace)
            pars = apply_values!(Pars(), parpoint)
            pars.seed = seed
            if verbose
                @time data = run_once(pars)
            else
                data = run_once(pars)
            end
            add_to_dataframe!(df, data, (), (seed,))
            if verbose
                println(parpoint)
            else
                print(".")
            end
        end
    end
    df
end


function run_all_threaded_by_seed(parspace)
    dfs = [DataFrame() for i in 1:10]
    pardf = create_df!(parspace, DataFrame())
    @threads for seed in 1:10
        create_dataframe!(Data, dfs[seed])
        dfs[seed].seed = Int[]
        for parpoint in points_in_space(parspace)
            pars = apply_values!(Pars(), parpoint)
            pars.seed = seed
            data = run_once(pars)
            add_to_dataframe!(dfs[seed], data, (), (seed,))
            print(".")
        end
        dfs[seed] = hcat(pardf, dfs[seed])
    end
    dfs
end

