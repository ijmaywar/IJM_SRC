################################################################################
#
# Create plots from L2 wind data that show the winds experienced by albatrosses
#
################################################################################

# Clear environment -------------------------------------------------------

rm(list = ls())

# User Inputted Values -----------------------------------------------------

locations = c('Bird_Island','Midway')

# Load Packages -----------------------------------------------------------

library(tidyverse)
library(ggplot2)
library(readxl)
library(lme4)
library(stringr)
library(dplyr)
library(mgcv)
library(mgcViz)
library(gridExtra)
library(patchwork)
library(gratia)
library(readr)
library(viridis)
library(grid)
library(egg)
library(ggbeeswarm)
library(see)

# Set Environment ---------------------------------------------------------

GD_dir <- "/Users/ian/Library/CloudStorage/GoogleDrive-ian.maywar@stonybrook.edu/My Drive/Thorne Lab Shared Drive/Data/Albatross/"
read_dir <- paste0(GD_dir, "Analysis/Maywar/Merged_Data/Merged_Hourly_Compiled/")

fullmeta <- read_excel(paste0(GD_dir,"metadata/Full_Metadata.xlsx"))

setwd(read_dir)
files <- list.files(pattern = '*.csv')
m_all <- read_csv(files[2])

# Classify 2BEP, E_pip, Ep as BG
m_all <- m_all %>% mutate(Trip_Type = factor(replace(as.character(Trip_Type),Trip_Type=="2BEP","BG")))
m_all <- m_all %>% mutate(Trip_Type = factor(replace(as.character(Trip_Type),Trip_Type=="E_pip","BG")))
m_all <- m_all %>% mutate(Trip_Type = factor(replace(as.character(Trip_Type),Trip_Type=="Ep","BG")))

# Format datetime
m_all$datetime <- as.POSIXct(m_all$datetime,format="%Y-%m-%d %H:%M:%S",tz="GMT")

# Categorize BWAs
m_all <- m_all %>% mutate(bird_wind_angle_cat = case_when(bird_wind_angle<60 ~ "tail",
                                                          bird_wind_angle>=60 & bird_wind_angle<120 ~ "cross",
                                                          bird_wind_angle>=120 ~ "head"))

m_all <- m_all %>% mutate(bird_wave_angle_cat = case_when(bird_wave_angle<60 ~ "tail",
                                                          bird_wave_angle>=60 & bird_wave_angle<120 ~ "cross",
                                                          bird_wave_angle>=120 ~ "head"))

m_all <- m_all %>% mutate(bird_swell_angle_cat = case_when(bird_swell_angle<60 ~ "tail",
                                                           bird_swell_angle>=60 & bird_swell_angle<120 ~ "cross",
                                                           bird_swell_angle>=120 ~ "head"))

m_all <- m_all %>% mutate(bird_ww_angle_cat = case_when(bird_ww_angle<60 ~ "tail",
                                                        bird_ww_angle>=60 & bird_ww_angle<120 ~ "cross",
                                                        bird_ww_angle>=120 ~ "head"))

# Turn variables into factors
m_all$id <- as.factor(m_all$id)
m_all$tripID <- as.factor(m_all$tripID) 
m_all$Field_Season <- as.factor(m_all$Field_Season)
m_all$Location <- as.factor(m_all$Location)
m_all$Trip_Type <- as.factor(m_all$Trip_Type)
m_all$Species <- as.factor(m_all$Species)
m_all$bird_wind_angle_cat <- as.factor(m_all$bird_wind_angle_cat)
m_all$bird_wave_angle_cat <- as.factor(m_all$bird_wave_angle_cat)
m_all$bird_swell_angle_cat <- as.factor(m_all$bird_swell_angle_cat)
m_all$bird_ww_angle_cat <- as.factor(m_all$bird_ww_angle_cat)
m_all$HMM_2S_state <- as.factor(m_all$HMM_2S_state)
m_all$HMM_3S_state <- as.factor(m_all$HMM_3S_state)

# Re-order Species groups and give them their full name
m_all <- m_all %>% mutate(Species = factor(replace(as.character(Species),Species=="BBAL","Black-browed")),
       Species = factor(replace(as.character(Species),Species=="GHAL","Grey-headed")),
       Species = factor(replace(as.character(Species),Species=="WAAL","Wandering")),
       Species = factor(replace(as.character(Species),Species=="BFAL","Black-footed")),
       Species = factor(replace(as.character(Species),Species=="LAAL","Laysan")))
m_all$Species <- factor(m_all$Species, levels=c("Black-browed", "Grey-headed", "Wandering", "Black-footed", "Laysan"))

