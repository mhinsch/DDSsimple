using Random
using Distributions

using MiniEvents

include("util.jl")

"Model parameters"
@kwdef mutable struct Pars
	"world size"
	sz :: Pos = 1000.0, 1000.0
	"initial pop size"
	n_ini :: Int = 50
	"y location of initial pop"
	ini_y :: Pos = 0.49, 0.51
	"x location of initial pop"
	ini_x :: Pos = 0.49, 0.51

	"reproduction rate"
	r_repr :: Float64 = 0.1
	"natural ibackground mortality"
	r_death :: Float64 = 1.0/60.0
	"mortality under starvation"
	r_starve :: Float64 = 1.0
	"movement rate"
	r_move :: Float64 = 0.01
	"exchange rate"
	r_exch :: Float64 = 1.0
	
	"effect of provisioning on reproduction (0-1)"
	eff_prov_repr :: Float64 = 1.0
	"effect of provisioning on death (0-1)"
	eff_prov_death :: Float64 = 0.0
	
	"carrying capacity"
	capacity :: Float64 = 5.0
	"sd of influence of density"
	spread_density :: Float64 = 5.0
	"max range of influence of density"
	rad_density :: Float64 = 15.0

	"whether agents are stopped at the edge or disappear"
	open_edge :: Bool = true
	"distribution of step size: 1 - Uniform, 2 - Normal, 3 - Levy"
	move_mode :: Int = 3

	"mean step size"
	mu_mig :: Float64 = 0.0
	"sd of stepsize"
	theta_mig :: Float64 = 0.5

	"sd of exchange distance"
	spread_exchange :: Float64 = 10
	"maximum exchange distance"
	rad_exchange :: Float64 = 30
	"proportion of resources that get exchanged"
	prop_exchange :: Float64 = 0.5
	"efficiency of exchange"
	eff_exchange :: Float64 = 0.9
	"rate at which resources get reset to default"
	r_reset_prov :: Float64 = 1.0

	"rate of appearance of weather effects"
	r_weather :: Float64 = 20
	"rate of disappearance of weather effects"
	r_weather_end :: Float64 = 0.3

	"sd of effect of weather"
	spread_weather :: Float64 = 10.0
	"max range of effect of weather"
	rad_weather :: Float64 = 30.0
	"min and max value of weather influence on capacity"
	wth_range :: Tuple{Float64, Float64} = -1.0, 0.2

	"random seed"
	seed :: Int = 41
	"simulation time"
	t_max :: Float64 = 1000.0
end


mutable struct Person
	pos :: Pos
	density :: Float64
	local_cond :: Float64
	exchange :: Float64
end

Person(pos) = Person(pos, 0.0, 1.0, 0.0)


struct Weather
	pos :: Pos
	effect :: Float64
end


mutable struct World
	pop_cache :: Cache2D{Person}
	weather_cache :: Cache2D{Weather}
end


@events person::Person begin
	@debug

	@rate(repr_rate(person, @sim().pars)) ~ true => begin
		child = reproduce!(person, @sim().world, @sim().pars)
		affected = Person[]
		adj_density_arrive!(child, affected, @sim().world, @sim().pars)
		set_weather_arrive!(child, @sim().world, @sim().pars)
#		println("repr: $(child.pos), $(child.density), $(child.weather)")
		@sim().N += 1
		@spawn child
		@r affected
	end

	@rate(death_rate(person, @sim().pars)) ~ true => begin
		# removes person from cache, so won't be affected by density change
		die!(person, @sim().world, @sim().pars)
		
		affected = Person[]
		adj_density_leave!(person.pos, affected, @sim().world, @sim().pars)

		@sim().N -= 1
		@kill person
		@r affected
	end
		
	@rate(move_rate(person, @sim().pars)) ~ true => begin
		old_pos = person.pos
		old_local_cond = person.local_cond

		affected = Person[]

		died = move!(person, @sim().world, @sim().pars)
		if died
			adj_density_leave!(person.pos, affected, @sim().world, @sim().pars)

			@sim().N -= 1
			@kill person
		else
			person.local_cond = 1.0
			set_weather_arrive!(person, @sim().world, @sim().pars)
		
			adj_density_move!(old_pos, person, affected, @sim().world, @sim().pars)
		end
