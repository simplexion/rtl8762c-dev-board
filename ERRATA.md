# Errata
Known bugs, workarounds and fixes

## RTL8762CKF Dev Board

### v0.1.0

| # | Category | Bug | Workaround | Fix | Fixed in |
|---|---|---|---|---|---|
| 1 | BOM | R5, R8, R11 are 1Ω instead of 10kΩ | replace with correct parts | set correct PNs in schematic | 0f1d93d |
| 2 | schematic | ZVD is connected in reverse | desolder Q3 | connect the ZVD the right way | f5408a7 |
| 3 | BOM | switching regulator inductor is 2.2uF capacitor instead of 2.2uH inductor | replace with correct part | set correct PN in schematic | bf8396c |
