#!/usr/bin/env Rscript

library(munsellinterpol)

interpolate_grays <- function() {
  grays <- paste0("N", seq(0, 10, 0.5))
  rgb <- MunsellTosRGB(grays)
  write.csv(rgb, "munsell_neutrals.csv")
}

args <- commandArgs(trailingOnly = TRUE)
lab <- strsplit(args[[1]], " ", fixed = TRUE)
lab <- unlist(lapply(lab, as.numeric))
lab <- matrix(lab, nrow = 1, ncol = 3, byrow = TRUE)
hvc <- LabtoMunsell(lab)
hue <- HueStringFromNumber(round(2.0 * hvc[[1]]) / 2.0)
value <- round(2.0 * hvc[[2]]) / 2.0
chroma <- round(hvc[[3]])
cat(paste(hue, value, chroma, "\n"))
