using CSV


include("run_sets.jl")


function run_batch(ps, range, outf)
    df = create_dataframe!(Data, DataFrame())
    pardf = create_df_cols!(ps, DataFrame())
    for n in range
        data, pc = run_nth(ps, n)
        add_to_dataframe!(df, data)
        add_to_df!(pardf, pc)
    end

    all = hcat(pardf, df)

    CSV.write(outf, all, delim='\t')
end


const psfile = ARGS[1]

const batch_size = parse(Int, ARGS[2])

const batch_n = parse(Int, ARGS[3])

include(psfile)

run_batch(parspace(), ((batch_n-1)*batch_size+1):(batch_n*batch_size), "results_$batch_n.csv")

