#!/usr/bin/env Rscript

library(munsellinterpol)

args <- commandArgs(trailingOnly = TRUE)
lab <- strsplit(args[[1]], " ", fixed = TRUE)
lab <- unlist(lapply(lab, as.numeric))
lab <- matrix(lab, nrow = 1, ncol = 3, byrow = TRUE)
hvc <- LabtoMunsell(lab)
hue <- HueStringFromNumber(hvc[[1]])
rhue <- HueStringFromNumber(round(hvc[[1]] / 2.5) * 2.5)
cat(paste(hue, rhue, hvc[[2]], hvc[[3]], "\n"))
