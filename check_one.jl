using CSV
using DataFramesMeta
using Statistics


include("run_sets.jl")


allpars, args = load_parameters(ARGS, Pars)      

const parspace = ParSpace(
    :r_exch => [0.0, 1.0],
    :seed => 1:20)

const points = [point for point in points_in_space(parspace)]

const dfs = [DataFrame() for point in points_in_space(parspace)]

@threads for i in 1:length(points)
    print(stderr, ".")

    point = points[i]

    pars = apply_values!(deepcopy(allpars[1]), point)
    data = run_once(pars)

    pardf = create_df_cols!(parspace, DataFrame())
    add_to_df!(pardf, point)

    create_dataframe!(Data, dfs[i])
    add_to_dataframe!(dfs[i], data)

    dfs[i] = hcat(pardf, dfs[i])
end

println(stderr)

const all_data = dfs[1]
for i in 2:length(dfs)
    append!(all_data, dfs[i])
end

CSV.write("data.csv", all_data, delim='\t')
    

const ex1 = @subset(all_data, :r_exch .== 1.0)
const ex0 = @subset(all_data, :r_exch .== 0.0)

println("exch 0  N: $(mean(ex0.N_n)), $(std(ex0.N_n)), speed: $(mean(ex0.outside_n./ex0.N_n))")
println("exch 1  N: $(mean(ex1.N_n)), $(std(ex1.N_n)), speed: $(mean(ex1.outside_n./ex1.N_n))")

