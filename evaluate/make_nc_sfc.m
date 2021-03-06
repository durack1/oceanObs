% Write results out to netcdf format
% Paul J. Durack 4 November 2009

% This script exports resolved ocean change fields to netcdf

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
% PJD 12 Oct 2010   - Renamed file to make_nc_sfc.m (was make_nc.m) and updated to surface only outputs
% PJD 12 Oct 2010   - Added using error estimates to mask bad mean and change data, without this masking mean fields in particular have hotspots
% PJD  7 Apr 2011   - Updated time/history attribute
% PJD  7 Apr 2011   - Used error estimates to mask bad mean and change data, without this masking mean fields in particular have hotspots
%                     Consult make_nc.m and ../100520_PaperPlots_Halosteric/make_paperplots (Fig2) ../110323_IMOS/make_paperplots.m for tips and limits
% PJD  7 Apr 2011   - Added comment attribute for variables, which includes error mask threshold used to generate data
% PJD  7 Apr 2011   - Removed longitude duplication (0 & 360) in observed data - fixed problem with basins3_NaN_ones_2x1 variable
% PJD  7 Apr 2011   - Requested new '*_change' standard names
% PJD  7 Apr 2011   - Updated for correct outvars for myMatEnv (clim_dir)
%
% PJD 22 Jun 2011   - Updated following updated applied to make_nc.m
% PJD 22 Jun 2011   - Updated outfile to just *_beta.nc (removed datestamp)
% PJD 22 Jun 2011   - Updated some hard-coded entries to use standard_names and time* variables
% PJD  1 Aug 2011   - Updated "pressure" standard_name to "sea_water_pressure"
% PJD  1 Aug 2011   - Updated change_in* to change_over_time_in*
% PJD  2 Aug 2011   - Updated salinity standard_name to "sea_water_practical_salinity"
% TODO Internal:
% PJD  2 Aug 2011   - TODO: Address issues suggested by CF-1.5 compliance checkers: http://cf-pcmdi.llnl.gov/conformance/compliance-checker/
% PJD  2 Aug 2011   - TODO: Updated valid_ranges, and info about density = neutral density (kg m-3 minus 1000)
% PJD  2 Aug 2011   - TODO: Resolve time coords (climatology, CF-1.4 chap7.9), resolve depth or pressure as z-coord (CF-1.4 chap4.3)
% PJD  2 Aug 2011   - TODO: Generate density data output too? - Convert to gamma n (Paul B's software?)
% PJD  2 Aug 2011   - TODO: Consider data packing/compression http://nco.sourceforge.net/nco.html#Packed-data
% PJD  2 Aug 2011   - TODO: Consider adding comment global att, which can contain more info than name
% PJD  2 Aug 2011   - TODO: Consider time_bnds for climatology and temporal data - http://cf-pcmdi.llnl.gov/documents/cf-conventions/1.4/ch07s04.html
%}
% PJD 10 Jan 2021   - Copied from /work/durack1/csiro/Backup/110808/Z_dur041_linux/Shared/090605_FLR2_sptg/make_nc_sfc.m (110801)
%                     and updated input

% make_nc_sfc.m

%% Cleanup workspace and command window
% Initialise environment variables - only homeDir needed for file cleanups
%[homeDir,work_dir,data_dir,obsDir,username,a_host_longname,a_maxThreads,a_opengl,a_matver] = myMatEnv(maxThreads);
[homeDir,~,~,obsDir,username,~,~,~,~] = myMatEnv(2);
archiveDir = [homeDir,'090605_FLR2_sptg/'];
if ~sum(strcmp(username,{'dur041','duro','durack1'})); disp('**myMatEnv - username error**'); keyboard; end

%% If running through entire script cleanup export files
data_dir = os_path('090605_FLR2_sptg/');
include_temp = 1; include_density = 0;
data_infile = '090605_190300_local_robust_1950_FLRdouble_sptg_79pres1000_v7.mat';
infile = [home_dir,data_dir,data_infile];
outfile = ([home_dir,data_dir,'DurackandWijffels_GlobalOceanSurfaceChanges_1950-2000_beta.nc']); % Finalised file
%outfile = ([home_dir,data_dir,'DurackandWijffels_GlobalOceanSurfaceChanges_1950-2000_',regexprep([datestr(now,11),datestr(now,5),datestr(now,7),'_',datestr(now,13)],':','_'),'_beta.nc']);
disp('* Are you sure you want to purge exported *.nc files? *'); keyboard
delete([home_dir,data_dir,'Durack*GlobalOceanSurfaceChanges*2000_beta.nc']);
delete([home_dir,data_dir,'Durack*GlobalOceanSurfaceChanges*',[datestr(now,11),datestr(now,5),datestr(now,7)],'*.nc']);

