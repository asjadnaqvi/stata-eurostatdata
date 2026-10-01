*! eurostatdata v1.0 (01 Oct 2026)
*! Asjad Naqvi (asjadnaqvi@gmail.com)

program define eurostatdata, rclass
version 15

gettoken sub : 0, parse(" ,")
if lower(`"`sub'"') == "meta" {
	gettoken sub 0 : 0, parse(" ,")
	_eurostatdata_meta `0'
	exit
	}
_eurostatdata_get `0'
return add
end


* ===========================================================================
* eurostatdata <code>: download and process a dataset (SDMX 3.0)
* ===========================================================================

program define _eurostatdata_get, rclass
version 15
syntax name(name=indicator) [, long noflags nolabel VALuelabels GEO(string) START(string) END(string) ///
	FILTer(string) compress fast stub(name) save noerase refreshmeta clear]

if "`fast'" != "" {
	capture which greshape
	if _rc {
		display as error "option {bf:fast} requires {bf:greshape} from gtools: {stata ssc install gtools}"
		exit 199
		}
	}

if "`clear'" != "" clear
else if c(changed) error 4

local indicator = lower("`indicator'")
local upind = upper("`indicator'")


* Server-side filters
* ===================

local geo = upper(subinstr(`"`geo'"', ",", " ", .))
local q
local rest `"`filter'"'
while `"`rest'"' != "" {
	gettoken piece rest : rest, parse(";")
	if `"`piece'"' == ";" continue
	local eq = strpos(`"`piece'"', "=")
	if `eq' == 0 {
		display as error "filter() expects dimension=codes, e.g. filter(unit=CP_MEUR; na_item=B1GQ B1G)"
		exit 198
		}
	local d = lower(strtrim(substr(`"`piece'"', 1, `eq' - 1)))
	local v = upper(subinstr(substr(`"`piece'"', `eq' + 1, .), ",", " ", .))
	if "`d'" == "geo" {
		local geo `geo' `v'
		continue
		}
	local v : list uniq v
	local q `q'&c[`d']=`=subinstr("`v'", " ", ",", .)'
	}
local geo : list uniq geo
if "`geo'" != "" local q `q'&c[geo]=`=subinstr("`geo'", " ", ",", .)'

local tp
if `"`start'"' != "" {
	_es_period `start'
	local tp "ge:`r(period)'"
	}
if `"`end'"' != "" {
	_es_period `end'
	local tp = cond("`tp'" == "", "le:`r(period)'", "`tp'+le:`r(period)'")
	}
if "`tp'" != "" local q `q'&c[TIME_PERIOD]=`tp'

local qurl "https://ec.europa.eu/eurostat/api/dissemination/sdmx/3.0/data/dataflow/ESTAT/`upind'/1.0/*?format=TSV`q'"


quietly {

_es_cachedir
local cdir `"`r(dir)'"'
if "`refreshmeta'" != "" local force force


* Dataset check (inventory cached, refreshed daily)
* ================================================

local lastupdate
_es_inventory data, dir(`"`cdir'"') `force'
if `"`r(file)'"' != "" {
	use code lastdatachange if code == "`upind'" using `"`r(file)'"', clear
	if _N == 0 {
		clear
		noisily display as error "Dataset `indicator' not found. See https://ec.europa.eu/eurostat/data/database"
		exit 601
		}
	local lastupdate = lastdatachange[1]
	clear
	}
noisily display as text "Dataset: " as result "`indicator'" as text "   Last update: " as result "`lastupdate'"


* Download
* ========

if "`erase'" == "noerase" {
	local rawfile `"`c(pwd)'/`upind'.tsv"'
	local infofile `"`c(pwd)'/`upind'.tsv.info"'
	}
else {
	tempfile raw
	local rawfile `"`raw'"'
	}

* Reuse a kept raw file only if the query and Eurostat's last update are unchanged
local reuse = 0
if "`erase'" == "noerase" {
	capture confirm file `"`rawfile'"'
	local rc1 = _rc
	capture confirm file `"`infofile'"'
	if `rc1' == 0 & _rc == 0 {
		tempname fh
		file open `fh' using `"`infofile'"', read text
		file read `fh' oldurl
		file read `fh' oldupd
		file close `fh'
		local reuse = (`"`oldurl'"' == `"`qurl'"') & ("`lastupdate'" == "" | `"`oldupd'"' == "`lastupdate'")
		}
	}

