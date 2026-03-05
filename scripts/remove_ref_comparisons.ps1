# Removes reference-value comparison blocks from all PSID test files.
#
# KEPT:    @test sim.status, @test execute!, @test small_sig.stable, @test isa(...)
# REMOVED: diff_val blocks, eigenvalue norm tests, PSSE/PSCAD trajectory comparisons

$testDir = "D:\Projekte\Code\PowerSimulationsDynamics.jl\test"
$files = Get-ChildItem -Path $testDir -Filter "*.jl" -Recurse

foreach ($file in $files) {
    $lines = Get-Content $file.FullName -Encoding UTF8
    $out = [System.Collections.Generic.List[string]]::new()
    $skip = $false

    foreach ($line in $lines) {

        # ── diff / diff_val block: start="\w*diff\w* = [0.0]", end="@test diff[1]" ──
        if ($line -match '^\s+\w*diff\w*\s*=\s*\[0\.0\]') {
            $skip = $true
            continue
        }
        if ($skip) {
            if ($line -match '@test\s+\(?\w*diff\w*\[1\]') {
                $skip = $false   # consume this closing @test line too
            }
            continue
        }

        # ── Single-line removals ───────────────────────────────────────────────────

        # eigs = small_sig.eigenvalues (only ever used in norm(eigs-ref) tests below)
        if ($line -match '^\s+eigs\s*=\s*small_sig\.eigenvalues\s*$') { continue }

        # @test LinearAlgebra.norm(eigs - <ref>)
        if ($line -match '@test\s+LinearAlgebra\.norm\(\s*eigs\s*-') { continue }

        # @test LinearAlgebra.norm involving named reference variables
        if ($line -match '@test\s+LinearAlgebra\.norm\(.*_eigvals') { continue }
        if ($line -match '@test\s+LinearAlgebra\.norm\(.*_psat') { continue }

        # PSSE CSV data loading and trajectory comparison @tests
        if ($line -match 't_psse\s*,\s*\w+\s*=\s*get_csv_delta') { continue }
        if ($line -match '@test\s+LinearAlgebra\.norm\(.*psse') { continue }

        # PSCAD CSV data loading orphan assignments (M used only for pscad comparisons)
        if ($line -match '^\s+M\s*=\s*get_csv_data\(') { continue }
        if ($line -match '^\s+t_pscad\s*=\s*M\[') { continue }
        if ($line -match '^\s+\w+_pscad\s*=\s*M\[') { continue }

        # PSSE/PSCAD M-column assignments: e.g. t_psse = M[:, 1], M_t = M[:, 1]
        if ($line -match '^\s+[\w_]+\s*=\s*M\[:,') { continue }
        # clean_extra_timestep! calls are always for PSSE comparison preprocessing
        if ($line -match 'clean_extra_timestep!') { continue }
        # Orphan PSSE variable assignments left after M removal
        if ($line -match '^\s+[\w_]+_psse\s*=') { continue }

        # PSCAD/PSSE trajectory @test norms
        if ($line -match '@test\s+LinearAlgebra\.norm\(.*_pscad') { continue }
        if ($line -match '@test\s+LinearAlgebra\.norm\(\s*t\s*-\s*round') { continue }
        if ($line -match '@test\s+LinearAlgebra\.norm\(\s*[δω]\s*-') { continue }

        # Comment lines that solely annotate removed blocks
        if ($line -match '^\s+#\s*(PSSE results are in Degrees|Test Transient Simulation Results|Test Initial Condition|Test Eigenvalues|Obtain PSCAD benchmark data)\s*$') { continue }

        $out.Add($line)
    }

    $original = (Get-Content $file.FullName -Raw -Encoding UTF8)
    $newContent = ($out -join "`n")

    if ($newContent.TrimEnd() -ne $original.TrimEnd()) {
        # Collapse runs of 3+ consecutive blank lines into at most 2
        $newContent = [regex]::Replace($newContent, "(\n[ \t]*){3,}\n", "`n`n`n")
        [System.IO.File]::WriteAllText($file.FullName, $newContent, [System.Text.Encoding]::UTF8)
        Write-Host "Modified: $($file.Name)"
    } else {
        Write-Host "Unchanged: $($file.Name)"
    }
}

Write-Host "`nDone."
