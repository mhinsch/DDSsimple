using MiniObserve
using Statistics

# mean and variance
const MVA = MeanVarAcc{Float64}
# maximum, minimum
const MMA = MaxMinAcc{Float64}


function local_relatedness(person, radius, world)
    r = 0.0
    m = 0.0
    n = 0

    for p in iter_circle(world.pop_cache, person.pos, radius)
        if p == person
            continue
        end
        rel = relatedness(person, p)
        m = max(m, rel)
        r += rel
        n += 1
    end

    r/n, m
end



@observe Data world t pars begin
    @record "time" Float64 t

    dens = Float64[]
    exch = Float64[]
    prov = Float64[]
    dist = Float64[]
    coop = Float64[]
    cond = Float64[]

    pop_in = Person[]
    pop_edge = Person[]
    
    for p in iter_cache(world.pop_cache)
        @stat("N", CountAcc) <| true

        d = euc_dist(p.pos, (pars.sz_y, pars.sz_x)./2)  

        @stat("dist", MMA) <| d

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

        push!(dist, d)
        push!(coop, p.coop)

        push!(dens, p.density)
        push!(exch, p.exchange)
        push!(prov, provision(p, pars))
        push!(cond, p.local_cond)
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

    
    range = pars.spread_exchange * pars.effect_radius
    coop_d = Float64[]
    n_d = Int[]
    for x in 0:2*range:pars.sz_x/2
        push!(coop_d, 0.0)
        push!(n_d, 0)
        for p in iter_circle(world.pop_cache, (pars.sz_y/2, pars.sz_x/2+x), range)
            coop_d[end] += p.coop
            n_d[end] += 1
        end
        if n_d[end] > 0
            coop_d[end] /= n_d[end]
        end
    end
        
    @record "cor_dens_exch" Float64 (isempty(dens) ? 0.0 : cor(dens, exch))
    @record "cor_dens_prov" Float64 (isempty(dens) ? 0.0 : cor(dens, prov))
    @record "cor_cond_prov" Float64 (isempty(cond) ? 0.0 : cor(cond, prov))
    @record "cor_dist_coop" Float64 (isempty(dist) ? 0.0 : cor(dist, coop))
    @record "cor_dens_coop" Float64 (isempty(dens) ? 0.0 : cor(dens, coop))
    @record "coop_dist_sample" Vector{Float64} coop_d
    @record "n_dist_sample" Vector{Float64} n_d
end


function ticker(out, data)
    um = data.outside.n / data.N.n
    println(out, "$(data.time) - N: $(data.N.n), dens: $(data.density.mean), prov: $(data.prov.mean) ex: $(data.exchange.mean)")
end
