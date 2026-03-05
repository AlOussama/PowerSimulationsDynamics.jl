"""
Case 45:
This case study a three bus system with 2 machines (Sauer Pai: 6th order model) and an infinite source.
The fault drop the connection between buses 1 and 3, eliminating the direct connection between the infinite source
and the generator located in bus 3. 
"""

##################################################
############### LOAD DATA ########################
##################################################

include(joinpath(TEST_FILES_DIR, "data_tests/test45.jl"))

##################################################
############### SOLVE PROBLEM ####################
##################################################

# Define Fault: Line trip
#PSY.show_components(threebus_sys, Line)
perturbation = BranchTrip(1.0, Line, "BUS 1-BUS 2-i_1")

@testset "Test 45 SauerPai ResidualModel" begin
    path = (joinpath(pwd(), "test-45"))
    !isdir(path) && mkdir(path)
    try
        # Define Simulation Problem
        sim = Simulation!(
            ResidualModel,
            threebus_sys, #system
            path,
            (0.0, 20.0), #time span
            perturbation, #Type of Fault
        ) #initial guess
        dict_setpoints = get_setpoints(sim)

        #for g in get_components(DynamicGenerator, threebus_sys)
        #    display("Power setpoints")
        #    display(get_P_ref(g))
        #end

        # Obtain small signal results for initial conditions
        small_sig = small_signal_analysis(sim)
        @test small_sig.stable


        # Solve problem
        @test execute!(sim, IDA(); dtmax = 0.005, saveat = 0.005) ==
              PSID.SIMULATION_FINALIZED
        results = read_results(sim)

        # Obtain data for angles
        series = get_voltage_magnitude_series(results, 101)
        t = series[1]
        V101 = series[2]

        # Should return zeros and a warning
        series3 = get_field_current_series(results, "generator-101-1")

        # TODO Testing:
        # Obtain PSAT benchmark data
        #psat_csv = joinpath(TEST_FILES_DIR, "benchmarks/psat/Test45/Test45_delta.csv")
        #t_psat, δ_psat = get_csv_delta(psat_csv)


        power = PSID.get_activepower_series(results, "generator-101-1")
        rpower = PSID.get_reactivepower_series(results, "generator-101-1")
        #@test isa(power, Tuple{Vector{Float64}, Vector{Float64}})
        #@test isa(rpower, Tuple{Vector{Float64}, Vector{Float64}})
    finally
        @info("removing test files")
        rm(path; force = true, recursive = true)
    end
end

@testset "Test 45 SauerPai MassMatrixModel" begin
    path = (joinpath(pwd(), "test-45"))
    !isdir(path) && mkdir(path)
    try
        # Define Simulation Problem
        sim = Simulation!(
            MassMatrixModel,
            threebus_sys, #system,
            path,
            (0.0, 20.0), #time span
            perturbation, #Type of Fault
        ) #initial guess


        # Obtain small signal results for initial conditions
        small_sig = small_signal_analysis(sim)
        @test small_sig.stable


        # Solve problem
        @test execute!(sim, Rodas4(); dtmax = 0.005, saveat = 0.005) ==
              PSID.SIMULATION_FINALIZED
        results = read_results(sim)

        # Obtain data for angles
        series = get_state_series(results, ("generator-101-1", :δ))
        t = series[1]
        δ = series[2]

        # Should return zeros and a warning
        series3 = get_field_current_series(results, "generator-101-1")

        # Obtain PSAT benchmark data
        #psat_csv = joinpath(TEST_FILES_DIR, "benchmarks/psat/Test45/Test45_delta.csv")
        #t_psat, δ_psat = get_csv_delta(psat_csv)


        power = PSID.get_activepower_series(results, "generator-101-1")
        rpower = PSID.get_reactivepower_series(results, "generator-101-1")
        #@test isa(power, Tuple{Vector{Float64}, Vector{Float64}})
        #@test isa(rpower, Tuple{Vector{Float64}, Vector{Float64}})

    finally
        @info("removing test files")
        rm(path; force = true, recursive = true)
    end
end