#		println("move: $(old_pos) -> $(person.pos), $(person.density), $(person.weather)")
		@r affected
	end

	@rate(exchange_rate(person, @sim().pars)) ~ provision(person, @sim().pars) < 0.0 => begin
		donor = exchange!(person, @sim().world, @sim().pars)
		if donor != person
			@r donor
		end
		@r person 
	end

	@rate(@sim().pars.r_reset_prov) ~ person.exchange != 0.0 => begin
		person.exchange = 0.0
		@r person
	end
end


@events weather::Weather begin
	@debug

	@rate(@sim().pars.r_weather_end) ~ true => begin
		affected = remove_weather!(@sim().world, weather, @sim().pars)
		@kill weather
		@r affected
	end
end


@events world::World begin
	@debug

	@rate(@sim().pars.r_weather) ~ true =>
	begin
		weather, affected = add_weather!(world, @sim().pars)
		@spawn weather
		@r world affected
	end
end


@simulation Sim Person Weather World begin
	world :: World
	pars :: Pars
	N :: Int
end
	

@inline provision(person, pars) = person.exchange + person.local_cond -
	person.density / pars.capacity
	
@inline repr_rate(person, pars) =
	(1.0-pars.eff_prov_repr + pars.eff_prov_repr * max(0.0, provision(person, pars))) * pars.r_repr
	
@inline death_rate(person, pars) = pars.r_death + 
	pars.eff_prov_death * max(0.0, 1.0-provision(person, pars)) * pars.r_starve


@inline move_rate(person, pars) = pars.r_move

@inline function rand_mig_dist(pars)
	if pars.move_mode == 1
		rand() * 2 * pars.theta_mig + pars.mu_mig - pars.theta_mig
	elseif pars.move_mode == 2
		abs(rand(Normal(pars.mu_mig, pars.theta_mig)))
	elseif pars.move_mode == 3
		abs(rand(Levy(pars.mu_mig, pars.theta_mig)))
	end
end
	

@inline exchange_weight(donee, donor, pars) =
	gaussian((donee.pos.-donor.pos)..., pars.spread_exchange) * provision(donor, pars)
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
	person = Person(person.pos)
	add_to_cache!(world.pop_cache, person, person.pos)
	person
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

	for p in iter_circle(world.pop_cache, person.pos, pars.rad_exchange)
		if provision(p, pars) > 0.0
			push!(pot_donors, p)
			push!(weights, exchange_weight(person, p, pars))
		end
	end

	if isempty(pot_donors)
		return person
	end

	s = rand() * sum(weights)
	for (p,w) in zip(pot_donors, weights)
		if s < w
			donation = provision(p, pars) * pars.prop_exchange
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


function setup(pars)
	Random.seed!(pars.seed)
	cache_zoom = 5.0
	world = World(
		Cache2D{Person}(floor.(Int, pars.sz./cache_zoom) .+ 1, cache_zoom),
		Cache2D{Weather}(floor.(Int, pars.sz./cache_zoom) .+ 1, cache_zoom))

	sim = Sim(world, pars, 0)
	
	pop = Person[]
	for i in 1:pars.n_ini
		pos = pars.sz[1] * (rand() * (pars.ini_y[2]-pars.ini_y[1]) + pars.ini_y[1]), 
			  pars.sz[2] * (rand() * (pars.ini_x[2]-pars.ini_x[1]) + pars.ini_x[1])
			   
		person = Person(pos)
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


function show_world(world, pars)
	println(length(world.pop))
	for y in 1:size(world.lsc)[1]
		for x in 1:size(world.lsc)[2]
			lvl = length(world.lsc[y, x]) / pars.k
			if lvl == 0.0
				ic = " "
			elseif lvl < 0.2
				ic = "."
			elseif lvl < 0.5
				ic = ":"
			elseif lvl < 0.9
				ic = "%"
			else
				ic = "#"
			end
			print(ic)
		end
		println()
	end
end