if `reuse' {
	noisily display as text "Using existing raw file `upind'.tsv (unchanged since last download)."
	}
else {
	noisily display as text "Downloading ..."
	local ok = 0
	if "`compress'" != "" {
		tempfile gz
		capture copy "`qurl'&compress=true" `"`gz'"', replace
		if _rc == 0 {
			capture erase `"`rawfile'"'
			_es_gunzip `"`gz'"' `"`rawfile'"'
			capture checksum `"`rawfile'"'
			local ok = (_rc == 0)
			if `ok' local ok = (r(filelen) > 0)
			if !`ok' noisily display as text "Decompression failed; downloading the uncompressed file."
			}
		}
	if !`ok' {
		capture copy "`qurl'&compress=false" `"`rawfile'"', replace
		if _rc {
			noisily display as error "Eurostat returned no data for this request:"
			noisily display as error `"  `qurl'"'
			noisily display as error "Check the dimension names and codes in filter()/geo(), and that start()/end() overlap the data."
			exit 677
			}
		}
	if "`erase'" == "noerase" {
		tempname fh
		file open `fh' using `"`infofile'"', write text replace
		file write `fh' `"`qurl'"' _n `"`lastupdate'"' _n
		file close `fh'
		}
	}


* Import (one pass: commas separate dimensions, tabs separate periods)
* ====================================================================

noisily display as text "Processing ..."
import delimited using `"`rawfile'"', delimiters(",\t") varnames(1) stringcols(_all) clear
if _N == 0 {
	noisily display as error "No observations returned."
	exit 2000
	}

* Dimensions end at the column headed "<dim>\TIME_PERIOD"
local dims
local tcols
local found = 0
foreach v of varlist _all {
	if `found' {
		local tcols `tcols' `v'
		continue
		}
	local lab : variable label `v'
	local p = strpos(`"`lab'"', char(92))
	if `p' {
		local d = strtoname(lower(substr(`"`lab'"', 1, `p' - 1)))
		if "`d'" != "`v'" rename `v' `d'
		local v `d'
		local found = 1
		}
	label variable `v' ""
	local dims `dims' `v'
	}
if !`found' | "`tcols'" == "" {
	noisily display as error "Unexpected file format returned by Eurostat."
	exit 610
	}

* Period columns: <indicator><period>, e.g. nama_10_gdp2020, namq_10_gdp2020q1, une_rt_m2022m1
local tvars
local kinds
foreach v of local tcols {
	local h : variable label `v'
	_es_timekey `h'
	local kinds `kinds' `r(kind)'
	rename `v' `indicator'`r(suffix)'
	label variable `indicator'`r(suffix)' ""
	local tvars `tvars' `indicator'`r(suffix)'
	}
local kinds : list uniq kinds
local kind = cond(wordcount("`kinds'") == 1, "`kinds'", "X")


* Labels (from the meta cache; applied before any reshape so merges stay small)
* ============================================================================

if "`refreshmeta'" != "" local compare compare

preserve
_es_inventory codelist, dir(`"`cdir'"') `force'
local invfile `"`r(file)'"'
foreach var of local dims {
	local upvar = upper("`var'")
	local ver
	if `"`invfile'"' != "" {
		use code version label if code == "`upvar'" using `"`invfile'"', clear
		if _N > 0 {
			local lb`var' = label[1]
			local ver = version[1]
			}
		}
	if "`label'" != "nolabel" {
		_es_codelist `upvar', dir(`"`cdir'"') version(`ver') `compare'
		local cl`var' `"`r(file)'"'
		}
	}
restore

