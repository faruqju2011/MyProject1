/*---------------------------------------------------------------------------
  WRDS - Audit Analytics: min / max cyber-breach disclosure date per firm.

  Audit Analytics' Cyber Security breach data lives in the WRDS `audit`
  library. The exact member (table) name and disclosure-date column differ
  slightly across subscriptions, so this program first *discovers* the right
  table/column and then computes the earliest and latest disclosure date for
  each firm.

  How to run:
    - On the WRDS SAS server (wrds-cloud / SAS Studio), the `audit` libname
      is pre-assigned, so you can run this as-is.
    - From a local SAS session, uncomment the SIGNON / RSUBMIT block below to
      connect to WRDS over SAS/CONNECT first.
---------------------------------------------------------------------------*/

/* --- Optional: connect from a local SAS session to the WRDS cloud ---------
%let wrds = wrds-cloud.wharton.upenn.edu 4016;
options comamid=TCP remote=WRDS;
signon username=_prompt_;
rsubmit;
----------------------------------------------------------------------------*/

/*---------------------------------------------------------------------------
  1. Discover the cyber-breach table inside the Audit Analytics library
---------------------------------------------------------------------------*/
proc sql;
    title "Candidate cyber-breach tables in the AUDIT library";
    select memname
    from dictionary.tables
    where libname = "AUDIT"
      and (upcase(memname) like "%CYBER%" or upcase(memname) like "%BREACH%");
quit;
title;

/* Set the table you want here (from the list above).                       */
/* Common member name is CYBERSECURITY; adjust if your list differs.        */
%let table = cybersecurity;

/*---------------------------------------------------------------------------
  2. Inspect the columns so we can pick the date and firm identifier
---------------------------------------------------------------------------*/
proc sql;
    title "Columns in AUDIT.&table";
    select name, type, format, label
    from dictionary.columns
    where libname = "AUDIT" and upcase(memname) = upcase("&table");
quit;
title;

/*---------------------------------------------------------------------------
  3. Pick the disclosure-date column and the firm identifier
     (set these to the real column names shown in step 2)

     disclosure date : disclosuredate, date_of_disclosure, date_of_breach,
                        date_became_aware
     firm identifier : company_fkey (Audit Analytics key), ticker, cik,
                        company_name
---------------------------------------------------------------------------*/
%let date_col = disclosuredate;   /* <-- set to the real date column   */
%let firm_col = company_fkey;     /* <-- set to your firm identifier    */

/*---------------------------------------------------------------------------
  4. Min / max disclosure date per firm
---------------------------------------------------------------------------*/
proc sql;
    create table cyberbreach_by_firm as
    select &firm_col           as firm,
           min(&date_col)      as first_disclosure format=date9.,
           max(&date_col)      as last_disclosure  format=date9.,
           count(*)            as n_breaches
    from audit.&table
    where &date_col is not null
    group by &firm_col
    order by firm;
quit;

proc print data=cyberbreach_by_firm (obs=20) noobs;
    title "Cyber-breach disclosure date range, by firm (first 20)";
run;
title;

/*---------------------------------------------------------------------------
  5. Overall (whole-database) disclosure-date range, for reference
---------------------------------------------------------------------------*/
proc sql;
    title "Overall cyber-breach disclosure-date range";
    select min(&date_col) as min_date format=date9.,
           max(&date_col) as max_date format=date9.
    from audit.&table
    where &date_col is not null;
quit;
title;

/* --- If you used RSUBMIT above, bring results back and end the session ----
proc download data=cyberbreach_by_firm out=cyberbreach_by_firm; run;
endrsubmit;
signoff;
----------------------------------------------------------------------------*/
