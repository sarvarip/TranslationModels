% � Peter Sarvari, Imperial College London

%Initialization
total_mRNA = 3971;
no_types_mRNA = 3;

total_protein_init = [7373, 10924, 138080];
total_transcript = [187, 278, 3506];
init_rates = [1,1,1];
temp = [init_rates(1)*ones(1,total_transcript(1)), init_rates(2)*ones(1,total_transcript(2)), init_rates(3)*ones(1,total_transcript(3))]; 
max_elongation = 126;
aac_array = [7500, 300, 300];

betas = cell(1,no_types_mRNA);
betas{1} = [init_rates(1), max_elongation*ones(1,750)]; %R
betas{2} = [init_rates(2), max_elongation*ones(1,30)]; %E
betas{3} = [init_rates(3), max_elongation*ones(1,30)]; %Q
type_idx_array = [ones(1,total_transcript(1)), 2*ones(1,total_transcript(2)), 3*ones(1,total_transcript(3))]; 

energy = 10^5;
S_i = 128;
R0 = total_protein_init(1); 

ss_start = 45000;
ss_end = 50000;
maxsteps = 2000*ss_end; %~est. 20 hrs
ref = 2000*ss_start;
time = zeros(1,maxsteps+1);
time_P_cell = cell(1,no_types_mRNA);
P_count_vec = total_protein_init;
state_array = ones(1,R0);
location_array = zeros(1,R0);

%Iterations

exists_reference = 0;
total_inst_gr_array=zeros(1, ss_end-ss_start);
P_count_vec_array=zeros(ss_end-ss_start+1, 3);
time_ss = zeros(1, ss_end-ss_start+1);
tic
for timestep=1:maxsteps
    if timestep == 1
        [state_array, location_array, type_idx_array, total_transcript, energy, S_i, time(timestep+1), time_P_cell, P_count_vec, temp, transition_array] = Gillespie_STS_Prod_Rate_Multi_WholeCell_2_final(state_array, location_array, betas, type_idx_array, total_transcript, energy, S_i, time(timestep), time_P_cell, P_count_vec, temp);
        %reconstruct the transcripts in case changes happened
    else    
        [state_array, location_array, type_idx_array, total_transcript, energy, S_i, time(timestep+1), time_P_cell, P_count_vec, temp, transition_array] = Gillespie_STS_Prod_Rate_Multi_WholeCell_2_final(state_array, location_array, betas, type_idx_array, total_transcript, energy, S_i, time(timestep), time_P_cell, P_count_vec, temp, transition_array);
        %reconstruct the transcripts in case changes happened
    end
    
    if rem(timestep,2000)==0
        if timestep >= ref
            P_count_vec_array((timestep/2000)-ss_start+1,:) = P_count_vec;
            if exists_reference == 0
                time_ref = time(timestep+1);
                mass_ref = zeros(1, no_types_mRNA); 
                for i=1:no_types_mRNA
                    mass_ref(i) = aac_array(i)*length(time_P_cell{i});
                end
                total_mass_ref = sum(mass_ref);
                exists_reference = 1;
                time_ss((timestep/2000)-ss_start+1) = time_ref;
            else
                time_current = time(timestep+1);
                time_elapsed = time_current - time_ref;
                mass_current = zeros(1, no_types_mRNA); 
                for i=1:no_types_mRNA
                    mass_current(i) = aac_array(i)*length(time_P_cell{i});
                end
                %mass_change = mass_current - mass_ref;
                %inst_gr = (mass_change./mass_ref)/time_elapsed;
                total_mass_current = sum(mass_current);
                total_mass_change = total_mass_current - total_mass_ref;
                total_inst_gr = total_mass_change/(10^8*time_elapsed)*60;
                time_ref = time_current;
                total_mass_ref = total_mass_current;
                %inst_gr_array = [inst_gr_array; inst_gr]; %waste calculating both here, second can be calc from first
                total_inst_gr_array((timestep/2000)-ss_start) = total_inst_gr;
                disp(['Instantaneous growth rate: ',num2str(total_inst_gr)]);
                time_ss((timestep/2000)-ss_start+1) = time_ref;
            end
        end    
        ratio = timestep/maxsteps;
        disp([num2str(100*ratio), '%']);
        disp(['Energy: ',num2str(energy)]);
    end
end
toc

%Final average production calcs

time_elapsed = time(end)-time(ref);
transient_P=zeros(1,no_types_mRNA);
total_P = zeros(1,no_types_mRNA);
for i=1:no_types_mRNA
    transient_P(i) = sum(time_P_cell{i}<=time(ref)); %we only care about states from the 1001th timstep on (incl), but
    total_P(i) = length(time_P_cell{i});
    %if a protein was produced at time = 1001, it was the trasition from state
    %1000 to 1001, so we disregard it! CHANGED: we are not averaging
    %here; also ss_start is estimated, for simplicity, use ref instead
    %of ref+1!!
end


P_ss = total_P-transient_P;
production_rate = P_ss/time_elapsed;
disp(['Production rate: ', num2str(production_rate)]);
growth_rate = (aac_array*total_P'-aac_array*transient_P')/(10^8*time_elapsed)*60;
disp(['Total Growth rate: ', num2str(growth_rate)]);

%Definition: 
% log_no_new = log((aac_array*total_P')/10^8 +1);
% log_no_old = log((aac_array*transient_P')/10^8 +1);
% no_generations = (log_no_new-log_no_old)/log(2);
% generation_time = (time_elapsed/60)/no_generations;
% growth_rate = 1/generation_time;

%mathematically the same as 
% log((aac_array*total_P'+10^8)/(aac_array*transient_P'+10^8))/(log(2)*time_elapsed)*60

%Now we only model one cell, so log_no_old = 0 (no_old is always one)
%However, still we cannot use this, since we only model one cell and the
%logarithmic model assumes that as soon as you have more than one, it helps
%producing more mass/cells, but here we only model a single cell

%approx.
%(aac_array*total_P'-aac_array*transient_P')/(10^8*time_elapsed)*60

avg_inst_growth_rate = mean(total_inst_gr_array);
std_inst_growth_rate = std(total_inst_gr_array);
disp(['Avg. Inst. Growth rate: ', num2str(avg_inst_growth_rate)]);
disp(['Std. Inst. Growth rate: ', num2str(std_inst_growth_rate)]);


save('FYP_1_06_endo')