local ivars
tempfile labfile
foreach var of local dims {
	label variable `var' `"`lb`var''"'
	local ivars `ivars' `var'
	if "`label'" == "nolabel" | `"`cl`var''"' == "" continue

	preserve
	use `"`cl`var''"', clear
	rename (code label) (`var' `var'_label)
	save `"`labfile'"', replace
	restore
	merge m:1 `var' using `"`labfile'"', nogenerate keep(master match)
	if "`valuelabels'" != "" {
		tempvar enc
		encode `var'_label, generate(`enc') label(`var')
		drop `var'_label
		rename `enc' `var'_label
		}
	label variable `var'_label `"`lb`var''"'
	local ivars `ivars' `var'_label
	}
order `ivars'


* Values and flags
* ================

if "`long'" == "" {
	foreach v of local tvars {
		tempvar x
		generate double `x' = real(word(`v', 1))
		if "`flags'" != "noflags" {
			generate flags_`v' = strtrim(substr(strtrim(`v'), strpos(strtrim(`v'), " ") + 1, .)) if strpos(strtrim(`v'), " ")
			}
		drop `v'
		rename `x' `v'
		}
	sort `dims'
	}
else {
	* Reshape only id + period columns (numeric j when possible), then attach the
	* dimensions by expanding them row-aligned (avoids a large m:1 merge and order)
	sort `dims'
	tempvar id
	tempfile valfile
	generate long `id' = _n
	local nw = _N
	local nt : word count `tvars'

	preserve
	keep `id' `tvars'
	local rshp = cond("`fast'" != "", "greshape", "reshape")
	local off = 100000		// keeps pre-1960 Stata dates positive in variable names
	if "`kind'" != "X" {
		local L = length("`indicator'")
		foreach v of local tvars {
			local s = substr("`v'", `L' + 1, .)
			if "`kind'" == "A" local k = real("`s'")
			if "`kind'" == "Q" local k = quarterly("`s'", "YQ")
			if "`kind'" == "M" local k = monthly("`s'", "YM")
			if "`kind'" == "S" local k = halfyearly(subinstr("`s'", "s", "h", 1), "YH")
			if "`kind'" == "W" local k = weekly("`s'", "YW")
			if "`kind'" == "D" local k = daily(subinstr(subinstr("`s'", "m", "-", 1), "d", "-", 1), "YMD")
			rename `v' __es`=`k' + `off''
			}
		`rshp' long __es, i(`id') j(time)
		replace time = time - `off'
		if "`kind'" == "Q" format time %tq
		if "`kind'" == "M" format time %tm
		if "`kind'" == "S" format time %th
		if "`kind'" == "W" format time %tw
		if "`kind'" == "D" format time %td
		rename __es `indicator'
		}
	else {
		`rshp' long `indicator', i(`id') j(time) string
		noisily display as text "Mixed time frequencies: time kept as string."
		}
	assert _N == `nw' * `nt'
	sort `id' time

	tempvar x
	generate double `x' = real(word(`indicator', 1))
	if "`flags'" != "noflags" {
		generate flags_`indicator' = strtrim(substr(strtrim(`indicator'), strpos(strtrim(`indicator'), " ") + 1, .)) if strpos(strtrim(`indicator'), " ")
		}
	drop `indicator' `id'
	rename `x' `indicator'
	order time `indicator'
	save `"`valfile'"'
	restore

	keep `id' `ivars'
	expand `nt'
	sort `id'
	drop `id'
	merge 1:1 _n using `"`valfile'"', nogenerate
	sort `dims' time
	}


* Finish
* ======

if "`stub'" != "" {
	rename `indicator'* `stub'*
	capture rename flags_`indicator'* flags_`stub'*
	}

compress

if "`save'" != "" {
	noisily save `indicator'.dta, replace
	}

noisily display as text "Done: " as result %12.0fc _N as text " observations, dimensions: " as result "`dims'"

} // end quietly

return scalar N = _N
return local dimensions "`dims'"
return local lastupdate "`lastupdate'"
return local url `"`qurl'"'
return local code "`indicator'"
end


* ===========================================================================
* eurostatdata meta: manage the meta cache
* ===========================================================================

program define _eurostatdata_meta
version 15
syntax [, LIst CHeck UPdate Force CODEs(string) ALL PURGE]

_es_cachedir
local cdir `"`r(dir)'"'

if "`purge'" != "" {
	local files : dir `"`cdir'"' files "_eurostat_meta_*.dta", respectcase
	local n = 0
	foreach f of local files {
		erase `"`cdir'/`f'"'
		local ++n
		}
	display as text "Removed `n' cached file(s) from " as result `"`cdir'"'
	exit
	}

if "`force'" != "" local update update
if "`check'`update'" == "" local list list
if "`all'" != "" & "`update'" == "" {
	display as error "option all requires update"
	exit 198
	}

preserve

* Inventories
display as text _newline "Eurostat meta cache: " as result `"`cdir'"' _newline
if "`update'" != "" {
	quietly _es_inventory data, dir(`"`cdir'"') force
	}
if "`check'`update'" != "" {
	quietly _es_inventory codelist, dir(`"`cdir'"') force
	}
foreach inv in codelists datasets {
	local f `"`cdir'/_eurostat_meta_`inv'.dta"'
	capture confirm file `"`f'"'
	if _rc {
		display as text %-12s "`inv'" "not cached"
		}
	else {
		quietly use in 1 using `"`f'"', clear
		local d : char _dta[es_date]
		display as text %-12s "`inv'" "inventory downloaded `d'"
		}
	}
local invfile `"`cdir'/_eurostat_meta_codelists.dta"'
capture confirm file `"`invfile'"'
if _rc local invfile

* Codelists to process
local targets
if "`codes'" != "" {
	local targets = upper("`codes'")
	}
else if "`all'" != "" & `"`invfile'"' != "" {
	quietly use code using `"`invfile'"', clear
	quietly levelsof code, local(targets) clean
	}
else {
	local files : dir `"`cdir'"' files "_eurostat_meta_cl_*.dta", respectcase
	foreach f of local files {
		local c = subinstr(subinstr("`f'", "_eurostat_meta_cl_", "", 1), ".dta", "", 1)
		local targets `targets' `=upper("`c'")'
		}
	}

if "`targets'" == "" {
	display as text _newline "No codelists cached."
	exit
	}

display as text _newline %-20s "Codelist" %-10s "Cached" %-10s "Latest" %-14s "Downloaded" "Status"
display as text "{hline 70}"
local nout = 0
local ndl = 0
foreach c of local targets {
	local f `"`cdir'/_eurostat_meta_cl_`c'.dta"'
	local cver
	local cdate
	capture confirm file `"`f'"'
	local have = (_rc == 0)
	if `have' {
		quietly use in 1 using `"`f'"', clear
		local cver : char _dta[es_version]
		local cdate : char _dta[es_date]
		}
	local lver
	if "`check'`update'" != "" & `"`invfile'"' != "" {
		quietly use code version if code == "`c'" using `"`invfile'"', clear
		if _N > 0 local lver = version[1]
		}

	if "`list'" != "" {
		local status = cond(`have', "cached", "not cached")
		}
	else {
		local stale = !`have' | ("`lver'" != "" & "`cver'" != "`lver'")
		if "`update'" != "" & (`stale' | "`force'" != "") {
			quietly _es_codelist `c', dir(`"`cdir'"') version(`lver') force
			local status "`r(status)'"
			if "`status'" == "downloaded" {
				local ++ndl
				local cver `lver'
				local cdate `c(current_date)'
				}
			}
		else if !`have' local status "not cached"
		else if "`lver'" == "" local status "not in inventory"
		else if `stale' {
			local status "outdated"
			local ++nout
			}
		else local status "up to date"
		}
	display as text %-20s "`c'" %-10s "`cver'" %-10s "`lver'" %-14s "`cdate'" as result "`status'"
	}
display as text "{hline 70}"
if "`check'" != "" & "`update'" == "" {
	display as text "`nout' outdated codelist(s). Use {bf:eurostatdata meta, update} to refresh."
	}
if "`update'" != "" {
	display as text "`ndl' codelist(s) downloaded."
	}
end


* ===========================================================================
* Helpers
* ===========================================================================

* Cache folder: $EUROSTAT_CACHE if set, else PLUS/_ ; falls back to tmpdir
program define _es_cachedir, rclass
if `"$EUROSTAT_CACHE"' != "" {
	local dir `"$EUROSTAT_CACHE"'
	}
