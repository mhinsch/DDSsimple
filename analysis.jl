using MiniObserve
using Statistics

# mean and variance
const MVA = MeanVarAcc{Float64}
# maximum, minimum
const MMA = MaxMinAcc{Float64}


@observe Data world t pars begin
    @record "time" Float64 t

    dens = Float64[]
    exch = Float64[]
    prov = Float64[]
    dist = Float64[]
    coop = Float64[]
    cond = Float64[]

    for p in iter_cache(world.pop_cache)
        @stat("N", CountAcc) <| true

        d = euc_dist(p.pos, pars.sz./2)  

        @stat("dist", HistAcc{Float64}(10.0, 2.0)) <| d

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

        push!(dist, d)
        push!(coop, p.coop)

        push!(dens, p.density)
        push!(exch, p.exchange)
        push!(prov, provision(p, pars))
        push!(cond, p.local_cond)
    end

    @record "cor_dens_exch" Float64 (isempty(dens) ? 0.0 : cor(dens, exch))
    @record "cor_dens_prov" Float64 (isempty(dens) ? 0.0 : cor(dens, prov))
    @record "cor_cond_prov" Float64 (isempty(cond) ? 0.0 : cor(cond, prov))
    @record "cor_dist_coop" Float64 (isempty(dist) ? 0.0 : cor(dist, coop))
    @record "cor_dens_coop" Float64 (isempty(dens) ? 0.0 : cor(dens, coop))
end


function ticker(out, data)
    um = data.outside.n / data.N.n
    println(out, "$(data.time) - N: $(data.N.n), dens: $(data.density.mean), prov: $(data.prov.mean) ex: $(data.exchange.mean)")
end
