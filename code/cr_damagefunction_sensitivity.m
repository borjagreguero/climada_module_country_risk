function entity_out=cr_damagefunction_sensitivity(entity,hazard,selection_i,show_plot,save_dir)
% explore the DFCs' sensitivity to underlying damagefunctions
% MODULE:
%   country_risk
% NAME:
%   cr_damagefunction_sensitivity
% PURPOSE:
%   Given an entity and a hazard, generate different event damage sets
%   (EDSs) by varying the underlying damagefunctions. Plot the 
%   resulting damage frequency curves (DFCs) together with the two DFCs
%   (indexed and original) that stem from the historic event set of the
%   international disaster database EM-DAT.
%
%   The plot then allows to determine by eye which of the damagefunctions
%   used to calculate the DFCs produces the best fit to the EM-DAT data.
%
%   If the function is given a specific selection of a damagefunction
%   (selection_i), the damagefunctions in the input entity gets overwritten
%   with that selected damagefunction. The default value for selection_i is
%   1, which refers to the original damagefunction, such that in that case
%   the entity's damagefunction is left unchanged.
%   However, there is one change that applies to all input entities: If an
%   entity contains a field 'MDR' (Mean Damage Ratio), this field is
%   removed because it is not needed in any damage calculation in CLIMADA.
%
%   For the generation of entities and hazards in one single function, see 
%   country_risk_calc (in the module country_risk), which creates hazard 
%   sets and an entity for a given country before it runs the risk 
%   calculations.
%
%   For more information on the EM-DAT database, see http://www.emdat.be/
%   
% CALLING SEQUENCE:
%   entity_out=cr_damagefunction_sensitivity(entity,hazard,selection_i,show_plot,save_dir)
% EXAMPLE:
%   entity_out=cr_damagefunction_sensitivity(entity,hazard,4) 
%   overwrites the damagefunctions of the entity with damagefunction 4
% INPUTS:
%   entity: a climada entity with the fields 
%       - assets
%       - damagefunctions
%       - measures
%       - discount
%   to generate an entity, see climada_nightlight_entity (in the module 
%   country_risk) or climada_create_GDP_entity (in the module GDP_entity)
%
%   hazard: a climada hazard event set structure, see e.g. 
%        climada_tc_hazard_set
% OPTIONAL INPUT PARAMETERS:
%   selection_i: selection of the damagefunction to overwrite the entity's
%   damagefunction with
%       1: original damagefunctions, entity is left unchanged (=default)
%       2: shift to the right by 15% of max intensity
%       3: shift to the left by 15% of max intensity
%       4: [...]
%       etc. (this is only a preliminary version of the function, further
%       selections will be added later. See section 'implement 
%       damagefunction modifications here' in this code for the
%       currently implemented damagefunctions)
%   show_plot: only save the plot (=0), or show and save the plots (=1;
%   default)
%   save_dir: directory where the plot will be saved 
% OUTPUTS:
%   entity_out: entity with the damagefunction selection_i refers to
%   (default for selection_i is 1, i.e. entity_out is the same as the 
%   original entity).
% NOTE 1: 
% Feel free to play around and implement further damagefunctions in the 
% code (in the section 'implement damagefunction modifications here')
% NOTE 2:
% This is a preliminary version that might need some clean-up /
% optimization
%
% MODIFICATION HISTORY:
% Melanie Bieli, melanie.bieli@bluewin.ch, 20150203, initial
% Melanie Bieli, melanie.bieli@bluewin.ch, 20150206, added show_plot and save_dir
%-

% initialize output
entity_out = []; % init output 

global climada_global
if ~climada_init_vars,return;end % init/import global variables

%check arguments and set default variables if necessary
if ~exist('entity','var')
    fprintf('error: missing input argument ''entity'', can''t proceed.\n');
    return;
end
if ~exist('hazard','var')
    fprintf('error: missing input argument ''hazard'', can''t proceed.\n');
    return;
end
if ~exist('selection_i','var') || isempty(selection_i), selection_i = 1;end
if ~exist('show_plot','var'), show_plot = 1;end
if ~exist('save_dir','var'), save_dir = [];end

% PARAMETERS
%
% ID of the damage function we will use as starting point
damfun_ID = 1;
%
% default directory where the plots will be saved 
default_save_dir = [climada_global.data_dir filesep 'results' filesep ...
    'damagefun_plots'];
%
% the maximum return period (RP) to show in plots - has to be one of the
% return periods the comparison DFC exists for
plot_max_RP = 120; % default=120
%-

