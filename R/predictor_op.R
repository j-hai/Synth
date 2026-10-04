# Internal: turn the name of a predictor operator into a checked function.
#
# dataprep() and spec.pred.func() aggregate a predictor over time by calling
# the operator as f(x, na.rm = TRUE) and need a single number back. The name
# is looked up from the caller's frame: in the Synth namespace and its
# imports, then base, then the global environment and attached packages.
# These are the places apply() searched when it was handed the name itself.
#
# `what` names the argument in error messages.

.predictor_op <-
function(op, what = "predictors.op")
  {
    envir <- parent.frame()

    # the name used to be passed through paste(), so anything that pastes to
    # one name (a string, a factor, a symbol) is still accepted
    name <- if (is.function(op)) NULL
            else tryCatch(paste(op), error = function(e) NULL)
    if (length(name) != 1 || (is.atomic(op) && is.na(op)))
     {stop("\n ", what, " must be a single character string naming a function, e.g. \"mean\" or \"median\" (the name in quotes, not the function itself)\n", call. = FALSE)}
    op <- name

    fun <- tryCatch(get(op, mode = "function", envir = envir),
                    error = function(e) NULL)
    if (is.null(fun))
     {stop("\n ", what, " = \"", op, "\": no function of that name was found. Give the bare name of a function (not \"package::name\") that is defined at top level or comes from an attached package\n", call. = FALSE)}

    # a closure with neither `...` nor a formal that na.rm can match
    # cannot be called with na.rm = TRUE; primitives match by position
    if (!is.primitive(fun))
     {
      fmls <- as.character(names(formals(fun)))
      if (!("..." %in% fmls) && !any(startsWith(fmls, "na.rm")))
       {stop("\n ", what, " = \"", op, "\": this function has no na.rm argument. It is called as ", op, "(x, na.rm = TRUE), so it has to accept na.rm\n", call. = FALSE)}
     }

    function(x, na.rm = TRUE)
      {
        out <- tryCatch(fun(x, na.rm = na.rm),
                        error = function(e)
                          stop("\n ", what, " = \"", op, "\" failed when called as ", op, "(x, na.rm = TRUE): ", conditionMessage(e), "\n", call. = FALSE))
        if (length(out) != 1 || !is.atomic(out) || is.factor(out) ||
            !(typeof(out) %in% c("double", "integer", "logical")))
         {stop("\n ", what, " = \"", op, "\" has to return a single number each time it is applied; it returned an object of class \"", class(out)[1], "\" and length ", length(out), "\n", call. = FALSE)}
        out
      }
  }
