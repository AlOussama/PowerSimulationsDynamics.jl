using PowerSimulationsDynamics
using Sundials

"""
Case 23:
This case study a 15-state droop grid forming inverter against an infinite bus located at bus 1, with inverter located at bus 2.
The perturbation increase the reference power (analogy for mechanical power) from 0.5 to 0.7.
"""

##################################################
############### LOAD DATA ########################
##################################################

omib_sys = build_system(PSIDTestSystems, "psid_test_droop_inverter")
case_inv = [g for g in get_components(DynamicInjection, omib_sys)][1]

##################################################
############### SOLVE PROBLEM ####################
##################################################

# time span
tspan = (0.0, 4.0);

# PSCAD benchmark data

#Define Fault using Callbacks
Pref_change = ControlReferenceChange(1.0, case_inv, :P_ref, 0.7)

@testset "Test 23 Droop Inverter ResidualModel" begin
    path = mktempdir()
    try
        # Define Simulation Problem
        sim = Simulation!(
            ResidualModel,
            omib_sys, # system
            path,
            tspan,
            Pref_change,
        )


        # Obtain small signal results for initial conditions
        small_sig = small_signal_analysis(sim)
        @test small_sig.stable


        #Solve problem
        @test execute!(sim, IDA(); dtmax = 0.005, saveat = 0.005) ==
              PSID.SIMULATION_FINALIZED
        results = read_results(sim)

        #Obtain data for angles
        series = get_state_series(results, ("generator-102-1", :θ_oc))
        t = series[1]
        θ = series[2]


        ω = PSID.get_frequency_series(results, "generator-102-1")
        @test isa(ω, Tuple{Vector{Float64}, Vector{Float64}})
    finally
        @info("removing test files")
        rm(path; force = true, recursive = true)
    end
end

@testset "Test 23 Droop Inverter MassMatrixModel" begin
    path = mktempdir()
    try
        # Define Simulation Problem
        sim = Simulation!(
            MassMatrixModel,
            omib_sys, # system
            path,
            tspan,
            Pref_change,
        )


        # Obtain small signal results for initial conditions
        small_sig = small_signal_analysis(sim)
        @test small_sig.stable


        #Solve problem
        @test execute!(sim, Rodas4(); dtmax = 0.005, saveat = 0.005) ==
              PSID.SIMULATION_FINALIZED
        results = read_results(sim)

        #Obtain data for angles
        series = get_state_series(results, ("generator-102-1", :θ_oc))
        t = series[1]
        θ = series[2]


        ω = PSID.get_frequency_series(results, "generator-102-1")
        @test isa(ω, Tuple{Vector{Float64}, Vector{Float64}})
    finally
        @info("removing test files")
        rm(path; force = true, recursive = true)
    end
end