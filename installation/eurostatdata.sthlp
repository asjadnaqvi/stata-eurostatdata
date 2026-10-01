{smcl}
{* 01Oct2026}{...}
{hi:help eurostatdata}{...}
{right:{browse "https://github.com/asjadnaqvi/stata-eurostatdata":eurostatdata v1.0 (GitHub)}}

{hline}

{title:eurostatdata}: A Stata package for importing Eurostat data using the SDMX 3.0 API.

{p 4 4 2}
Data are filtered by Eurostat before download, so only the requested slice is transferred. Values are numeric,
flags are split out, dimensions are labelled from a local codelist cache, and {opt long} output has Stata-formatted time.


{marker syntax}{title:Syntax}

{p 8 15 2}
{cmd:eurostatdata} {it:code}, 
		{cmd:[} {cmd:geo}({it:codes}) {cmd:start}({it:period}) {cmd:end}({it:period}) {cmd:filter}({it:dim}={it:codes}[; {it:dim}={it:codes} ...]) 
		  {cmd:long} {cmd:fast} {cmd:noflags} {cmd:nolabel} {cmd:valuelabels} {cmd:stub}({it:name}) {cmd:save} {cmd:clear}
		  {cmd:compress} {cmd:noerase} {cmd:refreshmeta} {cmd:]}

{p 8 15 2}
{cmd:eurostatdata meta}, 
		{cmd:[} {cmd:list} {cmd:check} {cmd:update} {cmd:force} {cmd:codes}({it:codelists}) {cmd:all} {cmd:purge} {cmd:]}

{p 4 4 2}
{it:code} is the Eurostat dataset code, e.g. {cmd:nama_10_gdp}. Capitalisation does not matter.
Browse codes in the {browse "https://ec.europa.eu/eurostat/data/database":Eurostat database}.


{marker options}{title:Options}

{synoptset 24 tabbed}{...}

{marker selection}{dlgtab:Selection (applied by Eurostat before download)}

{p2coldent : {opt geo(codes)}}Geographic codes to keep, separated by spaces or commas, e.g. {opt geo(EU27_2020 AT DE)}.{p_end}

{p2coldent : {opt start(period)}}First period. Accepted forms: {it:2020}, {it:2020Q1}/{it:2020-Q1}, {it:2020S1}/{it:2020H1}, {it:2020W5},
{it:2020M1}/{it:2020M01}/{it:2020-01}, {it:2020-01-15}. A year also works for sub-annual data, e.g. {opt start(2020)} keeps 2020Q1 onwards.{p_end}

{p2coldent : {opt end(period)}}Last period. Same forms as {opt start()}. Either or both can be specified.{p_end}

{p2coldent : {opt filt:er(spec)}}Codes to keep within named dimensions. Separate dimensions with {bf:;} and codes with spaces, 
e.g. {opt filter(unit=CP_MEUR; na_item=B1GQ B1G; s_adj=NSA)}. Dimension names are the variable names returned by {cmd:eurostatdata}
(e.g. {it:freq unit na_item geo}). {bf:geo=} can also be given here.{p_end}

{p 4 4 2}
If Eurostat returns no data (unknown dimension or code, or a period range without data), the command stops with an error and shows the request URL.

{marker output}{dlgtab:Output}

{p2coldent : {opt long}}One row per dimension combination and period, with a numeric {bf:time} variable formatted
{it:%tq}, {it:%tm}, {it:%th}, {it:%tw} or {it:%td} as appropriate (annual data: year). Default is wide, one column per period, 
named {it:code}{it:period}, e.g. {it:nama_10_gdp2020}, {it:namq_10_gdp2020q1}, {it:une_rt_m2022m1}.{p_end}

{p2coldent : {opt fast}}Use {stata help greshape:greshape} from {bf:gtools} instead of {stata help reshape:reshape} for {opt long}.
The command checks that {bf:greshape} is installed. Recommended for large tables.{p_end}

{p2coldent : {opt noflags}}Drop the Eurostat observation flags (e.g. {it:p} provisional, {it:e} estimated, {it:c} confidential).
By default, flags are stored in {it:flags_varname}.{p_end}

{p2coldent : {opt nolabel}}Do not create the {it:dim_label} variables. Variable labels of the dimensions are still set.{p_end}

{p2coldent : {opt val:uelabels}}Store {it:dim_label} as numeric variables with value labels instead of strings. Makes large {opt long} datasets considerably smaller.{p_end}

{p2coldent : {opt stub(name)}}Rename value variables from {it:code} to {it:name}. Flag variables are renamed accordingly.{p_end}

{p2coldent : {opt save}}Save the result as {it:code}.dta in the working directory (replaces an existing file). Default is not to save.{p_end}

{p2coldent : {opt clear}}Replace the data in memory.{p_end}

{marker download}{dlgtab:Download}

{p2coldent : {opt compress}}Download the gzip-compressed file (about 3-4 times smaller) and decompress it locally, using PowerShell on Windows 
or {it:gunzip} on macOS/Linux. No external tools are needed. Useful on slow connections. Falls back to the uncompressed download if decompression fails.{p_end}

{p2coldent : {opt noerase}}Keep the raw download as {it:CODE}.tsv (plus {it:CODE}.tsv.info) in the working directory. A later run with {opt noerase} reuses it
if the request is identical and Eurostat's last update has not changed. By default, the raw file is a temporary file.{p_end}

{p2coldent : {opt refreshmeta}}Refresh the dataset inventory and compare the cached codelists used by this dataset with the latest Eurostat versions,
downloading any that changed.{p_end}

{marker meta}{dlgtab:Meta cache: eurostatdata meta}

