using Random


include("util.jl")

include("params.jl")

include("model.jl")	


function provision(person, pars)
	sp = surplus(person, pars)
	sp > 0 ? sp - person.storage : sp + person.storage
end	
# current "income"
function surplus(person, pars)
	density = person.density / pars.capacity
	lc = person.local_cond - 1
	mode = pars.weather_density_mode
	lc_effect =
		if mode == 1
			lc
		elseif mode == 2
			lc * (1.0-density)
		elseif mode == 3
			lc * abs(person.landscape)
		else
			error("unknown weather density mode")
			0.0
		end

	person.exchange + 1 + lc_effect + person.landscape - density
end

pot_donation(person, pars) =
	if pars.donate_mode == 1
		provision(person, pars)
	elseif pars.donate_mode == 2
		person.storage
	else
		error("unknown donation mode")
		0.0
	end

@inline storage_rate(person, pars) = pars.r_store

@inline storage_reset_rate(person, pars) = pars.r_store_reset
	
@inline repr_rate(person, pars) = pars.r_repr * 
	(1.0-pars.eff_prov_repr +
	pars.eff_prov_repr * sigmoid(limit(0.0, provision(person, pars), 1.0), pars.shape_prov_repr)) 
	
@inline death_rate(person, pars) = pars.r_death + pars.r_starve * 
	pars.eff_prov_death * sigmoid(limit(0.0, -provision(person, pars), 1.0), pars.shape_prov_death)  

@inline move_rate(person, pars) =
	(1-pars.dd_move + pars.dd_move*(pars.dd_r_move_0 + person.density/pars.capacity)) * pars.r_move

@inline exchange_rate(person, pars) =
	if pars.exchange_mode == 1
		max(0.0, -provision(person, pars)) * pars.r_exch
	elseif pars.exchange_mode == 2
		max(0.0, -person.local_cond) * pars.r_exch
	else
		error("unknown exchange mode")
		0.0
	end

@inline improvement_rate(person, pars) = pars.r_improve
	
	
function rand_mig_dist(pars)
	if pars.move_mode == 1
		rand() * 2 * pars.theta_mig + pars.mu_mig - pars.theta_mig
	elseif pars.move_mode == 2
		abs(rand(Normal(pars.mu_mig, pars.theta_mig)))
	elseif pars.move_mode == 3
		abs(rand(Levy(pars.mu_mig, pars.theta_mig)))
	end
end
	

@inline density(p1, p2, pars) = gaussian((p1.-p2)..., pars.spread_density)

function density_effects(p1, p2, pars)
	effect = density(p1.pos, p2.pos, pars) 
	# no priority for effect on self
	if p1 == p2
		return effect, effect
	end
	# p1 arrived later than p2 => experiences despoticness
	scale = p1.toa > p2.toa ? pars.despoticness : 1.0 - pars.despoticness
	2 * effect * scale, 2 * effect * (1.0 - scale)
end

@inline weather_effect(weather, ppos, pars) =
	weather.effect * gaussian((weather.pos.-ppos)..., pars.spread_weather)

@inline landscape_effect(obst, ppos, pars) =
	obst.effect * gaussian((obst.pos.-ppos)..., pars.spread_density)


function adj_density_leave!(leaver, affected, world, pars)
	for person in iter_circle(world.pop_cache, leaver.pos, pars.spread_density*pars.effect_radius)
		push!(affected, person)
		# leavers' density gets reset anyway
		if person == leaver
			continue
		end
		effect_l, effect_s = density_effects(leaver, person, pars)
		person.density -= effect_s
		@assert person.density >= 0.0 "$(person.density)"
	end	
	nothing
end


function adj_density_arrive!(new_person, affected, world, pars)
	for person in iter_circle(world.pop_cache, new_person.pos, pars.spread_density*pars.effect_radius)
		push!(affected, person)
		delta_n, delta_o = density_effects(new_person, person, pars)
		person.density += delta_o
		new_person.density += delta_n
	end	
	# avoid double counting
	new_person.density -= density_effects(new_person, new_person, pars)[1]
	@assert new_person.density >= 0.0 "$(new_person.density)"
	nothing
