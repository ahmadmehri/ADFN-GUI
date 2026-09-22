# Example joint planes

Mapped **3D joint planes in a band**, for trying the 3D route of **import**, **fit** and
**conditioning** without real field data. The 2D route (traces on a face) has its own
examples in `..\trace_maps`.

## Set this up first

The coordinates are **local**: axes parallel to the domain's, origin at the **centre of the
band**, which is where the section plane sits. So the model must be set up to match:

| Model tab | value |
|---|---|
| Domain | X `0 – 10`, Y `0 – 10`, Z `0 – 8` |
| Section plane | Dip `90`, DipDir `0`, Offset `0` |

| Conditioning tab | value |
|---|---|
| Band thickness | `2` |

That puts the band centre at `(5, 5, 4)` and the band itself at `x = 4 … 6`, the full
height and width of the domain. Then **Import file…** — the app reads the layout from the
file and sets Source to *3D: imported joint planes*. **Show planes** draws the band and
the planes in the viewport.

## The layouts

All three describe the same thing: where a plane is, which way it faces, how big it is.
`size` is the plane's **diameter**; `radius` is half of it. Angles in degrees, dip
direction anticlockwise from +X as everywhere in the app.

```
xc yc zc dip dipdir size [set]      6 columns, or a header naming them
xc yc zc nx ny nz radius [set]      7 columns, or a header naming them
x y z                               polygon corners: one polygon per block,
                                    blocks separated by a blank line
.mat                                a cell array of n-by-3 corner lists, plus an
                                    optional vector named set / sid / setid
```

Without a header, the column count decides (6 = dip/dipdir, 7 = normal/radius); a
`set` column then needs a header. With a header the names decide, so the order does not
matter and extra columns are ignored.

## The files

| file | planes | what it is for |
|---|---|---|
| `01_five_planes_dip_dipdir.csv` | 5 | a vertical plane and four inclined ones, obvious enough to check by eye |
| `01_five_planes_normal_radius.csv` | 5 | the same five, as normals and radii |
| `01_five_planes_polygons.txt` | 5 | the same five, as octagon corners |
| `02_from_known_model.csv` | 160 | drawn from the two-set model below, with set ids |
| `02_from_known_model.mat` | 160 | the same planes as polygons |

## The truth behind `02`

`02` was drawn from this table, with the planes' **centres uniform inside the band**
(seed 2024):

| set | N in band | Dip | dDip | DipDir | dDDir | Lmin | Lmean | Lmax |
|---|---|---|---|---|---|---|---|---|
| 1 | 90 | 70 | −30 | 120 | −30 | 0.5 | 1.2 | 3.0 |
| 2 | 70 | 20 | −20 | 300 | −20 | 0.6 | 1.8 | 4.0 |

The dips are drawn exactly as ADFNE's `DFN` draws them, which means `dDip = −30` is a
*tight* spread (about ±2.6°) while `dDDir = −30` is about ±10° — see the note on the
joint-set table in the main README. So after import, **FIT DFN TO PLANES** from any
two-row starting table should return the dips within a degree, the dip directions within
a couple of degrees, and the kappas within about a third — a 3D plane carries its
orientation, so unlike the 2D fit this one recovers it.
`N` comes back as the count for the *whole domain* that gives the band its P32 (about
four times the in-band count for this geometry, less edge effects). `Lmean` is the
weakest number: it is the exponential's mean *before* truncation, and when the range is
tight the truncated mean barely moves with it, so a small sampling error in the mean size
becomes a larger one in `Lmean`.

Then **Compare 3D Joint Planes** — mapped against the model in the same band, with the
stereonet showing both sets of poles.

## Regenerating

`tests\make_examples.m` is not shipped; the files were written by the app's own
`synthPlanesInBand` and are checked by `tests\run_all.m` (import, fit recovery, and
conditioning that reproduces every plane exactly).
