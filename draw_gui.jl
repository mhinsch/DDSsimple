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

	for y in 1:size(wc)[1], x in 1:size(wc)[2]
		for w in wc[y, x]
			p = w.pos ./ (zoomy, zoomx)

			col = w.effect < 0 ?
				red(floor(UInt32, -w.effect * 250)) :
				green(floor(UInt32, w.effect * 250)) 

			circle_fill(canvas, floor(Int, p[2]), floor(Int, p[1]),
				floor(Int, model.pars.spread_weather/zoomx), UInt32(col), true)
			circle(canvas, floor(Int, p[2]), floor(Int, p[1]),
				floor(Int, model.pars.rad_weather/zoomx), UInt32(col), true)
		end
	end


	pc = model.world.pop_cache.data

	for y in 1:size(pc)[1], x in 1:size(pc)[2]
		for a in pc[y, x]
			p = a.pos ./ (zoomy, zoomx)

			col = rgb(a.coop*150+105, a.coop*150+105, 255)
			
			circle_fill(canvas, floor(Int, p[1]), floor(Int, p[2]), 2, col, true)
		end
	end
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

