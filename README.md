# PAM3 and direct power control

Research archive from the initial PAM3 detector simulation through the final DPC comparison. The MATLAB source, native Simulink `.slx` models, FPGA files, validation fixtures, figures and archived results are in this repository.

`main` contains the entire archive. Each branch under `archive/` marks the commit that added one recovered package. These are reconstructed snapshots, not original development history. Package files remain in their original layout under `versions/` so scripts can resolve relative paths.

| Package | Files | Snapshot branch |
| --- | ---: | --- |
| [Initial Python and RTL patent simulation](versions/pam3/patent-simulation/) | 146 | `archive/pam3-patent-simulation` |
| [FPGA RTL, synthesis and verification](versions/pam3/fpga/) | 126 | `archive/pam3-fpga` |
| [Original simulation and FPGA handover](versions/pam3/professor-package/) | 103 | `archive/pam3-professor-package` |
| [MATLAB and standalone Simulink detector](versions/pam3/matlab-simulink/) | 59 | `archive/pam3-matlab-simulink` |
| [Early DPC comparison using the same input](versions/dpc/initial-comparison/) | 76 | `archive/dpc-initial-comparison` |
| [Control quality and reference fixtures](versions/dpc/control-quality/) | 47 | `archive/dpc-control-quality` |
| [Nine-state ternary table and validation](versions/dpc/ternary-table/) | 50 | `archive/dpc-ternary-table` |
| [Ternary controller noise study](versions/dpc/ternary-noise/) | 75 | `archive/dpc-ternary-noise` |
| [Standalone hysteresis vs. PAM3 in MATLAB](versions/comparison/matlab/) | 36 | `archive/comparison-matlab` |
| [Standalone hysteresis vs. PAM3 in Simulink](versions/comparison/simulink/) | 53 | `archive/comparison-simulink` |
| [Mapping onto the professor’s Simulink model](versions/dpc/professor-mapping/) | 21 | `archive/dpc-professor-mapping` |
| [Improved controller and Stage 2 experiments](versions/dpc/stage-2/) | 73 | `archive/dpc-stage-2` |
| [Stage 3 and Stage 4, including binary rematch](versions/dpc/stage-3-4/) | 113 | `archive/dpc-stage-3-4` |
| [Separate ternary detector reproducibility study](versions/research/ternary-stage-4/) | 12 | `archive/research-ternary-stage-4` |
| [Separate ternary detector Stage 8 study](versions/research/ternary-stage-8/) | 15 | `archive/research-ternary-stage-8` |

## Run the Simulink experiments

1. Use MATLAB with Simulink (the development environment was MATLAB R2024b). For Windows, clone into a short path such as `C:\dpc` to avoid Simulink-generated paths exceeding Windows limits.
2. Open the package's own README first. Start MATLAB from the corresponding package folder. Avoid adding every historical version to the MATLAB path at once; several stages use identical function names.
3. In [the latest package](versions/dpc/stage-3-4/DPC_PAM3_Stage3/), read [README_FA.md](versions/dpc/stage-3-4/DPC_PAM3_Stage3/README_FA.md) and the package's logging, final-point and binary-comparison notes. The recovered entry points include `RUN_RESEARCH_STAGE4`, `RUN_FINAL_DPC_POINT`, `RUN_BINARY_DPC_POINTS` and `RUN_BINARY_DPC_REMATCH`.
4. To reproduce an older stage, follow that version's README from its own folder. For the professor's original models, see [reference-models](reference-models/).

## Results and provenance

- [Stage 3](results/stage-3/) and [Stage 4](results/stage-4/) hold the original result exports. The two-level initial and rematched runs are separate. Use `SwitchingComparable` before treating a run as matched.
- [Reports](reports/) contains the Persian comparison report and earlier project deliverables.
- [Archive manifest](ARCHIVE_MANIFEST.tsv) records the name and SHA-256 of each recovered source ZIP and the matching branch.
- The two copies of `PAM3_MATLAB_Simulink.zip` recovered under different filenames have identical SHA-256; they are represented once. Only package snapshots recoverable as files are represented. The Simulink models were checked for archive integrity here; the simulations were not rerun during the migration.
