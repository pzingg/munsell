#!/usr/bin/env Rscript

library(munsellinterpol)

grays <- paste0("N", seq(0, 10, 0.5))
rgb <- MunsellTosRGB(grays)
write.csv(rgb, "munsell_neutrals.csv")
quit("no")

args <- commandArgs(trailingOnly = TRUE)
lab <- strsplit(args[[1]], " ", fixed = TRUE)
lab <- unlist(lapply(lab, as.numeric))
lab <- matrix(lab, nrow = 1, ncol = 3, byrow = TRUE)
hvc <- LabtoMunsell(lab)
hue <- HueStringFromNumber(hvc[[1]], digits = 3)
cat(paste(hue, hvc[[2]], hvc[[3]], "\n"))
