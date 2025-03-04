using MiniObserve

# mean and variance
const MVA = MeanVarAcc{Float64}
# maximum, minimum
const MMA = MaxMinAcc{Float64}


@observe Data world t pars begin
    @record "time" Float64 t


    for p in iter_cache(world.pop_cache)
        @stat("N", CountAcc) <| true
        @stat("outside", CountAcc) <| (euc_dist(p.pos, pars.sz./2) > 200.0)
        @stat("donors", CountAcc) <| (p.exchange < 0.0)
        @stat("donees", CountAcc) <| (p.exchange > 0.0)
        @stat("prov", MVA) <| provision(p, pars)
        @stat("coop", MVA) <| p.coop
    end
end


function ticker(out, data)
    um = data.outside.n / data.N.n
    println(out, "$(data.time) - N: $(data.N.n), out: $um")
end
