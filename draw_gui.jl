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

	zoomy = model.pars.sz[1] / ys
	zoomx = model.pars.sz[2] / xs

	wc = model.world.weather_cache.data

	r1_wth = floor(Int, model.pars.spread_weather/zoomx)
	r2_wth = floor(Int, model.pars.rad_weather/zoomx)

	for y in 1:size(wc)[1], x in 1:size(wc)[2]
		for w in wc[y, x]
			p = w.pos ./ (zoomy, zoomx)

			col = w.effect < 0 ?
				red(floor(UInt32, -w.effect * 250)) :
				green(floor(UInt32, w.effect * 250)) 

			circle_fill(canvas, floor(Int, p[2]), floor(Int, p[1]), r1_wth, UInt32(col), true)
			circle(canvas, floor(Int, p[2]), floor(Int, p[1]), r2_wth, UInt32(col), true)
		end
	end


	pc = model.world.pop_cache.data

	r1_p = 1
	r2_p = floor(Int, model.pars.spread_exchange/zoomx)

	for y in 1:size(pc)[1], x in 1:size(pc)[2]
		for a in pc[y, x]
			p = a.pos ./ (zoomy, zoomx)

			col = rgb(a.coop*150+105, a.coop*150+105, 255)
			col2 = rgb(100, 100, 100)
			
			circle_fill(canvas, floor(Int, p[1]), floor(Int, p[2]), r1_p, col, true)
			circle(canvas, floor(Int, p[1]), floor(Int, p[2]), r2_p, col2, true)
		end
	end
	
	circle(canvas, xs ÷ 2, ys ÷ 2, floor(Int, 200/zoomx), rgb(0, 255, 0), true)
end

# draw both panels to video memory
function draw(model, graphs, gui)
	clear!(gui.canvas)
	draw_world(gui.canvas, model)
	update!(gui.panels[1,1], gui.canvas)

	clear!(gui.canvas)
	draw_graph(gui.canvas, graphs)
	update!(gui.panels[2, 1], gui.canvas)
end