%% Create strings for data labels
timeyrs     = '50yrs';
timewindow  = '1950-2000';
timeend     = '2009-04-04';

%% Load input data
load(infile, ...
     'a_file_process_time','a_host_longname','a_matlab_version','a_script_name','a_script_start_time', ...
     'pressure_levels','ptc','ptce','ptmean','sc','sce','smean','gamrfc','gamrfce','gamrfmean','xi','yi'); %, ...
     %'sxdatscale','sydatscale');

% Smooth fields, truncate values beneath 2000db, trim off duplicate longitude and prepare for output
% Fix longitude duplication
xi = xi(1:180);
% Set level at 2000db (66) or surface (1)
z_lvl = 1; depth = pressure_levels(1:z_lvl);
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
climatology_bnds = datenum({'1950-1-1','1999-12-31'}); % bounds of change climatology
time = mean(([climatology_bnds(1),climatology_bnds(2)]))-datenum('1950-1-1'); % middle day of middle year
climatology_bnds = climatology_bnds-datenum('1950-1-1');
climatology_bnds_mean = datenum({'1950-1-1','2009-04-04'}); % bounds of mean climatology
time_mean = mean(([climatology_bnds_mean(1),climatology_bnds_mean(2)]))-datenum('1950-1-1');
climatology_bnds_mean = climatology_bnds_mean-datenum('1950-1-1');

% Depth
depth_bnds  = NaN(1:length(depth),2);
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
end; % [depth_bnds(:,1),depth,depth_bnds(:,2)]

