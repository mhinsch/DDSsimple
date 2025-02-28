
using SimpleDirectMediaLayer.LibSDL2

include("run.jl")

using SimpleGui

include("draw_gui.jl")



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
			data = observe(Data, model.world, t, model.pars)
			# in case we skipped a step (shouldn't happen, but just in case...)
			for i in last:now
				# print all stats to file
				#print_stats(logfile, model)
				# this is suboptimal, as all these are calculated in print_stats as well
				# solution forthcoming
				add_value!(graphs[1], data.N.n)
				add_value!(graphs[2], data.outside.n)
				add_value!(graphs[3], data.donors.n)
				add_value!(graphs[4], data.donees.n)
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


const model, logf = prepare_model(ARGS) 

# two 640x640 panels next to each other
const gui = setup_Gui("SRM", 1000, 1000, 2, 1)
const graphs = [Graph{Int}(green(255)), Graph{Int}(red(255)), Graph{Int}(blue(255)), Graph{Int}(WHITE)] 


run(model, gui, graphs, logf)


close(logf)


SimpleDirectMediaLayer.Quit()
