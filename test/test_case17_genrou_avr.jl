"""
Case GENROU + AVR Type I:
This case study defines a three bus system with an infinite bus, GENROU (with AVR TypeI) and a load.
The fault drop the line connecting the infinite bus and GENROU.
"""

##################################################
############### LOAD DATA ########################
##################################################

include(joinpath(TEST_FILES_DIR, "data_tests/test17.jl"))

##################################################
############### SOLVE PROBLEM ####################
##################################################

@testset "Test 17 GENROU AVR ResidualModel" begin
    path = mktempdir()
    try
        # Define Simulation Problem
        sim = Simulation!(
            ResidualModel,
            sys, #system
            path,
            (0.0, 30.0), #time span
            BranchTrip(1.0, Line, "BUS 1-BUS 2-i_1"), #Type of Fault,
        ) #Type of Fault


        # Obtain small signal results for initial conditions
        small_sig = small_signal_analysis(sim)
        @test small_sig.stable


        # Solve problem
        @test execute!(sim, IDA(); dtmax = 0.01) == PSID.SIMULATION_FINALIZED
        results = read_results(sim)

        # Obtain data for angles
        series = get_state_series(results, ("generator-102-1", :δ))
    finally
        @info("removing test files")
        rm(path; force = true, recursive = true)
    end
end

@testset "Test 17 GENROU AVR MassMatrixModel" begin
    path = mktempdir()
    try
        # Define Simulation Problem
        sim = Simulation!(
            MassMatrixModel,
            sys, #system
            path,
            (0.0, 30.0), #time span
            BranchTrip(1.0, Line, "BUS 1-BUS 2-i_1"), #Type of Fault,
        ) #Type of Fault


        # Obtain small signal results for initial conditions
        small_sig = small_signal_analysis(sim)
        @test small_sig.stable


        # Solve problem
        @test execute!(sim, Rodas4(); dtmax = 0.01) == PSID.SIMULATION_FINALIZED
        results = read_results(sim)

        # Obtain data for angles
        series = get_state_series(results, ("generator-102-1", :δ))
    finally
        @info("removing test files")
        rm(path; force = true, recursive = true)
    end
end