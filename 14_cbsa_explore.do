*=============================================================================
* 14_cbsa_explore.do
* Standalone Stata explorer for the CBSA-level macro panel.
* Designed to run on any machine that has Stata + cbsa_treatments.dta.
* Copy this file plus cbsa_treatments.dta to the target machine and just run.
*=============================================================================
clear all
set more off
version 17

* ---- Path (EDIT for the target machine) ------------------------------------
local DATA "./cbsa_treatments.dta"   /* assumes .do and .dta in same folder */

use "`DATA'", clear
di as text "Loaded " _N " CBSAs."

* ---- Quick coverage --------------------------------------------------------
di as text _n "Coverage of headline variables:"
foreach v in hpi_boom bartik_1980_9907 bartik_1980_0711 ///
             d_tradeusch_pw_0007 saiz_elasticity gmns_gamma ///
             wealth_median_2000 wealth_median_2020 d_wealth_median_0020 {
    quietly count if !missing(`v')
    di as text "   `v': n=" r(N)
}

* ---- Standardize cross-CBSA exposures --------------------------------------
foreach v in hpi_boom bartik_1980_9907 bartik_1980_0711 ///
             d_tradeusch_pw_0007 saiz_elasticity gmns_gamma {
    cap confirm variable `v'
    if !_rc {
        sum `v'
        gen z_`v' = (`v' - r(mean)) / r(sd)
    }
}

* ---- Sample restriction ----------------------------------------------------
gen byte _has_all_exp = !missing(z_hpi_boom, z_bartik_1980_9907, ///
                                  z_bartik_1980_0711, z_d_tradeusch_pw_0007)
keep if _has_all_exp & !missing(d_wealth_median_0020) & !missing(lf_1999)
di as text _n "Working sample: " _N " CBSAs"

* ---- Single-predictor specs on Δ Median wealth (2000-2020) ----------------
di as text _n "{hline 70}"
di as text "Δ Median wealth 2000-2020 (per σ exposure, dollars), LF-weighted"
di as text "{hline 70}"
foreach v in z_hpi_boom z_bartik_1980_9907 z_bartik_1980_0711 z_d_tradeusch_pw_0007 {
    quietly reg d_wealth_median_0020 `v' [aw=lf_1999], vce(robust)
    estimates store m_`v'
}
esttab m_z_hpi_boom m_z_bartik_1980_9907 m_z_bartik_1980_0711 m_z_d_tradeusch_pw_0007, ///
    se star(* 0.10 ** 0.05 *** 0.01) ///
    keep(z_hpi_boom z_bartik_1980_9907 z_bartik_1980_0711 z_d_tradeusch_pw_0007) ///
    mtitles("HPI" "Bartik 9907" "Bartik 0711" "ADH 0007") ///
    stats(r2 N, fmt(3 0))

* ---- Joint spec ------------------------------------------------------------
di as text _n "Joint spec on Δ Median wealth:"
reg d_wealth_median_0020 z_hpi_boom z_bartik_1980_9907 z_d_tradeusch_pw_0007 ///
    [aw=lf_1999], vce(robust)
estimates store m_joint_med

* Same for Δ Mean and Δ Gini, joint spec
reg d_wealth_mean_0020 z_hpi_boom z_bartik_1980_9907 z_d_tradeusch_pw_0007 ///
    [aw=lf_1999], vce(robust)
estimates store m_joint_mean

reg d_wealth_gini_0020 z_hpi_boom z_bartik_1980_9907 z_d_tradeusch_pw_0007 ///
    [aw=lf_1999], vce(robust)
estimates store m_joint_gini

reg d_wealth_top10_0020 z_hpi_boom z_bartik_1980_9907 z_d_tradeusch_pw_0007 ///
    [aw=lf_1999], vce(robust)
estimates store m_joint_top10

reg d_wealth_bottom50_0020 z_hpi_boom z_bartik_1980_9907 z_d_tradeusch_pw_0007 ///
    [aw=lf_1999], vce(robust)
