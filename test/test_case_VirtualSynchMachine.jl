"""
Case 8:
This case study a 19-state virtual synchronous machine against an infinite bus located at bus 1, with VSM located at bus 2.
The perturbation increase the reference power (analogy for mechanical power) from 0.5 to 0.7.
"""

##################################################
############### LOAD DATA ########################
##################################################

omib_sys = build_system(PSIDTestSystems, "psid_test_vsm_inverter")
case_inv = [g for g in get_components(DynamicInjection, omib_sys)][1]

##################################################
############### SOLVE PROBLEM ####################
##################################################

#PSCAD benchmark data

#Define Fault using Callbacks
Pref_change = ControlReferenceChange(1.0, case_inv, :P_ref, 0.7)

@testset "Test 08 VSM Inverter Infinite Bus ResidualModel" begin
    path = mktempdir()
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

        # Check Eigenvalue Report
        df1 = summary_eigenvalues(small_sig)
        df2 = summary_participation_factors(small_sig)
        @test isa(df1, DataFrame)
        @test isa(df2, DataFrame)


        # Solve problem
        @test execute!(sim, IDA(); dtmax = 0.005, saveat = 0.005) ==
              PSID.SIMULATION_FINALIZED
        results = read_results(sim)

        # Obtain frequency data
        series = get_state_series(results, ("generator-102-1", :ω_oc))
        t = series[1]
        ω = series[2]

        # Should return zeros and a warning
        series3 = get_field_current_series(results, "generator-102-1")
        series4 = get_field_voltage_series(results, "generator-102-1")


        power = PSID.get_activepower_series(results, "generator-102-1")
        rpower = PSID.get_reactivepower_series(results, "generator-102-1")
        ω2 = PSID.get_frequency_series(results, "generator-102-1")
        @test isa(power, Tuple{Vector{Float64}, Vector{Float64}})
        @test isa(rpower, Tuple{Vector{Float64}, Vector{Float64}})
        @test isa(ω2, Tuple{Vector{Float64}, Vector{Float64}})

    finally
        @info("removing test files")
        rm(path; force = true, recursive = true)
    end
end

@testset "Test 08 VSM Inverter Infinite Bus MassMatrixModel" begin
    path = mktempdir()
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

        # Check Eigenvalue Report
        df1 = summary_eigenvalues(small_sig)
        df2 = summary_participation_factors(small_sig)
        @test isa(df1, DataFrame)
        @test isa(df2, DataFrame)


        # Solve problem
        @test execute!(sim, Rodas5(); dtmax = 0.005, saveat = 0.005) ==
              PSID.SIMULATION_FINALIZED
        results = read_results(sim)

        # Obtain frequency data
        series = get_state_series(results, ("generator-102-1", :ω_oc))
        t = series[1]
        ω = series[2]


        power = PSID.get_activepower_series(results, "generator-102-1")
        rpower = PSID.get_reactivepower_series(results, "generator-102-1")
        ω2 = PSID.get_frequency_series(results, "generator-102-1")
        @test isa(power, Tuple{Vector{Float64}, Vector{Float64}})
        @test isa(rpower, Tuple{Vector{Float64}, Vector{Float64}})
        @test isa(ω2, Tuple{Vector{Float64}, Vector{Float64}})
    finally
        @info("removing test files")
        rm(path; force = true, recursive = true)
    end
end