% find the ID of the peril we are dealing with (note: only take the first
% two characters, otherwise 'WSEU' does not work)
if isfield(hazard,'peril_ID')
    hazard_peril_ID = hazard.peril_ID(1:2);
else
    fprintf('Error: no peril ID found in hazard.\n')
    return;
end

% find the damagefunction for the peril under consideration
damfun_ID_positions = find(entity.damagefunctions.DamageFunID == damfun_ID);  % indices of required damfun IDs 
damfun_positions = damfun_ID_positions(strcmp(...
    entity.damagefunctions.peril_ID(damfun_ID_positions),hazard_peril_ID)); % indices of required damage function (match with peril)
if isempty(damfun_positions)
    fprintf('Error: No damagefunction found for damfun_ID %d and peril %s\n', ...
        damfun_ID, hazard_peril_ID);
end

%% prepare a "base entity" containing only the relevant damage function 
% (makes handling easier when manipulating the damage functions afterwards)
% entity.assets.Cover=entity.assets.Value; % might be necessary for new entities
if isfield(entity.damagefunctions,'MDR')
    entity.damagefunctions = rmfield(entity.damagefunctions,'MDR');
end
entity_original = entity;   % backup
entity.damagefunctions.DamageFunID = entity.damagefunctions.DamageFunID(damfun_positions);
entity.damagefunctions.Intensity = entity.damagefunctions.Intensity(damfun_positions);
entity.damagefunctions.MDD = entity.damagefunctions.MDD(damfun_positions);
entity.damagefunctions.PAA = entity.damagefunctions.PAA(damfun_positions);
entity.damagefunctions.peril_ID = entity.damagefunctions.peril_ID(damfun_positions);
entities(1) = entity; % first entity is the original entity

%%%%%%%%%%%%% implement damagefunction modifications here  %%%%%%%%%%%%%%%%
%% now we create additional entities with different damage functions
% i.e., generate entity(2), entity(3), etc.
% entity 2: shift damagefunction to the right by 15% of the max intensity
entities(2) = entity;
entities(2).damagefunctions.Intensity = entity.damagefunctions.Intensity ...
     - 0.15 * max(entity.damagefunctions.Intensity);

% entity 3: shift damagefunction to the left by 15% of the max intensity
entities(3) = entity;
entities(3).damagefunctions.Intensity = entity.damagefunctions.Intensity ...
     + 0.15 * max(entity.damagefunctions.Intensity);

% entity 4: decrease the MDD at small intensities and increase it at high
% intensitites (squared modification factors) 
entities(4) = entity;
mod_factors = linspace(0.7,1.8,length(entity.damagefunctions.MDD));
for MDD_i = 1:length(entity.damagefunctions.MDD)
    entities(4).damagefunctions.MDD(MDD_i) = min(1,mod_factors(MDD_i)^2 ...
        * entity.damagefunctions.MDD(MDD_i));
end
        
% entity 5: increase the MDD at small intensities and decrease it at high
% intensities (squared modification factors)
entities(5) = entity;
mod_factors = linspace(1.8,0.7,length(entity.damagefunctions.MDD));
for MDD_i = 1:length(entity.damagefunctions.MDD)
    entities(5).damagefunctions.MDD(MDD_i) = min(1,mod_factors(MDD_i)^2 ...
        * entity.damagefunctions.MDD(MDD_i));
end

% entity 6: increase the MDD at small intensities and decrease it at high
% intensities (modification factors to the fourth power)
entities(6) = entity;
mod_factors = linspace(1.8,0.7,length(entity.damagefunctions.MDD));
for MDD_i = 1:length(entity.damagefunctions.MDD)
    entities(6).damagefunctions.MDD(MDD_i) = min(1,mod_factors(MDD_i)^4 ...
        * entity.damagefunctions.MDD(MDD_i));
end


% entity 7: add 15% of the maximum MDD to each MDD value
entities(7) = entity;
for MDD_i = 1:length(entity.damagefunctions.MDD)
    entities(7).damagefunctions.MDD(MDD_i) = min(1, ...
        entity.damagefunctions.MDD(MDD_i)+ 0.15*max(entity.damagefunctions.MDD));
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% calculate event damage sets (EDSs) for all entities and the given hazard
for entity_i = 1:length(entities)
    annotation_name = sprintf('damagefun_%d',entity_i);
    EDS(entity_i) = climada_EDS_calc(entities(entity_i),hazard,annotation_name);
    fprintf('finished EDS %d\n',entity_i)
