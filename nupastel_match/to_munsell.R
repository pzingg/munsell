#!/usr/bin/env Rscript

library(jsonlite)
library(munsellinterpol)

args <- commandArgs(trailingOnly = TRUE)
args <- strsplit(args[[1]], " ", fixed = TRUE)[[1]]
# args are c("xyY", c1, c2, c3)

space <- args[[1]]
color <- unlist(lapply(args[2:length(args)], as.numeric))

if (space == "xyY") {
  cmat <- matrix(color, ncol = length(color), nrow = 1, byrow = TRUE)
  # Expects a 1x3 matrix with x, y in [0, 1] and Y in [0, 100]
  out <- xyYtoMunsell(cmat, perf = TRUE)
} else if (space == "sRGB") {
  # Expects a 3-element vector with each value in [0, 255]
  out <- RGBtoMunsell(color, space=space)
} else {
  out <- list(error=paste0('invalid space ', space))
}

cat(jsonlite::toJSON(out))
