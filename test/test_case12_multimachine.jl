"""
Case 12:
This case study a three bus system with 2 machines (Classic Model - Single Shaft: 2 State model) without loads.
The machine at bus 1 is used as a reference machine, while machine at bus 2 has a simplified droop governor (TGTypeII).
The perturbation trips four (out of 5) circuits of line between buses 1 and 2, multiplying by 4 its impedance.
"""

##################################################
############### LOAD DATA ########################
##################################################

include(joinpath(dirname(@__FILE__), "data_tests/test12.jl"))

##################################################
############### SOLVE PROBLEM ####################
##################################################

#Time span
tspan = (0.0, 5.0)

#Define Fault: Change of YBus
Ybus_change = NetworkSwitch(
    1.0, #change at t = 1.0
    Ybus_fault,
) #New YBus

@testset "Test 12 Multi Machine ImplicitModel" begin
    path = (joinpath(pwd(), "test-12"))
    !isdir(path) && mkdir(path)
    try
        sim = Simulation!(
            ImplicitModel,
            threebus_sys, #system,
            path,
            tspan, #time span
            Ybus_change, #Type of Fault
        )

        small_sig = small_signal_analysis(sim)
        @test small_sig.stable

        #Run simulation
        execute!(
            sim, #simulation structure
            IDA(),#Sundials DAE Solver
            dtmax = 0.02, #keywords arguments
        )

        series = get_state_series(sim, ("generator-102-1", :ω))

        diff = [0.0]
        res = get_init_values_for_comparison(sim)
        for (k, v) in test12_x0_init
            diff[1] += LinearAlgebra.norm(res[k] - v)
        end
        @test (diff[1] < 1e-3)
        @test sim.solution.retcode == :Success
    finally
        @info("removing test files")
        rm(path, force = true, recursive = true)
    end
end

@testset "Test 12 Multi Machine MassMatrixModel" begin
    path = (joinpath(pwd(), "test-12"))
    !isdir(path) && mkdir(path)
    try
        sim = Simulation!(
            MassMatrixModel,
            threebus_sys, #system,
            path,
            tspan, #time span
            Ybus_change, #Type of Fault
        )

        # small_sig = small_signal_analysis(sim)
        # @test small_sig.stable

        #Run simulation
        execute!(
            sim, #simulation structure
            Rodas5(),#Sundials DAE Solver
            dtmax = 0.02, #keywords arguments
        )

        series = get_state_series(sim, ("generator-102-1", :ω))

        diff = [0.0]
        res = get_init_values_for_comparison(sim)
        for (k, v) in test12_x0_init
            diff[1] += LinearAlgebra.norm(res[k] - v)
        end
        @test (diff[1] < 1e-3)
        @test sim.solution.retcode == :Success
    finally
        @info("removing test files")
        rm(path, force = true, recursive = true)
    end
end
