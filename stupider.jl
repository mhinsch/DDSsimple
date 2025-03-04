using Random


include("util.jl")

include("params.jl")

include("model.jl")	


@inline provision(person, pars) = person.exchange + person.local_cond -
	person.density / pars.capacity
	
@inline repr_rate(person, pars) =
	(1.0-pars.eff_prov_repr + pars.eff_prov_repr * max(0.0, provision(person, pars))) * pars.r_repr
	
@inline death_rate(person, pars) = pars.r_death + 
	pars.eff_prov_death * max(0.0, 1.0-provision(person, pars)) * pars.r_starve


@inline move_rate(person, pars) = pars.r_move

function rand_mig_dist(pars)
	if pars.move_mode == 1
		rand() * 2 * pars.theta_mig + pars.mu_mig - pars.theta_mig
	elseif pars.move_mode == 2
		abs(rand(Normal(pars.mu_mig, pars.theta_mig)))
	elseif pars.move_mode == 3
		abs(rand(Levy(pars.mu_mig, pars.theta_mig)))
	end
end
	

@inline exchange_weight(donee, donor, pars) =
	gaussian((donee.pos.-donor.pos)..., pars.spread_exchange) * provision(donor, pars) *
	donor.coop
@inline exchange_rate(person, pars) =
	max(0.0, -provision(person, pars)) * pars.r_exch

@inline density(p1, p2, pars) = gaussian((p1.-p2)..., pars.spread_density)

@inline weather_effect(weather, ppos, pars) =
	weather.effect * gaussian((weather.pos.-ppos)..., pars.spread_weather)


function adj_density_leave!(pos, affected, world, pars)
	for person in iter_circle(world.pop_cache, pos, pars.rad_density)
		person.density -= density(pos, person.pos, pars)
		push!(affected, person)
	end	
	nothing
end


function adj_density_arrive!(new_person, affected, world, pars)
	for person in iter_circle(world.pop_cache, new_person.pos, pars.rad_density)
		delta = density(new_person.pos, person.pos, pars)
		@assert delta >= 0
		person.density += delta
		new_person.density += delta
		push!(affected, person)
	end	
	new_person.density -= density(new_person.pos, new_person.pos, pars)
	nothing
end


function reproduce!(person, world, pars)
	child = Person(person.pos)
	child.coop = person.coop
	add_to_cache!(world.pop_cache, child, child.pos)
	child
end


function die!(person, world, pars)
	remove_from_cache!(world.pop_cache, person, person.pos)
	nothing
end


function move!(person, world, pars)
	pos = person.pos

	dist = rand_mig_dist(pars)
	angle = rand() * 2 * pi
	dx = cos(angle) * dist
	dy = sin(angle) * dist

	new_pos = pos[1] + dy, pos[2] + dx

	if pars.open_edge
		if !(0.0 <= new_pos[1] <= pars.sz[1] && 0.0 <= new_pos[2] <= pars.sz[2])
			die!(person, world, pars)
			return true
		end
	else
		new_pos = limit(0.0, new_pos[1], pars.sz[1]), limit(0.0, new_pos[2], pars.sz[2])
	end

	old_grid_pos = pos2cache_idx(world.pop_cache, pos)
	new_grid_pos = pos2cache_idx(world.pop_cache, new_pos)
	
	if new_grid_pos != old_grid_pos
		remove_from_cache!(world.pop_cache, person, pos)
		add_to_cache!(world.pop_cache, person, new_pos)
	end

	person.pos = new_pos

	false
end


function adj_density_move!(old_pos, migrant, affected, world, pars)
	# adjust for migrant moving away
	adj_density_leave!(old_pos, affected, world, pars)
	migrant.density = 0.0
	# now adjust for migrant moving in
	adj_density_arrive!(migrant, affected, world, pars)

	# ranges might overlap, so we have to make sure to remove duplicates
	sort!(affected, by=objectid)
	unique!(affected)
	nothing
end


function set_weather_arrive!(person, world, pars)
	for weather in iter_circle(world.weather_cache, person.pos, pars.rad_weather)
		person.local_cond += weather_effect(weather, person.pos, pars)
	end
