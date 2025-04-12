using Distributions

using MiniEvents


mutable struct Person
	pos :: Pos
	density :: Float64
	local_cond :: Float64
	exchange :: Float64
	storage :: Float64
	landscape :: Float64
	coop :: Float64
	family :: BitVector
end

Person(pos) = Person(pos, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, [])


struct Weather
	pos :: Pos
	effect :: Float64
end


struct Obstacle
	pos :: Pos
	effect :: Float64
end


mutable struct World
	pop_cache :: Cache2D{Person}
	weather_cache :: Cache2D{Weather}
	obstacle_cache :: Cache2D{Obstacle}
end


@events person::Person begin
	@debug

	@rate(repr_rate(person, @sim().pars)) ~ true => begin
		person.exchange != 0.0 ? @sim().n_x += 1 : @sim().n_no_x += 1
			
		child = reproduce!(person, @sim().world, @sim().pars)
		affected = Person[]
		adj_density_arrive!(child, affected, @sim().world, @sim().pars)
		set_weather_arrive!(child, @sim().world, @sim().pars)
		set_landscape_arrive!(child, @sim().world, @sim().pars)
#		println("repr: $(child.pos), $(child.density), $(child.weather)")
		@sim().N += 1
		@spawn child
		@r affected
	end

	@rate(death_rate(person, @sim().pars)) ~ true => begin
		person.exchange != 0.0 ? @sim().n_x += 1 : @sim().n_no_x += 1
			
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

		person.landscape = 0.0

		died = move!(person, @sim().world, @sim().pars)
		if died
			adj_density_leave!(person.pos, affected, @sim().world, @sim().pars)

			@sim().N -= 1
			@kill person
		else
			person.local_cond = 1.0
			set_weather_arrive!(person, @sim().world, @sim().pars)

			set_landscape_arrive!(person, @sim().world, @sim().pars)
		
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

	@rate(storage_rate(person, @sim().pars)) ~
		person.storage <= 0.0 && surplus(person, @sim().pars) > 0.0 => begin
		person.storage += surplus(person, @sim().pars) * @sim().pars.prop_store
		@r person
	end

	@rate(storage_reset_rate(person, @sim().pars)) ~ person.storage > 0.0 => begin
		person.storage = 0.0
		@r person
	end
	
	@rate(improvement_rate(person, @sim().pars)) ~ person.landscape < 0.0 => begin
		affected = improve_landscape!(person, @sim().world, @sim().pars)
		@r person affected
	end
	
	@rate(@sim().pars.r_reset_prov) ~ person.exchange != 0.0 => begin
		person.exchange = 0.0
		@r person
	end

	@rate(@sim().pars.r_mut) ~ true => mutate!(person, @sim().pars)
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
	n_x :: Int
	n_no_x :: Int
end
