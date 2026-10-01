* End-to-end speed benchmark for Eurostat import commands.
* Timings include network transfer and package-specific processing.
* Run from Stata; change project_dir and xteurostat_7zip for another computer.

version 15.0
set more off

local project_dir "D:\Dropbox\STATA - MASTER\EUROSTATDATA"
local dataset "nama_10_gdp"
local repetitions 3
local xteurostat_7zip "C:\Program Files\7-Zip\7zG.exe"
local output_dir "data"

local original_pwd `"`c(pwd)'"'
capture cd `"`project_dir'"'
if _rc {
	display as error "Project folder not found. Edit local project_dir near the top of this dofile."
	exit 601
	}

capture confirm file "installation/eurostatdata.ado"
if _rc {
	display as error "Run this dofile from a complete EUROSTATDATA project checkout."
	cd `"`original_pwd'"'
	exit 601
	}

local restore_data 0
if c(k) > 0 {
	tempfile original_data
	quietly save `"`original_data'"', replace
	local restore_data 1
	}

capture mkdir `"`output_dir'"'
capture log close eubench
log using `"`output_dir'/eurostatdata_speed_benchmark.log"', text replace name(eubench)

display as text "Eurostat import speed benchmark"
display as text "Dataset: `dataset'; measured runs per package: `repetitions'"
display as text "Timings include Eurostat response time, downloads, and package processing."
display as text "Results: `output_dir'/eurostatdata_speed_benchmark_runs.* and _summary.*"

* Install missing SSC packages before running, for example:
/*
ssc install eurostatuse, replace
ssc install eurouse, replace
ssc install getdata, replace
ssc install sdmxuse, replace
ssc install xteurostat, replace
*/

local installation_dir `"`project_dir'/installation"'
adopath ++ `"`installation_dir'"'

capture program drop _eurostat_speed_call
program define _eurostat_speed_call
	args package code sevenzip

	if "`package'" == "eurostatdata" {
		eurostatdata `code', clear noflags nolabel
		}
	else if "`package'" == "eurostatuse" {
		eurostatuse `code', clear uncompressed noflags nolabel
		}
	else if "`package'" == "eurouse" {
		eurouse `code', clear
		}
	else if "`package'" == "getdata" {
		getdata raw EUROSTAT, rest(`code'/...) clear
		}
	else if "`package'" == "sdmxuse" {
		sdmxuse data ESTAT, dataset(`code') clear
		}
	else if "`package'" == "xteurostat" {
		if `"`sevenzip'"' == "" {
			xteurostat `code', clear
			}
		else {
			xteurostat `code', clear path7zg(`"`sevenzip'"')
			}
		}
	else {
		display as error "Unknown benchmark package: `package'"
		exit 198
		}
end

tempfile benchmark_results
tempname post_handle
postfile `post_handle' str20 package int run double seconds long observations ///
	int variables int rc str24 status using `"`benchmark_results'"', replace

local packages "eurostatdata eurostatuse eurouse getdata sdmxuse xteurostat"
foreach package of local packages {
	if "`package'" == "eurouse" & c(os) == "Windows" {
		post `post_handle' ("`package'") (0) (.) (.) (.) (0) ("unsupported: Windows")
		continue
		}

	capture which `package'
	local which_rc = _rc
	if `which_rc' {
		post `post_handle' ("`package'") (0) (.) (.) (.) (`which_rc') ("not installed")
		display as error "Skipping `package': command not installed."
		continue
		}

	if "`package'" == "xteurostat" & c(os) == "Windows" {
		capture confirm file `"`xteurostat_7zip'"'
		if _rc {
			post `post_handle' ("`package'") (0) (.) (.) (.) (_rc) ("7-Zip not found")
			display as error "Skipping xteurostat: set xteurostat_7zip to a valid 7-Zip executable."
			continue
			}
		}

	display as text _newline "Warm-up: `package'"
	clear
	capture noisily _eurostat_speed_call "`package'" "`dataset'" `"`xteurostat_7zip'"'
	local warm_rc = _rc
	local warm_n = _N
	local warm_k = c(k)
	if `warm_rc' != 0 | `warm_n' == 0 {
		local warm_status "warm-up failed"
		if `warm_rc' == 0 local warm_status "empty output"
		post `post_handle' ("`package'") (0) (.) (`warm_n') (`warm_k') (`warm_rc') ("`warm_status'")
		display as error "Skipping timed runs for `package' (return code `warm_rc', observations `warm_n')."
		continue
		}

	forvalues run = 1/`repetitions' {
		clear
		timer clear 1
		timer on 1
		capture noisily _eurostat_speed_call "`package'" "`dataset'" `"`xteurostat_7zip'"'
		local run_rc = _rc
		timer off 1
		quietly timer list 1
		local elapsed = r(t1)
		local observations = _N
		local variables = c(k)
		local status "ok"
		if `run_rc' != 0 local status "failed"
		else if `observations' == 0 local status "empty output"
		post `post_handle' ("`package'") (`run') (`elapsed') (`observations') ///
			(`variables') (`run_rc') ("`status'")
		display as text "`package' run `run': " %8.3f `elapsed' " sec; N=" ///
			%12.0fc `observations' "; variables=" `variables' "; `status'"
		}
	}

postclose `post_handle'
adopath - `"`installation_dir'"'

use `"`benchmark_results'"', clear
format seconds %9.3f
sort package run
list package run status rc observations variables seconds, sepby(package) noobs
save `"`output_dir'/eurostatdata_speed_benchmark_runs.dta"', replace
export delimited using `"`output_dir'/eurostatdata_speed_benchmark_runs.csv"', replace

preserve
keep if status == "ok"
count
if r(N) > 0 {
	collapse (median) median_seconds=seconds (min) min_seconds=seconds ///
		(max) max_seconds=seconds (count) successful_runs=seconds, by(package)
	sort median_seconds
	quietly summarize median_seconds, meanonly
	local fastest = r(min)
	gen relative_to_fastest = .
	if `fastest' > 0 replace relative_to_fastest = median_seconds / `fastest'
	format median_seconds min_seconds max_seconds %9.3f
	format successful_runs %9.0f
	format relative_to_fastest %9.2f
	display as text _newline "Median runtime summary (lower is faster):"
	list package successful_runs median_seconds min_seconds max_seconds ///
		relative_to_fastest, noobs
	save `"`output_dir'/eurostatdata_speed_benchmark_summary.dta"', replace
	export delimited using `"`output_dir'/eurostatdata_speed_benchmark_summary.csv"', replace
	}
else {
	display as error "No successful benchmark runs; see the run results and log."
	}
restore

log close eubench
capture adopath - `"`installation_dir'"'
if `restore_data' {
	use `"`original_data'"', clear
	}
else {
	clear
	}
cd `"`original_pwd'"'




*******

timer clear

timer on 1
eurostatdata nama_10_gdp, clear noflags nolabel
timer off 1

timer on 2
eurostatuse nama_10_gdp, clear uncompressed noflags nolabel
timer off 2

timer list