m_all$bird_wind_angle_cat <- factor(m_all$bird_wind_angle_cat, levels=c("head", "cross", "tail"))
m_all$bird_wave_angle_cat <- factor(m_all$bird_wave_angle_cat, levels=c("head", "cross", "tail"))
m_all$bird_swell_angle_cat <- factor(m_all$bird_swell_angle_cat, levels=c("head", "cross", "tail"))
m_all$bird_ww_angle_cat <- factor(m_all$bird_ww_angle_cat, levels=c("head", "cross", "tail"))

# Add km/hr of wind_vel
m_all$wind_vel_kmh <- 3.6*(m_all$wind_vel)

m_all_nonaflaps <- m_all %>% drop_na(flaps)
m_all_nonaflapsbwas <- m_all_nonaflaps %>% drop_na(bird_wind_angle)
m_all_nonaflapsbwas_pos_complete <- m_all_nonaflapsbwas %>% filter(Pos_complete==1)



# Some stats -------------------------------------------------------------------

m_all_nonaflaps %>% group_by(Species) %>% summarize(unique_IDs=n_distinct(id))

m_all_nonaflaps %>% group_by(id) %>% summarize(count=n())

# m_all %>% group_by(GLS_state) %>% summarize(count=n())



# Density plots for wind--------------------------------------------------------

cat_hist_colors <- c("#440154FF","#1F968BFF","#FDE725FF")

BWA_cat_hist_data <- as.data.frame(m_all_nonaflapsbwas_pos_complete %>% group_by(Location,Species,id,BWA_cat) %>% 
  summarize(count=n()) %>% 
  mutate(proportion = count/sum(count),
         Species = factor(replace(as.character(Species),Species=="BBAL","Black-browed")),
         Species = factor(replace(as.character(Species),Species=="GHAL","Grey-headed")),
         Species = factor(replace(as.character(Species),Species=="WAAL","Wandering")),
         Species = factor(replace(as.character(Species),Species=="BFAL","Black-footed")),
         Species = factor(replace(as.character(Species),Species=="LAAL","Laysan"))))
  
ggplot(BWA_cat_hist_data) +
  facet_wrap(~Species) +
  geom_density(aes(x=proportion,fill=BWA_cat)) +
  scale_fill_manual(values=cat_hist_colors) + 
  labs(y="Density") +
  theme_bw() +
  scale_x_continuous(name ="Proportion of time", 
                     breaks=c(0,0.25,0.5,0.75,1),
                     labels = c("0",".25",".5",".75","1"),
                     limits = c(0,1)) + 
  theme(legend.position = c(0.85, 0.2), # c(0,0) bottom left, c(1,1) top-right.
        legend.background = element_rect(fill = NA, colour = NA)) +
  guides(fill=guide_legend(title="Relative wind")) +
  theme(text = element_text(size = 24))

# For low windspeeds (<=5m/s) --------------------------------------------------

BWA_cat_hist_data_low <- as.data.frame(m_all_nonaflapsbwas_pos_complete %>% filter(wind_vel<=5) %>% group_by(Species,id,BWA_cat) %>% 
                                         summarize(count=n()) %>% 
                                         mutate(proportion = count/sum(count),
                                                Species = factor(replace(as.character(Species),Species=="BBAL","Black-browed")),
                                                Species = factor(replace(as.character(Species),Species=="GHAL","Grey-headed")),
                                                Species = factor(replace(as.character(Species),Species=="WAAL","Wandering")),
                                                Species = factor(replace(as.character(Species),Species=="BFAL","Black-footed")),
                                                Species = factor(replace(as.character(Species),Species=="LAAL","Laysan"))))

ggplot(BWA_cat_hist_data_low %>% filter()) +
  geom_density(aes(x=proportion,fill=BWA_cat)) +
  scale_fill_manual(values=cat_hist_colors) + 
  labs(y="Density") +
  theme_bw() + 
  scale_x_continuous(name ="Proportion of time", breaks=c(0,0.25,0.5,0.75,1),
                     labels = c("0","0.25","0.5","0.75","1")) + 
  facet_wrap(~Species) +
  theme(legend.position = c(0.85, 0.2), # c(0,0) bottom left, c(1,1) top-right.
        legend.background = element_rect(fill = NA, colour = NA)) +
  guides(fill=guide_legend(title="Relative wind")) +
  theme(text = element_text(size = 24))


# Windspeeds along tracks -----------------------------------------

