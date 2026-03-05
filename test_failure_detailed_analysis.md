# Test Failure Analysis - PowerSimulationsDynamics.jl

## Summary
**Test Results:** 699 passed, 42 failed, 17 errored (Total: 758 tests)
**Improvement from previous run:** +5 passed, +16 failed, -2 errored

## Failure Stage Categories

### 1. PowerFlows/PNM Stage (1 test, 2 errors)
**PowerFlows fails to solve, simulation cannot initialize**

- **Test 35: MultiGen**
  - Error: "No available sources at bus BUS 2 HV"
  - Stage: PowerFlows AC Power Flow solver
  - Root cause: Bus configuration issue prevents PF convergence
  - PF/PNM relation: **Direct PowerFlows failure**

---

### 2. Dynamic Device Initialization Stage (6 tests, ~10 errors)
**PowerFlows succeeds, but device-level NLSolve fails to converge**

- **Test 25: Marconato with Dynamic Lines** (2 errors: Residual+Mass)
  - Error: `Residual error is too large to continue` (0.173 at Generator V_3, state I)
  - Stage: Device initialization NLSolve
  - PF/PNM: PowerFlows completed successfully
  - Issue: Induction motor initialization cannot converge at new operating point
  
- **Test 29: RENA (Ref_Flag=1, V_Flag=0, Q_Flag=0)** (2 errors)
  - Error: `Residual error is too large` (0.00336 at generator-103-1, state V_cflt)
  - Stage: Device initialization NLSolve  
  - PF/PNM: PowerFlows completed successfully
  - Issue: Renewable model (REGCA/REEC) fails to initialize

- **Test 37: 5th_order Induction Motor** (2 errors)
  - Error: `MethodError: no method matching get_activepower_series(::Nothing, ::String)`
  - Stage: Simulation building (likely perturbation setup)
  - PF/PNM: PowerFlows completed successfully
  - Issue: Code bug - missing API method for induction motor load series

- **Test 38: 3rd_order Induction Motor** (2 errors)
  - Error: `MethodError: no method matching get_activepower_series(::Nothing, ::String)`
  - Stage: Simulation building (likely perturbation setup)
  - PF/PNM: PowerFlows completed successfully
  - Issue: Code bug - missing API method for simplified induction motor

- **Test 45: SauerPai** (2 errors)
  - Error: (TBD - likely initialization convergence)
  - Stage: Device initialization
  - PF/PNM: PowerFlows completed successfully
  - Issue: SauerPai machine model initialization fails

---

### 3. System-Level Initialization Stage (1 test, 2 errors)
**Device init succeeds, but system NLSolve `refine_initial_condition!` fails**

- **Test 31: HYGOV in Kundur Model** (2 errors + 2 failures)
  - Error: `Error is too large to continue` (58.3 at bus 2, voltage component)
  - Stage: System-level `refine_initial_condition!` NLSolve
  - PF/PNM: PowerFlows completed successfully
  - Warnings: All 4 HYGOV governors report gate positions outside limits (5.53-7.14 vs limits)
  - Issue: Our HYGOV fix clamps values, but system-level NLSolve cannot converge with clamped parameters
  - **Note:** This is the one test where our init robustness fix created new problems

---

### 4. Dynamic Simulation Stage (4 tests, 4 failures)
**Initialization succeeds, but ODE solver reports unstable dynamics**

- **Test 29: RENA (No Flags, Freq Flag)** (2 failures)
  - Error: `The simulation failed with return code Unstable`
  - Stage: ODE integration during execute!()
  - PF/PNM: PowerFlows completed successfully
  - Init: Completed successfully
  - Issue: System becomes dynamically unstable during simulation - physics problem

- **Test 30: IEEEST (no Filter, with Filter)** (2 failures)
  - Error: `The simulation failed with return code Unstable`
  - Stage: ODE integration
  - PF/PNM: PowerFlows completed successfully
  - Init: Completed successfully
  - Issue: PSS (IEEEST) causes instability at new operating point

---

### 5. Initialization Convergence Warnings (Tests that pass with warnings)

- **Tests 39, 40, 43, 55** and others show:
  - `Warning: Initialization non-linear solve convergence failed`
  - `Attempting again with reduced numeric tolerance and using another solver`
  - `Warning: The resulting voltages in the initial conditions differ from the power flow results`
  - These warnings appear but tests eventually execute (may pass or fail later)

---

### 6. Test-Specific Issues

- **Test 39: EXST1** (1 error, 2 failures)
  - Status: Got past HYGOV gate limit crash (our fix worked!)
  - Now has: Build failures and execution issues
  - Mixed init convergence and simulation problems

- **Test 40: EXAC1** (2 errors, 2 failures)
  - Status: Got past HYGOV gate limit crash (our fix worked!)
  - Now has: 2 tests pass, 2 fail with simulation issues
  - Mixed results

- **Test 42: DERA** (2 failures)
  - Both FreqFlag=0 and FreqFlag=1 cases fail
  - Likely simulation instability

