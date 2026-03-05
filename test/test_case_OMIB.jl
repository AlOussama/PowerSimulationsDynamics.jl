"""
Case 1:
This case study defines a classical machine against an infinite bus. The fault
drop a circuit on the (double circuit) line connecting the two buses, doubling its impedance
"""

##################################################
############### LOAD DATA ########################
##################################################

omib_sys = build_system(PSIDTestSystems, "psid_test_omib")

#Compute Y_bus after fault
omib_sys_fault = deepcopy(omib_sys)
fault_branch = get_component(Branch, omib_sys_fault, "BUS 1-BUS 2-i_1")
fault_branch.r = 0.00;
fault_branch.x = 0.1;
Ybus_fault = PNM.Ybus(omib_sys_fault)[:, :]

##################################################
############### SOLVE PROBLEM ####################
##################################################
# Define Fault: Change of YBus
Ybus_change = NetworkSwitch(
    1.0, #change at t = 1.0
    Ybus_fault,
) #New YBus

@testset "Test 01 OMIB ResidualModel" begin
    path = mktempdir()
    try
        # Define Simulation Problem
        sim = Simulation!(
            ResidualModel,
            omib_sys, #system
            path,
            (0.0, 20.0), #time span
            Ybus_change,
        )


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
        series3 = get_voltage_angle_series(results, 102)

        #Obtain PSAT and PSS/e benchmark data

        # We test that the time series have the same number of items for convenience.

        power = get_activepower_series(results, "generator-102-1")
        rpower = get_reactivepower_series(results, "generator-102-1")
        @test isa(power, Tuple{Vector{Float64}, Vector{Float64}})
        @test isa(rpower, Tuple{Vector{Float64}, Vector{Float64}})

        series_repeat_timestamps =
            get_state_series(results, ("generator-102-1", :δ); unique_timestamps = false)
        @test length(δ) + 1 == length(series_repeat_timestamps[2])
    finally
        @info("removing test files")
        rm(path; force = true, recursive = true)
    end
end

@testset "Test 01 OMIB MassMatrixModel" begin
    path = (joinpath(pwd(), "test-01"))
    !isdir(path) && mkdir(path)
    try
        # Define Simulation Problem
        sim = Simulation!(
            MassMatrixModel,
            omib_sys, #system
            path,
            (0.0, 20.0), #time span
            Ybus_change,
        )


        small_sig = small_signal_analysis(sim)
        #Test Small Signal
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
        series3 = get_voltage_angle_series(results, 102)

        # Obtain PSAT and PSS/e benchmark data


        power = get_activepower_series(results, "generator-102-1")
        rpower = get_reactivepower_series(results, "generator-102-1")
        @test isa(power, Tuple{Vector{Float64}, Vector{Float64}})
        @test isa(rpower, Tuple{Vector{Float64}, Vector{Float64}})

    finally
        @info("removing test files")
        rm(path; force = true, recursive = true)
    end
end