m_all_nonaflapsbwas_pos_complete |>
  ggplot(aes(Species,wind_vel_kmh)) +
  geom_violinhalf(width=1.2,flip=TRUE) + 
  geom_boxplot(width=0.4) +
  # add scatter points
  # theme_minimal() +
  ylim(0,100) +
  labs(y="Windspeed (km/h)",x="Species") +
  theme_bw() +
  theme(text = element_text(size = 24))

# Wave heights along tracks ----------------------------------------------------

# Swell and wind waves 
m_all_nonaflapsbwas_pos_complete |>
  ggplot(aes(Species,swh)) +
  geom_violinhalf(width=1.2,flip=TRUE) + 
  geom_boxplot(width=0.4) +
  # add scatter points
  # theme_minimal() +
  # ylim(0,100) +
  labs(x="Species") +
  theme_bw() +
  theme(text = element_text(size = 24))

# Swells
m_all_nonaflapsbwas_pos_complete |>
  ggplot(aes(Species,shts)) +
  geom_violinhalf(width=1.2,flip=TRUE) + 
  geom_boxplot(width=0.4) +
  # add scatter points
  # theme_minimal() +
  # ylim(0,100) +
  labs(x="Species") +
  theme_bw() +
  theme(text = element_text(size = 24))

# Wind waves
m_all_nonaflapsbwas_pos_complete |>
  ggplot(aes(Species,shww)) +
  geom_violinhalf(width=1.2,flip=TRUE) + 
  geom_boxplot(width=0.4) +
  # add scatter points
  # theme_minimal() +
  # ylim(0,100) +
  labs(x="Species") +
  theme_bw() +
  theme(text = element_text(size = 24))

# Wave period along tracks -----------------------------------------------------

# Swell and wind waves 
m_all_nonaflapsbwas_pos_complete |>
  ggplot(aes(Species,mwp)) +
  geom_violinhalf(width=1.2,flip=TRUE) + 
  geom_boxplot(width=0.4) +
  # add scatter points
  # theme_minimal() +
  # ylim(0,100) +
  labs(x="Species") +
  theme_bw() +
  theme(text = element_text(size = 24))

# Swells
m_all_nonaflapsbwas_pos_complete |>
  ggplot(aes(Species,mpts)) +
  geom_violinhalf(width=1.2,flip=TRUE) + 
  geom_boxplot(width=0.4) +
  # add scatter points
  # theme_minimal() +
  # ylim(0,100) +
  labs(x="Species") +
  theme_bw() +
  theme(text = element_text(size = 24))

# Wind waves
m_all_nonaflapsbwas_pos_complete |>
  ggplot(aes(Species,mpww)) +
  geom_violinhalf(width=1.2,flip=TRUE) + 
  geom_boxplot(width=0.4) +
  # add scatter points
  # theme_minimal() +
  # ylim(0,100) +
  labs(x="Species") +
  theme_bw() +
  theme(text = element_text(size = 24))

# free_convective_velocity_over_the_oceans -------------------------------------

m_all_nonaflapsbwas_pos_complete |>
  ggplot(aes(Species,p140208)) +
  geom_boxplot(width=0.4) +
  # geom_violinhalf(width=1,flip=TRUE) + 
  # add scatter points
  # theme_minimal() +
  # ylim(0,100) +
  labs(x="Species") +
  theme_bw() +
  theme(text = element_text(size = 24))

# Bird-wave angle along tracks -------------------------------------------------

m_all_nonaflapsbwas_pos_complete |>
  ggplot(aes(Species,b_wave_a)) +
  geom_violinhalf(width=1.2,flip=TRUE) + 
  geom_boxplot(width=0.4) +
  # add scatter points
  # theme_minimal() +
  # ylim(0,100) +
  labs(y="SWH (m)",x="Species") +
  theme_bw() +
  theme(text = element_text(size = 24))


# More code ------------------------------------------------------

w_rel_polar_BBAL <- ggplot(m_all_nonaflaps %>% filter(Species=="BBAL"),aes(x=w_rel)) +
  geom_histogram(aes(y=after_stat(count/sum(count))),breaks=seq(0,360,by=10)-5,
                 fill=w_rel_colors) +
  labs(y="Proportion of time",x="Relative wind angle") +
  ggtitle("BBAL") +
  theme_bw() +
  ylim(0,0.06) +
  coord_polar(start=-0.0873)
w_rel_polar_GHAL <- ggplot(m_all_nonaflaps %>% filter(Species=="GHAL"),aes(x=w_rel)) +
  geom_histogram(aes(y=after_stat(count/sum(count))),breaks=seq(0,360,by=10)-5,
                 fill=w_rel_colors) +
  labs(y="Proportion of time",x="Relative wind angle") +
  ggtitle("GHAL") +
  theme_bw() +
  ylim(0,0.06) +
  coord_polar(start=-0.0873)
