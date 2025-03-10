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

    for p in iter_cache(world.pop_cache)
        @stat("N", CountAcc) <| true
        @stat("outside", CountAcc) <| (euc_dist(p.pos, pars.sz./2) > 200.0)
        @stat("donors", CountAcc) <| (p.exchange < 0.0)
        @stat("donees", CountAcc) <| (p.exchange > 0.0)
        if p.exchange != 0
            @stat("exchange", MVA) <| abs(p.exchange)
        end
        @stat("prov", MVA) <| provision(p, pars)
        @stat("density", MVA) <| p.density
        @stat("coop", MVA) <| p.coop

        push!(dens, p.density)
        push!(exch, p.exchange)
    end

    @record "cor_de" Float64 (isempty(dens) ? 0.0 : cor(dens, exch))
end


function ticker(out, data)
    um = data.outside.n / data.N.n
    println(out, "$(data.time) - N: $(data.N.n), out: $um, ex: $(data.exchange.mean)")
end
