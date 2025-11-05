
"Model parameters"
@kwdef mutable struct Pars
	"world size x"
	sz_x :: Float64 = 1000.0
	"world size y"
	sz_y :: Float64 = 1000.0
	"initial pop size"
	n_ini :: Int = 200
	"y spread of initial pop"
	ini_y :: Float64 = 100.0
	"x spread of initial pop"
	ini_x :: Float64 = 100.0
	"ini range of coop values"
    ini_coop :: Vector{Float64} = [1.0, 1.0]
    "number of landscape effects"
    n_obst :: Int = 30000

	"max range of spatial effects (in multiple of sd)"
	effect_radius :: Float64 = 3.0
    
	"reproduction rate"
	r_repr :: Float64 = 0.1
	"natural background mortality"
	r_death :: Float64 = 1.0/60.0
	"mortality under starvation"
	r_starve :: Float64 = 1.0
	"movement rate"
	r_move :: Float64 = 1.0
	"exchange rate"
	r_exch :: Float64 = 1.0
	"improvement rate"
	r_improve :: Float64 = 1.0
	"storage rate"
	r_store :: Float64 = 1.0
	"rate of storage reset"
	r_store_reset :: Float64 = 1.0
	
	"effect of provisioning on reproduction (0-1)"
	eff_prov_repr :: Float64 = 1.0
	"nonlinear effects of provision on reproduction (1=neutral)"
	shape_prov_repr :: Float64 = 2.0
	"effect of provisioning on death (0-1)"
	eff_prov_death :: Float64 = 0.0
	"nonlinear effects of provision on death (1=neutral)"
	shape_prov_death :: Float64 = 2.0
	
	"specific carrying capacity ; K = r^2 * f"
	spec_capacity :: Float64 = 1.0/5.0
	"radius of influence of density"
	spread_density :: Float64 = 5.0
	"effect of obstacles"
	obst_effect :: Float64 = -1.0
	"priority of resource access for first arrivals"
	despoticness :: Float64 = 0.5

	"whether agents are stopped at the edge or disappear"
	open_edge :: Bool = true
	"distribution of step size: 1 - Uniform, 2 - Normal, 3 - Levy"
	move_mode :: Int = 2
	"mean step size"
	mu_mig :: Float64 = 0.0
	"sd of stepsize"
	theta_mig :: Float64 = 2.5
	"density dependence of move rate"
	r_move_d :: Float64 = 0.0
	"density independent move rate"
	r_move_0 :: Float64 = 1.0

	"donation model: 1 - provision, 2 - storage"
	donate_mode :: Int = 1
	"proportion of surplus to store"
	prop_store :: Float64 = 0.5

	"exchange rate model: 1 - provision, 2 - local condition"
	exchange_mode :: Int = 1
	"sd of exchange distance"
	spread_exchange :: Float64 = 10
	"proportion of resources that get exchanged"
	prop_exchange :: Float64 = 0.5
	"efficiency of exchange"
	eff_exchange :: Float64 = 0.9
	"rate at which resources get reset to default"
	r_reset_prov :: Float64 = 1.0
	"whether to cap donations at amount needed"
	cap_donations :: Bool = true

	"'mutation' rate"
	r_mut :: Float64 = 0.0
	d_mut :: Float64 = 0.05

	"number of bits in family genes"
	n_family :: Int = 0
	"how many bits to flip during mutation"
	n_family_mutate :: Int = 0
	ini_rand_family :: Bool = true
	"whether relatedness affects exchange"
	rel_exchange :: Bool = false
	
	"rate of appearance of weather effects"
	r_weather :: Float64 = 20
	"rate of disappearance of weather effects"
	r_weather_end :: Float64 = 0.3

	"sd of effect of weather"
	spread_weather :: Float64 = 10.0
	"min and max value of weather influence on capacity"
	wth_range :: Vector{Float64} = [-1.0, 0.0]
	"whether weather is mitigated by density: 1 - not at all, 2 - density, 3 - landscape"
	weather_density_mode :: Int = 1

	shuffle_coop :: Bool = false

	"random seed"
	seed :: Int = 41
	"simulation time"
	t_max :: Float64 = 1000.0
end
