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
    %