% Latitude
lat_bnds  = NaN(1:length(yi),2);
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
end; % [lat_bnds(:,1),yi',lat_bnds(:,2)]

% Longitude
lon_bnds  = NaN(1:length(xi),2);
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
end; %[lon_bnds(:,1),xi',lon_bnds(:,2)]

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

% Infill all fields
pt_chg          = inpaint_nans(pt_chg,2);
pt_chg_err      = inpaint_nans(pt_chg_err,2);
pt_mean         = inpaint_nans(pt_mean,2);
s_chg           = inpaint_nans(s_chg,2);
s_chg_err       = inpaint_nans(s_chg_err,2);
s_mean          = inpaint_nans(s_mean,2);

% Smooth all fields and cookie cut out land/marginal seas mask
load([home_dir,'code/make_basins.mat'], 'basins3_NaN_ones_2x1')
% Fix issue with mask
basins3_NaN_ones_2x1 = basins3_NaN_ones_2x1(:,1:180);
basins3_NaN_ones_2x1(:,1) = basins3_NaN_ones_2x1(:,2);
pt_chg          = smooth3(repmat(pt_chg,[1 1 2]));          pt_chg = pt_chg(:,:,1).*basins3_NaN_ones_2x1';
pt_chg_err      = smooth3(repmat(pt_chg_err,[1 1 2]));      pt_chg_err = pt_chg_err(:,:,1).*basins3_NaN_ones_2x1';
pt_mean         = smooth3(repmat(pt_mean,[1 1 2]));         pt_mean = pt_mean(:,:,1).*basins3_NaN_ones_2x1';
s_chg           = smooth3(repmat(s_chg,[1 1 2]));           s_chg = s_chg(:,:,1).*basins3_NaN_ones_2x1';
s_chg_err       = smooth3(repmat(s_chg_err,[1 1 2]));       s_chg_err = s_chg_err(:,:,1).*basins3_NaN_ones_2x1';
s_mean          = smooth3(repmat(s_mean,[1 1 2]));          s_mean = s_mean(:,:,1).*basins3_NaN_ones_2x1';

lon = xi; clear xi
lat = yi; clear yi
depth = pressure_levels(1:z_lvl); clear pressure_levels

%% Now create netcdf outfile
ncid = netcdf.create(outfile,'NC_NOCLOBBER');

% Initialise dimensions
dimIdTime   = netcdf.defDim(ncid,'time',1);
dimIdDepth  = netcdf.defDim(ncid,'depth',length(depth));
dimIdLat    = netcdf.defDim(ncid,'latitude',length(lat));
dimIdLon    = netcdf.defDim(ncid,'longitude',length(lon));
dimIdBnds   = netcdf.defDim(ncid,'bounds',2);

% Initialise variables
% Time
timeId = netcdf.defVar(ncid,'time','double',dimIdTime);
netcdf.putatt(ncid,timeId,'climatology','climatology_bounds')
netcdf.putatt(ncid,timeId,'units','days since 1950-1-1')
netcdf.putatt(ncid,timeId,'calendar','gregorian')
netcdf.putatt(ncid,timeId,'long_name','time')
netcdf.putatt(ncid,timeId,'standard_name','time')
netcdf.putatt(ncid,timeId,'axis','T')

% Depth
depthId = netcdf.defVar(ncid,'depth','double',dimIdDepth);
netcdf.putatt(ncid,depthId,'units','decibar')
netcdf.putatt(ncid,depthId,'units_long','decibar (pressure)')
netcdf.putatt(ncid,depthId,'long_name','sea_water_pressure')
netcdf.putatt(ncid,depthId,'standard_name','sea_water_pressure')
%netcdf.putatt(ncid,depthId,'units','m')
%netcdf.putatt(ncid,depthId,'units_long','meters')
%netcdf.putatt(ncid,depthId,'long_name','depth')
%netcdf.putatt(ncid,depthId,'standard_name','depth')
netcdf.putatt(ncid,depthId,'axis','Z')
netcdf.putatt(ncid,depthId,'positive','down')
netcdf.putatt(ncid,depthId,'bounds','depth_bnds')

% Latitude
latId = netcdf.defVar(ncid,'latitude','double',dimIdLat);
netcdf.putatt(ncid,latId,'units','degrees_north')
netcdf.putatt(ncid,latId,'long_name','latitude')
netcdf.putatt(ncid,latId,'standard_name','latitude')
netcdf.putatt(ncid,latId,'axis','Y')
netcdf.putatt(ncid,latId,'bounds','lat_bnds');

% Longitude
lonId = netcdf.defVar(ncid,'longitude','double',dimIdLon);
netcdf.putatt(ncid,lonId,'units','degrees_east')
netcdf.putatt(ncid,lonId,'long_name','longitude')
netcdf.putatt(ncid,lonId,'standard_name','longitude')
netcdf.putatt(ncid,lonId,'axis','X')
netcdf.putatt(ncid,lonId,'bounds','lon_bnds');

% Bounds
timebndsId = netcdf.defVar(ncid,'climatology_bounds','double',[dimIdBnds,dimIdTime]);
depthbndsId = netcdf.defVar(ncid,'depth_bnds','double',[dimIdBnds,dimIdDepth]);
latbndsId = netcdf.defVar(ncid,'lat_bnds','double',[dimIdBnds,dimIdLat]);
lonbndsId = netcdf.defVar(ncid,'lon_bnds','double',[dimIdBnds,dimIdLon]);

% Variables
if include_temp
    var_pt_mean_id = netcdf.defVar(ncid,'thetao_mean','float',[dimIdLon,dimIdLat,dimIdDepth,dimIdTime]);
    netcdf.putatt(ncid,var_pt_mean_id,'units','degree_C')
    netcdf.putatt(ncid,var_pt_mean_id,'long_name',['Potential Temperature mean ',timewindow])
    netcdf.putatt(ncid,var_pt_mean_id,'standard_name','sea_water_potential_temperature')
    netcdf.putatt(ncid,var_pt_mean_id,'_FillValue',single(1.0e+20))
    netcdf.putatt(ncid,var_pt_mean_id,'missing_value',single(1.0e+20))
    netcdf.putatt(ncid,var_pt_mean_id,'valid_range',single([-2 35]))
    netcdf.putatt(ncid,var_pt_mean_id,'comment',[['Error threshold: ',num2str(pt_threshold,'%2.1f'),10], ...
                                                 ['Mean calculated over period: 1950-1-1 to ',timeend]])
    var_pt_chg_id = netcdf.defVar(ncid,'thetao_change','float',[dimIdLon,dimIdLat,dimIdDepth,dimIdTime]);
    netcdf.putatt(ncid,var_pt_chg_id,'units',['degree_C/',timeyrs])
    netcdf.putatt(ncid,var_pt_chg_id,'long_name',['Potential Temperature change ',timewindow])
    netcdf.putatt(ncid,var_pt_chg_id,'standard_name','change_over_time_in_sea_water_potential_temperature')
    netcdf.putatt(ncid,var_pt_chg_id,'_FillValue',single(1.0e+20))
    netcdf.putatt(ncid,var_pt_chg_id,'missing_value',single(1.0e+20))
    netcdf.putatt(ncid,var_pt_chg_id,'valid_range',single([-2 2]))
    netcdf.putatt(ncid,var_pt_chg_id,'comment',['Error threshold: ',num2str(pt_threshold,'%2.1f')])
    var_pt_chg_err_id = netcdf.defVar(ncid,'thetao_change_error','float',[dimIdLon,dimIdLat,dimIdDepth,dimIdTime]);
    netcdf.putatt(ncid,var_pt_chg_err_id,'units',['degree_C/',timeyrs])
    netcdf.putatt(ncid,var_pt_chg_err_id,'long_name',['Potential Temperature change error ',timewindow])
    %netcdf.putatt(ncid,var_pt_chg_err_id,'standard_name','change_over_time_in_sea_water_potential_temperature_error')
    netcdf.putatt(ncid,var_pt_chg_err_id,'_FillValue',single(1.0e+20))
    netcdf.putatt(ncid,var_pt_chg_err_id,'missing_value',single(1.0e+20))
    netcdf.putatt(ncid,var_pt_chg_err_id,'comment','  ')
end
var_s_mean_id = netcdf.defVar(ncid,'salinity_mean','float',[dimIdLon,dimIdLat,dimIdDepth,dimIdTime]);
netcdf.putatt(ncid,var_s_mean_id,'units','1e-3')
netcdf.putatt(ncid,var_s_mean_id,'units_long','PSS-78')
netcdf.putatt(ncid,var_s_mean_id,'long_name',['Salinity mean ',timewindow])
%netcdf.putatt(ncid,var_s_mean_id,'standard_name','sea_water_practical_salinity')
netcdf.putatt(ncid,var_s_mean_id,'standard_name','sea_water_salinity')
netcdf.putatt(ncid,var_s_mean_id,'_FillValue',single(1.0e+20))
netcdf.putatt(ncid,var_s_mean_id,'missing_value',single(1.0e+20))
netcdf.putatt(ncid,var_s_mean_id,'valid_range',single([6 42]))
netcdf.putatt(ncid,var_s_mean_id,'comment',[['Error threshold: ',num2str(s_threshold,'%2.1f'),10], ...
                                            ['Mean calculated over period: 1950-1-1 to ',timeend]])
var_s_chg_id = netcdf.defVar(ncid,'salinity_change','float',[dimIdLon,dimIdLat,dimIdDepth,dimIdTime]);
netcdf.putatt(ncid,var_s_chg_id,'units',['1e-3/',timeyrs])
netcdf.putatt(ncid,var_s_chg_id,'units_long',['PSS-78/',timeyrs])
netcdf.putatt(ncid,var_s_chg_id,'long_name',['Salinity change ',timewindow])
%netcdf.putatt(ncid,var_s_chg_id,'standard_name','change_over_time_in_sea_water_practical_salinity')
netcdf.putatt(ncid,var_s_chg_id,'standard_name','change_over_time_in_sea_water_salinity')
netcdf.putatt(ncid,var_s_chg_id,'_FillValue',single(1.0e+20))
netcdf.putatt(ncid,var_s_chg_id,'missing_value',single(1.0e+20))
netcdf.putatt(ncid,var_s_chg_id,'valid_range',single([-1 1]))
netcdf.putatt(ncid,var_s_chg_id,'comment',['Error threshold: ',num2str(s_threshold,'%2.1f')])
var_s_chg_err_id = netcdf.defVar(ncid,'salinity_change_error','float',[dimIdLon,dimIdLat,dimIdDepth,dimIdTime]);
netcdf.putatt(ncid,var_s_chg_err_id,'units',['1e-3/',timeyrs])
netcdf.putatt(ncid,var_s_chg_err_id,'units_long',['PSS-78/',timeyrs])
netcdf.putatt(ncid,var_s_chg_err_id,'long_name',['Salinity change error ',timewindow])
%netcdf.putatt(ncid,var_s_chg_err_id,'standard_name','change_over_time_in_sea_water_practical_salinity_error')
netcdf.putatt(ncid,var_s_chg_err_id,'_FillValue',single(1.0e+20))
netcdf.putatt(ncid,var_s_chg_err_id,'missing_value',single(1.0e+20))
netcdf.putatt(ncid,var_s_chg_err_id,'comment','  ')
if include_density
    var_g_mean_id = netcdf.defVar(ncid,'density_mean','float',[dimIdLon,dimIdLat,dimIdDepth,dimIdTime]);
    netcdf.putatt(ncid,var_g_mean_id,'units','kg m-3')
    netcdf.putatt(ncid,var_g_mean_id,'units_long','kg m-3')
    netcdf.putatt(ncid,var_g_mean_id,'long_name',['Neutral Density mean ',timewindow])
    netcdf.putatt(ncid,var_g_mean_id,'standard_name','sea_water_neutral_density')
    netcdf.putatt(ncid,var_g_mean_id,'_FillValue',single(1.0e+20))
    netcdf.putatt(ncid,var_g_mean_id,'missing_value',single(1.0e+20))
    netcdf.putatt(ncid,var_g_mean_id,'valid_range',single([6 42]))
    netcdf.putatt(ncid,var_g_mean_id,'comment',[['Error threshold: ',num2str(g_threshold,'%2.1f'),10], ...
                                                ['Mean calculated over period: 1950-1-1 to ',timeend]])
    var_g_chg_id = netcdf.defVar(ncid,'density_change','float',[dimIdLon,dimIdLat,dimIdDepth,dimIdTime]);
    netcdf.putatt(ncid,var_g_chg_id,'units',['kg m-3/',timeyrs])
    netcdf.putatt(ncid,var_g_chg_id,'units_long',['kg m-3/',timeyrs])
    netcdf.putatt(ncid,var_g_chg_id,'long_name',['Density change ',timewindow])
    netcdf.putatt(ncid,var_g_chg_id,'standard_name','change_over_time_in_sea_water_neutral_density')
    netcdf.putatt(ncid,var_g_chg_id,'_FillValue',single(1.0e+20))
    netcdf.putatt(ncid,var_g_chg_id,'missing_value',single(1.0e+20))
    netcdf.putatt(ncid,var_g_chg_id,'valid_range',single([-1 1]))
    netcdf.putatt(ncid,var_g_chg_id,'comment','  ')
    var_g_chg_err_id = netcdf.defVar(ncid,'density_change_error','float',[dimIdLon,dimIdLat,dimIdDepth,dimIdTime]);
    netcdf.putatt(ncid,var_g_chg_err_id,'units',['kg m-3/',timeyrs])
    netcdf.putatt(ncid,var_g_chg_err_id,'units_long',['kg m-3/',timeyrs])
    netcdf.putatt(ncid,var_g_chg_err_id,'long_name',['Density change error ',timewindow])
    %netcdf.putatt(ncid,var_g_chg_err_id,'standard_name','change_over_time_in_sea_water_neutral_density_error')
    netcdf.putatt(ncid,var_g_chg_err_id,'_FillValue',single(1.0e+20))
    netcdf.putatt(ncid,var_g_chg_err_id,'missing_value',single(1.0e+20))
    netcdf.putatt(ncid,var_g_chg_err_id,'comment','  ')
end

% Global attributes
attIdGlobal = netcdf.getConstant('NC_GLOBAL');
netcdf.putatt(ncid,attIdGlobal,'title',['Observed Global Ocean surface property changes for the 20th Century ',timewindow]);
netcdf.putatt(ncid,attIdGlobal,'institution','CSIRO Marine and Atmospheric Research, Hobart, TAS, Australia');
netcdf.putatt(ncid,attIdGlobal,'version','1.0.0; Beta - pre-release data');
netcdf.putatt(ncid,attIdGlobal,'contact',['Paul Durack; Paul.Durack@csiro.au (',username,'); +61 3 6232 5283']);
netcdf.putatt(ncid,attIdGlobal,'sourcefile',infile);
netcdf.putatt(ncid,attIdGlobal,'sourcefile_atts',[['script_name: ',a_script_name,10], ...
                                                  ['host_longname: ',a_host_longname,10], ...
                                                  ['matlab_version: ',a_matlab_version,10], ...
                                                  ['start_time: ',a_script_start_time,10], ...
                                                  ['process_time: ',num2str(a_file_process_time)]]);
[~,timestr] = unix('date --utc +%d-%b-%Y\ %X');
netcdf.putatt(ncid,attIdGlobal,'history',[regexprep(timestr,'\r\n|\n|\r',''),' UTC; Hobart, TAS, Australia']);
hoststr = [a_hostname,'; Matlab Version: ',version];
netcdf.putatt(ncid,attIdGlobal,'host',hoststr);
netcdf.putatt(ncid,attIdGlobal,'Conventions','CF-1.5');
netcdf.putatt(ncid,attIdGlobal,'Reference','Durack P.J. & S.E. Wijffels (2010) Fifty-Year Trends in Global Ocean Salinities and their Relationship to Broadscale Warming. Journal of Climate, 23, 4342-4362');
netcdf.putatt(ncid,attIdGlobal,'Reference_doi','http://dx.doi.org/10.1175/2010JCLI3377.1');
netcdf.putatt(ncid,attIdGlobal,'Reference_www','http://www.cmar.csiro.au/oceanchange/');
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
if include_temp
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
end
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