{p 4 4 2}
Eurostat inventories and codelists are cached as {it:_eurostat_meta_*.dta} in {it:c(sysdir_plus)_/}.
Codelists are downloaded only when missing. The dataset inventory (used to validate the code and show the last update) is refreshed at most once a day.

{p2coldent : {opt list}}List the cache folder and the cached codelists with their versions. This is the default.{p_end}

{p2coldent : {opt check}}Compare the cached codelists with the latest Eurostat versions and report the outdated ones.{p_end}

{p2coldent : {opt update}}Download missing or outdated codelists and refresh both inventories.{p_end}

{p2coldent : {opt force}}Together with {opt update}, download all codelists again regardless of version.{p_end}

{p2coldent : {opt codes(codelists)}}Restrict {opt check} or {opt update} to specific codelists, e.g. {opt codes(GEO UNIT)}.{p_end}

{p2coldent : {opt all}}Together with {opt update}, download every Eurostat codelist (for offline use).{p_end}

{p2coldent : {opt purge}}Delete all cached files.{p_end}

{synoptline}
{p2colreset}{...}


{title:Stored results}

{p 4 4 2}{cmd:eurostatdata} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(N)}}number of observations{p_end}
{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(code)}}dataset code{p_end}
{synopt:{cmd:r(dimensions)}}dimension variables{p_end}
{synopt:{cmd:r(lastupdate)}}Eurostat last data change{p_end}
{synopt:{cmd:r(url)}}SDMX 3.0 request URL{p_end}
{p2colreset}{...}


{title:Dependencies}

None. For the {opt fast} option, {browse "https://gtools.readthedocs.io":gtools} (Caceres Bravo 2018) is required:

{stata ssc install gtools, replace}


{title:Examples}

Whole table, wide:

{stata eurostatdata nama_10_gdp, clear}

Only what is needed (typically downloaded in under a second):

{stata eurostatdata nama_10_gdp, clear geo(AT DE FR) start(2015) end(2020) filter(unit=CP_MEUR; na_item=B1GQ)}

Quarterly data in long format with %tq time:

{stata eurostatdata namq_10_gdp, clear long geo(AT) start(2020Q1) filter(unit=CP_MEUR; s_adj=NSA; na_item=B1GQ)}

Monthly unemployment rate:

{stata eurostatdata une_rt_m, clear long noflags geo(AT DE) start(2022M1) filter(unit=PC_ACT; s_adj=SA; sex=T; age=TOTAL)}

Large table in long format, fast and compact:

{stata eurostatdata nama_10_gdp, clear long fast valuelabels}

Maintain the label cache:

{stata eurostatdata meta, check}
{stata eurostatdata meta, update}

See {browse "https://github.com/asjadnaqvi/stata-eurostatdata":GitHub} for more examples.


{hline}

{title:Package details}

Version      : {bf:eurostatdata} v1.0
This release : 01 Oct 2026
First release: 01 Oct 2026
Repository   : {browse "https://github.com/asjadnaqvi/stata-eurostatdata":GitHub}
Keywords     : Stata, Eurostat, SDMX, data import
License      : {browse "https://opensource.org/licenses/MIT":MIT}

Author       : {browse "https://github.com/asjadnaqvi":Asjad Naqvi}
E-mail       : asjadnaqvi@gmail.com
Twitter/X    : {browse "https://twitter.com/AsjadNaqvi":@AsjadNaqvi}


{title:Feedback}

Please submit bugs, errors, feature requests on {browse "https://github.com/asjadnaqvi/stata-eurostatdata/issues":GitHub} by opening a new issue.


{title:Citation guidelines}

Please cite the {browse "https://github.com/asjadnaqvi/stata-eurostatdata":GitHub} repository. An official SSC citation will be added once the package is on SSC.


{title:References}

{p 4 8 2}Caceres Bravo, M. (2018). {browse "https://github.com/mcaceresb/stata-gtools":gtools: Faster Stata for big data}. GitHub repository.

{p 4 8 2}Eurostat (2026). {browse "https://wikis.ec.europa.eu/display/EUROSTATHELP/API+SDMX+3.0":API - SDMX 3.0}. Eurostat online help.

{p 4 8 2}Fontenay, S. (2016). {browse "https://ideas.repec.org/c/boc/bocode/s458231.html":SDMXUSE: Stata module to import data from statistical agencies using the SDMX standard}. Statistical Software Components S458231, Boston College Department of Economics.

{p 4 8 2}Fontenay, S., Vandekerckhove, S. (2015). {browse "https://ideas.repec.org/c/boc/bocode/s458088.html":EUROSTATUSE: Stata module to import data from Eurostat repository into Stata}. Statistical Software Components S458088, Boston College Department of Economics.

{p 4 8 2}Naqvi, A. (2020). {browse "https://medium.com/the-stata-guide/automating-eurostat-in-stata-part-1-a047941b2b4f":Automating Eurostat in Stata}. The Stata Guide, Medium.


{title:Other packages}

{psee}
    {helpb arcplot}, {helpb alluvial}, {helpb bimap}, {helpb bumparea}, {helpb bumpline}, {helpb circlebar}, {helpb circlepack}, {helpb clipgeo}, {helpb delaunay}, {helpb eurostatdata}, {helpb graphfunctions},
	{helpb geoboundary}, {helpb geoflow}, {helpb joyplot}, {helpb marimekko}, {helpb polarspike}, {helpb sankey}, {helpb schemepack}, {helpb spider}, {helpb splinefit}, {helpb streamplot}, 
	{helpb sunburst}, {helpb ternary}, {helpb tidytuesday}, {helpb treecluster}, {helpb treemap}, {helpb trimap}, {helpb waffle}

Visit {browse "https://github.com/asjadnaqvi":GitHub} for further information.
