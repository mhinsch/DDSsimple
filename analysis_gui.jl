include("analysis_common.jl")

const dens = Float64[]
const exch = Float64[]
const prov = Float64[]
const dist = Float64[]
const coop = Float64[]
const cond = Float64[]
const store = Float64[]
const lsc = Float64[]

const sample_relatedness = Float64[]
const sample_coop_diff = Float64[]

const pop = Person[]
const pop_in = Person[]
const pop_edge = Person[]

@observe Data world t pars begin
    @record "time" Float64 t

    empty!(dens)
    empty!(exch)
    empty!(prov)
    empty!(dist)
    empty!(coop)
    empty!(cond)
    empty!(store)
    empty!(lsc)

    empty!(sample_relatedness)
    empty!(sample_coop_diff)

    empty!(pop)
    empty!(pop_in)
    empty!(pop_edge)
    
    for p in iter_cache(world.pop_cache)
        @stat("N", CountAcc) <| true

        push!(pop, p)

        d = euc_dist(p.pos, (pars.sz_y, pars.sz_x)./2)  

        @stat("dist", HistAcc{Float64}(10.0, 2.0), MMA) <| d

        if d > 200.0
            @stat("outside", CountAcc) <| true
            @stat("coop_out", MVA) <| p.coop
            if d > 400.0
                push!(pop_edge, p)
                @stat("coop_edge", MVA) <| p.coop
            end
        else
            push!(pop_in, p)
            @stat("coop_in", MVA) <| p.coop
        end
        
        @stat("donors", CountAcc) <| (p.exchange < 0.0)
        @stat("donees", CountAcc) <| (p.exchange > 0.0)
        if p.exchange != 0
            @stat("exchange", MVA) <| abs(p.exchange)
        end
        @stat("prov", MVA) <| provision(p, pars)
        @stat("density", MVA) <| p.density
        @stat("coop", MVA) <| p.coop
        @stat("storage", MVA, HistAcc{Float64}(0.0, 0.1, 0.0)) <| p.storage

        push!(dist, d)
        push!(coop, p.coop)

        push!(dens, p.density)
        push!(exch, p.exchange)
        push!(prov, provision(p, pars))
        push!(cond, p.local_cond)
        push!(store, p.storage)
        push!(lsc, p.landscape)
    end


    if !isempty(pop_in)
        for i in 1:20
            p = rand(pop_in)
            mean_r, max_r = local_relatedness(p, pars.spread_exchange, world)
            @stat("meanlocrel_in", MVA) <| mean_r
            @stat("maxlocrel_in", MVA) <| max_r
        end
    end

    if !isempty(pop_edge)
        for i in 1:20
            p = rand(pop_edge)
            mean_r, max_r = local_relatedness(p, pars.spread_exchange, world)
            @stat("meanlocrel_edge", MVA) <| mean_r
            @stat("maxlocrel_edge", MVA) <| max_r
        end
    end

    if !isempty(pop)
        for i in 1:500
            p1 = rand(pop)
            p2 = rand(pop)
            if p1 == p2
                continue
            end
            rel = relatedness(p1, p2)
            diff_coop = abs(p1.coop - p2.coop)
            @stat("pop_relatedness", MVA) <| rel

            push!(sample_relatedness, rel)
            push!(sample_coop_diff, diff_coop)
        end
    end

    @record "sample_relatedness" Vector{Float64} sample_relatedness
    @record "sample_coop_diff" Vector{Float64} sample_coop_diff
    @record "cor_rel_coop" Tuple{Float64, Float64} (isempty(sample_relatedness) ?
        (0.0, 0.0) : Tuple{Float64, Float64}(coef(linregress(sample_relatedness, sample_coop_diff))))
    
    @record "distance_all" Vector{Float64} dist
    @record "density_all" Vector{Float64} dens
    @record "exchange_all" Vector{Float64} exch
    @record "provision_all" Vector{Float64} prov
    @record "coop_all" Vector{Float64} coop
    @record "condition_all" Vector{Float64} cond
    @record "storage_all" Vector{Float64} store
    @record "lsc_all" Vector{Float64} lsc

    @record "cor_dens_exch" Tuple{Float64, Float64} (isempty(dens) ?
        (0.0, 0.0) : Tuple{Float64, Float64}(coef(linregress(dens, exch))))
    @record "cor_dist_exch" Tuple{Float64, Float64} (isempty(dist) ?
        (0.0, 0.0) : Tuple{Float64, Float64}(coef(linregress(dist, exch))))
    @record "cor_dens_prov" Tuple{Float64, Float64} (isempty(dens) ?
        (0.0, 0.0) : Tuple{Float64, Float64}(coef(linregress(dens, prov))))
    @record "cor_cond_prov" Tuple{Float64, Float64} (isempty(cond) ?
        (0.0, 0.0) : Tuple{Float64, Float64}(coef(linregress(cond, prov))))
    @record "cor_dist_coop" Tuple{Float64, Float64} (isempty(dist) ?
        (0.0, 0.0) : Tuple{Float64, Float64}(coef(linregress(dist, coop))))
    @record "cor_dens_coop" Tuple{Float64, Float64} (isempty(dens) ?
        (0.0, 0.0) : Tuple{Float64, Float64}(coef(linregress(dens, coop))))
    @record "cor_dist_store" Tuple{Float64, Float64} (isempty(dist) ?
        (0.0, 0.0) : Tuple{Float64, Float64}(coef(linregress(dist, store))))
    @record "cor_dens_store" Tuple{Float64, Float64} (isempty(dens) ?
        (0.0, 0.0) : Tuple{Float64, Float64}(coef(linregress(dens, store))))
end


function ticker(out, data::Data)
    um = data.outside.n / data.N.n
    println(out, "$(data.time) - N: $(data.N.n), dens: $(data.density.mean), prov: $(data.prov.mean), coop: $(data.coop.mean), ex: $(data.exchange.mean)")
end
