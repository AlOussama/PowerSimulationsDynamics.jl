using PowerSimulationsDynamics
using Sundials

"""
Case 44:
This case study a 14-state virtual oscillator grid forming inverter against an infinite bus located at bus 1, with VOC located at bus 2.
The perturbation increase the reference power (analogy for mechanical power) from 0.5 to 0.7.
"""

##################################################
############### LOAD DATA ########################
##################################################

include(joinpath(TEST_FILES_DIR, "data_tests/test44.jl"))

##################################################
############### SOLVE PROBLEM ####################
##################################################

#PSCAD benchmark data: TODO

#Define Fault using Callbacks
Pref_change = ControlReferenceChange(1.0, case_inv, :P_ref, 0.7)

@testset "Test 44 VOC Inverter Infinite Bus ResidualModel" begin
    path = (joinpath(pwd(), "test-44"))
    !isdir(path) && mkdir(path)
    try
        # Define Simulation Problem
        sim = Simulation(
            ResidualModel,
            omib_sys, # system
            path,
            (0.0, 4.0),
            Pref_change,
        )


        # Obtain small signal results for initial conditions
        small_sig = small_signal_analysis(sim)
        @test small_sig.stable


        # Solve problem
        @test execute!(sim, IDA(); dtmax = 0.005, saveat = 0.005) ==
              PSID.SIMULATION_FINALIZED
        results = read_results(sim)

        # Obtain series data
        series = get_state_series(results, ("generator-102-1", :E_oc))
        t = series[1]
        E_oc = series[2]

        # Should return zeros and a warning
        series3 = get_field_current_series(results, "generator-102-1")
        series4 = get_field_voltage_series(results, "generator-102-1")

        # Obtain PSCAD benchmark data: TODO

        power = PSID.get_activepower_series(results, "generator-102-1")
        rpower = PSID.get_reactivepower_series(results, "generator-102-1")
        ω = PSID.get_frequency_series(results, "generator-102-1")
        @test isa(power, Tuple{Vector{Float64}, Vector{Float64}})
        @test isa(rpower, Tuple{Vector{Float64}, Vector{Float64}})
        @test isa(ω, Tuple{Vector{Float64}, Vector{Float64}})

    finally
        @info("removing test files")
        rm(path; force = true, recursive = true)
    end
end

@testset "Test 44 VOC Inverter Infinite Bus MassMatrixModel" begin
    path = (joinpath(pwd(), "test-44"))
    !isdir(path) && mkdir(path)
    try
        #Define Simulation Problem
        sim = Simulation(
            MassMatrixModel,
            omib_sys, # system
            path,
            (0.0, 4.0),
            Pref_change,
        )


        # Obtain small signal results for initial conditions
        small_sig = small_signal_analysis(sim)
        @test small_sig.stable


        # Solve problem
        @test execute!(sim, Rodas5(); dtmax = 0.005, saveat = 0.005) ==
              PSID.SIMULATION_FINALIZED
        results = read_results(sim)

        # Obtain series data
        series = get_state_series(results, ("generator-102-1", :E_oc))
        t = series[1]
        E_oc = series[2]

        # Obtain PSCAD benchmark data: TODO

        power = PSID.get_activepower_series(results, "generator-102-1")
        rpower = PSID.get_reactivepower_series(results, "generator-102-1")
        ω = PSID.get_frequency_series(results, "generator-102-1")
        @test isa(power, Tuple{Vector{Float64}, Vector{Float64}})
        @test isa(rpower, Tuple{Vector{Float64}, Vector{Float64}})
        @test isa(ω, Tuple{Vector{Float64}, Vector{Float64}})

    finally
        @info("removing test files")
        rm(path; force = true, recursive = true)
    end
end