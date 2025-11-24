limit(mi, v, ma) = max(mi, min(v, ma))


function remove_uo!(cont, to_remove)
	for (i, el) in enumerate(cont)
		if el == to_remove
			remove_uo_at!(cont, i)
			return i
		end
	end
	error("element not found")
	0
end


function remove_uo_at!(cont, i)
	cont[i] = cont[end]
	pop!(cont)
end


gaussian(x, y, s) = exp(-x^2/(2*s^2)-y^2/(2*s^2))


sq_dist(a, b) = sum((a[1]-b[1], a[2]-b[2]).^2)
euc_dist(a, b) = sqrt(sq_dist(a, b))


function sigmoid(x, alpha, mid=0.5)
	c = mid/(1.0-mid)
	xa = x^alpha
	xa/(((1.0-x)*c)^alpha + xa)
end

sigmoid2_scaling(x0, y0, alpha) = -log((1/y0-1)^(1/alpha)+1)/log(x0)

function sigmoid2(x, scale, alpha)
	xs = x^(scale*alpha)
	xs / (xs + (1-x^scale)^alpha)
end


const Pos = Tuple{Float64, Float64}



struct Cache2D{ELT}
	data :: Matrix{Vector{ELT}}
	zoom :: Float64
end


Cache2D{ELT}(sz::Tuple{Int, Int}, zoom::Float64) where {ELT} =
	Cache2D{ELT}([ ELT[] for y in 1:sz[1], x in 1:sz[2] ], zoom)


pos2cache_idx(cache, pos) = floor(Int, pos[1]/cache.zoom) + 1, floor(Int, pos[2]/cache.zoom) + 1
	

function add_to_cache!(cache, item, pos)
	push!(cache.data[pos2cache_idx(cache, pos)...], item)
end

function remove_from_cache!(cache, item, pos)
	remove_uo!(cache.data[pos2cache_idx(cache, pos)...], item)
end



mutable struct Cache2DIter{ELT}
	const cache :: Matrix{Vector{ELT}}
	const pos :: Pos
	const r2 :: Float64
	const top :: Int
	const left :: Int
	const ym :: Int
	const xm :: Int
	i :: Int
	j :: Int
end


# iterate through the entire cache
iter_cache(cache) = Cache2DIter(cache.data, (1.0,1.0), 0.0,
	1, 1,
	(size(cache.data).-(1,1))...,
	0, 1
	)
	

# iterate through all elements within a circle around pos
function iter_circle(cache, pos, radius)
	#println(pos, " ", radius)
	# coordinates of window in cache
	top_left = floor.(Int, (pos .- radius) ./ cache.zoom)
	bot_right = ceil.(Int, (pos .+ radius) ./ cache.zoom)
	sz = size(cache.data) 
	tl_clipped = max.(1, top_left)
	br_clipped = min.(sz, bot_right)
	Cache2DIter(cache.data, pos, radius^2, 
		tl_clipped[1], 
		tl_clipped[2], 
		# second set is sizes, not coordinates
		br_clipped[1] - tl_clipped[1],
		br_clipped[2] - tl_clipped[2], 
		0, 1)
end


function Base.iterate(hhci::CITER) where {CITER <: Cache2DIter}
	iterate(hhci, hhci)
end
	

function Base.iterate(hhci::CITER, dummy) where {CITER <: Cache2DIter}
	#dump(hhci)
	yo = 0
	while true
		y, x = hhci.top + hhci.i%(hhci.ym+1), hhci.left + hhci.i÷(hhci.ym+1)
		if yo != y
			yo = y
			#println()
		end
		#print("$y,$x,$(hhci.i)|")
		vec = hhci.cache[y, x]
		if hhci.j <= length(vec)
			el = vec[hhci.j]
			hhci.j += 1
			if hhci.r2 <= 0.0 || sum((el.pos .- hhci.pos).^2) < hhci.r2
				#print("!")
				return el, hhci
			end
		else
			hhci.i += 1
			if hhci.i >= (hhci.xm+1) * (hhci.ym+1)
				#println(".")
				return nothing
			end
			hhci.j = 1
		end
	end
end
