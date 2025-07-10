#   Copyright (C) 2020 Martin Hinsch <hinsch.martin@gmail.com>
#
#   This program is free software: you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation, either version 3 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program.  If not, see <https://www.gnu.org/licenses/>.



using SSDL
using SimpleGraph
using SimpleGui


### draw GUI

# draw world to canvas
function draw_world(canvas, model)
	xs = canvas.xsize - 1
	ys = canvas.ysize - 1

	zoomy = model.pars.sz_y / ys
	zoomx = model.pars.sz_x / xs

	wc = model.world.weather_cache.data

	r1_wth = floor(Int, model.pars.spread_weather/zoomx)
	r2_wth = floor(Int, model.pars.spread_weather*model.pars.effect_radius/zoomx)

	for y in 1:size(wc)[1], x in 1:size(wc)[2]
		for w in wc[y, x]
			p = w.pos ./ (zoomy, zoomx)

			col = w.effect < 0 ?
				red(floor(UInt32, -w.effect * 150)) :
				green(floor(UInt32, w.effect * 150)) 

			circle_fill(canvas, floor(Int, p[2]), floor(Int, p[1]), r1_wth, UInt32(col), true)
			circle(canvas, floor(Int, p[2]), floor(Int, p[1]), r2_wth, UInt32(col), true)
		end
	end

	lsc = model.world.obstacle_cache.data

	for y in 1:size(lsc)[1], x in 1:size(lsc)[2]
		for l in lsc[y, x]
			p = l.pos ./ (zoomy, zoomx)

			col = blue(255)

			circle_fill(canvas, floor(Int, p[2]), floor(Int, p[1]), 2, UInt32(col), true)
		end
	end

	pc = model.world.pop_cache.data

	r1_p = 1
	r2_p = floor(Int, model.pars.spread_exchange/zoomx)

	for y in 1:size(pc)[1], x in 1:size(pc)[2]
		for a in pc[y, x]
			p = a.pos ./ (zoomy, zoomx)
			dens = limit(0.0, a.density / ccapacity(model.pars), 1.0)

			colc = rgb((1.0-dens)*150+105, dens*150+105, 155)
			prov = limit(-1.0, provision(a, model.pars), 1.0)
			exch = sign(a.exchange)
#			col = rgb(150, prov*125+130, 130-prov*125)
			col = if exch > 0
					rgb(255, 0, 255)
				elseif exch == 0
					#rgb(0, 155, 0)
					colc
				else
					rgb(255, 255, 255)
				end
				
			col2 = rgb(50, 50, 50)

			col3 = model.pars.n_family > 0 ? UInt32(a.family.chunks[1] & ~UInt32(0)) : col
			
			circle_fill(canvas, floor(Int, p[2]), floor(Int, p[1]), r1_p, col3, true)
			#circle(canvas, floor(Int, p[1]), floor(Int, p[2]), r2_p, col2, true)
		end
	end
	
	circle(canvas, xs ÷ 2, ys ÷ 2, floor(Int, 200/zoomx), rgb(0, 255, 0), true)
end


function draw(model, graphs1, graphs2, graphs3, gui)
	bg = rgb(100, 100, 100)
	redraw_at!(gui, 1, bg) do canvas
		draw_world(canvas, model)
	end

	redraw_at!(gui, 2, bg) do canvas
		draw_graph(canvas, graphs1)
	end

	redraw_at!(gui, 3, bg) do canvas
		draw_graph(canvas, graphs2)
	end
	
	redraw_at!(gui, 4, bg) do canvas
		draw_graph(canvas, graphs3)
	end
end