else {
	local dir `"`c(sysdir_plus)'_"'
	}
if inlist(substr(`"`dir'"', -1, 1), "/", char(92)) local dir = substr(`"`dir'"', 1, length(`"`dir'"') - 1)
capture mkdir `"`dir'"'

tempname fh
capture file open `fh' using `"`dir'/_eurostat_meta_write.tmp"', write replace
if _rc {
	local dir = c(tmpdir)
	if inlist(substr(`"`dir'"', -1, 1), "/", char(92)) local dir = substr(`"`dir'"', 1, length(`"`dir'"') - 1)
	noisily display as text "Note: meta cache folder not writable; using " as result `"`dir'"'
	}
else {
	file close `fh'
	capture erase `"`dir'/_eurostat_meta_write.tmp"'
	}
return local dir `"`dir'"'
end


* Eurostat inventories (type: codelist | data). Data inventory refreshes daily.
program define _es_inventory, rclass
syntax name(name=type), dir(string) [force]
if "`type'" == "codelist" {
	local f `"`dir'/_eurostat_meta_codelists.dta"'
	local keep code version label
	}
else {
	local f `"`dir'/_eurostat_meta_datasets.dta"'
	local keep code lastdatachange laststructuralchange
	}

capture confirm file `"`f'"'
local have = (_rc == 0)
if `have' & "`force'" == "" {
	local fresh = ("`type'" == "codelist")
	if !`fresh' {
		use in 1 using `"`f'"', clear
		local d : char _dta[es_date]
		local fresh = ("`d'" == c(current_date))
		}
	if `fresh' {
		return local file `"`f'"'
		exit
		}
	}

