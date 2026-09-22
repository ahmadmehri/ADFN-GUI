# Third-party code and licenses

This GUI is a front end for **ADFNE** (Alghalandis Discrete Fracture Network
Engineering) by Dr. Younes Fadakar Alghalandis. It does not modify ADFNE, adds it to
the MATLAB path read-only, and vendors a merged copy of it so the app is self-contained
(see the main [README](README.md) for why two ADFNE releases are merged). ADFNE's own
license governs everything under `lib/adfne/`, unchanged by anything in this
repository.

## ADFNE 1.0 and 1.5

Copyright (c) Dr. Younes Fadakar Alghalandis, Alghalandis Computing
(<http://alghalandis.net>). Both releases are BSD-style: redistribution and use in
source and binary form are permitted with attribution, the author's name may not be
used to endorse derived products without permission, and **at least one of the two
papers below must be cited** by anyone using ADFNE (directly or through this GUI):

- Fadakar-A Y. (2017) *ADFNE: Open source software for discrete fracture network
  engineering, two and three dimensional applications*. Computers & Geosciences
  102:1-11.
- Fadakar-A Y. (2018) *DFNE Practices with ADFNE*. Alghalandis Computing, Toronto,
  Ontario, Canada, 61 pp.

Full license text: [docs/ADFNE1.0_License.txt](docs/ADFNE1.0_License.txt) and
[docs/ADFNE1.5_License.txt](docs/ADFNE1.5_License.txt).

Every vendored file under `lib/adfne/` keeps its original license header. The ADFNE 1.5
files there are byte-identical to the author's distribution; the ADFNE 1.0 files are
untouched except for twelve renamed to avoid a name collision with 1.5 — no logic was
changed.

## Dependency shims (`lib/deps/`)

ADFNE 1.0 calls into third-party toolboxes (geom2d/geom3d — MatGeom — and CircStat)
that are not bundled with it, and a few of its own functions are missing from the
public distribution. `lib/deps/` supplies a vetted replacement layer so the library
runs standalone. Their licenses (MatGeom: BSD; CircStat: BSD-like) are reproduced in
[docs/Ext_Licenses.pdf](docs/Ext_Licenses.pdf). A few files in this folder are original
reconstructions written for this project from published algorithm descriptions; those
follow this repository's own license, since they are not copies of any third-party
source.

## The GUI itself

Everything else — `ADFNE_GUI.m` and this documentation — is original work licensed
under the terms in [LICENSE](LICENSE).
