# Validation status

Preparation environment: Octave 8.4.0, Python/SciPy. No MATLAB/Simulink runtime.

Revision 2 corrects the native binary Relay oracle's equality semantics using
the user's R2024b failure capture. The exact four reported differences are
reproduced by strict-vs-inclusive oracle comparison. Python boundary/adjacent
float regressions and MATLAB numerical binary-history checks are included.
This is not a report that revision 2 native preflight or converter runs passed.

Actually completed:

- 696 independent table contexts, covering all nine state pairs, all 12
  sectors, both 20/200-kHz controller rates, multiple P/Q operating points,
  and zero-resistance edge cases.
- All 48 original binary table entries matched values independently parsed
  from the original SLX script, not another copied MATLAB array.
- Exact RL/rotating-source prediction matched an independent real ABC
  Gauss-Legendre integration oracle. Maximum absolute discrepancy:
  7.958078640513122e-13 W/var.
- 246 tested zero-containing contexts selected gates different from the
  original binary path. Zero handling did not silently collapse to bit hold.
- 862 streaming fixture samples matched independent classifier/table gates.
- All tested binary-limit gates matched the independent original source table.
- Initial constant +3/-3 errors immediately generated +1/-1 states.
- Known THD=50% and known ripple values passed.
- Clock-roundoff alignment and causal intersample holding passed.
- 1724 callback sample steps with a TEST DOUBLE block object matched the same
  independent fixtures. Repeated Outputs calls were pure; Update committed
  the correct state; sample periods and output widths were checked.
- Static MATLAB syntax lint and package/source integrity checks.

NOT executed here:

- Native Simulink block creation/compilation and the six-case native preflight.
- The six full converter runs (baseline, binary limit and ternary at each rate).
- The bit-exact FULL-PLANT binary-limit check in actual Simulink.
- Native MATLAB figure rendering, powergui GUI cross-check, plant-step
  convergence, hardware or real-time execution.

Saved numerical/callback reports explicitly have simulink_executed=false.
The native reports are created only by successful actual MATLAB runs. No
converter performance numbers or professor figures are prefilled in this ZIP.
The test-double callback test is not a replacement for native preflight.