tempfile raw dta
capture copy "https://ec.europa.eu/eurostat/api/dissemination/files/inventory?type=`type'" `"`raw'"', replace
if _rc {
	if `have' {
		noisily display as text "Could not refresh the Eurostat `type' inventory; using cached copy."
		return local file `"`f'"'
		}
	else {
		noisily display as text "Could not download the Eurostat `type' inventory."
		}
	exit
	}
import delimited using `"`raw'"', delimiters(tab) varnames(1) stringcols(_all) bindquote(nobind) encoding("utf-8") clear
keep `keep'
char _dta[es_date] "`c(current_date)'"
compress
save `"`dta'"'
copy `"`dta'"' `"`f'"', replace
return local file `"`f'"'
end


* One codelist (code, label). Uses cache unless force, or compare finds a new version.
program define _es_codelist, rclass
syntax name(name=code), dir(string) [version(string) compare force]
local code = upper("`code'")
local f `"`dir'/_eurostat_meta_cl_`code'.dta"'

capture confirm file `"`f'"'
local have = (_rc == 0)
if `have' & "`force'" == "" {
	local current = 1
	if "`compare'" != "" & "`version'" != "" {
		use in 1 using `"`f'"', clear
		local cver : char _dta[es_version]
		local current = ("`cver'" == "`version'")
		}
	if `current' {
		return local file `"`f'"'
		return local status "cached"
		exit
		}
	}

tempfile raw dta
capture copy "https://ec.europa.eu/eurostat/api/dissemination/sdmx/2.1/codelist/ESTAT/`code'/?format=TSV&compressed=false&lang=en" `"`raw'"', replace
if _rc {
	if `have' {
		noisily display as text "  could not refresh `code'; using cached copy"
		return local file `"`f'"'
		}
	else {
		noisily display as text "  labels for `code' not available"
		}
	return local status "failed"
	exit
	}
