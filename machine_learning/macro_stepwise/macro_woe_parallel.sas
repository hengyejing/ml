%let embedded_macro_path = /ccarp_02/bbcrisk/RGC3/MODELING/macro_robot
/* embedded macro: macro_woe_monotone.sas */

%macro woe(data = , y = , xn = , xn_trend = , wt = , sg = , path = ., pvalue = 0.20, maxbin = 50,
           minbads = 50, minfreq = 500, SV_lkptbl = , RP_lkptbl = , threads = 12, n_jobs = 10);

**************************************************************************************;
*  CREATED BY HENRY JING ON 08/16/2019 FOR PARALLEL COMPUTING OF WOE TRANSFORMATION. *;
*  IT NEEDS TO INVOKE 'MACRO_WOE_MONOTONE.SAS' FROM SASLIB                           *;
*                                                                                    *;
*  PARAMETERS:                                                                       *;
*   - DATA: INPUT DATA. (REQUIRED)                                                   *;
*   - Y   : RESPONSE VARIABLE (BAD RESPONSE), 0/1 VALUES ONLY. (REQUIRED)            *;
*   - XN  : PREDICTORS (INDEPENDENT VARIABLE, REQUIRED).                             *;
*                                                                                    *;
*   - XN_TREND: EXPECTED TREND OF EACH VARIABLE. THE DEFAULT IS NULL, MEANING        *;
*       THE TREND OF EACH VARIABLE IS DETERMINATED BY DATA. (OPTIONAL)               *;
*   - WT  : WEIGHTS, DEFAULT WEIGHT IS 1. (OPTIONAL)                                 *;
*   - SG  : SEGMENT ID, DEFAULT IS NULL (OPTIONAL)                                   *;
*   - PATH: THE PATH TO SAVE OUTPUT FILES. DEFAULT IS CURRENT WORKING DIR.           *;
*   - PVALUE: P-VALUE FOR CHISQUARE TEST OF BINS COMBINATION. DEFAULT IS 0.20.       *;
*   - MAXBIN: MAXIMUM NUMBER OF BINS. THE DEFAULT IS 50.                             *;
*   - MINBADS: MINIMUM BADS FOR BINNING PROCEDURE. DEFAULT IS 50.                    *;
*   - SV_LKPTBL: A SAS DATASET CONTAINING COLUMNS 'NAME', 'MAX_VAL' OR MORE          *;
*               (I.E., 'SV1', 'SV2',...).                                            *;
*           THE DEFAULT IS NULL, MEANING NO SPECIAL VALUES IN EACH VARIABLE.         *;
*   - RP_LKPTBL: A SAS DATASET CONTAINING COLUMNS 'NAME', 'REF_POINT' FOR            *;
*           OVERWRITTING THE WOE VALUE OF MISSING OR SPECIAL VALUES WHICH            *;
*           HAVE BAD RATE LARGER THAN THE OVERALL BAD RATE (RISK).                   *;
*   - THREADS: NUMBER OF THREADS FOR PARALLEL COMPUTING (FOR PROC HPSUMMARY)         *;
*   - NJOBS: NUMBER OF JOBS FOR PARALLEL COMPUTING. DEFAULT IS 10.                   *;
*                                                                                    *;
*  OUTPUTS:                                                                          *;
*   - 100_WOE_SEG.OUT: A FILE CONTAINING BINNING SUMMARY TABLE                       *;
*   - 100_WOE_SEG_ORI.WOE: A FILE CONTAINING ORIGINAL WOE SAS CODE                   *;
*   - 100_WOE_SEG_OWT.WOE: A FILE CONTAINING MISSING OR SPECIAL VALUE BEING          *;
*                       OVER-WRITTEN BY REFERENCE WOE VALUE. IF RP_LKPTBL            *;
*                   IS PROVIDED, THE WOE VALUES OF MISSING OR SPECIAL VALUES         *;
*                   WILL BE OVERWRITTEN BY WOE VALUES CORRESPONDING TO THESE         *;
*                   PROVIDED REF POINT. OTHERWISE, THE REF WOE VALUES WILL BE        *;
*                   DETERMINATED BY DATA ITSELF.                                     *;
*   - 100_WOE_SEG.SIG: A FILE CONTAINING SUMMARY INFORMATION                         *;
*   - 100_WOE_SEG.FMT: A FILE CONTAINING BINNING FORMAT                              *;
**************************************************************************************;

    *** LOCATE THE DATA SOURCE: LIBARY NAME, DATASET NAME AND LIBARY PATH ***;
    %let lib_data = %scan(&data, 1, '.'); /* extract data library name */
    %let data_name = %scan(&data, 2, '.'); /* extract data name */
    *** If libname not specified, search the work library path that stores the data ***;
    %IF "&data_name" = "" %THEN %DO;
        %let data_name = &lib_data;
        %let lib_data = in;
        %let data_path = %sysfunc(pathname(work));
        %let data = in.&data;
    %END;
    %ELSE %let data_path = %sysfunc(pathname(&lib_data));

    %IF "&SV_lkptbl" ne "" %THEN %DO;
        %let lib_SV = %scan(&SV_lkptbl, 1, '.');
        %let SV_name = %scan(&SV_lkptbl, 2, '.');
        %IF "&SV_name" = "" %THEN %DO;
            %let SV_name = &lib_SV;
            %let lib_SV = in1;
            %let SV_path = %sysfunc(pathname(work));
            %let SV_lkptbl = in1.&SV_lktbl;
        %END;
        %ELSE %let SV_path = %sysfunc(pathname(&lib_SV));
    %END;
    %IF "RP_lkptbl" ne "" %THEN %DO;
        %let lib_RP = %scan(&RP_lkptbl, 1, '.');
        %let RP_name = %scan(&RP_lkptbl, 2, '.');
        %IF "RP_name" = "" %THEN %DO;
            %let RP_name = &lib_RP;
            %let lib_RP = in2;
            %let RP_path = %sysfunc(pathname(work));
            %let RP_lkptbl = in2.&RP_lkptbl;
        %END;
        %ELSE %let RP_path = %sysfunc(pathname(&lib_RP));
    %END;

    *** DIVIDE THE VARIABLE LIST INTO N_JOBS LISTS ***;
    %let numvars = %sysfunc(countw(&xn, ' '));
    %IF &numvars < &n_jobs %THEN %LET n_jobs = &numvars;
    %let numvars_1grp = %sysevalf(&numvars/&n_jobs);
    %let numvars_1grp = %sysfunc(ceil(&numvars_1grp));
    %PUT THIS IS &numvars_1grp;
    proc datasets lib = work; delete _varlist; run;
    %DO i = 1 %TO &numvars;
        %let xi = %scan(&xn,&i,' ');
        %IF &xn_trend ne  %THEN %let xi_trd = %scan(&xn_trend, &i, ' ');
        data _tempA_;
            length variable &33.;
            varsID = &i;
            variable = "&xi";
            grp = ceil(varsID/&numvars_1grp);
            if grp > &n_jobs then grp = &n_jobs;
            %IF &xn_trend ne  %THEN %DO;
                length trend $5.;
                trend = "&xi_trd";
            %END;
            if varsID = &numvars then call symput("n_jobs", grp);
        run;
        proc append data = _tempA_ base = _varlist force; run;
    %END;

    *** CREATE A TEMPARARY DIRECTORY TO RUN PARALLEL WOE ***;
    x "mkdir - p &path./WoE_Output";
    %let temp_woe_path = &path./WoE_Output;

    *** GENERATE N_JOBS SAS FILE FOR PREPARATION OF PARALLEL COMPUTING ***;
    %let cmd_run_nohup = ;
    %DO i = 1 %TO &n_jobs;
        x "rm -f &temp_woe_path./varlist_woe_g&i..dat";
        data _null_;
            file "&temp_woe_path./varlist_woe_g&i..dat" mod;
            set _varlist(where = (grp = &i.)) end = eof;
            if _N_ = 1 then put '%let ' " xn_g&i = ";
            put variable;
            if eof then put ";";
        run;
        %IF "&xn_trend" ne "" %THEN %DO;
            data _null_;
                file "&temp_woe_path./varlist_woe_g&i..dat" mod;
                set _varlist(where = (grp = &i.)) end = eof;
                if _N_ = 1 then put '%let ' " xn_trend_g&i = ";
                put varsID;
                if eof then put ";";
            run;
        %END;

