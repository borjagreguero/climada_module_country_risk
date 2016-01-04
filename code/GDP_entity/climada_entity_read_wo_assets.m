function entity = climada_entity_read_wo_assets(entity_filename)

% climada assets read import without assets
% NAME:
%   climada_entity_read_wo_assets
% PURPOSE:
%   read the Excel file without assets, but with damagefunctions, measures
%   etc. without encoding (climada_assets_encode)
%   The code invokes climada_spreadsheet_read to really read the data,
%   which implements .xls files
%   For .xls, the sheet names are dynamically checked,
%   'assets','damagefunctions','measures' and 'discount' need to exist.
% CALLING SEQUENCE:
%   entity = climada_entity_read_wo_assets(entity_filename, assets_off)
% EXAMPLE:
%   entity = climada_entity_read_wo_assets
% INPUTS:
%   entity_filename: the filename of the Excel file with the assets
%       > promted for if not given
% OUTPUTS:
%   entity: a structure, with
%       assets: a structure, with
%           Latitude: the latitude of the values
%           Longitude: the longitude of the values
%           Value: the total insurable value
%           Deductible: the deductible
%           Cover: the cover
%           DamageFunID: the damagefunction curve ID
%       damagefunctions: a structure, with
%           DamageFunID: the damagefunction curve ID
%           Intensity: the hazard intensity
%           MDD: the mean damage degree
% MODIFICATION HISTORY:
% David N. Bresch, david.bresch@gmail.com, 20090920
% Lea Mueller, 20110720
% David N. Bresch, david.bresch@gmail.com, 20130328, vuln_MDD_impact ->
% MDD_impact ...
%-

global climada_global
if ~climada_init_vars,return;end % init/import global variables

entity=[];

%%if climada_global.verbose_mode,fprintf('*** %s ***\n',mfilename);end % show routine name on stdout

% poor man's version to check arguments
if ~exist('entity_filename', 'var'), entity_filename = []; end

% prompt for entity_filename if not given
if isempty(entity_filename) % local GUI
    entity_filename      = [climada_global.data_dir filesep 'entities' filesep '*' climada_global.spreadsheet_ext];
    [filename, pathname] = uigetfile(entity_filename, 'Select entity file:');
    if isequal(filename,0) || isequal(pathname,0)
        return; % cancel
    else
        entity_filename = fullfile(pathname,filename);
    end
end



% field assets is empty
entity.assets = [];

% % read assets
% % -----------
% assets                   = climada_spreadsheet_read('no',entity_filename,'assets',1);
% % check for OLD naming convention, VulnCurveID -> DamageFunID
% if isfield(assets,'VulnCurveID'),assets.DamageFunID=assets.VulnCurveID;assets=rmfield(assets,'VulnCurveID');end

% % encode assets
% [entity.assets hazard]   = climada_assets_encode(assets,hazard);


% figure out the file type
[fP,fN,fE] = fileparts(entity_filename);

if strcmp(fE,'.ods')
    % hard-wired sheet names for files of type .ods
    sheet_names={'damagefunctions','measures','discount'};
else
    % inquire sheet names from .xls
    [sheet_type,sheet_names] = xlsfinfo(entity_filename);
end

try
    % read damagefunctions
    % --------------------
    for sheet_i=1:length(sheet_names) % loop over tab (sheet) names
        if strcmp(sheet_names{sheet_i},'damagefunctions')
            entity.damagefunctions=climada_spreadsheet_read('no',entity_filename,'damagefunctions',1);
        end
        if strcmp(sheet_names{sheet_i},'vulnerability')
            entity.damagefunctions=climada_spreadsheet_read('no',entity_filename,'vulnerability',1);
        end
    end % sheet_i
    
    if isfield(entity,'damagefunctions')
        % check for OLD naming convention, VulnCurveID -> DamageFunID
        if isfield(entity.damagefunctions,'VulnCurveID'),entity.damagefunctions.DamageFunID=entity.damagefunctions.VulnCurveID;entity.damagefunctions=rmfield(entity.damagefunctions,'VulnCurveID');end
        
        % check consistency (a damagefunction definition for each DamageFunID)
        if ~isempty(entity.assets)
            asset_DamageFunIDs=unique(entity.assets.DamageFunID);
            damagefunctions_DamageFunIDs=unique(entity.damagefunctions.DamageFunID);
            tf=ismember(asset_DamageFunIDs,damagefunctions_DamageFunIDs);
            if length(find(tf))<length(tf)
                fprintf('WARN: DamageFunIDs in assets might not all be defined in damagefunctions tab\n')
            end
        else
            fprintf('NOTE: assets empty, DamageFunIDs not checked for consistency\n')
            
        end
    end
    
catch ME
    fprintf('WARN: no damagefunctions data read, %s\n',ME.message)
end

%try
% try to read also the measures (if exists)
% -----------------------------
for sheet_i=1:length(sheet_names) % loop over tab (sheet) names
    if strcmp(sheet_names{sheet_i},'measures')
        %%fprintf('NOTE: also reading measures tab\n');
        measures        = climada_spreadsheet_read('no',entity_filename,'measures',1);
        entity.measures = climada_measures_encode(measures);
        
        % check for OLD naming convention, vuln_MDD_impact_a -> MDD_impact_a
        if isfield(entity.measures,'vuln_MDD_impact_a'),entity.measures.MDD_impact_a=entity.measures.vuln_MDD_impact_a;entity.measures=rmfield(entity.measures,'vuln_MDD_impact_a');end
        if isfield(entity.measures,'vuln_MDD_impact_b'),entity.measures.MDD_impact_b=entity.measures.vuln_MDD_impact_b;entity.measures=rmfield(entity.measures,'vuln_MDD_impact_b');end
        if isfield(entity.measures,'vuln_PAA_impact_a'),entity.measures.PAA_impact_a=entity.measures.vuln_PAA_impact_a;entity.measures=rmfield(entity.measures,'vuln_PAA_impact_a');end
        if isfield(entity.measures,'vuln_PAA_impact_b'),entity.measures.PAA_impact_b=entity.measures.vuln_PAA_impact_b;entity.measures=rmfield(entity.measures,'vuln_PAA_impact_b');end
        if isfield(entity.measures,'vuln_map'),entity.measures.damagefunctions_map=entity.measures.vuln_map;entity.measures=rmfield(entity.measures,'vuln_map');end
        
    end
end % sheet_i
% catch ME
%     fprintf('WARN: no measures data read, %s\n',ME.message)
% end

try
    % try to read also the discount sheet (if exists)
    % -----------------------------------
    for sheet_i=1:length(sheet_names) % loop over tab (sheet) names
        if strcmp(sheet_names{sheet_i},'discount')
            %%fprintf('NOTE: also reading measures tab\n');
            entity.discount = climada_spreadsheet_read('no',entity_filename,'discount',1);
        end
    end % sheet_i
catch ME
    fprintf('WARN: no discount data read, %s\n',ME.message)
end

% save entity as .mat file for fast access
[fP,fN] = fileparts(entity_filename);
entity_save_file=[fP filesep fN '.mat'];
save(entity_save_file,'entity');
fprintf('entity saved as mat-file in %s\n',entity_save_file);

return
