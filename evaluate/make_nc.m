function make_nc(infile,writeFile)
% Write results out to netcdf format
%
% inputs:   infile - input mat file following standard analysis output format
%
% Paul J. Durack 4 November 2009

% Comments Nov 2009 - Apr 2011 inclusive
%{
% PJD  4 Nov 2009   - Obtained nc code from make_models.m
% PJD  5 Nov 2009   - Included thetao and salinity changes
% PJD  5 Nov 2009   - Added machine independent code
% PJD  5 Nov 2009   - Tidy up global attributes (need to confirm CF-1.5)
% PJD  5 Nov 2009   - Propagated correct _FillValue entries for each var
% PJD  6 Nov 2009   - Still struggling with botched variables written to file, tidied up CF-1.4 reference (current standard)
% PJD  6 Nov 2009   - Reverse order of dimensions - so declare [dimIdLon,dimIdLat,dimIdDepth] and write [Lon,Lat,Depth]
% PJD  6 Nov 2009   - Included timestamp in outfile to declare "beta" status of the data, format and conventions
% PJD 12 Nov 2009   - Valid ranges for means and changes included, as per: http://durack-hf.hba.marine.csiro.au/mywiki/0805_blog
% PJD 12 Nov 2009   - Vertical coordinate: positive = "down" - defined before y, x
% PJD 13 Nov 2009   - Added more restrictive purge command (will only purge an *.nc file if generated on same day as purge attempt)
% PJD 11 Jan 2010   - Updated depth to 2000db (66) was 1000db (55) and created variable z_lvl to contain this info
% PJD 13 Jan 2010   - Updated standard_name and units in response to Paul Tildesley's CF compliance checker: reg2:/tildes/cfchecks/cfchecker
% PJD 15 Mar 2010   - Added density variable (and errors)
% PJD 13 May 2010   - Updated DOI to valid value; Added ptmean, smean and gamrfmean offsets
% PJD  9 Jun 2010   - Added version info for data; 1.0; Beta pre-release data
% PJD  8 Oct 2010   - Updated Reference global_att
% PJD  1 Mar 2011   - Updated time/history attribute (UTC)
% PJD 23 Mar 2011   - Used error estimates to mask bad mean and change data, without this masking mean fields in particular have hotspots
%                     Consult make_nc_sfc.m and ../100520_PaperPlots_Halosteric/make_paperplots (Fig2) ../110323_IMOS/make_paperplots.m for tips and limits
% PJD 23 Mar 2011   - Added comment attribute for variables, which includes error mask threshold used to generate data
% PJD 23 Mar 2011   - Removed longitude duplication (0 & 360) in observed data - fixed problem with basins3_NaN_ones_2x1 variable
% PJD 24 Mar 2011   - Quick comparison script written for DW10 vs WOA09 comparison, checks out ok (DW10vsWOA09.zip)
% PJD 24 Mar 2011   - Requested new '*_change' standard names
% PJD  8 Apr 2011   - Added depth masking using bathymetry data to mask out near-coastal regions
% PJD  8 Apr 2011   - Updated call to myMatEnv to include clim_dir variable assignment
%
% PJD 17 May 2011   - Updated standard names for variables which have them - names requested 110516
% PJD 17 May 2011   - Included *_bnds variables (time climatology_bnds needs work)
% PJD 17 May 2011   - Ignored '*_change_error' standard name request - too hard - don't provide a standard name for these variables
% PJD 17 May 2011   - Quite code tidyup, myMatEnv etc
% PJD 18 May 2011   - Added time and climatology_bnds variables, as per http://cf-pcmdi.llnl.gov/documents/cf-conventions/1.5/ch07s04.html
% PJD 18 May 2011   - Fixed issue with climatology attributes - mean data is 1950-2008 (climatology_bnds_mean),
%                     changes are 1950-2000 (climatology_bnds) added clarification to variables using comments attribute -
%                     as file focusses on changes (title, filename etc) climatology_bnds aligns with change fields
% PJD 20 Jun 2011   - Updated following corresponding file at ../110520_FLR2/sptg/make_nc.m
% PJD 22 Jun 2011   - Updated outfile to just *_beta.nc (removed datestamp)
% PJD 22 Jun 2011   - Updated some hard-coded entries to use standard_names and time* variables
% PJD 18 Jul 2011   - Updated "pressure" standard_name to "sea_water_pressure"
% PJD  1 Aug 2011   - Updated change_in* to change_over_time_in*
% PJD  2 Aug 2011   - Updated salinity standard_name to "sea_water_practical_salinity" - commented until standard name table v19
% TODO Internal:
% PJD  2 Aug 2011   - TODO: Add spatial scale info (x/ydatscale) and median time variables - check these outputs for consistency
% PJD  2 Aug 2011   - TODO: Consider converting change to decade-1, to get around issue with 58yr mean 50yr trends
% TODO External:
% PJD  2 Aug 2011   - TODO: Address issues suggested by CF-1.5 compliance checkers: http://cf-pcmdi.llnl.gov/conformance/compliance-checker/
% PJD  2 Aug 2011   - TODO: Consider data packing/compression http://nco.sourceforge.net/nco.html#Packed-data;
%                     chunksize optimisation http://www.unidata.ucar.edu/software/netcdf/old_docs/docs_3_6_2/
% NEW DATA ANALYSIS - 2011:
% PJD  2 Aug 2011   - TODO: Generate density data output too? - Convert to sig0/gamma n (Paul B's software?)
% PJD  2 Aug 2011   - TODO: Update using pressure corrected Argo (1950-2010), provide as v1.1 with suitable additional attributes
% PJD  2 Aug 2011   - TODO: Consider adding new abyssal data as presented by Purkey & Johnson (2010), need to account for topography (Jeff's code)
% PJD  2 Aug 2011   - TODO: Update valid_ranges, and info about density = neutral density (kg m-3 minus 1000)
%}
% PJD 10 Jan 2021   - Copied from /work/durack1/csiro/Backup/110808/Z_dur041_linux/Shared/090605_FLR2_sptg/make_nc.m (110801)
%                     and updated input
% PJD 22 Jan 2021   - Turned on standard_name writing, all registered https://cfconventions.org/Data/cf-standard-names/77/build/cf-standard-name-table.html
% PJD 22 Jan 2021   - Update to use a_infile* and time* variables in metadata creation https://github.com/durack1/oceanObs/issues/11
% PJD 22 Jan 2021   - Updated netcdf version global attribute 1.0.0 -> 1.1.0
% PJD  9 Feb 2021   - Updated to generate nc from old file versions (no infile/time/git attributes)
% PJD 18 Feb 2021   - Add salinity contrast diagnostics, and writeFile runtime argument
%                   - TODO: Add 35.0 test case for area weights; PA calculation, plus min/max changes written to globalAtt

% make_nc.m

%% Cleanup workspace and command window
% Initialise environment variables - only homeDir needed for file cleanups
%[homeDir,work_dir,dataDir,obsDir,username,a_host_longname,a_maxThreads,a_opengl,a_matver] = myMatEnv(maxThreads);
[homeDir,~,~,~,username,aHostLongname,~,~,~] = myMatEnv(2);
%archiveDir = [homeDir,'090605_FLR2_sptg/'];
if ~sum(strcmp(username,{'dur041','duro','durack1'})); disp('**myMatEnv - username error**'); keyboard; end

%% Toggle write density in output
include_density = 0;

%% Change the infile and pathnames
% Create inputs if they are not passed as arguments - check usage below..
if nargin < 1, disp('No valid input file, exiting'); return; end
if ~validatestring(writeFile,{'0','1','True','true','False','false'})
    disp('Invalid writeFile argument, exiting'); return
end
if sum(strcmp(writeFile,{'0','False','false'}))
    writeFile = false;
elseif sum(strcmp(writeFile,{'1','True','true'}))
    writeFile = true;
end
if nargin > 2, disp('Too many arguments, exiting'); return; end
if nargin == 2
   % Validate input is matfile
   if isfile(infile)
       fclose('all');
       [fid,~] = fopen(infile);
       S = convertCharsToStrings(fread(fid,80,'uint8=>char')); % read 80 elements, captures all version and date info
       ind = strfind(S,',');
       fclose(fid); clear fid
       matver = extractBefore(S,ind(1)); clear ind
       disp(matver)
       if contains(matver,'MAT-file')
           [outPath,name,ext] = fileparts(infile);
           %fileNameBits = split(name,'_'); % cell array
           %outPath = char(fullfile(filePath,join(fileNameBits([1,2,5,7:end]),'_')));
           disp(['outPath: ',outPath])
       else
           disp('No valid MAT-file, exiting')
           quit
       end % contains(matver
   end % isfile(infile)
end % nargin == 1

%% Load input data
load(infile, ...
     'a_file_process_time','a_gitHash','a_host_longname','a_infile','a_infileMd5','a_infileModify', ...
     'a_infileTimeBounds','a_matlab_version','a_script_name','a_script_start_time', ...
     'timebin','timespan', ...
     'pressure_levels','xi','yi', ...
     'ptc','ptce','ptmean','sc','sce','smean','gamrfc','gamrfce','gamrfmean'); %, ...
     %'sxdatscale','sydatscale','timemid','timescan',);

%% Create strings for data labels - read from infile
timeYrs         = [num2str(timespan),'yrs']; clear timespan
clim            = strsplit(a_infileTimeBounds,';'); clear a_infileTimeBounds
climBndsStart   = strtok(clim{1});
climBndsEnd     = strtok(clim{2}); clear clim
timeStart       = [num2str(timebin(1)),'0101']; clear timebin
if datestr(now,10) == climBndsEnd(1:4) % Catch case of current year
    timeBits = strsplit(climBndsEnd,'-');
    yr = timeBits{1};
    mn = num2str(str2double(timeBits{2}),'%02d');
    da = num2str(str2double(timeBits{end}),'%02d');
    timeStop        = [yr,mn,da];
else
    timeStop        = [climBndsEnd(1:4),'1231'];
end
timeWindow      = [timeStart,'-',timeStop];

%% Create string for data labels - in case of old files hard-code
% All runs from 200913 to 201105 (which don't include file variables) - see /work/durack1/Shared/200428_data_OceanObsAnalysis
% 210114 R2020bU3 run with 2021 data/AR6 1950-2019 analysis
%{
load('/work/durack1/Shared/200428_data_OceanObsAnalysis/210114_200121_local_robust_195001to201912_FLRdouble_sptg_R2020bU3_detect_79pres1000.mat')
Ref: https://github.com/durack1/oceanObs/blob/64625fdb225cb8d594e8073d17a4b10be267d800/fit_pres_1950_FLRdouble_sptg.m
%}
% 200913 R2020a run with original 090408 data
%{
%load('/work/durack1/Shared/200428_data_OceanObsAnalysis/200913_210216_local_robust_1950_FLRdouble_sptg_200913_79pres1000.mat')
%Ref: https://github.com/durack1/oceanObs/blob/64625fdb225cb8d594e8073d17a4b10be267d800/fit_pres_1950_FLRdouble_sptg.m
%load('/work/durack1/Shared/090605_FLR2_sptg/090408_pressurf_global_nodupes_exclude.mat')
%[~,indMin] = min(time_decimal); [~,indMax] = max(time_decimal);
%disp(time_elements(:,indMin)'), disp(time_elements(:,indMax)')
timeYrs = 59; % 1950-2008
clim = strsplit('1874-10-11 0:0:0; 2009-04-04 02:34:27',';');
climBndsStart   = strtok(clim{1});
climBndsEnd     = strtok(clim{2}); clear clim
timebin         = 1950:10:2010;
timeStart       = [num2str(timebin(1)),'0101']; clear timebin
timeStop        = [climBndsEnd(1:4),'0404']; %'1231'];
timeWindow      = [timeStart,'-',timeStop,'-200913-R2020a'];
a_infile        = '/work/durack1/Shared/090605_FLR2_sptg/090408_pressurf_global_nodupes_exclude.mat';
a_infileMd5     = 'f8c9b93250d6d9a1d990d17fcbcf541a';
a_infileModify  = '2012-03-24 17:51:03.000000000 -0700';
a_gitHash       = 'github.com/durack1/oceanObs/blob/64625fdb225cb8d594e8073d17a4b10be267d800/fit_pres_1950_FLRdouble_sptg.m';
%}
% 201223 R2020bU3 run with 201223 data
%{
%load('/work/durack1/Shared/200428_data_OceanObsAnalysis/201223_152459_local_robust_195001to202012_FLRdouble_sptg_R2020bU3_detect_79pres1000.mat')
%Ref: https://github.com/durack1/oceanObs/blob/5bab303fe00cd0b004d8e0bf0d71a3ca6faced48/fit_pres_1950_FLRdouble_sptg.m
%load('/work/durack1/Shared/200428_data_OceanObsAnalysis/201223_pressurf_global_nodupes_exclude.mat')
%[~,indMin] = min(time_decimal); [~,indMax] = max(time_decimal);
%disp(time_elements(:,indMin)'), disp(time_elements(:,indMax)')
timeYrs = 70; % 1950-2020
clim = strsplit('1874-10-13 0:0:0; 2020-12-11 00:33:00',';');
climBndsStart   = strtok(clim{1});
climBndsEnd     = strtok(clim{2}); clear clim
timebin         = 1950:10:2020;
timeStart       = [num2str(timebin(1)),'0101']; clear timebin
timeStop        = [climBndsEnd(1:4),'1211'];
timeWindow      = [timeStart,'-',timeStop,'-201223-R2020bU3'];
a_infile        = '/work/durack1/Shared/200428_data_OceanObsAnalysis/201223_pressurf_global_nodupes_exclude.mat';
a_infileMd5     = '2e46e589757491ab31c1196d263e0fe4';
a_infileModify  = '2020-12-23 13:35:25.056337661 -0800';
a_gitHash       = 'github.com/durack1/oceanObs/blob/5bab303fe00cd0b004d8e0bf0d71a3ca6faced48/fit_pres_1950_FLRdouble_sptg.m';
%}

%% If running through entire script cleanup export files
infile = char(fullfile(outPath,[name,ext]));
timeNow = [datestr(now,11),datestr(now,5),datestr(now,7),'-',datestr(now,13)];
outFile = (char(fullfile(outPath,['DurackandWijffels_GlobalOceanChanges_',timeWindow,'__', ...
           regexprep(timeNow,':',''),'_beta.nc']))); % Beta file
%outFile = (char(fullfile(outPath,['DurackandWijffels_GlobalOceanChanges_',timeWindow,'.nc']))); % Finalised file
disp(['outFile: ',outFile])
disp('* Are you sure you want to purge exported *.nc files? *'); keyboard
delete([outPath,['Durack*GlobalOceanChanges*',timeWindow,'_beta.nc']]);
delete([outPath,'Durack*GlobalOceanChanges*',timeNow,'*.nc']);

%% Smooth fields, truncate values beneath 2000db, trim off duplicate longitude and prepare for output
% Fix longitude duplication
xi = xi(1:180);
% Set level at 2000db (66) or surface (1)
z_lvl = 66; depth = pressure_levels(1:z_lvl);
% Trim data
pt_chg = squeeze(ptc(1:180,:,1:z_lvl,19));
pt_chg_err = squeeze(ptce(1:180,:,1:z_lvl,19)); clear ptce
pt_mean = ptmean(1:180,:,1:z_lvl)+squeeze(ptc(1:180,:,1:z_lvl,1)); clear ptmean ptc
s_chg = squeeze(sc(1:180,:,1:z_lvl,19));
s_chg_err = squeeze(sce(1:180,:,1:z_lvl,19)); clear sce
s_mean = squeeze(smean(1:180,:,1:z_lvl))+squeeze(sc(1:180,:,1:z_lvl,1)); clear smean sc
gamrf_chg = squeeze(gamrfc(1:180,:,1:z_lvl,19));
gamrf_chg_err = squeeze(gamrfce(1:180,:,1:z_lvl,19)); clear gamrfce
gamrf_mean = squeeze(gamrfmean(1:180,:,1:z_lvl))+squeeze(gamrfc(1:180,:,1:z_lvl,1)); clear gamrfmean gamrfc

%% Create bounds variables
% Time
climatology_bnds = datenum({climBndsStart,climBndsEnd}); % bounds of change climatology
time = mean(([climatology_bnds(1),climatology_bnds(2)]))-datenum(climBndsStart); % middle day of middle year
climatology_bnds = climatology_bnds-datenum(climBndsStart);
%climatology_bnds_mean = datenum({climBndsStart,climBndsEnd}); % bounds of mean climatology
%time_mean = mean(([climatology_bnds_mean(1),climatology_bnds_mean(2)]))-datenum(climBndsStart);
%climatology_bnds_mean = climatology_bnds_mean-datenum(climBndsStart);

% Depth
depth_bnds  = NaN(length(depth),2);
for x = 1:length(depth)
    if x == 1 % Fix start indices
        depth_bnds(x,1) = 0;
        depth_bnds(x,2) = 2.5;
    elseif x == length(depth) % Fix end indices
        depth_bnds(x,1) = 1950;
        depth_bnds(x,2) = 2000;
        continue;
    else
        depth_bnds(x,1) = (depth(x-1)+depth(x))/2;
        depth_bnds(x,2) = (depth(x)+depth(x+1))/2;
    end
end % [depth_bnds(:,1),depth,depth_bnds(:,2)]

% Latitude
lat_bnds  = NaN(length(yi),2);
for x = 1:length(yi)
    if x == 1 % Fix start indices
        lat_bnds(x,1) = -70;
        lat_bnds(x,2) = -69.5;
    elseif x == length(yi) % Fix end indices
        lat_bnds(x,1) = 69.5;
        lat_bnds(x,2) = 70;
        continue;
    else
        lat_bnds(x,1) = (yi(x-1)+yi(x))/2;
        lat_bnds(x,2) = (yi(x)+yi(x+1))/2;
    end
end % [lat_bnds(:,1),yi',lat_bnds(:,2)]

% Longitude
lon_bnds  = NaN(length(xi),2);
for x = 1:length(xi)
    if x == 1 % Fix start indices
        lon_bnds(x,1) = 0;
        lon_bnds(x,2) = 1;
    elseif x == length(xi) % Fix end indices
        lon_bnds(x,1) = 357;
        lon_bnds(x,2) = 359;
        continue;
    else
        lon_bnds(x,1) = (xi(x-1)+xi(x))/2;
        lon_bnds(x,2) = (xi(x)+xi(x+1))/2;
    end
end %[lon_bnds(:,1),xi',lon_bnds(:,2)]

%% Error mask bad data before infilling and smoothing - Check /home/dur041/Shared/090605_FLR2_sptg/110323_IMOS/make_paperplots.m
% temperature
pt_threshold = 2;
indpt_bad = pt_chg_err(:,:,:,1) > pt_threshold; % > 1 = 1161pts; > 2 = 472pts; Susan uses >2 ..work/global_thermal/matlab/plot_heat_content_map_durack.m
indpt_bad = double(indpt_bad); indpt_bad(indpt_bad == 1) = NaN; indpt_bad(indpt_bad == 0) = 1; % Use mean fields to determine errors
ind_bad   = indpt_bad;
disp(['Number of pt bad points (>',num2str(pt_threshold,'%2.1f'),'): ',num2str(sum(sum(sum((isnan(ind_bad))))))]);
% salinity
s_threshold = 0.4;
inds_bad  = s_chg_err(:,:,:,1) > s_threshold; % > 0.25 = 507pts; > 0.3 = 296pts; > 0.4 = 158pts; > 0.5 = 87pts
inds_bad  = double(inds_bad); inds_bad(inds_bad == 1) = NaN; inds_bad(inds_bad == 0) = 1; % Use mean fields to determine errors
ind_bad   = inds_bad;
disp(['Number of s  bad points (>',num2str(s_threshold,'%2.1f'),'): ',num2str(sum(sum(sum((isnan(ind_bad))))))]);
% density
g_threshold = 0.5;
indg_bad  = gamrf_chg_err(:,:,:,1) > g_threshold; % > 0.25 = 872pts; > 0.3 = 621pts; > 0.4 = 381pts; > 0.5 = 210pts
indg_bad  = double(indg_bad); indg_bad(indg_bad == 1) = NaN; indg_bad(indg_bad == 0) = 1; % Use mean fields to determine errors
ind_bad   = indg_bad;
disp(['Number of g  bad points (>',num2str(g_threshold,'%2.1f'),'): ',num2str(sum(sum(sum((isnan(ind_bad))))))]);
% Composite bad index - just pt and s
ind_bad   = indpt_bad.*inds_bad;
disp(['Number of total bad points    : ',num2str(sum(sum(sum((isnan(ind_bad))))))]);

% And mask data
pt_chg     = pt_chg.*ind_bad;
pt_mean    = pt_mean.*ind_bad;
s_chg      = s_chg.*ind_bad;
s_mean     = s_mean.*ind_bad;
gamrf_chg  = gamrf_chg.*ind_bad;
gamrf_mean = gamrf_mean.*ind_bad;

%% Infill all fields
load([homeDir,'code/make_basins.mat'], 'basins3_NaN_ones_2x1')
% Fix issue with mask
basins3_NaN_ones_2x1 = basins3_NaN_ones_2x1(:,1:180);
basins3_NaN_ones_2x1(:,1) = basins3_NaN_ones_2x1(:,2);
for x = 1:size(s_mean,3)
    pt_chg(:,:,x)     = inpaint_nans(pt_chg(:,:,x),2);
    pt_chg_err(:,:,x) = inpaint_nans(pt_chg_err(:,:,x),2);
    pt_mean(:,:,x)    = inpaint_nans(pt_mean(:,:,x),2);
    s_chg(:,:,x)      = inpaint_nans(s_chg(:,:,x),2);
    s_chg_err(:,:,x)  = inpaint_nans(s_chg_err(:,:,x),2);
    s_mean(:,:,x)     = inpaint_nans(s_mean(:,:,x),2);
    gamrf_chg(:,:,x)  = inpaint_nans(gamrf_chg(:,:,x),2);
    gamrf_chg_err(:,:,x) = inpaint_nans(gamrf_chg_err(:,:,x),2);
    gamrf_mean(:,:,x) = inpaint_nans(gamrf_mean(:,:,x),2);
end

% Smooth all fields
pt_chg = smooth3(pt_chg);
pt_chg_err = smooth3(pt_chg_err);
pt_mean = smooth3(pt_mean);
s_chg = smooth3(s_chg);
s_chg_err = smooth3(s_chg_err);
s_mean = smooth3(s_mean);
gamrf_chg = smooth3(gamrf_chg);
gamrf_chg_err = smooth3(gamrf_chg_err);
gamrf_mean = smooth3(gamrf_mean);

% Cookie cut out land/marginal seas mask
for x = 1:size(s_mean,3)
    pt_chg(:,:,x) = pt_chg(:,:,x).*basins3_NaN_ones_2x1';
    pt_chg_err(:,:,x) = pt_chg_err(:,:,x).*basins3_NaN_ones_2x1';
    pt_mean(:,:,x) = pt_mean(:,:,x).*basins3_NaN_ones_2x1';
    s_chg(:,:,x) = s_chg(:,:,x).*basins3_NaN_ones_2x1';
    s_chg_err(:,:,x) = s_chg_err(:,:,x).*basins3_NaN_ones_2x1';
    s_mean(:,:,x) = s_mean(:,:,x).*basins3_NaN_ones_2x1';
    gamrf_chg(:,:,x) = gamrf_chg(:,:,x).*basins3_NaN_ones_2x1';
    gamrf_chg_err(:,:,x) = gamrf_chg_err(:,:,x).*basins3_NaN_ones_2x1';
    gamrf_mean(:,:,x) = gamrf_mean(:,:,x).*basins3_NaN_ones_2x1';
end

lon = xi; clear xi
lat = yi; clear yi
depth = pressure_levels(1:z_lvl); clear pressure_levels

%% Deal with topography (mask seafloor regions)
infile_bath     = '/work/durack1/csiro/eez_data/bath/gebco08_1min.nc';
bath            = getnc(infile_bath,'height');
grid_spacing    = getnc(infile_bath,'grid_spacing');
bath_lon_range  = getnc(infile_bath,'lon_range');
bath_lon        = [bath_lon_range(1):grid_spacing(1):bath_lon_range(2),bath_lon_range(2)];
bath_lat_range  = getnc(infile_bath,'lat_range');
bath_lat        = [bath_lat_range(1):grid_spacing(2):bath_lat_range(2),bath_lat_range(2)];
bath            = interp2(bath_lon,bath_lat,bath,lon',lat)';
% Set limit of 2000m and mask
bath(bath > 0 | bath < -2000) = NaN;
for x = 1:length(lon)
    for y = 1:length(lat)
        if isnan(bath(x,y))
            continue
        else
            % Find depth index
            depth_bath    = -bath(x,y);
            [~,depth_ind] = min(abs(depth-depth_bath));
            if depth(depth_ind) < depth_bath; depth_ind = depth_ind+1; deeper = 1; else deeper = 0; end
            % Check limits - write to screen
            %disp(['depth, bath, depth_above ',num2str(depth(depth_ind),'%04d'),' ',num2str(round(depth_bath),'%04d'), ...
            %      ' ',num2str(depth(depth_ind-1),'%04d'),' deeper: ',num2str(deeper)])
            % Mask values beneath resolved bathymetry
            pt_chg(x,y,depth_ind:end)        = NaN;
            pt_chg_err(x,y,depth_ind:end)    = NaN;
            pt_mean(x,y,depth_ind:end)       = NaN;
            s_chg(x,y,depth_ind:end)         = NaN;
            s_chg_err(x,y,depth_ind:end)     = NaN;
            s_mean(x,y,depth_ind:end)        = NaN;
            gamrf_chg(x,y,depth_ind:end)     = NaN;
            gamrf_chg_err(x,y,depth_ind:end) = NaN;
            gamrf_mean(x,y,depth_ind:end)    = NaN;
        end
    end
end

%% Create near-surface salinity contrast diagnostic
% Generate masks and near-surface fields
[~,~,areaKm2] = area_weight(lon,lat);
areaKm2Masked = areaKm2.*basins3_NaN_ones_2x1';
areaKm2MaskedSum = nansum(nansum(areaKm2Masked));
nearSurfMeanSalinity = squeeze(s_mean(:,:,1));
nearSurfChgSalinity = squeeze(s_chg(:,:,1));
% Generate weighted and unweighted numbers
nearSurfMeanSalinityUnwt = nanmean(nanmean(nearSurfMeanSalinity));
nearSurfMeanSalinityWt = nansum(nansum(nearSurfMeanSalinity.*areaKm2Masked))/areaKm2MaskedSum;
% Generate masks using weighted mean
nearSurfLowSalinityMask = nearSurfMeanSalinity < nearSurfMeanSalinityWt;
nearSurfLowSalinityMask = double(nearSurfLowSalinityMask); nearSurfLowSalinityMask(nearSurfLowSalinityMask == 0) = NaN;
nearSurfHighSalinityMask = nearSurfMeanSalinity > nearSurfMeanSalinityWt;
nearSurfHighSalinityMask = double(nearSurfHighSalinityMask); nearSurfHighSalinityMask(nearSurfHighSalinityMask == 0) = NaN;
% Weight masked low/high areas
areaKm2HighMasked = areaKm2.*nearSurfHighSalinityMask;
areaKm2LowMasked = areaKm2.*nearSurfLowSalinityMask;
% Using weights calculate low/high from near-surface change fields
areaKm2LowMaskedSum = nansum(nansum(areaKm2LowMasked));
nearSurfLowChgSalinity = nearSurfChgSalinity.*areaKm2LowMasked;
nearSurfLowSalinityWt = nansum(nansum(nearSurfLowChgSalinity))/areaKm2LowMaskedSum;
areaKm2HighMaskedSum = nansum(nansum(areaKm2HighMasked));
nearSurfHighChgSalinity = nearSurfChgSalinity.*areaKm2HighMasked;
nearSurfHighSalinityWt = nansum(nansum(nearSurfHighChgSalinity))/areaKm2HighMaskedSum;
% Report
disp(['infile: ',infile])
disp(['times: ',timeStart,' to ',timeStop])
disp(['Mean salinity:              ',num2str(nearSurfMeanSalinityWt,'%+7.3f')])
disp(['Mean salinity (Unweighted): ',num2str(nearSurfMeanSalinityUnwt,'%+7.3f')])
disp(['low salinity chg (wt''d):                   ',num2str(nearSurfLowSalinityWt,'%+8.4f')])
disp(['high salinity chg (wt''d):                  ',num2str(nearSurfHighSalinityWt,'%+8.4f')])
disp(['salinity contrast chg (wt''d):              ',num2str((nearSurfHighSalinityWt-nearSurfLowSalinityWt),'%+8.4f')])
if contains(infile,'_200913_')
    disp(['salinity contrast chg (wt''d) 59yrs:        ',num2str((nearSurfHighSalinityWt-nearSurfLowSalinityWt)*(59/50),'%+8.4f')])
else
    disp(['salinity contrast chg (wt''d) decade-1:     ',num2str((nearSurfHighSalinityWt-nearSurfLowSalinityWt)/((2020-1950)/10),'%+8.4f')])
end
% Plots for region validation
%{
nearSurfHighSalinityMaskSum = nansum(nansum(areaKm2.*nearSurfHighSalinityMask));
nearSurfHighSalinityMaskSumArr = areaKm2.*nearSurfHighSalinityMask;
figure(1); clf, pcolor(lon,lat,(nearSurfHighSalinityMaskSumArr/nearSurfHighSalinityMaskSum)'); shading flat, continents, colorbar
nearSurfLowSalinityMaskSum = nansum(nansum(areaKm2.*nearSurfLowSalinityMask));
nearSurfLowSalinityMaskSumArr = areaKm2.*nearSurfLowSalinityMask;
figure(2); clf ,pcolor(lon,lat,(nearSurfLowSalinityMaskSumArr/nearSurfLowSalinityMaskSum)'); shading flat, continents, colorbar
%}

%% Now create netcdf outFile
if writeFile
    ncid = netcdf.create(outFile,'NC_NOCLOBBER');

    % Initialise dimensions
    dimIdTime   = netcdf.defDim(ncid,'time',1);
    dimIdDepth  = netcdf.defDim(ncid,'depth',length(depth));
    dimIdLat    = netcdf.defDim(ncid,'latitude',length(lat));
    dimIdLon    = netcdf.defDim(ncid,'longitude',length(lon));
    dimIdBnds   = netcdf.defDim(ncid,'bounds',2);

    % Initialise variables
    % Time
    timeId = netcdf.defVar(ncid,'time','double',dimIdTime);
    netcdf.putAtt(ncid,timeId,'climatology','climatology_bounds')
    netcdf.putAtt(ncid,timeId,'units',['days since ',climBndsStart])
    netcdf.putAtt(ncid,timeId,'calendar','gregorian')
    netcdf.putAtt(ncid,timeId,'long_name','time')
    netcdf.putAtt(ncid,timeId,'standard_name','time')
    netcdf.putAtt(ncid,timeId,'axis','T')

    % Depth
    depthId = netcdf.defVar(ncid,'depth','double',dimIdDepth);
    netcdf.putAtt(ncid,depthId,'units','decibar')
    netcdf.putAtt(ncid,depthId,'units_long','decibar (pressure)')
    netcdf.putAtt(ncid,depthId,'long_name','sea_water_pressure')
    netcdf.putAtt(ncid,depthId,'standard_name','sea_water_pressure')
    %netcdf.putAtt(ncid,depthId,'units','m')
    %netcdf.putAtt(ncid,depthId,'units_long','meters')
    %netcdf.putAtt(ncid,depthId,'long_name','depth')
    %netcdf.putAtt(ncid,depthId,'standard_name','depth')
    netcdf.putAtt(ncid,depthId,'axis','Z')
    netcdf.putAtt(ncid,depthId,'positive','down')
    netcdf.putAtt(ncid,depthId,'bounds','depth_bnds')

    % Latitude
    latId = netcdf.defVar(ncid,'latitude','double',dimIdLat);
    netcdf.putAtt(ncid,latId,'units','degrees_north')
    netcdf.putAtt(ncid,latId,'long_name','latitude')
    netcdf.putAtt(ncid,latId,'standard_name','latitude')
    netcdf.putAtt(ncid,latId,'axis','Y')
    netcdf.putAtt(ncid,latId,'bounds','lat_bnds');

    % Longitude
    lonId = netcdf.defVar(ncid,'longitude','double',dimIdLon);
    netcdf.putAtt(ncid,lonId,'units','degrees_east')
    netcdf.putAtt(ncid,lonId,'long_name','longitude')
    netcdf.putAtt(ncid,lonId,'standard_name','longitude')
    netcdf.putAtt(ncid,lonId,'axis','X')
    netcdf.putAtt(ncid,lonId,'bounds','lon_bnds');

    % Bounds
    timebndsId = netcdf.defVar(ncid,'climatology_bounds','double',[dimIdBnds,dimIdTime]);
    depthbndsId = netcdf.defVar(ncid,'depth_bnds','double',[dimIdBnds,dimIdDepth]);
    latbndsId = netcdf.defVar(ncid,'lat_bnds','double',[dimIdBnds,dimIdLat]);
    lonbndsId = netcdf.defVar(ncid,'lon_bnds','double',[dimIdBnds,dimIdLon]);

    % Variables
    var_pt_mean_id = netcdf.defVar(ncid,'thetao_mean','float',[dimIdLon,dimIdLat,dimIdDepth,dimIdTime]);
    netcdf.putAtt(ncid,var_pt_mean_id,'units','degree_C')
    netcdf.putAtt(ncid,var_pt_mean_id,'long_name',['Potential Temperature mean ',timeWindow])
    netcdf.putAtt(ncid,var_pt_mean_id,'standard_name','sea_water_potential_temperature')
    netcdf.putAtt(ncid,var_pt_mean_id,'_FillValue',single(1.0e+20))
    netcdf.putAtt(ncid,var_pt_mean_id,'missing_value',single(1.0e+20))
    netcdf.putAtt(ncid,var_pt_mean_id,'valid_range',single([-2 35]))
    netcdf.putAtt(ncid,var_pt_mean_id,'comment',[['Error threshold: ',num2str(pt_threshold,'%2.1f'),10], ...
        ['Mean calculated over period: ',climBndsStart,' to ',climBndsEnd]])
    var_pt_chg_id = netcdf.defVar(ncid,'thetao_change','float',[dimIdLon,dimIdLat,dimIdDepth,dimIdTime]);
    netcdf.putAtt(ncid,var_pt_chg_id,'units',['degree_C/',timeYrs])
    netcdf.putAtt(ncid,var_pt_chg_id,'long_name',['Potential Temperature change ',timeWindow])
    netcdf.putAtt(ncid,var_pt_chg_id,'standard_name','change_over_time_in_sea_water_potential_temperature')
    netcdf.putAtt(ncid,var_pt_chg_id,'_FillValue',single(1.0e+20))
    netcdf.putAtt(ncid,var_pt_chg_id,'missing_value',single(1.0e+20))
    netcdf.putAtt(ncid,var_pt_chg_id,'valid_range',single([-2 2]))
    netcdf.putAtt(ncid,var_pt_chg_id,'comment',['Error threshold: ',num2str(pt_threshold,'%2.1f')])
    var_pt_chg_err_id = netcdf.defVar(ncid,'thetao_change_error','float',[dimIdLon,dimIdLat,dimIdDepth,dimIdTime]);
    netcdf.putAtt(ncid,var_pt_chg_err_id,'units',['degree_C/',timeYrs])
    netcdf.putAtt(ncid,var_pt_chg_err_id,'long_name',['Potential Temperature change error ',timeWindow])
    netcdf.putAtt(ncid,var_pt_chg_err_id,'standard_name','change_over_time_in_sea_water_potential_temperature_error')
    netcdf.putAtt(ncid,var_pt_chg_err_id,'_FillValue',single(1.0e+20))
    netcdf.putAtt(ncid,var_pt_chg_err_id,'missing_value',single(1.0e+20))
    netcdf.putAtt(ncid,var_pt_chg_err_id,'comment','  ')
    var_s_mean_id = netcdf.defVar(ncid,'salinity_mean','float',[dimIdLon,dimIdLat,dimIdDepth,dimIdTime]);
    netcdf.putAtt(ncid,var_s_mean_id,'units','1e-3')
    netcdf.putAtt(ncid,var_s_mean_id,'units_long','PSS-78')
    netcdf.putAtt(ncid,var_s_mean_id,'long_name',['Salinity mean ',timeWindow])
    netcdf.putAtt(ncid,var_s_mean_id,'standard_name','sea_water_practical_salinity')
    netcdf.putAtt(ncid,var_s_mean_id,'standard_name','sea_water_salinity')
    netcdf.putAtt(ncid,var_s_mean_id,'_FillValue',single(1.0e+20))
    netcdf.putAtt(ncid,var_s_mean_id,'missing_value',single(1.0e+20))
    netcdf.putAtt(ncid,var_s_mean_id,'valid_range',single([6 42]))
    netcdf.putAtt(ncid,var_s_mean_id,'comment',[['Error threshold: ',num2str(s_threshold,'%2.1f'),10], ...
        ['Mean calculated over period: ',climBndsStart,' to ',climBndsEnd]])
    var_s_chg_id = netcdf.defVar(ncid,'salinity_change','float',[dimIdLon,dimIdLat,dimIdDepth,dimIdTime]);
    netcdf.putAtt(ncid,var_s_chg_id,'units',['1e-3/',timeYrs])
    netcdf.putAtt(ncid,var_s_chg_id,'units_long',['PSS-78/',timeYrs])
    netcdf.putAtt(ncid,var_s_chg_id,'long_name',['Salinity change ',timeWindow])
    netcdf.putAtt(ncid,var_s_chg_id,'standard_name','change_over_time_in_sea_water_practical_salinity')
    netcdf.putAtt(ncid,var_s_chg_id,'standard_name','change_over_time_in_sea_water_salinity')
    netcdf.putAtt(ncid,var_s_chg_id,'_FillValue',single(1.0e+20))
    netcdf.putAtt(ncid,var_s_chg_id,'missing_value',single(1.0e+20))
    netcdf.putAtt(ncid,var_s_chg_id,'valid_range',single([-1 1]))
    netcdf.putAtt(ncid,var_s_chg_id,'comment',['Error threshold: ',num2str(s_threshold,'%2.1f')])
    var_s_chg_err_id = netcdf.defVar(ncid,'salinity_change_error','float',[dimIdLon,dimIdLat,dimIdDepth,dimIdTime]);
    netcdf.putAtt(ncid,var_s_chg_err_id,'units',['1e-3/',timeYrs])
    netcdf.putAtt(ncid,var_s_chg_err_id,'units_long',['PSS-78/',timeYrs])
    netcdf.putAtt(ncid,var_s_chg_err_id,'long_name',['Salinity change error ',timeWindow])
    netcdf.putAtt(ncid,var_s_chg_err_id,'standard_name','change_over_time_in_sea_water_practical_salinity_error')
    netcdf.putAtt(ncid,var_s_chg_err_id,'_FillValue',single(1.0e+20))
    netcdf.putAtt(ncid,var_s_chg_err_id,'missing_value',single(1.0e+20))
    netcdf.putAtt(ncid,var_s_chg_err_id,'comment','  ')
    if include_density
        var_g_mean_id = netcdf.defVar(ncid,'density_mean','float',[dimIdLon,dimIdLat,dimIdDepth,dimIdTime]);
        netcdf.putAtt(ncid,var_g_mean_id,'units','kg m-3')
        netcdf.putAtt(ncid,var_g_mean_id,'units_long','kg m-3')
        netcdf.putAtt(ncid,var_g_mean_id,'long_name',['Neutral Density mean ',timeWindow])
        netcdf.putAtt(ncid,var_g_mean_id,'standard_name','sea_water_neutral_density')
        netcdf.putAtt(ncid,var_g_mean_id,'_FillValue',single(1.0e+20))
        netcdf.putAtt(ncid,var_g_mean_id,'missing_value',single(1.0e+20))
        netcdf.putAtt(ncid,var_g_mean_id,'valid_range',single([6 42]))
        netcdf.putAtt(ncid,var_g_mean_id,'comment',[['Error threshold: ',num2str(g_threshold,'%2.1f'),10], ...
            ['Mean calculated over period: ',climBndsStart,' to ',climBndsEnd]])
        var_g_chg_id = netcdf.defVar(ncid,'density_change','float',[dimIdLon,dimIdLat,dimIdDepth,dimIdTime]);
        netcdf.putAtt(ncid,var_g_chg_id,'units',['kg m-3/',timeYrs])
        netcdf.putAtt(ncid,var_g_chg_id,'units_long',['kg m-3/',timeYrs])
        netcdf.putAtt(ncid,var_g_chg_id,'long_name',['Density change ',timeWindow])
        netcdf.putAtt(ncid,var_g_chg_id,'standard_name','change_over_time_in_sea_water_neutral_density')
        netcdf.putAtt(ncid,var_g_chg_id,'_FillValue',single(1.0e+20))
        netcdf.putAtt(ncid,var_g_chg_id,'missing_value',single(1.0e+20))
        netcdf.putAtt(ncid,var_g_chg_id,'valid_range',single([-1 1]))
        netcdf.putAtt(ncid,var_g_chg_id,'comment','  ')
        var_g_chg_err_id = netcdf.defVar(ncid,'density_change_error','float',[dimIdLon,dimIdLat,dimIdDepth,dimIdTime]);
        netcdf.putAtt(ncid,var_g_chg_err_id,'units',['kg m-3/',timeYrs])
        netcdf.putAtt(ncid,var_g_chg_err_id,'units_long',['kg m-3/',timeYrs])
        netcdf.putAtt(ncid,var_g_chg_err_id,'long_name',['Density change error ',timeWindow])
        netcdf.putAtt(ncid,var_g_chg_err_id,'standard_name','change_over_time_in_sea_water_neutral_density_error')
        netcdf.putAtt(ncid,var_g_chg_err_id,'_FillValue',single(1.0e+20))
        netcdf.putAtt(ncid,var_g_chg_err_id,'missing_value',single(1.0e+20))
        netcdf.putAtt(ncid,var_g_chg_err_id,'comment','  ')
    end

    % Global attributes
    attIdGlobal = netcdf.getConstant('NC_GLOBAL');
    netcdf.putAtt(ncid,attIdGlobal,'Conventions','CF-1.7');
    netcdf.putAtt(ncid,attIdGlobal,'title',['Observed Global Ocean property changes for the 20th and 21st Centuries ',timeWindow]);
    netcdf.putAtt(ncid,attIdGlobal,'institution','Program for Climate Model Diagnosis and Intercomparison, LLNL, Livermore, CA, USA');
    netcdf.putAtt(ncid,attIdGlobal,'version','1.1.0; Beta - pre-release data');
    netcdf.putAtt(ncid,attIdGlobal,'contact',['Paul J. Durack; pauldurack@llnl.gov (',username,'); +1 925 422 5208']);
    netcdf.putAtt(ncid,attIdGlobal,'datafile',char(a_infile));
    netcdf.putAtt(ncid,attIdGlobal,'datafile_md5',char(a_infileMd5));
    netcdf.putAtt(ncid,attIdGlobal,'datafile_modTime',char(a_infileModify));
    netcdf.putAtt(ncid,attIdGlobal,'sourcefile',infile);
    % Validate through md5
    [~,infileMd5Str] = unix(['/usr/bin/md5sum ',infile]);
    infileMd5 = strsplit(infileMd5Str,' ');
    netcdf.putAtt(ncid,attIdGlobal,'sourcefile_md5',char(infileMd5(1)));
    % fix a_script_name
    a_script_name = strrep(a_script_name,'//','/');
    a_gitHash = ['github.com/durack1/oceanObs/commit/',a_gitHash];
    netcdf.putAtt(ncid,attIdGlobal,'sourcefile_atts',[['script_name: ',a_script_name,10], ...
        ['git_hash: ',a_gitHash,10], ...
        ['host_longname: ',a_host_longname,10], ...
        ['matlab_version: ',a_matlab_version,10], ...
        ['start_time: ',a_script_start_time,10], ...
        ['process_time: ',num2str(a_file_process_time)]]);
    [~,timestr] = unix('date --utc +%d-%b-%Y\ %X');
    netcdf.putAtt(ncid,attIdGlobal,'history',[regexprep(timestr,'\r\n|\n|\r',''),' UTC; Livermore, California, USA']);
    hoststr = [aHostLongname,'; Matlab Version: ',version];
    netcdf.putAtt(ncid,attIdGlobal,'host',hoststr);
    netcdf.putAtt(ncid,attIdGlobal,'Reference','Durack P.J. & S.E. Wijffels (2010) Fifty-Year Trends in Global Ocean Salinities and their Relationship to Broadscale Warming. Journal of Climate, 23, 4342-4362');
    netcdf.putAtt(ncid,attIdGlobal,'Reference_doi','http://doi.org/10.1175/2010JCLI3377.1');
    netcdf.putAtt(ncid,attIdGlobal,'Reference_www','http://www.cmar.csiro.au/oceanchange/');
    netcdf.endDef(ncid); % Leave define and enter data mode

    % Write out data to file
    % Dimensions
    netcdf.putVar(ncid,timeId,time)
    netcdf.putVar(ncid,lonId,lon)
    netcdf.putVar(ncid,latId,lat)
    netcdf.putVar(ncid,depthId,depth);

    % Bnds
    netcdf.putVar(ncid,timebndsId,climatology_bnds);
    netcdf.putVar(ncid,depthbndsId,depth_bnds');
    netcdf.putVar(ncid,latbndsId,lat_bnds');
    netcdf.putVar(ncid,lonbndsId,lon_bnds');

    % Variables
    % s_mean
    var_out = single(s_mean); % Float conversion
    var_out(isnan(var_out)) = single(1.0e+20); % NaN->Float conversion
    netcdf.putVar(ncid,var_s_mean_id,var_out)
    % s_chg
    var_out = single(s_chg); % Float conversion
    var_out(isnan(var_out)) = single(1.0e+20); % NaN->Float conversion
    netcdf.putVar(ncid,var_s_chg_id,var_out)
    % s_chg_err
    var_out = single(s_chg_err); % Float conversion
    var_out(isnan(var_out)) = single(1.0e+20); % NaN->Float conversion
    netcdf.putVar(ncid,var_s_chg_err_id,var_out)
    % pt_mean
    var_out = single(pt_mean); % Float conversion
    var_out(isnan(var_out)) = single(1.0e+20); % NaN->Float conversion
    netcdf.putVar(ncid,var_pt_mean_id,var_out)
    % pt_chg
    var_out = single(pt_chg); % Float conversion
    var_out(isnan(var_out)) = single(1.0e+20); % NaN->Float conversion
    netcdf.putVar(ncid,var_pt_chg_id,var_out)
    % pt_chg_err
    var_out = single(pt_chg_err); % Float conversion
    var_out(isnan(var_out)) = single(1.0e+20); % NaN->Float conversion
    netcdf.putVar(ncid,var_pt_chg_err_id,var_out)
    % gamrf_mean
    if include_density
        var_out = single(gamrf_mean); % Float conversion
        var_out(isnan(var_out)) = single(1.0e+20); % NaN->Float conversion
        netcdf.putVar(ncid,var_g_mean_id,var_out)
        % gamrf_chg
        var_out = single(gamrf_chg); % Float conversion
        var_out(isnan(var_out)) = single(1.0e+20); % NaN->Float conversion
        netcdf.putVar(ncid,var_g_chg_id,var_out)
        % gamrf_chg_err
        var_out = single(gamrf_chg_err); % Float conversion
        var_out(isnan(var_out)) = single(1.0e+20); % NaN->Float conversion
        netcdf.putVar(ncid,var_g_chg_err_id,var_out)
    end
    netcdf.close(ncid)
end %if writeFile

% Check validity of output data
%{
% Use CSIRO matlab interface
clear,close all,clc
so_mean_csiro = getnc('DurackandWijffels_GlobalOceanChanges_1950-2000.nc','salinity_mean');
thetao_mean_csiro = getnc('DurackandWijffels_GlobalOceanChanges_1950-2000.nc','thetao_mean');
%ncid = netcdf.open('DurackandWijffels_GlobalOceanChanges_1950-2000.nc','NC_NOWRITE');
%[varname,xtype,dimids,natts] = netcdf.inqVar(ncid,varid);
%so_varid = netcdf.inqVarID(ncid,'salinity_mean');
%so_mean = netcdf.getVar(ncid,so_varid);
%thetao_varid = netcdf.inqVarID(ncid,'thetao_mean');
%thetao_mean = netcdf.getVar(ncid,thetao_varid);
%netcdf.close(ncid);
lat = getnc('DurackandWijffels_GlobalOceanChanges_1950-2000.nc','lat');
lon = getnc('DurackandWijffels_GlobalOceanChanges_1950-2000.nc','lon');
figure(1),clf,contourf(lon,lat,squeeze(so_mean_csiro(1,:,:)),50); caxis([33 37]), colorbar, title('so\_mean')
figure(2),clf,contourf(lon,lat,squeeze(thetao_mean_csiro(1,:,:)),50); caxis([0 30]), colorbar, title('thetao\_mean')
% Check precision problems
var_out = single(s_mean); % Float conversion
var_out(isnan(var_out)) = single(1.0e+20); % NaN->Float conversion
%netcdf.putVar(ncid,var_s_mean_id,var_out)
var_out_test = var_out;
var_out_test(var_out_test > 1.0e+10) = NaN;
figure(3),clf,contourf(var_out_test(:,:,1)',50); caxis([33 37]), colorbar, title('var_out_test')
%}