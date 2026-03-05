"""
Validation PSSE/ESAC1A:
This case study defines a three bus system with an infinite bus, GENROU and a load.
The GENROU machine has connected an ESAC1A Excitation System.
The fault drop the line connecting the infinite bus and GENROU.
"""

##################################################
############### SOLVE PROBLEM ####################
##################################################

# Define dyr files

names = ["AC1A: No Saturation", "AC1A: with Saturation"]

dyr_files = [
    joinpath(TEST_FILES_DIR, "benchmarks/psse/AC1A/ThreeBus_ESAC1A.dyr"),
    joinpath(TEST_FILES_DIR, "benchmarks/psse/AC1A/ThreeBus_ESAC1A_SAT.dyr"),
]




raw_file_dir = joinpath(TEST_FILES_DIR, "benchmarks/psse/AC1A/ThreeBusMulti.raw")
tspan = (0.0, 20.0)

function test_ac1a_implicit(dyr_file)
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
        # Obtain data for voltage magnitude at bus 102
        series2 = get_voltage_magnitude_series(results, 102)
        series3 = get_field_current_series(results, "generator-102-1")
        series4 = get_field_voltage_series(results, "generator-102-1")
        t = series[1]
        δ = series[2]
        V = series2[2]
        # TODO: Test I_fd and Vf with PSSE
        I_fd = series3[2]
        Vf = series4[2]


    finally
        @info("removing test files")
        rm(path; force = true, recursive = true)
    end
end

function test_ac1a_mass_matrix(dyr_file)
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
        # Obtain data for voltage magnitude at bus 102
        series2 = get_voltage_magnitude_series(results, 102)
        series3 = get_field_current_series(results, "generator-102-1")
        series4 = get_field_voltage_series(results, "generator-102-1")
        t = series[1]
        δ = series[2]
        V = series2[2]
        # TODO: Test I_fd and Vf with PSSE
        I_fd = series3[2]
        Vf = series4[2]


    finally
        @info("removing test files")
        rm(path; force = true, recursive = true)
    end
end

@testset "Test 20 AC1A ResidualModel" begin
    for (ix, name) in enumerate(names)
        @testset "$(name)" begin
            dyr_file = dyr_files[ix]
            test_ac1a_implicit(dyr_file)
        end
    end
end

@testset "Test 20 AC1A MassMatrixModel" begin
    for (ix, name) in enumerate(names)
        @testset "$(name)" begin
            dyr_file = dyr_files[ix]
            test_ac1a_mass_matrix(dyr_file)
        end
    end
end