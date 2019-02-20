#' Tidy version of cor.test
#'
#' @inheritParams correlation
#' @param x Name of a variable.
#' @param y Name of a variable.
#' @param ... Arguments passed to or from other methods.
#'
#' @examples
#' cor_test(iris, "Petal.Length", "Petal.Width")
#' @export
cor_test <- function(data, x, y, ci = "default", method = "pearson", bayesian = FALSE, iterations = 10^4, rope_full = TRUE, rope_bounds = c(-0.05, 0.05), ...) {
  if (bayesian == FALSE) {
    if (ci == "default") ci <- 0.95
    out <- .cor_test_freq(data, x, y, ci = ci, method = method, ...)
  } else {
    if (ci == "default") ci <- 0.9
    out <- .cor_test_bayes(data, x, y, ci = ci, iterations = iterations, rope_full = rope_full, rope_bounds = rope_bounds)
  }

  return(out)
}










#' @importFrom stats cor.test complete.cases
#' @keywords internal
.cor_test_freq <- function(data, x, y, ci = 0.95, method = "pearson", ...) {
  var_x <- data[[x]]
  var_y <- data[[y]]
  var_x <- var_x[complete.cases(var_x, var_y)]
  var_y <- var_y[complete.cases(var_x, var_y)]

  rez <- cor.test(var_x, var_y, conf.level = ci, method = match.arg(method, c("pearson", "kendall", "spearman"), several.ok = FALSE), alternative = "two.sided")

  params <- parameters::model_parameters(rez)
  params$Parameter1 <- x
  params$Parameter2 <- y

  if(x == y){
    if("t" %in% names(params)) params$t <- Inf
    if("z" %in% names(params)) params$z <- Inf
    if("S" %in% names(params)) params$S <- Inf
  }

  return(params)
}






#' @importFrom stats complete.cases mad median
#' @importFrom utils install.packages
#' @keywords internal
.cor_test_bayes <- function(data, x, y, ci = 0.90, iterations = 10^4, rope_full = TRUE, rope_bounds = c(-0.05, 0.05), prior="medium",  ...) {
  if (!requireNamespace("BayesFactor")) {
    warning("This function needs `BayesFactor` to be installed... installing now.")
    install.packages("BayesFactor")
    requireNamespace("BayesFactor")
  }

  var_x <- data[[x]]
  var_y <- data[[y]]
  var_x <- var_x[complete.cases(var_x, var_y)]
  var_y <- var_y[complete.cases(var_x, var_y)]

  if(x == y){
    params <- data.frame(
      "Parameter1" = x,
      "Parameter2" = y,
      "Median" = 1,
      "MAD" = 0,
      "CI_low" = 1,
      "CI_high" = 1,
      "pd" = 0,
      "ROPE_Percentage" = 0,
      "BF" = Inf,
      "Prior" = prior
    )
  } else{
    rez <- BayesFactor::correlationBF(var_x, var_y, rscale=prior)
    posterior <- as.data.frame(suppressMessages(BayesFactor::posterior(rez, iterations = iterations, progress = FALSE)))
    posterior <- posterior$rho
    hdi <- bayestestR::hdi(posterior, ci = ci)
    if (rope_full == TRUE) {
      rope <- bayestestR::rope(posterior, bounds = rope_bounds, ci = 1)
    } else {
      rope <- bayestestR::rope(posterior, bounds = rope_bounds, ci = ci)
    }

    params <- data.frame(
      "Parameter1" = x,
      "Parameter2" = y,
      "Median" = median(posterior),
      "MAD" = mad(posterior),
      "CI_low" = hdi$CI_low,
      "CI_high" = hdi$CI_high,
      "pd" = bayestestR::p_direction(posterior),
      "ROPE_Percentage" = rope$ROPE_Percentage,
      "BF" = exp(rez@bayesFactor$bf),
      "Prior" = prior,
      stringsAsFactors = FALSE
    )
  }


  return(params)
}