w_rel_polar_WAAL <- ggplot(m_all_nonaflaps %>% filter(Species=="WAAL"),aes(x=w_rel)) +
  geom_histogram(aes(y=after_stat(count/sum(count))),breaks=seq(0,360,by=10)-5,
                 fill=w_rel_colors) +
  labs(y="Proportion of time",x="Relative wind angle") +
  ggtitle("WAAL") +
  theme_bw() +
  ylim(0,0.06) +
  coord_polar(start=-0.0873)
w_rel_polar_BFAL <- ggplot(m_all_nonaflaps %>% filter(Species=="BFAL"),aes(x=w_rel)) +
  geom_histogram(aes(y=after_stat(count/sum(count))),breaks=seq(0,360,by=10)-5,
                 fill=w_rel_colors) +
  labs(y="Proportion of time",x="Relative wind angle") +
  ggtitle("BFAL") +
  theme_bw() +
  ylim(0,0.06) +
  coord_polar(start=-0.0873)
w_rel_polar_LAAL <- ggplot(m_all_nonaflaps %>% filter(Species=="LAAL"),aes(x=w_rel)) +
  geom_histogram(aes(y=after_stat(count/sum(count))),breaks=seq(0,360,by=10)-5,
                 fill=w_rel_colors) +
  labs(y="Proportion of time",x="Relative wind angle") +
  ggtitle("LAAL") +
  theme_bw() +
  ylim(0,0.06) +
  coord_polar(start=-0.0873)

grid.arrange(w_rel_polar_BBAL,w_rel_polar_GHAL,w_rel_polar_WAAL,w_rel_polar_BFAL,w_rel_polar_LAAL,
             nrow=2)




ggplot(m_all_nonaflaps %>% filter(Species=="LAAL"),aes(x=w_rel)) +
  geom_histogram(aes(y=after_stat(count/sum(count))),breaks=seq(0,360,by=10)-5,
                 fill=w_rel_colors) +
  labs(y="Proportion of time",x="Relative wind angle") +
  ggtitle("LAAL") +
  theme_bw() +
  ylim(0,0.06) +
  coord_polar(start=-0.0873)

w_rel_colors = c(rep("#e74c3c",5),rep("#2980b9",9),rep("#27ae60",9),rep("#2980b9",9),rep("#e74c3c",4))




  


polar_plot_bar <- ggplot(data, aes(x = categories, y = Freq)) +
  # geom_bar(stat = "identity", width = 1, fill = "skyblue") +
  geom_bar(stat="identity", alpha=1, fill="black") + 
  labs(main="Polar plot of wind angle relative to bird heading",y="Frequency",x="") +
  coord_polar(start = 0)  # Adjust the starting angle if needed
# scale_y_continuous(limits=c(0,1200))

seq(0,360,by=10)-5








wind_vel_hist_BBAL <- ggplot(m_all_nonaflaps %>% filter(Species=="BBAL"),aes(x=wind_vel)) +
  geom_histogram(aes(y=after_stat(count/sum(count))),bins=20) +
  labs(y="Proportion of time",x="Wind velocity (m/s)") +
  ggtitle("BBAL") +
  theme_bw() +
  ylim(0,0.15)
wind_vel_hist_GHAL <- ggplot(m_all_nonaflaps %>% filter(Species=="GHAL"),aes(x=wind_vel)) +
  geom_histogram(aes(y=after_stat(count/sum(count))),bins=20) +
  labs(y="Proportion of time",x="Wind velocity (m/s)") +
  ggtitle("GHAL") +
  theme_bw() +
  ylim(0,0.15)
wind_vel_hist_WAAL <- ggplot(m_all_nonaflaps %>% filter(Species=="WAAL"),aes(x=wind_vel)) +
  geom_histogram(aes(y=after_stat(count/sum(count))),bins=20) +
  labs(y="Proportion of time",x="Wind velocity (m/s)") +
  ggtitle("WAAL") +
  theme_bw() +
  ylim(0,0.15)
wind_vel_hist_BFAL <- ggplot(m_all_nonaflaps %>% filter(Species=="BFAL"),aes(x=wind_vel)) +
  geom_histogram(aes(y=after_stat(count/sum(count))),bins=20) +
  labs(y="Proportion of time",x="Wind velocity (m/s)") +
  ggtitle("BFAL") +
  theme_bw() +
  ylim(0,0.15)