end


relatedness(p1, p2) = count(p1.family.==p2.family)/length(p1.family)


function mutate_family!(person, pars)
	for i in 1:pars.n_family_mutate
		m = rand(1:pars.n_family)
		person.family[m] = !person.family[m]
	end
end


function reproduce!(person, world, pars)
	child = Person(person.pos)
	child.coop = person.coop
	if pars.n_family > 0
		child.family = copy(person.family)
		mutate_family!(child, pars)
	end
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
		if !(0.0 <= new_pos[1] <= pars.sz_y && 0.0 <= new_pos[2] <= pars.sz_x)
			die!(person, world, pars)
			return true
		end
	else
		new_pos = limit(0.0, new_pos[1], pars.sz_y), limit(0.0, new_pos[2], pars.sz_x)
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


function set_weather_arrive!(person, world, pars)
	for weather in iter_circle(world.weather_cache, person.pos, pars.spread_weather*pars.effect_radius)
		person.local_cond += weather_effect(weather, person.pos, pars)
	end
end


function add_weather!(world, pars)
	pos = rand() * pars.sz_y, rand() * pars.sz_x
	effect = rand() * (pars.wth_range[2]-pars.wth_range[1]) + pars.wth_range[1]
	new_weather = Weather(pos, effect)
	add_to_cache!(world.weather_cache, new_weather, pos)

	affected = Person[]
	
	for person in iter_circle(world.pop_cache, pos, pars.spread_weather*pars.effect_radius)
		person.local_cond += weather_effect(new_weather, person.pos, pars)
		push!(affected, person)
	end	

	new_weather, affected
end


function remove_weather!(world, weather, pars)
	affected = Person[]
	
	for person in iter_circle(world.pop_cache, weather.pos, pars.spread_weather*pars.effect_radius)
		person.local_cond -= weather_effect(weather, person.pos, pars)
		push!(affected, person)
	end	

	remove_from_cache!(world.weather_cache, weather, weather.pos)

	affected
end


function set_landscape_arrive!(person, world, pars)
	for obst in iter_circle(world.obstacle_cache, person.pos, pars.spread_density*pars.effect_radius)
		person.landscape += landscape_effect(obst, person.pos, pars)
	end
end


function remove_obstacle!(obst, world, pars)
	affected = Person[]
	for person in iter_circle(world.pop_cache, obst.pos, pars.spread_density*pars.effect_radius)
		person.landscape -= landscape_effect(obst, person.pos, pars)
		push!(affected, person)
	end

	remove_from_cache!(world.obstacle_cache, obst, obst.pos)

	affected
end


@inline landscape_weight(person, lsc, pars) = gaussian((person.pos.-lsc.pos)..., pars.spread_density)

function improve_landscape!(person, world, pars)
	pot_obst = Obstacle[]
	weights = Float64[]

	sum_w = 0.0
	for obst in iter_circle(world.obstacle_cache, person.pos, pars.spread_density*pars.effect_radius)
		push!(pot_obst, obst)
		push!(weights, landscape_weight(person, obst, pars))
		@assert weights[end] >= 0.0
		sum_w += weights[end]
	end

	if isempty(pot_obst)
		return [person]
	end

	affected = Person[]

	s = rand() * sum_w
	for (l,w) in zip(pot_obst, weights)
		if s < w
			affected = remove_obstacle!(l, world, pars)
			break
		end
	end

	affected
end


@inline exchange_weight(donee, donor, pars) =
	gaussian((donee.pos.-donor.pos)..., pars.spread_exchange) * pot_donation(donor, pars) *
	donor.coop * (pars.rel_exchange ? relatedness(donee, donor) : 1.0)

