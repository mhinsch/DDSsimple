
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
