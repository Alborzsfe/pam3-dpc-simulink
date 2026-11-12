# Primary references and provenance

- Supplied source SLX, preserved byte-for-byte:
  SHA256 c637ed60cde46882b00b42aefcaf2d51796233b7814fdf6bbf72d947dcafd9a9.
  chart_29.xml contains the original four binary switching rows.
  chart_40.xml contains the original sector law.
  system_49.xml contains the actual P/Q sign and normalization.
- Norniella et al., Multiple switching tables direct power control of active
  front-end rectifiers, IET Power Electronics, 2014.
  https://doi.org/10.1049/iet-pel.2013.0492
  Supports physical DPC table design from power derivatives, dependence on
  operating conditions and multirate plant/control simulation. This package is
  NOT represented as a reproduction of that paper's full algorithm.
- MathWorks Relay: hysteresis block and sample-time parameter. Exact equality
  semantics for the binary fixture are grounded in the user's R2024b capture
  (see REVISION_2.md), rather than inferred from prose such as "exceeds".
  https://www.mathworks.com/help/simulink/slref/relay.html
- MathWorks From Workspace: two-column array input, zero-order-hold setting
  and final-value hold.
  https://www.mathworks.com/help/simulink/slref/fromworkspace.html
- MathWorks To Workspace: logging and structure-with-time layout.
  https://www.mathworks.com/help/simulink/slref/toworkspace.html
- MathWorks Stateflow.EMChart: script access for the common boundary fix.
  https://www.mathworks.com/help/stateflow/api/stateflow.emchart.html
- MathWorks harmonic RMS THD definition.
  https://www.mathworks.com/help/simscape-electrical/ref/totalharmonicdistortion.html

The new zero-state selection rule is derived explicitly in CONTROL_LAW.md.
Reference citations establish concepts/APIs; they do not certify execution or
performance of this implementation. Native execution is required in MATLAB.
