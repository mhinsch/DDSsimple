using MiniObserve
using LinearRegression

# mean and variance
const MVA = MeanVarAcc{Float64}
# maximum, minimum
const MMA = MaxMinAcc{Float64}

const dens = Float64[]
const exch = Float64[]
const prov = Float64[]
const dist = Float64[]
const coop = Float64[]
const cond = Float64[]
const store = Float64[]
const lsc = Float64[]

@observe DataGUI world t pars begin
    @record "time" Float64 t

    empty!(dens)
    empty!(exch)
    empty!(prov)
    empty!(dist)
    empty!(coop)
    empty!(cond)
    empty!(store)
    empty!(lsc)

    for p in iter_cache(world.pop_cache)
        @stat("N", CountAcc) <| true

        d = euc_dist(p.pos, (pars.sz_y, pars.sz_x)./2)  

        @stat("dist", HistAcc{Float64}(10.0, 2.0), MMA) <| d

        if d > 200.0
            @stat("outside", CountAcc) <| true
            @stat("coop_out", MVA) <| p.coop
        else
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


function ticker(out, data::DataGUI)
    um = data.outside.n / data.N.n
    println(out, "$(data.time) - N: $(data.N.n), dens: $(data.density.mean), prov: $(data.prov.mean) ex: $(data.exchange.mean)")
end
