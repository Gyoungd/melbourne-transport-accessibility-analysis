install.packages(c('DBI', 'RPostgres', 'sf','dplyr','ggplot2','scales'))

library(DBI)
library(RPostgres)
library(sf)
library(dplyr)
library(ggplot2)
library(scales)
library(ggrepel)

# Connect DB + Load table
con <- dbConnect(
  RPostgres::Postgres(),
  host = "crossover.proxy.rlwy.net",
  dbname = "railway",
  user="postgres",
  password="F34g5EGDea16Ab3B43DcAeCD2C3AgBaE",
  port=44328
)

sa2 <- st_read(
  con,
  query = "
    select sa2_code, sa2_name, area_km2,
    stop_density, route_coverage, service_intensity,
    geom_4326
    from ptv.q1_sa2_metrics
  "
)

print(sa2)
st_is_valid(sa2) |> table()

# Make Choropleth 
# Plot base
plot_choropleth <- function(sf_df, value_col, title, subtitle=NULL){
  ggplot(sf_df) +
    geom_sf(aes(fill = .data[[value_col]]), color = NA) +
    labs(
      title = title,
      subtittle = subtitle,
      fill = NULL
    ) +
    theme_minimal(base_size = 12) +
    theme(
      plot.title = element_text(face = "bold"),
      legend.position = "right"
    )
}

# Plot per indicator
p1 <- plot_choropleth(
  sa2,
  "stop_density",
  "Stop Density by SA2 (per km2)"
)

p2 <- plot_choropleth(
  sa2,
  "route_coverage",
  "Route Coverage by SA2 (distinct routes per km²)"
)

p3 <- plot_choropleth(
  sa2,
  "service_intensity",
  "Service Intensity by SA2 (avg weekday stop events per km²)",
  subtitle = "Computed using weekday flags in GTFS calendar (Mon–Fri)"
)

p1; p2; p3

# Worst & Best 10
plot_worst_best <- function(sf_df, value_col, n=10, title = NULL,
                            label = TRUE, label_size = 3,
                            digits = 2, worst_high = TRUE){
  
  stopifnot(inherits(sf_df, "sf"))
  stopifnot(value_col %in% names(sf_df))
  
  suppressPackageStartupMessages({
    library(dplyr)
    library(sf)
    library(ggplot2)
    library(ggrepel)
  })
  
  df <- sf_df %>%
    mutate(val = .data[[value_col]]) %>%
    filter(!is.na(val))
  
  # Rank Logic
  if (worst_high) {
    # Low is worst, high is best
    df <- df %>%
      mutate(rank_worst = min_rank(val),
             rank_best = min_rank(desc(val)))
  } else {
    # high is worst, low is best
    df <- df %>%
      mutate(rank_worst = min_rank(desc(val)),
             rank_best = min_rank(val))
  }
  
  df <- df %>%
    mutate(group = case_when(
      rank_worst <= n ~ "Worst",
      rank_best <= n ~ "Best",
      T ~ "Other"
    )) %>%
    mutate(group = factor(group, levels = c("Worst", "Best", "Other")))
  
  # Labels
  labs_df <- df %>%
    filter(group %in% c("Worst", "Best")) %>%
    st_transform(3857) %>%
    st_point_on_surface() %>%
    st_transform(4326) %>%
    cbind(st_coordinates(.)) %>%
    as.data.frame() %>%
    mutate(label_txt = paste0(sa2_name, '\n', format(round(val, digits), nsmall = digits)))
  
  # Color
  fill_map <- c(
    "Worst" = "#ED3915",
    "Best" = "#0072B2",
    "Other" = "grey85"
  )
  
  p <- ggplot(df) +
    # Other -> Gray
    geom_sf(aes(fill = group),
            color = "white", linewidth = .15) +
    # Group legend
    scale_fill_manual(values = fill_map, name = NULL, drop =F,
                      breaks = c("Worst", "Best")) +
    coord_sf(datum = NA) +
    #labs(
     # title = title %||% paste0(tools::toTitleCase(gsub("_", " ", value_col)), ": Worst/Best", n, " in Melbourne")
    #) +
    theme_minimal(base_size = 12) +
    theme(
      plot.title = element_text(face= "bold"),
      legend.position = "right",
      axis.title = element_blank(),
      axis.text  = element_blank(),
      axis.ticks = element_blank()
    ) 
    
  if (label && nrow(labs_df) > 0) {
    p <- p +
    geom_label_repel(
      data = labs_df,
      aes(X, Y, label = sa2_name),
      size = label_size,
      fill = "white",
      color = "black",
      label.size = .2, # Stroke
      label.padding = unit(.15, "lines"),
      min.segment.length = 0,
      max.overlaps = Inf
    )
  }
  
  p
}


plot_worst_best(sa2, "stop_density", n=5)
plot_worst_best(sa2, "route_coverage", n=5)
plot_worst_best(sa2, "service_intensity" , n=5)