wind_vel_hist_LAAL <- ggplot(m_all_nonaflaps %>% filter(Species=="LAAL"),aes(x=wind_vel)) +
  geom_histogram(aes(y=after_stat(count/sum(count))),bins=20) +
  labs(y="Proportion of time",x="Wind velocity (m/s)") +
  ggtitle("LAAL") +
  theme_bw() +
  ylim(0,0.15)

grid.arrange(wind_vel_hist_BBAL,wind_vel_hist_GHAL,wind_vel_hist_WAAL,wind_vel_hist_BFAL,wind_vel_hist_LAAL,
             nrow=2)











m_all_nonaflaps |>
  ggplot(aes(wind_vel)) +
  geom_histogram() + 
  # theme_minimal() +
  # ylim(0,30) +
  labs(y="Wind velocity (m/s)",x="Species") +
  ggtitle("Wind velocities experienced") +
  theme_bw() + 
  facet_wrap(~Species)

m_all_nonaflaps |>
  ggplot(aes(Species,bwa)) +
  geom_violin() + 
  # theme_minimal() +
  ylim(0,180) +
  labs(y="Relative wind angle (degrees)",x="Species")

m_all_nonaflaps %>% filter(HMM_3S_state!=1) |>
  ggplot(aes(Species,flaps)) +
  geom_violin() + 
  # theme_minimal() +
  ylim(0,2000) +
  labs(y="Flaps/hour",x="Species")









# Downsampling Bird_Island to Midway --------------------------------------

downsampled_ids <- c(sample(unique(m_BBAL_nonaflaps$id),
                            size=length(unique(m_BFAL_nonaflaps$id)),
                            replace=FALSE),
                     sample(unique(m_GHAL_nonaflaps$id),
                            size=length(unique(m_BFAL_nonaflaps$id)),
                            replace=FALSE),
                     sample(unique(m_WAAL_nonaflaps$id),
                            size=length(unique(m_BFAL_nonaflaps$id)),
                            replace=FALSE),
                     sample(unique(m_LAAL_nonaflaps$id),
                            size=length(unique(m_BFAL_nonaflaps$id)),
                            replace=FALSE),
                     unique(m_BFAL_nonaflaps$id))
ds_m_all_nonaflaps <- m_all_nonaflaps %>% filter(id %in% downsampled_ids)



# Downsampled plots

ds_m_all_nonaflaps |>
  ggplot(aes(Species,wind_vel)) +
  geom_violin() + 
  # theme_minimal() +
  ylim(0,30) +
  labs(y="Wind velocity (m/s)",x="Species")

ds_m_all_nonaflaps |>
  ggplot(aes(Species,bwa)) +
  geom_violin() + 
  # theme_minimal() +
  ylim(0,180) +
  labs(y="Relative wind angle (degrees)",x="Species")

ds_m_all_nonaflaps %>% filter(HMM_3S_state!=1) |>
  ggplot(aes(Species,flaps)) +
  geom_violin() + 
  # theme_minimal() +
  ylim(0,2000) +
  labs(y="Flaps/hour",x="Species")

ds_m_all_nonaflaps |>
  ggplot(aes(Species,wind_vel)) +
  geom_boxplot() + 
  theme_minimal()

ds_m_all_nonaflaps |>
  ggplot(aes(Species,flaps)) +
  geom_boxplot() +
  ylim(0,1000) +
  theme_minimal()

ds_m_all_nonaflaps |>
  ggplot(aes(Species,flaps)) +
  geom_violin(draw_quantiles = TRUE) +
  ylim(0,1000) +
  theme_minimal()


# Wind angle plots -------------------------------------------------------------

# set breaks
breaks <- seq(0,360,by=5)
categories <- cut(m_all_nonaflaps$w_rel,breaks,include.lowest=TRUE,right=FALSE)
frequency_table <- table(categories)
data <- as.data.frame(frequency_table)
data$categories <- breaks[-length(breaks)]

polar_plot <- ggplot(data, aes(x = categories, y = Freq)) + #, group=3)) +  #, group = day, color = day)) +
  geom_line() +
  coord_polar(start=0) 
# + scale_y_continuous(limits=c(0,75))

polar_plot

polar_plot_bar <- ggplot(data, aes(x = categories, y = Freq)) +
  # geom_bar(stat = "identity", width = 1, fill = "skyblue") +
  geom_bar(stat="identity", alpha=1, fill="black") + 
  labs(main="Polar plot of wind angle relative to bird heading",y="Frequency",x="") +
  coord_polar(start = 0)  # Adjust the starting angle if needed
# scale_y_continuous(limits=c(0,1200))

polar_plot_bar

