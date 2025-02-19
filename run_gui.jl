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



using SimpleDirectMediaLayer.LibSDL2

using MiniEvents

include("util.jl")
include("stupider.jl")
include("main_util.jl")

using SimpleGui

include("draw_gui.jl")



### run simulation with given setup and parameters

function run(model, gui, graphs, logfile, max_step = 0.1)
	t = 1.0
	step = max_step
	last = 0

	pause = false
	quit = false
	while ! quit
		# don't do anything if we are in pause mode
		if pause
			sleep(0.03)
			continue
		end

		t1 = time()
		step_until!(model, t) # run internal scheduler up to the next time step
		
		# we want the analysis to happen at every integral time step
		if (now = trunc(Int, t)) >= last
			# in case we skipped a step (shouldn't happen, but just in case...)
			for i in last:now
				# print all stats to file
				#print_stats(logfile, model)
				# this is suboptimal, as all these are calculated in print_stats as well
				# solution forthcoming
				add_value!(graphs[1], model.N)
				#add_value!(graphs[2], count(ag -> ag.status == infected, model.pop))
				#add_value!(graphs[3], count(ag -> ag.status == immune, model.pop))
				#add_value!(graphs[4], count(ag -> ag.status == dead, model.pop))
			end
			# remember when we did the last data output
			last = now
		end

		t += step

		# measure (real-world) time it took to simulate one step
		dt = time() - t1

		# adjust simulation step size
		if dt > 0.1
			step /= 1.1
		elseif dt < 0.03 && step < max_step # this is a simple model, so let's limit
			step *= 1.1                # max step size to about 1
		end

		println(t)

		event_ref = Ref{SDL_Event}()
        while Bool(SDL_PollEvent(event_ref))
            evt = event_ref[]
            evt_ty = evt.type
			if evt_ty == SDL_QUIT
                quit = true
                break
            elseif evt_ty == SDL_KEYDOWN
                scan_code = evt.key.keysym.scancode
                if scan_code == SDL_SCANCODE_ESCAPE || scan_code == SDL_SCANCODE_Q
					quit = true
					break
                elseif scan_code == SDL_SCANCODE_P || scan_code == SDL_SCANCODE_SPACE
					pause = !pause
                    break
                else
                    break
                end
            end
		end

		# draw gui to video memory
		draw(model, graphs, gui)
		# copy to screen
		render!(gui)
	end
end


function prepare_outfiles(fname)
	logfile = open(fname, "w")
	#print_header(logfile, Data)
	logfile
end

const allpars, args = load_parameters(ARGS, Pars) #=, cmdl = ( 
    ["--log-freq"],
    Dict(:help => "set time steps between log calls", :default => 23*60, :arg_type => Int),
    ["--output", "-o"],
    Dict(:help => "set data output file name", :default => "data.tsv", :arg_type => String)))
    =#
    
const p = allpars[1]

Random.seed!(p.seed)


## setup

const model = setup(p)

const logf = prepare_outfiles("log_file.txt")

# two 640x640 panels next to each other
const gui = setup_Gui("SRM", 1000, 1000, 2, 1)
const graphs = [Graph{Int}(green(255)), Graph{Int}(red(255)), Graph{Int}(blue(255)), Graph{Int}(WHITE)] 



## run

run(model, gui, graphs, logf)



## cleanup

close(logf)

Quit()