end


function add_weather!(world, pars)
	pos = rand() * pars.sz[1], rand() * pars.sz[2]
	effect = rand() * (pars.wth_range[2]-pars.wth_range[1]) + pars.wth_range[1]
	new_weather = Weather(pos, effect)
	add_to_cache!(world.weather_cache, new_weather, pos)

	affected = Person[]
	
	for person in iter_circle(world.pop_cache, pos, pars.rad_weather)
		person.local_cond += weather_effect(new_weather, person.pos, pars)
		push!(affected, person)
	end	

	new_weather, affected
end


function remove_weather!(world, weather, pars)
	affected = Person[]
	
	for person in iter_circle(world.pop_cache, weather.pos, pars.rad_weather)
		person.local_cond -= weather_effect(weather, person.pos, pars)
		push!(affected, person)
	end	

	remove_from_cache!(world.weather_cache, weather, weather.pos)

	affected
end


function exchange!(person, world, pars)
	pot_donors = Person[]
	weights = Float64[]

	sum_w = 0.0
	for p in iter_circle(world.pop_cache, person.pos, pars.rad_exchange)
		if provision(p, pars) > 0.0 && p.coop > 0.0
			push!(pot_donors, p)
			push!(weights, exchange_weight(person, p, pars))
			@assert weights[end] >= 0.0
			sum_w += weights[end]
		end
	end

	if isempty(pot_donors)
		return person
	end

	s = rand() * sum_w
	for (p,w) in zip(pot_donors, weights)
		if s < w
			donation = provision(p, pars) * pars.prop_exchange * p.coop
			@assert donation > 0.0
			p.exchange -= donation
			person.exchange += donation * pars.eff_exchange
			
			return p
		end
		s -= w
	end
	error("donor selection went wrong")		
	person
end


function mutate!(person, pars)
	person.coop = limit(0.0, person.coop + rand(Normal(0.0, pars.d_mut)), 1.0)
	nothing
end


function setup(pars)
	Random.seed!(pars.seed)
	cache_zoom = 5.0
	world = World(
		Cache2D{Person}(floor.(Int, pars.sz./cache_zoom) .+ 1, cache_zoom),
		Cache2D{Weather}(floor.(Int, pars.sz./cache_zoom) .+ 1, cache_zoom))

	sim = Sim(world, pars, 0)
	
	pop = Person[]
	for i in 1:pars.n_ini
		pos = pars.sz[1]/2 - pars.ini_y/2 + rand() * pars.ini_y, 
			   pars.sz[2]/2 - pars.ini_x/2 + rand() * pars.ini_x 
			   
		person = Person(pos)
		person.coop = rand() * (pars.ini_coop[2] - pars.ini_coop[1]) + pars.ini_coop[1]
		push!(pop, person)
		add_to_cache!(world.pop_cache, person, person.pos)
		adj_density_arrive!(person, Person[], world, pars)
	end

	foreach(p -> spawn!(p, sim), pop)
	spawn!(world, sim)

	sim.N = pars.n_ini
	
	sim
end


function check_cache(cache)
	for x in 1:size(cache.data)[2], y in 1:size(cache.data)[1]
		for el in cache.data[y,x]
			@assert pos2cache_idx(cache, el.pos) == (y,x) "$(pos2cache_idx(cache, el.pos)) != $y,$x)"
		end
	end
end


function check_weather_density(world, pars)
	for x in 1:size(world.pop_cache.data)[2], y in 1:size(world.pop_cache.data)[1]
		for person in world.pop_cache.data[y,x]
			test_person = Person(person.pos, 0.0, 1.0)
			set_weather_arrive!(test_person, world, pars)
			@assert(abs(test_person.local_cond - person.local_cond)<0.0001,
				 "$(test_person.local_cond) != $(person.local_cond)")
			for p in iter_circle(world.pop_cache, test_person.pos, pars.rad_density)
				test_person.density += density(test_person.pos, p.pos, pars)
			end	
			@assert abs(test_person.density - person.density) < 0.0001 "$(test_person.density) != $(person.density)"
		end
	end
end