estimates store m_joint_bot50

esttab m_joint_med m_joint_mean m_joint_gini m_joint_top10 m_joint_bot50, ///
    se star(* 0.10 ** 0.05 *** 0.01) ///
    mtitles("Δmedian" "Δmean" "Δgini" "Δtop10" "Δbot50") ///
    stats(r2 N, fmt(3 0))

* ---- Decadal breakdown (boom-bust vs recovery+COVID) -----------------------
di as text _n "{hline 70}"
di as text "Decadal split: 2000-2010 vs 2010-2020"
di as text "{hline 70}"
foreach base in d_wealth_median d_wealth_mean d_wealth_gini {
    foreach win in 0010 1020 0020 {
        cap confirm variable `base'_`win'
        if !_rc {
            quietly reg `base'_`win' z_hpi_boom z_bartik_1980_9907 [aw=lf_1999], vce(robust)
            estimates store dec_`base'_`win'
        }
    }
}
esttab dec_d_wealth_median_0010 dec_d_wealth_median_1020 dec_d_wealth_median_0020 ///
       dec_d_wealth_mean_0010   dec_d_wealth_mean_1020   dec_d_wealth_mean_0020 ///
       dec_d_wealth_gini_0010   dec_d_wealth_gini_1020   dec_d_wealth_gini_0020, ///
    se star(* 0.10 ** 0.05 *** 0.01) ///
    keep(z_hpi_boom z_bartik_1980_9907) ///
    mtitles("Med 00-10" "Med 10-20" "Med 00-20" ///
            "Mean 00-10" "Mean 10-20" "Mean 00-20" ///
            "Gini 00-10" "Gini 10-20" "Gini 00-20") ///
    stats(r2 N, fmt(3 0))

* ---- Interaction: HPI × Bartik 9907 ---------------------------------------
di as text _n "{hline 70}"
di as text "HPI × Bartik 9907 interaction (boom decade)"
di as text "{hline 70}"
gen z_hpi_x_bart9907 = z_hpi_boom * z_bartik_1980_9907
foreach base in d_wealth_median d_wealth_mean d_wealth_gini {
    foreach win in 0010 1020 0020 {
        cap confirm variable `base'_`win'
        if !_rc {
            quietly reg `base'_`win' z_hpi_boom z_bartik_1980_9907 z_hpi_x_bart9907 ///
                [aw=lf_1999], vce(robust)
            estimates store int_`base'_`win'
        }
    }
}
esttab int_d_wealth_median_* int_d_wealth_mean_* int_d_wealth_gini_*, ///
    se star(* 0.10 ** 0.05 *** 0.01) ///
    keep(z_hpi_boom z_bartik_1980_9907 z_hpi_x_bart9907) ///
    stats(r2 N, fmt(3 0))

* ---- Cell-mean wealth trajectories ----------------------------------------
di as text _n "Cell means on key outcomes:"
table cell, statistic(mean wealth_median_2000 wealth_median_2020 ///
                              d_wealth_median_0020 d_wealth_gini_0020 ///
                              d_own_rate_0020) nformat(%10.0f)

* ---- Scatter: Δmedian wealth vs HPI boom ----------------------------------
twoway (scatter d_wealth_median_0020 z_hpi_boom [w=lf_1999], msymbol(circle_hollow)) ///
       (lfit    d_wealth_median_0020 z_hpi_boom [w=lf_1999], lwidth(thick)), ///
    title("CBSA Δmedian wealth 2000-2020 vs 1999-07 HPI boom") ///
    xtitle("z-score, 1999-07 HPI growth") ytitle("Δ median wealth, 2000-2020") ///
    legend(off) graphregion(color(white))
graph export "fig_cbsa_dmed_vs_boom.pdf", replace
di as text _n "Saved fig_cbsa_dmed_vs_boom.pdf"