end

% we take EDS(1) (which resulted from the original damagefunction) and 
% adjust it to an EDS that tries to match the EM-DAT damage history
EDS(end+1) = climada_EDS_emdat_adjust(EDS(1));
EDS(end).annotation_name = 'damagefun_1_EMDAT_adjusted';

%% plot the DFCs resulting from the different EDSs
% define figure parameters
msize      = 5;
legend_str = {};
color_ = jet(length(EDS));
marker_ = repmat('o-',[length(EDS)+1,1]);
marker_(1,:) = '*-';

% order according to size of damage
damage_                 = arrayfun(@(x)(sum(x.damage)), EDS);
[~,sort_index] = sort(damage_,'ascend');
color_ = color_(sort_index,:);
   
% plot the DFCs of all EDSs
if show_plot
    visibility_string = 'on';
else
    visibility_string = 'off';
end

f = figure('visible',visibility_string);
max_sorted_damage = 0;
h = zeros(length(EDS)+2,1);
ii      = 1;
for EDS_i=1:length(EDS)
    [sorted_damage,exceedence_freq]... 
                    = climada_damage_exceedence(EDS(EDS_i).damage,EDS(EDS_i).frequency);
    nonzero_pos     = find(exceedence_freq);
    sorted_damage   = sorted_damage(nonzero_pos);
    exceedence_freq = exceedence_freq(nonzero_pos);
    return_period   = 1./exceedence_freq;
    h(EDS_i)= plot(return_period,sorted_damage,marker_(ii,:),'color',color_(ii,:),...
        'LineWidth',1.5,'markersize',msize);
    if max(sorted_damage) > max_sorted_damage 
        max_sorted_damage = max(sorted_damage); 
    end
    hold on
    ii = ii+1; 
    if isfield(EDS(EDS_i),'annotation_name')
        legend_str{EDS_i}=strrep(EDS(EDS_i).annotation_name,'_',' '); 
    end
end % EDS_i

% we also plot the EM-DAT DFCs for comparison
green = [0 204 0]/255;
em_data = emdat_read('',entity.assets.admin0_name,hazard_peril_ID,1);
h(end-1)=plot(em_data.DFC.return_period,em_data.DFC.damage,'diamond','Color','k', ...
    'MarkerSize',7,'markerfacecolor',green); 
hold on
h(end)=plot(em_data.DFC.return_period,em_data.DFC_orig.damage,'o','Color','k',...
    'MarkerSize',7,'markerfacecolor',green); hold on
legend_str{end+1} = em_data.DFC.annotation_name;
legend_str{end+1} = em_data.DFC_orig.annotation_name;

% zoom to 0..plot_max_RP years return period
y_max = max(max_sorted_damage,max(em_data.DFC.damage));
axis([0 plot_max_RP 0 y_max]);

% add legend and axis labels
set(gca,'fontsize',12);
if ~isempty(legend_str),legend(h,legend_str,'Location','NorthWest');end 
grid on; % show grid
xlabel('Return period (years)');
ylabel('Damage (USD)');

% add title
title_str = sprintf('%s | %s',entity.assets.admin0_name,hazard_peril_ID);
title(title_str,'FontSize',12);

hold off;

%% save the plot 
if isempty(save_dir), save_dir = default_save_dir; end
if ~exist(default_save_dir, 'dir')
    mkdir(default_save_dir);
end
plot_name = sprintf('%s_%s_%s_damfun_sensitivity.png', ...
    entity.assets.admin0_ISO3, entity.assets.admin0_name, hazard_peril_ID);
save_file = fullfile(save_dir, plot_name);
saveas(f, save_file,'png');


%% Overwrite the damagefunction of the original entity with the
% damagefunction selection_i refers to
if ismember(selection_i,1:length(EDS)-1)
    % valid selection, i.e. we adjust the damagefunctions of the input
    % entity (adjust MDD as well as Intensity, since both these fields
    % could have been modified depending on the choice of selection_i)
    entity_out = entity_original;
    entity_out.damagefunctions.MDD(damfun_positions) = ...
        entities(selection_i).damagefunctions.MDD;
    entity_out.damagefunctions.Intensity(damfun_positions) = ...
        entities(selection_i).damagefunctions.Intensity;
else 
    fprintf('\n Warning: %d is not a valid option for selection_i.\n',...
        selection_i)
    fprintf('No changes will be made in %s.\n',inputname(1)) % entity name
    entity_out=entity_original;
end
                       