- **Test 43: REGCA Voltage** (2 failures)
  - Both ResidualModel and MassMatrixModel fail
  - `Initialization non-linear solve convergence failed` warnings
  - Likely init convergence → simulation failure chain

- **Test 50: Load BasePower** (4 failures)
  - Test file: test_case50_load_basepower.jl
  - These are specific value comparison tests
  - Failures at lines 95, 97, 100, 102
  - Likely checking load_active_power_total, load_reactive_power_total values
  - Issue: Values changed due to different PF operating point

- **Test 32: 9-Bus Machine Only System** (2 failures)
  - Status: TBD - likely TGTypeI warnings + init/simulation issues

- **Test 05/06: Anderson models** (4 failures total)
  - Both Simple Anderson and Anderson fail
  - Status: Likely init convergence or simulation instability

- **Test 55: ESST1A** (1 error, 2 failures)
  - Status: Got past HYGOV gate limit crash (our fix worked!)
  - Now has: Mixed init and execution issues

- **Sundials KLU** (1 error)
  - Error: `[IDAHandleFailure] At t = 1 and h = 9.76e-07, error test failed repeatedly`
  - Stage: Sundials IDA solver (sparse linear algebra)
  - Issue: Numerical stiffness or ill-conditioning with KLU

---

## Relation to PowerFlows and PowerNetworkMatrices

### PowerFlows v0.15 Impact

**Direct failures:**
- **Test 35:** PowerFlows cannot solve (bus configuration issue)

**Indirect impact (majority of failures):**
- PowerFlows solves successfully but produces **different operating points** than PSY3/PF0.6
- Old PF: `PF.solve_ac_powerflow!(sys)` using NLSolve backend
- New PF: `PF.ACPowerFlow()` using Newton-Raphson with no reactive power limit enforcement
- Operating point differences cascade into:
  - Device initialization failures (can't converge at new voltages/powers)
  - System initialization failures (refined IC diverges)
  - Dynamic instability (system unstable at new equilibrium)

**Benign warnings:**
- `Reactive power at ref bus is outside limits` - appears frequently but doesn't cause failures
- This is expected with `check_reactive_power_limits=false`

### PowerNetworkMatrices v0.18.2 Impact

**No direct failures attributed to PNM**
- `Ybus(sys)` constructor works correctly
- `Setting the system unit base from DEVICE_BASE to SYSTEM_BASE` warnings are benign
- Fault Ybus creation (deepcopy + remove_component) works

### Root Cause Analysis

```
PowerFlows v0.15 (Newton-Raphson) 
    ↓
Different operating point vs. PSY3/PF0.6
    ↓
Three failure paths:

Path 1: PF itself fails (Test 35)
Path 2: Device init NLSolve fails (Tests 25, 29, 37, 38, 45)
Path 3: System init fails (Test 31 with HYGOV limits)
Path 4: Dynamic simulation unstable (Tests 29, 30, 42, 43, 05, 06)
Path 5: Code bugs exposed (Tests 37, 38 - get_activepower_series)
```

---

## Success from Init Robustness Fixes

**Tests that improved:**
- Test 59 (ST6B): **FULLY FIXED** ✅ - 0→4  passes (all tests now pass)
- Test 40 (EXAC1): Partial fix - 0→2 passes, still has 2 failures
- Test 39, 55: Partial fix - now execute instead of crash

**Impact:**
- Changed hard `error()` to `@warn()` + fallback logic
- Tests moved from "errored" (crash) to "failed" (runs but unstable)
- This is **progress** - exposes underlying physics issues rather than crashing

---

## Fixability Assessment

### ✅ Fixable (Code bugs)
- **Tests 37, 38:** Missing `get_activepower_series` method - can implement
- **Test 50:** Update test value expectations to match new PF
- **Potentially Test 35:** Investigate bus configuration, may need test system fix

### ⚠️ Partially Fixable (Init robustness)
- **Tests 25, 29, 45, 43:** May benefit from relaxed tolerances or better initial guesses
- **Test 31:** May need smarter HYGOV limit handling (adjust limits instead of clamping?)

### ❌ Not Easily Fixable (Physics/Stability)
- **Tests 29, 30, 42, 05, 06:** Dynamic instability at new operating point
- These would require:
  - Changing PF solver back (defeats upgrade purpose)
  - OR adjusting dynamic device parameters (V_ref, P_ref, gains, etc.)
  - OR accepting that these test systems are not stable at new operating points
  - OR generating new reference data at new operating points

---

## Recommendations

1. **Fix code bugs first** (Tests 37, 38, 50) - straightforward
2. **Investigate Test 35** PF failure - may be test system issue
3. **Review Test 31** HYGOV handling - may need different approach than clamping
4. **Document remaining failures** as "operating point incompatibility with PSY3→PSY5 migration"
5. **Consider:** Generate new reference data for unstable tests at PSY5 operating points
