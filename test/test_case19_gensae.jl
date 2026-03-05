"""
Validation PSSE/GENSAE:
This case study defines a three bus system with an infinite bus, GENSAE and a load.
The fault drop the line connecting the infinite bus and GENSAE.
"""

##################################################
############### SOLVE PROBLEM ####################
##################################################

# Define dyr files

names = [
    "GENSAE: Normal Saturation",
    #"GENSAE: High Saturation"
]

dyr_files = [
    joinpath(TEST_FILES_DIR, "benchmarks/psse/GENSAE/ThreeBus_GENSAE.dyr"),
    #joinpath(TEST_FILES_DIR, "benchmarks/psse/GENSAE/ThreeBus_GENSAE_HIGH_SAT.dyr"),
]




raw_file_dir = joinpath(TEST_FILES_DIR, "benchmarks/psse/GENSAE/ThreeBusMulti.raw")
tspan = (0.0, 20.0)

function test_gensae_implicit(dyr_file)
    path = mktempdir()
    try
        sys = System(raw_file_dir, dyr_file)
        for l in get_components(PSY.StandardLoad, sys)
            transform_load_to_constant_impedance(l)
        end

        # Define Simulation Problem
        sim = Simulation!(
            ResidualModel,
            sys, #system
            path,
            tspan, #time span
            BranchTrip(1.0, Line, "BUS 1-BUS 2-i_1"), #Type of Fault
        ) #Type of Fault


        # Obtain small signal results for initial conditions
        small_sig = small_signal_analysis(sim)
        @test small_sig.stable


        # Solve problem
        @test execute!(sim, IDA(); dtmax = 0.005, saveat = 0.005) ==
              PSID.SIMULATION_FINALIZED
        results = read_results(sim)

        # Obtain data for angles
        series = get_state_series(results, ("generator-102-1", :δ))
        t = series[1]
        δ = series[2]
        series2 = get_voltage_magnitude_series(results, 102)
        # TODO: Test I_fd with PSSE
        series3 = get_field_current_series(results, "generator-102-1")


        power = PSID.get_activepower_series(results, "generator-102-1")
        rpower = PSID.get_reactivepower_series(results, "generator-102-1")
        @test isa(series2, Tuple{Vector{Float64}, Vector{Float64}})
        @test isa(power, Tuple{Vector{Float64}, Vector{Float64}})
        @test isa(rpower, Tuple{Vector{Float64}, Vector{Float64}})
    finally
        @info("removing test files")
        rm(path; force = true, recursive = true)
    end
end

function test_gensae_mass_matrix(dyr_file)
    path = mktempdir()
    try
        sys = System(raw_file_dir, dyr_file)
        for l in get_components(PSY.StandardLoad, sys)
            transform_load_to_constant_impedance(l)
        end

        # Define Simulation Problem
        sim = Simulation!(
            MassMatrixModel,
            sys, #system
            path,
            tspan, #time span
            BranchTrip(1.0, Line, "BUS 1-BUS 2-i_1"), #Type of Fault
        ) #Type of Fault


        # Obtain small signal results for initial conditions
        small_sig = small_signal_analysis(sim)
        @test small_sig.stable


        # Solve problem
        @test execute!(sim, Rodas4(); dtmax = 0.005, saveat = 0.005) ==
              PSID.SIMULATION_FINALIZED
        results = read_results(sim)

        # Obtain data for angles
        series = get_state_series(results, ("generator-102-1", :δ))
        t = series[1]
        δ = series[2]
        series2 = get_voltage_magnitude_series(results, 102)
        # TODO: Test I_fd with PSSE
        series3 = get_field_current_series(results, "generator-102-1")


        power = PSID.get_activepower_series(results, "generator-102-1")
        rpower = PSID.get_reactivepower_series(results, "generator-102-1")
        @test isa(series2, Tuple{Vector{Float64}, Vector{Float64}})
        @test isa(power, Tuple{Vector{Float64}, Vector{Float64}})
        @test isa(rpower, Tuple{Vector{Float64}, Vector{Float64}})
    finally
        @info("removing test files")
        rm(path; force = true, recursive = true)
    end
end

@testset "Test 19 GENSAE ResidualModel" begin
    for (ix, name) in enumerate(names)
        @testset "$(name)" begin
            dyr_file = dyr_files[ix]
            test_gensae_implicit(dyr_file)
        end
    end
end

@testset "Test 19 GENSAE MassMatrixModel" begin
    for (ix, name) in enumerate(names)
        @testset "$(name)" begin
            dyr_file = dyr_files[ix]
            test_gensae_mass_matrix(dyr_file)
        end
    end
end