import delimited using `"`raw'"', delimiters(tab) varnames(nonames) stringcols(_all) bindquote(nobind) encoding("utf-8") clear
keep v1 v2
rename (v1 v2) (code label)
duplicates drop code, force
char _dta[es_version] "`version'"
char _dta[es_date] "`c(current_date)'"
compress
save `"`dta'"'
copy `"`dta'"' `"`f'"', replace
return local file `"`f'"'
return local status "downloaded"
end


* User period -> Eurostat TIME_PERIOD (2020, 2020-Q1, 2020-S1, 2020-W05, 2020-01, 2020-01-15)
program define _es_period, rclass
args p
local p = upper(subinstr(strtrim(`"`p'"'), " ", "", .))
if ustrregexm("`p'", "^(\d{4})$") {
	local out "`p'"
	}
else if ustrregexm("`p'", "^(\d{4})-?Q([1-4])$") {
	local out = ustrregexs(1) + "-Q" + ustrregexs(2)
	}
else if ustrregexm("`p'", "^(\d{4})-?[SH]([12])$") {
	local out = ustrregexs(1) + "-S" + ustrregexs(2)
	}
else if ustrregexm("`p'", "^(\d{4})-?W(\d{1,2})$") {
	local out = ustrregexs(1) + "-W" + string(real(ustrregexs(2)), "%02.0f")
	}
else if ustrregexm("`p'", "^(\d{4})-?M?(\d{1,2})$") {
	local out = ustrregexs(1) + "-" + string(real(ustrregexs(2)), "%02.0f")
	}
else if ustrregexm("`p'", "^(\d{4})-?M?(\d{1,2})-?D?(\d{1,2})$") {
	local out = ustrregexs(1) + "-" + string(real(ustrregexs(2)), "%02.0f") + "-" + string(real(ustrregexs(3)), "%02.0f")
	}
else {
	display as error "invalid period: `p' (use e.g. 2020, 2020Q1, 2020S1, 2020W5, 2020M1, 2020-01-15)"
	exit 198
	}
return local period "`out'"
end


* Eurostat period header -> kind (A Q S W M D X) and variable-name suffix
program define _es_timekey, rclass
args h
local h = upper(strtrim(`"`h'"'))
if ustrregexm("`h'", "^(\d{4})$") {
	return local kind "A"
	return local suffix "`h'"
	}
else if ustrregexm("`h'", "^(\d{4})-Q([1-4])$") {
	return local kind "Q"
	return local suffix = ustrregexs(1) + "q" + ustrregexs(2)
	}
else if ustrregexm("`h'", "^(\d{4})-S([12])$") {
	return local kind "S"
	return local suffix = ustrregexs(1) + "s" + ustrregexs(2)
	}
else if ustrregexm("`h'", "^(\d{4})-W(\d{2})$") {
	return local kind "W"
	return local suffix = ustrregexs(1) + "w" + ustrregexs(2)
	}
else if ustrregexm("`h'", "^(\d{4})-(\d{2})$") {
	return local kind "M"
	return local suffix = ustrregexs(1) + "m" + string(real(ustrregexs(2)))
	}
else if ustrregexm("`h'", "^(\d{4})-(\d{2})-(\d{2})$") {
	return local kind "D"
	return local suffix = ustrregexs(1) + "m" + string(real(ustrregexs(2))) + "d" + string(real(ustrregexs(3)))
	}
else {
	return local kind "X"
	return local suffix = ustrregexra(lower("`h'"), "[^a-z0-9]", "")
	}
end


* Decompress a .gz file without external tools
program define _es_gunzip
args src dst
if c(os) == "Windows" {
	shell powershell -NoProfile -Command "\$i=[IO.File]::OpenRead('`src''); \$o=[IO.File]::Create('`dst''); \$g=New-Object IO.Compression.GZipStream(\$i,[IO.Compression.CompressionMode]::Decompress); \$g.CopyTo(\$o); \$g.Close(); \$o.Close()"
	}
else {
	shell gunzip -c "`src'" > "`dst'"
	}
end
