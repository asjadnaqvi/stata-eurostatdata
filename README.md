
[Installation](#Installation) | [Syntax](#Syntax) | [Examples](#Examples) | [Citation-guidelines](#Citation-guidelines) | [Feedback](#Feedback) | [Change-log](#Change-log)


<img width="100%" alt="eurostatdata_banner" src="https://github.com/user-attachments/assets/da3f1ab7-6e93-4012-a24d-5016ce13cafb" />


---

# eurostatdata v1.0
*(01 Oct 2026)*

`eurostatdata` imports data from [Eurostat](https://ec.europa.eu/eurostat/data/database) using the SDMX 3.0 API. It sends supported dimension and time filters to Eurostat before downloading, so only the requested slice is transferred. Results can be returned in wide or long format, with observation flags and dimension labels.

The command requires an internet connection to access the Eurostat API. Codelists are cached locally after their first download.

## Installation

Install the latest version from SSC:

```
coming soon
```


or GitHub (v1.0):

```stata
net install eurostatdata, from("https://raw.githubusercontent.com/asjadnaqvi/stata-eurostatdata/main/installation/") replace
```

Requires Stata 15 or later. The `fast` option uses [`greshape`](https://github.com/mcaceresb/stata-gtools) from `gtools`; all other options use Stata commands only.


## Syntax

```stata
eurostatdata code [, geo(codes) start(period) end(period) filter(spec) ///
    long fast noflags nolabel valuelabels stub(name) save clear ///
    compress noerase refreshmeta]

eurostatdata meta [, list check update force codes(codelists) all purge]
```

See `help eurostatdata` in Stata for the complete set of options. The `filter()` option takes dimension/code pairs separated by semicolons; separate multiple codes with spaces or commas.

## Examples

Download a complete dataset in wide format:

```stata
eurostatdata nama_10_gdp, clear
```

Select geographies, periods, and dimension codes before download:

```stata
eurostatdata nama_10_gdp, clear geo(AT DE FR) start(2015) end(2020) ///
    filter(unit=CP_MEUR; na_item=B1GQ)
```

Import quarterly data in long format with a Stata quarterly time variable:

```stata
eurostatdata namq_10_gdp, clear long geo(AT) start(2020Q1) ///
    filter(unit=CP_MEUR; s_adj=NSA; na_item=B1GQ)
```

Import monthly unemployment data:

```stata
eurostatdata une_rt_m, clear long noflags geo(AT DE) start(2022M1) ///
    filter(unit=PC_ACT; s_adj=SA; sex=T; age=TOTAL)
```

Check or update the local metadata cache:

```stata
eurostatdata meta, check
eurostatdata meta, update
```

## Performance

An end-to-end benchmark of `nama_10_gdp` was run in Stata 17 SE on Windows on 1 Oct 2026. Each command was warmed up, then timed over three runs. Timings include the Eurostat response, download, and package processing. Each successful run returned 35,866 observations and 55 variables.

| Command | Successful runs | Median (seconds) | Range (seconds) | Relative to `eurostatdata` |
| --- | ---: | ---: | ---: | ---: |
| `eurostatdata` | 3 | 3.638 | 3.343-3.701 | 1.00x |
| `eurostatuse` | 3 | 211.397 | 208.298-213.316 | 58.11x |


### Doing your own benchmark runs

If you want to do your own benchmarks, then install all the packages that claim to connect with Eurostat:

```stata
ssc install eurostatdata, replace    // when available, otherwise install from GitHub
ssc install eurostatuse, replace
*ssc install eurouse, replace   // stale
*ssc install getdata, replace  // stale
*ssc install sdmxuse, replace  // stale
*ssc install xteurostat, replace // stale
```

Note that some of the packages are no longer working given the changes in Eurostat protocols. Run the benchmark on two packages:


```stata
timer clear

timer on 1
eurostatdata nama_10_gdp, clear noflags nolabel
timer off 1

timer on 2
eurostatuse nama_10_gdp, clear uncompressed noflags nolabel
timer off 2

timer list
```




## Citation guidelines

If you use this package, please cite the [eurostatdata GitHub repository](https://github.com/asjadnaqvi/eurostatdata). An SSC citation will be added if the package is published on SSC.

## Feedback

Please report bugs, errors, or feature requests by opening an [issue](https://github.com/asjadnaqvi/eurostatdata/issues).

## Change log

**v1.0 (01 Oct 2026)**
- Initial release.
