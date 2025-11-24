
function setup(pars)
	if pars.dd2_model == 2
		mf_r = mf_d = pars.dd2_mixed
	else
		mf_r = pars.r_death
		mf_d = pars.r_repr
	end
	pars.dd2_scale_cached_r =
		sigmoid2_scaling(0.5, (pars.r_repr-mf_r)/pars.r_repr, pars.shape_prov_repr)
	pars.dd2_scale_cached_d =
		sigmoid2_scaling(0.5, (mf_d-pars.r_death)/(1-pars.r_death), pars.shape_prov_death)

	
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
			if pars.ini_rand_family
				person.family = BitVector(rand(Bool, pars.n_family))
			else
				person.family = BitVector(zeros(Bool, pars.n_family))
			end
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