function exchange!(donee, world, pars)
	@assert provision(donee, pars) < 0
	pot_donors = Person[]
	weights = Float64[]

	sum_w = 0.0
	for donor in iter_circle(world.pop_cache, donee.pos, pars.spread_exchange*pars.effect_radius)
		if pot_donation(donor, pars) > 0.0 && donor.coop > 0.0
			push!(pot_donors, donor)
			push!(weights, exchange_weight(donee, donor, pars))
			@assert weights[end] >= 0.0
			sum_w += weights[end]
		end
	end

	if isempty(pot_donors)
		return donee
	end

	s = rand() * sum_w
	for (donor,w) in zip(pot_donors, weights)
		if s < w
			donation = pot_donation(donor, pars) * pars.prop_exchange * donor.coop
			if pars.cap_donations
				donation = min(donation, -provision(donee, pars)/pars.eff_exchange)
			end
			@assert donation > 0.0
			donor.exchange -= donation
			donee.exchange += donation * pars.eff_exchange
			
			return donor
		end
		s -= w
	end
	error("donor selection went wrong")		
	donee
end


function mutate!(person, pars)
	person.coop = limit(0.0, person.coop + rand(Normal(0.0, pars.d_mut)), 1.0)
	nothing
end


function setup(pars)
	Random.seed!(pars.seed)
	cache_zoom = 5.0
	world = World(
		Cache2D{Person}(floor.(Int, (pars.sz_y, pars.sz_x)./cache_zoom) .+ 1, cache_zoom),
		Cache2D{Weather}(floor.(Int, (pars.sz_y, pars.sz_x)./cache_zoom) .+ 1, cache_zoom),
		Cache2D{Obstacle}(floor.(Int, (pars.sz_y, pars.sz_x)./cache_zoom) .+ 1, cache_zoom))

	sim = Sim(world, pars, 0, 0, 0)

	ini_y_mi = pars.sz_y/2 - pars.ini_y/2
	ini_y_ma = pars.sz_y/2 + pars.ini_y/2
	ini_x_mi = pars.sz_x/2 - pars.ini_x/2
	ini_x_ma = pars.sz_x/2 + pars.ini_x/2

	for i in 1:pars.n_obst
		x, y = 0.0, 0.0
		while true
			y = rand() * pars.sz_y
			x = rand() * pars.sz_x
			if ! (ini_y_mi < y < ini_y_ma && ini_x_mi < x < ini_x_ma)
				break
			end
		end

		new_obst = Obstacle((y,x), pars.obst_effect)
		add_to_cache!(world.obstacle_cache, new_obst, (y,x))
	end
	
	pop = Person[]
	for i in 1:pars.n_ini
		pos = ini_y_mi + rand() * pars.ini_y, 
			   ini_x_mi + rand() * pars.ini_x 
			   
		person = Person(pos)
		# artificial toa to avoid ambiguities
		person.toa = -i

		if pars.n_family > 0
			person.family = BitVector(rand(Bool, pars.n_family))
		end
		person.coop = rand() * (pars.ini_coop[2] - pars.ini_coop[1]) + pars.ini_coop[1]
		push!(pop, person)
		add_to_cache!(world.pop_cache, person, person.pos)
		adj_density_arrive!(person, Person[], world, pars)
		set_landscape_arrive!(person, world, pars)
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
			for p in iter_circle(world.pop_cache, test_person.pos, pars.spread_density*pars.effect_radius)
				test_person.density += density(test_person.pos, p.pos, pars)
			end	
			@assert abs(test_person.density - person.density) < 0.0001 "$(test_person.density) != $(person.density)"
		end
	end
end


function check_iter_circle(world, pars)
	pop = Person[]
	for x in 1:size(world.pop_cache.data)[2], y in 1:size(world.pop_cache.data)[1]
		append!(pop, world.pop_cache.data[y,x])
	end

	n = 0

	for p1 in pop, p2 in pop

		found1 = false
		for person in iter_circle(world.pop_cache, p1.pos, pars.spread_density*pars.effect_radius)
			if person == p2
				found1 = true
				break
			end
		end

		found2 = false
		for person in iter_circle(world.pop_cache, p2.pos, pars.spread_density*pars.effect_radius)
			if person == p1
				found2 = true
				break
			end
		end

		if found1 != found2
			n += 1
		end
	end

	@assert n==0 "$n mismatches"
end
		
